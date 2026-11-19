import Foundation

/// One part of a feed series ("The life of Peter, 2 of 5").
struct FeedSeriesPart: Hashable, Sendable {
    var seriesID: String
    var title: String
    var index: Int
    var count: Int
    var part: LearnSeries.Part

    var isLast: Bool { index + 1 >= count }
}

/// A card in the feed that leads into Learn: today's Daily 5, or the next lesson.
enum LearnNudge: Hashable, Sendable {
    case daily5(number: Int)
    case lesson(id: String, title: String, pathTitle: String, number: Int, count: Int, verseRef: String?, started: Bool)
}

/// What Learn adds to Scroll the Word ("For you" only; topic feeds stay on their topic).
struct FeedLearn: Sendable {
    var sayings: [JesusSaying] = []
    var places: [PlaceCard] = []
    /// The next series parts, in order: unfinished series first, so the story you started carries on.
    var series: [FeedSeriesPart] = []
    var nudges: [LearnNudge] = []

    static let empty = FeedLearn()

    func has(_ kind: FeedCardKind) -> Bool {
        switch kind {
        case .jesusSaid: return !sayings.isEmpty
        case .place: return !places.isEmpty
        case .series: return !series.isEmpty
        case .lesson: return !nudges.isEmpty
        default: return false
        }
    }

    static func make(library: LearnLibrary, progress: LearnProgress, today: DayKey, calendar: Calendar = .current) -> FeedLearn {
        var feed = FeedLearn(sayings: library.jesusSaid, places: library.places)
        // Series: started ones first (pick up where you left off), then new ones, then finished ones from the top.
        let started = library.series.filter { let seen = progress.seriesSeen[$0.id] ?? 0; return seen > 0 && seen < $0.parts.count }
        let fresh = library.series.filter { (progress.seriesSeen[$0.id] ?? 0) == 0 }
        let finished = library.series.filter { (progress.seriesSeen[$0.id] ?? 0) >= $0.parts.count }
        for series in started + fresh + finished {
            let seen = progress.seriesSeen[series.id] ?? 0
            let from = seen >= series.parts.count ? 0 : seen
            for index in from..<series.parts.count {
                feed.series.append(FeedSeriesPart(seriesID: series.id, title: series.title, index: index,
                                                  count: series.parts.count, part: series.parts[index]))
            }
        }
        // Nudges: today's Daily 5 until it's played, then the lesson you're on.
        if progress.dailyResult(on: today) == nil {
            feed.nudges.append(.daily5(number: Daily5.number(for: today, calendar: calendar)))
        }
        if let lesson = progress.continueLesson(in: library), let place = library.locate(lesson.id) {
            feed.nudges.append(.lesson(id: lesson.id, title: lesson.title, pathTitle: place.path.title, number: place.index + 1,
                                       count: place.path.lessons.count, verseRef: lesson.keyVerse?.ref,
                                       started: progress.doneCount(in: place.path) > 0))
        }
        return feed
    }
}
