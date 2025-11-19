import Foundation

enum Endpoints {
  static let base: URL = {
    guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
          let url = URL(string: urlString)
    else {
      // Graceful fallback instead of crashing
      print("⚠️ CRITICAL: API_BASE_URL not found in Info.plist")
      print("⚠️ Using localhost fallback. Check xcconfig files and build configuration.")
      return URL(string: "http://localhost:3000")!
    }
    return url
  }()

  static func path(_ p: String) -> URL { self.base.appendingPathComponent(p) }
}
