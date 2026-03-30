import Foundation

// MARK: - WebSocket / overlay payloads (tv2demo)
// Extracted from the legacy demo WebSocketManager; used by casting overlays and TV2VideoPlayer state.

struct ProductEvent: Codable {
    let type: String
    let data: ProductEventData
    let campaignLogo: String?
    let timestamp: Int64
}

struct ProductEventData: Codable, Equatable {
    let id: String
    let productId: String
    let name: String
    let description: String
    let price: String
    let currency: String
    let imageUrl: String
    var campaignLogo: String?
}

struct PollEvent: Codable {
    let type: String
    let data: PollEventData
    let campaignLogo: String?
    let timestamp: Int64
}

struct PollEventData: Codable, Identifiable, Equatable {
    let id: String
    let question: String
    let options: [PollOption]
    let duration: Int
    let imageUrl: String?
    var campaignLogo: String?
}

struct PollOption: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case text
        case avatarUrl
        case imageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        text = try container.decode(String.self, forKey: .text)
        if let url = try container.decodeIfPresent(String.self, forKey: .avatarUrl) {
            avatarUrl = url
        } else {
            avatarUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
    }

    init(text: String, avatarUrl: String?) {
        self.id = UUID()
        self.text = text
        self.avatarUrl = avatarUrl
    }
}

struct ContestEvent: Codable {
    let type: String
    let data: ContestEventData
    let campaignLogo: String?
    let timestamp: Int64
}

struct ContestEventData: Codable, Equatable {
    let id: String
    let name: String
    let prize: String
    let deadline: String
    let maxParticipants: Int
    var campaignLogo: String?
}
