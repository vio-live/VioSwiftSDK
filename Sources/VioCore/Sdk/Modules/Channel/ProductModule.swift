import Foundation
import VioCore

public final class ProductRepositoryGQL: ProductRepository {
    private let client: GraphQLHTTPClient
    public init(client: GraphQLHTTPClient) { self.client = client }

    private func requirePositiveIds(_ ids: [Int], _ field: String) throws {
        if ids.isEmpty {
            throw ValidationException("\(field) cannot be empty", details: ["field": field])
        }
        if ids.contains(where: { $0 <= 0 }) {
            throw ValidationException(
                "\(field) must contain positive IDs only", details: ["field": field])
        }
    }

    private func requireNonEmptyStrings(_ values: [String], _ field: String) throws {
        if values.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            throw ValidationException(
                "\(field) cannot contain empty strings", details: ["field": field])
        }
    }

    private func validateCommonFilters(
        currency: String?, imageSize: String?, shippingCountryCode: String?
    ) throws {
        if let c = currency { try Validation.requireCurrency(c) }
        if let s = shippingCountryCode { try Validation.requireCountry(s) }
        if let i = imageSize, i.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationException("imageSize cannot be empty", details: ["field": "imageSize"])
        }
    }

    @inline(__always)
    private func fetchProducts(
        currency: String?,
        imageSize: String?,
        barcodeList: [String]?,
        categoryIds: [Int]?,
        productIds: [Int]?,
        skuList: [String]?,
        useCache: Bool,
        shippingCountryCode: String?
    ) async throws -> [ProductDto] {
        // Determine if we should use GetProducts (all products) or Products (filtered)
        // Use GetProducts when no filters are provided (loads all products from channel)
        let hasProductIds = productIds != nil && !productIds!.isEmpty
        let hasBarcodeList = barcodeList != nil && !barcodeList!.isEmpty
        let hasSkuList = skuList != nil && !skuList!.isEmpty
        let hasCategoryIds = categoryIds != nil && !categoryIds!.isEmpty
        
        let shouldLoadAllProducts = !hasProductIds && !hasBarcodeList && !hasSkuList && !hasCategoryIds
        
        if shouldLoadAllProducts {
            // Use GetProducts query when no filters are provided (loads all products)
            let vars: [String: Any] = [
                "currency": currency as Any,
                "imageSize": imageSize as Any,
                "shippingCountryCode": shippingCountryCode as Any,
            ].compactMapValues { $0 }
            
            let res = try await client.runQuerySafe(
                query: ChannelGraphQL.GET_PRODUCTS_QUERY,
                variables: vars
            )
            
            guard let list: [Any] = GraphQLPick.pickPath(res.data, path: ["Channel", "GetProducts"]) else {
                throw SdkException("Empty response in Product.get", code: "EMPTY_RESPONSE")
            }
            let data = try JSONSerialization.data(withJSONObject: list, options: [])
            let products = try JSONDecoder().decode([ProductDto].self, from: data)
            return products
        } else {
            // Use Products query when filters are provided
            let vars: [String: Any] = [
                "currency": currency as Any,
                "imageSize": imageSize as Any,
                "barcodeList": barcodeList ?? [],
                "skuList": skuList ?? [],
                "categoryIds": categoryIds ?? [],
                "productIds": productIds ?? [],
                "useCache": useCache,
                "shippingCountryCode": shippingCountryCode as Any,
            ].compactMapValues { $0 }
            
            let res = try await client.runQuerySafe(
                query: ChannelGraphQL.GET_PRODUCTS_CHANNEL_QUERY,
                variables: vars
            )
            
            guard let list: [Any] = GraphQLPick.pickPath(res.data, path: ["Channel", "Products"]) else {
                throw SdkException("Empty response in Product.get", code: "EMPTY_RESPONSE")
            }
            let data = try JSONSerialization.data(withJSONObject: list, options: [])
            let products = try JSONDecoder().decode([ProductDto].self, from: data)
            return products
        }
    }

    // ---------- Public API (unchanged signatures) ----------
    public func get(
        currency: String?,
        imageSize: String? = "large",
        barcodeList: [String]?,
        categoryIds: [Int]?,
        productIds: [Int]?,
        skuList: [String]?,
        useCache: Bool = true,
        shippingCountryCode: String?
    ) async throws -> [ProductDto] {
        try validateCommonFilters(
            currency: currency, imageSize: imageSize, shippingCountryCode: shippingCountryCode)
        if let ids = categoryIds { try requirePositiveIds(ids, "categoryIds") }
        if let ids = productIds { try requirePositiveIds(ids, "productIds") }
        if let list = skuList { try requireNonEmptyStrings(list, "skuList") }
        if let list = barcodeList { try requireNonEmptyStrings(list, "barcodeList") }

        return try await fetchProducts(
            currency: currency,
            imageSize: imageSize,
            barcodeList: barcodeList,
            categoryIds: categoryIds,
            productIds: productIds,
            skuList: skuList,
            useCache: useCache,
            shippingCountryCode: shippingCountryCode
        )
    }

    public func getByCategoryId(
        categoryId: Int,
        currency: String?,
        imageSize: String = "large",
        shippingCountryCode: String?
    ) async throws -> [ProductDto] {
        guard categoryId > 0 else {
            throw ValidationException("categoryId must be > 0", details: ["field": "categoryId"])
        }
        try validateCommonFilters(
            currency: currency, imageSize: imageSize, shippingCountryCode: shippingCountryCode)

        return try await fetchProducts(
            currency: currency,
            imageSize: imageSize,
            barcodeList: [],
            categoryIds: [categoryId],
            productIds: [],
            skuList: [],
            useCache: true,
            shippingCountryCode: shippingCountryCode
        )
    }

    public func getByCategoryIds(
        categoryIds: [Int],
        currency: String?,
        imageSize: String = "large",
        shippingCountryCode: String?
    ) async throws -> [ProductDto] {
        try requirePositiveIds(categoryIds, "categoryIds")
        try validateCommonFilters(
            currency: currency, imageSize: imageSize, shippingCountryCode: shippingCountryCode)

        return try await fetchProducts(
            currency: currency,
            imageSize: imageSize,
            barcodeList: [],
            categoryIds: categoryIds,
            productIds: [],
            skuList: [],
            useCache: true,
            shippingCountryCode: shippingCountryCode
        )
    }

    public func getByParams(
        currency: String?,
        imageSize: String = "large",
        sku: String?,
        barcode: String?,
        productId: Int?,
        shippingCountryCode: String?
    ) async throws -> ProductDto {
        try validateCommonFilters(
            currency: currency, imageSize: imageSize, shippingCountryCode: shippingCountryCode)
        if let pid = productId, pid <= 0 {
            throw ValidationException("productId must be > 0", details: ["field": "productId"])
        }
        if let s = sku, s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationException("sku cannot be empty", details: ["field": "sku"])
        }
        if let b = barcode, b.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationException("barcode cannot be empty", details: ["field": "barcode"])
        }

        let products = try await fetchProducts(
            currency: currency,
            imageSize: imageSize,
            barcodeList: barcode.map { [$0] } ?? [],
            categoryIds: [],
            productIds: productId.map { [$0] } ?? [],
            skuList: sku.map { [$0] } ?? [],
            useCache: true,
            shippingCountryCode: shippingCountryCode
        )
        guard let first = products.first else {
            throw SdkException("Empty response in Product.getByParams", code: "EMPTY_RESPONSE")
        }
        return first
    }

    public func getByIds(
        productIds: [Int],
        currency: String?,
        imageSize: String = "large",
        useCache: Bool = true,
        shippingCountryCode: String?
    ) async throws -> [ProductDto] {
        try requirePositiveIds(productIds, "productIds")
        try validateCommonFilters(
            currency: currency, imageSize: imageSize, shippingCountryCode: shippingCountryCode)

        return try await fetchProducts(
            currency: currency,
            imageSize: imageSize,
            barcodeList: [],
            categoryIds: [],
            productIds: productIds,
            skuList: [],
            useCache: useCache,
            shippingCountryCode: shippingCountryCode
        )
    }

    public func getBySkus(
        sku: String,
        productId: Int?,
        currency: String?,
        imageSize: String = "large",
        shippingCountryCode: String?
    ) async throws -> [ProductDto] {
        try Validation.requireNonEmpty(sku, field: "sku")
        if let pid = productId, pid <= 0 {
            throw ValidationException("productId must be > 0", details: ["field": "productId"])
        }
        try validateCommonFilters(
            currency: currency, imageSize: imageSize, shippingCountryCode: shippingCountryCode)

        return try await fetchProducts(
            currency: currency,
            imageSize: imageSize,
            barcodeList: [],
            categoryIds: [],
            productIds: productId.map { [$0] } ?? [],
            skuList: [sku],
            useCache: true,
            shippingCountryCode: shippingCountryCode
        )
    }

    public func getByBarcodes(
        barcode: String,
        productId: Int?,
        currency: String?,
        imageSize: String = "large",
        shippingCountryCode: String?
    ) async throws -> [ProductDto] {
        try Validation.requireNonEmpty(barcode, field: "barcode")
        if let pid = productId, pid <= 0 {
            throw ValidationException("productId must be > 0", details: ["field": "productId"])
        }
        try validateCommonFilters(
            currency: currency, imageSize: imageSize, shippingCountryCode: shippingCountryCode)

        return try await fetchProducts(
            currency: currency,
            imageSize: imageSize,
            barcodeList: [barcode],
            categoryIds: [],
            productIds: productId.map { [$0] } ?? [],
            skuList: [],
            useCache: true,
            shippingCountryCode: shippingCountryCode
        )
    }
}
