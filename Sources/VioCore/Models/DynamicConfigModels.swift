import Foundation

// MARK: - Campaign Configuration

/// Complete campaign configuration from backend
public struct CampaignConfig: Codable {
    public let campaignId: Int
    public let version: String?
    public let brand: DynamicBrandConfig?
    public let engagement: DynamicEngagementConfig?
    public let ui: DynamicUIConfig?
    public let features: DynamicFeatureFlags?
    public let cache: CacheConfig?
    
    public init(
        campaignId: Int,
        version: String? = nil,
        brand: DynamicBrandConfig? = nil,
        engagement: DynamicEngagementConfig? = nil,
        ui: DynamicUIConfig? = nil,
        features: DynamicFeatureFlags? = nil,
        cache: CacheConfig? = nil
    ) {
        self.campaignId = campaignId
        self.version = version
        self.brand = brand
        self.engagement = engagement
        self.ui = ui
        self.features = features
        self.cache = cache
    }
}

// MARK: - Brand Configuration

/// Dynamic brand configuration from backend
public struct DynamicBrandConfig: Codable {
    public let name: String?
    public let iconAsset: String?
    public let iconUrl: String?
    public let logoUrl: String?
    public let sponsorBadgeText: [String: String]?
    
    public init(
        name: String? = nil,
        iconAsset: String? = nil,
        iconUrl: String? = nil,
        logoUrl: String? = nil,
        sponsorBadgeText: [String: String]? = nil
    ) {
        self.name = name
        self.iconAsset = iconAsset
        self.iconUrl = iconUrl
        self.logoUrl = logoUrl
        self.sponsorBadgeText = sponsorBadgeText
    }
}

// MARK: - Engagement Configuration

/// Dynamic engagement configuration from backend
public struct DynamicEngagementConfig: Codable {
    public let demoMode: Bool?
    public let defaultPollDuration: Int?
    public let defaultContestDuration: Int?
    public let maxVotesPerPoll: Int?
    public let maxContestsPerMatch: Int?
    public let enableRealTimeUpdates: Bool?
    public let updateInterval: Int?
    
    public init(
        demoMode: Bool? = nil,
        defaultPollDuration: Int? = nil,
        defaultContestDuration: Int? = nil,
        maxVotesPerPoll: Int? = nil,
        maxContestsPerMatch: Int? = nil,
        enableRealTimeUpdates: Bool? = nil,
        updateInterval: Int? = nil
    ) {
        self.demoMode = demoMode
        self.defaultPollDuration = defaultPollDuration
        self.defaultContestDuration = defaultContestDuration
        self.maxVotesPerPoll = maxVotesPerPoll
        self.maxContestsPerMatch = maxContestsPerMatch
        self.enableRealTimeUpdates = enableRealTimeUpdates
        self.updateInterval = updateInterval
    }
}

// MARK: - UI Configuration

/// Dynamic UI configuration from backend
public struct DynamicUIConfig: Codable {
    public let theme: DynamicThemeConfig?
    public let components: DynamicComponentsConfig?
    
    public init(
        theme: DynamicThemeConfig? = nil,
        components: DynamicComponentsConfig? = nil
    ) {
        self.theme = theme
        self.components = components
    }
}

public struct DynamicThemeConfig: Codable {
    public let primaryColor: String?
    public let secondaryColor: String?
    
    public init(
        primaryColor: String? = nil,
        secondaryColor: String? = nil
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }
}

public struct DynamicComponentsConfig: Codable {
    public let cart: DynamicCartConfig?
    public let discountBadge: DynamicDiscountBadgeConfig?
    
    public init(
        cart: DynamicCartConfig? = nil,
        discountBadge: DynamicDiscountBadgeConfig? = nil
    ) {
        self.cart = cart
        self.discountBadge = discountBadge
    }
}

public struct DynamicCartConfig: Codable {
    public let position: String?
    public let displayMode: String?
    public let size: String?
    
    public init(
        position: String? = nil,
        displayMode: String? = nil,
        size: String? = nil
    ) {
        self.position = position
        self.displayMode = displayMode
        self.size = size
    }
}

public struct DynamicDiscountBadgeConfig: Codable {
    public let enabled: Bool?
    public let text: String?
    public let position: String?
    
    public init(
        enabled: Bool? = nil,
        text: String? = nil,
        position: String? = nil
    ) {
        self.enabled = enabled
        self.text = text
        self.position = position
    }
}

// MARK: - Feature Flags

/// Dynamic feature flags from backend
public struct DynamicFeatureFlags: Codable {
    public let enableLiveStreaming: Bool?
    public let enableProductCatalog: Bool?
    public let enableEngagement: Bool?
    public let enablePolls: Bool?
    public let enableContests: Bool?
    
    public init(
        enableLiveStreaming: Bool? = nil,
        enableProductCatalog: Bool? = nil,
        enableEngagement: Bool? = nil,
        enablePolls: Bool? = nil,
        enableContests: Bool? = nil
    ) {
        self.enableLiveStreaming = enableLiveStreaming
        self.enableProductCatalog = enableProductCatalog
        self.enableEngagement = enableEngagement
        self.enablePolls = enablePolls
        self.enableContests = enableContests
    }
}

// MARK: - Localization Configuration

/// Dynamic localization configuration from backend
public struct DynamicLocalizationConfig: Codable {
    public let language: String
    public let campaignId: Int?
    public let translations: [String: String]
    public let dateFormat: String?
    public let timeFormat: String?
    public let cache: CacheConfig?
    
    public init(
        language: String,
        campaignId: Int? = nil,
        translations: [String: String],
        dateFormat: String? = nil,
        timeFormat: String? = nil,
        cache: CacheConfig? = nil
    ) {
        self.language = language
        self.campaignId = campaignId
        self.translations = translations
        self.dateFormat = dateFormat
        self.timeFormat = timeFormat
        self.cache = cache
    }
}

// MARK: - Cache Configuration

/// Cache configuration from backend
public struct CacheConfig: Codable {
    public let ttl: Int?
    public let version: String?
    
    public init(ttl: Int? = nil, version: String? = nil) {
        self.ttl = ttl
        self.version = version
    }
}

// MARK: - Cached Config Wrapper

/// Wrapper for cached configuration with metadata
struct CachedConfig<T: Codable> {
    let data: T
    let cachedAt: Date
    let ttl: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > ttl
    }
    
    init(data: T, ttl: TimeInterval = 300) {
        self.data = data
        self.cachedAt = Date()
        self.ttl = ttl
    }
}

// MARK: - Engagement Config Response

/// Response wrapper for engagement config endpoint
struct EngagementConfigResponse: Codable {
    let matchId: String
    let engagement: DynamicEngagementConfig
    let cache: CacheConfig?
}
