import AppIntents
import Foundation

/// Shared logic for every "Pray Before …" intent.
/// Unlocked (or within a launch pass / grace) → return silently, the app stays open.
/// Locked → continue in the foreground: PrayToScroll opens on the prayer screen.
/// "Test my gate" pending → PrayToScroll opens on "✓ Instagram is protected".
@MainActor
enum GateIntentRunner {
    static func run<I: AppIntent & ForegroundContinuableIntent>(appID: String, intent: I) async throws {
        let store = SharedStore.shared
        let key = GateEngine.canonicalID(appID, customApps: store.settings.customApps)
        let now = Date()
        store.recordGateFired(appID: key, at: now)
        let snapshot = store.gateSnapshot
        let decision = GateEngine.decide(appID: key, now: now, snapshot: snapshot)

        // The all-apps automation answers a test for whichever app is being tested.
        var target = key
        let verify: Bool
        switch decision {
        case .allow:
            return
        case .verifyTest:
            verify = true
            target = GateEngine.testedApp(key, now: now, snapshot: snapshot) ?? key
            store.clearTest(appID: target)
            if target != key { store.recordGateFired(appID: target, at: now) }
        case .requirePrayer:
            verify = false
        }
        let destination = target
        store.setPendingGate(appID: verify ? "verify:" + destination : destination, at: now)

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            do {
                try await intent.continueInForeground(alwaysConfirm: false)
                AppModel.shared.handleIntentContinuation(appID: destination, verify: verify)
                return
            } catch {
                // Fall through to the iOS 17–25 path below.
            }
        }
        #endif

        let appName = AppCatalog.app(id: destination, customApps: store.settings.customApps)?.name ?? "your apps"
        let dialog: IntentDialog = verify
            ? IntentDialog(stringLiteral: "\(appName) is protected. Tap to see it in \(AppConstants.appName).")
            : IntentDialog(stringLiteral: "Pray first, then \(appName). \(AppConstants.slogan)")
        throw intent.needsToContinueInForegroundError(dialog) {
            AppModel.shared.handleIntentContinuation(appID: destination, verify: verify)
        }
    }
}

/// The gate for every app: ONE Shortcuts automation (App → choose all your apps → Is Opened) with App left empty.
/// Setting App (or using a "Pray Before <app>" action) still works for one app per automation.
struct PrayFirstIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray First"
    static let description = IntentDescription("Use this in one Shortcuts automation for all your gated apps. Leave App empty, or pick one app.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    @Parameter(title: "App")
    var app: GatedAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Pray before opening \(\.$app)")
    }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: app?.id ?? GateEngine.anyAppID, intent: self)
        return .result()
    }
}

/// Opens PrayToScroll straight into a prayer.
struct PrayNowIntent: AppIntent {
    static let title: LocalizedStringResource = "Pray Now"
    static let description = IntentDescription("Start a prayer right away.", categoryName: "Prayer")
    static let openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.startPrayer(source: .manual)
        return .result()
    }
}

/// "Tempted? Pray now": a short prayer from the tempted pool, no gate needed.
struct TemptedPrayerIntent: AppIntent {
    static let title: LocalizedStringResource = "Tempted? Pray Now"
    static let description = IntentDescription("Open a one-minute prayer for a moment of temptation.", categoryName: "Prayer")
    static let openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.startPrayer(style: .quick, source: .manual, mood: .tempted)
        return .result()
    }
}

struct GatedAppEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "App"
    static let defaultQuery = GatedAppQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(app: GatedApp) {
        id = app.id
        name = app.name
    }
}

struct GatedAppQuery: EntityQuery {
    init() {}

    private func all() -> [GatedApp] {
        let custom = SharedStore.shared.settings.customApps
        return AppCatalog.all.filter { app in !custom.contains { $0.id == app.id } } + custom
    }

    func entities(for identifiers: [String]) async throws -> [GatedAppEntity] {
        let apps = all()
        return identifiers.compactMap { id in apps.first { $0.id == id }.map(GatedAppEntity.init(app:)) }
    }

    func suggestedEntities() async throws -> [GatedAppEntity] {
        let settings = SharedStore.shared.settings
        let gated = settings.gatedApps
        let rest = all().filter { app in !gated.contains(where: { $0.id == app.id }) }
        return (gated + rest).map(GatedAppEntity.init(app:))
    }
}

struct PrayToScrollShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PrayNowIntent(),
                    phrases: ["Pray now with \(.applicationName)", "Start a prayer in \(.applicationName)", "Open \(.applicationName) prayer"],
                    shortTitle: "Pray Now",
                    systemImageName: "hands.and.sparkles.fill")
        AppShortcut(intent: TemptedPrayerIntent(),
                    phrases: ["I'm tempted, \(.applicationName)", "Tempted prayer in \(.applicationName)"],
                    shortTitle: "Tempted? Pray",
                    systemImageName: "shield.lefthalf.filled")
        AppShortcut(intent: PrayFirstIntent(),
                    phrases: ["Pray first with \(.applicationName)"],
                    shortTitle: "Pray First",
                    systemImageName: "scroll.fill")
    }
}
