import XCTest
@testable import PrayToScroll

/// "Add someone" type-ahead and the one-press "Let them know" text.
final class ContactsTests: XCTestCase {
    // MARK: Name search

    func testTypedWordsMustStartWordsOfTheName() {
        XCTAssertTrue(NameSearch.matches("da", name: "Dad"))
        XCTAssertTrue(NameSearch.matches("Da", name: "David Kim"))
        XCTAssertTrue(NameSearch.matches("da", name: "Pastor Dan"), "any word of the name")
        XCTAssertTrue(NameSearch.matches("kim", name: "David Kim"))
        XCTAssertTrue(NameSearch.matches("da k", name: "David Kim"), "every typed word must match")
        XCTAssertFalse(NameSearch.matches("da k", name: "Dad"))
        XCTAssertFalse(NameSearch.matches("ad", name: "Dad"), "prefixes only, not the middle of a word")
        XCTAssertFalse(NameSearch.matches("", name: "Dad"))
        XCTAssertFalse(NameSearch.matches("   ", name: "Dad"))
    }

    func testSearchIgnoresCaseAndAccents() {
        XCTAssertTrue(NameSearch.matches("zoe", name: "Zoë Hart"))
        XCTAssertTrue(NameSearch.matches("ZOË", name: "zoe hart"))
        XCTAssertTrue(NameSearch.matches("jose", name: "José Ramírez"))
        XCTAssertTrue(NameSearch.matches("brien", name: "Sean O'Brien"), "apostrophes split words")
    }

    func testOneTypedWordCantMatchTheSameNameWordTwice() {
        XCTAssertFalse(NameSearch.matches("da da", name: "Dad"))
        XCTAssertTrue(NameSearch.matches("da da", name: "Dad Daniels"))
    }

    func testRankingPutsFirstNameMatchesFirstThenShorterNames() {
        let names = ["Pastor Dan", "Danielle Brooks", "David Kim", "Dad", "Mom"]
        XCTAssertEqual(NameSearch.rank("Da", names, name: { $0 }), ["Dad", "David Kim", "Danielle Brooks", "Pastor Dan"])
        XCTAssertEqual(NameSearch.rank("dad", names, name: { $0 }).first, "Dad", "an exact first word wins")
        XCTAssertEqual(NameSearch.rank("Da", names, name: { $0 }, limit: 2), ["Dad", "David Kim"])
        XCTAssertEqual(NameSearch.rank("x", names, name: { $0 }), [])
    }

    func testSameNameComparesWordsNotSpacingOrCase() {
        XCTAssertTrue(NameSearch.sameName("dad", " Dad "))
        XCTAssertTrue(NameSearch.sameName("Sarah  Mitchell", "sarah mitchell"))
        XCTAssertFalse(NameSearch.sameName("Dad", "Dada"))
        XCTAssertFalse(NameSearch.sameName("", ""))
    }

    func testTheDemoBookFindsDadFirstForDa() {
        let top = NameSearch.rank("Da", DemoContacts.book, name: \.name)
        XCTAssertEqual(top.first?.name, "Dad")
        XCTAssertEqual(top.first?.phone, "(555) 010-0100")
        XCTAssertEqual(Set(top.map(\.name)), ["Dad", "Danielle Brooks", "David Kim"])
    }

    // MARK: Contacts

    func testBestPhonePrefersAMobileNumber() {
        XCTAssertEqual(ContactMatch.bestPhone(from: [(label: "_$!<Home>!$_", number: "111"), (label: "_$!<Mobile>!$_", number: "222")]), "222")
        XCTAssertEqual(ContactMatch.bestPhone(from: [(label: "_$!<Work>!$_", number: "111"), (label: "iPhone", number: "333")]), "333")
        XCTAssertEqual(ContactMatch.bestPhone(from: [(label: nil, number: "444"), (label: "_$!<Work>!$_", number: "555")]), "444")
        XCTAssertEqual(ContactMatch.bestPhone(from: [(label: "_$!<Mobile>!$_", number: "  "), (label: nil, number: "666")]), "666")
        XCTAssertNil(ContactMatch.bestPhone(from: []))
    }

    func testDisplayNameFallsBackToTheNickname() {
        XCTAssertEqual(ContactNames.display(given: "David", family: "Kim"), "David Kim")
        XCTAssertEqual(ContactNames.display(given: " Dad ", family: ""), "Dad")
        XCTAssertEqual(ContactNames.display(given: "", family: "", nickname: "Grandpa"), "Grandpa")
        XCTAssertEqual(ContactNames.display(given: "", family: ""), "")
    }

    func testOnlyFullOrLimitedAccessCanSearch() {
        XCTAssertTrue(ContactsAccess.full.canSearch)
        XCTAssertTrue(ContactsAccess.limited.canSearch, "iOS 18's limited access searches the shared contacts")
        XCTAssertFalse(ContactsAccess.denied.canSearch)
        XCTAssertFalse(ContactsAccess.notDetermined.canSearch)
    }

    // MARK: The "Let them know" text

    private let link = URL(string: "https://praytoscroll.vercel.app")!

    /// Read from the source tree, so this runs in both the hosted CI tests and the local runner.
    private func promptsFile() throws -> [String] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../PrayToScroll/Resources/prompts.json").standardizedFileURL
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["forSomeone"] as? [String] ?? []
    }

    func testEveryForSomeonePromptHasALineSpokenToThePerson() throws {
        let prompts = try promptsFile()
        XCTAssertGreaterThanOrEqual(prompts.count, 40)
        for prompt in prompts {
            XCTAssertNotNil(LetThemKnowMessage.lines[prompt], "no text line for: \(prompt)")
        }
        for (prompt, line) in LetThemKnowMessage.lines {
            XCTAssertFalse(line.contains("{") || line.contains("}"), "a placeholder left in: \(line)")
            XCTAssertTrue(line.hasPrefix("I "), "speaks as the one who prayed: \(line)")
            XCTAssertFalse(line.lowercased().contains(" they ") || line.lowercased().contains(" their "),
                           "speaks to them, not about them: \(prompt)")
            XCTAssertLessThanOrEqual(line.count, 100)
        }
    }

    func testTheMessageIsWarmShortAndFilledIn() throws {
        for prompt in try promptsFile() {
            let text = LetThemKnowMessage.build(template: prompt, link: link)
            XCTAssertTrue(text.hasPrefix("I just prayed for you 🙏 "), text)
            XCTAssertTrue(text.hasSuffix(link.absoluteString), text)
            XCTAssertFalse(text.contains("{name}") || text.contains("{") || text.contains("}"), text)
            XCTAssertLessThanOrEqual(text.count, LetThemKnowMessage.maxLength, text)
            XCTAssertTrue(text.contains(LetThemKnowMessage.lines[prompt] ?? "missing"), text)
        }
    }

    func testTheMessageWithoutAPromptUsesAVerseOrTheFallback() {
        let plain = LetThemKnowMessage.build(template: nil, link: link)
        XCTAssertEqual(plain, "I just prayed for you 🙏 \(LetThemKnowMessage.fallbackLine)\n\n\(link.absoluteString)")

        let short = Verse(day: 1, ref: "Numbers 6:24", text: "The Lord bless you and keep you.")
        let withVerse = LetThemKnowMessage.build(template: nil, verse: short, link: link)
        XCTAssertTrue(withVerse.contains("\u{201C}The Lord bless you and keep you.\u{201D} Numbers 6:24"), withVerse)

        let long = Verse(day: 2, ref: "Long 1:1", text: String(repeating: "word ", count: 40))
        XCTAssertFalse(LetThemKnowMessage.build(template: nil, verse: long, link: link).contains("Long 1:1"),
                       "a long verse would bury the point, so the line is used instead")

        let unknown = LetThemKnowMessage.build(template: "Some new prompt for {name}.", link: link)
        XCTAssertTrue(unknown.contains(LetThemKnowMessage.fallbackLine), "an unknown prompt never leaks its {name} text")
    }
}
