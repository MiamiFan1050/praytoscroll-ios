import XCTest
@testable import PrayToScroll

/// v1.1 "Invite from contacts": the prefilled text.
final class FriendInviteTests: XCTestCase {
    func testTheInviteNamesYouAndLinksYourProfile() {
        let text = FriendInvite.message(handle: "Faith_Walker")
        XCTAssertTrue(text.contains("@faith_walker"), text)
        XCTAssertTrue(text.hasSuffix(AppLinks.profileWebURL(handle: "faith_walker").absoluteString), text)
        XCTAssertTrue(text.contains("/u/faith_walker"), text)
        XCTAssertFalse(text.contains("{") || text.contains("}"), text)
        XCTAssertLessThanOrEqual(text.count, 200)
    }
}
