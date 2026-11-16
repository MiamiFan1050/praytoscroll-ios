import ContactsUI
import SwiftData
import SwiftUI

/// "Who will you pray for?" Prayer List first (longest-ago on top), Contacts via the system picker, or a typed name.
struct PersonChooserView: View {
    @Bindable var flow: PrayerFlow
    let onClose: () -> Void
    @Environment(AppModel.self) private var model
    @Query private var people: [Person]
    @State private var showContacts = false
    @State private var typedName = ""
    @State private var addToList = true
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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Someone else")
                            .font(.akHeadline)
                            .foregroundStyle(Palette.cream)
                        Button {
                            showContacts = true
                        } label: {
                            Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
                        }
                        .buttonStyle(QuietButtonStyle())
                        HStack(spacing: 10) {
                            TextField("", text: $typedName, prompt: Text("Type a name").foregroundStyle(Palette.cream.opacity(0.4)))
                                .font(.akBody)
                                .foregroundStyle(Palette.cream)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.go)
                                .focused($nameFocused)
                                .onSubmit(useTypedName)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 52)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
                                .accessibilityIdentifier("chooser.nameField")
                            Button(action: useTypedName) {
                                Image(systemName: "arrow.right")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(Palette.midnight)
                                    .frame(width: 52, height: 52)
                                    .background(Circle().fill(Palette.goldButton))
                            }
                            .disabled(typedName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity(typedName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                            .accessibilityLabel("Pray for this person")
                        }
                        Toggle(isOn: $addToList) {
                            Text("Add them to my prayer list").font(.akSubheadline).foregroundStyle(Palette.cream.opacity(0.8))
                        }
                        .tint(Palette.gold)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(
            ContactPickerPresenter(isPresented: $showContacts) { name in
                guard let name else { return }
                flow.choose(name: name, addToList: addToList)
                flow.beginPrayingForChosenPerson()
            }
        )
    }

    private func pick(_ person: Person) {
        Haptics.tap()
        flow.choose(person: person)
        flow.beginPrayingForChosenPerson()
    }

    private func useTypedName() {
        let name = typedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        nameFocused = false
        flow.choose(name: name, addToList: addToList)
        flow.beginPrayingForChosenPerson()
    }
}

/// Presents the system contact picker modally (it can't be embedded). No Contacts permission is needed:
/// we only read the chosen person's name.
struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (String?) -> Void

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
            let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            finish(name.isEmpty ? nil : name)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            finish(nil)
        }

        private func finish(_ name: String?) {
            isPresenting = false
            parent.isPresented = false
            let callback = parent.onPick
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { callback(name) }
        }
    }
}
