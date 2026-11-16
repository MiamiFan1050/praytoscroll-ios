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
        let decision = GateEngine.decide(appID: key, now: now, snapshot: store.gateSnapshot)

        let verify: Bool
        switch decision {
        case .allow:
            return
        case .verifyTest:
            verify = true
            store.clearTest(appID: key)
        case .requirePrayer:
            verify = false
        }

        store.setPendingGate(appID: verify ? "verify:" + key : key, at: now)

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            do {
                try await intent.continueInForeground(alwaysConfirm: false)
                AppModel.shared.handleIntentContinuation(appID: key, verify: verify)
                return
            } catch {
                // Fall through to the iOS 17–25 path below.
            }
        }
        #endif

        let appName = AppCatalog.app(id: key, customApps: store.settings.customApps)?.name ?? "your app"
        let dialog: IntentDialog = verify
            ? IntentDialog(stringLiteral: "\(appName) is protected. Tap to see it in \(AppConstants.appName).")
            : IntentDialog(stringLiteral: "Pray first, then \(appName). \(AppConstants.slogan)")
        throw intent.needsToContinueInForegroundError(dialog) {
            AppModel.shared.handleIntentContinuation(appID: key, verify: verify)
        }
    }
}

/// Gate for any app, including custom URL-scheme apps. Preset apps have their own parameterless intents.
struct PrayFirstIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray First (Any App)"
    static let description = IntentDescription("Use this in a Shortcuts automation for any app you added, including custom apps. Pick the same app in the App field.", categoryName: "Prayer Gate")
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
        try await GateIntentRunner.run(appID: app?.id ?? "app", intent: self)
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
        AppCatalog.all + SharedStore.shared.settings.customApps
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
                    systemImageName: "key.fill")
    }
}
