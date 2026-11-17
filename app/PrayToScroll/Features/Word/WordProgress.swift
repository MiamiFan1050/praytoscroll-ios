import Foundation

/// A themed board of saved verses ("Morning", "Hard days"…), newest first.
struct WordBoard: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var emoji: String
    var refs: [String] = []
    var createdAt: Date = Date()

    static let maxNameLength = 30
    /// Offered the first time someone saves to a board.
    static let starters: [(name: String, emoji: String)] = [("Morning", "☀️"), ("Hard days", "🫶"), ("Promises", "🌈")]
}

enum WordBadge: String, Codable, CaseIterable, Identifiable, Sendable {
    case firstSave, firstGoal, streak3, streak7, streak30, read100, read500, read1000, finish10, who10, allThemes,
         firstBoard, firstSend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSave: return "First heart"
        case .firstGoal: return "Goal met"
        case .streak3: return "3 days running"
        case .streak7: return "A full week"
        case .streak30: return "30 days running"
        case .read100: return "100 verses"
        case .read500: return "500 verses"
        case .read1000: return "1,000 verses"
        case .finish10: return "Verse finisher"
        case .who10: return "Good listener"
        case .allThemes: return "Every theme"
        case .firstBoard: return "Collector"
        case .firstSend: return "Encourager"
        }
    }

    var detail: String {
        switch self {
        case .firstSave: return "Saved your first verse."
        case .firstGoal: return "Met your daily goal."
        case .streak3: return "Met your goal 3 days in a row."
        case .streak7: return "Met your goal 7 days in a row."
        case .streak30: return "Met your goal 30 days in a row."
        case .read100: return "Read 100 verses."
        case .read500: return "Read 500 verses."
        case .read1000: return "Read 1,000 verses."
        case .finish10: return "Finished 10 verses right."
        case .who10: return "Named 10 speakers right."
        case .allThemes: return "Read a verse from all 14 themes."
        case .firstBoard: return "Started a collection."
        case .firstSend: return "Sent a verse to someone."
        }
    }

    var symbol: String {
        switch self {
        case .firstSave: return "heart.fill"
        case .firstGoal: return "checkmark.seal.fill"
        case .streak3, .streak7, .streak30: return "flame.fill"
        case .read100, .read500, .read1000: return "book.fill"
        case .finish10: return "text.badge.checkmark"
        case .who10: return "person.wave.2.fill"
        case .allThemes: return "square.grid.3x3.fill"
        case .firstBoard: return "rectangle.stack.fill"
        case .firstSend: return "paperplane.fill"
        }
    }
}

/// Levels grow with verses read: a seed to a harvest, then on.
struct WordLevel: Equatable, Sendable {
    let number: Int
    let name: String
    /// Verses read where this level starts, and where the next one does (nil at the top).
    let floor: Int
    let next: Int?

    static let floors = [0, 10, 30, 60, 100, 160, 250, 400, 600, 850, 1200, 1700, 2500, 3500, 5000]
    static let names = ["Seed", "Sprout", "Root", "Stem", "Leaf", "Branch", "Bud", "Bloom", "Fruit", "Vine",
                        "Orchard", "Harvest", "Cedar", "Oak", "Mountain"]

    static func `for`(read: Int) -> WordLevel {
        let index = floors.lastIndex(where: { read >= $0 }) ?? 0
        return WordLevel(number: index + 1, name: names[index], floor: floors[index],
                         next: index + 1 < floors.count ? floors[index + 1] : nil)
    }

    func progress(read: Int) -> Double {
        guard let next else { return 1 }
        return min(1, max(0, Double(read - floor) / Double(next - floor)))
    }
}

/// Something worth a card in the feed.
enum WordEvent: Equatable, Sendable {
    case goalReached(Int)
    case levelUp(WordLevel)
    case badge(WordBadge)
}

/// "For you" signals, all on this iPhone.
enum ForYouSignal: Equatable, Sendable {
    case heart, board, share, pray, sent
    /// Seconds a verse stayed on screen.
    case dwell(Double)

    /// How much a signal moves a theme. A quick flick past is a mild "less of this".
    var weight: Double {
        switch self {
        case .heart, .board: return 1.0
        case .share, .pray, .sent: return 0.8
        case .dwell(let seconds):
            if seconds < 1.5 { return -0.3 }
            if seconds >= 15 { return 0.6 }
            if seconds >= 7 { return 0.3 }
            return 0
        }
    }
}

/// Scroll the Word progress, on this iPhone only: verses read per day, the goal streak, level, badges, quiz scores,
/// boards, and the theme weights behind "For you". Nothing here is uploaded.
struct WordProgress: Codable, Equatable, Sendable {
    var readByDay: [String: Int] = [:]
    var totalRead = 0
    /// Days the daily goal was met ("2026-11-16"), oldest first.
    var goalDays: [String] = []
    var themesRead: [String] = []
    var finishRight = 0
    var finishPlayed = 0
    var whoRight = 0
    var whoPlayed = 0
    var sent = 0
    var badges: [WordBadge] = []
    var affinity: [String: Double] = [:]
    var boards: [WordBoard] = []
    /// Facts and quizzes in the order they were shown (oldest first), so they rotate.
    var seenExtras: [String] = []

    static let goalOptions = [5, 10, 15, 20, 30, 50]
    static let defaultGoal = 10
    static let themeCount = 14

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        readByDay = (try? c.decodeIfPresent([String: Int].self, forKey: .readByDay)) ?? [:]
        totalRead = (try? c.decodeIfPresent(Int.self, forKey: .totalRead)) ?? 0
        goalDays = (try? c.decodeIfPresent([String].self, forKey: .goalDays)) ?? []
        themesRead = (try? c.decodeIfPresent([String].self, forKey: .themesRead)) ?? []
        finishRight = (try? c.decodeIfPresent(Int.self, forKey: .finishRight)) ?? 0
        finishPlayed = (try? c.decodeIfPresent(Int.self, forKey: .finishPlayed)) ?? 0
        whoRight = (try? c.decodeIfPresent(Int.self, forKey: .whoRight)) ?? 0
        whoPlayed = (try? c.decodeIfPresent(Int.self, forKey: .whoPlayed)) ?? 0
        sent = (try? c.decodeIfPresent(Int.self, forKey: .sent)) ?? 0
        badges = ((try? c.decodeIfPresent([String].self, forKey: .badges)) ?? []).compactMap(WordBadge.init(rawValue:))
        affinity = (try? c.decodeIfPresent([String: Double].self, forKey: .affinity)) ?? [:]
        boards = (try? c.decodeIfPresent([WordBoard].self, forKey: .boards)) ?? []
        seenExtras = (try? c.decodeIfPresent([String].self, forKey: .seenExtras)) ?? []
    }

    var level: WordLevel { WordLevel.for(read: totalRead) }

    func readOn(_ day: String) -> Int { readByDay[day] ?? 0 }

    /// Days in a row the goal was met, ending today, or yesterday while today is still open.
    /// A missed day just starts a new count: nothing is "lost" on screen.
    func streak(today: DayKey, calendar: Calendar = .current) -> Int {
        let met = Set(goalDays)
        var day = met.contains(today.string) ? today : today.adding(days: -1, calendar: calendar)
        var count = 0
        while met.contains(day.string) {
            count += 1
            day = day.adding(days: -1, calendar: calendar)
        }
        return count
    }

    // MARK: Recording

    /// A verse (or a verse card) was read. Returns what's worth celebrating.
    mutating func recordRead(theme: String?, today: DayKey, goal: Int, calendar: Calendar = .current) -> [WordEvent] {
        let before = level
        let key = today.string
        readByDay[key, default: 0] += 1
        totalRead += 1
        trimDays(today: today, calendar: calendar)
        if let theme, !theme.isEmpty, !themesRead.contains(theme) { themesRead.append(theme) }
        var events: [WordEvent] = []
        // At or past the goal (it may have been lowered mid-day), once a day.
        if readByDay[key, default: 0] >= max(1, goal), !goalDays.contains(key) {
            goalDays.append(key)
            if goalDays.count > 400 { goalDays.removeFirst(goalDays.count - 400) }
            events.append(.goalReached(goal))
        }
        if level.number > before.number { events.append(.levelUp(level)) }
        events += award(today: today, calendar: calendar)
        return events
    }

    enum Quiz { case finish, who }

    mutating func recordQuiz(_ quiz: Quiz, right: Bool, today: DayKey) -> [WordEvent] {
        switch quiz {
        case .finish:
            finishPlayed += 1
            if right { finishRight += 1 }
        case .who:
            whoPlayed += 1
            if right { whoRight += 1 }
        }
        return award(today: today)
    }

    mutating func recordSent(today: DayKey) -> [WordEvent] {
        sent += 1
        return award(today: today)
    }

    mutating func recordSaved(today: DayKey) -> [WordEvent] {
        var events = award(today: today)
        if !badges.contains(.firstSave) {
            badges.append(.firstSave)
            events.append(.badge(.firstSave))
        }
        return events
    }

    /// Nudges a theme's "For you" weight. Old signals fade a little with every new one.
    mutating func signal(_ signal: ForYouSignal, theme: String?) {
        guard let theme, !theme.isEmpty else { return }
        let weight = signal.weight
        guard weight != 0 else { return }
        for key in affinity.keys { affinity[key]! *= 0.99 }
        affinity[theme] = min(8, max(-4, (affinity[theme] ?? 0) + weight))
    }

    mutating func markExtraSeen(_ id: String) {
        seenExtras.removeAll { $0 == id }
        seenExtras.append(id)
        if seenExtras.count > 600 { seenExtras.removeFirst(seenExtras.count - 600) }
    }

    /// New badges since the last check.
    private mutating func award(today: DayKey, calendar: Calendar = .current) -> [WordEvent] {
        let streak = streak(today: today, calendar: calendar)
        let earned: [(WordBadge, Bool)] = [
            (.firstGoal, !goalDays.isEmpty),
            (.streak3, streak >= 3), (.streak7, streak >= 7), (.streak30, streak >= 30),
            (.read100, totalRead >= 100), (.read500, totalRead >= 500), (.read1000, totalRead >= 1000),
            (.finish10, finishRight >= 10), (.who10, whoRight >= 10),
            (.allThemes, themesRead.count >= Self.themeCount),
            (.firstBoard, boards.contains { !$0.refs.isEmpty }),
            (.firstSend, sent >= 1),
        ]
        var events: [WordEvent] = []
        for (badge, done) in earned where done && !badges.contains(badge) {
            badges.append(badge)
            events.append(.badge(badge))
        }
        return events
    }

    /// Keeps the per-day counts to the last 120 days.
    private mutating func trimDays(today: DayKey, calendar: Calendar) {
        guard readByDay.count > 120 else { return }
        let cutoff = today.adding(days: -120, calendar: calendar).string
        readByDay = readByDay.filter { $0.key >= cutoff }
    }

    // MARK: Boards

    /// Adds the starter boards the first time.
    mutating func ensureBoards() {
        guard boards.isEmpty else { return }
        boards = WordBoard.starters.enumerated().map { index, starter in
            WordBoard(id: "starter-\(index)", name: starter.name, emoji: starter.emoji)
        }
    }

    @discardableResult
    mutating func addBoard(name: String, emoji: String) -> WordBoard? {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(WordBoard.maxNameLength))
        guard !clean.isEmpty else { return nil }
        if let existing = boards.first(where: { $0.name.lowercased() == clean.lowercased() }) { return existing }
        let board = WordBoard(id: UUID().uuidString, name: clean, emoji: emoji.isEmpty ? "📖" : emoji)
        boards.append(board)
        return board
    }

    /// Puts a verse on a board (once, newest first). Returns new badges.
    mutating func add(ref: String, toBoard id: String, today: DayKey) -> [WordEvent] {
        guard let index = boards.firstIndex(where: { $0.id == id }) else { return [] }
        boards[index].refs.removeAll { $0 == ref }
        boards[index].refs.insert(ref, at: 0)
        return award(today: today)
    }

    mutating func remove(ref: String, fromBoard id: String) {
        guard let index = boards.firstIndex(where: { $0.id == id }) else { return }
        boards[index].refs.removeAll { $0 == ref }
    }

    mutating func deleteBoard(_ id: String) {
        boards.removeAll { $0.id == id }
    }

    /// A verse un-saved everywhere also leaves every board.
    mutating func removeEverywhere(ref: String) {
        for index in boards.indices { boards[index].refs.removeAll { $0 == ref } }
    }

    func boards(containing ref: String) -> [WordBoard] {
        boards.filter { $0.refs.contains(ref) }
    }
}
