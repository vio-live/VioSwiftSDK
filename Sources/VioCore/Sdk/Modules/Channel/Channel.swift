import Foundation

public final class Channel {
    public let product: ProductRepository
    public let market: ChannelMarketRepository
    public let category: ChannelCategoryRepository
    public let info: ChannelInfoRepository

    public init(_ client: GraphQLHTTPClient) {
        self.product = ProductRepositoryGQL(client: client)
        self.market = ChannelMarketRepositoryGQL(client: client)
        self.category = ChannelCategoryRepositoryGQL(client: client)
        self.info = ChannelInfoRepositoryGQL(client: client)
    }
}
