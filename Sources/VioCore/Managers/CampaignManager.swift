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
    /// Zero-config: APNs hex from the app; `register-device` runs only after `discoverCampaigns` sets `currentCampaign`.
    private var pendingApnsDeviceTokenHex: String?
    private var pendingSponsorLogoUrl: String? = nil  // Set from dynamic config, applied when Campaign is created
    
    /// Called when backend sends a `lineup_show` WS event.
    /// Set this from VioCastingUI layer (LineupTimelineHandler) — avoids cross-module dependency.
    public var onLineupShow: ((LineupShowEvent) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var baseURL: String  // For REST API (GraphQL base URL)
    private var isInitializing = false  // Flag to prevent multiple simultaneous initializations
    private var campaignRestBaseOverride: String?
    private var campaignWebSocketBaseOverride: String?
    private var commerceBootstrapTask: Task<Void, Never>?
    private var commerceBootstrapTaskApiKey: String?
    private var discoverCampaignsTask: Task<Void, Never>?
    private var discoverCampaignsTaskBroadcastId: String?
    private var discoverCampaignsTaskApiKey: String?
    private var lastSuccessfulDiscoveryBroadcastId: String?
    private var lastSuccessfulDiscoveryApiKey: String?
    
    // Campaign endpoints from configuration
    private var campaignWebSocketBaseURL: String {
        campaignWebSocketBaseOverride ?? VioConfiguration.shared.wsBaseURL
    }
    
    private var campaignRestAPIBaseURL: String {
        campaignRestBaseOverride ?? VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
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
        print("🎯 [CampaignManager] register-device    APNs token: hex len=\(hex.count) (hex completo solo en logs DEBUG)")
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
        campaignRestBaseOverride = nil
        campaignWebSocketBaseOverride = nil
        commerceBootstrapTask?.cancel()
        commerceBootstrapTask = nil
        commerceBootstrapTaskApiKey = nil
        discoverCampaignsTask?.cancel()
        discoverCampaignsTask = nil
        discoverCampaignsTaskBroadcastId = nil
        discoverCampaignsTaskApiKey = nil
        lastSuccessfulDiscoveryBroadcastId = nil
        lastSuccessfulDiscoveryApiKey = nil
        VioConfiguration.shared.applySdkBootstrapCommerce(apiKey: nil, graphQLURL: nil)
        
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
    @available(*, deprecated, message: "Use VioSession.shared.start(...) / VioRuntime.startSession(...) for orchestrated startup.")
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

        // 1. Campaign info (primary sponsor + secondaries + commerce keys) now comes
        //    exclusively from `GET /v2/mobile/config` via bootstrapCommerceFromSdkConfig.
        //    The legacy /v1/sdk/config fallback was removed as part of the v2
        //    multi-sponsor hygiene pass — shape collision (single commerce vs per-sponsor).
        //    isCampaignActive + campaignState default to active here; WS events
        //    (`campaign_ended`, `campaign_paused`, `campaign_resumed`) correct the state.
        self.isCampaignActive = true
        self.campaignState = .active

        // 2. Connect WebSocket for real-time updates
        // According to backend behavior:
        // - If Ended: Backend sends campaign_ended immediately
        // - If Upcoming: No event sent, waits for campaign_started
        // - If Active: No event sent, can fetch components
        await connectWebSocket(campaignId: campaignId)
        
        // 3. Components now arrive over WebSocket (`component_status_changed` events)
        //    + the per-broadcast `GET /v2/mobile/broadcasts/:id/components` call when a
        //    broadcast is opened. The legacy `/v1/offers` polling fallback was removed
        //    as part of the v2 multi-sponsor hygiene pass.
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

    // MARK: - Cold-start fetch of campaign placements

    /// Fetches `GET /v2/mobile/campaigns/:id/components` and merges the result
    /// into `activeComponents` so the SDK can resolve placements on a fresh
    /// install without waiting for the next `component_status_changed` WS
    /// event. Best-effort: any failure is logged and bootstrap continues.
    @MainActor
    public func fetchAndApplyCampaignComponentsIfPossible() async {
        guard let campaign = currentCampaign else {
            VioLogger.debug("fetchAndApplyCampaignComponents: skipped — no currentCampaign", component: "CampaignManager")
            return
        }
        let cfg = VioConfiguration.shared
        let base = cfg.campaignConfiguration.restAPIBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let apiKey = cfg.resolvedSdkApiKey
        guard !base.isEmpty, !apiKey.isEmpty else { return }
        guard let url = URL(string: "\(base)/v2/mobile/campaigns/\(campaign.id)/components") else { return }

        var req = URLRequest(url: url)
        req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        req.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                VioLogger.warning("fetchAndApplyCampaignComponents: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)", component: "CampaignManager")
                return
            }
            // Lightweight envelope decoder — Component decoding via its own
            // `init(from decoder:)` so existing tests / callers unaffected.
            struct Envelope: Decodable { let campaignId: Int; let components: [Component] }
            let decoded = try JSONDecoder().decode(Envelope.self, from: data)

            // Merge: replace any existing entry with same (template id, locationId),
            // keep the rest. Two campaign_components rows can share the same
            // template (`product-carousel-template`) yet live in different slots —
            // a key that ignores locationId would clobber one with the other on
            // every fetch. Avoids dropping components that arrived via WS in the
            // tiny window between bootstrap and this fetch.
            for component in decoded.components {
                if let idx = activeComponents.firstIndex(where: {
                    $0.id == component.id && $0.locationId == component.locationId
                }) {
                    activeComponents[idx] = component
                } else {
                    activeComponents.append(component)
                }
            }
            CacheManager.shared.saveComponents(activeComponents)
            print("🎯 [CampaignManager] /v2/mobile/campaigns/\(campaign.id)/components → \(decoded.components.count) instance(s) merged into activeComponents")
        } catch {
            VioLogger.warning("fetchAndApplyCampaignComponents failed (non-fatal): \(error)", component: "CampaignManager")
        }
    }

    /// Clears cart intent UI state (e.g. after dismiss or when leaving the session).
    public func dismissCartIntent() {
        activeCartIntentEvent = nil
    }

    // MARK: - Unified Inbound Dispatcher

    /// Single entry point for any `IncomingTVEvent` regardless of transport.
    /// Both the WebSocket adapter (`webSocketManager.onCartIntent`) and the
    /// push-notification adapter (`handlePushNotificationUserInfo`) call this
    /// after parsing/validating their respective payloads.
    ///
    /// Responsibilities:
    ///   - Staleness gate: events older than ``staleEventTTL`` are dropped,
    ///     so a tap on an hour-old notification doesn't surface a stale
    ///     overlay. Events with no `dispatchedAt` skip this gate (no regression
    ///     for back-ends that haven't shipped the field yet).
    ///   - Per-event routing: forwards to `publishXxxIfChanged`, where dedup
    ///     and state mutation live. To add a new event type, see the docs on
    ///     `IncomingTVEvent`.
    public func dispatch(_ event: IncomingTVEvent, source: TVEventSource) {
        switch event {
        case .cartIntent(let cartEvent):
            if let ts = cartEvent.dispatchedAt {
                let age = Date().timeIntervalSince(ts)
                if age > Self.staleEventTTL {
                    VioLogger.debug(
                        "Dropping stale cart_intent (age=\(Int(age))s, ttl=\(Int(Self.staleEventTTL))s, source=\(source.rawValue), activationId=\(cartEvent.activationId.map(String.init) ?? "nil"))",
                        component: "CampaignManager"
                    )
                    return
                }
            }
            publishCartIntentIfChanged(cartEvent, channel: source.rawValue)
        }
    }

    /// Maximum age of a `cart_intent` for the dispatcher to still surface it.
    /// 5 min covers normal network/push delivery slack while killing the
    /// "tapped a notification an hour later" stale-overlay case.
    private static let staleEventTTL: TimeInterval = 5 * 60

    /// Window during which a recently-dispatched `cart_intent` activation
    /// suppresses redundant foreground notification banners. Set to be
    /// comfortably longer than typical WS-vs-APNs delivery skew (~1-2 s) but
    /// shorter than user re-engagement scenarios.
    private static let recentlyDispatchedTTL: TimeInterval = 30

    /// Activation IDs we've published in the last ``recentlyDispatchedTTL``
    /// seconds. Read by `wasActivationRecentlyDispatched(_:)` from the host
    /// app's `UNUserNotificationCenterDelegate.willPresent` to decide whether
    /// the foreground APNs banner is redundant with the overlay we already
    /// raised over WebSocket.
    private var recentlyDispatchedActivations: [Int: Date] = [:]

    /// True if `activationId` was published via the dispatcher within the
    /// last ``recentlyDispatchedTTL`` seconds. Use from `willPresent` to
    /// suppress the foreground banner when the overlay has already handled
    /// the moment.
    public func wasActivationRecentlyDispatched(_ activationId: Int) -> Bool {
        purgeRecentlyDispatched()
        return recentlyDispatchedActivations[activationId] != nil
    }

    private func recordRecentlyDispatched(_ activationId: Int?) {
        guard let id = activationId else { return }
        recentlyDispatchedActivations[id] = Date()
        purgeRecentlyDispatched()
    }

    private func purgeRecentlyDispatched() {
        let cutoff = Date().addingTimeInterval(-Self.recentlyDispatchedTTL)
        recentlyDispatchedActivations = recentlyDispatchedActivations.filter { $0.value >= cutoff }
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
            deeplink: base.deeplink,
            activationId: base.activationId,
            sponsorId: base.sponsorId
        )
        // Push-side adapter into the unified dispatcher. Same convergence point
        // as the WS handler (CampaignManager.bindWebSocketCallbacks → onCartIntent).
        dispatch(.cartIntent(merged), source: .push)
        if let envUid = merged.vioUserId?.trimmingCharacters(in: .whitespacesAndNewlines), !envUid.isEmpty,
           let appUid = userId?.trimmingCharacters(in: .whitespacesAndNewlines), !appUid.isEmpty,
           envUid != appUid {
            print("🎯 [CampaignManager] cart_intent ⚠️ vio_user_id=\(envUid) distinto de CampaignManager.userId=\(appUid) (demo: revisar routing)")
        }
    }

    /// Publishes a `cart_intent` onto ``activeCartIntentEvent`` unless it's a duplicate
    /// of the event already in flight (same `activationId`, or same `(productId, campaignId)`
    /// when the envelope has no `activationId`). Solves the dual-delivery race where the
    /// backend both pushes over WebSocket **and** calls the partner webhook / APNs as
    /// redundancy — both deliveries land and without this gate the product overlay would
    /// open twice.
    private func publishCartIntentIfChanged(_ event: CartIntentEvent, channel: String) {
        if let incoming = event.activationId, let current = activeCartIntentEvent?.activationId, incoming == current {
            // Same activation already on screen — record again so the recent
            // cache stays warm for any later APNs banner suppression even
            // though we don't re-publish.
            recordRecentlyDispatched(incoming)
            print("🎯 [CampaignManager] cart_intent [\(channel)] dedup: activationId=\(incoming) ya publicado — ignorando duplicado")
            return
        }
        if event.activationId == nil,
           let prev = activeCartIntentEvent,
           prev.activationId == nil,
           prev.productId == event.productId,
           prev.campaignId == event.campaignId {
            print("🎯 [CampaignManager] cart_intent [\(channel)] dedup: mismo (productId,campaignId) sin activationId — ignorando duplicado")
            return
        }
        activeCartIntentEvent = event
        recordRecentlyDispatched(event.activationId)
        let pid = event.productId ?? ""
        let aid = event.activationId.map(String.init) ?? "nil"
        let spid = event.sponsorId.map(String.init) ?? "nil"
        print("🎯 [CampaignManager] cart_intent aplicado [\(channel)] productId=\(pid) campaignId=\(event.campaignId.map(String.init) ?? "nil") activationId=\(aid) sponsorId=\(spid) name=\(event.productName ?? "nil") → activeCartIntentEvent (overlay + commerce GraphQL)")
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
                        dict[k] = "<redacted len=\(s.count)>"
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

    /// Strips `apiKey` query values so URLs are safe for `print` / console (no key material, not even a prefix).
    private static func redactApiKeyQuery(in urlString: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"([?&]apiKey=)[^&]*"#,
            options: [.caseInsensitive]
        ) else { return urlString }
        let ns = urlString as NSString
        return regex.stringByReplacingMatches(
            in: urlString,
            options: [],
            range: NSRange(location: 0, length: ns.length),
            withTemplate: "$1<redacted>",
        )
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
    @available(*, deprecated, message: "Use VioRuntime.ensureCommerceReady() or VioRuntime.startSession(...)")
    public func ensureCommerceBootstrapApplied() async {
        let apiKey = VioConfiguration.shared.resolvedSdkApiKey
        guard !apiKey.isEmpty else {
            print("🎯 [CampaignManager] ensureCommerceBootstrapApplied — skip (empty apiKey)")
            return
        }
        await fetchAndApplySdkBootstrap(usingSdkApiKey: apiKey)
    }
    
    /// Loads `GET /v1/sdk/config` and applies `commerce.apiKey` / `commerce.endpoint` for ProductService (GraphQL).
    /// Requests are serialized to avoid races between concurrent bootstrap callers.
    private func fetchAndApplySdkBootstrap(usingSdkApiKey apiKey: String) async {
        if let inFlight = commerceBootstrapTask {
            if commerceBootstrapTaskApiKey == apiKey {
                await inFlight.value
                return
            }
            await inFlight.value
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchAndApplySdkBootstrapNow(usingSdkApiKey: apiKey)
        }
        commerceBootstrapTask = task
        commerceBootstrapTaskApiKey = apiKey
        await task.value
        if commerceBootstrapTaskApiKey == apiKey {
            commerceBootstrapTask = nil
            commerceBootstrapTaskApiKey = nil
        }
    }

    private func fetchAndApplySdkBootstrapNow(usingSdkApiKey apiKey: String, allowRestFallback: Bool = true) async {
        guard !apiKey.isEmpty else {
            VioConfiguration.shared.applySdkBootstrapCommerce(apiKey: nil, graphQLURL: nil)
            return
        }
        let restBase = campaignRestAPIBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var urlComponents = URLComponents(string: "\(restBase)/v2/mobile/config")
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
            let bootstrap: SdkBootstrapResponse
            do {
                bootstrap = try JSONDecoder().decode(SdkBootstrapResponse.self, from: data)
            } catch {
                print("🎯 [CampaignManager] sdk/bootstrap    ❌ decode SdkBootstrapResponse falló: \(error)")
                if let de = error as? DecodingError {
                    print("🎯 [CampaignManager] sdk/bootstrap    DecodingError: \(String(describing: de))")
                }
                if let redacted = Self.sdkConfigJSONRedactedForLogs(data) {
                    let limit = min(2500, redacted.count)
                    print("🎯 [CampaignManager] sdk/bootstrap    body (redactado, prefix \(limit) chars):\n\(redacted.prefix(limit))")
                } else {
                    print("🎯 [CampaignManager] sdk/bootstrap    body no JSON o vacío, bytes=\(data.count)")
                }
                VioLogger.warning("SDK bootstrap JSON decode failed: \(error.localizedDescription)", component: "CampaignManager")
                return
            }
            // v2: commerce auth lives on `primarySponsor.commerce`. The `commerce` convenience
            // alias on SdkBootstrapResponse maps to `primarySponsor.commerce` for compatibility.
            let primarySponsor = VioSponsor(bootstrap: bootstrap.primarySponsor)
            let secondarySponsors = (bootstrap.secondarySponsors ?? []).compactMap { VioSponsor(bootstrap: $0) }
            VioConfiguration.shared.applySdkBootstrapSponsors(primary: primarySponsor, secondaries: secondarySponsors)

            // Populate currentCampaign directly from the v2 bootstrap response.
            // Previously a separate /v1/sdk/campaigns call did this; removed in the
            // v2 multi-sponsor hygiene pass. `/v2/mobile/config` is now the single
            // source of truth for the active campaign + sponsors + commerce.
            if let cb = bootstrap.campaign {
                let campaign = Campaign(
                    id: cb.id,
                    startDate: cb.startDate,
                    endDate: cb.endDate,
                    isPaused: cb.isPaused,
                    campaignLogo: cb.logo,
                    broadcastContext: nil
                )
                await MainActor.run {
                    self.currentCampaign = campaign
                    self.activeCampaigns = [campaign]
                    let paused = (cb.isPaused == true)
                    let active = (cb.isActive ?? true) && !paused
                    self.isCampaignActive = active
                    // CampaignState enum = {upcoming, active, ended}. Paused is orthogonal
                    // (tracked via campaign.isPaused). Derive phase from dates if present.
                    self.campaignState = Campaign(
                        id: cb.id,
                        startDate: cb.startDate,
                        endDate: cb.endDate,
                        isPaused: cb.isPaused,
                        campaignLogo: cb.logo,
                        broadcastContext: nil
                    ).currentState
                }
                CacheManager.shared.saveCampaign(campaign)
                print("🎯 [CampaignManager] sdk/bootstrap    currentCampaign=#\(cb.id) paused=\(cb.isPaused == true) active=\(cb.isActive ?? true)")

                // Cold-start fetch of campaign-level placement instances. Without
                // this, fresh installs only see placements that arrive via WS
                // `component_status_changed` after operator toggles them — which
                // misses anything already-active in the campaign at boot time.
                // Hooked here (inside the bootstrap success path) so it fires
                // for both `VioSession.start()` and direct `discoverCampaigns()`
                // callers (the latter is what most partner demos use today).
                await fetchAndApplyCampaignComponentsIfPossible()
            }

            let key = primarySponsor?.commerce?.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyNonEmpty = (key?.isEmpty == false) ? key : nil
            // Solo aplicar URL del bootstrap cuando hay clave de commerce; si no, evita fijar URLs internas del servidor (p. ej. k8s) sin Authorization válida.
            let gqlForApply: String? = {
                guard keyNonEmpty != nil else { return nil }
                let t = bootstrap.endpoints?.commerceGraphQL?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (t?.isEmpty == false) ? t : nil
            }()
            let featShoppable = bootstrap.features?.shoppable ?? bootstrap.features?.commerce
            if featShoppable == true, keyNonEmpty == nil {
                print("🎯 [CampaignManager] sdk/bootstrap    ⚠️ features.shoppable=true pero primarySponsor.commerce.apiKey vacío; fallback a campaigns.commerceApiKey en vio-config si está definida")
            }
            VioConfiguration.shared.applySdkBootstrapCommerce(apiKey: keyNonEmpty, graphQLURL: gqlForApply)
            print("🎯 [CampaignManager] sdk/bootstrap    primarySponsor=\(primarySponsor?.name ?? "-"), secondary count=\(secondarySponsors.count)")
            if let k = keyNonEmpty {
                VioLogger.debug(
                    "SDK bootstrap: commerce GraphQL Authorization from backend (key len \(k.count))",
                    component: "CampaignManager",
                )
                print("🎯 [CampaignManager] sdk/bootstrap    commerce.apiKey aplicada (len=\(k.count), sin imprimir valor)")
            } else {
                VioLogger.debug(
                    "SDK bootstrap: sin commerce.apiKey en respuesta — ProductService usará VioConfiguration.resolvedCommerceApiKey (apiKey del cliente / DEMO_KEY)",
                    component: "CampaignManager",
                )
                print("🎯 [CampaignManager] sdk/bootstrap    commerce.apiKey ausente — GraphQL usará fallback resolvedCommerceApiKey")
            }
            let cfg = VioConfiguration.shared
            let src = cfg.sdkBootstrapCommerceApiKey != nil ? "bootstrap(/v2/mobile/config)" : "vio-config(apiKey campaña)"
            print("🎯 [CampaignManager] sdk/bootstrap    → commerce listo: fuente=\(src) GraphQL=\(cfg.resolvedCommerceGraphQLURL) authKey len=\(cfg.resolvedCommerceApiKey.count) (sin imprimir)")
        } catch {
            if allowRestFallback,
               activateRestBaseFallbackIfNeeded(currentBase: restBase, error: error, context: "sdk/bootstrap") {
                await fetchAndApplySdkBootstrapNow(usingSdkApiKey: apiKey, allowRestFallback: false)
                return
            }
            VioLogger.warning("SDK bootstrap failed: \(error.localizedDescription)", component: "CampaignManager")
        }
    }
    
    /// Fetch campaign information from API using new v1 endpoint
    /// Uses campaign id from discovery (`discoverCampaigns` / `initializeCampaign`).
    
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

        if shouldReuseLatestDiscoverySnapshot(broadcastId: broadcastId, apiKey: apiKey) {
            print("🎯 [CampaignManager] discoverCampaigns — reusing in-memory snapshot (startup warm state)")
            if let activeCampaign = self.currentCampaign, activeCampaign.isPaused != true {
                await connectWebSocket(campaignId: activeCampaign.id)
            }
            await flushPendingApnsDeviceTokenRegistrationWithVio()
            return
        }

        await runDiscoverCampaignsSingleFlight(broadcastId: broadcastId, apiKey: apiKey)
    }

    private func shouldReuseLatestDiscoverySnapshot(broadcastId: String?, apiKey: String) -> Bool {
        guard lastSuccessfulDiscoveryApiKey == apiKey,
              lastSuccessfulDiscoveryBroadcastId == broadcastId else {
            return false
        }
        return currentCampaign != nil || !activeCampaigns.isEmpty || !activeComponents.isEmpty
    }

    private func runDiscoverCampaignsSingleFlight(broadcastId: String?, apiKey: String) async {
        if let inFlight = discoverCampaignsTask {
            if discoverCampaignsTaskApiKey == apiKey,
               discoverCampaignsTaskBroadcastId == broadcastId {
                await inFlight.value
                return
            }
            await inFlight.value
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.discoverCampaignsNow(broadcastId: broadcastId, apiKey: apiKey)
        }
        discoverCampaignsTask = task
        discoverCampaignsTaskApiKey = apiKey
        discoverCampaignsTaskBroadcastId = broadcastId
        await task.value
        if discoverCampaignsTaskApiKey == apiKey,
           discoverCampaignsTaskBroadcastId == broadcastId {
            discoverCampaignsTask = nil
            discoverCampaignsTaskApiKey = nil
            discoverCampaignsTaskBroadcastId = nil
        }
    }

    /// v2 multi-sponsor discovery — single source of truth is `GET /v2/mobile/config`.
    ///
    /// The legacy `/v1/sdk/campaigns` call was removed (passed apiKey in query, returned
    /// v1 single-sponsor shape that contaminated multi-sponsor state, and duplicated
    /// the campaign info already present in `/v2/mobile/config`). The bootstrap now
    /// populates `currentCampaign` + `activeCampaigns` directly from the v2 response.
    ///
    /// Components are NOT fetched here anymore — they arrive via WS
    /// `component_status_changed` events and per-broadcast
    /// `GET /v2/mobile/broadcasts/:id/components` when a broadcast is opened.
    private func discoverCampaignsNow(
        broadcastId: String? = nil,
        apiKey: String
    ) async {
        print("🎯 [CampaignManager] discoverCampaigns → v2 bootstrap only")

        // Bootstrap: sponsors + commerce keys + currentCampaign all populated here.
        await fetchAndApplySdkBootstrap(usingSdkApiKey: apiKey)

        // Enrich campaign logo from dynamic brand config if the bootstrap didn't include one.
        if var active = self.currentCampaign, active.campaignLogo == nil {
            if let dynamicConfig = await DynamicConfigurationManager.shared.loadCampaignConfig(
                campaignId: active.id,
                broadcastId: nil
            ), let brandLogoUrl = dynamicConfig.brand?.logoUrl, !brandLogoUrl.isEmpty {
                active = Campaign(
                    id: active.id,
                    startDate: active.startDate,
                    endDate: active.endDate,
                    isPaused: active.isPaused,
                    campaignLogo: brandLogoUrl,
                    broadcastContext: active.broadcastContext
                )
                await MainActor.run { self.currentCampaign = active }
                if let brandConfig = dynamicConfig.brand {
                    VioConfiguration.shared.updateDynamicBrandConfig(brandConfig)
                }
                print("🎯 [Sponsor] enriched campaignLogo from dynamic brand config: \(brandLogoUrl)")
            }
        }

        // Connect WebSocket for the active campaign (cart_intent, campaign events, etc.)
        if let activeCampaign = self.currentCampaign, activeCampaign.isPaused != true {
            print("🎯 [CampaignManager] discoverCampaigns - Connecting WebSocket for campaignId: \(activeCampaign.id)")
            await connectWebSocket(campaignId: activeCampaign.id)
        }

        await flushPendingApnsDeviceTokenRegistrationWithVio()
        lastSuccessfulDiscoveryApiKey = apiKey
        lastSuccessfulDiscoveryBroadcastId = broadcastId
    }

    private func activateRestBaseFallbackIfNeeded(
        currentBase: String,
        error: Error,
        context: String
    ) -> Bool {
        guard let urlError = error as? URLError else { return false }
        let connectivityCodes: Set<URLError.Code> = [
            .cannotConnectToHost, .timedOut, .networkConnectionLost, .notConnectedToInternet
        ]
        guard connectivityCodes.contains(urlError.code) else { return false }

        let fallbackRaw = CampaignConfiguration.default.restAPIBaseURL
        let fallbackBase = fallbackRaw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedCurrent = currentBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !fallbackBase.isEmpty, fallbackBase != trimmedCurrent else { return false }

        // Keep REST and WS on the same environment/base to avoid split-brain behavior.
        let fallbackWs = deriveWebSocketBase(fromRestBase: fallbackBase)
        campaignRestBaseOverride = fallbackBase
        campaignWebSocketBaseOverride = fallbackWs
        print("🎯 [CampaignManager] \(context) fallback activated → REST=\(fallbackBase) WS=\(fallbackWs)")
        VioLogger.warning(
            "\(context) connectivity failed on \(trimmedCurrent); retrying with REST=\(fallbackBase) WS=\(fallbackWs)",
            component: "CampaignManager"
        )
        return true
    }

    private func deriveWebSocketBase(fromRestBase restBase: String) -> String {
        let trimmed = restBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: trimmed) else {
            return campaignWebSocketBaseURL
        }
        if components.scheme == "https" {
            components.scheme = "wss"
        } else if components.scheme == "http" {
            components.scheme = "ws"
        } else if components.scheme == nil {
            components.scheme = "wss"
        }
        return (components.string ?? trimmed).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    // Backward compatibility method
    @available(*, deprecated, renamed: "discoverCampaigns(broadcastId:)")
    public func discoverCampaigns(matchId: String? = nil) async {
        await discoverCampaigns(broadcastId: matchId)
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
        if let existingManager = webSocketManager {
            // If a stale manager exists while disconnected, recycle it so startup/discovery
            // can actively reconnect after transport resets or exhausted internal retries.
            print("🎯 [CampaignManager] connectWebSocket - Recreating stale manager while disconnected")
            existingManager.disconnect()
            webSocketManager = nil
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
                // WS-side adapter into the unified dispatcher. Same convergence
                // point as the push handler (applyCartIntentFromNotificationUserInfo).
                self?.dispatch(.cartIntent(event), source: .webSocket)
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

        // Components arrive via WS `component_status_changed` events + per-broadcast
        // `GET /v2/mobile/broadcasts/:id/components` on demand. Legacy /v1/offers
        // polling removed (v2 multi-sponsor hygiene).

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

        // Components arrive via WS + per-broadcast v2 call. Legacy /v1/offers removed.

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
                
                // De-dup by (id + locationId) only — multi-location placements
                // legitimately share a template id across slots (e.g. one
                // `product-carousel-template` instance in `home_top` for XXL +
                // another in `match_pre_kickoff` for Torshov). Removing by
                // `type` alone clobbered the other slot whenever any toggle
                // arrived. Mirrors the cold-start fetch dedupe key in
                // `fetchAndApplyCampaignComponentsIfPossible`.
                if let index = activeComponents.firstIndex(where: {
                    $0.id == componentId && $0.locationId == component.locationId
                }) {
                    activeComponents[index] = component
                } else {
                    activeComponents.append(component)
                }

                // Save to cache
                CacheManager.shared.saveComponents(activeComponents)
            } else {
                // Remove component — match the same composite key so we don't
                // accidentally drop another location's instance of the same id.
                activeComponents.removeAll {
                    $0.id == componentId && $0.locationId == component.locationId
                }

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
    /// Posted when commerce bootstrap credentials change (apply or clear) so clients can invalidate cached GraphQL state.
    public static let vioCommerceBootstrapDidApply = Notification.Name("io.vio.sdk.commerceBootstrapDidApply")
}

