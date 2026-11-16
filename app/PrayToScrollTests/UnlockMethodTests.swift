import XCTest
@testable import PrayToScroll

/// Unlock with: Prayer / Read a verse / Devotional, the 60+ devotionals, and the minimum read times.
final class UnlockMethodTests: XCTestCase {
    private static let books: Set<String> = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
        "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job", "Psalm", "Psalms",
        "Proverbs", "Ecclesiastes", "Song of Songs", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea",
        "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
        "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
        "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon",
        "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation",
    ]

    private func devotionals() throws -> [Devotional] {
        let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "devotionals", withExtension: "json"))
        return try JSONDecoder().decode([Devotional].self, from: Data(contentsOf: url))
    }

    private func words(_ text: String) -> Int { ReadingTime.wordCount([text]) }

    // MARK: Devotionals

    func testAtLeastSixtyDevotionalsEachOneOfAKind() throws {
        let all = try devotionals()
        XCTAssertGreaterThanOrEqual(all.count, 60)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "ids are unique")
        XCTAssertEqual(Set(all.map(\.title)).count, all.count, "titles are unique")
        XCTAssertEqual(Set(all.map(\.ref)).count, all.count, "no verse is used twice")
    }

    func testEveryDevotionalIsAboutOneHundredTwentyWordsWithAOneLinePrayer() throws {
        for d in try devotionals() {
            XCTAssertTrue((100...140).contains(words(d.body)), "\(d.id) body is \(words(d.body)) words")
            XCTAssertTrue(d.prayer.hasSuffix("Amen."), "\(d.id) prayer ends with Amen.")
            XCTAssertLessThanOrEqual(words(d.prayer), 30, "\(d.id) prayer is one line")
            XCTAssertFalse(d.prayer.contains("\n"), d.id)
            XCTAssertTrue((1...6).contains(words(d.title)), "\(d.id) title is short")
            XCTAssertFalse(d.theme.isEmpty, d.id)
        }
    }

    func testEveryVerseReferenceIsARealBookChapterAndVerse() throws {
        let pattern = try NSRegularExpression(pattern: #"^((?:[123] )?[A-Z][a-z]+(?: of [A-Z][a-z]+)?) (\d{1,3}):(\d{1,3})(?:-(\d{1,3}))?$"#)
        for d in try devotionals() {
            let range = NSRange(d.ref.startIndex..., in: d.ref)
            guard let match = pattern.firstMatch(in: d.ref, range: range),
                  let bookRange = Range(match.range(at: 1), in: d.ref),
                  let firstRange = Range(match.range(at: 3), in: d.ref) else {
                XCTFail("\(d.id): \(d.ref) isn't Book chapter:verse"); continue
            }
            XCTAssertTrue(Self.books.contains(String(d.ref[bookRange])), "\(d.id): unknown book in \(d.ref)")
            if let lastRange = Range(match.range(at: 4), in: d.ref) {
                XCTAssertTrue((Int(d.ref[firstRange]) ?? 0) < (Int(d.ref[lastRange]) ?? 0), "\(d.id): \(d.ref) runs forwards")
            }
        }
    }

    func testVerseTextIsTheBundledPublicDomainText() throws {
        for d in try devotionals() {
            XCTAssertGreaterThanOrEqual(words(d.text), 5, "\(d.id) has its WEB text")
            XCTAssertGreaterThanOrEqual(words(d.kjv ?? ""), 5, "\(d.id) has its KJV text")
            XCTAssertFalse(d.text.contains("Yahweh"), "\(d.id): the WEB edition we ship says LORD")
            XCTAssertFalse(d.text.contains("{") || d.text.contains("\\"), "\(d.id): no markup left in the text")
        }
    }

    func testOurWordsFollowTheHouseStyle() throws {
        for d in try devotionals() {
            for part in [d.title, d.body, d.prayer] {
                XCTAssertFalse(part.contains("'") || part.contains("\""), "\(d.id): curly quotes and apostrophes only")
                XCTAssertFalse(part.contains("—"), "\(d.id): no em dashes")
                XCTAssertFalse(part.contains("  "), "\(d.id): no double spaces")
            }
        }
    }

    // MARK: Read times

    func testEveryDevotionalTakesSixtyToNinetySeconds() throws {
        for d in try devotionals() {
            XCTAssertTrue(ReadingTime.devotionalRange.contains(ReadingTime.devotional(words: d.readingWords)), d.id)
        }
        XCTAssertEqual(ReadingTime.devotional(words: 50), 60, "short ones still take a minute")
        XCTAssertEqual(ReadingTime.devotional(words: 400), 90, "long ones are capped at 90 seconds")
        XCTAssertEqual(ReadingTime.devotional(words: 200), 80, "about 150 words a minute")
    }

    func testVerseReadTimeScalesWithLength() throws {
        XCTAssertEqual(ReadingTime.verse(words: 0), 8, "never shorter than 8 seconds")
        XCTAssertEqual(ReadingTime.verse(words: 30), 13)
        XCTAssertEqual(ReadingTime.verse(words: 60), 23)
        XCTAssertEqual(ReadingTime.verse(words: 500), 40, "capped")
        var last = 0
        for count in stride(from: 0, through: 120, by: 5) {
            let seconds = ReadingTime.verse(words: count)
            XCTAssertGreaterThanOrEqual(seconds, last, "longer never means less time")
            last = seconds
        }
        let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "verses", withExtension: "json"))
        let verses = VerseProvider.decode(try Data(contentsOf: url))
        XCTAssertEqual(verses.count, 366)
        for verse in verses {
            let meaning = try XCTUnwrap(verse.meaning, "\(verse.ref) has its what-this-means line")
            XCTAssertFalse(meaning.isEmpty, verse.ref)
            XCTAssertTrue(ReadingTime.verseRange.contains(ReadingTime.verse(words: ReadingTime.wordCount([verse.text, meaning]))), verse.ref)
        }
    }

    func testWordCountSplitsOnSpacesAndNewlines() {
        XCTAssertEqual(ReadingTime.wordCount(["Be still,  and know", "that I\nam God."]), 8)
        XCTAssertEqual(ReadingTime.wordCount([""]), 0)
    }

    // MARK: The setting

    func testPrayerIsTheDefaultAndOldSettingsDecodeToIt() throws {
        XCTAssertEqual(AppSettings().unlockMethod, .prayer)
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"unlockStyle":"quick"}"#.utf8))
        XCTAssertEqual(old.unlockMethod, .prayer)
        XCTAssertEqual(old.unlockStyle, .quick)
        var settings = AppSettings()
        settings.unlockMethod = .devotional
        let back = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(back.unlockMethod, .devotional)
        let unknown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"unlockMethod":"podcast"}"#.utf8))
        XCTAssertEqual(unknown.unlockMethod, .prayer, "an unknown value falls back to Prayer")
    }

    func testEachMethodStartsTheRightSession() {
        XCTAssertEqual(UnlockMethod.prayer.style(prayerStyle: .quick), .quick)
        XCTAssertEqual(UnlockMethod.prayer.style(prayerStyle: .forSomeone), .forSomeone)
        XCTAssertEqual(UnlockMethod.verse.style(prayerStyle: .quick), .readVerse)
        XCTAssertEqual(UnlockMethod.devotional.style(prayerStyle: .guided), .devotional)
        XCTAssertEqual(UnlockMethod.prayer.style(prayerStyle: .devotional), .guided, "a prayer is always a prayer style")
        for method in UnlockMethod.allCases {
            XCTAssertEqual(UnlockMethod(style: method.style(prayerStyle: .verse)), method)
        }
        XCTAssertEqual(UnlockStyle.prayerStyles, [.quick, .guided, .verse, .forSomeone])
        XCTAssertTrue(UnlockStyle.prayerStyles.allSatisfy { !$0.isReading })
        XCTAssertTrue(UnlockStyle.readVerse.isReading && UnlockStyle.devotional.isReading)
    }
}
