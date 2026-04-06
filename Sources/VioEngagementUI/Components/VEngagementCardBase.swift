//
//  VEngagementCardBase.swift
//  VioEngagementUI
//
//  Base component shared by all engagement cards (Poll, Contest, Product)
//  Provides common UI elements like drag indicator, sponsor badge, and background
//

import SwiftUI
import VioCore
import VioDesignSystem

/// Base component for engagement cards with common UI elements
public struct VEngagementCardBase<Content: View>: View {
    let content: Content
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onDismiss = onDismiss
        self.content = content()
    }
    
    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        
        VStack(spacing: 0) {
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.large)
                .fill(colors.surface.opacity(0.4))
                .background(
                    RoundedRectangle(cornerRadius: VioBorderRadius.large)
                        .fill(.ultraThinMaterial)
                )
        )
        .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 8)
        .frame(maxWidth: EngagementCardLayout.maxCardWidth)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

/// Drag indicator component
public struct VEngagementDragIndicator: View {
    let width: CGFloat
    let height: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(width: CGFloat = 32, height: CGFloat = 4) {
        self.width = width
        self.height = height
    }
    
    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        
        Capsule()
            .fill(colors.textPrimary.opacity(0.3))
            .frame(width: width, height: height)
            .padding(.top, 8)
    }
}

/// Sponsor badge wrapper for engagement cards
public struct VEngagementSponsorBadge: View {
    let maxWidth: CGFloat?
    let maxHeight: CGFloat
    
    public init(maxWidth: CGFloat? = 80, maxHeight: CGFloat = 24) {
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }
    
    public var body: some View {
        HStack {
            CampaignSponsorBadge(
                text: "Sponset av",
                maxWidth: maxWidth,
                maxHeight: maxHeight,
                alignment: .leading
            )
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}
