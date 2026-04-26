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

    // MARK: - Placement registry (manifest upload)

    /// Register a placement component the partner app implements. Call this
    /// once at app boot for each component the SDK should know about. The
    /// manifest endpoint upserts the underlying `app_components` row(s) so
    /// the operator dashboard's "Add placement" picker only ever offers
    /// components this app actually has implementations for.
    ///
    /// Idempotent — re-registering the same `componentType` is a no-op.
    @MainActor
    public static func registerPlacementComponent<T: VioPlacementComponent>(_ type: T.Type) {
        VioPlacementRegistry.shared.register(type)
    }

    /// Register a placement slot location the partner's layout exposes. Call
    /// this once at app boot for each slot. The dashboard's location picker
    /// reads from these so an operator can never bind a `campaign_components`
    /// instance to a slot the dev's code doesn't actually render to.
    ///
    /// Idempotent — re-registering the same `id` updates the displayName
    /// (matches backend `INSERT ... ON CONFLICT DO UPDATE`).
    @MainActor
    public static func registerPlacementLocation(_ location: VioPlacementLocation) {
        VioPlacementRegistry.shared.registerLocation(location)
    }
}
