//
//  LiveMatchViewModel.swift
//  VioCastingUI
//

import Foundation
import SwiftUI
import Combine
import VioEngagementSystem

// MARK: - Match Tab Enum
public enum MatchTab: String, CaseIterable {
    case all = "All"
    case chat = "Chat"
    case highlights = "Highlights"
    case statistics = "Statistics"
    case polls = "Interaktivt"
    case liveScores = "Live Scores"
    case engagement = "Engagement"

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .chat: return "message"
        case .highlights: return "play.rectangle"
        case .liveScores: return "trophy"
        case .polls: return "hand.raised.fill"
        case .statistics: return "chart.bar"
        case .engagement: return "sparkles"
        }
    }

    /// Tabs to display. Engagement tab only shown when backend has engagement (contentId flow).
    public static func visibleTabs(hasEngagement: Bool) -> [MatchTab] {
        if hasEngagement {
            return allCases
        }
        return allCases.filter { $0 != .engagement }
    }
}

@MainActor
public class LiveMatchViewModel: ObservableObject {

    @Published public var selectedTab: MatchTab = .all
    @Published public var selectedMinute: Int? = nil
    @Published public var useTimelineSync: Bool = true
    @Published public var lastNavigatedTimestamp: TimeInterval = 0

    @Published public var currentHomeScore = 0
    @Published public var currentAwayScore = 0

    public let timeline: UnifiedTimelineManager
    private var timelineCancellable: AnyCancellable?
    private var engagementCancellable: AnyCancellable?

    public let chatManager: ChatManager
    public let matchSimulation: MatchSimulationManager
    public let playerViewModel: VideoPlayerViewModel

    public let match: Match
    public let matchStatistics: MatchStatistics
    public let leagueTable: LeagueTable

    public var matchTimeline: MatchTimeline {
        MatchTimeline(events: matchSimulation.events)
    }

    public var currentFilterMinute: Int {
        selectedMinute ?? timeline.currentMinute
    }

    public var currentVideoTime: TimeInterval {
        selectedMinute.map { TimeInterval($0 * 60) } ?? timeline.currentVideoTime
    }

    public init(match: Match, useTimelineSync: Bool = true) {
        self.match = match
        self.matchStatistics = MatchStatistics.mock(for: match)
        self.leagueTable = LeagueTable.premierLeague
        self.useTimelineSync = useTimelineSync

        self.timeline = UnifiedTimelineManager()
        self.chatManager = ChatManager(timeline: timeline)
        self.matchSimulation = MatchSimulationManager(timeline: timeline)
        self.playerViewModel = VideoPlayerViewModel()

        // Forward timeline changes so UI updates when currentVideoTime/visibleEvents change
        self.timelineCancellable = timeline.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Observe backend contests from EngagementManager and inject into timeline
        self.engagementCancellable = EngagementManager.shared.$contestsByBroadcast
            .receive(on: RunLoop.main)
            .sink { [weak self] contestsByBroadcast in
                guard let self = self else { return }
                let broadcastId = self.match.contentId ?? ""
                guard !broadcastId.isEmpty,
                      let contests = contestsByBroadcast[broadcastId] else { return }
                for contest in contests {
                    let contestType: CastingContestEvent.ContestType = contest.contestType == .giveaway ? .giveaway : .quiz
                    let event = CastingContestEvent(
                        id: contest.id,
                        videoTimestamp: 0, // live — show immediately at top
                        title: contest.title,
                        description: contest.description,
                        prize: contest.prize,
                        contestType: contestType,
                        imageUrl: contest.imageUrl,
                        metadata: nil,
                        broadcastContext: contest.broadcastContext
                    )
                    // Remove existing event with same id before adding updated one
                    self.timeline.removeEvent(id: event.id)
                    self.timeline.addEvent(event)
                }
            }
    }

    public func onAppear() {
        playerViewModel.setupPlayer()

        if useTimelineSync {
            loadTimelineData()

            // Barcelona-PSG: start at 45' so halftime events (competitions, products, stats) are visible immediately
            if match.title.contains("Barcelona") && match.title.contains("PSG") {
                let halftimeStart: TimeInterval = 2700  // 45'
                timeline.liveVideoTime = halftimeStart
                timeline.currentVideoTime = halftimeStart
                selectedMinute = 45
            } else {
                timeline.liveVideoTime = -900
                timeline.currentVideoTime = -900
            }

            updateScoresFromTimeline()

            chatManager.startSimulation(withTimeline: true)
            matchSimulation.startSimulation()
            startTimelinePlayback()
        } else {
            chatManager.startSimulation(withTimeline: false)
            matchSimulation.startSimulation()
        }
    }

    public func onDisappear() {
        playerViewModel.cleanup()
        chatManager.stopSimulation()
        matchSimulation.stopSimulation()
        stopTimelinePlayback()
    }

    private var playbackTimer: Timer?

    private func startTimelinePlayback() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let previousMinute = self.timeline.liveMinute

            self.timeline.updateLiveTime(self.timeline.liveVideoTime + 1)

            if self.timeline.liveMinute != previousMinute {
                self.chatManager.loadMessagesFromTimeline()
                self.updateScoresFromTimeline()
            }

            if self.timeline.liveMinute >= 105 {
                self.stopTimelinePlayback()
            }
        }
    }

    private func stopTimelinePlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func loadTimelineData() {
        let generatedEvents: [AnyTimelineEvent]
        if match.title.contains("Real Madrid") && match.title.contains("Barcelona") {
            generatedEvents = TimelineDataGenerator.generateRealMadridBarcelonaTimeline()
        } else {
            generatedEvents = TimelineDataGenerator.generateBarcelonaPSGTimeline()
        }

        timeline.addWrappedEvents(generatedEvents)

        chatManager.loadMessagesFromTimeline()
    }

    public func handlePollVote(componentId: String, optionId: String) {
        // Poll voting handled in TimelinePollCard
    }

    public func jumpToMinute(_ minute: Int) {
        selectedMinute = minute

        if useTimelineSync {
            let newTime = TimeInterval(minute * 60)
            timeline.currentVideoTime = newTime

            updateScoresFromTimeline()
            chatManager.loadMessagesFromTimeline()
            objectWillChange.send()
        }
    }

    public func goToLive() {
        selectedMinute = nil

        if useTimelineSync {
            timeline.goToLive()
            updateScoresFromTimeline()
            chatManager.loadMessagesFromTimeline()
        }
    }

    private func updateScoresFromTimeline() {
        let allGoals = timeline.visibleEvents
            .filter { $0.eventType == .matchGoal }
            .compactMap { $0.event as? MatchGoalEvent }

        var home = 0
        var away = 0

        for goal in allGoals {
            if goal.team == .home && !goal.isOwnGoal {
                home += 1
            } else if goal.team == .away && !goal.isOwnGoal {
                away += 1
            }
        }

        currentHomeScore = home
        currentAwayScore = away
    }

    public func selectTab(_ tab: MatchTab) {
        withAnimation {
            selectedTab = tab
        }
    }

    public func sendChatMessage(_ text: String) {
        let message = ChatMessage(
            username: "Angelo",
            text: text,
            usernameColor: Color(red: 0.96, green: 0.08, blue: 0.42),
            likes: 0,
            timestamp: Date(),
            videoTimestamp: timeline.currentVideoTime
        )

        chatManager.addMessage(message)

        if useTimelineSync {
            timeline.addEvent(message.toTimelineEvent())
            chatManager.loadMessagesFromTimeline()
        }
    }

    public func filteredChatMessages() -> [ChatMessage] {
        if useTimelineSync {
            return chatManager.messages.filter { $0.videoTimestamp <= currentVideoTime }
        } else {
            return chatManager.messages.filter { message in
                let messageIndex = chatManager.messages.firstIndex(where: { $0.id == message.id }) ?? 0
                let estimatedMinute = (messageIndex * currentFilterMinute) / max(chatManager.messages.count, 1)
                return estimatedMinute <= currentFilterMinute
            }
        }
    }

    public func filteredPolls() -> [PollTimelineEvent] {
        timeline.visiblePolls()
    }

    public func filteredEvents() -> [MatchEvent] {
        matchTimeline.events.filter { $0.minute <= currentFilterMinute }
    }

    public func navigateToTimestamp(_ timestamp: TimeInterval) {
        guard useTimelineSync else { return }

        lastNavigatedTimestamp = timestamp

        timeline.currentVideoTime = timestamp

        updateScoresFromTimeline()
        chatManager.loadMessagesFromTimeline()

        objectWillChange.send()
    }

    public func navigateToNextCastingContest() {
        guard useTimelineSync else { return }

        let castingContestEvents = timeline.allEvents
            .filter { $0.eventType == .castingContest }
            .sorted { $0.videoTimestamp < $1.videoTimestamp }

        guard !castingContestEvents.isEmpty else { return }

        if let nextEvent = castingContestEvents.first(where: { $0.videoTimestamp > timeline.currentVideoTime }) {
            let adjustedTimestamp = max(0, nextEvent.videoTimestamp - 2)
            navigateToTimestamp(adjustedTimestamp)
        } else {
            if let firstEvent = castingContestEvents.first {
                let adjustedTimestamp = max(0, firstEvent.videoTimestamp - 2)
                navigateToTimestamp(adjustedTimestamp)
            }
        }
    }

    public func navigateToPreviousCastingContest() {
        guard useTimelineSync else { return }

        let castingContestEvents = timeline.allEvents
            .filter { $0.eventType == .castingContest }
            .sorted { $0.videoTimestamp < $1.videoTimestamp }

        guard !castingContestEvents.isEmpty else { return }

        if let previousEvent = castingContestEvents.last(where: { $0.videoTimestamp < timeline.currentVideoTime }) {
            let adjustedTimestamp = max(0, previousEvent.videoTimestamp - 2)
            navigateToTimestamp(adjustedTimestamp)
        } else {
            if let lastEvent = castingContestEvents.last {
                let adjustedTimestamp = max(0, lastEvent.videoTimestamp - 2)
                navigateToTimestamp(adjustedTimestamp)
            }
        }
    }

    public func visibleTimelineEvents() -> [AnyTimelineEvent] {
        guard useTimelineSync else { return [] }
        return timeline.visibleEvents
    }

    public func visibleTimelineEvents(ofType type: TimelineEventType) -> [AnyTimelineEvent] {
        guard useTimelineSync else { return [] }
        return timeline.visibleEvents.filter { $0.eventType == type }
    }

    public func allTimelineEvents() -> [AnyTimelineEvent] {
        guard useTimelineSync else { return [] }
        return timeline.allEvents
    }
}
