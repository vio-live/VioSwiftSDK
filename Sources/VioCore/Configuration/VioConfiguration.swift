import Foundation
import SwiftUI

/// Vio SDK Global Configuration
///
/// Centralized configuration system that allows developers to set up the entire SDK
/// once and use it across all modules (Core, UI, LiveShow, etc.) without additional setup.
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
    @Published public private(set) var liveShowConfiguration: LiveShowConfiguration = .default
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
        liveShowConfig: LiveShowConfiguration? = nil,
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
        
        instance.apiKey = apiKey
        instance.environment = environment
        instance.theme = theme ?? .default
        instance.cartConfiguration = cartConfig ?? .default
        instance.networkConfiguration = networkConfig ?? .default
        instance.uiConfiguration = uiConfig ?? .default
        instance.liveShowConfiguration = liveShowConfig ?? .default
        instance.marketConfiguration = marketConfig ?? .default
        instance.productDetailConfiguration = productDetailConfig ?? .default
        instance.localizationConfiguration = localizationConfig ?? .default
        instance.campaignConfiguration = campaignConfig ?? .default
        instance.analyticsConfiguration = analyticsConfig ?? .default
        instance.demoDataConfiguration = demoDataConfig ?? ConfigurationLoader.loadDemoDataConfiguration()
        // Brand: demo data overrides reachu-config for consistency (single source per demo)
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
    }
    
    /// Quick configuration with just API key (uses defaults for everything else)
    public static func configure(apiKey: String) {
        configure(
            apiKey: apiKey,
            environment: .production,
            theme: nil,
            cartConfig: nil,
            networkConfig: nil,
            uiConfig: nil,
            liveShowConfig: nil
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
    case development = "development"
    case sandbox = "sandbox"
    case production = "production"
    
    public var baseURL: String {
        switch self {
        case .development:
            return "https://graph-ql-dev.reachu.io"
        case .sandbox:
            return "https://graph-ql-dev.reachu.io"  // Sandbox uses same endpoint as development
        case .production:
            return "https://graph-ql-dev.reachu.io"  // Same as development for now
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
