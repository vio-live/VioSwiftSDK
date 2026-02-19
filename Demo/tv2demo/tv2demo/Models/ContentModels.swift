import Foundation

// MARK: - Category
struct Category: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let slug: String
}

// MARK: - Content Item
struct ContentItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let imageURL: String
    let category: String
    let isLive: Bool
    let duration: String?
    let date: String?
    // Match-specific properties
    let homeTeamLogo: String?
    let awayTeamLogo: String?
    let matchTime: String?
    let matchday: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        imageURL: String,
        category: String,
        isLive: Bool = false,
        duration: String? = nil,
        date: String? = nil,
        homeTeamLogo: String? = nil,
        awayTeamLogo: String? = nil,
        matchTime: String? = nil,
        matchday: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.category = category
        self.isLive = isLive
        self.duration = duration
        self.date = date
        self.homeTeamLogo = homeTeamLogo
        self.awayTeamLogo = awayTeamLogo
        self.matchTime = matchTime
        self.matchday = matchday
    }
}

// MARK: - Mock Data
extension ContentItem {
    static let mockItems: [ContentItem] = [
        ContentItem(
            title: "Barcelona - PSG",
            subtitle: "Fotball • Menn • UEFA Champions League",
            imageURL: "barcelona_psg_bg",
            category: "Fotball",
            isLive: true,
            date: "Tir. 18:40",
            homeTeamLogo: "barcelona_logo",
            awayTeamLogo: "psg_logo",
            matchTime: "18:40",
            matchday: "M"
        ),
        ContentItem(
            title: "FOTBALLKVELD",
            subtitle: "Alt fra CL-runden",
            imageURL: "bg-card-1",
            category: "Fotball",
            isLive: false,
            date: "I dag 17:40"
        ),
        ContentItem(
            title: "CHAMPIONS LEAGUE",
            subtitle: "Kremmerne",
            imageURL: "bg-card-3",
            category: "Fotball",
            isLive: false,
            date: "I dag 19:00"
        ),
        ContentItem(
            title: "Rolex Shanghai Masters",
            subtitle: "Dag 2",
            imageURL: "bg-card-2",
            category: "Tennis",
            isLive: true,
            duration: "DIREKTE"
        ),
        ContentItem(
            title: "Rosenborg vs Brann",
            subtitle: "Fotball kveld",
            imageURL: "bg-card-1",
            category: "Fotball",
            isLive: false,
            date: "I dag 17:40"
        ),
        ContentItem(
            title: "Håndball Highlights",
            subtitle: "Best of Champions League",
            imageURL: "bg-card-2",
            category: "Håndball",
            isLive: false,
            date: "I går 20:00"
        ),
        ContentItem(
            title: "Sykkel VM",
            subtitle: "Herrenes fellesstart",
            imageURL: "bg-card-3",
            category: "Sykkel",
            isLive: false,
            date: "27 sep"
        )
    ]
}

extension Category {
    static let mockCategories: [Category] = [
        Category(name: "Sporten", slug: "sporten"),
        Category(name: "Fotball", slug: "fotball"),
        Category(name: "Norsk", slug: "norsk"),
        Category(name: "Tennis", slug: "tennis"),
        Category(name: "Håndball", slug: "handball"),
        Category(name: "Sykkel", slug: "cycling")
    ]
}


