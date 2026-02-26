import XCTest
@testable import VioCore
@testable import VioUI

@MainActor
final class ComponentTests: XCTestCase {
    
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
    }
    
    // MARK: - VProductBanner Tests
    
    func testVProductBannerInitialization() {
        let banner = VProductBanner()
        XCTAssertNotNil(banner)
    }
    
    func testVProductBannerWithComponentId() {
        let banner = VProductBanner(componentId: "test-banner")
        XCTAssertNotNil(banner)
    }
    
    // MARK: - VProductCarousel Tests
    
    func testVProductCarouselInitialization() {
        let carousel = VProductCarousel()
        XCTAssertNotNil(carousel)
    }
    
    func testVProductCarouselWithLayout() {
        let carouselFull = VProductCarousel(layout: "full")
        XCTAssertNotNil(carouselFull)
        
        let carouselCompact = VProductCarousel(layout: "compact")
        XCTAssertNotNil(carouselCompact)
        
        let carouselHorizontal = VProductCarousel(layout: "horizontal")
        XCTAssertNotNil(carouselHorizontal)
    }
    
    func testVProductCarouselWithComponentId() {
        let carousel = VProductCarousel(componentId: "test-carousel")
        XCTAssertNotNil(carousel)
    }
    
    // MARK: - VProductStore Tests
    
    func testVProductStoreInitialization() {
        let store = VProductStore()
        XCTAssertNotNil(store)
    }
    
    func testVProductStoreWithMode() {
        let storeAll = VProductStore(mode: "all")
        XCTAssertNotNil(storeAll)
        
        let storeFiltered = VProductStore(mode: "filtered")
        XCTAssertNotNil(storeFiltered)
    }
    
    func testVProductStoreWithComponentId() {
        let store = VProductStore(componentId: "test-store")
        XCTAssertNotNil(store)
    }
    
    // MARK: - VProductSpotlight Tests
    
    func testVProductSpotlightInitialization() {
        let spotlight = VProductSpotlight()
        XCTAssertNotNil(spotlight)
    }
    
    func testVProductSpotlightWithVariant() {
        let spotlightHero = VProductSpotlight(variant: .hero)
        XCTAssertNotNil(spotlightHero)
        
        let spotlightGrid = VProductSpotlight(variant: .grid)
        XCTAssertNotNil(spotlightGrid)
        
        let spotlightList = VProductSpotlight(variant: .list)
        XCTAssertNotNil(spotlightList)
        
        let spotlightMinimal = VProductSpotlight(variant: .minimal)
        XCTAssertNotNil(spotlightMinimal)
    }
    
    func testVProductSpotlightWithComponentId() {
        let spotlight = VProductSpotlight(componentId: "test-spotlight")
        XCTAssertNotNil(spotlight)
    }
    
    func testVProductSpotlightWithShowAddToCartButton() {
        let spotlightWithButton = VProductSpotlight(showAddToCartButton: true)
        XCTAssertNotNil(spotlightWithButton)
        
        let spotlightWithoutButton = VProductSpotlight(showAddToCartButton: false)
        XCTAssertNotNil(spotlightWithoutButton)
    }
    
    // MARK: - VProductSlider Tests
    
    func testVProductSliderInitialization() {
        let slider = VProductSlider(
            title: "Test Products",
            products: []
        )
        XCTAssertNotNil(slider)
    }
    
    func testVProductSliderWithCategory() {
        let slider = VProductSlider(
            title: "Category Products",
            categoryId: 123
        )
        XCTAssertNotNil(slider)
    }
    
    func testVProductSliderLayouts() {
        let compact = VProductSlider.compact(title: "Compact")
        XCTAssertNotNil(compact)
        
        let cards = VProductSlider.cards(title: "Cards")
        XCTAssertNotNil(cards)
        
        let featured = VProductSlider.featured(title: "Featured")
        XCTAssertNotNil(featured)
        
        let detailed = VProductSlider.detailed(title: "Detailed")
        XCTAssertNotNil(detailed)
        
        let showcase = VProductSlider.showcase(title: "Showcase")
        XCTAssertNotNil(showcase)
        
        let micro = VProductSlider.micro(title: "Micro")
        XCTAssertNotNil(micro)
    }
}

// MARK: - ViewModel Tests

@MainActor
final class ViewModelTests: XCTestCase {
    
    func testVProductCarouselViewModelInitialState() {
        let viewModel = VProductCarouselViewModel()
        XCTAssertEqual(viewModel.products.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isMarketUnavailable)
        XCTAssertEqual(viewModel.currentIndex, 0)
    }
    
    func testVProductStoreViewModelInitialState() {
        let viewModel = VProductStoreViewModel()
        XCTAssertEqual(viewModel.products.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isMarketUnavailable)
    }
    
    func testVProductSpotlightViewModelInitialState() {
        let viewModel = VProductSpotlightViewModel()
        XCTAssertNil(viewModel.product)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isMarketUnavailable)
    }
}

// MARK: - Error Handling Tests

@MainActor
final class ErrorHandlingTests: XCTestCase {
    
    func testProductServiceErrorDescriptions() {
        let invalidConfig = ProductServiceError.invalidConfiguration("Test message")
        XCTAssertNotNil(invalidConfig.errorDescription)
        XCTAssertTrue(invalidConfig.errorDescription?.contains("Invalid configuration") ?? false)
        
        let invalidId = ProductServiceError.invalidProductId("invalid")
        XCTAssertNotNil(invalidId.errorDescription)
        XCTAssertTrue(invalidId.errorDescription?.contains("Invalid product ID") ?? false)
        
        let notFound = ProductServiceError.productNotFound(123)
        XCTAssertNotNil(notFound.errorDescription)
        XCTAssertTrue(notFound.errorDescription?.contains("Product not found") ?? false)
    }
}

