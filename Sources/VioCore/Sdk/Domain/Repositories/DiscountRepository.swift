import Foundation

public protocol DiscountRepository {
    func get() async throws -> [GetDiscountsDto]
    func getByChannel() async throws -> [GetDiscountsDto]
    func getById(discountId: Int) async throws -> GetDiscountByIdDto
    func getType(id: Int?, type: String?) async throws -> [GetDiscountTypeDto]

    func add(code: String, percentage: Int, startDate: String, endDate: String, typeId: Int)
        async throws -> AddDiscountDto
    func apply(code: String, cartId: String) async throws -> ApplyDiscountDto
    func deleteApplied(code: String, cartId: String) async throws -> DeleteAppliedDiscountDto
    func delete(discountId: Int) async throws -> DeleteDiscountDto
    func update(
        discountId: Int, code: String?, percentage: Int?, startDate: String?, endDate: String?,
        products: [Int]?
    ) async throws -> UpdateDiscountDto
    func verify(verifyDiscountId: Int?, code: String?) async throws -> VerifyDiscountDto
}
