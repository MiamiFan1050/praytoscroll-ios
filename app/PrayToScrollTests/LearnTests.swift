import XCTest
@testable import PrayToScroll

/// Learn's bundled content, read from the source tree like scroll.json.
enum LearnFiles {
    static func library() throws -> LearnLibrary {
        try XCTUnwrap(LearnLibrary.decode(Data(contentsOf: SourceFiles.resource("learn.json"))), "learn.json decodes")
    }
}

private func quiz(_ id: String, answer: String = "Right") -> LearnQuiz {
    LearnQuiz(id: id, question: "Question \(id)?", choices: [answer, "Wrong one", "Wrong two"], answer: answer,
              ref: "John 3:16", explain: "What the verse says.")
}

private func lesson(_ id: String, quizzes: Int = 2) -> Lesson {
    var cards = [LessonCard(kind: .story, text: "What happened.", ref: "John 2:1-2"),
                 LessonCard(kind: .verse, text: "Jesus wept.", ref: "John 11:35")]
    for n in 0..<quizzes {
        cards.append(LessonCard(kind: .quiz, ref: "John 2:1", question: "Q\(n)?", choices: ["A", "B", "C"], answer: "A", explain: "Because."))
    }
    cards.append(LessonCard(kind: .recap, text: "One line."))
    return Lesson(id: id, title: "Lesson \(id)", passage: "John 2:1-11", prayer: "Thank you.", cards: cards)
}

private func path(_ id: String, count: Int) -> LearnPath {
    LearnPath(id: id, title: "Path \(id)", subtitle: "A path.", symbol: "book.fill",
              lessons: (1...count).map { lesson("\(id)-\($0)") })
}

private func pools(general: Int = 40, who: Int = 10, finish: Int = 10) -> Daily5.Pools {
    let library = LearnLibrary(daily: (0..<general).map { quiz(String(format: "d%03d", $0)) })
    let scroll = ScrollContent(
        whoSaid: (0..<who).map { WhoSaidQuiz(id: String(format: "w%03d", $0), ref: "Ruth 1:16", quote: "Where you go, I will go",
                                             speaker: "Ruth", choices: ["Naomi", "Ruth", "Orpah"]) },
        finish: (0..<finish).map { FinishVerse(id: String(format: "x%03d", $0), ref: "John 11:35", text: "Jesus wept.",
                                               answer: "wept", decoys: ["smiled", "slept"]) })
    return Daily5.Pools(library: library, scroll: scroll)
}

// MARK: - Daily 5

final class Daily5Tests: XCTestCase {
    private let calendar = TestCalendar.newYork

    func testTheNumberCountsDaysFromTheFirstDaily5() {
        XCTAssertEqual(Daily5.number(for: TestCalendar.day(2026, 11, 20), calendar: calendar), 1)
        XCTAssertEqual(Daily5.number(for: TestCalendar.day(2026, 11, 21), calendar: calendar), 2)
        XCTAssertEqual(Daily5.number(for: TestCalendar.day(2026, 12, 31), calendar: calendar), 42)
        XCTAssertEqual(Daily5.number(for: TestCalendar.day(2026, 11, 1), calendar: calendar), 1, "a clock set early still gets #1")
    }

    func testTheSameDayGivesEveryoneTheSameFive() {
        let day = TestCalendar.day(2026, 12, 3)
        let a = Daily5.questions(for: day, pools: pools(), calendar: calendar).map(\.id)
        let b = Daily5.questions(for: day, pools: pools(), calendar: calendar).map(\.id)
        XCTAssertEqual(a, b)
        // The pools are sorted by id, so the order content arrives in doesn't matter.
        let shuffled = Daily5.Pools(library: LearnLibrary(daily: (0..<40).reversed().map { quiz(String(format: "d%03d", $0)) }),
                                    scroll: ScrollContent())
        let plain = Daily5.Pools(library: LearnLibrary(daily: (0..<40).map { quiz(String(format: "d%03d", $0)) }), scroll: ScrollContent())
        XCTAssertEqual(Daily5.questions(number: 9, pools: shuffled).map(\.id), Daily5.questions(number: 9, pools: plain).map(\.id))
        XCTAssertNotEqual(Daily5.questions(number: 9, pools: pools()).map(\.id), Daily5.questions(number: 10, pools: pools()).map(\.id))
    }

    func testFiveDifferentQuestionsInTheHouseOrder() {
        for number in 1...30 {
            let day = Daily5.questions(number: number, pools: pools())
            XCTAssertEqual(day.count, 5, "#\(number)")
            XCTAssertEqual(Set(day.map(\.id)).count, 5, "#\(number) never asks the same thing twice")
            XCTAssertEqual(day.map(\.kind), [.quiz, .whoSaid, .quiz, .finish, .quiz], "#\(number)")
            for question in day { XCTAssertTrue(question.choices.contains(question.answer), question.id) }
        }
    }

    func testNothingRepeatsUntilAPoolIsUsedUp() {
        let p = pools(general: 40, who: 10, finish: 10)
        let general = (1...13).flatMap { Daily5.questions(number: $0, pools: p).filter { $0.kind == .quiz }.map(\.id) }
        XCTAssertEqual(general.count, 39)
        XCTAssertEqual(Set(general).count, 39, "13 days × 3 questions out of 40: no repeats")
        let who = (1...10).flatMap { Daily5.questions(number: $0, pools: p).filter { $0.kind == .whoSaid }.map(\.id) }
        XCTAssertEqual(Set(who).count, 10, "every Who said it? once in 10 days")
        let later = (11...40).map { Daily5.questions(number: $0, pools: p) }
        XCTAssertTrue(later.allSatisfy { $0.count == 5 }, "it keeps going after a pool wraps round")
    }

    func testSmallPoolsStillGiveFive() {
        let onlyQuizzes = pools(general: 12, who: 0, finish: 0)
        for number in 1...10 {
            let day = Daily5.questions(number: number, pools: onlyQuizzes)
            XCTAssertEqual(day.count, 5, "#\(number)")
            XCTAssertEqual(Set(day.map(\.id)).count, 5)
        }
        XCTAssertTrue(Daily5.questions(number: 1, pools: pools(general: 0, who: 0, finish: 0)).isEmpty)
    }

    func testTrueFalseKeepsItsOrderAndOtherChoicesAreShuffledStably() {
        let tf = LearnQuiz(id: "t1", question: "Jesus was born in Bethlehem.", choices: ["False", "True"], answer: "True",
                           ref: "Luke 2:4", explain: "Luke says so.")
        XCTAssertTrue(tf.isTrueFalse)
        XCTAssertEqual(tf.orderedChoices, ["True", "False"])
        XCTAssertEqual(Daily5Question(tf).kind, .trueFalse)
        let many = (0..<20).map { quiz("q\($0)") }
        XCTAssertEqual(many.map(\.orderedChoices), many.map(\.orderedChoices), "stable")
        XCTAssertTrue(many.contains { $0.orderedChoices.first != $0.answer }, "the answer isn't always first")
        XCTAssertTrue(many.allSatisfy { Set($0.orderedChoices) == Set($0.choices) })
    }

    func testTheShareTextIsAGridWithNoAnswers() {
        let text = Daily5.shareText(number: 12, marks: [true, true, false, true, true], streak: 3, appName: "Pray to Scroll",
                                    link: "https://praytoscroll.vercel.app")
        XCTAssertEqual(text, "Pray to Scroll Daily 5 #12\n🟩🟩⬜🟩🟩 4/5\n🔥 3 days in a row\nhttps://praytoscroll.vercel.app")
        XCTAssertEqual(Daily5.shareText(number: 1, marks: [false, false, false, false, false], streak: 1, appName: "Pray to Scroll"),
                       "Pray to Scroll Daily 5 #1\n⬜⬜⬜⬜⬜ 0/5", "no run line on day one")
        XCTAssertFalse(text.contains("🟥"), "a miss is never red")
    }

    func testPracticeLeadsWithMissedQuestions() {
        let p = pools()
        let round = Daily5.practice(pools: p, missed: ["d004", "w002"], avoiding: ["d010"], seed: 3)
        XCTAssertEqual(round.count, 5)
        XCTAssertEqual(Array(round.prefix(2)).map(\.id), ["w002", "d004"], "the latest miss first")
        XCTAssertFalse(round.contains { $0.id == "d010" })
        XCTAssertEqual(Set(round.map(\.id)).count, 5)
    }

    func testTheRealLibraryGivesFiveFairQuestionsEveryDayForAYear() throws {
        let real = Daily5.Pools(library: try LearnFiles.library(), scroll: try SourceFiles.scroll())
        XCTAssertGreaterThanOrEqual(real.general.count, 200, "at least 40 days before a question repeats")
        var firstMonth: [String] = []
        for number in 1...366 {
            let day = Daily5.questions(number: number, pools: real)
            XCTAssertEqual(day.count, 5, "#\(number)")
            XCTAssertEqual(Set(day.map(\.id)).count, 5, "#\(number)")
            for question in day {
                XCTAssertTrue(question.choices.contains(question.answer), "\(question.id): the answer is a choice")
                XCTAssertFalse(question.prompt.isEmpty)
            }
            if number <= 30 { firstMonth += day.filter { $0.kind == .quiz || $0.kind == .trueFalse }.map(\.id) }
        }
        XCTAssertEqual(Set(firstMonth).count, firstMonth.count, "no question repeats in the first month")
    }
}

// MARK: - Paths and progress

final class LearnProgressTests: XCTestCase {
    private let calendar = TestCalendar.newYork
    private let today = TestCalendar.day(2026, 11, 25)

    func testOnlyTheFirstLessonStartsOpen() {
        let jesus = path("jesus", count: 5)
        let progress = LearnProgress()
        XCTAssertTrue(progress.isUnlocked(jesus, index: 0))
        for index in 1..<5 { XCTAssertFalse(progress.isUnlocked(jesus, index: index), "\(index)") }
        XCTAssertFalse(progress.isUnlocked(jesus, index: 9), "no such lesson")
        XCTAssertEqual(progress.nextIndex(in: jesus), 0)
    }

    func testFinishingALessonOpensTheNextAndGivesXP() {
        let jesus = path("jesus", count: 3)
        var progress = LearnProgress()
        let reward = progress.complete(jesus.lessons[0], in: jesus, right: 2, today: today)
        XCTAssertEqual(reward, LessonReward(xp: 20, firstTime: true, unlocked: "jesus-2"))
        XCTAssertEqual(progress.xp, 20)
        XCTAssertTrue(progress.isUnlocked(jesus, index: 1))
        XCTAssertFalse(progress.isUnlocked(jesus, index: 2))
        XCTAssertEqual(progress.nextIndex(in: jesus), 1)
        XCTAssertEqual(progress.doneCount(in: jesus), 1)
        XCTAssertEqual(progress.lessonDays, [today.string])
        let last = progress.complete(jesus.lessons[1], in: jesus, right: 0, today: today)
        XCTAssertEqual(last.xp, 10, "no right answers still earns the lesson")
        XCTAssertEqual(progress.lessonDays, [today.string], "one entry a day")
        let end = progress.complete(jesus.lessons[2], in: jesus, right: 1, today: today)
        XCTAssertNil(end.unlocked, "the end of the path")
        XCTAssertNil(progress.nextIndex(in: jesus))
    }

    func testAReplayGivesALittleXPAndNothingIsEverTakenAway() {
        let jesus = path("jesus", count: 3)
        var progress = LearnProgress()
        _ = progress.complete(jesus.lessons[0], in: jesus, right: 2, today: today)
        let again = progress.complete(jesus.lessons[0], in: jesus, right: 0, today: today)
        XCTAssertEqual(again, LessonReward(xp: LearnProgress.replayXP, firstTime: false, unlocked: nil))
        XCTAssertEqual(progress.xp, 20 + LearnProgress.replayXP)
        XCTAssertEqual(progress.completed, ["jesus-1"])
        progress.answered("jesus-1-q2", right: false)
        XCTAssertEqual(progress.xp, 25, "a wrong answer costs nothing")
        XCTAssertTrue(progress.isUnlocked(jesus, index: 0), "done lessons stay open to replay")
    }

    func testContinueGoesToTheNextLessonOnThePathYouWereOn() {
        let library = LearnLibrary(paths: [path("jesus", count: 3), path("story", count: 2)])
        var progress = LearnProgress()
        XCTAssertEqual(progress.continueLesson(in: library)?.id, "jesus-1")
        progress.opened("story-1")
        XCTAssertEqual(progress.continueLesson(in: library)?.id, "story-1")
        _ = progress.complete(library.paths[1].lessons[0], in: library.paths[1], right: 1, today: today)
        XCTAssertEqual(progress.continueLesson(in: library)?.id, "story-2")
        _ = progress.complete(library.paths[1].lessons[1], in: library.paths[1], right: 1, today: today)
        XCTAssertEqual(progress.continueLesson(in: library)?.id, "jesus-1", "a finished path hands over to the next")
        XCTAssertEqual(library.locate("story-2")?.index, 1)
        XCTAssertNil(library.lesson("nope"))
    }

    func testMissedQuestionsComeBackUntilAnsweredRight() {
        var progress = LearnProgress()
        progress.answered("d001", right: false)
        progress.answered("d002", right: false)
        progress.answered("d001", right: false)
        XCTAssertEqual(progress.missed, ["d002", "d001"])
        progress.answered("d002", right: true)
        XCTAssertEqual(progress.missed, ["d001"])
        XCTAssertEqual(progress.quizPlayed, 4)
        XCTAssertEqual(progress.quizRight, 1)
        for n in 0..<100 { progress.answered("m\(n)", right: false) }
        XCTAssertEqual(progress.missed.count, 60, "capped")
    }

    func testTheDaily5CountsOnceADay() {
        var progress = LearnProgress()
        XCTAssertNil(progress.dailyResult(on: today))
        let xp = progress.recordDaily([true, true, false, true, true], number: 6, on: today, calendar: calendar)
        XCTAssertEqual(xp, LearnProgress.dailyXP + 4 * LearnProgress.dailyAnswerXP)
        XCTAssertEqual(progress.dailyResult(on: today)?.right, 4)
        XCTAssertEqual(progress.recordDaily([true, true, true, true, true], number: 6, on: today, calendar: calendar), 0,
                       "a second go the same day doesn't change the score")
        XCTAssertEqual(progress.dailyResult(on: today)?.right, 4)
    }

    func testTheDaily5RunWaitsForTodayAndGraceCoversOneMissedDayAWeek() {
        var progress = LearnProgress()
        func play(_ back: Int) {
            let day = today.adding(days: -back, calendar: calendar)
            progress.daily[day.string] = Daily5Result(number: 1, marks: [true])
        }
        XCTAssertEqual(progress.dailyStreak(today: today, calendar: calendar), 0)
        play(1); play(2); play(3)
        XCTAssertEqual(progress.dailyStreak(today: today, calendar: calendar), 3, "today is still open")
        play(0)
        XCTAssertEqual(progress.dailyStreak(today: today, calendar: calendar), 4)
        XCTAssertFalse(progress.dailyGraceUsed(today: today, calendar: calendar))
        // 2026-11-25 is a Wednesday: skip Monday the 23rd, with Sunday and Saturday played before it.
        progress = LearnProgress()
        play(0); play(1); play(3); play(4)
        XCTAssertEqual(progress.dailyStreak(today: today, calendar: calendar), 4, "one missed day is covered")
        XCTAssertTrue(progress.dailyGraceUsed(today: today, calendar: calendar))
        // Two missed days in a row start a new run.
        progress = LearnProgress()
        play(0); play(3); play(4)
        XCTAssertEqual(progress.dailyStreak(today: today, calendar: calendar), 1)
        // A second missed day in the same week isn't covered.
        let friday = TestCalendar.day(2026, 11, 27)
        progress = LearnProgress()
        for back in [0, 2, 4] { progress.daily[friday.adding(days: -back, calendar: calendar).string] = Daily5Result(number: 1, marks: [true]) }
        XCTAssertEqual(progress.dailyStreak(today: friday, calendar: calendar), 2, "grace once a week")
    }

    func testProgressSurvivesARoundTripAndJunk() throws {
        var progress = LearnProgress()
        progress.completed = ["jesus-01"]
        progress.xp = 42
        progress.seriesSeen = ["peter": 2]
        progress.daily["2026-11-20"] = Daily5Result(number: 1, marks: [true, false])
        let back = try JSONDecoder().decode(LearnProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(back, progress)
        let junk = try JSONDecoder().decode(LearnProgress.self, from: Data(#"{"xp": "lots", "completed": ["a"], "future": 1}"#.utf8))
        XCTAssertEqual(junk.xp, 0)
        XCTAssertEqual(junk.completed, ["a"])
    }

    func testEraseAllDataClearsLearn() throws {
        let defaults = makeScratchDefaults()
        defaults.set(try JSONEncoder().encode(LearnProgress()), forKey: LearnStore.key)
        XCTAssertTrue(LearnStore.key.hasPrefix("ak."), "Erase all data clears every ak. key")
        SharedStore(defaults: defaults).resetAll()
        XCTAssertNil(defaults.data(forKey: LearnStore.key))
    }

    func testSeriesProgressOnlyMovesForward() {
        var progress = LearnProgress()
        progress.sawSeriesPart("peter", index: 2)
        progress.sawSeriesPart("peter", index: 0)
        XCTAssertEqual(progress.seriesSeen["peter"], 3)
    }
}

// MARK: - The feed

final class LearnFeedTests: XCTestCase {
    private let verses = (1...90).map { Verse(day: $0, ref: "John \($0):1", text: "Verse \($0).", theme: "peace", meaning: "A line that says what it means.") }

    private func library() -> LearnLibrary {
        LearnLibrary(paths: [path("jesus", count: 4)],
                     jesusSaid: (1...6).map { JesusSaying(id: "j\($0)", ref: "John 8:12", quote: "I am the light of the world.", context: "In the temple.") },
                     places: (1...6).map { PlaceCard(id: "p\($0)", title: "Born", place: "Bethlehem", when: "In the days of Herod", text: "A town.", ref: "Matthew 2:1") },
                     series: [LearnSeries(id: "peter", title: "The life of Peter", parts: (0..<5).map {
                         LearnSeries.Part(text: "Part \($0).", ref: "John 1:42", next: $0 < 4 ? "Next: more." : nil) })])
    }

    private func content() -> ScrollContent {
        ScrollContent(facts: (0..<4).map { BibleFact(id: "f\($0)", text: "Fact \($0) is true and checkable.", ref: "Genesis 5:27") },
                      whoSaid: [WhoSaidQuiz(id: "w0", ref: "Ruth 1:16", quote: "Where you go", speaker: "Ruth", choices: ["Naomi", "Ruth", "Orpah"])],
                      finish: [FinishVerse(id: "x0", ref: "John 11:35", text: "Jesus wept.", answer: "wept", decoys: ["smiled", "slept"])],
                      reflect: [Reflection(id: "r0", theme: "peace", question: "Where do you need peace today?")])
    }

    private func mix(_ learn: FeedLearn) -> [FeedItem] {
        FeedMixer.build(.init(verses: verses, content: content(), prompts: ["Thank God for one thing."], topic: nil, seed: 4, learn: learn))
    }

    func testLearnCardsJoinTheMixWithoutCrowdingOutVerses() {
        let learn = FeedLearn.make(library: library(), progress: LearnProgress(), today: TestCalendar.day(2026, 11, 25),
                                   calendar: TestCalendar.newYork)
        let items = mix(learn)
        XCTAssertEqual(items.first?.kind, .verse)
        XCTAssertEqual(items.first { $0.kind != .verse }?.kind, .lesson, "the first special card leads into Learn")
        let kinds = Set(items.map(\.kind))
        for kind in FeedMixer.learning { XCTAssertTrue(kinds.contains(kind), "\(kind)") }
        let verseCards = items.filter { $0.kind.carriesVerse }.count
        XCTAssertGreaterThanOrEqual(Double(verseCards) / Double(items.count), 0.6)
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
        for (a, b) in zip(items, items.dropFirst()) { XCTAssertFalse(a.kind != .verse && b.kind != .verse, "\(a.id) then \(b.id)") }
        XCTAssertTrue(items.filter { FeedMixer.learning.contains($0.kind) }.allSatisfy { $0.readableVerse == nil },
                      "Learn cards are never saved or counted as verses")
    }

    func testWithoutLearnTheFeedIsUnchanged() {
        let plain = FeedMixer.build(.init(verses: verses, content: content(), prompts: ["Pray."], topic: nil, seed: 4))
        XCTAssertFalse(plain.contains { FeedMixer.learning.contains($0.kind) })
        XCTAssertEqual(plain.map(\.id), FeedMixer.build(.init(verses: verses, content: content(), prompts: ["Pray."], topic: nil,
                                                               seed: 4, learn: .empty)).map(\.id))
    }

    func testSeriesPartsComeInOrderAndPickUpWhereYouLeftOff() {
        var progress = LearnProgress()
        progress.sawSeriesPart("peter", index: 1)
        let learn = FeedLearn.make(library: library(), progress: progress, today: TestCalendar.day(2026, 11, 25), calendar: TestCalendar.newYork)
        XCTAssertEqual(learn.series.map(\.index), [2, 3, 4], "parts 1 and 2 were seen")
        let parts = mix(learn).compactMap(\.seriesPart).map(\.index)
        XCTAssertEqual(parts, Array(parts.sorted()), "in order")
        XCTAssertEqual(Set(parts).count, parts.count, "each part once")
        progress.sawSeriesPart("peter", index: 4)
        XCTAssertEqual(FeedLearn.make(library: library(), progress: progress, today: TestCalendar.day(2026, 11, 25)).series.first?.index, 0,
                       "a finished series starts again from the top")
    }

    func testTheDaily5CardShowsUntilItsPlayed() {
        let day = TestCalendar.day(2026, 11, 25)
        var progress = LearnProgress()
        let before = FeedLearn.make(library: library(), progress: progress, today: day, calendar: TestCalendar.newYork).nudges
        XCTAssertEqual(before.first, .daily5(number: 6))
        XCTAssertEqual(before.count, 2, "then the lesson")
        progress.recordDaily([true], number: 6, on: day)
        let after = FeedLearn.make(library: library(), progress: progress, today: day, calendar: TestCalendar.newYork).nudges
        XCTAssertEqual(after.count, 1)
        if case .lesson(let id, _, _, let number, let count, _, let started) = after.first {
            XCTAssertEqual(id, "jesus-1")
            XCTAssertEqual(number, 1)
            XCTAssertEqual(count, 4)
            XCTAssertFalse(started)
        } else {
            XCTFail("expected the lesson card")
        }
    }

    func testThreeRightInARowBursts() {
        var combo = 0
        var bursts: [Int] = []
        for right in [true, true, true, true, false, true, true, true, true, true, true] {
            combo = QuizCombo.next(combo, right: right)
            if QuizCombo.bursts(combo) { bursts.append(combo) }
        }
        XCTAssertEqual(bursts, [3, 3, 6])
    }
}

// MARK: - Content (learn.json)

final class LearnContentTests: XCTestCase {
    private func allRefs(_ library: LearnLibrary, facts: [BibleFact]) -> [(String, String)] {
        var refs: [(String, String)] = []
        for path in library.paths {
            for lesson in path.lessons {
                refs.append((lesson.id, lesson.passage))
                for (index, card) in lesson.cards.enumerated() { if let ref = card.ref { refs.append(("\(lesson.id) card \(index + 1)", ref)) } }
            }
        }
        refs += library.daily.map { ($0.id, $0.ref) }
        refs += library.jesusSaid.map { ($0.id, $0.ref) }
        refs += library.places.map { ($0.id, $0.ref) }
        refs += library.series.flatMap { series in series.parts.enumerated().map { ("\(series.id) \($0.offset + 1)", $0.element.ref) } }
        refs += facts.map { ($0.id, $0.ref) }
        return refs
    }

    func testThreePathsWithTheirLessons() throws {
        let library = try LearnFiles.library()
        XCTAssertEqual(library.paths.map(\.id), ["jesus", "story", "parables"])
        XCTAssertGreaterThanOrEqual(library.path("jesus")?.lessons.count ?? 0, 28, "Meet Jesus")
        XCTAssertGreaterThanOrEqual(library.path("story")?.lessons.count ?? 0, 12, "The Big Story")
        XCTAssertGreaterThanOrEqual(library.path("parables")?.lessons.count ?? 0, 12, "Parables")
        for path in library.paths {
            XCTAssertFalse(path.title.isEmpty)
            XCTAssertFalse(path.subtitle.isEmpty)
            XCTAssertTrue(path.lessons.allSatisfy { $0.id.hasPrefix(path.id + "-") }, path.id)
        }
    }

    func testEveryLessonIsBiteSizeWithAStoryAVerseAQuizAndARecap() throws {
        for path in try LearnFiles.library().paths {
            for lesson in path.lessons {
                let kinds = lesson.cards.map(\.kind)
                XCTAssertTrue((5...8).contains(kinds.count), "\(lesson.id): \(kinds.count) cards")
                XCTAssertEqual(kinds.first, .story, lesson.id)
                XCTAssertEqual(kinds.last, .recap, lesson.id)
                XCTAssertGreaterThanOrEqual(lesson.quizzes.count, 1, "\(lesson.id) has a quiz")
                let verse = try XCTUnwrap(lesson.keyVerse, "\(lesson.id) has a key verse")
                XCTAssertFalse(verse.text?.isEmpty ?? true, "\(lesson.id): the key verse's WEB text is filled in")
                XCTAssertFalse(verse.text?.contains("Yahweh") ?? false, lesson.id)
                for card in lesson.cards where card.kind != .quiz { XCTAssertFalse(card.text?.isEmpty ?? true, "\(lesson.id) \(card.kind)") }
                XCTAssertFalse(lesson.prayer.isEmpty, lesson.id)
                XCTAssertLessThanOrEqual(lesson.title.count, 40, lesson.id)
            }
        }
    }

    func testEveryAnswerIsOneOfItsChoices() throws {
        let library = try LearnFiles.library()
        let quizzes = library.lessonQuizzes + library.daily
        XCTAssertGreaterThanOrEqual(library.daily.count, 100)
        for quiz in quizzes {
            XCTAssertTrue(quiz.choices.contains(quiz.answer), "\(quiz.id): \(quiz.answer)")
            XCTAssertTrue((2...4).contains(quiz.choices.count), quiz.id)
            XCTAssertEqual(Set(quiz.choices.map { $0.lowercased() }).count, quiz.choices.count, "\(quiz.id): choices differ")
            XCTAssertFalse(quiz.explain.isEmpty, "\(quiz.id) explains its answer")
            XCTAssertTrue(quiz.question.hasSuffix("?") || (quiz.isTrueFalse && quiz.question.hasSuffix(".")), quiz.id)
        }
    }

    func testEveryReferenceParses() throws {
        let refs = allRefs(try LearnFiles.library(), facts: try SourceFiles.scroll().facts)
        XCTAssertGreaterThan(refs.count, 500)
        for (where_, ref) in refs { XCTAssertNotNil(BibleRef(ref), "\(where_): \(ref)") }
        let samuel = try XCTUnwrap(BibleRef("1 Samuel 16:1-13"))
        XCTAssertEqual(samuel.book, "1 Samuel")
        XCTAssertEqual(samuel.chapter, 16)
        XCTAssertEqual(samuel.verse, 1)
        XCTAssertEqual(samuel.endVerse, 13)
        XCTAssertEqual(BibleRef("Song of Solomon 2:4")?.book, "Song of Solomon")
        XCTAssertNil(BibleRef("Hezekiah 1:1"), "no such book")
        XCTAssertNil(BibleRef("John 3"), "a verse, not a chapter")
        XCTAssertNil(BibleRef("John 3:16-12"), "ranges run forward")
        XCTAssertNil(BibleRef("Matthew 26:75-27:2"), "one chapter at a time")
    }

    func testIdsAreUnique() throws {
        let library = try LearnFiles.library()
        // One append at a time: the chained `+` took the type checker past CI's limit (strict job, run 44783752303).
        var ids: [String] = library.paths.flatMap { $0.lessons.map(\.id) }
        ids += library.daily.map(\.id)
        ids += library.jesusSaid.map(\.id)
        ids += library.places.map(\.id)
        ids += library.series.map(\.id)
        ids += library.lessonQuizzes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        let facts = try SourceFiles.scroll().facts
        XCTAssertGreaterThanOrEqual(facts.count, 160, "60 facts + 100 Did you know")
        XCTAssertEqual(Set(facts.map(\.id)).count, facts.count)
    }

    func testJesusSaidPlacesAndSeries() throws {
        let library = try LearnFiles.library()
        XCTAssertGreaterThanOrEqual(library.jesusSaid.count, 50)
        XCTAssertEqual(Set(library.jesusSaid.map(\.ref)).count, library.jesusSaid.count, "every saying from its own verse")
        for saying in library.jesusSaid {
            XCTAssertTrue((8...200).contains(saying.quote.count), saying.id)
            XCTAssertFalse(saying.quote.hasPrefix("\u{201C}") || saying.quote.hasSuffix("\u{201D}"), "\(saying.id): the card adds the quote marks")
            XCTAssertFalse(saying.context.isEmpty, saying.id)
        }
        XCTAssertGreaterThanOrEqual(library.places.count, 30)
        for place in library.places { XCTAssertFalse(place.place.isEmpty || place.when.isEmpty || place.text.isEmpty, place.id) }
        XCTAssertGreaterThanOrEqual(library.series.count, 5)
        for series in library.series {
            XCTAssertTrue((3...6).contains(series.parts.count), series.id)
            for (index, part) in series.parts.enumerated() {
                XCTAssertFalse(part.text.isEmpty, series.id)
                XCTAssertEqual(part.next == nil, index == series.parts.count - 1, "\(series.id) \(index + 1): a teaser on all but the last")
            }
        }
    }

    func testHouseStyleAndNoShame() throws {
        let library = try LearnFiles.library()
        var lines: [String] = []
        for path in library.paths {
            lines += [path.title, path.subtitle]
            for lesson in path.lessons {
                lines += [lesson.title, lesson.prayer]
                // Verse cards are the WEB, word for word: tools/learn_content.py checks those.
                for card in lesson.cards where card.kind != .verse {
                    lines += [card.text, card.question, card.explain].compactMap { $0 } + (card.choices ?? [])
                }
            }
        }
        lines += library.daily.flatMap { [$0.question, $0.explain] + $0.choices }
        lines += library.jesusSaid.map(\.context) + library.places.flatMap { [$0.title, $0.place, $0.when, $0.text] }
        lines += library.series.flatMap { [$0.title] + $0.parts.flatMap { [$0.text, $0.next].compactMap { $0 } } }
        var appLines: [String] = []
        for right in 0...5 { appLines.append(LearnCopy.dailyScoreLine(right: right, of: 5)) }
        for streak in [0, 1, 2, 9] { appLines += [LearnCopy.dailyStreakLine(streak, graced: false), LearnCopy.dailyStreakLine(streak, graced: true)] }
        for first in [true, false] { for right in 0...2 { appLines.append(LearnCopy.lessonDoneLine(firstTime: first, right: right, quizzes: 2)) } }
        appLines += (0..<4).map(LearnCopy.rightLine) + (0..<3).map(LearnCopy.notQuiteLine)
        let banned = ["blocker", "subscribe", "premium", "upgrade", "free trial", "$", "you failed", "lazy", "lose your streak",
                      "shame on you", "disappoint"]
        for line in lines + appLines {
            for word in banned { XCTAssertFalse(line.lowercased().contains(word), "“\(line)” says \(word)") }
            XCTAssertFalse(line.contains("\"") || line.contains("'"), "straight quotes: \(line)")
        }
        for line in appLines { XCTAssertFalse(line.lowercased().contains("price"), line) }
    }
}
