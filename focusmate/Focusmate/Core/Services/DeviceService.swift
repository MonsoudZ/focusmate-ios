import Foundation
import UIKit

final class DeviceService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Device Management
    
    func registerDevice(pushToken: String? = nil) async throws -> DeviceRegistrationResponse {
        let deviceInfo = DeviceInfo(pushToken: pushToken)
        return try await apiClient.request("POST", "devices", body: deviceInfo)
    }
    
    func updateDeviceToken(_ token: String) async throws {
        let request = DeviceTokenUpdateRequest(pushToken: token)
        _ = try await apiClient.request("PUT", "devices/token", body: request) as EmptyResponse
    }
    
    // MARK: - Request/Response Models
    
    struct DeviceInfo: Codable {
        let platform: String
        let version: String
        let model: String
        let systemVersion: String
        let appVersion: String
        let pushToken: String?
        
        init(pushToken: String? = nil) {
            self.platform = "iOS"
            self.version = UIDevice.current.systemVersion
            self.model = UIDevice.current.model
            self.systemVersion = UIDevice.current.systemVersion
            self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            self.pushToken = pushToken
        }
    }
    
    struct DeviceRegistrationResponse: Codable {
        let device: Device
    }
    
    struct Device: Codable {
        let id: Int
        let platform: String
        let version: String
        let model: String
        let systemVersion: String
        let appVersion: String
        let pushToken: String?
        let isActive: Bool
        let createdAt: Date
        let updatedAt: Date
    }
    
    struct DeviceTokenUpdateRequest: Codable {
        let pushToken: String
    }
    
    struct EmptyResponse: Codable {}
}
