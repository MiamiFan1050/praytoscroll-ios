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
}

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let options: LaunchOptions
    let store: SharedStore
    let container: ModelContainer
    let circles: any CircleService
    /// Screen Time shields (Apple's in the app, a stand-in in the Debug demo, a fake in unit tests).
    let lock: any AppLock
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
    var pendingChallengeID: String?
    var verifiedGateApp: GatedApp?
    var troubleshootApp: GatedApp?
    var showSettings = false
    var showGateSetup = false
    var showLockSetup = false
    var peopleShowsAnswered = false
    var openCircleCode: String?
    var toast: String?
    var shortcutsInstalled = true
    /// Set when Screen Time refuses the relock timer: the apps stay locked and this explains why (never silent).
    var lockProblem: String?
    /// Bumped after the picked apps change, so views showing their icons refresh.
    private(set) var lockRevision = 0

    private var testingApp: GatedApp?
    private var testStartedAt: Date?

    /// `store` is injectable so unit tests can drive the real gate/streak code against scratch defaults.
    init(options: LaunchOptions = .current, store injected: SharedStore? = nil, lock injectedLock: (any AppLock)? = nil) {
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
        self.lock = injectedLock ?? (demo ? (options.showOnboarding ? DemoLock(authorized: false, picked: []) : DemoLock()) : ScreenTimeLock())
        if demo {
            DemoSeeder.seedDefaults(store: sharedStore, options: options)
        }
        #else
        self.circles = CloudKitCircleService()
        self.lock = injectedLock ?? ScreenTimeLock()
        #endif
        var loaded = sharedStore.settings
        #if DEBUG
        if let forced = options.appearance { loaded.appearance = forced }
        #endif
        self.settings = loaded
        Haptics.enabled = loaded.hapticsEnabled
        #if DEBUG
        if demo {
            DemoSeeder.seedData(context: modelContainer.mainContext, store: sharedStore)
            var seeded = sharedStore.settings
            if let forced = options.appearance { seeded.appearance = forced }
            self.settings = seeded
        }
        #endif
        reloadGateState()
        refreshStreak()
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
        let lockChanged = copy.gateEnabled != settings.gateEnabled || copy.lockMethod != settings.lockMethod
        settings = copy
        store.settings = copy
        Haptics.enabled = copy.hapticsEnabled
        if remindersChanged { refreshReminders() }
        if lockChanged { syncLock() }
        WidgetCenter.shared.reloadAllTimelines()
    }

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
        GateSetupStatus.status(lastFired: gateFired[app.id], markedSetUpAt: setupMarked[app.id], now: now)
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
        guard let url = app.openURL else { return }
        UIApplication.shared.open(url)
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
                     verse: Verse? = nil, seedPrompt: String? = nil) {
        let request = SessionRequest(style: style ?? settings.unlockStyle, source: source, gatedAppID: gatedAppID,
                                     personID: personID, mood: mood, isSample: isSample,
                                     verse: verse, seedPrompt: seedPrompt)
        if activeSession != nil {
            activeSession = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.activeSession = request }
        } else {
            activeSession = request
        }
    }

    func gatedApp(id: String?) -> GatedApp? {
        guard let id else { return nil }
        return AppCatalog.app(id: id, customApps: settings.customApps)
    }

    /// Minimum seconds before Amen unlocks, by style.
    func minimumSeconds(for style: UnlockStyle, isSample: Bool) -> Double {
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

        // Milestones
        let earned = MilestoneEngine.newlyEarned(streak: streak.current, alreadyAwarded: Set(settings.awardedMilestones))
        if !earned.isEmpty {
            updateSettings { $0.awardedMilestones = Array(Set($0.awardedMilestones + earned)).sorted() }
        }

        // Unlock: write it to the app group now, before any "Continue" can reopen the app.
        let now = Date()
        var until: Date?
        switch settings.unlockMode {
        case .window:
            let end = lockSafeEnd(GateEngine.unlock(from: now, minutes: effectiveWindowMinutes, existing: store.unlockedUntil), now: now)
            store.unlockedUntil = end
            until = end
            ReminderService.shared.scheduleWindowEnd(at: end, minutes: effectiveWindowMinutes, enabled: settings.windowEndNudge)
        case .dailyKey:
            let end = lockSafeEnd(GateEngine.dailyKeyUntil(from: now, resetHour: settings.dailyKeyResetHour, calendar: .current), now: now)
            store.dailyKeyUntil = end
            until = end
        }
        reloadGateState()
        syncLock(now: now)
        refreshChallenges()
        refreshReminders()
        WidgetCenter.shared.reloadAllTimelines()
        reportCircleProgress()

        return PrayerCompletion(previousStreak: previous, streak: streak, newMilestones: earned,
                                unlockMode: settings.unlockMode, unlockedUntil: until,
                                gatedApp: gatedApp(id: outcome.gatedAppID), personName: outcome.personName)
    }

    // MARK: People

    func fetchPerson(id: UUID) -> Person? {
        try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.id == id })).first
    }

    func allPeople() -> [Person] {
        (try? context.fetch(FetchDescriptor<Person>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    @discardableResult
    func addPerson(name: String, relationship: String, emoji: String = "") -> Person {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = allPeople().first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let person = Person(name: trimmed, relationship: relationship, emoji: emoji)
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
        }
    }

    /// `-route <name>` in demo mode jumps straight to a screen (debugging + screenshots).
    #if DEBUG
    /// Debug builds only: `-route <name>` opens a screen directly for UI tests and screenshots.
    func openDemoRoute(_ route: String) {
        switch route {
        case "pray": startPrayer(source: .manual)
        case "gatepray": startPrayer(source: .gate, gatedAppID: "instagram")
        case "quick": startPrayer(style: .quick, source: .manual)
        case "someone": startPrayer(style: .forSomeone, source: .manual, personID: suggestedPerson()?.id)
        case "choose": startPrayer(style: .forSomeone, source: .manual)
        case "gate": showGateSetup = true
        case "lock": showLockSetup = true
        case "people": selectedTab = .people
        case "answered":
            selectedTab = .people
            peopleShowsAnswered = true
        case "circle":
            selectedTab = .together
            openCircleCode = "K7Q2MX"
        case "stats": selectedTab = .progress
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
        // Lift Screen Time shields first: the picked apps are erased with everything else.
        lock.cancelRelock()
        lock.unshield()
        lock.forgetSelection()
        store.screenTimeActive = false
        lockRevision += 1
        try? context.delete(model: PrayerSession.self)
        try? context.delete(model: JournalEntry.self)
        try? context.delete(model: PrayerRequest.self)
        try? context.delete(model: Person.self)
        try? context.delete(model: SavedVerse.self)
        try? context.save()
        // Delete my circle rows BEFORE the member id goes: resetAll() would otherwise mint a new id first,
        // and the old nickname/count rows would stay in the public database.
        let codes = store.circleCodes
        let memberID = store.circleMemberID
        let circles = self.circles
        let store = self.store
        store.resetAll(keepingCircleMemberID: !codes.isEmpty)
        Task {
            try? await circles.deleteMyData(codes: codes)
            if !codes.isEmpty, store.circleMemberID == memberID { store.forgetCircleMemberID() }
        }
        settings = AppSettings()
        store.settings = settings
        ReminderService.shared.cancelAll()
        reloadGateState()
        refreshStreak()
        WidgetCenter.shared.reloadAllTimelines()
        selectedTab = .today
    }
}
