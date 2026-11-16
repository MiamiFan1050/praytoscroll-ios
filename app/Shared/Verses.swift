import Foundation

/// The two public-domain translations the app ships (nothing licensed).
enum BibleTranslation: String, Codable, CaseIterable, Identifiable, Sendable {
    case web, kjv
    var id: String { rawValue }
    var name: String { self == .kjv ? "King James Version" : "World English Bible" }
    var short: String { self == .kjv ? "KJV" : "WEB" }
}

/// One verse of the day: World English Bible text, the King James text, and our one-line "what this means".
struct Verse: Codable, Hashable, Identifiable, Sendable {
    var day: Int
    var ref: String
    /// World English Bible.
    var text: String
    var theme: String?
    /// King James Version (public domain; filled by tools/bible_text.py).
    var kjv: String?
    /// One line in our own words, shown under the verse in Scroll the Word.
    var meaning: String?
    /// Which translation `displayText` shows (not stored in verses.json; nil = WEB).
    var translation: BibleTranslation?

    var id: Int { day }

    /// The verse in the reader's translation.
    var displayText: String {
        translation == .kjv ? (kjv ?? text) : text
    }

    var translationName: String { (kjv != nil && translation == .kjv ? BibleTranslation.kjv : .web).name }

    func rendered(in translation: BibleTranslation) -> Verse {
        var copy = self
        copy.translation = translation
        return copy
    }

    /// Splits the verse into short lines for the tap-to-reveal reading.
    var revealLines: [String] {
        let cleaned = displayText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = []
        var current = ""
        for word in cleaned.split(separator: " ") {
            current += (current.isEmpty ? "" : " ") + word
            let wordCount = current.split(separator: " ").count
            let endsClause = word.last.map { ",;:.!?".contains($0) } ?? false
            if (endsClause && wordCount >= 3) || wordCount >= 9 {
                lines.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            if current.split(separator: " ").count <= 2, let last = lines.popLast() {
                lines.append(last + " " + current)
            } else {
                lines.append(current)
            }
        }
        return lines.isEmpty ? [cleaned] : lines
    }

    var themeTitle: String {
        guard let theme, !theme.isEmpty else { return "Today" }
        return theme.prefix(1).uppercased() + theme.dropFirst()
    }

    static let fallback = Verse(day: 0, ref: "Psalm 46:10",
                                text: "Be still, and know that I am God. I will be exalted among the nations. I will be exalted in the earth.",
                                theme: "peace")
}

/// Loads verses.json from the bundle (app and widget both bundle it), in the reader's translation.
final class VerseProvider: @unchecked Sendable {
    static let shared = VerseProvider()

    private lazy var all: [Verse] = load()
    /// Set by AppModel from Settings; the widget reads it from the app group.
    var translation: BibleTranslation = SharedStore.shared.settings.translation

    var verses: [Verse] {
        let t = translation
        return all.map { $0.rendered(in: t) }
    }

    private func load() -> [Verse] {
        guard let url = Bundle.main.url(forResource: "verses", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return VerseProvider.decode(data)
    }

    static func decode(_ data: Data) -> [Verse] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([Verse].self, from: data) { return list.sorted { $0.day < $1.day } }
        struct Wrapped: Decodable { let verses: [Verse] }
        if let wrapped = try? decoder.decode(Wrapped.self, from: data) { return wrapped.verses.sorted { $0.day < $1.day } }
        return []
    }

    func verse(for date: Date = Date(), calendar: Calendar = .current) -> Verse {
        verse(forDayOfYear: DayKey(date, calendar: calendar).dayOfYear(calendar: calendar))
    }

    func verse(forDayOfYear day: Int) -> Verse {
        let list = all
        guard !list.isEmpty else { return Verse.fallback.rendered(in: translation) }
        if let exact = list.first(where: { $0.day == day }) { return exact.rendered(in: translation) }
        return list[(max(day, 1) - 1) % list.count].rendered(in: translation)
    }
}
