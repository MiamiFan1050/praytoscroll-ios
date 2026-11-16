#if STRICT_LOCK
import FamilyControls
import SwiftUI

/// v1.1 Strict Lock settings: Screen Time authorization, app picker, on/off.
struct StrictLockSettingsView: View {
    @State private var authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    @State private var enabled = StrictLockStore.isEnabled
    @State private var selection = StrictLockStore.selection
    @State private var showPicker = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Strict Lock", systemImage: "lock.shield.fill").font(.akHeadline)
                    Text("Apple's Screen Time shields your chosen apps until you pray. No Shortcuts needed, and it can't be skipped by deleting an automation.")
                        .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 4)
            }
            if !authorized {
                Section {
                    Button("Allow Screen Time access") { Task { await authorize() } }
                        .fontWeight(.semibold)
                } footer: {
                    Text("Screen Time data never leaves your iPhone. \(AppConstants.appName) only sees opaque tokens, never your app usage.")
                }
            } else {
                Section {
                    Button { showPicker = true } label: {
                        HStack {
                            Text("Apps to lock")
                            Spacer()
                            Text("\(selection.applicationTokens.count) apps · \(selection.categoryTokens.count) categories")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Toggle("Strict Lock on", isOn: $enabled)
                        .tint(Palette.gold)
                        .disabled(!StrictLockStore.hasSelection && !enabled)
                        .onChange(of: enabled) { _, on in
                            StrictLockStore.isEnabled = on
                            if on { StrictLockStore.shield() } else { StrictLockStore.unshield() }
                        }
                } footer: {
                    Text("After each prayer your apps open for your unlock window, then lock again automatically.")
                }
            }
            if let error {
                Section { Text(error).foregroundStyle(Theme.roseText) }
            }
        }
        .navigationTitle("Strict Lock")
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: selection) { _, newValue in
            StrictLockStore.selection = newValue
            if StrictLockStore.isEnabled { StrictLockStore.shield() }
        }
    }

    private func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            self.error = "Screen Time access wasn't granted. You can try again, or keep using the Shortcuts gate."
        }
    }
}
#endif
