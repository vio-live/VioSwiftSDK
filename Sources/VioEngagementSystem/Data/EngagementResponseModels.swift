import Foundation

/// Response models for backend engagement API
/// These are internal types used for decoding backend responses

struct PollsResponse: Codable {
    let polls: [PollData]
    let broadcastStartTime: Date? // Broadcast start time at root level
    let matchStartTime: Date? // Match start time at root level (backward compatibility)
    let pagination: PaginationMetadata?
    
    struct PaginationMetadata: Codable {
        let limit: Int
        let offset: Int
        let total: Int
        let hasMore: Bool
    }
    
    struct PollData: Codable {
        let id: String
        let broadcastId: String? // New field
        let matchId: String // Backward compatibility
        let question: String
        let options: [PollOptionData]
        let startTime: Date?
        let endTime: Date?
        let videoStartTime: Int? // Time in seconds relative to broadcast start
        let videoEndTime: Int? // Time in seconds relative to broadcast start
        let broadcastStartTime: Date? // Broadcast start time per poll (optional, can use root level)
        let matchStartTime: Date? // Match start time per poll (backward compatibility)
        let isActive: Bool
        let totalVotes: Int
        
        struct PollOptionData: Codable {
            let id: String
            let text: String
            let voteCount: Int
            let percentage: Double
        }
    }
}

struct ContestsResponse: Codable {
    let contests: [ContestData]
    let broadcastStartTime: Date? // Broadcast start time at root level
    let matchStartTime: Date? // Match start time at root level (backward compatibility)
    let pagination: PaginationMetadata?
    
    struct PaginationMetadata: Codable {
        let limit: Int
        let offset: Int
        let total: Int
        let hasMore: Bool
    }
    
    struct ContestData: Codable {
        let id: String
        let broadcastId: String? // New field
        let matchId: String // Backward compatibility
        let title: String
        let description: String
        let prize: String
        let contestType: String
        let startTime: Date?
        let endTime: Date?
        let videoStartTime: Int? // Time in seconds relative to broadcast start
        let videoEndTime: Int? // Time in seconds relative to broadcast start
        let broadcastStartTime: Date? // Broadcast start time per contest (optional, can use root level)
        let matchStartTime: Date? // Match start time per contest (backward compatibility)
        let isActive: Bool
    }
}
