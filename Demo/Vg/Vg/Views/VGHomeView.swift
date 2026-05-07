//
//  VGHomeView.swift
//  Vg
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI
import VioUI
import VioCore

struct VGHomeView: View {
    @State private var selectedTab = 0 // "Nyheter" (news) tab — default for VG demo
    @State private var showMatchDetail = false
    @State private var selectedMatchTitle = ""
    @State private var selectedMatchSubtitle = ""
    @State private var showProducts = false
    @State private var showMaxboArticle = false  // advertorial: push from right
    
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var checkoutDraft: CheckoutDraft
    @StateObject private var componentManager = ComponentManager.shared
    var body: some View {
        ZStack {
            // Background
            VGTheme.Colors.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content based on selected tab. The Maxbo advertorial
                // takes over the news tab in-place (NOT as a fullScreenCover)
                // because nesting `.fullScreenCover` + `.sheet` (the product
                // detail) on iOS 26 stalls the post-AddItem resume of the
                // Apple Pay flow when @Published cart state cascades through
                // the modal stack. Swapping the tab content keeps a single
                // active sheet (matching TV2's known-working flow).
                Group {
                    switch selectedTab {
                    case 0:
                        if showMaxboArticle {
                            MaxboArticleView(onClose: {
                                showMaxboArticle = false
                            })
                        } else {
                            NewsView(onMaxboArticleTap: {
                                showMaxboArticle = true
                            })
                        }
                    case 1:
                        ClipsView()
                    case 2:
                        VGLiveView()
                    case 3:
                        liveContentView
                    case 4:
                        SettingsView()
                    default:
                        liveContentView
                    }
                }

                // Bottom Navigation Bar (always visible)
                BottomNavigationBar(selectedTab: $selectedTab)
            }

        }
        .sheet(isPresented: $showMatchDetail) {
            MatchDetailView(
                matchTitle: selectedMatchTitle,
                matchSubtitle: selectedMatchSubtitle,
                onBackTapped: {
                    showMatchDetail = false
                },
                onShareTapped: {
                    print("📤 [VG] Share match: \(selectedMatchTitle)")
                }
            )
        }
        .sheet(isPresented: $showProducts) {
            ProductsView(onBackTapped: {
                showProducts = false
            })
        }
    }
    
    // Live content with header
    private var liveContentView: some View {
        VStack(spacing: 0) {
            // VG Logo Header
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 22)
                    Spacer()
                }
                .padding(.vertical, VGTheme.Spacing.sm)
                
                // Separator line
                Divider()
                    .background(VGTheme.Colors.mediumGray)
            }
            .background(VGTheme.Colors.black)
            
            // Main Content
            ScrollView {
                VStack(spacing: 0) {
                    // Featured Match Hero
                    FeaturedMatchHero(
                        time: "I dag 18:15",
                        title: "Lecce - Napoli",
                        category: "Sport",
                        description: "Se italiensk Serie A direkte på VG+Sport. Lecce og Napoli møtes i niende serierunde på Stadio Via del Mare i Lecce. Vegard Aulstad står for kommenteringen.",
                        onPlayTapped: {
                            print("🎬 [VG] Opening match: Lecce - Napoli")
                        },
                        onMatchTapped: {
                            selectedMatchTitle = "Lecce - Napoli"
                            selectedMatchSubtitle = "Sport · i dag, 18:15... Se mer"
                            showMatchDetail = true
                        }
                    )
                    
                    // Next Live Section
                    NextLiveSection(
                        onSeeAllTapped: {
                            print("📺 [VG] See all next live broadcasts")
                        },
                        onCardTapped: { index in
                            let titles = ["Lecce - Napoli", "Borussia Dortmund - Bayern Munich", "AC Milan - Inter Milan", "RB Leipzig - Bayer Leverkusen"]
                            let subtitles = ["Sport · i dag, 18:15... Se mer", "Sport · i morgen, 20:30... Se mer", "Sport · i morgen, 18:00... Se mer", "Sport · i overmorgen, 15:30... Se mer"]
                            
                            selectedMatchTitle = titles[index]
                            selectedMatchSubtitle = subtitles[index]
                            showMatchDetail = true
                        }
                    )
                    .padding(.top, 24)
                    
                    // Serie A Section
                    SerieASection(
                        onSeeAllTapped: {
                            print("⚽ [VG] See all Serie A matches")
                        },
                        onCardTapped: { index in
                            let titles = ["Lecce - Napoli", "Atalanta - Milan"]
                            let subtitles = ["Sport · i dag, 18:15... Se mer", "Sport · i dag, 20:30... Se mer"]
                            
                            selectedMatchTitle = titles[index]
                            selectedMatchSubtitle = subtitles[index]
                            showMatchDetail = true
                        }
                    )
                    .padding(.top, 32)
                    
                    // Previous Broadcasts Section
                    PreviousBroadcastsSection(
                        onSeeAllTapped: {
                            print("📺 [VG] See all previous broadcasts")
                        },
                        onCardTapped: { index in
                            let titles = ["Lecce - Napoli", "Atalanta - Milan", "Lazio - Juventus", "Roma - Inter"]
                            let subtitles = ["Sport · i dag, 18:15... Se mer", "Sport · i dag, 20:30... Se mer", "Sport · i går, 20:30... Se mer", "Sport · i går, 18:00... Se mer"]
                            
                            selectedMatchTitle = titles[index]
                            selectedMatchSubtitle = subtitles[index]
                            showMatchDetail = true
                        }
                    )
                    .padding(.top, 32)
                    
                    // Bottom padding for navigation
                    // Spacer()
                    //     .frame(height: 80)
                }
                VStack(alignment: .leading, spacing: 10) {                                    
                    // Header with title and sponsor badge
                    HStack(alignment: .top, spacing: 12) {
                        // Title
                        Text("Ukens tilbud")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                        Spacer()
                        
                        // Sponsor badge
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sponset av")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Image(DemoDataManager.shared.defaultLogo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 80, maxHeight: 24)
                                .onTapGesture {
                                    showProducts = true
                                }
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 16)

                    VProductCarousel(componentId: "product-carousel-template", layout: "compact")
                }
                VStack(alignment: .leading, spacing: 10) {    
                    if let bannerConfig = componentManager.activeBanner {
                        VOfferBannerDynamic(
                            onNavigateToStore: {
                                showProducts = true
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .environment(\.colorScheme, .light)
                .padding(.bottom, 100)            
            }
        }
    }
}

#Preview {
    VGHomeView()
}
