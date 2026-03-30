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
    @StateObject private var castingManager = CastingManager.shared
    @State private var showCastingView = false
    @EnvironmentObject var cartManager: CartManager
    
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
