import Contacts
import Foundation

/// A contact someone can pray for: a name and (if there is one) a phone number for texting, read on the iPhone.
/// Contacts are never uploaded or stored in bulk; only the person you pick is saved, in your prayer list.
struct ContactMatch: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var phone: String?

    /// The number to text: a mobile or iPhone number first, then any number. Labels are Contacts' raw ones
    /// ("_$!<Mobile>!$_", "iPhone") or plain words.
    static func bestPhone(from numbers: [(label: String?, number: String)]) -> String? {
        let cleaned = numbers.filter { !$0.number.trimmingCharacters(in: .whitespaces).isEmpty }
        let mobileLabels = ["mobile", "iphone", "cell"]
        if let mobile = cleaned.first(where: { entry in
            let label = (entry.label ?? "").lowercased()
            return mobileLabels.contains { label.contains($0) }
        }) {
            return mobile.number
        }
        return cleaned.first?.number
    }
}

enum ContactsAccess: Equatable, Sendable {
    case notDetermined, full, limited, denied

    /// Type-ahead can search the address book (all of it, or the contacts the person shared on iOS 18+).
    var canSearch: Bool { self == .full || self == .limited }
}

/// Type-ahead name matching: case- and accent-insensitive, every typed word must start a word of the name
/// ("da" finds Dad, David Kim and Pastor Dan; "da k" finds David Kim; "ad" finds nobody).
enum NameSearch {
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func words(_ text: String) -> [String] {
        fold(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    static func matches(_ query: String, name: String) -> Bool {
        let wanted = words(query)
        guard !wanted.isEmpty else { return false }
        var available = words(name)
        for word in wanted {
            guard let index = available.firstIndex(where: { $0.hasPrefix(word) }) else { return false }
            available.remove(at: index)
        }
        return true
    }

    /// Lower is better: the first word starts with the query, then any word; ties go shorter, then A–Z.
    static func score(_ query: String, name: String) -> Int {
        let first = words(query).first ?? ""
        let nameWords = words(name)
        if let lead = nameWords.first, lead.hasPrefix(first) { return lead == first ? 0 : 1 }
        return 2
    }

    static func rank<T>(_ query: String, _ items: [T], name: (T) -> String, limit: Int = 8) -> [T] {
        items.filter { matches(query, name: name($0)) }
            .sorted { a, b in
                let sa = score(query, name: name(a)), sb = score(query, name: name(b))
                if sa != sb { return sa < sb }
                let na = name(a), nb = name(b)
                if na.count != nb.count { return na.count < nb.count }
                return na.localizedCaseInsensitiveCompare(nb) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    static func sameName(_ a: String, _ b: String) -> Bool { words(a) == words(b) && !words(a).isEmpty }
}

/// Where contacts come from: the iPhone's address book, or (Debug only) a demo book for UI tests.
protocol ContactsProvider: AnyObject, Sendable {
    func access() -> ContactsAccess
    func requestAccess() async -> ContactsAccess
    /// Names + best phone number. Read on demand, kept in memory only.
    func load() async -> [ContactMatch]
}

final class DeviceContacts: ContactsProvider, @unchecked Sendable {
    private let store = CNContactStore()

    func access() -> ContactsAccess {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .authorized: return .full
        case .denied, .restricted: return .denied
        default: return .limited   // iOS 18's limited access: only the contacts the person chose to share
        }
    }

    func requestAccess() async -> ContactsAccess {
        _ = try? await store.requestAccess(for: .contacts)
        return access()
    }

    func load() async -> [ContactMatch] {
        guard access().canSearch else { return [] }
        return await Task.detached(priority: .userInitiated) { [self] in self.fetchAll() }.value
    }

    private func fetchAll() -> [ContactMatch] {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName
        var found: [ContactMatch] = []
        try? store.enumerateContacts(with: request) { contact, _ in
            if let match = ContactMatch(contact) { found.append(match) }
        }
        return found
    }
}

extension ContactMatch {
    /// From a CNContact (an address-book read, or the one person picked in the system picker).
    init?(_ contact: CNContact) {
        let name = ContactNames.display(
            given: contact.isKeyAvailable(CNContactGivenNameKey) ? contact.givenName : "",
            family: contact.isKeyAvailable(CNContactFamilyNameKey) ? contact.familyName : "",
            nickname: contact.isKeyAvailable(CNContactNicknameKey) ? contact.nickname : "")
        guard !name.isEmpty else { return nil }
        let numbers = contact.isKeyAvailable(CNContactPhoneNumbersKey)
            ? contact.phoneNumbers.map { (label: $0.label, number: $0.value.stringValue) } : []
        self.init(id: contact.identifier, name: name, phone: ContactMatch.bestPhone(from: numbers))
    }
}

enum ContactNames {
    static func display(given: String, family: String, nickname: String = "") -> String {
        let full = [given, family].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? nickname.trimmingCharacters(in: .whitespaces) : full
    }
}

#if DEBUG
/// Debug builds only: a small address book for UI tests and screenshots. Not in the Release binary.
final class DemoContacts: ContactsProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var status: ContactsAccess

    init(status: ContactsAccess = .notDetermined) { self.status = status }

    static let book: [ContactMatch] = [
        ContactMatch(id: "demo-dad", name: "Dad", phone: "(555) 010-0100"),
        ContactMatch(id: "demo-danielle", name: "Danielle Brooks", phone: "(555) 010-0101"),
        ContactMatch(id: "demo-david", name: "David Kim", phone: "(555) 010-0102"),
        ContactMatch(id: "demo-mom", name: "Mom", phone: "(555) 010-0103"),
        ContactMatch(id: "demo-sarah", name: "Sarah Mitchell", phone: "(555) 010-0104"),
        ContactMatch(id: "demo-grandma", name: "Grandma Rose", phone: "(555) 010-0105"),
        ContactMatch(id: "demo-mike", name: "Pastor Mike", phone: nil),
        ContactMatch(id: "demo-zoe", name: "Zoë Hart", phone: "(555) 010-0107"),
    ]

    func access() -> ContactsAccess { lock.withLock { status } }

    func requestAccess() async -> ContactsAccess {
        lock.withLock {
            if status == .notDetermined { status = .full }
            return status
        }
    }

    func load() async -> [ContactMatch] { access().canSearch ? Self.book : [] }
}
#endif
