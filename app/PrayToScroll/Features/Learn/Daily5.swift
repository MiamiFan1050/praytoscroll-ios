import Foundation

/// One Daily 5 (or practice) question, whatever it came from: a quiz, "Who said it?" or "Finish the verse".
struct Daily5Question: Hashable, Identifiable, Sendable {
    enum Kind: String, Hashable, Sendable { case quiz, trueFalse, whoSaid, finish }

    var id: String
    var kind: Kind
    var prompt: String
    /// The words in question ("Who said it?").
    var quote: String?
    var choices: [String]
    var answer: String
    var ref: String
    /// Shown after any answer, right or wrong.
    var explain: String

    func isRight(_ choice: String) -> Bool { choice == answer }

    var overline: String {
        switch kind {
        case .quiz: return "Question"
        case .trueFalse: return "True or false?"
        case .whoSaid: return "Who said it?"
        case .finish: return "Finish the verse"
        }
    }

    init(_ quiz: LearnQuiz) {
        id = quiz.id
        kind = quiz.isTrueFalse ? .trueFalse : .quiz
        prompt = quiz.question
        choices = quiz.orderedChoices
        answer = quiz.answer
        ref = quiz.ref
        explain = quiz.explain
    }

    init(_ who: WhoSaidQuiz) {
        id = who.id
        kind = .whoSaid
        prompt = "Who said it?"
        quote = who.quote
        choices = who.shuffledChoices(seed: 0)
        answer = who.speaker
        ref = who.ref
        explain = "It was \(who.speaker), \(who.ref)."
    }

    init(_ finish: FinishVerse) {
        id = finish.id
        kind = .finish
        prompt = finish.prompt
        choices = finish.choices(seed: 0)
        answer = finish.answer
        ref = finish.ref
        explain = finish.text
    }
}

/// The Daily 5: five questions a day, the same for everyone that day (picked from the date alone), then a
/// spoiler-free grid to share, Wordle-style. #1 is 2026-11-20.
enum Daily5 {
    static let epoch = DayKey(year: 2026, month: 11, day: 20)
    static let count = 5

    /// "#12": days since the first Daily 5, counting from 1.
    static func number(for day: DayKey, calendar: Calendar = .current) -> Int {
        max(1, epoch.days(until: day, calendar: calendar) + 1)
    }

    /// The question pools, each in a fixed order (sorted by id), so every iPhone draws the same ones.
    struct Pools: Sendable {
        var general: [Daily5Question]
        var whoSaid: [Daily5Question]
        var finish: [Daily5Question]

        init(library: LearnLibrary, scroll: ScrollContent) {
            let quizzes = library.daily + library.lessonQuizzes
            general = Dictionary(quizzes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                .values.sorted { $0.id < $1.id }.map(Daily5Question.init)
            whoSaid = scroll.whoSaid.sorted { $0.id < $1.id }.map(Daily5Question.init)
            finish = scroll.finish.sorted { $0.id < $1.id }.map(Daily5Question.init)
        }

        var all: [Daily5Question] { general + whoSaid + finish }
    }

    /// Day N's five: three questions, one "Who said it?" and one "Finish the verse", in the order
    /// question, who, question, finish, question. Nothing repeats until its pool has been used up.
    static func questions(number: Int, pools: Pools) -> [Daily5Question] {
        let n = max(1, number)
        var general = draw(pools.general, perDay: 3, number: n, salt: "general")
        let who = draw(pools.whoSaid, perDay: 1, number: n, salt: "who")
        let finish = draw(pools.finish, perDay: 1, number: n, salt: "finish")
        // A pool that's empty (or too small) is topped up from the questions.
        var extra = draw(pools.general, perDay: 5, number: n, salt: "extra").filter { q in !general.contains(q) }
        func fill(_ list: [Daily5Question]) -> Daily5Question? {
            if let first = list.first { return first }
            return extra.isEmpty ? nil : extra.removeFirst()
        }
        var day: [Daily5Question] = []
        if !general.isEmpty { day.append(general.removeFirst()) }
        if let w = fill(who) { day.append(w) }
        if !general.isEmpty { day.append(general.removeFirst()) }
        if let f = fill(finish) { day.append(f) }
        if !general.isEmpty { day.append(general.removeFirst()) }
        var seen = Set<String>()
        return day.filter { seen.insert($0.id).inserted }
    }

    static func questions(for day: DayKey, pools: Pools, calendar: Calendar = .current) -> [Daily5Question] {
        questions(number: number(for: day, calendar: calendar), pools: pools)
    }

    /// `perDay` items for day `number`: walks a fixed shuffle of the pool, a new shuffle each time round.
    static func draw(_ pool: [Daily5Question], perDay: Int, number: Int, salt: String) -> [Daily5Question] {
        guard !pool.isEmpty else { return [] }
        var picked: [Daily5Question] = []
        var slot = (number - 1) * perDay
        var tries = 0
        while picked.count < min(perDay, pool.count), tries < perDay + pool.count {
            let round = slot / pool.count
            let order = shuffle(pool.count, salt: salt, round: round)
            let item = pool[order[slot % pool.count]]
            if !picked.contains(item) { picked.append(item) }
            slot += 1
            tries += 1
        }
        return picked
    }

    private static func shuffle(_ count: Int, salt: String, round: Int) -> [Int] {
        var rng = SplitMix(seed: FeedHash.stable("daily5-\(salt)-\(round)"))
        return LearnShuffle.shuffled(Array(0..<count), using: &rng)
    }

    /// A practice round (after the Daily 5, as many as you like): missed questions first, then fresh ones.
    static func practice(pools: Pools, missed: [String], avoiding: Set<String>, seed: UInt64, count: Int = 5) -> [Daily5Question] {
        let all = pools.all
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var round = missed.reversed().compactMap { byID[$0] }.filter { !avoiding.contains($0.id) }
        round = Array(round.prefix(2))
        var rng = SplitMix(seed: seed)
        for question in LearnShuffle.shuffled(all, using: &rng) where round.count < count {
            if !avoiding.contains(question.id), !round.contains(question) { round.append(question) }
        }
        return round
    }

    // MARK: Share

    /// 🟩 right, ⬜ not this time (never red: it's a gift, not a test).
    static func grid(_ marks: [Bool]) -> String {
        marks.map { $0 ? "🟩" : "⬜" }.joined()
    }

    /// "Pray to Scroll Daily 5 #12", the grid and score, the run, and the link. No answers in it.
    static func shareText(number: Int, marks: [Bool], streak: Int, appName: String = AppConstants.appName,
                          link: String? = nil) -> String {
        var lines = ["\(appName) Daily 5 #\(number)", "\(grid(marks)) \(marks.filter { $0 }.count)/\(marks.count)"]
        if streak >= 2 { lines.append("🔥 \(streak) days in a row") }
        if let link, !link.isEmpty { lines.append(link) }
        return lines.joined(separator: "\n")
    }
}

/// Words for the Daily 5 and lessons. Encouraging, never shaming (unit-tested).
enum LearnCopy {
    static func dailyScoreLine(right: Int, of total: Int) -> String {
        switch right {
        case total: return "All \(total). You know your Bible."
        case total - 1: return "\(right) of \(total). So close to perfect."
        case 0: return "A fresh start. Every answer is now one you know."
        default: return "\(right) of \(total). Every miss is a verse you know now."
        }
    }

    static func dailyStreakLine(_ streak: Int, graced: Bool) -> String {
        if streak <= 1 { return "Day 1 of a new run. A new Daily 5 is here tomorrow." }
        return graced ? "\(streak) days in a row. You were away one day: grace covered it." : "\(streak) days in a row."
    }

    static func lessonDoneLine(firstTime: Bool, right: Int, quizzes: Int) -> String {
        if !firstTime { return "Good to go over it again. It sinks in deeper every time." }
        if quizzes == 0 || right == quizzes { return "Every answer right. Well learned." }
        return "Lesson learned. The answers you missed will come back in practice."
    }

    static func rightLine(_ index: Int) -> String {
        ["Right!", "Yes! That’s it.", "Exactly right.", "You know this one."][index % 4]
    }

    static func notQuiteLine(_ index: Int) -> String {
        ["Not quite. Now you know.", "Close. Here’s what it says.", "Not this time. Now it’s yours."][index % 3]
    }
}
