import XCTest
@testable import PrayToScroll

/// Scroll the Word's order: topic feeds, today's verse first, and no repeats across sessions.
final class WordFeedPlannerTests: XCTestCase {
    private let themes = WordFeedPlanner.topics
    private lazy var verses: [Verse] = (1...140).map {
        Verse(day: $0, ref: "Psalm \($0):1", text: "Verse \($0)", theme: themes[$0 % themes.count])
    }

    func testForYouStartsWithTodaysVerseAndHasEveryVerseOnce() {
        let order = WordFeedPlanner.order(verses: verses, topic: nil, seen: [], today: 42, seed: 7)
        XCTAssertEqual(order.first?.day, 42)
        XCTAssertEqual(order.count, verses.count)
        XCTAssertEqual(Set(order.map(\.day)).count, verses.count, "no verse twice")
    }

    func testATopicFeedOnlyHasThatTopic() {
        let order = WordFeedPlanner.order(verses: verses, topic: "anxiety", seen: [], today: 42, seed: 7)
        XCTAssertFalse(order.isEmpty)
        XCTAssertTrue(order.allSatisfy { $0.theme == "anxiety" })
        XCTAssertEqual(order.count, verses.filter { $0.theme == "anxiety" }.count)
    }

    func testTheNextSessionOpensOnVersesYouHaventSeen() {
        var seen: [Int] = []
        var shown = Set<Int>()
        // Five sessions of 20 cards each: no card repeats until the feed has been read through.
        for _ in 0..<5 {
            let order = WordFeedPlanner.order(verses: verses, topic: nil, seen: seen, today: 42, seed: 99)
            for verse in order.prefix(20) {
                XCTAssertFalse(shown.contains(verse.day), "verse \(verse.day) repeated before the feed was read through")
                shown.insert(verse.day)
                seen = WordFeedPlanner.markSeen(verse.day, in: seen)
            }
        }
        XCTAssertEqual(shown.count, 100)
    }

    func testOnceEverythingIsSeenTheLongestAgoComesBackFirst() {
        let seen = verses.map(\.day).reversed().map { $0 }   // 140 seen first, 1 seen last
        let order = WordFeedPlanner.order(verses: verses, topic: nil, seen: seen, today: 42, seed: 3)
        XCTAssertEqual(order.first?.day, 140)
        XCTAssertEqual(order.last?.day, 1)
    }

    func testTheShuffleIsStablePerInstallAndDiffersBetweenInstalls() {
        let a = WordFeedPlanner.order(verses: verses, topic: nil, seen: [], today: nil, seed: 1).map(\.day)
        let again = WordFeedPlanner.order(verses: verses, topic: nil, seen: [], today: nil, seed: 1).map(\.day)
        let other = WordFeedPlanner.order(verses: verses, topic: nil, seen: [], today: nil, seed: 2).map(\.day)
        XCTAssertEqual(a, again)
        XCTAssertNotEqual(a, other)
        XCTAssertNotEqual(a, verses.map(\.day), "not just calendar order")
    }

    func testMarkSeenMovesARepeatToTheEndAndCaps() {
        XCTAssertEqual(WordFeedPlanner.markSeen(2, in: [1, 2, 3]), [1, 3, 2])
        XCTAssertEqual(WordFeedPlanner.markSeen(9, in: Array(1...5), limit: 5), [2, 3, 4, 5, 9])
    }

    func testTheStoreRemembersSeenVersesAndKeepsItsSeed() {
        let store = SharedStore(defaults: makeScratchDefaults())
        store.markVerseSeen(5)
        store.markVerseSeen(6)
        store.markVerseSeen(5)
        XCTAssertEqual(store.wordSeen, [6, 5])
        XCTAssertEqual(store.wordSeed, store.wordSeed, "made once")
    }

    func testADifferentCardEveryTwoOrThreeVerses() {
        let items = FeedMixer.build(.init(verses: Array(verses.prefix(12)), content: ScrollContent(),
                                          prompts: ["Pray A.", "Pray {name}.", "Pray B."], topic: nil, seed: 1))
        XCTAssertEqual(items.first?.kind, .verse)
        var run = 0
        for item in items.dropLast() {
            if item.kind == .verse { run += 1 } else { XCTAssertTrue((2...3).contains(run), "verses before \(item.id): \(run)"); run = 0 }
        }
        XCTAssertFalse(items.contains { $0.prompt?.contains("{name}") == true })
        XCTAssertEqual(Set(items.map(\.id)).count, items.count, "ids are unique")
    }
}
