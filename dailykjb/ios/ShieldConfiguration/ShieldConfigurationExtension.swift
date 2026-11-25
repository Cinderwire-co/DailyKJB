import ManagedSettings
import ManagedSettingsUI
import UIKit

/// What a closed app shows: the app's parchment and burnt orange, a line of
/// scripture, and a button that sends a notification to open DailyKJB (a
/// shield can't open another app itself).
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private static let parchment = UIColor(red: 0.953, green: 0.914, blue: 0.843, alpha: 1)
    private static let ink = UIColor(red: 0.165, green: 0.118, blue: 0.082, alpha: 1)
    private static let faded = UIColor(red: 0.486, green: 0.408, blue: 0.322, alpha: 1)
    private static let accent = UIColor(red: 0.753, green: 0.388, blue: 0.169, alpha: 1)

    private func shield(_ what: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: Self.parchment.withAlphaComponent(0.96),
            icon: UIImage(systemName: "book.closed.fill")?.withTintColor(Self.accent, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "The Word first", color: Self.ink),
            subtitle: ShieldConfiguration.Label(
                text: "\(what) opens once today's reading is done in DailyKJB.\n\n\"Seek ye first the kingdom of God.\" Matthew 6:33",
                color: Self.faded
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Read now", color: .white),
            primaryButtonBackgroundColor: Self.accent,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: Self.faded)
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shield(application.localizedDisplayName ?? "This app")
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shield(application.localizedDisplayName ?? "This app")
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shield(webDomain.domain ?? "This site")
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        shield(webDomain.domain ?? "This site")
    }
}
