import Foundation

/// One verse of the day (World English Bible, public domain).
struct Verse: Codable, Hashable, Identifiable, Sendable {
    var day: Int
    var ref: String
    var text: String
    var theme: String?
    /// King James Version (public domain; filled by tools/bible_text.py).
    var kjv: String?
    /// One line in our own words, shown under the verse in Scroll the Word.
    var meaning: String?

    var id: Int { day }

    /// Splits the verse into short lines for the tap-to-reveal reading.
    var revealLines: [String] {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
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

/// Loads verses.json from the bundle (app and widget both bundle it).
final class VerseProvider: @unchecked Sendable {
    static let shared = VerseProvider()

    private(set) lazy var verses: [Verse] = load()

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
        let list = verses
        guard !list.isEmpty else { return .fallback }
        if let exact = list.first(where: { $0.day == day }) { return exact }
        return list[(max(day, 1) - 1) % list.count]
    }
}
