import Foundation

public struct CurrencyMarketsDto: Codable, Equatable {
    public let code: String?
    public let name: String?
    public let symbol: String?
}

public struct GetAvailableGlobalMarketsDto: Codable, Equatable {
    public let code: String?
    public let name: String?
    public let official: String?
    public let flag: String?
    public let phoneCode: String?
    public let currency: CurrencyMarketsDto?

    enum CodingKeys: String, CodingKey {
        case code, name, official, flag, currency
        case phoneCode = "phone_code"
    }
}
