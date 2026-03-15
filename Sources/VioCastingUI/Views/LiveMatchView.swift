//
//  LiveMatchView.swift
//  VioCastingUI
//

import SwiftUI
import VioCore
import VioDesignSystem

/// Main live match view - refactored using small, reusable components
public struct LiveMatchView: View {
    let match: Match
    let onDismiss: () -> Void
    let sessionContext: VioSessionContext?

    @StateObject private var viewModel: LiveMatchViewModel
    @StateObject private var defaultSessionContext: VioSessionContext

    /// - Parameters:
    ///   - match: Match model for the live event
    ///   - onDismiss: Callback when user dismisses the view
    ///   - sessionContext: Optional session context (userId, broadcastContext). If nil, a default is created from match for backward compatibility.
    public init(match: Match, onDismiss: @escaping () -> Void, sessionContext: VioSessionContext? = nil) {
        self.match = match
        self.onDismiss = onDismiss
        self.sessionContext = sessionContext
        self._viewModel = StateObject(wrappedValue: LiveMatchViewModel(match: match))
        self._defaultSessionContext = StateObject(wrappedValue: VioSessionContext(broadcastContext: match.toBroadcastContext()))
    }

    private var effectiveSessionContext: VioSessionContext {
        sessionContext ?? defaultSessionContext
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: "1B1B25").ignoresSafeArea()

                VStack(spacing: 0) {
                    MatchHeaderView(
                        match: match,
                        homeScore: viewModel.currentHomeScore,
                        awayScore: viewModel.currentAwayScore,
                        currentMinute: viewModel.timeline.currentMinute,
                        onDismiss: onDismiss
                    )
                    .padding(.top, -8)

                    MatchNavigationTabs(selectedTab: $viewModel.selectedTab)

                    MatchContentView(
                        selectedTab: viewModel.selectedTab,
                        viewModel: viewModel
                    )
                    .frame(maxHeight: .infinity)

                    VideoTimelineControl(
                        currentMinute: viewModel.timeline.currentMinute,
                        liveMinute: viewModel.timeline.liveMinute,
                        isAtLive: viewModel.timeline.isLive,
                        selectedMinute: $viewModel.selectedMinute,
                        events: viewModel.matchSimulation.events,
                        isPlaying: viewModel.playerViewModel.isPlaying,
                        isMuted: viewModel.playerViewModel.isMuted,
                        totalDuration: 120,
                        onPlayPause: viewModel.playerViewModel.togglePlayPause,
                        onToggleMute: viewModel.playerViewModel.toggleMute,
                        onGoToLive: viewModel.goToLive,
                        onSeek: { minute in
                            viewModel.jumpToMinute(minute)
                        },
                        onNavigateToNextCastingContest: {
                            viewModel.navigateToNextCastingContest()
                        },
                        onNavigateToPreviousCastingContest: {
                            viewModel.navigateToPreviousCastingContest()
                        }
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .environmentObject(effectiveSessionContext)
        .onAppear {
            viewModel.onAppear()
            // Auto-discovery: trigger discoverCampaigns so sponsor logo + components are loaded
            let ctx = effectiveSessionContext
            Task {
                let broadcastId = ctx.contentId ?? ctx.broadcastContext?.broadcastId
                await CampaignManager.shared.discoverCampaigns(broadcastId: broadcastId)
            }
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}
