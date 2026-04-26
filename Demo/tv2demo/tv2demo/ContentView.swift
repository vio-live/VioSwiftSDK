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
                        print("🎯 [ContentView] discoverCampaigns()")
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
                    sponsorId: event.sponsorId,
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
    /// Sponsor id carried on the cart_intent envelope. Used to route the
    /// Commerce GraphQL call to the right sponsor's apiKey so overlays rendered
    /// from a secondary sponsor's shoppable_ad (e.g. XXL) don't hit the primary
    /// sponsor's channel (e.g. Elkjøp). Nil falls back to primary.
    let sponsorId: Int?
    let onDismissIntent: () -> Void

    @EnvironmentObject private var cartManager: CartManager
    @State private var loadedProduct: Product?
    /// Default `true` so the loader appears the moment the user taps the push
    /// notification (before `.task` runs and ProductService.loadProduct flips
    /// it). Without this, there's a perceptible silent gap between the tap and
    /// the spinner appearing while the SwiftUI scheduler hasn't processed
    /// `.task` yet — the user assumes nothing happened.
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // Always-on dim while the host is mounted (was flickering between
            // 0.001 and 0.4 depending on isLoading, so the very first frames
            // had no visible feedback at all).
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if isLoading {
                        onDismissIntent()
                    }
                }

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("Laster produkt…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
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
        print("🎯 [cart_intent] CartIntentProductDetailHost — bootstrap aplicado, lanzando loadProduct id=\(productId) sponsorId=\(sponsorId.map(String.init) ?? "nil")")

        do {
            let product = try await ProductService.shared.loadProduct(
                productId: productId,
                currency: cartManager.currency,
                country: cartManager.country,
                sponsorId: sponsorId
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
