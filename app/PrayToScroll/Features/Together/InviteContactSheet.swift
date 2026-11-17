import SwiftUI

/// The text a friend invite sends: who you are on Pray to Scroll and your /u/<handle> link.
enum FriendInvite {
    static func message(handle: String) -> String {
        let clean = UsernameRules.normalize(handle)
        return "I\u{2019}m praying with \(AppConstants.appName). Add me as a friend: @\(clean) 🙏\n\n"
            + AppLinks.profileWebURL(handle: clean).absoluteString
    }
}

/// "Invite from contacts": search your contacts, tap one person, and Messages opens with their number and your
/// invite filled in. One person at a time, and you tap Send yourself: no bulk invites, nothing sent automatically.
struct InviteContactSheet: View {
    let handle: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var search: ContactSearch?
    @State private var query = ""
    @State private var inviting: Invitee?
    @State private var invited: Set<String> = []
    @State private var showPicker = false
    @State private var showShare = false
    @FocusState private var focused: Bool

    struct Invitee: Identifiable { var id: String; var name: String; var phone: String? }

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var message: String { FriendInvite.message(handle: handle) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        Text("Pick one person. Messages opens with your invite ready, and you tap Send.")
                            .font(.akFootnote)
                            .foregroundStyle(Theme.textSecondary)
                        searchField
                        if let search {
                            if search.access.canSearch {
                                rows(search)
                            } else if search.access == .denied {
                                Button { showPicker = true } label: {
                                    Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
                                }
                                .buttonStyle(QuietButtonStyle())
                                .accessibilityIdentifier("invite.picker")
                            }
                        }
                        Text("Your contacts stay on this iPhone. Nothing is sent unless you tap Send.")
                            .font(.akFootnote)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, Spacing.page)
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Invite a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("invite.done")
                }
            }
            .background(
                ContactPickerPresenter(isPresented: $showPicker) { picked in
                    if let picked { invite(Invitee(id: picked.id, name: picked.name, phone: picked.phone)) }
                }
            )
            .sheet(item: $inviting) { person in
                composer(for: person)
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: [message]).presentationDetents([.medium, .large])
            }
        }
        .task {
            let search = self.search ?? ContactSearch(provider: model.contacts)
            self.search = search
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focused = true }
            await search.start(ask: true)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
            TextField("", text: $query, prompt: Text("Search contacts").foregroundStyle(Theme.textTertiary))
                .font(.akBody)
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focused)
                .accessibilityIdentifier("invite.search")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }

    @ViewBuilder
    private func rows(_ search: ContactSearch) -> some View {
        let shown = trimmed.isEmpty ? Array(search.contacts.prefix(200)) : search.results(for: trimmed, limit: 30)
        ForEach(shown) { contact in
            let done = invited.contains(contact.id)
            Button { invite(Invitee(id: contact.id, name: contact.name, phone: contact.phone)) } label: {
                HStack(spacing: 12) {
                    Avatar(name: contact.name, emoji: "", colorIndex: 3, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).font(.akBodyMedium).foregroundStyle(Theme.textPrimary)
                        Text(done ? "Invite ready to send again" : (contact.phone ?? "No number: share the link instead"))
                            .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text(done ? "Invited" : "Invite")
                        .font(.akSubheadlineSemibold)
                        .foregroundStyle(done ? Theme.textSecondary : Theme.goldText)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("invite.contact.\(contact.name)")
        }
    }

    private func invite(_ person: Invitee) {
        focused = false
        Haptics.tap()
        if person.phone == nil {
            showShare = true            // no number: the share sheet (Messages, Mail, Copy…) with the same text
            return
        }
        inviting = person
    }

    @ViewBuilder
    private func composer(for person: Invitee) -> some View {
        let recipients = person.phone.map { [$0] } ?? []
        #if DEBUG
        if LaunchOptions.current.isDemo {
            DemoMessageComposer(recipients: recipients, text: message) { sent in finish(person, sent: sent) }
        } else {
            liveComposer(person, recipients)
        }
        #else
        liveComposer(person, recipients)
        #endif
    }

    @ViewBuilder
    private func liveComposer(_ person: Invitee, _ recipients: [String]) -> some View {
        if MessageComposer.canSend {
            MessageComposer(body: message, recipients: recipients) { sent in finish(person, sent: sent) }
                .ignoresSafeArea()
        } else {
            ShareSheet(items: [message])
        }
    }

    private func finish(_ person: Invitee, sent: Bool) {
        inviting = nil
        if sent {
            invited.insert(person.id)
            Haptics.success()
        }
    }
}
