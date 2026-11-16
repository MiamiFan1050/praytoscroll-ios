import XCTest

/// Functional UI checks on the seeded demo (fast: -uitest shortens the prayer minimums).
final class FlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-uitest"] + extra
        app.launch()
        return app
    }

    private func sayAmen(in app: XCUIApplication) {
        let amen = app.descendants(matching: .any)["amenButton"]
        XCTAssertTrue(amen.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value == ''"), evaluatedWith: amen)
        waitForExpectations(timeout: 10)
        amen.press(forDuration: 2.0)
    }

    func testQuickPrayerUnlocksAndCelebrates() {
        let app = launch([])
        let pray = app.buttons["home.prayNow"]
        XCTAssertTrue(pray.waitForExistence(timeout: 10))
        pray.tap()
        // Home's Pray now uses the person's style (guided in the demo): step through to the Amen.
        for _ in 0..<6 {
            if app.descendants(matching: .any)["amenButton"].exists { break }
            let next = app.buttons["session.next"]
            if next.waitForExistence(timeout: 3) { next.tap() }
        }
        sayAmen(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10))
        let done = app.buttons["celebration.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(pray.waitForExistence(timeout: 10), "back home after the celebration")
    }

    func testAmenStaysLockedUntilTheMinimumTime() {
        let app = launch(["-route", "quick", "-longMinimum"])
        let amen = app.descendants(matching: .any)["amenButton"]
        XCTAssertTrue(amen.waitForExistence(timeout: 10))
        XCTAssertNotEqual(amen.value as? String ?? "", "", "Amen starts disabled")
        amen.press(forDuration: 1.5)
        XCTAssertFalse(app.descendants(matching: .any)["celebration.title"].exists)
    }

    func testOnboardingStartsAndAdvances() {
        let app = launch(["-onboarding"])
        let cta = app.buttons["onboarding.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.headline"].exists)
        cta.tap()
        XCTAssertTrue(app.buttons["onboarding.back"].waitForExistence(timeout: 5), "moved past the welcome screen")
    }

    func testCircleLeaderboardShowsMeAndReportMenu() {
        let app = launch(["-route", "circle"])
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["circle.me"].firstMatch.waitForExistence(timeout: 5))
        let member = app.descendants(matching: .any)["circle.member"].firstMatch
        XCTAssertTrue(member.exists)
        member.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Report"].waitForExistence(timeout: 5) || app.buttons["Report…"].exists,
                      "App Review 1.2: members can be reported")
    }

    func testAddAnotherAppBySearchShowsItInTheList() {
        let app = launch(["-route", "gate"])
        let edit = app.buttons["Edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        let addAnother = app.buttons["apps.addAnother"]
        XCTAssertTrue(addAnother.waitForExistence(timeout: 10))
        addAnother.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("disc")
        let discord = app.buttons["addApp.discord"]
        XCTAssertTrue(discord.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'scheme'")).firstMatch.exists,
                       "never asks for a URL scheme")
        discord.tap()
        let added = app.buttons["app.discord"]
        XCTAssertTrue(added.waitForExistence(timeout: 5), "Discord shows up in the list")
        XCTAssertTrue(added.isSelected, "and is gated")
    }

    func testDeepLinkJoinOpensTogether() {
        let app = launch([])
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 10))
        app.open(URL(string: "prayscroll://join?c=R4NB8T")!)
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 10)
                      || app.descendants(matching: .any)["circle.nickname"].waitForExistence(timeout: 5))
    }
}
