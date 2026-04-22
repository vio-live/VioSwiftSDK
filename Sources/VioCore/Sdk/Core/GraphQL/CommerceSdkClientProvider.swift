import Foundation

@MainActor
public final class CommerceSdkClientProvider {
    public static let shared = CommerceSdkClientProvider()

    private var cachedClient: SdkClient?
    private var cachedURL: URL?
    private var cachedApiKey: String?

    /// Per-sponsor client cache, keyed by `sponsorId`. Populated by
    /// ``client(forSponsorId:configuration:)`` so cart-intent overlays
    /// rendering a secondary sponsor's product hit that sponsor's Commerce
    /// channel instead of the primary's.
    private var sponsorClients: [Int: SdkClient] = [:]
    private var sponsorClientURLs: [Int: URL] = [:]
    private var sponsorClientKeys: [Int: String] = [:]

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

    /// Returns an `SdkClient` authenticated with the sponsor's own Commerce
    /// credentials when available, falling back to the primary sponsor / bootstrap
    /// key when `sponsorId` is nil, the sponsor is unknown, or the sponsor is
    /// visual-only (no `commerce` block).
    ///
    /// Use this from `cart_intent` rendering paths so an event with
    /// `sponsorId = 7` (XXL) hydrates the product detail via XXL's GraphQL key
    /// instead of the primary sponsor's.
    public func client(
        forSponsorId sponsorId: Int?,
        configuration: VioConfiguration = .shared,
    ) throws -> SdkClient {
        guard let sponsorId,
              let sponsorKey = configuration.commerce(forSponsorId: sponsorId)?.apiKey
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !sponsorKey.isEmpty else {
            return try client(configuration: configuration)
        }
        guard let resolvedURL = URL(string: configuration.resolvedCommerceGraphQLURL) else {
            throw SdkException(
                "Invalid commerce GraphQL URL: \(configuration.resolvedCommerceGraphQLURL)",
                code: "INVALID_COMMERCE_GRAPHQL_URL")
        }

        if let existing = sponsorClients[sponsorId],
           sponsorClientURLs[sponsorId] == resolvedURL,
           sponsorClientKeys[sponsorId] == sponsorKey {
            return existing
        }

        if let existing = sponsorClients[sponsorId] {
            existing.updateCredentials(baseUrl: resolvedURL, apiKey: sponsorKey)
            sponsorClientURLs[sponsorId] = resolvedURL
            sponsorClientKeys[sponsorId] = sponsorKey
            return existing
        }

        let created = SdkClient(baseUrl: resolvedURL, apiKey: sponsorKey)
        sponsorClients[sponsorId] = created
        sponsorClientURLs[sponsorId] = resolvedURL
        sponsorClientKeys[sponsorId] = sponsorKey
        return created
    }

    public func refresh(configuration: VioConfiguration = .shared) throws {
        _ = try client(configuration: configuration)
    }

    public func clear() {
        cachedClient = nil
        cachedURL = nil
        cachedApiKey = nil
        sponsorClients.removeAll()
        sponsorClientURLs.removeAll()
        sponsorClientKeys.removeAll()
    }
}
