import Foundation

/// Metadata for a `cart_intent` delivered over the campaign WebSocket (for logging / demo hooks).
public struct CartIntentWebSocketDeliveryInfo: Sendable, Equatable {
    public let socketConnected: Bool
    public let campaignSocketId: Int
    /// e.g. `skipped(foregroundAppActivePolicy)`, `enqueued`.
    public let localNotificationSummary: String
    /// Short preview of redacted pretty JSON (for one-line app logs).
    public let rawJSONRedactedPreview: String

    public init(
        socketConnected: Bool,
        campaignSocketId: Int,
        localNotificationSummary: String,
        rawJSONRedactedPreview: String
    ) {
        self.socketConnected = socketConnected
        self.campaignSocketId = campaignSocketId
        self.localNotificationSummary = localNotificationSummary
        self.rawJSONRedactedPreview = rawJSONRedactedPreview
    }
}
