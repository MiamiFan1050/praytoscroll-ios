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
    /// `-route <name>`: open a screen directly (demo only): pray, gatepray, quick, someone, choose, gate, answered, circle,
    /// stats, journal, word, settings, verified, troubleshoot (see AppModel.openDemoRoute).
    let route: String?
    /// `-appearance light|dark`
    let appearance: AppearancePreference?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    init(arguments: [String]) {
        isDemo = arguments.contains("-demo")
        showOnboarding = arguments.contains("-onboarding")
        isUITest = arguments.contains("-uitest")
        longMinimum = arguments.contains("-longMinimum")
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
    }
}
