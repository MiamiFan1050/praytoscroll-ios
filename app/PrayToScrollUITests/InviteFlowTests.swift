import XCTest

/// v1.1 Friends → "Invite from contacts": one person at a time, Messages opens with their number and your
/// /u/<handle> link, and you tap Send yourself (the Debug demo address book + demo Messages sheet).
final class InviteFlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testInviteOneContactWithAPrefilledTextYouSendYourself() {
        let app = launchDemo(["-route", "friends"])
        let handle = app.staticTexts["friends.myHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 10), "my @username")
        let invite = app.buttons["friends.invite"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5))
        invite.tap()

        let search = app.textFields["invite.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 6))
        if !waitUntil(3, { (search.value(forKey: "hasKeyboardFocus") as? Bool) ?? false }) { search.tap() }
        search.typeText("Da")
        let dad = app.buttons["invite.contact.Dad"]
        XCTAssertTrue(dad.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["invite.contact.Mom"].exists, "type-ahead filters")
        dad.tap()

        let to = app.staticTexts["demo.composer.to"]
        XCTAssertTrue(to.waitForExistence(timeout: 6), "Messages opens for one person")
        XCTAssertEqual(to.label, "To: (555) 010-0100")
        let body = app.staticTexts["demo.composer.body"].label
        let me = handle.label.replacingOccurrences(of: "@", with: "")
        XCTAssertTrue(body.contains("@\(me)"), body)
        XCTAssertTrue(body.contains("/u/\(me)"), "the profile link: \(body)")
        app.buttons["demo.composer.send"].tap()

        XCTAssertTrue(waitUntil(5) { dad.label.contains("Invited") }, "marked after they tapped Send: \(dad.label)")
        app.buttons["invite.done"].tap()
        XCTAssertTrue(invite.waitForExistence(timeout: 5))
    }
}
