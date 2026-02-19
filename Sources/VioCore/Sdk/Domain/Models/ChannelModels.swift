import Foundation

public struct GetCategoryDto: Codable, Equatable {
    public let id: Int?
    public let name: String?
    public let fatherCategoryId: Int?
    public let categoryImage: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case fatherCategoryId = "father_category_id"
        case categoryImage = "category_image"
    }
}

public struct SettingsChannelDto: Codable, Equatable {
    public let stripePaymentLink: Bool
    public let stripePaymentIntent: Bool
    public let klarna: Bool
    public let markets: [String]
    public let purchaseConditions: Bool

    enum CodingKeys: String, CodingKey {
        case stripePaymentLink = "stripe_payment_link"
        case stripePaymentIntent = "stripe_payment_intent"
        case klarna, markets
        case purchaseConditions = "purchase_conditions"
    }
}

public struct GetChannelsDto: Codable, Equatable {
    public let channel: String
    public let name: String
    public let id: Int
    public let apiKey: String?
    public let settings: SettingsChannelDto

    enum CodingKeys: String, CodingKey {
        case channel, name, id, settings
        case apiKey = "api_key"
    }
}

public struct AttrContentElementTac: Codable, Equatable {
    public let level: Int?
}

public struct LinkMarkTac: Codable, Equatable {
    public let href: String?
    public let linktype: String?
    public let target: String?
}

public struct TextElementTac: Codable, Equatable {
    public let type: String?
    public let text: String?
    public let marks: [LinkMarkTac]?
}

public struct ContentElementTac: Codable, Equatable {
    public let type: String?
    public let attrs: AttrContentElementTac?
    public let content: [TextElementTac]?
}

public struct GetTermsAndConditionsDto: Codable, Equatable {
    public let headline: String?
    public let lead: String?
    public let updated: String?
    public let content: [ContentElementTac]?
}

public struct CurrencyDto: Codable, Equatable {
    public let code: String?
    public let name: String?
    public let symbol: String?
}

public struct GetAvailableMarketsDto: Codable, Equatable {
    public let code: String?
    public let name: String?
    public let official: String?
    public let flag: String?
    public let phoneCode: String?
    public let currency: CurrencyDto?

    enum CodingKeys: String, CodingKey {
        case code, name, official, flag, currency
        case phoneCode = "phone_code"
    }
}
