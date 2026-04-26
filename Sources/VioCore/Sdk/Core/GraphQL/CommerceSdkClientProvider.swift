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

    /// The sponsor whose Commerce credentials are currently active in the
    /// resolved SDK client. Single source of truth for "who are we transacting
    /// with right now" — set every time `client(forSponsorId:)` or
    /// `client(configuration:)` returns a client.
    ///
    /// Consumers (e.g. `VApplePayConfirmationSheet`) read this to render the
    /// purchase sponsor's brand without trusting `CampaignManager.activeCartIntentEvent`
    /// (which can be cleared by overlay dismissal flows before the
    /// confirmation surface mounts).
    ///
    /// Semantics:
    ///   - Per-sponsor resolution succeeded → `activeSponsorId = sponsorId`
    ///   - Per-sponsor fell back to primary (unknown id / no commerce block) →
    ///     `activeSponsorId = configuration.primarySponsor?.id`
    ///   - `clear()` was called → nil
    public private(set) var activeSponsorId: Int?

    private init() {}

    public func client(configuration: VioConfiguration = .shared) throws -> SdkClient {
        guard let resolvedURL = URL(string: configuration.resolvedCommerceGraphQLURL) else {
            throw SdkException(
                "Invalid commerce GraphQL URL: \(configuration.resolvedCommerceGraphQLURL)",
                code: "INVALID_COMMERCE_GRAPHQL_URL")
        }
        let resolvedApiKey = configuration.resolvedCommerceApiKey
        // Bootstrap key (no per-sponsor scope) → the active sponsor is the
        // primary by definition. Mirrors what `client(forSponsorId: nil)`
        // resolves to, so consumers that read activeSponsorId always see the
        // sponsor whose key is in use.
        activeSponsorId = configuration.primarySponsor?.id
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
            // Fallback path inside `client(configuration:)` already sets
            // activeSponsorId to the primary's id — no need to set it here.
            return try client(configuration: configuration)
        }
        guard let resolvedURL = URL(string: configuration.resolvedCommerceGraphQLURL) else {
            throw SdkException(
                "Invalid commerce GraphQL URL: \(configuration.resolvedCommerceGraphQLURL)",
                code: "INVALID_COMMERCE_GRAPHQL_URL")
        }

        // Per-sponsor resolution succeeded — this is the single source of
        // truth for "who are we transacting with". Confirmation sheet reads it.
        activeSponsorId = sponsorId

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
        activeSponsorId = nil
    }
}
