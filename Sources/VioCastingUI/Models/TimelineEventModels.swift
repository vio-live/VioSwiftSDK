//
//  TimelineEventModels.swift
//  VioCastingUI
//

import Foundation
import SwiftUI
import VioCore
import VioDesignSystem

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Shared TeamSide for match events
public enum TimelineTeamSide: String, Codable {
    case home = "home"
    case away = "away"
}

// MARK: - Chat Message Event
public struct ChatMessageEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let username: String
    public let text: String
    public let usernameColor: String
    public let likes: Int
    public let timestamp: Date
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .chatMessage }
    public var displayPriority: Int { 1 }

    public var colorValue: Color {
        Color(hex: usernameColor)
    }

    public init(
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
public struct AdminCommentEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let adminName: String
    public let comment: String
    public let isPinned: Bool
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .adminComment }
    public var displayPriority: Int { 10 }
}

// MARK: - Commentary Event
public struct CommentaryEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let minute: Int
    public let text: String
    public let commentaryType: CommentaryType
    public let isHighlighted: Bool
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .adminComment }
    public var displayPriority: Int { isHighlighted ? 8 : 3 }

    public enum CommentaryType: String, Codable {
        case general, goal, chance, card, substitution, corner, foul, save, halftime, kickoff

        public var icon: String {
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

        public var hasIcon: Bool { !icon.isEmpty }
    }
}

// MARK: - Tweet Event
public struct TweetEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let authorName: String
    public let authorHandle: String
    public let authorAvatar: String?
    public let tweetText: String
    public let isVerified: Bool
    public let likes: Int
    public let retweets: Int
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .tweet }
    public var displayPriority: Int { 2 }
}

// MARK: - Social Post Event
public struct SocialPostEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let platform: SocialPlatform
    public let authorName: String
    public let authorAvatar: String?
    public let content: String
    public let imageUrl: String?
    public let reactions: [String: Int]
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .socialPost }
    public var displayPriority: Int { 2 }

    public enum SocialPlatform: String, Codable {
        case twitter = "twitter"
        case instagram = "instagram"
        case facebook = "facebook"
        case tiktok = "tiktok"

        public var displayName: String {
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
public struct MatchGoalEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let player: String
    public let team: TimelineTeamSide
    public let score: String
    public let assistBy: String?
    public let isOwnGoal: Bool
    public let isPenalty: Bool
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .matchGoal }
    public var displayPriority: Int { 10 }
}

// MARK: - Match Card Event
public struct MatchCardEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let player: String
    public let team: TimelineTeamSide
    public let cardType: CardType
    public let reason: String?
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .matchCard }
    public var displayPriority: Int { 8 }

    public enum CardType: String, Codable {
        case yellow = "yellow"
        case red = "red"
        case secondYellow = "second_yellow"

        public var displayName: String {
            switch self {
            case .yellow: return "Gult kort"
            case .red: return "Rødt kort"
            case .secondYellow: return "Andre gule kort"
            }
        }
    }
}

// MARK: - Match Substitution Event
public struct MatchSubstitutionEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let playerIn: String
    public let playerOut: String
    public let team: TimelineTeamSide
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .matchSubstitution }
    public var displayPriority: Int { 5 }
}

// MARK: - Poll Event
public struct PollTimelineEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let question: String
    public let options: [PollOption]
    public let duration: TimeInterval?
    public let endTimestamp: TimeInterval?
    public let metadata: [String: String]?
    public let broadcastContext: BroadcastContext?

    public var eventType: TimelineEventType { .poll }
    public var displayPriority: Int { 7 }

    @available(*, deprecated, renamed: "broadcastContext")
    public var matchContext: BroadcastContext? { broadcastContext }

    public struct PollOption: Codable, Identifiable {
        public let id: String
        public let text: String
        public let voteCount: Int
        public let percentage: Double?
    }
}

// MARK: - Product Highlight Event
public struct ProductTimelineEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let productId: String
    public let productName: String
    public let productImage: String?
    public let price: String
    public let currency: String
    public let duration: TimeInterval?
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .productHighlight }
    public var displayPriority: Int { 3 }
}

// MARK: - Announcement Event
public struct AnnouncementEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let title: String
    public let message: String
    public let imageUrl: String?
    public let actionUrl: String?
    public let actionText: String?
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .announcement }
    public var displayPriority: Int { 9 }
}

// MARK: - Lineup Event

/// Carries starting XI data for both teams as a proper timeline event.
/// Injected by LineupTimelineHandler when a lineup_show WS event arrives.
/// Players are embedded at injection time — no need to query LineupService at render time.
public struct LineupTimelineEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let teamKey: String      // "home" | "away"
    public let teamName: String
    public let formation: String?
    public let teamLogo: String?
    public let players: [LineupPlayer]
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .lineup }
    public var displayPriority: Int { 9 }

    public init(id: String, videoTimestamp: TimeInterval, teamKey: String, teamName: String, formation: String?, teamLogo: String?, players: [LineupPlayer], metadata: [String: String]? = nil) {
        self.id = id
        self.videoTimestamp = videoTimestamp
        self.teamKey = teamKey
        self.teamName = teamName
        self.formation = formation
        self.teamLogo = teamLogo
        self.players = players
        self.metadata = metadata
    }
}

// MARK: - Highlight Event
public struct HighlightTimelineEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let title: String
    public let description: String?
    public let thumbnailUrl: String?
    public let clipUrl: String?
    public let highlightType: HighlightType
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .highlight }
    public var displayPriority: Int { 4 }

    public enum HighlightType: String, Codable {
        case goal = "goal"
        case chance = "chance"
        case save = "save"
        case yellowCard = "yellow_card"
        case redCard = "red_card"
        case tackle = "tackle"
        case pass = "pass"
        case other = "other"

        public var displayName: String {
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

        public var icon: String {
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

        public var iconColor: String {
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
public struct StatisticsUpdateEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let statName: String
    public let homeValue: Double
    public let awayValue: Double
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .statisticsUpdate }
    public var displayPriority: Int { 2 }
}

// MARK: - Casting Contest Event
public struct CastingContestEvent: TimelineEvent {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let title: String
    public let description: String
    public let prize: String
    public let contestType: ContestType
    public let metadata: [String: String]?
    public let broadcastContext: BroadcastContext?

    public var eventType: TimelineEventType { .castingContest }
    public var displayPriority: Int { 8 }

    @available(*, deprecated, renamed: "broadcastContext")
    public var matchContext: BroadcastContext? { broadcastContext }

    public enum ContestType: String, Codable {
        case quiz = "quiz"
        case giveaway = "giveaway"
    }
}

// MARK: - Casting Product Event
public struct CastingProductEvent: TimelineEvent, Identifiable {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let productId: String
    public let productIds: [String]?
    public let title: String
    public let description: String
    public let castingProductUrl: String?
    public let castingCheckoutUrl: String?
    public let imageAsset: String?
    public let metadata: [String: String]?

    public var eventType: TimelineEventType { .castingProduct }
    public var displayPriority: Int { 7 }

    public var allProductIds: [String] {
        var ids = [productId]
        if let additionalIds = productIds {
            ids.append(contentsOf: additionalIds)
        }
        return ids
    }
}

// MARK: - Helper Extensions
extension TimelineEvent {
    public var displayMinute: Int {
        Int(videoTimestamp / 60)
    }

    public var displayTime: String {
        let minutes = Int(videoTimestamp / 60)
        let seconds = Int(videoTimestamp.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Match Phase
public enum MatchPhase {
    case preMatch
    case firstHalf
    case halfTime
    case secondHalf
    case postMatch

    public var displayName: String {
        switch self {
        case .preMatch: return "Før kampen"
        case .firstHalf: return "1. omgang"
        case .halfTime: return "Pause"
        case .secondHalf: return "2. omgang"
        case .postMatch: return "Etter kampen"
        }
    }
}

// MARK: - Type-Erased Wrapper
public struct AnyTimelineEvent: Identifiable {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let eventType: TimelineEventType
    public let displayPriority: Int
    public let metadata: [String: String]?
    public let event: Any

    public init<T: TimelineEvent>(_ event: T) {
        self.id = event.id
        self.videoTimestamp = event.videoTimestamp
        self.eventType = event.eventType
        self.displayPriority = event.displayPriority
        self.metadata = event.metadata
        self.event = event
    }
}

// MARK: - Backend Export Model
public struct EventExportData: Codable {
    public let id: String
    public let videoTimestamp: TimeInterval
    public let eventType: String
    public let metadata: [String: String]?
}

// MARK: - Color Extension for Hex Conversion
extension Color {
    func toHex() -> String? {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components else { return nil }
        #elseif canImport(AppKit)
        guard let components = NSColor(self).cgColor.components else { return nil }
        #else
        return nil
        #endif
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}
