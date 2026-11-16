import Foundation

/// Launch arguments. `-demo` seeds a lively, isolated demo (used by UI tests and screenshots).
struct LaunchOptions: Sendable {
    let isDemo: Bool
    /// `-onboarding` with `-demo`: start at onboarding instead of home.
    let showOnboarding: Bool
    /// `-uitest`: shorter prayer minimums and no animations that would slow tests.
    let isUITest: Bool
    /// `-longMinimum` with `-uitest`: keep the real-length minimum, for tests that check Amen starts locked.
    let longMinimum: Bool
    /// `-route <name>`: open a screen directly (demo only): pray, gatepray, gateany, gateask, quick, someone, choose, gate, answered, circle,
    /// stats, journal, word, settings, verified, troubleshoot, lock (see AppModel.openDemoRoute).
    let route: String?
    /// `-appearance light|dark`
    let appearance: AppearancePreference?
    /// `-shortcutsGate` with `-demo`: the v1.0 Shortcuts gate instead of the (demo) Screen Time lock.
    let shortcutsGate: Bool
    /// `-today yyyy-MM-dd` (Debug UI tests only): the date seasonal content (Advent) uses. Release ignores it.
    let today: Date?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    /// Debug builds only (UI tests + screenshots). A Release build never reads launch arguments.
    init(arguments: [String]) {
        #if DEBUG
        isDemo = arguments.contains("-demo")
        showOnboarding = arguments.contains("-onboarding")
        isUITest = arguments.contains("-uitest")
        longMinimum = arguments.contains("-longMinimum")
        shortcutsGate = arguments.contains("-shortcutsGate")
        if let index = arguments.firstIndex(of: "-today"), arguments.indices.contains(index + 1) {
            let parser = DateFormatter()
            parser.locale = Locale(identifier: "en_US_POSIX")
            parser.dateFormat = "yyyy-MM-dd HH:mm"
            today = parser.date(from: arguments[index + 1] + " 12:00")
        } else {
            today = nil
        }
        if let index = arguments.firstIndex(of: "-route"), arguments.indices.contains(index + 1) {
            route = arguments[index + 1]
        } else {
            route = nil
        }
        if let index = arguments.firstIndex(of: "-appearance"), arguments.indices.contains(index + 1) {
            appearance = AppearancePreference(rawValue: arguments[index + 1])
        } else {
            appearance = nil
        }
        #else
        isDemo = false
        showOnboarding = false
        isUITest = false
        longMinimum = false
        shortcutsGate = false
        today = nil
        route = nil
        appearance = nil
        #endif
    }
}
