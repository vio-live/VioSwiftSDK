import Foundation

/// Discriminated union of every event the SDK can receive from a TV (or any
/// other secondary surface) that targets the **individual user's mobile app**.
///
/// Both transports converge on this type before any state is updated:
///
/// ```text
///   ┌──── WebSocket ───── CampaignWebSocketManager.onCartIntent ─────┐
///   │                                                                │
///   │                                                                ▼
///   │                                                  CampaignManager.dispatch(_:source:)
///   │                                                                ▲
///   │                                                                │
///   └──── APNs ─── UNUserNotificationCenterDelegate ────              │
///                                                      ─ handlePushNotificationUserInfo ─┘
/// ```
///
/// Today only `cart_intent` rides this path. To add a new TV-originated,
/// user-targeted event:
///
///   1. Define the typed model (e.g., `PollResultEvent`).
///   2. Add a case here (e.g., `case pollResult(PollResultEvent)`).
///   3. Add the receive-side state to `CampaignManager` (e.g., a new
///      `@Published var activePollResult: PollResultEvent?` + a private
///      `publishPollResultIfChanged(_:channel:)` that mirrors the existing
///      cart-intent dedup pattern).
///   4. Extend the `switch` in `CampaignManager.dispatch(_:source:)` with the
///      new case so both transports route through the same dispatcher.
///   5. Wire the WS adapter in `CampaignManager.bindWebSocketCallbacks()` and
///      the APNs adapter in `handlePushNotificationUserInfo` to wrap the
///      decoded event in the new case.
///
/// The dedup, the logging channel, and the publisher are concerns of the
/// per-event publisher — `dispatch(_:source:)` only does the routing.
public enum IncomingTVEvent {
    case cartIntent(CartIntentEvent)
    // case pollResult(PollResultEvent)        — future
    // case scoreUpdate(ScoreUpdateEvent)      — future
    // case contestWinner(ContestWinnerEvent)  — future
}

/// Where an `IncomingTVEvent` was delivered from. Used for the dedup channel
/// label and for telemetry so we can distinguish a WS dispatch from a push
/// dispatch when investigating duplicates or delivery latency.
public enum TVEventSource: String {
    /// Delivered via the campaign WebSocket (foreground app, same node or
    /// Redis cluster forward).
    case webSocket = "ws"
    /// Delivered via the OS notification center (real APNs push from partner
    /// mock or backend direct APNs fallback). Note: the SDK no longer
    /// self-schedules local `UNNotificationRequest`s — anything arriving via
    /// this source is now genuinely a remote push.
    case push = "push"
}
