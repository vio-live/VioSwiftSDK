import Foundation

// MARK: - Match
struct TV2Match: Identifiable {
    let id = UUID()
    let homeTeam: TV2Team
    let awayTeam: TV2Team
    let title: String
    let subtitle: String
    let competition: String
    let venue: String
    let commentator: String?
    let isLive: Bool
    let backgroundImage: String
    let availability: TV2MatchAvailability
    let relatedContent: [TV2RelatedTeam]
    let campaignLogo: String?
    let contentId: String?
    let country: String
    
    init(
        homeTeam: TV2Team,
        awayTeam: TV2Team,
        title: String,
        subtitle: String,
        competition: String,
        venue: String,
        commentator: String? = nil,
        isLive: Bool = false,
        backgroundImage: String,
        availability: TV2MatchAvailability,
        relatedContent: [TV2RelatedTeam] = [],
        campaignLogo: String? = nil,
        contentId: String? = nil,
        country: String = "NO"
    ) {
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
        self.contentId = contentId
        self.country = country
    }
}

// MARK: - Team
struct TV2Team: Identifiable {
    let id = UUID()
    let name: String
    let shortName: String
    let logo: String
}

// MARK: - Match Availability
enum TV2MatchAvailability {
    case available
    case availableUntil(date: String)
    case upcoming(date: String)
    
    var title: String {
        switch self {
        case .available:
            return "Tilgjengelighet"
        case .availableUntil:
            return "Tilgjengelighet"
        case .upcoming:
            return "Kommer snart"
        }
    }
    
    var description: String {
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
struct TV2RelatedTeam: Identifiable {
    let id = UUID()
    let team: TV2Team
    let description: String?
}

// MARK: - Mock Data
extension TV2Match {
    static let barcelonaPSG = TV2Match(
        homeTeam: TV2Team(
            name: "FC Barcelona",
            shortName: "Barcelona",
            logo: "barcelona_logo"
        ),
        awayTeam: TV2Team(
            name: "Paris Saint-Germain",
            shortName: "PSG",
            logo: "psg_logo"
        ),
        title: "Barcelona - PSG",
        subtitle: "UEFA Champions League • Fotball",
        competition: "UEFA Champions League",
        venue: "Camp Nou",
        commentator: "Magnus Drivenes",
        isLive: true,
        backgroundImage: "barcelona_psg_bg",
        availability: .available,
        relatedContent: [
            TV2RelatedTeam(
                team: TV2Team(name: "FC Barcelona", shortName: "Barcelona", logo: "barcelona_logo"),
                description: nil
            ),
            TV2RelatedTeam(
                team: TV2Team(name: "Paris Saint-Germain", shortName: "PSG", logo: "psg_logo"),
                description: nil
            )
        ],
        campaignLogo: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Adidas_logo.png/800px-Adidas_logo.png",
        contentId: "barcelona-psg-2025-01-23",
        country: "NO"
    )
    
    // Keep old match for reference
    static let dortmundAtletico = TV2Match(
        homeTeam: TV2Team(
            name: "Borussia Dortmund",
            shortName: "Dortmund",
            logo: "bvb_logo"
        ),
        awayTeam: TV2Team(
            name: "Athletic Club",
            shortName: "Athletic",
            logo: "athletic_logo"
        ),
        title: "Dortmund - Athletic",
        subtitle: "UEFA Champions League • Fotball",
        competition: "UEFA Champions League",
        venue: "SIGNAL IDUNA PARK",
        commentator: "Magnus Drivenes",
        isLive: false,
        backgroundImage: "dortmund_bg",
        availability: .availableUntil(date: "ett år"),
        relatedContent: [
            TV2RelatedTeam(
                team: TV2Team(name: "Borussia Dortmund", shortName: "BVB", logo: "bvb_logo"),
                description: nil
            ),
            TV2RelatedTeam(
                team: TV2Team(name: "Athletic Club", shortName: "Athletic", logo: "athletic_logo"),
                description: nil
            )
        ]
    )
    
    static let mockMatches: [TV2Match] = [
        barcelonaPSG,
        dortmundAtletico,
        TV2Match(
            homeTeam: TV2Team(name: "Manchester City", shortName: "City", logo: "city_logo"),
            awayTeam: TV2Team(name: "Real Madrid", shortName: "Madrid", logo: "madrid_logo"),
            title: "Man City - Real Madrid",
            subtitle: "UEFA Champions League • Fotball",
            competition: "UEFA Champions League",
            venue: "Etihad Stadium",
            commentator: "Øyvind Alsaker",
            isLive: true,
            backgroundImage: "city_bg",
            availability: .available,
            relatedContent: []
        )
    ]
}

