import Foundation

enum PeopleRanking {
    /// The person to pray for next: never prayed for first, then the longest ago.
    static func next(in people: [Person]) -> Person? {
        sorted(people).first
    }

    static func sorted(_ people: [Person]) -> [Person] {
        people.sorted { a, b in
            switch (a.lastPrayedAt, b.lastPrayedAt) {
            case (nil, nil): return a.createdAt < b.createdAt
            case (nil, _): return true
            case (_, nil): return false
            case let (x?, y?): return x < y
            }
        }
    }

    /// "Today", "Yesterday", "3 days ago", "Never".
    static func lastPrayedText(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "Not prayed for yet" }
        let days = DayKey(date, calendar: calendar).days(until: DayKey(now, calendar: calendar), calendar: calendar)
        switch days {
        case ..<1: return "Prayed today"
        case 1: return "Prayed yesterday"
        default: return "Last prayed \(days) days ago"
        }
    }
}
