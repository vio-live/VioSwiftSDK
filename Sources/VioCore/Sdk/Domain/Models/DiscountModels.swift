import Foundation

private enum Lossy {
    static func int(_ dict: [String: Any], _ key: String) -> Int? {
        if let v = dict[key] as? Int { return v }
        if let d = dict[key] as? Double { return Int(d) }
        if let s = dict[key] as? String { return Int(s) }
        return nil
    }
}

public struct DiscountMetadataDto: Codable, Equatable {
    public let apiKey: String?
}

public struct GetDiscountsDto: Codable, Equatable {
    public let id: Int
    public let code: String?
    public let percentage: Int?
    public let discountMetadata: DiscountMetadataDto?

    enum CodingKeys: String, CodingKey {
        case id, code, percentage
        case discountMetadata = "discount_metadata"
    }
}

public struct GetDiscountByIdDto: Codable, Equatable {
    public let id: Int
    public let code: String?
    public let percentage: Int?
}

public struct GetDiscountTypeDto: Codable, Equatable {
    public let id: Int
    public let type: String
}

public struct AddDiscountDto: Codable, Equatable {
    public let id: Int
    public let code: String?
    public let percentage: Int?
    public let startDate: String?
    public let endDate: String?

    enum CodingKeys: String, CodingKey {
        case id, code, percentage
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

public struct ApplyDiscountDto: Codable, Equatable {
    public let executed: Bool
    public let message: String
}

public struct DeleteAppliedDiscountDto: Codable, Equatable {
    public let executed: Bool
    public let message: String
}

public struct DeleteDiscountDto: Codable, Equatable {
    public let executed: Bool
    public let message: String
}

public struct UpdateDiscountDto: Codable, Equatable {
    public let id: Int
    public let code: String?
    public let percentage: Int?
    public let startDate: String?
    public let endDate: String?

    enum CodingKeys: String, CodingKey {
        case id, code, percentage
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

public struct VerifyDiscountDto: Codable, Equatable {
    public let valid: Bool
    public let message: String
    public let discount: GetDiscountByIdDto?
}
