import SwiftUI
import VioCore
import VioLiveShow
import VioDesignSystem
import VioUI

/// Live Product Card component - horizontal layout with full configuration integration
public struct RLiveProductCard: View {
    
    // MARK: - Properties
    private let product: LiveProduct
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cartManager: CartManager
    @State private var showProductDetail = false
    
    // Configuration
    private var config: VioConfiguration { VioConfiguration.shared }
    private var theme: VioTheme { config.theme }
    private var uiConfig: UIConfiguration { config.uiConfiguration }
    
    // Colors based on theme and color scheme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    // Convert LiveProduct to Product for detail overlay
    private var productForDetail: Product {
        product.asProduct
    }
    
    public init(product: LiveProduct) {
        self.product = product
    }
    
    // MARK: - Body
    public var body: some View {
        HStack(spacing: VioSpacing.sm) {
            // Product image (smaller)
            productImage
            
            // Product info (compact)
            productInfo
            
            // Live indicator only
            liveIndicator
        }
        .padding(VioSpacing.sm)
        .background(backgroundView)
        .overlay(borderView)
        .cornerRadius(theme.borderRadius.medium)
        .onTapGesture {
            print("🛒 [LiveProduct] Tapped product: \(product.title)")
            showProductDetail = true
        }
        .sheet(isPresented: $showProductDetail) {
            VioProductDetailOverlay(
                product: productForDetail,
                onAddToCart: { product in
                    // Handle add to cart from detail overlay
                    print("🛒 [LiveProduct] Adding to cart from detail: \(product.title)")
                    Task {
                        await cartManager.addProduct(product, quantity: 1)
                        print("✅ [LiveProduct] Successfully added to cart: \(product.title)")
                    }
                }
            )
            .environmentObject(cartManager)
        }
    }
    
    // MARK: - Product Image
    
    @ViewBuilder
    private var productImage: some View {
        AsyncImage(url: URL(string: product.imageUrl)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(adaptiveColors.surfaceSecondary)
                .overlay(
                    VioCustomLoader(style: .rotate, size: 20, speed: 1.5)
                )
        }
        .frame(width: 60, height: 60)
        .cornerRadius(theme.borderRadius.small)
        .clipped()
    }
    
    // MARK: - Product Info
    
    @ViewBuilder
    private var productInfo: some View {
        VStack(alignment: .leading, spacing: VioSpacing.xs) {
            // Product title (smaller)
            Text(product.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(adaptiveColors.textPrimary)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
            
            // Brand name (smaller)
            Text("COSMED BEAUTY")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(adaptiveColors.textSecondary)
                .lineLimit(1)
            
            // Price section (compact)
            priceSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Price Section
    
    @ViewBuilder
    private var priceSection: some View {
        HStack(spacing: VioSpacing.xs) {
            // Current price (smaller) - uses amount_incl_taxes if available
            Text(product.price.formattedPrice)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.red)
            
            // Original price (strikethrough, smaller) - uses compare_at_incl_taxes if available
            if let originalPrice = product.originalPrice,
               let compareAtPrice = originalPrice.formattedCompareAtPrice {
                Text(compareAtPrice)
                    .font(.system(size: 12))
                    .foregroundColor(adaptiveColors.textTertiary)
                    .strikethrough()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Live Indicator
    
    @ViewBuilder
    private var liveIndicator: some View {
        VStack {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
            
            Spacer()
        }
    }
    
    // MARK: - Background & Border
    
    @ViewBuilder
    private var backgroundView: some View {
        Rectangle()
            .fill(adaptiveColors.surface.opacity(0.9))
    }
    
    @ViewBuilder
    private var borderView: some View {
        if uiConfig.enableProductCardAnimations {
            Rectangle()
                .stroke(adaptiveColors.border, lineWidth: 1)
        } else {
            Rectangle()
                .stroke(Color.clear, lineWidth: 0)
        }
    }
    
    // Actions removed - now handled by VioProductDetailOverlay
}

// MARK: - Preview

#Preview("Light Mode") {
    VStack(spacing: 20) {
        RLiveProductCard(product: DemoProductData.featuredProducts[0])
            .environmentObject(CartManager())
        
        RLiveProductCard(product: DemoProductData.featuredProducts[1])
            .environmentObject(CartManager())
    }
    .padding()
    .background(Color.black.opacity(0.8))
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        RLiveProductCard(product: DemoProductData.featuredProducts[0])
            .environmentObject(CartManager())
        
        RLiveProductCard(product: DemoProductData.featuredProducts[1])
            .environmentObject(CartManager())
    }
    .padding()
    .background(Color.black.opacity(0.8))
    .preferredColorScheme(.dark)
}
