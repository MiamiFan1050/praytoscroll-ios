import SwiftUI

/// Gate status on Home: Locked / Unlocked 12:34 left / Daily key / Paused / Set up.
struct GateStatusCard: View {
    @Environment(AppModel.self) private var model
    let onEmergency: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let apps = model.settings.gatedApps
        if !model.settings.gateEnabled {
            row(symbol: "lock.slash.fill", tint: Theme.textTertiary, title: "Prayer Gate is off",
                detail: "Turn it on in Settings whenever you're ready.", actionTitle: "Settings") { model.showSettings = true }
        } else if apps.isEmpty || (model.protectedCount == 0 && model.setupMarked.isEmpty) {
            row(symbol: "key.fill", tint: Theme.goldIcon, title: "Set up your Prayer Gate",
                detail: "About a minute per app. Your apps will wait for your Amen.", actionTitle: "Set up") { model.showGateSetup = true }
        } else if model.isPaused(now: now), let until = model.pausedUntil {
            row(symbol: "pause.circle.fill", tint: Theme.goldIcon,
                title: "Paused until \(until.formatted(.dateTime.weekday(.abbreviated).hour().minute()))",
                detail: "Your gate is resting. It counts honestly in your stats.", actionTitle: "Resume") { model.pauseGate(days: nil) }
        } else if let end = model.currentUnlockEnd(now: now) {
            unlocked(end: end, now: now, apps: apps)
        } else {
            locked(apps: apps)
        }
    }

    private func unlocked(end: Date, now: Date, apps: [GatedApp]) -> some View {
        let isDaily = model.dailyKeyUntil.map { $0 >= end } ?? false
        let total = isDaily ? 86_400.0 : Double(max(model.settings.unlockWindowMinutes, GateEngine.emergencyMinutes) * 60)
        let remaining = GateEngine.remaining(now: now, unlockedUntil: end)
        return HStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: isDaily ? 1 : remaining / total, lineWidth: 6)
                    .frame(width: 56, height: 56)
                Image(systemName: "lock.open.fill").foregroundStyle(Theme.goldIcon)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(isDaily ? "Daily key" : "Unlocked").akOverline(color: Theme.sageText)
                Text(isDaily ? "Open until \(end.formatted(date: .omitted, time: .shortened))" : "\(GateEngine.countdownText(remaining)) left")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
                Text("\(apps.count) \(apps.count == 1 ? "app is" : "apps are") open. Enjoy, then put it down.")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .akCard(highlighted: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.gateStatus")
    }

    private func locked(apps: [GatedApp]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconBadge(systemImage: "lock.fill", tint: Theme.goldIcon, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Prayer Gate is on").akOverline()
                    Text("\(apps.count) \(apps.count == 1 ? "app waits" : "apps wait") for your Amen")
                        .font(.akHeadline)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(apps) { app in
                        AppNameChip(app: app, isOn: model.setupStatus(for: app).isProtected)
                    }
                }
            }
            HStack(spacing: 8) {
                Spacer(minLength: 8)
                if model.canUseEmergencyPass {
                    Button("I need it now", action: onEmergency)
                        .font(.akFootnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 44)
                }
            }
        }
        .akCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.gateStatus")
        .contextMenu {
            Button { model.pauseGate(days: 1) } label: { Label("Pause for 1 day", systemImage: "pause") }
            Button { model.pauseGate(days: 3) } label: { Label("Pause for 3 days", systemImage: "pause") }
            Button { model.pauseGate(days: 7) } label: { Label("Pause for 1 week", systemImage: "pause") }
            Button { model.showGateSetup = true } label: { Label("Gate setup", systemImage: "key") }
        }
    }

    private func row(symbol: String, tint: Color, title: String, detail: String, actionTitle: String,
                     action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: symbol, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                Text(detail).font(.akFootnote).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(actionTitle) {
                Haptics.tap()
                action()
            }
            .font(.akSubheadlineSemibold)
            .foregroundStyle(Palette.midnight)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(Capsule().fill(Palette.goldButton))
        }
        .akCard()
        .accessibilityIdentifier("home.gateStatus")
    }
}
