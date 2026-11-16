import XCTest

/// Each destructive action on a fresh demo launch, checked end to end.
final class DestructiveTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testEraseAllDataStartsCompletelyFresh() {
        let app = launchDemo(["-route", "settings"])
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let erase = app.buttons.matching(NSPredicate(format: "label == 'Erase all data'")).firstMatch
        for _ in 0..<12 {
            if erase.exists, erase.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(erase.isHittable, "Erase all data is reachable in Settings")
        erase.tap()
        // The confirmation's button has the same title: tap the one that's on top now.
        let confirm = firstHittable(app.buttons.matching(NSPredicate(format: "label == 'Erase all data'")))
        XCTAssertNotNil(confirm, "erase asks for confirmation")
        confirm?.tap()
        XCTAssertTrue(app.buttons["onboarding.cta"].waitForExistence(timeout: 10), "back to a first-run welcome")
        finishOnboardingIfNeeded(app)
        XCTAssertEqual(app.state, .runningForeground)
        let streak = app.descendants(matching: .any)["home.streak"]
        if streak.exists { XCTAssertFalse(streak.label.contains("13"), "the streak is gone") }
        app.tabBars.buttons["People"].tap()
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sarah Mitchell'")).firstMatch.waitForExistence(timeout: 3),
                       "the prayer list is empty")
        app.tabBars.buttons["Scroll"].tap()
        XCTAssertEqual(savedCount(app), 0, "saved verses are erased too")
        app.tabBars.buttons["Together"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["circle.row.K7Q2MX"].waitForExistence(timeout: 3), "left every circle")
    }

    func testLeaveCircleRemovesItFromTheList() {
        let app = launchDemo(["-route", "circle"])
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 10))
        app.buttons["Circle options"].tap()
        let leave = app.buttons["Leave circle"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        leave.tap()
        let confirm = firstHittable(app.buttons.matching(NSPredicate(format: "label == 'Leave circle'")))
        XCTAssertNotNil(confirm, "leaving asks first")
        confirm?.tap()
        // Back on Together: the circles list ("New circle" carries `circles.create` there too).
        XCTAssertTrue(app.buttons["circles.create"].waitForExistence(timeout: 10), "back on Together")
        XCTAssertTrue(waitUntil(5) { !app.descendants(matching: .any)["circle.row.K7Q2MX"].exists }, "the circle is gone")
        XCTAssertTrue(app.descendants(matching: .any)["circle.row.R4NB8T"].waitForExistence(timeout: 5), "the other circle stays")
    }

    func testReportAndBlockHideMembers() {
        let app = launchDemo(["-route", "circle"])
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 10))
        let members = app.descendants(matching: .any).matching(identifier: "circle.member")
        XCTAssertTrue(members.firstMatch.waitForExistence(timeout: 5))
        let before = members.count
        XCTAssertGreaterThanOrEqual(before, 2)

        members.firstMatch.press(forDuration: 1.0)
        let report = app.buttons["Report"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        report.tap()
        let reason = app.buttons["Offensive name"]
        XCTAssertTrue(reason.waitForExistence(timeout: 5), "report reasons")
        reason.tap()
        XCTAssertTrue(waitUntil(6) { members.count == before - 1 }, "a reported member is hidden right away")

        members.firstMatch.press(forDuration: 1.0)
        let block = app.buttons["Block"]
        XCTAssertTrue(block.waitForExistence(timeout: 5))
        block.tap()
        XCTAssertTrue(waitUntil(6) { members.count == before - 2 }, "a blocked member is hidden")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
