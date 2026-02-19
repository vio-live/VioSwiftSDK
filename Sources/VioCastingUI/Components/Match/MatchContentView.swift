//
//  MatchContentView.swift
//  Viaplay
//
//  Organism component: Match content router by selected tab
//

import SwiftUI

struct MatchContentView: View {
    let selectedTab: MatchTab
    @ObservedObject var viewModel: LiveMatchViewModel
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                switch selectedTab {
                case .all:
                    if viewModel.useTimelineSync {
                        AllContentFeed(
                            timelineEvents: viewModel.visibleTimelineEvents(),
                            statistics: viewModel.matchStatistics,
                            canChat: true,
                            onPollVote: viewModel.handlePollVote,
                            onSelectTab: viewModel.selectTab,
                            onSendMessage: { text in
                                viewModel.sendChatMessage(text)
                            },
                            onNavigateToTimestamp: { timestamp in
                                viewModel.navigateToTimestamp(timestamp)
                            },
                            lastNavigatedTimestamp: $viewModel.lastNavigatedTimestamp
                        )
                    } else {
                        AllContentFeed(
                            timelineEvents: [],
                            statistics: viewModel.matchStatistics,
                            canChat: true,
                            onPollVote: viewModel.handlePollVote,
                            onSelectTab: viewModel.selectTab,
                            onSendMessage: { text in
                                viewModel.sendChatMessage(text)
                            },
                            onNavigateToTimestamp: nil,
                            lastNavigatedTimestamp: .constant(0)
                        )
                    }
                    
                case .chat:
                    ChatListView(
                        messages: viewModel.filteredChatMessages(),
                        viewerCount: viewModel.chatManager.viewerCount,
                        selectedMinute: viewModel.selectedMinute,
                        canChat: true,
                        onSendMessage: { text in
                            viewModel.sendChatMessage(text)
                        }
                    )
                    
                case .highlights:
                    // Same style as All, but filtered to highlight-worthy events
                    AllContentFeed(
                        timelineEvents: viewModel.timeline.visibleEvents.filter { event in
                            // Show all important match events + lineups
                            switch event.eventType {
                            case .matchGoal, .matchCard, .matchSubstitution,
                                 .highlight, .statisticsUpdate:
                                return true
                            case .adminComment:
                                // Show commentary for goals and cards
                                if let commentary = event.event as? CommentaryEvent {
                                    return commentary.isHighlighted || 
                                           commentary.commentaryType == .goal ||
                                           commentary.commentaryType == .card
                                }
                                return true
                            case .announcement:
                                // Include lineups, stats, and phase announcements
                                if let announcement = event.event as? AnnouncementEvent {
                                    let type = announcement.metadata?["type"]
                                    return type == "lineup" ||
                                           type == "halftime-stats" ||
                                           type == "fulltime-stats" ||
                                           type == "final-stats" ||
                                           type == "kickoff" ||
                                           type == "halftime" ||
                                           type == "fulltime"
                                }
                                return false
                            default:
                                return false
                            }
                        },
                        statistics: viewModel.matchStatistics,
                        canChat: false,
                        onPollVote: viewModel.handlePollVote,
                        onSelectTab: viewModel.selectTab,
                        onSendMessage: nil,
                        onNavigateToTimestamp: viewModel.useTimelineSync ? { timestamp in
                            viewModel.navigateToTimestamp(timestamp)
                        } : nil,
                        lastNavigatedTimestamp: viewModel.useTimelineSync ? $viewModel.lastNavigatedTimestamp : .constant(0)
                    )
                    
                case .liveScores:
                    LiveScoresListView()
                    
                case .polls:
                    PollsListView(
                        timelinePolls: viewModel.timeline.allEvents
                            .filter { $0.eventType == .poll }
                            .compactMap { $0.event as? PollTimelineEvent },
                        contests: viewModel.timeline.allEvents
                            .filter { $0.eventType == .announcement }
                            .compactMap { $0.event as? AnnouncementEvent }
                            .filter { $0.metadata?["type"] == "contest" },
                        castingContests: viewModel.timeline.allEvents
                            .filter { $0.eventType == .castingContest }
                            .compactMap { $0.event as? CastingContestEvent },
                        timeline: viewModel.timeline,
                        onNavigateToTimestamp: viewModel.useTimelineSync ? { timestamp in
                            viewModel.navigateToTimestamp(timestamp)
                        } : nil
                    )
                    
                case .statistics:
                    MatchStatsView(statistics: viewModel.matchStatistics)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// MARK: - Live Scores List (Placeholder)

struct LiveScoresListView: View {
    // Sample matches with highlights
    private let sampleMatches: [LiveMatchData] = [
        LiveMatchData(
            id: "1",
            homeTeam: "Barcelona",
            awayTeam: "Real Madrid",
            homeScore: 3,
            awayScore: 2,
            minute: 87,
            isLive: true,
            competition: "Champions League",
            highlights: [
                MatchHighlightData(title: "MÅL: Lewandowski", minute: 23, videoURL: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/1.MP4?alt=media&token=898b7836-5e27-492d-82bb-9d7bb50f9d66"),
                MatchHighlightData(title: "Stor sjanse!", minute: 45, videoURL: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/2.MP4?alt=media&token=9011a94a-1085-4b69-bd41-3b1432ca577a"),
                MatchHighlightData(title: "Gult kort: Ramos", minute: 67, videoURL: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/3.MP4?alt=media&token=f28dadf8-05df-4544-a21f-a4c45836793f")
            ]
        ),
        LiveMatchData(
            id: "2",
            homeTeam: "Manchester City",
            awayTeam: "Liverpool",
            homeScore: 1,
            awayScore: 1,
            minute: 72,
            isLive: true,
            competition: "Premier League",
            highlights: [
                MatchHighlightData(title: "MÅL: Haaland", minute: 34, videoURL: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/1.MP4?alt=media&token=898b7836-5e27-492d-82bb-9d7bb50f9d66"),
                MatchHighlightData(title: "MÅL: Salah", minute: 56, videoURL: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/2.MP4?alt=media&token=9011a94a-1085-4b69-bd41-3b1432ca577a")
            ]
        ),
        LiveMatchData(
            id: "3",
            homeTeam: "Bayern Munich",
            awayTeam: "PSG",
            homeScore: 2,
            awayScore: 0,
            minute: 90,
            isLive: false,
            competition: "Champions League",
            highlights: [
                MatchHighlightData(title: "MÅL: Müller", minute: 12, videoURL: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/1.MP4?alt=media&token=898b7836-5e27-492d-82bb-9d7bb50f9d66"),
                MatchHighlightData(title: "MÅL: Sané", minute: 38, videoURL: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/3.MP4?alt=media&token=f28dadf8-05df-4544-a21f-a4c45836793f")
            ]
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Live Resultater")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text("\(sampleMatches.filter { $0.isLive }.count) LIVE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Match cards
                ForEach(sampleMatches) { match in
                    ExpandableLiveScoreCard(match: match)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(hex: "1B1B25"))
    }
}

// MARK: - Live Score Item

private struct LiveScoreItem: View {
    let index: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Team A")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("\(index)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text("Team B")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("Premier League")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(45 + index)'")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Live Match Models

struct LiveMatchData: Identifiable {
    let id: String
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int
    let awayScore: Int
    let minute: Int
    let isLive: Bool
    let competition: String
    let highlights: [MatchHighlightData]
}

struct MatchHighlightData: Identifiable {
    let id = UUID()
    let title: String
    let minute: Int
    let videoURL: String
}

// MARK: - Expandable Card

private struct ExpandableLiveScoreCard: View {
    let match: LiveMatchData
    @State private var isExpanded = false
    @State private var showVideoPlayer = false
    @State private var selectedHighlight: MatchHighlightData?
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(spacing: 10) {
                    HStack {
                        Text(match.homeTeam).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(match.homeScore)").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                            Circle().fill(Color.white.opacity(0.3)).frame(width: 6, height: 6)
                            Text("\(match.awayScore)").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        }
                        Spacer()
                        Text(match.awayTeam).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                    }
                    HStack {
                        Text(match.competition).font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        if match.isLive {
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                                Text("LIVE • \(match.minute)'").font(.system(size: 12, weight: .medium)).foregroundColor(.red)
                            }
                        } else {
                            Text("Fulltid").font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 10)).foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            }
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(match.highlights) { h in
                        Button(action: { selectedHighlight = h; showVideoPlayer = true }) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.3)).frame(width: 60, height: 40)
                                    Image(systemName: "play.fill").font(.system(size: 14)).foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(h.title).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                    Text("\(h.minute)'").font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.white.opacity(0.3))
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let h = selectedHighlight, let url = URL(string: h.videoURL) {
                HighlightVideoPlayerView(videoURL: url, title: h.title) { showVideoPlayer = false }
            }
        }
    }
}

#Preview {
    MatchContentView_PreviewWrapper()
}

private struct MatchContentView_PreviewWrapper: View {
    @StateObject var viewModel = LiveMatchViewModel(match: Match.barcelonaPSG)
    var body: some View {
        MatchContentView(selectedTab: .all, viewModel: viewModel)
    }
}


