import Foundation
import VioCore

// MARK: - Engagement Models

/// Poll model for engagement system
/// Supports video synchronization using relative timestamps
public struct Poll: Codable, Identifiable {
    public let id: String
    public let broadcastId: String
    public let question: String
    public let options: [PollOption]
    
    // Absolute timestamps (backward compatibility)
    public let startTime: Date?
    public let endTime: Date?
    
    // Video synchronization timestamps (relative to broadcast start)
    /// Time in seconds relative to broadcast start when poll should appear (e.g., -690 = 11:30 before start)
    public let videoStartTime: Int?
    /// Time in seconds relative to broadcast start when poll should disappear (e.g., 0 = at broadcast start)
    public let videoEndTime: Int?
    /// Absolute timestamp of broadcast start time
    public let broadcastStartTime: Date?
    
    public let isActive: Bool
    public let totalVotes: Int
    public let broadcastContext: BroadcastContext?
    
    public init(
        id: String,
        broadcastId: String,
        question: String,
        options: [PollOption],
        startTime: Date? = nil,
        endTime: Date? = nil,
        videoStartTime: Int? = nil,
        videoEndTime: Int? = nil,
        broadcastStartTime: Date? = nil,
        isActive: Bool = true,
        totalVotes: Int = 0,
        broadcastContext: BroadcastContext? = nil
    ) {
        self.id = id
        self.broadcastId = broadcastId
        self.question = question
        self.options = options
        self.startTime = startTime
        self.endTime = endTime
        self.videoStartTime = videoStartTime
        self.videoEndTime = videoEndTime
        self.broadcastStartTime = broadcastStartTime
        self.isActive = isActive
        self.totalVotes = totalVotes
        self.broadcastContext = broadcastContext
    }
    
    // Backward compatibility properties
    @available(*, deprecated, renamed: "broadcastId")
    public var matchId: String { broadcastId }
    
    @available(*, deprecated, renamed: "broadcastStartTime")
    public var matchStartTime: Date? { broadcastStartTime }
    
    @available(*, deprecated, renamed: "broadcastContext")
    public var matchContext: BroadcastContext? { broadcastContext }
    
    // Custom decoder to handle both matchId and broadcastId
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        // Try broadcastId first, fallback to matchId for backward compatibility
        if let broadcastId = try? container.decode(String.self, forKey: .broadcastId) {
            self.broadcastId = broadcastId
        } else {
            self.broadcastId = try container.decode(String.self, forKey: .matchId)
        }
        
        question = try container.decode(String.self, forKey: .question)
        options = try container.decode([PollOption].self, forKey: .options)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        videoStartTime = try container.decodeIfPresent(Int.self, forKey: .videoStartTime)
        videoEndTime = try container.decodeIfPresent(Int.self, forKey: .videoEndTime)
        
        // Try broadcastStartTime first, fallback to matchStartTime
        if let broadcastStartTime = try? container.decodeIfPresent(Date.self, forKey: .broadcastStartTime) {
            self.broadcastStartTime = broadcastStartTime
        } else {
            self.broadcastStartTime = try container.decodeIfPresent(Date.self, forKey: .matchStartTime)
        }
        
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        totalVotes = try container.decodeIfPresent(Int.self, forKey: .totalVotes) ?? 0
        
        // Try broadcastContext first, fallback to matchContext
        if let broadcastContext = try? container.decodeIfPresent(BroadcastContext.self, forKey: .broadcastContext) {
            self.broadcastContext = broadcastContext
        } else {
            self.broadcastContext = try container.decodeIfPresent(BroadcastContext.self, forKey: .matchContext)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(broadcastId, forKey: .broadcastId)
        try container.encode(question, forKey: .question)
        try container.encode(options, forKey: .options)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encodeIfPresent(videoStartTime, forKey: .videoStartTime)
        try container.encodeIfPresent(videoEndTime, forKey: .videoEndTime)
        try container.encodeIfPresent(broadcastStartTime, forKey: .broadcastStartTime)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(totalVotes, forKey: .totalVotes)
        try container.encodeIfPresent(broadcastContext, forKey: .broadcastContext)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case broadcastId
        case matchId  // For backward compatibility decoding
        case question
        case options
        case startTime
        case endTime
        case videoStartTime
        case videoEndTime
        case broadcastStartTime
        case matchStartTime  // For backward compatibility decoding
        case isActive
        case totalVotes
        case broadcastContext
        case matchContext  // For backward compatibility decoding
    }
    
    // Backward compatibility initializer
    @available(*, deprecated, message: "Use init with broadcastId instead")
    public init(
        id: String,
        matchId: String,
        question: String,
        options: [PollOption],
        startTime: Date? = nil,
        endTime: Date? = nil,
        videoStartTime: Int? = nil,
        videoEndTime: Int? = nil,
        matchStartTime: Date? = nil,
        isActive: Bool = true,
        totalVotes: Int = 0,
        matchContext: MatchContext? = nil
    ) {
        self.id = id
        self.broadcastId = matchId
        self.question = question
        self.options = options
        self.startTime = startTime
        self.endTime = endTime
        self.videoStartTime = videoStartTime
        self.videoEndTime = videoEndTime
        self.broadcastStartTime = matchStartTime
        self.isActive = isActive
        self.totalVotes = totalVotes
        self.broadcastContext = matchContext
    }
    
    public struct PollOption: Codable, Identifiable {
        public let id: String
        public let text: String
        public let voteCount: Int
        public let percentage: Double
        
        public init(id: String, text: String, voteCount: Int = 0, percentage: Double = 0.0) {
            self.id = id
            self.text = text
            self.voteCount = voteCount
            self.percentage = percentage
        }
    }
}

/// Contest model for engagement system
/// Supports video synchronization using relative timestamps
public struct Contest: Codable, Identifiable {
    public let id: String
    public let broadcastId: String
    public let title: String
    public let description: String
    public let prize: String
    public let contestType: ContestType
    
    // Absolute timestamps (backward compatibility)
    public let startTime: Date?
    public let endTime: Date?
    
    // Video synchronization timestamps (relative to broadcast start)
    /// Time in seconds relative to broadcast start when contest should appear
    public let videoStartTime: Int?
    /// Time in seconds relative to broadcast start when contest should disappear
    public let videoEndTime: Int?
    /// Absolute timestamp of broadcast start time
    public let broadcastStartTime: Date?
    
    public let isActive: Bool
    public let broadcastContext: BroadcastContext?
    
    public init(
        id: String,
        broadcastId: String,
        title: String,
        description: String,
        prize: String,
        contestType: ContestType,
        startTime: Date? = nil,
        endTime: Date? = nil,
        videoStartTime: Int? = nil,
        videoEndTime: Int? = nil,
        broadcastStartTime: Date? = nil,
        isActive: Bool = true,
        broadcastContext: BroadcastContext? = nil
    ) {
        self.id = id
        self.broadcastId = broadcastId
        self.title = title
        self.description = description
        self.prize = prize
        self.contestType = contestType
        self.startTime = startTime
        self.endTime = endTime
        self.videoStartTime = videoStartTime
        self.videoEndTime = videoEndTime
        self.broadcastStartTime = broadcastStartTime
        self.isActive = isActive
        self.broadcastContext = broadcastContext
    }
    
    // Backward compatibility properties
    @available(*, deprecated, renamed: "broadcastId")
    public var matchId: String { broadcastId }
    
    @available(*, deprecated, renamed: "broadcastStartTime")
    public var matchStartTime: Date? { broadcastStartTime }
    
    @available(*, deprecated, renamed: "broadcastContext")
    public var matchContext: BroadcastContext? { broadcastContext }
    
    // Custom decoder to handle both matchId and broadcastId
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        // Try broadcastId first, fallback to matchId for backward compatibility
        if let broadcastId = try? container.decode(String.self, forKey: .broadcastId) {
            self.broadcastId = broadcastId
        } else {
            self.broadcastId = try container.decode(String.self, forKey: .matchId)
        }
        
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        prize = try container.decode(String.self, forKey: .prize)
        contestType = try container.decode(ContestType.self, forKey: .contestType)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        videoStartTime = try container.decodeIfPresent(Int.self, forKey: .videoStartTime)
        videoEndTime = try container.decodeIfPresent(Int.self, forKey: .videoEndTime)
        
        // Try broadcastStartTime first, fallback to matchStartTime
        if let broadcastStartTime = try? container.decodeIfPresent(Date.self, forKey: .broadcastStartTime) {
            self.broadcastStartTime = broadcastStartTime
        } else {
            self.broadcastStartTime = try container.decodeIfPresent(Date.self, forKey: .matchStartTime)
        }
        
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        
        // Try broadcastContext first, fallback to matchContext
        if let broadcastContext = try? container.decodeIfPresent(BroadcastContext.self, forKey: .broadcastContext) {
            self.broadcastContext = broadcastContext
        } else {
            self.broadcastContext = try container.decodeIfPresent(BroadcastContext.self, forKey: .matchContext)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(broadcastId, forKey: .broadcastId)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(prize, forKey: .prize)
        try container.encode(contestType, forKey: .contestType)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encodeIfPresent(videoStartTime, forKey: .videoStartTime)
        try container.encodeIfPresent(videoEndTime, forKey: .videoEndTime)
        try container.encodeIfPresent(broadcastStartTime, forKey: .broadcastStartTime)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(broadcastContext, forKey: .broadcastContext)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case broadcastId
        case matchId  // For backward compatibility decoding
        case title
        case description
        case prize
        case contestType
        case startTime
        case endTime
        case videoStartTime
        case videoEndTime
        case broadcastStartTime
        case matchStartTime  // For backward compatibility decoding
        case isActive
        case broadcastContext
        case matchContext  // For backward compatibility decoding
    }
    
    // Backward compatibility initializer
    @available(*, deprecated, message: "Use init with broadcastId instead")
    public init(
        id: String,
        matchId: String,
        title: String,
        description: String,
        prize: String,
        contestType: ContestType,
        startTime: Date? = nil,
        endTime: Date? = nil,
        videoStartTime: Int? = nil,
        videoEndTime: Int? = nil,
        matchStartTime: Date? = nil,
        isActive: Bool = true,
        matchContext: MatchContext? = nil
    ) {
        self.id = id
        self.broadcastId = matchId
        self.title = title
        self.description = description
        self.prize = prize
        self.contestType = contestType
        self.startTime = startTime
        self.endTime = endTime
        self.videoStartTime = videoStartTime
        self.videoEndTime = videoEndTime
        self.broadcastStartTime = matchStartTime
        self.isActive = isActive
        self.broadcastContext = matchContext
    }
    
    public enum ContestType: String, Codable {
        case quiz = "quiz"
        case giveaway = "giveaway"
    }
}
