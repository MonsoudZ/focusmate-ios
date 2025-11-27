import Foundation
import UIKit

final class DeviceService {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  // MARK: - Device Management

  func registerDevice(pushToken: String? = nil) async throws -> DeviceRegistrationResponse {
    #if DEBUG
    print("📱 DeviceService: Registering device with platform: ios")
    #endif
    #if DEBUG
    print("📱 DeviceService: Push token: \(pushToken ?? "nil")")
    #endif

    let deviceInfo = DeviceInfo(pushToken: pushToken)

    // Debug: Log the request payload
    do {
      let jsonData = try JSONEncoder().encode(deviceInfo)
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        #if DEBUG
        print("🔍 DeviceService: Sending device registration payload: \(jsonString)")
        #endif
      }
    } catch {
      #if DEBUG
      print("❌ DeviceService: Failed to encode device info: \(error)")
      #endif
    }

    // If no push token is available, we need to handle this gracefully
    if pushToken == nil {
      #if DEBUG
      print("⚠️ DeviceService: No APNS token available - this may cause registration to fail")
      #endif
      #if DEBUG
      print("⚠️ DeviceService: This is normal in simulator or when push notifications are not configured")
      #endif
    }

    do {
      // Try to decode as wrapped response first
      do {
        let response: DeviceRegistrationResponse = try await apiClient.request("POST", "devices", body: deviceInfo)
        #if DEBUG
        print("✅ DeviceService: Device registered successfully with ID: \(response.device.id)")
        #endif
        return response
      } catch {
        // If wrapped response fails, try direct device object
        #if DEBUG
        print("⚠️ DeviceService: Wrapped response failed, trying direct device object")
        #endif
        let device: Device = try await apiClient.request("POST", "devices", body: deviceInfo)
        let response = DeviceRegistrationResponse(device: device)
        #if DEBUG
        print("✅ DeviceService: Device registered successfully with ID: \(device.id)")
        #endif
        return response
      }
    } catch let apiError as APIError {
      // Suppress error logging for 422 validation errors (expected in development)
      if case .badStatus(422, _, _) = apiError {
        #if DEBUG
        print("ℹ️ DeviceService: Device registration skipped - validation failed")
        #endif
      } else {
        #if DEBUG
        print("⚠️ DeviceService: Device registration failed: \(apiError)")
        #endif
      }
      throw apiError
    } catch {
      #if DEBUG
      print("⚠️ DeviceService: Device registration failed: \(error)")
      #endif
      throw APIError.network(error)
    }
  }

  func updateDeviceToken(_ token: String) async throws {
    let request = DeviceTokenUpdateRequest(pushToken: token)
    _ = try await self.apiClient.request("PUT", "devices/token", body: request) as EmptyResponse
  }

  // MARK: - Request/Response Models

  struct DeviceInfo: Codable {
    let platform: String
    let device_name: String
    let os_version: String
    let app_version: String
    let bundle_id: String
    let locale: String
    let apns_token: String?

    enum CodingKeys: String, CodingKey {
      case platform, device_name, os_version, app_version
      case bundle_id, locale, apns_token
    }

    init(pushToken: String? = nil) {
      self.platform = "ios" // Use lowercase "ios" as required by Rails API
      self.device_name = UIDevice.current.model
      self.os_version = UIDevice.current.systemVersion
      self.app_version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
      self.bundle_id = Bundle.main.bundleIdentifier ?? "com.focusmate.dev"
      self.locale = Locale.current.identifier
      self.apns_token = pushToken
    }
  }

  struct DeviceRegistrationResponse: Codable {
    let device: Device
  }

  struct Device: Codable {
    let id: Int
    let platform: String
    let device_name: String
    let os_version: String
    let app_version: String
    let bundle_id: String
    let locale: String
    let apns_token: String?
    let is_active: Bool
    let created_at: String
    let updated_at: String

    enum CodingKeys: String, CodingKey {
      case id, platform, device_name, os_version, app_version
      case bundle_id, locale, apns_token, is_active
      case created_at, updated_at
    }
  }

  struct DeviceTokenUpdateRequest: Codable {
    let pushToken: String

    enum CodingKeys: String, CodingKey {
      case pushToken = "apns_token" // Map to apns_token for Rails API
    }
  }

  struct EmptyResponse: Codable {}
}
