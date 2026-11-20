import SwiftUI

/// One lesson: 5–8 full-screen cards you swipe up through, in Scroll the Word's look (the story, why it matters,
/// the key verse, a quick check or two, the lesson in one line), then "Lesson done" with XP and the next lesson.
/// The next card shows once a quiz is answered, so the check is never skipped by accident; a wrong answer only
/// shows what the verse says. No hearts, no lives, nothing to lose.
struct LessonPlayerView: View {
    let lessonID: String
    var onClose: () -> Void
    var onNextLesson: (String) -> Void
    var onBackToPath: () -> Void
    var onPray: (String) -> Void

    private let store = LearnStore.shared
    private let library = LearnLibrary.shared
    @State private var answers: [Int: String] = [:]
    @State private var right = 0
    @State private var position: Int?
    @State private var reward: LessonReward?
    @State private var combo = 0
    @State private var burst: Int?
    @ScaledMetric(relativeTo: .title) private var bodySize: CGFloat = 27

    static let donePage = 999

    var body: some View {
        ZStack(alignment: .top) {
            Palette.midnightDeep.ignoresSafeArea()
            if let lesson = library.lesson(lessonID) {
                pager(lesson)
                topBar(lesson)
            } else {
                VStack(spacing: 16) {
                    Text("This lesson isn’t here yet.").font(.akHeadline).foregroundStyle(Palette.cream)
                    LearnButton(title: "Back", style: .glass, id: "lesson.missing", action: onClose).frame(maxWidth: 220)
                }
                .frame(maxHeight: .infinity)
            }
            if let burst {
                ComboBurst(combo: burst).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { store.progress.opened(lessonID) }
        .onChange(of: position) { _, _ in Haptics.selection() }
    }

    // MARK: Pages

    /// Cards up to (and including) the first unanswered quiz, then the done page once finished.
    private func pages(_ lesson: Lesson) -> [Int] {
        let gate = lesson.cards.indices.first { lesson.cards[$0].kind == .quiz && answers[$0] == nil }
        var list = Array(0..<((gate ?? (lesson.cards.count - 1)) + 1))
        if reward != nil { list.append(Self.donePage) }
        return list
    }

    private func pager(_ lesson: Lesson) -> some View {
        let base = Int(FeedHash.stable(lesson.id) % UInt64(FeedBackgrounds.count))
        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(pages(lesson), id: \.self) { page in
                    ZStack {
                        PhotoBackdrop(index: (base + page * 7) % FeedBackgrounds.count, scene: .candle, isCurrent: position == page)
                        Group {
                            if page == Self.donePage {
                                doneContent(lesson)
                            } else {
                                cardContent(lesson, index: page)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 70)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(page)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $position)
        .ignoresSafeArea()
        .accessibilityIdentifier("lesson.pager")
        .onAppear { if position == nil { position = 0 } }
    }

    private func topBar(_ lesson: Lesson) -> some View {
        let current = position == Self.donePage ? lesson.cards.count : min(lesson.cards.count, (position ?? 0) + 1)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                LearnCloseButton(id: "lesson.close", action: onClose)
                HStack(spacing: 4) {
                    ForEach(0..<lesson.cards.count, id: \.self) { index in
                        Capsule()
                            .fill(index < current ? AnyShapeStyle(Palette.goldButton) : AnyShapeStyle(Palette.cream.opacity(0.22)))
                            .frame(height: 5)
                    }
                }
                .animation(.snappy, value: current)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Card \(current) of \(lesson.cards.count)")
                .accessibilityIdentifier("lesson.progress")
                XPChip(xp: store.progress.xp)
            }
            Text(lesson.title)
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Palette.cream.opacity(0.75))
                .padding(.leading, 56)
                .accessibilityIdentifier("lesson.title")
        }
        .padding(.horizontal, Spacing.page)
        .padding(.top, 6)
    }

    // MARK: Cards

    @ViewBuilder
    private func cardContent(_ lesson: Lesson, index: Int) -> some View {
        let card = lesson.cards[index]
        let isLast = index == lesson.cards.count - 1
        VStack(alignment: .leading, spacing: 18) {
            switch card.kind {
            case .story:
                Text(index == 0 ? "The story" : "What happened next").akOverline(color: Palette.warmGold)
                bigText(card.text ?? "", id: "lesson.card.story")
                refLine(card.ref)
                nextButton(index)
            case .why:
                Text("Why it matters").akOverline(color: Palette.warmGold)
                bigText(card.text ?? "", id: "lesson.card.why")
                refLine(card.ref)
                nextButton(index)
            case .verse:
                Text("Key verse").akOverline(color: Palette.warmGold)
                Text(card.text ?? "")
                    .font(.system(size: bodySize * 1.08, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .lineSpacing(6)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(card.text ?? ""). \(card.ref ?? "")")
                    .accessibilityIdentifier("lesson.card.verse")
                Text(card.ref ?? "")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.warmGold)
                    .accessibilityHidden(true)
                Text("World English Bible")
                    .font(.akCaption)
                    .foregroundStyle(Palette.cream.opacity(0.5))
                    .accessibilityHidden(true)
                nextButton(index)
            case .quiz:
                if let quiz = card.quiz(id: "\(lesson.id)-q\(index)") { quizContent(quiz, index: index, isLast: isLast) }
            case .recap:
                Text("In one line").akOverline(color: Palette.warmGold)
                bigText(card.text ?? "", id: "lesson.card.recap")
                Text("A prayer to take with you")
                    .font(.akCaption.weight(.semibold))
                    .foregroundStyle(Palette.cream.opacity(0.6))
                    .padding(.top, 4)
                Text(lesson.prayer)
                    .font(.system(.body, design: .serif))
                    .italic()
                    .foregroundStyle(Palette.cream.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                if reward == nil {
                    LearnButton(title: "Finish lesson", symbol: "checkmark", id: "lesson.finish") { finish(lesson) }
                        .padding(.top, 6)
                } else {
                    nextButton(index)
                }
            }
        }
        .padding(.bottom, 40)
    }

    private func bigText(_ text: String, id: String) -> some View {
        Text(text)
            .font(.system(size: text.count > 220 ? bodySize * 0.88 : bodySize, weight: .regular, design: .serif))
            .foregroundStyle(Palette.cream)
            .lineSpacing(6)
            .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private func refLine(_ ref: String?) -> some View {
        if let ref {
            Label(ref, systemImage: "book")
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.warmGold)
        }
    }

    private func nextButton(_ index: Int) -> some View {
        Button {
            withAnimation(.snappy) { position = index + 1 < (library.lesson(lessonID)?.cards.count ?? 0) ? index + 1 : Self.donePage }
        } label: {
            Label("Next", systemImage: "chevron.down")
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Palette.cream)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(Capsule().fill(.ultraThinMaterial))
        }
        .buttonStyle(PressScaleStyle())
        .padding(.top, 4)
        .accessibilityHint("Or swipe up")
        .accessibilityIdentifier("lesson.next")
    }

    private func quizContent(_ quiz: LearnQuiz, index: Int, isLast: Bool) -> some View {
        let picked = answers[index]
        return VStack(alignment: .leading, spacing: 16) {
            Text(quiz.isTrueFalse ? "True or false?" : "Quick check").akOverline(color: Palette.warmGold)
            Text(quiz.question)
                .font(.system(size: bodySize * 0.95, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.cream)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lesson.card.quiz")
            LearnChoiceList(choices: quiz.orderedChoices, right: quiz.answer, picked: picked, idPrefix: "lesson.choice") { choice in
                answer(choice, quiz: quiz, index: index)
            }
            if let picked {
                let isRight = quiz.isRight(picked)
                LearnAnswerNote(right: isRight, line: isRight ? LearnCopy.rightLine(index) : LearnCopy.notQuiteLine(index),
                                explain: quiz.explain, ref: quiz.ref, id: "lesson.result")
                nextButton(index)
            }
        }
    }

    // MARK: Actions

    private func answer(_ choice: String, quiz: LearnQuiz, index: Int) {
        guard answers[index] == nil else { return }
        let isRight = quiz.isRight(choice)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { answers[index] = choice }
        if isRight { right += 1 }
        store.progress.answered(quiz.id, right: isRight)
        combo = QuizCombo.next(combo, right: isRight)
        store.progress.noteCombo(combo)
        if QuizCombo.bursts(combo) {
            QuizCombo.celebrate()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { burst = combo }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { withAnimation(.easeOut(duration: 0.3)) { burst = nil } }
        } else if isRight {
            Haptics.success()
        } else {
            Haptics.warning()
        }
    }

    private func finish(_ lesson: Lesson) {
        guard reward == nil else { return }
        let path = library.locate(lesson.id)?.path
        // A finished lesson earns XP, not a prayer day: the streak counts prayers (and verse/devotional unlocks).
        // The lesson ends on "Pray about it", which counts through the normal prayer flow.
        let earned = store.progress.complete(lesson, in: path, right: right, today: .today())
        Haptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { reward = earned }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.snappy) { position = Self.donePage }
        }
    }

    // MARK: Done

    @ViewBuilder
    private func doneContent(_ lesson: Lesson) -> some View {
        if let reward {
            let place = library.locate(lesson.id)
            let next = place.flatMap { $0.index + 1 < $0.path.lessons.count ? $0.path.lessons[$0.index + 1] : nil }
            LessonDoneContent(lesson: lesson, reward: reward, right: right, quizzes: lesson.quizzes.count,
                              pathTitle: place?.path.title ?? "", done: place.map { store.progress.doneCount(in: $0.path) } ?? 0,
                              total: place?.path.lessons.count ?? 0, next: next,
                              onNext: { if let next { onNextLesson(next.id) } },
                              onPray: { onPray(lesson.prayer) },
                              onBack: onBackToPath)
        }
    }
}

/// "Lesson done": the seal, the XP, where you are on the path, then the next lesson, a prayer, or back to the map.
struct LessonDoneContent: View {
    let lesson: Lesson
    let reward: LessonReward
    let right: Int
    let quizzes: Int
    let pathTitle: String
    let done: Int
    let total: Int
    let next: Lesson?
    var onNext: () -> Void
    var onPray: () -> Void
    var onBack: () -> Void
    @State private var glow = false
    @State private var shownXP = 0

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Palette.gold.opacity(glow ? 0.28 : 0.12)).frame(width: 170, height: 170).blur(radius: 18)
                Image(systemName: done >= total && total > 0 ? "crown.fill" : "checkmark.seal.fill")
                    .font(.system(size: 92, weight: .semibold))
                    .foregroundStyle(Palette.goldGradient)
                    .scaleEffect(glow ? 1.05 : 0.95)
            }
            .accessibilityHidden(true)
            Text(done >= total && total > 0 ? "Path complete" : "Lesson done")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(Palette.cream)
                .accessibilityIdentifier("lesson.done")
            Text("+\(shownXP) XP")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.warmGold)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("Plus \(reward.xp) XP")
                .accessibilityIdentifier("lesson.xp")
            Text(LearnCopy.lessonDoneLine(firstTime: reward.firstTime, right: right, quizzes: quizzes))
                .font(.akCallout)
                .foregroundStyle(Palette.cream.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if total > 0 {
                VStack(spacing: 6) {
                    ProgressView(value: Double(done), total: Double(total)).tint(Palette.gold)
                    Text("\(done) of \(total) in \(pathTitle)")
                        .font(.akFootnote)
                        .foregroundStyle(Palette.cream.opacity(0.7))
                }
                .frame(maxWidth: 260)
                .accessibilityElement(children: .combine)
            }
            VStack(spacing: 10) {
                if let next {
                    LearnButton(title: "Next: \(next.title)", symbol: "play.fill", id: "lesson.nextLesson", action: onNext)
                }
                LearnButton(title: "Pray about it", symbol: "hands.and.sparkles.fill", style: next == nil ? .gold : .glass,
                            id: "lesson.pray", action: onPray)
                Button("Back to the path", action: onBack)
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.cream.opacity(0.85))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("lesson.backToPath")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if !MotionPolicy.off {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) { shownXP = reward.xp }
        }
    }
}
