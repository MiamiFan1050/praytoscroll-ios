import Foundation

/// One day of the Advent journey (advent.json: WEB + KJV text filled by tools/bible_text.py).
struct AdventDay: Codable, Hashable, Sendable {
    /// "MM-DD".
    var date: String
    var week: String
    var title: String
    var ref: String
    var prompt: String
    var text: String
    var kjv: String?
}

/// Advent runs on the real calendar only: November 29 to December 24, by the device's date. There is no server
/// switch and no setting that turns it on outside those dates (guideline 2.5.19).
enum AdventPlan {
    static let firstDate = (month: 11, day: 29)
    static let lastDate = (month: 12, day: 24)

    /// Today's place in the plan, or nil outside Advent.
    static func today(_ date: Date, calendar: Calendar, days: [AdventDay]) -> (index: Int, day: AdventDay)? {
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let dayOfMonth = parts.day, isInSeason(month: month, day: dayOfMonth) else { return nil }
        let key = String(format: "%02d-%02d", month, dayOfMonth)
        guard let index = days.firstIndex(where: { $0.date == key }) else { return nil }
        return (index, days[index])
    }

    static func isInSeason(month: Int, day: Int) -> Bool {
        (month == firstDate.month && day >= firstDate.day) || (month == lastDate.month && day <= lastDate.day)
    }

    /// Advent days so far this season (up to and including today) on which you prayed.
    static func daysPrayed(_ prayed: Set<DayKey>, through date: Date, calendar: Calendar) -> Int {
        let year = calendar.component(.year, from: date)
        let today = DayKey(date, calendar: calendar)
        return prayed.filter { key in
            key.year == year && key <= today && isInSeason(month: key.month, day: key.day)
        }.count
    }

    /// The day's reading as a verse for "Pray this verse" (in the reader's translation).
    static func verse(for day: AdventDay, index: Int, translation: BibleTranslation) -> Verse {
        Verse(day: 2000 + index, ref: day.ref, text: day.text, theme: "advent", kjv: day.kjv, meaning: nil)
            .rendered(in: translation)
    }
}
