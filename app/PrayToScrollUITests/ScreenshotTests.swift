import XCTest

/// App Store screenshots from the seeded `-demo` launch. Each screen is attached to the test result as
/// "NN-name" (lifetime .keepAlways) and, when SCREENSHOT_DIR is set (pass TEST_RUNNER_SCREENSHOT_DIR to
/// xcodebuild), also written there as a PNG. Run: tools/screenshots.sh
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(route: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-uitest", "-appearance", "dark"] + extra
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
        let app = launch(route: "gatepray")
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
        snap("07-circle", settle: 1.8)
    }

    func test08GateSetup() {
        let app = launch(route: "gate")
        waitFor(app.descendants(matching: .any)["gate.title"])
        snap("08-gate")
    }

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
}
