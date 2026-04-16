import Foundation

/// Central retry/fallback policy used by runtime orchestration flows.
public enum VioRuntimeRetryPolicy {
    /// Current campaign REST fallback only retries once with dev endpoints.
    public static let campaignRestFallbackRetryCount = 1

    /// Retry count for commerce bootstrap before surfacing degraded state.
    public static let commerceBootstrapRetryCount = 1

    /// WebSocket reconnect attempts before giving up.
    public static let webSocketMaxReconnectAttempts = 5

    /// Upper bound for exponential reconnect delay.
    public static let webSocketMaxBackoffSeconds = 30.0

    /// Ordered Stripe intent attempts for Apple Pay key provisioning.
    public static let applePayStripeIntentReturnEphemeralKeyModes: [Bool?] = [false, nil]

    /// Payment confirmation retries are intentionally disabled by default.
    public static let confirmPaymentRetryCount = 0
}
