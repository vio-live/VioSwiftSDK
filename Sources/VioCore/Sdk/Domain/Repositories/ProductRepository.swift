import Foundation

public protocol ProductRepository {
    func get(
        currency: String?,
        imageSize: String?,
        barcodeList: [String]?,
        categoryIds: [Int]?,
        productIds: [Int]?,
        skuList: [String]?,
        useCache: Bool,
        shippingCountryCode: String?
    ) async throws -> [ProductDto]

    func getByCategoryId(
        categoryId: Int,
        currency: String?,
        imageSize: String,
        shippingCountryCode: String?
    ) async throws -> [ProductDto]

    func getByCategoryIds(
        categoryIds: [Int],
        currency: String?,
        imageSize: String,
        shippingCountryCode: String?
    ) async throws -> [ProductDto]

    func getByParams(
        currency: String?,
        imageSize: String,
        sku: String?,
        barcode: String?,
        productId: Int?,
        shippingCountryCode: String?
    ) async throws -> ProductDto

    func getByIds(
        productIds: [Int],
        currency: String?,
        imageSize: String,
        useCache: Bool,
        shippingCountryCode: String?
    ) async throws -> [ProductDto]

    func getBySkus(
        sku: String,
        productId: Int?,
        currency: String?,
        imageSize: String,
        shippingCountryCode: String?
    ) async throws -> [ProductDto]

    func getByBarcodes(
        barcode: String,
        productId: Int?,
        currency: String?,
        imageSize: String,
        shippingCountryCode: String?
    ) async throws -> [ProductDto]
}
