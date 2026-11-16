import Foundation

/// What unlocks the gated apps: a prayer (the default), reading one verse, or a short devotional.
/// All three count toward the streak.
enum UnlockMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case prayer, verse, devotional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prayer: return "Prayer"
        case .verse: return "Read a verse"
        case .devotional: return "Devotional"
        }
    }

    var subtitle: String {
        switch self {
        case .prayer: return "Your prayer style, then Amen."
        case .verse: return "A verse and what it means. Amen once you’ve read it."
        case .devotional: return "60 to 90 seconds: a verse, a short reading and a one-line prayer."
        }
    }

    var symbol: String {
        switch self {
        case .prayer: return "hands.and.sparkles.fill"
        case .verse: return "book.closed.fill"
        case .devotional: return "text.book.closed.fill"
        }
    }

    /// The session style this method starts (Prayer uses the person's prayer style).
    func style(prayerStyle: UnlockStyle) -> UnlockStyle {
        switch self {
        case .prayer: return prayerStyle.isReading ? .guided : prayerStyle
        case .verse: return .readVerse
        case .devotional: return .devotional
        }
    }

    init(style: UnlockStyle) {
        switch style {
        case .readVerse: self = .verse
        case .devotional: self = .devotional
        default: self = .prayer
        }
    }
}

/// How long a reading has to stay on screen before Amen: scaled to its length, so nobody can tap straight through.
enum ReadingTime {
    static let verseRange = 8...40
    static let devotionalRange = 60...90

    static func wordCount(_ parts: [String]) -> Int {
        parts.reduce(0) { $0 + $1.split(whereSeparator: { $0 == " " || $0 == "\n" }).count }
    }

    /// A verse and its meaning: about 3 words a second plus a breath.
    static func verse(words: Int) -> Int {
        clamp(Int((Double(words) / 3).rounded(.up)) + 3, verseRange)
    }

    /// A devotional, read slowly (about 150 words a minute): 60 to 90 seconds.
    static func devotional(words: Int) -> Int {
        clamp(Int((Double(words) / 2.5).rounded()), devotionalRange)
    }

    private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
