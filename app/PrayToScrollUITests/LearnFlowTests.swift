import XCTest

/// Learn: the path map from Scroll the Word, one lesson from its story to "Lesson done", and the Daily 5's grid.
final class LearnFlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testScrollTheWordOpensTheLearnMap() {
        let app = launchDemo(["-route", "word"])
        XCTAssertTrue(app.descendants(matching: .any)["word.feed"].waitForExistence(timeout: 10))
        let learn = app.buttons["word.openLearn"]
        XCTAssertTrue(learn.waitForExistence(timeout: 5), "Learn leads the topic chips")
        learn.tap()
        XCTAssertTrue(app.descendants(matching: .any)["learn.title"].waitForExistence(timeout: 6))
        for id in ["jesus", "story", "parables"] { XCTAssertTrue(app.buttons["learn.path.\(id)"].exists, id) }
        let next = app.descendants(matching: .any)["learn.lesson.jesus-04"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertEqual(next.value as? String, "Up next", "the demo has done three lessons")
        XCTAssertEqual(app.descendants(matching: .any)["learn.lesson.jesus-01"].value as? String, "Done")
        XCTAssertEqual(app.descendants(matching: .any)["learn.lesson.jesus-05"].value as? String, "Locked")
        app.buttons["learn.close"].tap()
        XCTAssertTrue(waitUntil(6) { app.buttons["word.openLearn"].isHittable }, "back in the feed")
    }

    func testALessonFromItsStoryToLessonDone() {
        let app = launchDemo(["-route", "word", "-openLearn", "jesus-04"])
        XCTAssertTrue(app.descendants(matching: .any)["lesson.card.story"].waitForExistence(timeout: 10), "the lesson opens on its story")
        let done = app.descendants(matching: .any)["lesson.done"]
        var answered = 0
        for _ in 0..<30 where !(done.exists && done.isHittable) {
            if let finish = firstHittable(app.buttons.matching(identifier: "lesson.finish"), timeout: 1) {
                finish.tap()
            } else if let next = firstHittable(app.buttons.matching(identifier: "lesson.next"), timeout: 1) {
                next.tap()
            } else if let choice = firstHittable(app.buttons.matching(identifier: "lesson.choice.0"), timeout: 1) {
                choice.tap()
                answered += 1
                XCTAssertNotNil(firstHittable(app.descendants(matching: .any).matching(identifier: "lesson.result"), timeout: 4),
                                "an answer shows what the verse says")
            } else {
                app.swipeUp()
            }
            Thread.sleep(forTimeInterval: 0.8)
        }
        XCTAssertTrue(done.exists && done.isHittable, "the lesson ends on Lesson done")
        XCTAssertGreaterThanOrEqual(answered, 1, "every lesson has a quick check")
        XCTAssertTrue(app.descendants(matching: .any)["lesson.xp"].exists)
        XCTAssertTrue(app.buttons["lesson.nextLesson"].exists, "the next lesson is open now")
        XCTAssertTrue(app.buttons["lesson.pray"].exists)
        app.buttons["lesson.close"].tap()
        XCTAssertTrue(waitUntil(6) { app.buttons["word.openLearn"].isHittable }, "back in the feed")
    }

    func testTheDaily5EndsOnAGridAndPracticeGoesOn() {
        let app = launchDemo(["-route", "word", "-openLearn", "daily5"])
        XCTAssertTrue(app.descendants(matching: .any)["daily5.prompt"].waitForExistence(timeout: 10))
        for question in 0..<5 {
            let choice = firstHittable(app.buttons.matching(identifier: "daily5.choice.\(question % 2)"), timeout: 5)
            XCTAssertNotNil(choice, "question \(question + 1) has choices")
            choice?.tap()
            XCTAssertTrue(app.descendants(matching: .any)["daily5.result"].waitForExistence(timeout: 4), "question \(question + 1)")
            firstHittable(app.buttons.matching(identifier: "daily5.next"), timeout: 4)?.tap()
            Thread.sleep(forTimeInterval: 0.7)
        }
        XCTAssertTrue(app.descendants(matching: .any)["daily5.grid"].waitForExistence(timeout: 5), "the share grid")
        let score = app.descendants(matching: .any)["daily5.score"].label
        XCTAssertTrue(score.hasSuffix("/5"), score)
        let streak = app.descendants(matching: .any)["daily5.streak"].label
        XCTAssertTrue(streak.contains("4 days in a row"), "the demo's 3-day run plus today: \(streak)")
        XCTAssertTrue(app.buttons["daily5.share"].exists)

        app.buttons["daily5.practice"].tap()
        XCTAssertTrue(waitUntil(5) { firstHittable(app.descendants(matching: .any).matching(identifier: "daily5.number"), timeout: 1)?.label == "Practice" })
        XCTAssertNotNil(firstHittable(app.descendants(matching: .any).matching(identifier: "daily5.prompt"), timeout: 4))
        firstHittable(app.buttons.matching(identifier: "daily5.close"))?.tap()
        XCTAssertNotNil(firstHittable(app.descendants(matching: .any).matching(identifier: "daily5.grid"), timeout: 5),
                        "Close goes back to today's score")
        firstHittable(app.buttons.matching(identifier: "daily5.close"))?.tap()
        XCTAssertTrue(waitUntil(6) { app.buttons["word.openDaily5"].isHittable }, "back in the feed")
        XCTAssertTrue(app.buttons["word.openDaily5"].label.contains("played today"), app.buttons["word.openDaily5"].label)
    }
}
