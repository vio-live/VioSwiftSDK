import Foundation

// MARK: - Campaign Models

/// Broadcast context for associating campaigns and components to specific broadcasts
/// A broadcast can be a live sports match, TV show, stream, or any live event
public struct BroadcastContext: Codable, Equatable {
    public let broadcastId: String  // Required: Unique identifier for the broadcast (e.g., "barcelona-psg-2025-01-23")
    public let broadcastName: String?  // Optional: Human-readable broadcast name (e.g., "Barcelona vs PSG")
    public let startTime: String?  // Optional: ISO 8601 timestamp for broadcast start time
    public let channelId: Int?  // Optional: Channel/stream ID associated with the broadcast
    public let metadata: [String: String]?  // Optional: Additional metadata
    
    public init(
        broadcastId: String,
        broadcastName: String? = nil,
        startTime: String? = nil,
        channelId: Int? = nil,
        metadata: [String: String]? = nil
    ) {
        self.broadcastId = broadcastId
        self.broadcastName = broadcastName
        self.startTime = startTime
        self.channelId = channelId
        self.metadata = metadata
    }
    
    // Backward compatibility: support decoding from matchId/matchName fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try broadcastId first, fallback to matchId
        if let broadcastId = try? container.decode(String.self, forKey: .broadcastId) {
            self.broadcastId = broadcastId
        } else {
            self.broadcastId = try container.decode(String.self, forKey: .matchId)
        }
        
        // Try broadcastName first, fallback to matchName
        if let broadcastName = try? container.decodeIfPresent(String.self, forKey: .broadcastName) {
            self.broadcastName = broadcastName
        } else {
            self.broadcastName = try container.decodeIfPresent(String.self, forKey: .matchName)
        }
        
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        channelId = try container.decodeIfPresent(Int.self, forKey: .channelId)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(broadcastId, forKey: .broadcastId)
        try container.encodeIfPresent(broadcastName, forKey: .broadcastName)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(channelId, forKey: .channelId)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
    
    private enum CodingKeys: String, CodingKey {
        case broadcastId
        case broadcastName
        case matchId  // For backward compatibility
        case matchName  // For backward compatibility
        case startTime
        case channelId
        case metadata
    }
    
    // Backward compatibility properties
    @available(*, deprecated, renamed: "broadcastId")
    public var matchId: String { broadcastId }
    
    @available(*, deprecated, renamed: "broadcastName")
    public var matchName: String? { broadcastName }
    
    // Convenience initializer from MatchContext (for migration)
    @available(*, deprecated, message: "Use BroadcastContext directly")
    public init(matchId: String, matchName: String? = nil, startTime: String? = nil, channelId: Int? = nil, metadata: [String: String]? = nil) {
        self.broadcastId = matchId
        self.broadcastName = matchName
        self.startTime = startTime
        self.channelId = channelId
        self.metadata = metadata
    }
}

// MARK: - Broadcast Validation (contentId flow)

/// Result of validating a contentId against the backend.
/// Returned by GET /v1/sdk/broadcast?contentId=&country=
/// Polls and contests are loaded separately via EngagementManager.loadEngagement when hasEngagement is true.
public struct BroadcastValidationResult: Codable, Equatable {
    public let hasEngagement: Bool
    public let broadcastId: String?
    public let broadcastName: String?
    public let status: String?
    public let campaignId: Int?
    public let websocketChannel: String?

    public init(
        hasEngagement: Bool,
        broadcastId: String? = nil,
        broadcastName: String? = nil,
        status: String? = nil,
        campaignId: Int? = nil,
        websocketChannel: String? = nil
    ) {
        self.hasEngagement = hasEngagement
        self.broadcastId = broadcastId
        self.broadcastName = broadcastName
        self.status = status
        self.campaignId = campaignId
        self.websocketChannel = websocketChannel
    }
}

/// Deprecated: Use BroadcastContext instead
@available(*, deprecated, renamed: "BroadcastContext")
public typealias MatchContext = BroadcastContext

/// Campaign lifecycle state
public enum CampaignState: String, Codable {
    case upcoming  // Before startDate
    case active    // Between startDate and endDate
    case ended     // After endDate
}

/// Campaign model
public struct Campaign: Codable, Identifiable, Equatable {
    public let id: Int
    public let startDate: String?  // ISO 8601 timestamp
    public let endDate: String?    // ISO 8601 timestamp
    public let isPaused: Bool?     // Campaign paused state (independent of dates)
    public let campaignLogo: String?  // Sponsor logo URL from campaign
    public let broadcastContext: BroadcastContext?  // Optional: Broadcast context for context-aware campaigns
    
    public init(
        id: Int,
        startDate: String? = nil,
        endDate: String? = nil,
        isPaused: Bool? = nil,
        campaignLogo: String? = nil,
        broadcastContext: BroadcastContext? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.isPaused = isPaused
        self.campaignLogo = campaignLogo
        self.broadcastContext = broadcastContext
    }
    
    // Custom decoder to handle isPaused as both String and Bool, and broadcastContext/matchContext
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        campaignLogo = try container.decodeIfPresent(String.self, forKey: .campaignLogo)
        
        // Try broadcastContext first, fallback to matchContext for backward compatibility
        if let broadcastContext = try? container.decodeIfPresent(BroadcastContext.self, forKey: .broadcastContext) {
            self.broadcastContext = broadcastContext
        } else {
            // Try decoding as MatchContext (which is now BroadcastContext)
            self.broadcastContext = try container.decodeIfPresent(BroadcastContext.self, forKey: .matchContext)
        }
        
        // Handle isPaused as either String or Bool
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .isPaused) {
            isPaused = boolValue
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .isPaused) {
            // Convert string "true"/"false" to Bool
            isPaused = stringValue.lowercased() == "true"
        } else {
            isPaused = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(isPaused, forKey: .isPaused)
        try container.encodeIfPresent(campaignLogo, forKey: .campaignLogo)
        try container.encodeIfPresent(broadcastContext, forKey: .broadcastContext)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case startDate
        case endDate
        case isPaused
        case campaignLogo
        case broadcastContext
        case matchContext  // For backward compatibility decoding
    }
    
    // Backward compatibility property
    @available(*, deprecated, renamed: "broadcastContext")
    public var matchContext: BroadcastContext? { broadcastContext }
    
    /// Determine current state based on dates
    /// Handles special cases:
    /// - No dates: Always active (legacy behavior)
    /// - Only startDate: Active after start, never ends
    /// - Only endDate: Active until endDate
    /// - Both dates: Respects both start and end
    public var currentState: CampaignState {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Parse dates if available
        let start = startDate.flatMap { formatter.date(from: $0) }
        let end = endDate.flatMap { formatter.date(from: $0) }
        
        // Special case: No dates set - campaign is always active (legacy behavior)
        if start == nil && end == nil {
            return .active
        }
        
        // Special case: Only endDate - campaign is active until endDate
        if start == nil, let end = end {
            return now > end ? .ended : .active
        }
        
        // Special case: Only startDate - campaign becomes active after start, never ends
        if end == nil, let start = start {
            return now < start ? .upcoming : .active
        }
        
        // Normal case: Both dates present
        if let start = start, let end = end {
            if now < start {
                return .upcoming
            } else if now > end {
                return .ended
            } else {
                return .active
            }
        }
        
        // Fallback: Default to active
        return .active
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: Campaign, rhs: Campaign) -> Bool {
        return lhs.id == rhs.id &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.isPaused == rhs.isPaused &&
               lhs.campaignLogo == rhs.campaignLogo &&
               lhs.broadcastContext == rhs.broadcastContext
    }
}

/// SDK Config Response from GET /v1/sdk/config
internal struct SDKConfigResponse: Codable {
    let campaignId: Int?
    let campaignName: String?
    let campaignLogo: String?
    let channelId: Int?
    let channelName: String?
    let environment: String?
    let campaigns: CampaignsConfig?
    let marketFallback: MarketFallbackConfig?
    let features: FeaturesConfig?
    let broadcastContext: BroadcastContext?  // Optional: Broadcast context for context-aware campaigns
    let sdkVersion: String?
    @available(*, deprecated, renamed: "broadcastContext")
    var matchContext: BroadcastContext? { broadcastContext }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        campaignId = try container.decodeIfPresent(Int.self, forKey: .campaignId)
        campaignName = try container.decodeIfPresent(String.self, forKey: .campaignName)
        campaignLogo = try container.decodeIfPresent(String.self, forKey: .campaignLogo)
        channelId = try container.decodeIfPresent(Int.self, forKey: .channelId)
        channelName = try container.decodeIfPresent(String.self, forKey: .channelName)
        environment = try container.decodeIfPresent(String.self, forKey: .environment)
        campaigns = try container.decodeIfPresent(CampaignsConfig.self, forKey: .campaigns)
        marketFallback = try container.decodeIfPresent(MarketFallbackConfig.self, forKey: .marketFallback)
        features = try container.decodeIfPresent(FeaturesConfig.self, forKey: .features)
        sdkVersion = try container.decodeIfPresent(String.self, forKey: .sdkVersion)
        
        // Try broadcastContext first, fallback to matchContext for backward compatibility
        if let broadcastContext = try? container.decodeIfPresent(BroadcastContext.self, forKey: .broadcastContext) {
            self.broadcastContext = broadcastContext
        } else {
            self.broadcastContext = try container.decodeIfPresent(BroadcastContext.self, forKey: .matchContext)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(campaignId, forKey: .campaignId)
        try container.encodeIfPresent(campaignName, forKey: .campaignName)
        try container.encodeIfPresent(campaignLogo, forKey: .campaignLogo)
        try container.encodeIfPresent(channelId, forKey: .channelId)
        try container.encodeIfPresent(channelName, forKey: .channelName)
        try container.encodeIfPresent(environment, forKey: .environment)
        try container.encodeIfPresent(campaigns, forKey: .campaigns)
        try container.encodeIfPresent(marketFallback, forKey: .marketFallback)
        try container.encodeIfPresent(features, forKey: .features)
        try container.encodeIfPresent(sdkVersion, forKey: .sdkVersion)
        try container.encodeIfPresent(broadcastContext, forKey: .broadcastContext)
    }
    
    private enum CodingKeys: String, CodingKey {
        case campaignId
        case campaignName
        case campaignLogo
        case channelId
        case channelName
        case environment
        case campaigns
        case marketFallback
        case features
        case sdkVersion
        case broadcastContext
        case matchContext  // For backward compatibility decoding
    }
    
    struct CampaignsConfig: Codable {
        let webSocketBaseURL: String?
        let restAPIBaseURL: String?
    }
    
    struct MarketFallbackConfig: Codable {
        let countryCode: String?
        let currencyCode: String?
        let currencySymbol: String?
        let phoneCode: String?
    }
    
    struct FeaturesConfig: Codable {
        let enableWebSocket: Bool?
        let enableGuestCheckout: Bool?
    }
}

/// Minimal decode for GET /v1/sdk/config zero-config bootstrap (`commerce` + `endpoints`).
internal struct SdkBootstrapResponse: Codable {
    struct CommerceBlock: Codable {
        let apiKey: String
        let endpoint: String?
    }
    struct EndpointsBlock: Codable {
        let commerceGraphQL: String?
    }
    let commerce: CommerceBlock?
    let endpoints: EndpointsBlock?
}

/// Campaigns Discovery Response from GET /v1/sdk/campaigns
/// Used for auto-discovery of campaigns using only the Vio SDK API key
internal struct CampaignsDiscoveryResponse: Codable {
    let campaigns: [CampaignDiscoveryItem]
    
    struct CampaignDiscoveryItem: Codable {
        let campaignId: Int
        let campaignName: String?
        let campaignLogo: String?
        let broadcastContext: BroadcastContext?  // Broadcast context for this campaign
        @available(*, deprecated, renamed: "broadcastContext")
        var matchContext: BroadcastContext? { broadcastContext }
        let isActive: Bool
        let startDate: String?
        let endDate: String?
        let isPaused: Bool?
        let components: [ComponentDiscoveryItem]?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            campaignId = try container.decode(Int.self, forKey: .campaignId)
            campaignName = try container.decodeIfPresent(String.self, forKey: .campaignName)
            campaignLogo = try container.decodeIfPresent(String.self, forKey: .campaignLogo)
            isActive = try container.decode(Bool.self, forKey: .isActive)
            startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
            endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
            isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused)
            components = try container.decodeIfPresent([ComponentDiscoveryItem].self, forKey: .components)
            
            // Try broadcastContext first, fallback to matchContext for backward compatibility
            if let broadcastContext = try? container.decodeIfPresent(BroadcastContext.self, forKey: .broadcastContext) {
                self.broadcastContext = broadcastContext
            } else {
                self.broadcastContext = try container.decodeIfPresent(BroadcastContext.self, forKey: .matchContext)
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(campaignId, forKey: .campaignId)
            try container.encodeIfPresent(campaignName, forKey: .campaignName)
            try container.encodeIfPresent(campaignLogo, forKey: .campaignLogo)
            try container.encode(isActive, forKey: .isActive)
            try container.encodeIfPresent(startDate, forKey: .startDate)
            try container.encodeIfPresent(endDate, forKey: .endDate)
            try container.encodeIfPresent(isPaused, forKey: .isPaused)
            try container.encodeIfPresent(components, forKey: .components)
            try container.encodeIfPresent(broadcastContext, forKey: .broadcastContext)
        }
        
        private enum CodingKeys: String, CodingKey {
            case campaignId
            case campaignName
            case campaignLogo
            case broadcastContext
            case matchContext  // For backward compatibility decoding
            case isActive
            case startDate
            case endDate
            case isPaused
            case components
        }
        
        struct ComponentDiscoveryItem: Codable {
            let id: String
            let type: String
            let name: String
            let locationId: String?
            let broadcastContext: BroadcastContext?
            @available(*, deprecated, renamed: "broadcastContext")
            var matchContext: BroadcastContext? { broadcastContext }
            let config: [String: AnyCodable]
            let status: String?
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                type = try container.decode(String.self, forKey: .type)
                name = try container.decode(String.self, forKey: .name)
                locationId = try container.decodeIfPresent(String.self, forKey: .locationId)
                config = try container.decode([String: AnyCodable].self, forKey: .config)
                status = try container.decodeIfPresent(String.self, forKey: .status)
                
                // Try broadcastContext first, fallback to matchContext for backward compatibility
                if let broadcastContext = try? container.decodeIfPresent(BroadcastContext.self, forKey: .broadcastContext) {
                    self.broadcastContext = broadcastContext
                } else {
                    self.broadcastContext = try container.decodeIfPresent(BroadcastContext.self, forKey: .matchContext)
                }
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(id, forKey: .id)
                try container.encode(type, forKey: .type)
                try container.encode(name, forKey: .name)
                try container.encode(config, forKey: .config)
                try container.encodeIfPresent(status, forKey: .status)
                try container.encodeIfPresent(broadcastContext, forKey: .broadcastContext)
            }
            
            private enum CodingKeys: String, CodingKey {
                case id
                case type
                case name
                case locationId
                case broadcastContext
                case matchContext  // For backward compatibility decoding
                case config
                case status
            }
        }
    }
}

/// Offers Response from GET /v1/offers
internal struct OffersResponse: Codable {
    let campaignId: Int
    let campaignName: String?
    let campaignLogo: String?
    let channelId: Int?
    let channelName: String?
    let offers: [OfferResponse]
}

/// Individual offer/component from offers response
internal struct OfferResponse: Codable {
    let id: String
    let type: String
    let name: String
    let config: [String: AnyCodable]
    let placement: String?
}

/// Backend response wrapper for GET /api/campaigns/:campaignId/components (Legacy)
/// Backend sends: { "components": [...] }
internal struct ComponentsResponseWrapper: Codable {
    let components: [ComponentResponse]
}

/// Backend response model for campaign components
/// This is the actual structure returned by the API
internal struct ComponentResponse: Codable {
    let id: Int
    let campaignId: Int
    let componentId: String
    let status: String
    internal let customConfig: [String: AnyCodable]?
    internal let component: ComponentData?
    let broadcastContext: BroadcastContext?  // Optional: Broadcast context for context-aware components
    @available(*, deprecated, renamed: "broadcastContext")
    var matchContext: BroadcastContext? { broadcastContext }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        campaignId = try container.decode(Int.self, forKey: .campaignId)
        componentId = try container.decode(String.self, forKey: .componentId)
        status = try container.decode(String.self, forKey: .status)
        customConfig = try container.decodeIfPresent([String: AnyCodable].self, forKey: .customConfig)
        component = try container.decodeIfPresent(ComponentData.self, forKey: .component)
        
        // Try broadcastContext first, fallback to matchContext for backward compatibility
        if let broadcastContext = try? container.decodeIfPresent(BroadcastContext.self, forKey: .broadcastContext) {
            self.broadcastContext = broadcastContext
        } else {
            self.broadcastContext = try container.decodeIfPresent(BroadcastContext.self, forKey: .matchContext)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(campaignId, forKey: .campaignId)
        try container.encode(componentId, forKey: .componentId)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(customConfig, forKey: .customConfig)
        try container.encodeIfPresent(component, forKey: .component)
        try container.encodeIfPresent(broadcastContext, forKey: .broadcastContext)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case campaignId
        case componentId
        case status
        case customConfig
        case component
        case broadcastContext
        case matchContext  // For backward compatibility decoding
    }
    
    struct ComponentData: Codable {
        let id: String
        let type: String
        let name: String
        let config: [String: AnyCodable]
    }
}

/// Helper type to decode arbitrary JSON values
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode AnyCodable"))
        }
    }
}

/// Component model for dynamic campaign components
/// Uses ComponentConfig from OfferBannerModels for compatibility
public struct Component: Codable, Identifiable {
    public let id: String
    public let type: String  // "banner", "offer_banner", "countdown", etc.
    public let name: String
    public let config: ComponentConfig
    public let status: String?  // "active" or "inactive"
    public let locationId: String?  // Slot identifier (e.g., "sport-detail-carousel", "sport-detail-banner")
    public let broadcastContext: BroadcastContext?  // Optional: Broadcast context for context-aware components
    
    public init(
        id: String,
        type: String,
        name: String,
        config: ComponentConfig,
        status: String? = nil,
        locationId: String? = nil,
        broadcastContext: BroadcastContext? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.config = config
        self.status = status
        self.locationId = locationId
        self.broadcastContext = broadcastContext
    }
    
    // Backward compatibility property
    @available(*, deprecated, renamed: "broadcastContext")
    public var matchContext: BroadcastContext? { broadcastContext }
    
    public var isActive: Bool {
        return status == "active"
    }
    
    /// Decode from backend response format
    init(from response: ComponentResponse) throws {
        // Use componentId as the id (it's the template ID)
        self.id = response.componentId
        
        // Get type and name from nested component, or use defaults
        guard let componentData = response.component else {
            throw DecodingError.keyNotFound(
                CodingKeys.component,
                DecodingError.Context(codingPath: [], debugDescription: "Component data is missing")
            )
        }
        
        self.type = componentData.type
        self.name = componentData.name
        self.status = response.status
        
        // Use customConfig if available, otherwise use component.config
        let configToUse: [String: AnyCodable]
        if let customConfig = response.customConfig, !customConfig.isEmpty {
            configToUse = customConfig
        } else {
            configToUse = componentData.config
        }
        
        // Convert [String: AnyCodable] to JSON Data and decode as ComponentConfig
        let jsonData = try JSONSerialization.data(withJSONObject: configToUse.mapValues { $0.value })
        self.config = try JSONDecoder().decode(ComponentConfig.self, from: jsonData)
        
        // Decode broadcastContext from response if available
        self.broadcastContext = response.broadcastContext
        self.locationId = nil
    }
    
    /// Decode from JSON (for WebSocket events)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        config = try container.decode(ComponentConfig.self, forKey: .config)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        locationId = try container.decodeIfPresent(String.self, forKey: .locationId)
        // Try broadcastContext first, fallback to matchContext for backward compatibility
        if let broadcastContext = try? container.decodeIfPresent(BroadcastContext.self, forKey: .broadcastContext) {
            self.broadcastContext = broadcastContext
        } else {
            self.broadcastContext = try container.decodeIfPresent(BroadcastContext.self, forKey: .matchContext)
        }
    }
    
    /// Encode to JSON (for WebSocket events)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(config, forKey: .config)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(broadcastContext, forKey: .broadcastContext)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case locationId
        case config
        case status
        case broadcastContext
        case matchContext  // For backward compatibility decoding
        case component
    }
}

// MARK: - WebSocket Event Models

/// Base WebSocket event structure
public struct CampaignWebSocketEvent: Codable {
    public let type: String
    public let campaignId: Int
    
    public init(type: String, campaignId: Int) {
        self.type = type
        self.campaignId = campaignId
    }
}

/// Campaign started event
public struct CampaignStartedEvent: Codable {
    public let type: String
    public let campaignId: Int
    public let startDate: String?
    public let endDate: String?
    public let broadcastId: String?  // Optional: Broadcast context for context-aware campaigns
    @available(*, deprecated, renamed: "broadcastId")
    public var matchId: String? { broadcastId }
    
    public init(type: String = "campaign_started", campaignId: Int, startDate: String? = nil, endDate: String? = nil, broadcastId: String? = nil) {
        self.type = type
        self.campaignId = campaignId
        self.startDate = startDate
        self.endDate = endDate
        self.broadcastId = broadcastId
    }
    
    // Backward compatibility initializer
    @available(*, deprecated, message: "Use init with broadcastId instead")
    public init(type: String = "campaign_started", campaignId: Int, startDate: String? = nil, endDate: String? = nil, matchId: String?) {
        self.init(type: type, campaignId: campaignId, startDate: startDate, endDate: endDate, broadcastId: matchId)
    }
}

/// Campaign ended event
public struct CampaignEndedEvent: Codable {
    public let type: String
    public let campaignId: Int
    public let endDate: String?
    
    public init(type: String = "campaign_ended", campaignId: Int, endDate: String? = nil) {
        self.type = type
        self.campaignId = campaignId
        self.endDate = endDate
    }
}

/// Campaign paused event
public struct CampaignPausedEvent: Codable {
    public let type: String
    public let campaignId: Int
    
    public init(type: String = "campaign_paused", campaignId: Int) {
        self.type = type
        self.campaignId = campaignId
    }
}

/// Campaign resumed event
public struct CampaignResumedEvent: Codable {
    public let type: String
    public let campaignId: Int
    
    public init(type: String = "campaign_resumed", campaignId: Int) {
        self.type = type
        self.campaignId = campaignId
    }
}

/// Component status changed event
/// Supports two formats:
/// 1. New format: { "type": "component_status_changed", "data": { "componentId": 8, "campaignComponentId": 15, "componentType": "product_banner", "status": "active", "config": {...} } }
/// 2. Legacy format: { "type": "component_status_changed", "campaignId": 14, "componentId": "product-banner-template", "status": "inactive", "component": {...} }
public struct ComponentStatusChangedEvent: Codable {
    let broadcastId: String?  // Optional: Broadcast context for context-aware components
    @available(*, deprecated, renamed: "broadcastId")
    var matchId: String? { broadcastId }
    public let type: String
    public let data: ComponentStatusData?
    
    // Legacy format fields
    public let campaignId: Int?
    public let componentId: String?  // Legacy: string ID
    public let status: String?  // Legacy: status at root level
    public let component: LegacyComponentData?  // Legacy: component object
    
    public struct ComponentStatusData: Codable {
        public let componentId: Int  // Template component ID
        public let campaignComponentId: Int  // Campaign-specific component ID
        public let componentType: String  // "product_banner", "product_carousel", etc.
        public let status: String  // "active" or "inactive"
        public let config: [String: AnyCodable]  // Already merged config (customConfig + defaults)
    }
    
    public struct LegacyComponentData: Codable {
        public let id: String
        public let type: String
        public let name: String
        public let config: [String: AnyCodable]
    }
    
    public init(type: String = "component_status_changed", data: ComponentStatusData? = nil, campaignId: Int? = nil, componentId: String? = nil, status: String? = nil, component: LegacyComponentData? = nil, broadcastId: String? = nil) {
        self.type = type
        self.data = data
        self.campaignId = campaignId
        self.componentId = componentId
        self.status = status
        self.component = component
        self.broadcastId = broadcastId
    }
    
    // Backward compatibility initializer
    @available(*, deprecated, message: "Use init with broadcastId instead")
    public init(type: String = "component_status_changed", data: ComponentStatusData? = nil, campaignId: Int? = nil, componentId: String? = nil, status: String? = nil, component: LegacyComponentData? = nil, matchId: String?) {
        self.init(type: type, data: data, campaignId: campaignId, componentId: componentId, status: status, component: component, broadcastId: matchId)
    }
    
    /// Helper to convert to Component model
    public func toComponent() throws -> Component {
        // Try new format first
        if let data = data {
            let jsonData = try JSONSerialization.data(withJSONObject: data.config.mapValues { $0.value })
            let componentConfig = try JSONDecoder().decode(ComponentConfig.self, from: jsonData)
            
            return Component(
                id: String(data.campaignComponentId),
                type: data.componentType,
                name: "",  // Name not provided in WebSocket event
                config: componentConfig,
                status: data.status
            )
        }
        
        // Fallback to legacy format
        guard let component = component,
              let status = status else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Missing required fields for component_status_changed event"))
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: component.config.mapValues { $0.value })
        let componentConfig = try JSONDecoder().decode(ComponentConfig.self, from: jsonData)
        
        return Component(
            id: component.id,
            type: component.type,
            name: component.name,
            config: componentConfig,
            status: status
        )
    }
}

/// Component config updated event
/// Backend sends two possible formats:
/// 1. { "type": "component_config_updated", "data": { "componentId": 8, "campaignComponentId": 15, "componentType": "product_banner", "config": {...} } }
/// 2. { "type": "component_config_updated", "campaignId": 14, "componentId": "product-banner-template", "component": { "id": "...", "type": "...", "name": "...", "config": {...} } }
public struct ComponentConfigUpdatedEvent: Codable {
    public let type: String
    public let campaignId: Int?
    public let componentId: String?  // String format (new format)
    public let data: ComponentConfigData?  // Old format
    public let component: Component?  // New format (direct Component object)
    
    public struct ComponentConfigData: Codable {
        public let componentId: Int  // Template component ID (old format)
        public let campaignComponentId: Int  // Campaign-specific component ID (old format)
        public let componentType: String  // "product_banner", "product_carousel", etc. (old format)
        public let config: [String: AnyCodable]  // New merged config (old format)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        type = try container.decode(String.self, forKey: .type)
        campaignId = try container.decodeIfPresent(Int.self, forKey: .campaignId)
        componentId = try container.decodeIfPresent(String.self, forKey: .componentId)
        
        // Try new format first (with direct component)
        if container.contains(.component) {
            component = try container.decode(Component.self, forKey: .component)
            data = nil
        }
        // Fallback to old format (with data wrapper)
        else if container.contains(.data) {
            data = try container.decode(ComponentConfigData.self, forKey: .data)
            component = nil
        } else {
            data = nil
            component = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(campaignId, forKey: .campaignId)
        try container.encodeIfPresent(componentId, forKey: .componentId)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(component, forKey: .component)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, campaignId, componentId, data, component
    }
    
    /// Helper to convert to Component model (handles both formats)
    public func toComponent() throws -> Component {
        // New format: direct Component object
        if let component = component {
            return component
        }
        
        // Old format: convert from ComponentConfigData
        guard let data = data else {
            throw DecodingError.keyNotFound(
                CodingKeys.component,
                DecodingError.Context(codingPath: [], debugDescription: "Neither component nor data found in ComponentConfigUpdatedEvent")
            )
        }
        
        // Convert config dictionary to ComponentConfig
        let jsonData = try JSONSerialization.data(withJSONObject: data.config.mapValues { $0.value })
        let componentConfig = try JSONDecoder().decode(ComponentConfig.self, from: jsonData)
        
        return Component(
            id: String(data.campaignComponentId),
            type: data.componentType,
            name: "",  // Name not provided in old format
            config: componentConfig,
            status: "active"  // Config updates are always for active components
        )
    }
}



// MARK: - Cart Intent WS Event

/// Received when the backend routes a cart_intent to this user's WebSocket connection.
/// Triggered by POST /api/campaigns/:id/cart-intent → wsUserMap lookup → send to device.
public struct CartIntentEvent: Codable, Equatable {
    public let type: String
    /// Name of the product the user is being prompted to add to cart.
    public let productName: String?
    /// Optional product ID for deep-linking into a product detail view.
    public let productId: String?
    /// Optional campaign ID for context.
    public let campaignId: Int?
    
    public init(type: String, productName: String?, productId: String?, campaignId: Int?) {
        self.type = type
        self.productName = productName
        self.productId = productId
        self.campaignId = campaignId
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case productName = "productName"
        case productId   = "productId"
        case campaignId  = "campaignId"
    }
}

// MARK: - Push / notification envelope (canonical)

/// Stable string values for `vio_event_type` in notification `userInfo` (APNs, local, FCM data map).
public enum VioPushEventType: String, Sendable, CaseIterable {
    case cartIntent = "cart_intent"
}

/// Top-level keys present on every Vio-originated or partner push that follows the integration contract.
public enum VioNotificationUserInfoKeys {
    /// Integer schema version for the envelope (currently `1`).
    public static let notificationVersion = "vio_notification_version"
    /// Discriminator; use `VioPushEventType.rawValue`.
    public static let eventType = "vio_event_type"
}

/// Keys in `UNNotificationContent.userInfo` for type-specific `cart_intent` payload (alongside the envelope).
public enum CartIntentNotificationKeys {
    public static let kind = "vio_cartIntent_kind"
    public static let productId = "vio_cartIntent_productId"
    public static let productName = "vio_cartIntent_productName"
    public static let campaignId = "vio_cartIntent_campaignId"
    public static let kindValueCartIntent = "cart_intent"
}
