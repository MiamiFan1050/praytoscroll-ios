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

    func testUnlockForPickerThenAmenChoicesThenHomeShowsTheWindow() {
        let app = launch(["-route", "settings"])
        let unlockFor = app.buttons["settings.unlockFor"]
        for _ in 0..<6 where !unlockFor.isHittable { app.swipeUp() }
        XCTAssertTrue(unlockFor.waitForExistence(timeout: 10))
        unlockFor.tap()
        XCTAssertTrue(app.buttons["unlockFor.m5"].waitForExistence(timeout: 5), "5 min in Shortcuts mode")
        app.buttons["unlockFor.m45"].tap()
        XCTAssertTrue(app.buttons["unlockFor.m45"].isSelected)
        app.buttons["unlockFor.custom"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["unlock.customStepper"].waitForExistence(timeout: 3))
        app.buttons["unlockFor.m45"].tap()
        let ask = app.switches["unlock.askEachTime"]
        XCTAssertTrue(ask.waitForExistence(timeout: 3))
        ask.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()   // back to Settings
        app.buttons["Done"].firstMatch.tap()

        let pray = app.buttons["home.prayNow"]
        XCTAssertTrue(pray.waitForExistence(timeout: 10))
        pray.tap()
        for _ in 0..<6 {
            if app.descendants(matching: .any)["amenButton"].exists { break }
            let next = app.buttons["session.next"]
            if next.waitForExistence(timeout: 3) { next.tap() }
        }
        sayAmen(in: app)
        let choices = app.descendants(matching: .any)["celebration.unlockChoices"]
        XCTAssertTrue(choices.waitForExistence(timeout: 10), "Ask me after each prayer shows the lengths")
        XCTAssertTrue(app.buttons["unlock.m45"].isSelected, "the default is preselected")
        app.buttons["unlock.m120"].tap()
        XCTAssertTrue(app.staticTexts["Unlocked for 2 h"].waitForExistence(timeout: 5))
        let done = app.buttons["celebration.done"]
        for _ in 0..<4 where !done.isHittable { app.swipeUp() }
        done.tap()
        let status = app.descendants(matching: .any)["home.gateStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("1:59:") || status.label.contains("2:00:"), "Home counts down the 2 h picked: \(status.label)")
    }

    func testUnlockWithDevotionalShowsTheReadingThenAmen() {
        let app = launch(["-route", "settings"])
        let unlockWith = app.buttons["settings.unlockWith"]
        for _ in 0..<6 where !unlockWith.isHittable { app.swipeUp() }
        XCTAssertTrue(unlockWith.waitForExistence(timeout: 10))
        unlockWith.tap()
        XCTAssertTrue(app.buttons["unlockWith.prayer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["unlockWith.prayer"].isSelected, "Prayer is the default")
        app.buttons["unlockWith.devotional"].tap()
        XCTAssertTrue(app.buttons["unlockWith.devotional"].isSelected)
        app.navigationBars.buttons.element(boundBy: 0).tap()   // back to Settings
        app.buttons["Done"].firstMatch.tap()

        let pray = app.buttons["home.prayNow"]
        XCTAssertTrue(pray.waitForExistence(timeout: 10))
        pray.tap()
        XCTAssertTrue(app.staticTexts["reading.title"].waitForExistence(timeout: 10), "a devotional, not a prayer prompt")
        XCTAssertTrue(app.staticTexts["reading.ref"].exists)
        XCTAssertTrue(app.staticTexts["reading.body"].exists)
        let prayer = app.staticTexts["reading.prayer"]
        for _ in 0..<4 where !prayer.isHittable { app.swipeUp() }
        XCTAssertTrue(prayer.label.hasSuffix("Amen."), "ends with its one-line prayer")
        sayAmen(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10),
                      "a devotional completes like a prayer")
    }

    func testGateScreenLetsYouPickHowToUnlockWhenAskIsOn() {
        let app = launch(["-route", "gateask"])
        let devotional = app.buttons["session.method.devotional"]
        XCTAssertTrue(devotional.waitForExistence(timeout: 10), "Ask me after each prayer offers the method on the gate screen")
        XCTAssertTrue(app.buttons["session.method.prayer"].isSelected)
        devotional.tap()
        XCTAssertTrue(app.staticTexts["reading.title"].waitForExistence(timeout: 5))
        app.buttons["session.method.verse"].tap()
        XCTAssertTrue(app.staticTexts["reading.ref"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["reading.title"].exists, "a verse has no devotional title")
        XCTAssertTrue(app.buttons["session.method.verse"].isSelected)
        sayAmen(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.unlockChoices"].waitForExistence(timeout: 10))
    }

    func testTheAllAppsAutomationOffersEveryAppAfterTheAmen() {
        let app = launch(["-route", "gateany"])
        sayAmen(in: app)
        XCTAssertTrue(app.buttons["celebration.backTo.instagram"].waitForExistence(timeout: 10),
                      "one automation can't say which app opened, so each gated app is offered")
        XCTAssertTrue(app.buttons["celebration.backTo.tiktok"].exists)
        XCTAssertTrue(app.buttons["celebration.done"].exists)
    }

    func testDeepLinkJoinOpensTogether() {
        let app = launch([])
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 10))
        app.open(URL(string: "prayscroll://join?c=R4NB8T")!)
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 10)
                      || app.descendants(matching: .any)["circle.nickname"].waitForExistence(timeout: 5))
    }
}
