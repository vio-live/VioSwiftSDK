//
//  ReactionButton.swift
//  Viaplay
//
//  Atomic component: Emoji reaction button with count and animations
//

import SwiftUI

struct ReactionButton: View {
    let emoji: String
    let count: Int
    let isSelected: Bool
    let isAnimating: Bool
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var countScale: CGFloat = 1.0
    
    init(
        emoji: String,
        count: Int,
        isSelected: Bool = false,
        isAnimating: Bool = false,
        onTap: @escaping () -> Void = {}
    ) {
        self.emoji = emoji
        self.count = count
        self.isSelected = isSelected
        self.isAnimating = isAnimating
        self.onTap = onTap
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
    
    var body: some View {
        Button(action: {
            // Tap animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 0.85
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.0
                }
            }
            onTap()
        }) {
            HStack(spacing: 5) {
                Text(emoji)
                    .font(.system(size: 17))
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                
                Text(formatCount(count))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.7))
                    .scaleEffect(countScale)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        isSelected 
                        ? Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.25)
                        : Color.white.opacity(0.08)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected 
                                ? Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.5)
                                : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .scaleEffect(scale)
        .onChange(of: count) { _ in
            // Animate count change
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                countScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    countScale = 1.0
                }
            }
        }
        .onChange(of: isAnimating) { animating in
            if animating {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    // Emoji grows when someone reacts
                }
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ReactionButton(emoji: "🔥", count: 3456)
        ReactionButton(emoji: "❤️", count: 2345, isSelected: true)
        ReactionButton(emoji: "⚽", count: 1234)
    }
    .padding()
    .background(Color.black)
}


