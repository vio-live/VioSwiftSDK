import Foundation

// MARK: - GET /v1/sdk/config (full snapshot)

/// Typed snapshot of ``GET /v1/sdk/config``. Unknown JSON keys are ignored by `JSONDecoder`.
/// Use ``VioConfiguration/lastSdkConfigRawData`` for the exact server payload when you need fields not modeled here.
public struct SdkRemoteConfig: Codable, Sendable, Equatable {
    public let sdkVersion: String?
    public let clientApp: ClientApp?
    public let endpoints: Endpoints?
    public let features: Features?
    public let commerce: Commerce?
    public let theme: Theme?
    public let markets: [Market]?
    public let campaign: Campaign?

    public struct ClientApp: Codable, Sendable, Equatable {
        public let id: Int?
        public let name: String?
        public let apiKey: String?
    }

    public struct Endpoints: Codable, Sendable, Equatable {
        public let restBase: String?
        public let webSocketBase: String?
        public let commerceGraphQL: String?
    }

    public struct Features: Codable, Sendable, Equatable {
        public let engagement: Bool?
        public let adPlacements: Bool?
        public let commerce: Bool?
        public let lineup: Bool?
    }

    public struct Commerce: Codable, Sendable, Equatable {
        public let apiKey: String?
        public let endpoint: String?

        enum CodingKeys: String, CodingKey {
            case apiKey
            case api_key
            case endpoint
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let camel = try c.decodeIfPresent(String.self, forKey: .apiKey)
            let snake = try c.decodeIfPresent(String.self, forKey: .api_key)
            let merged = [camel, snake].compactMap { $0 }.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            apiKey = merged
            endpoint = try c.decodeIfPresent(String.self, forKey: .endpoint)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(apiKey, forKey: .apiKey)
            try c.encodeIfPresent(endpoint, forKey: .endpoint)
        }
    }

    public struct Theme: Codable, Sendable, Equatable {
        public let primaryColor: String?
        public let accentColor: String?
    }

    /// Loose market row: extra keys from the backend are ignored.
    public struct Market: Codable, Sendable, Equatable {
        public let id: Int?
        public let code: String?
        public let name: String?
    }

    public struct Campaign: Codable, Sendable, Equatable {
        public let id: Int?
        public let campaignId: Int?
        public let campaignName: String?
        public let campaignLogo: String?
        public let isActive: Bool?
        public let isPaused: Bool?
        public let startDate: String?
        public let endDate: String?

        enum CodingKeys: String, CodingKey {
            case id
            case campaignId
            case campaignName
            case campaignLogo
            case isActive
            case isPaused
            case startDate
            case endDate
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decodeIfPresent(Int.self, forKey: .id)
            campaignId = try c.decodeIfPresent(Int.self, forKey: .campaignId)
            campaignName = try c.decodeIfPresent(String.self, forKey: .campaignName)
            campaignLogo = try c.decodeIfPresent(String.self, forKey: .campaignLogo)
            isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive)
            isPaused = Self.decodeLooseBool(c, key: .isPaused)
            startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
            endDate = try c.decodeIfPresent(String.self, forKey: .endDate)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(id, forKey: .id)
            try c.encodeIfPresent(campaignId, forKey: .campaignId)
            try c.encodeIfPresent(campaignName, forKey: .campaignName)
            try c.encodeIfPresent(campaignLogo, forKey: .campaignLogo)
            try c.encodeIfPresent(isActive, forKey: .isActive)
            try c.encodeIfPresent(isPaused, forKey: .isPaused)
            try c.encodeIfPresent(startDate, forKey: .startDate)
            try c.encodeIfPresent(endDate, forKey: .endDate)
        }

        private static func decodeLooseBool(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Bool? {
            if let b = try? c.decodeIfPresent(Bool.self, forKey: key) { return b }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if t == "true" || t == "1" || t == "yes" { return true }
                if t == "false" || t == "0" || t == "no" { return false }
            }
            return nil
        }
    }
}

// MARK: - Commerce bootstrap (same contract as CampaignManager)

extension SdkRemoteConfig {
    /// Pares `(apiKey, graphQLURL)` para ``VioConfiguration/applySdkBootstrapCommerce(apiKey:graphQLURL:)`` según `features.commerce` y bloque `commerce` / `endpoints`.
    public func commerceCredentialsForBootstrap() -> (apiKey: String?, graphQLURL: String?) {
        let key = commerce?.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyNonEmpty = (key?.isEmpty == false) ? key : nil
        let gqlForApply: String? = {
            guard keyNonEmpty != nil else { return nil }
            let g = commerce?.endpoint ?? endpoints?.commerceGraphQL
            let t = g?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (t?.isEmpty == false) ? t : nil
        }()
        let featCommerce = features?.commerce
        let applyKey: String?
        let applyGql: String?
        switch featCommerce {
        case .some(false):
            applyKey = nil
            applyGql = nil
        case .some(true):
            if let k = keyNonEmpty {
                applyKey = k
                applyGql = gqlForApply
            } else {
                applyKey = nil
                applyGql = nil
            }
        case .none:
            if let k = keyNonEmpty {
                applyKey = k
                applyGql = gqlForApply
            } else {
                applyKey = nil
                applyGql = nil
            }
        }
        return (applyKey, applyGql)
    }
}
