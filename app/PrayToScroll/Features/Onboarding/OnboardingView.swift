import SwiftUI
import UserNotifications

/// First run: welcome → scroll quiz → mirror → promise → try it → apps → style → window → reminders → name → gate → first prayer.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Step = .welcome
    @State private var goingBack = false
    @State private var showGateSetup = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    enum Step: Int, CaseIterable {
        case welcome, scrollQuiz, mirror, promise, tryIt, chooseApps, style, window, reminders, name, gateSetup, firstPrayer
    }

    private var copy: CopyBook { model.content.copy }

    /// copy.json text with the app's name kept in one place.
    private func text(_ path: String, _ fallback: String) -> String {
        let raw = copy.string("onboarding.\(path)", default: fallback)
        let hours = model.settings.scrollHoursPerDay
        return CopyBook.fill(raw.replacingOccurrences(of: "Pray to Scroll", with: AppConstants.appName),
                             name: model.settings.firstName, hours: hours, days: mirrorDays)
    }

    private var mirrorDays: Int { Int((model.settings.scrollHoursPerDay * 365 / 24).rounded()) }

    var body: some View {
        ZStack {
            AppBackground(glowStrength: step == .welcome ? 1.4 : 1)
            if step == .welcome || step == .mirror {
                LightParticles(count: 28, speed: 0.8).ignoresSafeArea()
            }
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Spacing.page)
                    .padding(.top, 6)
                ZStack {
                    page(step)
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                            removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
                    .padding(.horizontal, Spacing.page)
                    .padding(.bottom, 12)
            }
        }
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showGateSetup, onDismiss: { advance() }) {
            NavigationStack { GateSetupView() }
                .environment(model)
        }
        .onChange(of: model.activeSession) { _, session in
            // The "Try it" sample ends: move on.
            if session == nil, step == .tryIt, model.sampleCompleted { advance() }
        }
        .onAppear {
            name = model.settings.firstName
            let r = model.settings.reminders
            reminderTime = Calendar.current.date(bySettingHour: r.dailyHour, minute: r.dailyMinute, second: 0, of: Date()) ?? reminderTime
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.cream)
                    .frame(width: 44, height: 44)
            }
            .opacity(step == .welcome ? 0 : 1)
            .disabled(step == .welcome)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("onboarding.back")
            progress
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var progress: some View {
        GeometryReader { geo in
            let fraction = Double(step.rawValue) / Double(Step.allCases.count - 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(Palette.goldButton)
                    .frame(width: max(8, geo.size.width * fraction))
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step)
            }
        }
        .frame(height: 5)
        .opacity(step == .welcome ? 0 : 1)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 6) {
            PrimaryButton(ctaTitle, systemImage: ctaSymbol) { primaryAction() }
                .disabled(ctaDisabled)
                .accessibilityIdentifier("onboarding.cta")
            if let secondary = secondaryTitle {
                Button(secondary) { secondaryAction() }
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.cream.opacity(0.65))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding.secondary")
            } else {
                Color.clear.frame(height: 44)
            }
        }
    }

    private var ctaTitle: String {
        switch step {
        case .welcome: return text("welcome.cta", "Get started")
        case .scrollQuiz: return text("scrollQuiz.cta", "Continue")
        case .mirror: return text("mirror.cta", "I want that")
        case .promise: return text("promise.cta", "I'm in")
        case .tryIt: return model.sampleCompleted ? "Continue" : "Try a 15-second prayer"
        case .chooseApps: return model.settings.gatedAppIDs.isEmpty ? "Choose at least one" : text("chooseApps.cta", "Continue")
        case .style: return text("unlockStyle.cta", "Continue")
        case .window: return text("window.cta", "Continue")
        case .reminders: return text("reminders.cta", "Turn on reminders")
        case .name: return text("name.cta", "Continue")
        case .gateSetup: return text("gateSetup.cta", "Show me how")
        case .firstPrayer: return text("firstPrayer.cta", "Start praying")
        }
    }

    private var ctaSymbol: String? {
        switch step {
        case .tryIt: return model.sampleCompleted ? "arrow.right" : "hands.and.sparkles.fill"
        case .reminders: return "bell.fill"
        case .firstPrayer: return "hands.and.sparkles.fill"
        default: return nil
        }
    }

    private var ctaDisabled: Bool {
        step == .chooseApps && model.settings.gatedAppIDs.isEmpty
    }

    private var secondaryTitle: String? {
        switch step {
        case .tryIt: return model.sampleCompleted ? nil : "Skip"
        case .chooseApps: return "I'll choose later"
        case .reminders: return text("reminders.secondary", "Not now")
        case .name: return "Skip"
        case .gateSetup: return text("gateSetup.secondary", "I'll do this later")
        case .firstPrayer: return "Maybe later"
        default: return nil
        }
    }

    // MARK: Actions

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        goingBack = false
        nameFocused = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { step = next }
    }

    private func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        goingBack = true
        nameFocused = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) { step = previous }
        Haptics.tap()
    }

    private func primaryAction() {
        switch step {
        case .tryIt:
            if model.sampleCompleted {
                advance()
            } else {
                model.startPrayer(style: .quick, source: .onboarding, isSample: true,
                                  seedPrompt: "Take a breath. Thank God for one good thing from today.")
            }
        case .reminders:
            saveReminderTime()
            Task {
                let granted = await ReminderService.shared.requestAuthorization()
                await MainActor.run {
                    model.updateSettings { $0.reminders.dailyEnabled = granted }
                    advance()
                }
            }
        case .name:
            saveName()
            advance()
        case .gateSetup:
            if model.settings.gatedAppIDs.isEmpty {
                advance()
            } else {
                showGateSetup = true
            }
        case .firstPrayer:
            finish(pray: true)
        default:
            advance()
        }
    }

    private func secondaryAction() {
        switch step {
        case .reminders:
            model.updateSettings { s in
                s.reminders.dailyEnabled = false
                s.reminders.morningVerseEnabled = false
            }
            advance()
        case .name:
            name = ""
            advance()
        case .firstPrayer:
            finish(pray: false)
        default:
            advance()
        }
    }

    private func saveReminderTime() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        model.updateSettings { s in
            s.reminders.dailyHour = parts.hour ?? 8
            s.reminders.dailyMinute = parts.minute ?? 0
        }
    }

    private func saveName() {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = cleaned.split(separator: " ").first.map(String.init) ?? ""
        model.updateSettings { $0.firstName = String(first.prefix(30)) }
    }

    private func finish(pray: Bool) {
        model.updateSettings { $0.hasOnboarded = true }
        model.refreshReminders()
        Haptics.success()
        if pray {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                model.startPrayer(style: .quick, source: .onboarding)
            }
        }
    }

    // MARK: Pages

    @ViewBuilder
    private func page(_ step: Step) -> some View {
        switch step {
        case .welcome: welcomePage
        case .scrollQuiz: scrollQuizPage
        case .mirror: mirrorPage
        case .promise: promisePage
        case .tryIt: tryItPage
        case .chooseApps: chooseAppsPage
        case .style: stylePage
        case .window: windowPage
        case .reminders: remindersPage
        case .name: namePage
        case .gateSetup: gateSetupPage
        case .firstPrayer: firstPrayerPage
        }
    }

    private func header(_ headline: String, _ subline: String, overline: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let overline { Text(overline).akOverline(color: Palette.warmGold) }
            Text(headline)
                .font(.akLargeTitle)
                .foregroundStyle(Palette.cream)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboarding.headline")
            Text(subline)
                .font(.akCallout)
                .foregroundStyle(Palette.cream.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scrollPage<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                content()
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var welcomePage: some View {
        VStack(spacing: 22) {
            Spacer()
            MascotView(pose: .waving, size: 230)
            VStack(spacing: 10) {
                Text(AppConstants.appName)
                    .akOverline(color: Palette.warmGold)
                Text(text("welcome.headline", AppConstants.slogan))
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("onboarding.headline")
                Text(text("welcome.subline", "A short prayer between you and the apps that eat your day."))
                    .font(.akCallout)
                    .foregroundStyle(Palette.cream.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Label("Free. No ads. No account. No tracking.", systemImage: "lock.shield.fill")
                .font(.akFootnote.weight(.semibold))
                .foregroundStyle(Palette.cream.opacity(0.6))
        }
        .padding(.horizontal, 28)
    }

    private var scrollQuizPage: some View {
        scrollPage {
            header(text("scrollQuiz.headline", "How many hours a day do you scroll?"),
                   text("scrollQuiz.subline", "No judgment. Most of us guess low."))
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(hoursString(model.settings.scrollHoursPerDay))
                        .font(.system(size: 88, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.goldGradient)
                        .contentTransition(.numericText(value: model.settings.scrollHoursPerDay))
                        .animation(.snappy, value: model.settings.scrollHoursPerDay)
                    Text(model.settings.scrollHoursPerDay == 1 ? "hour" : "hours")
                        .font(.akTitle2)
                        .foregroundStyle(Palette.cream.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                Slider(value: Binding(get: { model.settings.scrollHoursPerDay },
                                      set: { value in
                                          let snapped = (value * 2).rounded() / 2
                                          if snapped != model.settings.scrollHoursPerDay { Haptics.selection() }
                                          model.updateSettings { $0.scrollHoursPerDay = snapped }
                                      }),
                       in: 0.5...10, step: 0.5)
                    .tint(Palette.gold)
                    .accessibilityLabel("Hours a day")
                    .accessibilityValue(hoursString(model.settings.scrollHoursPerDay) + " hours")
                HStack {
                    Text("30 min").font(.akCaption)
                    Spacer()
                    Text("10 hours").font(.akCaption)
                }
                .foregroundStyle(Palette.cream.opacity(0.5))
            }
            .akCard()
        }
    }

    private func hoursString(_ hours: Double) -> String {
        hours == hours.rounded() ? "\(Int(hours))" : String(format: "%.1f", hours)
    }

    private var mirrorPage: some View {
        scrollPage {
            if MascotView.hasArt {
                MascotView(pose: .phone, size: 150)
                    .frame(maxWidth: .infinity)
            }
            VStack(spacing: 6) {
                Text("\(mirrorDays)")
                    .font(.system(size: 120, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.goldGradient)
                    .shadow(color: Palette.gold.opacity(0.4), radius: 24)
                    .accessibilityHidden(true)
                Text("full days every year")
                    .font(.akHeadline)
                    .foregroundStyle(Palette.cream.opacity(0.75))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            header(text("mirror.headline", "That's {days} days a year."),
                   text("mirror.subline", "{hours} a day adds up to {days} full days every year. What if a few minutes went to God first?"))
            HStack(spacing: 12) {
                mirrorStat(value: "\(Int((model.settings.scrollHoursPerDay * 60 * 7).rounded()))", label: "minutes a week")
                mirrorStat(value: "\(Int((model.settings.scrollHoursPerDay * 365).rounded()))", label: "hours a year")
            }
        }
    }

    private func mirrorStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title, design: .serif, weight: .bold))
                .foregroundStyle(Palette.cream)
            Text(label).font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.6))
        }
        .akCard(padding: 16, cornerRadius: 20)
    }

    private var promisePage: some View {
        scrollPage {
            if MascotView.hasArt {
                MascotView(pose: .phone, size: 130)
                    .frame(maxWidth: .infinity)
            }
            header(text("promise.headline", "Here's the deal."),
                   text("promise.subline", "When you open a gated app, you pray first. Then you hold Amen, and the app is yours."))
            VStack(spacing: 12) {
                promiseRow(1, "iphone.gen3", "Open Instagram, TikTok, anything you choose", "Your app pauses for a moment.")
                promiseRow(2, "hands.and.sparkles.fill", "Pray for 30 seconds or a few minutes", "A prompt, a verse, or a friend.")
                promiseRow(3, "hand.tap.fill", "Press and hold Amen", "Your app opens, and stays open for your window.")
            }
            Label("Free. No ads. No account. No tracking.", systemImage: "lock.shield.fill")
                .font(.akFootnote.weight(.semibold))
                .foregroundStyle(Palette.sage)
                .frame(maxWidth: .infinity)
        }
    }

    private func promiseRow(_ number: Int, _ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Palette.gold.opacity(0.16)).frame(width: 48, height: 48)
                Image(systemName: symbol).font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.warmGold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.akHeadline).foregroundStyle(Palette.cream).fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.65))
            }
            Spacer(minLength: 0)
        }
        .akCard(padding: 14, cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number). \(title). \(detail)")
    }

    private var tryItPage: some View {
        scrollPage {
            if model.sampleCompleted {
                VStack(spacing: 16) {
                    MascotView(pose: .celebrating, size: 170)
                    Text("You just did it.")
                        .font(.akLargeTitle)
                        .foregroundStyle(Palette.cream)
                    Text("That's the whole thing: pray, hold Amen, and your app is yours. Now let's choose the apps.")
                        .font(.akCallout)
                        .foregroundStyle(Palette.cream.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            } else {
                header("Try it once.", "A 15-second sample prayer, so you know exactly what happens when you open a gated app. It won't count toward anything.",
                       overline: "Before any setup")
                ZStack {
                    BreathingGlow(size: 220)
                    HoldPreview()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 260)
            }
        }
    }

    private var chooseAppsPage: some View {
        scrollPage {
            header(text("chooseApps.headline", "Which apps pull you in?"),
                   text("chooseApps.subline", "Pick the ones you open without thinking."))
            Text("Start with 1–3. You can add more any time.")
                .font(.akFootnote.weight(.semibold))
                .foregroundStyle(Palette.warmGold)
            AppPickerView(embedded: true)
            Text("You’ll pick the real app in Shortcuts. This list is just so we can send you back to it.")
                .font(.akFootnote)
                .foregroundStyle(Palette.cream.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stylePage: some View {
        scrollPage {
            header(text("unlockStyle.headline", "How do you want to pray?"),
                   text("unlockStyle.subline", "Choose your default. You can switch any time."))
            VStack(spacing: 10) {
                ForEach(UnlockStyle.prayerStyles) { style in
                    let isOn = model.settings.unlockMethod == .prayer && model.settings.unlockStyle == style
                    Button {
                        Haptics.selection()
                        model.updateSettings { $0.unlockStyle = style; $0.unlockMethod = .prayer }
                    } label: {
                        HStack(spacing: 14) {
                            IconBadge(systemImage: style.symbol, tint: Palette.warmGold, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(text("unlockStyle.options.\(style.rawValue).title", style.title))
                                    .font(.akHeadline).foregroundStyle(Palette.cream)
                                Text(text("unlockStyle.options.\(style.rawValue).detail", style.subtitle))
                                    .font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isOn ? Palette.gold : Palette.cream.opacity(0.3))
                        }
                        .akCard(padding: 14, cornerRadius: 20, highlighted: isOn)
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("style.\(style.rawValue)")
                }
            }
            readingChoices
            if model.settings.unlockMethod == .prayer, model.settings.unlockStyle == .guided {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Guided length").font(.akSubheadlineSemibold).foregroundStyle(Palette.cream.opacity(0.8))
                    HStack(spacing: 8) {
                        ForEach(AppSettings.guidedLengthOptions, id: \.self) { seconds in
                            Button {
                                Haptics.selection()
                                model.updateSettings { $0.guidedSeconds = seconds }
                            } label: {
                                Chip(text: SettingsFormat.length(seconds), isSelected: model.settings.guidedSeconds == seconds, tint: Palette.warmGold)
                            }
                            .buttonStyle(PressScaleStyle())
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.settings.unlockStyle)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.settings.unlockMethod)
    }

    /// Unlock with: reading instead of praying (Settings → Unlock with has the same choice).
    private var readingChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Or unlock by reading")
                .font(.akFootnote.weight(.semibold))
                .foregroundStyle(Palette.warmGold)
            HStack(spacing: 10) {
                ForEach([UnlockMethod.verse, .devotional]) { method in
                    let isOn = model.settings.unlockMethod == method
                    Button {
                        Haptics.selection()
                        model.updateSettings { $0.unlockMethod = method }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: method.symbol).foregroundStyle(Palette.warmGold)
                                Spacer()
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isOn ? Palette.gold : Palette.cream.opacity(0.3))
                            }
                            Text(method.title).font(.akHeadline).foregroundStyle(Palette.cream)
                            Text(method == .verse ? "A verse and what it means." : "A verse, a short reading, a prayer.")
                                .font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.65))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .akCard(padding: 14, cornerRadius: 20, highlighted: isOn)
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("onboarding.unlockWith.\(method.rawValue)")
                }
            }
        }
        .padding(.top, 6)
    }

    private var windowPage: some View {
        scrollPage {
            header(text("window.headline", "How long should Amen unlock?"),
                   text("window.subline", "After you pray, your apps stay open this long."))
            UnlockChoiceGrid(presets: model.unlockPresets, selected: model.unlockChoice) { choice in
                model.updateSettings { choice.apply(to: &$0) }
            }
            Text(model.unlockChoice == .restOfToday
                 ? "Pray once and your apps stay open until \(UnlockForView.hourLabel(model.settings.dailyKeyResetHour)). You can change the time in Settings."
                 : "Want to decide each time? Turn on the switch below.")
                .font(.akFootnote)
                .foregroundStyle(Palette.cream.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: model.binding(\.askUnlockEachTime)) {
                Text("Ask me after each prayer").font(.akHeadline).foregroundStyle(Palette.cream)
            }
            .tint(Palette.gold)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
            .accessibilityIdentifier("onboarding.askEachTime")
        }
    }

    private var remindersPage: some View {
        scrollPage {
            header(text("reminders.headline", "A gentle nudge, once a day."),
                   text("reminders.subline", "Pick a prayer time and we'll remind you then."))
            VStack(spacing: 14) {
                DatePicker("Prayer time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxWidth: .infinity)
                Toggle(isOn: model.binding(\.reminders.morningVerseEnabled)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Morning verse").font(.akBodyMedium).foregroundStyle(Palette.cream)
                        Text("Today's verse at 7 AM, quietly.").font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.6))
                    }
                }
                .tint(Palette.gold)
                Toggle(isOn: model.binding(\.reminders.streakAtRiskEnabled)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Streak heads-up").font(.akBodyMedium).foregroundStyle(Palette.cream)
                        Text("At 8 PM, only if you haven't prayed yet.").font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.6))
                    }
                }
                .tint(Palette.gold)
            }
            .akCard()
        }
    }

    private var namePage: some View {
        scrollPage {
            header(text("name.headline", "What should we call you?"),
                   text("name.subline", "Just your first name."))
            TextField("", text: $name, prompt: Text(text("name.placeholder", "First name")).foregroundStyle(Palette.cream.opacity(0.35)))
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(Palette.cream)
                .textInputAutocapitalization(.words)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit {
                    saveName()
                    advance()
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 64)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.gold.opacity(nameFocused ? 0.6 : 0.15), lineWidth: 1))
                .accessibilityIdentifier("onboarding.name")
            Text("Stays on this iPhone. We never see it.")
                .font(.akFootnote)
                .foregroundStyle(Palette.cream.opacity(0.5))
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { nameFocused = true } }
    }

    private var gateSetupPage: some View {
        scrollPage {
            ArtImage(name: "SealScroll") { DoorwayIllustration(symbol: "scroll.fill") }
                .frame(width: 150, height: 150)
                .shadow(color: Palette.gold.opacity(0.4), radius: 28)
                .frame(maxWidth: .infinity)
            header(text("gateSetup.headline", "Set up your Prayer Gate."),
                   text("gateSetup.subline", "A quick Shortcuts automation lets us know when you open a gated app."))
            HStack(spacing: 6) {
                ForEach(model.settings.gatedApps.prefix(4)) { app in
                    AppNameChip(app: app)
                }
                if model.settings.gatedApps.isEmpty {
                    Text("No apps chosen yet. You can set this up later in Settings.")
                        .font(.akFootnote)
                        .foregroundStyle(Palette.cream.opacity(0.6))
                }
            }
            Label("One automation for all your apps, about a minute. We'll show every tap.", systemImage: "clock.fill")
                .font(.akFootnote.weight(.semibold))
                .foregroundStyle(Palette.warmGold)
        }
    }

    private var firstPrayerPage: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                BreathingGlow(size: 240)
                MascotView(pose: .praying, size: 190)
            }
            VStack(spacing: 12) {
                Text(text("firstPrayer.headline", "Let's pray. Right now."))
                    .font(.akLargeTitle)
                    .foregroundStyle(Palette.cream)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("onboarding.headline")
                Text(text("firstPrayer.subline", "Your first prayer takes about 30 seconds."))
                    .font(.akCallout)
                    .foregroundStyle(Palette.cream.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

/// A gently pulsing scroll-in-ring that previews the Amen button.
private struct HoldPreview: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { systemReduceMotion || MotionPolicy.off }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let fill = reduceMotion ? 0.7 : (sin(t * 1.2) + 1) / 2
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 6).frame(width: 130, height: 130)
                Circle()
                    .trim(from: 0, to: fill)
                    .stroke(Palette.goldGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 130, height: 130)
                PrayToScrollMark(glow: true).frame(height: 64)
            }
        }
        .accessibilityHidden(true)
    }
}
