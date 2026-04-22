import Foundation

/// Sponsor descriptor as exposed to host apps via ``VioConfiguration``.
/// Mirrors the shape of `primarySponsor` / `secondarySponsors` entries in `GET /v2/sdk/config`.
///
/// A sponsor with `commerce == nil` is a **visual-only** sponsor — its logo/branding can be
/// shown but the SDK will not initiate a purchase flow for it.
public struct VioSponsor: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let logoUrl: String?
    public let primaryColor: String?
    public let secondaryColor: String?
    public let commerce: CommerceBlock?

    /// Per-sponsor Commerce credentials. Each sponsor is a distinct Commerce merchant with
    /// its own `apiKey`, optional `channelId`, and the list of `paymentMethods` it accepts.
    public struct CommerceBlock: Codable, Equatable, Sendable {
        public let apiKey: String
        public let channelId: String?
        public let paymentMethods: [String]

        public init(apiKey: String, channelId: String? = nil, paymentMethods: [String] = []) {
            self.apiKey = apiKey
            self.channelId = channelId
            self.paymentMethods = paymentMethods
        }
    }

    public init(
        id: Int,
        name: String,
        logoUrl: String? = nil,
        primaryColor: String? = nil,
        secondaryColor: String? = nil,
        commerce: CommerceBlock? = nil
    ) {
        self.id = id
        self.name = name
        self.logoUrl = logoUrl
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.commerce = commerce
    }
}

// MARK: - Internal mapping from `SdkBootstrapResponse.SponsorBlock` → `VioSponsor`

extension VioSponsor {
    internal init?(bootstrap: SdkBootstrapResponse.SponsorBlock?) {
        guard let s = bootstrap else { return nil }
        let mappedCommerce: CommerceBlock? = {
            guard let c = s.commerce, let key = c.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
                return nil
            }
            return CommerceBlock(
                apiKey: key,
                channelId: c.channelId,
                paymentMethods: c.paymentMethods ?? []
            )
        }()
        self.init(
            id: s.id,
            name: s.name,
            logoUrl: s.logoUrl,
            primaryColor: s.primaryColor,
            secondaryColor: s.secondaryColor,
            commerce: mappedCommerce
        )
    }
}
