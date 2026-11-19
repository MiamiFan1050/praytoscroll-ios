import Foundation

/// Every URL PrayToScroll understands.
enum DeepLink: Equatable {
    case pray(appID: String?, mood: PrayerMood?)
    case join(code: String)
    /// A friend's profile link: prayscroll://u/<name> or https://<domain>/u/<name>.
    case user(handle: String)
    case challenge(id: String)
    case stats
    case people
    case journal
    case word
    /// prayscroll://night: Night prayer (the bedtime reminder opens it).
    case nightPrayer

    /// prayscroll://pray, prayscroll://pray?app=instagram, prayscroll://join?c=CODE, prayscroll://challenge/<id>
    /// (the legacy amenkey:// scheme works too)
    /// and the web form https://<domain>/join?c=CODE.
    init?(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems ?? []
        func value(_ name: String) -> String? {
            query.first { $0.name.lowercased() == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let scheme = url.scheme?.lowercased() ?? ""
        var parts: [String]
        if scheme == AppConstants.urlScheme || AppConstants.legacyURLSchemes.contains(scheme) {
            parts = [url.host ?? ""] + url.pathComponents.filter { $0 != "/" }
        } else if scheme == "https" || scheme == "http" {
            parts = url.pathComponents.filter { $0 != "/" }
        } else {
            return nil
        }
        parts = parts.map { $0.lowercased() }.filter { !$0.isEmpty }
        guard let head = parts.first else { return nil }

        switch head {
        case "pray", "prayer", "gate", "tempted":
            let app = value("app").flatMap { $0.isEmpty ? nil : $0.lowercased() }
            let mood = value("mood").flatMap { PrayerMood(rawValue: $0.lowercased()) } ?? (head == "tempted" ? .tempted : nil)
            self = .pray(appID: app, mood: mood)
        case "join":
            guard let raw = value("c") ?? value("code") ?? parts.dropFirst().first,
                  let code = CircleCode.normalize(raw) else { return nil }
            self = .join(code: code)
        case "u", "user", "friend":
            guard let raw = parts.dropFirst().first ?? value("n") ?? value("u") else { return nil }
            let handle = UsernameRules.normalize(raw)
            guard UsernameRules.problem(with: handle) == nil || UsernameRules.problem(with: handle) == .reserved else { return nil }
            self = .user(handle: handle)
        case "challenge", "challenges":
            guard let id = parts.dropFirst().first ?? value("id") else { return nil }
            self = .challenge(id: id)
        case "stats", "streak", "progress":
            self = .stats
        case "people", "list":
            self = .people
        case "journal":
            self = .journal
        case "word", "scroll", "verses", "feed":
            self = .word
        case "night", "examen", "nightprayer":
            self = .nightPrayer
        default:
            return nil
        }
    }
}
