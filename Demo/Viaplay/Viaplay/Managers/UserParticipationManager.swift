//
//  UserParticipationManager.swift
//  Viaplay
//
//  Manages user participation state for polls and contests
//

import Foundation
import Combine

@MainActor
class UserParticipationManager: ObservableObject {
    static let shared = UserParticipationManager()
    
    @Published private(set) var participatedPolls: Set<String> = []
    @Published private(set) var participatedContests: Set<String> = []
    @Published private(set) var pollVotes: [String: String] = [:]  // pollId: optionId
    
    private let pollsKey = "viaplay.participated.polls"
    private let contestsKey = "viaplay.participated.contests"
    private let votesKey = "viaplay.poll.votes"
    
    private init() {
        loadState()
    }
    
    // MARK: - Poll Participation
    
    func hasVotedInPoll(_ pollId: String) -> Bool {
        participatedPolls.contains(pollId)
    }
    
    func getVote(for pollId: String) -> String? {
        pollVotes[pollId]
    }
    
    func recordPollVote(pollId: String, optionId: String) {
        participatedPolls.insert(pollId)
        pollVotes[pollId] = optionId
        saveState()
        
        print("📊 [Participation] Recorded vote in poll \(pollId): \(optionId)")
    }
    
    // MARK: - Contest Participation
    
    func hasParticipatedInContest(_ contestId: String) -> Bool {
        participatedContests.contains(contestId)
    }
    
    func recordContestParticipation(contestId: String) {
        participatedContests.insert(contestId)
        saveState()
        
        print("🏆 [Participation] Recorded contest participation: \(contestId)")
    }
    
    // MARK: - Persistence
    
    private func loadState() {
        if let pollsData = UserDefaults.standard.array(forKey: pollsKey) as? [String] {
            participatedPolls = Set(pollsData)
        }
        
        if let contestsData = UserDefaults.standard.array(forKey: contestsKey) as? [String] {
            participatedContests = Set(contestsData)
        }
        
        if let votesData = UserDefaults.standard.dictionary(forKey: votesKey) as? [String: String] {
            pollVotes = votesData
        }
        
        print("💾 [Participation] Loaded state: \(participatedPolls.count) polls, \(participatedContests.count) contests")
    }
    
    private func saveState() {
        UserDefaults.standard.set(Array(participatedPolls), forKey: pollsKey)
        UserDefaults.standard.set(Array(participatedContests), forKey: contestsKey)
        UserDefaults.standard.set(pollVotes, forKey: votesKey)
        
        print("💾 [Participation] Saved state")
    }
    
    // MARK: - Reset (for testing)
    
    func resetAll() {
        participatedPolls.removeAll()
        participatedContests.removeAll()
        pollVotes.removeAll()
        saveState()
        
        print("🔄 [Participation] Reset all participation")
    }
}
