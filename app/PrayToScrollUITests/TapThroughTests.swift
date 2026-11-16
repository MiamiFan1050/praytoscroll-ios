import XCTest

/// The 60–90 s walk-through CI records for Mark: home → pray → Amen → Scroll the Word → pray for someone →
/// circles → gate setup → progress. It writes rec.start / rec.stop into $QA_DIR so the recorder only keeps this part.
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
        pause(1.0)
        writeQAMarker("rec.start")
        pause(2.0)   // the recorder starts up
        let started = Date()

        // Home
        pause(2.5)
        app.swipeUp()
        pause(1.5)
        app.swipeDown()
        pause(1.0)

        // Pray → Amen
        home.tap()
        pause(1.5)
        let next = app.buttons["session.next"]
        for _ in 0..<6 where !app.descendants(matching: .any)["amenButton"].exists {
            if next.waitForExistence(timeout: 3) { pause(1.2); next.tap() }
        }
        prayToAmen(app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10))
        pause(3.5)
        app.buttons["celebration.done"].tap()
        pause(1.5)

        // Scroll the Word
        app.tabBars.buttons["Scroll"].tap()
        pause(2.5)
        for _ in 0..<3 { app.swipeUp(); pause(1.6) }
        firstHittable(app.buttons.matching(identifier: "word.save"))?.tap()
        pause(1.5)
        firstHittable(app.buttons.matching(NSPredicate(format: "label == 'Share'")))?.tap()
        if app.buttons["Close"].waitForExistence(timeout: 5) {
            pause(2.5)
            app.buttons["Close"].tap()
        }
        pause(1.0)

        // Pray for someone
        app.tabBars.buttons["People"].tap()
        pause(2.0)
        let dad = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Dad'")).firstMatch
        XCTAssertTrue(dad.waitForExistence(timeout: 5))
        dad.tap()
        pause(2.0)
        let prayForHim = app.buttons["person.pray"]
        XCTAssertTrue(prayForHim.waitForExistence(timeout: 5))
        prayForHim.tap()
        pause(1.0)
        prayToAmen(app)
        if app.buttons["letknow.skip"].waitForExistence(timeout: 6) {
            pause(2.5)
            app.buttons["letknow.skip"].tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10))
        pause(2.5)
        app.buttons["celebration.done"].tap()
        pause(1.0)

        // Circles
        app.tabBars.buttons["Together"].tap()
        pause(2.0)
        let circle = app.descendants(matching: .any)["circle.row.K7Q2MX"]
        XCTAssertTrue(circle.waitForExistence(timeout: 6))
        circle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["circle.title"].waitForExistence(timeout: 6))
        pause(3.0)
        app.swipeUp()
        pause(1.5)

        // Gate setup (long-press the gate card on Today → Gate setup)
        app.tabBars.buttons["Today"].tap()
        pause(1.5)
        let gateCard = app.descendants(matching: .any)["home.gateStatus"].firstMatch
        XCTAssertTrue(gateCard.waitForExistence(timeout: 5))
        gateCard.press(forDuration: 1.2)
        let setup = app.buttons["Gate setup"]
        if setup.waitForExistence(timeout: 4) {
            pause(1.0)
            setup.tap()
        } else {
            app.buttons["home.settings"].tap()
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Prayer Gate'")).firstMatch.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["gate.title"].waitForExistence(timeout: 6))
        pause(3.0)
        let instagram = app.descendants(matching: .any)["gate.row.instagram"]
        if instagram.waitForExistence(timeout: 3), instagram.isHittable {
            instagram.tap()
            let guide = app.buttons["guide.next"]
            if guide.waitForExistence(timeout: 5) {
                for _ in 0..<3 { pause(1.6); if guide.exists, guide.isHittable { guide.tap() } }
                pause(1.2)
                if app.buttons["Close"].exists { app.buttons["Close"].tap() }
            }
        }
        pause(1.0)
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        pause(1.2)

        // Progress
        app.tabBars.buttons["Progress"].tap()
        pause(2.5)
        app.swipeUp()
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
