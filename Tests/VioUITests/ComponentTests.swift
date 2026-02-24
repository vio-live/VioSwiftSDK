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
    
    // MARK: - VioProductBanner Tests
    
    func testRProductBannerInitialization() {
        let banner = VioProductBanner()
        XCTAssertNotNil(banner)
    }
    
    func testRProductBannerWithComponentId() {
        let banner = VioProductBanner(componentId: "test-banner")
        XCTAssertNotNil(banner)
    }
    
    // MARK: - VioProductCarousel Tests
    
    func testRProductCarouselInitialization() {
        let carousel = VioProductCarousel()
        XCTAssertNotNil(carousel)
    }
    
    func testRProductCarouselWithLayout() {
        let carouselFull = VioProductCarousel(layout: "full")
        XCTAssertNotNil(carouselFull)
        
        let carouselCompact = VioProductCarousel(layout: "compact")
        XCTAssertNotNil(carouselCompact)
        
        let carouselHorizontal = VioProductCarousel(layout: "horizontal")
        XCTAssertNotNil(carouselHorizontal)
    }
    
    func testRProductCarouselWithComponentId() {
        let carousel = VioProductCarousel(componentId: "test-carousel")
        XCTAssertNotNil(carousel)
    }
    
    // MARK: - VioProductStore Tests
    
    func testRProductStoreInitialization() {
        let store = VioProductStore()
        XCTAssertNotNil(store)
    }
    
    func testRProductStoreWithMode() {
        let storeAll = VioProductStore(mode: "all")
        XCTAssertNotNil(storeAll)
        
        let storeFiltered = VioProductStore(mode: "filtered")
        XCTAssertNotNil(storeFiltered)
    }
    
    func testRProductStoreWithComponentId() {
        let store = VioProductStore(componentId: "test-store")
        XCTAssertNotNil(store)
    }
    
    // MARK: - VProductSpotlight Tests
    
    func testRProductSpotlightInitialization() {
        let spotlight = VProductSpotlight()
        XCTAssertNotNil(spotlight)
    }
    
    func testRProductSpotlightWithVariant() {
        let spotlightHero = VProductSpotlight(variant: .hero)
        XCTAssertNotNil(spotlightHero)
        
        let spotlightGrid = VProductSpotlight(variant: .grid)
        XCTAssertNotNil(spotlightGrid)
        
        let spotlightList = VProductSpotlight(variant: .list)
        XCTAssertNotNil(spotlightList)
        
        let spotlightMinimal = VProductSpotlight(variant: .minimal)
        XCTAssertNotNil(spotlightMinimal)
    }
    
    func testRProductSpotlightWithComponentId() {
        let spotlight = VProductSpotlight(componentId: "test-spotlight")
        XCTAssertNotNil(spotlight)
    }
    
    func testRProductSpotlightWithShowAddToCartButton() {
        let spotlightWithButton = VProductSpotlight(showAddToCartButton: true)
        XCTAssertNotNil(spotlightWithButton)
        
        let spotlightWithoutButton = VProductSpotlight(showAddToCartButton: false)
        XCTAssertNotNil(spotlightWithoutButton)
    }
    
    // MARK: - VProductSlider Tests
    
    func testRProductSliderInitialization() {
        let slider = VProductSlider(
            title: "Test Products",
            products: []
        )
        XCTAssertNotNil(slider)
    }
    
    func testRProductSliderWithCategory() {
        let slider = VProductSlider(
            title: "Category Products",
            categoryId: 123
        )
        XCTAssertNotNil(slider)
    }
    
    func testRProductSliderLayouts() {
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
    
    func testRProductCarouselViewModelInitialState() {
        let viewModel = VioProductCarouselViewModel()
        XCTAssertEqual(viewModel.products.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isMarketUnavailable)
        XCTAssertEqual(viewModel.currentIndex, 0)
    }
    
    func testRProductStoreViewModelInitialState() {
        let viewModel = VioProductStoreViewModel()
        XCTAssertEqual(viewModel.products.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isMarketUnavailable)
    }
    
    func testRProductSpotlightViewModelInitialState() {
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

