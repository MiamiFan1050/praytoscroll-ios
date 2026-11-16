import SwiftUI

/// Settings → Unlock with: Prayer (default), Read a verse, or Devotional. All three count toward the streak.
struct UnlockWithView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                ForEach(UnlockMethod.allCases) { method in
                    let isOn = model.settings.unlockMethod == method
                    Button {
                        Haptics.selection()
                        model.updateSettings { $0.unlockMethod = method }
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(systemImage: method.symbol, tint: Theme.goldIcon, size: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(method.title).foregroundStyle(Theme.textPrimary)
                                Text(method.subtitle).font(.akFootnote).foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            if isOn {
                                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Theme.goldText)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("unlockWith.\(method.rawValue)")
                }
            } footer: {
                Text(model.settings.askUnlockEachTime
                     ? "Every one counts toward your streak. “Ask me after each prayer” is on, so you can also switch on the gate screen."
                     : "Every one counts toward your streak. Verses are from the World English Bible.")
            }
        }
        .navigationTitle("Unlock with")
        .navigationBarTitleDisplayMode(.inline)
    }
}
