//
//  MatchModels.swift
//  VioCastingUI
//

import Foundation
import VioCore

// MARK: - Match Model
public struct Match: Identifiable {
    public let id: UUID
    public let homeTeam: Team
    public let awayTeam: Team
    public let title: String
    public let subtitle: String
    public let competition: String
    public let venue: String
    public let commentator: String?
    public let isLive: Bool
    public let backgroundImage: String
    public let availability: MatchAvailability
    public let relatedContent: [RelatedTeam]
    public let campaignLogo: String?

    public init(
        id: UUID = UUID(),
        homeTeam: Team,
        awayTeam: Team,
        title: String,
        subtitle: String,
        competition: String,
        venue: String,
        commentator: String?,
        isLive: Bool,
        backgroundImage: String,
        availability: MatchAvailability,
        relatedContent: [RelatedTeam],
        campaignLogo: String?
    ) {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.title = title
        self.subtitle = subtitle
        self.competition = competition
        self.venue = venue
        self.commentator = commentator
        self.isLive = isLive
        self.backgroundImage = backgroundImage
        self.availability = availability
        self.relatedContent = relatedContent
        self.campaignLogo = campaignLogo
    }
}

// MARK: - Team Model
public struct Team: Identifiable {
    public let id: UUID
    public let name: String
    public let shortName: String
    public let logo: String

    public init(id: UUID = UUID(), name: String, shortName: String, logo: String) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.logo = logo
    }
}

// MARK: - Match Availability
public enum MatchAvailability {
    case available
    case availableUntil(date: String)
    case upcoming(date: String)

    public var title: String {
        switch self {
        case .available:
            return "Tilgjengelighet"
        case .availableUntil:
            return "Tilgjengelighet"
        case .upcoming:
            return "Kommer snart"
        }
    }

    public var description: String {
        switch self {
        case .available:
            return "Tilgjengelig nå"
        case .availableUntil:
            return "Tilgjengelig lenger enn ett år"
        case .upcoming(let date):
            return date
        }
    }
}

// MARK: - Related Team
public struct RelatedTeam: Identifiable {
    public let id: UUID
    public let team: Team
    public let description: String?

    public init(id: UUID = UUID(), team: Team, description: String?) {
        self.id = id
        self.team = team
        self.description = description
    }
}

// MARK: - BroadcastContext Helper

extension Match: BroadcastContextProvider {
    /// Creates a BroadcastContext from Match for SDK integration
    public func toBroadcastContext(channelId: Int? = nil) -> BroadcastContext {
        let broadcastId = generateBroadcastId()
        return BroadcastContext(
            broadcastId: broadcastId,
            broadcastName: title,
            startTime: nil,
            channelId: channelId,
            metadata: [
                "competition": competition,
                "venue": venue,
                "homeTeam": homeTeam.name,
                "awayTeam": awayTeam.name
            ]
        )
    }

    @available(*, deprecated, renamed: "toBroadcastContext(channelId:)")
    public func toMatchContext(channelId: Int? = nil) -> MatchContext {
        return toBroadcastContext(channelId: channelId)
    }

    private func generateBroadcastId() -> String {
        if title.contains("Barcelona") && title.contains("PSG") {
            return "barcelona-psg-2025-01-23"
        }
        if title.contains("Real Madrid") && title.contains("Barcelona") {
            return "real-madrid-barcelona-2025-01-24"
        }
        let homeTeamSlug = homeTeam.name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "fc", with: "")
            .trimmingCharacters(in: .whitespaces)
        let awayTeamSlug = awayTeam.name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "fc", with: "")
            .trimmingCharacters(in: .whitespaces)
        let competitionSlug = competition.lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(homeTeamSlug)-\(awayTeamSlug)-\(competitionSlug)".lowercased()
    }
}

// MARK: - Mock Data
extension Match {
    public static let barcelonaPSG = Match(
        homeTeam: Team(
            name: "FC Barcelona",
            shortName: "Barcelona",
            logo: "barcelona_logo"
        ),
        awayTeam: Team(
            name: "Paris Saint-Germain",
            shortName: "PSG",
            logo: "psg_logo"
        ),
        title: "Barcelona - PSG",
        subtitle: "UEFA Champions League",
        competition: "Champions League",
        venue: "Camp Nou",
        commentator: "Magnus Drivenes",
        isLive: true,
        backgroundImage: "img1",
        availability: .available,
        relatedContent: [
            RelatedTeam(team: Team(name: "FC Barcelona", shortName: "Barcelona", logo: "barcelona_logo"), description: nil),
            RelatedTeam(team: Team(name: "Paris Saint-Germain", shortName: "PSG", logo: "psg_logo"), description: nil)
        ],
        campaignLogo: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Adidas_logo.png/800px-Adidas_logo.png"
    )

    public static let realMadridBarcelona = Match(
        homeTeam: Team(name: "Real Madrid", shortName: "Madrid", logo: "madrid_logo"),
        awayTeam: Team(name: "FC Barcelona", shortName: "Barcelona", logo: "barcelona_logo"),
        title: "Real Madrid - Barcelona",
        subtitle: "La Liga",
        competition: "La Liga",
        venue: "Santiago Bernabéu",
        commentator: "Camino López",
        isLive: false,
        backgroundImage: "img1",
        availability: .upcoming(date: "24. januar 20:00"),
        relatedContent: [
            RelatedTeam(team: Team(name: "Real Madrid", shortName: "Madrid", logo: "madrid_logo"), description: nil),
            RelatedTeam(team: Team(name: "FC Barcelona", shortName: "Barcelona", logo: "barcelona_logo"), description: nil)
        ],
        campaignLogo: nil
    )

    public static let mockMatches: [Match] = [
        barcelonaPSG,
        realMadridBarcelona,
        Match(
            homeTeam: Team(name: "Manchester City", shortName: "City", logo: "city_logo"),
            awayTeam: Team(name: "Real Madrid", shortName: "Madrid", logo: "madrid_logo"),
            title: "Man City - Real Madrid",
            subtitle: "UEFA Champions League • Fotball",
            competition: "UEFA Champions League",
            venue: "Etihad Stadium",
            commentator: "Øyvind Alsaker",
            isLive: true,
            backgroundImage: "img1",
            availability: .available,
            relatedContent: [],
            campaignLogo: nil
        )
    ]
}
