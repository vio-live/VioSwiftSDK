import Foundation

public final class ChannelCategoryRepositoryGQL: ChannelCategoryRepository {
    private let client: GraphQLHTTPClient
    public init(client: GraphQLHTTPClient) { self.client = client }

    public func get() async throws -> [GetCategoryDto] {
        let res = try await client.runQuerySafe(
            query: ChannelGraphQL.GET_CATEGORIES_CHANNEL_QUERY,
            variables: [:]
        )
        guard let list: [Any] = GraphQLPick.pickPath(res.data, path: ["Channel", "GetCategories"])
        else {
            throw SdkException("Empty response in Category.get", code: "EMPTY_RESPONSE")
        }
        let data = try JSONSerialization.data(withJSONObject: list, options: [])
        return try JSONDecoder().decode([GetCategoryDto].self, from: data)
    }
}
