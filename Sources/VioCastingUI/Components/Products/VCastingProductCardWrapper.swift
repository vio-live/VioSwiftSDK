//
//  CastingProductCardWrapper.swift
//  Viaplay
//
//  Wrapper component that uses VEngagementProductGridCard from SDK
//  Converts CastingProductEvent to SDK component format
//

import SwiftUI
import VioCore
import VioUI
import VioEngagementUI
import VioDesignSystem

struct CastingProductCardWrapper: View {
    let productEvent: CastingProductEvent
    let onViewProduct: () -> Void
    
    @State private var products: [Product] = []
    @State private var isLoadingProducts = false
    @State private var showModal = false
    @State private var selectedProductEvent: CastingProductEvent?
    
    @EnvironmentObject private var cartManager: CartManager
    
    var body: some View {
        let brandConfig = VioConfiguration.shared.brandConfiguration
        
        return VEngagementProductGridCard(
            products: convertProductsToSDKFormat(products),
            promotionalText: productEvent.description.isEmpty ? "Ikke gå glipp av denne muligheten - 25% rabatt kun under kampen" : productEvent.description,
            brandName: brandConfig.name,
            brandIcon: brandConfig.iconAsset,
            displayTime: productEvent.displayTime,
            isLoading: isLoadingProducts,
            onProductTap: { productData in
                // Find the matching Product from the loaded products
                if let product = products.first(where: { String($0.id) == productData.productId }) {
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
                }
            }
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
    
    private func convertProductsToSDKFormat(_ products: [Product]) -> [VEngagementProductData] {
        return products.map { product in
            let discountPercentage = calculateDiscountPercentage(product)
            
            return VEngagementProductData(
                productId: String(product.id),
                name: product.title,
                description: product.description,
                price: product.price.displayAmount,
                imageUrl: product.images.first?.url ?? "",
                discountPercentage: discountPercentage
            )
        }
    }
    
    private func calculateDiscountPercentage(_ product: Product) -> Int? {
        let currentPrice = product.price.amount_incl_taxes ?? product.price.amount
        let originalPrice = product.price.compare_at_incl_taxes ?? product.price.compare_at
        
        guard let compareAt = originalPrice, compareAt > currentPrice else {
            return nil
        }
        
        let discount = ((compareAt - currentPrice) / compareAt) * 100
        return Int(discount.rounded())
    }
    
    private func getProductUrl(for product: Product) -> String? {
        let productIdString = String(product.id)
        return DemoDataManager.shared.productUrl(for: productIdString) ?? productEvent.castingProductUrl
    }
    
    private func loadProducts() async {
        isLoadingProducts = true
        
        let productIds = productEvent.allProductIds
        
        do {
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
