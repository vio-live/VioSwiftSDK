import Foundation

public protocol CartRepository {
    func getById(cart_id: String) async throws -> CartDto
    func create(customer_session_id: String, currency: String, shippingCountry: String?)
        async throws -> CartDto
    func update(cart_id: String, shipping_country: String) async throws -> CartDto
    func delete(cart_id: String) async throws -> RemoveCartDto
    func addItem(cart_id: String, line_items: [LineItemInput]) async throws -> CartDto
    func updateItem(cart_id: String, cart_item_id: String, shipping_id: String?, quantity: Int?)
        async throws -> CartDto
    func deleteItem(cart_id: String, cart_item_id: String) async throws -> CartDto
    func getLineItemsBySupplier(cart_id: String) async throws -> [GetLineItemsBySupplierDto]
}
