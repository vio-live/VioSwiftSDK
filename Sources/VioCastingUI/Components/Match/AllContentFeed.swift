//
//  AllContentFeed.swift
//  Viaplay
//
//  Organism component: Mixed content feed (All tab)
//

import SwiftUI
import VioEngagementUI

struct AllContentFeed: View {
    let timelineEvents: [AnyTimelineEvent]
    let statistics: MatchStatistics
    let canChat: Bool
    let onPollVote: (String, String) -> Void
    let onSelectTab: (MatchTab) -> Void
    let onSendMessage: ((String) -> Void)?
    let onNavigateToTimestamp: ((TimeInterval) -> Void)?
    @Binding var lastNavigatedTimestamp: TimeInterval
    
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var showShareModal = false
    @State private var shareVideoTitle = ""
    @State private var shareVideoURL: URL?
    @State private var scrolledToTop = false
    
    init(
        timelineEvents: [AnyTimelineEvent],
        statistics: MatchStatistics,
        canChat: Bool = true,
        onPollVote: @escaping (String, String) -> Void,
        onSelectTab: @escaping (MatchTab) -> Void,
        onSendMessage: ((String) -> Void)? = nil,
        onNavigateToTimestamp: ((TimeInterval) -> Void)? = nil,
        lastNavigatedTimestamp: Binding<TimeInterval> = .constant(0)
    ) {
        self.timelineEvents = timelineEvents
        self.statistics = statistics
        self.canChat = canChat
        self.onPollVote = onPollVote
        self.onSelectTab = onSelectTab
        self.onSendMessage = onSendMessage
        self.onNavigateToTimestamp = onNavigateToTimestamp
        self._lastNavigatedTimestamp = lastNavigatedTimestamp
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Events scroll view
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // Welcome message - shown immediately at the top
                        welcomeMessage
                            .id("welcome")
                        
                        // Events oldest to newest (antiguos arriba, nuevos abajo)
                        ForEach(timelineEvents.sorted { $0.videoTimestamp < $1.videoTimestamp }, id: \.id) { wrappedEvent in
                            renderEvent(wrappedEvent)
                                .id(wrappedEvent.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        // Invisible anchor at bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, canChat ? (80 + keyboardHeight) : 12)
                }
                .onAppear {
                    // Scroll to welcome message on first appear
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("welcome", anchor: .top)
                        }
                    }
                }
                .onChange(of: timelineEvents.count) { _ in
                    // Only scroll when count actually changes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: keyboardHeight) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: lastNavigatedTimestamp) { newTimestamp in
                    // When navigating to a timestamp, check if we need to scroll to an Elkjøp contest
                    handlePowerContestScroll(proxy: proxy, timestamp: newTimestamp)
                }
            }
            
            // Chat input - Fixed at bottom
            if canChat {
                ChatInputBar(
                    messageText: $messageText,
                    isFocused: $isInputFocused,
                    onSend: {
                        guard !messageText.isEmpty else { return }
                        onSendMessage?(messageText)
                        messageText = ""
                        isInputFocused = false
                    }
                )
            }
        }
        .background(Color(hex: "1B1B25"))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Swipe down to dismiss keyboard
                    if value.translation.height > 50 {
                        isInputFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
        )
        .onAppear {
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
        .overlay(
            Group {
                if showShareModal, let url = shareVideoURL {
                    ShareHighlightModal(
                        highlightTitle: shareVideoTitle,
                        videoURL: url,
                        onDismiss: {
                            showShareModal = false
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(999)  // Ensure it's on top
                }
            }
        )
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func handlePowerContestScroll(proxy: ScrollViewProxy, timestamp: TimeInterval) {
        // Find Elkjøp contest events near the navigated timestamp
        let castingContestEvents = timelineEvents
            .filter({ $0.eventType == .castingContest })
            .sorted(by: { $0.videoTimestamp < $1.videoTimestamp })
        
        // Check if any Elkjøp contest is within 5 seconds of the navigated timestamp
        if let targetEvent = castingContestEvents.first(where: { 
            abs($0.videoTimestamp - timestamp) <= 5 
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(targetEvent.id, anchor: .top)
                }
            }
        }
    }
    
    // MARK: - Welcome Message
    
    private var welcomeMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "soccerball.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(red: 0.96, green: 0.08, blue: 0.42))
                }
                
                Text("Kampen starter snart")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text("Startoppstillingene kommer snart. Følg med her for å se alle hendelsene, kommentarer og høydepunkter fra kampen i sanntid.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.15),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Default Lineups
    
    private func getDefaultLineup(team: String, formation: String) -> [PlayerInfo] {
        if team == "home" && formation == "4-3-3" {
            return [
                PlayerInfo(number: 31, name: "Ter Stegen", position: "Keeper"),
                PlayerInfo(number: 2, name: "Koundé", position: "Forsvar"),
                PlayerInfo(number: 15, name: "Araújo", position: "Forsvar"),
                PlayerInfo(number: 6, name: "Christensen", position: "Forsvar"),
                PlayerInfo(number: 13, name: "Alba", position: "Forsvar"),
                PlayerInfo(number: 25, name: "Busquets", position: "Midtbane"),
                PlayerInfo(number: 37, name: "De Jong", position: "Midtbane"),
                PlayerInfo(number: 8, name: "Pedri", position: "Midtbane"),
                PlayerInfo(number: 7, name: "Dembélé", position: "Angrep"),
                PlayerInfo(number: 30, name: "Lewandowski", position: "Angrep"),
                PlayerInfo(number: 10, name: "Ferran", position: "Angrep")
            ]
        } else if team == "away" && formation == "4-4-2" {
            return [
                PlayerInfo(number: 99, name: "Donnarumma", position: "Keeper"),
                PlayerInfo(number: 2, name: "Hakimi", position: "Forsvar"),
                PlayerInfo(number: 5, name: "Marquinhos", position: "Forsvar"),
                PlayerInfo(number: 4, name: "Ramos", position: "Forsvar"),
                PlayerInfo(number: 25, name: "Mendes", position: "Forsvar"),
                PlayerInfo(number: 17, name: "Vitinha", position: "Midtbane"),
                PlayerInfo(number: 8, name: "Ruiz", position: "Midtbane"),
                PlayerInfo(number: 19, name: "Lee", position: "Midtbane"),
                PlayerInfo(number: 33, name: "Zaïre-Emery", position: "Midtbane"),
                PlayerInfo(number: 7, name: "Mbappé", position: "Angrep"),
                PlayerInfo(number: 23, name: "Kolo Muani", position: "Angrep")
            ]
        }
        return []
    }
    
    @ViewBuilder
    private func renderEvent(_ wrappedEvent: AnyTimelineEvent) -> some View {
        Group {
            switch wrappedEvent.eventType {
            // Match events
            case .matchGoal, .matchCard, .matchSubstitution, .matchKickOff, .matchHalfTime, .matchFullTime:
                if let matchEvent = wrappedEvent.event as? MatchEvent {
                    TimelineEventCard(event: matchEvent)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    EmptyView()
                }
                
            // Chat
            case .chatMessage:
                if let chatEvent = wrappedEvent.event as? ChatMessageEvent {
                    ChatMessageRow(
                        message: ChatMessage(
                            username: chatEvent.username,
                            text: chatEvent.text,
                            usernameColor: chatEvent.colorValue,
                            likes: chatEvent.likes,
                            timestamp: chatEvent.timestamp,
                            videoTimestamp: chatEvent.videoTimestamp
                        )
                    )
                    // ChatMessageRow already has its own transition
                }
                
            // Admin comments & Commentary
            case .adminComment:
                // Try commentary first, then admin comment
                if let commentaryEvent = wrappedEvent.event as? CommentaryEvent {
                    CommentaryCard(commentary: commentaryEvent)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else if let adminEvent = wrappedEvent.event as? AdminCommentEvent {
                    AdminCommentCard(comment: adminEvent)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                
            // Tweets
            case .tweet:
                if let tweetEvent = wrappedEvent.event as? TweetEvent {
                    TweetCard(tweet: tweetEvent)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                }
                
            // Polls
            case .poll:
                if let pollEvent = wrappedEvent.event as? PollTimelineEvent {
                    TimelinePollCard(
                        poll: pollEvent,
                        onVote: { optionId in
                            print("📊 Usuario votó: \(optionId) en poll: \(pollEvent.id)")
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                
            // Casting Products
            case .castingProduct:
                if let productEvent = wrappedEvent.event as? CastingProductEvent {
                    CastingProductCardWrapper(
                        productEvent: productEvent,
                        onViewProduct: {
                            print("🛒 Usuario ve Elkjøp product: \(productEvent.id)")
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            
            // Elkjøp Contests
            case .castingContest:
                if let contest = wrappedEvent.event as? CastingContestEvent {
                    CastingContestCardWrapper(
                        contest: contest,
                        onParticipate: {
                            print("🏆 Usuario participa en Elkjøp contest: \(contest.id)")
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                
            // Announcements (including contests, lineups, interviews, etc.)
            case .announcement:
                if let announcement = wrappedEvent.event as? AnnouncementEvent {
                    // Check metadata type for special rendering
                    switch announcement.metadata?["type"] {
                    case "contest":
                        ContestCard(
                            contestId: announcement.id,
                            title: announcement.title.replacingOccurrences(of: "🏆 ", with: ""),
                            prize: announcement.metadata?["prize"] ?? "Premie",
                            question: announcement.metadata?["question"],
                            drawTime: announcement.metadata?["drawTime"],
                            onParticipate: {
                                print("🏆 Usuario participa en concurso!")
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                        
                    case "lineup":
                        // Render lineup card with proper positions
                        if let team = announcement.metadata?["team"],
                           let formation = announcement.metadata?["formation"] {
                            let players = getDefaultLineup(team: team, formation: formation)
                            
                            LineupCard(
                                teamName: announcement.title.replacingOccurrences(of: "Oppstilling ", with: ""),
                                formation: formation,
                                players: players,
                                teamColor: team == "home" ? .blue : .red,
                                isHome: team == "home"
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                    case "interview":
                        // Render interview card
                        PlayerInterviewCard(
                            playerName: announcement.metadata?["player"] ?? "",
                            playerPhoto: nil,
                            quote: announcement.message,
                            teamName: announcement.metadata?["team"] ?? ""
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                        
                    case "final-stats":
                        // Render final stats
                        FinalStatsCard(
                            statistics: statistics,
                            homeScore: 3,  // TODO: Get from match result
                            awayScore: 1
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                        
                    case "prediction":
                        // Already handled as poll
                        EmptyView()
                        
                    default:
                        // Regular announcement
                        AnnouncementCard(announcement: announcement)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                
            // Statistics
            case .statisticsUpdate:
                StatPreviewCard(
                    statistics: statistics,
                    onViewAll: { onSelectTab(.statistics) }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .opacity
                ))
                
            // Highlights with video
            case .highlight:
                if let highlightEvent = wrappedEvent.event as? HighlightTimelineEvent {
                    HighlightVideoCard(
                        highlight: highlightEvent,
                        onShare: { title, url in
                            shareVideoTitle = title
                            shareVideoURL = url
                            showShareModal = true
                        }
                    )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                
            // Other types - add as needed
            default:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: wrappedEvent.id)
    }
}

#Preview {
    AllContentFeed(
        timelineEvents: [],
        statistics: MatchStatistics.mock(for: Match.barcelonaPSG),
        onPollVote: { _, _ in },
        onSelectTab: { _ in },
        onNavigateToTimestamp: nil,
        lastNavigatedTimestamp: .constant(0)
    )
}


