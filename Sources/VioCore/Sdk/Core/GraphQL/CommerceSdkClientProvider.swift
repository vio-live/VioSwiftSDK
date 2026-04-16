import Foundation

@MainActor
public final class CommerceSdkClientProvider {
    public static let shared = CommerceSdkClientProvider()

    private var cachedClient: SdkClient?
    private var cachedURL: URL?
    private var cachedApiKey: String?

    private init() {}

    public func client(configuration: VioConfiguration = .shared) throws -> SdkClient {
        guard let resolvedURL = URL(string: configuration.resolvedCommerceGraphQLURL) else {
            throw SdkException(
                "Invalid commerce GraphQL URL: \(configuration.resolvedCommerceGraphQLURL)",
                code: "INVALID_COMMERCE_GRAPHQL_URL")
        }
        let resolvedApiKey = configuration.resolvedCommerceApiKey
        if let existing = cachedClient,
            cachedURL == resolvedURL,
            cachedApiKey == resolvedApiKey
        {
            return existing
        }

        if let existing = cachedClient {
            existing.updateCredentials(baseUrl: resolvedURL, apiKey: resolvedApiKey)
            cachedURL = resolvedURL
            cachedApiKey = resolvedApiKey
            return existing
        }

        let created = SdkClient(baseUrl: resolvedURL, apiKey: resolvedApiKey)
        cachedClient = created
        cachedURL = resolvedURL
        cachedApiKey = resolvedApiKey
        return created
    }

    public func refresh(configuration: VioConfiguration = .shared) throws {
        _ = try client(configuration: configuration)
    }

    public func clear() {
        cachedClient = nil
        cachedURL = nil
        cachedApiKey = nil
    }
}
