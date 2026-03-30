//
//  ContentView.swift
//  tv2demo
//
//  Created by Angelo Sepulveda on 02/10/2025.
//

import SwiftUI
import VioUI
import VioCore
import AVFoundation

struct ContentView: View {
    @ObservedObject private var campaignManager = CampaignManager.shared
    @StateObject private var castingManager = CastingManager.shared
    @State private var showCastingView = false
    @State private var cartIntentPresentationID = UUID()
    @EnvironmentObject var cartManager: CartManager

    private var commerceSdkClient: SdkClient {
        let config = VioConfiguration.shared
        let baseURL = URL(string: config.environment.graphQLURL)
            ?? URL(string: "https://graph-ql-dev.vio.live/graphql")!
        let commerceKey = config.liveShowConfiguration.commerceApiKey
        let resolvedApiKey = commerceKey.isEmpty
            ? (config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey)
            : commerceKey
        return SdkClient(baseUrl: baseURL, apiKey: resolvedApiKey)
    }
    
    var body: some View {
        ZStack {
            // Main app content
            HomeView()
                .onAppear {
                    // 🎯 SDK: discover active campaigns → WS connect → identify → ready for cart_intent
                    Task {
                        print("🎯 [ContentView] Starting campaign discovery...")
                        await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
                        print("🎯 [ContentView] Campaigns found: \(CampaignManager.shared.activeCampaigns.count), WS connected: \(CampaignManager.shared.isConnected)")
                    }
                }
            
            // Mini player de casting - SIEMPRE visible cuando hay casting (persistente)
            if castingManager.isCasting {
                CastingMiniPlayer {
                    showCastingView = true
                }
                .zIndex(998) // Por debajo del cart (999) pero por encima del resto
            }
            
            // Global floating cart indicator - always on top
            VFloatingCartIndicator(
                customPadding: EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: castingManager.isCasting ? 180 : 100, // Más arriba si hay casting
                    trailing: TV2Theme.Spacing.md
                )
            )
            .zIndex(999) // Asegurar que esté por encima de todo (video, overlays, etc.)

            // Second-screen cart_intent (e.g. Apple TV tap → iPhone overlay)
            if let event = campaignManager.activeCartIntentEvent,
               let productEvent = TV2CartIntentMapping.productEventData(
                from: event,
                currency: cartManager.currency,
                campaignLogo: campaignManager.currentCampaign?.campaignLogo
               ) {
                TV2ProductOverlay(
                    productEvent: productEvent,
                    isChatExpanded: false,
                    sdk: commerceSdkClient,
                    currency: cartManager.currency,
                    country: cartManager.country,
                    onAddToCart: { productDto in
                        guard let dto = productDto else { return }
                        let product = TV2CartIntentMapping.product(from: dto)
                        Task {
                            await cartManager.addProduct(product, quantity: 1)
                        }
                    },
                    onDismiss: {
                        campaignManager.dismissCartIntent()
                    }
                )
                .environmentObject(cartManager)
                .id(cartIntentPresentationID)
                .zIndex(1000)
            }
        }
        .onChange(of: campaignManager.activeCartIntentEvent) { _, newValue in
            if newValue != nil {
                cartIntentPresentationID = UUID()
            }
        }
        .fullScreenCover(isPresented: $showCastingView) {
            if castingManager.isCasting {
                CastingActiveView(match: Match.barcelonaPSG)
                    .environmentObject(cartManager)
            }
        }
        .onChange(of: castingManager.isCasting) { isCasting in
            if !isCasting {
                showCastingView = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CartManager())
}
