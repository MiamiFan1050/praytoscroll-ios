import SwiftUI

/// Gate status on Home: Locked / Unlocked 12:34 left / Rest of today / Paused / Set up.
struct GateStatusCard: View {
    @Environment(AppModel.self) private var model
    let onEmergency: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
        }
    }

#if STRICT_LOCK
    @ViewBuilder
    private func content(now: Date) -> some View {
        let apps = model.settings.gatedApps
        let _ = model.lockRevision
        if !model.settings.gateEnabled {
            row(symbol: "lock.slash.fill", tint: Theme.textTertiary, title: "Prayer Gate is off",
                detail: "Turn it on in Settings whenever you're ready.", actionTitle: "Settings") { model.showSettings = true }
        } else if model.screenTimeAccessLost {
            row(symbol: "exclamationmark.lock.fill", tint: Theme.roseText, title: "Screen Time access is off",
                detail: "Your apps aren't locked right now. Turn access back on and they wait for your Amen again.",
                actionTitle: "Turn on") { Task { await model.restoreScreenTimeAccess() } }
        } else if model.usesScreenTime, case .paused(let fault) = model.lockHealth(now: now) {
            // Failed open, never silent and never stuck: the apps are open and this says so until it's fixed.
            row(symbol: "exclamationmark.lock.fill", tint: Theme.roseText, title: "Lock paused, tap to fix",
                detail: fault.detail + " Tap Fix and they lock again on time.", actionTitle: "Fix") { model.retryLock() }
        } else if model.usesScreenTime {
            screenTimeContent(now: now)
        } else if model.settings.lockMethod == .screenTime {
            row(symbol: "lock.fill", tint: Theme.goldIcon, title: "Choose the apps to lock",
                detail: "Pick them in Apple's Screen Time list. They'll wait for your Amen.", actionTitle: "Choose") { model.showLockSetup = true }
        } else if apps.isEmpty || (model.protectedCount == 0 && model.setupMarked.isEmpty) {
            row(symbol: "lock.fill", tint: Theme.goldIcon, title: "Lock your apps until you pray",
                detail: "Pick TikTok, Instagram or any app. A prayer opens them.", actionTitle: "Set up") { model.showLockSetup = true }
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

    // MARK: Screen Time

    @ViewBuilder
    private func screenTimeContent(now: Date) -> some View {
        if model.isPaused(now: now), let until = model.pausedUntil {
            row(symbol: "pause.circle.fill", tint: Theme.goldIcon,
                title: "Paused until \(until.formatted(.dateTime.weekday(.abbreviated).hour().minute()))",
                detail: "Your apps lock again then, by themselves.", actionTitle: "Resume") { model.pauseGate(days: nil) }
        } else if let end = model.currentUnlockEnd(now: now) {
            unlocked(end: end, now: now, apps: [], openCount: model.lock.lockedCount, relocks: true)
        } else {
            lockedScreenTime
        }
    }

    /// "Locked: [real app icons]": the premise at a glance.
    private var lockedScreenTime: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconBadge(systemImage: "lock.fill", tint: Theme.goldIcon, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Locked").akOverline()
                    Text("These wait for your Amen")
                        .font(.akHeadline)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                model.lock.icons(size: 34, limit: 6)
                Spacer(minLength: 8)
                if model.canUseEmergencyPass {
                    Button("I need it now", action: onEmergency)
                        .font(.akFootnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 44)
                }
            }
            lockCheck(now: .now)
        }
        .akCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.gateStatus")
        .contextMenu {
            Button { model.pauseGate(days: 1) } label: { Label("Pause for 1 day", systemImage: "pause") }
            Button { model.pauseGate(days: 3) } label: { Label("Pause for 3 days", systemImage: "pause") }
            Button { model.pauseGate(days: 7) } label: { Label("Pause for 1 week", systemImage: "pause") }
            Button { model.showLockSetup = true } label: { Label("Locked apps", systemImage: "lock.shield") }
        }
    }

    /// The lock check: proof on Home that the lock is on, or that a relock timer is set for this window.
    @ViewBuilder
    private func lockCheck(now: Date) -> some View {
        switch model.lockHealth(now: now) {
        case .locked:
            if let last = model.lastRelockAt, now.timeIntervalSince(last) < 86_400 {
                lockCheckLabel("Lock check: on. Locked again by itself at \(last.formatted(date: .omitted, time: .shortened)).")
            } else {
                lockCheckLabel("Lock check: on.")
            }
        case .open(let relocksAt):
            lockCheckLabel("Lock check: relock set for \(relocksAt.formatted(date: .omitted, time: .shortened)).")
        default:
            EmptyView()
        }
    }

    private func lockCheckLabel(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.shield.fill")
            .font(.akCaption)
            .foregroundStyle(Theme.sageText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("home.lockHealth")
    }
#else
    @ViewBuilder
    private func content(now: Date) -> some View {
        let apps = model.settings.gatedApps
        if !model.settings.gateEnabled {
            row(symbol: "lock.slash.fill", tint: Theme.textTertiary, title: "Prayer Gate is off",
                detail: "Turn it on in Settings whenever you're ready.", actionTitle: "Settings") { model.showSettings = true }
        } else if apps.isEmpty || (model.protectedCount == 0 && model.setupMarked.isEmpty) {
            row(symbol: "scroll.fill", tint: Theme.goldIcon, title: "Set up your Prayer Gate",
                detail: "One automation, about a minute. Your apps will wait for your Amen.", actionTitle: "Set up") { model.showGateSetup = true }
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
#endif

    private func unlocked(end: Date, now: Date, apps: [GatedApp], openCount: Int? = nil, relocks: Bool = false) -> some View {
        let isDaily = model.dailyKeyUntil.map { $0 >= end } ?? false
        let remaining = GateEngine.remaining(now: now, unlockedUntil: end)
        // The ring empties over this window's length (it may differ from the default when picked on the Amen screen).
        let total = max(remaining, Double(max(model.effectiveWindowMinutes, model.emergencyMinutes) * 60))
        return HStack(spacing: 16) {
            ZStack {
                ProgressRing(progress: isDaily ? 1 : remaining / total, lineWidth: 6)
                    .frame(width: 56, height: 56)
                Image(systemName: "lock.open.fill").foregroundStyle(Theme.goldIcon)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(isDaily ? "Rest of today" : "Unlocked").akOverline(color: Theme.sageText)
                Text(isDaily ? "Open until \(end.formatted(date: .omitted, time: .shortened))" : "\(GateEngine.countdownText(remaining)) left")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
                let count = openCount ?? apps.count
                Text(relocks
                     ? "\(count) \(count == 1 ? "app is" : "apps are") open. They lock again at \(end.formatted(date: .omitted, time: .shortened))."
                     : "\(count) \(count == 1 ? "app is" : "apps are") open. Enjoy, then put it down.")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textSecondary)
                #if STRICT_LOCK
                if relocks { lockCheck(now: now) }
                #endif
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
            Button { model.showGateSetup = true } label: { Label("Gate setup", systemImage: "scroll") }
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
        .accessibilityElement(children: .contain)   // the card's id stays on the card, not its text and button
        .accessibilityIdentifier("home.gateStatus")
    }
}
