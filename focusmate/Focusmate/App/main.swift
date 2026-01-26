import SwiftUI

if NSClassFromString("XCTestCase") == nil {
    FocusmateApp.main()
} else {
    TestHostApp.main()
}

/// Minimal app used when the process is hosted by XCTest.
/// Avoids creating AuthStore, keychain access, and EventBus
/// subscriptions that interfere with test isolation.
struct TestHostApp: App {
    var body: some Scene {
        WindowGroup { EmptyView() }
    }
}
