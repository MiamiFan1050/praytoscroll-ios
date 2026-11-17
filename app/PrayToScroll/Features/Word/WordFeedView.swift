import SwiftData
import SwiftUI

/// "Scroll the Word": a full-screen, swipe-up feed. Verses on original photo backdrops with a slow drift, mixed with
/// "What this means", "Finish the verse", "Who said it?", Bible facts, questions to sit with, prayer prompts and
/// "Who needs this today?" cards. A haptic tick on every card, a heart burst on double-tap, swipe left to pray.
/// A daily goal ring, a goal streak, levels, badges and boards; "For you" learns from hearts, saves, shares and how
/// long you stay on a verse, on this iPhone only. When the goal is met: "Goal done 🙏", pray or keep going.
struct WordFeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedVerse.savedAt, order: .reverse) private var saved: [SavedVerse]
    @State private var shareCard: ShareCardKind?
    @State private var showSaved = false
    @State private var showDisplay = false
    @State private var showProgress = false
    @State private var boardVerse: Verse?
    @State private var sendVerse: Verse?
    @State private var position: String?
    @State private var items: [FeedItem] = []
    /// nil = "For you" (every verse).
    @State private var topic: String?
    /// Quiz picks by card id.
    @State private var answers: [String: String] = [:]
    /// Cards already counted this session (scrolling back never counts twice).
    @State private var counted: Set<String> = []
    @State private var visibleSince = Date()
    @State private var savedToast: Verse?
    @State private var milestoneCount = 0
    private let reader = VerseReader.shared

    private var today: DayKey { DayKey.today() }

    var body: some View {
        let savedRefs = Set(saved.map(\.ref))
        let settings = model.settings
        ZStack(alignment: .top) {
            Palette.midnightDeep.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        FeedCard(item: item,
                                 isCurrent: item.id == position,
                                 translation: settings.translation,
                                 textScale: settings.wordTextScale,
                                 showMeaning: settings.showMeanings,
                                 isSpeaking: item.readableVerse.map { reader.speakingDay == $0.day } ?? false,
                                 isSaved: item.readableVerse.map { savedRefs.contains($0.ref) } ?? false,
                                 friendsLine: item.readableVerse.flatMap { FriendSaves.line(model.friendSaves[$0.ref] ?? []) },
                                 answer: answers[item.id],
                                 actions: actions(for: item, savedRefs: savedRefs))
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
            .ignoresSafeArea(edges: .top)
            .accessibilityIdentifier("word.feed")

            VStack(spacing: 10) {
                header
                topicBar
            }

            if let verse = savedToast {
                savedToastView(verse)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(\.colorScheme, .dark)
        .sheet(item: $shareCard) { kind in ShareCardSheet(kind: kind).environment(model) }
        .sheet(isPresented: $showSaved) {
            NavigationStack { SavedVersesView() }
                .environment(model)
        }
        .sheet(isPresented: $showDisplay) {
            NavigationStack { WordDisplaySheet() }
                .environment(model)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showProgress) {
            NavigationStack { WordProgressSheet() }
                .environment(model)
                .presentationDetents([.large])
        }
        .sheet(item: $boardVerse) { verse in
            NavigationStack { SaveToBoardSheet(verse: verse) { ensureSaved(verse) } }
                .environment(model)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $sendVerse) { verse in
            SendVerseSheet(verse: verse) {
                model.wordProgress.signal(.sent, theme: verse.theme)
                celebrate(model.wordProgress.recordSent(today: today))
            }
            .environment(model)
        }
        .onChange(of: position) { old, id in
            Haptics.selection()
            cardLeft(old)
            cardBecameVisible(id)
        }
        .onChange(of: topic) { _, _ in rebuild() }
        .onChange(of: model.username) { _, _ in model.refreshFriendSaves(force: true) }
        .onChange(of: model.settings.ambientSound) { _, on in on ? AmbientSound.shared.start() : AmbientSound.shared.stop() }
        .onAppear {
            if items.isEmpty { rebuild() }
            if model.settings.ambientSound { AmbientSound.shared.start() }
            model.refreshFriendSaves()
        }
        .onDisappear {
            reader.stop()
            AmbientSound.shared.stop()
            cardLeft(position)
        }
    }

    // MARK: Header

    private var header: some View {
        let progress = model.wordProgress
        let read = progress.readOn(today.string)
        let goal = model.settings.wordGoal
        let streak = progress.streak(today: today)
        return HStack(spacing: 10) {
            Button { showProgress = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        ProgressRing(progress: Double(read) / Double(max(1, goal)), lineWidth: 4, track: Palette.cream.opacity(0.2))
                        Text("\(min(read, 999))")
                            .font(.system(.footnote, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.cream)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(read >= goal ? "Goal done" : "\(read) of \(goal)")
                            .font(.akSubheadlineSemibold)
                            .foregroundStyle(Palette.cream)
                            .monospacedDigit()
                        Text("Level \(progress.level.number) · \(progress.level.name)")
                            .font(.akCaption)
                            .foregroundStyle(Palette.cream.opacity(0.65))
                    }
                    if streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill").foregroundStyle(Palette.flameGradient)
                            Text("\(streak)").font(.akSubheadlineSemibold).foregroundStyle(Palette.cream).monospacedDigit()
                        }
                    }
                }
                .padding(.leading, 6)
                .padding(.trailing, 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(.ultraThinMaterial))
            }
            .buttonStyle(PressScaleStyle(scale: 0.96))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily goal, \(read) of \(goal) verses. Level \(progress.level.number)."
                                + (streak > 0 ? " Goal met \(streak) days in a row." : ""))
            .accessibilityIdentifier("word.goal")
            Spacer(minLength: 4)
            Button { showDisplay = true } label: {
                Text("Aa")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.cream)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .accessibilityLabel("Text size, translation, read aloud and sound")
            .accessibilityIdentifier("word.display")
            Button { showSaved = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").foregroundStyle(Palette.rose)
                    Text("\(saved.count)").font(.akSubheadlineSemibold).foregroundStyle(Palette.cream).monospacedDigit()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(.ultraThinMaterial))
            }
            .accessibilityLabel("Saved verses, \(saved.count)")
            .accessibilityIdentifier("word.saved")
        }
        .padding(.horizontal, Spacing.page)
        .padding(.top, 6)
    }

    /// "For you" + one feed per topic.
    private var topicBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                topicChip(nil, title: "For you")
                ForEach(WordFeedPlanner.topics, id: \.self) { topicChip($0, title: WordFeedPlanner.title(for: $0)) }
            }
            .padding(.horizontal, Spacing.page)
        }
        .scrollClipDisabled()
    }

    private func topicChip(_ value: String?, title: String) -> some View {
        let selected = topic == value
        return Button {
            guard topic != value else { return }
            Haptics.selection()
            withAnimation(.snappy) { topic = value }
        } label: {
            Text(title)
                .font(.akFootnote.weight(.semibold))
                .foregroundStyle(selected ? Palette.midnight : Palette.cream)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background {
                    if selected { Capsule().fill(Palette.goldButton) } else { Capsule().fill(.ultraThinMaterial) }
                }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("word.topic.\(value ?? "all")")
    }

    private func savedToastView(_ verse: Verse) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill").foregroundStyle(Palette.rose)
            Text("Saved").font(.akSubheadlineSemibold).foregroundStyle(Palette.cream)
            Spacer(minLength: 8)
            Button {
                savedToast = nil
                boardVerse = verse
            } label: {
                Text("Add to a board")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.midnight)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Capsule().fill(Palette.goldButton))
            }
            .accessibilityIdentifier("word.toast.board")
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(minHeight: 52)
        .background(Capsule().fill(.ultraThinMaterial))
        .padding(.horizontal, Spacing.page)
        .padding(.trailing, 70)
    }

    // MARK: Building the feed

    private func rebuild() {
        reader.stop()
        answers = [:]
        let dayOfYear = today.dayOfYear(calendar: .current)
        let all = ScrollContent.shared.feedVerses(daily: model.verses.verses)
        let seen = model.store.wordSeen
        var ordered = WordFeedPlanner.order(verses: all, topic: topic, seen: seen,
                                            today: model.verses.verse(forDayOfYear: dayOfYear).day, seed: model.store.wordSeed)
        if topic == nil {
            ordered = ForYouRanker.order(ordered, affinity: model.wordProgress.affinity, seed: model.store.wordSeed,
                                         seen: Set(seen), pinFirst: true)
        }
        var built = FeedMixer.build(.init(verses: ordered, content: ScrollContent.shared, prompts: model.content.prompts.quick,
                                          topic: topic, seed: model.store.wordSeed &+ UInt64(seen.count / 7),
                                          seenExtras: model.wordProgress.seenExtras))
        #if DEBUG
        // UI tests: `-wordCard finish|whoSaid|fact|reflect|send|meaning|pray` opens the feed on that kind of card.
        if let raw = model.options.wordCard, let kind = FeedCardKind(rawValue: raw),
           let index = built.firstIndex(where: { $0.kind == kind }) {
            built.insert(built.remove(at: index), at: 0)
        }
        #endif
        items = built
        position = items.first?.id
        cardBecameVisible(position)
    }

    private func preload(around id: String?) {
        guard let id, let index = items.firstIndex(where: { $0.id == id }) else { return }
        let window = BackdropCache.window
        let lower = max(0, index - window), upper = min(items.count - 1, index + window)
        guard lower <= upper else { return }
        BackdropCache.shared.preload(items[lower...upper].map(\.background))
    }

    private func cardBecameVisible(_ id: String?) {
        visibleSince = Date()
        preload(around: id)
        guard let id, let item = items.first(where: { $0.id == id }) else { return }
        if let extra = item.fact?.id ?? item.who?.id ?? item.finish?.id ?? item.reflection?.id {
            model.wordProgress.markExtraSeen(extra)
        }
        guard let verse = item.readableVerse else {
            reader.stop()
            return
        }
        model.store.markVerseSeen(verse.day)
        if !counted.contains(id) {
            counted.insert(id)
            let events = model.wordProgress.recordRead(theme: verse.theme, today: today, goal: model.settings.wordGoal)
            celebrate(events, after: id)
        }
        if model.settings.readAloud {
            reader.read(verse.rendered(in: model.settings.translation))
        } else if reader.speakingDay != nil, reader.speakingDay != verse.day {
            reader.stop()
        }
    }

    /// How long a verse stayed on screen feeds "For you" (a quick flick past is a mild "less of this").
    private func cardLeft(_ id: String?) {
        guard let id, let verse = items.first(where: { $0.id == id })?.readableVerse else { return }
        model.wordProgress.signal(.dwell(Date().timeIntervalSince(visibleSince)), theme: verse.theme)
    }

    /// Slots one celebration card in after the current one: the goal first, then a level, then a badge.
    private func celebrate(_ events: [WordEvent], after id: String? = nil) {
        let ranked = events.sorted { rank($0) < rank($1) }
        guard let event = ranked.first,
              let anchor = id ?? position,
              let index = items.firstIndex(where: { $0.id == anchor }) else { return }
        // "First goal" is the goal card itself.
        if case .badge(.firstGoal) = event, events.count == 1 { return }
        milestoneCount += 1
        var card = FeedMixer.milestone(for: event, streak: model.wordProgress.streak(today: today), index: milestoneCount)
        card.background = (items[index].background + FeedBackgrounds.count / 2) % FeedBackgrounds.count
        items.insert(card, at: index + 1)
    }

    private func rank(_ event: WordEvent) -> Int {
        switch event {
        case .goalReached: return 0
        case .levelUp: return 1
        case .badge: return 2
        }
    }

    // MARK: Card actions

    private func actions(for item: FeedItem, savedRefs: Set<String>) -> FeedCardActions {
        FeedCardActions(
            save: { toggleSave(item, savedRefs: savedRefs, forceOn: false) },
            doubleTap: { toggleSave(item, savedRefs: savedRefs, forceOn: true) },
            share: { share(item) },
            listen: { listen(item) },
            pray: { pray(item) },
            send: { if let verse = item.readableVerse { sendVerse = verse.rendered(in: model.settings.translation) } },
            boards: {
                if let verse = item.readableVerse {
                    Haptics.tap()
                    boardVerse = verse.rendered(in: model.settings.translation)
                }
            },
            answer: { choice in answer(choice, on: item) },
            keepGoing: { keepGoing(from: item) })
    }

    private func toggleSave(_ item: FeedItem, savedRefs: Set<String>, forceOn: Bool) {
        guard let verse = item.readableVerse?.rendered(in: model.settings.translation) else {
            if forceOn { Haptics.tap() }
            return
        }
        if savedRefs.contains(verse.ref) {
            guard !forceOn else { return }
            for entry in saved where entry.ref == verse.ref { context.delete(entry) }
            model.wordProgress.removeEverywhere(ref: verse.ref)
            Haptics.tap()
            withAnimation { savedToast = nil }
        } else {
            context.insert(SavedVerse(verse: verse))
            Haptics.success()
            model.wordProgress.signal(.heart, theme: verse.theme)
            celebrate(model.wordProgress.recordSaved(today: today))
            showSavedToast(verse)
        }
        try? context.save()
        model.savedVersesChanged()
    }

    private func ensureSaved(_ verse: Verse) {
        guard !saved.contains(where: { $0.ref == verse.ref }) else { return }
        context.insert(SavedVerse(verse: verse))
        try? context.save()
        model.wordProgress.signal(.board, theme: verse.theme)
        _ = model.wordProgress.recordSaved(today: today)
        model.savedVersesChanged()
    }

    private func showSavedToast(_ verse: Verse) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { savedToast = verse }
        let shown = verse.ref
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if savedToast?.ref == shown { withAnimation { savedToast = nil } }
        }
    }

    private func answer(_ choice: String, on item: FeedItem) {
        guard answers[item.id] == nil else { return }
        let right: Bool
        let quiz: WordProgress.Quiz
        if let finish = item.finish {
            right = finish.isRight(choice)
            quiz = .finish
        } else if let who = item.who {
            right = who.isRight(choice)
            quiz = .who
        } else {
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { answers[item.id] = choice }
        if right { Haptics.success() } else { Haptics.warning() }
        celebrate(model.wordProgress.recordQuiz(quiz, right: right, today: today), after: item.id)
    }

    private func keepGoing(from item: FeedItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }), index + 1 < items.count else { return }
        withAnimation(.snappy) { position = items[index + 1].id }
    }

    private func share(_ item: FeedItem) {
        if let verse = item.readableVerse {
            model.wordProgress.signal(.share, theme: verse.theme)
            shareCard = .verse(verse.rendered(in: model.settings.translation))
        }
    }

    private func listen(_ item: FeedItem) {
        if let verse = item.readableVerse { reader.toggle(verse.rendered(in: model.settings.translation)) }
    }

    private func pray(_ item: FeedItem) {
        reader.stop()
        if let verse = item.readableVerse {
            model.wordProgress.signal(.pray, theme: verse.theme)
            model.startPrayer(style: .verse, source: .manual, verse: verse.rendered(in: model.settings.translation))
        } else if let prompt = item.prompt {
            model.startPrayer(style: .quick, source: .manual, seedPrompt: prompt)
        } else if let reflection = item.reflection {
            model.startPrayer(style: .quick, source: .manual, seedPrompt: reflection.question)
        } else {
            model.startPrayer(style: .quick, source: .manual)
        }
    }
}

/// Scroll the Word's reading options: translation, text size, the meaning line, read aloud, ambient sound and
/// sharing saves with friends.
struct WordDisplaySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Picker("Translation", selection: model.binding(\.translation)) {
                    ForEach(BibleTranslation.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("word.translation")
            } header: {
                Text("Translation")
            } footer: {
                Text("Both are public domain. Your choice is used everywhere in the app.")
            }
            Section("Text size") {
                HStack(spacing: 16) {
                    Button { step(-0.1) } label: {
                        Text("A−").font(.system(.body, design: .serif, weight: .semibold)).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.settings.wordTextScale <= 0.8)
                    .accessibilityLabel("Smaller text")
                    .accessibilityIdentifier("word.textSmaller")
                    Spacer()
                    Text("\(Int((model.settings.wordTextScale * 100).rounded()))%")
                        .font(.akHeadline).monospacedDigit()
                        .accessibilityIdentifier("word.textSize")
                    Spacer()
                    Button { step(0.1) } label: {
                        Text("A+").font(.system(.title2, design: .serif, weight: .semibold)).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.settings.wordTextScale >= 1.6)
                    .accessibilityLabel("Bigger text")
                    .accessibilityIdentifier("word.textBigger")
                }
            }
            Section {
                Toggle("Show what each verse means", isOn: model.binding(\.showMeanings))
                    .accessibilityIdentifier("word.meanings")
                Toggle("Read each verse aloud", isOn: model.binding(\.readAloud))
                    .accessibilityIdentifier("word.readAloud")
            } footer: {
                Text(VerseReader.onlyCompactVoices
                     ? "Uses your iPhone’s voices. For a more natural voice, download an Enhanced English voice in Settings › Accessibility › Spoken Content › Voices."
                     : "Uses your iPhone’s own voices. Nothing leaves your phone.")
            }
            Section {
                Toggle("Ambient sound", isOn: model.binding(\.ambientSound))
                    .accessibilityIdentifier("word.ambient")
            } footer: {
                Text("A quiet, original background pad while you scroll. Follows the silent switch.")
            }
            Section {
                Toggle("Friends see verses I save", isOn: Binding(
                    get: { model.settings.shareSavesWithFriends },
                    set: { on in
                        model.updateSettings { $0.shareSavesWithFriends = on }
                        model.publishFriendProfile()
                    }))
                    .disabled(model.username == nil)
                    .accessibilityIdentifier("word.shareSaves")
            } header: {
                Text("Friends")
            } footer: {
                Text(model.username == nil
                     ? "Pick a @username in Friends first. Then friends can see “Grace saved this” on verses you both love."
                     : "Off by default. When on, your friends see which verses you saved (the reference only, like “Psalm 23:1”), and you see theirs.")
            }
        }
        .tint(Palette.gold)
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
    }

    private func step(_ delta: Double) {
        model.updateSettings { $0.wordTextScale = min(1.6, max(0.8, (($0.wordTextScale + delta) * 10).rounded() / 10)) }
        Haptics.selection()
    }
}

/// The drawn sky a card falls back to while its photo loads (and the share card uses).
enum FeedScene: CaseIterable, Hashable {
    case dawn, night, sea, hills, desert, forest, candle

    /// A verse always gets the same sky (in the feed and on its share card).
    static func `for`(_ verse: Verse) -> FeedScene {
        let skies: [FeedScene] = [.dawn, .night, .sea, .hills, .desert, .forest]
        return skies[abs(verse.day) % skies.count]
    }

    var colors: [Color] {
        switch self {
        case .dawn: return [Color(hex: 0x1B2A4A), Color(hex: 0x7A4E6E), Color(hex: 0xE9A270), Color(hex: 0xF5D58A)]
        case .night: return [Color(hex: 0x060B16), Color(hex: 0x0E1726), Color(hex: 0x1D2D49)]
        case .sea: return [Color(hex: 0x0C1E33), Color(hex: 0x15466B), Color(hex: 0x3A86A8)]
        case .hills: return [Color(hex: 0x223A5E), Color(hex: 0x5C7FA3), Color(hex: 0xC7B999)]
        case .desert: return [Color(hex: 0x2B1E3A), Color(hex: 0x8C4F5B), Color(hex: 0xE0A15E)]
        case .forest: return [Color(hex: 0x0D1C17), Color(hex: 0x1F3B2E), Color(hex: 0x4E7A5A)]
        case .candle: return [Color(hex: 0x09101C), Color(hex: 0x1A1410), Color(hex: 0x3A2614)]
        }
    }
}

/// Code-drawn backdrop for a card: gradient sky + simple silhouettes.
struct FeedBackdrop: View {
    let scene: FeedScene

    var body: some View {
        ZStack {
            LinearGradient(colors: scene.colors, startPoint: .top, endPoint: .bottom)
            Canvas { gc, size in
                let w = size.width, h = size.height
                switch scene {
                case .night, .candle:
                    var rng = SeededRNG(seed: scene == .night ? 7 : 11)
                    for _ in 0..<(scene == .night ? 90 : 0) {
                        let x = Double(rng.next() % 1000) / 1000 * w
                        let y = Double(rng.next() % 1000) / 1000 * h * 0.7
                        let r = Double(rng.next() % 100) / 100 * 1.6 + 0.4
                        gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.7)))
                    }
                    if scene == .candle {
                        let center = CGPoint(x: w / 2, y: h * 0.78)
                        gc.fill(Path(ellipseIn: CGRect(x: center.x - 160, y: center.y - 200, width: 320, height: 320)),
                                with: .radialGradient(Gradient(colors: [Palette.gold.opacity(0.35), .clear]), center: center, startRadius: 0, endRadius: 170))
                        gc.fill(Path(roundedRect: CGRect(x: center.x - 14, y: center.y, width: 28, height: 70), cornerRadius: 4),
                                with: .color(Palette.cream.opacity(0.9)))
                        var flame = Path()
                        flame.move(to: CGPoint(x: center.x, y: center.y - 34))
                        flame.addQuadCurve(to: CGPoint(x: center.x, y: center.y - 4), control: CGPoint(x: center.x + 16, y: center.y - 10))
                        flame.addQuadCurve(to: CGPoint(x: center.x, y: center.y - 34), control: CGPoint(x: center.x - 16, y: center.y - 10))
                        gc.fill(flame, with: .linearGradient(Gradient(colors: [Palette.cream, Palette.gold]), startPoint: CGPoint(x: center.x, y: center.y - 34), endPoint: CGPoint(x: center.x, y: center.y)))
                    }
                case .dawn, .desert:
                    let sun = CGPoint(x: w * 0.5, y: h * 0.72)
                    gc.fill(Path(ellipseIn: CGRect(x: sun.x - 220, y: sun.y - 220, width: 440, height: 440)),
                            with: .radialGradient(Gradient(colors: [Palette.warmGold.opacity(0.55), .clear]), center: sun, startRadius: 0, endRadius: 220))
                    gc.fill(Path(ellipseIn: CGRect(x: sun.x - 60, y: sun.y - 60, width: 120, height: 120)), with: .color(Palette.cream.opacity(0.85)))
                    gc.fill(hills(w: w, h: h, base: 0.80, amp: 0.05, phase: 0.3), with: .color(.black.opacity(0.35)))
                    gc.fill(hills(w: w, h: h, base: 0.88, amp: 0.04, phase: 1.7), with: .color(.black.opacity(0.55)))
                case .sea:
                    for i in 0..<6 {
                        let y = h * (0.68 + Double(i) * 0.055)
                        gc.fill(waves(w: w, y: y, amp: 6 + Double(i) * 2, phase: Double(i)), with: .color(.white.opacity(0.05 + Double(i) * 0.02)))
                    }
                    gc.fill(Path(ellipseIn: CGRect(x: w * 0.7, y: h * 0.12, width: 70, height: 70)), with: .color(Palette.cream.opacity(0.8)))
                case .hills, .forest:
                    gc.fill(hills(w: w, h: h, base: 0.70, amp: 0.08, phase: 0.6), with: .color(.black.opacity(0.18)))
                    gc.fill(hills(w: w, h: h, base: 0.80, amp: 0.06, phase: 2.2), with: .color(.black.opacity(0.32)))
                    gc.fill(hills(w: w, h: h, base: 0.90, amp: 0.05, phase: 4.0), with: .color(.black.opacity(0.5)))
                }
            }
            LinearGradient(colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func hills(w: Double, h: Double, base: Double, amp: Double, phase: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))
        for x in stride(from: 0.0, through: w, by: 8) {
            let y = h * base - sin(x / w * .pi * 2 + phase) * h * amp - sin(x / w * .pi * 5 + phase * 2) * h * amp * 0.3
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }

    private func waves(w: Double, y: Double, amp: Double, phase: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        for x in stride(from: 0.0, through: w, by: 6) {
            path.addLine(to: CGPoint(x: x, y: y + sin(x / 40 + phase) * amp))
        }
        path.addLine(to: CGPoint(x: w, y: y + 4))
        for x in stride(from: w, through: 0.0, by: -6) {
            path.addLine(to: CGPoint(x: x, y: y + 4 + sin(x / 40 + phase) * amp))
        }
        path.closeSubpath()
        return path
    }
}

struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 11
    }
}

/// Swipe left on a verse to pray it, without ever stealing the vertical feed's scroll: only a mostly-sideways pan
/// counts. iOS 18 uses a UIKit pan that refuses vertical starts (a SwiftUI DragGesture inside a ScrollView can block
/// scrolling there); iOS 17 uses a simultaneous DragGesture.
struct SwipeLeft: ViewModifier {
    let enabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if !enabled {
            content
        } else if #available(iOS 18.0, *) {
            content.gesture(HorizontalPan(onChanged: onChanged, onEnded: onEnded))
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { value in
                        let dx = value.translation.width, dy = value.translation.height
                        onChanged(dx < 0 && abs(dx) > abs(dy) * 1.4 ? dx : 0)
                    }
                    .onEnded { value in
                        let dx = value.translation.width, dy = value.translation.height
                        onEnded(abs(dx) > abs(dy) * 1.4 ? dx : 0)
                    }
            )
        }
    }
}

@available(iOS 18.0, *)
private struct HorizontalPan: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let dx = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed: onChanged(dx)
        case .ended: onEnded(dx)
        case .cancelled, .failed: onEnded(0)
        default: break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return velocity.x < 0 && abs(velocity.x) > abs(velocity.y) * 1.4
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
