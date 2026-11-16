#if DEBUG
// Debug builds only: demo data / mock circles for UI tests and screenshots. Not in the Release binary.
import Foundation

/// In-memory circles for demo mode, previews and tests.
final class MockCircleService: CircleService, @unchecked Sendable {
    private let lock = NSLock()
    private var circles: [String: PrayerCircle] = [:]
    private var membersByCode: [String: [CircleMember]] = [:]
    private var joined: [String] = []
    private let meID = "me"
    var simulatedAvailability: CircleAvailability = .available

    init() {}

    static func demo() -> MockCircleService {
        let service = MockCircleService()
        let week = CircleWeek.key()
        let code = "K7Q2MX"
        let circle = PrayerCircle(code: code, name: "Lighthouse Small Group", createdAt: Date().addingTimeInterval(-86_400 * 40), ownerID: "me")
        let people: [(String, String, Int, Int)] = [
            ("Sarah", "🌻", 19, 31),
            ("Mark", "🕊️", 16, 13),
            ("James", "⛰️", 14, 9),
            ("Grace", "🌿", 11, 22),
            ("Daniel", "🔥", 8, 5),
            ("Ruth", "🌙", 6, 3),
        ]
        let members = people.enumerated().map { index, p in
            CircleMember(id: p.0 == "Mark" ? "me" : "demo-\(index)", displayName: p.0, emoji: p.1, prayersThisWeek: p.2,
                         streak: p.3, weekKey: week, updatedAt: Date().addingTimeInterval(-Double(index) * 3_600),
                         isMe: p.0 == "Mark")
        }
        let second = PrayerCircle(code: "R4NB8T", name: "Morrison Family", createdAt: Date().addingTimeInterval(-86_400 * 12), ownerID: "demo-9")
        let family = [
            CircleMember(id: "me", displayName: "Mark", emoji: "🕊️", prayersThisWeek: 16, streak: 13, weekKey: week, updatedAt: Date(), isMe: true),
            CircleMember(id: "fam-1", displayName: "Mom", emoji: "🌷", prayersThisWeek: 21, streak: 64, weekKey: week, updatedAt: Date(), isMe: false),
            CircleMember(id: "fam-2", displayName: "Luke", emoji: "⚾️", prayersThisWeek: 7, streak: 4, weekKey: week, updatedAt: Date(), isMe: false),
        ]
        service.circles = [code: circle, second.code: second]
        service.membersByCode = [code: members, second.code: family]
        service.joined = [code, second.code]
        return service
    }

    func availability() async -> CircleAvailability { simulatedAvailability }

    func myCircles() async throws -> [PrayerCircle] {
        lock.withLock { joined.compactMap { circles[$0] } }
    }

    func create(name: String, displayName: String, emoji: String) async throws -> PrayerCircle {
        guard NameFilter.isAllowed(name), NameFilter.isAllowed(displayName) else { throw CircleError.nameNotAllowed }
        return lock.withLock {
            let code = CircleCode.generate()
            let circle = PrayerCircle(code: code, name: NameFilter.clean(name), createdAt: Date(), ownerID: meID)
            circles[code] = circle
            membersByCode[code] = [CircleMember(id: meID, displayName: displayName, emoji: emoji, prayersThisWeek: 0, streak: 0,
                                                weekKey: CircleWeek.key(), updatedAt: Date(), isMe: true)]
            joined.append(code)
            return circle
        }
    }

    func join(code rawCode: String, displayName: String, emoji: String) async throws -> PrayerCircle {
        guard let code = CircleCode.normalize(rawCode) else { throw CircleError.invalidCode }
        guard NameFilter.isAllowed(displayName) else { throw CircleError.nameNotAllowed }
        return lock.withLock {
            let circle = circles[code] ?? PrayerCircle(code: code, name: "Friends Circle", createdAt: Date(), ownerID: "someone")
            circles[code] = circle
            var members = membersByCode[code] ?? [
                CircleMember(id: "host", displayName: "Hannah", emoji: "🌸", prayersThisWeek: 9, streak: 14,
                             weekKey: CircleWeek.key(), updatedAt: Date(), isMe: false),
            ]
            if !members.contains(where: { $0.isMe }) {
                members.append(CircleMember(id: meID, displayName: displayName, emoji: emoji, prayersThisWeek: 0, streak: 0,
                                            weekKey: CircleWeek.key(), updatedAt: Date(), isMe: true))
            }
            membersByCode[code] = members
            if !joined.contains(code) { joined.append(code) }
            return circle
        }
    }

    func leave(code: String) async throws {
        lock.withLock {
            joined.removeAll { $0 == code }
            membersByCode[code]?.removeAll { $0.isMe }
        }
    }

    func members(code: String) async throws -> [CircleMember] {
        lock.withLock { membersByCode[code] ?? [] }
    }

    func reportProgress(displayName: String, emoji: String, prayersThisWeek: Int, streak: Int) async throws {
        lock.withLock {
            for code in joined {
                guard var members = membersByCode[code], let index = members.firstIndex(where: { $0.isMe }) else { continue }
                members[index].displayName = displayName
                members[index].emoji = emoji
                members[index].prayersThisWeek = max(members[index].prayersThisWeek, prayersThisWeek)
                members[index].streak = max(members[index].streak, streak)
                members[index].weekKey = CircleWeek.key()
                members[index].updatedAt = Date()
                membersByCode[code] = members
            }
        }
    }

    func setHidden(_ hidden: Bool, code: String) async throws {
        lock.withLock {
            guard var members = membersByCode[code], let index = members.firstIndex(where: { $0.isMe }) else { return }
            members[index].isHidden = hidden
            membersByCode[code] = members
        }
    }

    func report(memberID: String, code: String, reason: String) async throws {
        CircleBlockList.block(memberID)
    }

    func deleteMyData(codes: [String]) async throws {
        lock.withLock {
            for code in codes { membersByCode[code]?.removeAll { $0.isMe } }
            joined.removeAll()
        }
    }
}
#endif
