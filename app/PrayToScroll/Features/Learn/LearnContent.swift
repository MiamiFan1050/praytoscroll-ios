import Foundation

// Learn: Duolingo-style paths of bite-size lessons, the Daily 5, and the learning cards woven into Scroll the Word.
// All content is bundled (Resources/learn.json). Scripture is the World English Bible, word for word: verse cards are
// filled from the reference and every quote is checked by tools/learn_content.py, which fails on any mismatch.

/// A quiz question: multiple choice or true/false, with the verse that settles it and a kind line shown after any answer.
struct LearnQuiz: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var question: String
    var choices: [String]
    var answer: String
    var ref: String
    var explain: String

    var isTrueFalse: Bool { Set(choices) == ["True", "False"] }

    func isRight(_ choice: String) -> Bool { choice == answer }

    /// A stable order for this question: true/false stays "True, False"; other choices are shuffled per question so
    /// the answer isn't always first.
    var orderedChoices: [String] {
        if isTrueFalse { return ["True", "False"] }
        var rng = SplitMix(seed: FeedHash.stable(id + question))
        return LearnShuffle.shuffled(choices, using: &rng)
    }
}

/// One swipe card in a lesson.
struct LessonCard: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// What happened.
        case story
        /// Why it matters.
        case why
        /// The key verse (WEB text, filled from the reference).
        case verse
        /// A quick check.
        case quiz
        /// The lesson in one line.
        case recap
    }

    var kind: Kind
    var text: String?
    var ref: String?
    var question: String?
    var choices: [String]?
    var answer: String?
    var explain: String?

    /// The card as a quiz (quiz cards only).
    func quiz(id: String) -> LearnQuiz? {
        guard kind == .quiz, let question, let choices, let answer, let ref else { return nil }
        return LearnQuiz(id: id, question: question, choices: choices, answer: answer, ref: ref, explain: explain ?? "")
    }
}

struct Lesson: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    /// The whole passage the lesson walks through ("Luke 2:1-20").
    var passage: String
    /// One short first-person prayer to end on.
    var prayer: String
    var cards: [LessonCard]
    /// The section of the path map it sits in ("The last week").
    var unit: String?

    var quizzes: [LearnQuiz] {
        cards.enumerated().compactMap { index, card in card.quiz(id: "\(id)-q\(index)") }
    }

    /// The key verse card (for the "Continue your lesson" card and the path map).
    var keyVerse: LessonCard? { cards.first { $0.kind == .verse } }

    /// About 20 seconds a card.
    var minutes: Int { max(1, Int((Double(cards.count) * 20 / 60).rounded())) }
}

struct LearnPath: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    /// An SF Symbol for the path chip.
    var symbol: String
    var lessons: [Lesson]
}

/// "Jesus said": his own words (red letter), and one plain line on who he was talking to.
struct JesusSaying: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var ref: String
    var quote: String
    var context: String
}

/// "Where and when": a key moment, its place and its era in plain words.
struct PlaceCard: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var place: String
    var when: String
    var text: String
    var ref: String
}

/// A short series ("The life of Peter") whose parts show up one at a time in the feed.
struct LearnSeries: Codable, Hashable, Identifiable, Sendable {
    struct Part: Codable, Hashable, Sendable {
        var text: String
        var ref: String
        /// A one-line teaser for the next part (nil on the last).
        var next: String?
    }

    var id: String
    var title: String
    var parts: [Part]
}

/// Everything in learn.json.
struct LearnLibrary: Codable, Sendable {
    var paths: [LearnPath] = []
    var daily: [LearnQuiz] = []
    var jesusSaid: [JesusSaying] = []
    var places: [PlaceCard] = []
    var series: [LearnSeries] = []

    static let shared: LearnLibrary = load()

    static func load(bundle: Bundle = .main) -> LearnLibrary {
        guard let url = bundle.url(forResource: "learn", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return LearnLibrary() }
        return decode(data) ?? LearnLibrary()
    }

    static func decode(_ data: Data) -> LearnLibrary? {
        try? JSONDecoder().decode(LearnLibrary.self, from: data)
    }

    init(paths: [LearnPath] = [], daily: [LearnQuiz] = [], jesusSaid: [JesusSaying] = [], places: [PlaceCard] = [],
         series: [LearnSeries] = []) {
        self.paths = paths
        self.daily = daily
        self.jesusSaid = jesusSaid
        self.places = places
        self.series = series
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paths = try c.decodeIfPresent([LearnPath].self, forKey: .paths) ?? []
        daily = try c.decodeIfPresent([LearnQuiz].self, forKey: .daily) ?? []
        jesusSaid = try c.decodeIfPresent([JesusSaying].self, forKey: .jesusSaid) ?? []
        places = try c.decodeIfPresent([PlaceCard].self, forKey: .places) ?? []
        series = try c.decodeIfPresent([LearnSeries].self, forKey: .series) ?? []
    }

    func path(_ id: String) -> LearnPath? { paths.first { $0.id == id } }

    /// The path a lesson is in, and its index there.
    func locate(_ lessonID: String) -> (path: LearnPath, index: Int)? {
        for path in paths {
            if let index = path.lessons.firstIndex(where: { $0.id == lessonID }) { return (path, index) }
        }
        return nil
    }

    func lesson(_ id: String) -> Lesson? { locate(id).map { $0.path.lessons[$0.index] } }

    /// Every quiz card in every lesson (they also feed the Daily 5).
    var lessonQuizzes: [LearnQuiz] { paths.flatMap { $0.lessons.flatMap(\.quizzes) } }
}

/// A Bible reference the content uses: "John 3:16", "1 Samuel 16:1-13", "Song of Solomon 2:4".
struct BibleRef: Equatable, Sendable {
    var book: String
    var chapter: Int
    var verse: Int
    var endVerse: Int?

    static let books: [String] = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
        "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job", "Psalm", "Psalms",
        "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea",
        "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
        "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
        "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon",
        "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation",
    ]

    /// nil if it doesn't parse or names no book of the Bible.
    init?(_ text: String) {
        guard let match = text.range(of: #"^(.+) (\d+):(\d+)(-(\d+))?$"#, options: .regularExpression), match == text.startIndex..<text.endIndex else { return nil }
        let parts = text.split(separator: " ")
        guard let tail = parts.last else { return nil }
        let book = parts.dropLast().joined(separator: " ")
        guard Self.books.contains(book) else { return nil }
        let numbers = tail.split(separator: ":")
        guard numbers.count == 2, let chapter = Int(numbers[0]) else { return nil }
        let verses = numbers[1].split(separator: "-").compactMap { Int($0) }
        guard let first = verses.first, chapter > 0, first > 0 else { return nil }
        let last = verses.count > 1 ? verses[1] : nil
        if let last, last < first { return nil }
        self.book = book
        self.chapter = chapter
        self.verse = first
        self.endVerse = last
    }
}

/// A Fisher–Yates shuffle that only uses `next()`, so it gives the same order on every iPhone and iOS version
/// (the Daily 5 has to be the same for everyone).
enum LearnShuffle {
    static func shuffled<T>(_ list: [T], using rng: inout SplitMix) -> [T] {
        var copy = list
        guard copy.count > 1 else { return copy }
        for i in stride(from: copy.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            if i != j { copy.swapAt(i, j) }
        }
        return copy
    }
}
