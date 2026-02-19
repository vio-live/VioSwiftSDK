import Foundation

public final class DiscountRepositoryGQL: DiscountRepository {
    private let client: GraphQLHTTPClient
    private let apiKey: String
    private let baseUrl: String

    public init(client: GraphQLHTTPClient, apiKey: String, baseUrl: String = "") {
        self.client = client
        self.apiKey = apiKey
        self.baseUrl = baseUrl
    }

    public func get() async throws -> [GetDiscountsDto] {
        let res = try await client.runQuerySafe(
            query: DiscountGraphQL.GET_DISCOUNT_QUERY,
            variables: [:]
        )
        guard let list: [Any] = GraphQLPick.pickPath(res.data, path: ["Discounts", "GetDiscounts"])
        else {
            throw SdkException("Empty response in Discount.get", code: "EMPTY_RESPONSE")
        }
        let data = try JSONSerialization.data(withJSONObject: list, options: [])
        return try JSONDecoder().decode([GetDiscountsDto].self, from: data)
    }

    public func getByChannel() async throws -> [GetDiscountsDto] {
        try Validation.requireNonEmpty(apiKey, field: "apiKey")
        let all = try await get()
        return all.filter { $0.discountMetadata?.apiKey == apiKey }
    }

    public func getById(discountId: Int) async throws -> GetDiscountByIdDto {
        guard discountId > 0 else {
            throw ValidationException("discountId must be > 0", details: ["field": "discountId"])
        }
        let res = try await client.runQuerySafe(
            query: DiscountGraphQL.GET_DISCOUNT_BY_ID_QUERY,
            variables: ["discountId": discountId]
        )
        guard
            let obj: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Discounts", "GetDiscountsById"])
        else {
            throw SdkException("Empty response in Discount.getById", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(obj, as: GetDiscountByIdDto.self)
    }

    public func getType(id: Int?, type: String?) async throws -> [GetDiscountTypeDto] {
        if id == nil
            && (type == nil || type!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        {
            throw ValidationException(
                "Provide at least one of: id or type", details: ["fields": ["id", "type"]])
        }
        if let i = id, i <= 0 {
            throw ValidationException("id must be > 0", details: ["field": "id"])
        }
        if let t = type, t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationException("type cannot be empty", details: ["field": "type"])
        }

        let res = try await client.runQuerySafe(
            query: DiscountGraphQL.GET_DISCOUNT_TYPE_QUERY,
            variables: ["getDiscountTypeId": id as Any?, "type": type as Any?].compactMapValues {
                $0
            }
        )
        guard
            let list: [Any] = GraphQLPick.pickPath(
                res.data, path: ["Discounts", "GetDiscountType"])
        else {
            throw SdkException("Empty response in Discount.getType", code: "EMPTY_RESPONSE")
        }
        let data = try JSONSerialization.data(withJSONObject: list, options: [])
        return try JSONDecoder().decode([GetDiscountTypeDto].self, from: data)
    }

    public func add(code: String, percentage: Int, startDate: String, endDate: String, typeId: Int)
        async throws -> AddDiscountDto
    {
        try Validation.requireNonEmpty(code, field: "code")
        if !(1...100).contains(percentage) {
            throw ValidationException(
                "percentage must be between 1 and 100", details: ["field": "percentage"])
        }
        try Validation.requireNonEmpty(startDate, field: "startDate")
        try Validation.requireNonEmpty(endDate, field: "endDate")
        let iso = ISO8601DateFormatter()
        guard let s = iso.date(from: startDate) else {
            throw ValidationException("startDate must be ISO-8601", details: ["field": "startDate"])
        }
        guard let e = iso.date(from: endDate) else {
            throw ValidationException("endDate must be ISO-8601", details: ["field": "endDate"])
        }
        if !e.timeIntervalSince1970.isFinite || !(e > s) {
            throw ValidationException(
                "endDate must be after startDate", details: ["fields": ["startDate", "endDate"]])
        }
        guard typeId > 0 else {
            throw ValidationException("typeId must be > 0", details: ["field": "typeId"])
        }

        let vars: [String: Any] = [
            "code": code,
            "percentage": percentage,
            "startDate": startDate,
            "endDate": endDate,
            "typeId": typeId,
        ]
        let res = try await client.runMutationSafe(
            query: DiscountGraphQL.ADD_DISCOUNT_MUTATION,
            variables: vars
        )
        guard
            let obj: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Discounts", "AddDiscount"])
        else {
            throw SdkException("Empty response in Discount.add", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(obj, as: AddDiscountDto.self)
    }

    public func apply(code: String, cartId: String) async throws -> ApplyDiscountDto {
        try Validation.requireNonEmpty(code, field: "code")
        try Validation.requireNonEmpty(cartId, field: "cartId")

        let res = try await client.runMutationSafe(
            query: DiscountGraphQL.APPLY_DISCOUNT_MUTATION,
            variables: ["code": code, "cartId": cartId]
        )
        guard
            let obj: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Discounts", "ApplyDiscount"])
        else {
            throw SdkException("Empty response in Discount.apply", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(obj, as: ApplyDiscountDto.self)
    }

    public func deleteApplied(code: String, cartId: String) async throws -> DeleteAppliedDiscountDto
    {
        try Validation.requireNonEmpty(code, field: "code")
        try Validation.requireNonEmpty(cartId, field: "cartId")

        let res = try await client.runMutationSafe(
            query: DiscountGraphQL.DELETE_APPLIED_DISCOUNT_MUTATION,
            variables: ["code": code, "cartId": cartId]
        )
        guard
            let obj: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Discounts", "DeleteAppliedDiscount"])
        else {
            throw SdkException("Empty response in Discount.deleteApplied", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(obj, as: DeleteAppliedDiscountDto.self)
    }

    public func delete(discountId: Int) async throws -> DeleteDiscountDto {
        guard discountId > 0 else {
            throw ValidationException("discountId must be > 0", details: ["field": "discountId"])
        }
        let res = try await client.runMutationSafe(
            query: DiscountGraphQL.DELETE_DISCOUNT_MUTATION,
            variables: ["discountId": discountId]
        )
        guard
            let obj: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Discounts", "DeleteDiscount"])
        else {
            throw SdkException("Empty response in Discount.delete", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(obj, as: DeleteDiscountDto.self)
    }

    public func update(
        discountId: Int, code: String?, percentage: Int?, startDate: String?, endDate: String?,
        products: [Int]?
    ) async throws -> UpdateDiscountDto {
        guard discountId > 0 else {
            throw ValidationException("discountId must be > 0", details: ["field": "discountId"])
        }
        if let c = code, c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationException("code cannot be empty", details: ["field": "code"])
        }
        if let p = percentage, !(1...100).contains(p) {
            throw ValidationException(
                "percentage must be between 1 and 100", details: ["field": "percentage"])
        }

        let iso = ISO8601DateFormatter()
        if let s = startDate {
            if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ValidationException(
                    "startDate cannot be empty", details: ["field": "startDate"])
            }
            guard iso.date(from: s) != nil else {
                throw ValidationException(
                    "startDate must be ISO-8601", details: ["field": "startDate"])
            }
        }
        if let e = endDate {
            if e.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ValidationException("endDate cannot be empty", details: ["field": "endDate"])
            }
            guard iso.date(from: e) != nil else {
                throw ValidationException("endDate must be ISO-8601", details: ["field": "endDate"])
            }
        }
        if let s = startDate, let e = endDate, let sd = iso.date(from: s),
            let ed = iso.date(from: e), !(ed > sd)
        {
            throw ValidationException(
                "endDate must be after startDate", details: ["fields": ["startDate", "endDate"]])
        }

        var vars: [String: Any?] = [
            "discountId": discountId,
            "code": code,
            "percentage": percentage,
            "startDate": startDate,
            "endDate": endDate,
            "products": products,
        ]

        let res = try await client.runMutationSafe(
            query: DiscountGraphQL.UPDATE_DISCOUNT_MUTATION,
            variables: vars.compactMapValues { $0 }
        )
        guard
            let obj: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Discounts", "UpdateDiscount"])
        else {
            throw SdkException("Empty response in Discount.update", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(obj, as: UpdateDiscountDto.self)
    }

    public func verify(verifyDiscountId: Int?, code: String?) async throws -> VerifyDiscountDto {
        if (verifyDiscountId == nil || verifyDiscountId! <= 0)
            && (code == nil || code!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        {
            throw ValidationException(
                "Provide verifyDiscountId (> 0) or code",
                details: ["fields": ["verifyDiscountId", "code"]])
        }
        if let id = verifyDiscountId, id <= 0 {
            throw ValidationException(
                "verifyDiscountId must be > 0", details: ["field": "verifyDiscountId"])
        }
        if let c = code, c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationException("code cannot be empty", details: ["field": "code"])
        }

        let res = try await client.runMutationSafe(
            query: DiscountGraphQL.VERIFY_DISCOUNT_MUTATION,
            variables: ["verifyDiscountId": verifyDiscountId as Any?, "code": code as Any?]
                .compactMapValues { $0 }
        )
        guard
            let obj: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Discounts", "VerifyDiscount"])
        else {
            throw SdkException("Empty response in Discount.verify", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(obj, as: VerifyDiscountDto.self)
    }
}
