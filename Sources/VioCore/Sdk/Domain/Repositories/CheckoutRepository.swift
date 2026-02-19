import Foundation

public protocol CheckoutRepository {
    func getById(checkout_id: String) async throws -> GetCheckoutDto
    func create(cart_id: String) async throws -> CreateCheckoutDto
    func update(
        checkout_id: String,
        status: String?,
        email: String?,
        success_url: String?,
        cancel_url: String?,
        payment_method: String?,
        shipping_address: [String: Any]?,
        billing_address: [String: Any]?,
        buyer_accepts_terms_conditions: Bool,
        buyer_accepts_purchase_conditions: Bool
    ) async throws -> UpdateCheckoutDto
    func delete(checkout_id: String) async throws -> RemoveCheckoutDto
}
