import XCTest

/// "Add someone" from Contacts and the one-press "Let them know" text, through the Debug-only demo address book
/// (DemoContacts: Dad, Danielle Brooks, David Kim, Mom…) and the demo Messages sheet (the simulator can't text).
final class ContactsFlowTests: XCTestCase {
    private var taps = 0

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        taps = 0
    }

    /// A counted tap, for the "how many taps to pray" checks.
    private func tap(_ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 8), "\(what) is on screen", file: file, line: line)
        element.tap()
        taps += 1
    }

    private func hasFocus(_ field: XCUIElement) -> Bool {
        (field.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    /// Types into a search box that should already be focused; taps it (counted) only if the keyboard didn't come up.
    private func type(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 8), "search box", file: file, line: line)
        if !waitUntil(3, { hasFocus(field) }) { tap(field, "search box", file: file, line: line) }
        field.typeText(text)
    }

    /// Mark (11-16): "add someone, then you import contacts… should be easy to pray." A new user, no one on the list:
    /// Home → "Pray for someone" → type "Da" → Dad → praying, in 3 taps or fewer. Then Amen → "Let Dad know" opens
    /// the Messages sheet with his number and the text filled in.
    func testHomeToPrayingForAContactInThreeTapsOrFewerThenOnePressText() {
        let app = launchDemo(["-noPeople"])
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 12), "Home")

        tap(app.buttons["home.quick.someone"], "Pray for someone")
        type("Da", into: app.textFields["chooser.search"])
        XCTAssertTrue(app.buttons["chooser.result.David Kim"].waitForExistence(timeout: 5), "type-ahead shows every Da…")
        XCTAssertFalse(app.buttons["chooser.result.Mom"].exists, "…and nobody else")
        tap(app.buttons["chooser.result.Dad"], "Dad")
        XCTAssertTrue(app.descendants(matching: .any)["session.styleLabel"].waitForExistence(timeout: 8), "praying for Dad")
        XCTAssertLessThanOrEqual(taps, 3, "Home → praying for a contact took \(taps) taps")

        prayToAmen(app)
        XCTAssertTrue(app.staticTexts["letknow.title"].waitForExistence(timeout: 10), "Let Dad know?")
        XCTAssertEqual(app.staticTexts["letknow.to"].label, "To (555) 010-0100", "his number came from Contacts")
        app.buttons["letknow.send"].tap()

        let to = app.staticTexts["demo.composer.to"]
        XCTAssertTrue(to.waitForExistence(timeout: 6), "one press asks for the Messages sheet")
        XCTAssertEqual(to.label, "To: (555) 010-0100")
        let body = app.staticTexts["demo.composer.body"].label
        XCTAssertTrue(body.hasPrefix("I just prayed for you 🙏"), body)
        XCTAssertTrue(body.contains("praytoscroll"), "the app's link: \(body)")
        XCTAssertFalse(body.contains("{"), "no placeholder left: \(body)")
        app.buttons["demo.composer.send"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10))

        // Dad stays on the prayer list, with his number, for next time.
        app.buttons["celebration.done"].tap()
        app.tabBars.buttons["People"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Dad'")).firstMatch.waitForExistence(timeout: 6))
    }

    /// People → + goes straight to the contacts with the search focused; a name → "Pray for Dad now" → praying.
    func testAddSomeoneGoesStraightToContactsThenPrayNow() {
        let app = launchDemo(["-noPeople"])
        app.tabBars.buttons["People"].tap()
        tap(app.buttons["people.add"], "Add someone")
        XCTAssertTrue(app.buttons["add.result.Mom"].waitForExistence(timeout: 6), "the contacts list, before typing")
        type("Da", into: app.textFields["add.search"])
        XCTAssertTrue(waitUntil(4) { !app.buttons["add.result.Mom"].exists }, "filtered to Da…")
        tap(app.buttons["add.result.Dad"], "Dad")
        let prayNow = app.buttons["add.prayNow"]
        XCTAssertTrue(prayNow.waitForExistence(timeout: 5), "Pray for Dad now")
        XCTAssertTrue(prayNow.label.contains("Pray for Dad now"), prayNow.label)
        tap(prayNow, "Pray for Dad now")
        XCTAssertTrue(app.descendants(matching: .any)["session.styleLabel"].waitForExistence(timeout: 10), "praying for Dad")
        XCTAssertLessThanOrEqual(taps, 4, "People → Add → Dad → Pray now")
    }

    /// Contacts turned off: no dead end. The system picker (no permission needed) and a typed name still work.
    func testWithContactsOffAddSomeoneOffersThePickerAndATypedName() {
        let app = launchDemo(["-noPeople", "-contacts", "denied"])
        app.tabBars.buttons["People"].tap()
        tap(app.buttons["people.add"], "Add someone")
        XCTAssertTrue(app.buttons["add.picker"].waitForExistence(timeout: 6), "Choose from Contacts")
        XCTAssertFalse(app.buttons["add.result.Dad"].exists, "nothing read from the address book")
        type("Aunt May", into: app.textFields["add.search"])
        tap(app.buttons["add.typed"], "Add “Aunt May”")
        XCTAssertTrue(app.buttons["add.prayNow"].waitForExistence(timeout: 5))
        app.buttons["add.close"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Aunt May'")).firstMatch.waitForExistence(timeout: 6))
    }
}
