import Foundation

/// SDK feature module identifier.
///
/// The Vio backend partitions WS events into module buckets so a host
/// app that only uses, say, placements does not have to receive (or
/// process) engagement events. The SDK declares which buckets it cares
/// about via `{type:"subscribe", modules:[…]}` right after the
/// `identify` handshake; the server filters every emit by the
/// receiving socket's subscription set.
///
/// Default policy (`VioConfiguration.shared.enabledModules`):
///   - `.placements`   — on (current production usage)
///   - `.cartIntent`   — on (current production usage; Apple TV → iOS)
///   - `.engagement`   — off (wire when polls/contests/chat ship)
///   - `.broadcast`    — off (wire when lineup/score/stats ship)
///
/// Host apps that don't need a module can drop it via
/// `VioConfiguration.shared.disableModule(.cartIntent)` etc., and the
/// next WS connect will subscribe with the smaller set.
///
/// Sprint 2026-04-28 PM. See server/events/types.ts for the canonical
/// list (kept in sync deliberately).
public enum VioModule: String, Codable, CaseIterable, Hashable {
    /// Placement lifecycle events: status changes (pause/resume),
    /// config updates (productIds, title, layout), and multi-sponsor
    /// rotation swaps. Scope: campaign.
    case placements

    /// Polls, contests, chat, lineup, score, stats. Scope: broadcast.
    /// **Future** — backend handlers do not yet emit on this module.
    case engagement

    /// Generic broadcast metadata events (start, end, viewer count
    /// updates, etc.). Scope: broadcast. **Future**.
    case broadcast

    /// Direct user-targeted cart_intent events from Apple TV → iOS.
    /// Scope: user. Migration target — currently uses direct user
    /// routing, will move to outbox in a follow-up sprint.
    case cartIntent = "cart_intent"
}
