import Foundation

public final class MarketRepositoryGQL: MarketRepository {
    private let client: GraphQLHTTPClient
    public init(client: GraphQLHTTPClient) { self.client = client }

    public func getAvailable() async throws -> [GetAvailableGlobalMarketsDto] {
        let res = try await client.runQuerySafe(
            query: MarketGraphQL.GET_AVAILABLE_MARKET_QUERY,
            variables: [:]
        )

        guard
            let list: [Any] = GraphQLPick.pickPath(
                res.data, path: ["Markets", "GetAvailableMarkets"])
        else {
            throw SdkException("Empty response in Market.getAvailable", code: "EMPTY_RESPONSE")
        }

        let data = try JSONSerialization.data(withJSONObject: list, options: [])
        return try JSONDecoder().decode([GetAvailableGlobalMarketsDto].self, from: data)
    }
}
