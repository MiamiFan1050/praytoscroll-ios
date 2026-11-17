import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The shield people see on a locked app: "Pray first".
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    private func make(name: String?) -> ShieldConfiguration {
        let cream = UIColor(hex: 0xFBF6EC)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(hex: 0x0E1726),
            icon: UIImage(systemName: "hands.and.sparkles.fill")?.withTintColor(UIColor(hex: 0xE9B949), renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "Pray first", color: cream),
            subtitle: ShieldConfiguration.Label(text: "\(name ?? "This app") opens after a short prayer.\nKnees before feeds.", color: cream.withAlphaComponent(0.75)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Pray now", color: UIColor(hex: 0x0E1726)),
            primaryButtonBackgroundColor: UIColor(hex: 0xE9B949),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Not now", color: cream.withAlphaComponent(0.7))
        )
    }
}
