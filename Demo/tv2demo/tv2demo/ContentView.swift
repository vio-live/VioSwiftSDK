//
//  ContentView.swift
//  tv2demo
//
//  Created by Angelo Sepulveda on 02/10/2025.
//

import SwiftUI
import VioUI
import VioCore

/// Same console shape as VioUI overlays: bullseye + bracket tag + message.
private enum TV2DemoConsole {
    private static let tag = "\u{1F3AF} [TV2Demo]"
    static func log(_ message: String) {
        print("\(tag) \(message)")
    }
}

struct ContentView: View {
    @ObservedObject private var campaignManager = CampaignManager.shared
    @StateObject private var castingManager = CastingManager.shared
    @State private var showCastingView = false
    @State private var didLogWebSocketConnected = false
    @State private var didLogWebSocketTimeout = false
    @EnvironmentObject var cartManager: CartManager

    var body: some View {
        ZStack {
            // Main app content
            HomeView()
                .onAppear {
                    Task {
                        TV2DemoConsole.log("Discovering campaigns…")
                        await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
                        let n = campaignManager.activeCampaigns.count
                        TV2DemoConsole.log("Discovery complete: campaigns=\(n) (WebSocket finishes connecting shortly after)")
                        #if DEBUG
                        Task {
                            try? await Task.sleep(nanoseconds: 10_000_000_000)
                            await MainActor.run {
                                guard !didLogWebSocketConnected, !didLogWebSocketTimeout else { return }
                                didLogWebSocketTimeout = true
                                if !campaignManager.isConnected {
                                    TV2DemoConsole.log("WebSocket not connected after 10s timeout")
                                }
                            }
                        }
                        #endif
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
                    campaignId: event.campaignId,
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
        .onChange(of: campaignManager.isConnected) { _, connected in
            guard connected, !didLogWebSocketConnected else { return }
            didLogWebSocketConnected = true
            TV2DemoConsole.log("WebSocket connected")
        }
    }
}

// MARK: - cart_intent → ProductService + VProductDetailOverlay (VioUI, sin Engagement)

private struct CartIntentProductDetailHost: View {
    let productId: String
    let campaignId: Int?
    let onDismissIntent: () -> Void

    @EnvironmentObject private var cartManager: CartManager
    @State private var loadedProduct: Product?
    @State private var isLoading = false

    /// Stable id for `.task` so same product in a different campaign reloads; identical to ``CampaignManager`` presentation key (productId + campaignId).
    private var cartIntentLoadTaskId: String {
        let c = campaignId.map(String.init) ?? ""
        return "\(productId)|\(c)"
    }

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
        .task(id: cartIntentLoadTaskId) {
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

        TV2DemoConsole.log("cart_intent overlay loadProduct id=\(productId)")

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
                TV2DemoConsole.log("cart_intent loadProduct failed: \(sdk.description)")
            } else {
                TV2DemoConsole.log("cart_intent loadProduct failed: \(String(describing: error))")
            }
            onDismissIntent()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CartManager())
}
