import XCTest

/// App Store screenshots from the seeded `-demo` launch (the demo person is Grace, @gracepray). Each screen is attached to the test result as
/// "NN-name" (lifetime .keepAlways) and, when SCREENSHOT_DIR is set (pass TEST_RUNNER_SCREENSHOT_DIR to
/// xcodebuild), also written there as a PNG. Run: tools/screenshots.sh
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// `fastTimers` (-uitest) shortens prayer minimums; screens that show the countdown run with real timers.
    private func launch(route: String? = nil, fastTimers: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-appearance", "dark"] + (fastTimers ? ["-uitest"] : []) + extra
        if let route { app.launchArguments += ["-route", route] }
        app.launch()
        return app
    }

    private func snap(_ name: String, settle: TimeInterval = 1.2) {
        // Let springs and fades finish so the shot isn't mid-animation.
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: url)
        }
    }

    private func waitFor(_ element: XCUIElement, _ timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "missing \(element)", file: file, line: line)
    }

    func test01Home() {
        let app = launch()
        waitFor(app.buttons["home.prayNow"])
        snap("01-home")
    }

    func test02GatePrayer() {
        let app = launch(route: "gatepray", fastTimers: false)
        waitFor(app.descendants(matching: .any)["session.prompt"])
        snap("02-prayer", settle: 2)
    }

    func test03Amen() {
        let app = launch(route: "quick")
        let amen = app.descendants(matching: .any)["amenButton"]
        waitFor(amen)
        // The Amen button unlocks after the (shortened, -uitest) minimum prayer time.
        let enabled = NSPredicate(format: "value == ''")
        expectation(for: enabled, evaluatedWith: amen)
        waitForExpectations(timeout: 10)
        amen.press(forDuration: 2.0)
        waitFor(app.descendants(matching: .any)["celebration.title"])
        snap("03-amen", settle: 2.5)
    }

    func test04ScrollTheWord() {
        let app = launch(route: "word")
        waitFor(app.descendants(matching: .any)["word.feed"])
        snap("04-word", settle: 1.8)
    }

    func test05PrayerList() {
        let app = launch(route: "people")
        waitFor(app.descendants(matching: .any)["people.segment"])
        snap("05-people")
    }

    func test06AnsweredWall() {
        let app = launch(route: "answered")
        waitFor(app.descendants(matching: .any)["answered.count"])
        snap("06-answered")
    }

    func test07CircleLeaderboard() {
        let app = launch(route: "circle")
        waitFor(app.descendants(matching: .any)["circle.title"])
        // Prayer requests sit above the board: scroll until the whole podium is clear of the tab bar.
        let podium = app.descendants(matching: .any)["circle.podium"]
        waitFor(podium)
        let tabBar = app.tabBars.firstMatch
        let bottom = (tabBar.exists ? tabBar.frame.minY : app.frame.maxY - 120) - 16
        let window = app.windows.firstMatch
        for _ in 0..<6 where podium.frame.maxY > bottom {
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
        XCTAssertLessThanOrEqual(podium.frame.maxY, bottom, "the podium sits above the tab bar")
        snap("07-circle", settle: 1.8)
    }

    #if STRICT_LOCK
    func test08LockedApps() {
        let app = launch(route: "lock")
        waitFor(app.descendants(matching: .any)["lock.title"])
        snap("08-lock")
    }
    #else
    func test08GateSetup() {
        let app = launch(route: "gate")
        waitFor(app.descendants(matching: .any)["gate.title"])
        snap("08-gate")
    }
    #endif

    func test09Streak() {
        let app = launch(route: "stats")
        waitFor(app.descendants(matching: .any)["stats.streak"])
        snap("09-streak")
    }

    func test10PrayForSomeone() {
        let app = launch(route: "someone")
        waitFor(app.descendants(matching: .any)["session.prompt"])
        snap("10-someone", settle: 2)
    }

    /// A Finish the verse card after a pick: the right ending marked and the whole verse shown.
    func test11FinishTheVerse() {
        let app = launch(route: "word", extra: ["-wordCard", "finish"])
        waitFor(app.descendants(matching: .any)["word.finish"])
        let choice = { (app: XCUIApplication, index: Int) in app.buttons["word.finish.choice.\(index)"] }
        let labels = (0..<3).map { choice(app, $0).label }
        choice(app, 0).tap()
        waitFor(app.descendants(matching: .any)["word.finish.result"])
        let right = (0..<3).first { (choice(app, $0).value as? String) == "Right answer" }
        if let right, right != 0 {
            // Show the right ending being picked: the demo opens on the same card each launch, so pick it there.
            app.terminate()
            let again = launch(route: "word", extra: ["-wordCard", "finish"])
            waitFor(again.descendants(matching: .any)["word.finish"])
            let target = (0..<3).first { choice(again, $0).label == labels[right] } ?? right
            choice(again, target).tap()
            waitFor(again.descendants(matching: .any)["word.finish.result"])
        }
        snap("11-finish", settle: 1.5)
    }

    /// Not a store shot: the home-screen icon + "Pray to Scroll" label, to check it isn't truncated.
    func test99HomeScreenLabel() {
        let app = launch()
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons["Pray to Scroll"]
        XCTAssertTrue(icon.waitForExistence(timeout: 10))
        for _ in 0..<4 where !icon.isHittable {
            springboard.swipeLeft()
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        }
        snap("99-home-label")
    }
}
