import Foundation

/// Vio Engagement System
/// 
/// Core module for engagement features (polls, contests)
/// Import this target to get engagement data models and managers

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct VioEngagementSystem {
    
    /// Configure VioEngagementSystem with default settings
    public static func configure() {
        // Configuration can be added here if needed in the future
    }
}

// MARK: - Public Exports

// Export engagement managers
public typealias VioEngagementManager = EngagementManager

// Export engagement models
public typealias VioPoll = Poll
public typealias VioContest = Contest
public typealias VioPollOption = Poll.PollOption
public typealias VioPollResults = PollResults
public typealias VioPollOptionResults = PollResults.PollOptionResults
