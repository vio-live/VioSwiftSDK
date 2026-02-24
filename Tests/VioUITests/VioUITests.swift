import XCTest
@testable import VioUI

final class VioUITests: XCTestCase {
    
    func testRProductCardVariants() throws {
        // Test that all variants are defined
        let gridVariant = VioProductCard.Variant.grid
        let listVariant = VioProductCard.Variant.list
        let heroVariant = VioProductCard.Variant.hero
        let minimalVariant = VioProductCard.Variant.minimal
        
        // These should not crash
        XCTAssertNotNil(gridVariant)
        XCTAssertNotNil(listVariant)
        XCTAssertNotNil(heroVariant)
        XCTAssertNotNil(minimalVariant)
    }
}
