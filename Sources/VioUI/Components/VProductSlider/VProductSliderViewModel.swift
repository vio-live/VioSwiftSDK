import Foundation
import VioCore
import SwiftUI

/// Internal ViewModel for VProductSlider
/// Handles automatic product loading from the API
@MainActor
class VProductSliderViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isMarketUnavailable: Bool = false  // True when market/404 error occurs
    
    // MARK: - Private Properties
    private var hasLoaded: Bool = false
    
    // MARK: - Public Methods
    
    /// Load products from the API
    /// - Parameters:
    ///   - categoryId: Optional category filter
    ///   - currency: Currency code (defaults to USD)
    ///   - country: Country code for shipping (defaults to US)
    ///   - forceRefresh: Force reload even if already loaded
    func loadProducts(
        categoryId: Int? = nil,
        currency: String = "USD",
        country: String = "US",
        forceRefresh: Bool = false
    ) async {
        // Check if SDK should be used before attempting operations
        guard VioConfiguration.shared.shouldUseSDK else {
            VioLogger.warning("Skipping product load - SDK disabled (market not available)", component: "VProductSlider")
            isMarketUnavailable = true
            isLoading = false
            return
        }
        
        // Skip if already loaded and not forcing refresh
        guard !hasLoaded || forceRefresh else { return }
        
        // Skip if already loading
        guard !isLoading else { return }
        
        if forceRefresh {
            products = []
            hasLoaded = false
        }

        isLoading = true
        errorMessage = nil
        isMarketUnavailable = false
        
        if let catId = categoryId {
            VioLogger.debug("Loading products for category: \(catId)", component: "VProductSlider")
        } else {
            VioLogger.debug("Loading all products from channel", component: "VProductSlider")
        }
        VioLogger.debug("Currency: \(currency), Country: \(country)", component: "VProductSlider")
        
        do {
            let loadedProducts: [Product]
            
            if let catId = categoryId {
                // Load products by category
                loadedProducts = try await ProductService.shared.loadProductsByCategory(
                    categoryId: catId,
                    currency: currency,
                    country: country
                )
            } else {
                // Load all products from channel
                loadedProducts = try await ProductService.shared.loadProducts(
                    productIds: nil,
                    currency: currency,
                    country: country
                )
            }
            
            products = loadedProducts
            hasLoaded = true
            
        } catch ProductServiceError.sdkError(let error) {
            // Only show error if it's not a NOT_FOUND error
            if error.code == "NOT_FOUND" || error.status == 404 {
                isMarketUnavailable = true
                errorMessage = nil
                VioLogger.warning("Market not available for \(currency)/\(country) - hiding component", component: "VProductSlider")
            } else {
                errorMessage = error.message
                VioLogger.error("Failed to load products: \(error.message)", component: "VProductSlider")
            }
        } catch ProductServiceError.invalidConfiguration(let message) {
            errorMessage = message
            VioLogger.error("Invalid configuration: \(message)", component: "VProductSlider")
        } catch ProductServiceError.networkError(let error) {
            errorMessage = error.localizedDescription
            VioLogger.error("Network error: \(error.localizedDescription)", component: "VProductSlider")
        } catch {
            errorMessage = error.localizedDescription
            VioLogger.error("Failed to load products: \(error.localizedDescription)", component: "VProductSlider")
        }
        
        isLoading = false
    }
    
    /// Reload products (force refresh)
    func reload(categoryId: Int? = nil, currency: String = "USD", country: String = "US") async {
        hasLoaded = false
        await loadProducts(categoryId: categoryId, currency: currency, country: country, forceRefresh: true)
    }
    
    /// Clear products (used when campaign becomes inactive)
    func clearProducts() {
        products = []
        hasLoaded = false
        isLoading = false
        errorMessage = nil
        isMarketUnavailable = false
    }
}
