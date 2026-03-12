import Foundation

// MARK: - Remote SDK Config
// Response model for GET /v1/sdk/config?apiKey=<apiKey>
// This endpoint returns everything the SDK needs to operate — no vio-config.json required.

public struct RemoteSDKConfig: Codable {
    public let clientApp: RemoteClientApp?
    public let endpoints: RemoteEndpoints?
    public let features: RemoteFeatures?
    public let commerce: RemoteCommerceConfig?
    public let theme: RemoteThemeConfig?
    public let markets: [String]?
}

public struct RemoteClientApp: Codable {
    public let id: Int
    public let name: String
    public let apiKey: String
}

public struct RemoteEndpoints: Codable {
    public let restBase: String?
    public let webSocketBase: String?
    public let commerceGraphQL: String?
}

public struct RemoteFeatures: Codable {
    public let engagement: Bool?
    public let adPlacements: Bool?
    public let commerce: Bool?
    public let lineup: Bool?
}

public struct RemoteCommerceConfig: Codable {
    public let apiKey: String?
    public let endpoint: String?
}

public struct RemoteThemeConfig: Codable {
    public let primaryColor: String?
    public let accentColor: String?
    public let backgroundColor: String?
}
