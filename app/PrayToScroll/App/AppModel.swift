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
    var peopleShowsAnswered = false
    var openCircleCode: String?
    var toast: String?
    var shortcutsInstalled = true

    private var testingApp: GatedApp?
    private var testStartedAt: Date?

    init(options: LaunchOptions = .current) {
        self.options = options
        if options.isDemo {
            UserDefaults.standard.removePersistentDomain(forName: AppConstants.demoSuite)
        }
        let sharedStore = SharedStore.shared
        let modelContainer = AppModel.makeContainer(inMemory: options.isDemo)
        self.store = sharedStore
        self.container = modelContainer
        self.circles = options.isDemo ? MockCircleService.demo() : CloudKitCircleService()
        if options.isDemo {
            DemoSeeder.seedDefaults(store: sharedStore, options: options)
        }
        var loaded = sharedStore.settings
        if let forced = options.appearance { loaded.appearance = forced }
        self.settings = loaded
        Haptics.enabled = loaded.hapticsEnabled
        if options.isDemo {
            DemoSeeder.seedData(context: modelContainer.mainContext, store: sharedStore)
        }
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
        settings = copy
        store.settings = copy
        Haptics.enabled = copy.hapticsEnabled
        if remindersChanged { refreshReminders() }
        WidgetCenter.shared.reloadAllTimelines()
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
        shortcutsInstalled = options.isDemo || UIApplication.shared.canOpenURL(URL(string: "shortcuts://")!)
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
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Opens the gated app for 5 minutes without a prayer. Once a day, counted honestly.
    @discardableResult
    func useEmergencyPass(for app: GatedApp?) -> Bool {
        guard canUseEmergencyPass else { return false }
        let now = Date()
        store.emergencyLastUsed = now
        store.emergencyUses += 1
        let until = GateEngine.unlock(from: now, minutes: GateEngine.emergencyMinutes, existing: store.unlockedUntil)
        store.unlockedUntil = until
        reloadGateState()
        #if STRICT_LOCK
        StrictLockStore.unlock(until: until)
        #endif
        ReminderService.shared.scheduleWindowEnd(at: until, minutes: GateEngine.emergencyMinutes, enabled: settings.windowEndNudge)
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
        #if STRICT_LOCK
        StrictLockStore.enforce()
        #endif
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
        if isSample { return options.isUITest ? 2 : 15 }
        if options.isUITest { return 3 }
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
            let end = GateEngine.unlock(from: now, minutes: settings.unlockWindowMinutes, existing: store.unlockedUntil)
            store.unlockedUntil = end
            until = end
            ReminderService.shared.scheduleWindowEnd(at: end, minutes: settings.unlockWindowMinutes, enabled: settings.windowEndNudge)
        case .dailyKey:
            let end = GateEngine.dailyKeyUntil(from: now, resetHour: settings.dailyKeyResetHour, calendar: .current)
            store.dailyKeyUntil = end
            until = end
        }
        reloadGateState()
        #if STRICT_LOCK
        if let until { StrictLockStore.unlock(until: until) }
        #endif
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
        let name = settings.displayName
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
    func openDemoRoute(_ route: String) {
        switch route {
        case "pray": startPrayer(source: .manual)
        case "gatepray": startPrayer(source: .gate, gatedAppID: "instagram")
        case "quick": startPrayer(style: .quick, source: .manual)
        case "someone": startPrayer(style: .forSomeone, source: .manual, personID: suggestedPerson()?.id)
        case "choose": startPrayer(style: .forSomeone, source: .manual)
        case "gate": showGateSetup = true
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

    // MARK: Reset

    func resetAllData() {
        try? context.delete(model: PrayerSession.self)
        try? context.delete(model: JournalEntry.self)
        try? context.delete(model: PrayerRequest.self)
        try? context.delete(model: Person.self)
        try? context.save()
        let codes = store.circleCodes
        Task { try? await circles.deleteMyData(codes: codes) }
        store.resetAll()
        settings = AppSettings()
        store.settings = settings
        ReminderService.shared.cancelAll()
        reloadGateState()
        refreshStreak()
        WidgetCenter.shared.reloadAllTimelines()
        selectedTab = .today
    }
}
