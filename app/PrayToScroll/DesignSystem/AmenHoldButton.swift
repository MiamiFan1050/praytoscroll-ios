import SwiftUI

/// The signature moment. Press and hold for 1.2 s: the ring fills with gold, the key turns in its lock,
/// the haptics rise, and on release of the last moment the door opens.
struct HoldToConfirmButton: View {
    var duration: Double = 1.2
    var size: CGFloat = 148
    var isEnabled: Bool = true
    var disabledLabel: String = ""
    var idleLabel: String = "Hold to say Amen"
    var holdingLabel: String = "Amen…"
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0
    @State private var isHolding = false
    @State private var completed = false
    @State private var burst = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                // Halo that grows as you hold.
                Circle()
                    .fill(RadialGradient(colors: [Palette.gold.opacity(0.18 + 0.42 * progress), .clear],
                                         center: .center, startRadius: size * 0.2, endRadius: size * (0.75 + 0.25 * progress)))
                    .frame(width: size * 1.9, height: size * 1.9)
                    .opacity(isEnabled ? 1 : 0.3)

                // Rays that unfold around the key.
                ForEach(0..<16, id: \.self) { i in
                    Capsule()
                        .fill(Palette.warmGold.opacity(0.55))
                        .frame(width: 2.5, height: size * 0.09)
                        .offset(y: -size * (0.62 + 0.06 * progress))
                        .rotationEffect(.degrees(Double(i) * 22.5))
                        .opacity(progress > Double(i) / 16 ? 0.9 : 0.0)
                }

                // Burst ring on completion.
                Circle()
                    .stroke(Palette.warmGold, lineWidth: 3)
                    .frame(width: size, height: size)
                    .scaleEffect(burst ? 1.9 : 1)
                    .opacity(burst ? 0 : (completed ? 1 : 0))

                // Track + progress.
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    .frame(width: size, height: size)
                Circle()
                    .trim(from: 0, to: max(0.0001, progress))
                    .stroke(AngularGradient(colors: [Palette.warmGold, Palette.gold, Color.white, Palette.warmGold],
                                            center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
                    .shadow(color: Palette.gold.opacity(0.8), radius: 8)

                // The keyhole disc.
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x22345A), Palette.ink, Palette.midnightDeep],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(
                        LinearGradient(colors: [Palette.warmGold.opacity(0.7), Palette.gold.opacity(0.15)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.5))
                    .frame(width: size - 22, height: size - 22)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 6)

                PrayToScrollMark(glow: progress > 0.05 || completed)
                    .frame(height: size * 0.5)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : progress * 72), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .scaleEffect(completed ? 1.08 : 1 - 0.04 * (isHolding ? 1 : 0))
                    .opacity(isEnabled ? 1 : 0.45)
            }
            .frame(width: size * 1.35, height: size * 1.35)
            .scaleEffect(isHolding ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isHolding)
            .contentShape(Circle().inset(by: -10))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginHold() }
                    .onEnded { _ in endHold() }
            )

            Text(label)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(isEnabled ? Palette.warmGold : Palette.cream.opacity(0.6))
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: label)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Amen")
        .accessibilityValue(isEnabled ? "" : disabledLabel)
        .accessibilityHint(isEnabled ? "Double-tap to finish your prayer and unlock" : "Keep praying a little longer")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("amenButton")
        .accessibilityAction {
            if isEnabled { complete() }
        }
        .onDisappear { holdTask?.cancel() }
    }

    private var label: String {
        if completed { return "Amen" }
        if !isEnabled { return disabledLabel }
        return isHolding ? holdingLabel : idleLabel
    }

    private func beginHold() {
        guard !isHolding, !completed else { return }
        guard isEnabled else {
            Haptics.warning()
            return
        }
        isHolding = true
        Haptics.prepareRamp()
        let start = Date()
        let startProgress = progress
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            var lastHaptic = Date.distantPast
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                let value = min(1, startProgress + elapsed / duration)
                progress = value
                let hapticGap = 0.14 - 0.09 * value
                if Date().timeIntervalSince(lastHaptic) >= hapticGap {
                    Haptics.ramp(value)
                    lastHaptic = Date()
                }
                if value >= 1 {
                    complete()
                    return
                }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    private func endHold() {
        guard isHolding else { return }
        isHolding = false
        holdTask?.cancel()
        holdTask = nil
        guard !completed else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { progress = 0 }
    }

    private func complete() {
        guard !completed else { return }
        holdTask?.cancel()
        holdTask = nil
        isHolding = false
        completed = true
        progress = 1
        Haptics.success()
        withAnimation(.easeOut(duration: 0.7)) { burst = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.1 : 0.45)) {
            onComplete()
        }
    }
}
