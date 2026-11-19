import Foundation
import Observation
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

enum AppTab: String, Hashable, CaseIterable {
    case today, word, people, together, progress
}

/// A prayer the app should present.
struct SessionRequest: Identifiable, Equatable {
    let id = UUID()
    var style: UnlockStyle
    var source: SessionSource
    var gatedAppID: String?
    var personID: UUID?
    var mood: PrayerMood?
    /// Onboarding "Try it" sample: a short prayer that doesn't count or unlock anything.
    var isSample: Bool = false
    /// "Pray this" from Scroll the Word: pray a specific verse or prompt.
    var verse: Verse?
    var seedPrompt: String?
    /// "Pray about…" a topic (family, healing, work…).
    var topic: PrayerTopic?
    /// "Pray now" on a circle prayer request: the Amen records "I prayed 🙏" on it.
    var circleRequest: CirclePrayerRequest?
    /// "Pray for @friend": the Amen shows them "@you prayed for you 🙏".
    var friend: FriendProfile?
    /// "Pray to watch" on a Bible Stories episode: the Amen opens that episode for good.
    var storyEpisodeID: String?
    /// Night prayer: the five-step evening Examen (a guided prayer with its own prompts).
    var isNightPrayer: Bool = false
}

/// What happened in a finished prayer.
struct PrayerOutcome {
    var style: UnlockStyle
    var source: SessionSource
    var gatedAppID: String?
    var startedAt: Date
    var completedAt: Date
    var personID: UUID?
    var personName: String = ""
    var verseRef: String = ""
    var circleRequest: CirclePrayerRequest?
    var friend: FriendProfile?
    var storyEpisodeID: String?
    /// The mood chip picked, for "Your week" (most-felt mood).
    var mood: PrayerMood?
    var isNightPrayer: Bool = false
}

/// What the celebration shows.
struct PrayerCompletion: Equatable {
    var previousStreak: Int
    var streak: StreakSummary
    var newMilestones: [Int]
    var unlockMode: UnlockMode
    var unlockedUntil: Date?
    var gatedApp: GatedApp?
    var personName: String
    /// How long this Amen unlocked (the default, or what the person picked on the Amen screen).
    var unlockChoice: UnlockChoice = .minutes(GateEngine.defaultWindowMinutes)
}

/// The gate state just before a prayer's unlock, so "Ask me after each prayer" can re-apply this prayer's
/// window with another length (shorter included) without touching what earlier prayers opened.
struct UnlockBase: Equatable {
    var unlockedUntil: Date?
    var dailyKeyUntil: Date?
    var at: Date
}

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let options: LaunchOptions
    let store: SharedStore
    let container: ModelContainer
    let circles: any CircleService
    let friends: any FriendService
    #if STRICT_LOCK
    /// Screen Time shields (Apple's in the app, a stand-in in the Debug demo, a fake in unit tests).
    let lock: any AppLock
    #endif
    /// The address book for "Add someone" type-ahead. Read on demand, never uploaded.
    let contacts: any ContactsProvider
    let content = ContentStore.shared
    let verses = VerseProvider.shared

    private(set) var settings: AppSettings
    private(set) var streak: StreakSummary = .empty
    private(set) var unlockedUntil: Date?
    private(set) var dailyKeyUntil: Date?
    private(set) var pausedUntil: Date?
    private(set) var emergencyLastUsed: Date?
    private(set) var gateFired: [String: Date] = [:]
    private(set) var setupMarked: [String: Date] = [:]
    private(set) var emergencyUses: Int = 0

    // Navigation + global presentation
    var selectedTab: AppTab = .today
    var openJournal = false
    var sampleCompleted = false
    var activeSession: SessionRequest?
    var pendingJoinCode: String?
    /// A praytoscroll.vercel.app/u/<name> or prayscroll://u/<name> link: Together opens the add-friend lookup.
    var pendingFriendHandle: String?
    /// My @username (nil until chosen; friends can't find me before that).
    var username: String?
    /// Bumped after any friend change so the Friends section reloads.
    var friendsRevision = 0
    var pendingChallengeID: String?
    var verifiedGateApp: GatedApp?
    var troubleshootApp: GatedApp?
    var showSettings = false
    var showGateSetup = false
    #if STRICT_LOCK
    var showLockSetup = false
    #endif
    var peopleShowsAnswered = false
    var openCircleCode: String?
    var toast: String?
    var shortcutsInstalled = true
    #if STRICT_LOCK
    /// Set when Screen Time refuses the relock timer: the apps stay locked and this explains why (never silent).
    var lockProblem: String?
    /// Bumped after the picked apps change, so views showing their icons refresh.
    private(set) var lockRevision = 0
    #endif

    /// Scroll the Word progress: verses read, goal streak, level, badges, boards, "For you" weights. On this iPhone only.
    var wordProgress = WordProgress() {
        didSet { store.wordProgressData = try? JSONEncoder().encode(wordProgress) }
    }
    /// v1.1 friends: who saved which verse ("Grace saved this"), by reference. Loaded when the feed opens.
    private(set) var friendSaves: [String: [String]] = [:]
    private var friendSavesLoadedAt: Date?

    private var testingApp: GatedApp?
    private var testStartedAt: Date?

    /// `store` is injectable so unit tests can drive the real gate/streak code against scratch defaults.
    init(options: LaunchOptions = .current, store injected: SharedStore? = nil, lock injectedLock: LockInjection? = nil) {
        self.options = options
        #if DEBUG
        let demo = options.isDemo
        if demo, injected == nil {
            UserDefaults.standard.removePersistentDomain(forName: AppConstants.demoSuite)
        }
        #else
        let demo = false
        #endif
        let sharedStore = injected ?? SharedStore.shared
        let modelContainer = AppModel.makeContainer(inMemory: demo)
        self.store = sharedStore
        self.container = modelContainer
        #if DEBUG
        self.circles = demo ? MockCircleService.demo() : CloudKitCircleService()
        self.friends = demo ? MockFriendService.demo(withUsername: !options.showOnboarding && !options.noUsername) : CloudKitFriendService()
        #if STRICT_LOCK
        self.lock = injectedLock ?? (demo ? (options.showOnboarding ? DemoLock(authorized: false, picked: []) : DemoLock()) : ScreenTimeLock())
        #endif
        self.contacts = demo ? DemoContacts(status: options.contactsStatus ?? .notDetermined) : DeviceContacts()
        if demo {
            DemoSeeder.seedDefaults(store: sharedStore, options: options)
        }
        #else
        self.circles = CloudKitCircleService()
        self.friends = CloudKitFriendService()
        #if STRICT_LOCK
        self.lock = injectedLock ?? ScreenTimeLock()
        #endif
        self.contacts = DeviceContacts()
        #endif
        var loaded = sharedStore.settings
        #if DEBUG
        if let forced = options.appearance { loaded.appearance = forced }
        #endif
        self.settings = loaded
        VerseProvider.shared.translation = loaded.translation
        Haptics.enabled = loaded.hapticsEnabled
        #if DEBUG
        if demo {
            DemoSeeder.seedData(context: modelContainer.mainContext, store: sharedStore, withPeople: !options.noPeople)
            var seeded = sharedStore.settings
            if let forced = options.appearance { seeded.appearance = forced }
            self.settings = seeded
        }
        #endif
        self.username = sharedStore.username
        if let data = sharedStore.wordProgressData, let saved = try? JSONDecoder().decode(WordProgress.self, from: data) {
            self.wordProgress = saved
        }
        reloadGateState()
        refreshStreak()
        #if DEBUG
        if demo { Task { await self.refreshUsername() } }
        #endif
    }

    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema(PrayToScrollSchema.models)
        let config = ModelConfiguration("PrayToScroll", schema: schema, isStoredInMemoryOnly: inMemory,
                                        groupContainer: .none, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }
        // Last resort: never crash on a corrupted store; fall back to memory and keep the app usable.
        let memory = ModelConfiguration("PrayToScrollRecovery", schema: schema, isStoredInMemoryOnly: true,
                                        groupContainer: .none, cloudKitDatabase: .none)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [memory])
    }

    var context: ModelContext { container.mainContext }

    // MARK: Settings

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        var copy = settings
        change(&copy)
        guard copy != settings else { return }
        let remindersChanged = copy.reminders != settings.reminders || copy.firstName != settings.firstName
        #if STRICT_LOCK
        let lockChanged = copy.gateEnabled != settings.gateEnabled || copy.lockMethod != settings.lockMethod
        #endif
        let translationChanged = copy.translation != settings.translation
        settings = copy
        store.settings = copy
        if translationChanged { verses.translation = copy.translation; refreshReminders() }
        Haptics.enabled = copy.hapticsEnabled
        if remindersChanged { refreshReminders() }
        #if STRICT_LOCK
        if lockChanged { syncLock() }
        #endif
        WidgetCenter.shared.reloadAllTimelines()
    }

    #if STRICT_LOCK
    // MARK: Screen Time lock

    /// Screen Time shields are the lock (picked in onboarding / Settings, access granted, apps picked).
    var usesScreenTime: Bool {
        settings.lockMethod == .screenTime && lock.authorization == .approved && lock.hasSelection
    }

    /// The unlock window actually used: Screen Time can't relock sooner than 15 minutes.
    var effectiveWindowMinutes: Int {
        ShieldPlanner.effectiveWindowMinutes(settings.unlockWindowMinutes, method: usesScreenTime ? .screenTime : .shortcuts)
    }

    var emergencyMinutes: Int { ShieldPlanner.emergencyMinutes(for: usesScreenTime ? .screenTime : .shortcuts) }

    /// Brings Apple's shields in line with the gate state: shielded, open with a relock timer, or off.
    /// Called after every unlock, pause, resume, setting change, app pick and on every return to the app.
    func syncLock(now: Date = Date()) {
        let active = settings.gateEnabled && usesScreenTime
        let plan = ShieldPlanner.plan(now: now, active: active, unlockedUntil: store.unlockedUntil,
                                      pausedUntil: store.pausedUntil, dailyKeyUntil: store.dailyKeyUntil)
        store.screenTimeActive = active
        let lock = self.lock
        let step = ShieldPlanner.step(for: plan, now: now, scheduledRelock: lock.scheduledRelock, monitoring: lock.isMonitoring)
        let ok = ShieldPlanner.perform(step, now: now, shield: { lock.shield() }, unshield: { lock.unshield() },
                                       schedule: { try lock.scheduleRelock(at: $0, now: now) }, cancel: { lock.cancelRelock() })
        lockProblem = ok ? nil : "Screen Time couldn't start the timer that locks your apps again, so they stay locked for now. Try again in a moment."
    }

    /// After the picker: start with "Screen Time" as the lock and shield the new picks.
    func lockSelectionChanged() {
        lockRevision += 1
        if lock.hasSelection, lock.authorization == .approved, settings.lockMethod != .screenTime {
            updateSettings { $0.lockMethod = .screenTime }   // syncs
        } else {
            syncLock()
        }
    }
    #else
    // The default build (project.yml) has no Screen Time: the Shortcuts gate is the lock, with its own timings.

    var usesScreenTime: Bool { false }
    var effectiveWindowMinutes: Int { settings.unlockWindowMinutes }
    var emergencyMinutes: Int { GateEngine.emergencyMinutes }
    /// Nothing to sync without Screen Time (the Shortcuts automation reads the gate state when an app opens).
    func syncLock(now: Date = Date()) {}
    #endif

    // MARK: Circle prayer requests

    /// Bumped when something changes a circle's requests outside its screen (a "Pray now" Amen), so it reloads.
    var circleRevision = 0

    /// A short prayer for a circle member's request. Finishing it records "I prayed 🙏".
    func prayForCircleRequest(_ request: CirclePrayerRequest) {
        let ask = request.note.isEmpty
            ? "\(request.displayName) asked your circle to pray about \(request.topic.requestTitle.lowercased()). Bring it to God for them, in your own words."
            : "\(request.displayName) asked your circle to pray: “\(request.note)”. Bring it to God for them, in your own words."
        startPrayer(style: .quick, source: .manual, seedPrompt: ask, topic: request.topic, circleRequest: request)
    }

    // MARK: Advent

    /// Today's Advent reading, only from Nov 29 to Dec 24 on the device's calendar.
    func adventToday(now: Date = Date()) -> (index: Int, day: AdventDay)? {
        AdventPlan.today(options.today ?? now, calendar: .current, days: content.advent)
    }

    func adventDaysPrayed(now: Date = Date()) -> Int {
        AdventPlan.daysPrayed(store.prayedDays, through: options.today ?? now, calendar: .current)
    }

    func prayAdvent(now: Date = Date()) {
        guard let today = adventToday(now: now) else { return }
        startPrayer(style: .verse, source: .manual,
                    verse: AdventPlan.verse(for: today.day, index: today.index, translation: settings.translation),
                    seedPrompt: today.day.prompt)
    }

    #if STRICT_LOCK
    /// Home's card for people who set up the v1.0 Shortcuts gate: the real lock is one tap away.
    var offersScreenTime: Bool {
        let _ = lockRevision
        return settings.gateEnabled && settings.lockMethod == .shortcuts && !settings.gatedAppIDs.isEmpty
            && lock.authorization != .denied && !store.screenTimeOfferDismissed
    }

    func dismissScreenTimeOffer() {
        store.screenTimeOfferDismissed = true
        lockRevision += 1
    }

    func retryLock() {
        lockProblem = nil
        syncLock()
    }

    /// Under Screen Time an unlock is at least 15 minutes (the shortest relock Apple runs).
    private func lockSafeEnd(_ end: Date, now: Date) -> Date {
        usesScreenTime ? ShieldPlanner.end(atLeastMinimumFrom: now, proposed: end) : end
    }
    #else
    private func lockSafeEnd(_ end: Date, now: Date) -> Date { end }
    #endif

    func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { self.settings[keyPath: keyPath] },
                set: { newValue in self.updateSettings { $0[keyPath: keyPath] = newValue } })
    }

    var colorScheme: ColorScheme? {
        switch settings.appearance {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    // MARK: Gate state

    func reloadGateState() {
        unlockedUntil = store.unlockedUntil
        dailyKeyUntil = store.dailyKeyUntil
        pausedUntil = store.pausedUntil
        emergencyLastUsed = store.emergencyLastUsed
        gateFired = store.gateFiredDates
        setupMarked = store.setupMarked
        emergencyUses = store.emergencyUses
        #if DEBUG
        let demo = options.isDemo
        #else
        let demo = false
        #endif
        shortcutsInstalled = demo || UIApplication.shared.canOpenURL(URL(string: "shortcuts://")!)
    }

    /// The moment apps are open until, from whichever unlock is active.
    func currentUnlockEnd(now: Date = Date()) -> Date? {
        let candidates = [unlockedUntil, dailyKeyUntil].compactMap { $0 }.filter { $0 > now }
        return candidates.max()
    }

    func isPaused(now: Date = Date()) -> Bool {
        guard let pausedUntil else { return false }
        return now < pausedUntil
    }

    func setupStatus(for app: GatedApp, now: Date = Date()) -> GateSetupStatus {
        // The all-apps automation fires as "app": it protects every gated app it was set up for.
        let fired = [gateFired[app.id], gateFired[GateEngine.anyAppID]].compactMap { $0 }.max()
        let marked = [setupMarked[app.id], setupMarked[GateEngine.anyAppID]].compactMap { $0 }.max()
        return GateSetupStatus.status(lastFired: fired, markedSetUpAt: marked, now: now)
    }

    var protectedCount: Int {
        settings.gatedApps.filter { setupStatus(for: $0).isProtected }.count
    }

    func markSetUp(_ app: GatedApp) {
        var marked = store.setupMarked
        marked[app.id] = Date()
        store.setupMarked = marked
        reloadGateState()
    }

    /// "I've added it" for the one automation that covers every gated app.
    func markAllAppsSetUp() {
        var marked = store.setupMarked
        marked[GateEngine.anyAppID] = Date()
        store.setupMarked = marked
        reloadGateState()
    }

    /// The app "Test my gate" opens: the first gated app we can open by URL.
    var testableGatedApp: GatedApp? { settings.gatedApps.first { $0.openURL != nil } }

    var canUseEmergencyPass: Bool {
        GateEngine.canUseEmergencyPass(now: Date(), lastUsed: emergencyLastUsed, calendar: .current)
    }

    func pauseGate(days: Int?) {
        if let days {
            store.pausedUntil = Calendar.current.date(byAdding: .day, value: days, to: Date())
            toast = "Gate paused"
        } else {
            store.pausedUntil = nil
            toast = "Gate is back on"
        }
        reloadGateState()
        syncLock()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Opens the gated app for 5 minutes without a prayer. Once a day, counted honestly.
    @discardableResult
    func useEmergencyPass(for app: GatedApp?) -> Bool {
        guard canUseEmergencyPass else { return false }
        let now = Date()
        store.emergencyLastUsed = now
        store.emergencyUses += 1
        store.activity.record(.emergency, app: app?.id, at: now)
        let until = lockSafeEnd(GateEngine.unlock(from: now, minutes: emergencyMinutes, existing: store.unlockedUntil), now: now)
        store.unlockedUntil = until
        reloadGateState()
        syncLock(now: now)
        ReminderService.shared.scheduleWindowEnd(at: until, minutes: emergencyMinutes, enabled: settings.windowEndNudge)
        if let app { openApp(app) }
        return true
    }

    /// Reopens a gated app. The unlock and a 30 s launch pass are written BEFORE the URL opens,
    /// so the automation that fires on the way in returns silently.
    func openApp(_ app: GatedApp) {
        store.grantLaunchPass(appID: app.id)
        guard let url = app.openURL else {
            toast = "Now open \(app.name). It’s unlocked."
            return
        }
        UIApplication.shared.open(url) { [weak self] opened in
            guard !opened else { return }
            Task { @MainActor in self?.toast = "Now open \(app.name). It’s unlocked." }
        }
    }

    // MARK: Gate tests

    /// "Test my gate": flag the app, open it, and wait for the automation to report back.
    func testGate(_ app: GatedApp) {
        guard let url = app.openURL else {
            troubleshootApp = app
            return
        }
        store.startTest(appID: app.id)
        testingApp = app
        testStartedAt = Date()
        UIApplication.shared.open(url) { [weak self] opened in
            Task { @MainActor in
                guard let self else { return }
                if !opened {
                    self.store.clearTest(appID: app.id)
                    self.testingApp = nil
                    self.toast = "\(app.name) isn't installed on this iPhone"
                }
            }
        }
    }

    /// Called by the intent (or a pending flag) when the automation fired during a test.
    func gateVerified(appID: String) {
        store.clearTest(appID: appID)
        testingApp = nil
        reloadGateState()
        verifiedGateApp = AppCatalog.app(id: appID, customApps: settings.customApps)
            ?? GatedApp.custom(name: appID.capitalized, scheme: "")
        Haptics.success()
    }

    // MARK: Foreground

    func sceneBecameActive() {
        reloadGateState()
        refreshStreak()
        syncLock()
        if let pending = store.consumePendingGate() {
            handlePendingGate(pending)
        } else if let app = testingApp, let started = testStartedAt {
            // Back in PrayToScroll without the automation reporting in: help them fix it.
            if Date().timeIntervalSince(started) > 8, store.testPending[app.id] != nil {
                store.clearTest(appID: app.id)
                testingApp = nil
                troubleshootApp = app
            }
        }
        ReminderService.shared.refreshIfNeeded(model: self)
    }

    private func handlePendingGate(_ pending: String) {
        if pending.hasPrefix("verify:") {
            gateVerified(appID: String(pending.dropFirst("verify:".count)))
        } else {
            startGatePrayer(appID: pending)
        }
    }

    /// Entry point from the "Pray Before …" intents once PrayToScroll is in the foreground.
    func handleIntentContinuation(appID: String, verify: Bool) {
        _ = store.consumePendingGate()
        if verify {
            gateVerified(appID: appID)
        } else {
            startGatePrayer(appID: appID)
        }
    }

    func startGatePrayer(appID: String) {
        if let current = activeSession, current.source == .gate, current.gatedAppID == appID { return }
        reloadGateState()
        startPrayer(source: .gate, gatedAppID: appID)
    }

    // MARK: Prayer

    func startPrayer(style: UnlockStyle? = nil, source: SessionSource, gatedAppID: String? = nil,
                     personID: UUID? = nil, mood: PrayerMood? = nil, isSample: Bool = false,
                     verse: Verse? = nil, seedPrompt: String? = nil, topic: PrayerTopic? = nil,
                     circleRequest: CirclePrayerRequest? = nil, friend: FriendProfile? = nil,
                     storyEpisodeID: String? = nil, nightPrayer: Bool = false) {
        var request = SessionRequest(style: style ?? defaultSessionStyle, source: source, gatedAppID: gatedAppID,
                                     personID: personID, mood: mood, isSample: isSample,
                                     verse: verse, seedPrompt: seedPrompt, topic: topic, circleRequest: circleRequest,
                                     friend: friend, storyEpisodeID: storyEpisodeID)
        request.isNightPrayer = nightPrayer
        if activeSession != nil {
            activeSession = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.activeSession = request }
        } else {
            activeSession = request
        }
    }

    /// Night prayer: thank, look back, sorry, ask, tomorrow. A guided prayer, so it counts for the streak like any other.
    func startNightPrayer(source: SessionSource = .manual) {
        startPrayer(style: .guided, source: source, nightPrayer: true)
    }

    /// The minimum for Night prayer (about two and a half minutes across its five steps).
    var nightPrayerSeconds: Double {
        #if DEBUG
        if options.isUITest && !options.longMinimum { return 3 }
        #endif
        return Double(NightPrayer.seconds)
    }

    /// Already prayed Night prayer this evening (the evening runs until 3 AM).
    func prayedNightPrayerTonight(now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let tonight = NightPrayer.eveningKey(for: now, calendar: calendar)
        return store.activity.events.contains { $0.kind == .nightPrayer && NightPrayer.eveningKey(for: $0.at, calendar: calendar) == tonight }
    }

    func gatedApp(id: String?) -> GatedApp? {
        guard let id else { return nil }
        return AppCatalog.app(id: id, customApps: settings.customApps)
    }

    /// Minimum seconds before Amen unlocks, by style.
    /// What a prayer starts as by default: the Unlock with choice (Prayer uses the prayer style).
    var defaultSessionStyle: UnlockStyle {
        settings.unlockMethod.style(prayerStyle: settings.unlockStyle)
    }

    /// The style for a method picked on the gate screen ("Ask me after each prayer").
    func sessionStyle(for method: UnlockMethod) -> UnlockStyle {
        method.style(prayerStyle: settings.unlockStyle)
    }

    func minimumSeconds(for style: UnlockStyle, isSample: Bool, readingWords: Int = 0) -> Double {
        #if DEBUG
        if isSample { return options.isUITest && !options.longMinimum ? 2 : 15 }
        if options.isUITest && !options.longMinimum { return 3 }
        #else
        if isSample { return 15 }
        #endif
        switch style {
        case .quick: return 30
        case .guided: return Double(max(30, settings.guidedSeconds))
        case .verse: return 45
        case .forSomeone: return 40
        case .readVerse: return Double(ReadingTime.verse(words: readingWords))
        case .devotional: return Double(ReadingTime.devotional(words: readingWords))
        }
    }

    @discardableResult
    func completePrayer(_ outcome: PrayerOutcome) -> PrayerCompletion {
        let previous = streak.current
        let session = PrayerSession(startedAt: outcome.startedAt, completedAt: outcome.completedAt, style: outcome.style,
                                    source: outcome.source, gatedAppID: outcome.gatedAppID ?? "",
                                    personName: outcome.personName, verseRef: outcome.verseRef)
        session.personID = outcome.personID
        context.insert(session)
        if outcome.source == .gate {
            store.activity.record(.prayedFirst, app: outcome.gatedAppID.map { GateEngine.canonicalID($0, customApps: settings.customApps) },
                                  at: outcome.completedAt)
        }
        if let mood = outcome.mood { store.activity.record(.mood, detail: mood.rawValue, at: outcome.completedAt) }
        if outcome.isNightPrayer { store.activity.record(.nightPrayer, at: outcome.completedAt) }

        if let personID = outcome.personID {
            let descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.id == personID })
            if let person = try? context.fetch(descriptor).first {
                person.lastPrayedAt = outcome.completedAt
                person.prayerCount += 1
                for request in person.openRequests { request.timesPrayed += 1 }
            }
        }
        try? context.save()

        store.lastPrayerAt = outcome.completedAt
        refreshStreak()
        if let episodeID = outcome.storyEpisodeID { stories.unlock(episodeID) }

        if let circleRequest = outcome.circleRequest, !circleRequest.isMine {
            Task {
                try? await circles.prayed(for: circleRequest)
                circleRevision += 1
            }
        }
        if let friend = outcome.friend {
            Task {
                try? await friends.prayedFor(friend)
                friendsRevision += 1
            }
        }

        // Milestones
        let earned = MilestoneEngine.newlyEarned(streak: streak.current, alreadyAwarded: Set(settings.awardedMilestones))
        if !earned.isEmpty {
            updateSettings { $0.awardedMilestones = Array(Set($0.awardedMilestones + earned)).sorted() }
        }

        // Unlock: write it to the app group now, before any "Continue" can reopen the app.
        let base = UnlockBase(unlockedUntil: store.unlockedUntil, dailyKeyUntil: store.dailyKeyUntil, at: Date())
        lastUnlockBase = base
        let choice = unlockChoice
        let until = applyUnlock(choice, base: base)
        refreshChallenges()
        refreshReminders()
        WidgetCenter.shared.reloadAllTimelines()
        reportCircleProgress()
        publishFriendProfile()

        return PrayerCompletion(previousStreak: previous, streak: streak, newMilestones: earned,
                                unlockMode: settings.unlockMode, unlockedUntil: until,
                                gatedApp: gatedApp(id: outcome.gatedAppID), personName: outcome.personName,
                                unlockChoice: choice)
    }

    // MARK: Unlock length

    /// The default unlock length (Settings → Unlock for).
    var unlockChoice: UnlockChoice {
        let choice = UnlockChoice.current(in: settings)
        // A 5-minute default picked in Shortcuts mode becomes 15 under Screen Time (its floor).
        if case .minutes(let minutes) = choice, minutes < minimumUnlockMinutes { return .minutes(minimumUnlockMinutes) }
        return choice
    }

    /// The shortest window offered: 5 minutes in Shortcuts mode.
    #if STRICT_LOCK
    var minimumUnlockMinutes: Int { ShieldPlanner.minimumWindowMinutes(for: usesScreenTime ? .screenTime : .shortcuts) }
    #else
    var minimumUnlockMinutes: Int { GateEngine.minimumWindowMinutes }
    #endif

    /// The presets offered in Settings, onboarding and on the Amen screen (Custom is separate).
    var unlockPresets: [UnlockChoice] { UnlockChoice.presets(minimumMinutes: minimumUnlockMinutes) }

    @ObservationIgnored private(set) var lastUnlockBase: UnlockBase?

    /// Writes one prayer's unlock on top of `base` and returns when the apps lock again. Windows are absolute
    /// instants; the window-end nudge is rescheduled (cancelled for Rest of today, which ends at the reset hour).
    @discardableResult
    func applyUnlock(_ choice: UnlockChoice, base: UnlockBase) -> Date {
        // Under Screen Time nothing ends sooner than 15 minutes from the Amen (DeviceActivity's floor).
        let end = lockSafeEnd(choice.end(from: base.at, resetHour: settings.dailyKeyResetHour, calendar: .current), now: base.at)
        switch choice {
        case .restOfToday:
            store.unlockedUntil = base.unlockedUntil
            store.dailyKeyUntil = max(end, base.dailyKeyUntil ?? end)
            ReminderService.shared.scheduleWindowEnd(at: end, minutes: nil, enabled: false)
        case .minutes, .custom:
            store.dailyKeyUntil = base.dailyKeyUntil
            let window = GateEngine.unlock(from: base.at, until: end, existing: base.unlockedUntil)
            store.unlockedUntil = window
            let minutes = max(1, Int((window.timeIntervalSince(base.at) / 60).rounded()))
            ReminderService.shared.scheduleWindowEnd(at: window, minutes: minutes, enabled: settings.windowEndNudge)
        }
        reloadGateState()
        syncLock(now: base.at)
        return currentUnlockEnd(now: base.at) ?? end
    }

    /// "Ask me after each prayer": re-applies the last Amen's unlock with another length. Returns the new end.
    @discardableResult
    func changeLastUnlock(to choice: UnlockChoice) -> Date? {
        guard let base = lastUnlockBase else { return nil }
        let until = applyUnlock(choice, base: base)
        WidgetCenter.shared.reloadAllTimelines()
        return until
    }

    // MARK: Put it down

    /// "I'm good, put it down" after a gate prayer: this Amen's unlock is taken back (the gate goes back to exactly
    /// what it was before the prayer), nothing opens, and the win is logged. No launch pass is written, so the next
    /// open of the app asks again. Returns how many times this week (including this one) they chose not to scroll.
    @discardableResult
    func putItDown(appID: String?, now: Date = Date()) -> Int {
        if let base = lastUnlockBase {
            store.unlockedUntil = base.unlockedUntil
            store.dailyKeyUntil = base.dailyKeyUntil
            if let earlier = base.unlockedUntil, earlier > now {
                let minutes = max(1, Int((earlier.timeIntervalSince(now) / 60).rounded()))
                ReminderService.shared.scheduleWindowEnd(at: earlier, minutes: minutes, enabled: settings.windowEndNudge)
            } else {
                ReminderService.shared.scheduleWindowEnd(at: now, minutes: nil, enabled: false)   // cancel the nudge
            }
            lastUnlockBase = nil
            reloadGateState()
            syncLock(now: now)
        }
        let app = appID.map { GateEngine.canonicalID($0, customApps: settings.customApps) }
        store.activity.record(.putDown, app: app, at: now)
        WidgetCenter.shared.reloadAllTimelines()
        Haptics.success()
        return store.activity.count(.putDown, in: WeekWindow.current(now: now, calendar: .current))
    }

    // MARK: People

    func fetchPerson(id: UUID) -> Person? {
        try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.id == id })).first
    }

    func allPeople() -> [Person] {
        (try? context.fetch(FetchDescriptor<Person>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    @discardableResult
    func addPerson(name: String, relationship: String, emoji: String = "", phone: String? = nil) -> Person {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = allPeople().first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            if existing.textNumber == nil, let number, !number.isEmpty {
                existing.phone = number
                try? context.save()
            }
            return existing
        }
        let person = Person(name: trimmed, relationship: relationship, emoji: emoji)
        if let number, !number.isEmpty { person.phone = number }
        context.insert(person)
        try? context.save()
        return person
    }

    /// Whoever was prayed for longest ago (never-prayed-for first).
    func suggestedPerson(in people: [Person]? = nil) -> Person? {
        PeopleRanking.next(in: people ?? allPeople())
    }

    func saveJournal(text: String, personID: UUID?, style: UnlockStyle?, verseRef: String = "") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var person: Person?
        if let personID {
            person = try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.id == personID })).first
        }
        context.insert(JournalEntry(text: trimmed, person: person, style: style, verseRef: verseRef))
        try? context.save()
        toast = "Saved to your journal"
    }

    // MARK: Streak (computed from the prayer log, never a counter)

    func allSessions() -> [PrayerSession] {
        (try? context.fetch(FetchDescriptor<PrayerSession>(sortBy: [SortDescriptor(\.completedAt)]))) ?? []
    }

    func refreshStreak(now: Date = Date()) {
        let calendar = Calendar.current
        let days = Set(allSessions().map { DayKey($0.completedAt, calendar: calendar) })
        if days != store.prayedDays { store.prayedDays = days }   // mirror for the widget
        let today = DayKey(now, calendar: calendar)
        let frozen = StreakEngine.reconcileFreezes(prayed: days, frozen: store.frozenDays, today: today, calendar: calendar)
        if frozen != store.frozenDays { store.frozenDays = frozen }
        let summary = StreakEngine.summary(prayed: days, frozen: frozen, today: today, calendar: calendar)
        if summary != streak { streak = summary }
    }

    var prayedDays: Set<DayKey> { store.prayedDays }

    /// "Times you prayed instead of scrolling": prayers that came through the gate.
    var gatesHonoured: Int {
        let gate = SessionSource.gate.rawValue
        let descriptor = FetchDescriptor<PrayerSession>(predicate: #Predicate { $0.sourceRaw == gate })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: Challenges

    func startChallenge(_ id: String) {
        updateSettings { s in
            s.activeChallenges.removeAll { $0.id == id }
            s.activeChallenges.append(ActiveChallenge(id: id, startedAt: Date()))
        }
        Haptics.success()
    }

    func abandonChallenge(_ id: String) {
        updateSettings { $0.activeChallenges.removeAll { $0.id == id } }
    }

    func progress(for definition: ChallengeDefinition, active: ActiveChallenge, now: Date = Date()) -> ChallengeProgress {
        let people = allSessions()
            .filter { !$0.personName.isEmpty }
            .map { (name: $0.personName, date: $0.completedAt) }
        return ChallengeEngine.progress(definition: definition, startedAt: active.startedAt, now: now,
                                        prayedDays: prayedDays, peoplePrayedFor: people, calendar: .current)
    }

    /// Moves finished challenges to "completed" and awards them.
    func refreshChallenges() {
        var completedNow: [String] = []
        for active in settings.activeChallenges {
            guard let definition = content.challenge(id: active.id) else { continue }
            if progress(for: definition, active: active).isComplete { completedNow.append(active.id) }
        }
        guard !completedNow.isEmpty else { return }
        updateSettings { s in
            s.completedChallengeIDs = Array(Set(s.completedChallengeIDs + completedNow)).sorted()
        }
    }

    // MARK: Circles

    func prayersThisWeek(now: Date = Date()) -> Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return allSessions().filter { week.contains($0.completedAt) }.count
    }

    func reportCircleProgress() {
        let prayers = prayersThisWeek()
        let streakNow = streak.current
        let name = settings.circleName   // the nickname they chose for circles, never the private first name
        let emoji = settings.circleDisplayEmoji
        Task {
            try? await circles.reportProgress(displayName: name, emoji: emoji, prayersThisWeek: prayers, streak: streakNow)
        }
    }

    // MARK: Friends

    /// My friend profile: the circle nickname + emoji and my streak (never my first name or what I prayed), plus the
    /// references of verses I saved when I've chosen to share them.
    func myFriendProfile() -> FriendProfile {
        FriendProfile(memberID: store.circleMemberID, handle: username ?? "", displayName: settings.circleName,
                      emoji: settings.circleDisplayEmoji, streak: streak.current,
                      lastPrayedDay: store.lastPrayerAt.map { DayKey($0).string } ?? "",
                      savedRefs: settings.shareSavesWithFriends ? recentSavedRefs() : [])
    }

    /// The last 50 saved verse references, newest first.
    func recentSavedRefs(limit: Int = FriendProfile.maxSavedRefs) -> [String] {
        var fetch = FetchDescriptor<SavedVerse>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        fetch.fetchLimit = limit
        return ((try? context.fetch(fetch)) ?? []).map(\.ref)
    }

    // MARK: Scroll the Word

    /// Loads friends' saved verses (at most every 5 minutes), for "Grace and 2 friends saved this".
    func refreshFriendSaves(force: Bool = false) {
        guard username != nil else {
            friendSaves = [:]
            return
        }
        if !force, let at = friendSavesLoadedAt, Date().timeIntervalSince(at) < 300 { return }
        friendSavesLoadedAt = Date()
        let friends = self.friends
        Task {
            guard let snapshot = try? await friends.snapshot() else { return }
            self.friendSaves = FriendSaves.byRef(snapshot.friends)
        }
    }

    /// A verse was saved or un-saved: friends who can see my saves get the new list.
    func savedVersesChanged() {
        if settings.shareSavesWithFriends { publishFriendProfile() }
    }

    /// Keeps my profile current for friends, with the circles I own (friends can join those without a code).
    func publishFriendProfile() {
        guard username != nil else { return }   // hidden until a username is chosen
        let base = myFriendProfile()
        let me = store.circleMemberID
        let circles = self.circles
        let friends = self.friends
        Task {
            let owned = ((try? await circles.myCircles()) ?? []).filter { $0.ownerID == me }
            var profile = base
            profile.openCircles = owned.map { FriendProfile.OpenCircle(code: $0.code, name: $0.name) }
            try? await friends.publish(profile)
        }
    }

    /// Claims a @username (atomic: "taken" if someone has it). Frees the old one; once every 30 days.
    @discardableResult
    func claimUsername(_ raw: String) async throws -> String {
        let handle = try await friends.claim(handle: raw, profile: myFriendProfile())
        username = handle
        store.username = handle
        friendsRevision += 1
        publishFriendProfile()
        return handle
    }

    func refreshUsername() async {
        let server = await friends.myHandle()
        if server != username { username = server }
    }

    /// "Pray for @friend": a prayer for them; the Amen shows them "@me prayed for you 🙏".
    func prayFor(friend: FriendProfile) {
        startPrayer(style: .forSomeone, source: .manual, friend: friend)
    }

    // MARK: Reminders

    func refreshReminders() {
        ReminderService.shared.refresh(settings: settings, streak: streak, verses: verses, copy: content.copy)
    }

    // MARK: Deep links

    func handle(url: URL) {
        guard let link = DeepLink(url: url) else { return }
        handle(link)
    }

    func handle(_ link: DeepLink) {
        switch link {
        case .pray(let appID, let mood):
            if let appID {
                startGatePrayer(appID: appID)
            } else if mood == .tempted {
                startPrayer(style: .quick, source: .deepLink, mood: .tempted)
            } else {
                startPrayer(source: .deepLink, mood: mood)
            }
        case .join(let code):
            selectedTab = .together
            pendingJoinCode = code
        case .user(let handle):
            selectedTab = .together
            pendingFriendHandle = handle
        case .challenge(let id):
            selectedTab = .together
            pendingChallengeID = id
        case .stats:
            selectedTab = .progress
        case .people:
            selectedTab = .people
        case .journal:
            selectedTab = .progress
            openJournal = true
        case .word:
            selectedTab = .word
        case .nightPrayer:
            startNightPrayer(source: .deepLink)
        }
    }

    /// `-route <name>` in demo mode jumps straight to a screen (debugging + screenshots).
    #if DEBUG
    /// Debug builds only: `-route <name>` opens a screen directly for UI tests and screenshots.
    func openDemoRoute(_ route: String) {
        switch route {
        case "pray": startPrayer(source: .manual)
        case "gatepray": startPrayer(source: .gate, gatedAppID: "instagram")
        case "gateany": startPrayer(style: .quick, source: .gate, gatedAppID: GateEngine.anyAppID)
        case "gateask":
            updateSettings { $0.askUnlockEachTime = true }
            startPrayer(source: .gate, gatedAppID: "instagram")
        case "quick": startPrayer(style: .quick, source: .manual)
        case "night": startNightPrayer()
        case "someone": startPrayer(style: .forSomeone, source: .manual, personID: suggestedPerson()?.id)
        case "choose": startPrayer(style: .forSomeone, source: .manual)
        case "gate": showGateSetup = true
        #if STRICT_LOCK
        case "lock": showLockSetup = true
        #endif
        case "people": selectedTab = .people
        case "answered":
            selectedTab = .people
            peopleShowsAnswered = true
        case "circle":
            selectedTab = .together
            openCircleCode = "K7Q2MX"
        case "stats": selectedTab = .progress
        case "friends": selectedTab = .together
        case "journal":
            selectedTab = .progress
            openJournal = true
        case "word": selectedTab = .word
        case "settings": showSettings = true
        case "verified": verifiedGateApp = AppCatalog.app(id: "instagram")
        case "troubleshoot": troubleshootApp = AppCatalog.app(id: "instagram")
        default: break
        }
    }
    #endif

    // MARK: Reset

    func resetAllData() {
        #if STRICT_LOCK
        // Lift Screen Time shields first: the picked apps are erased with everything else.
        lock.cancelRelock()
        lock.unshield()
        lock.forgetSelection()
        store.screenTimeActive = false
        lockRevision += 1
        #endif
        try? context.delete(model: PrayerSession.self)
        try? context.delete(model: JournalEntry.self)
        try? context.delete(model: PrayerRequest.self)
        try? context.delete(model: Person.self)
        try? context.delete(model: SavedVerse.self)
        try? context.save()
        // Delete my circle rows BEFORE the member id goes: resetAll() would otherwise mint a new id first,
        // and the old nickname/count rows would stay in the public database.
        // The same goes for my Username record, friend links, requests and prayed-for rows.
        let codes = store.circleCodes
        let memberID = store.circleMemberID
        let circles = self.circles
        let friends = self.friends
        let handle = username ?? store.username
        let store = self.store
        let keepID = !codes.isEmpty || handle != nil
        store.resetAll(keepingCircleMemberID: keepID)
        username = nil
        friendsRevision += 1
        wordProgress = WordProgress()
        friendSaves = [:]
        Task {
            try? await circles.deleteMyData(codes: codes)
            if let handle { try? await friends.deleteMyData(handle: handle) }
            if keepID, store.circleMemberID == memberID { store.forgetCircleMemberID() }
        }
        settings = AppSettings()
        store.settings = settings
        verses.translation = settings.translation
        ReminderService.shared.cancelAll()
        reloadGateState()
        refreshStreak()
        WidgetCenter.shared.reloadAllTimelines()
        selectedTab = .today
    }
}

#if STRICT_LOCK
/// Unit tests hand AppModel a fake Screen Time lock.
typealias LockInjection = any AppLock
#else
/// No Screen Time in this build, so there's nothing to inject.
enum LockInjection {}
#endif
