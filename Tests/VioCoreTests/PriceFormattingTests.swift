// Tests for Price formatting — covers NOK/SEK/EUR/USD/GBP/DKK currencies,
// Elkjøp product prices, discount display, and edge cases for Viaplay SDK demo

import XCTest
@testable import VioCore

final class PriceFormattingTests: XCTestCase {

    // MARK: - Basic Display Format

    func testDisplayAmountFormatsCurrencyAndAmount() {
        let price = Price(amount: 99.99, currency_code: "USD")
        XCTAssertEqual(price.displayAmount, "USD 99.99")
    }

    func testDisplayAmountUsesAmountInclTaxesWhenAvailable() {
        let price = Price(amount: 100.0, currency_code: "NOK", amount_incl_taxes: 125.0)
        XCTAssertEqual(price.displayAmount, "NOK 125.00")
    }

    func testDisplayAmountFallsBackToAmountWhenNoTaxes() {
        let price = Price(amount: 759.0, currency_code: "NOK")
        XCTAssertEqual(price.displayAmount, "NOK 759.00")
    }

    // MARK: - NOK Currency (Elkjøp Products)

    func testElkjopHeadphonesPrice759NOK() {
        let price = Price(amount: 759.0, currency_code: "NOK")
        XCTAssertEqual(price.displayAmount, "NOK 759.00")
    }

    func testElkjopAccessoryPrice999NOK() {
        let price = Price(amount: 999.0, currency_code: "NOK")
        XCTAssertEqual(price.displayAmount, "NOK 999.00")
    }

    func testElkjopLaptopPrice6999NOK() {
        let price = Price(amount: 6999.0, currency_code: "NOK")
        XCTAssertEqual(price.displayAmount, "NOK 6999.00")
    }

    func testElkjopSamsungTVPrice17990NOK() {
        let price = Price(amount: 17990.0, currency_code: "NOK")
        XCTAssertEqual(price.displayAmount, "NOK 17990.00")
    }

    // MARK: - Zero Price

    func testZeroPriceDisplaysCorrectly() {
        let price = Price(amount: 0.0, currency_code: "NOK")
        XCTAssertEqual(price.displayAmount, "NOK 0.00")
    }

    // MARK: - Compare At / Discount

    func testDisplayCompareAtAmountWhenPresent() {
        let price = Price(amount: 6999.0, currency_code: "NOK", compare_at: 8999.0)
        XCTAssertEqual(price.displayCompareAtAmount, "NOK 8999.00")
    }

    func testDisplayCompareAtAmountIsNilWhenNoDiscount() {
        let price = Price(amount: 759.0, currency_code: "NOK")
        XCTAssertNil(price.displayCompareAtAmount)
    }

    func testDisplayCompareAtAmountUsesInclTaxesWhenAvailable() {
        let price = Price(
            amount: 6999.0,
            currency_code: "NOK",
            compare_at: 8999.0,
            compare_at_incl_taxes: 11248.75
        )
        XCTAssertEqual(price.displayCompareAtAmount, "NOK 11248.75")
    }

    func testDisplayCompareAtAmountFallsBackToCompareAt() {
        let price = Price(amount: 6999.0, currency_code: "NOK", compare_at: 8999.0)
        XCTAssertEqual(price.displayCompareAtAmount, "NOK 8999.00")
    }

    func testIsDiscountedWhenCompareAtIsHigher() {
        let price = Price(amount: 6999.0, currency_code: "NOK", compare_at: 8999.0)
        // compare_at present and higher than amount = discounted
        XCTAssertNotNil(price.compare_at)
        XCTAssertTrue(price.compare_at! > price.amount)
    }

    func testIsNotDiscountedWhenNoCompareAt() {
        let price = Price(amount: 999.0, currency_code: "NOK")
        XCTAssertNil(price.compare_at)
    }

    // MARK: - Multiple Currencies

    func testUSDCurrencyFormatting() {
        let price = Price(amount: 49.99, currency_code: "USD")
        XCTAssertEqual(price.displayAmount, "USD 49.99")
    }

    func testEURCurrencyFormatting() {
        let price = Price(amount: 39.99, currency_code: "EUR")
        XCTAssertEqual(price.displayAmount, "EUR 39.99")
    }

    func testGBPCurrencyFormatting() {
        let price = Price(amount: 34.99, currency_code: "GBP")
        XCTAssertEqual(price.displayAmount, "GBP 34.99")
    }

    func testSEKCurrencyFormatting() {
        let price = Price(amount: 899.0, currency_code: "SEK")
        XCTAssertEqual(price.displayAmount, "SEK 899.00")
    }

    func testDKKCurrencyFormatting() {
        let price = Price(amount: 699.0, currency_code: "DKK")
        XCTAssertEqual(price.displayAmount, "DKK 699.00")
    }

    // MARK: - Price Equatable

    func testPriceEquality() {
        let a = Price(amount: 999.0, currency_code: "NOK")
        let b = Price(amount: 999.0, currency_code: "NOK")
        XCTAssertEqual(a, b)
    }

    func testPriceInequalityDifferentAmount() {
        let a = Price(amount: 999.0, currency_code: "NOK")
        let b = Price(amount: 1099.0, currency_code: "NOK")
        XCTAssertNotEqual(a, b)
    }

    func testPriceInequalityDifferentCurrency() {
        let a = Price(amount: 999.0, currency_code: "NOK")
        let b = Price(amount: 999.0, currency_code: "SEK")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Tax Information

    func testPriceWithFullTaxInfo() {
        let price = Price(
            amount: 799.20,
            currency_code: "NOK",
            amount_incl_taxes: 999.0,
            tax_amount: 199.80,
            tax_rate: 25.0
        )
        XCTAssertEqual(price.tax_rate, 25.0)
        XCTAssertEqual(price.displayAmount, "NOK 999.00")
    }

    // MARK: - JSON Codable

    func testPriceRoundTripsJSON() throws {
        let original = Price(amount: 17990.0, currency_code: "NOK", compare_at: 19990.0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Price.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testPriceDecodesFromJSON() throws {
        let json = """
        {"amount": 6999.0, "currency_code": "NOK", "compare_at": 8999.0}
        """.data(using: .utf8)!

        let price = try JSONDecoder().decode(Price.self, from: json)
        XCTAssertEqual(price.amount, 6999.0)
        XCTAssertEqual(price.compare_at, 8999.0)
    }
}
