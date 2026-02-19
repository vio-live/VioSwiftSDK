//
//  TimelineEventModels.swift
//  Viaplay
//
//  Concrete implementations of timeline events
//  Ready for backend integration via Codable
//

import Foundation
import SwiftUI
import VioCore

// MARK: - Chat Message Event

struct ChatMessageEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let username: String
    let text: String
    let usernameColor: String  // Hex color for backend compatibility
    let likes: Int
    let timestamp: Date
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .chatMessage }
    var displayPriority: Int { 1 }
    
    // Convert Color to hex for storage
    var colorValue: Color {
        Color(hex: usernameColor)
    }
    
    init(
        id: String = UUID().uuidString,
        videoTimestamp: TimeInterval,
        username: String,
        text: String,
        usernameColor: Color,
        likes: Int = 0,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.videoTimestamp = videoTimestamp
        self.username = username
        self.text = text
        self.usernameColor = usernameColor.toHex() ?? "#FFFFFF"
        self.likes = likes
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Admin Comment Event

struct AdminCommentEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let adminName: String
    let comment: String
    let isPinned: Bool
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .adminComment }
    var displayPriority: Int { 10 }  // Higher priority (shows on top)
}

// MARK: - Commentary Event (Play-by-play)
// Note: Uses adminComment as eventType but distinct struct for rendering

struct CommentaryEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let minute: Int
    let text: String
    let commentaryType: CommentaryType
    let isHighlighted: Bool
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .adminComment }
    var displayPriority: Int { isHighlighted ? 8 : 3 }
    
    enum CommentaryType: String, Codable {
        case general, goal, chance, card, substitution, corner, foul, save, halftime, kickoff
        
        var icon: String {
            switch self {
            case .general: return ""
            case .goal: return "soccerball.circle.fill"
            case .chance: return "soccerball"
            case .card: return "rectangle.fill"
            case .substitution: return "arrow.triangle.2.circlepath"
            case .corner: return "flag.fill"
            case .foul: return "hand.raised.fill"
            case .save: return "hand.raised.circle.fill"
            case .halftime: return "pause.circle.fill"
            case .kickoff: return "play.circle.fill"
            }
        }
        
        var hasIcon: Bool { !icon.isEmpty }
    }
}

// MARK: - Tweet Event

struct TweetEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let authorName: String
    let authorHandle: String
    let authorAvatar: String?
    let tweetText: String
    let isVerified: Bool
    let likes: Int
    let retweets: Int
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .tweet }
    var displayPriority: Int { 2 }
}

// MARK: - Social Media Post Event

struct SocialPostEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let platform: SocialPlatform
    let authorName: String
    let authorAvatar: String?
    let content: String
    let imageUrl: String?
    let reactions: [String: Int]  // emoji -> count
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .socialPost }
    var displayPriority: Int { 2 }
    
    enum SocialPlatform: String, Codable {
        case twitter = "twitter"
        case instagram = "instagram"
        case facebook = "facebook"
        case tiktok = "tiktok"
        
        var displayName: String {
            switch self {
            case .twitter: return "X"
            case .instagram: return "Instagram"
            case .facebook: return "Facebook"
            case .tiktok: return "TikTok"
            }
        }
    }
}

// MARK: - Match Goal Event

struct MatchGoalEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let player: String
    let team: TeamSide
    let score: String  // "1-0"
    let assistBy: String?
    let isOwnGoal: Bool
    let isPenalty: Bool
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .matchGoal }
    var displayPriority: Int { 10 }
    
    enum TeamSide: String, Codable {
        case home = "home"
        case away = "away"
    }
}

// MARK: - Match Card Event

struct MatchCardEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let player: String
    let team: TeamSide
    let cardType: CardType
    let reason: String?
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .matchCard }
    var displayPriority: Int { 8 }
    
    enum CardType: String, Codable {
        case yellow = "yellow"
        case red = "red"
        case secondYellow = "second_yellow"
        
        var displayName: String {
            switch self {
            case .yellow: return "Gult kort"
            case .red: return "Rødt kort"
            case .secondYellow: return "Andre gule kort"
            }
        }
    }
    
    enum TeamSide: String, Codable {
        case home = "home"
        case away = "away"
    }
}

// MARK: - Match Substitution Event

struct MatchSubstitutionEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let playerIn: String
    let playerOut: String
    let team: TeamSide
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .matchSubstitution }
    var displayPriority: Int { 5 }
    
    enum TeamSide: String, Codable {
        case home = "home"
        case away = "away"
    }
}

// MARK: - Poll Event

struct PollTimelineEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let question: String
    let options: [PollOption]
    let duration: TimeInterval?  // How long poll is active
    let endTimestamp: TimeInterval?  // When poll closes
    let metadata: [String: String]?
    let broadcastContext: BroadcastContext?  // Optional: Broadcast context for context-aware polls
    
    var eventType: TimelineEventType { .poll }
    var displayPriority: Int { 7 }
    
    // Backward compatibility property
    @available(*, deprecated, renamed: "broadcastContext")
    var matchContext: BroadcastContext? { broadcastContext }
    
    struct PollOption: Codable, Identifiable {
        let id: String
        let text: String
        let voteCount: Int
        let percentage: Double?
    }
}

// MARK: - Product Highlight Event

struct ProductTimelineEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let productId: String
    let productName: String
    let productImage: String?
    let price: String
    let currency: String
    let duration: TimeInterval?  // How long to display
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .productHighlight }
    var displayPriority: Int { 3 }
}

// MARK: - Announcement Event

struct AnnouncementEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let title: String
    let message: String
    let imageUrl: String?
    let actionUrl: String?
    let actionText: String?
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .announcement }
    var displayPriority: Int { 9 }
}

// MARK: - Highlight Event

struct HighlightTimelineEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let title: String
    let description: String?
    let thumbnailUrl: String?
    let clipUrl: String?
    let highlightType: HighlightType
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .highlight }
    var displayPriority: Int { 4 }
    
    enum HighlightType: String, Codable {
        case goal = "goal"
        case chance = "chance"
        case save = "save"
        case yellowCard = "yellow_card"
        case redCard = "red_card"
        case tackle = "tackle"
        case pass = "pass"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .goal: return "Mål"
            case .chance: return "Sjanse"
            case .save: return "Redning"
            case .yellowCard: return "Gult kort"
            case .redCard: return "Rødt kort"
            case .tackle: return "Takling"
            case .pass: return "Pasning"
            case .other: return "Høydepunkt"
            }
        }
        
        var icon: String {
            switch self {
            case .goal: return "soccerball.circle.fill"
            case .chance: return "target"
            case .save: return "hand.raised.fill"
            case .yellowCard: return "rectangle.fill"
            case .redCard: return "rectangle.fill"
            case .tackle: return "figure.soccer"
            case .pass: return "arrow.triangle.swap"
            case .other: return "star.fill"
            }
        }
        
        var iconColor: String {
            switch self {
            case .goal: return "green"
            case .chance: return "orange"
            case .save: return "blue"
            case .yellowCard: return "yellow"
            case .redCard: return "red"
            case .tackle: return "cyan"
            case .pass: return "purple"
            case .other: return "white"
            }
        }
    }
}

// MARK: - Statistics Update Event

struct StatisticsUpdateEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let statName: String
    let homeValue: Double
    let awayValue: Double
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .statisticsUpdate }
    var displayPriority: Int { 2 }
}

// MARK: - Casting Contest Event

struct CastingContestEvent: TimelineEvent {
    let id: String
    let videoTimestamp: TimeInterval
    let title: String
    let description: String
    let prize: String
    let contestType: ContestType
    let metadata: [String: String]?
    let broadcastContext: BroadcastContext?  // Optional: Broadcast context for context-aware contests
    
    var eventType: TimelineEventType { .castingContest }
    var displayPriority: Int { 8 }
    
    // Backward compatibility property
    @available(*, deprecated, renamed: "broadcastContext")
    var matchContext: BroadcastContext? { broadcastContext }
    
    enum ContestType: String, Codable {
        case quiz = "quiz"
        case giveaway = "giveaway"
    }
}

// MARK: - Casting Product Event

struct CastingProductEvent: TimelineEvent, Identifiable {
    let id: String
    let videoTimestamp: TimeInterval
    let productId: String  // ID del producto en Vio (primary)
    let productIds: [String]?  // IDs adicionales de productos (para mostrar múltiples)
    let title: String
    let description: String
    let castingProductUrl: String?  // URL del producto en Casting
    let castingCheckoutUrl: String?  // URL del checkout en Casting
    let imageAsset: String?  // Asset name para imagen del producto
    let metadata: [String: String]?
    
    var eventType: TimelineEventType { .castingProduct }
    var displayPriority: Int { 7 }
    
    // Helper to get all product IDs
    var allProductIds: [String] {
        var ids = [productId]
        if let additionalIds = productIds {
            ids.append(contentsOf: additionalIds)
        }
        return ids
    }
}

// MARK: - Helper Extensions

extension TimelineEvent {
    var displayMinute: Int {
        Int(videoTimestamp / 60)
    }
    
    var displayTime: String {
        let minutes = Int(videoTimestamp / 60)
        let seconds = Int(videoTimestamp.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Color Extension for Hex Conversion

extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", 
                     lroundf(r * 255), 
                     lroundf(g * 255), 
                     lroundf(b * 255))
    }
}
