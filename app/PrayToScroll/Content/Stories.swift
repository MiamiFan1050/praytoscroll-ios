import Foundation
import Observation
import SwiftData
import UserNotifications

// MARK: Bible Stories
//
// Short vertical Bible episodes (the studio's @bibleinblocks films) in series. DramaWave's three mechanics with prayer as
// the paywall: the first two episodes of a series are free; each later one opens with one short prayer and stays open.
// The catalog is a small JSON manifest (hosted, cached, with a bundled copy), so new episodes ship without an update.
// Videos stream from the media host; nothing about the viewer is sent anywhere.

struct StoryManifest: Codable, Equatable, Sendable {
    var version: Int
    var updated: String
    var base_url: String
    var notice: String
    var series: [StorySeries]

    var baseURL: URL? { URL(string: base_url) }
}

struct StorySeries: Codable, Equatable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var poster: String
    var episodes: [StoryEpisode]
}

struct StoryEpisode: Codable, Equatable, Identifiable, Hashable, Sendable {
    var id: String
    var number: Int
    var label: String
    var title: String
    var hook: String
    var scripture: String
    var question: String
    var prayer: String
    var duration: Double
    var video: String
    var poster: String
    var free: Bool
}

@MainActor
@Observable
final class StoryLibrary {
    static let shared = StoryLibrary()
    static let manifestURL = URL(string: "https://praytoscroll-media.vercel.app/stories.json")!

    private(set) var manifest: StoryManifest?
    private(set) var unlocked: Set<String>
    private(set) var watched: Set<String>
    private(set) var lastEpisodeID: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var lastFetch: Date?

    private enum Key {
        static let manifest = "ak.stories.manifest"
        static let unlocked = "ak.stories.unlocked"
        static let watched = "ak.stories.watched"
        static let last = "ak.stories.last"
    }
    static let cliffhangerID = "ak.story.cliffhanger"

    init(defaults: UserDefaults = SharedStore.shared.defaults, bundle: Bundle = .main) {
        self.defaults = defaults
        unlocked = Set(defaults.stringArray(forKey: Key.unlocked) ?? [])
        watched = Set(defaults.stringArray(forKey: Key.watched) ?? [])
        lastEpisodeID = defaults.string(forKey: Key.last)
        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: Key.manifest), let cached = try? decoder.decode(StoryManifest.self, from: data),
           !cached.series.isEmpty {
            manifest = cached
        } else if let url = bundle.url(forResource: "stories", withExtension: "json"),
                  let data = try? Data(contentsOf: url), let bundled = try? decoder.decode(StoryManifest.self, from: data) {
            manifest = bundled
        }
    }

    var series: [StorySeries] { manifest?.series ?? [] }
    var notice: String { manifest?.notice ?? "" }

    /// Fetches the catalog at most once an hour. A bad or empty answer keeps what we have.
    func refresh(force: Bool = false) async {
        if !force, let lastFetch, Date().timeIntervalSince(lastFetch) < 3600 { return }
        lastFetch = Date()
        var request = URLRequest(url: Self.manifestURL)
        request.cachePolicy = .reloadRevalidatingCacheData
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let fresh = try? JSONDecoder().decode(StoryManifest.self, from: data),
              !fresh.series.isEmpty, fresh.baseURL != nil else { return }
        if fresh != manifest {
            manifest = fresh
            defaults.set(data, forKey: Key.manifest)
        }
    }

    func url(_ path: String) -> URL? {
        guard let base = manifest?.baseURL else { return nil }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }

    func isUnlocked(_ episode: StoryEpisode) -> Bool { episode.free || unlocked.contains(episode.id) }

    func unlock(_ id: String) {
        guard !unlocked.contains(id) else { return }
        unlocked.insert(id)
        defaults.set(Array(unlocked).sorted(), forKey: Key.unlocked)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.cliffhangerID])
    }

    func markWatched(_ episode: StoryEpisode) {
        lastEpisodeID = episode.id
        defaults.set(episode.id, forKey: Key.last)
        guard !watched.contains(episode.id) else { return }
        watched.insert(episode.id)
        defaults.set(Array(watched).sorted(), forKey: Key.watched)
        ActivityLog(defaults: defaults).record(.story, detail: episode.id)   // "Your week"
    }

    func series(containing episodeID: String) -> StorySeries? {
        series.first { $0.episodes.contains { $0.id == episodeID } }
    }

    func previous(of episode: StoryEpisode, in series: StorySeries) -> StoryEpisode? {
        guard let index = series.episodes.firstIndex(of: episode), index > 0 else { return nil }
        return series.episodes[index - 1]
    }

    func next(after episode: StoryEpisode, in series: StorySeries) -> StoryEpisode? {
        guard let index = series.episodes.firstIndex(of: episode), index + 1 < series.episodes.count else { return nil }
        return series.episodes[index + 1]
    }

    /// Home's "Continue": the episode after the last one watched (in its series), else nil.
    var continueTarget: (series: StorySeries, episode: StoryEpisode)? {
        guard let lastEpisodeID, let series = series(containing: lastEpisodeID),
              let last = series.episodes.first(where: { $0.id == lastEpisodeID }),
              let next = next(after: last, in: series) else { return nil }
        return (series, next)
    }

    func watchedCount(in series: StorySeries) -> Int { series.episodes.filter { watched.contains($0.id) }.count }

    var hasFinishedASeries: Bool { series.contains { s in s.episodes.allSatisfy { watched.contains($0.id) } } }

    /// Stopped at a locked part: one gentle nudge tomorrow evening, only if reminders are already allowed.
    func scheduleCliffhanger(for episode: StoryEpisode, in series: StorySeries) {
        let center = UNUserNotificationCenter.current()
        let seriesTitle = series.title
        let label = episode.label
        let title = episode.title
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = "\(seriesTitle): \(label) is waiting"
            content.body = "“\(title)” opens with one short prayer."
            content.sound = .default
            var when = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86_400))
            when.hour = 19
            when.minute = 30
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            center.add(UNNotificationRequest(identifier: StoryLibrary.cliffhangerID, content: content, trigger: trigger)) { _ in }
        }
    }
}

extension AppModel {
    var stories: StoryLibrary { StoryLibrary.shared }

    /// "Pray to watch Part N": a short prayer seeded with the story just watched; the Amen opens the episode for good.
    func prayToWatch(_ episode: StoryEpisode, in series: StorySeries) {
        let previous = stories.previous(of: episode, in: series)
        let seed = (previous?.prayer).map { "\($0) Then keep talking to Him in your own words." }
        startPrayer(style: .quick, source: .story, seedPrompt: seed ?? "Thank God for His Word, and ask Him to speak to you through this story.",
                    storyEpisodeID: episode.id)
    }
}

// MARK: Rating prompt

/// When to show Apple's rating sheet: after a calm, happy moment, never on the way to another app.
@MainActor
enum ReviewPrompt {
    private static let askedVersionKey = "ak.review.askedVersion"

    static func shouldAsk(model: AppModel, source: SessionSource, isSample: Bool) -> Bool {
        // Gate and story unlocks are on their way somewhere; a finished series asks from the player instead.
        if isSample || source == .gate || source == .onboarding || source == .story { return false }
        if model.options.isUITest || model.options.isDemo { return false }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if model.store.defaults.string(forKey: askedVersionKey) == version { return false }
        // Not in the first day, and not before a few prayers.
        guard model.store.prayedDays.count >= 2 else { return false }
        let offline = SessionSource.offline.rawValue
        let prayers = (try? model.container.mainContext.fetchCount(FetchDescriptor<PrayerSession>(predicate: #Predicate { $0.sourceRaw != offline }))) ?? 0
        return prayers >= 3
    }

    static func markAsked(model: AppModel) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        model.store.defaults.set(version, forKey: askedVersionKey)
    }
}
