import Foundation

/// The kinds of card in Scroll the Word.
enum FeedCardKind: String, CaseIterable, Hashable, Sendable {
    /// A verse, its meaning line underneath.
    case verse
    /// "What this means": the meaning big, the verse under it.
    case meaning
    /// A question to sit with.
    case reflect
    /// "Finish the verse": three endings, one true.
    case finish
    /// "Who said it?": three names, one true.
    case whoSaid
    /// "Bible fact".
    case fact
    /// "Pause & pray": a prayer prompt.
    case pray
    /// "Who needs this today?": a verse to text to someone.
    case send
    /// Goal met, a new level or a badge (added as it happens, never planned).
    case milestone
    /// "Jesus said": his own words, red letter, and who he said them to.
    case jesusSaid
    /// "Where and when": a key moment's place and era.
    case place
    /// One part of a short series ("The life of Peter, 2 of 5"); the next part comes later in the feed.
    case series
    /// Into Learn: today's Daily 5, or "Continue your lesson".
    case lesson

    /// Cards built around a verse (they count as read, and can be saved, shared and prayed).
    var carriesVerse: Bool { self == .verse || self == .meaning || self == .send }
}

/// A celebration card.
enum FeedMilestone: Hashable, Sendable {
    case goalDone(goal: Int, streak: Int)
    case levelUp(number: Int, name: String)
    case badge(WordBadge)
}

/// One card in the feed.
struct FeedItem: Identifiable, Hashable {
    let id: String
    var kind: FeedCardKind
    var verse: Verse?
    var prompt: String?
    var fact: BibleFact?
    var who: WhoSaidQuiz?
    var finish: FinishVerse?
    var reflection: Reflection?
    var milestone: FeedMilestone?
    var saying: JesusSaying?
    var place: PlaceCard?
    var seriesPart: FeedSeriesPart?
    var nudge: LearnNudge?
    /// The sky the card falls back to (and the share card uses).
    var scene: FeedScene
    /// Which photo backdrop (an index into FeedBackgrounds).
    var background: Int = 0

    init(id: String, kind: FeedCardKind, verse: Verse? = nil, prompt: String? = nil, fact: BibleFact? = nil,
         who: WhoSaidQuiz? = nil, finish: FinishVerse? = nil, reflection: Reflection? = nil,
         milestone: FeedMilestone? = nil, saying: JesusSaying? = nil, place: PlaceCard? = nil,
         seriesPart: FeedSeriesPart? = nil, nudge: LearnNudge? = nil, scene: FeedScene = .candle) {
        self.id = id
        self.kind = kind
        self.verse = verse
        self.prompt = prompt
        self.fact = fact
        self.who = who
        self.finish = finish
        self.reflection = reflection
        self.milestone = milestone
        self.saying = saying
        self.place = place
        self.seriesPart = seriesPart
        self.nudge = nudge
        self.scene = verse.map(FeedScene.for) ?? scene
    }

    /// A verse card's verse; nil for every other kind (so save/listen only show on verse cards).
    var readableVerse: Verse? { kind.carriesVerse ? verse : nil }
}

/// Builds the feed: verses in "For you" (or topic) order, with a different kind of card every two or three verses,
/// so it never feels like the same thing twice. The first card is always a verse; two non-verse cards are never
/// side by side; at least 60% of cards are verses.
enum FeedMixer {
    /// Verses between special cards, repeating.
    static let gaps = [2, 2, 3]
    /// One round of special cards, reshuffled every round (never the same kind twice in a row).
    static let specials: [FeedCardKind] = [.meaning, .finish, .reflect, .whoSaid, .fact, .pray, .send]
    /// Learn's cards join the round when there's something to show ("For you" only).
    static let learning: [FeedCardKind] = [.jesusSaid, .place, .series, .lesson]

    struct Input {
        var verses: [Verse]
        var content: ScrollContent
        var prompts: [String]
        var topic: String?
        var seed: UInt64
        /// Facts and quizzes already shown, oldest first (they go to the back).
        var seenExtras: [String] = []
        /// Jesus said, Where and when, series parts and the Learn cards.
        var learn: FeedLearn = .empty
    }

    static func build(_ input: Input) -> [FeedItem] {
        let verses = input.verses.isEmpty ? [Verse.fallback] : input.verses
        var rng = SplitMix(seed: input.seed ^ FeedHash.stable("mix-\(input.topic ?? "all")"))

        let facts = rotate(input.content.facts, id: \.id, seen: input.seenExtras, seed: input.seed)
        let quizzes = rotate(input.content.whoSaid, id: \.id, seen: input.seenExtras, seed: input.seed)
        let finishes = rotate(input.content.finish, id: \.id, seen: input.seenExtras, seed: input.seed)
        let reflections = rotate(input.content.reflect.filter { input.topic == nil || $0.theme == input.topic },
                                 id: \.id, seen: input.seenExtras, seed: input.seed)
        let prompts = input.prompts.filter { !$0.contains("{name}") }
        let sayings = rotate(input.learn.sayings, id: \.id, seen: input.seenExtras, seed: input.seed)
        let places = rotate(input.learn.places, id: \.id, seen: input.seenExtras, seed: input.seed)
        var seriesQueue = input.learn.series
        let kinds = specials + learning.filter { input.learn.has($0) }
        var used: [FeedCardKind: Int] = [:]
        func next<T>(_ list: [T], _ kind: FeedCardKind) -> (T, Int)? {
            guard !list.isEmpty else { return nil }
            let n = used[kind, default: 0]
            used[kind] = n + 1
            return (list[n % list.count], n)
        }

        var items: [FeedItem] = []
        var verseIndex = 0
        func makeSpecial(_ kind: FeedCardKind) -> FeedItem? {
            switch kind {
            case .meaning, .send:
                guard verseIndex < verses.count else { return nil }
                let carried = verses[verseIndex]
                if kind == .meaning, carried.meaning == nil { return nil }
                verseIndex += 1
                return FeedItem(id: (kind == .meaning ? "m" : "s") + "\(carried.day)", kind: kind, verse: carried)
            case .finish:
                return next(finishes, .finish).map { FeedItem(id: "x\($0.0.id)-\($0.1)", kind: .finish, finish: $0.0) }
            case .whoSaid:
                return next(quizzes, .whoSaid).map { FeedItem(id: "w\($0.0.id)-\($0.1)", kind: .whoSaid, who: $0.0) }
            case .fact:
                return next(facts, .fact).map { FeedItem(id: "f\($0.0.id)-\($0.1)", kind: .fact, fact: $0.0) }
            case .reflect:
                return next(reflections, .reflect).map { FeedItem(id: "r\($0.0.id)-\($0.1)", kind: .reflect, reflection: $0.0) }
            case .pray:
                return next(prompts, .pray).map { FeedItem(id: "p\($0.1)", kind: .pray, prompt: $0.0) }
            case .jesusSaid:
                return next(sayings, .jesusSaid).map { FeedItem(id: "wj\($0.0.id)-\($0.1)", kind: .jesusSaid, saying: $0.0) }
            case .place:
                return next(places, .place).map { FeedItem(id: "wp\($0.0.id)-\($0.1)", kind: .place, place: $0.0) }
            case .series:
                // Each part once, in order: a series is read through before anything repeats.
                guard !seriesQueue.isEmpty else { return nil }
                let part = seriesQueue.removeFirst()
                return FeedItem(id: "ws-\(part.seriesID)-\(part.index)", kind: .series, seriesPart: part)
            case .lesson:
                return next(input.learn.nudges, .lesson).map { FeedItem(id: "wn\($0.1)", kind: .lesson, nudge: $0.0) }
            case .verse, .milestone:
                return nil
            }
        }
        var round: [FeedCardKind] = []
        var lastSpecial: FeedCardKind?
        var gapIndex = 0
        var sinceSpecial = 0

        while verseIndex < verses.count {
            let verse = verses[verseIndex]
            verseIndex += 1
            items.append(FeedItem(id: "v\(verse.day)", kind: .verse, verse: verse))
            sinceSpecial += 1
            guard items.count > 1, sinceSpecial >= gaps[gapIndex % gaps.count] else { continue }
            // Time for a special card: the next kind in this round that has something to show.
            var special: FeedItem?
            var kind = FeedCardKind.verse
            // The first special card leads into Learn (today's Daily 5, or your next lesson) when there is one.
            if lastSpecial == nil, input.learn.has(.lesson) {
                kind = .lesson
                special = makeSpecial(.lesson)
            }
            for _ in 0..<(2 * kinds.count) where special == nil {
                if round.isEmpty {
                    round = kinds.shuffled(using: &rng)
                    if round.first == lastSpecial { round.append(round.removeFirst()) }
                }
                kind = round.removeFirst()
                special = makeSpecial(kind)
            }
            if let special {
                items.append(special)
                lastSpecial = kind
            }
            sinceSpecial = 0
            gapIndex += 1
        }
        return assignBackgrounds(items, seed: input.seed)
    }

    /// Unseen first (shuffled for this install), then seen ones oldest first.
    static func rotate<T>(_ list: [T], id: KeyPath<T, String>, seen: [String], seed: UInt64) -> [T] {
        let rank = Dictionary(seen.enumerated().map { ($1, $0) }, uniquingKeysWith: { _, last in last })
        var rng = SplitMix(seed: seed ^ 0x5EED)
        let unseen = list.filter { rank[$0[keyPath: id]] == nil }.shuffled(using: &rng)
        let already = list.filter { rank[$0[keyPath: id]] != nil }.sorted { rank[$0[keyPath: id]]! < rank[$1[keyPath: id]]! }
        return unseen + already
    }

    /// Neighbouring cards never share a backdrop: a stride through the set that's coprime with its size.
    static func assignBackgrounds(_ items: [FeedItem], seed: UInt64, count: Int = FeedBackgrounds.count) -> [FeedItem] {
        guard count > 1 else { return items }
        let stride = [7, 11, 13, 17, 19, 23].first { gcd($0, count) == 1 } ?? 1
        let start = Int(seed % UInt64(count))
        return items.enumerated().map { index, item in
            var copy = item
            copy.background = (start + index * stride) % count
            return copy
        }
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }

    /// A celebration card to slot in after the current one.
    static func milestone(for event: WordEvent, streak: Int, index: Int) -> FeedItem {
        let milestone: FeedMilestone
        switch event {
        case .goalReached(let goal): milestone = .goalDone(goal: goal, streak: streak)
        case .levelUp(let level): milestone = .levelUp(number: level.number, name: level.name)
        case .badge(let badge): milestone = .badge(badge)
        }
        return FeedItem(id: "ms\(index)-\(milestone.idPart)", kind: .milestone, milestone: milestone, scene: .candle)
    }
}

extension FeedMilestone {
    var idPart: String {
        switch self {
        case .goalDone(let goal, _): return "goal\(goal)"
        case .levelUp(let number, _): return "level\(number)"
        case .badge(let badge): return "badge-\(badge.rawValue)"
        }
    }
}

/// "For you": the next verses lean toward the themes you heart, save, share and linger on, and away from ones you
/// flick past, while one in four is picked at random so the feed never narrows to a single theme. On this iPhone only.
enum ForYouRanker {
    static let explore = 0.25

    /// - Parameters:
    ///   - verses: the planner's order (unseen first, then seen). Only the unseen part is re-ranked, so nothing
    ///     repeats before the feed has been read through.
    ///   - pinFirst: keep the first verse first (today's verse).
    static func order(_ verses: [Verse], affinity: [String: Double], seed: UInt64, seen: Set<Int> = [],
                      pinFirst: Bool = false) -> [Verse] {
        let head = pinFirst ? Array(verses.prefix(1)) : []
        let rest = Array(verses.dropFirst(head.count))
        let unseen = rest.filter { !seen.contains($0.day) }
        let already = rest.filter { seen.contains($0.day) }
        return head + rank(unseen, affinity: affinity, seed: seed) + already
    }

    static func rank(_ verses: [Verse], affinity: [String: Double], seed: UInt64) -> [Verse] {
        guard affinity.values.contains(where: { $0 != 0 }), verses.count > 2 else { return verses }
        var rng = SplitMix(seed: seed ^ 0xF0F0)
        // Keep each theme's own order (already "unseen first, shuffled"), and pick which theme comes next.
        var queues: [String: [Verse]] = [:]
        var order: [String] = []
        for verse in verses {
            let theme = verse.theme ?? ""
            if queues[theme] == nil { order.append(theme) }
            queues[theme, default: []].append(verse)
        }
        var result: [Verse] = []
        result.reserveCapacity(verses.count)
        while result.count < verses.count {
            let open = order.filter { !(queues[$0]?.isEmpty ?? true) }
            guard !open.isEmpty else { break }
            let roll = Double(rng.next() % 10_000) / 10_000
            let theme: String
            if roll < explore {
                theme = open[Int(rng.next() % UInt64(open.count))]
            } else {
                let weights = open.map { exp(0.45 * min(6, max(-4, affinity[$0] ?? 0))) }
                var pick = Double(rng.next() % 1_000_000) / 1_000_000 * weights.reduce(0, +)
                var chosen = open.last!
                for (candidate, weight) in zip(open, weights) {
                    pick -= weight
                    if pick <= 0 { chosen = candidate; break }
                }
                theme = chosen
            }
            result.append(queues[theme]!.removeFirst())
        }
        return result
    }
}
