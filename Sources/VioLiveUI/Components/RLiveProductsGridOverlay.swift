import SwiftUI
import VioCore
import VioLiveShow
import VioDesignSystem
import VioUI

#if os(iOS)
import UIKit
#endif

/// Products grid overlay that slides from bottom (80% height)
public struct RLiveProductsGridOverlay: View {
    
    // MARK: - Properties
    private let products: [LiveProduct]
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cartManager: CartManager
    @State private var selectedProduct: Product?
    
    // Configuration
    private var config: VioConfiguration { VioConfiguration.shared }
    private var theme: VioTheme { config.theme }
    private var uiConfig: UIConfiguration { config.uiConfiguration }
    
    // Colors based on theme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    // Grid configuration with compact spacing
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: VioSpacing.sm),
            GridItem(.flexible(), spacing: VioSpacing.sm)
        ]
    }
    
    public init(products: [LiveProduct]) {
        self.products = products
    }
    
    // MARK: - Body
    public var body: some View {
        VStack(spacing: 0) {
            // Custom header
            headerSection
            
            // Products grid with proper layout
            ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: VioSpacing.md) {
                        ForEach(products) { liveProduct in
                            compactProductCard(liveProduct)
                        }
                    }
                .padding(.horizontal, VioSpacing.lg)
                .padding(.top, VioSpacing.md)
                .padding(.bottom, VioSpacing.lg)
            }
        }
        .background(adaptiveColors.background)
        .cornerRadius(VioBorderRadius.large)
        .clipped() // Prevent overflow
        .ignoresSafeArea(.container, edges: .bottom) // Remove white border at bottom
        .sheet(item: $selectedProduct) { product in
            VioProductDetailOverlay(
                product: product,
                onAddToCart: { product in
                    Task {
                        await cartManager.addProduct(product, quantity: 1)
                    }
                    // Close both overlays after adding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        selectedProduct = nil
                        dismiss()
                    }
                }
            )
            .environmentObject(cartManager)
        }
    }
    
    // MARK: - Compact Product Card
    
    @ViewBuilder
    private func compactProductCard(_ liveProduct: LiveProduct) -> some View {
        VStack(alignment: .leading, spacing: VioSpacing.sm) {
            // Product image
            AsyncImage(url: URL(string: liveProduct.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(adaptiveColors.surfaceSecondary)
                    .overlay(
                        VioCustomLoader(style: .rotate, size: 30)
                    )
            }
            .frame(height: 100) // More compact height
            .cornerRadius(VioBorderRadius.medium)
            .clipped()
            
            // Product info
            VStack(alignment: .leading, spacing: VioSpacing.xs) {
                Text(liveProduct.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(adaptiveColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: VioSpacing.xs) {
                    Text(liveProduct.price.formattedPrice)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(adaptiveColors.primary)
                    
                    // Use compare_at_incl_taxes if available for original price
                    if let originalPrice = liveProduct.originalPrice,
                       let compareAtPrice = originalPrice.formattedCompareAtPrice {
                        Text(compareAtPrice)
                            .font(.system(size: 12))
                            .foregroundColor(adaptiveColors.textTertiary)
                            .strikethrough()
                    }
                }
                
                // Remove add to cart button - only tap to open detail
            }
        }
        .padding(VioSpacing.sm)
        .background(adaptiveColors.surface)
        .cornerRadius(VioBorderRadius.medium)
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180) // Fixed consistent height
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(adaptiveColors.textTertiary)
                .frame(width: 40, height: 4)
                .padding(.top, VioSpacing.sm)
            
            // Header content with avatar and title
            HStack {
                // Avatar + Title section
                HStack(spacing: VioSpacing.sm) {
                    AsyncImage(url: URL(string: "https://storage.googleapis.com/tipio-images/1756737999235-012.png")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(adaptiveColors.surfaceSecondary)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Featured Products")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(adaptiveColors.textPrimary)
                        
                        Text("Live Shopping • \(products.count) items")
                            .font(.system(size: 11))
                            .foregroundColor(adaptiveColors.textSecondary)
                    }
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .font(.system(size: 14))
                .foregroundColor(adaptiveColors.primary)
            }
            .padding(.horizontal, VioSpacing.lg)
            .padding(.vertical, VioSpacing.md)
            
            Divider()
                .background(adaptiveColors.border)
        }
        .background(adaptiveColors.surface)
    }
}

// Corner radius extensions removed - using standard cornerRadius

// MARK: - Preview

#Preview {
    RLiveProductsGridOverlay(products: DemoProductData.featuredProducts)
        .environmentObject(CartManager())
}
