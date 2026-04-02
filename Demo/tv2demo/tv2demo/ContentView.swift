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

            // Second-screen cart_intent — solo `VProductDetailOverlay` (VioUI) tras fetch; sin tarjetas demo ni casting
            if let event = campaignManager.activeCartIntentEvent,
               let productId = event.productId, !productId.isEmpty {
                CartIntentVProductDetailHost(
                    productId: productId,
                    sdk: commerceSdkClient,
                    currency: cartManager.currency,
                    country: cartManager.country,
                    onDismiss: { campaignManager.dismissCartIntent() }
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

// MARK: - cart_intent → VProductDetailOverlay (commerce)

private struct CartIntentVProductDetailHost: View {
    let productId: String
    let sdk: SdkClient
    let onDismiss: () -> Void

    @EnvironmentObject private var cartManager: CartManager
    @StateObject private var viewModel: ProductFetchViewModel

    init(
        productId: String,
        sdk: SdkClient,
        currency: String,
        country: String,
        onDismiss: @escaping () -> Void
    ) {
        self.productId = productId
        self.sdk = sdk
        self.onDismiss = onDismiss
        _viewModel = StateObject(
            wrappedValue: ProductFetchViewModel(sdk: sdk, currency: currency, country: country)
        )
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            if let dto = viewModel.product {
                VProductDetailOverlay(
                    product: TV2CartIntentMapping.product(from: dto),
                    onDismiss: onDismiss,
                    onAddToCart: { _ in onDismiss() }
                )
                .environmentObject(cartManager)
            } else if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            } else {
                VStack(spacing: 16) {
                    Text("Could not load product")
                        .foregroundStyle(.white)
                    Button("Close", action: onDismiss)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task(id: productId) {
            await viewModel.fetchProduct(productId: productId)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CartManager())
}
