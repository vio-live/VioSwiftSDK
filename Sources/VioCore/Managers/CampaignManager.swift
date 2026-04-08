import Foundation
import Combine

/// Global Campaign Manager for handling campaign lifecycle
/// Manages campaign states, WebSocket connections, and component visibility
@MainActor
public class CampaignManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = CampaignManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isCampaignActive: Bool = true  // Default to true (no campaign restrictions)
    @Published public private(set) var campaignState: CampaignState = .active
    @Published public private(set) var activeComponents: [Component] = []
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var currentCampaign: Campaign?
    @Published public private(set) var currentBroadcastContext: BroadcastContext?  // Current broadcast context for filtering
    
    // Backward compatibility property
    @available(*, deprecated, renamed: "currentBroadcastContext")
    public var currentMatchContext: BroadcastContext? {
        get { currentBroadcastContext }
        set { currentBroadcastContext = newValue }
    }
    @Published public private(set) var activeCampaigns: [Campaign] = []  // Multiple campaigns support
    /// Latest `cart_intent` from the campaign WebSocket for this `userId` (shoppable / second-screen).
    @Published public private(set) var activeCartIntentEvent: CartIntentEvent? = nil
    
    // MARK: - Private Properties
    private var webSocketManager: CampaignWebSocketManager?
    
    /// User ID passed to WebSocket for targeted notifications (wsUserMap).
    /// Set before calling `discoverCampaigns`.
    /// Example: `CampaignManager.shared.userId = jwtPayload.sub`
    public var userId: String?
    /// When `true` (default), schedules a **local** notification for WebSocket `cart_intent` even while the app is **active**, so the banner appears together with the overlay. Set `false` to skip local notifications in foreground (overlay only).
    public var showsCartIntentLocalNotificationWhenAppIsActive: Bool = true
    /// Zero-config: APNs hex from the app; `register-device` runs only after `discoverCampaigns` sets `currentCampaign`.
    private var pendingApnsDeviceTokenHex: String?
    private var pendingSponsorLogoUrl: String? = nil  // Set from dynamic config, applied when Campaign is created
    
    /// Called when backend sends a `lineup_show` WS event.
    /// Set this from VioCastingUI layer (LineupTimelineHandler) — avoids cross-module dependency.
    public var onLineupShow: ((LineupShowEvent) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var baseURL: String  // For REST API (GraphQL base URL)
    private var isInitializing = false  // Flag to prevent multiple simultaneous initializations
    
    // Campaign endpoints from configuration
    private var campaignWebSocketBaseURL: String {
        VioConfiguration.shared.wsBaseURL
    }
    
    private var campaignRestAPIBaseURL: String {
        VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
    }
    
    // MARK: - Initialization
    private init() {
        // Get base URL from configuration
        let config = VioConfiguration.shared
        self.baseURL = config.environment.graphQLURL
            .replacingOccurrences(of: "/graphql", with: "")
            .replacingOccurrences(of: "/v1/graphql", with: "")
        
        // Zero-config: campaign id comes from GET /v1/sdk/campaigns after discoverCampaigns.
        self.isCampaignActive = true
        self.campaignState = .active
        VioLogger.debug("CampaignManager ready — call discoverCampaigns for campaign resolution", component: "CampaignManager")
    }
    
    // MARK: - Partner APNs registration (zero-config)
    
    /// Queues the APNs device token and attempts `POST .../register-device` when `currentCampaign` exists (after `discoverCampaigns`).
    /// Call from `AppDelegate`; do not pass a campaign id — it comes from `GET /v1/sdk/campaigns` like the rest of the SDK.
    public func submitApnsDeviceTokenForVioRegister(_ deviceTokenHex: String) {
        let trimmed = deviceTokenHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingApnsDeviceTokenHex = trimmed
        Task { await self.flushPendingApnsDeviceTokenRegistrationWithVio() }
    }
    
    private func flushPendingApnsDeviceTokenRegistrationWithVio() async {
        guard let hex = pendingApnsDeviceTokenHex, !hex.isEmpty else { return }
        guard let campaignId = currentCampaign?.id, campaignId > 0 else { return }
        let uid = userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !uid.isEmpty else {
            VioLogger.warning("APNs register-device skipped: set CampaignManager.userId before or with discovery", component: "CampaignManager")
            return
        }
        let src = campaignRestAPIBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let tokenLog: String = {
            let len = hex.count
            if len <= 16 { return "hex len=\(len) (short)" }
            return "hex len=\(len) prefix=\(hex.prefix(8))…suffix=\(hex.suffix(8))"
        }()
        print("🎯 [CampaignManager] register-device    APNs token: \(tokenLog)")
        #if DEBUG
        print("🎯 [CampaignManager] register-device    APNs token (DEBUG full): \(hex)")
        #endif
        print("🎯 [CampaignManager] register-device → POST \(src)/api/campaigns/\(campaignId)/register-device (x-api-key)")
        print("🎯 [CampaignManager] register-device    esperado: HTTP 200, { \"success\": true } (+ forward al partner en servidor si está configurado)")
        do {
            try await VioCampaignPartnerAPI.registerDevice(
                campaignId: campaignId,
                userId: uid,
                deviceToken: hex,
                platform: "ios"
            )
            pendingApnsDeviceTokenHex = nil
            print("🎯 [CampaignManager] register-device ← OK (token entregado al backend para campaign \(campaignId))")
        } catch {
            print("🎯 [CampaignManager] register-device ← fallo: \(error.localizedDescription)")
            VioLogger.error("APNs register-device failed: \(error.localizedDescription)", component: "CampaignManager")
        }
    }
    
    // MARK: - Public Methods
    
    /// Reinitialize campaign manager with current configuration
    /// Called automatically when VioConfiguration is updated
    public func reinitialize() {
        VioLogger.debug("Reinitializing", component: "CampaignManager")
        disconnect()
        pendingApnsDeviceTokenHex = nil
        
        let config = VioConfiguration.shared
        
        // Update base URL
        self.baseURL = config.environment.graphQLURL
            .replacingOccurrences(of: "/graphql", with: "")
            .replacingOccurrences(of: "/v1/graphql", with: "")
        
        self.isCampaignActive = true
        self.campaignState = .active
        self.activeComponents.removeAll()
        VioLogger.debug("Reinitialized — run discoverCampaigns to resolve campaign", component: "CampaignManager")
    }
    
    /// Initialize campaign connection (called automatically if campaignId > 0)
    public func initializeCampaign() async {
        guard let campaignId = currentCampaign?.id, campaignId > 0 else {
            print("🎯 [CampaignManager] initializeCampaign - No discovered campaignId, skipping")
            return
        }
        
        // Prevent multiple simultaneous initializations
        guard !isInitializing else {
            // Campaign initialization already in progress, skip
            print("🎯 [CampaignManager] initializeCampaign - Already initializing, skipping")
            return
        }
        
        isInitializing = true
        defer { 
            isInitializing = false
            print("🎯 [CampaignManager] initializeCampaign - Completed, isInitializing set to false")
        }
        
        print("🎯 [CampaignManager] initializeCampaign - Starting initialization for campaignId: \(campaignId)")
        
        // Commerce GraphQL credentials from GET /v1/sdk/config (no local commerce key required)
        await fetchAndApplySdkBootstrap(usingSdkApiKey: VioConfiguration.shared.resolvedSdkApiKey)
        
        // 0. Load dynamic configuration from backend
        var dynamicSponsorLogoUrl: String? = nil
        if let config = await DynamicConfigurationManager.shared.loadCampaignConfig(
            campaignId: campaignId,
            broadcastId: currentBroadcastContext?.broadcastId
        ) {
            // Update VioConfiguration with dynamic config
            if let brandConfig = config.brand {
                VioConfiguration.shared.updateDynamicBrandConfig(brandConfig)
                dynamicSponsorLogoUrl = brandConfig.logoUrl
                pendingSponsorLogoUrl = brandConfig.logoUrl  // Used by fetchCampaignInfo to set Campaign.campaignLogo
            }
            if let engagementConfig = config.engagement {
                VioConfiguration.shared.updateDynamicEngagementConfig(engagementConfig)
            }
            print("🎯 [CampaignManager] initializeCampaign - Loaded dynamic config for campaignId: \(campaignId), sponsorLogo: \(dynamicSponsorLogoUrl ?? "nil")")
        }
        
        // 0.5. Load from cache first for instant UI update
        loadFromCache()
        
        // 1. Fetch campaign info and determine initial state
        print("🎯 [CampaignManager] initializeCampaign - Calling fetchCampaignInfo...")
        await fetchCampaignInfo(campaignId: campaignId)
        print("🎯 [CampaignManager] initializeCampaign - fetchCampaignInfo completed")
        
        // 2. Connect WebSocket for real-time updates
        // According to backend behavior:
        // - If Ended: Backend sends campaign_ended immediately
        // - If Upcoming: No event sent, waits for campaign_started
        // - If Active: No event sent, can fetch components
        await connectWebSocket(campaignId: campaignId)
        
        // 3. Fetch active components ONLY if campaign is active AND not paused
        // Don't fetch if Upcoming (wait for campaign_started), Ended (already handled), or Paused
        if campaignState == .active && isCampaignActive && currentCampaign?.isPaused != true {
            await fetchActiveComponents(campaignId: campaignId)
        }
    }
    
    /// Set the current broadcast context for filtering campaigns and components
    /// This filters automatically to show only components for the specified broadcast
    public func setBroadcastContext(_ context: BroadcastContext) async {
        print("🎯 [CampaignManager] setBroadcastContext - Setting context: \(context.broadcastId)")
        
        // Clear components from previous context
        self.activeComponents.removeAll()
        
        // Set new context
        self.currentBroadcastContext = context
        
        // Load engagement config for this broadcast
        if let engagementConfig = await DynamicConfigurationManager.shared.loadEngagementConfig(broadcastId: context.broadcastId) {
            VioConfiguration.shared.updateDynamicEngagementConfig(engagementConfig)
            print("🎯 [CampaignManager] setBroadcastContext - Loaded engagement config for broadcastId: \(context.broadcastId)")
        }
        
        // Reload campaigns and components for this context
        await refreshCampaignsForContext(context)
    }
    
    /// Refresh campaigns and components for a specific broadcast context
    private func refreshCampaignsForContext(_ context: BroadcastContext) async {
        await discoverCampaigns(broadcastId: context.broadcastId)
        
        // Filter components by context
        filterComponentsByContext(context)
    }
    
    /// Filter active components by broadcast context
    /// Components without broadcastContext are shown for all broadcasts (backward compatibility)
    private func filterComponentsByContext(_ context: BroadcastContext) {
        let allComponents = self.activeComponents
        self.activeComponents = allComponents.filter { component in
            // Include components without broadcastContext (backward compatibility)
            guard let componentBroadcastId = component.broadcastContext?.broadcastId else {
                return true  // Show components without broadcastContext for all broadcasts
            }
            // Include components that match the current broadcastId
            return componentBroadcastId == context.broadcastId
        }
        print("🎯 [CampaignManager] filterComponentsByContext - Filtered to \(self.activeComponents.count) components for broadcastId: \(context.broadcastId)")
    }
    
    /// Get components for a specific broadcast context
    /// Components without broadcastContext are included for backward compatibility
    public func getComponents(for context: BroadcastContext) -> [Component] {
        return activeComponents.filter { component in
            // Include components without broadcastContext (backward compatibility)
            guard let componentBroadcastId = component.broadcastContext?.broadcastId else {
                return true  // Show components without broadcastContext for all broadcasts
            }
            return componentBroadcastId == context.broadcastId
        }
    }
    
    // Backward compatibility methods
    // Note: MatchContext is a typealias of BroadcastContext, so getComponents(for:) automatically works for both
    // We only need to provide a deprecated method for setMatchContext to show the migration path
    @available(*, deprecated, renamed: "setBroadcastContext(_:)")
    public func setMatchContext(_ context: MatchContext) async {
        // MatchContext is a typealias, so we can pass it directly
        await setBroadcastContext(context)
    }
    
    /// Check if a component should be displayed based on campaign state and context
    public func shouldShowComponent(type: String) -> Bool {
        // If no campaign discovered yet, show everything
        guard let cid = currentCampaign?.id, cid > 0 else {
            return true
        }
        
        // Campaign must be active
        guard isCampaignActive else {
            return false
        }
        
        // Check if component type is active
        let component = activeComponents.first { $0.type == type }
        
        // If we have a currentBroadcastContext, verify component belongs to it
        if let context = currentBroadcastContext {
            guard let componentBroadcastId = component?.broadcastContext?.broadcastId else {
                // Component without broadcastContext should not be shown when context is active
                return false
            }
            guard componentBroadcastId == context.broadcastId else {
                // Component belongs to different broadcast
                return false
            }
        }
        
        return component?.isActive ?? false
    }
    
    /// Get active component by type
    /// - Parameters:
    ///   - type: Component type (e.g., "product_spotlight", "product_carousel")
    ///   - componentId: Optional component ID to identify a specific component. If nil, returns the first matching component.
    /// - Returns: Active component matching the type and optional componentId, or nil if not found
    public func getActiveComponent(type: String, componentId: String? = nil, locationId: String? = nil) -> Component? {
        guard isCampaignActive else { return nil }
        
        if let locationId = locationId {
            // Search by locationId first (preferred — slot system)
            return activeComponents.first {
                $0.type == type && $0.locationId == locationId && $0.isActive
            }
        } else if let componentId = componentId {
            // Search by type AND specific componentId
            return activeComponents.first { 
                $0.type == type && $0.id == componentId && $0.isActive 
            }
        } else {
            // Return the first one found
            return activeComponents.first { $0.type == type && $0.isActive }
        }
    }
    
    /// Get all active components by type
    public func getActiveComponents(type: String) -> [Component] {
        guard isCampaignActive else { return [] }
        return activeComponents.filter { $0.type == type && $0.isActive }
    }
    
    /// Clears cart intent UI state (e.g. after dismiss or when leaving the session).
    public func dismissCartIntent() {
        activeCartIntentEvent = nil
    }
    
    /// Preferred entry point for **remote or local** notification taps: reads `vio_notification_version` / `vio_event_type`, then dispatches.
    /// Falls back to legacy `vio_cartIntent_kind` when `vio_event_type` is absent.
    /// Call after `discoverCampaigns` when possible so commerce bootstrap is ready for `ProductService`.
    public func handlePushNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard let resolved = Self.resolveVioEventType(from: userInfo) else {
            VioLogger.warning("Vio notification missing \(VioNotificationUserInfoKeys.eventType) and no legacy cart_intent marker", component: "CampaignManager")
            return
        }
        switch resolved {
        case VioPushEventType.cartIntent.rawValue:
            print("🎯 [CampaignManager] handlePushNotificationUserInfo → cart_intent (siguiente paso: commerce bootstrap + ProductService en overlay)")
            applyCartIntentFromNotificationUserInfo(userInfo)
        default:
            VioLogger.debug("Unhandled vio_event_type: \(resolved)", component: "CampaignManager")
        }
    }
    
    /// Legacy convenience: applies cart-intent UI state without envelope routing (caller guarantees type).
    /// Prefer ``handlePushNotificationUserInfo(_:)`` for APNs / unified handling.
    public func presentCartIntentFromNotification(userInfo: [AnyHashable: Any]) {
        applyCartIntentFromNotificationUserInfo(userInfo)
    }
    
    /// Returns whether `userInfo` should be treated as a Vio cart-intent notification (canonical or legacy).
    public static func isVioCartIntentNotificationUserInfo(_ userInfo: [AnyHashable: Any]) -> Bool {
        if let t = userInfo[VioNotificationUserInfoKeys.eventType] as? String,
           t == VioPushEventType.cartIntent.rawValue {
            return true
        }
        if userInfo[CartIntentNotificationKeys.kind] as? String == CartIntentNotificationKeys.kindValueCartIntent {
            return true
        }
        if hasVioPayloadProductId(in: userInfo) {
            return true
        }
        return false
    }

    /// True if `vio_payload` exists and carries a product id (canonical APNs shape).
    private static func hasVioPayloadProductId(in userInfo: [AnyHashable: Any]) -> Bool {
        var top: [String: Any] = [:]
        for (k, v) in userInfo {
            guard let ks = k as? String else { continue }
            top[ks] = v
        }
        guard let payload = normalizedVioPayloadDict(from: top) else { return false }
        let pid = payload["product_id"] ?? payload["productId"]
        if let s = pid as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if let n = pid as? NSNumber { return true }
        if let i = pid as? Int { return true }
        return false
    }

    private static func normalizedVioPayloadDict(from top: [String: Any]) -> [String: Any]? {
        if let p = top["vio_payload"] as? [String: Any] { return p }
        if let s = top["vio_payload"] as? String,
           let d = s.data(using: .utf8),
           let o = try? JSONSerialization.jsonObject(with: d, options: []) as? [String: Any] {
            return o
        }
        return nil
    }
    
    /// Resolves `vio_event_type`, or legacy cart_intent when only older keys are present.
    private static func resolveVioEventType(from userInfo: [AnyHashable: Any]) -> String? {
        if let raw = userInfo[VioNotificationUserInfoKeys.eventType] as? String,
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if userInfo[CartIntentNotificationKeys.kind] as? String == CartIntentNotificationKeys.kindValueCartIntent {
            return VioPushEventType.cartIntent.rawValue
        }
        var top: [String: Any] = [:]
        for (k, v) in userInfo {
            guard let ks = k as? String else { continue }
            top[ks] = v
        }
        if normalizedVioPayloadDict(from: top) != nil, hasVioPayloadProductId(in: userInfo) {
            return VioPushEventType.cartIntent.rawValue
        }
        return nil
    }
    
    private func applyCartIntentFromNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard let base = CartIntentEvent.from(userInfo: userInfo) else {
            VioLogger.warning(
                "cart_intent notification missing product id (revisar vio_payload.product_id, \(CartIntentNotificationKeys.productId), productId o deeplink vio://)",
                component: "CampaignManager",
            )
            print("🎯 [CampaignManager] cart_intent [push/local] parse fallido — userInfo no contiene id de producto reconocible")
            return
        }
        let notifTitle = base.notificationTitle ?? Self.apsAlertTitleFromUserInfo(userInfo)
        let notifBody = base.notificationBody ?? Self.apsAlertBodyFromUserInfo(userInfo)
        let merged = CartIntentEvent(
            type: base.type,
            productName: base.productName,
            productId: base.productId,
            campaignId: base.campaignId,
            notificationTitle: notifTitle,
            notificationBody: notifBody,
            vioUserId: base.vioUserId,
            source: base.source,
            deeplink: base.deeplink
        )
        activeCartIntentEvent = merged
        if let envUid = merged.vioUserId?.trimmingCharacters(in: .whitespacesAndNewlines), !envUid.isEmpty,
           let appUid = userId?.trimmingCharacters(in: .whitespacesAndNewlines), !appUid.isEmpty,
           envUid != appUid {
            print("🎯 [CampaignManager] cart_intent ⚠️ vio_user_id=\(envUid) distinto de CampaignManager.userId=\(appUid) (demo: revisar routing)")
        }
        let pid = merged.productId ?? ""
        print("🎯 [CampaignManager] cart_intent aplicado [push/local] productId=\(pid) campaignId=\(merged.campaignId.map(String.init) ?? "nil") name=\(merged.productName ?? "nil") title=\(notifTitle ?? "nil") → activeCartIntentEvent (overlay + commerce GraphQL)")
    }
    
    private static func apsAlertTitleFromUserInfo(_ userInfo: [AnyHashable: Any]) -> String? {
        guard let aps = userInfo["aps"] as? [String: Any] else { return nil }
        if let alert = aps["alert"] as? [String: Any] { return alert["title"] as? String }
        return nil
    }
    
    private static func apsAlertBodyFromUserInfo(_ userInfo: [AnyHashable: Any]) -> String? {
        guard let aps = userInfo["aps"] as? [String: Any] else { return nil }
        if let alert = aps["alert"] as? [String: Any] { return alert["body"] as? String }
        if let alertStr = aps["alert"] as? String { return alertStr }
        return nil
    }
    
    private static func stringFromUserInfo(_ userInfo: [AnyHashable: Any], key: String) -> String? {
        if let s = userInfo[key] as? String { return s }
        if let n = userInfo[key] as? Int { return String(n) }
        if let n = userInfo[key] as? NSNumber { return n.stringValue }
        return nil
    }

    /// Pretty-prints `GET /v1/sdk/config` JSON for logs with secrets redacted (commerce keys, etc.).
    private static func sdkConfigJSONRedactedForLogs(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
        let redacted = redactSecretsInJSONObject(root)
        guard JSONSerialization.isValidJSONObject(redacted),
              let out = try? JSONSerialization.data(withJSONObject: redacted, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: out, encoding: .utf8)
        else { return nil }
        return s
    }

    private static func redactSecretsInJSONObject(_ any: Any) -> Any {
        if var dict = any as? [String: Any] {
            for (k, v) in dict {
                let lower = k.lowercased()
                if lower.contains("apikey") || lower == "authorization" || lower.contains("api_key") || lower.contains("secret") {
                    if let s = v as? String, !s.isEmpty {
                        dict[k] = "<redacted len=\(s.count) prefix=\(String(s.prefix(8)))…>"
                    } else {
                        dict[k] = "<redacted>"
                    }
                } else {
                    dict[k] = redactSecretsInJSONObject(v)
                }
            }
            return dict
        }
        if let arr = any as? [Any] {
            return arr.map { redactSecretsInJSONObject($0) }
        }
        return any
    }
    
    /// Disconnect from campaign
    public func disconnect() {
        webSocketManager?.disconnect()
        webSocketManager = nil
        isConnected = false
        activeCartIntentEvent = nil
    }
    
    /// Close only the campaign WebSocket (keeps `currentCampaign` and components). Call from
    /// `applicationDidEnterBackground` so the backend removes this `userId` from `wsUserMap` and
    /// `POST .../cart-intent` can use the **push/webhook** path while the user is in another app.
    /// Pair with ``resumeWebSocketIfNeeded()`` on return to foreground.
    public func suspendWebSocketForBackground() {
        webSocketManager?.disconnect()
        webSocketManager = nil
        isConnected = false
        VioLogger.debug(
            "WebSocket suspended for background — server can deliver cart_intent via APNs/webhook",
            component: "CampaignManager",
        )
    }
    
    /// Reconnect WebSocket after ``suspendWebSocketForBackground()``.
    public func resumeWebSocketIfNeeded() async {
        guard let activeCampaign = currentCampaign,
              activeCampaign.isPaused != true,
              activeCampaign.id > 0
        else { return }
        await connectWebSocket(campaignId: activeCampaign.id)
    }
    
    // MARK: - Private Methods
    
    /// Load campaign and components from cache for instant UI update
    private func loadFromCache() {
        let config = VioConfiguration.shared
        let currentCampaignId = currentCampaign?.id ?? 0
        let currentApiKey = config.campaignConfiguration.campaignAdminApiKey.isEmpty 
            ? (config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey)
            : config.campaignConfiguration.campaignAdminApiKey
        let currentBaseURL = self.baseURL
        
        // Validate cache configuration BEFORE loading anything
        let validation = CacheManager.shared.validateCacheConfiguration(
            currentCampaignId: currentCampaignId,
            currentCampaignAdminApiKey: currentApiKey,
            currentBaseURL: currentBaseURL
        )
        
        if validation.shouldClearCache {
            // Configuration changed or version mismatch - clear cache and hide components
            print("🎯 [CampaignManager] loadFromCache - Configuration changed, clearing cache and hiding components")
            CacheManager.shared.clearCache()
            self.currentCampaign = nil
            self.campaignState = .active
            self.isCampaignActive = false  // Hide all SDK components
            self.activeComponents.removeAll()
            return
        }
        
        // Configuration matches - safe to load from cache
        // But wrap in do-catch for error recovery
        do {
            // Load campaign
            if let cachedCampaign = CacheManager.shared.loadCampaign() {
                self.currentCampaign = cachedCampaign
                self.campaignState = cachedCampaign.currentState
            }
            
            // Load campaign state
            if let cachedState = CacheManager.shared.loadCampaignState() {
                self.campaignState = cachedState.state
                self.isCampaignActive = cachedState.isActive
            }
            
            // Load components ONLY if campaign is active
            // Also filter by currentMatchContext if set
            if isCampaignActive {
                let cachedComponents = CacheManager.shared.loadComponents()
                
                // Filter by broadcastContext if currentBroadcastContext is set
                if let context = currentBroadcastContext {
                    let filteredComponents = cachedComponents.filter { component in
                        guard let componentBroadcastId = component.broadcastContext?.broadcastId else {
                            // If component has no broadcastContext, don't show it when context is active (security)
                            return false
                        }
                        return componentBroadcastId == context.broadcastId
                    }
                    self.activeComponents = filteredComponents
                } else {
                    // No context set - show all components (legacy mode)
                    self.activeComponents = cachedComponents
                }
            } else {
                // Campaign not active - ensure components are cleared
                self.activeComponents.removeAll()
            }
        } catch {
            // Cache is corrupt - clear it and start fresh
            VioLogger.error("Failed to load from cache: \(error) - clearing cache", component: "CampaignManager")
            CacheManager.shared.clearCache()
            self.currentCampaign = nil
            self.campaignState = .active
            self.isCampaignActive = false
            self.activeComponents.removeAll()
        }
    }
    
    /// Re-runs commerce bootstrap from `GET /v1/sdk/config` (e.g. before ``ProductService`` load in cart_intent overlay). Idempotent.
    public func ensureCommerceBootstrapApplied() async {
        let apiKey = VioConfiguration.shared.resolvedSdkApiKey
        guard !apiKey.isEmpty else {
            print("🎯 [CampaignManager] ensureCommerceBootstrapApplied — skip (empty apiKey)")
            return
        }
        print("🎯 [CampaignManager] ensureCommerceBootstrapApplied → GET /v1/sdk/config")
        await fetchAndApplySdkBootstrap(usingSdkApiKey: apiKey)
    }
    
    /// Loads `GET /v1/sdk/config` and applies `commerce.apiKey` / `commerce.endpoint` for ProductService (GraphQL).
    private func fetchAndApplySdkBootstrap(usingSdkApiKey apiKey: String) async {
        guard !apiKey.isEmpty else {
            VioConfiguration.shared.applySdkBootstrapCommerce(apiKey: nil, graphQLURL: nil)
            return
        }
        let restBase = campaignRestAPIBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var urlComponents = URLComponents(string: "\(restBase)/v1/sdk/config")
        urlComponents?.queryItems = [URLQueryItem(name: "apiKey", value: apiKey)]
        guard let url = urlComponents?.url else {
            VioLogger.warning("Invalid SDK bootstrap URL", component: "CampaignManager")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        let safeURLForLog = url.absoluteString.replacingOccurrences(of: apiKey, with: "<redacted>")
        print("🎯 [CampaignManager] sdk/bootstrap → GET \(safeURLForLog)")
        print("🎯 [CampaignManager] sdk/bootstrap    REST base (campaigns.* en vio-config): \(restBase)")
        print("🎯 [CampaignManager] sdk/bootstrap    URL host=\(url.host ?? "nil") port=\(url.port.map(String.init) ?? "default") query apiKey len=\(apiKey.count) prefix=\(apiKey.prefix(12))…")
        print("🎯 [CampaignManager] sdk/bootstrap    esperado: HTTP 200 + objeto \"commerce\" con apiKey (como curl al mismo host)")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("🎯 [CampaignManager] sdk/bootstrap ← HTTP \(code) (omitido o error)")
                if let body = String(data: data, encoding: .utf8), !body.isEmpty {
                    print("🎯 [CampaignManager] sdk/bootstrap    cuerpo error (prefix 800):\n\(body.prefix(800))")
                }
                VioLogger.warning("SDK bootstrap HTTP error", component: "CampaignManager")
                return
            }
            print("🎯 [CampaignManager] sdk/bootstrap ← HTTP \(http.statusCode) OK bodyBytes=\(data.count)")
            if let redacted = Self.sdkConfigJSONRedactedForLogs(data) {
                print("🎯 [CampaignManager] sdk/bootstrap    respuesta JSON (secretos redactados, comparable a `curl | json.tool`):\n\(redacted)")
            } else {
                print("🎯 [CampaignManager] sdk/bootstrap    ⚠️ no se pudo pretty-print JSON; body utf8 prefix 500:\n\(String(data: data, encoding: .utf8)?.prefix(500) ?? "<nil>")")
            }
            // Diagnóstico rápido: bloque "commerce" en bruto (sin imprimir la apiKey completa).
            if let root = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let commerce = root["commerce"] as? [String: Any] {
                let hasKey = ((commerce["apiKey"] as? String)?.isEmpty == false)
                print("🎯 [CampaignManager] sdk/bootstrap    parse manual commerce: tiene.apiKey=\(hasKey) endpoint=\(String(describing: commerce["endpoint"] ?? "nil"))")
            } else {
                print("🎯 [CampaignManager] sdk/bootstrap    parse manual: clave \"commerce\" ausente o no es objeto (revisar body arriba)")
            }
            let bootstrap: SdkBootstrapResponse
            do {
                bootstrap = try JSONDecoder().decode(SdkBootstrapResponse.self, from: data)
            } catch {
                print("🎯 [CampaignManager] sdk/bootstrap    ❌ decode SdkBootstrapResponse falló: \(error)")
                if let de = error as? DecodingError {
                    print("🎯 [CampaignManager] sdk/bootstrap    DecodingError: \(String(describing: de))")
                }
                if let raw = String(data: data, encoding: .utf8) {
                    let limit = 2500
                    print("🎯 [CampaignManager] sdk/bootstrap    body prefix (\(min(limit, raw.count)) chars):\n\(raw.prefix(limit))")
                }
                VioLogger.warning("SDK bootstrap JSON decode failed: \(error.localizedDescription)", component: "CampaignManager")
                return
            }
            let key = bootstrap.commerce?.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyNonEmpty = (key?.isEmpty == false) ? key : nil
            // Solo aplicar URL del bootstrap cuando hay clave de commerce; si no, evita fijar URLs internas del servidor (p. ej. k8s) sin Authorization válida.
            let gqlForApply: String? = {
                guard keyNonEmpty != nil else { return nil }
                let g = bootstrap.commerce?.endpoint ?? bootstrap.endpoints?.commerceGraphQL
                let t = g?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (t?.isEmpty == false) ? t : nil
            }()
            let hadCommerce = keyNonEmpty != nil
            let featCommerce = bootstrap.features?.commerce
            print("🎯 [CampaignManager] sdk/bootstrap    decode OK features.commerce=\(String(describing: featCommerce)) commerce.apiKey.present=\(hadCommerce) commerce.endpoint.aplicaráAlBootstrap=\(gqlForApply != nil && !(gqlForApply?.isEmpty ?? true))")
            if featCommerce == true, keyNonEmpty == nil {
                print("🎯 [CampaignManager] sdk/bootstrap    ⚠️ features.commerce=true pero sin commerce.apiKey usará campaigns.commerceApiKey en vio-config si está definida")
            }
            VioConfiguration.shared.applySdkBootstrapCommerce(apiKey: keyNonEmpty, graphQLURL: gqlForApply)
            NotificationCenter.default.post(name: .vioCommerceBootstrapDidApply, object: nil)
            print("🎯 [CampaignManager] sdk/bootstrap    posted vioCommerceBootstrapDidApply (invalidate ProductService GraphQL cache)")
            if let k = keyNonEmpty {
                VioLogger.debug(
                    "SDK bootstrap: commerce GraphQL Authorization from backend (prefix \(k.prefix(8))…, len \(k.count))",
                    component: "CampaignManager",
                )
                print("🎯 [CampaignManager] sdk/bootstrap    commerce.apiKey aplicada prefix=\(k.prefix(8))… len=\(k.count)")
            } else {
                VioLogger.debug(
                    "SDK bootstrap: sin commerce.apiKey en respuesta — ProductService usará VioConfiguration.resolvedCommerceApiKey (apiKey del cliente / DEMO_KEY)",
                    component: "CampaignManager",
                )
                print("🎯 [CampaignManager] sdk/bootstrap    commerce.apiKey ausente — GraphQL usará fallback resolvedCommerceApiKey")
            }
            let cfg = VioConfiguration.shared
            let src = cfg.sdkBootstrapCommerceApiKey != nil ? "bootstrap(/v1/sdk/config)" : "fallback(apiKey campaña)"
            print("🎯 [CampaignManager] sdk/bootstrap    → commerce listo: fuente=\(src) GraphQL=\(cfg.resolvedCommerceGraphQLURL) authKey prefix=\(cfg.resolvedCommerceApiKey.prefix(8))… len=\(cfg.resolvedCommerceApiKey.count)")
        } catch {
            VioLogger.warning("SDK bootstrap failed: \(error.localizedDescription)", component: "CampaignManager")
        }
    }
    
    /// Fetch campaign information from API using new v1 endpoint
    /// Uses campaign id from discovery (`discoverCampaigns` / `initializeCampaign`).
    private func fetchCampaignInfo(campaignId: Int) async {
        let config = VioConfiguration.shared
        
        // Use campaign admin API key (different from SDK API key)
        let campaignAdminApiKey = config.campaignConfiguration.campaignAdminApiKey.isEmpty 
            ? (config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey)  // Fallback to SDK API key if not configured
            : config.campaignConfiguration.campaignAdminApiKey
        
        print("🎯 [CampaignManager] fetchCampaignInfo - Using campaignId: \(campaignId)")
        print("🎯 [CampaignManager] fetchCampaignInfo - campaignAdminApiKey: \(campaignAdminApiKey.prefix(20))...")
        guard campaignId > 0 else {
            VioLogger.warning("No campaignId — skipping campaign info fetch", component: "CampaignManager")
            return
        }
        
        let urlString = "\(campaignRestAPIBaseURL)/v1/sdk/config?apiKey=\(campaignAdminApiKey)&campaignId=\(campaignId)"
        print("🎯 [CampaignManager] fetchCampaignInfo - Request URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            VioLogger.error("Invalid campaign API URL: \(urlString)", component: "CampaignManager")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0  // 10 second timeout
        
        var responseData: Data?
        
        do {
            print("🎯 [CampaignManager] fetchCampaignInfo - Starting URLSession request...")
            print("🎯 [CampaignManager] fetchCampaignInfo - URL: \(url.absoluteString)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            responseData = data
            print("🎯 [CampaignManager] fetchCampaignInfo - Request completed, data size: \(data.count) bytes")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🎯 [CampaignManager] fetchCampaignInfo - HTTP Status Code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    print("🎯 [CampaignManager] ❌ Campaign \(campaignId) not found (404)")
                    VioLogger.warning("Campaign \(campaignId) not found - SDK works normally", component: "CampaignManager")
                    // Campaign not found - allow normal SDK behavior
                    self.isCampaignActive = true
                    self.campaignState = .active
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                    print("🎯 [CampaignManager] ❌ HTTP Error \(httpResponse.statusCode): \(responseString)")
                    VioLogger.error("Campaign info request failed with status \(httpResponse.statusCode): \(responseString)", component: "CampaignManager")
                    // On error, allow normal SDK behavior
                    self.isCampaignActive = true
                    self.campaignState = .active
                    return
                }
            } else {
                print("🎯 [CampaignManager] ⚠️ Response is not HTTPURLResponse")
            }
            
            // Validate that we received JSON, not HTML
            if let responseString = String(data: data, encoding: .utf8), responseString.trimmingCharacters(in: .whitespaces).hasPrefix("<") {
                print("🎯 [CampaignManager] ❌ Received HTML instead of JSON")
                VioLogger.error("Received HTML instead of JSON from campaign endpoint", component: "CampaignManager")
                // On error, allow normal SDK behavior
                self.isCampaignActive = true
                self.campaignState = .active
                return
            }
            
            // Log raw JSON response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("🎯 [CampaignManager] Raw SDK Config JSON response: \(responseString)")
            }
            
            // Decode new SDK config response
            let sdkConfig = try JSONDecoder().decode(SDKConfigResponse.self, from: data)
            print("🎯 [CampaignManager] SDK Config decoded - Campaign ID: \(sdkConfig.campaignId)")
            print("🎯 [CampaignManager] SDK Config - campaignLogo from response: \(sdkConfig.campaignLogo ?? "nil")")
            print("🎯 [CampaignManager] SDK Config - campaignLogo isEmpty: \(sdkConfig.campaignLogo?.isEmpty ?? true)")
            
            // Create Campaign model from SDK config response
            // Note: The new endpoint doesn't return startDate/endDate/isPaused, so we preserve existing values
            let existingCampaign = self.currentCampaign
            print("🎯 [CampaignManager] Existing campaign before update: ID=\(existingCampaign?.id ?? -1), logo=\(existingCampaign?.campaignLogo ?? "nil")")
            
            let resolvedCampaignId = sdkConfig.campaignId ?? existingCampaign?.id ?? campaignId
            let resolvedLogo = sdkConfig.campaignLogo ?? pendingSponsorLogoUrl
            let campaign = Campaign(
                id: resolvedCampaignId,
                startDate: existingCampaign?.startDate,
                endDate: existingCampaign?.endDate,
                isPaused: existingCampaign?.isPaused,
                campaignLogo: resolvedLogo,
                broadcastContext: sdkConfig.broadcastContext ?? existingCampaign?.broadcastContext
            )
            
            print("🎯 [CampaignManager] New Campaign created - ID: \(campaign.id), campaignLogo: \(campaign.campaignLogo ?? "nil")")
            
            // Detect changes in campaign configuration
            let oldLogoUrl = existingCampaign?.campaignLogo
            let newLogoUrl = campaign.campaignLogo
            
            // Check if campaign configuration changed
            let campaignChanged = existingCampaign != campaign
            
            self.currentCampaign = campaign
            print("🎯 [CampaignManager] currentCampaign updated - ID: \(self.currentCampaign?.id ?? -1), campaignLogo: \(self.currentCampaign?.campaignLogo ?? "nil")")
            
            self.campaignState = campaign.currentState
            self.isCampaignActive = true  // Restore after cache clear — campaign fetched successfully
            
            // If campaign configuration changed, invalidate cache appropriately
            if campaignChanged {
                // Check if logo specifically changed
                let logoChanged = oldLogoUrl != newLogoUrl
                
                if logoChanged, let oldLogo = oldLogoUrl {
                    // Logo changed - invalidate old logo
                    print("🎯 [CampaignManager] Logo changed - invalidating old logo: \(oldLogo)")
                    NotificationCenter.default.post(
                        name: .campaignLogoChanged,
                        object: nil,
                        userInfo: [
                            "oldLogoUrl": oldLogo,
                            "newLogoUrl": newLogoUrl ?? ""
                        ]
                    )
                } else if !logoChanged, let currentLogo = newLogoUrl {
                    // Other configuration changed (dates, state, matchContext) but logo is same
                    // Invalidate current logo to ensure branding changes are reflected
                    print("🎯 [CampaignManager] Campaign configuration changed (logo unchanged) - invalidating current logo: \(currentLogo)")
                    NotificationCenter.default.post(
                        name: .campaignLogoChanged,
                        object: nil,
                        userInfo: [
                            "oldLogoUrl": currentLogo,
                            "newLogoUrl": newLogoUrl ?? ""
                        ]
                    )
                }
                
                // Pre-load new logo if it changed (will be cached by ImageLoader)
                if let logoUrl = newLogoUrl, logoUrl != oldLogoUrl, let url = URL(string: logoUrl) {
                    // Pre-load logo in background to cache it
                    Task {
                        _ = try? await URLSession.shared.data(from: url)
                    }
                }
            }
            
            // Check if campaign is paused first (takes priority over date-based state)
            if campaign.isPaused == true {
                self.isCampaignActive = false
                self.activeComponents.removeAll()
                // Save to cache
                CacheManager.shared.saveCampaign(campaign)
                CacheManager.shared.saveCampaignState(campaignState, isActive: isCampaignActive)
                CacheManager.shared.saveComponents([])
                return
            }
            
            // Update active state based on campaign state
            switch campaignState {
            case .upcoming:
                self.isCampaignActive = false
            case .active:
                self.isCampaignActive = true
                // Campaign is active
            case .ended:
                self.isCampaignActive = false
                self.activeComponents.removeAll()
                VioLogger.warning("Campaign \(campaignId) has ended - hiding all components", component: "CampaignManager")
            }
            
            // Save to cache
            CacheManager.shared.saveCampaign(campaign)
            CacheManager.shared.saveCampaignState(campaignState, isActive: isCampaignActive)
            
            // Save configuration hash for future validation
            let config = VioConfiguration.shared
            let apiKey = config.campaignConfiguration.campaignAdminApiKey.isEmpty 
                ? (config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey)
                : config.campaignConfiguration.campaignAdminApiKey
            CacheManager.shared.saveCacheConfiguration(
                campaignId: campaign.id,
                campaignAdminApiKey: apiKey,
                baseURL: self.baseURL
            )
            
        } catch let decodingError as DecodingError {
            print("🎯 [CampaignManager] ❌ Decoding Error: \(decodingError)")
            if case .dataCorrupted(let context) = decodingError {
                print("🎯 [CampaignManager] Data corrupted at: \(context.debugDescription)")
                if let data = responseData, let dataString = String(data: data, encoding: .utf8) {
                    print("🎯 [CampaignManager] Raw data: \(dataString)")
                }
            }
            VioLogger.error("Failed to decode campaign info: \(decodingError)", component: "CampaignManager")
            // On error, allow normal SDK behavior
            self.isCampaignActive = true
            self.campaignState = .active
        } catch {
            print("🎯 [CampaignManager] ❌ Network/Other Error: \(error.localizedDescription)")
            print("🎯 [CampaignManager] ❌ Error details: \(error)")
            VioLogger.warning("Failed to fetch campaign info: \(error)", component: "CampaignManager")
            // On error, allow normal SDK behavior
            self.isCampaignActive = true
            self.campaignState = .active
        }
    }
    
    /// Discover campaigns using auto-discovery endpoint
    /// Uses only the Vio SDK API key (no campaignAdminApiKey needed)
    /// - Parameter matchId: Optional matchId to filter campaigns for a specific match
    public func discoverCampaigns(broadcastId: String? = nil) async {
        let config = VioConfiguration.shared
        let apiKey = config.resolvedSdkApiKey
        
        guard !apiKey.isEmpty else {
            VioLogger.error("Cannot discover campaigns: API key is empty", component: "CampaignManager")
            return
        }
        
        var urlString = "\(campaignRestAPIBaseURL)/v1/sdk/campaigns?apiKey=\(apiKey)"
        if let broadcastId = broadcastId {
            urlString += "&broadcastId=\(broadcastId)"
            // Also include matchId for backward compatibility with backend
            urlString += "&matchId=\(broadcastId)"
        }
        
        guard let url = URL(string: urlString) else {
            VioLogger.error("Invalid campaigns discovery URL: \(urlString)", component: "CampaignManager")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        do {
            // Commerce from GET /v1/sdk/config must not depend on /v1/sdk/campaigns succeeding (GraphQL / cart_intent needs sponsor key even if discovery errors).
            await fetchAndApplySdkBootstrap(usingSdkApiKey: apiKey)
            
            let safeUrlForLog = "\(campaignRestAPIBaseURL)/v1/sdk/campaigns?apiKey=<redacted>"
            print("🎯 [CampaignManager] discoverCampaigns → GET \(safeUrlForLog)")
            print("🎯 [CampaignManager] discoverCampaigns    esperado: HTTP 200, JSON con array \"campaigns\" (campaignId, components, …)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                    print("🎯 [CampaignManager] discoverCampaigns ← HTTP \(httpResponse.statusCode) (error). Body: \(responseString.prefix(300))")
                    VioLogger.error("Campaigns discovery failed with status \(httpResponse.statusCode): \(responseString)", component: "CampaignManager")
                    return
                }
            }
            print("🎯 [CampaignManager] discoverCampaigns ← HTTP \(statusCode) OK")
            
            // Decode campaigns discovery response
            let discoveryResponse = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: data)
            print("🎯 [CampaignManager] discoverCampaigns    decodificado: \(discoveryResponse.campaigns.count) fila(s) en \"campaigns\"")
            
            // Convert discovery items to Campaign models
            var discoveredCampaigns: [Campaign] = []
            var allComponents: [Component] = []
            
            for item in discoveryResponse.campaigns {
                let campaign = Campaign(
                    id: item.campaignId,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    isPaused: item.isPaused,
                    campaignLogo: item.campaignLogo,
                    broadcastContext: item.broadcastContext
                )
                discoveredCampaigns.append(campaign)
                
                // Process components from discovery response
                if let componentItems = item.components {
                    for componentItem in componentItems {
                        // Convert ComponentDiscoveryItem to Component
                        // Note: This requires decoding ComponentConfig from the config dictionary
                        do {
                            let configData = try JSONSerialization.data(withJSONObject: componentItem.config.mapValues { $0.value })
                            let componentConfig = try JSONDecoder().decode(ComponentConfig.self, from: configData)
                            
                            let component = Component(
                                id: componentItem.id,
                                type: componentItem.type,
                                name: componentItem.name,
                                config: componentConfig,
                                status: componentItem.status,
                                locationId: componentItem.locationId,
                                broadcastContext: componentItem.broadcastContext
                            )
                            allComponents.append(component)
                        } catch {
                            VioLogger.error("Failed to decode component from discovery: \(error)", component: "CampaignManager")
                        }
                    }
                }
            }
            
            // Update active campaigns
            self.activeCampaigns = discoveredCampaigns
            
            // Filter components by currentBroadcastContext if set
            // Components without broadcastContext are shown for all broadcasts (backward compatibility)
            if let context = currentBroadcastContext {
                self.activeComponents = allComponents.filter { component in
                    // Include components without broadcastContext (backward compatibility)
                    guard let componentBroadcastId = component.broadcastContext?.broadcastId else {
                        return true  // Show components without broadcastContext for all broadcasts
                    }
                    // Include components that match the current broadcastId
                    return componentBroadcastId == context.broadcastId
                }
            } else {
                self.activeComponents = allComponents
            }
            
            // Set current campaign to first active campaign if available
            print("🎯 [Sponsor] discoveredCampaigns: \(discoveredCampaigns.map { "id:\($0.id) state:\($0.currentState) paused:\($0.isPaused ?? false)" })")
            if var firstActiveCampaign = discoveredCampaigns.first(where: { $0.currentState == .active && $0.isPaused != true }) {
                // If campaignLogo is null from discovery, fetch it from dynamic config (brand.logoUrl)
                print("🎯 [Sponsor] campaignLogo from discovery: \(firstActiveCampaign.campaignLogo ?? "nil") | restAPIBase: \(campaignRestAPIBaseURL)")
                if firstActiveCampaign.campaignLogo == nil {
                    if let dynamicConfig = await DynamicConfigurationManager.shared.loadCampaignConfig(
                        campaignId: firstActiveCampaign.id,
                        broadcastId: nil
                    ), let brandLogoUrl = dynamicConfig.brand?.logoUrl, !brandLogoUrl.isEmpty {
                        print("🎯 [Sponsor] fetched brand.logoUrl from dynamic config: \(brandLogoUrl)")
                        firstActiveCampaign = Campaign(
                            id: firstActiveCampaign.id,
                            startDate: firstActiveCampaign.startDate,
                            endDate: firstActiveCampaign.endDate,
                            isPaused: firstActiveCampaign.isPaused,
                            campaignLogo: brandLogoUrl,
                            broadcastContext: firstActiveCampaign.broadcastContext
                        )
                        // Also update VioConfiguration brand config
                        if let brandConfig = dynamicConfig.brand {
                            VioConfiguration.shared.updateDynamicBrandConfig(brandConfig)
                        }
                    }
                }

                // Detect changes in campaign configuration
                let existingCampaign = self.currentCampaign
                let oldLogoUrl = existingCampaign?.campaignLogo
                let newLogoUrl = firstActiveCampaign.campaignLogo
                
                // Check if campaign configuration changed
                let campaignChanged = existingCampaign != firstActiveCampaign
                
                self.currentCampaign = firstActiveCampaign
                self.campaignState = firstActiveCampaign.currentState
                self.isCampaignActive = true
                
                // If campaign configuration changed, invalidate cache appropriately
                if campaignChanged {
                    // Check if logo specifically changed
                    let logoChanged = oldLogoUrl != newLogoUrl
                    
                    if logoChanged, let oldLogo = oldLogoUrl {
                        // Logo changed - invalidate old logo
                        print("🎯 [CampaignManager] Logo changed in discovery - invalidating old logo: \(oldLogo)")
                        NotificationCenter.default.post(
                            name: .campaignLogoChanged,
                            object: nil,
                            userInfo: [
                                "oldLogoUrl": oldLogo,
                                "newLogoUrl": newLogoUrl ?? ""
                            ]
                        )
                    } else if !logoChanged, let currentLogo = newLogoUrl {
                        // Other configuration changed (dates, state, matchContext) but logo is same
                        // Invalidate current logo to ensure branding changes are reflected
                        print("🎯 [CampaignManager] Campaign configuration changed in discovery (logo unchanged) - invalidating current logo: \(currentLogo)")
                        NotificationCenter.default.post(
                            name: .campaignLogoChanged,
                            object: nil,
                            userInfo: [
                                "oldLogoUrl": currentLogo,
                                "newLogoUrl": newLogoUrl ?? ""
                            ]
                        )
                    }
                    
                    // Pre-load new logo if it changed (will be cached by ImageLoader)
                    if let logoUrl = newLogoUrl, logoUrl != oldLogoUrl, let url = URL(string: logoUrl) {
                        // Pre-load logo in background to cache it
                        Task {
                            _ = try? await URLSession.shared.data(from: url)
                        }
                    }
                }
            } else if !discoveredCampaigns.isEmpty {
                print("🎯 [CampaignManager] discoverCampaigns - No active campaign (requires state .active and not paused). Skipping currentCampaign update, /v1/offers fallback, and WebSocket. Got: \(discoveredCampaigns.map { "id:\($0.id) state:\($0.currentState) paused:\($0.isPaused ?? false)" }.joined(separator: ", "))")
            }
            
            // Fetch offers from /v1/offers ONLY if discovery returned 0 components.
            // If components came from /v1/sdk/campaigns, skip /v1/offers to avoid overwriting them.
            if let activeCampaign = self.currentCampaign,
               self.campaignState == .active,
               activeCampaign.isPaused != true,
               allComponents.isEmpty {
                print("🎯 [CampaignManager] discoverCampaigns - No components from discovery, fetching from /v1/offers for campaignId: \(activeCampaign.id)")
                await fetchActiveComponents(campaignId: activeCampaign.id)
            } else if !allComponents.isEmpty {
                print("🎯 [CampaignManager] discoverCampaigns - Using \(allComponents.count) components from discovery, skipping /v1/offers")
            }
            
            // Cache components
            CacheManager.shared.saveComponents(self.activeComponents)
            ComponentManager.shared.refreshActiveBannerFromCampaignManager()
            
            print("🎯 [CampaignManager] discoverCampaigns - Discovered \(discoveredCampaigns.count) campaigns, \(self.activeComponents.count) components")
            
            // Connect WebSocket for the active campaign (enables cart_intent, campaign events, etc.)
            if let activeCampaign = self.currentCampaign, activeCampaign.isPaused != true {
                print("🎯 [CampaignManager] discoverCampaigns - Connecting WebSocket for campaignId: \(activeCampaign.id)")
                await connectWebSocket(campaignId: activeCampaign.id)
            }
            
            await flushPendingApnsDeviceTokenRegistrationWithVio()
            
        } catch {
            VioLogger.error("Failed to discover campaigns: \(error)", component: "CampaignManager")
        }
    }
    
    // Backward compatibility method
    @available(*, deprecated, renamed: "discoverCampaigns(broadcastId:)")
    public func discoverCampaigns(matchId: String? = nil) async {
        await discoverCampaigns(broadcastId: matchId)
    }
    
    /// Fetch active components from API using new v1 endpoint
    /// Fetches active components from /v1/offers using the provided campaignId.
    /// In autoDiscover mode, pass the discovered campaignId. In legacy mode, pass config campaignId.
    private func fetchActiveComponents(campaignId: Int) async {
        let config = VioConfiguration.shared
        
        // Use campaign admin API key (different from SDK API key)
        let campaignAdminApiKey = config.campaignConfiguration.campaignAdminApiKey.isEmpty 
            ? (config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey)  // Fallback to SDK API key if not configured
            : config.campaignConfiguration.campaignAdminApiKey
        
        let countryCode = config.marketConfiguration.countryCode
        
        // Use the passed-in campaignId (from discovery or config)
        guard campaignId > 0 else {
            VioLogger.warning("No campaignId provided - skipping components fetch from /v1/offers", component: "CampaignManager")
            return
        }
        
        // Build URL with query parameters
        var urlComponents = URLComponents(string: "\(campaignRestAPIBaseURL)/v1/offers")
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: campaignAdminApiKey),
            URLQueryItem(name: "campaignId", value: "\(campaignId)")
        ]
        
        // Add optional userCountry if available
        if !countryCode.isEmpty {
            urlComponents?.queryItems?.append(URLQueryItem(name: "userCountry", value: countryCode))
        }
        
        guard let url = urlComponents?.url else {
            VioLogger.error("Invalid offers API URL", component: "CampaignManager")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Validate HTTP response before decoding
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                    VioLogger.error("Offers request failed with status \(httpResponse.statusCode): \(responseString)", component: "CampaignManager")
                    
                    // If 404, campaign might not have offers configured - this is OK
                    if httpResponse.statusCode == 404 {
                        self.activeComponents = []
                        return
                    }
                    return
                }
            }
            
            // Validate that we received JSON, not HTML
            if let responseString = String(data: data, encoding: .utf8), responseString.trimmingCharacters(in: .whitespaces).hasPrefix("<") {
                VioLogger.error("Received HTML instead of JSON from offers endpoint", component: "CampaignManager")
                return
            }
            
            // Decode new offers response
            let offersResponse = try JSONDecoder().decode(OffersResponse.self, from: data)
            
            // Update campaign logo if available from offers response
            if let logo = offersResponse.campaignLogo, !logo.isEmpty {
                let existingCampaign = self.currentCampaign
                
                self.currentCampaign = Campaign(
                    id: existingCampaign?.id ?? offersResponse.campaignId,
                    startDate: existingCampaign?.startDate,
                    endDate: existingCampaign?.endDate,
                    isPaused: existingCampaign?.isPaused,
                    campaignLogo: logo
                )
            }
            
            // Convert offers to components
            let components = try offersResponse.offers.map { offer -> Component in
                // Convert OfferResponse config to ComponentConfig
                let jsonData = try JSONSerialization.data(withJSONObject: offer.config.mapValues { $0.value })
                let componentConfig = try JSONDecoder().decode(ComponentConfig.self, from: jsonData)
                
                return Component(
                    id: offer.id,
                    type: offer.type,
                    name: offer.name,
                    config: componentConfig,
                    status: "active" // All offers from /v1/offers are active
                )
            }
            
            // All offers are active by default
            // Filter components by currentMatchContext if set
            if let context = currentMatchContext {
                self.activeComponents = components.filter { component in
                    guard let componentMatchId = component.matchContext?.matchId else {
                        // Component without matchContext should not be shown when context is active (security)
                        return false
                    }
                    return componentMatchId == context.matchId
                }
            } else {
                // No context set - show all components (legacy mode)
                self.activeComponents = components
            }
            
            // Components loaded
            if !self.activeComponents.isEmpty {
                VioLogger.debug("Active component types: \(self.activeComponents.map { $0.type }.joined(separator: ", "))", component: "CampaignManager")
            }
            
            // Save to cache
            CacheManager.shared.saveComponents(self.activeComponents)
            
        } catch let decodingError as DecodingError {
            VioLogger.error("Failed to decode offers: \(decodingError)", component: "CampaignManager")
            
            // Log detailed decoding error information
            switch decodingError {
            case .typeMismatch(let type, let context):
                VioLogger.error("Type mismatch: Expected \(String(describing: type)), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", component: "CampaignManager")
            case .valueNotFound(let type, let context):
                VioLogger.error("Value not found: \(String(describing: type)), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", component: "CampaignManager")
            case .keyNotFound(let key, let context):
                VioLogger.error("Key not found: \(key.stringValue), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", component: "CampaignManager")
            case .dataCorrupted(let context):
                VioLogger.error("Data corrupted: \(context.debugDescription), path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", component: "CampaignManager")
            @unknown default:
                VioLogger.error("Unknown decoding error", component: "CampaignManager")
            }
        } catch {
            VioLogger.warning("Failed to fetch active components: \(error)", component: "CampaignManager")
        }
    }
    
    /// Connect to campaign WebSocket
    /// Uses the passed campaignId (from discovery response). Falls back to config file if 0.
    /// According to backend behavior:
    /// - If campaign is Ended: Backend sends campaign_ended immediately
    /// - If campaign is Upcoming: No event sent, waits for campaign_started
    /// - If campaign is Active: No event sent, can fetch components
    private func connectWebSocket(campaignId: Int) async {
        // Guard: skip if already connected or a manager is already being set up
        // discoverCampaigns has no isInitializing guard, so ContentView + TV2VideoPlayer
        // can call this simultaneously — without this check we get two separate URLSessions
        if isConnected {
            print("🎯 [CampaignManager] connectWebSocket - Already connected, skipping")
            return
        }
        if webSocketManager != nil {
            print("🎯 [CampaignManager] connectWebSocket - Manager already exists, skipping (prevents double-connect)")
            return
        }
        
        let resolvedCampaignId: Int
        if campaignId > 0 {
            resolvedCampaignId = campaignId
            print("🎯 [CampaignManager] connectWebSocket - Using campaignId from discovery: \(resolvedCampaignId)")
        } else {
            VioLogger.warning("No campaignId from discovery — skipping WebSocket connection", component: "CampaignManager")
            return
        }
        
        // Use the campaign WebSocket endpoint, not the GraphQL endpoint
        webSocketManager = CampaignWebSocketManager(campaignId: resolvedCampaignId, baseURL: campaignWebSocketBaseURL, userId: userId)
        
        // Setup event handlers
        webSocketManager?.onCampaignStarted = { [weak self] event in
            Task { @MainActor in
                self?.handleCampaignStarted(event)
            }
        }
        
        webSocketManager?.onCampaignEnded = { [weak self] event in
            Task { @MainActor in
                self?.handleCampaignEnded(event)
            }
        }
        
        webSocketManager?.onCampaignPaused = { [weak self] event in
            Task { @MainActor in
                self?.handleCampaignPaused(event)
            }
        }
        
        webSocketManager?.onCampaignResumed = { [weak self] event in
            Task { @MainActor in
                self?.handleCampaignResumed(event)
            }
        }
        
        webSocketManager?.onComponentStatusChanged = { [weak self] event in
            Task { @MainActor in
                self?.handleComponentStatusChanged(event)
            }
        }
        
        webSocketManager?.onComponentConfigUpdated = { [weak self] event in
            Task { @MainActor in
                self?.handleComponentConfigUpdated(event)
            }
        }
        
        webSocketManager?.onConnectionStatusChanged = { [weak self] connected in
            Task { @MainActor in
                self?.isConnected = connected
                if connected {
                    ComponentManager.shared.refreshActiveBannerFromCampaignManager()
                }
                
                // According to backend behavior:
                // - If campaign is Ended: Backend sends campaign_ended immediately when connection opens
                // - If campaign is Upcoming: No event sent, waits for campaign_started
                // - If campaign is Active: No event sent, can fetch components
                // The event handlers above will process these events automatically
            }
        }
        
        webSocketManager?.onLineupShow = { [weak self] event in
            Task { @MainActor in
                self?.onLineupShow?(event)
            }
        }
        
        webSocketManager?.onCartIntent = { [weak self] event in
            Task { @MainActor in
                print("🎯 [CampaignManager] cart_intent [WebSocket] productId=\(event.productId ?? "nil") campaignId=\(event.campaignId.map(String.init) ?? "nil") name=\(event.productName ?? "nil") → activeCartIntentEvent")
                self?.activeCartIntentEvent = event
            }
        }
        
        await webSocketManager?.connect()
        ComponentManager.shared.refreshActiveBannerFromCampaignManager()
    }
    
    // MARK: - Event Handlers
    
    private func handleCampaignStarted(_ event: CampaignStartedEvent) {
        VioLogger.success("Campaign started: \(event.campaignId)", component: "CampaignManager")
        
        isCampaignActive = true
        campaignState = .active
        
        // Update campaign with new dates, preserve existing campaignLogo if available
        let existingCampaign = currentCampaign
        let existingLogo = existingCampaign?.campaignLogo
        
        let newCampaign = Campaign(
            id: event.campaignId,
            startDate: event.startDate,
            endDate: event.endDate,
            isPaused: false,
            campaignLogo: existingLogo
        )
        
        // Detect if campaign configuration changed
        let campaignChanged = existingCampaign != newCampaign
        let oldLogoUrl = existingCampaign?.campaignLogo
        let newLogoUrl = newCampaign.campaignLogo
        
        currentCampaign = newCampaign
        
        VioLogger.debug("Campaign started - ID: \(event.campaignId), preserving campaignLogo: \(existingLogo ?? "nil")", component: "CampaignManager")
        
        // If campaign configuration changed, invalidate cache appropriately
        if campaignChanged {
            // Check if logo specifically changed
            let logoChanged = oldLogoUrl != newLogoUrl
            
            if logoChanged, let oldLogo = oldLogoUrl {
                // Logo changed - invalidate old logo
                VioLogger.debug("Logo changed in campaign_started - invalidating old logo: \(oldLogo)", component: "CampaignManager")
                NotificationCenter.default.post(
                    name: .campaignLogoChanged,
                    object: nil,
                    userInfo: [
                        "oldLogoUrl": oldLogo,
                        "newLogoUrl": newLogoUrl ?? ""
                    ]
                )
            } else if !logoChanged, let currentLogo = newLogoUrl {
                // Other configuration changed (dates) but logo is same
                // Invalidate current logo to ensure branding changes are reflected
                VioLogger.debug("Campaign configuration changed in campaign_started (logo unchanged) - invalidating current logo: \(currentLogo)", component: "CampaignManager")
                NotificationCenter.default.post(
                    name: .campaignLogoChanged,
                    object: nil,
                    userInfo: [
                        "oldLogoUrl": currentLogo,
                        "newLogoUrl": newLogoUrl ?? ""
                    ]
                )
            }
        }
        
        // Save to cache
        if let campaign = currentCampaign {
            CacheManager.shared.saveCampaign(campaign)
        }
        CacheManager.shared.saveCampaignState(campaignState, isActive: isCampaignActive)
        
        // Fetch active components now that campaign is active
        Task {
            await fetchActiveComponents(campaignId: event.campaignId)
        }
        
        // Notify observers
        NotificationCenter.default.post(
            name: .campaignStarted,
            object: nil,
            userInfo: ["campaignId": event.campaignId]
        )
    }
    
    private func handleCampaignEnded(_ event: CampaignEndedEvent) {
        VioLogger.warning("Campaign ended: \(event.campaignId)", component: "CampaignManager")
        
        isCampaignActive = false
        campaignState = .ended
        
        // Immediately hide ALL components
        activeComponents.removeAll()
        activeCartIntentEvent = nil
        
        // Get logo before updating campaign (to clear it from cache)
        let campaignLogoToClear = currentCampaign?.campaignLogo
        
        // Update campaign with end date, preserve existing campaignLogo if available
        if let campaign = currentCampaign {
            currentCampaign = Campaign(
                id: campaign.id,
                startDate: campaign.startDate,
                endDate: event.endDate,
                isPaused: campaign.isPaused,
                campaignLogo: campaign.campaignLogo
            )
        } else {
            // If campaign wasn't loaded yet, create it with end date
            currentCampaign = Campaign(
                id: event.campaignId,
                startDate: nil,
                endDate: event.endDate,
                isPaused: nil,
                campaignLogo: nil
            )
        }
        
        // Save to cache
        if let campaign = currentCampaign {
            CacheManager.shared.saveCampaign(campaign)
        }
        CacheManager.shared.saveCampaignState(campaignState, isActive: isCampaignActive)
        CacheManager.shared.saveComponents([])
        
        // Clear logo from cache when campaign ends
        if let logoUrl = campaignLogoToClear {
            print("🎯 [CampaignManager] Campaign ended - clearing logo from cache: \(logoUrl)")
            NotificationCenter.default.post(
                name: .campaignLogoChanged,
                object: nil,
                userInfo: [
                    "oldLogoUrl": logoUrl,
                    "newLogoUrl": ""
                ]
            )
        }
        
        // Notify observers
        NotificationCenter.default.post(
            name: .campaignEnded,
            object: nil,
            userInfo: ["campaignId": event.campaignId]
        )
        
        ComponentManager.shared.refreshActiveBannerFromCampaignManager()
    }
    
    private func handleCampaignPaused(_ event: CampaignPausedEvent) {
        VioLogger.info("Campaign paused: \(event.campaignId)", component: "CampaignManager")
        
        isCampaignActive = false
        
        // Immediately hide ALL components
        activeComponents.removeAll()
        activeCartIntentEvent = nil
        
        // Update campaign with paused state, preserve existing campaignLogo if available
        if let campaign = currentCampaign {
            currentCampaign = Campaign(
                id: campaign.id,
                startDate: campaign.startDate,
                endDate: campaign.endDate,
                isPaused: true,
                campaignLogo: campaign.campaignLogo
            )
        } else {
            // If campaign wasn't loaded yet, create it with paused state
            currentCampaign = Campaign(
                id: event.campaignId,
                startDate: nil,
                endDate: nil,
                isPaused: true,
                campaignLogo: nil
            )
        }
        
        // Save to cache
        if let campaign = currentCampaign {
            CacheManager.shared.saveCampaign(campaign)
        }
        CacheManager.shared.saveCampaignState(campaignState, isActive: isCampaignActive)
        CacheManager.shared.saveComponents([])
        
        // Notify observers
        NotificationCenter.default.post(
            name: .campaignPaused,
            object: nil,
            userInfo: ["campaignId": event.campaignId]
        )
        
        ComponentManager.shared.refreshActiveBannerFromCampaignManager()
    }
    
    private func handleCampaignResumed(_ event: CampaignResumedEvent) {
        VioLogger.success("Campaign resumed: \(event.campaignId)", component: "CampaignManager")
        
        isCampaignActive = true
        
        // Update campaign with resumed state, preserve existing campaignLogo if available
        if let campaign = currentCampaign {
            currentCampaign = Campaign(
                id: campaign.id,
                startDate: campaign.startDate,
                endDate: campaign.endDate,
                isPaused: false,
                campaignLogo: campaign.campaignLogo
            )
        }
        
        // Save to cache
        if let campaign = currentCampaign {
            CacheManager.shared.saveCampaign(campaign)
        }
        CacheManager.shared.saveCampaignState(campaignState, isActive: isCampaignActive)
        
        // Fetch active components now that campaign is resumed
        Task {
            await fetchActiveComponents(campaignId: event.campaignId)
        }
        
        // Notify observers
        NotificationCenter.default.post(
            name: .campaignResumed,
            object: nil,
            userInfo: ["campaignId": event.campaignId]
        )
    }
    
    private func handleComponentStatusChanged(_ event: ComponentStatusChangedEvent) {
        // Filter by match context if currentMatchContext is set
        if let context = currentMatchContext, let eventMatchId = event.matchId {
            guard eventMatchId == context.matchId else {
                VioLogger.debug("Ignoring component status change - event matchId (\(eventMatchId)) != current matchId (\(context.matchId))", component: "CampaignManager")
                return
            }
        }
        
        // Determine status and component ID based on format
        let status: String
        let componentId: String
        
        if let data = event.data {
            // New format
            status = data.status
            componentId = String(data.campaignComponentId)
            VioLogger.debug("Component status changed (new format): \(data.componentId) -> \(status)", component: "CampaignManager")
        } else if let legacyStatus = event.status, let legacyComponent = event.component {
            // Legacy format
            status = legacyStatus
            componentId = legacyComponent.id
            VioLogger.debug("Component status changed (legacy format): \(legacyComponent.id) -> \(status)", component: "CampaignManager")
        } else {
            VioLogger.error("Invalid component_status_changed event - missing required fields", component: "CampaignManager")
            return
        }
        
        // Business rule: Components CANNOT be activated in Upcoming state
        // Even if backend sends activation event, ignore it if campaign hasn't started
        if status == "active" && campaignState == .upcoming {
            VioLogger.warning("Ignoring component activation - campaign is upcoming", component: "CampaignManager")
            return
        }
        
        // Business rule: Components CANNOT be activated in Ended state
        if status == "active" && campaignState == .ended {
            VioLogger.warning("Ignoring component activation - campaign has ended", component: "CampaignManager")
            return
        }
        
        // Business rule: Components CANNOT be activated if campaign is paused
        if status == "active" && (currentCampaign?.isPaused == true || !isCampaignActive) {
            VioLogger.warning("Ignoring component activation - campaign is paused", component: "CampaignManager")
            return
        }
        
        do {
            let component = try event.toComponent()
            
            if status == "active" {
                // Filter by match context if currentMatchContext is set
                if let context = currentMatchContext {
                    guard component.matchContext?.matchId == context.matchId else {
                        VioLogger.debug("Ignoring component activation - component matchId (\(component.matchContext?.matchId ?? "nil")) != current matchId (\(context.matchId))", component: "CampaignManager")
                        return
                    }
                }
                
                // Only one component of each type can be active at a time
                // Remove any existing component of the same type first
                activeComponents.removeAll { $0.type == component.type && $0.id != componentId }
                
                // Add or update component
                if let index = activeComponents.firstIndex(where: { $0.id == componentId }) {
                    activeComponents[index] = component
                } else {
                    activeComponents.append(component)
                }
                
                // Save to cache
                CacheManager.shared.saveComponents(activeComponents)
            } else {
                // Remove component
                activeComponents.removeAll { $0.id == componentId }
                
                // Save to cache
                CacheManager.shared.saveComponents(activeComponents)
            }
            ComponentManager.shared.refreshActiveBannerFromCampaignManager()
        } catch {
            VioLogger.error("Failed to convert component event: \(error)", component: "CampaignManager")
        }
    }
    
    private func handleComponentConfigUpdated(_ event: ComponentConfigUpdatedEvent) {
        // Log which format we received
        if let componentId = event.componentId {
            VioLogger.debug("Component config updated (new format): \(componentId)", component: "CampaignManager")
        } else if let data = event.data {
            VioLogger.debug("Component config updated (old format): \(data.componentId)", component: "CampaignManager")
        }
        
        do {
            let component = try event.toComponent()
            let componentId = component.id
            
            // Update existing component's config (match by componentId string)
            if let index = activeComponents.firstIndex(where: { $0.id == componentId }) {
                activeComponents[index] = component
                VioLogger.success("Updated component config: \(componentId)", component: "CampaignManager")
                
                // Save to cache
                CacheManager.shared.saveComponents(activeComponents)
            } else {
                // If component doesn't exist yet, add it (only if campaign is active)
                if isCampaignActive && currentCampaign?.isPaused != true {
                    activeComponents.append(component)
                    VioLogger.success("Added new component from config update: \(componentId)", component: "CampaignManager")
                    
                    // Save to cache
                    CacheManager.shared.saveComponents(activeComponents)
                } else {
                    VioLogger.warning("Cannot add component - campaign not active or paused", component: "CampaignManager")
                }
            }
            ComponentManager.shared.refreshActiveBannerFromCampaignManager()
        } catch {
            VioLogger.error("Failed to convert component event: \(error)", component: "CampaignManager")
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    public static let campaignStarted = Notification.Name("VioCampaignStarted")
    public static let campaignEnded = Notification.Name("VioCampaignEnded")
    public static let campaignPaused = Notification.Name("VioCampaignPaused")
    public static let campaignResumed = Notification.Name("VioCampaignResumed")
    public static let componentStatusChanged = Notification.Name("VioComponentStatusChanged")
    public static let componentConfigUpdated = Notification.Name("VioComponentConfigUpdated")
    public static let campaignLogoChanged = Notification.Name("VioCampaignLogoChanged")
    /// Posted after a successful `GET /v1/sdk/config` bootstrap apply so ``VioUI/ProductService`` can invalidate cached GraphQL client.
    public static let vioCommerceBootstrapDidApply = Notification.Name("io.vio.sdk.commerceBootstrapDidApply")
}

