import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmReset = false
    @State private var confirmDeleteCircles = false
    @State private var showShareApp = false

    var body: some View {
        Form {
            profileSection
            prayerSection
            gateSection
            remindersSection
            circlesSection
            aboutSection
            dataSection
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }
        }
        .task { notificationStatus = await ReminderService.shared.authorizationStatus() }
        .sheet(isPresented: $showShareApp) {
            ShareSheet(items: ["\(AppConstants.appName): \(AppConstants.slogan) \(AppLinks.shareURL.absoluteString)"])
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Erase everything?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase all data", role: .destructive) {
                model.resetAllData()
                dismiss()
            }
        } message: {
            Text("Your people, journal, streak and settings are deleted from this iPhone, you leave every circle, and your username and friends are deleted. This can't be undone.")
        }
        .confirmationDialog("Delete your circle data?", isPresented: $confirmDeleteCircles, titleVisibility: .visible) {
            Button("Delete and leave all circles", role: .destructive) {
                let codes = model.store.circleCodes
                Task {
                    try? await model.circles.deleteMyData(codes: codes)
                    model.toast = "Your circle data was deleted"
                }
            }
        } message: {
            Text("Removes your nickname, emoji and counts from every circle you're in.")
        }
    }

    private func settingsLabel(_ title: String, _ symbol: String, tint: Color = Theme.goldIcon) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: symbol, tint: tint, size: 30)
            Text(title).foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: Sections

    private var profileSection: some View {
        Section {
            HStack(spacing: 12) {
                IconBadge(systemImage: "person.fill", size: 30)
                TextField("First name", text: model.binding(\.firstName))
                    .textInputAutocapitalization(.words)
                    .textContentType(.givenName)
            }
            NavigationLink {
                UsernameView()
            } label: {
                HStack {
                    settingsLabel("Username", "at")
                    Spacer()
                    Text(model.username.map { "@" + $0 } ?? "None")
                        .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .accessibilityIdentifier("settings.username")
            Picker(selection: model.binding(\.appearance)) {
                ForEach(AppearancePreference.allCases) { Text($0.title).tag($0) }
            } label: { settingsLabel("Appearance", "moon.stars.fill") }
            Toggle(isOn: model.binding(\.hapticsEnabled)) { settingsLabel("Haptics", "hand.tap.fill") }
                .tint(Palette.gold)
        } header: { Text("You") }
    }

    private var prayerSection: some View {
        Section {
            NavigationLink {
                UnlockWithView()
            } label: {
                HStack {
                    settingsLabel("Unlock with", model.settings.unlockMethod.symbol)
                    Spacer()
                    Text(model.settings.unlockMethod.title)
                        .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .accessibilityIdentifier("settings.unlockWith")
            Picker(selection: model.binding(\.unlockStyle)) {
                ForEach(UnlockStyle.prayerStyles) { Label($0.title, systemImage: $0.symbol).tag($0) }
            } label: { settingsLabel("Default prayer", "hands.and.sparkles.fill") }
            if model.settings.unlockStyle == .guided {
                Picker(selection: model.binding(\.guidedSeconds)) {
                    ForEach(AppSettings.guidedLengthOptions, id: \.self) { Text(SettingsFormat.length($0)).tag($0) }
                } label: { settingsLabel("Guided length", "timer") }
            }
            Picker(selection: model.binding(\.translation)) {
                ForEach(BibleTranslation.allCases) { Text($0.short).tag($0) }
            } label: { settingsLabel("Bible translation", "book.closed.fill") }
                .accessibilityIdentifier("settings.translation")
            HStack {
                settingsLabel("Prayer text size", "textformat.size")
                Spacer()
                Button {
                    model.updateSettings { $0.sessionTextScale = max(0.8, $0.sessionTextScale - 0.1) }
                } label: { Text("A−").font(.akHeadline).frame(width: 40, height: 36) }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Smaller text")
                Text("\(Int((model.settings.sessionTextScale * 100).rounded()))%")
                    .font(.akFootnote.monospacedDigit())
                    .frame(width: 44)
                Button {
                    model.updateSettings { $0.sessionTextScale = min(1.5, $0.sessionTextScale + 0.1) }
                } label: { Text("A+").font(.akHeadline).frame(width: 40, height: 36) }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Larger text")
            }
        } header: { Text("Prayer") }
    }

    private var gateSection: some View {
        Section {
            Toggle(isOn: model.binding(\.gateEnabled)) { settingsLabel("Prayer Gate", "scroll.fill") }
                .tint(Palette.gold)
            #if STRICT_LOCK
            NavigationLink {
                LockSetupView(showsDoneButton: false)
            } label: {
                HStack {
                    settingsLabel("Locked apps", "lock.shield.fill")
                    Spacer()
                    Text(model.usesScreenTime ? "\(model.lock.lockedCount) with Screen Time" : "Set up")
                        .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .accessibilityIdentifier("settings.lockedApps")
            #endif
            if model.settings.lockMethod == .shortcuts {
                NavigationLink {
                    GateSetupView(showsDoneButton: false)
                } label: {
                    HStack {
                        settingsLabel("Gated apps & setup", "square.grid.2x2.fill")
                        Spacer()
                        Text("\(model.protectedCount) of \(model.settings.gatedApps.count) protected")
                            .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            NavigationLink {
                UnlockForView()
            } label: {
                HStack {
                    settingsLabel("Unlock for", "lock.open.fill")
                    Spacer()
                    Text(model.settings.askUnlockEachTime ? "\(model.unlockChoice.title) · ask" : model.unlockChoice.title)
                        .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .accessibilityIdentifier("settings.unlockFor")
            Toggle(isOn: model.binding(\.windowEndNudge)) { settingsLabel("Nudge when time's up", "bell.badge.fill") }
                .tint(Palette.gold)
            if model.isPaused(), let until = model.pausedUntil {
                Button { model.pauseGate(days: nil) } label: {
                    HStack {
                        settingsLabel("Resume gate", "play.fill", tint: Theme.sageText)
                        Spacer()
                        Text("Paused until \(until.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                            .font(.akFootnote).foregroundStyle(Theme.textSecondary)
                    }
                }
            } else {
                Menu {
                    Button("1 day") { model.pauseGate(days: 1) }
                    Button("3 days") { model.pauseGate(days: 3) }
                    Button("1 week") { model.pauseGate(days: 7) }
                } label: {
                    settingsLabel("Pause gate…", "pause.fill")
                }
            }
        } header: { Text("Prayer Gate") } footer: {
            Text("One emergency pass a day opens an app for \(model.emergencyMinutes) minutes without praying. Pauses and passes are counted honestly in Progress.")
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var remindersSection: some View {
        Section {
            if notificationStatus == .denied {
                Button { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } } label: {
                    settingsLabel("Notifications are off. Turn on in Settings", "bell.slash.fill", tint: Theme.roseText)
                }
            }
            Toggle(isOn: Binding(get: { model.settings.reminders.dailyEnabled },
                                 set: { on in
                                     model.updateSettings { $0.reminders.dailyEnabled = on }
                                     if on { requestNotifications() }
                                 })) {
                settingsLabel("Daily prayer reminder", "bell.fill")
            }
            .tint(Palette.gold)
            if model.settings.reminders.dailyEnabled {
                DatePicker(selection: timeBinding(hour: \.reminders.dailyHour, minute: \.reminders.dailyMinute),
                           displayedComponents: .hourAndMinute) {
                    Text("Time").padding(.leading, 42)
                }
            }
            Toggle(isOn: model.binding(\.reminders.streakAtRiskEnabled)) { settingsLabel("Streak heads-up at 8 PM", "flame.fill") }
                .tint(Palette.gold)
            Toggle(isOn: Binding(get: { model.settings.reminders.morningVerseEnabled },
                                 set: { on in
                                     model.updateSettings { $0.reminders.morningVerseEnabled = on }
                                     if on { requestNotifications() }
                                 })) {
                settingsLabel("Morning verse", "sunrise.fill")
            }
            .tint(Palette.gold)
            if model.settings.reminders.morningVerseEnabled {
                DatePicker(selection: timeBinding(hour: \.reminders.morningHour, minute: \.reminders.morningMinute),
                           displayedComponents: .hourAndMinute) {
                    Text("Time").padding(.leading, 42)
                }
            }
        } header: { Text("Reminders") }
    }

    private func requestNotifications() {
        Task {
            _ = await ReminderService.shared.requestAuthorization()
            notificationStatus = await ReminderService.shared.authorizationStatus()
            model.refreshReminders()
        }
    }

    private func timeBinding(hour: WritableKeyPath<AppSettings, Int>, minute: WritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: model.settings[keyPath: hour], minute: model.settings[keyPath: minute], second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.updateSettings { s in
                    s[keyPath: hour] = parts.hour ?? 8
                    s[keyPath: minute] = parts.minute ?? 0
                }
            })
    }

    private var circlesSection: some View {
        Section {
            Picker(selection: model.binding(\.circleDisplayEmoji)) {
                ForEach(["🕊️", "🌻", "⛰️", "🌿", "🔥", "🌙", "🌷", "⭐️", "🐑", "📖", "☀️", "🌊"], id: \.self) { Text($0).tag($0) }
            } label: { settingsLabel("Your circle emoji", "face.smiling.fill") }
            if !CircleBlockList.blocked().isEmpty {
                Button {
                    CircleBlockList.unblockAll()
                    model.toast = "Unblocked everyone"
                } label: { settingsLabel("Unblock everyone", "hand.raised.slash.fill") }
            }
            Button(role: .destructive) { confirmDeleteCircles = true } label: {
                settingsLabel("Delete my circle data", "trash.fill", tint: Theme.roseText)
            }
        } header: { Text("Prayer Circles") } footer: {
            Text("Circles use iCloud with a random id, never your Apple ID. Only your nickname, emoji, weekly count and streak are shared.")
        }
    }

    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    PrayToScrollMark(glow: true).frame(width: 30, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppConstants.appName).font(.akHeadline).foregroundStyle(Theme.textPrimary)
                        Text(AppConstants.slogan).font(.system(.footnote, design: .serif)).italic().foregroundStyle(Theme.textSecondary)
                    }
                }
                Label("Free. No ads. No account. No tracking.", systemImage: "lock.shield.fill")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Theme.sageText)
                Text("Your prayers, people and journal stay on this iPhone. Grace is free: we'll never sell streak freezes.")
                    .font(.akFootnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.vertical, 6)
            Button { showShareApp = true } label: { settingsLabel("Share \(AppConstants.appName)", "square.and.arrow.up") }
            if let review = AppLinks.reviewURL {
                Button { openURL(review) } label: { settingsLabel("Rate on the App Store", "star.fill") }
            }
            Button { openURL(AppLinks.supportURL) } label: { settingsLabel("Help & support", "questionmark.circle.fill") }
            Button { openURL(AppLinks.privacyURL) } label: { settingsLabel("Privacy policy", "hand.raised.fill") }
            Button { openURL(AppLinks.termsURL) } label: { settingsLabel("Terms of use", "doc.text.fill") }
            HStack {
                settingsLabel("Version", "info.circle.fill")
                Spacer()
                Text(versionString).font(.akFootnote).foregroundStyle(Theme.textSecondary)
            }
            Text("Scripture: " + model.content.copy.string("translationCredit", default: "World English Bible and King James Version (both public domain)"))
                .font(.akCaption)
                .foregroundStyle(Theme.textTertiary)
        } header: { Text("About") }
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) { confirmReset = true } label: {
                settingsLabel("Erase all data", "exclamationmark.triangle.fill", tint: Theme.roseText)
            }
        } footer: {
            Text("\(AppConstants.appName) has no account and no server copy of your prayers, so erasing is permanent.")
        }
    }
}
