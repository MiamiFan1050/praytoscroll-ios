import XCTest
@testable import PrayToScroll

/// @usernames: validation, the reserved list, case-insensitivity, atomic uniqueness and the 30-day change rule.
final class UsernameTests: XCTestCase {
    private let day: TimeInterval = 86_400

    func testValidHandlesPass() {
        for handle in ["mark", "grace_22", "abc", "a_b", "x1234567890123456789", "sam_p"] {
            XCTAssertNil(UsernameRules.problem(with: handle), handle)
        }
    }

    func testLengthAndCharacters() {
        XCTAssertEqual(UsernameRules.problem(with: "ab"), .tooShort)
        XCTAssertEqual(UsernameRules.problem(with: ""), .tooShort)
        XCTAssertEqual(UsernameRules.problem(with: String(repeating: "a", count: 21)), .tooLong)
        XCTAssertNil(UsernameRules.problem(with: String(repeating: "a", count: 20)))
        for bad in ["mark.m", "mark m", "mark-m", "márk", "mark!", "🙏pray", "grace@home"] {
            XCTAssertEqual(UsernameRules.problem(with: bad), .badCharacters, bad)
        }
    }

    func testCaseAndAtSignAreIgnored() {
        XCTAssertEqual(UsernameRules.normalize("  @Mark_Prays "), "mark_prays")
        XCTAssertEqual(UsernameRules.normalize("@@GRACE"), "grace")
        XCTAssertNil(UsernameRules.problem(with: "@Grace"))
    }

    func testReservedNames() {
        for name in ["admin", "Apple", "jesus", "GOD", "official", "support", "praytoscroll", "amenkey", "moderator"] {
            XCTAssertEqual(UsernameRules.problem(with: name), .reserved, name)
        }
        // Look-alikes of roles and the brand are reserved too.
        for name in ["pray_to_scroll", "j_e_s_u_s", "official_mark", "praytoscroll_help", "apple_support", "the_admin"] {
            XCTAssertEqual(UsernameRules.problem(with: name), .reserved, name)
        }
        XCTAssertEqual(UsernameRules.problem(with: "___"), .reserved, "underscores only")
        XCTAssertNil(UsernameRules.problem(with: "godfrey_k"), "only whole reserved names, not every name containing god")
    }

    func testTheNameFilterApplies() {
        XCTAssertEqual(UsernameRules.problem(with: "shit_happens"), .notAllowed)
        XCTAssertEqual(UsernameRules.problem(with: "sh1t_lord_x"), .notAllowed, "leetspeak")
        XCTAssertEqual(UsernameRules.problem(with: "porn4u"), .notAllowed)
        XCTAssertTrue(UsernameRules.isValid("grace_and_peace"))
    }

    func testANameCanBeClaimedOnceAndIsCaseInsensitive() {
        var ledger = UsernameLedger()
        let now = Date()
        XCTAssertEqual(ledger.claim("Grace", for: "a", now: now), .success("grace"))
        XCTAssertEqual(ledger.claim("grace", for: "b", now: now), .failure(.taken))
        XCTAssertEqual(ledger.claim("GRACE", for: "b", now: now), .failure(.taken))
        XCTAssertEqual(ledger.claim("@grace", for: "b", now: now), .failure(.taken))
        XCTAssertEqual(ledger.owner(of: "GrAcE"), "a")
        XCTAssertEqual(ledger.claim("grace", for: "a", now: now), .success("grace"), "re-saving your own name is fine")
        XCTAssertEqual(ledger.claim("admin", for: "b", now: now), .failure(.reserved))
        XCTAssertEqual(ledger.claim("no", for: "b", now: now), .failure(.tooShort))
        XCTAssertNil(ledger.owner(of: "admin"))
    }

    func testOneChangeEvery30DaysAndTheOldNameIsFreed() {
        var ledger = UsernameLedger()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(ledger.claim("mark", for: "me", now: start), .success("mark"))
        // Too soon: the date of the next allowed change comes back.
        let soon = start.addingTimeInterval(10 * day)
        XCTAssertEqual(ledger.claim("mark2", for: "me", now: soon), .failure(.tooSoon(start.addingTimeInterval(30 * day))))
        XCTAssertEqual(ledger.handle(of: "me"), "mark")
        XCTAssertNil(ledger.owner(of: "mark2"))
        // After 30 days: the change works and "mark" is free for someone else.
        let later = start.addingTimeInterval(31 * day)
        XCTAssertEqual(ledger.claim("mark2", for: "me", now: later), .success("mark2"))
        XCTAssertNil(ledger.owner(of: "mark"))
        XCTAssertEqual(ledger.claim("mark", for: "other", now: later), .success("mark"))
        XCTAssertEqual(ledger.handle(of: "me"), "mark2")
        // And the next change is 30 days after that one.
        XCTAssertEqual(UsernameRules.nextChange(after: later, now: later.addingTimeInterval(day)), later.addingTimeInterval(30 * day))
        XCTAssertNil(UsernameRules.nextChange(after: later, now: later.addingTimeInterval(30 * day + 1)))
        XCTAssertNil(UsernameRules.nextChange(after: nil))
    }

    func testReleasingFreesTheName() {
        var ledger = UsernameLedger()
        _ = ledger.claim("grace", for: "a")
        ledger.release(memberID: "a")
        XCTAssertNil(ledger.owner(of: "grace"))
        XCTAssertEqual(ledger.claim("grace", for: "b"), .success("grace"))
    }

    func testProfileLinks() {
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://u/Grace")!), .user(handle: "grace"))
        XCTAssertEqual(DeepLink(url: URL(string: "https://praytoscroll.vercel.app/u/sam_p")!), .user(handle: "sam_p"))
        XCTAssertEqual(DeepLink(url: URL(string: "https://praytoscroll.vercel.app/u?n=%40hannah_b")!), .user(handle: "hannah_b"))
        XCTAssertNil(DeepLink(url: URL(string: "prayscroll://u/no")!), "too short")
        XCTAssertNil(DeepLink(url: URL(string: "prayscroll://u/bad.name")!))
        XCTAssertEqual(AppLinks.profileWebURL(handle: "grace").path, "/u/grace")
        XCTAssertEqual(AppLinks.profileDeepLink(handle: "grace").absoluteString, "prayscroll://u/grace")
    }

    func testFriendPrayedToday() {
        let today = DayKey(Date()).string
        let friend = FriendProfile(memberID: "x", handle: "grace", displayName: "Grace", emoji: "🌿", streak: 3, lastPrayedDay: today)
        XCTAssertTrue(friend.prayedToday())
        XCTAssertEqual(friend.atHandle, "@grace")
        var old = friend
        old.lastPrayedDay = "2020-01-01"
        XCTAssertFalse(old.prayedToday())
    }
}
