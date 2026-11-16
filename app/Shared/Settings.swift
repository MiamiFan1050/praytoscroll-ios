import Foundation

enum UnlockStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case quick
    case guided
    case verse
    case forSomeone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Quick prayer"
        case .guided: return "Guided prayer"
        case .verse: return "Verse + prayer"
        case .forSomeone: return "Pray for someone"
        }
    }

    var shortTitle: String {
        switch self {
        case .quick: return "Quick"
        case .guided: return "Guided"
        case .verse: return "Verse"
        case .forSomeone: return "For someone"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "30 seconds. One prompt, then Amen."
        case .guided: return "Adoration, Confession, Thanksgiving, Supplication. You choose the length."
        case .verse: return "Read today's verse line by line, then pray it."
        case .forSomeone: return "Lift up a friend, then let them know you prayed."
        }
    }

    var symbol: String {
        switch self {
        case .quick: return "bolt.heart.fill"
        case .guided: return "list.bullet.indent"
        case .verse: return "book.pages.fill"
        case .forSomeone: return "person.2.fill"
        }
    }
}

enum AppearancePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case dark, light, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dark: return "Night"
        case .light: return "Day"
        case .system: return "Match iPhone"
        }
    }
}

/// How a prayer unlocks the gated apps.
enum UnlockMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Every prayer opens your apps for a window (5/15/30/60 min).
    case window
    /// "Daily key": your first prayer opens your apps until the reset time (default 4 AM).
    case dailyKey

    var id: String { rawValue }
    var title: String {
        switch self {
        case .window: return "Every time"
        case .dailyKey: return "Daily key"
        }
    }
}

/// Optional "How are you feeling?" chips at the start of a prayer. They pick the prompt pool.
enum PrayerMood: String, Codable, CaseIterable, Identifiable, Sendable {
    case anxious, grateful, tempted, tired, lonely, joyful
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .anxious: return "wind"
        case .grateful: return "gift.fill"
        case .tempted: return "shield.lefthalf.filled"
        case .tired: return "moon.zzz.fill"
        case .lonely: return "person.fill"
        case .joyful: return "sun.max.fill"
        }
    }
}

struct ReminderSettings: Codable, Equatable, Sendable {
    var dailyEnabled: Bool = true
    var dailyHour: Int = 8
    var dailyMinute: Int = 0
    var streakAtRiskEnabled: Bool = true
    var morningVerseEnabled: Bool = false
    var morningHour: Int = 7
    var morningMinute: Int = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ReminderSettings.defaultValue
        dailyEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailyEnabled) ?? d.dailyEnabled
        dailyHour = try c.decodeIfPresent(Int.self, forKey: .dailyHour) ?? d.dailyHour
        dailyMinute = try c.decodeIfPresent(Int.self, forKey: .dailyMinute) ?? d.dailyMinute
        streakAtRiskEnabled = try c.decodeIfPresent(Bool.self, forKey: .streakAtRiskEnabled) ?? d.streakAtRiskEnabled
        morningVerseEnabled = try c.decodeIfPresent(Bool.self, forKey: .morningVerseEnabled) ?? d.morningVerseEnabled
        morningHour = try c.decodeIfPresent(Int.self, forKey: .morningHour) ?? d.morningHour
        morningMinute = try c.decodeIfPresent(Int.self, forKey: .morningMinute) ?? d.morningMinute
    }

    private static let defaultValue = ReminderSettings()
}

struct ActiveChallenge: Codable, Equatable, Hashable, Sendable {
    var id: String
    var startedAt: Date
}

/// Everything the user configures. Stored as JSON in the app-group defaults so the intent and widget can read it.
struct AppSettings: Codable, Equatable, Sendable {
    var firstName: String = ""
    var unlockStyle: UnlockStyle = .guided
    var guidedSeconds: Int = 120
    var unlockMode: UnlockMode = .window
    var unlockWindowMinutes: Int = GateEngine.defaultWindowMinutes
    var dailyKeyResetHour: Int = GateEngine.defaultDailyResetHour
    var lastMood: PrayerMood?
    var sessionTextScale: Double = 1
    var windowEndNudge: Bool = true
    var gatedAppIDs: [String] = []
    var customApps: [GatedApp] = []
    var gateEnabled: Bool = true
    var reminders: ReminderSettings = ReminderSettings()
    var appearance: AppearancePreference = .dark
    var scrollHoursPerDay: Double = 3
    var hasOnboarded: Bool = false
    var hapticsEnabled: Bool = true
    var activeChallenges: [ActiveChallenge] = []
    var completedChallengeIDs: [String] = []
    var awardedMilestones: [Int] = []
    var circleDisplayEmoji: String = "🕊️"

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.defaultValue
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName) ?? d.firstName
        unlockStyle = (try? c.decodeIfPresent(UnlockStyle.self, forKey: .unlockStyle)) ?? d.unlockStyle
        guidedSeconds = try c.decodeIfPresent(Int.self, forKey: .guidedSeconds) ?? d.guidedSeconds
        unlockMode = (try? c.decodeIfPresent(UnlockMode.self, forKey: .unlockMode)) ?? d.unlockMode
        unlockWindowMinutes = try c.decodeIfPresent(Int.self, forKey: .unlockWindowMinutes) ?? d.unlockWindowMinutes
        dailyKeyResetHour = try c.decodeIfPresent(Int.self, forKey: .dailyKeyResetHour) ?? d.dailyKeyResetHour
        lastMood = try? c.decodeIfPresent(PrayerMood.self, forKey: .lastMood)
        sessionTextScale = try c.decodeIfPresent(Double.self, forKey: .sessionTextScale) ?? d.sessionTextScale
        windowEndNudge = try c.decodeIfPresent(Bool.self, forKey: .windowEndNudge) ?? d.windowEndNudge
        gatedAppIDs = try c.decodeIfPresent([String].self, forKey: .gatedAppIDs) ?? d.gatedAppIDs
        customApps = (try? c.decodeIfPresent([GatedApp].self, forKey: .customApps)) ?? d.customApps
        gateEnabled = try c.decodeIfPresent(Bool.self, forKey: .gateEnabled) ?? d.gateEnabled
        reminders = (try? c.decodeIfPresent(ReminderSettings.self, forKey: .reminders)) ?? d.reminders
        appearance = (try? c.decodeIfPresent(AppearancePreference.self, forKey: .appearance)) ?? d.appearance
        scrollHoursPerDay = try c.decodeIfPresent(Double.self, forKey: .scrollHoursPerDay) ?? d.scrollHoursPerDay
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? d.hasOnboarded
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? d.hapticsEnabled
        activeChallenges = (try? c.decodeIfPresent([ActiveChallenge].self, forKey: .activeChallenges)) ?? d.activeChallenges
        completedChallengeIDs = try c.decodeIfPresent([String].self, forKey: .completedChallengeIDs) ?? d.completedChallengeIDs
        awardedMilestones = try c.decodeIfPresent([Int].self, forKey: .awardedMilestones) ?? d.awardedMilestones
        circleDisplayEmoji = try c.decodeIfPresent(String.self, forKey: .circleDisplayEmoji) ?? d.circleDisplayEmoji
    }

    private static let defaultValue = AppSettings()

    static let guidedLengthOptions = [30, 60, 120, 180, 300]

    var gatedApps: [GatedApp] {
        gatedAppIDs.compactMap { AppCatalog.app(id: $0, customApps: customApps) }
    }

    var displayName: String {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "friend" : trimmed
    }
}
