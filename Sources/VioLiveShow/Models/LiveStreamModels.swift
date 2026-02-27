import Foundation
import VioCore

// MARK: - Live Stream Models

/// Represents a live streaming session
public struct LiveStream: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let description: String?
    public let streamer: LiveStreamer
    public let videoUrl: String? // Vimeo URL
    public let thumbnailUrl: String?
    public let viewerCount: Int
    public let isLive: Bool
    public let startTime: Date
    public let endTime: Date?
    public let featuredProducts: [LiveProduct]
    public let chatMessages: [LiveChatMessage]
    /// Vimeo live event ID (for hearts API)
    public let liveStreamId: String?
    
    public init(
        id: String,
        title: String,
        description: String? = nil,
        streamer: LiveStreamer,
        videoUrl: String? = nil,
        thumbnailUrl: String? = nil,
        viewerCount: Int = 0,
        isLive: Bool = true,
        startTime: Date = Date(),
        endTime: Date? = nil,
        featuredProducts: [LiveProduct] = [],
        chatMessages: [LiveChatMessage] = [],
        liveStreamId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.streamer = streamer
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.viewerCount = viewerCount
        self.isLive = isLive
        self.startTime = startTime
        self.endTime = endTime
        self.featuredProducts = featuredProducts
        self.chatMessages = chatMessages
        self.liveStreamId = liveStreamId
    }
}

/// Represents a live streamer/host
public struct LiveStreamer: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let username: String
    public let avatarUrl: String?
    public let isVerified: Bool
    public let followerCount: Int
    
    public init(
        id: String,
        name: String,
        username: String,
        avatarUrl: String? = nil,
        isVerified: Bool = false,
        followerCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.avatarUrl = avatarUrl
        self.isVerified = isVerified
        self.followerCount = followerCount
    }
}

/// Product featured during live stream
public struct LiveProduct: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let price: Price
    public let originalPrice: Price?     
    public let imageUrl: String
    public let isAvailable: Bool
    public let stockCount: Int?
    public let discount: String?
    public let specialOffer: String?
    public let showUntil: Date?
    
    // Convert to regular Product for cart integration
    public var asProduct: Product {
        Product(
            id: Int(id.hashValue),
            title: title,
            brand: nil,
            description: specialOffer ?? "Featured on Live Show",
            tags: nil,
            sku: "LIVE-\(id)",
            quantity: stockCount ?? 100,
            price: price,
            variants: [],
            barcode: nil,
            options: nil,
            categories: nil,
            images: [ProductImage(id: UUID().uuidString, url: imageUrl, width: nil, height: nil, order: 0)],
            product_shipping: nil,
            supplier: "Live Show",
            supplier_id: nil,
            imported_product: nil,
            referral_fee: nil,
            options_enabled: false,
            digital: false,
            origin: "",
            return: nil
        )
    }
    
    public init(
        id: String,
        title: String,
        price: Price,
        originalPrice: Price? = nil,
        imageUrl: String,
        isAvailable: Bool = true,
        stockCount: Int? = nil,
        discount: String? = nil,
        specialOffer: String? = nil,
        showUntil: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.originalPrice = originalPrice
        self.imageUrl = imageUrl
        self.isAvailable = isAvailable
        self.stockCount = stockCount
        self.discount = discount
        self.specialOffer = specialOffer
        self.showUntil = showUntil
    }
}

/// Chat message in live stream
public struct LiveChatMessage: Identifiable, Codable, Equatable {
    public let id: String
    public let user: LiveChatUser
    public let message: String
    public let timestamp: Date
    public let isStreamerMessage: Bool
    public let isPinned: Bool
    public let reactions: [LiveChatReaction]
    
    public init(
        id: String = UUID().uuidString,
        user: LiveChatUser,
        message: String,
        timestamp: Date = Date(),
        isStreamerMessage: Bool = false,
        isPinned: Bool = false,
        reactions: [LiveChatReaction] = []
    ) {
        self.id = id
        self.user = user
        self.message = message
        self.timestamp = timestamp
        self.isStreamerMessage = isStreamerMessage
        self.isPinned = isPinned
        self.reactions = reactions
    }
}

/// Chat user roles
public enum ChatUserRole: String, Codable, CaseIterable {
    case viewer = "viewer"
    case subscriber = "subscriber"
    case moderator = "moderator"
    case admin = "admin"
    case streamer = "streamer"
    case vip = "vip"
    
    public var displayName: String {
        switch self {
        case .viewer: return "Viewer"
        case .subscriber: return "Subscriber"
        case .moderator: return "Mod"
        case .admin: return "Admin"
        case .streamer: return "Streamer"
        case .vip: return "VIP"
        }
    }
    
    public var color: String {
        switch self {
        case .viewer: return "gray"
        case .subscriber: return "blue"
        case .moderator: return "yellow"
        case .admin: return "red"
        case .streamer: return "purple"
        case .vip: return "gold"
        }
    }
    
    public var priority: Int {
        switch self {
        case .streamer: return 5
        case .admin: return 4
        case .moderator: return 3
        case .vip: return 2
        case .subscriber: return 1
        case .viewer: return 0
        }
    }
}

/// Chat user
public struct LiveChatUser: Identifiable, Codable, Equatable {
    public let id: String
    public let username: String
    public let avatarUrl: String?
    public let isVerified: Bool
    public let isModerator: Bool
    public let role: ChatUserRole
    public let joinDate: Date?
    public let subscriberMonths: Int?
    
    public init(
        id: String,
        username: String,
        avatarUrl: String? = nil,
        isVerified: Bool = false,
        isModerator: Bool = false,
        role: ChatUserRole = .viewer,
        joinDate: Date? = nil,
        subscriberMonths: Int? = nil
    ) {
        self.id = id
        self.username = username
        self.avatarUrl = avatarUrl
        self.isVerified = isVerified
        self.isModerator = isModerator
        self.role = role
        self.joinDate = joinDate
        self.subscriberMonths = subscriberMonths
    }
    
    // Computed properties for backward compatibility
    public var isAdmin: Bool {
        return role == .admin || role == .streamer
    }
    
    public var isStreamer: Bool {
        return role == .streamer
    }
    
    public var isVip: Bool {
        return role == .vip
    }
    
    public var isSubscriber: Bool {
        return role == .subscriber || subscriberMonths != nil
    }
}

/// Chat reaction/emoji
public struct LiveChatReaction: Identifiable, Codable, Equatable {
    public let id: String
    public let emoji: String
    public let count: Int
    
    public init(id: String = UUID().uuidString, emoji: String, count: Int = 1) {
        self.id = id
        self.emoji = emoji
        self.count = count
    }
}

// MARK: - Live Stream Layout Types

public enum LiveStreamLayout: String, CaseIterable {
    case fullScreenOverlay = "fullScreenOverlay"
    case bottomSheet = "bottomSheet"
    case modal = "modal"
    
    public var displayName: String {
        switch self {
        case .fullScreenOverlay: return "Full Screen Overlay"
        case .bottomSheet: return "Bottom Sheet"
        case .modal: return "Modal"
        }
    }
}

public enum MiniPlayerPosition: String, CaseIterable {
    case topLeft = "topLeft"
    case topRight = "topRight"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    
    public var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

// MARK: - Extensions

extension Price {
    /// Formatted price string for display (uses amount_incl_taxes if available)
    public var formattedPrice: String {
        // Use price with taxes if available (what customer actually pays)
        let priceToShow = amount_incl_taxes ?? amount
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency_code
        return formatter.string(from: NSNumber(value: priceToShow)) ?? "\(currency_code) \(priceToShow)"
    }
    
    /// Formatted compare at price string for display (uses compare_at_incl_taxes if available)
    public var formattedCompareAtPrice: String? {
        // Use compare at price with taxes if available, otherwise base compare at
        let compareAtPrice: Float?
        if let compareAtWithTaxes = compare_at_incl_taxes {
            compareAtPrice = compareAtWithTaxes
        } else if let compareAt = compare_at {
            compareAtPrice = compareAt
        } else {
            return nil
        }
        
        guard let price = compareAtPrice else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency_code
        return formatter.string(from: NSNumber(value: price)) ?? "\(currency_code) \(price)"
    }
}

// MARK: - Socket Event Types

public enum LiveStreamSocketEvent: Equatable {
    case started(LiveStream)
    case ended(LiveStream)
}

// MARK: - Livestream Refresh API Response

/// Decodes refresh-HLS API response (generic livestream format). Used for HLS URL refresh.
struct LivestreamRefreshResponse: Codable {
    let id: Int
    let title: String
    let liveStreamId: String
    let hls: String?
    let player: String?
    let thumbnail: String?
    let broadcasting: Bool
    let date: Date
    let endDate: Date
    let videoUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, liveStreamId, hls, player, thumbnail, broadcasting, date, videoUrl
        case endDate = "end_date"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        liveStreamId = try c.decode(String.self, forKey: .liveStreamId)
        hls = try c.decodeIfPresent(String.self, forKey: .hls)
        player = try c.decodeIfPresent(String.self, forKey: .player)
        thumbnail = try c.decodeIfPresent(String.self, forKey: .thumbnail)
        broadcasting = try c.decode(Bool.self, forKey: .broadcasting)
        videoUrl = try c.decodeIfPresent(String.self, forKey: .videoUrl)
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        date = try df.date(from: c.decode(String.self, forKey: .date)) ?? Date()
        endDate = try df.date(from: c.decode(String.self, forKey: .endDate)) ?? Date()
    }
    
    func toLiveStream() -> LiveStream {
        let name = title.components(separatedBy: " ").first ?? "Live Host"
        let streamer = LiveStreamer(
            id: "ls-\(id)",
            name: name,
            username: "@\(name.lowercased())",
            avatarUrl: thumbnail,
            isVerified: true,
            followerCount: 0
        )
        return LiveStream(
            id: String(id),
            title: title,
            description: nil,
            streamer: streamer,
            videoUrl: videoUrl ?? hls ?? player,
            thumbnailUrl: thumbnail,
            viewerCount: 0,
            isLive: broadcasting,
            startTime: date,
            endTime: endDate,
            featuredProducts: [],
            chatMessages: [],
            liveStreamId: liveStreamId
        )
    }
}

// MARK: - Chat API Response (livestream interactions API)

/// Chat message from by-channel API (generic format)
struct ChatApiMessage: Codable {
    let user: String
    let text: String
    let userTime: Date
    let role: String
    let pinned: Bool
    let visible: Bool?
    let clientId: String
    let messageid: Date
    let father: ChatApiMessageFather?
    let replies: [ChatApiMessage]
    
    enum CodingKeys: String, CodingKey {
        case user, text, userTime, role, pinned, visible, clientId, messageid, father, replies
    }
}

struct ChatApiMessageFather: Codable {
    let user: String
    let text: String
    let userTime: Date
}

extension ChatApiMessage {
    func toLiveChatMessage() -> LiveChatMessage {
        let chatRole: ChatUserRole = role.lowercased() == "streamer" ? .streamer : .viewer
        let chatUser = LiveChatUser(
            id: clientId,
            username: user,
            avatarUrl: nil,
            isVerified: false,
            isModerator: chatRole == .streamer,
            role: chatRole
        )
        return LiveChatMessage(
            user: chatUser,
            message: text,
            timestamp: userTime,
            isStreamerMessage: role.lowercased() == "streamer",
            isPinned: pinned,
            reactions: []
        )
    }
}
