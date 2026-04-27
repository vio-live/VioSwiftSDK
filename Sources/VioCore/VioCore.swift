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

    /// Register a slot location this app's layout exposes. Call once per
    /// slot at app boot.
    ///
    /// At cold-start the SDK uploads the registered locations to
    /// `POST /v2/mobile/components/manifest`. The dashboard's
    /// `/apps/:id` "Add from library" form lists these as the available
    /// locationIds when an operator/admin creates a named app placement.
    /// The operator can never bind a placement to a slot the dev hasn't
    /// declared here.
    ///
    /// Sync-semantic: locations not in a subsequent manifest payload are
    /// soft-deprecated server-side. Re-registering an existing id clears
    /// the deprecated flag.
    ///
    /// Example:
    /// ```swift
    /// Vio.registerPlacementLocation(VioPlacementLocation(
    ///     id: "home_top",
    ///     displayName: "Home — Top"
    /// ))
    /// ```
    ///
    /// Idempotent — re-registering the same `id` updates the
    /// `displayName` (matches backend `INSERT ... ON CONFLICT DO UPDATE`).
    @MainActor
    public static func registerPlacementLocation(_ location: VioPlacementLocation) {
        VioPlacementRegistry.shared.registerLocation(location)
    }
}
