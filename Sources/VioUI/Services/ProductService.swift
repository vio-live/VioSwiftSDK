import Foundation
import VioCore

/// Shared service for loading products across all components
/// Eliminates code duplication and provides consistent error handling
@MainActor
public class ProductService {
    
    // MARK: - Singleton
    public static let shared = ProductService()
    
    // MARK: - Private Properties
    private var cachedSdkClient: SdkClient?
    private let sdkClientQueue = DispatchQueue(label: "com.vio.productsdk")
    private var bootstrapObserver: NSObjectProtocol?
    
    private init() {
        bootstrapObserver = NotificationCenter.default.addObserver(
            forName: .vioCommerceBootstrapDidApply,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearCache()
                print("🎯 [ProductService] GraphQL cache cleared — vioCommerceBootstrapDidApply")
            }
        }
    }
    
    deinit {
        if let o = bootstrapObserver {
            NotificationCenter.default.removeObserver(o)
        }
    }
    
    // MARK: - SDK Client Management
    
    /// Get or create SDK client.
    /// Uses `VioConfiguration.resolvedCommerceApiKey` (SDK bootstrap → `apiKey`).
    /// Recreates the client if the resolved key or GraphQL URL changes.
    private func getSdkClient() throws -> SdkClient {
        let config = VioConfiguration.shared
        let graphQLURLString = config.resolvedCommerceGraphQLURL
        
        guard let baseURL = URL(string: graphQLURLString) else {
            throw ProductServiceError.invalidConfiguration("Invalid GraphQL URL: \(graphQLURLString)")
        }
        
        // Backend `GET /v1/sdk/config` → `sdkBootstrapCommerceApiKey`, then SDK `apiKey`
        let resolvedApiKey = config.resolvedCommerceApiKey
        
        // Invalidate cache if the key or URL has changed (e.g. bootstrap loaded after first call)
        if let cached = cachedSdkClient {
            let cachedKeyMatches = cached.apiKey == resolvedApiKey
            let cachedURLMatches = cached.baseUrl == baseURL
            if cachedKeyMatches && cachedURLMatches {
                return cached
            }
            let fromBootstrap = config.sdkBootstrapCommerceApiKey != nil
            VioLogger.debug("SDK client config changed — recreating (bootstrap commerce: \(fromBootstrap))", component: "ProductService")
            cachedSdkClient = nil
        }
        
        let client = SdkClient(baseUrl: baseURL, apiKey: resolvedApiKey)
        cachedSdkClient = client
        
        let commerceSource: String
        if config.sdkBootstrapCommerceApiKey != nil {
            commerceSource = "GET /v1/sdk/config (bootstrap)"
        } else if !config.campaignConfiguration.commerceApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commerceSource = "vio-config campaigns.commerceApiKey"
        } else {
            commerceSource = "sdk apiKey fallback (añade sponsor commerceApiKey en backend o campaigns.commerceApiKey en vio-config)"
        }
        print("🎯 [ProductService] GraphQL Authorization: \(commerceSource) authKey len=\(resolvedApiKey.count) (valor no logueado)")
        VioLogger.debug("Created SDK client (bootstrap commerce: \(config.sdkBootstrapCommerceApiKey != nil))", component: "ProductService")
        
        return client
    }
    
    /// Clear cached SDK client (useful for testing or reconfiguration)
    public func clearCache() {
        cachedSdkClient = nil
        VioLogger.debug("Cleared SDK client cache", component: "ProductService")
    }
    
    // MARK: - Product Loading
    
    /// Load a single product by ID
    /// - Parameters:
    ///   - productId: Product ID (as String, will be converted to Int)
    ///   - currency: Currency code (e.g., "USD", "EUR")
    ///   - country: Country code (e.g., "US", "DE")
    /// - Returns: Product if found, nil otherwise
    /// - Throws: ProductServiceError for various error conditions
    public func loadProduct(
        productId: String,
        currency: String,
        country: String
    ) async throws -> Product {
        guard let productIdInt = Int(productId) else {
            throw ProductServiceError.invalidProductId(productId)
        }
        
        return try await loadProduct(productId: productIdInt, currency: currency, country: country)
    }
    
    /// Load a single product by ID
    /// - Parameters:
    ///   - productId: Product ID (as Int)
    ///   - currency: Currency code (e.g., "USD", "EUR")
    ///   - country: Country code (e.g., "US", "DE")
    /// - Returns: Product if found
    /// - Throws: ProductServiceError for various error conditions
    public func loadProduct(
        productId: Int,
        currency: String,
        country: String
    ) async throws -> Product {
        VioLogger.debug("Loading product with ID: \(productId)", component: "ProductService")
        VioLogger.debug("Currency: \(currency), Country: \(country)", component: "ProductService")
        
        let sdk = try getSdkClient()
        let gqlURL = VioConfiguration.shared.resolvedCommerceGraphQLURL
        let keySrc = VioConfiguration.shared.sdkBootstrapCommerceApiKey != nil ? "bootstrap" : "fallback"
        print("🎯 [ProductService] loadProduct → GraphQL GET product id=\(productId) url=\(gqlURL) auth=\(keySrc) cc=\(country) cur=\(currency)")

        let dtoProducts = try await sdk.channel.product.get(
            currency: currency,
            imageSize: "medium",
            barcodeList: nil as [String]?,
            categoryIds: nil as [Int]?,
            productIds: [productId],
            skuList: nil as [String]?,
            useCache: true,
            shippingCountryCode: country
        )
        
        guard let dtoProduct = dtoProducts.first else {
            VioLogger.warning("Product not found for ID: \(productId)", component: "ProductService")
            print("🎯 [ProductService] loadProduct ← GraphQL OK pero 0 filas para id=\(productId)")
            throw ProductServiceError.productNotFound(productId)
        }
        
        let product = dtoProduct.toDomainProduct()
        print("🎯 [ProductService] loadProduct ← OK id=\(product.id) title=\(product.title) sku=\(product.sku) (commerce conectado)")
        return product
    }
    
    /// Load multiple products by IDs
    /// - Parameters:
    ///   - productIds: Array of product IDs. If empty or nil, loads all products from channel
    ///   - currency: Currency code (e.g., "USD", "EUR")
    ///   - country: Country code (e.g., "US", "DE")
    /// - Returns: Array of products found
    /// - Throws: ProductServiceError for various error conditions
    public func loadProducts(
        productIds: [Int]?,
        currency: String,
        country: String
    ) async throws -> [Product] {
        let idsToUse = productIds
        
        if let ids = idsToUse, !ids.isEmpty {
            VioLogger.debug("Loading products with IDs: \(ids)", component: "ProductService")
        } else {
            VioLogger.debug("No product IDs provided - loading all products from channel", component: "ProductService")
        }
        
        VioLogger.debug("Currency: \(currency), Country: \(country)", component: "ProductService")
        
        let sdk = try getSdkClient()
        
        let dtoProducts = try await sdk.channel.product.get(
            currency: currency,
            imageSize: "medium",
            barcodeList: nil as [String]?,
            categoryIds: nil as [Int]?,
            productIds: idsToUse,
            skuList: nil as [String]?,
            useCache: true,
            shippingCountryCode: country
        )
        
        if let ids = idsToUse, !ids.isEmpty, dtoProducts.count < ids.count {
            let foundIds = Set(dtoProducts.map { $0.id })
            let requestedIds = Set(ids)
            let missingIds = requestedIds.subtracting(foundIds)
            VioLogger.warning(
                "Only found \(dtoProducts.count) out of \(ids.count) products. Missing IDs: \(missingIds.sorted())",
                component: "ProductService"
            )
        }
        
        let products = dtoProducts.map { $0.toDomainProduct() }
        return products
    }
    
    /// Load products by category ID
    /// - Parameters:
    ///   - categoryId: Category ID to filter products
    ///   - currency: Currency code (e.g., "USD", "EUR")
    ///   - country: Country code (e.g., "US", "DE")
    /// - Returns: Array of products found in the category
    /// - Throws: ProductServiceError for various error conditions
    public func loadProductsByCategory(
        categoryId: Int,
        currency: String,
        country: String
    ) async throws -> [Product] {
        VioLogger.debug("Loading products for category ID: \(categoryId)", component: "ProductService")
        VioLogger.debug("Currency: \(currency), Country: \(country)", component: "ProductService")
        
        let sdk = try getSdkClient()
        
        let dtoProducts = try await sdk.channel.product.get(
            currency: currency,
            imageSize: "medium",
            barcodeList: nil as [String]?,
            categoryIds: [categoryId],
            productIds: nil as [Int]?,
            skuList: nil as [String]?,
            useCache: true,
            shippingCountryCode: country
        )
        
        let products = dtoProducts.map { $0.toDomainProduct() }
        return products
    }
}

// MARK: - ProductServiceError

public enum ProductServiceError: LocalizedError {
    case invalidConfiguration(String)
    case invalidProductId(String)
    case productNotFound(Int)
    case sdkError(SdkException)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .invalidProductId(let id):
            return "Invalid product ID format: \(id)"
        case .productNotFound(let id):
            return "Product not found: \(id)"
        case .sdkError(let error):
            return error.message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

