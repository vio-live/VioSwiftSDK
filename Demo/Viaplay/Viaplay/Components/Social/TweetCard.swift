//
//  TweetCard.swift
//  Viaplay
//
//  Molecular component: Tweet card with reactions
//  Style based on X/Twitter posts with Viaplay branding
//

import SwiftUI

struct TweetCard: View {
    let tweet: TweetEvent
    let onReact: ((String) -> Void)?
    
    @State private var reactionCounts: [String: Int] = [:]
    @State private var userReactions: Set<String> = []
    @State private var animatingReaction: String?
    @State private var countUpdateTimer: Timer?
    
    init(tweet: TweetEvent, onReact: ((String) -> Void)? = nil) {
        self.tweet = tweet
        self.onReact = onReact
        
        // Initialize reaction counts
        _reactionCounts = State(initialValue: [
            "🔥": tweet.likes / 4,
            "❤️": tweet.likes / 5,
            "⚽": tweet.retweets,
            "🏆": tweet.likes / 8,
            "👍": tweet.likes / 6,
            "🎯": tweet.likes / 12
        ])
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with avatar and info
            HStack(spacing: 8) {
                // Avatar (32px - same as chat)
                AsyncImage(url: URL(string: tweet.authorAvatar ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(String(tweet.authorName.prefix(1)))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Text(tweet.authorName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if tweet.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text("via X")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text(timeAgo(from: tweet.videoTimestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
            }
            
            // Tweet text
            Text(tweet.tweetText)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1)
            
            // Reactions row (interactive) - More compact
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
                                    Color(red: 0.96, green: 0.08, blue: 0.42),
                                    Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
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
                // Remove reaction
                userReactions.remove(emoji)
                reactionCounts[emoji, default: 0] -= 1
            } else {
                // Add reaction
                userReactions.insert(emoji)
                reactionCounts[emoji, default: 0] += 1
                
                // Animate
                animatingReaction = emoji
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    animatingReaction = nil
                }
            }
        }
        
        onReact?(emoji)
    }
    
    // MARK: - Reaction Simulation
    
    private func startReactionSimulation() {
        // Simulate reactions coming in (like people reacting in real-time)
        countUpdateTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 2.0...4.0), repeats: true) { _ in
            let randomEmoji = ["🔥", "❤️", "⚽", "🏆", "👍", "🎯"].randomElement()!
            let increment = Int.random(in: 1...3)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                reactionCounts[randomEmoji, default: 0] += increment
                
                // Quick flash animation
                animatingReaction = randomEmoji
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animatingReaction = nil
                }
            }
        }
    }
    
    private func stopReactionSimulation() {
        countUpdateTimer?.invalidate()
        countUpdateTimer = nil
    }
    
    // MARK: - Helpers
    
    private func timeAgo(from videoTimestamp: TimeInterval) -> String {
        let currentTime = Date()
        let messageTime = currentTime.addingTimeInterval(-videoTimestamp)
        let seconds = Int(currentTime.timeIntervalSince(messageTime))
        
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        return "\(hours)t"
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

// MARK: - Compact Reaction Button

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
    TweetCard(
        tweet: TweetEvent(
            id: "tweet-1",
            videoTimestamp: 810,
            authorName: "Luka Modrić",
            authorHandle: "@LukaModric10",
            authorAvatar: "https://pbs.twimg.com/profile_images/1467838580013015046/Ri-Mx4k0_400x400.jpg",
            tweetText: "Nikada ne odustaj! ⚽🔥 #ChampionsLeague",
            isVerified: true,
            likes: 1345,
            retweets: 878,
            metadata: nil
        )
    )
    .padding()
    .background(Color.black)
}
