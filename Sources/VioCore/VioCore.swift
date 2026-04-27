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

    /// Register a named placement instance — the explicit (name,
    /// componentType, locationId) tuple the partner app's UI implements.
    /// Replaces the implicit (component × location) cross-product that the
    /// older `registerPlacementComponent` + `registerPlacementLocation`
    /// pair declared.
    ///
    /// At app boot the SDK uploads these to
    /// `POST /v2/mobile/components/manifest`. The dashboard's "Add
    /// placement" picker lists exactly the registered placements (per
    /// clientApp), so an operator can never bind a `campaign_components`
    /// instance to a (component, location) combo the dev hasn't declared.
    ///
    /// Example:
    /// ```swift
    /// Vio.registerPlacement(
    ///     name: "Carrusel home",
    ///     type: TV2ProductCarouselPlacement.self,
    ///     locationId: "home_top",
    ///     locationDisplayName: "Home — Top"
    /// )
    /// ```
    ///
    /// Idempotent — same `name` re-registered overwrites the slot mapping;
    /// a second name claiming the same `(componentType, locationId)` slot
    /// is rejected (use a distinct `locationId` for A/B variants like
    /// `home_top_a`, `home_top_b`).
    @MainActor
    public static func registerPlacement<T: VioPlacementComponent>(
        name: String,
        type: T.Type,
        locationId: String,
        locationDisplayName: String? = nil
    ) {
        VioPlacementRegistry.shared.registerPlacement(
            name: name,
            type: type,
            locationId: locationId,
            locationDisplayName: locationDisplayName
        )
    }

    /// Register a placement component the partner app implements. Call this
    /// once at app boot for each component the SDK should know about. The
    /// manifest endpoint upserts the underlying `app_components` row(s) so
    /// the operator dashboard's "Add placement" picker only ever offers
    /// components this app actually has implementations for.
    ///
    /// Idempotent — re-registering the same `componentType` is a no-op.
    ///
    /// **Deprecated**: prefer `registerPlacement(name:type:locationId:)`
    /// which makes the (type, location) binding explicit. This method
    /// remains for backwards compat — the manifest endpoint still
    /// upserts `app_components` rows from this signal.
    @available(*, deprecated, message: "Prefer registerPlacement(name:type:locationId:) which declares the (type, location) binding explicitly. The dashboard picker reads from named placements; type-only registration leaves the binding implicit and lets the picker offer combos the app may not render.")
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
    ///
    /// **Deprecated**: prefer `registerPlacement(name:type:locationId:)`.
    /// The location is still registered in the legacy
    /// `app_component_locations` table for backwards compat.
    @available(*, deprecated, message: "Prefer registerPlacement(name:type:locationId:) which binds the location to a specific component name. Standalone location registration is kept for backwards compat with v1 manifest payloads.")
    @MainActor
    public static func registerPlacementLocation(_ location: VioPlacementLocation) {
        VioPlacementRegistry.shared.registerLocation(location)
    }
}
