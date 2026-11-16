import SwiftUI

/// Step-by-step Shortcuts automation guide for one app, with drawn (not screenshotted) mock screens.
struct GateGuideView: View {
    let app: GatedApp
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private var intentName: String { app.isCustom ? "Pray First (Any App)" : "Pray Before \(app.name)" }

    private var steps: [GuideStep] {
        [
            GuideStep(title: "Open Shortcuts and tap Automation",
                      body: "It's the middle tab at the bottom of Apple's Shortcuts app.",
                      mock: .tabs),
            GuideStep(title: "Tap +, then choose App",
                      body: "Scroll the list of triggers if you don't see App right away.",
                      mock: .triggers),
            GuideStep(title: "Pick \(app.name), Is Opened, Run Immediately",
                      body: "Then turn OFF Notify When Run, so you don't get a banner every time. This step matters most.",
                      mock: .appTrigger(app.name)),
            GuideStep(title: "Tap Next, then Create New Shortcut",
                      body: "You'll land on an empty shortcut, ready for one action.",
                      mock: .newShortcut),
            GuideStep(title: "Add “\(intentName)”",
                      body: app.isCustom
                        ? "Search \(AppConstants.appName), add Pray First (Any App), and set its App field to \(app.name). Don't add an Open App step."
                        : "Search \(AppConstants.appName) and tap it. Don't add an Open App step: \(AppConstants.appName) reopens \(app.name) for you.",
                      mock: .action(intentName)),
            GuideStep(title: "Tap Done. Then test it.",
                      body: "Tap Test my gate below. \(app.name) opens, and \(AppConstants.appName) should step in within a second.",
                      mock: .finished(app.name, intentName)),
        ]
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, Spacing.page)
                    .padding(.top, 8)
                TabView(selection: $step) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                        stepPage(index: index, item: item).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: step)
                controls
                    .padding(.horizontal, Spacing.page)
                    .padding(.bottom, 16)
            }
        }
        .navigationTitle("Set up \(app.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? AnyShapeStyle(Palette.goldButton) : AnyShapeStyle(Theme.stroke))
                    .frame(height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(step + 1) of \(steps.count)")
    }

    private func stepPage(index: Int, item: GuideStep) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ShortcutsMock(kind: item.mock, app: app)
                    .frame(height: 300)
                    .padding(.top, 12)
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.system(.title, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.midnight)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Palette.goldButton))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.akTitle2)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.body)
                            .font(.akCallout)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Spacing.page)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if step == steps.count - 1 {
                PrimaryButton("Test my gate", systemImage: "checkmark.shield.fill") {
                    model.markSetUp(app)
                    model.testGate(app)
                }
                .disabled(app.openURL == nil)
                HStack {
                    Button("Open Shortcuts") { openShortcuts() }
                    Spacer()
                    Button("I've added it") {
                        model.markSetUp(app)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Theme.goldText)
                .frame(minHeight: 44)
            } else {
                PrimaryButton("Open Shortcuts", systemImage: "arrow.up.forward.app") { openShortcuts() }
                HStack {
                    Button("Back") { withAnimation { step = max(0, step - 1) } }
                        .opacity(step == 0 ? 0 : 1)
                        .disabled(step == 0)
                    Spacer()
                    Button("Next step") { withAnimation { step = min(steps.count - 1, step + 1) } }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("guide.next")
                }
                .font(.akSubheadlineSemibold)
                .foregroundStyle(Theme.goldText)
                .frame(minHeight: 44)
            }
        }
    }

    private func openShortcuts() {
        let fallback = URL(string: "shortcuts://")!
        guard let deep = URL(string: "shortcuts://create-automation") else { return }
        UIApplication.shared.open(deep) { opened in
            if !opened { UIApplication.shared.open(fallback) }
        }
    }
}

struct GuideStep {
    var title: String
    var body: String
    var mock: ShortcutsMock.Kind
}

/// Simplified, hand-drawn renditions of the Shortcuts screens (no Apple screenshots).
struct ShortcutsMock: View {
    enum Kind {
        case tabs, triggers, appTrigger(String), newShortcut, action(String), finished(String, String)
    }
    let kind: Kind
    let app: GatedApp

    private let screen = Color(hex: 0x1C1C1E)
    private let row = Color(hex: 0x2C2C2E)
    private let accent = Color(hex: 0x4F8EF7)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(screen)
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 6))
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
            content
                .padding(22)
        }
        .frame(maxWidth: 300)
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .tabs:
            VStack(spacing: 14) {
                titleBar("Automation")
                mockRow(icon: "plus", text: "New Automation", tint: accent)
                Spacer()
                HStack {
                    tab("square.stack.3d.up.fill", "Shortcuts", on: false)
                    tab("clock.badge.checkmark.fill", "Automation", on: true)
                    tab("square.grid.2x2.fill", "Gallery", on: false)
                }
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 16).fill(row))
            }
        case .triggers:
            VStack(spacing: 8) {
                titleBar("New Automation")
                mockRow(icon: "clock.fill", text: "Time of Day", tint: .orange)
                mockRow(icon: "alarm.fill", text: "Alarm", tint: .orange)
                mockRow(icon: "envelope.fill", text: "Email", tint: accent)
                mockRow(icon: "square.grid.3x3.fill", text: "App", tint: .purple, highlighted: true)
                mockRow(icon: "battery.75percent", text: "Battery Level", tint: .green)
            }
        case .appTrigger(let name):
            VStack(spacing: 8) {
                titleBar("When")
                mockRow(icon: "app.fill", text: "App: \(name)", tint: Color(hex: app.colorHex), highlighted: true)
                checkRow("Is Opened", on: true)
                checkRow("Is Closed", on: false)
                HStack(spacing: 0) {
                    segment("After Confirmation", on: false)
                    segment("Immediately", on: true)
                }
                .background(Capsule().fill(row))
                HStack {
                    Text("Notify When Run").font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    Spacer()
                    Capsule().fill(Color.gray.opacity(0.5)).frame(width: 40, height: 24)
                        .overlay(Circle().fill(.white).frame(width: 20).offset(x: -8))
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(row))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.gold, lineWidth: 2))
            }
        case .newShortcut:
            VStack(spacing: 14) {
                titleBar("Do")
                Spacer()
                Text("Create New Shortcut")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(accent))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.gold, lineWidth: 2))
                    .overlay(alignment: .bottomTrailing) { tapDot.offset(x: -30, y: 10) }
                Text("Or choose a starting action")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
        case .action(let intent):
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.5))
                    Text(AppConstants.appName).font(.system(size: 14)).foregroundStyle(.white)
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(row))
                HStack(spacing: 10) {
                    PrayToScrollMark(glow: false)
                        .frame(width: 20, height: 28)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.midnight))
                    Text(intent).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "plus.circle.fill").foregroundStyle(accent)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(row))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.gold, lineWidth: 2))
                .overlay(alignment: .trailing) { tapDot.offset(x: -4, y: 14) }
                HStack(spacing: 10) {
                    Image(systemName: "hands.and.sparkles.fill").foregroundStyle(Palette.gold).frame(width: 32)
                    Text("Pray Now").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(row))
                Spacer()
            }
        case .finished(let name, let intent):
            VStack(spacing: 12) {
                titleBar("Automation")
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "square.grid.3x3.fill").foregroundStyle(.purple).frame(width: 26)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("When \(name) is opened").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        Text(intent).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Capsule().fill(Color.green).frame(width: 40, height: 24)
                        .overlay(Circle().fill(.white).frame(width: 20).offset(x: 8))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(row))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.gold, lineWidth: 2))
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Palette.sage)
                Text("Protected").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Spacer()
            }
        }
    }

    private func titleBar(_ text: String) -> some View {
        HStack {
            Text(text).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Spacer()
        }
    }

    private func mockRow(icon: String, text: String, tint: Color, highlighted: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(tint))
            Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.35))
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 12).fill(row))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(highlighted ? Palette.gold : .clear, lineWidth: 2))
        .overlay(alignment: .trailing) { if highlighted { tapDot.offset(x: -36, y: 12) } }
    }

    private func checkRow(_ text: String, on: Bool) -> some View {
        HStack {
            Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
            Spacer()
            Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? accent : .white.opacity(0.3))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(row))
    }

    private func segment(_ text: String, on: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(on ? Color.black : .white.opacity(0.7))
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(Capsule().fill(on ? Color.white : .clear).padding(2))
            .overlay(Capsule().strokeBorder(on ? Palette.gold : .clear, lineWidth: 2).padding(1))
    }

    private func tab(_ icon: String, _ text: String, on: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 16))
            Text(text).font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(on ? accent : .white.opacity(0.45))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Palette.gold : .clear, lineWidth: 2))
        .overlay(alignment: .topTrailing) { if on { tapDot.offset(x: -8, y: 18) } }
    }

    private var tapDot: some View {
        Circle()
            .fill(Color.white.opacity(0.85))
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 6).scaleEffect(1.5))
            .shadow(color: .black.opacity(0.3), radius: 4)
    }
}
