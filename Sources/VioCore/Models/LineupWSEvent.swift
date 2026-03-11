//
//  LineupWSEvent.swift
//  VioCore
//
//  WebSocket event model for lineup_show events.
//  Sent by backend when showLineup is enabled for the broadcast.
//
//  The backend calculates all timestamps — the SDK uses them directly.
//  This avoids assumptions about when the stream started relative to kickoff.
//

import Foundation

/// Received via WebSocket when backend triggers lineup display.
public struct LineupShowEvent: Decodable {

    /// Seconds into the video where the lineup card should appear.
    /// Calculated by backend as: kickoffVideoTimestamp - leadTimeSeconds.
    /// Example: stream starts 20 min before kickoff, lead = 10 min
    ///   → kickoffVideoTimestamp = 1200, lineupVideoTimestamp = 600
    public let videoTimestamp: TimeInterval

    /// Seconds into the video where kickoff occurs.
    /// = Sportmonks starting_at − actual broadcastStartedAt
    /// Used by SDK to calibrate preMatchDuration in UnifiedTimelineManager.
    /// Optional: if nil, preMatchDuration is not adjusted.
    public let kickoffVideoTimestamp: TimeInterval?

    /// The externalId / contentId of the broadcast.
    public let broadcastId: String?

    /// How many seconds before kickoff the lineup is being shown.
    /// Informational — backend uses this to compute videoTimestamp.
    public let leadTimeSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case videoTimestamp
        case kickoffVideoTimestamp
        case broadcastId
        case leadTimeSeconds
    }
}
