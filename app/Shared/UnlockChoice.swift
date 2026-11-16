import Foundation

/// How long an Amen unlocks your apps. Every end is an absolute instant, so windows cross midnight and daylight
/// saving correctly, and a relock (the window-end check, or Screen Time's timer in v1.1) fires at exactly that time.
enum UnlockChoice: Hashable, Sendable, Identifiable {
    /// A preset: 5 (Shortcuts mode only), 15, 30, 45 min, 1, 2 or 3 h.
    case minutes(Int)
    /// 15 min to 8 h in 5-minute steps; never runs past the next reset hour.
    case custom(Int)
    /// Until the reset hour (the old "Daily key").
    case restOfToday

    static let presetMinutes = [5, 15, 30, 45, 60, 120, 180]
    static let customRange = 15...480
    static let customStep = 5
    static let defaultCustomMinutes = 90

    var id: String {
        switch self {
        case .minutes(let m): return "m\(m)"
        case .custom(let m): return "c\(m)"
        case .restOfToday: return "rest"
        }
    }

    /// The preset choices, shortest first, from the shortest window allowed (5 under Shortcuts, 15 under Screen
    /// Time), then Rest of today. Custom is offered separately.
    static func presets(minimumMinutes: Int) -> [UnlockChoice] {
        presetMinutes.filter { $0 >= minimumMinutes }.map(UnlockChoice.minutes) + [.restOfToday]
    }

    var minutes: Int? {
        switch self {
        case .minutes(let m), .custom(let m): return m
        case .restOfToday: return nil
        }
    }

    var isCustom: Bool { if case .custom = self { return true } else { return false } }

    /// "15 min", "1 h", "Rest of today", "1 h 30 min".
    var title: String {
        switch self {
        case .minutes(let m), .custom(let m): return Self.label(minutes: m)
        case .restOfToday: return "Rest of today"
        }
    }

    /// "15 min", "45 min", "1 h", "2 h 05 min" → "2 h 5 min".
    static func label(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    /// For sentences and VoiceOver: "15 minutes", "1 hour", "1 hour 30 minutes".
    static func spoken(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        let hours = h == 1 ? "1 hour" : "\(h) hours"
        let mins = m == 1 ? "1 minute" : "\(m) minutes"
        if h == 0 { return mins }
        return m == 0 ? hours : "\(hours) \(mins)"
    }

    static func clampCustom(_ minutes: Int) -> Int {
        let stepped = Int((Double(minutes) / Double(customStep)).rounded()) * customStep
        return min(customRange.upperBound, max(customRange.lowerBound, stepped))
    }

    /// The choice saved in settings. Users on the old Daily key get Rest of today; a fixed window stays as it was.
    static func current(in settings: AppSettings) -> UnlockChoice {
        if settings.unlockMode == .dailyKey { return .restOfToday }
        if settings.unlockCustom { return .custom(clampCustom(settings.unlockWindowMinutes)) }
        return .minutes(max(1, settings.unlockWindowMinutes))
    }

    func apply(to settings: inout AppSettings) {
        switch self {
        case .minutes(let m):
            settings.unlockMode = .window
            settings.unlockCustom = false
            settings.unlockWindowMinutes = m
        case .custom(let m):
            settings.unlockMode = .window
            settings.unlockCustom = true
            settings.unlockWindowMinutes = Self.clampCustom(m)
        case .restOfToday:
            settings.unlockMode = .dailyKey
            settings.unlockCustom = false
        }
    }

    /// When an Amen at `now` unlocks until. Rest of today ends at the reset hour; Custom stops there too.
    func end(from now: Date, resetHour: Int, calendar: Calendar) -> Date {
        let reset = GateEngine.dailyKeyUntil(from: now, resetHour: resetHour, calendar: calendar)
        switch self {
        case .minutes(let m):
            return now.addingTimeInterval(TimeInterval(max(1, m)) * 60)
        case .custom(let m):
            return min(now.addingTimeInterval(TimeInterval(Self.clampCustom(m)) * 60), reset)
        case .restOfToday:
            return reset
        }
    }
}
