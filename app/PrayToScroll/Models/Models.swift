import Foundation
import SwiftData

/// Someone on the Prayer List.
@Model
final class Person {
    var id: UUID = UUID()
    var name: String = ""
    var relationship: String = ""
    var emoji: String = ""
    var createdAt: Date = Date()
    var lastPrayedAt: Date?
    var prayerCount: Int = 0
    var colorIndex: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \PrayerRequest.person)
    var requests: [PrayerRequest] = []

    init(name: String, relationship: String = "", emoji: String = "", colorIndex: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.relationship = relationship
        self.emoji = emoji
        self.createdAt = Date()
        self.colorIndex = colorIndex ?? Int.random(in: 0..<6)
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var openRequests: [PrayerRequest] {
        requests.filter { !$0.isAnswered }.sorted { $0.createdAt > $1.createdAt }
    }

    var answeredRequests: [PrayerRequest] {
        requests.filter { $0.isAnswered }.sorted { ($0.answeredAt ?? $0.createdAt) > ($1.answeredAt ?? $1.createdAt) }
    }
}

/// A specific request for a person ("Her new job", "Healing for Dad's back").
@Model
final class PrayerRequest {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var isAnswered: Bool = false
    var answeredAt: Date?
    var answerNote: String = ""
    var timesPrayed: Int = 0
    var person: Person?

    init(text: String, person: Person? = nil, createdAt: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.person = person
        self.createdAt = createdAt
    }

    var daysToAnswer: Int? {
        guard let answeredAt else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: createdAt, to: answeredAt).day ?? 0)
    }
}

/// A journal entry, written after a prayer or on its own.
@Model
final class JournalEntry {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var text: String = ""
    var personID: UUID?
    var personName: String = ""
    var requestID: UUID?
    var requestText: String = ""
    var sessionStyleRaw: String = ""
    var verseRef: String = ""

    init(text: String, createdAt: Date = Date(), person: Person? = nil, request: PrayerRequest? = nil,
         style: UnlockStyle? = nil, verseRef: String = "") {
        self.id = UUID()
        self.text = text
        self.createdAt = createdAt
        self.personID = person?.id
        self.personName = person?.name ?? ""
        self.requestID = request?.id
        self.requestText = request?.text ?? ""
        self.sessionStyleRaw = style?.rawValue ?? ""
        self.verseRef = verseRef
    }

    var style: UnlockStyle? { UnlockStyle(rawValue: sessionStyleRaw) }
}

enum SessionSource: String, Codable, Sendable {
    case manual, gate, widget, deepLink, onboarding, reminder
}

/// One completed prayer.
@Model
final class PrayerSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var completedAt: Date = Date()
    var durationSeconds: Double = 0
    var styleRaw: String = UnlockStyle.quick.rawValue
    var sourceRaw: String = SessionSource.manual.rawValue
    var gatedAppID: String = ""
    var personID: UUID?
    var personName: String = ""
    var verseRef: String = ""

    init(startedAt: Date, completedAt: Date, style: UnlockStyle, source: SessionSource,
         gatedAppID: String = "", person: Person? = nil, personName: String = "", verseRef: String = "") {
        self.id = UUID()
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = max(0, completedAt.timeIntervalSince(startedAt))
        self.styleRaw = style.rawValue
        self.sourceRaw = source.rawValue
        self.gatedAppID = gatedAppID
        self.personID = person?.id
        self.personName = person?.name ?? personName
        self.verseRef = verseRef
    }

    var style: UnlockStyle { UnlockStyle(rawValue: styleRaw) ?? .quick }
    var source: SessionSource { SessionSource(rawValue: sourceRaw) ?? .manual }
}

/// A verse saved from Scroll the Word (double-tap ❤️).
@Model
final class SavedVerse {
    var ref: String = ""
    var text: String = ""
    var theme: String = ""
    var day: Int = 0
    var savedAt: Date = Date()

    init(verse: Verse) {
        self.ref = verse.ref
        self.text = verse.text
        self.theme = verse.theme ?? ""
        self.day = verse.day
        self.savedAt = Date()
    }

    var verse: Verse { Verse(day: day, ref: ref, text: text, theme: theme.isEmpty ? nil : theme) }
}

enum PrayToScrollSchema {
    static let models: [any PersistentModel.Type] = [Person.self, PrayerRequest.self, JournalEntry.self, PrayerSession.self, SavedVerse.self]
}
