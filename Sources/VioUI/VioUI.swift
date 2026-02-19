import SwiftUI
import VioCore

/// Vio UI Components
/// 
/// Optional target for pre-built SwiftUI components
/// Import this target to get ready-to-use UI components for Vio functionality

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct VioUI {
    
    /// Configure VioUI with default settings
    /// This ensures localization is set up even if no configuration file is provided
    public static func configure() {
        // Ensure localization is initialized with defaults if not already configured
        if !VioConfiguration.shared.isConfigured {
            // If SDK hasn't been configured, set up minimal defaults
            VioConfiguration.configure(
                apiKey: "",
                environment: .sandbox
            )
        }
        
        // Ensure localization system is initialized with default English translations
        let currentConfig = VioConfiguration.shared.localizationConfiguration
        if currentConfig.translations.isEmpty {
            // Use default English translations
            VioLocalization.shared.configure(.default)
        } else {
            // Already configured, just ensure it's set
            VioLocalization.shared.configure(currentConfig)
        }
    }
}

// MARK: - Public Exports

// Export cart management
public typealias VioCartManager = CartManager

// Export UI components
public typealias VioProductCard = VProductCard
public typealias VioProductSlider = VProductSlider
public typealias VioCheckoutOverlay = VCheckoutOverlay
public typealias VioProductDetailOverlay = VProductDetailOverlay

// Export auto-configured campaign components
public typealias VioProductCarousel = VProductCarousel
public typealias VioProductBanner = VProductBanner
public typealias VioProductStore = VProductStore

// Export UX enhancement components
public typealias VioFloatingCartIndicator = VFloatingCartIndicator

// Export offer banner components
public typealias VioOfferBanner = VOfferBanner
public typealias VioOfferBannerContainer = VOfferBannerContainer
