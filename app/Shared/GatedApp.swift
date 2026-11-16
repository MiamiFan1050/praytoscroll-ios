import Foundation

/// An app the Prayer Gate can stand in front of.
struct GatedApp: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    /// URL used to send the person back to the app after they pray, e.g. `instagram://`.
    var urlString: String
    /// Tile color (hex RGB) used for the app's monogram tile. No third-party logos are drawn.
    var colorHex: UInt32
    var secondaryHex: UInt32
    var isCustom: Bool

    var openURL: URL? { URL(string: urlString) }

    var monogram: String {
        switch id {
        case "x": return "X"
        case "youtube": return "▶"
        default: return String(name.prefix(1)).uppercased()
        }
    }

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
    static let all: [GatedApp] = [
        GatedApp(id: "instagram", name: "Instagram", urlString: "instagram://", colorHex: 0xE1306C, secondaryHex: 0xF77737, isCustom: false),
        GatedApp(id: "tiktok", name: "TikTok", urlString: "snssdk1233://", colorHex: 0x25F4EE, secondaryHex: 0xFE2C55, isCustom: false),
        GatedApp(id: "youtube", name: "YouTube", urlString: "youtube://", colorHex: 0xFF3B30, secondaryHex: 0xC4161C, isCustom: false),
        GatedApp(id: "x", name: "X", urlString: "twitter://", colorHex: 0x2B2B2B, secondaryHex: 0x000000, isCustom: false),
        GatedApp(id: "snapchat", name: "Snapchat", urlString: "snapchat://", colorHex: 0xFFE14D, secondaryHex: 0xF5C400, isCustom: false),
        GatedApp(id: "facebook", name: "Facebook", urlString: "fb://", colorHex: 0x3B82F6, secondaryHex: 0x1D4ED8, isCustom: false),
        GatedApp(id: "reddit", name: "Reddit", urlString: "reddit://", colorHex: 0xFF5722, secondaryHex: 0xD9400F, isCustom: false),
        GatedApp(id: "threads", name: "Threads", urlString: "barcelona://", colorHex: 0x3A3A3C, secondaryHex: 0x111111, isCustom: false),
        GatedApp(id: "pinterest", name: "Pinterest", urlString: "pinterest://", colorHex: 0xE60023, secondaryHex: 0xAD081B, isCustom: false),
    ]

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
