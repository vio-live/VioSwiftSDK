//
//  VideoTimelineControl.swift
//  Viaplay
//
//  Molecular component: Video timeline control with scrubber
//

import SwiftUI

struct VideoTimelineControl: View {
    let currentMinute: Int
    let liveMinute: Int  // NEW: Real live position
    let isAtLive: Bool    // NEW: Is user at live position?
    @Binding var selectedMinute: Int?
    let events: [MatchEvent]
    let isPlaying: Bool
    let isMuted: Bool
    let totalDuration: Int
    let onPlayPause: () -> Void
    let onToggleMute: () -> Void
    let onGoToLive: () -> Void  // NEW: Called when tapping LIVE
    let onSeek: ((Int) -> Void)?
    let onNavigateToNextCastingContest: (() -> Void)?  // Demo: Navigate to next Casting contest
    let onNavigateToPreviousCastingContest: (() -> Void)?  // Demo: Navigate to previous Casting contest
    
    @State private var isExpanded: Bool = true  // DEMO: Start expanded
    
    init(
        currentMinute: Int,
        liveMinute: Int = 0,
        isAtLive: Bool = true,
        selectedMinute: Binding<Int?>,
        events: [MatchEvent],
        isPlaying: Bool = false,
        isMuted: Bool = true,
        totalDuration: Int = 90,
        onPlayPause: @escaping () -> Void = {},
        onToggleMute: @escaping () -> Void = {},
        onGoToLive: @escaping () -> Void = {},
        onSeek: ((Int) -> Void)? = nil,
        onNavigateToNextCastingContest: (() -> Void)? = nil,
        onNavigateToPreviousCastingContest: (() -> Void)? = nil
    ) {
        self.currentMinute = currentMinute
        self.liveMinute = liveMinute
        self.isAtLive = isAtLive
        self._selectedMinute = selectedMinute
        self.events = events
        self.isPlaying = isPlaying
        self.isMuted = isMuted
        self.totalDuration = totalDuration
        self.onPlayPause = onPlayPause
        self.onToggleMute = onToggleMute
        self.onGoToLive = onGoToLive
        self.onSeek = onSeek
        self.onNavigateToNextCastingContest = onNavigateToNextCastingContest
        self.onNavigateToPreviousCastingContest = onNavigateToPreviousCastingContest
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.2))
            
            VStack(spacing: 8) {
                // Timeline Scrubber (expandible)
                if isExpanded {
                    TimelineScrubber(
                        currentMinute: currentMinute,
                        selectedMinute: $selectedMinute,
                        events: events,
                        totalDuration: totalDuration,
                        onSeek: onSeek
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Controls
                if isExpanded {
                    // Full controls when expanded
                    HStack(spacing: 12) {
                        // Time indicator / Toggle button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if let selected = selectedMinute {
                                    Text("\(selected)'")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                } else {
                                    LiveBadge(size: .medium, showPulse: true)
                                }
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        .fixedSize()
                        
                        // Backward button (Demo: Navigate to previous Casting contest)
                        if onNavigateToPreviousCastingContest != nil {
                            Button(action: {
                                onNavigateToPreviousCastingContest?()
                            }) {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        
                        // Play/Pause - Centered
                        Button(action: onPlayPause) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .contentShape(Circle())
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Forward button (Demo: Navigate to next Casting contest)
                        if onNavigateToNextCastingContest != nil {
                            Button(action: {
                                onNavigateToNextCastingContest?()
                            }) {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        
                        Spacer()
                        
                        // Mute/Unmute
                        Button(action: onToggleMute) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    // Minimized: Only LIVE badge
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if let selected = selectedMinute {
                                    Text("\(selected)'")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                } else {
                                    LiveBadge(size: .medium, showPulse: true)
                                }
                                
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, isExpanded ? 8 : 4)
            .background(Color(hex: "1F1E26"))
        }
    }
}

// MARK: - Timeline Scrubber

struct TimelineScrubber: View {
    let currentMinute: Int
    @Binding var selectedMinute: Int?
    let events: [MatchEvent]
    let totalDuration: Int
    let onSeek: ((Int) -> Void)?
    
    private var displayMinute: Int {
        selectedMinute ?? currentMinute
    }
    
    private var progress: CGFloat {
        // Normalize from -15 to 105 minutes to 0.0 to 1.0
        let normalizedMinute = CGFloat(displayMinute + 15)  // Shift by 15 to make -15 = 0
        return normalizedMinute / CGFloat(totalDuration + 15)  // totalDuration is now relative to 0
    }
    
    private func eventMarkerColor(for eventType: MatchEvent.EventType) -> Color {
        switch eventType {
        case .goal: return Color(red: 0.0, green: 1.0, blue: 0.0)  // Bright green
        case .yellowCard: return Color(red: 1.0, green: 1.0, blue: 0.0)  // Yellow
        case .redCard: return Color(red: 1.0, green: 0.0, blue: 0.0)  // Red
        case .substitution: return Color(red: 0.0, green: 0.8, blue: 1.0)  // Cyan
        case .kickOff: return .white  // White for kickoff
        case .halfTime: return .white.opacity(0.9)  // White for halftime
        case .fullTime: return .white.opacity(0.9)  // White for fulltime
        default: return .white.opacity(0.5)
        }
    }
    
    private func eventMarkerSize(for eventType: MatchEvent.EventType) -> CGFloat {
        switch eventType {
        case .goal: return 10  // Larger for goals
        case .redCard: return 10  // Larger for red cards
        case .yellowCard: return 8
        case .kickOff, .halfTime, .fullTime: return 12  // Largest for phase changes
        case .substitution: return 6
        default: return 6
        }
    }
    
    private func isSpecialMarker(_ eventType: MatchEvent.EventType) -> Bool {
        switch eventType {
        case .kickOff, .halfTime, .fullTime:
            return true
        default:
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // Progress track
                    Rectangle()
                        .fill(Color(red: 0.96, green: 0.08, blue: 0.42))
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                    
                    // Event markers (only show events that have already occurred)
                    ForEach(events.filter { $0.minute <= displayMinute }, id: \.id) { event in
                        let position = CGFloat(event.minute) / CGFloat(totalDuration)
                        let size = eventMarkerSize(for: event.type)
                        
                        ZStack {
                            // Main marker
                            Circle()
                                .fill(eventMarkerColor(for: event.type))
                                .frame(width: size, height: size)
                            
                            // Special phase markers (kickoff, halftime, fulltime)
                            if isSpecialMarker(event.type) {
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                                    .frame(width: size + 3, height: size + 3)
                            }
                        }
                        .offset(x: geometry.size.width * position - size/2)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Phase markers (only show if that phase has been reached)
                    // Kickoff marker (0') - always visible
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2, height: 12)
                        .offset(x: -1, y: -4)
                    
                    // Halftime marker (45') - only if we've reached minute 45
                    if displayMinute >= 45 {
                        let halftimePosition = CGFloat(45) / CGFloat(totalDuration)
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 2, height: 12)
                            .offset(x: geometry.size.width * halftimePosition - 1, y: -4)
                            .transition(.opacity)
                    }
                    
                    // Second half marker (46') - only if we've reached minute 46
                    if displayMinute >= 46 {
                        let secondHalfPosition = CGFloat(46) / CGFloat(totalDuration)
                        Rectangle()
                            .fill(Color.green.opacity(0.4))
                            .frame(width: 2, height: 12)
                            .offset(x: geometry.size.width * secondHalfPosition - 1, y: -4)
                            .transition(.opacity)
                    }
                    
                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: geometry.size.width * progress - 8)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                    // Map percentage to -15 to 105 minute range
                                    let minute = Int(percentage * CGFloat(totalDuration + 15)) - 15
                                    selectedMinute = minute
                                    onSeek?(minute)
                                }
                        )
                }
            }
            .frame(height: 20)
            
            // Labels
            HStack {
                Text("-15'")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
                
                Text("0'")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                if selectedMinute == nil {
                    LiveBadge(size: .small, isLive: true)
                } else {
                    Text("\(selectedMinute!)'")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Button {
                        selectedMinute = nil
                    } label: {
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                Text("90'")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("105'")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    VideoTimelineControl_PreviewWrapper()
}

private struct VideoTimelineControl_PreviewWrapper: View {
    @State var selectedMinute: Int? = nil
    var body: some View {
        VideoTimelineControl(
            currentMinute: 45,
            selectedMinute: $selectedMinute,
            events: [
                MatchEvent(minute: 13, type: .goal, player: "A. Diallo", team: .home, description: nil, score: "1-0"),
                MatchEvent(minute: 18, type: .yellowCard, player: "Casemiro", team: .home, description: nil, score: nil)
            ],
            isPlaying: true,
            onNavigateToNextCastingContest: nil,
            onNavigateToPreviousCastingContest: nil
        )
        .background(Color(hex: "1B1B25"))
    }
}


