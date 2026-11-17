import ContactsUI
import SwiftData
import SwiftUI

/// "Who will you pray for?" One search box over your prayer list and your contacts (or a typed name), then the
/// prayer list (longest-ago on top). With an empty list the search opens focused, so a contact is two taps from praying.
struct PersonChooserView: View {
    @Bindable var flow: PrayerFlow
    let onClose: () -> Void
    @Environment(AppModel.self) private var model
    @Query private var people: [Person]
    @State private var showContacts = false
    @State private var typedName = ""
    @State private var addToList = true
    @State private var search: ContactSearch?
    @FocusState private var nameFocused: Bool

    var body: some View {
        let ranked = PeopleRanking.sorted(people)
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Close", size: 40, action: onClose)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pray for someone").akOverline(color: Palette.warmGold)
                        Text("Who's on your heart?")
                            .font(.akLargeTitle)
                            .foregroundStyle(Palette.cream)
                        Text("Pray for them now, then let them know. It might be the best text they get today.")
                            .font(.akCallout)
                            .foregroundStyle(Palette.cream.opacity(0.7))
                    }

                    searchField

                    if !trimmedName.isEmpty {
                        searchResults(ranked)
                    } else {
                        listSections(ranked)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(
            ContactPickerPresenter(isPresented: $showContacts) { picked in
                guard let picked else { return }
                flow.choose(name: picked.name, phone: picked.phone, addToList: addToList)
                flow.beginPrayingForChosenPerson()
            }
        )
        .task {
            let search = self.search ?? ContactSearch(provider: model.contacts)
            self.search = search
            if people.isEmpty {
                // A new list: straight to the search, asking for Contacts the first time.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nameFocused = true }
                await search.start(ask: true)
            } else {
                await search.start(ask: false)
            }
        }
        .onChange(of: nameFocused) { _, isFocused in
            guard isFocused, let search, search.access == .notDetermined else { return }
            Task { await search.start(ask: true) }
        }
    }

    private var trimmedName: String { typedName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.cream.opacity(0.5))
            TextField("", text: $typedName, prompt: Text("Search your list or contacts").foregroundStyle(Palette.cream.opacity(0.4)))
                .font(.akBody)
                .foregroundStyle(Palette.cream)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($nameFocused)
                .onSubmit(useTopResult)
                .accessibilityIdentifier("chooser.search")
            if !typedName.isEmpty {
                Button { typedName = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.cream.opacity(0.5)) }
                    .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.08)))
    }

    @ViewBuilder
    private func searchResults(_ ranked: [Person]) -> some View {
        let listMatches = NameSearch.rank(trimmedName, ranked, name: \.name, limit: 5)
        let contactMatches = search?.results(for: trimmedName, hiding: people.map(\.name), limit: 8) ?? []
        VStack(alignment: .leading, spacing: 10) {
            ForEach(listMatches) { person in
                Button { pick(person) } label: {
                    resultRow(name: person.name, emoji: person.emoji, colorIndex: person.colorIndex,
                              detail: PeopleRanking.lastPrayedText(person.lastPrayedAt))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("chooser.person.\(person.name)")
            }
            ForEach(contactMatches) { contact in
                Button { pick(contact) } label: {
                    resultRow(name: contact.name, emoji: "", colorIndex: 2, detail: "From your contacts")
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("chooser.result.\(contact.name)")
            }
            if !listMatches.contains(where: { NameSearch.sameName($0.name, trimmedName) })
                && !contactMatches.contains(where: { NameSearch.sameName($0.name, trimmedName) }) {
                Button(action: useTypedName) {
                    resultRow(name: trimmedName, emoji: "", colorIndex: 1, detail: "Pray for \u{201C}\(trimmedName)\u{201D}")
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("chooser.typed")
            }
            if search?.access == .denied {
                contactsPickerButton
            }
            Toggle(isOn: $addToList) {
                Text("Add them to my prayer list").font(.akSubheadline).foregroundStyle(Palette.cream.opacity(0.8))
            }
            .tint(Palette.gold)
            .padding(.top, 4)
        }
    }

    private func resultRow(name: String, emoji: String, colorIndex: Int, detail: String) -> some View {
        HStack(spacing: 12) {
            Avatar(name: name, emoji: emoji, colorIndex: colorIndex, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.akBodyMedium).foregroundStyle(Palette.cream)
                Text(detail).font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.6))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Palette.warmGold)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
        .contentShape(Rectangle())
    }

    private var contactsPickerButton: some View {
        Button {
            showContacts = true
        } label: {
            Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityIdentifier("chooser.picker")
    }

    @ViewBuilder
    private func listSections(_ ranked: [Person]) -> some View {
        if let suggested = ranked.first {
            Button {
                pick(suggested)
            } label: {
                HStack(spacing: 14) {
                    Avatar(name: suggested.name, emoji: suggested.emoji, colorIndex: suggested.colorIndex, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested").akOverline(color: Palette.warmGold)
                        Text(suggested.name)
                            .font(.akTitle3)
                            .foregroundStyle(Palette.cream)
                        Text(PeopleRanking.lastPrayedText(suggested.lastPrayedAt))
                            .font(.akFootnote)
                            .foregroundStyle(Palette.cream.opacity(0.65))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.warmGold)
                }
                .akCard(highlighted: true)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("chooser.suggested")
        }

        if ranked.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your prayer list")
                    .font(.akHeadline)
                    .foregroundStyle(Palette.cream)
                ForEach(ranked.dropFirst()) { person in
                    Button { pick(person) } label: {
                        HStack(spacing: 12) {
                            Avatar(name: person.name, emoji: person.emoji, colorIndex: person.colorIndex, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name).font(.akBodyMedium).foregroundStyle(Palette.cream)
                                Text(PeopleRanking.lastPrayedText(person.lastPrayedAt))
                                    .font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.6))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            }
        }

        if search?.access.canSearch != true {
            VStack(alignment: .leading, spacing: 12) {
                Text("Someone else")
                    .font(.akHeadline)
                    .foregroundStyle(Palette.cream)
                if search?.access == .notDetermined {
                    Button {
                        nameFocused = true
                    } label: {
                        Label("Connect contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityIdentifier("chooser.connect")
                    Text("Then type a name to find them. Contacts never leave your iPhone.")
                        .font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.55))
                } else {
                    contactsPickerButton
                }
            }
        }
    }

    private func pick(_ person: Person) {
        Haptics.tap()
        nameFocused = false
        flow.choose(person: person)
        flow.beginPrayingForChosenPerson()
    }

    private func pick(_ contact: ContactMatch) {
        Haptics.tap()
        nameFocused = false
        flow.choose(name: contact.name, phone: contact.phone, addToList: addToList)
        flow.beginPrayingForChosenPerson()
    }

    private func useTypedName() {
        let name = trimmedName
        guard !name.isEmpty else { return }
        nameFocused = false
        flow.choose(name: name, addToList: addToList)
        flow.beginPrayingForChosenPerson()
    }

    /// Return on the keyboard: the best match on the list, then in contacts, then the typed name.
    private func useTopResult() {
        guard !trimmedName.isEmpty else { return }
        if let person = NameSearch.rank(trimmedName, PeopleRanking.sorted(people), name: \.name, limit: 1).first {
            pick(person)
        } else if let contact = search?.results(for: trimmedName, hiding: people.map(\.name), limit: 1).first {
            pick(contact)
        } else {
            useTypedName()
        }
    }
}

/// Presents the system contact picker modally (it can't be embedded). No Contacts permission is needed:
/// iOS hands over only the one person picked (we keep their name and a phone number).
struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (ContactMatch?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        return host
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, !context.coordinator.isPresenting else { return }
        context.coordinator.isPresenting = true
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        DispatchQueue.main.async {
            host.present(picker, animated: true)
        }
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerPresenter
        var isPresenting = false
        init(parent: ContactPickerPresenter) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            finish(ContactMatch(contact))
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            finish(nil)
        }

        private func finish(_ picked: ContactMatch?) {
            isPresenting = false
            parent.isPresented = false
            let callback = parent.onPick
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { callback(picked) }
        }
    }
}
