import SwiftUI

/// Where Learn opens: the path map, a lesson, or today's Daily 5.
enum LearnStart: Hashable, Identifiable {
    case hub, lesson(String), daily5

    var id: String {
        switch self {
        case .hub: return "hub"
        case .lesson(let id): return "lesson-\(id)"
        case .daily5: return "daily5"
        }
    }

    var routes: [LearnRoute] {
        switch self {
        case .hub: return []
        case .lesson(let id): return [.lesson(id)]
        case .daily5: return [.daily5]
        }
    }
}

enum LearnRoute: Hashable { case lesson(String), daily5, practice }

/// Learn, full screen: the path map with lessons and the Daily 5 pushed on top. Presented from Scroll the Word
/// (and the Home card). Ending a lesson with "Pray about it" closes Learn and starts the prayer.
struct LearnRootView: View {
    let start: LearnStart
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var path: [LearnRoute]

    init(start: LearnStart) {
        self.start = start
        _path = State(initialValue: start.routes)
    }

    var body: some View {
        NavigationStack(path: $path) {
            LearnHubView(open: { path.append($0) }, close: { dismiss() })
                .navigationDestination(for: LearnRoute.self) { route in destination(route) }
        }
        .environment(\.colorScheme, .dark)
        .onAppear { LearnStore.shared.reload() }
    }

    @ViewBuilder
    private func destination(_ route: LearnRoute) -> some View {
        switch route {
        case .lesson(let id):
            LessonPlayerView(lessonID: id,
                             onClose: close,
                             onNextLesson: { next in
                                 if path.isEmpty { path = [.lesson(next)] } else { path[path.count - 1] = .lesson(next) }
                             },
                             onBackToPath: { path = [] },
                             onPray: pray)
                .id(id)
        case .daily5:
            Daily5View(mode: .today, onClose: close, onPractice: { path.append(.practice) })
        case .practice:
            Daily5View(mode: .practice, onClose: close, onPractice: {})
        }
    }

    /// Back one screen; opened straight into a lesson or the Daily 5 (from the feed), closing goes back to the feed.
    private func close() {
        if start != .hub, path.count <= 1 {
            dismiss()
        } else if !path.isEmpty {
            path.removeLast()
        } else {
            dismiss()
        }
    }

    private func pray(_ prompt: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            model.startPrayer(style: .quick, source: .manual, seedPrompt: prompt)
        }
    }
}

/// The Learn home: XP, today's Daily 5, the three paths and a Duolingo-style map of the chosen one. Every path is
/// open from day one; inside a path, finishing a lesson opens the next. No hearts, no lives, no timers.
struct LearnHubView: View {
    var open: (LearnRoute) -> Void
    var close: () -> Void

    private let store = LearnStore.shared
    private let library = LearnLibrary.shared
    @State private var pathID: String?
    @State private var note: String?

    private var today: DayKey { .today() }

    private var selected: LearnPath? {
        let id = pathID ?? store.progress.continueLesson(in: library).flatMap { library.locate($0.id)?.path.id }
        return library.path(id ?? "") ?? library.paths.first
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        daily5Card
                        pathPicker
                        if let selected {
                            pathHeader(selected)
                            LearnPathMap(path: selected, progress: store.progress) { index in
                                tapped(selected, index: index)
                            }
                        } else {
                            Text("Lessons are on their way.").font(.akHeadline).foregroundStyle(Theme.textSecondary)
                        }
                        Text("Your progress stays on this iPhone.")
                            .font(.akCaption)
                            .foregroundStyle(Palette.cream.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 30)
                    }
                    .padding(.horizontal, Spacing.page)
                    .padding(.top, 8)
                }
                .onAppear {
                    if let next = selected.flatMap({ store.progress.nextIndex(in: $0) }), next > 2 {
                        DispatchQueue.main.async { proxy.scrollTo("node-\(next)", anchor: .center) }
                    }
                }
            }
            if let note {
                Text(note)
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .padding(.horizontal, Spacing.page)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("learn.note")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Learn")
                    .font(.akLargeTitle)
                    .foregroundStyle(Palette.cream)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("learn.title")
                Text("Bite-size lessons through the Bible")
                    .font(.akFootnote)
                    .foregroundStyle(Palette.cream.opacity(0.7))
            }
            Spacer(minLength: 8)
            XPChip(xp: store.progress.xp)
                .accessibilityIdentifier("learn.xp")
            LearnCloseButton(id: "learn.close", action: close)
        }
    }

    // MARK: Daily 5

    private var daily5Card: some View {
        let result = store.progress.dailyResult(on: today)
        let number = Daily5.number(for: today)
        let streak = store.progress.dailyStreak(today: today)
        return Button {
            Haptics.tap()
            open(.daily5)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily 5 · #\(number)").akOverline(color: Palette.warmGold)
                    Text(result == nil ? "Five questions. The same five for everyone today." : "\(result!.right) of 5 today")
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(Palette.cream)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        if let result {
                            Text(Daily5.grid(result.marks)).font(.system(size: 18))
                        } else {
                            ForEach(0..<Daily5.count, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.cream.opacity(0.5), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        if streak > 0 {
                            Label("\(streak)", systemImage: "flame.fill")
                                .font(.akSubheadlineSemibold)
                                .foregroundStyle(Palette.cream)
                                .labelStyle(TintedIconLabelStyle(tint: Palette.ember))
                                .padding(.leading, 6)
                        }
                    }
                }
                Spacer(minLength: 4)
                Text(result == nil ? "Play" : "Share")
                    .font(.akHeadline)
                    .foregroundStyle(Palette.midnight)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Palette.goldButton))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.gold.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(result == nil ? "Daily 5 number \(number). Five questions, the same for everyone today. Play."
                            : "Daily 5 number \(number). \(result!.right) of 5 today. Share.")
        .accessibilityIdentifier("learn.daily5")
    }

    // MARK: Paths

    private var pathPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(library.paths) { path in
                    let isSelected = path.id == selected?.id
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy) { pathID = path.id }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: path.symbol).font(.caption.weight(.bold))
                            Text(path.title)
                            Text("\(store.progress.doneCount(in: path))/\(path.lessons.count)")
                                .monospacedDigit()
                                .opacity(0.7)
                        }
                        .font(.akFootnote.weight(.semibold))
                        .foregroundStyle(isSelected ? Palette.midnight : Palette.cream)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 38)
                        .background {
                            if isSelected { Capsule().fill(Palette.goldButton) } else { Capsule().fill(.ultraThinMaterial) }
                        }
                    }
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("learn.path.\(path.id)")
                }
            }
        }
        .scrollClipDisabled()
    }

    private func pathHeader(_ path: LearnPath) -> some View {
        let done = store.progress.doneCount(in: path)
        return VStack(alignment: .leading, spacing: 8) {
            Text(path.title)
                .font(.akTitle2)
                .foregroundStyle(Palette.cream)
            Text(path.subtitle)
                .font(.akSubheadline)
                .foregroundStyle(Palette.cream.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                ProgressView(value: Double(done), total: Double(max(1, path.lessons.count))).tint(Palette.gold)
                Text("\(done) of \(path.lessons.count)")
                    .font(.akFootnote.weight(.semibold))
                    .foregroundStyle(Palette.cream.opacity(0.8))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("learn.pathHeader")
    }

    private func tapped(_ path: LearnPath, index: Int) {
        if store.progress.isUnlocked(path, index: index) {
            Haptics.tap()
            open(.lesson(path.lessons[index].id))
        } else {
            Haptics.selection()
            let before = path.lessons[index - 1].title
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                note = "Finish \u{201C}\(before)\u{201D} and this one opens."
            }
            let shown = note
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                if note == shown { withAnimation { note = nil } }
            }
        }
    }
}

/// The path map: lessons as stepping stones on a winding trail, grouped by unit. Done = gold with a check, the next
/// one glows with "Start", later ones wait with a lock until the one before is done.
struct LearnPathMap: View {
    let path: LearnPath
    let progress: LearnProgress
    var onTap: (Int) -> Void
    @State private var pulse = false

    private static let swing: CGFloat = 78

    static func offset(_ index: Int) -> CGFloat { CGFloat(sin(Double(index) * 0.9)) * swing }

    private var groups: [(unit: String?, indices: [Int])] {
        var result: [(unit: String?, indices: [Int])] = []
        for (index, lesson) in path.lessons.enumerated() {
            if let last = result.last, last.unit == lesson.unit {
                result[result.count - 1].indices.append(index)
            } else {
                result.append((lesson.unit, [index]))
            }
        }
        return result
    }

    var body: some View {
        let next = progress.nextIndex(in: path)
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { number, group in
                if let unit = group.unit {
                    HStack(spacing: 10) {
                        Text("Unit \(number + 1)").akOverline(color: Palette.warmGold)
                        Text(unit).font(.akSubheadlineSemibold).foregroundStyle(Palette.cream)
                        Rectangle().fill(Palette.cream.opacity(0.15)).frame(height: 1)
                    }
                    .padding(.vertical, 14)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
                ForEach(group.indices, id: \.self) { index in
                    if index != group.indices.first { trail(from: index - 1) }
                    node(index, isNext: index == next)
                        .id("node-\(index)")
                }
            }
            if next == nil, !path.lessons.isEmpty {
                Label("Path complete", systemImage: "crown.fill")
                    .font(.akHeadline)
                    .foregroundStyle(Palette.midnight)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Palette.goldButton))
                    .padding(.top, 18)
                    .accessibilityIdentifier("learn.pathComplete")
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !MotionPolicy.off else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    /// Three dots between two stones, following the curve.
    private func trail(from index: Int) -> some View {
        let a = Self.offset(index), b = Self.offset(index + 1)
        let done = progress.isDone(path.lessons[index].id)
        return VStack(spacing: 7) {
            ForEach(1...3, id: \.self) { step in
                Circle()
                    .fill(done ? Palette.gold.opacity(0.8) : Palette.cream.opacity(0.22))
                    .frame(width: 7, height: 7)
                    .offset(x: a + (b - a) * CGFloat(step) / 4)
            }
        }
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }

    private func node(_ index: Int, isNext: Bool) -> some View {
        let lesson = path.lessons[index]
        let done = progress.isDone(lesson.id)
        let open = progress.isUnlocked(path, index: index)
        let state = done ? "Done" : (isNext ? "Up next" : (open ? "Open" : "Locked"))
        return Button { onTap(index) } label: {
            VStack(spacing: 8) {
                if isNext {
                    Text(progress.doneCount(in: path) == 0 ? "Start" : "Continue")
                        .font(.akCaption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.midnight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.cream))
                        .offset(y: pulse ? -3 : 1)
                }
                ZStack {
                    if isNext {
                        Circle().stroke(Palette.gold.opacity(0.5), lineWidth: 6).frame(width: 84, height: 84)
                            .scaleEffect(pulse ? 1.08 : 0.98)
                    }
                    Circle()
                        .fill(done || isNext ? AnyShapeStyle(Palette.goldButton) : AnyShapeStyle(Color.white.opacity(open ? 0.16 : 0.08)))
                        .frame(width: 70, height: 70)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
                        .shadow(color: (done || isNext) ? Palette.gold.opacity(0.4) : .clear, radius: 12, y: 4)
                    Group {
                        if done {
                            Image(systemName: "checkmark").font(.system(size: 26, weight: .heavy))
                        } else if isNext {
                            Image(systemName: "play.fill").font(.system(size: 24, weight: .bold))
                        } else if open {
                            Text("\(index + 1)").font(.system(.title3, design: .rounded, weight: .bold))
                        } else {
                            Image(systemName: "lock.fill").font(.system(size: 20, weight: .semibold))
                        }
                    }
                    .foregroundStyle(done || isNext ? Palette.midnight : Palette.cream.opacity(open ? 0.9 : 0.45))
                }
                Text(lesson.title)
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.cream.opacity(open ? 1 : 0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 170)
                Text("\(lesson.passage) · \(lesson.minutes) min")
                    .font(.akCaption)
                    .foregroundStyle(Palette.cream.opacity(open ? 0.6 : 0.35))
            }
            .offset(x: Self.offset(index))
        }
        .buttonStyle(PressScaleStyle(scale: 0.94))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lesson \(index + 1): \(lesson.title). \(lesson.passage)")
        .accessibilityValue(state)
        .accessibilityIdentifier("learn.lesson.\(lesson.id)")
    }
}
