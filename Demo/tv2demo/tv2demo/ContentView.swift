//
//  ContentView.swift
//  tv2demo
//
//  Created by Angelo Sepulveda on 02/10/2025.
//

import SwiftUI
import VioUI
import VioCore
import VioEngagementUI
import VioCastingUI
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

            // Second-screen cart_intent — mismo patrón que `VCastingVideoPlayer` / Viaplay casting
            if let event = campaignManager.activeCartIntentEvent,
               let productId = event.productId, !productId.isEmpty {
                CartIntentEngagementProductHost(
                    event: event,
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

// MARK: - cart_intent → VEngagementProductOverlay + VProductDetailOverlay (igual que VCastingVideoPlayer)

private struct CartIntentEngagementProductHost: View {
    let event: CartIntentEvent
    let productId: String
    let sdk: SdkClient
    let onDismiss: () -> Void

    @EnvironmentObject private var cartManager: CartManager
    @StateObject private var viewModel: ProductFetchViewModel
    @State private var showProductDetail = false

    init(
        event: CartIntentEvent,
        productId: String,
        sdk: SdkClient,
        currency: String,
        country: String,
        onDismiss: @escaping () -> Void
    ) {
        self.event = event
        self.productId = productId
        self.sdk = sdk
        self.onDismiss = onDismiss
        _viewModel = StateObject(
            wrappedValue: ProductFetchViewModel(
                sdk: sdk,
                currency: currency,
                country: country
            )
        )
    }

    var body: some View {
        VEngagementProductOverlay(
            product: VEngagementProductData(
                productId: productId,
                name: viewModel.product?.title ?? event.productName ?? "Product",
                description: TV2CartIntentMapping.engagementDescription(from: viewModel.product),
                price: viewModel.product.map { TV2CartIntentMapping.formatDisplayPrice($0.price) } ?? "",
                imageUrl: viewModel.product?.images.first?.url ?? "",
                discountPercentage: TV2CartIntentMapping.discountPercentage(from: viewModel.product)
            ),
            isChatExpanded: false,
            isLoading: viewModel.isLoading,
            onAddToCart: {
                guard let dto = viewModel.product else { return }
                let product = TV2CartIntentMapping.product(from: dto)
                Task {
                    await cartManager.addProduct(product, quantity: 1)
                }
            },
            onShowDetail: {
                if viewModel.product != nil {
                    showProductDetail = true
                }
            },
            onDismiss: onDismiss
        )
        .task(id: productId) {
            viewModel.currency = cartManager.currency
            viewModel.country = cartManager.country
            await viewModel.fetchProduct(productId: productId)
        }
        .sheet(isPresented: $showProductDetail) {
            if let dto = viewModel.product {
                VProductDetailOverlay(
                    product: TV2CartIntentMapping.product(from: dto),
                    onDismiss: { showProductDetail = false },
                    onAddToCart: { _ in showProductDetail = false }
                )
                .environmentObject(cartManager)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CartManager())
}
