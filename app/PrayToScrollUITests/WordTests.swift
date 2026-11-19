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
            seen.append(cardKey(app) ?? "(no card)")
        }
        XCTAssertEqual(Set(seen).count, seen.count, "each swipe shows a new card: \(seen)")
        app.swipeDown()
        Thread.sleep(forTimeInterval: 1.0)
        let back = cardKey(app) ?? "(no card)"
        XCTAssertTrue(seen.dropLast().contains(back), "swiping back returns to an earlier card: \(back)")
    }

    /// Whatever card is on screen: a verse ("<text>. <ref>") or the main line of a quiz, fact, question or prompt.
    private func cardKey(_ app: XCUIApplication) -> String? {
        let refPattern = "(?s).*\\. (1 |2 |3 )?[A-Z][A-Za-z ]+ [0-9]+:[0-9]+(-[0-9]+)?$"
        let ids = ["word.finish", "word.finish.full", "word.who", "word.fact", "word.reflect", "word.prompt", "word.milestone",
                   "word.jesus", "word.place", "word.series", "word.learn"]
        let cards = app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@ OR identifier IN %@", refPattern, ids))
        return firstHittable(cards, timeout: 4)?.label
    }

    func testFinishTheVerse() {
        let app = launchDemo(["-route", "word", "-wordCard", "finish"])
        let prompt = app.descendants(matching: .any)["word.finish"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10), "the feed opens on a Finish the verse card")
        XCTAssertTrue(prompt.label.contains("blank"), "the ending is blanked: \(prompt.label)")
        let choices = (0..<3).map { app.buttons["word.finish.choice.\($0)"] }
        XCTAssertTrue(choices.allSatisfy { $0.exists }, "three endings")
        XCTAssertEqual(Set(choices.map(\.label)).count, 3)
        choices[1].tap()
        XCTAssertTrue(app.descendants(matching: .any)["word.finish.result"].waitForExistence(timeout: 4), "the card says right or not")
        XCTAssertTrue(app.descendants(matching: .any)["word.finish.full"].waitForExistence(timeout: 4), "the whole verse shows")
        let right = choices.filter { ($0.value as? String) == "Right answer" }
        XCTAssertEqual(right.count, 1, "exactly one ending is marked right")
        let result = app.descendants(matching: .any)["word.finish.result"].firstMatch.label
        XCTAssertTrue(result.hasPrefix(choices[1] == right.first ? "Right!" : "Not quite"), result)
        choices[0].tap()
        XCTAssertEqual(app.descendants(matching: .any)["word.finish.result"].firstMatch.label, result, "one answer per card")
        app.swipeUp()
        XCTAssertNotNil(visibleVerse(app), "a verse follows the quiz")
    }

    func testWhoSaidIt() {
        let app = launchDemo(["-route", "word", "-wordCard", "whoSaid"])
        let quote = app.descendants(matching: .any)["word.who"]
        XCTAssertTrue(quote.waitForExistence(timeout: 10), "the feed opens on a Who said it? card")
        XCTAssertTrue(quote.label.hasPrefix("Who said it?"))
        let choices = (0..<3).map { app.buttons["word.who.choice.\($0)"] }
        XCTAssertTrue(choices.allSatisfy { $0.exists }, "three names")
        choices[2].tap()
        let result = app.descendants(matching: .any)["word.who.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 4))
        let right = choices.filter { ($0.value as? String) == "Right answer" }
        XCTAssertEqual(right.count, 1)
        let speaker = right.first?.label ?? "?"
        XCTAssertTrue(result.label.contains(speaker), "the card names the speaker: \(result.label)")
        XCTAssertTrue(result.label.hasPrefix(choices[2] == right.first ? "Right!" : "It was"), result.label)
    }

    func testDailyGoalRingCelebratesThenLetsYouPrayOrKeepGoing() {
        let app = launchDemo(["-route", "word"])
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 10))
        let goal = app.descendants(matching: .any)["word.goal"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        XCTAssertTrue(goal.label.contains("1 of 10"), "today's first verse counts: \(goal.label)")
        XCTAssertTrue(goal.label.contains("4 days in a row"), "the demo's goal streak: \(goal.label)")
        goal.tap()
        let five = app.buttons["word.goal.option.5"]
        XCTAssertTrue(five.waitForExistence(timeout: 5), "the progress sheet offers goals")
        XCTAssertTrue(app.descendants(matching: .any)["word.progress.level"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["word.badge.firstSave"].exists)
        five.tap()
        XCTAssertTrue(waitUntil(3) { five.isSelected })
        app.buttons["Done"].tap()
        XCTAssertTrue(waitUntil(4) { goal.label.contains("1 of 5") }, goal.label)

        let milestone = app.descendants(matching: .any)["word.milestone"]
        for _ in 0..<12 where !(milestone.exists && milestone.isHittable) {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1.0)
        }
        XCTAssertTrue(milestone.exists && milestone.isHittable, "a celebration card after the fifth verse")
        XCTAssertTrue(milestone.label.contains("Goal done"), milestone.label)
        XCTAssertTrue(app.buttons["word.milestone.pray"].exists, "offers prayer")
        XCTAssertTrue(goal.label.contains("5 days in a row"), "today joins the streak: \(goal.label)")
        app.buttons["word.milestone.keepGoing"].tap()
        XCTAssertTrue(waitUntil(4) { !milestone.isHittable }, "Keep going moves on")
        XCTAssertNotNil(cardKey(app))
    }

    func testSaveToABoardAndFriendsWhoSavedIt() {
        let app = launchDemo(["-route", "word"])
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 10))
        let friends = app.descendants(matching: .any)["word.friendsSaved"].firstMatch
        XCTAssertTrue(friends.waitForExistence(timeout: 10), "the demo friends saved today's verse")
        XCTAssertEqual(friends.label, "Naomi and Sam saved this")

        firstHittable(app.buttons.matching(identifier: "word.save"))?.tap()
        let addToBoard = app.buttons["word.toast.board"]
        XCTAssertTrue(addToBoard.waitForExistence(timeout: 4), "saving offers a board")
        addToBoard.tap()
        let morning = app.buttons["word.board.Morning"]
        XCTAssertTrue(morning.waitForExistence(timeout: 5))
        morning.tap()
        XCTAssertTrue(waitUntil(3) { (morning.value as? String) == "Added" })

        app.buttons["word.board.new"].tap()
        let name = app.textFields["word.board.newName"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["word.board.create"].exists, "a Create button next to the name")
        name.tap()
        name.typeText("Hard Mondays\n")   // Return creates it (the keyboard covers the button on smaller phones)
        let mine = app.buttons["word.board.Hard Mondays"]
        XCTAssertTrue(mine.waitForExistence(timeout: 4), "the new board is listed")
        XCTAssertEqual(mine.value as? String, "Added")
        app.navigationBars["Save to a board"].buttons["Done"].tap()

        app.buttons["word.saved"].tap()
        XCTAssertTrue(app.navigationBars["Saved verses"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Boards"].tap()
        let morningRow = app.buttons["saved.board.Morning"]
        XCTAssertTrue(morningRow.waitForExistence(timeout: 4))
        XCTAssertTrue(morningRow.label.contains("3 verses"), "two demo verses + this one: \(morningRow.label)")
        XCTAssertTrue(app.buttons["saved.board.Hard Mondays"].label.contains("1 verse"))
        morningRow.tap()
        XCTAssertTrue(app.navigationBars["☀️ Morning"].waitForExistence(timeout: 4), "the board opens")
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
        for _ in 0..<3 where !meanings.isHittable { meanings.swipeUp() }
        setSwitch(meanings, on: false)
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
