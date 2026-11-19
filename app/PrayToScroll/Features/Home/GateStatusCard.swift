import SwiftUI

/// Gate status on Home. The Shortcuts gate shows "Your apps": each guarded app by name with "Waits for your Amen",
/// "Open · 12:04 left", "Paused until Thu" or "Not connected yet". (Screen Time shows Apple's icons instead.)
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
        } else if let problem = model.lockProblem {
            row(symbol: "exclamationmark.lock.fill", tint: Theme.roseText, title: "Your apps stayed locked",
                detail: problem, actionTitle: "Try again") { model.retryLock() }
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
#else
    @ViewBuilder
    private func content(now: Date) -> some View {
        let apps = model.settings.gatedApps
        if !model.settings.gateEnabled {
            row(symbol: "lock.slash.fill", tint: Theme.textTertiary, title: "Prayer Gate is off",
                detail: "Turn it on in Settings whenever you're ready.", actionTitle: "Settings") { model.showSettings = true }
        } else if apps.isEmpty {
            row(symbol: "scroll.fill", tint: Theme.goldIcon, title: "Set up your Prayer Gate",
                detail: "Pick the apps that wait for your Amen. One automation, about a minute.", actionTitle: "Set up") { model.showGateSetup = true }
        } else {
            yourApps(apps, now: now)
        }
    }

    // MARK: Your apps (the Shortcuts gate)

    /// One app's line on Home: what happens if you open it right now.
    private enum AppLine: Equatable {
        case waits, open(left: String), openUntil(String), paused(String), notConnected, checkOnce, quiet

        var text: String {
            switch self {
            case .waits: return "Waits for your Amen"
            case .open(let left): return "Open · \(left) left"
            case .openUntil(let time): return "Open until \(time)"
            case .paused(let day): return "Paused until \(day)"
            case .notConnected: return "Not connected yet"
            case .checkOnce: return "Open it once to check"
            case .quiet: return "Quiet lately"
            }
        }

        var symbol: String {
            switch self {
            case .waits: return "lock.fill"
            case .open, .openUntil: return "lock.open.fill"
            case .paused: return "pause.circle.fill"
            case .notConnected: return "link"
            case .checkOnce: return "hourglass"
            case .quiet: return "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .waits: return Theme.goldIcon
            case .open, .openUntil: return Theme.sageText
            case .paused, .checkOnce: return Theme.textSecondary
            case .notConnected: return Theme.textTertiary
            case .quiet: return Theme.roseText
            }
        }
    }

    private func line(for app: GatedApp, now: Date, end: Date?, isDaily: Bool) -> AppLine {
        let status = model.setupStatus(for: app, now: now)
        if status == .notSetUp { return .notConnected }
        if model.isPaused(now: now), let until = model.pausedUntil {
            return .paused(until.formatted(.dateTime.weekday(.abbreviated)))
        }
        if let end {
            return isDaily ? .openUntil(end.formatted(date: .omitted, time: .shortened))
                : .open(left: GateEngine.countdownText(GateEngine.remaining(now: now, unlockedUntil: end)))
        }
        switch status {
        case .waitingForFirstOpen: return .checkOnce
        case .silent: return .quiet
        default: return .waits
        }
    }

    /// "Your apps": every guarded app by name with what it does right now, and the next step.
    @ViewBuilder
    private func yourApps(_ apps: [GatedApp], now: Date) -> some View {
        let paused = model.isPaused(now: now)
        let end = paused ? nil : model.currentUnlockEnd(now: now)
        let isDaily = end.map { end in model.dailyKeyUntil.map { $0 >= end } ?? false } ?? false
        let lines = apps.map { (app: $0, line: line(for: $0, now: now, end: end, isDaily: isDaily)) }
        let connected = lines.contains { $0.line != .notConnected }
        let card = VStack(alignment: .leading, spacing: 14) {
            appsHeader(paused: paused, end: end, isDaily: isDaily, connected: connected, now: now)
            VStack(spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Divider().overlay(Theme.stroke) }
                    appRow(item.app, item.line, offerFix: connected && end == nil)
                }
            }
            if connected, !paused, end == nil { lockedFooter }
        }
        .akCard(highlighted: end != nil)
        .contextMenu {
            Button { model.pauseGate(days: 1) } label: { Label("Pause for 1 day", systemImage: "pause") }
            Button { model.pauseGate(days: 3) } label: { Label("Pause for 3 days", systemImage: "pause") }
            Button { model.pauseGate(days: 7) } label: { Label("Pause for 1 week", systemImage: "pause") }
            Button { model.showGateSetup = true } label: { Label("Gate setup", systemImage: "scroll") }
        }
        if end != nil {
            // Open: one element that reads the countdown (no buttons inside to lose).
            card
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home.gateStatus")
        } else {
            card
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.gateStatus")
        }
    }

    @ViewBuilder
    private func appsHeader(paused: Bool, end: Date?, isDaily: Bool, connected: Bool, now: Date) -> some View {
        HStack(spacing: 14) {
            if let end {
                ZStack {
                    let remaining = GateEngine.remaining(now: now, unlockedUntil: end)
                    let total = max(remaining, Double(max(model.effectiveWindowMinutes, model.emergencyMinutes) * 60))
                    ProgressRing(progress: isDaily ? 1 : remaining / total, lineWidth: 5)
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.open.fill").font(.footnote).foregroundStyle(Theme.goldIcon)
                }
            } else {
                IconBadge(systemImage: paused ? "pause.circle.fill" : (connected ? "lock.fill" : "scroll.fill"), tint: Theme.goldIcon, size: 44)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Your apps").akOverline(color: end != nil ? Theme.sageText : Theme.goldText)
                Text(headerTitle(paused: paused, end: end, isDaily: isDaily, connected: connected))
                    .font(.akHeadline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if paused {
                capsuleButton("Resume") { model.pauseGate(days: nil) }
            } else if !connected {
                capsuleButton("Set up") { model.showGateSetup = true }
            }
        }
    }

    private func headerTitle(paused: Bool, end: Date?, isDaily: Bool, connected: Bool) -> String {
        if paused, let until = model.pausedUntil {
            return "Paused until \(until.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
        }
        if let end {
            return isDaily ? "Open for the rest of today" : "Open now. They wait again at \(end.formatted(date: .omitted, time: .shortened))."
        }
        return connected ? "Waiting for your Amen" : "Connect them in Shortcuts, about a minute"
    }

    private func appRow(_ app: GatedApp, _ line: AppLine, offerFix: Bool) -> some View {
        HStack(spacing: 10) {
            Text(app.name)
                .font(.akHeadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: line.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(line.tint)
            Text(line.text)
                .font(.akFootnote.weight(.semibold))
                .foregroundStyle(line == .notConnected ? Theme.textTertiary : Theme.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if offerFix, line == .notConnected {
                smallLink("Set up") { model.showGateSetup = true }
            } else if offerFix, line == .quiet {
                smallLink("Check") { model.troubleshootApp = app }
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.app.\(app.id)")
    }

    /// Locked: what a prayer does, "Pray to open", and the once-a-day pass.
    private var lockedFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(unlockHint)
                .font(.akFootnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                capsuleButton("Pray to open", systemImage: "hands.and.sparkles.fill") { model.startPrayer(source: .manual) }
                    .accessibilityIdentifier("home.apps.prayNow")
                Spacer(minLength: 8)
                if model.canUseEmergencyPass {
                    Button("I need it now", action: onEmergency)
                        .font(.akFootnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private var unlockHint: String {
        switch model.unlockChoice {
        case .restOfToday:
            let reset = GateEngine.dailyKeyUntil(from: Date(), resetHour: model.settings.dailyKeyResetHour, calendar: .current)
            return "One prayer opens them until \(reset.formatted(date: .omitted, time: .shortened))."
        case .minutes(let minutes):
            return "One prayer opens them for \(UnlockChoice.label(minutes: minutes))."
        case .custom:
            return "One prayer opens them for a while. You choose how long in Settings."
        }
    }

    private func capsuleButton(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.footnote.weight(.bold)) }
                Text(title)
            }
            .font(.akSubheadlineSemibold)
            .foregroundStyle(Palette.midnight)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(Capsule().fill(Palette.goldButton))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func smallLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.akFootnote.weight(.bold))
                .foregroundStyle(Theme.goldText)
                .frame(minWidth: 44, minHeight: 44)
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
