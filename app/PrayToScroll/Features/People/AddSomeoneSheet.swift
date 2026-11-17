import ContactsUI
import SwiftData
import SwiftUI

/// Type-ahead over the address book, shared by "Add someone" and "Pray for someone".
/// Contacts are read into memory while the screen is open; only the person you pick is saved.
@MainActor
@Observable
final class ContactSearch {
    private let provider: any ContactsProvider
    private(set) var access: ContactsAccess
    private(set) var contacts: [ContactMatch] = []
    private(set) var isLoading = false
    private var started = false

    init(provider: any ContactsProvider) {
        self.provider = provider
        self.access = provider.access()
    }

    /// Reads the address book. With `ask`, shows Apple's permission prompt the first time.
    func start(ask: Bool) async {
        guard !started || (ask && access == .notDetermined) else { return }
        started = true
        isLoading = true
        if ask, provider.access() == .notDetermined {
            access = await provider.requestAccess()
        } else {
            access = provider.access()
        }
        contacts = access.canSearch ? await provider.load() : []
        isLoading = false
    }

    /// After iOS 18's "share more contacts" button, or a return from Settings.
    func reload() async {
        access = provider.access()
        contacts = access.canSearch ? await provider.load() : []
    }

    func results(for query: String, hiding names: [String] = [], limit: Int = 8) -> [ContactMatch] {
        let candidates = contacts.filter { contact in !names.contains { NameSearch.sameName($0, contact.name) } }
        return NameSearch.rank(query, candidates, name: \.name, limit: limit)
    }
}

/// "Add someone": straight to your contacts with the search focused. Tap a name and they're on your list,
/// one tap from praying for them.
struct AddSomeoneSheet: View {
    /// Called with the person to pray for; the presenter starts the prayer after the sheet closes.
    var onPray: (Person) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query private var people: [Person]
    @State private var search: ContactSearch?
    @State private var query = ""
    @State private var added: Person?
    @State private var showPicker = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if let added {
                    addedView(added)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    searchView
                }
            }
            .navigationTitle(added == nil ? "Add someone" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(added == nil ? "Cancel" : "Done") { dismiss() }
                        .accessibilityIdentifier("add.close")
                }
            }
            .background(
                ContactPickerPresenter(isPresented: $showPicker) { picked in
                    if let picked { add(name: picked.name, phone: picked.phone) }
                }
            )
        }
        .task {
            let search = self.search ?? ContactSearch(provider: model.contacts)
            self.search = search
            focusSoon()
            await search.start(ask: true)
        }
    }

    // MARK: Search

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var searchView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                searchField
                if let search {
                    switch search.access {
                    case .denied: deniedCard
                    case .limited: limitedNote(search)
                    default: EmptyView()
                    }
                    listRows(search)
                }
                if !trimmed.isEmpty, !exactMatch {
                    Button { add(name: trimmed, phone: nil) } label: {
                        row(name: trimmed, detail: "Add as a new name", symbol: "plus.circle.fill")
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityIdentifier("add.typed")
                }
                Text("Your contacts stay on this iPhone. Only the people you add are saved, with a number for texting them.")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 10)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
            TextField("", text: $query, prompt: Text("Search contacts or type a name").foregroundStyle(Theme.textTertiary))
                .font(.akBody)
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(addTopResult)
                .accessibilityIdentifier("add.search")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary) }
                    .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func listRows(_ search: ContactSearch) -> some View {
        let shown = trimmed.isEmpty ? Array(search.contacts.prefix(200)) : search.results(for: trimmed, limit: 30)
        if search.isLoading && search.contacts.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
        }
        ForEach(shown) { contact in
            let onList = people.contains { NameSearch.sameName($0.name, contact.name) }
            Button { add(name: contact.name, phone: contact.phone) } label: {
                row(name: contact.name,
                    detail: onList ? "On your prayer list" : (contact.phone ?? "No number"),
                    symbol: onList ? "checkmark.circle.fill" : "plus.circle")
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("add.result.\(contact.name)")
        }
        if !trimmed.isEmpty, search.access.canSearch, shown.isEmpty, !search.isLoading {
            Text("No contact named \u{201C}\(trimmed)\u{201D}.")
                .font(.akFootnote)
                .foregroundStyle(Theme.textSecondary)
                .padding(.vertical, 4)
        }
    }

    private func row(name: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Avatar(name: name, emoji: "", colorIndex: name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 6, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.akBodyMedium).foregroundStyle(Theme.textPrimary)
                Text(detail).font(.akFootnote).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: symbol).font(.title3).foregroundStyle(Theme.goldIcon)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
        .contentShape(Rectangle())
    }

    private var deniedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contacts are off for Pray to Scroll. You can still pick one person from Contacts, or type a name.")
                .font(.akSubheadline)
                .foregroundStyle(Theme.textSecondary)
            Button { showPicker = true } label: {
                Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("add.picker")
            if let settings = URL(string: UIApplication.openSettingsURLString) {
                Link("Turn on in Settings", destination: settings)
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Theme.goldText)
                    .accessibilityIdentifier("add.settings")
            }
        }
        .akCard()
    }

    @ViewBuilder
    private func limitedNote(_ search: ContactSearch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Showing the contacts you chose to share.")
                .font(.akFootnote)
                .foregroundStyle(Theme.textSecondary)
            if #available(iOS 18.0, *), !trimmed.isEmpty {
                // Apple's button finds matches you haven't shared yet; tapping one shares just that contact.
                ContactAccessButton(queryString: trimmed) { identifiers in
                    Task {
                        await search.reload()
                        if let id = identifiers.first, let match = search.contacts.first(where: { $0.id == id }) {
                            add(name: match.name, phone: match.phone)
                        }
                    }
                }
                .frame(minHeight: 44)
            }
        }
        .accessibilityIdentifier("add.limited")
    }

    private var exactMatch: Bool {
        guard let search else { return false }
        return search.contacts.contains { NameSearch.sameName($0.name, trimmed) }
    }

    private func addTopResult() {
        guard !trimmed.isEmpty else { return }
        if let top = search?.results(for: trimmed, limit: 1).first {
            add(name: top.name, phone: top.phone)
        } else {
            add(name: trimmed, phone: nil)
        }
    }

    private func add(name: String, phone: String?) {
        let person = model.addPerson(name: name, relationship: "", phone: phone)
        focused = false
        Haptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { added = person }
    }

    private func focusSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focused = true }
    }

    // MARK: Added

    private func addedView(_ person: Person) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Avatar(name: person.name, emoji: person.emoji, colorIndex: person.colorIndex, size: 96)
                .shadow(color: Palette.gold.opacity(0.35), radius: 18)
            VStack(spacing: 8) {
                Text("\(person.name) is on your prayer list")
                    .font(.akTitle2)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("add.addedTitle")
                Text(person.textNumber == nil
                     ? "Pray for them now. You can add a number later to text them."
                     : "Pray for them now, then let them know with one tap.")
                    .font(.akCallout)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: 12) {
                PrimaryButton("Pray for \(person.firstName) now", systemImage: "hands.sparkles.fill") {
                    onPray(person)
                    dismiss()
                }
                .accessibilityIdentifier("add.prayNow")
                Button("Add someone else") {
                    Haptics.tap()
                    query = ""
                    withAnimation { added = nil }
                    focusSoon()
                }
                .font(.akHeadline)
                .foregroundStyle(Theme.textSecondary)
                .frame(minHeight: 48)
                .accessibilityIdentifier("add.another")
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }
}
