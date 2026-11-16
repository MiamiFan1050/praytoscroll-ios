import Foundation
import Observation
import SwiftData

/// One screen of a prayer.
/// What a reading step shows (Read a verse / Devotional).
struct ReadingCard: Equatable {
    var title: String = ""
    var ref: String
    var text: String
    var body: String
    var closing: String = ""
}

struct PrayerStep: Identifiable, Equatable {
    enum Kind: Equatable { case prompt, verseReveal, reading }
    let id = UUID()
    var kind: Kind
    var overline: String
    var title: String
    var prompt: String
    var symbol: String
    /// Prompt-bag key, used by "another prompt".
    var poolKey: String
    var reading: ReadingCard? = nil
}

enum SessionPhase: Equatable {
    case choosePerson, praying, letThemKnow, celebration
}

/// Drives a prayer session: steps, the honest timer (pauses in the background), and completion.
@MainActor
@Observable
final class PrayerFlow {
    let request: SessionRequest
    let model: AppModel
    private(set) var minimumSeconds: Double
    /// Starts as the request's style; the gate screen can switch it ("Ask me after each prayer").
    private(set) var style: UnlockStyle
    /// The devotional on screen, if any.
    private(set) var devotional: Devotional?

    var phase: SessionPhase
    var steps: [PrayerStep] = []
    var stepIndex = 0
    var elapsed: Double = 0
    var isActive = true
    var showWelcomeBack = false
    var mood: PrayerMood?
    var verse: Verse
    var revealedLines = 1
    var personID: UUID?
    var personName: String = ""
    var personRequests: [String] = []
    var completion: PrayerCompletion?
    var startedAt = Date()

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var lastTick = Date()

    init(request: SessionRequest, model: AppModel) {
        self.request = request
        self.model = model
        self.minimumSeconds = model.minimumSeconds(for: request.style, isSample: request.isSample)
        self.style = request.style
        self.verse = request.verse ?? model.verses.verse()
        self.mood = request.mood
        self.phase = request.style == .forSomeone && request.personID == nil && request.friend == nil ? .choosePerson : .praying
        if let friend = request.friend {
            // "Pray for @friend": their nickname, nothing from my private prayer list.
            personName = friend.displayName.isEmpty ? friend.atHandle : friend.displayName
        }
        if let personID = request.personID, let person = model.fetchPerson(id: personID) {
            choose(person: person)
        }
        if phase == .praying { buildSteps() }
    }

    var method: UnlockMethod { UnlockMethod(style: style) }

    /// The gate screen offers Prayer / Read a verse / Devotional when "Ask me after each prayer" is on.
    var canSwitchMethod: Bool {
        request.source == .gate && !request.isSample && model.settings.askUnlockEachTime && phase == .praying
    }

    /// Switches how this unlock happens; the timer starts again for the new choice.
    func switchMethod(to newMethod: UnlockMethod) {
        guard newMethod != method else { return }
        var next = model.sessionStyle(for: newMethod)
        if next == .forSomeone, personName.isEmpty { next = .quick }   // no person picked on the gate screen
        style = next
        minimumSeconds = model.minimumSeconds(for: next, isSample: request.isSample)
        buildSteps()
        elapsed = 0
        startedAt = Date()
        showWelcomeBack = false
        Haptics.selection()
    }
    var gatedApp: GatedApp? { model.gatedApp(id: request.gatedAppID) }
    var currentStep: PrayerStep? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }
    var isLastStep: Bool { stepIndex >= steps.count - 1 }
    var remaining: Double { max(0, minimumSeconds - elapsed) }
    var canSayAmen: Bool { elapsed >= minimumSeconds && isLastStep && currentStep?.kind != .verseReveal }
    var progress: Double { minimumSeconds > 0 ? min(1, elapsed / minimumSeconds) : 1 }

    var styleLabel: String {
        if steps.count > 1 { return "\(style.shortTitle) · \(stepIndex + 1) of \(steps.count)" }
        return style.title
    }

    // MARK: Person

    func choose(person: Person) {
        personID = person.id
        personName = person.name
        personRequests = person.openRequests.prefix(3).map(\.text)
    }

    func choose(name: String, addToList: Bool) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if addToList {
            let person = model.addPerson(name: trimmed, relationship: "")
            choose(person: person)
        } else {
            personID = nil
            personName = trimmed
            personRequests = []
        }
    }

    func beginPrayingForChosenPerson() {
        guard !personName.isEmpty else { return }
        buildSteps()
        elapsed = 0
        startedAt = Date()
        withAnimationPhase(.praying)
    }

    var personFirstName: String {
        personName.split(separator: " ").first.map(String.init) ?? personName
    }

    // MARK: Steps

    private func draw(_ key: String, _ pool: [String]) -> String {
        model.store.nextPrompt(key: key, from: pool)
    }

    func buildSteps() {
        let library = model.content.prompts
        var built: [PrayerStep] = []
        switch style {
        case .quick:
            if let seed = request.seedPrompt, !seed.isEmpty {
                built = [PrayerStep(kind: .prompt, overline: request.circleRequest != nil ? "Praying for your circle" : "Pause & pray",
                                    title: "", prompt: seed, symbol: request.topic?.symbol ?? "bolt.heart.fill",
                                    poolKey: request.circleRequest != nil ? "" : "quick")]
            } else if let topic = request.topic {
                built = [PrayerStep(kind: .prompt, overline: "Praying about \(topic.title.lowercased())", title: "",
                                    prompt: draw(topic.poolKey, library.prompts(for: topic)),
                                    symbol: topic.symbol, poolKey: topic.poolKey)]
            } else if let mood, let pool = model.content.moodPrompts[mood] {
                built = [PrayerStep(kind: .prompt, overline: mood == .tempted ? "Right now" : "Quick prayer", title: "", prompt: draw("mood.\(mood.rawValue)", pool),
                                    symbol: mood.symbol, poolKey: "mood.\(mood.rawValue)")]
            } else if let time = PrayerTopic.timeOfDay(hour: Calendar.current.component(.hour, from: Date())),
                      Bool.random() {
                // Mornings and nights: every other quick prayer fits the hour (its own bag, so nothing repeats).
                built = [PrayerStep(kind: .prompt, overline: time == .morning ? "Morning prayer" : "Night prayer", title: "",
                                    prompt: draw(time.poolKey, library.prompts(for: time)),
                                    symbol: time.symbol, poolKey: time.poolKey)]
            } else {
                built = [PrayerStep(kind: .prompt, overline: "Quick prayer", title: "", prompt: draw("quick", library.quick),
                                    symbol: "bolt.heart.fill", poolKey: "quick")]
            }
        case .guided:
            // In prompts.json {name} means the person being prayed for. Nobody is picked in a guided
            // prayer, so those prompts are skipped here.
            built = ACTSStep.allCases.map { step in
                let pool = library.prompts(for: step).filter { !$0.contains("{name}") }
                let usable = pool.isEmpty ? PromptLibrary.fallback.prompts(for: step).filter { !$0.contains("{name}") } : pool
                let text = draw(step.rawValue + ".solo", usable)
                return PrayerStep(kind: .prompt, overline: step.title, title: step.caption, prompt: text, symbol: step.symbol,
                                  poolKey: step.rawValue + ".solo")
            }
            if let mood, let pool = model.content.moodPrompts[mood], !built.isEmpty {
                built[0].prompt = draw("mood.\(mood.rawValue)", pool)
            }
        case .verse:
            built = [
                PrayerStep(kind: .verseReveal,
                           overline: request.verse == nil ? "Today's verse" : (verse.theme == "advent" ? "Advent reading" : "Pray this verse"),
                           title: verse.ref, prompt: verse.displayText, symbol: "book.pages.fill", poolKey: ""),
                PrayerStep(kind: .prompt, overline: "Pray it", title: verse.ref,
                           prompt: request.seedPrompt.flatMap { $0.isEmpty ? nil : $0 }
                               ?? "Read it once more, slowly. Then tell God what it stirs in you, in your own words.",
                           symbol: "hands.and.sparkles.fill", poolKey: ""),
            ]
            revealedLines = 1
        case .forSomeone:
            let name = personFirstName.isEmpty ? "them" : personFirstName
            built = [PrayerStep(kind: .prompt, overline: "Praying for \(name)", title: "",
                                prompt: ContentStore.fill(draw("forSomeone", library.forSomeone), name: name),
                                symbol: "person.2.fill", poolKey: "forSomeone")]
        case .readVerse:
            // A different verse each time (a shuffled bag over the 366), unless a specific one was asked for.
            if request.verse == nil {
                let all = model.verses.verses
                let ref = draw("readVerse", all.map(\.ref))
                verse = all.first { $0.ref == ref } ?? verse
            }
            let card = ReadingCard(ref: verse.ref, text: verse.displayText, body: verse.meaning ?? "")
            built = [PrayerStep(kind: .reading, overline: "Read a verse", title: verse.ref, prompt: verse.displayText,
                                symbol: UnlockMethod.verse.symbol, poolKey: "", reading: card)]
            minimumSeconds = model.minimumSeconds(for: style, isSample: request.isSample,
                                                  readingWords: ReadingTime.wordCount([card.text, card.body]))
        case .devotional:
            let all = model.content.devotionals
            let id = draw("devotional", all.map(\.id))
            let entry = all.first { $0.id == id } ?? all.first ?? .fallback
            devotional = entry
            let text = model.settings.translation == .kjv ? (entry.kjv ?? entry.text) : entry.text
            let card = ReadingCard(title: entry.title, ref: entry.ref, text: text, body: entry.body, closing: entry.prayer)
            built = [PrayerStep(kind: .reading, overline: "Devotional", title: entry.title, prompt: text,
                                symbol: UnlockMethod.devotional.symbol, poolKey: "", reading: card)]
            minimumSeconds = model.minimumSeconds(for: style, isSample: request.isSample, readingWords: entry.readingWords)
        }
        steps = built
        stepIndex = 0
    }

    func anotherPrompt() {
        guard let step = currentStep, step.kind == .prompt, !step.poolKey.isEmpty else { return }
        let library = model.content.prompts
        var pool: [String]
        if step.poolKey.hasPrefix("mood."), let mood = PrayerMood(rawValue: String(step.poolKey.dropFirst(5))) {
            pool = model.content.moodPrompts[mood] ?? library.quick
        } else if let acts = ACTSStep(rawValue: step.poolKey.replacingOccurrences(of: ".solo", with: "")) {
            pool = library.prompts(for: acts).filter { !$0.contains("{name}") }
        } else if step.poolKey == "forSomeone" {
            pool = library.forSomeone
        } else if step.poolKey.hasPrefix("topic."), let topic = PrayerTopic(rawValue: String(step.poolKey.dropFirst(6))) {
            pool = library.prompts(for: topic)
        } else {
            pool = library.quick
        }
        if pool.count < 2 { pool = library.quick }
        var next = draw(step.poolKey, pool)
        if next == step.prompt { next = draw(step.poolKey, pool) }
        steps[stepIndex].prompt = style == .forSomeone ? ContentStore.fill(next, name: personFirstName) : next
        Haptics.selection()
    }

    func select(mood newMood: PrayerMood?) {
        mood = newMood
        model.updateSettings { $0.lastMood = newMood }
        guard let newMood, let pool = model.content.moodPrompts[newMood], stepIndex < steps.count,
              steps[stepIndex].kind == .prompt, style != .forSomeone else { return }
        steps[stepIndex].prompt = draw("mood.\(newMood.rawValue)", pool)
        steps[stepIndex].poolKey = "mood.\(newMood.rawValue)"
        Haptics.selection()
    }

    func next() {
        guard stepIndex < steps.count - 1 else { return }
        stepIndex += 1
        Haptics.tap()
    }

    func revealNextLine() {
        let total = verse.revealLines.count
        if revealedLines < total {
            revealedLines += 1
            Haptics.selection()
        }
    }

    var allLinesRevealed: Bool { revealedLines >= verse.revealLines.count }

    // MARK: Timer (counts only while PrayToScroll is in the foreground)

    func startTimer() {
        ticker?.cancel()
        lastTick = Date()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self else { return }
                let now = Date()
                if self.isActive && self.phase == .praying {
                    self.elapsed += now.timeIntervalSince(self.lastTick)
                }
                self.lastTick = now
            }
        }
    }

    func stopTimer() {
        ticker?.cancel()
        ticker = nil
    }

    func scenePhaseChanged(active: Bool) {
        if active && !isActive && phase == .praying && elapsed > 0 && remaining > 0 {
            showWelcomeBack = true
        }
        isActive = active
        lastTick = Date()
    }

    // MARK: Finish

    func sayAmen() {
        stopTimer()
        if request.isSample {
            model.sampleCompleted = true
            Haptics.success()
            withAnimationPhase(.celebration)
            return
        }
        let outcome = PrayerOutcome(style: style, source: request.source, gatedAppID: request.gatedAppID,
                                    startedAt: startedAt, completedAt: Date(), personID: personID,
                                    personName: personName, verseRef: verseRefForHistory,
                                    circleRequest: request.circleRequest, friend: request.friend)
        completion = model.completePrayer(outcome)
        // A friend sees "prayed for you" in the app, so there's no text message to offer.
        withAnimationPhase(style == .forSomeone && !personName.isEmpty && request.friend == nil ? .letThemKnow : .celebration)
    }

    private var verseRefForHistory: String {
        switch style {
        case .verse, .readVerse: return verse.ref
        case .devotional: return devotional?.ref ?? ""
        default: return ""
        }
    }

    func finishLetThemKnow() {
        withAnimationPhase(.celebration)
    }

    private func withAnimationPhase(_ newPhase: SessionPhase) {
        phase = newPhase
    }
}
