import Foundation

/// App-group backed storage shared by the app, the App Intent, the widget and the v1.1 extensions.
/// Only small values live here; people, journal and sessions live in SwiftData inside the app.
final class SharedStore: @unchecked Sendable {
    static let shared = SharedStore(defaults: SharedStore.makeDefaults())

    let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The real store uses the app group. A `-demo` launch uses its own domain, wiped on every launch.
    static func makeDefaults() -> UserDefaults {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            let demo = UserDefaults(suiteName: AppConstants.demoSuite) ?? .standard
            return demo
        }
        #endif
        return UserDefaults(suiteName: AppConstants.appGroup) ?? .standard
    }

    private enum Key {
        static let settings = "ak.settings.v1"
        static let unlockedUntil = "ak.gate.unlockedUntil"
        static let pausedUntil = "ak.gate.pausedUntil"
        static let emergencyLastUsed = "ak.gate.emergencyLastUsed"
        static let gateFired = "ak.gate.firedByApp"
        static let pendingGateApp = "ak.gate.pendingApp"
        static let pendingGateAt = "ak.gate.pendingAt"
        static let gateTriggers = "ak.stats.gateTriggers"
        static let emergencyUses = "ak.stats.emergencyUses"
        static let prayedDays = "ak.streak.prayedDays"
        static let frozenDays = "ak.streak.frozenDays"
        static let lastPrayerAt = "ak.streak.lastPrayerAt"
        static let circleCodes = "ak.circles.codes"
        static let circleMemberID = "ak.circles.memberID"
        static let dailyKeyUntil = "ak.gate.dailyKeyUntil"
        static let launchPasses = "ak.gate.launchPasses"
        static let testPending = "ak.gate.testPending"
        static let setupMarked = "ak.gate.setupMarked"
        static let promptBags = "ak.prompts.bags"
        static let screenTimeActive = "ak.strict.active"
        static let relockScheduledFor = "ak.strict.relockAt"
        static let screenTimeOfferDismissed = "ak.strict.offerDismissed"
    }

    // MARK: Settings

    var settings: AppSettings {
        get {
            guard let data = defaults.data(forKey: Key.settings),
                  let value = try? decoder.decode(AppSettings.self, from: data) else { return AppSettings() }
            return value
        }
        set {
            if let data = try? encoder.encode(newValue) { defaults.set(data, forKey: Key.settings) }
        }
    }

    // MARK: Gate

    var unlockedUntil: Date? {
        get { date(Key.unlockedUntil) }
        set { setDate(newValue, Key.unlockedUntil) }
    }

    var pausedUntil: Date? {
        get { date(Key.pausedUntil) }
        set { setDate(newValue, Key.pausedUntil) }
    }

    var emergencyLastUsed: Date? {
        get { date(Key.emergencyLastUsed) }
        set { setDate(newValue, Key.emergencyLastUsed) }
    }

    var dailyKeyUntil: Date? {
        get { date(Key.dailyKeyUntil) }
        set { setDate(newValue, Key.dailyKeyUntil) }
    }

    var gateSnapshot: GateSnapshot {
        let s = settings
        return GateSnapshot(gateEnabled: s.gateEnabled, gatedAppIDs: Set(s.gatedAppIDs), customApps: s.customApps,
                            unlockedUntil: unlockedUntil, pausedUntil: pausedUntil, dailyKeyUntil: dailyKeyUntil,
                            launchPasses: launchPasses, testPending: testPending, screenTimeActive: screenTimeActive)
    }

    // MARK: Screen Time (Strict Lock)

    /// True while Screen Time shields are in charge (set by the app after every lock sync).
    var screenTimeActive: Bool {
        get { defaults.bool(forKey: Key.screenTimeActive) }
        set { defaults.set(newValue, forKey: Key.screenTimeActive) }
    }

    /// The window end the running DeviceActivity relock timer was started for.
    var relockScheduledFor: Date? {
        get { date(Key.relockScheduledFor) }
        set { setDate(newValue, Key.relockScheduledFor) }
    }

    /// A v1.0 Shortcuts user closed the "lock with Screen Time" card on Home.
    var screenTimeOfferDismissed: Bool {
        get { defaults.bool(forKey: Key.screenTimeOfferDismissed) }
        set { defaults.set(newValue, forKey: Key.screenTimeOfferDismissed) }
    }

    /// Short per-app passes so PrayToScroll reopening an app never re-triggers the gate.
    var launchPasses: [String: Date] {
        get { dateMap(Key.launchPasses) }
        set { setDateMap(newValue, Key.launchPasses) }
    }

    func grantLaunchPass(appID: String, now: Date = Date()) {
        var passes = launchPasses.filter { $0.value > now }
        passes[canonical(appID)] = now.addingTimeInterval(GateEngine.launchPassSeconds)
        launchPasses = passes
    }

    /// "Test my gate" requests by app id.
    var testPending: [String: Date] {
        get { dateMap(Key.testPending) }
        set { setDateMap(newValue, Key.testPending) }
    }

    func startTest(appID: String, now: Date = Date()) {
        var tests = testPending
        tests[canonical(appID)] = now
        testPending = tests
    }

    func clearTest(appID: String) {
        var tests = testPending
        tests.removeValue(forKey: canonical(appID))
        testPending = tests
    }

    /// When the person said "I've added the automation" for an app (before it ever fired).
    var setupMarked: [String: Date] {
        get { dateMap(Key.setupMarked) }
        set { setDateMap(newValue, Key.setupMarked) }
    }

    /// Last time the "Pray First" automation fired per app id: proof that the Shortcuts automation is set up.
    var gateFiredDates: [String: Date] {
        get {
            let raw = defaults.dictionary(forKey: Key.gateFired) as? [String: Double] ?? [:]
            return raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
        set {
            defaults.set(newValue.mapValues { $0.timeIntervalSince1970 }, forKey: Key.gateFired)
        }
    }

    func recordGateFired(appID: String, at date: Date = Date()) {
        var fired = gateFiredDates
        fired[canonical(appID)] = date
        gateFiredDates = fired
        gateTriggers += 1
    }

    var gateTriggers: Int {
        get { defaults.integer(forKey: Key.gateTriggers) }
        set { defaults.set(newValue, forKey: Key.gateTriggers) }
    }

    var emergencyUses: Int {
        get { defaults.integer(forKey: Key.emergencyUses) }
        set { defaults.set(newValue, forKey: Key.emergencyUses) }
    }

    /// Set by the intent when a prayer is needed; read by the app when it comes to the foreground.
    func setPendingGate(appID: String, at date: Date = Date()) {
        defaults.set(appID, forKey: Key.pendingGateApp)
        setDate(date, Key.pendingGateAt)
    }

    /// Returns the pending gate app id if it is fresh (under 2 minutes old) and clears it.
    func consumePendingGate(now: Date = Date()) -> String? {
        defer {
            defaults.removeObject(forKey: Key.pendingGateApp)
            defaults.removeObject(forKey: Key.pendingGateAt)
        }
        guard let app = defaults.string(forKey: Key.pendingGateApp), let at = date(Key.pendingGateAt) else { return nil }
        return now.timeIntervalSince(at) < 120 ? app : nil
    }

    // MARK: Streak

    var prayedDays: Set<DayKey> {
        get { Set((defaults.stringArray(forKey: Key.prayedDays) ?? []).compactMap(DayKey.init(string:))) }
        set { defaults.set(newValue.sorted().map(\.string), forKey: Key.prayedDays) }
    }

    var frozenDays: Set<DayKey> {
        get { Set((defaults.stringArray(forKey: Key.frozenDays) ?? []).compactMap(DayKey.init(string:))) }
        set { defaults.set(newValue.sorted().map(\.string), forKey: Key.frozenDays) }
    }

    var lastPrayerAt: Date? {
        get { date(Key.lastPrayerAt) }
        set { setDate(newValue, Key.lastPrayerAt) }
    }

    func streakSummary(now: Date = Date(), calendar: Calendar = .current) -> StreakSummary {
        let today = DayKey(now, calendar: calendar)
        let prayed = prayedDays
        let frozen = StreakEngine.reconcileFreezes(prayed: prayed, frozen: frozenDays, today: today, calendar: calendar)
        return StreakEngine.summary(prayed: prayed, frozen: frozen, today: today, calendar: calendar)
    }

    // MARK: Circles

    var circleCodes: [String] {
        get { defaults.stringArray(forKey: Key.circleCodes) ?? [] }
        set { defaults.set(newValue, forKey: Key.circleCodes) }
    }

    /// A random, anonymous id used as this person's member id in circles (never their Apple ID).
    var circleMemberID: String {
        if let existing = defaults.string(forKey: Key.circleMemberID) { return existing }
        let id = UUID().uuidString.lowercased()
        defaults.set(id, forKey: Key.circleMemberID)
        return id
    }

    // MARK: Reset

    /// Erases every "ak." key. `keepingCircleMemberID` holds the circle id back until its rows are deleted.
    func resetAll(keepingCircleMemberID: Bool = false) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("ak.") {
            if keepingCircleMemberID, key == Key.circleMemberID { continue }
            defaults.removeObject(forKey: key)
        }
    }

    func forgetCircleMemberID() {
        defaults.removeObject(forKey: Key.circleMemberID)
    }

    // MARK: Prompt bags

    /// Persisted shuffle bags (remaining indices per prompt key) so prompts never repeat until a pool is used up.
    var promptBags: [String: [Int]] {
        get { defaults.dictionary(forKey: Key.promptBags) as? [String: [Int]] ?? [:] }
        set { defaults.set(newValue, forKey: Key.promptBags) }
    }

    // MARK: Helpers

    /// Catalog id for an app id or alias ("Twitter" → "x"), so passes, tests and setup proof line up with the gate.
    private func canonical(_ appID: String) -> String {
        GateEngine.canonicalID(appID, customApps: settings.customApps)
    }

    private func dateMap(_ key: String) -> [String: Date] {
        let raw = defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    private func setDateMap(_ map: [String: Date], _ key: String) {
        defaults.set(map.mapValues { $0.timeIntervalSince1970 }, forKey: key)
    }

    private func date(_ key: String) -> Date? {
        let value = defaults.double(forKey: key)
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    private func setDate(_ date: Date?, _ key: String) {
        if let date { defaults.set(date.timeIntervalSince1970, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}
