import Foundation
import Observation

/// One day's Daily 5: which answers were right, in order.
struct Daily5Result: Codable, Equatable, Sendable {
    var number: Int
    var marks: [Bool]
    var right: Int { marks.filter { $0 }.count }
}

/// What finishing a lesson earned.
struct LessonReward: Equatable, Sendable {
    var xp: Int
    var firstTime: Bool
    /// The lesson this one opened (nil at the end of a path, or on a replay).
    var unlocked: String?
}

/// Learn progress, on this iPhone only (app-group defaults, like Scroll the Word's): lessons done, XP, the Daily 5
/// days, how far each feed series has got, and missed questions (they come back in practice). Never a SwiftData model.
/// There are no hearts or lives: nothing here ever locks anyone out, and XP only goes up.
struct LearnProgress: Codable, Equatable, Sendable {
    /// Lesson ids, in the order they were first finished.
    var completed: [String] = []
    var xp = 0
    /// Days a lesson was finished ("2026-11-19"), oldest first.
    var lessonDays: [String] = []
    /// The Daily 5 by day ("2026-11-19").
    var daily: [String: Daily5Result] = [:]
    /// Feed series: parts seen so far, by series id.
    var seriesSeen: [String: Int] = [:]
    /// The lesson opened most recently (where "Continue" goes).
    var lastLessonID: String?
    var quizRight = 0
    var quizPlayed = 0
    /// Question ids answered wrong (newest last); they lead practice rounds until answered right.
    var missed: [String] = []
    /// The longest run of right answers in a row, anywhere in the app.
    var bestCombo = 0

    static let lessonXP = 10
    static let quizXP = 5
    static let replayXP = 5
    static let dailyXP = 5
    static let dailyAnswerXP = 2

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        completed = (try? c.decodeIfPresent([String].self, forKey: .completed)) ?? []
        xp = (try? c.decodeIfPresent(Int.self, forKey: .xp)) ?? 0
        lessonDays = (try? c.decodeIfPresent([String].self, forKey: .lessonDays)) ?? []
        daily = (try? c.decodeIfPresent([String: Daily5Result].self, forKey: .daily)) ?? [:]
        seriesSeen = (try? c.decodeIfPresent([String: Int].self, forKey: .seriesSeen)) ?? [:]
        lastLessonID = try? c.decodeIfPresent(String.self, forKey: .lastLessonID)
        quizRight = (try? c.decodeIfPresent(Int.self, forKey: .quizRight)) ?? 0
        quizPlayed = (try? c.decodeIfPresent(Int.self, forKey: .quizPlayed)) ?? 0
        missed = (try? c.decodeIfPresent([String].self, forKey: .missed)) ?? []
        bestCombo = (try? c.decodeIfPresent(Int.self, forKey: .bestCombo)) ?? 0
    }

    // MARK: Paths

    func isDone(_ lessonID: String) -> Bool { completed.contains(lessonID) }

    /// A lesson opens when the one before it is done (the first is always open). Done lessons stay open to replay.
    func isUnlocked(_ path: LearnPath, index: Int) -> Bool {
        guard path.lessons.indices.contains(index) else { return false }
        if index == 0 || isDone(path.lessons[index].id) { return true }
        return isDone(path.lessons[index - 1].id)
    }

    func doneCount(in path: LearnPath) -> Int { path.lessons.filter { isDone($0.id) }.count }

    /// The first open lesson not done yet (nil when the whole path is done).
    func nextIndex(in path: LearnPath) -> Int? {
        path.lessons.indices.first { !isDone(path.lessons[$0].id) && isUnlocked(path, index: $0) }
    }

    /// Where "Continue" goes: the path of the last lesson opened (else the first path), at its next lesson; if that
    /// path is done, the next path that isn't.
    func continueLesson(in library: LearnLibrary) -> Lesson? {
        let startPath = lastLessonID.flatMap { library.locate($0)?.path.id }
        let ordered = library.paths.filter { $0.id == startPath } + library.paths.filter { $0.id != startPath }
        for path in ordered {
            if let index = nextIndex(in: path) { return path.lessons[index] }
        }
        return nil
    }

    mutating func opened(_ lessonID: String) { lastLessonID = lessonID }

    /// A lesson reached its last card. First time: 10 XP plus 5 a right answer, and the next lesson opens.
    /// A replay: 5 XP. Nothing is ever taken away.
    mutating func complete(_ lesson: Lesson, in path: LearnPath?, right: Int, today: DayKey) -> LessonReward {
        let first = !isDone(lesson.id)
        let earned = first ? Self.lessonXP + Self.quizXP * max(0, right) : Self.replayXP
        xp += earned
        lastLessonID = lesson.id
        if first { completed.append(lesson.id) }
        if !lessonDays.contains(today.string) {
            lessonDays.append(today.string)
            if lessonDays.count > 400 { lessonDays.removeFirst(lessonDays.count - 400) }
        }
        var unlocked: String?
        if first, let path, let index = path.lessons.firstIndex(where: { $0.id == lesson.id }), index + 1 < path.lessons.count {
            unlocked = path.lessons[index + 1].id
        }
        return LessonReward(xp: earned, firstTime: first, unlocked: unlocked)
    }

    /// Any quiz answer (lesson, Daily 5 or practice). A wrong one comes back in practice; a right one clears it.
    mutating func answered(_ questionID: String, right: Bool) {
        quizPlayed += 1
        if right {
            quizRight += 1
            missed.removeAll { $0 == questionID }
        } else {
            missed.removeAll { $0 == questionID }
            missed.append(questionID)
            if missed.count > 60 { missed.removeFirst(missed.count - 60) }
        }
    }

    mutating func noteCombo(_ combo: Int) { bestCombo = max(bestCombo, combo) }

    // MARK: Daily 5

    func dailyResult(on day: DayKey) -> Daily5Result? { daily[day.string] }

    /// Saves today's Daily 5 (once a day: a second finish the same day never changes the score). Returns the XP.
    @discardableResult
    mutating func recordDaily(_ marks: [Bool], number: Int, on day: DayKey, calendar: Calendar = .current) -> Int {
        guard daily[day.string] == nil else { return 0 }
        daily[day.string] = Daily5Result(number: number, marks: marks)
        trimDaily(today: day, calendar: calendar)
        let earned = Self.dailyXP + Self.dailyAnswerXP * marks.filter { $0 }.count
        xp += earned
        return earned
    }

    /// Days in a row with a Daily 5, ending today (or yesterday while today is still open). One missed day a week is
    /// covered by grace, automatically and never sold: the count simply carries on.
    func dailyStreak(today: DayKey, calendar: Calendar = .current) -> Int {
        dailyRun(today: today, calendar: calendar).count
    }

    /// True when grace carried this week's Daily 5 run over a missed day.
    func dailyGraceUsed(today: DayKey, calendar: Calendar = .current) -> Bool {
        let week = WeekID(today, calendar: calendar)
        return dailyRun(today: today, calendar: calendar).graced.contains { WeekID($0, calendar: calendar) == week }
    }

    /// The current run: days played, and the missed days grace covered (at most one per calendar week, and only
    /// between two played days).
    func dailyRun(today: DayKey, calendar: Calendar = .current) -> (count: Int, graced: [DayKey]) {
        let played = Set(daily.keys)
        var day = played.contains(today.string) ? today : today.adding(days: -1, calendar: calendar)
        var count = 0
        var graced: [DayKey] = []
        while true {
            if played.contains(day.string) {
                count += 1
            } else {
                let before = day.adding(days: -1, calendar: calendar)
                let week = WeekID(day, calendar: calendar)
                guard played.contains(before.string),
                      !graced.contains(where: { WeekID($0, calendar: calendar) == week }) else { break }
                graced.append(day)
            }
            day = day.adding(days: -1, calendar: calendar)
        }
        return (count, graced)
    }

    /// Keeps the last 400 days of Daily 5 results.
    private mutating func trimDaily(today: DayKey, calendar: Calendar) {
        guard daily.count > 400 else { return }
        let cutoff = today.adding(days: -400, calendar: calendar).string
        daily = daily.filter { $0.key >= cutoff }
    }

    // MARK: Feed series

    mutating func sawSeriesPart(_ seriesID: String, index: Int) {
        seriesSeen[seriesID] = max(seriesSeen[seriesID] ?? 0, index + 1)
    }
}

/// The one place Learn progress is kept: app-group defaults, key "ak.learn.v1" (so Settings › Erase all data, which
/// clears every "ak." key, clears it too).
@MainActor
@Observable
final class LearnStore {
    nonisolated static let key = "ak.learn.v1"
    static let shared = LearnStore(defaults: SharedStore.shared.defaults)

    let defaults: UserDefaults
    var progress: LearnProgress {
        didSet { save() }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.progress = Self.read(defaults) ?? LearnProgress()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo"), defaults.data(forKey: Self.key) == nil {
            progress = Self.demo()
        }
        #endif
    }

    /// Re-reads the stored progress (after Erase all data, or a change made elsewhere).
    func reload() {
        let stored = Self.read(defaults) ?? LearnProgress()
        if stored != progress { progress = stored }
    }

    private static func read(_ defaults: UserDefaults) -> LearnProgress? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LearnProgress.self, from: data)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(progress), forKey: Self.key)
    }

    #if DEBUG
    /// Demo (screenshots, UI tests): three lessons into Meet Jesus and a 3-day Daily 5 run that today can extend.
    static func demo(today: DayKey = .today()) -> LearnProgress {
        var demo = LearnProgress()
        demo.completed = ["jesus-01", "jesus-02", "jesus-03"]
        demo.lastLessonID = "jesus-03"
        demo.xp = 85
        demo.quizPlayed = 6
        demo.quizRight = 5
        for back in 1...3 {
            let day = today.adding(days: -back)
            demo.daily[day.string] = Daily5Result(number: Daily5.number(for: day), marks: [true, true, back != 2, true, true])
        }
        demo.lessonDays = (1...3).map { today.adding(days: -$0).string }.reversed()
        return demo
    }
    #endif
}
