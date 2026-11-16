import XCTest

/// Shared helpers for the QA tests (crawler, destructive, Scroll the Word, tap-through).
extension XCTestCase {
    func launchDemo(_ extra: [String] = [], fast: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-appearance", "dark"] + (fast ? ["-uitest"] : []) + extra
        app.launch()
        return app
    }

    /// The first match that's on screen right now (feeds keep neighbouring cards in the hierarchy).
    func firstHittable(_ query: XCUIElementQuery, timeout: TimeInterval = 8) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let hit = query.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) { return hit }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        return nil
    }

    func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return condition()
    }

    /// Steps a session to the Amen, waits for it to unlock and holds it.
    func prayToAmen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let amen = app.descendants(matching: .any)["amenButton"]
        let next = app.buttons["session.next"]
        let verse = app.descendants(matching: .any)["session.verse"]
        // A `for … where` keeps iterating (and querying an animating screen) after the Amen appears; stop at once.
        for _ in 0..<16 {
            if amen.waitForExistence(timeout: 1.0) { break }
            if next.exists, next.isHittable {
                next.tap()                       // Next step / "Pray it"
            } else if verse.exists, verse.isHittable {
                verse.tap()                      // verse + prayer: reveal the next line
            }
        }
        XCTAssertTrue(amen.waitForExistence(timeout: 10), "Amen button", file: file, line: line)
        XCTAssertTrue(waitUntil(60) { (amen.value as? String ?? "x") == "" }, "Amen unlocks after the minimum", file: file, line: line)
        amen.press(forDuration: 2.0)
    }

    /// Finishes onboarding the quickest honest way (Skip / Not now when offered, else Continue).
    func finishOnboardingIfNeeded(_ app: XCUIApplication) {
        let home = app.buttons["home.prayNow"]
        for _ in 0..<20 {
            if home.waitForExistence(timeout: 1.5) { return }
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for label in ["Don’t Allow", "Don't Allow"] where springboard.alerts.buttons[label].exists {
                springboard.alerts.buttons[label].tap()
            }
            let secondary = app.buttons["onboarding.secondary"]
            let cta = app.buttons["onboarding.cta"]
            if secondary.exists, secondary.isHittable {
                secondary.tap()
            } else if cta.exists, cta.isHittable, cta.isEnabled {
                cta.tap()
            }
            Thread.sleep(forTimeInterval: 0.8)
        }
        XCTAssertTrue(home.waitForExistence(timeout: 5), "onboarding reaches Home")
    }

    /// "Saved verses, 9" → 9
    func savedCount(_ app: XCUIApplication) -> Int? {
        let saved = app.buttons["word.saved"]
        guard saved.waitForExistence(timeout: 8) else { return nil }
        return saved.label.split(separator: ",").last.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// The verse card on screen in Scroll the Word ("<text>. <ref>").
    func visibleVerse(_ app: XCUIApplication) -> String? {
        let refPattern = "(?s).*\\. (1 |2 |3 )?[A-Z][A-Za-z ]+ [0-9]+:[0-9]+(-[0-9]+)?$"
        let cards = app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", refPattern))
        return firstHittable(cards, timeout: 4)?.label
    }

    func writeQAMarker(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["QA_DIR"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? Date().description.write(to: url, atomically: true, encoding: .utf8)
    }

    /// True once the host (CI) has written `name` into $QA_DIR; true at once when there is no QA_DIR (local runs).
    func qaMarkerExists(_ name: String) -> Bool {
        guard let dir = ProcessInfo.processInfo.environment["QA_DIR"], !dir.isEmpty else { return true }
        return FileManager.default.fileExists(atPath: URL(fileURLWithPath: dir).appendingPathComponent(name).path)
    }
}
