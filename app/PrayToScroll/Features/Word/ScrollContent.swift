import Foundation

/// "Bible fact" card: one true, checkable line and the reference that shows it.
struct BibleFact: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var text: String
    var ref: String
    /// The reference's World English Bible text ("Read it" on the card).
    var verseText: String?
}

/// "Who said it?": words someone speaks in the Bible (World English Bible), the speaker and two decoys.
struct WhoSaidQuiz: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var ref: String
    var quote: String
    var speaker: String
    var choices: [String]

    /// The three names in an order that's stable for this card but not always answer-first.
    func shuffledChoices(seed: UInt64) -> [String] {
        var rng = SplitMix(seed: seed ^ FeedHash.stable(id))
        return choices.shuffled(using: &rng)
    }

    func isRight(_ choice: String) -> Bool { choice == speaker }
}

/// "Finish the verse": a well-known verse with its last words blanked, the real ending and two decoys.
struct FinishVerse: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var ref: String
    /// The whole verse (World English Bible).
    var text: String
    /// The verse's last 1–4 words, exactly as they appear in `text`.
    var answer: String
    var decoys: [String]

    static let blank = "____"

    /// "I can do all things through Christ who ____."
    var prompt: String {
        guard let range = text.range(of: answer, options: [.backwards, .caseInsensitive]) else { return text }
        return text.replacingCharacters(in: range, with: Self.blank)
    }

    func choices(seed: UInt64) -> [String] {
        var rng = SplitMix(seed: seed ^ FeedHash.stable(id))
        return ([answer] + decoys).shuffled(using: &rng)
    }

    func isRight(_ choice: String) -> Bool { choice == answer }
}

/// A question to sit with, by theme.
struct Reflection: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var theme: String
    var question: String
}

/// Scroll the Word's extra content, from scroll.json (app only; the widget keeps verses.json): more verses past the
/// daily 366 (days 1001+), Bible facts, "Who said it?", "Finish the verse" and reflection questions. Bible text is
/// the World English Bible (KJV alongside for verses), filled in by `tools/bible_text.py scroll`.
struct ScrollContent: Codable, Sendable {
    var verses: [Verse] = []
    var facts: [BibleFact] = []
    var whoSaid: [WhoSaidQuiz] = []
    var finish: [FinishVerse] = []
    var reflect: [Reflection] = []

    /// Extra verses are numbered from here, so they never collide with a day of the year.
    static let firstExtraDay = 1001

    static let shared: ScrollContent = load()

    static func load(bundle: Bundle = .main) -> ScrollContent {
        guard let url = bundle.url(forResource: "scroll", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return ScrollContent() }
        return decode(data) ?? ScrollContent()
    }

    static func decode(_ data: Data) -> ScrollContent? {
        try? JSONDecoder().decode(ScrollContent.self, from: data)
    }

    init(verses: [Verse] = [], facts: [BibleFact] = [], whoSaid: [WhoSaidQuiz] = [], finish: [FinishVerse] = [],
         reflect: [Reflection] = []) {
        self.verses = verses
        self.facts = facts
        self.whoSaid = whoSaid
        self.finish = finish
        self.reflect = reflect
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        verses = try c.decodeIfPresent([Verse].self, forKey: .verses) ?? []
        facts = try c.decodeIfPresent([BibleFact].self, forKey: .facts) ?? []
        whoSaid = try c.decodeIfPresent([WhoSaidQuiz].self, forKey: .whoSaid) ?? []
        finish = try c.decodeIfPresent([FinishVerse].self, forKey: .finish) ?? []
        reflect = try c.decodeIfPresent([Reflection].self, forKey: .reflect) ?? []
    }

    /// Every verse the feed can show: the daily 366 then the extras.
    func feedVerses(daily: [Verse]) -> [Verse] {
        let known = Set(daily.map(\.ref))
        return daily + verses.filter { !known.contains($0.ref) }
    }
}

/// A hash that's the same on every launch (Swift's hashValue isn't), for per-card shuffles.
enum FeedHash {
    static func stable(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        return hash
    }
}
