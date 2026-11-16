import Foundation

struct PrayerCircle: Identifiable, Hashable, Sendable {
    var code: String
    var name: String
    var createdAt: Date
    var ownerID: String
    var id: String { code }
}

struct CircleMember: Identifiable, Hashable, Sendable {
    var id: String
    var displayName: String
    var emoji: String
    var prayersThisWeek: Int
    var streak: Int
    var weekKey: String
    var updatedAt: Date
    var isMe: Bool
    var isHidden: Bool = false

    /// Weekly counts from an older week count as zero.
    func prayers(inWeek current: String) -> Int {
        weekKey == current ? prayersThisWeek : 0
    }
}

enum CircleAvailability: Equatable, Sendable {
    case available
    case noAccount
    case restricted
    case unavailable(String)
}

enum CircleError: LocalizedError, Equatable {
    case notFound
    case noAccount
    case network
    case nameNotAllowed
    case invalidCode
    case other(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "We couldn't find a circle with that code. Check the letters and try again."
        case .noAccount: return "Circles use your iCloud account. Sign in to iCloud in Settings to join friends."
        case .network: return "You're offline right now. Circles will sync when you're back online."
        case .nameNotAllowed: return "Please choose a different name."
        case .invalidCode: return "Circle codes are 6 letters and numbers, like K7Q 2MX."
        case .other(let message): return message
        }
    }
}

/// Prayer Circles backend. CloudKit public database in production, an in-memory mock in demo mode.
protocol CircleService: AnyObject, Sendable {
    func availability() async -> CircleAvailability
    func myCircles() async throws -> [PrayerCircle]
    func create(name: String, displayName: String, emoji: String) async throws -> PrayerCircle
    func join(code: String, displayName: String, emoji: String) async throws -> PrayerCircle
    func leave(code: String) async throws
    func members(code: String) async throws -> [CircleMember]
    func reportProgress(displayName: String, emoji: String, prayersThisWeek: Int, streak: Int) async throws
    func setHidden(_ hidden: Bool, code: String) async throws
    func report(memberID: String, code: String, reason: String) async throws
    func deleteMyData(codes: [String]) async throws
}

enum CircleWeek {
    /// "2026-W47" for the current week in the user's calendar.
    static func key(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let week = WeekID(DayKey(date, calendar: calendar), calendar: calendar)
        return String(format: "%04d-W%02d", week.yearForWeek, week.week)
    }

    /// When the weekly leaderboard resets (start of next week).
    static func resetDate(from date: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return nil }
        return interval.end
    }
}

/// Nickname + circle-name filter for Circles (App Review 1.2). Names only; there is no free-text chat.
/// Rules: 2–20 characters; letters, numbers, emoji and spaces only; no slurs or profanity (bundled list).
enum NameFilter {
    static let minLength = 2
    static let maxLength = 20

    enum Problem: Equatable {
        case tooShort, tooLong, badCharacters, notAllowed
        var message: String {
            switch self {
            case .tooShort: return "Use at least 2 characters."
            case .tooLong: return "Keep it to 20 characters or fewer."
            case .badCharacters: return "Use letters, numbers, emoji and spaces only."
            case .notAllowed: return "Please choose a different name."
            }
        }
    }

    /// Words loaded from `nickname-blocklist.json` (bundled), plus a built-in core list as a safety net.
    static let blockedWords: [String] = {
        var words: Set<String> = ["fuck", "shit", "bitch", "cunt", "pussy", "nigg", "faggot", "slut", "whore", "rapist",
                                  "nazi", "porn", "asshole", "retard", "hitler", "motherf", "dildo", "twat", "kike",
                                  "chink", "tranny", "jizz", "penis", "vagina", "sexy"]
        if let url = Bundle.main.url(forResource: "nickname-blocklist", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            words.formUnion(list.map { $0.lowercased() }.filter { $0.count >= 3 })
        }
        return Array(words)
    }()

    static func clean(_ raw: String) -> String {
        let collapsed = raw.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return String(collapsed.prefix(maxLength))
    }

    static func problem(with raw: String) -> Problem? {
        let name = raw.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if name.count < minLength { return .tooShort }
        if name.count > maxLength { return .tooLong }
        for character in name {
            let ok = character.isLetter || character.isNumber || character == " " || isEmoji(character)
            if !ok { return .badCharacters }
        }
        let squashed = name.lowercased()
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "7", with: "t")
            .filter { $0.isLetter }
        if blockedWords.contains(where: { squashed.contains($0) }) { return .notAllowed }
        return nil
    }

    static func isAllowed(_ raw: String) -> Bool { problem(with: raw) == nil }

    static func isEmoji(_ character: Character) -> Bool {
        character.unicodeScalars.contains { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C) }
            || character.unicodeScalars.contains { $0.value == 0xFE0F || $0.value == 0x200D }
    }
}

/// Local block list for circle members (never leaves the device).
enum CircleBlockList {
    private static let key = "ak.circles.blocked"

    static func blocked(in defaults: UserDefaults = SharedStore.shared.defaults) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    static func block(_ memberID: String, in defaults: UserDefaults = SharedStore.shared.defaults) {
        var set = blocked(in: defaults)
        set.insert(memberID)
        defaults.set(Array(set), forKey: key)
    }

    static func unblockAll(in defaults: UserDefaults = SharedStore.shared.defaults) {
        defaults.removeObject(forKey: key)
    }
}
