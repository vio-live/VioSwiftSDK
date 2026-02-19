//
//  UnifiedTimelineManager.swift
//  Viaplay
//
//  Unified timeline manager for all events
//  Syncs chat, match events, polls, products, etc. with video timestamp
//  Ready for backend integration
//

import Foundation
import Combine
import VioCastingUI

@MainActor
class UnifiedTimelineManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentVideoTime: TimeInterval = 0  // User's current position (can be in past)
    @Published var liveVideoTime: TimeInterval = 0     // Real-time position (always advancing)
    @Published private(set) var allEvents: [AnyTimelineEvent] = []
    
    // MARK: - Computed Properties
    
    var currentMinute: Int {
        Int(currentVideoTime / 60)  // Can be negative for pre-match
    }
    
    var liveMinute: Int {
        Int(liveVideoTime / 60)  // Can be negative for pre-match
    }
    
    var displayMinute: String {
        let min = currentMinute
        return min < 0 ? "\(min)'" : "\(min)'"
    }
    
    /// Is user watching LIVE (at real-time position)?
    var isLive: Bool {
        abs(currentVideoTime - liveVideoTime) < 5  // Within 5 seconds = live
    }
    
    /// How far behind live is the user?
    var timeBehindLive: TimeInterval {
        max(0, liveVideoTime - currentVideoTime)
    }
    
    var currentDisplayTime: String {
        let minutes = Int(currentVideoTime / 60)
        let seconds = Int(currentVideoTime.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var visibleEvents: [AnyTimelineEvent] {
        allEvents
            .filter { $0.videoTimestamp <= currentVideoTime }
            .sorted { event1, event2 in
                if event1.videoTimestamp == event2.videoTimestamp {
                    return event1.displayPriority > event2.displayPriority
                }
                return event1.videoTimestamp > event2.videoTimestamp
            }
    }
    
    // MARK: - Public Methods
    
    /// Add an event to the timeline
    func addEvent<T: TimelineEvent>(_ event: T) {
        let wrappedEvent = AnyTimelineEvent(event)
        allEvents.append(wrappedEvent)
        allEvents.sort { $0.videoTimestamp < $1.videoTimestamp }
    }
    
    /// Add multiple events
    func addEvents<T: TimelineEvent>(_ events: [T]) {
        for event in events {
            addEvent(event)
        }
    }
    
    /// Add multiple wrapped events (for pre-generated data)
    func addWrappedEvents(_ events: [AnyTimelineEvent]) {
        self.allEvents.append(contentsOf: events)
        self.allEvents.sort { $0.videoTimestamp < $1.videoTimestamp }
    }
    
    /// Remove an event
    func removeEvent(id: String) {
        allEvents.removeAll { $0.id == id }
    }
    
    /// Clear all events
    func clearAllEvents() {
        allEvents.removeAll()
    }
    
    // MARK: - Match Duration Constants
    
    static let preMatchDuration: TimeInterval = 900     // 15 minutes before kickoff
    static let firstHalfDuration: TimeInterval = 2700   // 45 minutes
    static let halfTimeDuration: TimeInterval = 900     // 15 minutes pause
    static let secondHalfDuration: TimeInterval = 2700  // 45 minutes
    static let postMatchDuration: TimeInterval = 900    // 15 minutes after
    static let totalMatchDuration: TimeInterval = 7200  // 120 minutes total
    
    /// Update user's video time (called by scrubber)
    func updateVideoTime(_ seconds: TimeInterval) {
        // Allow negative time for pre-match, cap at live position
        let clampedTime = max(-Self.preMatchDuration, min(seconds, liveVideoTime))
        currentVideoTime = clampedTime
    }
    
    /// Update live time (called by playback timer)
    func updateLiveTime(_ seconds: TimeInterval) {
        let clampedTime = max(0, min(seconds, Self.totalMatchDuration))
        liveVideoTime = clampedTime
        
        // If user is watching live, keep them in sync
        if isLive {
            currentVideoTime = liveVideoTime
        }
    }
    
    /// Jump to specific minute
    func jumpToMinute(_ minute: Int) {
        let seconds = TimeInterval(minute * 60)
        updateVideoTime(seconds)
    }
    
    /// Go to LIVE (jump to real-time position)
    func goToLive() {
        currentVideoTime = liveVideoTime
    }
    
    /// Get match phase at current time
    func currentMatchPhase() -> MatchPhase {
        if currentVideoTime < Self.firstHalfDuration {
            return .firstHalf
        } else if currentVideoTime < Self.firstHalfDuration + Self.halfTimeDuration {
            return .halfTime
        } else {
            return .secondHalf
        }
    }
    
    // MARK: - Filtering by Type
    
    func events(ofType type: TimelineEventType) -> [AnyTimelineEvent] {
        return visibleEvents.filter { $0.eventType == type }
    }
    
    func events(ofCategory category: TimelineEventCategory) -> [AnyTimelineEvent] {
        return visibleEvents.filter { $0.eventType.category == category }
    }
    
    // MARK: - Type-Safe Getters
    
    func visibleChatMessages() -> [ChatMessageEvent] {
        events(ofType: .chatMessage).compactMap { $0.event as? ChatMessageEvent }
    }
    
    func visibleMatchGoals() -> [MatchGoalEvent] {
        events(ofType: .matchGoal).compactMap { $0.event as? MatchGoalEvent }
    }
    
    func visiblePolls() -> [PollTimelineEvent] {
        events(ofType: .poll).compactMap { $0.event as? PollTimelineEvent }
    }
    
    func visibleTweets() -> [TweetEvent] {
        events(ofType: .tweet).compactMap { $0.event as? TweetEvent }
    }
    
    func visibleProducts() -> [ProductTimelineEvent] {
        events(ofType: .productHighlight).compactMap { $0.event as? ProductTimelineEvent }
    }
    
    func visibleAdminComments() -> [AdminCommentEvent] {
        events(ofType: .adminComment).compactMap { $0.event as? AdminCommentEvent }
    }
    
    func visibleAnnouncements() -> [AnnouncementEvent] {
        events(ofType: .announcement).compactMap { $0.event as? AnnouncementEvent }
    }
    
    // MARK: - Backend Integration Helpers
    
    /// Export events for backend sync (JSON ready)
    func exportEventsForBackend() -> Data? {
        let exportData = allEvents.map { event in
            EventExportData(
                id: event.id,
                videoTimestamp: event.videoTimestamp,
                eventType: event.eventType.rawValue,
                metadata: event.metadata
            )
        }
        return try? JSONEncoder().encode(exportData)
    }
    
    /// Import events from backend
    func importEventsFromBackend(_ data: Data) throws {
        // TODO: Implement when backend structure is defined
        // Will decode JSON and create appropriate event objects
    }
}

enum MatchPhase {
    case preMatch
    case firstHalf
    case halfTime
    case secondHalf
    case postMatch
    
    var displayName: String {
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

/// Type-erased wrapper for storing different event types in same array
struct AnyTimelineEvent: Identifiable {
    let id: String
    let videoTimestamp: TimeInterval
    let eventType: TimelineEventType
    let displayPriority: Int
    let metadata: [String: String]?
    let event: Any  // Original typed event
    
    init<T: TimelineEvent>(_ event: T) {
        self.id = event.id
        self.videoTimestamp = event.videoTimestamp
        self.eventType = event.eventType
        self.displayPriority = event.displayPriority
        self.metadata = event.metadata
        self.event = event
    }
}

// MARK: - Backend Export Model

struct EventExportData: Codable {
    let id: String
    let videoTimestamp: TimeInterval
    let eventType: String
    let metadata: [String: String]?
}
