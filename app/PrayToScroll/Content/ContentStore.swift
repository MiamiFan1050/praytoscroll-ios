import Foundation

/// ACTS + quick + intercession prompts from prompts.json.
struct PromptLibrary: Decodable, Sendable {
    var adoration: [String]
    var confession: [String]
    var thanksgiving: [String]
    var supplication: [String]
    var quick: [String]
    var forSomeone: [String]
    /// "Pray about…" topics (family, healing, work…), ≥40 each so they don't repeat.
    var topics: [String: [String]] = [:]

    enum CodingKeys: String, CodingKey {
        case adoration, confession, thanksgiving, supplication, quick, forSomeone, topics
        case forSomeoneSnake = "for_someone"
    }

    init(adoration: [String], confession: [String], thanksgiving: [String], supplication: [String], quick: [String],
         forSomeone: [String], topics: [String: [String]] = [:]) {
        self.adoration = adoration
        self.confession = confession
        self.thanksgiving = thanksgiving
        self.supplication = supplication
        self.quick = quick
        self.forSomeone = forSomeone
        self.topics = topics
    }

    /// A topic's prompts (falls back to the quick prompts if the file has none for it).
    func prompts(for topic: PrayerTopic) -> [String] {
        let list = topics[topic.rawValue] ?? []
        return list.isEmpty ? quick : list
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let f = PromptLibrary.fallback
        adoration = PromptLibrary.nonEmpty(try c.decodeIfPresent([String].self, forKey: .adoration), f.adoration)
        confession = PromptLibrary.nonEmpty(try c.decodeIfPresent([String].self, forKey: .confession), f.confession)
        thanksgiving = PromptLibrary.nonEmpty(try c.decodeIfPresent([String].self, forKey: .thanksgiving), f.thanksgiving)
        supplication = PromptLibrary.nonEmpty(try c.decodeIfPresent([String].self, forKey: .supplication), f.supplication)
        quick = PromptLibrary.nonEmpty(try c.decodeIfPresent([String].self, forKey: .quick), f.quick)
        let someone = try c.decodeIfPresent([String].self, forKey: .forSomeone) ?? c.decodeIfPresent([String].self, forKey: .forSomeoneSnake)
        forSomeone = PromptLibrary.nonEmpty(someone, f.forSomeone)
        let rawTopics = (try? c.decodeIfPresent([String: [String]].self, forKey: .topics)) ?? [:]
        topics = rawTopics.mapValues { PromptLibrary.nonEmpty($0, []) }.filter { !$0.value.isEmpty }
    }

    private static func nonEmpty(_ list: [String]?, _ fallback: [String]) -> [String] {
        let cleaned = (list ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return cleaned.isEmpty ? fallback : cleaned
    }

    func prompts(for step: ACTSStep) -> [String] {
        switch step {
        case .adoration: return adoration
        case .confession: return confession
        case .thanksgiving: return thanksgiving
        case .supplication: return supplication
        }
    }

    static let fallback = PromptLibrary(
        adoration: ["Tell God one thing you love about who He is.",
                    "Think of something beautiful you saw this week. Thank its Maker for it.",
                    "Say slowly: You are good, and You are here."],
        confession: ["Is there anything you'd rather not look at today? Bring it into the light.",
                     "Name one moment you wish you could redo. Receive mercy for it.",
                     "Let go of one thing you've been carrying alone."],
        thanksgiving: ["Name three small gifts from the last 24 hours.",
                       "Who made your life easier this week? Thank God for them by name.",
                       "Thank Him for something you usually take for granted."],
        supplication: ["Ask God for what {name} needs most today.",
                       "Ask for help with the thing that's been on your mind all day.",
                       "Pray for the next hour: your words, your focus, your heart."],
        quick: ["Take a breath. Give God the next ten minutes.",
                "Before you scroll: what do you actually need right now? Ask Him.",
                "Thank God for one thing, then ask for one thing."],
        forSomeone: ["Ask God to meet {name} right where they are today.",
                     "Pray for {name}'s heart: peace where there's worry, hope where there's tiredness.",
                     "Ask for one specific good thing for {name} this week."]
    )
}

/// "Pray about…": what's on your heart, each with its own no-repeat prompt bag.
enum PrayerTopic: String, CaseIterable, Identifiable, Codable, Sendable {
    case family, friends, healing, anxiety, work, gratitude, forgiveness, guidance, morning, night
    var id: String { rawValue }
    var title: String { self == .work ? "Work & school" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .family: return "house.fill"
        case .friends: return "person.2.fill"
        case .healing: return "cross.case.fill"
        case .anxiety: return "wind"
        case .work: return "briefcase.fill"
        case .gratitude: return "gift.fill"
        case .forgiveness: return "arrow.uturn.backward.circle.fill"
        case .guidance: return "signpost.right.fill"
        case .morning: return "sunrise.fill"
        case .night: return "moon.stars.fill"
        }
    }
    var poolKey: String { "topic.\(rawValue)" }

    /// Morning before 11, night from 8 PM: quick prayers then sometimes draw from these.
    static func timeOfDay(hour: Int) -> PrayerTopic? {
        if (4..<11).contains(hour) { return .morning }
        if hour >= 20 || hour < 4 { return .night }
        return nil
    }
}

enum ACTSStep: String, CaseIterable, Identifiable, Sendable {
    case adoration, confession, thanksgiving, supplication
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var letter: String { String(rawValue.prefix(1)).uppercased() }
    var symbol: String {
        switch self {
        case .adoration: return "sun.max.fill"
        case .confession: return "drop.fill"
        case .thanksgiving: return "gift.fill"
        case .supplication: return "hands.and.sparkles.fill"
        }
    }
    var caption: String {
        switch self {
        case .adoration: return "Praise God for who He is"
        case .confession: return "Bring it into the light"
        case .thanksgiving: return "Thank Him for what He's done"
        case .supplication: return "Ask for what you and others need"
        }
    }
}

/// A solo challenge from challenges.json.
struct ChallengeDefinition: Decodable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var days: Int
    var description: String
    var tips: [String]
    var metric: ChallengeMetric
    var target: Int
    var symbol: String
    var subtitle: String

    enum CodingKeys: String, CodingKey {
        case id, title, days, description, tips, dailyTips, daily_tips, tip, metric, target, symbol, icon, subtitle, summary, badge, badgeSymbol
    }

    init(id: String, title: String, days: Int, description: String, tips: [String], metric: ChallengeMetric? = nil,
         target: Int? = nil, symbol: String? = nil, subtitle: String = "") {
        self.id = id
        self.title = title
        self.days = days
        self.description = description
        self.tips = tips
        let resolved = metric ?? ChallengeDefinition.inferMetric(id: id, title: title)
        self.metric = resolved
        self.target = target ?? days
        self.symbol = symbol ?? ChallengeDefinition.defaultSymbol(id: id, metric: resolved)
        self.subtitle = subtitle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id)
        let title = try c.decodeIfPresent(String.self, forKey: .title) ?? id.capitalized
        let days = try c.decodeIfPresent(Int.self, forKey: .days) ?? 7
        let description = try c.decodeIfPresent(String.self, forKey: .description)
            ?? c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        let tips = try c.decodeIfPresent([String].self, forKey: .tips)
            ?? c.decodeIfPresent([String].self, forKey: .dailyTips)
            ?? c.decodeIfPresent([String].self, forKey: .daily_tips) ?? []
        let metricRaw = try c.decodeIfPresent(String.self, forKey: .metric)
        let metric = metricRaw.flatMap { ChallengeMetric(rawValue: $0) }
        let target = try c.decodeIfPresent(Int.self, forKey: .target)
        let symbol = try c.decodeIfPresent(String.self, forKey: .badgeSymbol)
            ?? c.decodeIfPresent(String.self, forKey: .symbol)
        let subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        self.init(id: id, title: title, days: days, description: description, tips: tips,
                  metric: metric, target: target, symbol: symbol, subtitle: subtitle)
    }

    static func inferMetric(id: String, title: String) -> ChallengeMetric {
        let text = (id + " " + title).lowercased()
        return text.contains("people") || text.contains("person") ? .distinctPeople : .prayedDays
    }

    static func defaultSymbol(id: String, metric: ChallengeMetric) -> String {
        if metric == .distinctPeople { return "person.3.fill" }
        let lower = id.lowercased()
        if lower.contains("fast") || lower.contains("social") { return "iphone.slash" }
        if lower.contains("habit") { return "leaf.fill" }
        if lower.contains("fresh") { return "sunrise.fill" }
        return "flag.checkered"
    }

    func tip(forDay day: Int) -> String? {
        guard !tips.isEmpty else { return nil }
        return tips[(max(day, 1) - 1) % tips.count]
    }

    static let fallback: [ChallengeDefinition] = [
        ChallengeDefinition(id: "fresh-start-7", title: "7-Day Fresh Start", days: 7,
                            description: "Seven days of praying before you scroll. A clean, simple restart.",
                            tips: ["Pray before your first app of the day."]),
        ChallengeDefinition(id: "habit-21", title: "21-Day Habit", days: 21,
                            description: "Three weeks to make prayer the first thing, not the last.",
                            tips: ["Pick a fixed time and protect it."]),
        ChallengeDefinition(id: "social-fast-40", title: "40-Day Social Media Fast", days: 40,
                            description: "Forty days where every scroll starts with a prayer.",
                            tips: ["When you reach for your phone, pray first."]),
        ChallengeDefinition(id: "pray-for-30-people", title: "Pray for 30 People", days: 30,
                            description: "Thirty days, thirty different people lifted up in prayer.",
                            tips: ["Start with someone you haven't spoken to in a while."]),
    ]
}

enum ChallengeMetric: String, Codable, Sendable {
    case prayedDays = "days"
    case distinctPeople = "people"
}

/// Optional copy.json: any nested object of strings or string arrays, read by dotted key path.
struct CopyBook: Sendable {
    private let root: [String: JSONValue]

    init(root: [String: JSONValue] = [:]) { self.root = root }

    func string(_ path: String, default fallback: String) -> String {
        guard let value = lookup(path) else { return fallback }
        switch value {
        case .string(let s): return s.isEmpty ? fallback : s
        case .array(let items):
            let strings = items.compactMap { item -> String? in if case .string(let s) = item { return s } else { return nil } }
            return strings.randomElement() ?? fallback
        default: return fallback
        }
    }

    func strings(_ path: String) -> [String] {
        guard let value = lookup(path) else { return [] }
        switch value {
        case .string(let s): return [s]
        case .array(let items): return items.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        default: return []
        }
    }

    /// A random {title, body} pair from an array of objects (notifications), or nil.
    func message(_ path: String) -> (title: String, body: String)? {
        guard let value = lookup(path) else { return nil }
        var candidates: [(String, String)] = []
        func take(_ v: JSONValue) {
            if case .object(let dict) = v, case .string(let title)? = dict["title"], case .string(let body)? = dict["body"] {
                candidates.append((title, body))
            }
        }
        switch value {
        case .array(let items): items.forEach(take)
        case .object: take(value)
        default: break
        }
        guard let pick = candidates.randomElement() else { return nil }
        return (pick.0, pick.1)
    }

    /// Fills copy.json placeholders. {name} = the user's first name (with a fallback).
    static func fill(_ text: String, name: String? = nil, hours: Double? = nil, days: Int? = nil, streak: Int? = nil,
                     verse: Verse? = nil) -> String {
        var out = text
        let first = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        out = out.replacingOccurrences(of: "{name}", with: first.isEmpty ? "friend" : first)
        if let hours {
            let formatted = hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
            out = out.replacingOccurrences(of: "{hours}", with: "\(formatted) \(hours == 1 ? "hour" : "hours")")
        }
        if let days { out = out.replacingOccurrences(of: "{days}", with: "\(days)") }
        if let streak { out = out.replacingOccurrences(of: "{streak}", with: "\(streak)") }
        if let verse {
            out = out.replacingOccurrences(of: "{verseRef}", with: verse.ref)
            out = out.replacingOccurrences(of: "{verseText}", with: verse.displayText)
        }
        return out
    }

    private func lookup(_ path: String) -> JSONValue? {
        var current: JSONValue = .object(root)
        for part in path.split(separator: ".") {
            guard case .object(let dict) = current, let next = dict[String(part)] else { return nil }
            current = next
        }
        return current
    }
}

enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { self = .null }
    }
}

/// Loads every content file once.
final class ContentStore: @unchecked Sendable {
    static let shared = ContentStore()

    let prompts: PromptLibrary
    let challenges: [ChallengeDefinition]
    let copy: CopyBook
    /// Mood pools ("tempted", "anxious", …) from prompts.json (top-level keys or a "moods" object), else built-in.
    let moodPrompts: [PrayerMood: [String]]
    /// The Advent journey (Nov 29 – Dec 24; shown only on those dates).
    let advent: [AdventDay]
    /// devotionals.json (Unlock with → Devotional).
    let devotionals: [Devotional]

    init(bundle: Bundle = .main) {
        let decoder = JSONDecoder()
        advent = ContentStore.data(named: "advent", bundle: bundle).flatMap { try? decoder.decode([AdventDay].self, from: $0) } ?? []
        if let data = ContentStore.data(named: "devotionals", bundle: bundle),
           let list = try? decoder.decode([Devotional].self, from: data), !list.isEmpty {
            devotionals = list
        } else {
            devotionals = [.fallback]
        }
        if let data = ContentStore.data(named: "prompts", bundle: bundle),
           let library = try? decoder.decode(PromptLibrary.self, from: data) {
            prompts = library
        } else {
            prompts = .fallback
        }

        var moods = ContentStore.builtInMoodPrompts
        if let data = ContentStore.data(named: "prompts", bundle: bundle),
           let object = try? decoder.decode([String: JSONValue].self, from: data) {
            var nested: [String: JSONValue] = [:]
            if case .object(let inner)? = object["moods"] { nested = inner }
            for mood in PrayerMood.allCases {
                let value = object[mood.rawValue] ?? nested[mood.rawValue]
                if case .array(let items)? = value {
                    let strings = items.compactMap { item -> String? in
                        if case .string(let s) = item, !s.trimmingCharacters(in: .whitespaces).isEmpty { return s }
                        return nil
                    }
                    if !strings.isEmpty { moods[mood] = strings }
                }
            }
        }
        moodPrompts = moods

        if let data = ContentStore.data(named: "challenges", bundle: bundle) {
            struct Wrapped: Decodable { let challenges: [ChallengeDefinition] }
            if let list = try? decoder.decode([ChallengeDefinition].self, from: data), !list.isEmpty {
                challenges = list
            } else if let wrapped = try? decoder.decode(Wrapped.self, from: data), !wrapped.challenges.isEmpty {
                challenges = wrapped.challenges
            } else {
                challenges = ChallengeDefinition.fallback
            }
        } else {
            challenges = ChallengeDefinition.fallback
        }

        if let data = ContentStore.data(named: "copy", bundle: bundle),
           let object = try? decoder.decode([String: JSONValue].self, from: data) {
            copy = CopyBook(root: object)
        } else {
            copy = CopyBook()
        }
    }

    private static func data(named name: String, bundle: Bundle) -> Data? {
        guard let url = bundle.url(forResource: name, withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }

    static let builtInMoodPrompts: [PrayerMood: [String]] = [
        .anxious: [
            "Name the worry out loud. Then hand it over: \"This is Yours now.\"",
            "Breathe slowly. Ask for peace that doesn't depend on how today goes.",
            "What's the next small step? Ask for courage for just that one.",
            "Tell God what you're afraid might happen. He's not surprised by any of it.",
        ],
        .grateful: [
            "Say thank you for three specific things from today. Small counts.",
            "Who made today better? Thank God for them by name.",
            "Thank Him for a prayer He already answered.",
            "Let gratitude be the whole prayer. No requests, just thanks.",
        ],
        .tempted: [
            "You reached for your phone, and you stopped. That's grace already at work. Ask for strength for the next ten minutes.",
            "Tell God honestly what you want right now. Then ask what you actually need.",
            "Ask for a way out, and then take the first one you see. Stand up, step outside, text a friend.",
            "You are not your temptation. Ask to be reminded who you are and whose you are.",
            "Pray for a clean, quiet heart, one minute at a time.",
            "Name what's pulling at you. Ask God to make the next right choice feel possible.",
            "Breathe. Picture handing this moment to Jesus. Let Him hold it while you walk away.",
            "Ask for help to fill this moment with something good instead.",
        ],
        .tired: [
            "You don't need the right words. Just rest here for a minute.",
            "Ask for enough strength for the rest of today, not all of tomorrow.",
            "Tell God you're tired. He invites the weary to come to Him.",
            "Let go of one thing you don't have to carry tonight.",
        ],
        .lonely: [
            "Tell God you feel alone. Ask Him to make His nearness real.",
            "Ask for one good conversation this week, and the courage to start it.",
            "Pray for someone else who might be lonely today, too.",
            "Rest in this: you are known and loved, right now, exactly as you are.",
        ],
        .joyful: [
            "Celebrate with God. Tell Him what made you smile today.",
            "Thank Him for this joy, and ask how to share it with someone.",
            "Praise Him for His goodness, out loud if you can.",
            "Ask that today's joy would carry you through a harder day later.",
        ],
    ]

    func challenge(id: String) -> ChallengeDefinition? {
        challenges.first { $0.id == id }
    }

    /// A prompt with `{name}` filled in.
    static func fill(_ prompt: String, name: String) -> String {
        prompt.replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{Name}", with: name)
            .replacingOccurrences(of: "{NAME}", with: name)
    }
}
