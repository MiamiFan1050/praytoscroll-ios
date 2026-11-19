import Foundation

enum UnlockStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case quick
    case guided
    case verse
    case forSomeone
    /// Unlock with: read a verse (Settings → Unlock with).
    case readVerse
    /// Unlock with: a 60–90 second devotional.
    case devotional

    var id: String { rawValue }

    /// The prayer styles (the reading ones are picked under Unlock with).
    static let prayerStyles: [UnlockStyle] = [.quick, .guided, .verse, .forSomeone]

    var isReading: Bool { self == .readVerse || self == .devotional }

    var title: String {
        switch self {
        case .quick: return "Quick prayer"
        case .guided: return "Guided prayer"
        case .verse: return "Verse + prayer"
        case .forSomeone: return "Pray for someone"
        case .readVerse: return "Read a verse"
        case .devotional: return "Devotional"
        }
    }

    var shortTitle: String {
        switch self {
        case .quick: return "Quick"
        case .guided: return "Guided"
        case .verse: return "Verse"
        case .forSomeone: return "For someone"
        case .readVerse: return "Verse"
        case .devotional: return "Devotional"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "30 seconds. One prompt, then Amen."
        case .guided: return "Adoration, Confession, Thanksgiving, Supplication. You choose the length."
        case .verse: return "Read today's verse line by line, then pray it."
        case .forSomeone: return "Lift up a friend, then let them know you prayed."
        case .readVerse: return UnlockMethod.verse.subtitle
        case .devotional: return UnlockMethod.devotional.subtitle
        }
    }

    var symbol: String {
        switch self {
        case .quick: return "bolt.heart.fill"
        case .guided: return "list.bullet.indent"
        case .verse: return "book.pages.fill"
        case .forSomeone: return "person.2.fill"
        case .readVerse: return UnlockMethod.verse.symbol
        case .devotional: return UnlockMethod.devotional.symbol
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

/// How the apps are kept closed until you pray.
enum LockMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    /// v1.0: a Shortcuts automation brings you here when you open a gated app (no Screen Time access needed).
    case shortcuts
    /// v1.1: Apple's Screen Time shields the apps you picked until you pray, and puts the shield back on time.
    case screenTime

    var id: String { rawValue }
}

/// How a prayer unlocks the gated apps.
enum UnlockMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Every prayer opens your apps for a window (a preset or Custom length: see UnlockChoice).
    case window
    /// "Rest of today" (formerly "Daily key"): a prayer opens your apps until the reset time (default 4 AM).
    case dailyKey

    var id: String { rawValue }
    var title: String {
        switch self {
        case .window: return "Every time"
        case .dailyKey: return "Rest of today"
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
    /// Sunday 7 PM: "Your week with God is ready" (opens Progress).
    var weeklyRecapEnabled: Bool = true
    /// "Before you scroll": a prayer reminder just before the hour you reach for your apps most (set from Your week).
    var nudgeEnabled: Bool = false
    var nudgeHour: Int = 21
    var nudgeMinute: Int = 45
    /// The app it's for, by catalog id ("" = your apps).
    var nudgeAppID: String = ""

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
        weeklyRecapEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .weeklyRecapEnabled)) ?? d.weeklyRecapEnabled
        nudgeEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .nudgeEnabled)) ?? d.nudgeEnabled
        nudgeHour = min(23, max(0, (try? c.decodeIfPresent(Int.self, forKey: .nudgeHour)) ?? d.nudgeHour))
        nudgeMinute = min(59, max(0, (try? c.decodeIfPresent(Int.self, forKey: .nudgeMinute)) ?? d.nudgeMinute))
        nudgeAppID = (try? c.decodeIfPresent(String.self, forKey: .nudgeAppID)) ?? d.nudgeAppID
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
    /// The window is a Custom length (UnlockChoice.custom) rather than a preset.
    var unlockCustom: Bool = false
    /// "Ask me after each prayer": the Amen screen offers the unlock lengths, the default preselected.
    var askUnlockEachTime: Bool = false
    /// Unlock with: Prayer (default), Read a verse or Devotional.
    var unlockMethod: UnlockMethod = .prayer
    var lastMood: PrayerMood?
    var sessionTextScale: Double = 1
    var windowEndNudge: Bool = true
    var gatedAppIDs: [String] = []
    var customApps: [GatedApp] = []
    var gateEnabled: Bool = true
    /// Screen Time shields (picked in onboarding) or the Shortcuts gate (the fallback when Screen Time is declined).
    var lockMethod: LockMethod = .shortcuts
    var reminders: ReminderSettings = ReminderSettings()
    var appearance: AppearancePreference = .dark
    var scrollHoursPerDay: Double = 3
    var hasOnboarded: Bool = false
    var hapticsEnabled: Bool = true
    var activeChallenges: [ActiveChallenge] = []
    var completedChallengeIDs: [String] = []
    var awardedMilestones: [Int] = []
    var circleDisplayEmoji: String = "🕊️"
    /// The nickname picked when joining or creating a circle (falls back to the first name).
    var circleNickname: String = ""
    /// Bible translation shown everywhere (both public domain).
    var translation: BibleTranslation = .web
    /// Scroll the Word text size (A− / A+), on top of Dynamic Type.
    var wordTextScale: Double = 1.0
    /// Read each verse aloud as it comes into view (system voices). Off by default.
    var readAloud: Bool = false
    /// Show the one-line "what this means" under each verse.
    var showMeanings: Bool = true
    /// Scroll the Word's daily goal (verses), the ring in the feed's corner.
    var wordGoal: Int = 10
    /// The soft ambient loop under Scroll the Word. Off by default.
    var ambientSound: Bool = false
    /// v1.1 friends: friends see "saved this" on verses I save (only the references). Off by default.
    var shareSavesWithFriends: Bool = false

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
        unlockCustom = try c.decodeIfPresent(Bool.self, forKey: .unlockCustom) ?? d.unlockCustom
        askUnlockEachTime = try c.decodeIfPresent(Bool.self, forKey: .askUnlockEachTime) ?? d.askUnlockEachTime
        unlockMethod = (try? c.decodeIfPresent(UnlockMethod.self, forKey: .unlockMethod)) ?? d.unlockMethod
        lastMood = try? c.decodeIfPresent(PrayerMood.self, forKey: .lastMood)
        sessionTextScale = try c.decodeIfPresent(Double.self, forKey: .sessionTextScale) ?? d.sessionTextScale
        windowEndNudge = try c.decodeIfPresent(Bool.self, forKey: .windowEndNudge) ?? d.windowEndNudge
        gatedAppIDs = try c.decodeIfPresent([String].self, forKey: .gatedAppIDs) ?? d.gatedAppIDs
        customApps = (try? c.decodeIfPresent([GatedApp].self, forKey: .customApps)) ?? d.customApps
        gateEnabled = try c.decodeIfPresent(Bool.self, forKey: .gateEnabled) ?? d.gateEnabled
        #if STRICT_LOCK
        lockMethod = (try? c.decodeIfPresent(LockMethod.self, forKey: .lockMethod)) ?? d.lockMethod
        #else
        lockMethod = .shortcuts   // the default build has no Screen Time lock, whatever an older build saved
        #endif
        translation = (try? c.decodeIfPresent(BibleTranslation.self, forKey: .translation)) ?? d.translation
        wordTextScale = (try? c.decodeIfPresent(Double.self, forKey: .wordTextScale)) ?? d.wordTextScale
        readAloud = (try? c.decodeIfPresent(Bool.self, forKey: .readAloud)) ?? d.readAloud
        showMeanings = (try? c.decodeIfPresent(Bool.self, forKey: .showMeanings)) ?? d.showMeanings
        wordGoal = min(200, max(1, (try? c.decodeIfPresent(Int.self, forKey: .wordGoal)) ?? d.wordGoal))
        ambientSound = (try? c.decodeIfPresent(Bool.self, forKey: .ambientSound)) ?? d.ambientSound
        shareSavesWithFriends = (try? c.decodeIfPresent(Bool.self, forKey: .shareSavesWithFriends)) ?? d.shareSavesWithFriends
        reminders = (try? c.decodeIfPresent(ReminderSettings.self, forKey: .reminders)) ?? d.reminders
        appearance = (try? c.decodeIfPresent(AppearancePreference.self, forKey: .appearance)) ?? d.appearance
        scrollHoursPerDay = try c.decodeIfPresent(Double.self, forKey: .scrollHoursPerDay) ?? d.scrollHoursPerDay
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? d.hasOnboarded
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? d.hapticsEnabled
        activeChallenges = (try? c.decodeIfPresent([ActiveChallenge].self, forKey: .activeChallenges)) ?? d.activeChallenges
        completedChallengeIDs = try c.decodeIfPresent([String].self, forKey: .completedChallengeIDs) ?? d.completedChallengeIDs
        awardedMilestones = try c.decodeIfPresent([Int].self, forKey: .awardedMilestones) ?? d.awardedMilestones
        circleDisplayEmoji = try c.decodeIfPresent(String.self, forKey: .circleDisplayEmoji) ?? d.circleDisplayEmoji
        circleNickname = try c.decodeIfPresent(String.self, forKey: .circleNickname) ?? d.circleNickname
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
