import XCTest

/// Scroll the Word: the feed swipes, and Save / Share / Pray this work; saves survive a relaunch.
final class WordTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testFeedSwipesThroughDifferentVerses() {
        let app = launchDemo(["-route", "word"])
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 10))
        var seen: [String] = []
        let first = visibleVerse(app)
        XCTAssertNotNil(first, "a verse card is on screen")
        seen.append(first ?? "")
        for _ in 0..<4 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1.0)
            let verse = visibleVerse(app) ?? "(prompt card)"
            seen.append(verse)
        }
        XCTAssertEqual(Set(seen).count, seen.count, "each swipe shows a new card: \(seen)")
        app.swipeDown()
        Thread.sleep(forTimeInterval: 1.0)
        let back = visibleVerse(app) ?? "(prompt card)"
        XCTAssertTrue(seen.dropLast().contains(back), "swiping back returns to an earlier card: \(back)")
    }

    func testSaveSharePrayThis() {
        let app = launchDemo(["-route", "word"])
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 10))
        let start = savedCount(app)
        XCTAssertEqual(start, 9, "the demo's saved verses")

        let save = firstHittable(app.buttons.matching(identifier: "word.save"))
        XCTAssertNotNil(save)
        save?.tap()
        XCTAssertTrue(waitUntil(4) { self.savedCount(app) == 10 }, "Save adds it")
        firstHittable(app.buttons.matching(identifier: "word.save"))?.tap()
        XCTAssertTrue(waitUntil(4) { self.savedCount(app) == 9 }, "tapping again un-saves")
        firstHittable(app.buttons.matching(identifier: "word.save"))?.tap()
        XCTAssertTrue(waitUntil(4) { self.savedCount(app) == 10 })

        app.buttons["word.saved"].tap()
        XCTAssertTrue(app.navigationBars["Saved verses"].waitForExistence(timeout: 5), "the saved list opens")
        app.buttons["Done"].tap()

        let share = firstHittable(app.buttons.matching(NSPredicate(format: "label == 'Share'")))
        XCTAssertNotNil(share)
        share?.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5), "the share card opens")
        app.buttons["Close"].tap()

        let pray = firstHittable(app.buttons.matching(identifier: "word.pray"))
        XCTAssertNotNil(pray)
        pray?.tap()
        XCTAssertTrue(app.descendants(matching: .any)["session.styleLabel"].waitForExistence(timeout: 8), "Pray this starts a prayer")
        prayToAmen(app)
        XCTAssertTrue(app.descendants(matching: .any)["celebration.title"].waitForExistence(timeout: 10))
        app.buttons["celebration.done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 8), "back in the feed")
    }

    /// The verse card on screen (label "<text>. <ref>", value = its topic).
    private func visibleCard(_ app: XCUIApplication) -> XCUIElement? {
        let refPattern = "(?s).*\\. (1 |2 |3 )?[A-Z][A-Za-z ]+ [0-9]+:[0-9]+(-[0-9]+)?$"
        return firstHittable(app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", refPattern)), timeout: 4)
    }

    func testTopicFeedsShowOnlyThatTopic() {
        let app = launchDemo(["-route", "word"])
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 10))
        let anxiety = app.buttons["word.topic.anxiety"]
        XCTAssertTrue(anxiety.waitForExistence(timeout: 5))
        anxiety.tap()
        XCTAssertTrue(waitUntil(4) { anxiety.isSelected })
        for _ in 0..<3 {
            Thread.sleep(forTimeInterval: 1.0)
            if let card = visibleCard(app) {
                XCTAssertEqual(card.value as? String, "Anxiety", "only anxiety verses: \(card.label)")
            }
            app.swipeUp()
        }
        app.buttons["word.topic.all"].tap()
        XCTAssertTrue(waitUntil(4) { app.buttons["word.topic.all"].isSelected })
    }

    func testMeaningTextSizeAndKJV() {
        let app = launchDemo(["-route", "word"])
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 10))
        XCTAssertNotNil(firstHittable(app.descendants(matching: .any).matching(identifier: "word.meaning")),
                        "a one-line meaning under the verse")
        let before = visibleCard(app)?.label ?? ""

        app.buttons["word.display"].tap()
        let bigger = app.buttons["word.textBigger"]
        XCTAssertTrue(bigger.waitForExistence(timeout: 5))
        bigger.tap()
        bigger.tap()
        XCTAssertEqual(app.staticTexts["word.textSize"].label, "120%")
        app.buttons["King James Version"].firstMatch.tap()
        let meanings = app.switches["word.meanings"]
        XCTAssertTrue(meanings.exists)
        meanings.tap()
        app.buttons["Done"].tap()

        let after = visibleCard(app)?.label ?? ""
        XCTAssertNotEqual(after, before, "the card switched to the King James text")
        XCTAssertEqual(after.components(separatedBy: ". ").last, before.components(separatedBy: ". ").last, "same verse")
        XCTAssertNil(firstHittable(app.descendants(matching: .any).matching(identifier: "word.meaning"), timeout: 1),
                     "meanings can be turned off")
    }

    func testSwipeLeftPraysTheVerse() {
        let app = launchDemo(["-route", "word"])
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 10))
        let card = visibleCard(app)
        XCTAssertNotNil(card)
        card?.swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["session.styleLabel"].waitForExistence(timeout: 8), "swiping left starts a prayer")
    }

    func testDoubleTapSavesAndListenReadsAloud() {
        let app = launchDemo(["-route", "word"])
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 10))
        let start = savedCount(app) ?? 0
        visibleCard(app)?.doubleTap()
        XCTAssertTrue(waitUntil(4) { self.savedCount(app) == start + 1 }, "double-tap saves")
        visibleCard(app)?.doubleTap()
        XCTAssertTrue(waitUntil(2) { self.savedCount(app) == start + 1 }, "a second double-tap never un-saves")

        let listen = firstHittable(app.buttons.matching(identifier: "word.listen"))
        XCTAssertEqual(listen?.label, "Listen")
        listen?.tap()
        XCTAssertTrue(waitUntil(3) { firstHittable(app.buttons.matching(identifier: "word.listen"), timeout: 1)?.label == "Stop" })
        firstHittable(app.buttons.matching(identifier: "word.listen"))?.tap()
        XCTAssertTrue(waitUntil(3) { firstHittable(app.buttons.matching(identifier: "word.listen"), timeout: 1)?.label == "Listen" })
    }

    /// A real install: the next session opens on verses you haven't seen yet.
    func testANewSessionNeverRepeatsWhatYouJustRead() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        finishOnboardingIfNeeded(app)
        app.tabBars.buttons["Scroll"].tap()
        var read = Set<String>()
        for _ in 0..<3 {
            Thread.sleep(forTimeInterval: 1.2)
            if let label = visibleCard(app)?.label { read.insert(label) }
            app.swipeUp()
        }
        XCTAssertFalse(read.isEmpty)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Scroll"].tap()
        Thread.sleep(forTimeInterval: 1.2)
        let first = visibleCard(app)?.label ?? ""
        XCTAssertFalse(read.contains(first), "opened on a verse read last session: \(first)")
    }

    /// A real (non-demo) install: save a verse, quit, relaunch, and the count is still there.
    func testSavedVersesPersistAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        finishOnboardingIfNeeded(app)
        app.tabBars.buttons["Scroll"].tap()
        let before = savedCount(app)
        XCTAssertNotNil(before)
        let save = firstHittable(app.buttons.matching(identifier: "word.save"))
        XCTAssertNotNil(save)
        let wasSaved = save?.label == "Saved"
        save?.tap()
        let expected = (before ?? 0) + (wasSaved ? -1 : 1)
        XCTAssertTrue(waitUntil(4) { self.savedCount(app) == expected })
        Thread.sleep(forTimeInterval: 1.0)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["home.prayNow"].waitForExistence(timeout: 10), "no onboarding the second time")
        app.tabBars.buttons["Scroll"].tap()
        XCTAssertEqual(savedCount(app), expected, "the saved count survives a relaunch")
    }
}
