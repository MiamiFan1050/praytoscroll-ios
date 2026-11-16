import Foundation

/// The order of Scroll the Word: verses you haven't seen yet first (today's verse leads the "For you" feed the first
/// time), in a shuffle that's stable for this install, then the ones you've seen, longest-ago first. So a new session
/// never opens on verses you just read, and nothing repeats until a feed has been read through.
enum WordFeedPlanner {
    /// The topic chips, most-wanted first (all 14 themes tagged in verses.json).
    static let topics = ["anxiety", "peace", "strength", "hope", "love", "gratitude", "rest", "courage",
                         "identity", "purpose", "focus", "forgiveness", "provision", "community"]

    static func title(for topic: String) -> String {
        topic.prefix(1).uppercased() + topic.dropFirst()
    }

    /// - Parameters:
    ///   - topic: nil = "For you" (every verse); else one theme.
    ///   - seen: verse days in the order they were seen (oldest first).
    ///   - today: today's verse day (leads "For you" until it's been seen).
    ///   - seed: per-install shuffle seed.
    static func order(verses: [Verse], topic: String?, seen: [Int], today: Int?, seed: UInt64) -> [Verse] {
        let pool = topic.map { t in verses.filter { $0.theme == t } } ?? verses
        let seenRank = Dictionary(seen.enumerated().map { ($1, $0) }, uniquingKeysWith: { _, last in last })
        var unseen = pool.filter { seenRank[$0.day] == nil }
        var rng = SplitMix(seed: seed ^ UInt64(truncatingIfNeeded: (topic ?? "all").hashValueStable))
        unseen.shuffle(using: &rng)
        if topic == nil, let today, let index = unseen.firstIndex(where: { $0.day == today }) {
            unseen.insert(unseen.remove(at: index), at: 0)
        }
        let already = pool.filter { seenRank[$0.day] != nil }.sorted { seenRank[$0.day]! < seenRank[$1.day]! }
        return unseen + already
    }

    /// Appends a seen verse (moving it to the end if it was seen before), keeping at most `limit` entries.
    static func markSeen(_ day: Int, in seen: [Int], limit: Int = 400) -> [Int] {
        var list = seen.filter { $0 != day }
        list.append(day)
        if list.count > limit { list.removeFirst(list.count - limit) }
        return list
    }
}

/// Deterministic RNG for the per-install shuffle.
struct SplitMix: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private extension String {
    /// FNV-1a: a hash that's the same on every launch (Swift's hashValue isn't).
    var hashValueStable: UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        return hash
    }
}
