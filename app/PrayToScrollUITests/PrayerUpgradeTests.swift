import XCTest

/// v1.1 prayer upgrades on the seeded demo: topic prayers, the date-gated Advent journey, circle prayer requests.
final class PrayerUpgradeTests: XCTestCase {
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

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    // MARK: Topics

    func testATopicChipPraysAboutThatTopicAndAnotherPromptStaysOnIt() {
        let app = launch(["-today", "2026-11-16"])
        let healing = app.buttons["home.topic.healing"]
        XCTAssertTrue(healing.waitForExistence(timeout: 10))
        healing.tap()
        let overline = element(app, "session.overline")
        XCTAssertTrue(overline.waitForExistence(timeout: 10))
        XCTAssertTrue(overline.label.localizedCaseInsensitiveContains("praying about healing"), overline.label)
        let prompt = element(app, "session.prompt")
        let first = prompt.label
        let another = app.buttons["session.anotherPrompt"]
        XCTAssertTrue(another.waitForExistence(timeout: 5))
        another.tap()
        expectation(for: NSPredicate(format: "label != %@", first), evaluatedWith: prompt)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(overline.label.localizedCaseInsensitiveContains("healing"), "another prompt keeps the topic")
        XCTAssertTrue(element(app, "amenButton").exists)
    }

    // MARK: Advent

    func testAdventShowsInSeasonAndPraysTodaysReading() {
        let app = launch(["-today", "2026-12-03"])
        let card = element(app, "advent.card")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["A Promise Kept"].exists, "Dec 3 is day 5")
        XCTAssertTrue(app.staticTexts["Jeremiah 33:14-15"].exists)
        app.buttons["advent.pray"].tap()
        let verse = element(app, "session.verse")
        XCTAssertTrue(verse.waitForExistence(timeout: 10))
        for _ in 0..<4 {
            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'waiting on God'")).firstMatch.exists { break }
            let next = app.buttons["session.next"]
            if next.waitForExistence(timeout: 3) { next.tap() }
        }
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'waiting on God'")).firstMatch.exists,
                      "the day's Advent prompt is the prayer step")
    }

    func testNoAdventOutsideItsDates() {
        let app = launch(["-today", "2026-11-28"])
        XCTAssertTrue(app.buttons["home.topic.healing"].waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "advent.card").exists, "Nov 28: not yet")
        app.terminate()
        let after = launch(["-today", "2026-12-25"])
        XCTAssertTrue(after.buttons["home.topic.healing"].waitForExistence(timeout: 10))
        XCTAssertFalse(element(after, "advent.card").exists, "Christmas Day: over")
    }

    // MARK: Circle prayer requests

    func testCircleRequestsPrayAskAndFilter() {
        let app = launch(["-route", "circle"])
        XCTAssertTrue(element(app, "circle.title").waitForExistence(timeout: 10))
        let request = element(app, "circle.request")
        XCTAssertTrue(request.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My grandma's surgery on Friday"].exists)

        // I prayed: once, and the button says so.
        let prayed = app.buttons["circle.request.prayed"].firstMatch
        XCTAssertTrue(prayed.waitForExistence(timeout: 5))
        prayed.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'You prayed'")).firstMatch.waitForExistence(timeout: 5))

        // Report is on every request (App Review 1.2).
        request.press(forDuration: 1.0)
        XCTAssertTrue(app.buttons["Report"].waitForExistence(timeout: 5))
        // Dismiss the menu with a tap at the top: the middle of the screen can land on "Pray for this now".
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        XCTAssertTrue(waitUntil(3) { !app.buttons["Report"].exists }, "the menu closed")

        // Ask: a link is refused, a plain line posts.
        app.buttons["Ask"].firstMatch.tap()
        let note = element(app, "ask.note")
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        app.buttons["ask.topic.work"].tap()
        note.tap()
        note.typeText("see mysite.com")
        XCTAssertTrue(element(app, "ask.problem").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["ask.post"].isEnabled)
        note.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        note.typeText(XCUIKeyboardKey.delete.rawValue)
        note.typeText("Job interview Thursday")
        XCTAssertTrue(app.buttons["ask.post"].isEnabled)
        app.buttons["ask.post"].tap()
        XCTAssertTrue(element(app, "circle.request.mine").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Job interview Thursday"].exists)
    }

    func testPrayNowOnARequestRecordsIPrayedAfterTheAmen() {
        let app = launch(["-route", "circle"])
        XCTAssertTrue(element(app, "circle.title").waitForExistence(timeout: 10))
        let prayNow = app.buttons["circle.request.prayNow"].firstMatch
        XCTAssertTrue(prayNow.waitForExistence(timeout: 5))
        prayNow.tap()
        let overline = element(app, "session.overline")
        XCTAssertTrue(overline.waitForExistence(timeout: 10))
        XCTAssertTrue(overline.label.localizedCaseInsensitiveContains("circle"), overline.label)
        let amen = element(app, "amenButton")
        expectation(for: NSPredicate(format: "value == ''"), evaluatedWith: amen)
        waitForExpectations(timeout: 10)
        amen.press(forDuration: 2.0)
        let done = app.buttons["celebration.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'You prayed'")).firstMatch.waitForExistence(timeout: 5),
                      "finishing the prayer marks the request")
    }
}
