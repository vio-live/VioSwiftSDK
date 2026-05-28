//
//  VGVevArticleView.swift
//  Vg
//
//  Full-screen Vev article (WKWebView) with open-product → Vio cart flow.
//

import SwiftUI
import VioCore
import VioUI

struct VGVevArticleView: View {
    var onClose: () -> Void = {}

    @EnvironmentObject private var cartManager: CartManager
    @ObservedObject private var vioConfig = VioConfiguration.shared

    @StateObject private var productVM: ProductFetchViewModel
    @State private var pendingOpen: VGVevOpenProductRequest?
    @State private var showProductDetail = false

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
        let config = VioConfiguration.shared
        let graphQL = URL(string: config.environment.graphQLURL)!
        let sdk = SdkClient(baseUrl: graphQL, apiKey: config.apiKey)
        _productVM = StateObject(wrappedValue: ProductFetchViewModel(
            sdk: sdk,
            currency: config.marketConfiguration.currencyCode,
            country: config.marketConfiguration.countryCode
        ))
    }

    private let topBarHeight: CGFloat = 56

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            if let articleURL = VGVevTestConfig.articleURLValue {
                VGVevWebView(url: articleURL) { request in
                    print(
                        "🧪 [VGVev] onOpenProduct → productId=\(request.productId) "
                        + "apiKey=\(maskedApiKey(request.apiKey))"
                    )
                    pendingOpen = request
                }
                .padding(.top, topBarHeight)
            } else {
                invalidURLState
                    .padding(.top, topBarHeight)
            }

            topBar
        }
        .onAppear {
            print("🧪 [VGVev] VGVevArticleView appear")
            print("🧪 [VGVev]   articleURL = \(VGVevTestConfig.articleURL)")
            print("🧪 [VGVev]   openProductHost = \(VGVevTestConfig.openProductHost)")
            print("🧪 [VGVev]   openProductPath = \(VGVevTestConfig.openProductPath)")
        }
        .task(id: pendingOpen) {
            guard let pending = pendingOpen else { return }
            print(
                "🧪 [VGVev] Fetch GraphQL productId=\(pending.productId) "
                + "apiKey=\(maskedApiKey(pending.apiKey))"
            )
            await productVM.fetchProduct(productId: pending.productId, apiKey: pending.apiKey)
            if let product = productVM.product {
                print("🧪 [VGVev] ✅ Producto listo: \(product.title) — abriendo VProductDetailOverlay")
                showProductDetail = true
            } else {
                print("🧪 [VGVev] ❌ Fetch falló: \(productVM.errorMessage ?? "sin mensaje")")
            }
            pendingOpen = nil
        }
        .sheet(isPresented: $showProductDetail) {
            if let dto = productVM.product {
                VProductDetailOverlay(
                    product: VGProductDtoConverter.product(from: dto),
                    sponsorId: vioConfig.primarySponsor?.id,
                    onDismiss: {
                        showProductDetail = false
                    }
                )
                .environmentObject(cartManager)
            }
        }
        .alert(
            "Kunne ikke laste produkt",
            isPresented: Binding(
                get: { productVM.errorMessage != nil && !showProductDetail },
                set: { if !$0 { productVM.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                productVM.errorMessage = nil
            }
        } message: {
            Text(productVM.errorMessage ?? "")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Button(action: onClose) {
                Text("Ferdig")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(white: 0.92)))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("VEV Design Test")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)

            Spacer()

            Color.clear.frame(width: 72, height: 1)
        }
        .padding(.horizontal, 12)
        .frame(height: topBarHeight)
        .background(Color.white.opacity(0.97))
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func maskedApiKey(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "(app default)" }
        if key.count <= 4 { return "****" }
        return String(repeating: "*", count: max(0, key.count - 4)) + key.suffix(4)
    }

    private var invalidURLState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "link.badge.plus")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Ugyldig Vev-URL")
                .font(.headline)
            Text("Sett `VGVevTestConfig.articleURL` til den publiserte artikkelen fra editor.vev.design.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

#Preview {
    VGVevArticleView()
        .environmentObject(CartManager())
}
