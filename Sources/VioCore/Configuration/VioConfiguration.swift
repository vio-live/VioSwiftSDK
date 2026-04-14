import Foundation
import SwiftUI

/// Vio SDK Global Configuration
///
/// Centralized configuration system that allows developers to set up the entire SDK
/// once and use it across all modules (Core, UI, engagement, casting, etc.) without additional setup.
///
/// **Usage:**
/// ```swift
/// // Configure once in AppDelegate or App.swift
/// VioConfiguration.configure(
///     apiKey: "your-api-key",
///     environment: .production,
///     theme: .default
/// )
/// 
/// // Use anywhere in the app
/// VProductCard(product: product) // Uses global config
/// VCheckoutOverlay() // Uses global cart position and colors
/// ```
public class VioConfiguration: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = VioConfiguration()
    
    // MARK: - Configuration Properties
    @Published public private(set) var apiKey: String = ""
    @Published public private(set) var environment: VioEnvironment = .sandbox
    @Published public private(set) var theme: VioTheme = .default
    @Published public private(set) var cartConfiguration: CartConfiguration = .default
    @Published public private(set) var networkConfiguration: NetworkConfiguration = .default
    @Published public private(set) var uiConfiguration: UIConfiguration = .default
    @Published public private(set) var marketConfiguration: MarketConfiguration = .default
    @Published public private(set) var productDetailConfiguration: ProductDetailConfiguration = .default
    @Published public private(set) var localizationConfiguration: LocalizationConfiguration = .default
    @Published public private(set) var campaignConfiguration: CampaignConfiguration = .default
    @Published public private(set) var analyticsConfiguration: AnalyticsConfiguration = .default
    @Published public private(set) var brandConfiguration: BrandConfiguration = .default
    @Published public private(set) var engagementConfiguration: EngagementConfiguration = .default
    @Published public private(set) var demoDataConfiguration: DemoDataConfiguration = .default
    
    // MARK: - Dynamic Configuration Properties
    @Published public private(set) var dynamicBrandConfig: DynamicBrandConfig?
    @Published public private(set) var dynamicEngagementConfig: DynamicEngagementConfig?
    @Published public private(set) var dynamicLocalizationConfig: DynamicLocalizationConfig?
    
    /// Dedicated WebSocket base URL for campaign connections.
    /// Dev default: wss://ws-dev.vio.live
    /// Prod default: wss://ws.vio.live
    /// Set by ConfigurationLoader from vio-config.json campaigns.wsBaseURL / campaigns.devWsBaseURL
    @Published public private(set) var wsBaseURL: String = "wss://ws-dev.vio.live"
    
    /// API key for SDK campaign REST endpoints: `/v1/sdk/broadcast`, `/v1/sdk/campaigns`, `/api/campaigns/...`, lineup, dynamic config.
    /// Prefer a single root `apiKey` in `vio-config.json`; when `campaigns.campaignApiKey` is non-empty it overrides (legacy).
    public var resolvedSdkApiKey: String {
        let override = campaignConfiguration.campaignApiKey
        return override.isEmpty ? apiKey : override
    }
    
    /// Commerce GraphQL `Authorization` from `GET /v1/sdk/config` only (not the SDK root `apiKey`).
    @Published public private(set) var sdkBootstrapCommerceApiKey: String?
    /// Commerce GraphQL URL from bootstrap (`commerce.endpoint` or `endpoints.commerceGraphQL`).
    @Published public private(set) var sdkBootstrapCommerceGraphQLURL: String?

    /// Last successful raw body of ``GET /v1/sdk/config`` (HTTP 2xx). Replaced on each successful fetch.
    @Published public private(set) var lastSdkConfigRawData: Data?
    /// Last decoded ``SdkRemoteConfig`` when JSON decoding succeeded; `nil` if only ``lastSdkConfigRawData`` is available.
    @Published public private(set) var lastSdkConfig: SdkRemoteConfig?

    @Published public private(set) var isConfigured: Bool = false
    @Published public private(set) var isMarketAvailable: Bool = true  // If false, SDK should not be used
    @Published public private(set) var userCountryCode: String? = nil  // User's country code if provided
    @Published public private(set) var availableMarkets: [GetAvailableMarketsDto] = []  // List of available markets from backend
    
    private init() {}
    
    // MARK: - Configuration Methods
    
    /// Main configuration method - call once at app startup
    public static func configure(
        apiKey: String,
        environment: VioEnvironment = .production,
        theme: VioTheme? = nil,
        cartConfig: CartConfiguration? = nil,
        networkConfig: NetworkConfiguration? = nil,
        uiConfig: UIConfiguration? = nil,
        marketConfig: MarketConfiguration? = nil,
        productDetailConfig: ProductDetailConfiguration? = nil,
        localizationConfig: LocalizationConfiguration? = nil,
        campaignConfig: CampaignConfiguration? = nil,
        analyticsConfig: AnalyticsConfiguration? = nil,
        brandConfig: BrandConfiguration? = nil,
        demoDataConfig: DemoDataConfiguration? = nil,
        engagementConfig: EngagementConfiguration? = nil
    ) {
        let instance = VioConfiguration.shared
        instance.resetSdkRemoteConfigSnapshot()
        instance.applySdkBootstrapCommerce(apiKey: nil, graphQLURL: nil)

        instance.apiKey = apiKey
        instance.environment = environment
        instance.theme = theme ?? .default
        instance.cartConfiguration = cartConfig ?? .default
        instance.networkConfiguration = networkConfig ?? .default
        instance.uiConfiguration = uiConfig ?? .default
        instance.marketConfiguration = marketConfig ?? .default
        instance.productDetailConfiguration = productDetailConfig ?? .default
        instance.localizationConfiguration = localizationConfig ?? .default
        instance.campaignConfiguration = campaignConfig ?? .default
        instance.analyticsConfiguration = analyticsConfig ?? .default
        instance.demoDataConfiguration = demoDataConfig ?? ConfigurationLoader.loadDemoDataConfiguration()
        // Brand: demo data overrides vio-config for consistency (single source per demo)
        if let demoBrand = instance.demoDataConfiguration.brand {
            instance.brandConfiguration = demoBrand
        } else if let brand = brandConfig {
            // Sync icon from demo assets when no explicit brand in demo data
            let iconAsset = instance.demoDataConfiguration.assets.defaultAvatar
            instance.brandConfiguration = BrandConfiguration(name: brand.name, iconAsset: iconAsset)
        } else {
            let iconAsset = instance.demoDataConfiguration.assets.defaultAvatar
            instance.brandConfiguration = BrandConfiguration(name: BrandConfiguration.default.name, iconAsset: iconAsset)
        }
        instance.engagementConfiguration = engagementConfig ?? .default
        
        // Configure localization system
        VioLocalization.shared.configure(instance.localizationConfiguration)
        
        instance.isConfigured = true
        
        // Initialize AnalyticsManager
        Task { @MainActor in
            AnalyticsManager.shared.configure(instance.analyticsConfiguration)
        }
        
        // Initialize CampaignManager with new configuration
        Task { @MainActor in
            CampaignManager.shared.reinitialize()
        }

        // Prime commerce GraphQL credentials from GET /v1/sdk/config so ProductService is ready before cart_intent / overlays.
        Task { @MainActor in
            await CampaignManager.shared.ensureCommerceBootstrapApplied()
        }
    }
    
    /// Quick configuration with just API key (uses defaults for everything else)
    public static func configure(apiKey: String) {
        configure(
            apiKey: apiKey,
            environment: .production,
            theme: nil,
            cartConfig: nil,
            networkConfig: nil,
            uiConfig: nil
        )
    }
    
    /// Map country codes to language codes
    /// Used to automatically select language based on market
    private static func languageCodeForCountry(_ countryCode: String?) -> String {
        guard let countryCode = countryCode?.uppercased() else { return "en" }
        
        // Map country codes to language codes
        let countryToLanguage: [String: String] = [
            "DE": "de",  // Germany → German
            "AT": "de",  // Austria → German
            "CH": "de",  // Switzerland → German
            "US": "en",  // United States → English
            "GB": "en",  // United Kingdom → English
            "CA": "en",  // Canada → English
            "AU": "en",  // Australia → English
            "NO": "no",  // Norway → Norwegian
            "SE": "sv",  // Sweden → Swedish
            "DK": "da",  // Denmark → Danish
            "FI": "fi",  // Finland → Finnish
            "ES": "es",  // Spain → Spanish
            "FR": "fr",  // France → French
            "IT": "it",  // Italy → Italian
            "NL": "nl",  // Netherlands → Dutch
            "PL": "pl",  // Poland → Polish
            "PT": "pt",  // Portugal → Portuguese
            "BR": "pt",  // Brazil → Portuguese
            "MX": "es",  // Mexico → Spanish
            "AR": "es",  // Argentina → Spanish
            "CL": "es",  // Chile → Spanish
            "CO": "es",  // Colombia → Spanish
            "JP": "ja",  // Japan → Japanese
            "CN": "zh",  // China → Chinese
            "KR": "ko",  // South Korea → Korean
        ]
        
        return countryToLanguage[countryCode] ?? "en"  // Default to English
    }
    
    /// Update wsBaseURL — called by ConfigurationLoader after resolving env-specific URL
    internal static func setWsBaseURL(_ url: String) {
        shared.wsBaseURL = url
    }

    /// Set market availability status and store available markets
    /// Also automatically updates language based on country code
    internal static func setMarketAvailable(_ available: Bool, userCountryCode: String? = nil, availableMarkets: [GetAvailableMarketsDto] = []) {
        shared.isMarketAvailable = available
        shared.userCountryCode = userCountryCode
        shared.availableMarkets = availableMarkets
        
        // Automatically update language based on country code
        if let countryCode = userCountryCode {
            let languageCode = languageCodeForCountry(countryCode)
            let localizationConfig = shared.localizationConfiguration
            
            // Check if translations exist for this language
            let hasTranslations = localizationConfig.translations[languageCode] != nil
            
            if hasTranslations {
                // Update language if translations are available
                VioLocalization.shared.setLanguage(languageCode)
            } else {
                // Use default language if translations not available
                let defaultLang = localizationConfig.defaultLanguage
                VioLocalization.shared.setLanguage(defaultLang)
            }
        }
    }
    
    /// Check if a specific country code is available in the markets list
    /// Returns true if the country is in the available markets list
    /// 
    /// **Usage:**
    /// ```swift
    /// if VioConfiguration.shared.isMarketAvailableForCountry("DE") {
    ///     // Show Germany-specific content
    /// }
    /// ```
    public func isMarketAvailableForCountry(_ countryCode: String) -> Bool {
        guard !availableMarkets.isEmpty else {
            // If markets list is empty, assume available (backward compatibility)
            return true
        }
        let upperCountryCode = countryCode.uppercased()
        return availableMarkets.contains { $0.code?.uppercased() == upperCountryCode }
    }
    
    /// Get market info for a specific country code
    /// Returns the full market information including currency, phone code, flag, etc.
    /// 
    /// **Usage:**
    /// ```swift
    /// if let marketInfo = VioConfiguration.shared.getMarketInfo(for: "DE") {
    ///     print("Currency: \(marketInfo.currency?.code ?? "EUR")")
    ///     print("Phone code: \(marketInfo.phoneCode ?? "+49")")
    /// }
    /// ```
    public func getMarketInfo(for countryCode: String) -> GetAvailableMarketsDto? {
        let upperCountryCode = countryCode.uppercased()
        return availableMarkets.first { $0.code?.uppercased() == upperCountryCode }
    }
    
    /// Check if SDK should be used (market is available)
    public var shouldUseSDK: Bool {
        return isConfigured && isMarketAvailable
    }
    
    /// Resolved commerce GraphQL URL: **solo** `GET /v1/sdk/config` (`commerce.endpoint` / `endpoints.commerceGraphQL`) cuando hay `commerce.apiKey` aplicada.
    /// Sin bootstrap de commerce, cadena vacía (no hay fallback a `campaigns.commerceGraphQLURL` ni a `environment.graphQLURL`).
    public var resolvedCommerceGraphQLURL: String {
        if let u = sdkBootstrapCommerceGraphQLURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !u.isEmpty,
           URL(string: u) != nil
        {
            return Self.normalizeCommerceGraphQLHTTPURL(u)
        }
        return ""
    }

    /// Resolved GraphQL `Authorization` para **commerce**: **solo** clave aplicada desde `GET /v1/sdk/config` (`commerce.apiKey`).
    /// Sin bootstrap de commerce, cadena vacía (no hay fallback a `campaigns.commerceApiKey` ni al `apiKey` raíz del SDK).
    public var resolvedCommerceApiKey: String {
        if let k = sdkBootstrapCommerceApiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !k.isEmpty {
            return k
        }
        return ""
    }
    
    /// Clears ``lastSdkConfig`` / ``lastSdkConfigRawData`` (e.g. before applying a new static configuration).
    internal func resetSdkRemoteConfigSnapshot() {
        lastSdkConfigRawData = nil
        lastSdkConfig = nil
    }

    /// Stores the latest `/v1/sdk/config` payload after HTTP 200. Replaces any previous snapshot.
    internal func storeSdkConfigSnapshotFromBootstrap(raw: Data, typed: SdkRemoteConfig?) {
        lastSdkConfigRawData = raw
        lastSdkConfig = typed
    }

    /// Apply commerce credentials from `GET /v1/sdk/config`. Pass `nil` fields to clear bootstrap overrides.
    internal func applySdkBootstrapCommerce(apiKey: String?, graphQLURL: String?) {
        let k = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let u = graphQLURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        sdkBootstrapCommerceApiKey = (k?.isEmpty == false) ? k : nil
        sdkBootstrapCommerceGraphQLURL = (u?.isEmpty == false) ? u : nil
    }

    /// `true` cuando la autorización GraphQL de **commerce** viene de `GET /v1/sdk/config` (clave dinámica del sponsor).
    /// No expone el secreto; úsalo en UI para saber si el catálogo puede usar la key remota antes de mostrar commerce.
    public var hasDynamicCommerceAuthorizationFromBootstrap: Bool {
        guard let k = sdkBootstrapCommerceApiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !k.isEmpty else {
            return false
        }
        return true
    }

    /// `GET /v1/sdk/config` often returns `commerce.endpoint` / `endpoints.commerceGraphQL` as host only (`https://graph-ql-dev.vio.live`).
    /// ``GraphQLHTTPClient`` POSTs to this URL; the service expects the `/graphql` path.
    private static func normalizeCommerceGraphQLHTTPURL(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: t), var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return raw
        }
        let path = comps.path
        if path.isEmpty || path == "/" {
            comps.path = "/graphql"
            return comps.string ?? "\(t.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/graphql"
        }
        if path.hasSuffix("/graphql") {
            return comps.string ?? raw
        }
        return raw
    }
    
    /// Update specific configurations after initial setup
    public static func updateTheme(_ theme: VioTheme) {
        shared.theme = theme
    }
    
    public static func updateCartConfiguration(_ config: CartConfiguration) {
        shared.cartConfiguration = config
    }
    
    // MARK: - Dynamic Configuration Methods
    
    /// Update dynamic brand configuration from backend
    public func updateDynamicBrandConfig(_ config: DynamicBrandConfig?) {
        self.dynamicBrandConfig = config
        
        // Merge with static config if dynamic config has values
        if let dynamic = config {
            var mergedBrand = self.brandConfiguration
            
            if let name = dynamic.name {
                mergedBrand = BrandConfiguration(
                    name: name,
                    iconAsset: dynamic.iconAsset ?? mergedBrand.iconAsset
                )
            } else if let iconAsset = dynamic.iconAsset {
                mergedBrand = BrandConfiguration(
                    name: mergedBrand.name,
                    iconAsset: iconAsset
                )
            }
            
            self.brandConfiguration = mergedBrand
        }
    }
    
    /// Update dynamic engagement configuration from backend
    public func updateDynamicEngagementConfig(_ config: DynamicEngagementConfig?) {
        self.dynamicEngagementConfig = config
        
        // Merge with static config if dynamic config has values
        if let dynamic = config {
            var mergedEngagement = self.engagementConfiguration
            
            if let demoMode = dynamic.demoMode {
                mergedEngagement = EngagementConfiguration(demoMode: demoMode)
            }
            
            self.engagementConfiguration = mergedEngagement
        }
    }
    
    /// Update dynamic localization configuration from backend
    public func updateDynamicLocalizationConfig(_ config: DynamicLocalizationConfig?) {
        self.dynamicLocalizationConfig = config
        
        // Merge translations with existing localization config
        if let dynamic = config {
            var translations = self.localizationConfiguration.translations
            
            // Merge dynamic translations
            for (key, value) in dynamic.translations {
                if translations[dynamic.language] == nil {
                    translations[dynamic.language] = [:]
                }
                translations[dynamic.language]?[key] = value
            }
            
            // Update localization configuration
            let updatedConfig = LocalizationConfiguration(
                defaultLanguage: self.localizationConfiguration.defaultLanguage,
                translations: translations,
                fallbackLanguage: self.localizationConfiguration.fallbackLanguage
            )
            
            self.localizationConfiguration = updatedConfig
            VioLocalization.shared.configure(updatedConfig)
        }
    }
    
    /// Get effective brand configuration (dynamic takes precedence over static)
    public var effectiveBrandConfiguration: BrandConfiguration {
        if let dynamic = dynamicBrandConfig {
            return BrandConfiguration(
                name: dynamic.name ?? brandConfiguration.name,
                iconAsset: dynamic.iconAsset ?? brandConfiguration.iconAsset
            )
        }
        return brandConfiguration
    }
    
    /// Get effective engagement configuration (dynamic takes precedence over static)
    public var effectiveEngagementConfiguration: EngagementConfiguration {
        if let dynamic = dynamicEngagementConfig {
            return EngagementConfiguration(
                demoMode: dynamic.demoMode ?? engagementConfiguration.demoMode
            )
        }
        return engagementConfiguration
    }
    
    // MARK: - Validation
    
    public var isValidConfiguration: Bool {
        return isConfigured && !apiKey.isEmpty
    }
    
    public func validateConfiguration() throws {
        guard isConfigured else {
            throw ConfigurationError.notConfigured
        }
        
        guard !apiKey.isEmpty else {
            throw ConfigurationError.missingAPIKey
        }
        
        // Additional validations can be added here
    }
}

// MARK: - Environment

public enum VioEnvironment: String, CaseIterable {
    /// Usa `campaigns.devRestAPIBaseURL` / `devWebSocketBaseURL` cuando están definidos (backend en Mac, Tailscale, etc.).
    case development = "development"
    /// Integración contra Vio **api-dev** (`restAPIBaseURL` / `webSocketBaseURL` HTTPS/WSS); no usa overrides `dev*`.
    case testing = "testing"
    case sandbox = "sandbox"
    case production = "production"
    
    public var baseURL: String {
        switch self {
        case .development, .testing, .sandbox:
            return "https://graph-ql-dev.vio.live"
        case .production:
            return "https://graph-ql-dev.vio.live"  // Same as development for now
        }
    }
    
    public var graphQLURL: String {
        return "\(baseURL)/graphql"
    }
}

// MARK: - Configuration Errors

public enum ConfigurationError: LocalizedError {
    case notConfigured
    case missingAPIKey
    case invalidEnvironment
    case invalidTheme
    case fileNotFound(fileName: String)
    case invalidJSON
    case invalidPlist
    
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Vio SDK is not configured. Call VioConfiguration.configure() first."
        case .missingAPIKey:
            return "API Key is required for Vio SDK configuration."
        case .invalidEnvironment:
            return "Invalid environment specified."
        case .invalidTheme:
            return "Invalid theme configuration."
        case .fileNotFound(let fileName):
            return "Configuration file '\(fileName)' not found in app bundle."
        case .invalidJSON:
            return "Invalid JSON configuration format."
        case .invalidPlist:
            return "Invalid Plist configuration format."
        }
    }
}
