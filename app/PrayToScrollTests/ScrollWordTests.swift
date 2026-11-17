import XCTest
@testable import PrayToScroll

/// Reads the app's bundled content straight from the source tree (the local test runner has no bundle resources).
enum SourceFiles {
    static let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    static func resource(_ name: String) -> URL {
        app.appendingPathComponent("PrayToScroll/Resources").appendingPathComponent(name)
    }

    static func daily() throws -> [Verse] {
        try JSONDecoder().decode([Verse].self, from: Data(contentsOf: resource("verses.json")))
    }

    static func scroll() throws -> ScrollContent {
        try XCTUnwrap(ScrollContent.decode(Data(contentsOf: resource("scroll.json"))), "scroll.json decodes")
    }
}

private let themes = Set(WordFeedPlanner.topics)

private func verse(_ day: Int, theme: String = "peace", meaning: String? = "A line that says what it means for you today.") -> Verse {
    Verse(day: day, ref: "John \(day):1", text: "Verse number \(day).", theme: theme, meaning: meaning)
}

private func content(facts: Int = 4, who: Int = 4, finish: Int = 4, reflect: [String] = ["peace", "hope", "rest"]) -> ScrollContent {
    ScrollContent(
        verses: [],
        facts: (0..<facts).map { BibleFact(id: "f\($0)", text: "Fact \($0) is true and checkable.", ref: "Genesis 5:27") },
        whoSaid: (0..<who).map { WhoSaidQuiz(id: "w\($0)", ref: "Ruth 1:16", quote: "Where you go, I will go", speaker: "Ruth", choices: ["Naomi", "Ruth", "Orpah"]) },
        finish: (0..<finish).map { FinishVerse(id: "x\($0)", ref: "John 11:35", text: "Jesus wept.", answer: "wept", decoys: ["smiled", "slept"]) },
        reflect: reflect.enumerated().map { Reflection(id: "r\($0.offset)", theme: $0.element, question: "Where do you need \($0.element) today?") })
}

private func mix(_ verses: [Verse], content: ScrollContent = content(), topic: String? = nil, seed: UInt64 = 7,
                 prompts: [String] = ["Thank God for one thing.", "Pray for {name}.", "Ask for patience today."]) -> [FeedItem] {
    FeedMixer.build(.init(verses: verses, content: content, prompts: prompts, topic: topic, seed: seed))
}

// MARK: - Card types

final class ScrollCardTests: XCTestCase {
    func testFinishTheVerseBlanksTheLastWordsAndKnowsTheAnswer() {
        let card = FinishVerse(id: "x1", ref: "Philippians 4:13", text: "I can do all things through Christ who strengthens me.",
                               answer: "who strengthens me", decoys: ["who first loved me", "who goes before me"])
        XCTAssertEqual(card.prompt, "I can do all things through Christ ____.")
        XCTAssertTrue(card.isRight("who strengthens me"))
        XCTAssertFalse(card.isRight("who first loved me"))
        let choices = card.choices(seed: 3)
        XCTAssertEqual(Set(choices), ["who strengthens me", "who first loved me", "who goes before me"])
        XCTAssertEqual(choices, card.choices(seed: 3), "the same order every time the card is drawn")
    }

    func testFinishTheVerseBlanksTheLastMatchNotTheFirst() {
        let card = FinishVerse(id: "x2", ref: "Psalm 136:1", text: "Give thanks, for his love endures. His love endures forever.",
                               answer: "endures forever", decoys: ["is near", "never fails"])
        XCTAssertEqual(card.prompt, "Give thanks, for his love endures. His love ____.")
    }

    func testWhoSaidItShufflesThreeNamesButKeepsTheSpeaker() {
        let quiz = WhoSaidQuiz(id: "w1", ref: "Esther 4:14", quote: "Who knows if you haven’t come to the kingdom for such a time as this?",
                               speaker: "Mordecai", choices: ["Mordecai", "Haman", "Ahasuerus"])
        let order = quiz.shuffledChoices(seed: 9)
        XCTAssertEqual(Set(order), ["Mordecai", "Haman", "Ahasuerus"])
        XCTAssertEqual(order, quiz.shuffledChoices(seed: 9))
        XCTAssertTrue(quiz.isRight("Mordecai"))
        XCTAssertFalse(quiz.isRight("Haman"))
    }

    func testOnlyVerseCardsCanBeSavedReadAloudOrCounted() {
        let base = verse(1)
        for kind in FeedCardKind.allCases {
            let item = FeedItem(id: "k\(kind.rawValue)", kind: kind, verse: base)
            XCTAssertEqual(item.readableVerse != nil, [.verse, .meaning, .send].contains(kind), "\(kind)")
        }
    }

    func testMilestoneCardsCarryTheirEvent() {
        let goal = FeedMixer.milestone(for: .goalReached(10), streak: 4, index: 1)
        XCTAssertEqual(goal.kind, .milestone)
        XCTAssertEqual(goal.milestone, .goalDone(goal: 10, streak: 4))
        let level = FeedMixer.milestone(for: .levelUp(WordLevel.for(read: 30)), streak: 0, index: 2)
        XCTAssertEqual(level.milestone, .levelUp(number: 3, name: "Root"))
        let badge = FeedMixer.milestone(for: .badge(.firstSend), streak: 0, index: 3)
        XCTAssertEqual(badge.milestone, .badge(.firstSend))
        XCTAssertNotEqual(goal.id, level.id)
        XCTAssertNil(goal.readableVerse)
    }

    func testCelebrationsNeverShame() {
        let banned = ["lost", "lose", "broke", "failed", "missed", "behind", "don’t forget", "only", "should"]
        var lines: [String] = []
        for milestone in [FeedMilestone.goalDone(goal: 10, streak: 0), .goalDone(goal: 5, streak: 12), .levelUp(number: 4, name: "Stem")]
            + WordBadge.allCases.map(FeedMilestone.badge) {
            lines += [WordMilestoneCopy.title(milestone), WordMilestoneCopy.detail(milestone)]
        }
        for read in [0, 1, 4, 9, 10, 25] { lines.append(WordProgressCopy.todayLine(read: read, goal: 10)) }
        for line in lines {
            for word in banned { XCTAssertFalse(line.lowercased().contains(word), "\(line) says \(word)") }
        }
        XCTAssertTrue(WordMilestoneCopy.title(.goalDone(goal: 10, streak: 3)).contains("Goal done"))
        XCTAssertTrue(WordMilestoneCopy.detail(.goalDone(goal: 10, streak: 3)).contains("prayer"), "offers prayer as the next step")
    }

    func testFriendsSavedLine() {
        XCTAssertNil(FriendSaves.line([]))
        XCTAssertEqual(FriendSaves.line(["Grace"]), "Grace saved this")
        XCTAssertEqual(FriendSaves.line(["Grace", "Sam"]), "Grace and Sam saved this")
        XCTAssertEqual(FriendSaves.line(["Grace", "Hannah", "Sam"]), "Grace and 2 friends saved this")
        let map = FriendSaves.byRef([
            FriendProfile(memberID: "a", handle: "sam_p", displayName: "Sam", emoji: "⛰️", streak: 1, lastPrayedDay: "", savedRefs: ["Psalm 23:1", "Psalm 23:1"]),
            FriendProfile(memberID: "b", handle: "grace", displayName: "", emoji: "🌿", streak: 1, lastPrayedDay: "", savedRefs: ["Psalm 23:1", "John 3:16"]),
        ])
        XCTAssertEqual(map["Psalm 23:1"], ["@grace", "Sam"], "each friend once; a blank nickname shows the handle")
        XCTAssertEqual(map["John 3:16"], ["@grace"])
    }

    func testAVerseMessageFitsOneText() throws {
        let all = try SourceFiles.scroll().feedVerses(daily: SourceFiles.daily())
        for verse in all {
            for translation in BibleTranslation.allCases {
                let message = VerseMessage.build(verse: verse.rendered(in: translation))
                XCTAssertLessThanOrEqual(message.count, VerseMessage.maxLength, verse.ref)
                XCTAssertTrue(message.hasPrefix(VerseMessage.opening))
                XCTAssertTrue(message.contains(verse.ref))
            }
        }
    }

    func testBackdropsAreAllThere() {
        XCTAssertEqual(FeedBackgrounds.name(0), "scroll-bg-01")
        XCTAssertEqual(FeedBackgrounds.name(59), "scroll-bg-60")
        XCTAssertEqual(FeedBackgrounds.name(60), "scroll-bg-01", "wraps")
        XCTAssertEqual(FeedBackgrounds.name(-1), "scroll-bg-60")
        let folder = SourceFiles.resource("Backgrounds")
        for index in 0..<FeedBackgrounds.count {
            let file = folder.appendingPathComponent(FeedBackgrounds.name(index) + ".heic")
            let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
            XCTAssertGreaterThan(size, 20_000, file.lastPathComponent)
            XCTAssertTrue(size < 400_000, "\(file.lastPathComponent) stays small")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: SourceFiles.resource("scroll-ambient.m4a").path))
    }

    func testScrollSettingsDefaultsAndClamp() throws {
        let fresh = AppSettings()
        XCTAssertEqual(fresh.wordGoal, 10)
        XCTAssertFalse(fresh.ambientSound, "ambient sound is off until turned on")
        XCTAssertFalse(fresh.shareSavesWithFriends, "friends see nothing until turned on")
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(old.wordGoal, 10)
        let wild = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"wordGoal": 9000}"#.utf8))
        XCTAssertEqual(wild.wordGoal, 200)
        let zero = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"wordGoal": 0}"#.utf8))
        XCTAssertEqual(zero.wordGoal, 1)
    }
}

// MARK: - The feed mix

final class FeedMixTests: XCTestCase {
    private let verses = (1...60).map { verse($0, theme: ["peace", "hope", "rest"][$0 % 3]) }

    func testTheFirstCardIsAVerseAndSpecialsNeverTouch() {
        let items = mix(verses)
        XCTAssertEqual(items.first?.kind, .verse)
        XCTAssertEqual(items.first?.verse?.day, 1)
        for (a, b) in zip(items, items.dropFirst()) {
            XCTAssertFalse(a.kind != .verse && b.kind != .verse, "\(a.id) then \(b.id)")
        }
    }

    func testMostCardsAreVersesAndEveryKindShowsUp() {
        let items = mix(verses)
        let verseCards = items.filter { $0.kind.carriesVerse }.count
        XCTAssertGreaterThanOrEqual(Double(verseCards) / Double(items.count), 0.6)
        let kinds = Set(items.prefix(40).map(\.kind))
        for kind in FeedMixer.specials { XCTAssertTrue(kinds.contains(kind), "\(kind) within 40 cards") }
        XCTAssertFalse(kinds.contains(.milestone), "milestones are added as they happen, never planned")
    }

    func testEveryVerseShowsUpOnceAndIdsAreUnique() {
        let items = mix(verses)
        let shown = items.compactMap(\.readableVerse).map(\.day)
        XCTAssertEqual(shown.count, verses.count)
        XCTAssertEqual(Set(shown), Set(verses.map(\.day)))
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
    }

    func testTheMixIsStableForASeed() {
        XCTAssertEqual(mix(verses, seed: 5).map(\.id), mix(verses, seed: 5).map(\.id))
        XCTAssertNotEqual(mix(verses, seed: 5).map(\.id), mix(verses, seed: 6).map(\.id))
    }

    func testNoSameSpecialTwiceInARow() {
        let specials = mix(Array((1...300).map { verse($0) }), seed: 11).filter { $0.kind != .verse }.map(\.kind)
        for (a, b) in zip(specials, specials.dropFirst()) { XCTAssertNotEqual(a, b) }
    }

    func testMeaningCardsNeedAMeaningAndPromptsNeverHoldPlaceholders() {
        let bare = (1...40).map { verse($0, meaning: nil) }
        let items = mix(bare)
        XCTAssertFalse(items.contains { $0.kind == .meaning })
        XCTAssertFalse(items.contains { $0.prompt?.contains("{name}") == true })
    }

    func testATopicFeedOnlyAsksThatTopicsQuestions() {
        let items = mix(verses.filter { $0.theme == "rest" }, topic: "rest")
        let questions = items.compactMap(\.reflection)
        XCTAssertTrue(questions.allSatisfy { $0.theme == "rest" })
    }

    func testNeighboursNeverShareABackdrop() {
        let items = mix(verses)
        for (a, b) in zip(items, items.dropFirst()) { XCTAssertNotEqual(a.background, b.background) }
        XCTAssertTrue(items.allSatisfy { (0..<FeedBackgrounds.count).contains($0.background) })
    }

    func testSeenFactsAndQuizzesGoToTheBack() {
        let list = ["a", "b", "c", "d"]
        let rotated = FeedMixer.rotate(list, id: \.self, seen: ["c", "a"], seed: 1)
        XCTAssertEqual(Array(rotated.suffix(2)), ["c", "a"], "oldest seen first")
        XCTAssertEqual(Set(rotated.prefix(2)), ["b", "d"])
    }

    func testAnEmptyLibraryStillShowsAVerse() {
        let items = FeedMixer.build(.init(verses: [], content: ScrollContent(), prompts: [], topic: nil, seed: 1))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.kind, .verse)
    }

    func testTheWholeLibraryMixesWithEveryVerseOnceFromAnyDay() throws {
        let library = try SourceFiles.scroll()
        let all = library.feedVerses(daily: try SourceFiles.daily())
        for today in [1, 60, 366] {
            let ordered = WordFeedPlanner.order(verses: all, topic: nil, seen: [], today: today, seed: UInt64(today))
            let items = FeedMixer.build(.init(verses: ordered, content: library, prompts: ["Pray A."], topic: nil, seed: UInt64(today)))
            let shown = items.compactMap(\.readableVerse).map(\.day)
            XCTAssertEqual(shown.count, all.count)
            XCTAssertEqual(Set(shown).count, all.count)
            XCTAssertEqual(items.first?.verse?.day, today)
            XCTAssertEqual(Set(items.map(\.id)).count, items.count)
        }
    }
}

// MARK: - For you

final class ForYouTests: XCTestCase {
    private let verses: [Verse] = (1...140).map { verse($0, theme: WordFeedPlanner.topics[$0 % 14]) }

    func testNoSignalsKeepsThePlannersOrder() {
        XCTAssertEqual(ForYouRanker.order(verses, affinity: [:], seed: 1).map(\.day), verses.map(\.day))
    }

    func testLovedThemesComeSoonerButOthersStillShowUp() {
        let ranked = ForYouRanker.order(verses, affinity: ["peace": 8, "anxiety": -4], seed: 3)
        XCTAssertEqual(Set(ranked.map(\.day)), Set(verses.map(\.day)), "nothing dropped or repeated")
        XCTAssertEqual(ranked.count, verses.count)
        let head = ranked.prefix(30)
        let peace = head.filter { $0.theme == "peace" }.count
        XCTAssertGreaterThanOrEqual(peace, 6, "well above the 2 an even mix would give")
        XCTAssertLessThanOrEqual(head.filter { $0.theme == "anxiety" }.count, 2)
        XCTAssertGreaterThanOrEqual(Set(head.compactMap(\.theme)).count, 6, "one in four picks explores")
    }

    func testTodaysVerseStaysFirstAndSeenVersesStayLast() {
        let seen: Set<Int> = [2, 3, 4]
        let ordered = verses.filter { !seen.contains($0.day) } + verses.filter { seen.contains($0.day) }
        let ranked = ForYouRanker.order(ordered, affinity: ["hope": 5], seed: 2, seen: seen, pinFirst: true)
        XCTAssertEqual(ranked.first?.day, ordered.first?.day)
        XCTAssertEqual(Set(ranked.suffix(3).map(\.day)), seen)
    }

    func testSignalsMoveThemesAndStayInBounds() {
        var progress = WordProgress()
        progress.signal(.heart, theme: "peace")
        XCTAssertEqual(progress.affinity["peace"], 1.0)
        progress.signal(.dwell(0.5), theme: "focus")
        XCTAssertEqual(progress.affinity["focus"], -0.3)
        progress.signal(.dwell(4), theme: "hope")
        XCTAssertNil(progress.affinity["hope"], "an ordinary read says nothing")
        for _ in 0..<40 { progress.signal(.heart, theme: "peace") }
        XCTAssertLessThanOrEqual(progress.affinity["peace"]!, 8)
        for _ in 0..<40 { progress.signal(.dwell(0.2), theme: "focus") }
        XCTAssertGreaterThanOrEqual(progress.affinity["focus"]!, -4)
        progress.signal(.heart, theme: nil)
        XCTAssertEqual(ForYouSignal.dwell(20).weight, 0.6)
        XCTAssertEqual(ForYouSignal.dwell(8).weight, 0.3)
    }
}

// MARK: - Progress

final class WordProgressTests: XCTestCase {
    private let calendar = TestCalendar.newYork
    private let today = TestCalendar.day(2026, 11, 16)

    func testTheGoalIsReachedOnceADay() {
        var progress = WordProgress()
        var goals = 0
        for _ in 0..<12 {
            let events = progress.recordRead(theme: "peace", today: today, goal: 5, calendar: calendar)
            goals += events.filter { if case .goalReached = $0 { return true } else { return false } }.count
        }
        XCTAssertEqual(goals, 1)
        XCTAssertEqual(progress.readOn(today.string), 12)
        XCTAssertEqual(progress.totalRead, 12)
        XCTAssertEqual(progress.goalDays, [today.string])
        XCTAssertTrue(progress.badges.contains(.firstGoal))
    }

    func testTheStreakCountsGoalDaysAndWaitsForToday() {
        var progress = WordProgress()
        progress.goalDays = (1...3).map { today.adding(days: -$0, calendar: calendar).string }.sorted()
        XCTAssertEqual(progress.streak(today: today, calendar: calendar), 3, "today is still open")
        progress.goalDays.append(today.string)
        XCTAssertEqual(progress.streak(today: today, calendar: calendar), 4)
        let later = today.adding(days: 3, calendar: calendar)
        XCTAssertEqual(progress.streak(today: later, calendar: calendar), 0, "a gap starts a new count")
    }

    func testLevelsGrowWithVersesRead() {
        XCTAssertEqual(WordLevel.for(read: 0).name, "Seed")
        XCTAssertEqual(WordLevel.for(read: 9).number, 1)
        XCTAssertEqual(WordLevel.for(read: 10).name, "Sprout")
        XCTAssertEqual(WordLevel.for(read: 5000).name, "Mountain")
        XCTAssertNil(WordLevel.for(read: 9999).next)
        XCTAssertEqual(WordLevel.for(read: 20).progress(read: 20), 0.5, accuracy: 0.001)
        var progress = WordProgress()
        var levelUps: [Int] = []
        for _ in 0..<30 {
            for event in progress.recordRead(theme: "hope", today: today, goal: 100, calendar: calendar) {
                if case .levelUp(let level) = event { levelUps.append(level.number) }
            }
        }
        XCTAssertEqual(levelUps, [2, 3])
    }

    func testBadgesAreAwardedOnce() {
        var progress = WordProgress()
        XCTAssertEqual(progress.recordSaved(today: today), [.badge(.firstSave)])
        XCTAssertEqual(progress.recordSaved(today: today), [])
        XCTAssertEqual(progress.recordSent(today: today), [.badge(.firstSend)])
        for _ in 0..<9 { _ = progress.recordQuiz(.finish, right: true, today: today) }
        XCTAssertEqual(progress.recordQuiz(.finish, right: true, today: today), [.badge(.finish10)])
        _ = progress.recordQuiz(.who, right: false, today: today)
        XCTAssertEqual(progress.whoPlayed, 1)
        XCTAssertEqual(progress.whoRight, 0)
        for theme in WordFeedPlanner.topics { _ = progress.recordRead(theme: theme, today: today, goal: 100, calendar: calendar) }
        XCTAssertTrue(progress.badges.contains(.allThemes))
        XCTAssertEqual(Set(progress.badges).count, progress.badges.count)
    }

    func testBoardsHoldSavedVerses() {
        var progress = WordProgress()
        progress.ensureBoards()
        XCTAssertEqual(progress.boards.map(\.name), ["Morning", "Hard days", "Promises"])
        progress.ensureBoards()
        XCTAssertEqual(progress.boards.count, 3, "starters only once")
        let morning = progress.boards[0].id
        XCTAssertEqual(progress.add(ref: "Psalm 5:3", toBoard: morning, today: today), [.badge(.firstBoard)])
        _ = progress.add(ref: "Lamentations 3:22-23", toBoard: morning, today: today)
        _ = progress.add(ref: "Psalm 5:3", toBoard: morning, today: today)
        XCTAssertEqual(progress.boards[0].refs, ["Psalm 5:3", "Lamentations 3:22-23"], "once each, newest first")
        let mine = progress.addBoard(name: "  For Mom and everyone I love very much indeed  ", emoji: "💛")
        XCTAssertEqual(mine?.name.count, WordBoard.maxNameLength)
        XCTAssertEqual(progress.addBoard(name: "morning", emoji: "✨")?.id, morning, "no duplicate names")
        XCTAssertNil(progress.addBoard(name: "   ", emoji: "✨"))
        _ = progress.add(ref: "Psalm 5:3", toBoard: mine!.id, today: today)
        XCTAssertEqual(progress.boards(containing: "Psalm 5:3").count, 2)
        progress.removeEverywhere(ref: "Psalm 5:3")
        XCTAssertTrue(progress.boards(containing: "Psalm 5:3").isEmpty)
        progress.remove(ref: "Lamentations 3:22-23", fromBoard: morning)
        XCTAssertTrue(progress.boards[0].refs.isEmpty)
        progress.deleteBoard(mine!.id)
        XCTAssertEqual(progress.boards.count, 3)
    }

    func testProgressSurvivesARoundTripAndJunk() throws {
        var progress = WordProgress()
        _ = progress.recordRead(theme: "rest", today: today, goal: 1, calendar: calendar)
        progress.ensureBoards()
        progress.markExtraSeen("f1")
        let back = try JSONDecoder().decode(WordProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(back, progress)
        let junk = try JSONDecoder().decode(WordProgress.self, from: Data(#"{"totalRead": "lots", "badges": ["firstSave", "madeUp"]}"#.utf8))
        XCTAssertEqual(junk.totalRead, 0)
        XCTAssertEqual(junk.badges, [.firstSave])
    }

    func testOldDaysAreTrimmed() {
        var progress = WordProgress()
        for back in 0..<130 { progress.readByDay[today.adding(days: -back, calendar: calendar).string] = 1 }
        _ = progress.recordRead(theme: nil, today: today, goal: 50, calendar: calendar)
        XCTAssertLessThanOrEqual(progress.readByDay.count, 121)
        XCTAssertEqual(progress.readOn(today.string), 2)
    }

    func testTheStoreKeepsProgressAndEraseClearsIt() throws {
        let store = SharedStore(defaults: makeScratchDefaults())
        var progress = WordProgress()
        progress.totalRead = 42
        store.wordProgressData = try JSONEncoder().encode(progress)
        let back = try JSONDecoder().decode(WordProgress.self, from: XCTUnwrap(store.wordProgressData))
        XCTAssertEqual(back.totalRead, 42)
        store.resetAll()
        XCTAssertNil(store.wordProgressData)
    }
}

// MARK: - Content (scroll.json)

final class ScrollLibraryTests: XCTestCase {
    func testAtLeastAThousandVersesWithUniqueReferences() throws {
        let daily = try SourceFiles.daily()
        let library = try SourceFiles.scroll()
        let all = library.feedVerses(daily: daily)
        XCTAssertGreaterThanOrEqual(all.count, 1000)
        XCTAssertEqual(all.count, daily.count + library.verses.count, "no extra repeats a daily verse")
        XCTAssertEqual(Set(all.map(\.ref)).count, all.count, "every reference once")
        XCTAssertEqual(Set(all.map(\.day)).count, all.count, "every id once")
        XCTAssertTrue(library.verses.allSatisfy { $0.day >= ScrollContent.firstExtraDay })
        for theme in themes {
            XCTAssertGreaterThanOrEqual(all.filter { $0.theme == theme }.count, 60, "\(theme) has a deep feed")
        }
    }

    func testEveryExtraVerseHasTextKjvAndAHouseStyleMeaning() throws {
        for verse in try SourceFiles.scroll().verses {
            let tag = "\(verse.day) \(verse.ref)"
            XCTAssertTrue(themes.contains(verse.theme ?? ""), tag)
            XCTAssertGreaterThan(verse.text.count, 20, tag)
            XCTAssertLessThanOrEqual(verse.text.count, 320, tag)
            XCTAssertFalse(verse.kjv?.isEmpty ?? true, tag)
            XCTAssertFalse(verse.text.contains("Yahweh"), tag)
            XCTAssertEqual(verse.text.filter { $0 == "\u{201C}" }.count, verse.text.filter { $0 == "\u{201D}" }.count, "quotes balance: \(tag)")
            XCTAssertTrue(verse.text.first.map { !$0.isLowercase } ?? false, "starts with a capital: \(tag)")
            let meaning = try XCTUnwrap(verse.meaning, tag)
            XCTAssertTrue((40...120).contains(meaning.count), "\(tag): meaning is \(meaning.count) chars")
            XCTAssertFalse(meaning.contains("'") || meaning.contains("\""), "curly quotes: \(tag)")
            XCTAssertFalse(meaning.contains("—") || meaning.contains("–"), "no dashes: \(tag)")
            XCTAssertTrue(meaning.first?.isUppercase ?? false, tag)
            XCTAssertTrue([".", "?", "!"].contains(meaning.last.map(String.init) ?? ""), tag)
            XCTAssertFalse(meaning.lowercased().hasPrefix("this verse"), tag)
        }
    }

    func testMeaningsAreAllDifferent() throws {
        let meanings = try (SourceFiles.daily() + SourceFiles.scroll().verses).compactMap(\.meaning)
        XCTAssertEqual(Set(meanings).count, meanings.count)
    }

    func testFactsAreShortAndShowTheirVerse() throws {
        let facts = try SourceFiles.scroll().facts
        XCTAssertGreaterThanOrEqual(facts.count, 40)
        XCTAssertEqual(Set(facts.map(\.id)).count, facts.count)
        for fact in facts {
            XCTAssertTrue((50...150).contains(fact.text.count), fact.id)
            XCTAssertFalse(fact.text.contains("'") || fact.text.contains("\""), fact.id)
            XCTAssertFalse(fact.verseText?.isEmpty ?? true, "\(fact.id) has its verse")
            XCTAssertNotNil(fact.ref.range(of: #"^.+ \d+:\d+(-\d+)?$"#, options: .regularExpression), fact.ref)
        }
        let methuselah = try XCTUnwrap(facts.first { $0.ref == "Genesis 5:27" })
        XCTAssertTrue(methuselah.verseText?.contains("nine hundred sixty-nine years") ?? false)
    }

    func testWhoSaidItHasThreeNamesAndTheSpeakerIsOne() throws {
        let quizzes = try SourceFiles.scroll().whoSaid
        XCTAssertGreaterThanOrEqual(quizzes.count, 40)
        for quiz in quizzes {
            XCTAssertEqual(quiz.choices.count, 3, quiz.id)
            XCTAssertEqual(Set(quiz.choices).count, 3, quiz.id)
            XCTAssertTrue(quiz.choices.contains(quiz.speaker), quiz.id)
            XCTAssertTrue((15...175).contains(quiz.quote.count), quiz.id)
            for name in quiz.choices where name != quiz.speaker {
                XCTAssertFalse(quiz.quote.contains(name), "\(quiz.id): the quote gives away a decoy")
            }
        }
        let ruth = try XCTUnwrap(quizzes.first { $0.ref == "Ruth 1:16" })
        XCTAssertEqual(ruth.speaker, "Ruth")
    }

    func testFinishTheVerseAnswersAreHowTheVerseEnds() throws {
        let cards = try SourceFiles.scroll().finish
        XCTAssertGreaterThanOrEqual(cards.count, 50)
        for card in cards {
            let body = card.text.trimmingCharacters(in: CharacterSet(charactersIn: ".!?…\u{201D}\u{2019} "))
            XCTAssertTrue(body.lowercased().hasSuffix(card.answer.lowercased()), "\(card.ref): \(card.answer)")
            XCTAssertTrue(card.prompt.contains(FinishVerse.blank), card.ref)
            XCTAssertFalse(card.prompt.lowercased().contains(card.answer.lowercased()) && card.answer.count > 6,
                           "\(card.ref): the answer isn't left showing")
            XCTAssertEqual(card.decoys.count, 2, card.ref)
            XCTAssertEqual(Set(([card.answer] + card.decoys).map { $0.lowercased() }).count, 3, card.ref)
            XCTAssertTrue((1...4).contains(card.answer.split(separator: " ").count), card.ref)
            XCTAssertLessThanOrEqual(card.text.count, 230, card.ref)
        }
        let strength = try XCTUnwrap(cards.first { $0.ref == "Philippians 4:13" })
        XCTAssertEqual(strength.answer, "who strengthens me")
    }

    func testReflectionQuestionsCoverEveryTheme() throws {
        let questions = try SourceFiles.scroll().reflect
        XCTAssertEqual(Set(questions.map(\.question)).count, questions.count)
        for theme in themes { XCTAssertGreaterThanOrEqual(questions.filter { $0.theme == theme }.count, 3, theme) }
        for question in questions {
            XCTAssertTrue(themes.contains(question.theme), question.id)
            XCTAssertTrue(question.question.hasSuffix("?"), question.id)
            XCTAssertTrue((25...110).contains(question.question.count), question.id)
            XCTAssertFalse(question.question.contains("'") || question.question.contains("\""), question.id)
        }
    }
}

final class WordGoalChangeTests: XCTestCase {
    func testLoweringTheGoalMidDayStillCountsTheDay() {
        let calendar = TestCalendar.newYork
        let today = TestCalendar.day(2026, 11, 16)
        var progress = WordProgress()
        for _ in 0..<7 { _ = progress.recordRead(theme: "peace", today: today, goal: 10, calendar: calendar) }
        XCTAssertTrue(progress.goalDays.isEmpty)
        let events = progress.recordRead(theme: "peace", today: today, goal: 5, calendar: calendar)
        XCTAssertTrue(events.contains(.goalReached(5)))
        XCTAssertEqual(progress.goalDays, [today.string])
    }
}
