import Foundation

public enum Validation {
    private static let iso4217 = try! NSRegularExpression(pattern: "^[A-Z]{3}$")
    private static let iso3166a2 = try! NSRegularExpression(pattern: "^[A-Z]{2}$")

    public static func requireNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationException("Required field", details: ["field": field])
        }
    }

    public static func requireCurrency(_ currency: String) throws {
        let range = NSRange(location: 0, length: currency.utf16.count)
        if Validation.iso4217.firstMatch(in: currency, options: [], range: range) == nil {
            throw ValidationException(
                "currency must be ISO-4217 (3 uppercase letters)",
                details: ["field": "currency", "got": currency])
        }
    }

    public static func requireCountry(_ code: String) throws {
        let range = NSRange(location: 0, length: code.utf16.count)
        if Validation.iso3166a2.firstMatch(in: code, options: [], range: range) == nil {
            throw ValidationException(
                "countryCode must be ISO-3166-1 alpha-2 (2 letters)",
                details: ["field": "countryCode", "got": code])
        }
    }
}
