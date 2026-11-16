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
