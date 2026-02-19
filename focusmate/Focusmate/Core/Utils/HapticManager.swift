import UIKit

enum HapticManager {
  static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
  }

  static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(type)
  }

  static func selection() {
    let generator = UISelectionFeedbackGenerator()
    generator.selectionChanged()
  }

  /// Convenience methods
  static func success() {
    self.notification(.success)
  }

  static func error() {
    self.notification(.error)
  }

  static func warning() {
    self.notification(.warning)
  }

  static func light() {
    self.impact(.light)
  }

  static func medium() {
    self.impact(.medium)
  }

  static func heavy() {
    self.impact(.heavy)
  }
}
