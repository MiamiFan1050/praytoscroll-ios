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

    /// v1.1 Strict Lock: onboarding asks for Screen Time, shows the app picker (DemoLock stands in for Apple's in
    /// Debug), the picked apps' icons appear, the Shortcuts setup step is skipped and Home shows "Locked" with them.
    func testOnboardingPicksAppsToLockWithScreenTime() {
        let app = launch(["-onboarding", "-noMotion"])
        let cta = app.buttons["onboarding.cta"]
        let secondary = app.buttons["onboarding.secondary"]
        let headline = app.descendants(matching: .any)["onboarding.headline"].firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 10))

        func step() {
            let opensSomething = ["prayer", "Show me how", "Start praying"].contains { cta.label.contains($0) }
            if cta.exists, cta.isEnabled, cta.isHittable, !(opensSomething && secondary.exists) {
                cta.tap()
            } else if secondary.exists, secondary.isHittable {
                secondary.tap()
            }
            Thread.sleep(forTimeInterval: 0.8)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for label in ["Allow", "Don’t Allow", "Don't Allow"] where springboard.alerts.buttons[label].exists {
                springboard.alerts.buttons[label].tap()
                break
            }
        }

        // To "Which apps pull you in?"
        for _ in 0..<10 where !(headline.exists && headline.label.contains("Which apps")) { step() }
        XCTAssertTrue(headline.label.contains("Which apps"), "reached the app step")
        XCTAssertEqual(cta.label, "Choose apps")
        XCTAssertEqual(secondary.label, "Use Shortcuts instead", "the Shortcuts gate stays as the fallback")

        // Allow Screen Time → Apple's picker (the demo stand-in) → pick TikTok and Instagram.
        cta.tap()
        let done = app.buttons["lockpicker.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 8), "the app picker opens")
        app.buttons["lockpicker.row.tiktok"].tap()
        app.buttons["lockpicker.row.instagram"].tap()
        done.tap()
        let icons = app.descendants(matching: .any)["lock.icons"].firstMatch
        XCTAssertTrue(icons.waitForExistence(timeout: 5), "the picked apps' icons show")
        XCTAssertTrue(icons.label.contains("TikTok") && icons.label.contains("Instagram"), icons.label)
        XCTAssertTrue(waitUntil(5) { cta.label == "Continue" })

        // Onward to Home: the Shortcuts setup page never appears.
        var sawShortcutsSetup = false
        for _ in 0..<12 where !app.buttons["home.prayNow"].exists {
            if headline.exists, headline.label.contains("Set up your Prayer Gate") { sawShortcutsSetup = true }
            if app.buttons["lockpicker.done"].exists { app.buttons["lockpicker.done"].tap() }
            step()
        }
        XCTAssertFalse(sawShortcutsSetup, "Screen Time needs no Shortcuts setup")
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 8), "reached Home")
        let status = app.descendants(matching: .any)["home.gateStatus"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let homeIcons = app.descendants(matching: .any)["lock.icons"].firstMatch
        XCTAssertTrue(homeIcons.waitForExistence(timeout: 5), "Home shows Locked: [the picked apps]")
        XCTAssertTrue(homeIcons.label.contains("TikTok"), homeIcons.label)
    }

    /// Settings → Locked apps shows what's locked and the 15-minute note; the window choices start at 15.
    func testLockedAppsScreenShowsThePickedApps() {
        let app = launch(["-route", "lock"])
        XCTAssertTrue(app.descendants(matching: .any)["lock.title"].waitForExistence(timeout: 10))
        let icons = app.descendants(matching: .any)["lock.icons"].firstMatch
        XCTAssertTrue(icons.waitForExistence(timeout: 5))
        XCTAssertTrue(icons.label.contains("TikTok"), icons.label)
        XCTAssertTrue(app.buttons["lock.choose"].exists, "apps can be changed")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '15 minutes'")).firstMatch.exists,
                      "the 15-minute minimum is said in the UI")
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

    func testDeepLinkJoinOpensTogether() {
        let app = launch([])
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 10))
        app.open(URL(string: "prayscroll://join?c=R4NB8T")!)
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 10)
                      || app.descendants(matching: .any)["circle.nickname"].waitForExistence(timeout: 5))
    }
}
