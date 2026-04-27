import Foundation

/// Sponsor descriptor as exposed to host apps via ``VioConfiguration``.
/// Mirrors the shape of `primarySponsor` / `secondarySponsors` entries in `GET /v2/mobile/config`.
///
/// A sponsor with `commerce == nil` is a **visual-only** sponsor — its logo/branding can be
/// shown but the SDK will not initiate a purchase flow for it.
///
/// ## Logo vs Avatar (legacy naming, both are the brand's logo)
/// `logoUrl` and `avatarUrl` both point at the sponsor's logo, just in
/// different formats. Naming is legacy — neither field is an avatar in
/// the social-media sense (this is brand iconography, not a user pic).
///
///   - `logoUrl`   → primary / wide / official logo. Often vector (SVG)
///                   for display on full-screen surfaces. **Cannot be
///                   rendered by SwiftUI's `AsyncImage` when SVG.**
///   - `avatarUrl` → square / raster / inline mark. Always renders
///                   cleanly in `AsyncImage`. Use this for carousel
///                   headers, badges, product cards, overlays.
///
/// **Use ``renderableLogoUrl``** for any inline UI rendering — it prefers
/// `avatarUrl` and falls back to `logoUrl`, avoiding the SVG-not-decoded
/// failure mode silently.
public struct VioSponsor: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    /// Wide horizontal logo. Often a vector file (`.svg`) which SwiftUI's
    /// `AsyncImage` cannot decode natively. **Prefer `avatarUrl`** for
    /// in-line UI rendering and fall back to `logoUrl` if avatar is nil.
    public let logoUrl: String?
    /// Square / raster brand mark (PNG/JPEG). Decodes cleanly in
    /// `AsyncImage`. Use this in carousel headers, badges, and inline
    /// branding strips. Mirrors `sponsors.avatar_url` on the backend.
    public let avatarUrl: String?
    public let primaryColor: String?
    public let secondaryColor: String?
    public let commerce: CommerceBlock?

    /// Best-effort URL for inline UI rendering. Avatar (raster) preferred,
    /// falls back to logo (which may be SVG and silently fail in
    /// AsyncImage). Hosts wanting full SVG support can read `logoUrl`
    /// directly and route through their own renderer.
    public var renderableLogoUrl: String? {
        avatarUrl ?? logoUrl
    }

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
        avatarUrl: String? = nil,
        primaryColor: String? = nil,
        secondaryColor: String? = nil,
        commerce: CommerceBlock? = nil
    ) {
        self.id = id
        self.name = name
        self.logoUrl = logoUrl
        self.avatarUrl = avatarUrl
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
            avatarUrl: s.avatarUrl,
            primaryColor: s.primaryColor,
            secondaryColor: s.secondaryColor,
            commerce: mappedCommerce
        )
    }
}
