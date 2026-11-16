import XCTest
@testable import PrayToScroll

final class LinksAndContentTests: XCTestCase {
    // MARK: Circle codes

    func testCircleCodesAreReadableAndNormalize() {
        var rng = SplitMix64(seed: 42)
        for _ in 0..<200 {
            let code = CircleCode.generate(using: &rng)
            XCTAssertTrue(CircleCode.isValid(code))
            XCTAssertFalse(code.contains("0") || code.contains("O") || code.contains("1") || code.contains("I"))
        }
        XCTAssertEqual(CircleCode.normalize(" k7q-2mx "), "K7Q2MX")
        XCTAssertEqual(CircleCode.normalize("K7Q 2MX"), "K7Q2MX")
        XCTAssertNil(CircleCode.normalize("K7Q2M"))
        XCTAssertNil(CircleCode.normalize("K7Q2M0"), "0 isn't in the alphabet")
        XCTAssertEqual(CircleCode.pretty("K7Q2MX"), "K7Q 2MX")
        XCTAssertEqual(CircleCode.extract(from: "Join me! https://praytoscroll.vercel.app/join?c=k7q2mx"), nil,
                       "free text around a link isn't parsed as a URL")
        XCTAssertEqual(CircleCode.extract(from: "https://praytoscroll.vercel.app/join?c=k7q2mx"), "K7Q2MX")
        XCTAssertEqual(CircleCode.extract(from: "prayscroll://join?code=R4NB8T"), "R4NB8T")
    }

    // MARK: Deep links

    func testDeepLinks() {
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://pray")!), .pray(appID: nil, mood: nil))
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://pray?app=Instagram")!), .pray(appID: "instagram", mood: nil))
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://tempted")!), .pray(appID: nil, mood: .tempted))
        XCTAssertEqual(DeepLink(url: URL(string: "amenkey://pray")!), .pray(appID: nil, mood: nil), "legacy scheme")
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://join?c=k7q-2mx")!), .join(code: "K7Q2MX"))
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://join/R4NB8T")!), .join(code: "R4NB8T"))
        XCTAssertEqual(DeepLink(url: URL(string: "https://praytoscroll.vercel.app/join?c=R4NB8T")!), .join(code: "R4NB8T"))
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://challenge/seven-days")!), .challenge(id: "seven-days"))
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://stats")!), .stats)
        XCTAssertEqual(DeepLink(url: URL(string: "prayscroll://word")!), .word)
        XCTAssertNil(DeepLink(url: URL(string: "prayscroll://join?c=bad")!))
        XCTAssertNil(DeepLink(url: URL(string: "otherapp://pray")!))
        XCTAssertNil(DeepLink(url: URL(string: "prayscroll://nope")!))
    }

    func testAppLinksRoundTripThroughDeepLink() {
        XCTAssertEqual(DeepLink(url: AppLinks.joinDeepLink(code: "K7Q2MX")), .join(code: "K7Q2MX"))
        XCTAssertEqual(DeepLink(url: AppLinks.joinWebURL(code: "K7Q2MX")), .join(code: "K7Q2MX"))
        XCTAssertEqual(DeepLink(url: AppLinks.prayDeepLink(app: "tiktok")), .pray(appID: "tiktok", mood: nil))
        XCTAssertEqual(DeepLink(url: AppLinks.statsDeepLink), .stats)
        XCTAssertTrue(AppLinks.privacyURL.absoluteString.hasPrefix("https://"))
    }

    // MARK: Prompt bag

    func testPromptBagNeverRepeatsUntilThePoolIsUsedUp() {
        var bags: [String: [Int]] = [:]
        var rng = SplitMix64(seed: 7)
        var previousLast: Int?
        for _ in 0..<20 {
            var seen = Set<Int>()
            var first: Int?
            for _ in 0..<6 {
                let i = PromptBag.draw(key: "adoration", poolCount: 6, bags: &bags, using: &rng)
                if first == nil { first = i }
                XCTAssertTrue(seen.insert(i).inserted, "no repeats within a round")
            }
            if let previousLast { XCTAssertNotEqual(first, previousLast, "a round never starts with the last prompt") }
            previousLast = bags["adoration#6#last"]?.first
        }
    }

    func testPromptBagResetsWhenContentChanges() {
        var bags: [String: [Int]] = [:]
        var rng = SplitMix64(seed: 1)
        _ = PromptBag.draw(key: "quick", poolCount: 4, bags: &bags, using: &rng)
        let i = PromptBag.draw(key: "quick", poolCount: 9, bags: &bags, using: &rng)
        XCTAssertTrue((0..<9).contains(i))
        XCTAssertNil(bags["quick#4"], "the old pool's bag is dropped")
        XCTAssertEqual(PromptBag.draw(key: "empty", poolCount: 0, bags: &bags, using: &rng), 0)
    }

    // MARK: Copy + names

    func testCopyPlaceholders() {
        let verse = Verse(day: 1, ref: "Psalm 46:10", text: "Be still, and know that I am God.", theme: nil)
        XCTAssertEqual(CopyBook.fill("Hey {name}", name: "Mark Morrison"), "Hey Mark Morrison")
        XCTAssertEqual(CopyBook.fill("Hey {name}", name: "  "), "Hey friend")
        XCTAssertEqual(CopyBook.fill("{hours} a week", hours: 3), "3 hours a week")
        XCTAssertEqual(CopyBook.fill("{hours} a week", hours: 1), "1 hour a week")
        XCTAssertEqual(CopyBook.fill("{hours} a week", hours: 2.5), "2.5 hours a week")
        XCTAssertEqual(CopyBook.fill("{days} days, {streak} streak", days: 12, streak: 4), "12 days, 4 streak")
        XCTAssertEqual(CopyBook.fill("{verseRef}: {verseText}", verse: verse), "Psalm 46:10: Be still, and know that I am God.")
        XCTAssertEqual(ContentStore.fill("Pray for {name} today", name: "Jake"), "Pray for Jake today")
    }

    func testNameFilter() {
        XCTAssertTrue(NameFilter.isAllowed("Mark"))
        XCTAssertTrue(NameFilter.isAllowed("Grace 🙏"))
        XCTAssertTrue(NameFilter.isAllowed("Lighthouse Group"))
        XCTAssertTrue(NameFilter.isAllowed("Scunthorpe Saints") == NameFilter.isAllowed("Scunthorpe Saints"))
        XCTAssertEqual(NameFilter.problem(with: "M"), .tooShort)
        XCTAssertEqual(NameFilter.problem(with: String(repeating: "a", count: 21)), .tooLong)
        XCTAssertEqual(NameFilter.problem(with: "mark<script>"), .badCharacters)
        XCTAssertEqual(NameFilter.problem(with: "sh1t head"), .notAllowed)
        XCTAssertEqual(NameFilter.clean("  Mark    M  "), "Mark M")
    }

    func testCirclesSeeTheChosenNicknameNeverAnUnfilteredName() {
        var settings = AppSettings()
        settings.firstName = "Mark"
        XCTAssertEqual(settings.circleName, "Mark", "no nickname yet: the first name")
        settings.circleNickname = "  Lighthouse   Guy "
        XCTAssertEqual(settings.circleName, "Lighthouse Guy", "the nickname picked when joining wins")
        settings.circleNickname = ""
        settings.firstName = "sh1t"
        XCTAssertEqual(settings.circleName, "friend", "a name the filter rejects never reaches a circle")
        settings.firstName = ""
        XCTAssertEqual(settings.circleName, "friend")
    }

    // MARK: Bundled content

    func testBundledContentLoads() {
        let content = ContentStore(bundle: Bundle(for: AppModel.self))
        XCTAssertGreaterThanOrEqual(content.prompts.adoration.count, 5)
        XCTAssertGreaterThanOrEqual(content.prompts.forSomeone.count, 5)
        XCTAssertTrue(content.prompts.forSomeone.allSatisfy { !$0.isEmpty })
        XCTAssertFalse(content.challenges.isEmpty)
        XCTAssertEqual(Set(content.challenges.map(\.id)).count, content.challenges.count, "challenge ids are unique")
        XCTAssertFalse(content.copy.string("translationCredit", default: "").isEmpty)
    }

    func testVersesAreCompleteAndUseTheLORD() throws {
        let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "verses", withExtension: "json"))
        let verses = try JSONDecoder().decode([Verse].self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(verses.count, 365)
        XCTAssertTrue(verses.allSatisfy { !$0.ref.isEmpty && !$0.text.isEmpty })
        XCTAssertFalse(verses.contains { $0.text.contains("Yahweh") }, "God's name is rendered \"the LORD\"")
        XCTAssertEqual(Set(verses.map(\.day)).count, verses.count, "one verse per day")
    }

    func testEveryVerseHasKJVTextAndAMeaning() throws {
        let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "verses", withExtension: "json"))
        let verses = try JSONDecoder().decode([Verse].self, from: Data(contentsOf: url))
        for verse in verses {
            let kjv = try XCTUnwrap(verse.kjv, verse.ref)
            XCTAssertGreaterThan(kjv.count, 15, verse.ref)
            XCTAssertFalse(kjv.contains("[") || kjv.contains("¶"), "KJV markup stripped: \(verse.ref)")
            let meaning = try XCTUnwrap(verse.meaning, verse.ref)
            XCTAssertTrue((40...120).contains(meaning.count), "\(verse.ref): \(meaning.count) chars")
            XCTAssertFalse(meaning.contains("'") || meaning.contains("—") || meaning.contains("–"), "house style: \(verse.ref)")
            XCTAssertNotEqual(meaning, verse.text)
        }
        XCTAssertEqual(Set(verses.compactMap(\.meaning)).count, verses.count, "every meaning is its own")
        XCTAssertEqual(Set(verses.compactMap(\.theme)), Set(WordFeedPlanner.topics), "every theme has a topic chip")
    }

    func testTranslationSwitchesTheTextEverywhere() {
        let verse = Verse(day: 1, ref: "Psalm 46:10", text: "Be still, and know that I am God.", theme: "peace",
                          kjv: "Be still, and know that I am God:", meaning: "Stop striving.")
        XCTAssertEqual(verse.displayText, verse.text, "WEB by default")
        XCTAssertEqual(verse.rendered(in: .kjv).displayText, "Be still, and know that I am God:")
        XCTAssertEqual(verse.rendered(in: .kjv).translationName, "King James Version")
        XCTAssertEqual(verse.rendered(in: .kjv).revealLines.joined(separator: " "), "Be still, and know that I am God:")
        var noKJV = verse
        noKJV.kjv = nil
        XCTAssertEqual(noKJV.rendered(in: .kjv).displayText, verse.text, "falls back to WEB")
        XCTAssertEqual(noKJV.rendered(in: .kjv).translationName, "World English Bible", "and says so")
        XCTAssertEqual(VerseReader.spokenRef("John 3:16-17"), "John 3, verses 16 to 17")
        XCTAssertEqual(VerseReader.spokenRef("Psalm 46:10"), "Psalm 46, verse 10")
    }
}
