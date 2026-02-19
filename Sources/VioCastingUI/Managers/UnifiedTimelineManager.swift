//
//  UnifiedTimelineManager.swift
//  VioCastingUI
//

import Foundation
import Combine

@MainActor
public class UnifiedTimelineManager: ObservableObject {

    @Published public var currentVideoTime: TimeInterval = 0
    @Published public var liveVideoTime: TimeInterval = 0
    @Published private(set) var allEvents: [AnyTimelineEvent] = []

    public var currentMinute: Int {
        Int(currentVideoTime / 60)
    }

    public var liveMinute: Int {
        Int(liveVideoTime / 60)
    }

    public var displayMinute: String {
        let min = currentMinute
        return min < 0 ? "\(min)'" : "\(min)'"
    }

    public var isLive: Bool {
        abs(currentVideoTime - liveVideoTime) < 5
    }

    public var timeBehindLive: TimeInterval {
        max(0, liveVideoTime - currentVideoTime)
    }

    public var currentDisplayTime: String {
        let minutes = Int(currentVideoTime / 60)
        let seconds = Int(currentVideoTime.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var visibleEvents: [AnyTimelineEvent] {
        allEvents
            .filter { $0.videoTimestamp <= currentVideoTime }
            .sorted { event1, event2 in
                if event1.videoTimestamp == event2.videoTimestamp {
                    return event1.displayPriority > event2.displayPriority
                }
                return event1.videoTimestamp > event2.videoTimestamp
            }
    }

    public var visibleEventsDesc: [AnyTimelineEvent] {
        visibleEvents
    }

    public init() {}

    public func addEvent<T: TimelineEvent>(_ event: T) {
        let wrappedEvent = AnyTimelineEvent(event)
        allEvents.append(wrappedEvent)
        allEvents.sort { $0.videoTimestamp < $1.videoTimestamp }
    }

    public func addEvents<T: TimelineEvent>(_ events: [T]) {
        for event in events {
            addEvent(event)
        }
    }

    public func addWrappedEvents(_ events: [AnyTimelineEvent]) {
        allEvents.append(contentsOf: events)
        allEvents.sort { $0.videoTimestamp < $1.videoTimestamp }
    }

    public func removeEvent(id: String) {
        allEvents.removeAll { $0.id == id }
    }

    public func clearAllEvents() {
        allEvents.removeAll()
    }

    public static let preMatchDuration: TimeInterval = 900
    public static let firstHalfDuration: TimeInterval = 2700
    public static let halfTimeDuration: TimeInterval = 900
    public static let secondHalfDuration: TimeInterval = 2700
    public static let postMatchDuration: TimeInterval = 900
    public static let totalMatchDuration: TimeInterval = 7200

    public func updateVideoTime(_ seconds: TimeInterval) {
        let clampedTime = max(-Self.preMatchDuration, min(seconds, liveVideoTime))
        currentVideoTime = clampedTime
    }

    public func updateLiveTime(_ seconds: TimeInterval) {
        let clampedTime = max(0, min(seconds, Self.totalMatchDuration))
        liveVideoTime = clampedTime
        if isLive {
            currentVideoTime = liveVideoTime
        }
    }

    public func jumpToMinute(_ minute: Int) {
        let seconds = TimeInterval(minute * 60)
        updateVideoTime(seconds)
    }

    public func goToLive() {
        currentVideoTime = liveVideoTime
    }

    public func currentMatchPhase() -> MatchPhase {
        if currentVideoTime < Self.firstHalfDuration {
            return .firstHalf
        } else if currentVideoTime < Self.firstHalfDuration + Self.halfTimeDuration {
            return .halfTime
        } else {
            return .secondHalf
        }
    }

    public func events(ofType type: TimelineEventType) -> [AnyTimelineEvent] {
        visibleEvents.filter { $0.eventType == type }
    }

    public func events(ofCategory category: TimelineEventCategory) -> [AnyTimelineEvent] {
        visibleEvents.filter { $0.eventType.category == category }
    }

    public func visibleChatMessages() -> [ChatMessageEvent] {
        events(ofType: .chatMessage).compactMap { $0.event as? ChatMessageEvent }
    }

    public func visibleMatchGoals() -> [MatchGoalEvent] {
        events(ofType: .matchGoal).compactMap { $0.event as? MatchGoalEvent }
    }

    public func visiblePolls() -> [PollTimelineEvent] {
        events(ofType: .poll).compactMap { $0.event as? PollTimelineEvent }
    }

    public func visibleTweets() -> [TweetEvent] {
        events(ofType: .tweet).compactMap { $0.event as? TweetEvent }
    }

    public func visibleProducts() -> [ProductTimelineEvent] {
        events(ofType: .productHighlight).compactMap { $0.event as? ProductTimelineEvent }
    }

    public func visibleAdminComments() -> [AdminCommentEvent] {
        events(ofType: .adminComment).compactMap { $0.event as? AdminCommentEvent }
    }

    public func visibleAnnouncements() -> [AnnouncementEvent] {
        events(ofType: .announcement).compactMap { $0.event as? AnnouncementEvent }
    }

    public func exportEventsForBackend() -> Data? {
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

    public func importEventsFromBackend(_ data: Data) throws {
        // TODO: Implement when backend structure is defined
    }
}
