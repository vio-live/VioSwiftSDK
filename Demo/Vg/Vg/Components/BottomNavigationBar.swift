//
//  BottomNavigationBar.swift
//  Vg
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI

struct BottomNavigationBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(
                icon: "doc.text",
                label: "Nyheter",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            
            TabButton(
                icon: "play.fill",
                label: "Klipp",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            TabButton(
                icon: "chevron.left",
                label: "VG Live",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            
            TabButton(
                icon: "video.fill",
                label: "Direkte",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }
            
            TabButton(
                icon: "gearshape",
                label: "Innstillinger",
                isSelected: selectedTab == 4
            ) {
                selectedTab = 4
            }
        }
        .padding(.vertical, VGTheme.Spacing.sm)
        .background(VGTheme.Colors.darkGray)
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 24 : 20))
                    .foregroundColor(isSelected ? .white : VGTheme.Colors.textSecondary)
                
                Text(label)
                    .font(VGTheme.Typography.small())
                    .foregroundColor(isSelected ? .white : VGTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    BottomNavigationBar(selectedTab: .constant(2))
        .background(VGTheme.Colors.black)
}
