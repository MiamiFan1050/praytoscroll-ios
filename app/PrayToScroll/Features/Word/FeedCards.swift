import SwiftUI

/// What a card can ask the feed to do.
struct FeedCardActions {
    var save: () -> Void = {}
    var doubleTap: () -> Void = {}
    var share: () -> Void = {}
    var listen: () -> Void = {}
    var pray: () -> Void = {}
    var send: () -> Void = {}
    var boards: () -> Void = {}
    var answer: (String) -> Void = { _ in }
    var keepGoing: () -> Void = {}
}

/// One full-screen card: a photo backdrop with a slow drift, the card's content, and (on verse cards) the rail of
/// Save / Listen / Share / Pray this. Double-tap a verse to heart it; swipe left to pray it.
struct FeedCard: View {
    let item: FeedItem
    var isCurrent = false
    var translation: BibleTranslation = .web
    var textScale: Double = 1
    var showMeaning = true
    var isSpeaking = false
    var isSaved = false
    /// "Grace and 2 friends saved this".
    var friendsLine: String?
    /// The choice picked on a quiz card (kept by the feed, so it survives scrolling away and back).
    var answer: String?
    var actions = FeedCardActions()
    @State private var burst = false
    @State private var factOpen = false
    /// A long press on the heart opens the boards; the tap that ends it mustn't also toggle the save.
    @State private var heldHeart = false
    /// Swipe left to pray: how far the card has been dragged (≤ 0).
    @State private var dragX: CGFloat = 0
    @ScaledMetric(relativeTo: .title) private var verseSize: CGFloat = 30
    private static let swipeToPray: CGFloat = 90

    private var verse: Verse? { item.readableVerse?.rendered(in: translation) }

    var body: some View {
        ZStack {
            PhotoBackdrop(index: item.background, scene: item.scene, isCurrent: isCurrent)
            content
                .padding(.leading, 28)
                .padding(.trailing, verse == nil ? 28 : 84)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .offset(x: dragX * 0.45)
            if verse != nil {
                rail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 14)
                    .padding(.bottom, 36)
            }
            if verse != nil, dragX < -8 { swipeHint }
            if burst { HeartBurst() }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard verse != nil else { return }
            actions.doubleTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { burst = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.3)) { burst = false }
            }
        }
        .modifier(SwipeLeft(enabled: verse != nil, onChanged: dragChanged, onEnded: dragEnded))
        .accessibilityElement(children: .contain)
    }

    // MARK: Content by kind

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .verse, .send:
            if let verse { verseContent(verse, sending: item.kind == .send) }
        case .meaning:
            if let verse {
                if showMeaning, verse.meaning != nil { meaningContent(verse) } else { verseContent(verse, sending: false) }
            }
        case .pray:
            if let prompt = item.prompt { prayContent(prompt) }
        case .reflect:
            if let reflection = item.reflection { reflectContent(reflection) }
        case .finish:
            if let finish = item.finish { finishContent(finish) }
        case .whoSaid:
            if let who = item.who { whoContent(who) }
        case .fact:
            if let fact = item.fact { factContent(fact) }
        case .milestone:
            if let milestone = item.milestone {
                MilestoneCardContent(milestone: milestone, isCurrent: isCurrent, onPray: actions.pray, onKeepGoing: actions.keepGoing)
            }
        }
    }

    private func verseFont(_ text: String) -> Font {
        let base = text.count > 220 ? verseSize * 0.72 : (text.count > 140 ? verseSize * 0.85 : verseSize)
        return .system(size: base * textScale, weight: .regular, design: .serif)
    }

    /// The verse, its reference and topic as one accessibility element ("<text>. <ref>", value = topic).
    private func verseBlock(_ verse: Verse, font: Font, color: Color = Palette.cream) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(verse.displayText)
                .font(font)
                .foregroundStyle(color)
                .lineSpacing(6)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text(verse.ref)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.warmGold)
                .shadow(color: .black.opacity(0.4), radius: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(verse.displayText). \(verse.ref)")
        .accessibilityValue(verse.themeTitle)
        .accessibilityAction(named: isSaved ? "Remove from saved" : "Save") { actions.save() }
        .accessibilityAction(named: "Share") { actions.share() }
        .accessibilityAction(named: "Listen") { actions.listen() }
        .accessibilityAction(named: "Pray this") { actions.pray() }
    }

    private func verseContent(_ verse: Verse, sending: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if sending {
                Text("Who needs this today?").akOverline(color: Palette.warmGold)
            } else {
                Chip(text: verse.themeTitle, tint: Palette.warmGold)
            }
            verseBlock(verse, font: verseFont(verse.displayText))
            if let friendsLine { friendsSaved(friendsLine) }
            if sending {
                Button(action: actions.send) {
                    Label("Send to someone", systemImage: "paperplane.fill")
                        .font(.akHeadline)
                        .foregroundStyle(Palette.midnight)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 50)
                        .background(Capsule().fill(Palette.goldButton))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("word.send")
            } else if showMeaning, let meaning = verse.meaning {
                HStack(alignment: .top, spacing: 10) {
                    Capsule().fill(Palette.warmGold.opacity(0.7)).frame(width: 3)
                    Text(meaning)
                        .font(.system(size: 17 * min(textScale, 1.3), weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.cream.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("What this means: \(meaning)")
                .accessibilityIdentifier("word.meaning")
            }
            Text("\(verse.translationName) · swipe left to pray it")
                .font(.akCaption)
                .foregroundStyle(Palette.cream.opacity(0.5))
                .accessibilityHidden(true)
        }
    }

    /// "What this means" first, big; the verse under it.
    private func meaningContent(_ verse: Verse) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What this means").akOverline(color: Palette.warmGold)
            Text(verse.meaning ?? "")
                .font(.system(size: verseSize * 0.95 * textScale, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.cream)
                .lineSpacing(5)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("What this means: \(verse.meaning ?? "")")
                .accessibilityIdentifier("word.meaningCard")
            Capsule().fill(Palette.warmGold.opacity(0.6)).frame(width: 44, height: 3)
            verseBlock(verse, font: .system(size: 19 * textScale, weight: .regular, design: .serif), color: Palette.cream.opacity(0.85))
            if let friendsLine { friendsSaved(friendsLine) }
        }
    }

    private func friendsSaved(_ line: String) -> some View {
        Label(line, systemImage: "heart.fill")
            .font(.akFootnote.weight(.semibold))
            .foregroundStyle(Palette.cream.opacity(0.9))
            .labelStyle(TintedIconLabelStyle(tint: Palette.rose))
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(Capsule().fill(.ultraThinMaterial))
            .accessibilityIdentifier("word.friendsSaved")
    }

    private func prayContent(_ prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Pause & pray").akOverline(color: Palette.warmGold)
            Text(prompt)
                .font(.system(size: verseSize * 0.95 * textScale, weight: .regular, design: .serif))
                .foregroundStyle(Palette.cream)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("word.prompt")
            goldButton("Pray this now", symbol: "hands.and.sparkles.fill", id: "word.prayPrompt", action: actions.pray)
        }
        .padding(.bottom, 80)
    }

    private func reflectContent(_ reflection: Reflection) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sit with this").akOverline(color: Palette.warmGold)
            Text(reflection.question)
                .font(.system(size: verseSize * 1.0 * textScale, weight: .regular, design: .serif))
                .foregroundStyle(Palette.cream)
                .lineSpacing(6)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("word.reflect")
            Chip(text: WordFeedPlanner.title(for: reflection.theme), tint: Palette.warmGold)
            Text("Take a breath. There's no wrong answer.")
                .font(.akFootnote)
                .foregroundStyle(Palette.cream.opacity(0.7))
            goldButton("Pray about it", symbol: "hands.and.sparkles.fill", id: "word.reflect.pray", action: actions.pray)
        }
        .padding(.bottom, 60)
    }

    // MARK: Quizzes

    private func finishContent(_ finish: FinishVerse) -> some View {
        let revealed = answer != nil
        return VStack(alignment: .leading, spacing: 18) {
            Text("Finish the verse").akOverline(color: Palette.warmGold)
            Text(revealed ? finish.text : finish.prompt)
                .font(verseFont(finish.text))
                .foregroundStyle(Palette.cream)
                .lineSpacing(6)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityLabel(revealed ? finish.text : "Finish the verse: " + finish.prompt.replacingOccurrences(of: FinishVerse.blank, with: "blank"))
                .accessibilityIdentifier(revealed ? "word.finish.full" : "word.finish")
            Text(finish.ref)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.warmGold)
            choiceList(finish.choices(seed: 0), id: "word.finish.choice", right: finish.answer)
            if let answer {
                resultLine(finish.isRight(answer) ? "Right! You know this one." : "Not quite. Now you'll remember it.",
                           right: finish.isRight(answer), id: "word.finish.result")
            }
        }
    }

    private func whoContent(_ who: WhoSaidQuiz) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Who said it?").akOverline(color: Palette.warmGold)
            Text("\u{201C}\(who.quote)\u{201D}")
                .font(verseFont(who.quote))
                .foregroundStyle(Palette.cream)
                .lineSpacing(6)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Who said it? \(who.quote)")
                .accessibilityIdentifier("word.who")
            choiceList(who.shuffledChoices(seed: 0), id: "word.who.choice", right: who.speaker)
            if let answer {
                resultLine(who.isRight(answer) ? "Right! \(who.speaker), \(who.ref)." : "It was \(who.speaker), \(who.ref).",
                           right: who.isRight(answer), id: "word.who.result")
            }
        }
    }

    private func choiceList(_ choices: [String], id: String, right: String) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                let picked = answer == choice
                let isRight = choice == right
                let revealed = answer != nil
                Button {
                    guard answer == nil else { return }
                    actions.answer(choice)
                } label: {
                    HStack {
                        Text(choice)
                            .font(.akHeadline)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if revealed && isRight { Image(systemName: "checkmark.circle.fill") }
                        if revealed && picked && !isRight { Image(systemName: "xmark.circle.fill") }
                    }
                    .foregroundStyle(revealed && isRight ? Palette.midnight : Palette.cream)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        if revealed && isRight {
                            Capsule().fill(Palette.goldButton)
                        } else if revealed && picked {
                            Capsule().fill(Palette.rose.opacity(0.35))
                        } else {
                            Capsule().fill(.ultraThinMaterial)
                        }
                    }
                    .opacity(revealed && !isRight && !picked ? 0.55 : 1)
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))
                .accessibilityLabel(choice)
                .accessibilityValue(revealed ? (isRight ? "Right answer" : (picked ? "Your pick" : "")) : "")
                .accessibilityIdentifier("\(id).\(index)")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: answer)
    }

    private func resultLine(_ text: String, right: Bool, id: String) -> some View {
        Label(text, systemImage: right ? "sparkles" : "book.fill")
            .font(.akSubheadlineSemibold)
            .foregroundStyle(right ? Palette.warmGold : Palette.cream)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .accessibilityIdentifier(id)
    }

    private func factContent(_ fact: BibleFact) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Bible fact").akOverline(color: Palette.warmGold)
            Text(fact.text)
                .font(.system(size: verseSize * 0.95 * textScale, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.cream)
                .lineSpacing(5)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("word.fact")
            Button {
                withAnimation(.snappy) { factOpen.toggle() }
            } label: {
                Label(fact.ref, systemImage: factOpen ? "chevron.up" : "book")
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.warmGold)
                    .frame(minHeight: 44)
            }
            .accessibilityHint(factOpen ? "Hides the verse" : "Shows the verse")
            .accessibilityIdentifier("word.fact.read")
            if factOpen, let text = fact.verseText {
                Text(text)
                    .font(.system(size: 18 * textScale, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.cream.opacity(0.88))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .accessibilityIdentifier("word.fact.verse")
            }
        }
    }

    private func goldButton(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.akHeadline)
                .foregroundStyle(Palette.midnight)
                .padding(.horizontal, 22)
                .frame(minHeight: 50)
                .background(Capsule().fill(Palette.goldButton))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier(id)
    }

    // MARK: Rail + swipe

    private var rail: some View {
        VStack(spacing: 22) {
            railButton(isSaved ? "heart.fill" : "heart", label: isSaved ? "Saved" : "Save",
                       tint: isSaved ? Palette.rose : Palette.cream) {
                if heldHeart { heldHeart = false } else { actions.save() }
            }
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    heldHeart = true
                    actions.boards()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { heldHeart = false }
                })
                .accessibilityAction(named: "Save to a board") { actions.boards() }
                .accessibilityIdentifier("word.save")
            railButton(isSpeaking ? "stop.fill" : "speaker.wave.2.fill", label: isSpeaking ? "Stop" : "Listen",
                       tint: Palette.cream, action: actions.listen)
                .accessibilityIdentifier("word.listen")
            railButton("square.and.arrow.up", label: "Share", tint: Palette.cream, action: actions.share)
            railButton("hands.and.sparkles.fill", label: "Pray this", tint: Palette.warmGold, action: actions.pray)
                .accessibilityIdentifier("word.pray")
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

    private func dragChanged(_ dx: CGFloat) {
        guard dx < 0 else { dragX = 0; return }
        let crossed = dragX > -Self.swipeToPray && dx <= -Self.swipeToPray
        dragX = max(dx, -160)
        if crossed { Haptics.selection() }
    }

    private func dragEnded(_ dx: CGFloat) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragX = 0 }
        if verse != nil, dx <= -Self.swipeToPray { actions.pray() }
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
}

/// The double-tap heart: a big heart that pops, with a ring of small ones flying out.
struct HeartBurst: View {
    @State private var fly = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(index.isMultiple(of: 2) ? Palette.rose : Palette.warmGold)
                    .offset(x: fly ? cos(angle) * 120 : 0, y: fly ? sin(angle) * 120 : 0)
                    .opacity(fly ? 0 : 1)
                    .scaleEffect(fly ? 0.6 : 1)
            }
            Image(systemName: "heart.fill")
                .font(.system(size: 110))
                .foregroundStyle(Palette.rose)
                .shadow(color: Palette.rose.opacity(0.6), radius: 24)
        }
        .transition(.scale(scale: 0.3).combined(with: .opacity))
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { fly = true } }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Goal met, a new level or a badge. The goal card is the healthy stopping point: pray, or keep going, no pressure.
struct MilestoneCardContent: View {
    let milestone: FeedMilestone
    var isCurrent = true
    var onPray: () -> Void
    var onKeepGoing: () -> Void
    @State private var glow = false

    var body: some View {
        VStack(alignment: .center, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(Palette.goldGradient)
                .shadow(color: Palette.gold.opacity(glow ? 0.8 : 0.3), radius: glow ? 30 : 12)
                .scaleEffect(glow ? 1.06 : 0.96)
                .onAppear {
                    if isCurrent { Haptics.success() }
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
                }
                .onChange(of: isCurrent) { _, now in if now { Haptics.success() } }
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(Palette.cream)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("word.milestone")
            Text(detail)
                .font(.akCallout)
                .foregroundStyle(Palette.cream.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 12) {
                if case .goalDone = milestone {
                    Button(action: onPray) {
                        Label("Pray now", systemImage: "hands.and.sparkles.fill")
                            .font(.akHeadline)
                            .foregroundStyle(Palette.midnight)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Capsule().fill(Palette.goldButton))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityIdentifier("word.milestone.pray")
                }
                Button(action: onKeepGoing) {
                    Text("Keep going")
                        .font(.akHeadline)
                        .foregroundStyle(Palette.cream)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Capsule().fill(.ultraThinMaterial))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("word.milestone.keepGoing")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var symbol: String {
        switch milestone {
        case .goalDone: return "checkmark.seal.fill"
        case .levelUp: return "leaf.fill"
        case .badge(let badge): return badge.symbol
        }
    }

    var title: String { WordMilestoneCopy.title(milestone) }
    var detail: String { WordMilestoneCopy.detail(milestone) }
}

/// The words on celebration cards. Encouraging, never shaming (unit-tested).
enum WordMilestoneCopy {
    static func title(_ milestone: FeedMilestone) -> String {
        switch milestone {
        case .goalDone: return "Goal done 🙏"
        case .levelUp(let number, let name): return "Level \(number): \(name)"
        case .badge(let badge): return badge.title
        }
    }

    static func detail(_ milestone: FeedMilestone) -> String {
        switch milestone {
        case .goalDone(let goal, let streak):
            let days = streak >= 2 ? " That's \(streak) days in a row." : ""
            return "You read \(goal) verses today.\(days) Keep going if you're enjoying it, or take it to God in prayer."
        case .levelUp(_, let name):
            return "You've grown into a \(name.lowercased()). Every verse you read takes root."
        case .badge(let badge):
            return badge.detail
        }
    }
}

/// A label whose icon has its own color.
struct TintedIconLabelStyle: LabelStyle {
    var tint: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(tint)
            configuration.title
        }
    }
}
