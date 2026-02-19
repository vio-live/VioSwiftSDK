import Foundation

public struct CheckoutTotalsDto: Codable, Equatable {
    public let currencyCode: String
    public let subtotal: Double
    public let total: Double
    public let taxes: Double
    public let shipping: Double
    public let discounts: Double?

    enum CodingKeys: String, CodingKey {
        case currencyCode = "currency_code"
        case subtotal
        case total
        case taxes
        case shipping
        case discounts
    }

    public init(
        currencyCode: String,
        subtotal: Double,
        total: Double,
        taxes: Double,
        shipping: Double,
        discounts: Double?
    ) {
        self.currencyCode = currencyCode
        self.subtotal = subtotal
        self.total = total
        self.taxes = taxes
        self.shipping = shipping
        self.discounts = discounts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.currencyCode = try c.decode(String.self, forKey: .currencyCode)
        self.subtotal = try c.decode(Double.self, forKey: .subtotal)
        self.total = try c.decode(Double.self, forKey: .total)
        self.taxes = try c.decode(Double.self, forKey: .taxes)
        self.shipping = try c.decode(Double.self, forKey: .shipping)
        self.discounts = try c.decodeIfPresent(Double.self, forKey: .discounts)
    }
}

public struct CreateCheckoutDto: Codable, Equatable {
    public let id: String
    public let status: String
    public let checkoutUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case checkoutUrl = "checkout_url"
    }
}

public struct UpdateCheckoutDto: Codable, Equatable {
    public let id: String
    public let status: String
    public let checkoutUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case checkoutUrl = "checkout_url"
    }
}

public struct GetCheckoutDto: Codable, Equatable {
    public let id: String
    public let status: String
    public let checkoutUrl: String?
    public let totals: CheckoutTotalsDto?

    enum CodingKeys: String, CodingKey {
        case id, status
        case checkoutUrl = "checkout_url"
        case totals
    }

    public init(
        id: String,
        status: String,
        checkoutUrl: String?,
        totals: CheckoutTotalsDto?
    ) {
        self.id = id
        self.status = status
        self.checkoutUrl = checkoutUrl
        self.totals = totals
    }
}

public struct RemoveCheckoutDto: Codable, Equatable {
    public let success: Bool
    public let message: String
}
