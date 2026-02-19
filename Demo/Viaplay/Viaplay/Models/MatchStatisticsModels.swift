//
//  MatchStatisticsModels.swift
//  Viaplay
//
//  Modelos para estadísticas y datos de partidos
//

import Foundation
import VioCastingUI

// MARK: - League Table

struct LeagueTable: Identifiable {
    let id = UUID()
    let season: String
    let teams: [TeamStanding]
}

struct TeamStanding: Identifiable {
    let id = UUID()
    let rank: Int
    let team: Team
    let gamesPlayed: Int
    let wins: Int
    let draws: Int
    let losses: Int
    let goalDifference: Int
    let points: Int
    let form: [MatchResult] // Últimos 5 resultados
    
    enum MatchResult: String {
        case win = "W"
        case draw = "D"
        case loss = "L"
        
        var color: String {
            switch self {
            case .win: return "green"
            case .draw: return "gray"
            case .loss: return "red"
            }
        }
    }
}

// MARK: - Match Statistics

struct MatchStatistics {
    let homeTeam: Team
    let awayTeam: Team
    let stats: [Statistic]
}

struct Statistic: Identifiable {
    let id = UUID()
    let name: String
    let homeValue: Double
    let awayValue: Double
    let unit: String? // "%", "min", etc.
    
    var homePercentage: Double {
        let total = homeValue + awayValue
        return total > 0 ? (homeValue / total) * 100 : 50
    }
    
    var awayPercentage: Double {
        return 100 - homePercentage
    }
}

// MARK: - Match Timeline

struct MatchTimeline {
    let events: [MatchEvent]
}

struct MatchEvent: Identifiable {
    let id = UUID()
    let minute: Int
    let type: EventType
    let player: String?
    let team: TeamSide
    let description: String?
    let score: String? // "1-0"
    
    enum EventType: Equatable {
        case goal
        case yellowCard
        case redCard
        case substitution(on: String, off: String)
        case kickOff
        case halfTime
        case fullTime
        case penalty
        case ownGoal
    }
    
    enum TeamSide {
        case home
        case away
    }
}

// MARK: - Team Lineup

struct TeamLineup {
    let team: Team
    let formation: String // "4-3-3"
    let players: [Player]
    let substitutes: [Player]
    let coach: String?
}

struct Player: Identifiable {
    let id = UUID()
    let number: Int
    let name: String
    let position: PlayerPosition
    let isCaptain: Bool
    let isSubstitute: Bool
    
    enum PlayerPosition {
        case goalkeeper
        case defender
        case midfielder
        case forward
        
        var displayName: String {
            switch self {
            case .goalkeeper: return "GK"
            case .defender: return "DF"
            case .midfielder: return "MF"
            case .forward: return "FW"
            }
        }
    }
}

// MARK: - Mock Data

extension LeagueTable {
    static let premierLeague: LeagueTable = LeagueTable(
        season: "2024/25",
        teams: [
            TeamStanding(
                rank: 1,
                team: Team(name: "Arsenal", shortName: "Arsenal", logo: "arsenal_logo"),
                gamesPlayed: 16,
                wins: 11,
                draws: 3,
                losses: 2,
                goalDifference: 20,
                points: 36,
                form: [.win, .win, .draw, .win, .win]
            ),
            TeamStanding(
                rank: 2,
                team: Team(name: "Manchester City", shortName: "Man City", logo: "city_logo"),
                gamesPlayed: 16,
                wins: 11,
                draws: 1,
                losses: 4,
                goalDifference: 22,
                points: 34,
                form: [.win, .win, .loss, .win, .draw]
            ),
            TeamStanding(
                rank: 3,
                team: Team(name: "Aston Villa", shortName: "Aston Villa", logo: "villa_logo"),
                gamesPlayed: 16,
                wins: 10,
                draws: 3,
                losses: 3,
                goalDifference: 8,
                points: 33,
                form: [.win, .draw, .win, .win, .loss]
            ),
            TeamStanding(
                rank: 4,
                team: Team(name: "Chelsea", shortName: "Chelsea", logo: "chelsea_logo"),
                gamesPlayed: 16,
                wins: 8,
                draws: 4,
                losses: 4,
                goalDifference: 12,
                points: 28,
                form: [.win, .draw, .win, .loss, .win]
            ),
            TeamStanding(
                rank: 5,
                team: Team(name: "Crystal Palace", shortName: "Crystal Palace", logo: "palace_logo"),
                gamesPlayed: 16,
                wins: 7,
                draws: 5,
                losses: 4,
                goalDifference: 5,
                points: 26,
                form: [.draw, .win, .loss, .win, .draw]
            ),
            TeamStanding(
                rank: 8,
                team: Team(name: "Manchester United", shortName: "Man Utd", logo: "manutd_logo"),
                gamesPlayed: 15,
                wins: 7,
                draws: 4,
                losses: 4,
                goalDifference: 4,
                points: 25,
                form: [.win, .loss, .draw, .win, .win]
            )
        ]
    )
}

extension MatchStatistics {
    static func mock(for match: Match) -> MatchStatistics {
        return MatchStatistics(
            homeTeam: match.homeTeam,
            awayTeam: match.awayTeam,
            stats: [
                Statistic(name: "Possession", homeValue: 56.3, awayValue: 43.7, unit: "%"),
                Statistic(name: "Passes", homeValue: 105, awayValue: 84, unit: nil),
                Statistic(name: "Accurate passes", homeValue: 84, awayValue: 52, unit: nil),
                Statistic(name: "Offsides", homeValue: 0, awayValue: 1, unit: nil),
                Statistic(name: "Shots", homeValue: 12, awayValue: 0, unit: nil),
                Statistic(name: "Shots on goal", homeValue: 3, awayValue: 0, unit: nil),
                Statistic(name: "Saves", homeValue: 0, awayValue: 2, unit: nil),
                Statistic(name: "Corners", homeValue: 3, awayValue: 1, unit: nil),
                Statistic(name: "Throw-ins", homeValue: 3, awayValue: 3, unit: nil),
                Statistic(name: "Clearances", homeValue: 9, awayValue: 7, unit: nil)
            ]
        )
    }
}

extension MatchTimeline {
    static func mock(for match: Match) -> MatchTimeline {
        return MatchTimeline(
            events: [
                MatchEvent(
                    minute: 0,
                    type: .kickOff,
                    player: nil,
                    team: .home,
                    description: nil,
                    score: "0-0"
                ),
                MatchEvent(
                    minute: 5,
                    type: .substitution(on: "A. Scott", off: "T. Adams"),
                    player: "A. Scott",
                    team: .away,
                    description: nil,
                    score: nil
                ),
                MatchEvent(
                    minute: 13,
                    type: .goal,
                    player: "A. Diallo",
                    team: .home,
                    description: nil,
                    score: "1-0"
                ),
                MatchEvent(
                    minute: 18,
                    type: .yellowCard,
                    player: "Casemiro",
                    team: .home,
                    description: nil,
                    score: nil
                ),
                MatchEvent(
                    minute: 25,
                    type: .yellowCard,
                    player: "M. Tavernier",
                    team: .away,
                    description: nil,
                    score: nil
                )
            ]
        )
    }
}

extension TeamLineup {
    static func mockHome(for match: Match) -> TeamLineup {
        return TeamLineup(
            team: match.homeTeam,
            formation: "4-3-3",
            players: [
                Player(number: 31, name: "S. Lammens", position: .goalkeeper, isCaptain: false, isSubstitute: false),
                Player(number: 15, name: "L. Yoro", position: .defender, isCaptain: false, isSubstitute: false),
                Player(number: 26, name: "A. Heaven", position: .defender, isCaptain: false, isSubstitute: false),
                Player(number: 23, name: "L. Shaw", position: .defender, isCaptain: false, isSubstitute: false),
                Player(number: 16, name: "A. Diallo", position: .midfielder, isCaptain: false, isSubstitute: false),
                Player(number: 18, name: "Casemiro", position: .midfielder, isCaptain: true, isSubstitute: false),
                Player(number: 8, name: "Bruno Fernandes", position: .midfielder, isCaptain: false, isSubstitute: false),
                Player(number: 2, name: "Diogo Dalot", position: .midfielder, isCaptain: false, isSubstitute: false),
                Player(number: 19, name: "B. Mbeumo", position: .forward, isCaptain: false, isSubstitute: false),
                Player(number: 10, name: "Matheus Cunha", position: .forward, isCaptain: false, isSubstitute: false),
                Player(number: 7, name: "M. Mount", position: .forward, isCaptain: false, isSubstitute: false)
            ],
            substitutes: [
                Player(number: 1, name: "A. Onana", position: .goalkeeper, isCaptain: false, isSubstitute: true),
                Player(number: 5, name: "H. Maguire", position: .defender, isCaptain: false, isSubstitute: true)
            ],
            coach: "Erik ten Hag"
        )
    }
    
    static func mockAway(for match: Match) -> TeamLineup {
        return TeamLineup(
            team: match.awayTeam,
            formation: "4-4-2",
            players: [
                Player(number: 9, name: "Evanilson", position: .goalkeeper, isCaptain: false, isSubstitute: false),
                Player(number: 24, name: "A. Semenyo", position: .defender, isCaptain: false, isSubstitute: false),
                Player(number: 19, name: "J. Kluivert", position: .defender, isCaptain: false, isSubstitute: false),
                Player(number: 20, name: "Álex Jiménez", position: .defender, isCaptain: false, isSubstitute: false),
                Player(number: 12, name: "T. Adams", position: .midfielder, isCaptain: false, isSubstitute: false),
                Player(number: 16, name: "M. Tavernier", position: .midfielder, isCaptain: true, isSubstitute: false)
            ],
            substitutes: [
                Player(number: 1, name: "N. Neto", position: .goalkeeper, isCaptain: false, isSubstitute: true)
            ],
            coach: "Andoni Iraola"
        )
    }
}

