import SwiftUI
import UserNotifications

/// Strict Lock setup: Screen Time access → Apple's app picker → the picked apps wait for the Amen.
/// Falls back to the Shortcuts gate only when Screen Time access is declined (or the person asks for it).
struct LockSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var showsDoneButton = true
    @State private var showPicker = false
    @State private var working = false
    @State private var notificationsOff = false

    var body: some View {
        let _ = model.lockRevision   // the lock isn't observable: re-render when the picks change
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    switch model.lock.authorization {
                    case .approved: chosenApps
                    case .notDetermined: allowCard
                    case .denied: deniedCard
                    }
                    if let problem = model.lockProblem { problemCard(problem) }
                    if notificationsOff, model.lock.authorization == .approved { notificationsCard }
                    howItWorks
                    shortcutsLink
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Lock your apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .background(model.lock.picker(isPresented: $showPicker) { model.lockSelectionChanged() })
        .task { await refreshNotificationStatus() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtImage(name: "PadlockGold") { DoorwayIllustration(symbol: "lock.fill") }
                .frame(width: 120, height: 120)
                .shadow(color: Palette.gold.opacity(0.35), radius: 24)
                .frame(maxWidth: .infinity)
            Text("Your apps wait for your Amen")
                .font(.akTitle2).foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("lock.title")
            Text("Apple's Screen Time locks the apps you pick. A short prayer opens them, and they lock again by themselves when your time is up.")
                .font(.akCallout).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var allowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Allow Screen Time", systemImage: "hourglass").font(.akHeadline).foregroundStyle(Theme.textPrimary)
            Text("Apple asks once. \(AppConstants.appName) only gets anonymous tokens for the apps you pick: never your usage, and nothing leaves your iPhone.")
                .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(working ? "Waiting for Apple…" : "Allow and choose apps", systemImage: "lock.shield.fill") {
                Task { await allowAndPick() }
            }
            .disabled(working)
            .accessibilityIdentifier("lock.allow")
        }
        .akCard()
    }

    private var deniedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Screen Time access is off", systemImage: "exclamationmark.lock.fill")
                .font(.akHeadline).foregroundStyle(Theme.textPrimary)
            Text("Turn it on in Settings › Screen Time › Apps with Screen Time Access, then come back. Or use the Shortcuts gate below; it needs no Screen Time access.")
                .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { Task { await allowAndPick() } } label: { Label("Try again", systemImage: "arrow.clockwise") }
                .buttonStyle(QuietButtonStyle(height: 48))
        }
        .akCard()
    }

    private var chosenApps: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.lock.hasSelection ? "Locked until you pray" : "No apps picked yet").akOverline()
                Spacer()
                if model.lock.hasSelection {
                    Text("\(model.lock.lockedCount) picked").font(.akFootnote).foregroundStyle(Theme.textSecondary)
                }
            }
            if model.lock.hasSelection {
                model.lock.icons(size: 40, limit: 6).id(model.lockRevision)
            } else {
                Text("Start with the 1–3 apps you open without thinking. TikTok, Instagram, YouTube…")
                    .font(.akFootnote).foregroundStyle(Theme.textSecondary)
            }
            PrimaryButton(model.lock.hasSelection ? "Change apps" : "Choose apps", systemImage: "square.grid.2x2.fill") {
                showPicker = true
            }
            .accessibilityIdentifier("lock.choose")
            if model.lock.hasSelection {
                Text("Windows start at 15 minutes: that's the shortest time Screen Time can lock apps again reliably.")
                    .font(.akCaption).foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .akCard(highlighted: model.lock.hasSelection)
    }

    private func problemCard(_ problem: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your apps stayed locked", systemImage: "exclamationmark.triangle.fill")
                .font(.akHeadline).foregroundStyle(Theme.roseText)
            Text(problem).font(.akFootnote).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") { model.retryLock() }.buttonStyle(QuietButtonStyle(height: 44))
        }
        .akCard()
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Turn on notifications", systemImage: "bell.badge.fill").font(.akHeadline).foregroundStyle(Theme.textPrimary)
            Text("A locked app's \"Pray now\" button can only bring you here with a notification. Without it, open \(AppConstants.appName) yourself to pray.")
                .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Allow notifications") {
                Task {
                    _ = await ReminderService.shared.requestAuthorization()
                    await refreshNotificationStatus()
                }
            }
            .buttonStyle(QuietButtonStyle(height: 44))
        }
        .akCard()
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "How it works")
            step(1, "hand.tap.fill", "Open a locked app", "It shows \"Pray to open\". Tap Pray now.")
            step(2, "hands.and.sparkles.fill", "Pray and hold Amen", "Your apps open for your window, at least 15 minutes.")
            step(3, "lock.fill", "It locks again by itself", "Even if you're still scrolling. The emergency pass, pause and Daily key all work.")
        }
    }

    private func step(_ number: Int, _ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: symbol, tint: Theme.goldIcon, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.akSubheadlineSemibold).foregroundStyle(Theme.textPrimary)
                Text(detail).font(.akFootnote).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title). \(detail)")
    }

    /// The Shortcuts gate stays for anyone who can't or won't grant Screen Time access.
    @ViewBuilder
    private var shortcutsLink: some View {
        if model.lock.authorization != .approved || !model.lock.hasSelection {
            Button {
                model.updateSettings { $0.lockMethod = .shortcuts }
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.showGateSetup = true }
            } label: {
                Label("Use the Shortcuts gate instead", systemImage: "square.stack.3d.up.fill")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Theme.goldText)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("lock.useShortcuts")
        }
    }

    private func allowAndPick() async {
        working = true
        let result = await model.lock.requestAuthorization()
        working = false
        if result == .approved {
            model.updateSettings { $0.lockMethod = .screenTime }
            showPicker = true
        }
    }

    private func refreshNotificationStatus() async {
        let status = await ReminderService.shared.authorizationStatus()
        notificationsOff = status == .denied || status == .notDetermined
    }
}
