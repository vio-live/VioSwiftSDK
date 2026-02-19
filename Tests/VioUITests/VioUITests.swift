import XCTest
@testable import VioUI

final class VioUITests: XCTestCase {
    
    func testRProductCardVariants() throws {
        // Test that all variants are defined
        let gridVariant = VProductCard.Variant.grid
        let listVariant = VProductCard.Variant.list
        let heroVariant = VProductCard.Variant.hero
        let minimalVariant = VProductCard.Variant.minimal
        
        // These should not crash
        XCTAssertNotNil(gridVariant)
        XCTAssertNotNil(listVariant)
        XCTAssertNotNil(heroVariant)
        XCTAssertNotNil(minimalVariant)
    }
}
