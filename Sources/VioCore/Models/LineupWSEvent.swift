//
//  LineupWSEvent.swift
//  VioCore
//
//  WebSocket event model for lineup_show events.
//  Sent by backend ~10 min before kickoff when showLineup is enabled for the broadcast.
//

import Foundation

/// Received via WebSocket when backend triggers lineup display.
public struct LineupShowEvent: Decodable {
    /// When to place the lineup card in the video timeline (seconds from stream start).
    /// Negative values = before kickoff (e.g. -600 = 10 min before).
    public let videoTimestamp: TimeInterval
    public let broadcastId: String?

    enum CodingKeys: String, CodingKey {
        case videoTimestamp
        case broadcastId
    }
}
