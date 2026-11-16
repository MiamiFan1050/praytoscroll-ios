import SwiftUI

/// Settings → Username (also a sheet from Friends): pick or change your @username. Optional; friends can't find
/// you until you have one. Names are exact, unique and case-insensitive; one change every 30 days.
struct UsernameView: View {
    var showsDone = false
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var working = false
    @State private var error: String?
    @State private var availability: CircleAvailability?

    private var normalized: String { UsernameRules.normalize(text) }
    private var isUnchanged: Bool { normalized == model.username }
    private var liveProblem: UsernameRules.Problem? {
        normalized.isEmpty || isUnchanged ? nil : UsernameRules.problem(with: normalized)
    }
    private var canSave: Bool {
        !working && !normalized.isEmpty && !isUnchanged && liveProblem == nil && availability == .available
    }

    var body: some View {
        Form {
            Section {
                UsernameField(text: $text)
                if let liveProblem {
                    Text(liveProblem.message).font(.akFootnote).foregroundStyle(Theme.roseText)
                        .accessibilityIdentifier("username.problem")
                }
                if let error {
                    Text(error).font(.akFootnote).foregroundStyle(Theme.roseText)
                        .accessibilityIdentifier("username.error")
                }
            } header: {
                Text(model.username == nil ? "Pick a username" : "Your username")
            } footer: {
                Text("3–20 letters, numbers or _. Friends add you by your exact username: there's no directory, and nobody can search for you until you pick one. You can change it once every 30 days.")
            }
            if let availability, availability != .available {
                Section {
                    Label("Usernames use your iCloud account. Sign in to iCloud in Settings to pick one.", systemImage: "icloud.slash")
                        .font(.akFootnote)
                }
            }
            Section {
                Button(action: save) {
                    HStack {
                        Text(model.username == nil ? "Save username" : "Change username")
                        Spacer()
                        if working { ProgressView() }
                    }
                }
                .disabled(!canSave)
                .accessibilityIdentifier("username.save")
            }
        }
        .navigationTitle("Username")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .task {
            if text.isEmpty { text = model.username ?? "" }
            availability = await model.friends.availability()
        }
    }

    private func save() {
        working = true
        error = nil
        Task {
            do {
                let handle = try await model.claimUsername(text)
                text = handle
                Haptics.success()
                model.toast = "You're @\(handle)"
                if showsDone { dismiss() }
            } catch {
                self.error = (error as? FriendError)?.errorDescription ?? error.localizedDescription
            }
            working = false
        }
    }
}

/// "@" + a lowercase, no-autocorrect text field, capped at 20 characters.
struct UsernameField: View {
    @Binding var text: String
    var dark = false

    var body: some View {
        HStack(spacing: 2) {
            Text("@").font(.akHeadline).foregroundStyle(dark ? Palette.cream.opacity(0.6) : Theme.textSecondary)
            TextField("", text: $text, prompt: Text("username").foregroundStyle(dark ? Palette.cream.opacity(0.35) : Theme.textTertiary))
                .font(.akHeadline)
                .foregroundStyle(dark ? Palette.cream : Theme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .textContentType(.username)
                .submitLabel(.done)
                .onChange(of: text) { _, new in
                    let cleaned = String(UsernameRules.normalize(new).prefix(UsernameRules.maxLength))
                    if cleaned != new { text = cleaned }
                }
                .accessibilityIdentifier("username.field")
        }
        .frame(minHeight: 44)
    }
}
