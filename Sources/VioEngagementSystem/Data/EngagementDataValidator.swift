import Foundation
import VioCore

/// Validator for engagement data from backend
struct EngagementDataValidator {
    
    /// Validate poll data from backend
    static func validate(_ pollData: PollsResponse.PollData) -> ValidationResult {
        var errors: [String] = []
        
        // Validate required fields
        if pollData.id.isEmpty {
            errors.append("Poll ID is empty")
        }
        
        if pollData.question.isEmpty {
            errors.append("Poll question is empty")
        }
        
        // Validate options
        if pollData.options.isEmpty {
            errors.append("Poll has no options")
        }
        
        for (index, option) in pollData.options.enumerated() {
            if option.id.isEmpty {
                errors.append("Poll option \(index) has empty ID")
            }
            if option.text.isEmpty {
                errors.append("Poll option \(index) has empty text")
            }
            if option.voteCount < 0 {
                errors.append("Poll option \(index) has negative vote count")
            }
            if option.percentage < 0 || option.percentage > 100 {
                errors.append("Poll option \(index) has invalid percentage: \(option.percentage)")
            }
        }
        
        // Validate broadcastId/matchId
        let broadcastId = pollData.broadcastId ?? pollData.matchId
        if broadcastId.isEmpty {
            errors.append("Poll has empty broadcastId/matchId")
        }
        
        // Validate vote counts consistency
        let calculatedTotal = pollData.options.reduce(0) { $0 + $1.voteCount }
        if pollData.totalVotes != calculatedTotal {
            errors.append("Poll totalVotes (\(pollData.totalVotes)) doesn't match sum of option votes (\(calculatedTotal))")
        }
        
        if errors.isEmpty {
            return .valid
        } else {
            return .invalid(errors)
        }
    }
    
    /// Validate contest data from backend
    static func validate(_ contestData: ContestsResponse.ContestData) -> ValidationResult {
        var errors: [String] = []
        
        // Validate required fields
        if contestData.id.isEmpty {
            errors.append("Contest ID is empty")
        }
        
        if contestData.title.isEmpty {
            errors.append("Contest title is empty")
        }
        
        if contestData.description.isEmpty {
            errors.append("Contest description is empty")
        }
        
        // Validate contest type
        if contestData.contestType != "quiz" && contestData.contestType != "giveaway" {
            errors.append("Contest has invalid type: \(contestData.contestType)")
        }
        
        // Validate broadcastId/matchId
        let broadcastId = contestData.broadcastId ?? contestData.matchId
        if broadcastId.isEmpty {
            errors.append("Contest has empty broadcastId/matchId")
        }
        
        if errors.isEmpty {
            return .valid
        } else {
            return .invalid(errors)
        }
    }
    
    enum ValidationResult {
        case valid
        case invalid([String])
        
        var isValid: Bool {
            if case .valid = self {
                return true
            }
            return false
        }
        
        var errors: [String] {
            if case .invalid(let errors) = self {
                return errors
            }
            return []
        }
    }
}
