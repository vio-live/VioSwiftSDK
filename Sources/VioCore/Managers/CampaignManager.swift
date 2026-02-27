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
    
    // MARK: - Private Properties
    private var campaignId: Int?  // Legacy: single campaign ID (for backward compatibility)
    private var webSocketManager: CampaignWebSocketManager?
    private var cancellables = Set<AnyCancellable>()
    private var baseURL: String  // For REST API (GraphQL base URL)
    private var isInitializing = false  // Flag to prevent multiple simultaneous initializations
    
    // Campaign endpoints from configuration
    private var campaignWebSocketBaseURL: String {
        VioConfiguration.shared.campaignConfiguration.webSocketBaseURL
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
        
        // Check if auto-discovery is enabled
        let autoDiscover = config.campaignConfiguration.autoDiscover
        let configuredCampaignId = config.liveShowConfiguration.campaignId
        
        VioLogger.debug("init: autoDiscover=\(autoDiscover), campaignId=\(configuredCampaignId)", component: "CampaignManager")
        
        // Backward compatibility logic:
        // - If autoDiscover is true, use auto-discovery (campaignId can be 0)
        // - If autoDiscover is false and campaignId > 0, use legacy single campaign mode
        // - If both are false/0, campaigns are disabled
        if autoDiscover {
            // Auto-discovery mode - campaigns will be discovered when setBroadcastContext is called
            VioLogger.debug("init: Auto-discovery enabled, waiting for setBroadcastContext", component: "CampaignManager")
            self.isCampaignActive = true
            self.campaignState = .active
        } else if configuredCampaignId > 0 {
            // Legacy mode - single campaign
            self.campaignId = configuredCampaignId
            VioLogger.debug("init: Legacy mode, campaignId=\(configuredCampaignId)", component: "CampaignManager")
            Task {
                await initializeCampaign()
            }
        } else {
            // No campaign configured - SDK works normally without restrictions
            self.isCampaignActive = true
            self.campaignState = .active
            VioLogger.debug("init: No campaignId configured, campaigns disabled", component: "CampaignManager")
        }
    }
    
    // MARK: - Public Methods
    
    /// Reinitialize campaign manager with current configuration
    /// Called automatically when VioConfiguration is updated
    public func reinitialize() {
        VioLogger.debug("reinitialize: Starting", component: "CampaignManager")
        // Disconnect existing connection
        disconnect()
        
        // Get current configuration
        let config = VioConfiguration.shared
        let configuredCampaignId = config.liveShowConfiguration.campaignId
        VioLogger.debug("reinitialize: campaignId from config=\(configuredCampaignId), previous=\(self.campaignId ?? -1)", component: "CampaignManager")
        
        // Update base URL
        self.baseURL = config.environment.graphQLURL
            .replacingOccurrences(of: "/graphql", with: "")
            .replacingOccurrences(of: "/v1/graphql", with: "")
        
        // If campaignId is 0 or not configured, campaigns are disabled (normal SDK behavior)
        if configuredCampaignId > 0 {
            self.campaignId = configuredCampaignId
            VioLogger.debug("reinitialize: Setting campaignId=\(configuredCampaignId)", component: "CampaignManager")
            Task {
                await initializeCampaign()
            }
        } else {
            // No campaign configured - SDK works normally without restrictions
            self.campaignId = nil
            self.isCampaignActive = true
            self.campaignState = .active
            self.activeComponents.removeAll()
            VioLogger.debug("reinitialize: No campaignId, campaigns disabled", component: "CampaignManager")
        }
    }
    
    /// Initialize campaign connection (called automatically if campaignId > 0)
    public func initializeCampaign() async {
        guard let campaignId = campaignId, campaignId > 0 else {
            VioLogger.debug("initializeCampaign: No campaignId, skipping", component: "CampaignManager")
            return
        }
        
        // Prevent multiple simultaneous initializations
        guard !isInitializing else {
            // Campaign initialization already in progress, skip
            VioLogger.debug("initializeCampaign: Already initializing, skipping", component: "CampaignManager")
            return
        }
        
        isInitializing = true
        defer { 
            isInitializing = false
            VioLogger.debug("initializeCampaign: Completed", component: "CampaignManager")
        }
        
        VioLogger.debug("initializeCampaign: Starting for campaignId=\(campaignId)", component: "CampaignManager")
        
        // 0. Load dynamic configuration from backend
        if let config = await DynamicConfigurationManager.shared.loadCampaignConfig(
            campaignId: campaignId,
            broadcastId: currentBroadcastContext?.broadcastId
        ) {
            // Update VioConfiguration with dynamic config
            if let brandConfig = config.brand {
                VioConfiguration.shared.updateDynamicBrandConfig(brandConfig)
            }
            if let engagementConfig = config.engagement {
                VioConfiguration.shared.updateDynamicEngagementConfig(engagementConfig)
            }
            if let commerceConfig = config.integrations?.commerce {
                VioConfiguration.shared.updateDynamicCommerceConfig(commerceConfig)
            }
            VioLogger.debug("initializeCampaign: Loaded dynamic config for campaignId=\(campaignId)", component: "CampaignManager")
        }
        
        // 0.5. Load from cache first for instant UI update
        loadFromCache()
        
        // 1. Fetch campaign info and determine initial state
        await fetchCampaignInfo(campaignId: campaignId)
        
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
        VioLogger.debug("setBroadcastContext: broadcastId=\(context.broadcastId)", component: "CampaignManager")
        
        // Clear components from previous context
        self.activeComponents.removeAll()
        
        // Set new context
        self.currentBroadcastContext = context
        
        // Load engagement config for this broadcast
        if let engagementConfig = await DynamicConfigurationManager.shared.loadEngagementConfig(broadcastId: context.broadcastId) {
            VioConfiguration.shared.updateDynamicEngagementConfig(engagementConfig)
            VioLogger.debug("setBroadcastContext: Loaded engagement config for broadcastId=\(context.broadcastId)", component: "CampaignManager")
        }
        
        // Reload campaigns and components for this context
        await refreshCampaignsForContext(context)
    }
    
    /// Refresh campaigns and components for a specific broadcast context
    private func refreshCampaignsForContext(_ context: BroadcastContext) async {
        let config = VioConfiguration.shared
        
        // Check if auto-discovery is enabled
        if config.campaignConfiguration.autoDiscover {
            // Use auto-discovery
            await discoverCampaigns(broadcastId: context.broadcastId)
        } else if let campaignId = campaignId, campaignId > 0 {
            // Use legacy single campaign mode
            await initializeCampaign()
        }
        
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
        VioLogger.debug("filterComponentsByContext: \(self.activeComponents.count) components for broadcastId=\(context.broadcastId)", component: "CampaignManager")
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
        // If no campaign configured, show everything
        guard campaignId != nil && campaignId! > 0 else {
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
    public func getActiveComponent(type: String, componentId: String? = nil) -> Component? {
        guard isCampaignActive else { return nil }
        
        if let componentId = componentId {
            // Search by type AND specific componentId
            return activeComponents.first { 
                $0.type == type && $0.id == componentId && $0.isActive 
            }
        } else {
            // Current behavior: return the first one found
            return activeComponents.first { $0.type == type && $0.isActive }
        }
    }
    
    /// Get all active components by type
    public func getActiveComponents(type: String) -> [Component] {
        guard isCampaignActive else { return [] }
        return activeComponents.filter { $0.type == type && $0.isActive }
    }
    
    /// Disconnect from campaign
    public func disconnect() {
        webSocketManager?.disconnect()
        webSocketManager = nil
        isConnected = false
    }
    
    // MARK: - Private Methods
    
    /// Load campaign and components from cache for instant UI update
    private func loadFromCache() {
        let config = VioConfiguration.shared
        let currentCampaignId = config.liveShowConfiguration.campaignId
        let currentApiKey = config.campaignConfiguration.campaignApiKey.isEmpty 
            ? (config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey)
            : config.campaignConfiguration.campaignApiKey
        let currentBaseURL = self.baseURL
        
        // Validate cache configuration BEFORE loading anything
        let validation = CacheManager.shared.validateCacheConfiguration(
            currentCampaignId: currentCampaignId,
            currentCampaignAdminApiKey: currentApiKey,
            currentBaseURL: currentBaseURL
        )
        
        if validation.shouldClearCache {
            // Configuration changed or version mismatch - clear cache and hide components
            VioLogger.debug("loadFromCache: Configuration changed, clearing cache", component: "CampaignManager")
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
    
    /// Fetch campaign information from API using new v1 endpoint
    /// Always uses campaignId from configuration file (vio-config.json)
    private func fetchCampaignInfo(campaignId: Int) async {
        let config = VioConfiguration.shared
        
        // Use Vio App API key (campaignApiKey or root apiKey)
        let vioApiKey = config.campaignConfiguration.campaignApiKey.isEmpty 
            ? (config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey)  // Fallback to root apiKey if not configured
            : config.campaignConfiguration.campaignApiKey
        
        // Always use campaignId from configuration file (vio-config.json)
        let configuredCampaignId = config.liveShowConfiguration.campaignId
        guard configuredCampaignId > 0 else {
            VioLogger.warning("No campaignId configured in liveShow.campaignId - skipping campaign info fetch", component: "CampaignManager")
            return
        }
        
        let urlString = "\(campaignRestAPIBaseURL)/v1/sdk/config?apiKey=\(vioApiKey)&campaignId=\(configuredCampaignId)"
        VioLogger.debug("fetchCampaignInfo: campaignId=\(configuredCampaignId)", component: "CampaignManager")
        
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
            
            let (data, response) = try await URLSession.shared.data(for: request)
            responseData = data
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if httpResponse.statusCode == 404 {
                    VioLogger.warning("Campaign \(campaignId) not found - SDK works normally", component: "CampaignManager")
                    // Campaign not found - allow normal SDK behavior
                    self.isCampaignActive = true
                    self.campaignState = .active
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                    VioLogger.error("Campaign info request failed with status \(httpResponse.statusCode): \(responseString)", component: "CampaignManager")
                    // On error, allow normal SDK behavior
                    self.isCampaignActive = true
                    self.campaignState = .active
                    return
                }
            } else {
            }
            
            // Validate that we received JSON, not HTML
            if let responseString = String(data: data, encoding: .utf8), responseString.trimmingCharacters(in: .whitespaces).hasPrefix("<") {
                VioLogger.error("Received HTML instead of JSON from campaign endpoint", component: "CampaignManager")
                // On error, allow normal SDK behavior
                self.isCampaignActive = true
                self.campaignState = .active
                return
            }
            
            // Log raw JSON response for debugging
            
            // Decode new SDK config response
            let sdkConfig = try JSONDecoder().decode(SDKConfigResponse.self, from: data)
            
            // Create Campaign model from SDK config response
            // Note: The new endpoint doesn't return startDate/endDate/isPaused, so we preserve existing values
            let existingCampaign = self.currentCampaign
            
            let campaign = Campaign(
                id: sdkConfig.campaignId,
                startDate: existingCampaign?.startDate,
                endDate: existingCampaign?.endDate,
                isPaused: existingCampaign?.isPaused,
                campaignLogo: sdkConfig.campaignLogo,
                broadcastContext: sdkConfig.broadcastContext ?? existingCampaign?.broadcastContext
            )
            
            
            // Detect changes in campaign configuration
            let oldLogoUrl = existingCampaign?.campaignLogo
            let newLogoUrl = campaign.campaignLogo
            
            // Check if campaign configuration changed
            let campaignChanged = existingCampaign != campaign
            
            self.currentCampaign = campaign
            
            self.campaignState = campaign.currentState
            
            // If campaign configuration changed, invalidate cache appropriately
            if campaignChanged {
                // Check if logo specifically changed
                let logoChanged = oldLogoUrl != newLogoUrl
                
                if logoChanged, let oldLogo = oldLogoUrl {
                    // Logo changed - invalidate old logo
                        VioLogger.debug("Logo changed, invalidating old: \(oldLogo)", component: "CampaignManager")
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
                    VioLogger.debug("Campaign config changed (logo unchanged), invalidating: \(currentLogo)", component: "CampaignManager")
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
            let apiKey = config.campaignConfiguration.campaignApiKey.isEmpty 
                ? (config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey)
                : config.campaignConfiguration.campaignApiKey
            CacheManager.shared.saveCacheConfiguration(
                campaignId: campaign.id,
                campaignAdminApiKey: apiKey,
                baseURL: self.baseURL
            )
            
        } catch let decodingError as DecodingError {
            if case .dataCorrupted(let context) = decodingError {
                VioLogger.debug("Decoding error at: \(context.debugDescription)", component: "CampaignManager")
            }
            VioLogger.error("Failed to decode campaign info: \(decodingError)", component: "CampaignManager")
            // On error, allow normal SDK behavior
            self.isCampaignActive = true
            self.campaignState = .active
        } catch {
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
        let apiKey = config.apiKey
        
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
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                    VioLogger.error("Campaigns discovery failed with status \(httpResponse.statusCode): \(responseString)", component: "CampaignManager")
                    return
                }
            }
            
            // Decode campaigns discovery response
            let discoveryResponse = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: data)
            
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
            if let firstActiveCampaign = discoveredCampaigns.first(where: { $0.currentState == .active && $0.isPaused != true }) {
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
                        VioLogger.debug("Logo changed in discovery, invalidating: \(oldLogo)", component: "CampaignManager")
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
                        VioLogger.debug("Campaign config changed in discovery, invalidating: \(currentLogo)", component: "CampaignManager")
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
            }
            
            // Cache components
            CacheManager.shared.saveComponents(self.activeComponents)
            
            VioLogger.debug("discoverCampaigns: \(discoveredCampaigns.count) campaigns, \(self.activeComponents.count) components", component: "CampaignManager")
            
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
    /// Always uses campaignId from configuration file (vio-config.json)
    private func fetchActiveComponents(campaignId: Int) async {
        let config = VioConfiguration.shared
        
        // Use Vio App API key (campaignApiKey or root apiKey)
        let vioApiKey = config.campaignConfiguration.campaignApiKey.isEmpty 
            ? (config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey)  // Fallback to root apiKey if not configured
            : config.campaignConfiguration.campaignApiKey
        
        let countryCode = config.marketConfiguration.countryCode
        
        // Always use campaignId from configuration file (vio-config.json)
        let configuredCampaignId = config.liveShowConfiguration.campaignId
        guard configuredCampaignId > 0 else {
            VioLogger.warning("No campaignId configured in liveShow.campaignId - skipping components fetch", component: "CampaignManager")
            return
        }
        
        // Build URL with query parameters
        var urlComponents = URLComponents(string: "\(campaignRestAPIBaseURL)/v1/offers")
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: vioApiKey),
            URLQueryItem(name: "campaignId", value: "\(configuredCampaignId)")
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
    /// Always uses campaignId from configuration file (vio-config.json)
    /// According to backend behavior:
    /// - If campaign is Ended: Backend sends campaign_ended immediately
    /// - If campaign is Upcoming: No event sent, waits for campaign_started
    /// - If campaign is Active: No event sent, can fetch components
    private func connectWebSocket(campaignId: Int) async {
        // Always use campaignId from configuration file (vio-config.json)
        let config = VioConfiguration.shared
        let configuredCampaignId = config.liveShowConfiguration.campaignId
        guard configuredCampaignId > 0 else {
            VioLogger.warning("No campaignId configured in liveShow.campaignId - skipping WebSocket connection", component: "CampaignManager")
            return
        }
        
        VioLogger.debug("connectWebSocket: campaignId=\(configuredCampaignId)", component: "CampaignManager")
        
        // Use the campaign WebSocket endpoint, not the GraphQL endpoint
        webSocketManager = CampaignWebSocketManager(campaignId: configuredCampaignId, baseURL: campaignWebSocketBaseURL)
        
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
                
                // According to backend behavior:
                // - If campaign is Ended: Backend sends campaign_ended immediately when connection opens
                // - If campaign is Upcoming: No event sent, waits for campaign_started
                // - If campaign is Active: No event sent, can fetch components
                // The event handlers above will process these events automatically
            }
        }
        
        await webSocketManager?.connect()
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
            VioLogger.debug("Campaign ended, clearing logo: \(logoUrl)", component: "CampaignManager")
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
    }
    
    private func handleCampaignPaused(_ event: CampaignPausedEvent) {
        VioLogger.info("Campaign paused: \(event.campaignId)", component: "CampaignManager")
        
        isCampaignActive = false
        
        // Immediately hide ALL components
        activeComponents.removeAll()
        
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
}

