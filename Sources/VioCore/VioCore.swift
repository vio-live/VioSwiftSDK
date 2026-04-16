import Foundation

// Export Product models for easy access
public typealias VioProduct = Product
public typealias VioPrice = Price
public typealias VioVariant = Variant
public typealias VioProductImage = ProductImage

// Export Configuration system for easy access
public typealias VioSDKConfiguration = VioConfiguration
public typealias VioSDKTheme = VioTheme
public typealias VioCartConfiguration = CartConfiguration
public typealias VioNetworkConfiguration = NetworkConfiguration
public typealias VioUIConfiguration = UIConfiguration
public typealias VioConfigurationLoader = ConfigurationLoader

// Export Logger
public typealias VioSDKLogger = VioLogger

// Export Cache Manager
public typealias VioSDKCacheManager = CacheManager

// Export runtime session orchestrator
public typealias VioSDKSession = VioSession

/// Minimal host-facing runtime contract for SDK-first integration.
public enum VioRuntime {
    @MainActor
    public static func startSession(broadcastId: String? = nil) async {
        await VioSession.shared.start(broadcastId: broadcastId)
    }

    @MainActor
    public static func refreshSession() async {
        await VioSession.shared.refresh()
    }

    @MainActor
    public static func stopSession() {
        VioSession.shared.stop()
    }

    @MainActor
    public static func setUserContext(userId: String?) {
        VioSession.shared.setUserContext(userId: userId)
    }

    @MainActor
    public static func submitPushToken(_ tokenHex: String) {
        VioSession.shared.submitPushToken(tokenHex)
    }

    @MainActor
    public static func ensureCommerceReady() async {
        await VioSession.shared.ensureCommerceBootstrapApplied()
    }
}
