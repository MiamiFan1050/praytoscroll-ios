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
    /// stats, journal, word, settings, verified, troubleshoot (see AppModel.openDemoRoute).
    let route: String?
    /// `-appearance light|dark`
    let appearance: AppearancePreference?
    /// `-noPeople` with `-demo`: an empty prayer list (a new user adding their first person).
    let noPeople: Bool
    /// `-contacts denied|limited|full` with `-demo`: the demo address book's permission (default: not asked yet).
    let contactsStatus: ContactsAccess?

    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    /// Debug builds only (UI tests + screenshots). A Release build never reads launch arguments.
    init(arguments: [String]) {
        #if DEBUG
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
        noPeople = arguments.contains("-noPeople")
        if let index = arguments.firstIndex(of: "-contacts"), arguments.indices.contains(index + 1) {
            switch arguments[index + 1] {
            case "denied": contactsStatus = .denied
            case "limited": contactsStatus = .limited
            case "full": contactsStatus = .full
            default: contactsStatus = nil
            }
        } else {
            contactsStatus = nil
        }
        #else
        isDemo = false
        showOnboarding = false
        isUITest = false
        longMinimum = false
        route = nil
        appearance = nil
        noPeople = false
        contactsStatus = nil
        #endif
    }
}
