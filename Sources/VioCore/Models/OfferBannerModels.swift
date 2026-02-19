import Foundation
import VioCore

/// Configuration for Offer Banner component
public struct OfferBannerConfig: Codable, Equatable {
    public let logoUrl: String
    public let title: String
    public let subtitle: String?
    public let backgroundImageUrl: String?  // Optional: can use backgroundColor instead
    public let backgroundColor: String?      // NEW: Optional background color
    public let countdownEndDate: String // ISO 8601 timestamp
    public let discountBadgeText: String
    public let ctaText: String
    public let ctaLink: String?
    public let overlayOpacity: Double?
    public let buttonColor: String?
    public let deeplinkUrl: String?
    public let deeplinkAction: String?
    
    enum CodingKeys: String, CodingKey {
        case logoUrl, title, subtitle, backgroundImageUrl, backgroundColor
        case countdownEndDate, discountBadgeText, ctaText, ctaLink
        case overlayOpacity, buttonColor, deeplinkUrl, deeplinkAction
        case deeplink  // To support backend format
    }
    
    public init(
        logoUrl: String,
        title: String,
        subtitle: String? = nil,
        backgroundImageUrl: String? = nil,
        backgroundColor: String? = nil,
        countdownEndDate: String,
        discountBadgeText: String,
        ctaText: String,
        ctaLink: String? = nil,
        overlayOpacity: Double? = nil,
        buttonColor: String? = nil,
        deeplinkUrl: String? = nil,
        deeplinkAction: String? = nil
    ) {
        self.logoUrl = logoUrl
        self.title = title
        self.subtitle = subtitle
        self.backgroundImageUrl = backgroundImageUrl
        self.backgroundColor = backgroundColor
        self.countdownEndDate = countdownEndDate
        self.discountBadgeText = discountBadgeText
        self.ctaText = ctaText
        self.ctaLink = ctaLink
        self.overlayOpacity = overlayOpacity
        self.buttonColor = buttonColor
        self.deeplinkUrl = deeplinkUrl
        self.deeplinkAction = deeplinkAction
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        logoUrl = try container.decode(String.self, forKey: .logoUrl)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        backgroundImageUrl = try container.decodeIfPresent(String.self, forKey: .backgroundImageUrl)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        countdownEndDate = try container.decode(String.self, forKey: .countdownEndDate)
        discountBadgeText = try container.decode(String.self, forKey: .discountBadgeText)
        ctaText = try container.decode(String.self, forKey: .ctaText)
        ctaLink = try container.decodeIfPresent(String.self, forKey: .ctaLink)
        overlayOpacity = try container.decodeIfPresent(Double.self, forKey: .overlayOpacity)
        buttonColor = try container.decodeIfPresent(String.self, forKey: .buttonColor)
        
        // Support both deeplinkUrl and deeplink (backend format)
        deeplinkUrl = try container.decodeIfPresent(String.self, forKey: .deeplinkUrl) 
            ?? container.decodeIfPresent(String.self, forKey: .deeplink)
        deeplinkAction = try container.decodeIfPresent(String.self, forKey: .deeplinkAction)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(logoUrl, forKey: .logoUrl)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subtitle, forKey: .subtitle)
        try container.encodeIfPresent(backgroundImageUrl, forKey: .backgroundImageUrl)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encode(countdownEndDate, forKey: .countdownEndDate)
        try container.encode(discountBadgeText, forKey: .discountBadgeText)
        try container.encode(ctaText, forKey: .ctaText)
        try container.encodeIfPresent(ctaLink, forKey: .ctaLink)
        try container.encodeIfPresent(overlayOpacity, forKey: .overlayOpacity)
        try container.encodeIfPresent(buttonColor, forKey: .buttonColor)
        try container.encodeIfPresent(deeplinkUrl, forKey: .deeplinkUrl)
        try container.encodeIfPresent(deeplinkAction, forKey: .deeplinkAction)
    }
}

/// Component Response Models
public struct ActiveComponentResponse: Codable {
    public let componentId: String
    public let type: String
    public let name: String
    public let config: ComponentConfig
    public let status: String
    public let activatedAt: String?
}

/// Component Config (Dynamic based on type)
public enum ComponentConfig: Codable {
    case banner(BannerConfig)
    case offerBanner(OfferBannerConfig)
    case productSpotlight(ProductSpotlightConfig)
    case countdown(CountdownConfig)
    case carouselAuto(CarouselAutoConfig)
    case carouselManual(CarouselManualConfig)
    case offerBadge(OfferBadgeConfig)
    case productCarousel(ProductCarouselConfig)
    case productBanner(ProductBannerConfig)
    case productStore(ProductStoreConfig)
    
    enum CodingKeys: String, CodingKey {
        case imageUrl, title, subtitle, ctaText, ctaLink, deeplinkUrl, deeplinkAction // banner
        case logoUrl, backgroundImageUrl, backgroundColor, countdownEndDate, discountBadgeText, overlayOpacity, buttonColor // offer_banner
        case productId, highlightText // product_spotlight
        case endDate, style, deeplink // countdown (agregar title y deeplink)
        case channelId, displayCount // carousel_auto
        case productIds // carousel_manual, product_carousel, product_store
        case text, color // offer_badge
        case autoPlay, interval // product_carousel
        case mode, displayType, columns // product_store
        case message // banner, product_banner
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try Countdown FIRST (has endDate AND title - formato nuevo del backend)
        // Esto debe ir antes de OfferBanner porque countdown puede tener logoUrl pero usa endDate, no countdownEndDate
        if container.contains(.endDate) && container.contains(.title) {
            let config = try CountdownConfig(from: decoder)
            self = .countdown(config)
        }
        // Try to decode as OfferBanner (has most specific fields: logoUrl AND countdownEndDate)
        else if container.contains(.logoUrl) && container.contains(.countdownEndDate) {
            let config = try OfferBannerConfig(from: decoder)
            self = .offerBanner(config)
        }
        // Try ProductBanner (has productId AND backgroundImageUrl, different from ProductSpotlight)
        else if container.contains(.productId) && container.contains(.backgroundImageUrl) {
            let config = try ProductBannerConfig(from: decoder)
            self = .productBanner(config)
        }
        // Then try Banner (has imageUrl but not logoUrl)
        // Banner can have deeplinkUrl/deeplinkAction like OfferBanner
        else if container.contains(.imageUrl) {
            let config = try BannerConfig(from: decoder)
            self = .banner(config)
        }
        // Try ProductStore (has mode AND displayType)
        else if container.contains(.mode) && container.contains(.displayType) {
            let config = try ProductStoreConfig(from: decoder)
            self = .productStore(config)
        }
        // Try ProductCarousel (identified by having autoPlay OR interval keys)
        // productIds is optional - if missing, defaults to empty array (loads all products)
        // Must check BEFORE CarouselManual since both can have productIds
        else if container.contains(.autoPlay) || container.contains(.interval) {
            let config = try ProductCarouselConfig(from: decoder)
            self = .productCarousel(config)
        }
        // Try CarouselManual (has productIds but no autoPlay/interval)
        else if container.contains(.productIds) {
            let config = try CarouselManualConfig(from: decoder)
            self = .carouselManual(config)
        }
        // Then try ProductSpotlight (has productId but no backgroundImageUrl)
        else if container.contains(.productId) {
            let config = try ProductSpotlightConfig(from: decoder)
            self = .productSpotlight(config)
        }
        // Try CarouselAuto (has channelId)
        else if container.contains(.channelId) {
            let config = try CarouselAutoConfig(from: decoder)
            self = .carouselAuto(config)
        }
        // Try OfferBadge (has text)
        else if container.contains(.text) {
            let config = try OfferBadgeConfig(from: decoder)
            self = .offerBadge(config)
        }
        // Unknown type
        else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown component config type"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .offerBanner(let config):
            try config.encode(to: encoder)
        case .banner(let config):
            try config.encode(to: encoder)
        case .productSpotlight(let config):
            try config.encode(to: encoder)
        case .countdown(let config):
            try config.encode(to: encoder)
        case .carouselAuto(let config):
            try config.encode(to: encoder)
        case .carouselManual(let config):
            try config.encode(to: encoder)
        case .offerBadge(let config):
            try config.encode(to: encoder)
        case .productCarousel(let config):
            try config.encode(to: encoder)
        case .productBanner(let config):
            try config.encode(to: encoder)
        case .productStore(let config):
            try config.encode(to: encoder)
        }
    }
}

/// Banner Config (Simple)
public struct BannerConfig: Codable {
    public let imageUrl: String
    public let title: String
    public let subtitle: String?
    public let ctaText: String?
    public let ctaLink: String?
    public let deeplinkUrl: String?
    public let deeplinkAction: String?
    
    public init(
        imageUrl: String,
        title: String,
        subtitle: String? = nil,
        ctaText: String? = nil,
        ctaLink: String? = nil,
        deeplinkUrl: String? = nil,
        deeplinkAction: String? = nil
    ) {
        self.imageUrl = imageUrl
        self.title = title
        self.subtitle = subtitle
        self.ctaText = ctaText
        self.ctaLink = ctaLink
        self.deeplinkUrl = deeplinkUrl
        self.deeplinkAction = deeplinkAction
    }
}

/// Product Spotlight Config
public struct ProductSpotlightConfig: Codable {
    public let productId: String
    public let highlightText: String?
}

/// Countdown Config
public struct CountdownConfig: Codable {
    // Core (requeridos)
    public let endDate: String
    public let title: String
    
    // Visuales (opcionales)
    public let logoUrl: String?
    public let subtitle: String?
    public let backgroundImageUrl: String?
    public let backgroundColor: String?
    public let discountBadgeText: String?
    public let ctaText: String?
    public let ctaLink: String?
    public let deeplink: String?
    public let overlayOpacity: Double?
    public let buttonColor: String?
    public let style: String?
    
    // Method to convert CountdownConfig to OfferBannerConfig
    public func toOfferBannerConfig() -> OfferBannerConfig? {
        return OfferBannerConfig(
            logoUrl: logoUrl ?? "",
            title: title,
            subtitle: subtitle,
            backgroundImageUrl: backgroundImageUrl,
            backgroundColor: backgroundColor,
            countdownEndDate: endDate,
            discountBadgeText: discountBadgeText ?? "",
            ctaText: ctaText ?? "Shop Now",
            ctaLink: ctaLink,
            overlayOpacity: overlayOpacity,
            buttonColor: buttonColor,
            deeplinkUrl: deeplink,  // Map single deeplink to deeplinkUrl
            deeplinkAction: nil
        )
    }
}

/// Carousel Auto Config
public struct CarouselAutoConfig: Codable {
    public let channelId: String
    public let displayCount: Int?
}

/// Carousel Manual Config
public struct CarouselManualConfig: Codable {
    public let productIds: [String]
}

/// Offer Badge Config
public struct OfferBadgeConfig: Codable {
    public let text: String
    public let color: String?
}

/// Product Carousel Config
public struct ProductCarouselConfig: Codable, Equatable {
    public let productIds: [String]
    public let autoPlay: Bool
    public let interval: Int  // milliseconds
    public let layout: String?  // "compact", "full", or "horizontal" (default: "full")
    
    public init(productIds: [String] = [], autoPlay: Bool = false, interval: Int = 3000, layout: String? = nil) {
        self.productIds = productIds
        self.autoPlay = autoPlay
        self.interval = interval
        self.layout = layout
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // productIds is optional, defaults to empty array (loads all products)
        self.productIds = try container.decodeIfPresent([String].self, forKey: .productIds) ?? []
        
        // autoPlay is optional, defaults to false if not present
        self.autoPlay = try container.decodeIfPresent(Bool.self, forKey: .autoPlay) ?? false
        
        // interval is optional, defaults to 3000ms if not present
        self.interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 3000
        
        // layout is optional
        self.layout = try container.decodeIfPresent(String.self, forKey: .layout)
    }
    
    enum CodingKeys: String, CodingKey {
        case productIds
        case autoPlay
        case interval
        case layout
    }
}

/// Product Banner Config
public struct ProductBannerConfig: Codable {
    public let productId: String
    public let backgroundImageUrl: String
    public let title: String
    public let subtitle: String?
    public let ctaText: String
    public let ctaLink: String?
    public let deeplink: String?
    
    // Optional styling properties
    public let titleColor: String?
    public let subtitleColor: String?
    public let buttonBackgroundColor: String?
    public let buttonTextColor: String?
    public let backgroundColor: String?  // Background color overlay (e.g., "rgba(0, 0, 0, 0.5)")
    public let overlayOpacity: Double?
    public let bannerHeight: Int?  // Absolute height in points (fallback)
    public let bannerHeightRatio: Double?  // Ratio of screen width (0.0-1.0, e.g., 0.25 = 25% of width) - preferred for responsive design
    public let titleFontSize: Int?
    public let subtitleFontSize: Int?
    public let buttonFontSize: Int?
    public let textAlignment: String?  // "left", "center", "right"
    public let contentVerticalAlignment: String?  // "top", "center", "bottom"
    
    public init(
        productId: String,
        backgroundImageUrl: String,
        title: String,
        subtitle: String? = nil,
        ctaText: String,
        ctaLink: String? = nil,
        deeplink: String? = nil,
        titleColor: String? = nil,
        subtitleColor: String? = nil,
        buttonBackgroundColor: String? = nil,
        buttonTextColor: String? = nil,
        backgroundColor: String? = nil,
        overlayOpacity: Double? = nil,
        bannerHeight: Int? = nil,
        bannerHeightRatio: Double? = nil,
        titleFontSize: Int? = nil,
        subtitleFontSize: Int? = nil,
        buttonFontSize: Int? = nil,
        textAlignment: String? = nil,
        contentVerticalAlignment: String? = nil
    ) {
        self.productId = productId
        self.backgroundImageUrl = backgroundImageUrl
        self.title = title
        self.subtitle = subtitle
        self.ctaText = ctaText
        self.ctaLink = ctaLink
        self.deeplink = deeplink
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.buttonBackgroundColor = buttonBackgroundColor
        self.buttonTextColor = buttonTextColor
        self.backgroundColor = backgroundColor
        self.overlayOpacity = overlayOpacity
        self.bannerHeight = bannerHeight
        self.bannerHeightRatio = bannerHeightRatio
        self.titleFontSize = titleFontSize
        self.subtitleFontSize = subtitleFontSize
        self.buttonFontSize = buttonFontSize
        self.textAlignment = textAlignment
        self.contentVerticalAlignment = contentVerticalAlignment
    }
}

/// Product Store Config
public struct ProductStoreConfig: Codable {
    public let mode: String  // "all" or "filtered"
    public let productIds: [String]?
    public let displayType: String  // "grid" or "list"
    public let columns: Int
    
    public init(mode: String, productIds: [String]? = nil, displayType: String = "grid", columns: Int = 2) {
        self.mode = mode
        self.productIds = productIds
        self.displayType = displayType
        self.columns = columns
    }
}

/// WebSocket message for component status changes
public struct ComponentStatusMessage: Codable {
    public let type: String // "component_status_changed"
    public let campaignId: Int
    public let componentId: String
    public let status: String // "active" or "inactive"
    public let component: ComponentData?
    
    public struct ComponentData: Codable {
        public let id: String
        public let type: String
        public let name: String
        public let config: ComponentConfig
        
        public init(id: String, type: String, name: String, config: ComponentConfig) {
            self.id = id
            self.type = type
            self.name = name
            self.config = config
        }
    }
    
    public init(type: String, campaignId: Int, componentId: String, status: String, component: ComponentData? = nil) {
        self.type = type
        self.campaignId = campaignId
        self.componentId = componentId
        self.status = status
        self.component = component
    }
}

/// Active component from API
public struct ActiveComponent: Codable, Identifiable {
    public let id: String?
    public let type: String
    public let config: OfferBannerConfig?
    
    public init(id: String?, type: String, config: OfferBannerConfig? = nil) {
        self.id = id
        self.type = type
        self.config = config
    }
}

/// Global component manager for handling dynamic components (singleton)
@MainActor
public class ComponentManager: ObservableObject {
    @Published public private(set) var activeComponents: [ActiveComponentResponse] = []
    @Published public private(set) var activeBanner: OfferBannerConfig?
    @Published public private(set) var isConnected = false
    
    public let campaignId: Int
    private let baseURL = "https://event-streamer-angelo100.replit.app"
    private var webSocketManager: WebSocketManager?
    
    // MARK: - Singleton
    public static let shared = ComponentManager()
    
    private init() {
        self.campaignId = VioConfiguration.shared.liveShowConfiguration.campaignId
        self.webSocketManager = WebSocketManager(campaignId: self.campaignId)
        
        // Auto-connect on initialization
        Task {
            await connect()
        }
    }
    
    
    /// Connect to backend and fetch active components
    public func connect() async {
        // 1. Fetch initial active components
        await fetchActiveComponents()
        
        // 2. Connect WebSocket for real-time updates
        webSocketManager = WebSocketManager(campaignId: campaignId)
        webSocketManager?.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleMessage(message)
            }
        }
        
        await webSocketManager?.connect()
        isConnected = true
    }
    
    /// Disconnect from backend
    public func disconnect() {
        webSocketManager?.disconnect()
        webSocketManager = nil
        isConnected = false
    }
    
    /// Fetch active components from API
    private func fetchActiveComponents() async {
        let urlString = "\(baseURL)/api/campaigns/\(campaignId)/active-components"
        
        guard let url = URL(string: urlString) else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let components = try JSONDecoder().decode([ActiveComponentResponse].self, from: data)
            
            self.activeComponents = components
            
            // Extract offer_banner if present
            if let offerBanner = components.first(where: { $0.type == "offer_banner" }) {
                if case .offerBanner(let config) = offerBanner.config {
                    self.activeBanner = config
                }
            }
            // Extract countdown and convert to OfferBannerConfig if no offer_banner
            else if let countdown = components.first(where: { $0.type == "countdown" }) {
                if case .countdown(let config) = countdown.config {
                    if let bannerConfig = config.toOfferBannerConfig() {
                        self.activeBanner = bannerConfig
                    }
                }
            } else {
                self.activeBanner = nil
            }
            
        } catch {
            // Silently fail - component will not be shown
        }
    }
    
    /// Handle WebSocket messages
    private func handleMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ComponentStatusMessage.self, from: data) else {
            return
        }
        
        switch decoded.type {
        case "component_status_changed":
            if decoded.status == "active", let component = decoded.component {
                // Add or update in activeComponents
                let componentResponse = ActiveComponentResponse(
                    componentId: component.id,
                    type: component.type,
                    name: component.name,
                    config: component.config,
                    status: "active",
                    activatedAt: nil
                )
                
                // Remove any existing component with same ID
                activeComponents.removeAll { $0.componentId == component.id }
                // Add the new active component
                activeComponents.append(componentResponse)
                
                // Try offer_banner first
                if case .offerBanner(let bannerConfig) = component.config {
                    activeBanner = bannerConfig
                }
                // Then try countdown and convert
                else if case .countdown(let countdownConfig) = component.config {
                    if let bannerConfig = countdownConfig.toOfferBannerConfig() {
                        activeBanner = bannerConfig
                    }
                }
            } else if decoded.status == "inactive" {
                // Component was deactivated - check if it's the currently active banner
                // Only remove if the deactivated component matches the current banner
                if let component = decoded.component {
                    // Check if the deactivated component is an offer_banner or countdown
                    let isBannerType = (component.type == "offer_banner" || component.type == "countdown")
                    
                    if isBannerType {
                        // Check if this is the currently active banner by comparing componentId
                        if let currentBannerId = activeComponents.first(where: { 
                            $0.type == "offer_banner" || $0.type == "countdown" 
                        })?.componentId, currentBannerId == decoded.componentId {
                            // This is the active banner being deactivated - remove it
                            activeBanner = nil
                            // Also remove from activeComponents
                            activeComponents.removeAll { $0.componentId == decoded.componentId }
                        }
                    }
                } else {
                    // No component data in message, but we have componentId
                    // Check if any active component matches this componentId
                    if activeComponents.contains(where: { $0.componentId == decoded.componentId }) {
                        // Check if it's a banner type
                        if let deactivatedComponent = activeComponents.first(where: { $0.componentId == decoded.componentId }),
                           (deactivatedComponent.type == "offer_banner" || deactivatedComponent.type == "countdown") {
                            activeBanner = nil
                        }
                        // Remove from activeComponents regardless of type
                        activeComponents.removeAll { $0.componentId == decoded.componentId }
                    }
                }
                
                // After removing, check if there are other active banner components
                if activeBanner == nil {
                    // Look for other active offer_banner or countdown components
                    if let otherBanner = activeComponents.first(where: { 
                        $0.type == "offer_banner" || $0.type == "countdown" 
                    }) {
                        if case .offerBanner(let bannerConfig) = otherBanner.config {
                            activeBanner = bannerConfig
                        } else if case .countdown(let countdownConfig) = otherBanner.config {
                            if let bannerConfig = countdownConfig.toOfferBannerConfig() {
                                activeBanner = bannerConfig
                            }
                        }
                    }
                }
            }
            
        case "campaign_ended":
            activeBanner = nil
            activeComponents.removeAll()
            
        default:
            break
        }
    }
}

/// WebSocket manager for component updates
public class WebSocketManager: ObservableObject {
    private let campaignId: Int
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    
    public var onMessage: ((String) -> Void)?
    
    public init(campaignId: Int) {
        self.campaignId = campaignId
        self.urlSession = URLSession(configuration: .default)
    }
    
    public func connect() async {
        // Build WebSocket URL from configuration (same pattern as CampaignWebSocketManager)
        let baseURL = VioConfiguration.shared.campaignConfiguration.webSocketBaseURL
        let wsURLString = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let urlString = "\(wsURLString)/ws/\(campaignId)"
        
        guard let url = URL(string: urlString) else {
            return
        }
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Start listening for messages
        await listenForMessages()
    }
    
    public func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    private func listenForMessages() async {
        while let webSocketTask = webSocketTask {
            do {
                let message = try await webSocketTask.receive()
                switch message {
                case .string(let text):
                    onMessage?(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        onMessage?(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                // Try to reconnect after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    Task {
                        await self.connect()
                    }
                }
                break
            }
        }
    }
}
