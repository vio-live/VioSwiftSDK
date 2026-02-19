import Foundation

/// Cache Manager for persisting campaign and component data
/// Provides fast initial load by reading from disk cache
/// Automatically updates cache when data changes via WebSocket
@MainActor
public class CacheManager {
    
    // MARK: - Singleton
    public static let shared = CacheManager()
    
    // MARK: - Cache Keys
    private enum CacheKeys {
        static let campaign = "reachu.cache.campaign"
        static let components = "reachu.cache.components"
        static let campaignState = "reachu.cache.campaignState"
        static let isCampaignActive = "reachu.cache.isCampaignActive"
        static let lastUpdated = "reachu.cache.lastUpdated"
        static let cacheConfigHash = "reachu.cache.configHash"
        static let cacheVersion = "reachu.cache.version"
    }
    
    // MARK: - Cache Version
    /// Current cache format version (increment when cache structure changes)
    private static let currentCacheVersion = 2
    
    // MARK: - Cache Expiration
    /// Cache expiration time in seconds (default: 24 hours)
    public var cacheExpirationInterval: TimeInterval = 24 * 60 * 60
    
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    private init() {
        self.userDefaults = UserDefaults.standard
    }
    
    // MARK: - Campaign Cache
    
    /// Save campaign to cache
    public func saveCampaign(_ campaign: Campaign) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(campaign)
            userDefaults.set(data, forKey: CacheKeys.campaign)
            userDefaults.set(Date(), forKey: CacheKeys.lastUpdated)
            VioLogger.debug("Campaign cached: ID \(campaign.id)", component: "CacheManager")
        } catch {
            VioLogger.error("Failed to cache campaign: \(error)", component: "CacheManager")
        }
    }
    
    /// Load campaign from cache
    /// - Returns: Cached campaign if available and not expired, nil otherwise
    public func loadCampaign() -> Campaign? {
        guard let data = userDefaults.data(forKey: CacheKeys.campaign),
              isCacheValid() else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let campaign = try decoder.decode(Campaign.self, from: data)
            VioLogger.debug("Campaign loaded from cache: ID \(campaign.id)", component: "CacheManager")
            return campaign
        } catch {
            VioLogger.error("Failed to decode cached campaign: \(error)", component: "CacheManager")
            return nil
        }
    }
    
    /// Save campaign state to cache
    public func saveCampaignState(_ state: CampaignState, isActive: Bool) {
        do {
            let encoder = JSONEncoder()
            let stateData = try encoder.encode(state)
            userDefaults.set(stateData, forKey: CacheKeys.campaignState)
            userDefaults.set(isActive, forKey: CacheKeys.isCampaignActive)
            userDefaults.set(Date(), forKey: CacheKeys.lastUpdated)
            VioLogger.debug("Campaign state cached: \(state.rawValue), active: \(isActive)", component: "CacheManager")
        } catch {
            VioLogger.error("Failed to cache campaign state: \(error)", component: "CacheManager")
        }
    }
    
    /// Load campaign state from cache
    /// - Returns: Tuple of (state, isActive) if available and not expired, nil otherwise
    public func loadCampaignState() -> (state: CampaignState, isActive: Bool)? {
        guard isCacheValid(),
              let stateData = userDefaults.data(forKey: CacheKeys.campaignState) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let state = try decoder.decode(CampaignState.self, from: stateData)
            let isActive = userDefaults.bool(forKey: CacheKeys.isCampaignActive)
            VioLogger.debug("Campaign state loaded from cache: \(state.rawValue), active: \(isActive)", component: "CacheManager")
            return (state, isActive)
        } catch {
            VioLogger.error("Failed to decode cached campaign state: \(error)", component: "CacheManager")
            return nil
        }
    }
    
    // MARK: - Components Cache
    
    /// Save components to cache
    public func saveComponents(_ components: [Component]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(components)
            userDefaults.set(data, forKey: CacheKeys.components)
            userDefaults.set(Date(), forKey: CacheKeys.lastUpdated)
            VioLogger.debug("Cached \(components.count) components", component: "CacheManager")
        } catch {
            VioLogger.error("Failed to cache components: \(error)", component: "CacheManager")
        }
    }
    
    /// Load components from cache
    /// - Returns: Cached components if available and not expired, empty array otherwise
    public func loadComponents() -> [Component] {
        guard let data = userDefaults.data(forKey: CacheKeys.components),
              isCacheValid() else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let components = try decoder.decode([Component].self, from: data)
            VioLogger.debug("Loaded \(components.count) components from cache", component: "CacheManager")
            return components
        } catch {
            VioLogger.error("Failed to decode cached components: \(error)", component: "CacheManager")
            return []
        }
    }
    
    // MARK: - Cache Validation
    
    /// Check if cache is still valid (not expired)
    private func isCacheValid() -> Bool {
        guard let lastUpdated = userDefaults.object(forKey: CacheKeys.lastUpdated) as? Date else {
            return false
        }
        
        let age = Date().timeIntervalSince(lastUpdated)
        let isValid = age < cacheExpirationInterval
        
        if !isValid {
            VioLogger.debug("Cache expired (age: \(Int(age))s, max: \(Int(cacheExpirationInterval))s)", component: "CacheManager")
        }
        
        return isValid
    }
    
    // MARK: - Configuration Cache Validation
    
    /// Calculate hash of campaign configuration for cache validation
    /// Uses a combination of campaignId, API key, and base URL to detect configuration changes
    private func calculateConfigHash(campaignId: Int, campaignAdminApiKey: String, baseURL: String) -> String {
        let configString = "\(campaignId)|\(campaignAdminApiKey)|\(baseURL)"
        // Use hashValue for simple hash, or could use SHA256 for more robust hashing
        return String(configString.hashValue)
    }
    
    /// Save configuration hash when caching campaign data
    /// This allows us to detect when configuration changes and invalidate cache
    public func saveCacheConfiguration(campaignId: Int, campaignAdminApiKey: String, baseURL: String) {
        let hash = calculateConfigHash(campaignId: campaignId, campaignAdminApiKey: campaignAdminApiKey, baseURL: baseURL)
        userDefaults.set(hash, forKey: CacheKeys.cacheConfigHash)
        userDefaults.set(Self.currentCacheVersion, forKey: CacheKeys.cacheVersion)
        VioLogger.debug("Cache configuration hash saved", component: "CacheManager")
    }
    
    /// Verify if cached configuration matches current configuration
    /// Returns: (isValid: Bool, shouldClearCache: Bool)
    /// - isValid: true if cache is valid for current config
    /// - shouldClearCache: true if cache should be cleared (config changed or version mismatch)
    public func validateCacheConfiguration(
        currentCampaignId: Int,
        currentCampaignAdminApiKey: String,
        currentBaseURL: String
    ) -> (isValid: Bool, shouldClearCache: Bool) {
        // Check cache version for backward compatibility
        let cachedVersion = userDefaults.integer(forKey: CacheKeys.cacheVersion)
        
        // If no version or old version, cache is from old SDK version - invalidate
        if cachedVersion == 0 || cachedVersion < Self.currentCacheVersion {
            VioLogger.info("Cache version mismatch (\(cachedVersion) < \(Self.currentCacheVersion)) - invalidating cache", component: "CacheManager")
            return (false, true)
        }
        
        // Get cached hash
        guard let cachedHash = userDefaults.string(forKey: CacheKeys.cacheConfigHash) else {
            // No cached hash means cache is from old version - invalidate
            VioLogger.info("No cache configuration hash found - invalidating cache", component: "CacheManager")
            return (false, true)
        }
        
        // Calculate current hash
        let currentHash = calculateConfigHash(
            campaignId: currentCampaignId,
            campaignAdminApiKey: currentCampaignAdminApiKey,
            baseURL: currentBaseURL
        )
        
        // Compare hashes
        let isValid = cachedHash == currentHash
        
        if !isValid {
            VioLogger.info("Cache configuration hash mismatch - campaignId or API keys changed", component: "CacheManager")
        }
        
        return (isValid, !isValid)
    }
    
    /// Clear all cached data
    public func clearCache() {
        userDefaults.removeObject(forKey: CacheKeys.campaign)
        userDefaults.removeObject(forKey: CacheKeys.components)
        userDefaults.removeObject(forKey: CacheKeys.campaignState)
        userDefaults.removeObject(forKey: CacheKeys.isCampaignActive)
        userDefaults.removeObject(forKey: CacheKeys.lastUpdated)
        userDefaults.removeObject(forKey: CacheKeys.cacheConfigHash)
        userDefaults.removeObject(forKey: CacheKeys.cacheVersion)
        
        // Post notification so demo can clear image cache
        NotificationCenter.default.post(name: NSNotification.Name("VioCacheCleared"), object: nil)
        
        VioLogger.info("Cache cleared", component: "CacheManager")
    }
    
    /// Clear cache for a specific campaign (useful when switching campaigns)
    public func clearCacheForCampaign(campaignId: Int) {
        // Check if cached campaign matches
        if let cachedCampaign = loadCampaign(), cachedCampaign.id == campaignId {
            clearCache()
            VioLogger.debug("Cleared cache for campaign \(campaignId)", component: "CacheManager")
        }
    }
    
    /// Get cache age in seconds
    public func getCacheAge() -> TimeInterval? {
        guard let lastUpdated = userDefaults.object(forKey: CacheKeys.lastUpdated) as? Date else {
            return nil
        }
        return Date().timeIntervalSince(lastUpdated)
    }
    
    /// Check if cache exists (regardless of expiration)
    public func hasCache() -> Bool {
        return userDefaults.object(forKey: CacheKeys.lastUpdated) != nil
    }
}

