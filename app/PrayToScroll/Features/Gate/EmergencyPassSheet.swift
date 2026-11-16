import SwiftUI

/// The honest escape hatch: once a day, open the app for a few minutes (15 under Screen Time) without praying.
struct EmergencyPassSheet: View {
    let app: GatedApp?
    var onUsed: () -> Void = {}
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 18) {
                Capsule().fill(Theme.strokeStrong).frame(width: 40, height: 5).padding(.top, 8)
                IconBadge(systemImage: "bolt.shield.fill", tint: Theme.roseText, size: 56)
                Text("I need it now")
                    .font(.akTitle)
                    .foregroundStyle(Theme.textPrimary)
                if model.canUseEmergencyPass {
                    Text("Open \(app?.name ?? "your apps") for \(model.emergencyMinutes) minutes without praying. You get one pass a day, and it shows in your stats.")
                        .font(.akCallout)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(app.map { "Open \($0.name) for \(model.emergencyMinutes) min" } ?? "Unlock for \(model.emergencyMinutes) min",
                                  systemImage: "lock.open.fill") {
                        model.useEmergencyPass(for: app)
                        dismiss()
                        onUsed()
                    }
                    .accessibilityIdentifier("emergency.use")
                } else {
                    Text("You've used today's pass. It comes back at midnight. A 30-second prayer opens the door right now.")
                        .font(.akCallout)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton("Pray for 30 seconds", systemImage: "bolt.heart.fill") {
                        dismiss()
                        model.startPrayer(style: .quick, source: app == nil ? .manual : .gate, gatedAppID: app?.id)
                    }
                }
                Button("Not now") { dismiss() }
                    .font(.akHeadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 20)
        }
    }
}
