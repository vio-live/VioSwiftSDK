//
//  TimelineEventProtocol.swift
//  VioCastingUI
//

import Foundation
import VioCore

// MARK: - Timeline Event Protocol

/// Base protocol for all events that can appear in the timeline
public protocol TimelineEvent: Identifiable, Codable {
    var id: String { get }
    var videoTimestamp: TimeInterval { get }
    var eventType: TimelineEventType { get }
    var displayPriority: Int { get }
    var metadata: [String: String]? { get }
}

// MARK: - Timeline Event Type

public enum TimelineEventType: String, Codable, CaseIterable {
    case matchGoal = "match_goal"
    case matchCard = "match_card"
    case matchSubstitution = "match_substitution"
    case matchKickOff = "match_kickoff"
    case matchHalfTime = "match_halftime"
    case matchFullTime = "match_fulltime"
    case matchPenalty = "match_penalty"
    case chatMessage = "chat_message"
    case adminComment = "admin_comment"
    case tweet = "tweet"
    case socialPost = "social_post"
    case poll = "poll"
    case quiz = "quiz"
    case trivia = "trivia"
    case prediction = "prediction"
    case voting = "voting"
    case castingContest = "power_contest"
    case castingProduct = "power_product"
    case productHighlight = "product_highlight"
    case offerBanner = "offer_banner"
    case highlight = "highlight"
    case statisticsUpdate = "statistics_update"
    case announcement = "announcement"
    case lineup = "lineup"
    case replay = "replay"

    public var displayName: String {
        switch self {
        case .matchGoal: return "Mål"
        case .matchCard: return "Kort"
        case .matchSubstitution: return "Bytte"
        case .matchKickOff: return "Avspark"
        case .matchHalfTime: return "Pause"
        case .matchFullTime: return "Fulltid"
        case .matchPenalty: return "Straffe"
        case .chatMessage: return "Chat"
        case .adminComment: return "Kommentar"
        case .tweet: return "Tweet"
        case .socialPost: return "Innlegg"
        case .poll: return "Avstemning"
        case .quiz: return "Quiz"
        case .trivia: return "Trivia"
        case .prediction: return "Spådom"
        case .voting: return "Avstemning"
        case .castingContest:
            return "\(VioConfiguration.shared.effectiveBrandConfiguration.name) Konkurranse"
        case .castingProduct:
            return "\(VioConfiguration.shared.effectiveBrandConfiguration.name) Produkt"
        case .productHighlight: return "Produkt"
        case .offerBanner: return "Tilbud"
        case .highlight: return "Høydepunkt"
        case .statisticsUpdate: return "Statistikk"
        case .announcement: return "Kunngjøring"
        case .lineup: return "Oppstilling"
        case .replay: return "Reprise"
        }
    }

    public var icon: String {
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
        case .lineup: return "person.3.fill"
        case .replay: return "arrow.counterclockwise.circle.fill"
        }
    }

    public var markerColor: String {
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
        case .lineup: return "blue"
        case .replay: return "gray"
        }
    }
}

// MARK: - Event Category

public enum TimelineEventCategory: String, Codable {
    case match = "match"
    case social = "social"
    case interactive = "interactive"
    case commerce = "commerce"
    case content = "content"

    public var displayName: String {
        switch self {
        case .match: return "Kamphendelser"
        case .social: return "Sosiale"
        case .interactive: return "Interaktive"
        case .commerce: return "Produkter"
        case .content: return "Innhold"
        }
    }
}

extension TimelineEventType {
    public var category: TimelineEventCategory {
        switch self {
        case .matchGoal, .matchCard, .matchSubstitution, .matchKickOff,
             .matchHalfTime, .matchFullTime, .matchPenalty, .lineup:
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
