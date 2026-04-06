//
//  VEngagementPollCard.swift
//  VioEngagementUI
//
//  Poll card component for engagement system
//  Uses SDK colors from configuration instead of hardcoded values
//

import SwiftUI
import VioCore
import VioDesignSystem

/// Poll option data for display
public struct VEngagementPollOption: Identifiable {
    public let id: String
    public let text: String
    public let avatarUrl: String?
    
    public init(id: String = UUID().uuidString, text: String, avatarUrl: String? = nil) {
        self.id = id
        self.text = text
        self.avatarUrl = avatarUrl
    }
}

/// Poll card component for engagement system
public struct VEngagementPollCard: View {
    let question: String
    let subtitle: String?
    let options: [VEngagementPollOption]
    let duration: Int?
    let onVote: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedOption: String?
    @State private var hasVoted = false
    @State private var showResults = false
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        question: String,
        subtitle: String? = nil,
        options: [VEngagementPollOption],
        duration: Int? = nil,
        onVote: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.question = question
        self.subtitle = subtitle
        self.options = options
        self.duration = duration
        self.onVote = onVote
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        
        ZStack {
            // Front side - Poll question
            if !showResults {
                pollFrontView(colors: colors)
                    .rotation3DEffect(
                        .degrees(0),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            
            // Back side - Results
            if showResults {
                pollResultsView(colors: colors)
                    .rotation3DEffect(
                        .degrees(180),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
        }
        .rotation3DEffect(
            .degrees(showResults ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
    }
    
    // MARK: - Front View
    
    private func pollFrontView(colors: AdaptiveColors) -> some View {
        VStack(spacing: VioSpacing.sm) {
                // Drag indicator
                VEngagementDragIndicator()
                
                // Sponsor badge
                VEngagementSponsorBadge()
                
                // Question
                Text(question)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, VioSpacing.md)
                
                // Subtitle
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .padding(.horizontal, VioSpacing.md)
                }
                
                // Options
                VStack(spacing: 6) {
                    ForEach(options) { option in
                        pollOptionButton(option: option, colors: colors)
                    }
                }
                
                // Timer
                if let duration = duration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9))
                        Text("\(duration)s")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(colors.textSecondary)
                    .padding(.top, 4)
                }
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
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            // Drag handled by base component
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            onDismiss()
                        }
                    }
            )
    }
    
    // MARK: - Results View
    
    private func pollResultsView(colors: AdaptiveColors) -> some View {
        VStack(spacing: VioSpacing.sm) {
                // Drag indicator
                VEngagementDragIndicator()
                
                // Title
                Text("Resultater")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.textPrimary)
                    .padding(.horizontal, VioSpacing.md)
                
                Text("Takk for at du stemte!")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(colors.primary)
                    .padding(.horizontal, VioSpacing.md)
                
                // Results bars
                VStack(spacing: VioSpacing.sm) {
                    ForEach(options) { option in
                        resultBar(option: option, isSelected: option.id == selectedOption, colors: colors)
                    }
                }
                .padding(.top, VioSpacing.sm)
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
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            // Drag handled by base component
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            onDismiss()
                        }
                    }
            )
    }
    
    // MARK: - Poll Option Button
    
    private func pollOptionButton(option: VEngagementPollOption, colors: AdaptiveColors) -> some View {
        Button(action: {
            guard !hasVoted else { return }
            selectedOption = option.id
            hasVoted = true
            onVote(option.id)
            
            // Delay before showing results
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showResults = true
                }
            }
        }) {
            HStack(spacing: 10) {
                // Avatar/Icon circle
                if let avatarUrl = option.avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                    CachedAsyncImage(url: url) { image in
                        Circle()
                            .fill(colors.surface)
                            .frame(width: 36, height: 36)
                            .overlay(
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 26, height: 26)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    } placeholder: {
                        Circle()
                            .fill(colors.surfaceSecondary)
                            .frame(width: 36, height: 36)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(colors.textPrimary)
                            )
                    }
                } else {
                    // Fallback: first letter with gradient using primary color
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [colors.primary.opacity(0.6), colors.primary.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(option.text.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(colors.textOnPrimary)
                        )
                }
                
                Text(option.text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: VioBorderRadius.large)
                    .fill(
                        selectedOption == option.id
                        ? colors.primary.opacity(0.6)
                        : colors.surfaceSecondary
                    )
            )
        }
        .disabled(hasVoted)
    }
    
    // MARK: - Result Bar
    
    private func resultBar(option: VEngagementPollOption, isSelected: Bool, colors: AdaptiveColors) -> some View {
        let percentage = calculatePercentage(for: option)
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(option.text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colors.textPrimary)
                
                Spacer()
                
                Text("\(Int(percentage))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? colors.primary : colors.textPrimary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(colors.textPrimary.opacity(0.2))
                    
                    // Fill
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(isSelected ? colors.primary : colors.primary.opacity(0.6))
                        .frame(width: geometry.size.width * (percentage / 100))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, VioSpacing.md)
    }
    
    private func calculatePercentage(for option: VEngagementPollOption) -> Double {
        // Simulate results - in production, this would come from the server
        guard let selected = selectedOption else { return 0 }
        
        if option.id == selected {
            return 75.0 // Selected option gets 75%
        } else {
            let remaining = 25.0
            let otherOptions = options.filter { $0.id != selected }.count
            return remaining / Double(otherOptions)
        }
    }
}
