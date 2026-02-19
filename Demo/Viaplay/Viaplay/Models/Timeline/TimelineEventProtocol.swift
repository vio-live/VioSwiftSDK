//
//  TimelineEventProtocol.swift
//  Viaplay
//
//  Protocol for all timeline events - extensible for any event type
//  Designed for easy backend integration
//

import Foundation
import VioCore

// MARK: - Timeline Event Protocol

/// Base protocol for all events that can appear in the timeline
/// All events (chat, goals, polls, tweets, etc.) implement this
protocol TimelineEvent: Identifiable, Codable {
    var id: String { get }
    var videoTimestamp: TimeInterval { get }  // Seconds from video start (0-5400 for 90 min)
    var eventType: TimelineEventType { get }
    var displayPriority: Int { get }  // For sorting when same timestamp
    var metadata: [String: String]? { get }  // Extensible metadata for backend
}

// MARK: - Timeline Event Type

/// All possible event types - easy to extend
enum TimelineEventType: String, Codable, CaseIterable {
    // Match events
    case matchGoal = "match_goal"
    case matchCard = "match_card"
    case matchSubstitution = "match_substitution"
    case matchKickOff = "match_kickoff"
    case matchHalfTime = "match_halftime"
    case matchFullTime = "match_fulltime"
    case matchPenalty = "match_penalty"
    
    // Social events
    case chatMessage = "chat_message"
    case adminComment = "admin_comment"
    case tweet = "tweet"
    case socialPost = "social_post"
    
    // Interactive events
    case poll = "poll"
    case quiz = "quiz"
    case trivia = "trivia"
    case prediction = "prediction"
    case voting = "voting"
    case castingContest = "power_contest"
    case castingProduct = "power_product"
    
    // Commerce events
    case productHighlight = "product_highlight"
    case offerBanner = "offer_banner"
    
    // Content events
    case highlight = "highlight"
    case statisticsUpdate = "statistics_update"
    case announcement = "announcement"
    case replay = "replay"
    
    // Norwegian display names
    var displayName: String {
        switch self {
        // Match events
        case .matchGoal: return "Mål"
        case .matchCard: return "Kort"
        case .matchSubstitution: return "Bytte"
        case .matchKickOff: return "Avspark"
        case .matchHalfTime: return "Pause"
        case .matchFullTime: return "Fulltid"
        case .matchPenalty: return "Straffe"
        
        // Social events
        case .chatMessage: return "Chat"
        case .adminComment: return "Kommentar"
        case .tweet: return "Tweet"
        case .socialPost: return "Innlegg"
        
        // Interactive events
        case .poll: return "Avstemning"
        case .quiz: return "Quiz"
        case .trivia: return "Trivia"
        case .prediction: return "Spådom"
        case .voting: return "Avstemning"
        case .castingContest:
            return "\(VioConfiguration.shared.effectiveBrandConfiguration.name) Konkurranse"
        case .castingProduct:
            return "\(VioConfiguration.shared.effectiveBrandConfiguration.name) Produkt"
        
        // Commerce events
        case .productHighlight: return "Produkt"
        case .offerBanner: return "Tilbud"
        
        // Content events
        case .highlight: return "Høydepunkt"
        case .statisticsUpdate: return "Statistikk"
        case .announcement: return "Kunngjøring"
        case .replay: return "Reprise"
        }
    }
    
    // Icon for timeline markers
    var icon: String {
        switch self {
        case .matchGoal: return "soccerball.circle.fill"
        case .matchCard: return "rectangle.fill"
        case .matchSubstitution: return "arrow.triangle.2.circlepath"
        case .matchKickOff: return "whistle.fill"
        case .matchHalfTime, .matchFullTime: return "pause.circle.fill"
        case .matchPenalty: return "exclamationmark.circle.fill"
        case .chatMessage: return "message.fill"
        case .adminComment: return "megaphone.fill"
        case .tweet: return "bird.fill"
        case .socialPost: return "person.2.fill"
        case .poll, .voting: return "chart.bar.fill"
        case .quiz, .trivia: return "questionmark.circle.fill"
        case .prediction: return "crystal.ball"
        case .castingContest: return "trophy.fill"
        case .castingProduct: return "cart.fill"
        case .productHighlight: return "cart.fill"
        case .offerBanner: return "tag.fill"
        case .highlight: return "play.circle.fill"
        case .statisticsUpdate: return "chart.line.uptrend.xyaxis"
        case .announcement: return "bell.fill"
        case .replay: return "arrow.counterclockwise.circle.fill"
        }
    }
    
    // Color for timeline markers
    var markerColor: String {
        switch self {
        case .matchGoal: return "green"
        case .matchCard: return "yellow"
        case .matchSubstitution: return "blue"
        case .matchKickOff, .matchHalfTime, .matchFullTime: return "white"
        case .matchPenalty: return "red"
        case .chatMessage: return "cyan"
        case .adminComment: return "orange"
        case .tweet: return "blue"
        case .socialPost: return "purple"
        case .poll, .voting: return "orange"
        case .quiz, .trivia: return "purple"
        case .prediction: return "pink"
        case .castingContest: return "orange"
        case .castingProduct: return "green"
        case .productHighlight: return "green"
        case .offerBanner: return "red"
        case .highlight: return "white"
        case .statisticsUpdate: return "cyan"
        case .announcement: return "yellow"
        case .replay: return "gray"
        }
    }
}

// MARK: - Event Category

/// Grouping for UI organization
enum TimelineEventCategory: String, Codable {
    case match = "match"           // Eventos del partido
    case social = "social"         // Chat, tweets, posts
    case interactive = "interactive" // Polls, quiz, voting
    case commerce = "commerce"     // Productos, ofertas
    case content = "content"       // Highlights, stats, announcements
    
    var displayName: String {
        switch self {
        case .match: return "Kamphendelser"
        case .social: return "Sosiale"
        case .interactive: return "Interaktive"
        case .commerce: return "Produkter"
        case .content: return "Innhold"
        }
    }
}

// MARK: - Helper Extensions

extension TimelineEventType {
    var category: TimelineEventCategory {
        switch self {
        case .matchGoal, .matchCard, .matchSubstitution, .matchKickOff, 
             .matchHalfTime, .matchFullTime, .matchPenalty:
            return .match
            
        case .chatMessage, .adminComment, .tweet, .socialPost:
            return .social
            
        case .poll, .quiz, .trivia, .prediction, .voting, .castingContest, .castingProduct:
            return .interactive
            
        case .productHighlight, .offerBanner:
            return .commerce
            
        case .highlight, .statisticsUpdate, .announcement, .replay:
            return .content
        }
    }
}
