//
//  MatchNavigationTabs.swift
//  Viaplay
//
//  Organism component: Match navigation tabs
//

import SwiftUI

struct MatchNavigationTabs: View {
    @Binding var selectedTab: MatchTab
    
    var body: some View {
        VStack(spacing: 0) {
            // Removed drag handle for cleaner look
            
            HStack(spacing: 0) {
                ForEach(MatchTab.allCases, id: \.self) { tab in
                    MatchTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        onTap: {
                            withAnimation {
                                selectedTab = tab
                            }
                        }
                    )
                }
            }
        }
        .background(Color(hex: "1F1E26"))
    }
}

// MARK: - Match Tab Button

private struct MatchTabButton: View {
    let tab: MatchTab
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(
                        isSelected 
                        ? Color(red: 0.96, green: 0.08, blue: 0.42) 
                        : Color.white.opacity(0.6)
                    )
                
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }
}

#Preview {
    MatchNavigationTabs_PreviewWrapper()
}

private struct MatchNavigationTabs_PreviewWrapper: View {
    @State var selectedTab: MatchTab = .all
    var body: some View {
        MatchNavigationTabs(selectedTab: $selectedTab)
    }
}


