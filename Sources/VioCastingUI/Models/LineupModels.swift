//
//  LineupModels.swift
//  VioCastingUI
//
//  Models for match lineup data fetched from Vio backend (sourced from Sportmonks)
//

import Foundation

// MARK: - Lineup Response

public struct MatchLineupResponse: Codable {
    public let fixtureId: Int?
    public let available: Bool
    public let message: String?
    public let home: LineupTeam?
    public let away: LineupTeam?

    public var isEmpty: Bool { !available || (home == nil && away == nil) }
}

public struct LineupTeam: Codable, Identifiable {
    public var id: Int { teamId }
    public let teamId: Int
    public let teamName: String
    public let teamLogo: String?
    public let formation: String?
    public let players: [LineupPlayer]

    public var starters: [LineupPlayer] { players }
}

public struct LineupPlayer: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let jerseyNumber: Int?
    public let position: String  // "goalkeeper" | "defender" | "midfielder" | "forward"

    public var positionEmoji: String {
        switch position {
        case "goalkeeper": return "🧤"
        case "defender":   return "🛡️"
        case "midfielder": return "⚙️"
        default:           return "⚽"
        }
    }
}

// MARK: - Lineup State

public enum LineupState {
    case idle
    case loading
    case unavailable(String)   // "Lineup not yet available"
    case loaded(MatchLineupResponse)
    case error(String)
}
