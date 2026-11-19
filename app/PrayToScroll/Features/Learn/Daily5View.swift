import SwiftUI

extension Daily5.Pools {
    /// Every bundled question, sorted, built once.
    static let shared = Daily5.Pools(library: .shared, scroll: .shared)
}

/// The Daily 5: five questions, one at a time; every answer shows what the verse says. Then a spoiler-free grid to
/// share ("Pray to Scroll Daily 5 #12 🟩🟩⬜🟩🟩 4/5"), the gentle run count, and unlimited practice.
struct Daily5View: View {
    enum Mode: Hashable { case today, practice }

    var mode: Mode = .today
    var onClose: () -> Void
    var onPractice: () -> Void

    private let store = LearnStore.shared
    @State private var questions: [Daily5Question] = []
    @State private var index = 0
    @State private var picks: [String?] = []
    @State private var finished: [Bool]?
    @State private var combo = 0
    @State private var burst: Int?
    @State private var showShare = false
    @State private var practiceRound = 0
    @ScaledMetric(relativeTo: .title) private var promptSize: CGFloat = 28

    private var today: DayKey { .today() }
    private var number: Int { Daily5.number(for: today) }

    var body: some View {
        ZStack(alignment: .top) {
            PhotoBackdrop(index: (number * 11 + (mode == .practice ? 5 + practiceRound : 0)) % FeedBackgrounds.count,
                          scene: .night, isCurrent: true)
            Group {
                if let finished {
                    result(finished)
                } else if index < questions.count {
                    question(questions[index])
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 76)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            topBar
            if let burst { ComboBurst(combo: burst).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .background(Palette.midnightDeep.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: start)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [shareText]).presentationDetents([.medium, .large])
        }
    }

    private func start() {
        guard questions.isEmpty else { return }
        switch mode {
        case .today:
            if let done = store.progress.dailyResult(on: today) {
                finished = done.marks
                questions = Daily5.questions(for: today, pools: .shared)
                picks = Array(repeating: nil, count: questions.count)
            } else {
                questions = Daily5.questions(for: today, pools: .shared)
                picks = Array(repeating: nil, count: questions.count)
            }
        case .practice:
            newPracticeRound()
        }
    }

    private func newPracticeRound() {
        let todays = Set(Daily5.questions(for: today, pools: .shared).map(\.id))
        let avoid = store.progress.dailyResult(on: today) == nil ? todays : []
        questions = Daily5.practice(pools: .shared, missed: store.progress.missed, avoiding: avoid,
                                    seed: UInt64.random(in: 1...UInt64.max))
        picks = Array(repeating: nil, count: questions.count)
        index = 0
        finished = nil
        combo = 0
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            LearnCloseButton(id: "daily5.close", action: onClose)
            HStack(spacing: 6) {
                ForEach(0..<max(questions.count, Daily5.count), id: \.self) { slot in
                    square(slot)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Question \(min(index + 1, Daily5.count)) of \(Daily5.count)")
            Spacer(minLength: 4)
            Text(mode == .today ? "#\(number)" : "Practice")
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Palette.warmGold)
                .accessibilityIdentifier("daily5.number")
        }
        .padding(.horizontal, Spacing.page)
        .padding(.top, 6)
    }

    private func square(_ slot: Int) -> some View {
        let mark: Bool? = finished.map { slot < $0.count ? $0[slot] : false }
            ?? (slot < picks.count ? picks[slot].map { questions[slot].isRight($0) } : nil)
        let current = finished == nil && slot == index
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(mark == true ? AnyShapeStyle(Color(hex: 0x6FBF73)) : (mark == false ? AnyShapeStyle(Palette.cream.opacity(0.85)) : AnyShapeStyle(Color.clear)))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(current ? Palette.gold : Palette.cream.opacity(0.4), lineWidth: current ? 2.5 : 1.5))
            .frame(width: 26, height: 26)
            .animation(.snappy, value: mark)
    }

    // MARK: Question

    private func question(_ q: Daily5Question) -> some View {
        let picked = index < picks.count ? picks[index] : nil
        return VStack(alignment: .leading, spacing: 16) {
            Text(q.overline).akOverline(color: q.kind == .whoSaid ? LearnPalette.redLetter : Palette.warmGold)
            if let quote = q.quote {
                Text("\u{201C}\(quote)\u{201D}")
                    .font(.system(size: promptSize, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .lineSpacing(5)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("daily5.prompt")
            } else {
                Text(q.prompt)
                    .font(.system(size: promptSize, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .lineSpacing(4)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(q.prompt.replacingOccurrences(of: FinishVerse.blank, with: "blank"))
                    .accessibilityIdentifier("daily5.prompt")
            }
            if q.kind == .finish || q.kind == .whoSaid {
                Text(q.ref)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Palette.warmGold)
                    .opacity(q.kind == .finish ? 1 : (picked == nil ? 0 : 1))
                    .accessibilityHidden(q.kind == .whoSaid && picked == nil)
            }
            LearnChoiceList(choices: q.choices, right: q.answer, picked: picked, idPrefix: "daily5.choice") { choice in
                pick(choice, for: q)
            }
            if let picked {
                let right = q.isRight(picked)
                LearnAnswerNote(right: right, line: right ? LearnCopy.rightLine(index) : LearnCopy.notQuiteLine(index),
                                explain: q.kind == .whoSaid ? "" : q.explain, ref: q.kind == .whoSaid ? q.explain : q.ref,
                                id: "daily5.result")
                LearnButton(title: index + 1 < questions.count ? "Next question" : "See my score",
                            symbol: index + 1 < questions.count ? "arrow.right" : "square.grid.3x3.fill",
                            id: "daily5.next", action: advance)
            }
        }
        .id(q.id)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        .padding(.bottom, 30)
    }

    private func pick(_ choice: String, for q: Daily5Question) {
        guard index < picks.count, picks[index] == nil else { return }
        let right = q.isRight(choice)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { picks[index] = choice }
        store.progress.answered(q.id, right: right)
        if mode == .practice, right { store.progress.xp += 1 }
        combo = QuizCombo.next(combo, right: right)
        store.progress.noteCombo(combo)
        if QuizCombo.bursts(combo) {
            QuizCombo.celebrate()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { burst = combo }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { withAnimation(.easeOut(duration: 0.3)) { burst = nil } }
        } else if right {
            Haptics.success()
        } else {
            Haptics.warning()
        }
    }

    private func advance() {
        Haptics.tap()
        if index + 1 < questions.count {
            withAnimation(.snappy) { index += 1 }
            return
        }
        let marks = zip(questions, picks).map { q, p in p.map { q.isRight($0) } ?? false }
        if mode == .today { store.progress.recordDaily(marks, number: number, on: today) }
        Haptics.success()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { finished = marks }
    }

    // MARK: Result

    private var marks: [Bool] { finished ?? [] }

    private var streak: Int { store.progress.dailyStreak(today: today) }

    private var shareText: String {
        Daily5.shareText(number: number, marks: marks, streak: streak, link: AppLinks.shareURL.absoluteString)
    }

    private func result(_ marks: [Bool]) -> some View {
        let right = marks.filter { $0 }.count
        return VStack(alignment: .leading, spacing: 18) {
            Text(mode == .today ? "Daily 5 · #\(number)" : "Practice round").akOverline(color: Palette.warmGold)
            Text(Daily5.grid(marks))
                .font(.system(size: 44))
                .accessibilityLabel("\(right) of \(marks.count) right")
                .accessibilityIdentifier("daily5.grid")
            Text("\(right)/\(marks.count)")
                .font(.system(size: 56, weight: .bold, design: .serif))
                .foregroundStyle(Palette.cream)
                .accessibilityIdentifier("daily5.score")
            Text(LearnCopy.dailyScoreLine(right: right, of: marks.count))
                .font(.akCallout)
                .foregroundStyle(Palette.cream.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            if mode == .today {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").foregroundStyle(Palette.flameGradient)
                    Text(LearnCopy.dailyStreakLine(streak, graced: store.progress.dailyGraceUsed(today: today)))
                        .font(.akSubheadlineSemibold)
                        .foregroundStyle(Palette.cream)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("daily5.streak")
                LearnButton(title: "Share my score", symbol: "square.and.arrow.up", id: "daily5.share") { showShare = true }
                LearnButton(title: "Practice more", symbol: "arrow.clockwise", style: .glass, id: "daily5.practice", action: onPractice)
                Text("A new Daily 5 every day at midnight. Same five for everyone.")
                    .font(.akCaption)
                    .foregroundStyle(Palette.cream.opacity(0.6))
            } else {
                LearnButton(title: "Another round", symbol: "arrow.clockwise", id: "daily5.again") {
                    practiceRound += 1
                    withAnimation(.snappy) { newPracticeRound() }
                }
                LearnButton(title: "Done", style: .glass, id: "daily5.done", action: onClose)
            }
        }
        .padding(.bottom, 30)
    }
}
