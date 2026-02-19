import Foundation

public final class CheckoutRepositoryGQL: CheckoutRepository {
    private let client: GraphQLHTTPClient
    public init(client: GraphQLHTTPClient) { self.client = client }

    public func getById(checkout_id: String) async throws -> GetCheckoutDto {
        try Validation.requireNonEmpty(checkout_id, field: "checkout_id")

        let res = try await client.runQuerySafe(
            query: CheckoutGraphQL.GET_BY_ID_CHECKOUT_QUERY,
            variables: ["checkoutId": checkout_id]
        )

        guard
            let data: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Checkout", "GetCheckout"])
        else {
            throw SdkException("Empty response in Checkout.getById", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: GetCheckoutDto.self)
    }

    public func create(cart_id: String) async throws -> CreateCheckoutDto {
        try Validation.requireNonEmpty(cart_id, field: "cart_id")

        let res = try await client.runMutationSafe(
            query: CheckoutGraphQL.CREATE_CHECKOUT_MUTATION,
            variables: ["cartId": cart_id]
        )

        guard
            let data: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Checkout", "CreateCheckout"])
        else {
            throw SdkException("Empty response in Checkout.create", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: CreateCheckoutDto.self)
    }

    public func update(
        checkout_id: String,
        status: String?,
        email: String?,
        success_url: String?,
        cancel_url: String?,
        payment_method: String?,
        shipping_address: [String: Any]?,
        billing_address: [String: Any]?,
        buyer_accepts_terms_conditions: Bool = true,
        buyer_accepts_purchase_conditions: Bool = true
    ) async throws -> UpdateCheckoutDto {

        try Validation.requireNonEmpty(checkout_id, field: "checkout_id")
        if let s = email, s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationException("email cannot be empty", details: ["field": "email"])
        }
        if let s = payment_method, s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationException(
                "payment_method cannot be empty", details: ["field": "payment_method"])
        }
        if let m = shipping_address, m.isEmpty {
            throw ValidationException(
                "shipping_address cannot be empty", details: ["field": "shipping_address"])
        }
        if let m = billing_address, m.isEmpty {
            throw ValidationException(
                "billing_address cannot be empty", details: ["field": "billing_address"])
        }

        var vars: [String: Any?] = [
            "checkoutId": checkout_id,
            "status": status,
            "email": email,
            "successUrl": success_url,
            "cancelUrl": cancel_url,
            "paymentMethod": payment_method,
            "shippingAddress": shipping_address,
            "billingAddress": billing_address,
            "buyerAcceptsTermsConditions": buyer_accepts_terms_conditions,
            "buyerAcceptsPurchaseConditions": buyer_accepts_purchase_conditions,
        ]

        let res = try await client.runMutationSafe(
            query: CheckoutGraphQL.UPDATE_CHECKOUT_MUTATION,
            variables: vars.compactMapValues { $0 }
        )

        guard
            let data: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Checkout", "UpdateCheckout"])
        else {
            throw SdkException("Empty response in Checkout.update", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: UpdateCheckoutDto.self)
    }

    public func delete(checkout_id: String) async throws -> RemoveCheckoutDto {
        try Validation.requireNonEmpty(checkout_id, field: "checkout_id")

        let res = try await client.runMutationSafe(
            query: CheckoutGraphQL.DELETE_CHECKOUT_MUTATION,
            variables: ["checkoutId": checkout_id]
        )

        guard
            let data: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Checkout", "RemoveCheckout"])
        else {
            throw SdkException("Empty response in Checkout.delete", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(data, as: RemoveCheckoutDto.self)
    }
}
