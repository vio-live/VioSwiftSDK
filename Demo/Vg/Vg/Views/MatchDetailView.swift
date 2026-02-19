import SwiftUI
import VioUI
import VioCore

struct MatchDetailView: View {
    let matchTitle: String
    let matchSubtitle: String
    let onBackTapped: () -> Void
    let onShareTapped: () -> Void
    @State private var showProducts = false
    
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var checkoutDraft: CheckoutDraft
    @StateObject private var componentManager = ComponentManager.shared

    private let contentItems = [
        (image: "card2x1", title: "Tondela - Sporting CP", subtitle: "Sport · 2. oktober", duration: "02:12:09"),
        (image: "card2x2", title: "Jose Mourinho Interview", subtitle: "Sport · 1. oktober", duration: "03:01:55")
    ]
    
    var body: some View {
        ZStack {
            // Background
            VGTheme.Colors.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header with back button and share
                    HStack {
                        Button(action: onBackTapped) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: onShareTapped) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                    
                    // Main content area (video)
                        LivePreviewWithPlayButton()
                    
                    // "Neste" section
                    VStack(alignment: .leading, spacing: 16) {
                        // Section header
                        Text("Neste")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Content cards
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(0..<contentItems.count, id: \.self) { index in
                                    ContentCard(
                                        imageName: contentItems[index].image,
                                        title: contentItems[index].title,
                                        subtitle: contentItems[index].subtitle,
                                        duration: contentItems[index].duration
                                    ) {
                                        print("Content item \(index) tapped")
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
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
                        // Auto-loads based on VioConfiguration (currency/country)
                        VProductCarousel(componentId: "product-carousel-template", layout: "compact")
                    }
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
            }
            
            // Floating cart indicator - always on top
            VFloatingCartIndicator(
                customPadding: EdgeInsets(top: 0, leading: 0, bottom: 80, trailing: 16)
            )
            .zIndex(10000)
        }
        .sheet(isPresented: $showProducts) {
            ProductsView(onBackTapped: {
                showProducts = false
            })
        }
        .sheet(isPresented: $cartManager.isCheckoutPresented) {
            VCheckoutOverlay()
                .environmentObject(cartManager)
                .environmentObject(checkoutDraft)
        }
    }
}

// MARK: - Live preview hero with Play button

private struct LivePreviewWithPlayButton: View {
    @State private var showPreMatchView = false
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var checkoutDraft: CheckoutDraft
    
    var body: some View {
        VStack(spacing: 0) {
        ZStack(alignment: .bottomLeading) {
                // Background image
                Image("bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 220)
                .clipped()
                .overlay(
                    // Sutil degradado para legibilidad en la parte inferior
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Botón Play en esquina inferior izquierda
                Button(action: { showPreMatchView = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Play")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(VGTheme.Colors.red)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: VGTheme.Colors.red.opacity(0.6), radius: 8, x: 0, y: 0)
            }
            .padding(.leading, 16)
            .padding(.bottom, 14)
        }
        .contentShape(Rectangle())
            .onTapGesture { showPreMatchView = true }
            
            // Match title and description below the image
            VStack(alignment: .leading, spacing: 8) {
                Text("Barcelona - PSG")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Champions League · Live now")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .fullScreenCover(isPresented: $showPreMatchView) {
            VGPreMatchView()
                .environmentObject(cartManager)
                .environmentObject(checkoutDraft)
        }
    }
}

#Preview {
    MatchDetailView(
        matchTitle: "Moreirense - FC Porto",
        matchSubtitle: "Sport · i går, 21:05... Se mer",
        onBackTapped: {
            print("Back tapped")
        },
        onShareTapped: {
            print("Share tapped")
        }
    )
}
