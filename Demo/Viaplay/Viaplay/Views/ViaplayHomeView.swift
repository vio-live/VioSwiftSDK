//
//  ViaplayHomeView.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI
import VioCore
import VioUI
import VioCastingUI

struct ViaplayHomeView: View {
    @Binding var selectedTab: Int
    @Binding var showSportView: Bool
    @State private var scrollOffset: CGFloat = 0
    let heroContent = HeroContent.mock
    let continueWatchingItems = ContinueWatchingItem.mockItems
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background
                Color(hex: "1B1B25")
                    .ignoresSafeArea()
            
            // Main Content
            ScrollView {
                    VStack(spacing: 0) {
                        // Hero Section (extends to top)
                        HeroSection(content: heroContent)
                            .frame(width: geometry.size.width)
                        
                        // Pagination dots after hero
                        HStack(spacing: 5) {
                            Circle()
                                .fill(.white)
                                .frame(width: 6, height: 6)
                            
                            ForEach(0..<5) { _ in
                                Circle()
                                    .fill(.white.opacity(0.4))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                        // Category Buttons Grid (2x2 + Channels on left)
                        VStack(spacing: 10) {
                            HStack(spacing: 12) {
                                CategoryButton(title: "Series") {}
                                CategoryButton(title: "Films") {}
                            }
                            
                            HStack(spacing: 12) {
                                CategoryButton(title: "Sport") {
                                    selectedTab = 1
                                }
                                CategoryButton(title: "Kids") {}
                            }
                            
                            HStack(spacing: 12) {
                                CategoryButton(title: "Channels") {}
                                    .frame(maxWidth: .infinity)
                                
                                // Empty spacer to keep Channels on the left
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: geometry.size.width)
                        
                        // Akkurat nå ser andre på Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Akkurat nå ser andre på")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            GeometryReader { scrollGeometry in
                                let cardWidth = (scrollGeometry.size.width - 32 - 24) / 3 // 32 = padding, 24 = spacing between 3 cards
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        CategoryCard(
                                            title: "Norske Truckers",
                                            localImageName: "card1",
                                            seasonEpisode: "S3 | E2"
                                        )
                                        .frame(width: cardWidth)
                                        
                                        CategoryCard(
                                            title: "Kraven The Hunter",
                                            localImageName: "card2",
                                            seasonEpisode: nil
                                        )
                                        .frame(width: cardWidth)
                                        
                                        CategoryCard(
                                            title: "Paradise Hotel",
                                            localImageName: "card3",
                                            seasonEpisode: "S17 | E28"
                                        )
                                        .frame(width: cardWidth)
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            .frame(height: 180)
                        }
                        .frame(maxWidth: geometry.size.width)
                        
                        // Nytt hos oss Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nytt hos oss")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            GeometryReader { scrollGeometry in
                                let cardWidth = (scrollGeometry.size.width - 32 - 24) / 3 // 32 = padding, 24 = spacing between 3 cards
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        CategoryCard(
                                            title: "American Gangster",
                                            localImageName: "card1",
                                            seasonEpisode: nil
                                        )
                                        .frame(width: cardWidth)
                                        
                                        CategoryCard(
                                            title: "The Equalizer",
                                            localImageName: "card2",
                                            seasonEpisode: nil
                                        )
                                        .frame(width: cardWidth)
                                        
                                        CategoryCard(
                                            title: "The Oath",
                                            localImageName: "card3",
                                            seasonEpisode: nil
                                        )
                                        .frame(width: cardWidth)
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            .frame(height: 180)
                        }
                        .frame(maxWidth: geometry.size.width)
                        
                        // Ukens tilbud Section (at the end)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ukens tilbud")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            VProductCarousel(
                                componentId: "product-carousel-template",
                                layout: "compact",
                                showSponsor: true,
                                sponsorPosition: "topRight"
                            )
                            GeometryReader { scrollGeometry in
                                
                            }
                            .frame(height: 180)
                        }
                        .frame(maxWidth: geometry.size.width)
                        .padding(.bottom, 100) // Space for bottom nav
                    }
                }
                .ignoresSafeArea(edges: .top) // Allow scroll content to go under status bar
                
                // Floating Header (appears on scroll) with blur effect
                if scrollOffset > 200 {
                    VStack(spacing: 0) {
                        ZStack {
                            // Blur background
                            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                            
                            HStack {
                                Spacer()
                                
                                // Viaplay Icon + Logo from assets
                                HStack(alignment: .center, spacing: 0) {
                                    Image(DemoDataManager.shared.brandAsset(for: .icon))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 28, height: 28)
                                    
                                    Image(DemoDataManager.shared.brandAsset(for: .logo))
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(.white)
                                        .frame(height: 22)
                                        .offset(x: -30)
                                }
                                .offset(x: 15) // Compensar el offset del logo para centrar el conjunto
                                
                                Spacer()
                                
                                // Avatar/Profile circle
                                Circle()
                                    .fill(Color.cyan.opacity(0.3))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.cyan)
                                    )
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                    .frame(width: geometry.size.width)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: scrollOffset)
                }
                
                // Bottom Navigation
                VStack {
                    Spacer()
                    VCastingBottomNav(selectedTab: $selectedTab)
                        .frame(width: geometry.size.width)
                }
            }
            .frame(width: geometry.size.width)
        }
    }
}

#Preview {
    ViaplayHomeView(selectedTab: .constant(0), showSportView: .constant(false))
}
