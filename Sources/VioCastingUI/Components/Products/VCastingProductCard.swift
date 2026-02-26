//
//  CastingProductCard.swift
//  Viaplay
//
//  Component for displaying Casting product events in the timeline
//  Shows multiple Vio products with discount badge and Viaplay colors
//

import SwiftUI
import VioCore
import VioUI
import VioDesignSystem

struct CastingProductCard: View {
    let productEvent: CastingProductEvent
    let onViewProduct: () -> Void
    
    @State private var showModal = false
    @State private var selectedProductEvent: CastingProductEvent?
    @State private var products: [Product] = []
    @State private var isLoadingProducts = false
    
    // Get currency and country from CartManager
    @EnvironmentObject private var cartManager: CartManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let brandConfig = VioConfiguration.shared.brandConfiguration
        let colors = VioColors.adaptive(for: colorScheme)
        
        return VStack(alignment: .leading, spacing: 12) {
            // Header (similar to CastingContestCard)
            HStack(spacing: 8) {
                // Brand avatar from config (consistent with brand name)
                Image(VioConfiguration.shared.effectiveBrandConfiguration.iconAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(brandConfig.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 9))
                                .foregroundColor(colors.primary)
                            
                            Text("Produkt")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text(productEvent.displayTime)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    // Badge alineado a la derecha del nombre
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(colors.info)
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                // Campaign sponsor badge
                CampaignSponsorBadge(
                    maxWidth: 50,
                    maxHeight: 16,
                    alignment: .trailing
                )
            }
            
            // Promotional text
            Text("Ikke gå glipp av denne muligheten - 25% rabatt kun under kampen")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineSpacing(2)
                .padding(.vertical, 4)
            
            // Products grid (side by side, elongated cards)
            if isLoadingProducts {
                // Loading skeleton
                HStack(spacing: 12) {
                    ForEach(0..<min(2, productEvent.allProductIds.count), id: \.self) { _ in
                        VStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 140)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 16)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 60, height: 16)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 36)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 280)
                    }
                }
            } else if !products.isEmpty {
                HStack(spacing: 12) {
                    ForEach(products.prefix(2), id: \.id) { product in
                        individualProductCard(product: product, colors: colors)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    colors.primary.opacity(0.4),
                                    colors.primary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .fullScreenCover(item: $selectedProductEvent) { event in
            CastingProductModal(productEvent: event) {
                selectedProductEvent = nil
                showModal = false
            }
        }
        .task {
            await loadProducts()
        }
    }
    
    // MARK: - Individual Product Card View (with its own button)
    
    @ViewBuilder
    private func individualProductCard(product: Product, colors: AdaptiveColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Ensure card doesn't overflow
            // Image container with fixed height for consistency
            ZStack(alignment: .topTrailing) {
                // Background for image container
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(height: 140)
                
                // Product image - centered and fixed size
                if let firstImage = product.images.first,
                   let imageUrl = URL(string: firstImage.url) {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 140)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: 140)
                                .clipped()
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 140)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 140)
                }
                
                // Discount badge (25%)
                discountBadge(text: "-25%", colors: colors)
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .cornerRadius(8)
            
            // Product title
            Text(product.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Price
            VStack(alignment: .leading, spacing: 2) {
                Text(product.price.displayAmount)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.primary)
                
                if let compareAtAmount = product.price.displayCompareAtAmount {
                    Text(compareAtAmount)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .strikethrough()
                }
            }
            
            // Individual buy button for this product
            Button(action: {
                // Create a temporary event for this specific product to open its checkout
                let tempEvent = CastingProductEvent(
                    id: productEvent.id + "-\(product.id)",
                    videoTimestamp: productEvent.videoTimestamp,
                    productId: String(product.id),
                    productIds: nil,
                    title: product.title,
                    description: productEvent.description,
                    castingProductUrl: getProductUrl(for: product),
                    castingCheckoutUrl: getProductUrl(for: product),
                    imageAsset: nil,
                    metadata: nil
                )
                
                selectedProductEvent = tempEvent
                showModal = true
                onViewProduct()
            }) {
                HStack {
                    Spacer()
                    Text("Kjøp nå")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    colors.primary,
                                    colors.primary.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280) // Fixed minimum height for consistency
        .layoutPriority(1) // Ensure proper layout
    }
    
    // MARK: - Helper to get product URL
    
    private func getProductUrl(for product: Product) -> String? {
        let productIdString = String(product.id)
        return DemoDataManager.shared.productUrl(for: productIdString) ?? productEvent.castingProductUrl
    }
    
    // MARK: - Discount Badge
    
    private func discountBadge(text: String, colors: AdaptiveColors) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(colors.primary)
            )
            .padding(6)
    }
    
    // MARK: - Helper Functions
    
    private func loadProducts() async {
        isLoadingProducts = true
        
        let productIds = productEvent.allProductIds
        
        do {
            // Load all products
            let productIdInts = productIds.compactMap { Int($0) }
            let loadedProducts = try await ProductService.shared.loadProducts(
                productIds: productIdInts,
                currency: cartManager.currency,
                country: cartManager.country
            )
            
            await MainActor.run {
                self.products = loadedProducts
                self.isLoadingProducts = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingProducts = false
            }
        }
    }
}
