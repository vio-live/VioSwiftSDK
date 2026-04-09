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
    @EnvironmentObject var cartManager: CartManager

    var body: some View {
        ZStack {
            // Main app content
            HomeView()
                .onAppear {
                    // 🎯 SDK: discover active campaigns → WS connect → identify → ready for cart_intent
                    Task {
                        print("🎯 [ContentView] discoverCampaigns() — ver logs [CampaignManager] / [CampaignWebSocket] (respuestas esperadas en 📋 al arranque)")
                        await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
                        print("🎯 [ContentView] Fin discovery — campaigns en memoria: \(CampaignManager.shared.activeCampaigns.count), WS isConnected: \(CampaignManager.shared.isConnected) (puede ser true un instante después)")
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
                .zIndex(1000)
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

        await CampaignManager.shared.ensureCommerceBootstrapApplied()
        print("🎯 [cart_intent] CartIntentProductDetailHost — bootstrap aplicado, lanzando loadProduct id=\(productId)")

        do {
            let product = try await ProductService.shared.loadProduct(
                productId: productId,
                currency: cartManager.currency,
                country: cartManager.country
            )
            loadedProduct = product
        } catch is CancellationError {
            // Task cancelled (e.g. view identity churn) — do not clear cart intent.
        } catch {
            if let sdk = error as? SdkException {
                print("❌ [cart_intent] ProductService.loadProduct failed: \(sdk.description) details=\(String(describing: sdk.details))")
            } else {
                print("❌ [cart_intent] ProductService.loadProduct failed: \(String(describing: error))")
            }
            onDismissIntent()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CartManager())
}
