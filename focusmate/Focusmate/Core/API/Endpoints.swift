import Foundation

enum Endpoints {
  static let base: URL = {
    guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
          let url = URL(string: urlString)
    else {
      fatalError("API_BASE_URL not found in Info.plist")
    }
    return url
  }()

  static func path(_ p: String) -> URL { self.base.appendingPathComponent(p) }
}
