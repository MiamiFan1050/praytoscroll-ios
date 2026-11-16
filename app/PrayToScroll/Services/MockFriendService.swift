#if DEBUG
// Debug builds only: demo friends for UI tests and screenshots. Not in the Release binary.
import Foundation

/// In-memory usernames + friends with the same rules as CloudKit (exact lookup, atomic names, blocks both ways).
final class MockFriendService: FriendService, @unchecked Sendable {
    private let lock = NSLock()
    private let meID = "me"
    private var ledger = UsernameLedger()
    private var profiles: [String: FriendProfile] = [:]
    private var links: Set<String> = []          // "owner>friend"
    private var requests: [String: FriendRequest] = [:]
    private var prayed: [PrayedForItem] = []
    private var prayedToday: Set<String> = []
    private var blocks: Set<String> = []         // "blocker>blocked"
    private var declined: Set<String> = []
    private(set) var reports: [(String, String)] = []
    private var myName: String?
    var simulatedAvailability: CircleAvailability = .available

    init() {}

    static func demo(withUsername: Bool = true) -> MockFriendService {
        let service = MockFriendService()
        let today = DayKey(Date()).string
        let yesterday = DayKey(Date().addingTimeInterval(-86_400)).string
        let people: [FriendProfile] = [
            FriendProfile(memberID: "f-grace", handle: "grace", displayName: "Grace", emoji: "🌿", streak: 22, lastPrayedDay: today,
                          openCircles: [.init(code: "G8R4CE", name: "Grace's Prayer Team")]),
            FriendProfile(memberID: "f-sam", handle: "sam_p", displayName: "Sam", emoji: "⛰️", streak: 9, lastPrayedDay: yesterday),
            FriendProfile(memberID: "f-jordan", handle: "jordan_k", displayName: "Jordan", emoji: "🔥", streak: 4, lastPrayedDay: today),
            FriendProfile(memberID: "f-hannah", handle: "hannah_b", displayName: "Hannah", emoji: "🌸", streak: 14, lastPrayedDay: today),
        ]
        let created = Date().addingTimeInterval(-40 * 86_400)
        for person in people {
            service.profiles[person.memberID] = person
            _ = service.ledger.claim(person.handle, for: person.memberID, now: created)
        }
        if withUsername {
            _ = service.ledger.claim("markprays", for: "me", now: created)
            service.myName = "markprays"
            service.profiles["me"] = FriendProfile(memberID: "me", handle: "markprays", displayName: "Mark", emoji: "🕊️",
                                                   streak: 13, lastPrayedDay: today)
        }
        service.links = ["me>f-grace", "f-grace>me", "me>f-sam", "f-sam>me"]
        service.requests["freq-f-jordan-me"] = FriendRequest(fromID: "f-jordan", toID: "me", fromHandle: "jordan_k", toHandle: "markprays",
                                                             createdAt: Date().addingTimeInterval(-3_600))
        service.prayed = [PrayedForItem(id: "pf-grace", fromID: "f-grace", fromHandle: "grace", createdAt: Date().addingTimeInterval(-2 * 3_600))]
        return service
    }

    func availability() async -> CircleAvailability { simulatedAvailability }

    func myHandle() async -> String? { lock.withLock { myName } }

    func claim(handle raw: String, profile: FriendProfile) async throws -> String {
        try lock.withLock {
            switch ledger.claim(raw, for: meID) {
            case .success(let handle):
                myName = handle
                var mine = profile
                mine.memberID = meID
                mine.handle = handle
                profiles[meID] = mine
                return handle
            case .failure(let problem):
                throw FriendError.invalid(problem)
            }
        }
    }

    func lookup(handle raw: String) async throws -> FriendProfile {
        try lock.withLock {
            guard let owner = ledger.owner(of: raw), let profile = profiles[owner] else { throw FriendError.notFound }
            if blocks.contains("\(owner)>\(meID)") || blocks.contains("\(meID)>\(owner)") { throw FriendError.notFound }
            return profile
        }
    }

    func snapshot() async throws -> FriendsSnapshot {
        lock.withLock {
            let blocked = Set(blocks.compactMap { pair -> String? in
                let parts = pair.split(separator: ">").map(String.init)
                return parts[0] == meID ? parts[1] : (parts[1] == meID ? parts[0] : nil)
            })
            let friends = profiles.values.filter { p in
                p.memberID != meID && links.contains("\(meID)>\(p.memberID)") && links.contains("\(p.memberID)>\(meID)")
                    && !blocked.contains(p.memberID)
            }
            let friendIDs = Set(friends.map(\.memberID))
            return FriendsSnapshot(
                me: profiles[meID],
                friends: friends.sorted { $0.handle < $1.handle },
                incoming: requests.values.filter { $0.toID == meID && !friendIDs.contains($0.fromID) && !declined.contains($0.fromID)
                    && !blocked.contains($0.fromID) }.sorted { $0.createdAt > $1.createdAt },
                outgoing: requests.values.filter { $0.fromID == meID && !friendIDs.contains($0.toID) && !blocked.contains($0.toID) },
                prayedForMe: prayed.filter { friendIDs.contains($0.fromID) },
                prayedTodayFor: prayedToday)
        }
    }

    func sendRequest(to profile: FriendProfile) async throws {
        try lock.withLock {
            guard let myName else { throw FriendError.needsUsername }
            if requests["freq-\(profile.memberID)-\(meID)"] != nil {
                links.insert("\(meID)>\(profile.memberID)")
                links.insert("\(profile.memberID)>\(meID)")
                requests["freq-\(profile.memberID)-\(meID)"] = nil
                return
            }
            let request = FriendRequest(fromID: meID, toID: profile.memberID, fromHandle: myName, toHandle: profile.handle, createdAt: Date())
            requests[request.id] = request
        }
    }

    func cancelRequest(to memberID: String) async throws {
        lock.withLock { requests["freq-\(meID)-\(memberID)"] = nil }
    }

    func accept(_ request: FriendRequest) async throws {
        lock.withLock {
            // The demo friend is always online: both sides link at once.
            links.insert("\(meID)>\(request.fromID)")
            links.insert("\(request.fromID)>\(meID)")
            requests[request.id] = nil
            declined.remove(request.fromID)
        }
    }

    func decline(_ request: FriendRequest) async throws {
        lock.withLock { _ = declined.insert(request.fromID) }
    }

    func remove(friend memberID: String) async throws {
        lock.withLock {
            links.remove("\(meID)>\(memberID)")
            links.remove("\(memberID)>\(meID)")
        }
    }

    func block(memberID: String, handle: String) async throws {
        lock.withLock {
            blocks.insert("\(meID)>\(memberID)")
            links.remove("\(meID)>\(memberID)")
            links.remove("\(memberID)>\(meID)")
            requests = requests.filter { $0.value.fromID != memberID && $0.value.toID != memberID }
        }
    }

    func report(memberID: String, handle: String, reason: String) async throws {
        lock.withLock { reports.append((memberID, reason)) }
        try await block(memberID: memberID, handle: handle)
    }

    func prayedFor(_ friend: FriendProfile) async throws {
        try lock.withLock {
            guard myName != nil else { throw FriendError.needsUsername }
            prayedToday.insert(friend.memberID)
        }
    }

    func publish(_ profile: FriendProfile) async throws {
        lock.withLock {
            guard let myName else { return }
            var mine = profile
            mine.memberID = meID
            mine.handle = myName
            profiles[meID] = mine
        }
    }

    func deleteMyData(handle: String?) async throws {
        lock.withLock {
            ledger.release(memberID: meID)
            myName = nil
            profiles[meID] = nil
            links = links.filter { !$0.hasPrefix("\(meID)>") && !$0.hasSuffix(">\(meID)") }
            requests = requests.filter { $0.value.fromID != meID }
            blocks = blocks.filter { !$0.hasPrefix("\(meID)>") }
            prayedToday = []
        }
    }
}
#endif
