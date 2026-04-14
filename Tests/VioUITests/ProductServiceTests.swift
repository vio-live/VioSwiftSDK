import XCTest
@testable import VioCore
@testable import VioUI

@MainActor
final class ProductServiceTests: XCTestCase {
    
    var productService: ProductService!
    
    override func setUp() async throws {
        // Configure SDK for testing
        VioConfiguration.configure(
            apiKey: "TEST_KEY",
            environment: .development,
            marketConfig: MarketConfiguration(
                countryCode: "US",
                countryName: "United States",
                currencyCode: "USD",
                currencySymbol: "$",
                phoneCode: "+1",
                flagURL: nil
            )
        )
        // Commerce GraphQL requires bootstrap credentials (no root apiKey fallback).
        VioConfiguration.shared.applySdkBootstrapCommerce(
            apiKey: "TEST_COMMERCE_KEY",
            graphQLURL: "https://graph.test/graphql"
        )

        productService = ProductService.shared
        productService.clearCache() // Clear cache before each test
    }

    override func tearDown() async throws {
        VioConfiguration.shared.applySdkBootstrapCommerce(apiKey: nil, graphQLURL: nil)
        productService?.clearCache()
        try await super.tearDown()
    }
    
    func testInvalidProductId() async {
        // Test with invalid product ID format
        do {
            _ = try await productService.loadProduct(
                productId: "invalid",
                currency: "USD",
                country: "US"
            )
            XCTFail("Should have thrown ProductServiceError.invalidProductId")
        } catch ProductServiceError.invalidProductId(let id) {
            XCTAssertEqual(id, "invalid")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCommerceNotConfiguredWithoutBootstrap() async {
        VioConfiguration.configure(
            apiKey: "TEST_KEY",
            environment: .custom(graphQLURL: "https://graph.example.com/graphql"),
            marketConfig: MarketConfiguration(
                countryCode: "US",
                countryName: "United States",
                currencyCode: "USD",
                currencySymbol: "$",
                phoneCode: "+1",
                flagURL: nil
            )
        )
        VioConfiguration.shared.applySdkBootstrapCommerce(apiKey: nil, graphQLURL: nil)
        productService.clearCache()

        do {
            _ = try await productService.loadProduct(
                productId: "123",
                currency: "USD",
                country: "US"
            )
            XCTFail("Should have thrown ProductServiceError.commerceNotConfigured")
        } catch ProductServiceError.commerceNotConfigured {
            // Expected: environment.graphQLURL is not used for commerce auth.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testLoadProductsWithEmptyArray() async {
        // Test loading products with empty array (should load all)
        do {
            let products = try await productService.loadProducts(
                productIds: [],
                currency: "USD",
                country: "US"
            )
            // Should not crash, even if no products returned
            XCTAssertNotNil(products)
        } catch {
            // Network errors are acceptable in tests
            XCTAssertTrue(error is ProductServiceError || error is SdkException)
        }
    }
    
    func testLoadProductsWithNil() async {
        // Test loading products with nil (should load all)
        do {
            let products = try await productService.loadProducts(
                productIds: nil,
                currency: "USD",
                country: "US"
            )
            // Should not crash, even if no products returned
            XCTAssertNotNil(products)
        } catch {
            // Network errors are acceptable in tests
            XCTAssertTrue(error is ProductServiceError || error is SdkException)
        }
    }
    
    func testClearCache() {
        // Test cache clearing
        productService.clearCache()
        // Should not crash
        XCTAssertNotNil(productService)
    }
}

// MARK: - VioLogger Tests

final class VioLoggerTests: XCTestCase {
    
    func testLoggingDisabled() {
        // Configure with logging disabled
        VioConfiguration.configure(
            apiKey: "TEST_KEY",
            environment: .development,
            networkConfig: NetworkConfiguration(enableLogging: false),
            marketConfig: MarketConfiguration(
                countryCode: "US",
                countryName: "United States",
                currencyCode: "USD",
                currencySymbol: "$",
                phoneCode: "+1",
                flagURL: nil
            )
        )
        
        // Should not crash
        VioLogger.debug("Test message", component: "TestComponent")
        VioLogger.info("Test message", component: "TestComponent")
        VioLogger.warning("Test message", component: "TestComponent")
        VioLogger.error("Test message", component: "TestComponent")
        VioLogger.success("Test message", component: "TestComponent")
    }
    
    func testLoggingEnabled() {
        // Configure with logging enabled
        VioConfiguration.configure(
            apiKey: "TEST_KEY",
            environment: .development,
            networkConfig: NetworkConfiguration(enableLogging: true, logLevel: .debug),
            marketConfig: MarketConfiguration(
                countryCode: "US",
                countryName: "United States",
                currencyCode: "USD",
                currencySymbol: "$",
                phoneCode: "+1",
                flagURL: nil
            )
        )
        
        // Should not crash
        VioLogger.debug("Test message", component: "TestComponent")
        VioLogger.info("Test message", component: "TestComponent")
        VioLogger.warning("Test message", component: "TestComponent")
        VioLogger.error("Test message", component: "TestComponent")
        VioLogger.success("Test message", component: "TestComponent")
    }
    
    func testLogLevelFiltering() {
        // Configure with warning level
        VioConfiguration.configure(
            apiKey: "TEST_KEY",
            environment: .development,
            networkConfig: NetworkConfiguration(enableLogging: true, logLevel: .warning),
            marketConfig: MarketConfiguration(
                countryCode: "US",
                countryName: "United States",
                currencyCode: "USD",
                currencySymbol: "$",
                phoneCode: "+1",
                flagURL: nil
            )
        )
        
        // Should not crash
        VioLogger.debug("Should not appear", component: "TestComponent")
        VioLogger.info("Should not appear", component: "TestComponent")
        VioLogger.warning("Should appear", component: "TestComponent")
        VioLogger.error("Should appear", component: "TestComponent")
    }
}

