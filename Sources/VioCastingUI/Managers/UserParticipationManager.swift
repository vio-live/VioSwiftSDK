//
//  UserParticipationManager.swift
//  VioCastingUI
//
//  Manages user participation state for polls and contests
//

import Foundation
import Combine

@MainActor
public class UserParticipationManager: ObservableObject {
    public static let shared = UserParticipationManager()
    
    @Published public private(set) var participatedPolls: Set<String> = []
    @Published public private(set) var participatedContests: Set<String> = []
    @Published public private(set) var pollVotes: [String: String] = [:]  // pollId: optionId
    
    private let pollsKey = "reachu.participated.polls"
    private let contestsKey = "reachu.participated.contests"
    private let votesKey = "reachu.poll.votes"
    
    private init() {
        loadState()
    }
    
    // MARK: - Poll Participation
    
    public func hasVotedInPoll(_ pollId: String) -> Bool {
        participatedPolls.contains(pollId)
    }
    
    public func getVote(for pollId: String) -> String? {
        pollVotes[pollId]
    }
    
    public func recordPollVote(pollId: String, optionId: String) {
        participatedPolls.insert(pollId)
        pollVotes[pollId] = optionId
        saveState()
    }
    
    // MARK: - Contest Participation
    
    public func hasParticipatedInContest(_ contestId: String) -> Bool {
        participatedContests.contains(contestId)
    }
    
    public func recordContestParticipation(contestId: String) {
        participatedContests.insert(contestId)
        saveState()
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
    }
    
    private func saveState() {
        UserDefaults.standard.set(Array(participatedPolls), forKey: pollsKey)
        UserDefaults.standard.set(Array(participatedContests), forKey: contestsKey)
        UserDefaults.standard.set(pollVotes, forKey: votesKey)
    }
    
    // MARK: - Reset (for testing)
    
    public func resetAll() {
        participatedPolls.removeAll()
        participatedContests.removeAll()
        pollVotes.removeAll()
        saveState()
    }
}
