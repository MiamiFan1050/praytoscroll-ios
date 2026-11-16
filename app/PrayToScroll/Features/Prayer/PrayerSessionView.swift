import SwiftData
import SwiftUI

/// The heart of PrayToScroll: a calm, full-screen prayer that ends with the press-and-hold Amen.
struct PrayerSessionView: View {
    let request: SessionRequest
    @Environment(AppModel.self) private var model
    @State private var flow: PrayerFlow?

    var body: some View {
        Group {
            if let flow {
                PrayerSessionContent(flow: flow)
            } else {
                Palette.midnight.ignoresSafeArea()
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            if flow == nil { flow = PrayerFlow(request: request, model: model) }
        }
    }
}

private struct PrayerSessionContent: View {
    @Bindable var flow: PrayerFlow
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLeave = false
    @State private var showEmergency = false

    var body: some View {
        ZStack {
            AppBackground(glowStrength: 1.2)
            switch flow.phase {
            case .choosePerson:
                PersonChooserView(flow: flow, onClose: close)
                    .transition(.opacity)
            case .praying:
                PrayingView(flow: flow, onClose: requestClose, onEmergency: { showEmergency = true })
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.04))))
            case .letThemKnow:
                LetThemKnowView(flow: flow)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .celebration:
                CelebrationView(flow: flow, onDone: close)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.86), value: flow.phase)
        .onAppear { flow.startTimer() }
        .onDisappear { flow.stopTimer() }
        .onChange(of: scenePhase) { _, phase in flow.scenePhaseChanged(active: phase == .active) }
        .confirmationDialog(leaveTitle, isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave prayer", role: .destructive, action: close)
            Button("Keep praying", role: .cancel) {}
        } message: {
            if let app = flow.gatedApp { Text("\(app.name) stays closed until you pray.") }
        }
        .sheet(isPresented: $showEmergency) {
            EmergencyPassSheet(app: flow.gatedApp, onUsed: close)
                .environment(model)
                .presentationDetents([.medium])
        }
    }

    private var leaveTitle: String { "Leave this prayer?" }

    private func requestClose() {
        if flow.elapsed > 5 || flow.gatedApp != nil { confirmLeave = true } else { close() }
    }

    private func close() {
        flow.stopTimer()
        if model.activeSession?.id == flow.request.id {
            model.activeSession = nil
        } else {
            dismiss()
        }
    }
}

// MARK: - Praying

private struct PrayingView: View {
    @Bindable var flow: PrayerFlow
    let onClose: () -> Void
    let onEmergency: () -> Void
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .title) private var promptBase: CGFloat = 25

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 720
            let ringSize = min(geo.size.width * 0.56, compact ? 170 : 228)
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if let app = flow.gatedApp {
                    waitingPill(app)
                        .padding(.top, 10)
                }

                if flow.showWelcomeBack {
                    welcomeBack
                        .padding(.top, 10)
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: compact ? 8 : 16)

                timerRing(size: ringSize)

                Spacer(minLength: compact ? 10 : 22)

                stepContent
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 560)

                Spacer(minLength: compact ? 10 : 18)

                if flow.stepIndex == 0, flow.style != .forSomeone, flow.currentStep?.kind == .prompt {
                    moodRow
                        .padding(.bottom, compact ? 8 : 14)
                }

                bottomControl(compact: compact)
                    .padding(.bottom, compact ? 8 : 16)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // Top bar: close · style · text size
    private var topBar: some View {
        HStack {
            CircleIconButton(systemImage: "xmark", label: "Close prayer", size: 40, action: onClose)
            Spacer()
            Text(flow.styleLabel)
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Palette.cream.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .accessibilityIdentifier("session.styleLabel")
            Spacer()
            Menu {
                Button { adjustText(0.1) } label: { Label("Larger text", systemImage: "textformat.size.larger") }
                Button { adjustText(-0.1) } label: { Label("Smaller text", systemImage: "textformat.size.smaller") }
                Button { model.updateSettings { $0.sessionTextScale = 1 } } label: { Label("Reset size", systemImage: "arrow.counterclockwise") }
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.cream)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.surfaceRaised.opacity(0.85)))
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .accessibilityLabel("Text size")
        }
    }

    private func adjustText(_ delta: Double) {
        model.updateSettings { $0.sessionTextScale = min(1.5, max(0.8, $0.sessionTextScale + delta)) }
        Haptics.selection()
    }

    private func waitingPill(_ app: GatedApp) -> some View {
        HStack(spacing: 8) {
            AppTile(app: app, size: 22)
            Text("\(app.name) is waiting for your Amen")
                .font(.akFootnote.weight(.semibold))
                .foregroundStyle(Palette.cream.opacity(0.85))
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var welcomeBack: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.circle.fill").foregroundStyle(Palette.gold)
            Text("Welcome back. Your prayer is waiting; the timer paused while you were away.")
                .font(.akFootnote)
                .foregroundStyle(Palette.cream.opacity(0.85))
            Spacer(minLength: 0)
            Button {
                withAnimation { flow.showWelcomeBack = false }
            } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Palette.cream.opacity(0.6))
            }
            .frame(width: 32, height: 32)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.07)))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func timerRing(size: CGFloat) -> some View {
        ZStack {
            BreathingGlow(size: size * 1.1)
            ProgressRing(progress: flow.progress, lineWidth: 5, track: Color.white.opacity(0.10))
                .frame(width: size, height: size)
            // segment ticks for multi-step prayers
            if flow.steps.count > 1 {
                ForEach(0..<flow.steps.count, id: \.self) { i in
                    Circle()
                        .fill(i <= flow.stepIndex ? Palette.warmGold : Color.white.opacity(0.25))
                        .frame(width: 7, height: 7)
                        .offset(y: -size / 2)
                        .rotationEffect(.degrees(Double(i) / Double(flow.steps.count) * 360))
                }
            }
            VStack(spacing: 8) {
                if let step = flow.currentStep {
                    if MascotView.hasArt {
                        MascotView(pose: .praying, size: size * 0.46)
                            .padding(.bottom, -size * 0.03)
                    } else {
                        Image(systemName: step.symbol)
                            .font(.system(size: size * 0.13, weight: .semibold))
                            .foregroundStyle(Palette.warmGold)
                            .symbolRenderingMode(.hierarchical)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Text(step.overline)
                        .akOverline(color: Palette.warmGold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: size * 0.72)
                }
                Text(flow.remaining > 0 ? GateEngine.countdownText(flow.remaining) : "Ready")
                    .font(.system(size: size * 0.11, weight: .medium, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cream.opacity(0.85))
                    .contentTransition(.numericText(countsDown: true))
                BreathCue()
            }
        }
        .frame(width: size * 1.2, height: size * 1.2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(flow.remaining > 0 ? "\(Int(flow.remaining)) seconds left" : "Ready for Amen")
    }

    @ViewBuilder
    private var stepContent: some View {
        if let step = flow.currentStep {
            switch step.kind {
            case .verseReveal:
                VerseRevealView(flow: flow, scale: model.settings.sessionTextScale)
            case .prompt:
                VStack(spacing: 14) {
                    if !step.title.isEmpty {
                        Text(step.title)
                            .font(.akFootnote.weight(.semibold))
                            .foregroundStyle(Palette.cream.opacity(0.55))
                    }
                    Text(step.prompt)
                        .font(.system(size: promptBase * model.settings.sessionTextScale, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.cream)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(step.prompt)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .accessibilityIdentifier("session.prompt")
                    if flow.style == .forSomeone, !flow.personRequests.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(flow.personRequests, id: \.self) { text in
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill").font(.caption2).foregroundStyle(Palette.rose)
                                    Text(text).font(.akFootnote).foregroundStyle(Palette.cream.opacity(0.75)).lineLimit(2)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    if !step.poolKey.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) { flow.anotherPrompt() }
                        } label: {
                            Label("Another prompt", systemImage: "arrow.triangle.2.circlepath")
                                .font(.akFootnote.weight(.semibold))
                                .foregroundStyle(Palette.warmGold.opacity(0.85))
                                .frame(minHeight: 44)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: step.prompt)
            }
        }
    }

    private var moodRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PrayerMood.allCases) { mood in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { flow.select(mood: flow.mood == mood ? nil : mood) }
                    } label: {
                        Chip(text: mood.title, systemImage: mood.symbol, isSelected: flow.mood == mood, tint: Palette.warmGold)
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(flow.mood == mood ? .isSelected : [])
                }
            }
            .padding(.horizontal, 24)
        }
        .accessibilityLabel("How are you feeling?")
    }

    @ViewBuilder
    private func bottomControl(compact: Bool) -> some View {
        let step = flow.currentStep
        if step?.kind == .verseReveal {
            VStack(spacing: 10) {
                if flow.allLinesRevealed {
                    PrimaryButton("Pray it", systemImage: "hands.and.sparkles.fill") {
                        withAnimation(.spring()) { flow.next() }
                    }
                    .padding(.horizontal, 28)
                    .accessibilityIdentifier("session.next")
                } else {
                    Text("Tap the verse to reveal the next line")
                        .font(.akFootnote)
                        .foregroundStyle(Palette.cream.opacity(0.6))
                        .frame(minHeight: 58)
                }
            }
        } else if !flow.isLastStep {
            VStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { flow.next() }
                } label: {
                    HStack(spacing: 8) {
                        Text("Next: \(flow.steps[flow.stepIndex + 1].overline)")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(QuietButtonStyle())
                .padding(.horizontal, 28)
                .accessibilityIdentifier("session.next")
                emergencyLink
            }
        } else {
            VStack(spacing: 4) {
                HoldToConfirmButton(size: compact ? 118 : 140,
                                    isEnabled: flow.canSayAmen,
                                    disabledLabel: "Pray… \(GateEngine.countdownText(flow.remaining))") {
                    flow.sayAmen()
                }
                emergencyLink
            }
        }
    }

    @ViewBuilder
    private var emergencyLink: some View {
        if flow.gatedApp != nil {
            Button("I need it now", action: onEmergency)
                .font(.akFootnote.weight(.semibold))
                .foregroundStyle(Palette.cream.opacity(0.5))
                .frame(minHeight: 36)
                .accessibilityHint("Opens your app for 5 minutes without praying, once a day")
        }
    }
}

/// Today's verse, revealed one line at a time.
private struct VerseRevealView: View {
    @Bindable var flow: PrayerFlow
    var scale: Double
    @ScaledMetric(relativeTo: .title2) private var base: CGFloat = 24

    var body: some View {
        let lines = flow.verse.revealLines
        VStack(spacing: 12) {
            Text(flow.verse.ref)
                .akOverline(color: Palette.warmGold)
            VStack(spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(size: base * scale, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.cream)
                        .multilineTextAlignment(.center)
                        .opacity(index < flow.revealedLines ? 1 : 0)
                        .blur(radius: index < flow.revealedLines ? 0 : 6)
                        .offset(y: index < flow.revealedLines ? 0 : 8)
                        .animation(.easeOut(duration: 0.6), value: flow.revealedLines)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .minimumScaleFactor(0.6)
            Text("World English Bible")
                .font(.akCaption)
                .foregroundStyle(Palette.cream.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { flow.revealNextLine() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(flow.verse.ref). \(lines.prefix(flow.revealedLines).joined(separator: " "))")
        .accessibilityHint(flow.allLinesRevealed ? "" : "Double-tap to reveal the next line")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("session.verse")
    }
}
