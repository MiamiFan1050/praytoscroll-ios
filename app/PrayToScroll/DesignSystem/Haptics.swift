import UIKit

/// Central haptics. Respects the in-app haptics setting.
@MainActor
enum Haptics {
    static var enabled: Bool = true

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func tap() {
        guard enabled else { return }
        light.impactOccurred()
    }

    static func selection() {
        guard enabled else { return }
        selectionGenerator.selectionChanged()
    }

    static func prepareRamp() {
        guard enabled else { return }
        soft.prepare()
        rigid.prepare()
    }

    /// Called repeatedly while holding "Amen"; intensity rises from 0.2 to 1.
    static func ramp(_ progress: Double) {
        guard enabled else { return }
        let intensity = CGFloat(0.25 + 0.75 * min(1, max(0, progress)))
        if progress < 0.7 {
            soft.impactOccurred(intensity: intensity)
        } else {
            rigid.impactOccurred(intensity: intensity)
        }
    }

    static func success() {
        guard enabled else { return }
        notification.notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        notification.notificationOccurred(.warning)
    }
}
