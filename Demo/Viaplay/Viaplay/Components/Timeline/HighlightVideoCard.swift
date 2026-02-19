//
//  HighlightVideoCard.swift
//  Viaplay
//
//  Molecular component: Highlight card with inline video preview
//  Style similar to tweets with video
//

import SwiftUI
import AVKit
import Combine
import VioCore

struct HighlightVideoCard: View {
    let highlight: HighlightTimelineEvent
    let onShare: ((String, URL) -> Void)?
    
    @State private var showFullscreenPlayer = false
    @State private var isPlaying = false
    @StateObject private var playerViewModel = InlineVideoPlayerViewModel()
    
    // Reactions
    @State private var reactionCounts: [String: Int]
    @State private var userReactions: Set<String> = []
    @State private var animatingReaction: String?
    @State private var countUpdateTimer: Timer?
    
    init(highlight: HighlightTimelineEvent, onShare: ((String, URL) -> Void)? = nil) {
        self.highlight = highlight
        self.onShare = onShare
        
        // Initialize reactions
        let baseCount = 500
        _reactionCounts = State(initialValue: [
            "🔥": baseCount + Int.random(in: 50...200),
            "❤️": baseCount + Int.random(in: 30...150),
            "⚽": baseCount + Int.random(in: 100...300),
            "🏆": baseCount + Int.random(in: 20...100),
            "👍": baseCount + Int.random(in: 40...180),
            "🎯": baseCount + Int.random(in: 10...80)
        ])
    }
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header (like tweet header)
            HStack(spacing: 8) {
                // Viaplay logo
                Image(DemoDataManager.shared.brandAsset(for: .icon))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(VioConfiguration.shared.effectiveBrandConfiguration.name) Highlights")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: highlight.highlightType.icon)
                            .font(.system(size: 9))
                            .foregroundColor(highlightColor(for: highlight.highlightType))
                        
                        Text(highlight.highlightType.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text(highlight.displayTime)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Campaign sponsor badge
                CampaignSponsorBadge(
                    maxWidth: 50,
                    maxHeight: 16,
                    alignment: .trailing
                )
            }
            
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineSpacing(1)
                
                if let description = highlight.description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(1)
                }
            }
            
            // Video player (inline)
            if let clipUrl = highlight.clipUrl, let url = URL(string: clipUrl) {
                InlineVideoPlayer(
                    videoURL: url,
                    playerViewModel: playerViewModel,
                    onTapFullscreen: {
                        showFullscreenPlayer = true
                    },
                    onTapShare: {
                        onShare?(highlight.title, url)
                    }
                )
            }
            
            // Reactions (same as tweets)
            HStack(spacing: 8) {
                ForEach(["🔥", "❤️", "⚽", "🏆", "👍", "🎯"], id: \.self) { emoji in
                    CompactReactionButton(
                        emoji: emoji,
                        count: reactionCounts[emoji] ?? 0,
                        isSelected: userReactions.contains(emoji),
                        isAnimating: animatingReaction == emoji,
                        onTap: {
                            handleReaction(emoji)
                        }
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    highlightColor(for: highlight.highlightType).opacity(0.4),
                                    highlightColor(for: highlight.highlightType).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .fullScreenCover(isPresented: $showFullscreenPlayer) {
            if let clipUrl = highlight.clipUrl, let url = URL(string: clipUrl) {
                HighlightVideoPlayerView(videoURL: url, title: highlight.title) {
                    showFullscreenPlayer = false
                }
            }
        }
        .onAppear {
            startReactionSimulation()
        }
        .onDisappear {
            stopReactionSimulation()
        }
    }
    
    // MARK: - Reaction Handling
    
    private func handleReaction(_ emoji: String) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if userReactions.contains(emoji) {
                userReactions.remove(emoji)
                reactionCounts[emoji, default: 0] -= 1
            } else {
                userReactions.insert(emoji)
                reactionCounts[emoji, default: 0] += 1
                
                animatingReaction = emoji
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    animatingReaction = nil
                }
            }
        }
    }
    
    private func startReactionSimulation() {
        // Disabled for performance on device
        #if DEBUG
        #if targetEnvironment(simulator)
        countUpdateTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 3.0...6.0), repeats: true) { _ in
            let randomEmoji = ["🔥", "❤️", "⚽", "🏆", "👍", "🎯"].randomElement()!
            let increment = Int.random(in: 1...2)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                reactionCounts[randomEmoji, default: 0] += increment
                animatingReaction = randomEmoji
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animatingReaction = nil
                }
            }
        }
        #endif
        #endif
    }
    
    private func stopReactionSimulation() {
        countUpdateTimer?.invalidate()
        countUpdateTimer = nil
    }
    
    private func highlightColor(for type: HighlightTimelineEvent.HighlightType) -> Color {
        switch type {
        case .goal: return .green
        case .chance: return .orange
        case .save: return .blue
        case .yellowCard: return .yellow
        case .redCard: return .red
        case .tackle: return .cyan
        case .pass: return .purple
        case .other: return .white
        }
    }
}

// MARK: - Inline Video Player

struct InlineVideoPlayer: View {
    let videoURL: URL
    @ObservedObject var playerViewModel: InlineVideoPlayerViewModel
    let onTapFullscreen: () -> Void
    let onTapShare: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video player
                if let player = playerViewModel.player {
                    VideoPlayer(player: player)
                        .frame(height: 200)
                        .disabled(true)  // Disable native controls
                        .onTapGesture {
                            playerViewModel.togglePlayPause()
                        }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                }
                
                // Play/Pause overlay
                if !playerViewModel.isPlaying {
                    Button(action: {
                        playerViewModel.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Video controls overlay
                VStack {
                    HStack {
                        Spacer()
                        
                        // Share button
                        Button(action: onTapShare) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        
                        // Fullscreen button
                        Button(action: onTapFullscreen) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                    }
                    .padding(8)
                    
                    Spacer()
                }
            }
        }
        .frame(height: 200)
        .cornerRadius(8)
        .onAppear {
            playerViewModel.setupPlayer(url: videoURL)
        }
        .onDisappear {
            playerViewModel.cleanup()
        }
    }
}

// MARK: - Inline Video Player ViewModel

@MainActor
class InlineVideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    
    func setupPlayer(url: URL) {
        player = AVPlayer(url: url)
        player?.isMuted = true  // Auto-muted for inline playback
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    func cleanup() {
        player?.pause()
        player = nil
        isPlaying = false
    }
}

// MARK: - Highlight Video Player

struct HighlightVideoPlayerView: View {
    let videoURL: URL
    let title: String
    let onDismiss: () -> Void
    
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(radius: 4)
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Title overlay
                VStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                        )
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
            player?.play()
            
            // Loop video
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Compact Reaction Button (same as TweetCard)

private struct CompactReactionButton: View {
    let emoji: String
    let count: Int
    let isSelected: Bool
    let isAnimating: Bool
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 0.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                }
            }
            onTap()
        }) {
            HStack(spacing: 2) {
                Text(emoji)
                    .font(.system(size: 12))
                    .scaleEffect(isAnimating ? 1.15 : 1.0)
                
                Text(formatCount(count))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.65))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(
                        isSelected 
                        ? Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.25)
                        : Color.white.opacity(0.06)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected 
                                ? Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.4)
                                : Color.clear,
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .scaleEffect(scale)
    }
}

#Preview {
    HighlightVideoCard(
        highlight: HighlightTimelineEvent(
            id: "h1",
            videoTimestamp: 780,
            title: "MÅL: A. Diallo",
            description: "Nydelig avslutning!",
            thumbnailUrl: nil,
            clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/1.MP4?alt=media&token=898b7836-5e27-492d-82bb-9d7bb50f9d66",
            highlightType: .goal,
            metadata: nil
        )
    )
    .padding()
    .background(Color.black)
}
