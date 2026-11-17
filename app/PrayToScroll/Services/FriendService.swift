import Foundation

/// Someone's public friend profile: their @username, the circle nickname + emoji, and their streak.
/// Nothing about what they pray is ever shared.
struct FriendProfile: Identifiable, Hashable, Sendable {
    var memberID: String
    var handle: String
    var displayName: String
    var emoji: String
    var streak: Int
    /// "2026-11-16": the last day they prayed (so a friend's flame can show "prayed today").
    var lastPrayedDay: String
    /// Circles they own that friends can join without a code.
    var openCircles: [OpenCircle] = []
    /// References of verses they saved in Scroll the Word, newest first. Empty unless they turned on sharing.
    var savedRefs: [String] = []

    static let maxSavedRefs = 50

    var id: String { memberID }
    var atHandle: String { "@" + handle }

    func prayedToday(_ today: String = DayKey(Date()).string) -> Bool { lastPrayedDay == today }

    struct OpenCircle: Hashable, Sendable, Identifiable {
        var code: String
        var name: String
        var id: String { code }
    }
}

/// "Grace and 2 friends saved this": friends' saved verses, by reference.
enum FriendSaves {
    static func byRef(_ friends: [FriendProfile]) -> [String: [String]] {
        var map: [String: [String]] = [:]
        for friend in friends {
            let name = friend.displayName.isEmpty ? friend.atHandle : friend.displayName
            for ref in Set(friend.savedRefs.prefix(FriendProfile.maxSavedRefs)) { map[ref, default: []].append(name) }
        }
        return map.mapValues { $0.sorted() }
    }

    /// "Grace saved this", "Grace and Sam saved this", "Grace and 2 friends saved this".
    static func line(_ names: [String]) -> String? {
        guard let first = names.first else { return nil }
        switch names.count {
        case 1: return "\(first) saved this"
        case 2: return "\(first) and \(names[1]) saved this"
        default: return "\(first) and \(names.count - 1) friends saved this"
        }
    }
}

/// A friend request someone sent me (or I sent).
struct FriendRequest: Identifiable, Hashable, Sendable {
    var fromID: String
    var toID: String
    var fromHandle: String
    var toHandle: String
    var createdAt: Date
    var id: String { "freq-\(fromID)-\(toID)" }
}

/// "@grace prayed for you 🙏" (in the app on the next open; no push, no message).
struct PrayedForItem: Identifiable, Hashable, Sendable {
    var id: String
    var fromID: String
    var fromHandle: String
    var createdAt: Date
}

/// Everything the Friends section shows, loaded in one go.
struct FriendsSnapshot: Sendable, Equatable {
    var me: FriendProfile?
    var friends: [FriendProfile] = []
    var incoming: [FriendRequest] = []
    var outgoing: [FriendRequest] = []
    var prayedForMe: [PrayedForItem] = []
    /// Friends I've prayed for today (one "Pray for" a day each).
    var prayedTodayFor: Set<String> = []
}

enum FriendError: LocalizedError, Equatable {
    case noAccount
    case network
    case needsUsername
    case invalid(UsernameRules.Problem)
    case notFound
    case alreadyFriends
    case tooManyRequests
    case other(String)

    var errorDescription: String? {
        switch self {
        case .noAccount: return "Friends use your iCloud account. Sign in to iCloud in Settings."
        case .network: return "You're offline right now. Try again when you're back online."
        case .needsUsername: return "Pick a @username first, so friends know it's you."
        case .invalid(let problem): return problem.message
        case .notFound: return "No one has that username. Check the spelling: it has to be exact."
        case .alreadyFriends: return "You're already friends."
        case .tooManyRequests: return "You have 20 requests waiting. Cancel some, or wait for answers."
        case .other(let message): return message
        }
    }
}

/// Usernames and friends. CloudKit public database in production, an in-memory mock in demo mode.
/// There is no directory and no messaging: friends are found by exact @username (or a link/QR), and the only
/// thing a friend can send is "prayed for you".
protocol FriendService: AnyObject, Sendable {
    func availability() async -> CircleAvailability
    /// My handle as the server has it (nil = none chosen).
    func myHandle() async -> String?
    /// Claims a handle atomically (fails with `.invalid(.taken)` if someone has it); frees my old one.
    func claim(handle: String, profile: FriendProfile) async throws -> String
    /// Exact lookup. Hidden from people I blocked and people who blocked me.
    func lookup(handle: String) async throws -> FriendProfile
    func snapshot() async throws -> FriendsSnapshot
    func sendRequest(to profile: FriendProfile) async throws
    func cancelRequest(to memberID: String) async throws
    func accept(_ request: FriendRequest) async throws
    func decline(_ request: FriendRequest) async throws
    func remove(friend memberID: String) async throws
    /// Blocks for both directions: they can't find me or send requests, and any friendship ends.
    func block(memberID: String, handle: String) async throws
    func report(memberID: String, handle: String, reason: String) async throws
    /// "Pray for @friend": once a day per friend.
    func prayedFor(_ friend: FriendProfile) async throws
    /// Keeps my profile (nickname, emoji, streak, open circles) current for friends.
    func publish(_ profile: FriendProfile) async throws
    /// Erase all: my Username (passed in, since the local copy is already wiped), profile, links, requests,
    /// prayed-for items and blocks.
    func deleteMyData(handle: String?) async throws
}

/// What the app can link to: praytoscroll.vercel.app/u/<name> (a plain page with the handle and the store button)
/// and prayscroll://u/<name> (opens the app straight to the add-friend lookup).
extension AppLinks {
    static func profileWebURL(handle: String) -> URL {
        URL(string: webBase + "/u/\(UsernameRules.normalize(handle))")!
    }

    static func profileDeepLink(handle: String) -> URL {
        URL(string: "\(AppConstants.urlScheme)://u/\(UsernameRules.normalize(handle))")!
    }
}

/// Friend state kept on this iPhone (cleared by Erase All with every other "ak." key).
extension SharedStore {
    private enum FriendKey {
        static let username = "ak.friends.username"
        static let declined = "ak.friends.declined"
        static let blocked = "ak.friends.blocked"
    }

    /// My @username once claimed (lowercase).
    var username: String? {
        get { defaults.string(forKey: FriendKey.username) }
        set { defaults.set(newValue, forKey: FriendKey.username) }
    }

    /// Requests I declined (by sender id): they stay hidden; the sender is never told.
    var declinedFriendRequests: Set<String> {
        get { Set(defaults.stringArray(forKey: FriendKey.declined) ?? []) }
        set { defaults.set(Array(newValue), forKey: FriendKey.declined) }
    }

    /// People I blocked (member ids), mirrored from my FriendBlock records.
    var blockedFriends: Set<String> {
        get { Set(defaults.stringArray(forKey: FriendKey.blocked) ?? []) }
        set { defaults.set(Array(newValue), forKey: FriendKey.blocked) }
    }
}
