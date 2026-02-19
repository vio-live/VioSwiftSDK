import SwiftUI

struct ContentCard: View {
    let item: ContentItem
    let width: CGFloat
    let height: CGFloat
    
    var isMatchCard: Bool {
        item.homeTeamLogo != nil && item.awayTeamLogo != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack(alignment: .topLeading) {
                // Background
                if isMatchCard {
                    // Match card gradient
                    ZStack {
                        // Base gradient
                        LinearGradient(
                            colors: [
                                Color(hex: "#2B2438"),
                                Color(hex: "#16001A")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // Accent gradient overlay
                        LinearGradient(
                            colors: [
                                TV2Theme.Colors.primary.opacity(0.2),
                                Color.clear,
                                TV2Theme.Colors.secondary.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .frame(width: width, height: height)
                }
                
                // Content
                if isMatchCard {
                    // Match card content
                    ZStack(alignment: .topLeading) {
                        // Team Logos - Centered
                        HStack(spacing: 30) {
                            Spacer()
                            
                            // Home Team Logo
                            if let homeLogo = item.homeTeamLogo {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(homeLogo)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 44, height: 44)
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            // Away Team Logo
                            if let awayLogo = item.awayTeamLogo {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(awayLogo)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 44, height: 44)
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            
                            Spacer()
                        }
                        .frame(width: width, height: height)
                        
                        // No header badges for match cards
                        EmptyView()
                    }
                } else {
                    // Regular content with background image
                    Image(item.imageURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                }
                
                // Live badge
                if item.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(TV2Theme.Colors.live)
                            .frame(width: 8, height: 8)
                        
                        Text("DIREKTE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding(TV2Theme.Spacing.sm)
                }
            }
            .cornerRadius(TV2Theme.CornerRadius.medium)
            
            // Title
            Text(item.title)
                .font(isMatchCard ? .system(size: 16, weight: .bold) : TV2Theme.Typography.caption)
                .foregroundColor(TV2Theme.Colors.textPrimary)
                .lineLimit(1)
                .padding(.top, TV2Theme.Spacing.sm)
            
            // Subtitle
            if let subtitle = item.subtitle {
                if isMatchCard {
                    // Match subtitle with bullet separators
                    HStack(spacing: 4) {
                        let components = subtitle.components(separatedBy: " • ")
                        ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                            Text(component)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(TV2Theme.Colors.textSecondary)
                            
                            if index < components.count - 1 {
                                Text("•")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(TV2Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .lineLimit(1)
                    .padding(.top, 3)
                } else {
                    Text(subtitle)
                        .font(TV2Theme.Typography.small)
                        .foregroundColor(TV2Theme.Colors.textSecondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
        }
        .frame(width: width)
    }
}

#Preview {
    ContentCard(
        item: ContentItem.mockItems[0],
        width: 280,
        height: 160
    )
    .padding()
    .background(TV2Theme.Colors.background)
}


