import Foundation

final class UsersAPI {
    private let api: NewAPIClient
    init(api: NewAPIClient) { self.api = api }
    
    func updateDeviceToken(apns: String) async throws {
        _ = try await api.request("PATCH", API.Users.deviceToken,
                                  body: DeviceTokenBody(device: .init(platform: "ios", token: apns))) as Empty
    }
}
