import XCTest

/// The 60–90 s walk-through CI records for Mark: home (Locked: the picked apps) → pray → Amen (open, relock time) →
/// Scroll the Word → pray for someone → circles → locked apps → progress. It writes rec.start / rec.stop into $QA_DIR so the recorder only keeps this part.
final class TapThroughTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func pause(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    func testTapThrough() {
        let app = launchDemo()
        let home = app.buttons["home.prayNow"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        pause(0.5)
        writeQAMarker("rec.start")
        // CI writes rec.ready once simctl says "Recording started", so the video opens on Home, not mid-prayer.
        _ = waitUntil(30) { qaMarkerExists("rec.ready") }
        pause(0.8)
        let started = Date()

        // Home: "Locked" with the picked apps' icons.
        XCTAssertTrue(app.descendants(matching: .any)["lock.icons"].firstMatch.waitForExistence(timeout: 5))
        pause(2.0)

        // Pray → Amen
        home.tap()
        pause(1.0)
        let next = app.buttons["session.next"]
        for _ in 0..<6 {
            if app.descendants(matching: .any)["amenButton"].exists { break }
            if next.waitForExistence(timeout: 3) { pause(0.8); next.tap() }
        }
        prayToAmen(app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10))
        pause(2.5)
        app.buttons["celebration.done"].tap()
        pause(1.0)

        // Scroll the Word
        app.tabBars.buttons["Scroll"].tap()
        pause(1.5)
        for _ in 0..<2 { app.swipeUp(); pause(1.2) }
        firstHittable(app.buttons.matching(identifier: "word.save"))?.tap()   // Share is covered by WordTests + the crawler
        pause(1.2)

        // Pray for someone
        app.tabBars.buttons["People"].tap()
        pause(1.5)
        let dad = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Dad'")).firstMatch
        XCTAssertTrue(dad.waitForExistence(timeout: 5))
        dad.tap()
        pause(1.5)
        let prayForHim = app.buttons["person.pray"]
        XCTAssertTrue(prayForHim.waitForExistence(timeout: 5))
        prayForHim.tap()
        pause(0.8)
        prayToAmen(app)
        if app.buttons["letknow.skip"].waitForExistence(timeout: 6) {
            pause(1.8)
            app.buttons["letknow.skip"].tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10))
        pause(1.8)
        app.buttons["celebration.done"].tap()
        pause(0.8)

        // Circles
        app.tabBars.buttons["Together"].tap()
        pause(1.5)
        let circle = app.descendants(matching: .any)["circle.row.K7Q2MX"]
        XCTAssertTrue(circle.waitForExistence(timeout: 6))
        circle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 6))
        pause(2.0)

        // Locked apps: Settings → Locked apps (Screen Time: the picked apps, Change apps, the 15-minute note).
        app.tabBars.buttons["Today"].tap()
        pause(1.0)
        app.buttons["home.settings"].tap()
        let locked = app.buttons["settings.lockedApps"]
        for _ in 0..<4 {
            if locked.waitForExistence(timeout: 2), locked.isHittable { break }
            app.swipeUp()
        }
        pause(1.0)
        locked.tap()
        XCTAssertTrue(app.descendants(matching: .any)["lock.title"].waitForExistence(timeout: 6))
        pause(1.5)
        let change = app.buttons["lock.choose"]
        if change.waitForExistence(timeout: 3), change.isHittable {
            change.tap()
            let done = app.buttons["lockpicker.done"]
            if done.waitForExistence(timeout: 5) {
                pause(1.2)
                app.buttons["lockpicker.row.snapchat"].tap()
                pause(1.0)
                done.tap()
            }
        }
        pause(1.5)
        // Back out of the pushed setup screen, then close Settings.
        let back = app.navigationBars.buttons["Settings"]   // the pushed screen's back button
        if back.exists, back.isHittable { back.tap(); pause(0.8) }
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 3) { done.tap() }
        pause(1.0)

        // Progress
        app.tabBars.buttons["Progress"].tap()
        pause(2.0)
        app.swipeUp()
        pause(2.0)
        let soFar = Date().timeIntervalSince(started)
        if soFar < 66 { app.swipeDown(); pause(66 - soFar) }
        writeQAMarker("rec.stop")
        pause(1.0)
        let duration = Date().timeIntervalSince(started)
        let note = XCTAttachment(string: String(format: "tap-through recorded %.0f s", duration))
        note.name = "tapthrough-duration"
        note.lifetime = .keepAlways
        add(note)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
