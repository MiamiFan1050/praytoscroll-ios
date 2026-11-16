import SwiftUI

/// Big buttons for the unlock lengths, on dark screens (onboarding, the Amen screen).
struct UnlockChoiceGrid: View {
    let presets: [UnlockChoice]
    let selected: UnlockChoice
    /// Show the Custom button and its stepper.
    var allowsCustom = true
    let onPick: (UnlockChoice) -> Void
    @State private var customMinutes = UnlockChoice.defaultCustomMinutes

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 10)]

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(presets) { choice in
                    button(choice.title, isOn: choice == selected, id: choice.id) { onPick(choice) }
                }
                if allowsCustom {
                    button(selected.isCustom ? selected.title : "Custom", isOn: selected.isCustom, id: "custom") {
                        onPick(.custom(customMinutes))
                    }
                }
            }
            if allowsCustom, selected.isCustom {
                Stepper(value: $customMinutes, in: UnlockChoice.customRange, step: UnlockChoice.customStep) {
                    Text("Custom: \(UnlockChoice.label(minutes: customMinutes))")
                        .font(.akHeadline)
                        .foregroundStyle(Palette.cream)
                }
                .tint(Palette.gold)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
                .onChange(of: customMinutes) { onPick(.custom(customMinutes)) }
                .accessibilityIdentifier("unlock.customStepper")
            }
        }
        .onAppear { if case .custom(let m) = selected { customMinutes = m } }
    }

    private func button(_ title: String, isOn: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.system(.headline, design: .serif, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isOn ? Palette.midnight : Palette.cream)
                .frame(maxWidth: .infinity, minHeight: 60)
                .padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isOn ? AnyShapeStyle(Palette.goldButton) : AnyShapeStyle(Color.white.opacity(0.06))))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(isOn ? 0 : 0.1), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("unlock.\(id)")
    }
}

/// Settings → Unlock for: one list of lengths, Custom, the reset hour (under Rest of today), and "Ask me after each prayer".
struct UnlockForView: View {
    @Environment(AppModel.self) private var model
    @State private var customMinutes = UnlockChoice.defaultCustomMinutes

    var body: some View {
        let selected = model.unlockChoice
        List {
            Section {
                ForEach(model.unlockPresets) { choice in
                    row(choice.title, isOn: choice == selected, id: choice.id) { pick(choice) }
                    if choice == .restOfToday, selected == .restOfToday {
                        Picker("Resets at", selection: model.binding(\.dailyKeyResetHour)) {
                            ForEach([2, 3, 4, 5, 6], id: \.self) { hour in Text(Self.hourLabel(hour)).tag(hour) }
                        }
                        .accessibilityIdentifier("unlock.resetHour")
                    }
                }
                row("Custom", isOn: selected.isCustom, id: "custom") { pick(.custom(customMinutes)) }
                if selected.isCustom {
                    Stepper(value: $customMinutes, in: UnlockChoice.customRange, step: UnlockChoice.customStep) {
                        Text(UnlockChoice.label(minutes: customMinutes)).monospacedDigit()
                    }
                    .onChange(of: customMinutes) { pick(.custom(customMinutes)) }
                    .accessibilityIdentifier("unlock.customStepper")
                }
            } header: {
                Text("Each Amen unlocks your apps for")
            } footer: {
                Text(footer(selected))
            }
            Section {
                Toggle("Ask me after each prayer", isOn: model.binding(\.askUnlockEachTime))
                    .tint(Palette.gold)
                    .accessibilityIdentifier("unlock.askEachTime")
            } footer: {
                Text("The Amen screen shows these lengths as buttons, with \(selected.title.lowercased()) already picked.")
            }
        }
        .navigationTitle("Unlock for")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if case .custom(let m) = selected { customMinutes = m } }
    }

    private func pick(_ choice: UnlockChoice) {
        Haptics.selection()
        model.updateSettings { choice.apply(to: &$0) }
    }

    private func footer(_ choice: UnlockChoice) -> String {
        let reset = Self.hourLabel(model.settings.dailyKeyResetHour)
        switch choice {
        case .restOfToday: return "Pray once and your apps stay open until \(reset)."
        case .custom: return "Custom lengths stop at \(reset), when a new day starts."
        case .minutes: return "Then the apps ask for a prayer again."
        }
    }

    private func row(_ title: String, isOn: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(Theme.textPrimary)
                Spacer()
                if isOn { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Theme.goldIcon) }
            }
            .frame(minHeight: 32)
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("unlockFor.\(id)")
    }

    static func hourLabel(_ hour: Int) -> String {
        var parts = DateComponents()
        parts.hour = hour
        let date = Calendar.current.date(from: parts) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
