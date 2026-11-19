import StoreKit
import SwiftUI
import UIKit

/// After the Amen: the streak grows, light rises, and the door opens.
struct CelebrationView: View {
    @Bindable var flow: PrayerFlow
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @State private var shownStreak: Int = 0
    @State private var appeared = false
    @State private var journal = ""
    @State private var journalSaved = false
    @State private var shareCard: ShareCardKind?
    /// "Ask me after each prayer": the length picked on this screen, and the end it gives.
    @State private var pickedUnlock: UnlockChoice?
    @State private var pickedUntil: Date?
    /// "I'm good, put it down": how many times this week they chose not to scroll (set once they choose it).
    @State private var putDownCount: Int?
    @State private var finished = false
    @FocusState private var journalFocused: Bool
    @Namespace private var flameSpace
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ZStack {
            LightParticles(count: 46, color: Palette.warmGold, speed: 1.3)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 30)
                    if flow.request.isSample {
                        sampleContent
                    } else if let count = putDownCount {
                        putDownContent(count)
                    } else {
                        streakHero
                        unlockPill
                        unlockChooser
                        if let milestone = flow.completion?.newMilestones.last {
                            milestoneCard(milestone)
                        }
                        journalField
                        actions
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            shownStreak = flow.completion?.previousStreak ?? 0
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.15)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    shownStreak = flow.completion?.streak.current ?? shownStreak
                }
                if (flow.completion?.streak.current ?? 0) > (flow.completion?.previousStreak ?? 0) { Haptics.success() }
            }
            // Apple's rating sheet after a calm, happy prayer (never on the way to another app, once per version).
            if ReviewPrompt.shouldAsk(model: model, source: flow.request.source, isSample: flow.request.isSample) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    ReviewPrompt.markAsked(model: model)
                    requestReview()
                }
            }
        }
        .sheet(item: $shareCard) { kind in
            ShareCardSheet(kind: kind)
                .environment(model)
        }
    }

    private var streakHero: some View {
        VStack(spacing: 14) {
            if MascotView.hasArt {
                ZStack(alignment: .bottomTrailing) {
                    MascotView(pose: .celebrating, size: 180)
                    StreakFlame(streak: shownStreak, lit: true, size: 70)
                        .matchedGeometryEffect(id: "flame", in: flameSpace)
                        .offset(x: 26, y: 8)
                }
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
            } else {
                StreakFlame(streak: shownStreak, lit: true, size: 118)
                    .matchedGeometryEffect(id: "flame", in: flameSpace)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
            }
            Text("Amen.")
                .font(.system(size: 52, weight: .bold, design: .serif))
                .foregroundStyle(Palette.cream)
                .accessibilityIdentifier("celebration.title")
            Text(headline)
                .font(.akTitle3)
                .foregroundStyle(Palette.warmGold)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
            Text(subline)
                .font(.akCallout)
                .foregroundStyle(Palette.cream.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var headline: String {
        guard let completion = flow.completion else { return "" }
        let streak = completion.streak.current
        if streak > completion.previousStreak {
            return streak == 1 ? "Day 1. Your streak starts now." : "Day \(streak). Your streak grew."
        }
        return "\(streak)-day streak, still burning."
    }

    private var subline: String {
        if !flow.personFirstName.isEmpty { return "You lifted up \(flow.personFirstName) today." }
        if flow.gatedApp != nil { return "You prayed before you scrolled." }
        return "Thanks for showing up today."
    }

    @ViewBuilder
    private var unlockPill: some View {
        if let completion = flow.completion, let until = pickedUntil ?? completion.unlockedUntil {
            HStack(spacing: 10) {
                Image(systemName: "lock.open.fill")
                    .foregroundStyle(Palette.midnight)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Palette.goldButton))
                VStack(alignment: .leading, spacing: 2) {
                    Text(unlockTitle(completion: completion, until: until))
                        .font(.akHeadline)
                        .foregroundStyle(Palette.cream)
                    Text(model.settings.gatedApps.isEmpty ? "Your gate opens the same way once it's set up."
                         : (isGatePrayer ? "Open it, or put it down. Your choice." : "Your gated apps are open."))
                        .font(.akFootnote)
                        .foregroundStyle(Palette.cream.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.gold.opacity(0.35), lineWidth: 1))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("celebration.unlock")
        }
    }

    private func unlockTitle(completion: PrayerCompletion, until: Date) -> String {
        let time = until.formatted(date: .omitted, time: .shortened)
        switch pickedUnlock ?? completion.unlockChoice {
        case .restOfToday: return "Open until \(time)"
        case .custom: return "Unlocked until \(time)"
        case .minutes(let m): return "Unlocked for \(UnlockChoice.label(minutes: m))"
        }
    }

    /// "Ask me after each prayer": the lengths as big buttons, the default picked, before Continue.
    @ViewBuilder
    private var unlockChooser: some View {
        if model.settings.askUnlockEachTime, let completion = flow.completion, completion.unlockedUntil != nil,
           model.settings.gateEnabled {
            VStack(alignment: .leading, spacing: 10) {
                Text("How long this time?").akOverline(color: Palette.warmGold)
                UnlockChoiceGrid(presets: model.unlockPresets, selected: pickedUnlock ?? completion.unlockChoice) { choice in
                    pickedUnlock = choice
                    pickedUntil = model.changeLastUnlock(to: choice)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("celebration.unlockChoices")
        }
    }

    private func milestoneCard(_ milestone: Int) -> some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                BadgeView(milestone: milestone, earned: true, size: 60)
                if MascotView.hasArt {
                    MascotView(pose: .celebrating, size: 40).offset(x: 12, y: 8)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("New milestone").akOverline(color: Palette.warmGold)
                Text(MilestoneEngine.title(for: milestone))
                    .font(.akTitle3)
                    .foregroundStyle(Palette.cream)
                Text("\(milestone) days of praying first.")
                    .font(.akFootnote)
                    .foregroundStyle(Palette.cream.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1))
    }

    private var journalField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's on your heart?")
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Palette.cream.opacity(0.8))
            HStack(spacing: 10) {
                TextField("", text: $journal, prompt: Text("One line for your journal (optional)").foregroundStyle(Palette.cream.opacity(0.35)), axis: .vertical)
                    .font(.akBody)
                    .foregroundStyle(Palette.cream)
                    .lineLimit(1...4)
                    .focused($journalFocused)
                    .disabled(journalSaved)
                    .accessibilityIdentifier("celebration.journal")
                if !journal.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        model.saveJournal(text: journal, personID: flow.personID, style: flow.style,
                                          verseRef: flow.style == .verse ? flow.verse.ref : "")
                        journalSaved = true
                        journalFocused = false
                        Haptics.success()
                    } label: {
                        Image(systemName: journalSaved ? "checkmark" : "arrow.up")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Palette.midnight)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Palette.goldButton))
                    }
                    .disabled(journalSaved)
                    .accessibilityLabel(journalSaved ? "Saved" : "Save to journal")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
        }
    }

    /// A prayer the gate asked for (Instagram, TikTok…): the celebration offers two equal choices, open it or not.
    private var isGatePrayer: Bool { flow.request.source == .gate && !flow.request.isSample }

    private var actions: some View {
        VStack(spacing: 12) {
            if let app = flow.gatedApp {
                if app.openURL != nil {
                    PrimaryButton("Open \(app.name)", systemImage: "arrow.up.forward.app.fill") {
                        saveJournalIfNeeded()
                        model.openApp(app)
                        finish()
                    }
                    .accessibilityIdentifier("celebration.continue")
                } else {
                    VStack(spacing: 6) {
                        Text("Now open \(app.name)")
                            .font(.akTitle3)
                            .foregroundStyle(Palette.cream)
                        Text("It’s unlocked. Go to your Home Screen and tap it.")
                            .font(.akCallout)
                            .foregroundStyle(Palette.cream.opacity(0.75))
                    }
                    .multilineTextAlignment(.center)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("celebration.openYourself")
                    PrimaryButton("Done", systemImage: "checkmark") {
                        saveJournalIfNeeded()
                        finish()
                    }
                    .accessibilityIdentifier("celebration.done")
                }
                putDownButton
            } else if flow.request.gatedAppID == GateEngine.anyAppID, !model.settings.gatedApps.isEmpty {
                // The all-apps automation can't say which app opened: offer each one.
                VStack(spacing: 10) {
                    Text("Open").akOverline(color: Palette.warmGold)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                        ForEach(model.settings.gatedApps) { app in
                            Button {
                                saveJournalIfNeeded()
                                model.openApp(app)
                                finish()
                            } label: {
                                Text(app.name)
                                    .font(.akHeadline)
                                    .foregroundStyle(Palette.midnight)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.goldButton))
                            }
                            .buttonStyle(PressScaleStyle())
                            .accessibilityIdentifier("celebration.backTo.\(app.id)")
                        }
                    }
                }
                putDownButton
            } else {
                PrimaryButton("Done", systemImage: "checkmark") {
                    saveJournalIfNeeded()
                    finish()
                }
                .accessibilityIdentifier("celebration.done")
                if isGatePrayer { putDownButton }
            }
            Button {
                shareCard = .streak
            } label: {
                Label("Share my streak", systemImage: "square.and.arrow.up")
                    .font(.akSubheadlineSemibold)
                    .foregroundStyle(Palette.warmGold)
                    .frame(minHeight: 44)
            }
        }
        .padding(.top, 4)
    }

    /// The other choice, the same size as Open: nothing opens and the gate stays shut.
    private var putDownButton: some View {
        Button {
            saveJournalIfNeeded()
            let count = model.putItDown(appID: flow.request.gatedAppID)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { putDownCount = count }
            // Land on Home by itself after a moment (VoiceOver users get the button instead).
            if !UIAccessibility.isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { finish() }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill").font(.body.weight(.semibold))
                Text("I'm good, put it down").lineLimit(2).multilineTextAlignment(.center)
            }
            .font(.akHeadline)
            .foregroundStyle(Palette.cream)
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 20)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.08)))
            .overlay(Capsule(style: .continuous).strokeBorder(Palette.cream.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityHint("Nothing opens. Your apps keep waiting for your Amen.")
        .accessibilityIdentifier("celebration.putDown")
    }

    /// After "put it down": one warm line, the running count, then Home.
    private func putDownContent(_ count: Int) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Palette.sage.opacity(0.18)).frame(width: 120, height: 120)
                if MascotView.hasArt {
                    MascotView(pose: .praying, size: 110)
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(Palette.sage)
                }
            }
            Text(PutDownCopy.warmLine(for: count))
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Palette.cream)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("celebration.putDownTitle")
            Text(PutDownCopy.countLine(count))
                .font(.akTitle3)
                .foregroundStyle(Palette.warmGold)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("celebration.putDownCount")
            Text("Your apps keep waiting for your Amen.")
                .font(.akCallout)
                .foregroundStyle(Palette.cream.opacity(0.7))
                .multilineTextAlignment(.center)
            PrimaryButton("Back to Home", systemImage: "house.fill") { finish() }
                .padding(.top, 8)
                .accessibilityIdentifier("celebration.home")
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    /// Closes the prayer once (the put-down screen also closes itself after a moment).
    private func finish() {
        guard !finished else { return }
        finished = true
        if putDownCount != nil { model.selectedTab = .today }
        onDone()
    }

    private func saveJournalIfNeeded() {
        guard !journalSaved, !journal.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.saveJournal(text: journal, personID: flow.personID, style: flow.style)
        journalSaved = true
    }

    // Onboarding "Try it" ending.
    private var sampleContent: some View {
        VStack(spacing: 18) {
            MascotView(pose: .celebrating, size: 170)
                .scaleEffect(appeared ? 1 : 0.5)
            Text("That's it.")
                .font(.system(size: 46, weight: .bold, design: .serif))
                .foregroundStyle(Palette.cream)
            Text("Pray, say Amen, and your app opens. Now let's connect your real apps.")
                .font(.akBody)
                .foregroundStyle(Palette.cream.opacity(0.75))
                .multilineTextAlignment(.center)
            PrimaryButton("Continue", systemImage: "arrow.right", action: onDone)
                .padding(.top, 8)
        }
    }
}
