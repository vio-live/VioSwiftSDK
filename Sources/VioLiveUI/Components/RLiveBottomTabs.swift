import SwiftUI
import VioCore
import VioLiveShow
import VioDesignSystem
import VioUI

/// Bottom tabs component for LiveShow (Chat and Products)
public struct RLiveBottomTabs: View {
    
    // MARK: - Tab Types
    public enum TabType: String, CaseIterable {
        case chat = "Chat"
        case products = "Shop"
        
        var icon: String {
            switch self {
            case .chat: return "bubble.left.fill"
            case .products: return "bag.fill"
            }
        }
    }
    
    // MARK: - Properties
    @State private var selectedTab: TabType = .chat
    @State private var isExpanded = true
    @Environment(\.colorScheme) private var colorScheme
    
    private let products: [LiveProduct]
    
    // Colors based on theme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(products: [LiveProduct] = []) {
        self.products = products
    }
    
    // MARK: - Body
    public var body: some View {
        VStack(spacing: 0) {
            // Tab content
            if isExpanded {
                contentView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Tab bar
            tabBar
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .chat:
            RLiveChatComponent()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        case .products:
            RLiveProductsComponent(products: products)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }
    
    // MARK: - Tab Bar
    
    @ViewBuilder
    private var tabBar: some View {
        HStack(spacing: 0) {
            // Collapse/Expand button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
            }
            
            // Tab buttons
            ForEach(TabType.allCases, id: \.self) { tab in
                Button(action: {
                    if selectedTab != tab {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }) {
                    HStack(spacing: VioSpacing.xs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(selectedTab == tab ? adaptiveColors.primary : .white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        selectedTab == tab ? 
                        Color.white.opacity(0.1) : 
                        Color.clear
                    )
                    .cornerRadius(VioBorderRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, VioSpacing.sm)
        .padding(.bottom, VioSpacing.sm)
        .background(Color.black.opacity(0.8))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            RLiveBottomTabs()
                .environmentObject(CartManager())
        }
    }
}
