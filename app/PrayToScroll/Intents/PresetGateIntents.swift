import AppIntents
import Foundation

// One parameterless intent per preset app, so the Shortcuts automation never needs the app picked twice
// (the step that breaks most Shortcuts gates). Generated from the catalog in Shared/GatedApp.swift.

struct PrayBeforeInstagramIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray Before Instagram"
    static let description = IntentDescription("Add this to a Shortcuts automation for when Instagram is opened. If you haven't prayed yet, you'll pray first; if you have, Instagram opens as normal.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: "instagram", intent: self)
        return .result()
    }
}

struct PrayBeforeTikTokIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray Before TikTok"
    static let description = IntentDescription("Add this to a Shortcuts automation for when TikTok is opened. If you haven't prayed yet, you'll pray first; if you have, TikTok opens as normal.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: "tiktok", intent: self)
        return .result()
    }
}

struct PrayBeforeYouTubeIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray Before YouTube"
    static let description = IntentDescription("Add this to a Shortcuts automation for when YouTube is opened. If you haven't prayed yet, you'll pray first; if you have, YouTube opens as normal.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: "youtube", intent: self)
        return .result()
    }
}

struct PrayBeforeXIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray Before X"
    static let description = IntentDescription("Add this to a Shortcuts automation for when X is opened. If you haven't prayed yet, you'll pray first; if you have, X opens as normal.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: "x", intent: self)
        return .result()
    }
}

struct PrayBeforeSnapchatIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray Before Snapchat"
    static let description = IntentDescription("Add this to a Shortcuts automation for when Snapchat is opened. If you haven't prayed yet, you'll pray first; if you have, Snapchat opens as normal.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: "snapchat", intent: self)
        return .result()
    }
}

struct PrayBeforeFacebookIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray Before Facebook"
    static let description = IntentDescription("Add this to a Shortcuts automation for when Facebook is opened. If you haven't prayed yet, you'll pray first; if you have, Facebook opens as normal.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: "facebook", intent: self)
        return .result()
    }
}

struct PrayBeforeRedditIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray Before Reddit"
    static let description = IntentDescription("Add this to a Shortcuts automation for when Reddit is opened. If you haven't prayed yet, you'll pray first; if you have, Reddit opens as normal.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: "reddit", intent: self)
        return .result()
    }
}

struct PrayBeforeThreadsIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray Before Threads"
    static let description = IntentDescription("Add this to a Shortcuts automation for when Threads is opened. If you haven't prayed yet, you'll pray first; if you have, Threads opens as normal.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: "threads", intent: self)
        return .result()
    }
}

struct PrayBeforePinterestIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Pray Before Pinterest"
    static let description = IntentDescription("Add this to a Shortcuts automation for when Pinterest is opened. If you haven't prayed yet, you'll pray first; if you have, Pinterest opens as normal.", categoryName: "Prayer Gate")
    static let openAppWhenRun: Bool = false
#if compiler(>=6.2)
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
#endif

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try await GateIntentRunner.run(appID: "pinterest", intent: self)
        return .result()
    }
}
