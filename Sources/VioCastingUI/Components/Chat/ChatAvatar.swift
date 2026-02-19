//
//  ChatAvatar.swift
//  Viaplay
//
//  Atomic component: Chat user avatar
//

import SwiftUI

struct ChatAvatar: View {
    let initial: String
    let color: Color
    let size: CGFloat
    
    init(initial: String, color: Color, size: CGFloat = 32) {
        self.initial = initial
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.4375, weight: .semibold))
                    .foregroundColor(color)
            )
    }
}

#Preview {
    HStack(spacing: 16) {
        ChatAvatar(initial: "M", color: .orange)
        ChatAvatar(initial: "S", color: .cyan, size: 40)
        ChatAvatar(initial: "T", color: .pink, size: 28)
    }
    .padding()
    .background(Color.black)
}


