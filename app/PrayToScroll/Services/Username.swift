import Foundation

/// @usernames for friends: 3–20 characters, a–z 0–9 and _, case-insensitive (stored lowercase), not reserved,
/// and passing the same name filter circles use. One change every 30 days.
enum UsernameRules {
    static let minLength = 3
    static let maxLength = 20
    static let changeInterval: TimeInterval = 30 * 86_400

    enum Problem: Error, Equatable, Sendable {
        case tooShort, tooLong, badCharacters, reserved, notAllowed, taken, tooSoon(Date)

        var message: String {
            switch self {
            case .tooShort: return "Use at least 3 characters."
            case .tooLong: return "Keep it to 20 characters or fewer."
            case .badCharacters: return "Use letters, numbers and _ only."
            case .reserved, .notAllowed: return "Please choose a different username."
            case .taken: return "That username is taken."
            case .tooSoon(let date):
                return "You can change your username again on \(date.formatted(date: .abbreviated, time: .omitted))."
            }
        }
    }

    /// Names nobody can pick: roles, sacred names, Apple and our brand.
    static let reserved: Set<String> = [
        "admin", "administrator", "root", "system", "mod", "moderator", "staff", "team", "official", "verified",
        "support", "help", "helpdesk", "contact", "security", "privacy", "legal", "abuse", "report", "info", "news",
        "apple", "icloud", "appstore", "testflight", "siri", "iphone",
        "jesus", "jesuschrist", "christ", "god", "lord", "yahweh", "jehovah", "holyspirit", "holy_spirit", "allah",
        "messiah", "savior", "saviour", "pope", "bible", "church",
        "praytoscroll", "pray_to_scroll", "pray2scroll", "prayscroll", "praytoscrollapp", "amenkey", "amenkeyapp",
        "prayergate", "praypass", "everyone", "anonymous", "null", "undefined", "me", "you", "user", "username",
    ]

    /// Lowercase, without a leading @ or surrounding spaces. Doesn't validate.
    static func normalize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while text.hasPrefix("@") { text.removeFirst() }
        return text
    }

    static func problem(with raw: String) -> Problem? {
        let handle = normalize(raw)
        if handle.count < minLength { return .tooShort }
        if handle.count > maxLength { return .tooLong }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
        if !handle.allSatisfy({ allowed.contains($0) }) { return .badCharacters }
        let bare = handle.replacingOccurrences(of: "_", with: "")
        if reserved.contains(handle) || reserved.contains(bare) || bare.isEmpty { return .reserved }
        // Brand and role look-alikes ("praytoscroll_support", "official_jesus") are reserved too.
        let roots = ["praytoscroll", "amenkey", "official", "admin", "support", "moderator", "apple"]
        if roots.contains(where: { bare.contains($0) }) { return .reserved }
        let squashed = bare
            .replacingOccurrences(of: "0", with: "o").replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e").replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "5", with: "s").replacingOccurrences(of: "7", with: "t")
            .filter { $0.isLetter }
        if NameFilter.blockedWords.contains(where: { squashed.contains($0) }) { return .notAllowed }
        return nil
    }

    static func isValid(_ raw: String) -> Bool { problem(with: raw) == nil }

    /// When the next change is allowed (nil = now).
    static func nextChange(after lastChange: Date?, now: Date = Date()) -> Date? {
        guard let lastChange else { return nil }
        let next = lastChange.addingTimeInterval(changeInterval)
        return next > now ? next : nil
    }
}

/// Exact-name uniqueness, in memory: the rules the CloudKit `Username` record gives us (its recordName IS the
/// lowercase handle, so a second save of the same name fails). Used by the demo service and the unit tests.
struct UsernameLedger: Sendable {
    struct Entry: Equatable, Sendable { var memberID: String; var createdAt: Date }
    private(set) var entries: [String: Entry] = [:]

    func owner(of raw: String) -> String? { entries[UsernameRules.normalize(raw)]?.memberID }

    func handle(of memberID: String) -> String? { entries.first { $0.value.memberID == memberID }?.key }

    /// Claims `raw` for `memberID`, releasing their old handle. Fails if it's invalid, someone else holds it, or
    /// their last change was under 30 days ago.
    mutating func claim(_ raw: String, for memberID: String, now: Date = Date()) -> Result<String, UsernameRules.Problem> {
        let handle = UsernameRules.normalize(raw)
        if let problem = UsernameRules.problem(with: handle) { return .failure(problem) }
        if let existing = entries[handle] {
            return existing.memberID == memberID ? .success(handle) : .failure(.taken)
        }
        if let old = self.handle(of: memberID) {
            if let next = UsernameRules.nextChange(after: entries[old]?.createdAt, now: now) { return .failure(.tooSoon(next)) }
            entries[old] = nil
        }
        entries[handle] = Entry(memberID: memberID, createdAt: now)
        return .success(handle)
    }

    mutating func release(memberID: String) {
        entries = entries.filter { $0.value.memberID != memberID }
    }
}
