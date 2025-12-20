import Foundation
import UIKit

final class DeviceService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func registerDevice(pushToken: String? = nil) async throws -> DeviceResponse {
        let deviceInfo = DeviceInfo(pushToken: pushToken)

        Logger.debug("DeviceService: Registering device", category: .api)

        let response: DeviceResponse = try await apiClient.request(
            "POST",
            API.Users.deviceToken,
            body: deviceInfo
        )

        Logger.info("DeviceService: Device registered with ID: \(response.id)", category: .api)
        return response
    }

    func removeDevice(id: Int) async throws {
        _ = try await apiClient.request(
            "DELETE",
            "\(API.Users.deviceToken)/\(id)",
            body: nil as String?
        ) as EmptyResponse
    }
}

// MARK: - Models

struct DeviceInfo: Codable {
    let platform: String
    let device_name: String
    let os_version: String
    let app_version: String
    let bundle_id: String
    let locale: String
    let apns_token: String?

    init(pushToken: String? = nil) {
        self.platform = "ios"
        self.device_name = UIDevice.current.model
        self.os_version = UIDevice.current.systemVersion
        self.app_version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.bundle_id = Bundle.main.bundleIdentifier ?? "com.focusmate.app"
        self.locale = Locale.current.identifier
        self.apns_token = pushToken
    }
}

struct DeviceResponse: Codable {
    let id: Int
    let platform: String
    let device_name: String
    let is_active: Bool
    let created_at: String
}
