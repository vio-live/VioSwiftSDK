import Foundation

public final class SdkClient {
    public let baseUrl: URL
    public let apiKey: String

    public let apolloClient: GraphQLHTTPClient

    public let cart: CartRepository
    public let channel: Channel
    public let checkout: CheckoutRepository
    public let discount: DiscountRepository
    public let market: MarketRepository
    public let payment: PaymentRepository

    public init(baseUrl: URL, apiKey: String) {
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.apolloClient = GraphQLHTTPClient(baseURL: baseUrl, apiKey: apiKey)

        self.cart = CartRepositoryGQL(client: apolloClient)
        self.channel = Channel(apolloClient)
        self.checkout = CheckoutRepositoryGQL(client: apolloClient)
        self.discount = DiscountRepositoryGQL(
            client: apolloClient,
            apiKey: apiKey,
            baseUrl: baseUrl.absoluteString
        )
        self.market = MarketRepositoryGQL(client: apolloClient)
        self.payment = PaymentRepositoryGQL(client: apolloClient)

        _ = prepareGraphQLOpsNoop()

    }
}

extension SdkClient {
    @inlinable
    public func noop<T>(_ value: T) -> T { value }

    @discardableResult
    public func prepareGraphQLOpsNoop() -> Bool {
        Task {
            let _ = await GraphQLOperationLoader().loadAll(from: [])
        }
        return true
    }
}
