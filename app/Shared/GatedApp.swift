import Foundation

/// An app the Prayer Gate can stand in front of.
struct GatedApp: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    /// URL used to send the person back to the app after they pray, e.g. `instagram://`.
    var urlString: String
    /// Legacy (v1.0 letter tiles). Kept so saved apps still decode; the UI shows names only, never a fake logo.
    var colorHex: UInt32
    var secondaryHex: UInt32
    var isCustom: Bool

    /// nil when there's no known way to open the app: after the Amen we say "Now open <name>" instead.
    var openURL: URL? { urlString.isEmpty ? nil : URL(string: urlString) }

    /// The featured apps each have their own "Pray Before <app>" Shortcuts action; every other app uses Pray First.
    var hasPresetIntent: Bool { !isCustom && AppCatalog.featured.contains { $0.id == id } }

    /// An app added by name only ("Other app…"): no URL scheme.
    static func named(_ name: String) -> GatedApp { custom(name: name, scheme: "") }

    static func custom(name: String, scheme: String) -> GatedApp {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = GatedApp.normalizeScheme(scheme)
        let slug = cleanedName.lowercased().filter { $0.isLetter || $0.isNumber }
        let palette: [(UInt32, UInt32)] = [(0x7C6CF2, 0x4B3FC4), (0x2FB3A3, 0x1C7F74), (0xE07A5F, 0xB4513A), (0x5B8DEF, 0x3461C4)]
        let pick = palette[abs(slug.hashValue) % palette.count]
        return GatedApp(
            id: "custom-" + (slug.isEmpty ? UUID().uuidString.prefix(6).lowercased() : slug),
            name: cleanedName.isEmpty ? "My app" : cleanedName,
            urlString: normalized,
            colorHex: pick.0,
            secondaryHex: pick.1,
            isCustom: true
        )
    }

    /// Accepts "myapp", "myapp:" or "myapp://path" and returns a launchable "myapp://..." string.
    static func normalizeScheme(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "" }
        if let range = value.range(of: "://") {
            let scheme = value[..<range.lowerBound].lowercased()
            let rest = value[range.upperBound...]
            return scheme + "://" + rest
        }
        if value.hasSuffix(":") { value.removeLast() }
        value = value.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." || $0 == "+" }
        return value.isEmpty ? "" : value + "://"
    }

    static func isValidScheme(_ raw: String) -> Bool {
        let normalized = normalizeScheme(raw)
        guard let range = normalized.range(of: "://") else { return false }
        let scheme = normalized[..<range.lowerBound]
        guard let first = scheme.first, first.isLetter else { return false }
        let blocked: Set<String> = ["http", "https", "tel", "sms", "mailto", AppConstants.urlScheme]
        return !blocked.contains(String(scheme))
    }
}

enum AppCatalog {
    private static func entry(_ id: String, _ name: String, _ scheme: String) -> GatedApp {
        GatedApp(id: id, name: name, urlString: scheme, colorHex: 0xE9B949, secondaryHex: 0xB8862B, isCustom: false)
    }

    /// Everything the gate knows by name: the featured apps plus the "Add another" list.
    static let all: [GatedApp] = featured + more

    /// The apps shown first in the picker.
    static let featured: [GatedApp] = [
        GatedApp(id: "instagram", name: "Instagram", urlString: "instagram://", colorHex: 0x2FB3A3, secondaryHex: 0x1C7F74, isCustom: false),
        GatedApp(id: "tiktok", name: "TikTok", urlString: "snssdk1233://", colorHex: 0xE07A5F, secondaryHex: 0xB4513A, isCustom: false),
        GatedApp(id: "youtube", name: "YouTube", urlString: "youtube://", colorHex: 0x7C6CF2, secondaryHex: 0x4B3FC4, isCustom: false),
        GatedApp(id: "x", name: "X", urlString: "twitter://", colorHex: 0x2FB3A3, secondaryHex: 0x1C7F74, isCustom: false),
        GatedApp(id: "snapchat", name: "Snapchat", urlString: "snapchat://", colorHex: 0x5B8DEF, secondaryHex: 0x3461C4, isCustom: false),
        GatedApp(id: "facebook", name: "Facebook", urlString: "fb://", colorHex: 0xE07A5F, secondaryHex: 0xB4513A, isCustom: false),
        GatedApp(id: "reddit", name: "Reddit", urlString: "reddit://", colorHex: 0x2FB3A3, secondaryHex: 0x1C7F74, isCustom: false),
        GatedApp(id: "threads", name: "Threads", urlString: "barcelona://", colorHex: 0x5B8DEF, secondaryHex: 0x3461C4, isCustom: false),
        GatedApp(id: "pinterest", name: "Pinterest", urlString: "pinterest://", colorHex: 0x7C6CF2, secondaryHex: 0x4B3FC4, isCustom: false),
    ]

    /// "Add another": popular apps by name, each with the URL scheme that opens it (empty = none we could verify,
    /// so after the Amen the person opens it themselves). The real app is picked in Shortcuts; this list only lets
    /// us send them back to it. Sorted by name in the picker.
    static let more: [GatedApp] = [
        entry("discord", "Discord", "discord://"),
        entry("twitch", "Twitch", "twitch://"),
        entry("bereal", "BeReal", "bereal://"),
        entry("netflix", "Netflix", "nflx://"),
        entry("spotify", "Spotify", "spotify://"),
        entry("whatsapp", "WhatsApp", "whatsapp://"),
        entry("telegram", "Telegram", "tg://"),
        entry("roblox", "Roblox", "roblox://"),
        entry("hulu", "Hulu", "hulu://"),
        entry("disneyplus", "Disney+", "disneyplus://"),
        entry("primevideo", "Prime Video", "aiv://"),
        entry("linkedin", "LinkedIn", "linkedin://"),
        entry("tumblr", "Tumblr", "tumblr://"),
        entry("kick", "Kick", ""),
        entry("messenger", "Messenger", "fb-messenger://"),
        entry("tinder", "Tinder", "tinder://"),
        entry("hinge", "Hinge", ""),
        entry("bumble", "Bumble", "bumble://"),
        entry("amazon", "Amazon", "com.amazon.mobile.shopping://"),
        entry("temu", "Temu", ""),
        entry("shein", "SHEIN", ""),
        entry("ebay", "eBay", "ebay://"),
        entry("max", "Max", ""),
        entry("peacock", "Peacock", ""),
        entry("paramountplus", "Paramount+", ""),
        entry("youtubemusic", "YouTube Music", "youtubemusic://"),
        entry("clashofclans", "Clash of Clans", "clashofclans://"),
        entry("clashroyale", "Clash Royale", "clashroyale://"),
        entry("brawlstars", "Brawl Stars", "brawlstars://"),
        entry("minecraft", "Minecraft", "minecraft://"),
        entry("pokemongo", "Pokémon GO", ""),
        entry("candycrush", "Candy Crush Saga", ""),
        entry("subwaysurfers", "Subway Surfers", ""),
        entry("codmobile", "Call of Duty: Mobile", ""),
        entry("genshin", "Genshin Impact", ""),
        entry("monopolygo", "Monopoly GO!", ""),
        entry("royalmatch", "Royal Match", ""),
        entry("capcut", "CapCut", ""),
        entry("lemon8", "Lemon8", ""),
        entry("vsco", "VSCO", "vsco://"),
        entry("quora", "Quora", "quora://"),
        entry("signal", "Signal", "sgnl://"),
        entry("kindle", "Kindle", "kindle://"),
        entry("audible", "Audible", "audible://"),
        entry("soundcloud", "SoundCloud", "soundcloud://"),
        entry("pandora", "Pandora", "pandora://"),
        entry("crunchyroll", "Crunchyroll", ""),
        entry("bluesky", "Bluesky", "bluesky://"),
        entry("espn", "ESPN", "sportscenter://"),
        entry("chesscom", "Chess.com", ""),
        entry("tubi", "Tubi", ""),
        entry("duolingo", "Duolingo", "duolingo://"),
        entry("steam", "Steam", ""),
        entry("ninegag", "9GAG", ""),
        entry("imgur", "Imgur", "imgur://"),
        entry("nextdoor", "Nextdoor", ""),
    ]

    /// "Add another" search: case- and accent-insensitive, matching any word start ("prime" finds Prime Video).
    static func search(_ query: String, excluding ids: Set<String> = []) -> [GatedApp] {
        let pool = more.filter { !ids.contains($0.id) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let q = query.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        guard !q.isEmpty else { return pool }
        return pool.filter { app in
            let name = app.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            let squashed = name.filter { $0.isLetter || $0.isNumber }
            return name.hasPrefix(q) || name.contains(" " + q) || squashed.hasPrefix(q.filter { $0.isLetter || $0.isNumber })
        }
    }

    static func app(id: String, customApps: [GatedApp] = []) -> GatedApp? {
        let key = id.lowercased()
        if let match = all.first(where: { $0.id == key }) { return match }
        if let match = customApps.first(where: { $0.id == key }) { return match }
        // Accept common aliases coming from deep links or Shortcuts.
        switch key {
        case "twitter": return all.first { $0.id == "x" }
        case "fb": return all.first { $0.id == "facebook" }
        case "snap": return all.first { $0.id == "snapchat" }
        case "yt": return all.first { $0.id == "youtube" }
        default: return nil
        }
    }

    static func isKnown(id: String, customApps: [GatedApp]) -> Bool {
        app(id: id, customApps: customApps) != nil
    }
}
