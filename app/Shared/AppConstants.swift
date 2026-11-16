import Foundation

/// Identifiers shared by the app, the widget, the App Intents and (v1.1) the Strict Lock extensions.
enum AppConstants {
    /// The display name, set ONCE in project.yml (`APP_DISPLAY_NAME`) and read from Info.plist.
    /// Every user-facing mention of the app's name uses this, so a rename is a one-line change.
    static var appName: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return (name?.isEmpty == false ? name : nil) ?? "Pray to Scroll"
    }
    static let appGroup = "group.com.amenkeyapp.ios"
    static let cloudKitContainer = "iCloud.com.amenkeyapp.ios"
    static let urlScheme = "prayscroll"
    /// Older scheme kept registered so early links (and the site's join page) still open the app.
    static let legacyURLSchemes = ["amenkey"]
    static let slogan = "Knees before feeds."
    static let bundleID = "com.amenkeyapp.ios"
    static let widgetKindStreak = "PrayToScrollStreakWidget"
    static let widgetKindVerse = "PrayToScrollVerseWidget"
    static let widgetKindPrayNow = "PrayToScrollPrayNowWidget"

    /// Demo data lives in its own defaults domain so screenshots never touch a real user's data.
    static let demoSuite = "com.amenkeyapp.ios.demo"

    /// Average length of one scroll session, used for the "time reclaimed" estimate.
    static let averageScrollSessionMinutes = 7.0
}

/// Public web + store links. The web base can be changed in Info.plist (`AKWebBase`) without code changes.
enum AppLinks {
    static var webBase: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "AKWebBase") as? String
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "https://praytoscroll.vercel.app" : trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static var appStoreID: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "AKAppStoreID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// The link people get in "I just prayed for you" messages and share cards.
    static var shareURL: URL {
        if let id = appStoreID, let url = URL(string: "https://apps.apple.com/app/id\(id)") { return url }
        return URL(string: webBase) ?? URL(string: "https://praytoscroll.vercel.app")!
    }

    static var reviewURL: URL? {
        guard let id = appStoreID else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }

    static var privacyURL: URL { URL(string: webBase + "/privacy")! }
    static var termsURL: URL { URL(string: webBase + "/terms")! }
    static var supportURL: URL { URL(string: webBase + "/support")! }

    static func joinWebURL(code: String) -> URL {
        URL(string: webBase + "/join?c=\(code)")!
    }

    static func joinDeepLink(code: String) -> URL {
        URL(string: "\(AppConstants.urlScheme)://join?c=\(code)")!
    }

    static let prayDeepLink = URL(string: "\(AppConstants.urlScheme)://pray")!
    static let statsDeepLink = URL(string: "\(AppConstants.urlScheme)://stats")!

    static func prayDeepLink(app: String) -> URL {
        URL(string: "\(AppConstants.urlScheme)://pray?app=\(app)")!
    }
}
