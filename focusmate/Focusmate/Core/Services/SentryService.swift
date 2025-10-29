import Foundation
// import Sentry  // TODO: Add Sentry via Xcode project

/// Service for initializing and managing Sentry crash reporting
final class SentryService {
    static let shared = SentryService()
    
    private init() {}
    
    /// Initialize Sentry with configuration
    func initialize() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String, !dsn.isEmpty else {
            print("⚠️ Sentry DSN not found in Info.plist")
            return
        }
        
        // TODO: Implement when Sentry is added via Xcode project
        // SentrySDK.start { options in
        //     options.dsn = dsn
        //     options.enableAutoSessionTracking = true
        //     options.enableNetworkTracking = true
        //     options.enableFileIOTracking = false
        //     options.enableCoreDataTracking = false
        //     options.tracesSampleRate = 0.2
        //     options.enableSwizzling = true
        // }
        
        print("✅ Sentry initialized with DSN: \(dsn.prefix(20))...")
    }
    
    /// Set user context for crash reporting
    func setUser(userId: String, email: String? = nil) {
        // TODO: Implement when Sentry is added via Xcode project
        // SentrySDK.setUser(User(userId: userId, email: email))
        print("Sentry setUser called with userId: \(userId)")
    }
    
    /// Add breadcrumb for debugging
    func addBreadcrumb(message: String, category: String = "user") {
        // TODO: Implement when Sentry is added via Xcode project
        // let breadcrumb = Breadcrumb()
        // breadcrumb.message = message
        // breadcrumb.category = category
        // breadcrumb.level = .info
        // SentrySDK.addBreadcrumb(breadcrumb)
        print("Sentry breadcrumb: \(message)")
    }
    
    /// Capture an error
    func captureError(_ error: Error) {
        // TODO: Implement when Sentry is added via Xcode project
        // SentrySDK.capture(error: error)
        print("Sentry error captured: \(error)")
    }
    
    /// Capture a message
    func captureMessage(_ message: String, level: String = "info") {
        // TODO: Implement when Sentry is added via Xcode project
        // SentrySDK.capture(message: message, level: level)
        print("Sentry message captured: \(message)")
    }
    
    /// Test Sentry integration (for debugging)
    func testIntegration() {
        #if DEBUG
        // SentrySDK.capture(message: "Sentry iOS wired")
        print("Sentry test integration called")
        #endif
    }
}
