import SwiftUI

/// Home's Learn card (self-contained, wired at the `// LEARN-HOOK` line in HomeView): today's Daily 5 and the lesson
/// you're on, each one tap away. Learn opens full screen over Home, as it does from Scroll the Word.
struct LearnHomeCard: View {
    @Environment(AppModel.self) private var model
    @State private var start: LearnStart?
    private let store = LearnStore.shared
    private let library = LearnLibrary.shared

    private var today: DayKey { .today() }

    var body: some View {
        Group {
            if !library.paths.isEmpty, showsInThisRun {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Learn the Bible", systemImage: "graduationcap.fill")
                            .font(.akOverline)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.goldText)
                        Spacer()
                        if store.progress.xp > 0 { Chip(text: "\(store.progress.xp) XP", tint: Theme.goldText) }
                    }
                    if let lesson = store.progress.continueLesson(in: library), let place = library.locate(lesson.id) {
                        row(symbol: place.path.symbol,
                            title: lesson.title,
                            detail: "\(place.path.title) · lesson \(place.index + 1) of \(place.path.lessons.count) · \(lesson.minutes) min",
                            id: "home.learn.lesson") { start = .lesson(lesson.id) }
                    } else {
                        row(symbol: "crown.fill", title: "Every path done", detail: "Replay any lesson from the map.",
                            id: "home.learn.hub") { start = .hub }
                    }
                    let played = store.progress.dailyResult(on: today)
                    row(symbol: "square.grid.3x3.fill",
                        title: "Daily 5 #\(Daily5.number(for: today))",
                        detail: played.map { "Played today: \($0.right) of \($0.marks.count). Practice any time." }
                            ?? "Five questions, the same five for everyone today.",
                        id: "home.learn.daily5") { start = .daily5 }
                }
                .akCard()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.learn")
            }
        }
        .fullScreenCover(item: $start) { start in
            LearnRootView(start: start).environment(model)
        }
        .onAppear { store.reload() }
    }

    /// UI-test runs (crawl, App Store screenshots) keep today's Home unless a test passes -learnCard.
    private var showsInThisRun: Bool {
        !model.options.isUITest || ProcessInfo.processInfo.arguments.contains("-learnCard")
    }

    private func row(symbol: String, title: String, detail: String, id: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.midnight)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Palette.goldButton))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.akHeadline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(detail)
                        .font(.akFootnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}
