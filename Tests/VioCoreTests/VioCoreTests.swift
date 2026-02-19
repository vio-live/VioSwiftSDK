import XCTest
@testable import VioCore

final class VioCoreTests: XCTestCase {
    
    func testProductModel() throws {
        let price = Price(amount: 99.99, currency_code: "USD")
        let image = ProductImage(id: "img1", url: "https://example.com/image.jpg", order: 0)
        
        let product = Product(
            id: 1,
            title: "Test Product",
            sku: "TEST-001",
            price: price,
            images: [image],
            supplier: "Test Supplier"
        )
        
        XCTAssertEqual(product.id, 1)
        XCTAssertEqual(product.title, "Test Product")
        XCTAssertEqual(product.price.displayAmount, "USD 99.99")
        XCTAssertEqual(product.images.count, 1)
        XCTAssertEqual(product.images.first?.order, 0)
    }
    
    func testPriceFormatting() throws {
        let price = Price(
            amount: 123.45,
            currency_code: "EUR",
            compare_at: 150.00
        )
        
        XCTAssertEqual(price.displayAmount, "EUR 123.45")
        XCTAssertEqual(price.displayCompareAtAmount, "EUR 150.00")
    }
}
