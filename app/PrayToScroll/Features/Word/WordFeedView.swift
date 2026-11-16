import SwiftData
import SwiftUI

/// "Scroll the Word": a full-screen, swipe-up feed of verses (with a prayer prompt every few cards).
/// Topic feeds, a one-line "what this means", double-tap to save, swipe left (or "Pray this") to pray the verse,
/// Listen (read aloud), A−/A+ and WEB/KJV under "Aa", and a share card. Verses you've seen go to the back, so a new
/// session never repeats what you just read.
struct WordFeedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedVerse.savedAt, order: .reverse) private var saved: [SavedVerse]
    @State private var shareCard: ShareCardKind?
    @State private var showSaved = false
    @State private var showDisplay = false
    @State private var position: String?
    @State private var items: [FeedItem] = []
    /// nil = "For you" (every verse).
    @State private var topic: String?
    private let reader = VerseReader.shared

    var body: some View {
        let savedRefs = Set(saved.map(\.ref))
        let settings = model.settings
        ZStack(alignment: .top) {
            Palette.midnightDeep.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        FeedCard(item: item,
                                 translation: settings.translation,
                                 textScale: settings.wordTextScale,
                                 showMeaning: settings.showMeanings,
                                 isSpeaking: item.verse.map { reader.speakingDay == $0.day } ?? false,
                                 isSaved: item.verse.map { savedRefs.contains($0.ref) } ?? false,
                                 onSave: { toggleSave(item, savedRefs: savedRefs, forceOn: false) },
                                 onDoubleTap: { toggleSave(item, savedRefs: savedRefs, forceOn: true) },
                                 onShare: { share(item) },
                                 onListen: { listen(item) },
                                 onPray: { pray(item) })
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
        .onChange(of: position) { _, id in
            Haptics.selection()
            cardBecameVisible(id)
        }
        .onChange(of: topic) { _, _ in rebuild() }
        .onAppear {
            if items.isEmpty { rebuild() }
        }
        .onDisappear { reader.stop() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Scroll the Word")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.cream)
                Text("The only feed worth the swipe")
                    .font(.akCaption)
                    .foregroundStyle(Palette.cream.opacity(0.6))
            }
            Spacer()
            Button { showDisplay = true } label: {
                Text("Aa")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.cream)
                    .frame(width: 44, height: 40)
                    .background(Capsule().fill(.ultraThinMaterial))
            }
            .accessibilityLabel("Text size, translation and read aloud")
            .accessibilityIdentifier("word.display")
            Button { showSaved = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").foregroundStyle(Palette.rose)
                    Text("\(saved.count)").font(.akSubheadlineSemibold).foregroundStyle(Palette.cream).monospacedDigit()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
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

    private func rebuild() {
        reader.stop()
        let today = DayKey(Date(), calendar: .current).dayOfYear(calendar: .current)
        let ordered = WordFeedPlanner.order(verses: model.verses.verses, topic: topic, seen: model.store.wordSeen,
                                            today: model.verses.verse(forDayOfYear: today).day, seed: model.store.wordSeed)
        items = FeedItem.build(ordered: ordered, prompts: model.content.prompts.quick,
                               promptOffset: Int(model.store.wordSeed % 997) + model.store.wordSeen.count / 5)
        position = items.first?.id
        cardBecameVisible(position)
    }

    private func cardBecameVisible(_ id: String?) {
        guard let id, let item = items.first(where: { $0.id == id }) else { return }
        guard let verse = item.verse else {
            reader.stop()
            return
        }
        model.store.markVerseSeen(verse.day)
        if model.settings.readAloud {
            reader.read(verse.rendered(in: model.settings.translation))
        } else if reader.speakingDay != nil, reader.speakingDay != verse.day {
            reader.stop()
        }
    }

    private func toggleSave(_ item: FeedItem, savedRefs: Set<String>, forceOn: Bool) {
        guard let verse = item.verse?.rendered(in: model.settings.translation) else {
            if forceOn { Haptics.tap() }
            return
        }
        if savedRefs.contains(verse.ref) {
            guard !forceOn else { return }
            for entry in saved where entry.ref == verse.ref { context.delete(entry) }
            Haptics.tap()
        } else {
            context.insert(SavedVerse(verse: verse))
            Haptics.success()
        }
        try? context.save()
    }

    private func share(_ item: FeedItem) {
        if let verse = item.verse { shareCard = .verse(verse.rendered(in: model.settings.translation)) }
    }

    private func listen(_ item: FeedItem) {
        if let verse = item.verse { reader.toggle(verse.rendered(in: model.settings.translation)) }
    }

    private func pray(_ item: FeedItem) {
        reader.stop()
        if let verse = item.verse {
            model.startPrayer(style: .verse, source: .manual, verse: verse.rendered(in: model.settings.translation))
        } else if let prompt = item.prompt {
            model.startPrayer(style: .quick, source: .manual, seedPrompt: prompt)
        }
    }
}

/// Scroll the Word's reading options: translation, text size, the meaning line and read aloud.
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

/// A verse or a prayer prompt in the feed.
struct FeedItem: Identifiable, Hashable {
    let id: String
    var verse: Verse?
    var prompt: String?
    var scene: FeedScene

    /// The verses in feed order, with a prayer prompt after every 5.
    static func build(ordered verses: [Verse], prompts: [String], promptOffset: Int) -> [FeedItem] {
        let list = verses.isEmpty ? [Verse.fallback] : verses
        var items: [FeedItem] = []
        let usablePrompts = prompts.filter { !$0.contains("{name}") }
        for (offset, verse) in list.enumerated() {
            items.append(FeedItem(id: "v\(verse.day)", verse: verse, prompt: nil, scene: FeedScene.for(verse)))
            if (offset + 1) % 5 == 0, !usablePrompts.isEmpty {
                let prompt = usablePrompts[(offset / 5 + promptOffset) % usablePrompts.count]
                items.append(FeedItem(id: "p\(offset)", verse: nil, prompt: prompt, scene: .candle))
            }
        }
        return items
    }
}

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

struct FeedCard: View {
    let item: FeedItem
    var translation: BibleTranslation = .web
    var textScale: Double = 1
    var showMeaning = true
    var isSpeaking = false
    let isSaved: Bool
    let onSave: () -> Void
    let onDoubleTap: () -> Void
    let onShare: () -> Void
    var onListen: () -> Void = {}
    let onPray: () -> Void
    @State private var burst = false
    /// Swipe left to pray: how far the card has been dragged (≤ 0).
    @State private var dragX: CGFloat = 0
    @ScaledMetric(relativeTo: .title) private var verseSize: CGFloat = 30
    private static let swipeToPray: CGFloat = 90

    var body: some View {
        ZStack {
            FeedBackdrop(scene: item.scene)
            content
                .padding(.leading, 28)
                .padding(.trailing, 84)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .offset(x: dragX * 0.45)
            rail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 14)
                .padding(.bottom, 36)
            if item.verse != nil, dragX < -8 { swipeHint }
            if burst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(Palette.rose)
                    .shadow(color: Palette.rose.opacity(0.6), radius: 24)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard item.verse != nil else { return }
            onDoubleTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { burst = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.3)) { burst = false }
            }
        }
        .modifier(SwipeLeft(enabled: item.verse != nil, onChanged: dragChanged, onEnded: dragEnded))
        .accessibilityElement(children: .contain)
    }

    private func dragChanged(_ dx: CGFloat) {
        guard dx < 0 else { dragX = 0; return }
        let crossed = dragX > -Self.swipeToPray && dx <= -Self.swipeToPray
        dragX = max(dx, -160)
        if crossed { Haptics.selection() }
    }

    private func dragEnded(_ dx: CGFloat) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragX = 0 }
        if item.verse != nil, dx <= -Self.swipeToPray { onPray() }
    }

    private var swipeHint: some View {
        let ready = dragX <= -Self.swipeToPray
        return Label(ready ? "Let go to pray" : "Pray this", systemImage: "hands.and.sparkles.fill")
            .font(.akHeadline)
            .foregroundStyle(ready ? Palette.midnight : Palette.cream)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .background(Capsule().fill(ready ? AnyShapeStyle(Palette.goldButton) : AnyShapeStyle(.ultraThinMaterial)))
            .opacity(min(1, Double(-dragX) / Double(Self.swipeToPray)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 18)
            .accessibilityHidden(true)
    }

    private func verseFont(_ text: String) -> Font {
        let base = text.count > 220 ? verseSize * 0.72 : (text.count > 140 ? verseSize * 0.85 : verseSize)
        return .system(size: base * textScale, weight: .regular, design: .serif)
    }

    @ViewBuilder
    private var content: some View {
        if let base = item.verse {
            let verse = base.rendered(in: translation)
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    Chip(text: verse.themeTitle, tint: Palette.warmGold)
                    Text(verse.displayText)
                        .font(verseFont(verse.displayText))
                        .foregroundStyle(Palette.cream)
                        .lineSpacing(6)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                        .minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verse.ref)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Palette.warmGold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(verse.displayText). \(verse.ref)")
                .accessibilityValue(verse.themeTitle)
                .accessibilityAction(named: isSaved ? "Remove from saved" : "Save") { onSave() }
                .accessibilityAction(named: "Share") { onShare() }
                .accessibilityAction(named: "Listen") { onListen() }
                .accessibilityAction(named: "Pray this") { onPray() }
                if showMeaning, let meaning = verse.meaning {
                    HStack(alignment: .top, spacing: 10) {
                        Capsule().fill(Palette.warmGold.opacity(0.7)).frame(width: 3)
                        Text(meaning)
                            .font(.system(size: 17 * min(textScale, 1.3), weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.cream.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("What this means: \(meaning)")
                    .accessibilityIdentifier("word.meaning")
                }
                Text("\(verse.translationName) · swipe left to pray it")
                    .font(.akCaption)
                    .foregroundStyle(Palette.cream.opacity(0.45))
                    .accessibilityHidden(true)
            }
        } else if let prompt = item.prompt {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pause & pray").akOverline(color: Palette.warmGold)
                Text(prompt)
                    .font(.system(size: verseSize * 0.95 * textScale, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onPray) {
                    Label("Pray this now", systemImage: "hands.and.sparkles.fill")
                        .font(.akHeadline)
                        .foregroundStyle(Palette.midnight)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 50)
                        .background(Capsule().fill(Palette.goldButton))
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.bottom, 120)
        }
    }

    private var rail: some View {
        VStack(spacing: 22) {
            if item.verse != nil {
                railButton(isSaved ? "heart.fill" : "heart", label: isSaved ? "Saved" : "Save",
                           tint: isSaved ? Palette.rose : Palette.cream, action: onSave)
                    .accessibilityIdentifier("word.save")
                railButton(isSpeaking ? "stop.fill" : "speaker.wave.2.fill", label: isSpeaking ? "Stop" : "Listen",
                           tint: Palette.cream, action: onListen)
                    .accessibilityIdentifier("word.listen")
                railButton("square.and.arrow.up", label: "Share", tint: Palette.cream, action: onShare)
                railButton("hands.and.sparkles.fill", label: "Pray this", tint: Palette.warmGold, action: onPray)
                    .accessibilityIdentifier("word.pray")
            }
        }
    }

    private func railButton(_ symbol: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(.ultraThinMaterial))
                    .contentTransition(.symbolEffect(.replace))
                Text(label)
                    .font(.akCaption.weight(.semibold))
                    .foregroundStyle(Palette.cream.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 3)
            }
        }
        .buttonStyle(PressScaleStyle(scale: 0.9))
        .accessibilityLabel(label)
    }
}

/// Favorites from Scroll the Word.
struct SavedVersesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedVerse.savedAt, order: .reverse) private var saved: [SavedVerse]
    @State private var shareCard: ShareCardKind?

    var body: some View {
        ZStack {
            AppBackground()
            if saved.isEmpty {
                EmptyState(title: "No saved verses yet", message: "Double-tap a verse in Scroll the Word to keep it here.", systemImage: "heart.fill")
            } else {
                List {
                    ForEach(saved) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.text).font(.akVerse).foregroundStyle(Theme.textPrimary)
                            HStack {
                                Text(entry.ref).font(.system(.subheadline, design: .serif, weight: .semibold)).foregroundStyle(Theme.goldText)
                                Spacer()
                                Button { shareCard = .verse(entry.verse) } label: { Image(systemName: "square.and.arrow.up") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Share")
                                Button {
                                    dismiss()
                                    let verse = entry.verse
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        model.startPrayer(style: .verse, source: .manual, verse: verse)
                                    }
                                } label: { Image(systemName: "hands.and.sparkles.fill") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Pray this")
                            }
                            .foregroundStyle(Theme.goldText)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(saved[index]) }
                        try? context.save()
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Saved verses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(item: $shareCard) { kind in ShareCardSheet(kind: kind).environment(model) }
    }
}

/// Swipe left on a verse to pray it, without ever stealing the vertical feed's scroll: only a mostly-sideways pan
/// counts. iOS 18 uses a UIKit pan that refuses vertical starts (a SwiftUI DragGesture inside a ScrollView can block
/// scrolling there); iOS 17 uses a simultaneous DragGesture.
private struct SwipeLeft: ViewModifier {
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
