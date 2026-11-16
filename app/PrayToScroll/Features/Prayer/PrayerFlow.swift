import Foundation
import Observation
import SwiftData

/// One screen of a prayer.
struct PrayerStep: Identifiable, Equatable {
    enum Kind: Equatable { case prompt, verseReveal }
    let id = UUID()
    var kind: Kind
    var overline: String
    var title: String
    var prompt: String
    var symbol: String
    /// Prompt-bag key, used by "another prompt".
    var poolKey: String
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
    let minimumSeconds: Double

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
        self.verse = request.verse ?? model.verses.verse()
        self.mood = request.mood
        self.phase = request.style == .forSomeone && request.personID == nil ? .choosePerson : .praying
        if let personID = request.personID, let person = model.fetchPerson(id: personID) {
            choose(person: person)
        }
        if phase == .praying { buildSteps() }
    }

    var style: UnlockStyle { request.style }
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
                built = [PrayerStep(kind: .prompt, overline: "Pause & pray", title: "", prompt: seed,
                                    symbol: "bolt.heart.fill", poolKey: "quick")]
            } else if let mood, let pool = model.content.moodPrompts[mood] {
                built = [PrayerStep(kind: .prompt, overline: mood == .tempted ? "Right now" : "Quick prayer", title: "", prompt: draw("mood.\(mood.rawValue)", pool),
                                    symbol: mood.symbol, poolKey: "mood.\(mood.rawValue)")]
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
                PrayerStep(kind: .verseReveal, overline: request.verse == nil ? "Today's verse" : "Pray this verse", title: verse.ref, prompt: verse.text, symbol: "book.pages.fill", poolKey: ""),
                PrayerStep(kind: .prompt, overline: "Pray it", title: verse.ref,
                           prompt: "Read it once more, slowly. Then tell God what it stirs in you, in your own words.",
                           symbol: "hands.and.sparkles.fill", poolKey: ""),
            ]
            revealedLines = 1
        case .forSomeone:
            let name = personFirstName.isEmpty ? "them" : personFirstName
            built = [PrayerStep(kind: .prompt, overline: "Praying for \(name)", title: "",
                                prompt: ContentStore.fill(draw("forSomeone", library.forSomeone), name: name),
                                symbol: "person.2.fill", poolKey: "forSomeone")]
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
                                    personName: personName, verseRef: style == .verse ? verse.ref : "")
        completion = model.completePrayer(outcome)
        withAnimationPhase(style == .forSomeone && !personName.isEmpty ? .letThemKnow : .celebration)
    }

    func finishLetThemKnow() {
        withAnimationPhase(.celebration)
    }

    private func withAnimationPhase(_ newPhase: SessionPhase) {
        phase = newPhase
    }
}
