import Foundation

public final class ChannelMarketRepositoryGQL: ChannelMarketRepository {
    private let client: GraphQLHTTPClient
    public init(client: GraphQLHTTPClient) { self.client = client }

    public func getAvailable() async throws -> [GetAvailableMarketsDto] {
        let res = try await client.runQuerySafe(
            query: ChannelGraphQL.GET_AVAILABLE_MARKETS_CHANNEL_QUERY,
            variables: [:]
        )
        guard
            let list: [Any] = GraphQLPick.pickPath(
                res.data, path: ["Channel", "GetAvailableMarkets"])
        else {
            throw SdkException("Empty response in Market.getAvailable", code: "EMPTY_RESPONSE")
        }
        let data = try JSONSerialization.data(withJSONObject: list, options: [])
        return try JSONDecoder().decode([GetAvailableMarketsDto].self, from: data)
    }
}
