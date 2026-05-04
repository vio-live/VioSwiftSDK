import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Cart Configuration

/// Configuration for cart behavior and appearance
public struct CartConfiguration {
    
    // Cart Position
    public let floatingCartPosition: FloatingCartPosition
    public let floatingCartDisplayMode: FloatingCartDisplayMode
    public let floatingCartSize: FloatingCartSize
    
    // Cart Behavior
    public let autoSaveCart: Bool
    public let cartPersistenceKey: String
    public let maxQuantityPerItem: Int
    public let showCartNotifications: Bool
    
    // Checkout Configuration
    public let enableGuestCheckout: Bool
    public let requirePhoneNumber: Bool
    public let defaultShippingCountry: String
    public let supportedPaymentMethods: [String]
    
    public init(
        floatingCartPosition: FloatingCartPosition = .bottomRight,
        floatingCartDisplayMode: FloatingCartDisplayMode = .minimal,
        floatingCartSize: FloatingCartSize = .small,
        autoSaveCart: Bool = true,
        cartPersistenceKey: String = "vio_cart",
        maxQuantityPerItem: Int = 99,
        showCartNotifications: Bool = true,
        enableGuestCheckout: Bool = true,
        requirePhoneNumber: Bool = true,
        defaultShippingCountry: String = "US",
        supportedPaymentMethods: [String] = ["stripe", "klarna", "paypal"]
    ) {
        self.floatingCartPosition = floatingCartPosition
        self.floatingCartDisplayMode = floatingCartDisplayMode
        self.floatingCartSize = floatingCartSize
        self.autoSaveCart = autoSaveCart
        self.cartPersistenceKey = cartPersistenceKey
        self.maxQuantityPerItem = maxQuantityPerItem
        self.showCartNotifications = showCartNotifications
        self.enableGuestCheckout = enableGuestCheckout
        self.requirePhoneNumber = requirePhoneNumber
        self.defaultShippingCountry = defaultShippingCountry
        self.supportedPaymentMethods = supportedPaymentMethods
    }
    
    public static let `default` = CartConfiguration()
}

// MARK: - Floating Cart Enums

public enum FloatingCartPosition: String, CaseIterable {
    case topLeft = "topLeft"
    case topCenter = "topCenter"
    case topRight = "topRight"
    case centerLeft = "centerLeft"
    case centerRight = "centerRight"
    case bottomLeft = "bottomLeft"
    case bottomCenter = "bottomCenter"
    case bottomRight = "bottomRight"
}

public enum FloatingCartDisplayMode: String, CaseIterable {
    case full = "full"
    case compact = "compact"
    case minimal = "minimal"
    case iconOnly = "iconOnly"
}

public enum FloatingCartSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
}

// MARK: - Market Configuration

/// Fallback configuration for markets and currency
public struct MarketConfiguration {
    public let countryCode: String
    public let countryName: String
    public let currencyCode: String
    public let currencySymbol: String
    public let phoneCode: String
    public let flagURL: String?

    public init(
        countryCode: String = "US",
        countryName: String = "United States",
        currencyCode: String = "USD",
        currencySymbol: String = "$",
        phoneCode: String = "+1",
        flagURL: String? = "https://flagcdn.com/w320/us.png"
    ) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.currencyCode = currencyCode
        self.currencySymbol = currencySymbol
        self.phoneCode = phoneCode
        self.flagURL = flagURL
    }

    public static let `default` = MarketConfiguration()
}

// MARK: - Network Configuration

/// Configuration for network requests and API behavior
public struct NetworkConfiguration {
    
    // Request Configuration
    public let timeout: TimeInterval
    public let retryAttempts: Int
    public let enableCaching: Bool
    public let cacheDuration: TimeInterval
    
    // GraphQL Configuration
    public let enableQueryBatching: Bool
    public let enableSubscriptions: Bool
    
    // Performance Configuration
    public let maxConcurrentRequests: Int
    public let requestPriority: RequestPriority
    public let enableCompression: Bool
    
    // Security Configuration
    public let enableSSLPinning: Bool
    public let trustedHosts: [String]
    public let enableCertificateValidation: Bool
    
    // Debug Configuration
    public let enableLogging: Bool
    public let logLevel: LogLevel
    public let enableNetworkInspector: Bool
    
    // Custom Headers
    public let customHeaders: [String: String]
    
    // Offline Configuration
    public let enableOfflineMode: Bool
    public let offlineCacheDuration: TimeInterval
    public let syncStrategy: SyncStrategy
    
    public init(
        timeout: TimeInterval = 30.0,
        retryAttempts: Int = 3,
        enableCaching: Bool = true,
        cacheDuration: TimeInterval = 300, // 5 minutes
        enableQueryBatching: Bool = true,
        enableSubscriptions: Bool = false,
        maxConcurrentRequests: Int = 6,
        requestPriority: RequestPriority = .normal,
        enableCompression: Bool = true,
        enableSSLPinning: Bool = false,
        trustedHosts: [String] = [],
        enableCertificateValidation: Bool = true,
        enableLogging: Bool = false,
        logLevel: LogLevel = .info,
        enableNetworkInspector: Bool = false,
        customHeaders: [String: String] = [:],
        enableOfflineMode: Bool = false,
        offlineCacheDuration: TimeInterval = 86400, // 24 hours
        syncStrategy: SyncStrategy = .automatic
    ) {
        self.timeout = timeout
        self.retryAttempts = retryAttempts
        self.enableCaching = enableCaching
        self.cacheDuration = cacheDuration
        self.enableQueryBatching = enableQueryBatching
        self.enableSubscriptions = enableSubscriptions
        self.maxConcurrentRequests = maxConcurrentRequests
        self.requestPriority = requestPriority
        self.enableCompression = enableCompression
        self.enableSSLPinning = enableSSLPinning
        self.trustedHosts = trustedHosts
        self.enableCertificateValidation = enableCertificateValidation
        self.enableLogging = enableLogging
        self.logLevel = logLevel
        self.enableNetworkInspector = enableNetworkInspector
        self.customHeaders = customHeaders
        self.enableOfflineMode = enableOfflineMode
        self.offlineCacheDuration = offlineCacheDuration
        self.syncStrategy = syncStrategy
    }
    
    public static let `default` = NetworkConfiguration()
}

public enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
}

// MARK: - UI Configuration

/// Configuration for UI components behavior and appearance
public struct UIConfiguration {
    
    // Product Cards
    public let defaultProductCardVariant: ProductCardVariant
    public let enableProductCardAnimations: Bool
    public let showProductBrands: Bool
    public let showProductDescriptions: Bool
    public let showDiscountBadge: Bool
    public let discountBadgeText: String?
    
    // Product Sliders
    public let defaultSliderLayout: ProductSliderLayout
    public let enableSliderPagination: Bool
    public let maxSliderItems: Int
    
    // Images
    public let imageQuality: ImageQuality
    public let enableImageCaching: Bool
    public let placeholderImageType: PlaceholderImageType
    
    // Typography
    public let typographyConfig: TypographyConfiguration
    
    // Shadows & Effects
    public let shadowConfig: ShadowConfiguration
    
    // Animations
    public let animationConfig: AnimationConfiguration
    
    // Layout & Spacing
    public let layoutConfig: LayoutConfiguration
    
    // Accessibility
    public let accessibilityConfig: AccessibilityConfiguration
    
    // Legacy (for backward compatibility)
    public let enableAnimations: Bool
    public let animationDuration: TimeInterval
    public let enableHapticFeedback: Bool
    
    public init(
        defaultProductCardVariant: ProductCardVariant = .grid,
        enableProductCardAnimations: Bool = true,
        showProductBrands: Bool = true,
        showProductDescriptions: Bool = false,
        showDiscountBadge: Bool = false,
        discountBadgeText: String? = nil,
        defaultSliderLayout: ProductSliderLayout = .cards,
        enableSliderPagination: Bool = true,
        maxSliderItems: Int = 20,
        imageQuality: ImageQuality = .medium,
        enableImageCaching: Bool = true,
        placeholderImageType: PlaceholderImageType = .shimmer,
        typographyConfig: TypographyConfiguration = .default,
        shadowConfig: ShadowConfiguration = .default,
        animationConfig: AnimationConfiguration = .default,
        layoutConfig: LayoutConfiguration = .default,
        accessibilityConfig: AccessibilityConfiguration = .default,
        // Legacy parameters for backward compatibility
        enableAnimations: Bool = true,
        animationDuration: TimeInterval = 0.3,
        enableHapticFeedback: Bool = true
    ) {
        self.defaultProductCardVariant = defaultProductCardVariant
        self.enableProductCardAnimations = enableProductCardAnimations
        self.showProductBrands = showProductBrands
        self.showProductDescriptions = showProductDescriptions
        self.showDiscountBadge = showDiscountBadge
        self.discountBadgeText = discountBadgeText
        self.defaultSliderLayout = defaultSliderLayout
        self.enableSliderPagination = enableSliderPagination
        self.maxSliderItems = maxSliderItems
        self.imageQuality = imageQuality
        self.enableImageCaching = enableImageCaching
        self.placeholderImageType = placeholderImageType
        self.typographyConfig = typographyConfig
        self.shadowConfig = shadowConfig
        self.animationConfig = animationConfig
        self.layoutConfig = layoutConfig
        self.accessibilityConfig = accessibilityConfig
        // Legacy properties
        self.enableAnimations = enableAnimations
        self.animationDuration = animationDuration
        self.enableHapticFeedback = enableHapticFeedback
    }
    
    public static let `default` = UIConfiguration()
}

// MARK: - Product Detail Configuration

/// Configuration for product detail modal appearance and behavior
public struct ProductDetailConfiguration {
    // Modal Appearance
    public let modalHeight: ProductDetailModalHeight
    public let imageFullWidth: Bool
    public let imageCornerRadius: CGFloat
    public let imageHeight: CGFloat?
    public let showImageGallery: Bool
    public let headerStyle: ProductDetailHeaderStyle
    public let enableImageZoom: Bool
    
    // Header Options
    public let showNavigationTitle: Bool
    public let closeButtonStyle: CloseButtonStyle
    
    // Content Sections
    public let showDescription: Bool
    public let showSpecifications: Bool
    
    // Additional Options
    public let showCloseButton: Bool
    public let dismissOnTapOutside: Bool
    public let enableShareButton: Bool
    
    public init(
        modalHeight: ProductDetailModalHeight = .full,
        imageFullWidth: Bool = false,
        imageCornerRadius: CGFloat = 12,
        imageHeight: CGFloat? = nil,
        showImageGallery: Bool = true,
        headerStyle: ProductDetailHeaderStyle = .standard,
        enableImageZoom: Bool = true,
        showNavigationTitle: Bool = true,
        closeButtonStyle: CloseButtonStyle = .navigationBar,
        showDescription: Bool = true,
        showSpecifications: Bool = true,
        showCloseButton: Bool = true,
        dismissOnTapOutside: Bool = true,
        enableShareButton: Bool = false
    ) {
        self.modalHeight = modalHeight
        self.imageFullWidth = imageFullWidth
        self.imageCornerRadius = imageCornerRadius
        self.imageHeight = imageHeight
        self.showImageGallery = showImageGallery
        self.headerStyle = headerStyle
        self.enableImageZoom = enableImageZoom
        self.showNavigationTitle = showNavigationTitle
        self.closeButtonStyle = closeButtonStyle
        self.showDescription = showDescription
        self.showSpecifications = showSpecifications
        self.showCloseButton = showCloseButton
        self.dismissOnTapOutside = dismissOnTapOutside
        self.enableShareButton = enableShareButton
    }
    
    public static let `default` = ProductDetailConfiguration()
}

public enum ProductDetailModalHeight: String, CaseIterable {
    case full = "full"
    case threeQuarters = "threeQuarters"
    case half = "half"
    
    public var fraction: CGFloat {
        switch self {
        case .full: return 1.0
        case .threeQuarters: return 0.75
        case .half: return 0.5
        }
    }
}

public enum ProductDetailHeaderStyle: String, CaseIterable {
    case standard = "standard"
    case compact = "compact"
}

public enum CloseButtonStyle: String, CaseIterable {
    case navigationBar = "navigationBar"
    case overlayTopLeft = "overlayTopLeft"
    case overlayTopRight = "overlayTopRight"
}

// MARK: - UI Enums

public enum ProductCardVariant: String, CaseIterable {
    case grid = "grid"
    case list = "list"
    case hero = "hero"
    case minimal = "minimal"
}

public enum ProductSliderLayout: String, CaseIterable {
    case compact = "compact"
    case cards = "cards"
    case featured = "featured"
    case wide = "wide"
    case showcase = "showcase"
    case micro = "micro"
}

public enum ImageQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

public enum PlaceholderImageType: String, CaseIterable {
    case shimmer = "shimmer"
    case blurred = "blurred"
    case solid = "solid"
    case none = "none"
}

// MARK: - Campaign Configuration

/// Configuration for Campaign endpoints
public struct CampaignConfiguration {
    public let webSocketBaseURL: String  // WebSocket endpoint for campaigns (e.g., "https://api-dev.vio.live")
    public let restAPIBaseURL: String    // REST API endpoint for campaigns (same as WebSocket base URL)
    /// API key for campaign admin endpoints (different from SDK API key)
    /// Used for endpoints like GET /v1/sdk/config and GET /v1/offers
    /// Configured in vio-config.json under "campaigns.campaignAdminApiKey"
    /// Only needed if autoDiscover is false (legacy mode)
    public let campaignAdminApiKey: String
    /// Optional override for SDK campaign REST auth (GET `/v1/sdk/broadcast`, etc.).
    /// Prefer a single root `apiKey` in `vio-config.json`; leave this empty so `VioConfiguration.resolvedSdkApiKey` uses the root key.
    /// Legacy: `campaigns.campaignApiKey` in JSON.
    public let campaignApiKey: String
    /// Enable auto-discovery of campaigns using only the Vio SDK API key
    /// When true, campaigns are discovered automatically via GET /v1/sdk/campaigns
    /// When false, uses legacy mode with campaignId from configuration
    public let autoDiscover: Bool
    /// Optional channel ID to filter campaigns during auto-discovery
    public let channelId: Int?
    /// Fallback Commerce GraphQL `Authorization` when `GET /v1/sdk/config` omits `commerce.apiKey` (e.g. local dev / sponsor sin key).
    /// Prefer bootstrap from backend; set in `vio-config.json` as `campaigns.commerceApiKey` only when needed.
    public let commerceApiKey: String
    /// Optional override for Commerce GraphQL endpoint when using `commerceApiKey` without bootstrap URL.
    public let commerceGraphQLURL: String?

    public init(
        webSocketBaseURL: String = "https://api-dev.vio.live",
        restAPIBaseURL: String = "https://api-dev.vio.live",
        campaignAdminApiKey: String = "",
        campaignApiKey: String = "",
        autoDiscover: Bool = false,
        channelId: Int? = nil,
        commerceApiKey: String = "",
        commerceGraphQLURL: String? = nil
    ) {
        self.webSocketBaseURL = webSocketBaseURL
        self.restAPIBaseURL = restAPIBaseURL
        self.campaignAdminApiKey = campaignAdminApiKey
        self.campaignApiKey = campaignApiKey
        self.autoDiscover = autoDiscover
        self.channelId = channelId
        self.commerceApiKey = commerceApiKey
        self.commerceGraphQLURL = commerceGraphQLURL
    }
    
    public static let `default` = CampaignConfiguration()
}

// MARK: - Engagement Configuration

/// Configuration for Engagement System (polls, contests, products)
public struct EngagementConfiguration {
    /// Enable demo mode to use mock data from TimelineDataGenerator instead of backend
    /// When true, EngagementManager will use DemoEngagementRepository
    /// When false, EngagementManager will use BackendEngagementRepository
    public let demoMode: Bool
    
    /// Enable dynamic configuration loading from backend
    /// When true, DynamicConfigurationManager will fetch configs from backend
    /// When false, only local JSON configuration will be used
    public let useDynamicConfig: Bool
    
    public init(demoMode: Bool = false, useDynamicConfig: Bool = true) {
        self.demoMode = demoMode
        self.useDynamicConfig = useDynamicConfig
    }
    
    public static let `default` = EngagementConfiguration()
}

public enum VideoQuality: String, CaseIterable {
    case low = "240p"
    case medium = "480p"
    case high = "720p"
    case hd = "1080p"
    case auto = "auto"
}

// MARK: - Advanced UI Configurations

/// Typography configuration for custom fonts and text styling
public struct TypographyConfiguration {
    // Custom Fonts
    public let fontFamily: String?
    public let enableCustomFonts: Bool
    public let fontWeightMapping: FontWeightMapping
    
    // Dynamic Type Support
    public let supportDynamicType: Bool
    public let minFontScale: CGFloat
    public let maxFontScale: CGFloat
    
    // Text Styling
    public let lineHeightMultiplier: CGFloat
    public let letterSpacing: CGFloat
    public let textAlignment: TextAlignment
    
    public init(
        fontFamily: String? = nil,
        enableCustomFonts: Bool = false,
        fontWeightMapping: FontWeightMapping = .default,
        supportDynamicType: Bool = true,
        minFontScale: CGFloat = 0.8,
        maxFontScale: CGFloat = 1.4,
        lineHeightMultiplier: CGFloat = 1.2,
        letterSpacing: CGFloat = 0.0,
        textAlignment: TextAlignment = .natural
    ) {
        self.fontFamily = fontFamily
        self.enableCustomFonts = enableCustomFonts
        self.fontWeightMapping = fontWeightMapping
        self.supportDynamicType = supportDynamicType
        self.minFontScale = minFontScale
        self.maxFontScale = maxFontScale
        self.lineHeightMultiplier = lineHeightMultiplier
        self.letterSpacing = letterSpacing
        self.textAlignment = textAlignment
    }
    
    public static let `default` = TypographyConfiguration()
}

/// Font weight mapping for custom fonts
public struct FontWeightMapping {
    public let light: String
    public let regular: String
    public let medium: String
    public let semibold: String
    public let bold: String
    
    public init(
        light: String = "Light",
        regular: String = "Regular",
        medium: String = "Medium",
        semibold: String = "Semibold",
        bold: String = "Bold"
    ) {
        self.light = light
        self.regular = regular
        self.medium = medium
        self.semibold = semibold
        self.bold = bold
    }
    
    public static let `default` = FontWeightMapping()
}

/// Shadow and visual effects configuration
public struct ShadowConfiguration {
    // Card Shadows
    public let cardShadowRadius: CGFloat
    public let cardShadowOpacity: Double
    public let cardShadowOffset: CGSize
    public let cardShadowColor: ShadowColor
    
    // Button Shadows
    public let buttonShadowEnabled: Bool
    public let buttonShadowRadius: CGFloat
    public let buttonShadowOpacity: Double
    
    // Modal Shadows
    public let modalShadowRadius: CGFloat
    public let modalShadowOpacity: Double
    
    // Blur Effects
    public let enableBlurEffects: Bool
    public let blurIntensity: Double
    public let blurStyle: BlurStyle
    
    public init(
        cardShadowRadius: CGFloat = 4,
        cardShadowOpacity: Double = 0.1,
        cardShadowOffset: CGSize = CGSize(width: 0, height: 2),
        cardShadowColor: ShadowColor = .adaptive,
        buttonShadowEnabled: Bool = true,
        buttonShadowRadius: CGFloat = 2,
        buttonShadowOpacity: Double = 0.15,
        modalShadowRadius: CGFloat = 20,
        modalShadowOpacity: Double = 0.3,
        enableBlurEffects: Bool = true,
        blurIntensity: Double = 0.3,
        blurStyle: BlurStyle = .systemMaterial
    ) {
        self.cardShadowRadius = cardShadowRadius
        self.cardShadowOpacity = cardShadowOpacity
        self.cardShadowOffset = cardShadowOffset
        self.cardShadowColor = cardShadowColor
        self.buttonShadowEnabled = buttonShadowEnabled
        self.buttonShadowRadius = buttonShadowRadius
        self.buttonShadowOpacity = buttonShadowOpacity
        self.modalShadowRadius = modalShadowRadius
        self.modalShadowOpacity = modalShadowOpacity
        self.enableBlurEffects = enableBlurEffects
        self.blurIntensity = blurIntensity
        self.blurStyle = blurStyle
    }
    
    public static let `default` = ShadowConfiguration()
}

/// Animation configuration for motion and transitions
public struct AnimationConfiguration {
    // Timing
    public let defaultDuration: TimeInterval
    public let springResponse: Double
    public let springDamping: Double
    
    // Animation Types
    public let enableSpringAnimations: Bool
    public let enableMicroInteractions: Bool
    public let enablePageTransitions: Bool
    public let enableSharedElementTransitions: Bool
    
    // Easing
    public let defaultEasing: AnimationEasing
    public let customTimingCurve: (Double, Double, Double, Double)?
    
    // Performance
    public let respectReduceMotion: Bool
    public let animationQuality: AnimationQuality
    public let enableHardwareAcceleration: Bool
    
    public init(
        defaultDuration: TimeInterval = 0.3,
        springResponse: Double = 0.4,
        springDamping: Double = 0.8,
        enableSpringAnimations: Bool = true,
        enableMicroInteractions: Bool = true,
        enablePageTransitions: Bool = true,
        enableSharedElementTransitions: Bool = false,
        defaultEasing: AnimationEasing = .easeInOut,
        customTimingCurve: (Double, Double, Double, Double)? = nil,
        respectReduceMotion: Bool = true,
        animationQuality: AnimationQuality = .high,
        enableHardwareAcceleration: Bool = true
    ) {
        self.defaultDuration = defaultDuration
        self.springResponse = springResponse
        self.springDamping = springDamping
        self.enableSpringAnimations = enableSpringAnimations
        self.enableMicroInteractions = enableMicroInteractions
        self.enablePageTransitions = enablePageTransitions
        self.enableSharedElementTransitions = enableSharedElementTransitions
        self.defaultEasing = defaultEasing
        self.customTimingCurve = customTimingCurve
        self.respectReduceMotion = respectReduceMotion
        self.animationQuality = animationQuality
        self.enableHardwareAcceleration = enableHardwareAcceleration
    }
    
    public static let `default` = AnimationConfiguration()
}

/// Layout and spacing configuration
public struct LayoutConfiguration {
    // Grid System
    public let gridColumns: Int
    public let gridSpacing: CGFloat
    public let gridMinItemWidth: CGFloat
    public let gridMaxItemWidth: CGFloat?
    
    // Safe Areas
    public let respectSafeAreas: Bool
    public let customSafeAreaInsets: EdgeInsets?
    public let extendThroughSafeArea: Bool
    
    // Responsive Design
    public let compactWidthThreshold: CGFloat
    public let regularWidthThreshold: CGFloat
    public let enableResponsiveLayout: Bool
    
    // Margins and Padding
    public let screenMargins: CGFloat
    public let sectionSpacing: CGFloat
    public let componentSpacing: CGFloat
    
    public init(
        gridColumns: Int = 2,
        gridSpacing: CGFloat = 16,
        gridMinItemWidth: CGFloat = 150,
        gridMaxItemWidth: CGFloat? = nil,
        respectSafeAreas: Bool = true,
        customSafeAreaInsets: EdgeInsets? = nil,
        extendThroughSafeArea: Bool = false,
        compactWidthThreshold: CGFloat = 768,
        regularWidthThreshold: CGFloat = 1024,
        enableResponsiveLayout: Bool = true,
        screenMargins: CGFloat = 16,
        sectionSpacing: CGFloat = 24,
        componentSpacing: CGFloat = 16
    ) {
        self.gridColumns = gridColumns
        self.gridSpacing = gridSpacing
        self.gridMinItemWidth = gridMinItemWidth
        self.gridMaxItemWidth = gridMaxItemWidth
        self.respectSafeAreas = respectSafeAreas
        self.customSafeAreaInsets = customSafeAreaInsets
        self.extendThroughSafeArea = extendThroughSafeArea
        self.compactWidthThreshold = compactWidthThreshold
        self.regularWidthThreshold = regularWidthThreshold
        self.enableResponsiveLayout = enableResponsiveLayout
        self.screenMargins = screenMargins
        self.sectionSpacing = sectionSpacing
        self.componentSpacing = componentSpacing
    }
    
    public static let `default` = LayoutConfiguration()
}

/// Accessibility configuration
public struct AccessibilityConfiguration {
    // Voice Over
    public let enableVoiceOverOptimizations: Bool
    public let customVoiceOverLabels: [String: String]
    
    // Dynamic Type
    public let enableDynamicTypeSupport: Bool
    public let maxDynamicTypeSize: DynamicTypeSize
    
    // Contrast & Colors
    public let respectHighContrastMode: Bool
    public let enableColorBlindnessSupport: Bool
    public let contrastRatio: ContrastRatio
    
    // Motion & Animations
    public let respectReduceMotion: Bool
    public let alternativeToAnimations: Bool
    
    // Touch & Interaction
    public let minimumTouchTargetSize: CGFloat
    public let enableHapticFeedback: Bool
    public let hapticIntensity: HapticIntensity
    
    public init(
        enableVoiceOverOptimizations: Bool = true,
        customVoiceOverLabels: [String: String] = [:],
        enableDynamicTypeSupport: Bool = true,
        maxDynamicTypeSize: DynamicTypeSize = .accessibility3,
        respectHighContrastMode: Bool = true,
        enableColorBlindnessSupport: Bool = false,
        contrastRatio: ContrastRatio = .aa,
        respectReduceMotion: Bool = true,
        alternativeToAnimations: Bool = true,
        minimumTouchTargetSize: CGFloat = 44,
        enableHapticFeedback: Bool = true,
        hapticIntensity: HapticIntensity = .medium
    ) {
        self.enableVoiceOverOptimizations = enableVoiceOverOptimizations
        self.customVoiceOverLabels = customVoiceOverLabels
        self.enableDynamicTypeSupport = enableDynamicTypeSupport
        self.maxDynamicTypeSize = maxDynamicTypeSize
        self.respectHighContrastMode = respectHighContrastMode
        self.enableColorBlindnessSupport = enableColorBlindnessSupport
        self.contrastRatio = contrastRatio
        self.respectReduceMotion = respectReduceMotion
        self.alternativeToAnimations = alternativeToAnimations
        self.minimumTouchTargetSize = minimumTouchTargetSize
        self.enableHapticFeedback = enableHapticFeedback
        self.hapticIntensity = hapticIntensity
    }
    
    public static let `default` = AccessibilityConfiguration()
}

// MARK: - Brand Configuration

/// Configuration for brand name and icon used in engagement components
public struct BrandConfiguration {
    /// Brand name displayed in engagement components (e.g., "Power", "Elkjøp")
    public let name: String
    
    /// Brand icon asset name (e.g., "avatar_power", "avatar_elkjop")
    public let iconAsset: String
    
    public init(
        name: String = "Vio",
        iconAsset: String = "avatar_el"
    ) {
        // Q4 L3 B8 (2026-05-04): default name changed from "Elkjøp" to
        // "Vio" so the Apple Pay sheet doesn't always show "Pay Elkjøp"
        // for hosts that haven't customized `brandConfiguration`.
        // Multi-sponsor stores additionally override per active sponsor
        // in `ApplePayManager.buildSummaryItems` (see that helper).
        self.name = name
        self.iconAsset = iconAsset
    }
    
    public static let `default` = BrandConfiguration()
    
    /// Legacy Power brand configuration. Kept for API compatibility; prefer `elkjøp` for new demos.
    public static let power = BrandConfiguration(
        name: "Power",
        iconAsset: "avatar_power"
    )
    
    /// Elkjøp brand configuration
    public static let elkjøp = BrandConfiguration(
        name: "Elkjøp",
        iconAsset: "avatar_elkjop"
    )
}

// MARK: - Supporting Enums

public enum TextAlignment: String, CaseIterable {
    case leading = "leading"
    case center = "center"
    case trailing = "trailing"
    case natural = "natural"
}

public enum ShadowColor: String, CaseIterable {
    case black = "black"
    case gray = "gray"
    case adaptive = "adaptive"
    case custom = "custom"
}

public enum BlurStyle: String, CaseIterable {
    case systemMaterial = "systemMaterial"
    case regularMaterial = "regularMaterial"
    case thickMaterial = "thickMaterial"
    case thinMaterial = "thinMaterial"
    case ultraThinMaterial = "ultraThinMaterial"
}

public enum AnimationEasing: String, CaseIterable {
    case linear = "linear"
    case easeIn = "easeIn"
    case easeOut = "easeOut"
    case easeInOut = "easeInOut"
    case spring = "spring"
    case custom = "custom"
}

public enum AnimationQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
}

public enum DynamicTypeSize: String, CaseIterable {
    case xSmall = "xSmall"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case xLarge = "xLarge"
    case xxLarge = "xxLarge"
    case xxxLarge = "xxxLarge"
    case accessibility1 = "accessibility1"
    case accessibility2 = "accessibility2"
    case accessibility3 = "accessibility3"
    case accessibility4 = "accessibility4"
    case accessibility5 = "accessibility5"
}

public enum ContrastRatio: String, CaseIterable {
    case aa = "aa"           // 4.5:1
    case aaa = "aaa"         // 7:1
    case custom = "custom"
}

public enum HapticIntensity: String, CaseIterable {
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
}

// MARK: - Network Enums

public enum RequestPriority: String, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
}

public enum SyncStrategy: String, CaseIterable {
    case automatic = "automatic"
    case manual = "manual"
    case background = "background"
    case realtime = "realtime"
}

// MARK: - Demo Data Configuration

/// Configuration for static demo data used in demos and development
/// This data can be replaced with backend data or moved to vio-config.json
public struct DemoDataConfiguration {
    
    // MARK: - Assets
    
    public struct AssetConfiguration {
        public let defaultLogo: String
        public let defaultAvatar: String
        public let backgroundImages: BackgroundImageAssets
        public let brandAssets: BrandImageAssets
        public let contestAssets: ContestImageAssets
        
        public struct BackgroundImageAssets {
            public let footballField: String
            public let mainBackground: String
            public let sportDetail: String
            public let sportDetailImage: String
            
            public init(
                footballField: String = "football_field_bg",
                mainBackground: String = "bg-main",
                sportDetail: String = "bg",
                sportDetailImage: String = "img1"
            ) {
                self.footballField = footballField
                self.mainBackground = mainBackground
                self.sportDetail = sportDetail
                self.sportDetailImage = sportDetailImage
            }
        }
        
        public struct BrandImageAssets {
            public let icon: String
            public let logo: String
            
            public init(
                icon: String = "icon ",
                logo: String = "logo"
            ) {
                self.icon = icon
                self.logo = logo
            }
        }
        
        public struct ContestImageAssets {
            public let giftCard: String
            public let championsLeagueTickets: String
            
            public init(
                giftCard: String = "contest_prize_giftcard",
                championsLeagueTickets: String = "contest_prize_tickets"
            ) {
                self.giftCard = giftCard
                self.championsLeagueTickets = championsLeagueTickets
            }
        }
        
        public init(
            defaultLogo: String = "default_logo",
            defaultAvatar: String = "avatar_el",
            backgroundImages: BackgroundImageAssets = BackgroundImageAssets(
                footballField: "football_field_bg",
                mainBackground: "bg-main",
                sportDetail: "bg",
                sportDetailImage: "img1"
            ),
            brandAssets: BrandImageAssets = BrandImageAssets(
                icon: "icon ",
                logo: "logo"
            ),
            contestAssets: ContestImageAssets = ContestImageAssets(
                giftCard: "contest_prize_giftcard",
                championsLeagueTickets: "contest_prize_tickets"
            )
        ) {
            self.defaultLogo = defaultLogo
            self.defaultAvatar = defaultAvatar
            self.backgroundImages = backgroundImages
            self.brandAssets = brandAssets
            self.contestAssets = contestAssets
        }
    }
    
    // MARK: - Demo Users
    
    public struct DemoUserConfiguration {
        public let defaultUsername: String
        public let chatUsernames: [ChatUsername]
        public let socialAccounts: [SocialAccount]
        
        public struct ChatUsername: Codable {
            public let name: String
            public let color: String
        }
        
        public struct SocialAccount: Codable {
            public let name: String
            public let handle: String
            public let verified: Bool
        }
        
        public init(
            defaultUsername: String = "Usuario",
            chatUsernames: [ChatUsername] = [],
            socialAccounts: [SocialAccount] = []
        ) {
            self.defaultUsername = defaultUsername
            self.chatUsernames = chatUsernames
            self.socialAccounts = socialAccounts
        }
    }
    
    // MARK: - Product Mappings
    
    public struct ProductMapping: Codable {
        public let name: String
        public let productUrl: String
        public let checkoutUrl: String
    }
    
    // MARK: - Event IDs
    
    public struct EventIdConfiguration {
        public let contestQuiz: String
        public let contestGiveaway: String
        public let productCombo: String
        public let tweetHalftime1: String
        public let tweetHalftime2: String
        
        public init(
            contestQuiz: String = "casting-contest-quiz",
            contestGiveaway: String = "casting-contest-giveaway",
            productCombo: String = "casting-product-combo",
            tweetHalftime1: String = "tweet-halftime-1",
            tweetHalftime2: String = "tweet-halftime-2"
        ) {
            self.contestQuiz = contestQuiz
            self.contestGiveaway = contestGiveaway
            self.productCombo = productCombo
            self.tweetHalftime1 = tweetHalftime1
            self.tweetHalftime2 = tweetHalftime2
        }
    }
    
    // MARK: - Timeline Events (for demo mode)
    
    public struct TimelineEventsConfiguration {
        public let castingContests: [CastingContestItem]
        public let castingProducts: [CastingProductItem]
        
        public struct CastingContestItem {
            public let id: String
            public let videoTimestamp: Int
            public let title: String
            public let description: String
            public let prize: String
            public let contestType: String
            public let imageAsset: String
            
            public init(id: String, videoTimestamp: Int, title: String, description: String, prize: String, contestType: String, imageAsset: String) {
                self.id = id
                self.videoTimestamp = videoTimestamp
                self.title = title
                self.description = description
                self.prize = prize
                self.contestType = contestType
                self.imageAsset = imageAsset
            }
        }
        
        public struct CastingProductItem {
            public let id: String
            public let videoTimestamp: Int
            public let productId: String
            public let productIds: [String]
            public let title: String
            public let description: String
            
            public init(id: String, videoTimestamp: Int, productId: String, productIds: [String], title: String, description: String) {
                self.id = id
                self.videoTimestamp = videoTimestamp
                self.productId = productId
                self.productIds = productIds
                self.title = title
                self.description = description
            }
        }
        
        public init(castingContests: [CastingContestItem] = [], castingProducts: [CastingProductItem] = []) {
            self.castingContests = castingContests
            self.castingProducts = castingProducts
        }
    }
    
    // MARK: - Match Defaults
    
    public struct MatchDefaultConfiguration {
        public let broadcastIdMappings: [String: String]
        public let defaultScore: Int
        
        public init(
            broadcastIdMappings: [String: String] = ["barcelona-psg": "barcelona-psg-2025-01-23"],
            defaultScore: Int = 3
        ) {
            self.broadcastIdMappings = broadcastIdMappings
            self.defaultScore = defaultScore
        }
    }
    
    // MARK: - Carousel Cards
    
    public struct CarouselCardItem: Codable {
        public let imageUrl: String
        public let time: String
        public let logo: String
        public let title: String
        public let subtitle: String
        
        public init(imageUrl: String = "img1", time: String = "", logo: String = "", title: String = "", subtitle: String = "") {
            self.imageUrl = imageUrl
            self.time = time
            self.logo = logo
            self.title = title
            self.subtitle = subtitle
        }
    }
    
    // MARK: - Live Cards
    
    public struct LiveCardItem: Codable {
        public let logo: String
        public let logoIcon: String
        public let title: String
        public let subtitle: String
        public let time: String
        public let backgroundImage: String?
        
        public init(logo: String = "", logoIcon: String = "star.fill", title: String = "", subtitle: String = "", time: String = "", backgroundImage: String? = nil) {
            self.logo = logo
            self.logoIcon = logoIcon
            self.title = title
            self.subtitle = subtitle
            self.time = time
            self.backgroundImage = backgroundImage
        }
    }
    
    // MARK: - Sport Clips
    
    public struct SportClipItem: Codable {
        public let imageUrl: String
        public let time: String
        public let title: String
        public let subtitle: String
        public let isLarge: Bool
        
        public init(imageUrl: String = "img1", time: String = "", title: String = "", subtitle: String = "", isLarge: Bool = false) {
            self.imageUrl = imageUrl
            self.time = time
            self.title = title
            self.subtitle = subtitle
            self.isLarge = isLarge
        }
    }
    
    // MARK: - Offer Banner
    
    public struct OfferBannerConfiguration {
        public let countdown: CountdownConfiguration
        public let title: String
        public let subtitle: String
        public let discountText: String
        public let buttonText: String
        
        public struct CountdownConfiguration {
            public let days: Int
            public let hours: Int
            public let minutes: Int
            public let seconds: Int
            
            public init(
                days: Int = 2,
                hours: Int = 1,
                minutes: Int = 59,
                seconds: Int = 47
            ) {
                self.days = days
                self.hours = hours
                self.minutes = minutes
                self.seconds = seconds
            }
        }
        
        public init(
            countdown: CountdownConfiguration = CountdownConfiguration(),
            title: String = "Ukens tilbud",
            subtitle: String = "Se denne ukes beste tilbud",
            discountText: String = "Opp til 30%",
            buttonText: String = "Se alle tilbud"
        ) {
            self.countdown = countdown
            self.title = title
            self.subtitle = subtitle
            self.discountText = discountText
            self.buttonText = buttonText
        }
    }
    
    // MARK: - Brand Override (optional - when set, overrides vio-config brand for demo consistency)
    
    public let brand: BrandConfiguration?
    
    // MARK: - Properties
    
    public let assets: AssetConfiguration
    public let demoUsers: DemoUserConfiguration
    public let productMappings: [String: ProductMapping]
    public let eventIds: EventIdConfiguration
    public let matchDefaults: MatchDefaultConfiguration
    public let offerBanner: OfferBannerConfiguration
    public let carouselCards: [CarouselCardItem]
    public let liveCards: [LiveCardItem]
    public let sportClips: [SportClipItem]
    public let timelineEvents: TimelineEventsConfiguration
    
    public init(
        brand: BrandConfiguration? = nil,
        assets: AssetConfiguration = AssetConfiguration(),
        demoUsers: DemoUserConfiguration = DemoUserConfiguration(),
        productMappings: [String: ProductMapping] = [:],
        eventIds: EventIdConfiguration = EventIdConfiguration(),
        matchDefaults: MatchDefaultConfiguration = MatchDefaultConfiguration(),
        offerBanner: OfferBannerConfiguration = OfferBannerConfiguration(),
        carouselCards: [CarouselCardItem] = [],
        liveCards: [LiveCardItem] = [],
        sportClips: [SportClipItem] = [],
        timelineEvents: TimelineEventsConfiguration = TimelineEventsConfiguration()
    ) {
        self.brand = brand
        self.assets = assets
        self.demoUsers = demoUsers
        self.productMappings = productMappings
        self.eventIds = eventIds
        self.matchDefaults = matchDefaults
        self.offerBanner = offerBanner
        self.carouselCards = carouselCards
        self.liveCards = liveCards
        self.sportClips = sportClips
        self.timelineEvents = timelineEvents
    }
    
    public static let `default` = DemoDataConfiguration()
}
