import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: TabItem
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                TabButton(tab: tab, isSelected: selectedTab == tab) {
                    selectedTab = tab
                }
            }
        }
        .padding(.horizontal, TV2Theme.Spacing.md)
        .padding(.top, TV2Theme.Spacing.md)
        .padding(.bottom, TV2Theme.Spacing.md)
        .background(
            TV2Theme.Colors.surface
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? TV2Theme.Colors.primary : TV2Theme.Colors.textSecondary)
                    .frame(height: 24)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

enum TabItem: CaseIterable {
    case home
    case search
    case library
    case add
    case downloads
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "square.stack.fill"
        case .add: return "plus.square.fill"
        case .downloads: return "arrow.down.circle.fill"
        }
    }
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .library: return "Library"
        case .add: return "Add"
        case .downloads: return "Downloads"
        }
    }
}

