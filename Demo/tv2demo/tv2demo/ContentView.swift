//
//  ContentView.swift
//  tv2demo
//
//  Created by Angelo Sepulveda on 02/10/2025.
//

import SwiftUI
import VioUI
import VioCore
import VioLiveUI
import VioLiveShow
import AVFoundation

struct ContentView: View {
    @StateObject private var castingManager = CastingManager.shared
    @State private var showCastingView = false
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        ZStack {
            // Main app content
            HomeView()
            
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
        .overlay {
            // Global live stream overlay (Tipio integration)
            LiveStreamGlobalOverlay()
                .environmentObject(cartManager)
        }
    }
}

// MARK: - Live Stream Overlay

struct LiveStreamGlobalOverlay: View {
    @ObservedObject private var liveShowManager = LiveShowManager.shared
    @EnvironmentObject private var cartManager: CartManager
    
    var body: some View {
        ZStack {
            // Full screen LiveShow overlay
            if liveShowManager.isLiveShowVisible {
                RLiveShowFullScreenOverlay()
                    .environmentObject(cartManager)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CartManager())
}
