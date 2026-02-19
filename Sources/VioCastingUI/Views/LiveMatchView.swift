//
//  LiveMatchView.swift
//  VioCastingUI
//

import SwiftUI
import VioDesignSystem

/// Main live match view - refactored using small, reusable components
public struct LiveMatchView: View {
    let match: Match
    let onDismiss: () -> Void

    @StateObject private var viewModel: LiveMatchViewModel

    public init(match: Match, onDismiss: @escaping () -> Void) {
        self.match = match
        self.onDismiss = onDismiss
        self._viewModel = StateObject(wrappedValue: LiveMatchViewModel(match: match))
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
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}
