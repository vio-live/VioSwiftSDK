import Foundation

public final class ChannelInfoRepositoryGQL: ChannelInfoRepository {
    private let client: GraphQLHTTPClient
    public init(client: GraphQLHTTPClient) { self.client = client }

    public func getChannels() async throws -> [GetChannelsDto] {
        let res = try await client.runQuerySafe(
            query: ChannelGraphQL.GET_CHANNELS_CHANNEL_QUERY,
            variables: [:]
        )
        guard let list: [Any] = GraphQLPick.pickPath(res.data, path: ["Channel", "GetChannels"])
        else {
            throw SdkException("Empty response in Info.getChannels", code: "EMPTY_RESPONSE")
        }
        let data = try JSONSerialization.data(withJSONObject: list, options: [])
        return try JSONDecoder().decode([GetChannelsDto].self, from: data)
    }

    public func getPurchaseConditions() async throws -> GetTermsAndConditionsDto {
        let res = try await client.runQuerySafe(
            query: ChannelGraphQL.GET_PURCHASE_CONDITIONS_CHANNEL_QUERY,
            variables: [:]
        )
        guard
            let obj: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Channel", "GetPurchaseConditions"])
        else {
            throw SdkException(
                "Empty response in Info.getPurchaseConditions", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(obj, as: GetTermsAndConditionsDto.self)
    }

    public func getTermsAndConditions() async throws -> GetTermsAndConditionsDto {
        let res = try await client.runQuerySafe(
            query: ChannelGraphQL.GET_TERMS_AND_CONDITIONS_CHANNEL_QUERY,
            variables: [:]
        )
        guard
            let obj: [String: Any] = GraphQLPick.pickPath(
                res.data, path: ["Channel", "GetTermsAndConditions"])
        else {
            throw SdkException(
                "Empty response in Info.getTermsAndConditions", code: "EMPTY_RESPONSE")
        }
        return try GraphQLPick.decodeJSON(obj, as: GetTermsAndConditionsDto.self)
    }
}
