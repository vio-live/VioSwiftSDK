import SwiftUI
import VioCore
import VioLiveShow
import VioDesignSystem
import VioUI

/// Reusable Live Products component for LiveShow overlays
public struct RLiveProductsComponent: View {
    
    // MARK: - Properties
    @ObservedObject private var liveShowManager = LiveShowManager.shared
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.colorScheme) private var colorScheme
    
    private let products: [LiveProduct]
    
    // Colors based on theme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(products: [LiveProduct] = []) {
        self.products = products.isEmpty ? DemoProductData.featuredProducts : products
    }
    
    // MARK: - Body
    public var body: some View {
        VStack(spacing: VioSpacing.sm) {
            // Products header
            HStack {
                Text("Featured Products")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(products.count) items")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, VioSpacing.md)
            .padding(.vertical, VioSpacing.sm)
            .background(Color.black.opacity(0.6))
            
            // Products scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VioSpacing.md) {
                    ForEach(products) { product in
                        liveProductCard(product: product)
                    }
                }
                .padding(.horizontal, VioSpacing.md)
            }
            .frame(height: 140)
        }
    }
    
    // MARK: - Product Card
    
    @ViewBuilder
    private func liveProductCard(product: LiveProduct) -> some View {
        VStack(alignment: .leading, spacing: VioSpacing.xs) {
            // Product image
            AsyncImage(url: URL(string: product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        VCustomLoader(style: .rotate, size: 24, color: .white)
                    )
            }
            .frame(width: 90, height: 90)
            .cornerRadius(VioBorderRadius.medium)
            .clipped()
            
            // Product info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: VioSpacing.xs) {
                    Text(product.price.formattedPrice)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(adaptiveColors.primary)
                    
                    // Use compare_at_incl_taxes if available for original price
                    if let originalPrice = product.originalPrice,
                       let compareAtPrice = originalPrice.formattedCompareAtPrice {
                        Text(compareAtPrice)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .strikethrough()
                    }
                }
                
                // Discount badge
                if let discount = product.discount, !discount.isEmpty {
                    Text(discount)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(4)
                }
            }
            .frame(width: 90, alignment: .leading)
            
            Spacer()
            
            // Add to cart button
            Button(action: {
                addProductToCart(product)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.medium))
                    Text("Add")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, VioSpacing.sm)
                .padding(.vertical, 6)
                .background(adaptiveColors.primary)
                .cornerRadius(VioBorderRadius.small)
            }
        }
        .frame(width: 110)
        .padding(VioSpacing.sm)
        .background(Color.black.opacity(0.5))
        .cornerRadius(VioBorderRadius.medium)
    }
    
    // MARK: - Helper Methods
    
    private func addProductToCart(_ product: LiveProduct) {
        liveShowManager.addProductToCart(product, cartManager: cartManager)
        
        // Visual feedback
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Add haptic feedback
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            #endif
        }
        
        print("🛒 [Products] Added to cart: \(product.title)")
    }
}

// MARK: - Demo Product Data

public struct DemoProductData {
    
    static let featuredProducts: [LiveProduct] = [
        LiveProduct(
            id: "live-product-1",
            title: "All Day Shield SPF 50",
            price: Price(amount: 29.99, currency_code: "USD"),
            originalPrice: Price(amount: 39.99, currency_code: "USD"),
            imageUrl: "https://picsum.photos/200/200?random=10",
            isAvailable: true,
            stockCount: 25,
            discount: "25% OFF",
            specialOffer: "Limited time offer for live viewers!",
            showUntil: Date().addingTimeInterval(600) // 10 minutes
        ),
        LiveProduct(
            id: "live-product-2",
            title: "Moisturizing Cream",
            price: Price(amount: 19.99, currency_code: "USD"),
            imageUrl: "https://picsum.photos/200/200?random=11",
            isAvailable: true,
            stockCount: 50,
            specialOffer: "Perfect for daily skincare routine"
        ),
        LiveProduct(
            id: "live-product-3",
            title: "Vitamin C Serum",
            price: Price(amount: 34.99, currency_code: "USD"),
            originalPrice: Price(amount: 44.99, currency_code: "USD"),
            imageUrl: "https://picsum.photos/200/200?random=12",
            isAvailable: true,
            stockCount: 15,
            discount: "22% OFF",
            specialOffer: "Brighten your skin instantly!"
        ),
        LiveProduct(
            id: "live-product-4",
            title: "Cleansing Oil",
            price: Price(amount: 24.99, currency_code: "USD"),
            imageUrl: "https://picsum.photos/200/200?random=13",
            isAvailable: true,
            stockCount: 30,
            specialOffer: "Gentle and effective cleansing"
        ),
        LiveProduct(
            id: "live-product-5",
            title: "Eye Cream Repair",
            price: Price(amount: 39.99, currency_code: "USD"),
            originalPrice: Price(amount: 49.99, currency_code: "USD"),
            imageUrl: "https://picsum.photos/200/200?random=14",
            isAvailable: true,
            stockCount: 20,
            discount: "20% OFF",
            specialOffer: "Anti-aging formula for delicate eye area"
        )
    ]
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            RLiveProductsComponent()
                .environmentObject(CartManager())
        }
    }
}
