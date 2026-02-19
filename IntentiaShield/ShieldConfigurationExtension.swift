//
//  ShieldConfigurationExtension.swift
//  IntentiaShield
//
//  Created by Monsoud Zanaty on 1/13/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Override the functions below to customize the shields used in various situations.
/// The system provides a default appearance for any methods that your subclass doesn't override.
/// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  override func configuration(shielding application: Application) -> ShieldConfiguration {
    self.makeConfiguration()
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    self.makeConfiguration()
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    self.makeConfiguration()
  }

  override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
    self.makeConfiguration()
  }

  private func makeConfiguration() -> ShieldConfiguration {
    ShieldConfiguration(
      backgroundBlurStyle: .systemThickMaterial,
      backgroundColor: UIColor.systemBackground,
      icon: UIImage(systemName: "lock.fill"),
      title: ShieldConfiguration.Label(
        text: "App Blocked",
        color: UIColor.label
      ),
      subtitle: ShieldConfiguration.Label(
        text: "You have overdue tasks. Complete them in Intentia to unlock this app.",
        color: UIColor.secondaryLabel
      ),
      primaryButtonLabel: ShieldConfiguration.Label(
        text: "OK",
        color: UIColor.white
      ),
      primaryButtonBackgroundColor: UIColor.systemBlue
    )
  }
}
