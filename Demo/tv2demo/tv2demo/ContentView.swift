//
//  ContentView.swift
//  tv2demo
//
//  Created by Angelo Sepulveda on 02/10/2025.
//

import SwiftUI
import VioUI
import VioCore

struct ContentView: View {
    @ObservedObject private var campaignManager = CampaignManager.shared
    @StateObject private var castingManager = CastingManager.shared
    @State private var showCastingView = false
    @State private var cartIntentPresentationID = UUID()
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

            // cart_intent → ProductService (GraphQL) → VProductDetailOverlay en .sheet (mismo contrato que VProductCarousel)
            if let event = campaignManager.activeCartIntentEvent,
               let productId = event.productId, !productId.isEmpty {
                CartIntentProductDetailHost(
                    productId: productId,
                    onDismissIntent: { campaignManager.dismissCartIntent() }
                )
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

// MARK: - cart_intent → ProductService + VProductDetailOverlay (VioUI, sin Engagement)

private struct CartIntentProductDetailHost: View {
    let productId: String
    let onDismissIntent: () -> Void

    @EnvironmentObject private var cartManager: CartManager
    @State private var loadedProduct: Product?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.opacity(isLoading ? 0.4 : 0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    if isLoading {
                        onDismissIntent()
                    }
                }

            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
        .task(id: productId) {
            await loadProduct()
        }
        .sheet(item: $loadedProduct, onDismiss: {
            onDismissIntent()
        }, content: { product in
            VProductDetailOverlay(
                product: product,
                onDismiss: {
                    loadedProduct = nil
                }
            )
            .environmentObject(cartManager)
        })
    }

    @MainActor
    private func loadProduct() async {
        isLoading = true
        loadedProduct = nil
        defer { isLoading = false }

        do {
            let product = try await ProductService.shared.loadProduct(
                productId: productId,
                currency: cartManager.currency,
                country: cartManager.country
            )
            loadedProduct = product
        } catch {
            print("❌ [cart_intent] ProductService.loadProduct failed: \(error.localizedDescription)")
            onDismissIntent()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CartManager())
}
