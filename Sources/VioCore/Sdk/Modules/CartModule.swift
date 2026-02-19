import Foundation

public final class CartRepositoryGQL: CartRepository {
    private let client: GraphQLHTTPClient
    public init(client: GraphQLHTTPClient) { self.client = client }

    public func getById(cart_id: String) async throws -> CartDto {
        try Validation.requireNonEmpty(cart_id, field: "cart_id")
        let res = try await client.runQuerySafe(
            query: CartGraphQL.GET_CART_QUERY, variables: ["cartId": cart_id])
        guard let data: [String: Any] = GraphQLPick.pickPath(res.data, path: ["Cart", "GetCart"])
        else {
            throw SdkException("Empty response in Cart.getById", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: CartDto.self)
    }

    public func         create(customer_session_id: String, currency: String, shippingCountry: String?)
        async throws -> CartDto
    {
        try Validation.requireNonEmpty(customer_session_id, field: "customer_session_id")
        try Validation.requireCurrency(currency)
        if let shippingCountry { try Validation.requireCountry(shippingCountry) }

        let vars: [String: Any?] = [
            "customerSessionId": customer_session_id,
            "currency": currency,
            "shippingCountry": shippingCountry,
        ]
        let res = try await client.runMutationSafe(
            query: CartGraphQL.CREATE_CART_MUTATION, variables: vars.compactMapValues { $0 })
        guard
            let data: [String: Any] = GraphQLPick.pickPath(res.data, path: ["Cart", "CreateCart"])
        else {
            throw SdkException("Empty response in Cart.create", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: CartDto.self)
    }

    public func update(cart_id: String, shipping_country: String) async throws -> CartDto {
        try Validation.requireNonEmpty(cart_id, field: "cart_id")
        try Validation.requireCountry(shipping_country)
        let res = try await client.runMutationSafe(
            query: CartGraphQL.UPDATE_CART_MUTATION,
            variables: ["cartId": cart_id, "shippingCountry": shipping_country])
        guard
            let data: [String: Any] = GraphQLPick.pickPath(res.data, path: ["Cart", "UpdateCart"])
        else {
            throw SdkException("Empty response in Cart.update", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: CartDto.self)
    }

    public func delete(cart_id: String) async throws -> RemoveCartDto {
        try Validation.requireNonEmpty(cart_id, field: "cart_id")
        let res = try await client.runMutationSafe(
            query: CartGraphQL.DELETE_CART_MUTATION, variables: ["cartId": cart_id])
        guard
            let data: [String: Any] = GraphQLPick.pickPath(res.data, path: ["Cart", "DeleteCart"])
        else {
            throw SdkException("Empty response in Cart.delete", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: RemoveCartDto.self)
    }

    public func addItem(cart_id: String, line_items: [LineItemInput]) async throws -> CartDto {
        try Validation.requireNonEmpty(cart_id, field: "cart_id")
        if line_items.isEmpty {
            throw ValidationException(
                "line_items cannot be empty", details: ["field": "line_items"])
        }
        let vars: [String: Any] = ["cartId": cart_id, "lineItems": line_items.map { $0.toJSON() }]
        let res = try await client.runMutationSafe(
            query: CartGraphQL.ADD_ITEM_TO_CART_MUTATION, variables: vars)
        guard let data: [String: Any] = GraphQLPick.pickPath(res.data, path: ["Cart", "AddItem"])
        else {
            throw SdkException("Empty response in Cart.addItem", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: CartDto.self)
    }

    public func updateItem(
        cart_id: String, cart_item_id: String, shipping_id: String?, quantity: Int?
    ) async throws -> CartDto {
        try Validation.requireNonEmpty(cart_id, field: "cart_id")
        try Validation.requireNonEmpty(cart_item_id, field: "cart_item_id")
        if quantity == nil && (shipping_id == nil || shipping_id!.isEmpty) {
            throw ValidationException(
                "You must provide either quantity or shipping_id",
                details: ["fields": ["quantity", "shipping_id"]])
        }
        if let q = quantity, q <= 0 {
            throw ValidationException("quantity must be > 0", details: ["field": "quantity"])
        }

        var vars: [String: Any] = ["cartId": cart_id, "cartItemId": cart_item_id]
        if let q = quantity { vars["qty"] = q }
        if let s = shipping_id { vars["shippingId"] = s }

        let res = try await client.runMutationSafe(
            query: CartGraphQL.UPDATE_ITEM_TO_CART_MUTATION, variables: vars)
        guard
            let data: [String: Any] = GraphQLPick.pickPath(res.data, path: ["Cart", "UpdateItem"])
        else {
            throw SdkException("Empty response in Cart.updateItem", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: CartDto.self)
    }

    public func deleteItem(cart_id: String, cart_item_id: String) async throws -> CartDto {
        try Validation.requireNonEmpty(cart_id, field: "cart_id")
        try Validation.requireNonEmpty(cart_item_id, field: "cart_item_id")
        let res = try await client.runMutationSafe(
            query: CartGraphQL.DELETE_ITEM_TO_CART_MUTATION,
            variables: ["cartId": cart_id, "cartItemId": cart_item_id])
        guard
            let data: [String: Any] = GraphQLPick.pickPath(res.data, path: ["Cart", "DeleteItem"])
        else {
            throw SdkException("Empty response in Cart.deleteItem", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: CartDto.self)
    }

    public func getLineItemsBySupplier(cart_id: String) async throws -> [GetLineItemsBySupplierDto]
    {
        try Validation.requireNonEmpty(cart_id, field: "cart_id")
        let res = try await client.runQuerySafe(
            query: CartGraphQL.GET_LINE_ITEMS_BY_SUPPLIER_QUERY, variables: ["cartId": cart_id])
        guard
            let list: [Any] = GraphQLPick.pickPath(
                res.data, path: ["Cart", "GetLineItemsBySupplier"])
        else {
            throw SdkException(
                "Empty response in Cart.getLineItemsBySupplier", code: "EMPTY_RESPONSE")
        }
        let data = try JSONSerialization.data(withJSONObject: list, options: [])
        return try JSONDecoder().decode([GetLineItemsBySupplierDto].self, from: data)
    }
}
