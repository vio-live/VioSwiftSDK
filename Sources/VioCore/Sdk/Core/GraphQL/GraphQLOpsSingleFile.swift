import Foundation

public struct GQLOperation: Sendable, Equatable {
    public let name: String
    public let content: String
    public let source: String
}

public struct GQLOperationSource: Sendable, Equatable {
    public let url: URL
    public let headers: [String: String]
    public init(url: URL, headers: [String: String] = [:]) {
        self.url = url
        self.headers = headers
    }
}

private enum _GQLOperationFallbackFromVars {
    static func bundle() -> [String: String] {
        var ops: [String: String] = [:]

        ops["cart/GetCart.graphql"] = CartGraphQL.GET_CART_QUERY
        ops["cart/GetLineItemsBySupplier.graphql"] = CartGraphQL.GET_LINE_ITEMS_BY_SUPPLIER_QUERY
        ops["cart/CreateCart.graphql"] = CartGraphQL.CREATE_CART_MUTATION
        ops["cart/UpdateCart.graphql"] = CartGraphQL.UPDATE_CART_MUTATION
        ops["cart/DeleteCart.graphql"] = CartGraphQL.DELETE_CART_MUTATION
        ops["cart/AddItem.graphql"] = CartGraphQL.ADD_ITEM_TO_CART_MUTATION
        ops["cart/UpdateItem.graphql"] = CartGraphQL.UPDATE_ITEM_TO_CART_MUTATION
        ops["cart/DeleteItem.graphql"] = CartGraphQL.DELETE_ITEM_TO_CART_MUTATION

        ops["checkout/GetCheckout.graphql"] = CheckoutGraphQL.GET_BY_ID_CHECKOUT_QUERY
        ops["checkout/CreateCheckout.graphql"] = CheckoutGraphQL.CREATE_CHECKOUT_MUTATION
        ops["checkout/UpdateCheckout.graphql"] = CheckoutGraphQL.UPDATE_CHECKOUT_MUTATION
        ops["checkout/RemoveCheckout.graphql"] = CheckoutGraphQL.DELETE_CHECKOUT_MUTATION

        ops["payment/GetAvailablePaymentMethods.graphql"] =
            PaymentGraphQL.GET_AVAILABLE_METHODS_PAYMENT_QUERY
        ops["payment/CreatePaymentIntentStripe.graphql"] =
            PaymentGraphQL.STRIPE_INTENT_PAYMENT_MUTATION
        ops["payment/CreatePaymentStripe.graphql"] =
            PaymentGraphQL.STRIPE_PLATFORM_BUILDER_PAYMENT_MUTATION
        ops["payment/CreatePaymentKlarna.graphql"] =
            PaymentGraphQL.KLARNA_PLATFORM_BUILDER_PAYMENT_MUTATION
        ops["payment/CreatePaymentVipps.graphql"] = PaymentGraphQL.VIPPS_PAYMENT

        ops["market/GetAvailableMarkets.graphql"] = MarketGraphQL.GET_AVAILABLE_MARKET_QUERY

        ops["discount/GetDiscounts.graphql"] = DiscountGraphQL.GET_DISCOUNT_QUERY
        ops["discount/GetDiscountsById.graphql"] = DiscountGraphQL.GET_DISCOUNT_BY_ID_QUERY
        ops["discount/GetDiscountType.graphql"] = DiscountGraphQL.GET_DISCOUNT_TYPE_QUERY
        ops["discount/AddDiscount.graphql"] = DiscountGraphQL.ADD_DISCOUNT_MUTATION
        ops["discount/ApplyDiscount.graphql"] = DiscountGraphQL.APPLY_DISCOUNT_MUTATION
        ops["discount/DeleteAppliedDiscount.graphql"] =
            DiscountGraphQL.DELETE_APPLIED_DISCOUNT_MUTATION
        ops["discount/DeleteDiscount.graphql"] = DiscountGraphQL.DELETE_DISCOUNT_MUTATION
        ops["discount/UpdateDiscount.graphql"] = DiscountGraphQL.UPDATE_DISCOUNT_MUTATION
        ops["discount/VerifyDiscount.graphql"] = DiscountGraphQL.VERIFY_DISCOUNT_MUTATION

        ops["channel/GetProducts.graphql"] = ChannelGraphQL.GET_PRODUCTS_CHANNEL_QUERY
        ops["channel/GetProductsByCategory.graphql"] =
            ChannelGraphQL.GET_PRODUCTS_BY_CATEGORY_CHANNEL_QUERY
        ops["channel/GetProductsByCategories.graphql"] =
            ChannelGraphQL.GET_PRODUCTS_BY_CATEGORIES_CHANNEL_QUERY
        ops["channel/GetProduct.graphql"] = ChannelGraphQL.GET_PRODUCT_CHANNEL_QUERY
        ops["channel/GetProductsByIds.graphql"] = ChannelGraphQL.GET_PRODUCTS_BY_IDS_CHANNEL_QUERY
        ops["channel/GetProductBySKUs.graphql"] = ChannelGraphQL.GET_PRODUCT_BY_SKUS_CHANNEL_QUERY
        ops["channel/GetProductByBarcodes.graphql"] =
            ChannelGraphQL.GET_PRODUCT_BY_BARCODES_CHANNEL_QUERY
        ops["channel/GetCategories.graphql"] = ChannelGraphQL.GET_CATEGORIES_CHANNEL_QUERY
        ops["channel/GetAvailableMarkets.graphql"] =
            ChannelGraphQL.GET_AVAILABLE_MARKETS_CHANNEL_QUERY
        ops["channel/GetPurchaseConditions.graphql"] =
            ChannelGraphQL.GET_PURCHASE_CONDITIONS_CHANNEL_QUERY
        ops["channel/GetTermsAndConditions.graphql"] =
            ChannelGraphQL.GET_TERMS_AND_CONDITIONS_CHANNEL_QUERY
        ops["channel/GetChannels.graphql"] = ChannelGraphQL.GET_CHANNELS_CHANNEL_QUERY

        return ops
    }
}

public final class GraphQLOperationLoader: @unchecked Sendable {
    private let session: URLSession
    private let timeout: TimeInterval
    private let cache = NSCache<NSString, NSString>()

    public init(timeout: TimeInterval = 3.5) {
        self.timeout = timeout
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: cfg)
    }

    public func loadAll(from sources: [GQLOperationSource]) async -> [GQLOperation] {
        if let remote = await tryFetchFirstWorking(sources: sources) {
            return mergeRemote(remote, withFallback: _GQLOperationFallbackFromVars.bundle())
        }
        return _GQLOperationFallbackFromVars.bundle()
            .map { GQLOperation(name: $0.key, content: $0.value, source: "fallback") }
            .sorted { $0.name < $1.name }
    }

    private func tryFetchFirstWorking(sources: [GQLOperationSource]) async -> [GQLOperation]? {
        for src in sources {
            do { if let r = try await fetchIndexAndFiles(from: src) { return r } } catch {}
        }
        return nil
    }

    private func fetchIndexAndFiles(from source: GQLOperationSource) async throws -> [GQLOperation]?
    {
        let (indexData, _) = try await request(source.url, headers: source.headers)
        guard
            let root = try? JSONSerialization.jsonObject(with: indexData) as? [String: Any],
            let files = root["files"] as? [[String: Any]]
        else { return nil }

        var ops: [GQLOperation] = []
        for f in files {
            guard let name = f["name"] as? String,
                let urlStr = f["url"] as? String,
                let url = URL(string: urlStr)
            else { continue }

            if let cached = cache.object(forKey: url.absoluteString as NSString) {
                let text = String(cached)
                ops.append(.init(name: name, content: text, source: "remote(cache)"))
                continue
            }

            do {
                let (data, _) = try await request(url, headers: source.headers)
                guard let text = String(data: data, encoding: .utf8),
                    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }
                cache.setObject(text as NSString, forKey: url.absoluteString as NSString)
                ops.append(.init(name: name, content: text, source: "remote"))
            } catch {
            }
        }
        return ops.isEmpty ? nil : ops
    }

    private func request(_ url: URL, headers: [String: String]) async throws -> (Data, URLResponse)
    {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        return try await session.data(for: req)
    }

    private func mergeRemote(_ remote: [GQLOperation], withFallback fb: [String: String])
        -> [GQLOperation]
    {
        var map = [String: GQLOperation]()
        for r in remote { map[r.name] = r }
        for (name, text) in fb where map[name] == nil {
            map[name] = GQLOperation(name: name, content: text, source: "fallback")
        }
        return map.values.sorted { $0.name < $1.name }
    }
}
