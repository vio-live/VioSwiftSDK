import Foundation

/// Manager for loading and caching dynamic configurations from backend
/// Provides fallback to local configuration and intelligent caching
@MainActor
public class DynamicConfigurationManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = DynamicConfigurationManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isDynamicConfigEnabled: Bool = true
    
    // MARK: - Private Properties
    
    // Cache storage
    private var campaignConfigCache: [Int: CachedConfig<CampaignConfig>] = [:]
    private var engagementConfigCache: [String: CachedConfig<DynamicEngagementConfig>] = [:]
    private var localizationCache: [String: CachedConfig<DynamicLocalizationConfig>] = [:]
    
    // API client
    private let apiClient = ConfigAPIClient()
    
    // Feature flag - can be controlled via local config initially
    private var useDynamicConfig: Bool {
        // Check if dynamic config is enabled in local config
        let config = VioConfiguration.shared
        return isDynamicConfigEnabled && config.engagementConfiguration.useDynamicConfig
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Load campaign configuration
    /// - Parameters:
    ///   - campaignId: Campaign ID
    ///   - broadcastId: Optional broadcast ID for broadcast-specific overrides
    /// - Returns: Campaign configuration or nil if unavailable
    public func loadCampaignConfig(
        campaignId: Int,
        broadcastId: String? = nil
    ) async -> CampaignConfig? {
        guard useDynamicConfig else {
            VioLogger.debug("Dynamic config disabled, skipping backend fetch", component: "DynamicConfigManager")
            return nil
        }
        
        // Check cache first
        if let cached = campaignConfigCache[campaignId],
           !cached.isExpired {
            VioLogger.debug("Using cached campaign config for campaignId: \(campaignId)", component: "DynamicConfigManager")
            return cached.data
        }
        
        // Fetch from backend
        do {
            let config = try await apiClient.fetchCampaignConfig(
                campaignId: campaignId,
                broadcastId: broadcastId
            )
            
            // Cache the result
            let ttl = TimeInterval(config.cache?.ttl ?? 300)
            campaignConfigCache[campaignId] = CachedConfig(data: config, ttl: ttl)
            
            VioLogger.debug("Loaded campaign config from backend for campaignId: \(campaignId)", component: "DynamicConfigManager")
            return config
            
        } catch {
            VioLogger.warning("Failed to load campaign config from backend: \(error.localizedDescription)", component: "DynamicConfigManager")
            return nil
        }
    }
    
    /// Load engagement configuration for a broadcast
    /// - Parameter broadcastId: Broadcast ID
    /// - Returns: Engagement configuration or nil if unavailable
    public func loadEngagementConfig(broadcastId: String) async -> DynamicEngagementConfig? {
        guard useDynamicConfig else {
            VioLogger.debug("Dynamic config disabled, skipping backend fetch", component: "DynamicConfigManager")
            return nil
        }
        
        // Check cache first
        if let cached = engagementConfigCache[broadcastId],
           !cached.isExpired {
            VioLogger.debug("Using cached engagement config for broadcastId: \(broadcastId)", component: "DynamicConfigManager")
            return cached.data
        }
        
        // Fetch from backend
        do {
            let config = try await apiClient.fetchEngagementConfig(broadcastId: broadcastId)
            
            // Cache the result (default TTL: 5 minutes)
            engagementConfigCache[broadcastId] = CachedConfig(data: config, ttl: 300)
            
            VioLogger.debug("Loaded engagement config from backend for broadcastId: \(broadcastId)", component: "DynamicConfigManager")
            return config
            
        } catch {
            VioLogger.warning("Failed to load engagement config from backend: \(error.localizedDescription)", component: "DynamicConfigManager")
            return nil
        }
    }
    
    // Backward compatibility method
    @available(*, deprecated, renamed: "loadEngagementConfig(broadcastId:)")
    public func loadEngagementConfig(matchId: String) async -> DynamicEngagementConfig? {
        return await loadEngagementConfig(broadcastId: matchId)
    }
    
    /// Load localization configuration
    /// - Parameters:
    ///   - language: Language code (e.g., "no", "en")
    ///   - campaignId: Optional campaign ID for campaign-specific translations
    ///   - broadcastId: Optional broadcast ID for broadcast-specific translations
    /// - Returns: Localization configuration or nil if unavailable
    public func loadLocalization(
        language: String,
        campaignId: Int? = nil,
        broadcastId: String? = nil
    ) async -> DynamicLocalizationConfig? {
        guard useDynamicConfig else {
            VioLogger.debug("Dynamic config disabled, skipping backend fetch", component: "DynamicConfigManager")
            return nil
        }
        
        // Create cache key
        let cacheKey = "\(language)_\(campaignId ?? 0)_\(broadcastId ?? "")"
        
        // Check cache first
        if let cached = localizationCache[cacheKey],
           !cached.isExpired {
            VioLogger.debug("Using cached localization for language: \(language)", component: "DynamicConfigManager")
            return cached.data
        }
        
        // Fetch from backend
        do {
            let config = try await apiClient.fetchLocalization(
                language: language,
                campaignId: campaignId,
                broadcastId: broadcastId
            )
            
            // Cache the result (default TTL: 1 hour)
            let ttl = TimeInterval(config.cache?.ttl ?? 3600)
            localizationCache[cacheKey] = CachedConfig(data: config, ttl: ttl)
            
            VioLogger.debug("Loaded localization from backend for language: \(language)", component: "DynamicConfigManager")
            return config
            
        } catch {
            VioLogger.warning("Failed to load localization from backend: \(error.localizedDescription)", component: "DynamicConfigManager")
            return nil
        }
    }
    
    // Backward compatibility method
    @available(*, deprecated, renamed: "loadLocalization(language:campaignId:broadcastId:)")
    public func loadLocalization(
        language: String,
        campaignId: Int? = nil,
        matchId: String? = nil
    ) async -> DynamicLocalizationConfig? {
        return await loadLocalization(language: language, campaignId: campaignId, broadcastId: matchId)
    }
    
    // Backward compatibility method for loadCampaignConfig
    @available(*, deprecated, renamed: "loadCampaignConfig(campaignId:broadcastId:)")
    public func loadCampaignConfig(
        campaignId: Int,
        matchId: String? = nil
    ) async -> CampaignConfig? {
        return await loadCampaignConfig(campaignId: campaignId, broadcastId: matchId)
    }
    
    /// Invalidate cache for specific campaign/broadcast or all cache
    /// - Parameters:
    ///   - campaignId: Optional campaign ID to invalidate
    ///   - broadcastId: Optional broadcast ID to invalidate
    public func invalidateCache(campaignId: Int? = nil, broadcastId: String? = nil) {
        if let campaignId = campaignId {
            campaignConfigCache.removeValue(forKey: campaignId)
            VioLogger.debug("Invalidated cache for campaignId: \(campaignId)", component: "DynamicConfigManager")
        }
        
        if let broadcastId = broadcastId {
            engagementConfigCache.removeValue(forKey: broadcastId)
            VioLogger.debug("Invalidated cache for broadcastId: \(broadcastId)", component: "DynamicConfigManager")
        }
        
        // If no specific IDs provided, clear all cache
        if campaignId == nil && broadcastId == nil {
            campaignConfigCache.removeAll()
            engagementConfigCache.removeAll()
            localizationCache.removeAll()
            VioLogger.debug("Invalidated all configuration cache", component: "DynamicConfigManager")
        }
    }
    
    /// Enable or disable dynamic configuration
    /// - Parameter enabled: Whether to enable dynamic config
    public func setDynamicConfigEnabled(_ enabled: Bool) {
        isDynamicConfigEnabled = enabled
        if !enabled {
            // Clear cache when disabling - use explicit parameterless call
            invalidateCache(campaignId: nil, broadcastId: nil)
        }
        VioLogger.debug("Dynamic config \(enabled ? "enabled" : "disabled")", component: "DynamicConfigManager")
    }
    
    /// Handle WebSocket config update event
    /// - Parameter event: Config update event payload
    public func handleConfigUpdateEvent(
        campaignId: Int?,
        broadcastId: String?,
        sections: [String]
    ) {
        VioLogger.debug("Received config update event for campaignId: \(campaignId ?? 0), broadcastId: \(broadcastId ?? "none"), sections: \(sections)", component: "DynamicConfigManager")
        
        // Invalidate affected cache
        invalidateCache(campaignId: campaignId, broadcastId: broadcastId)
        
        // Reload affected configurations
        Task {
            if let campaignId = campaignId {
                if sections.contains("brand") || sections.contains("engagement") || sections.contains("ui") || sections.contains("features") {
                    let _ = await loadCampaignConfig(campaignId: campaignId, broadcastId: broadcastId)
                }
            }
            
            if let broadcastId = broadcastId, sections.contains("engagement") {
                let _ = await loadEngagementConfig(broadcastId: broadcastId)
            }
        }
    }
    
    // Backward compatibility method
    @available(*, deprecated, renamed: "handleConfigUpdateEvent(campaignId:broadcastId:sections:)")
    public func handleConfigUpdateEvent(
        campaignId: Int?,
        matchId: String?,
        sections: [String]
    ) {
        handleConfigUpdateEvent(campaignId: campaignId, broadcastId: matchId, sections: sections)
    }
    
    // Backward compatibility method
    @available(*, deprecated, renamed: "invalidateCache(campaignId:broadcastId:)")
    public func invalidateCache(campaignId: Int? = nil, matchId: String? = nil) {
        invalidateCache(campaignId: campaignId, broadcastId: matchId)
    }
}
