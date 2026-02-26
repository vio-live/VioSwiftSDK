//
//  VEngagementProductGridCard.swift
//  VioEngagementUI
//
//  Product grid card component for engagement system
//  Displays multiple products side by side with discount badges
//  Uses SDK colors from configuration instead of hardcoded values
//

import SwiftUI
import VioCore
import VioDesignSystem

#if canImport(UIKit)
import UIKit
#endif

/// Product grid card component for engagement system
/// Displays multiple products in a horizontal grid layout
public struct VEngagementProductGridCard: View {
    let products: [VEngagementProductData]
    let promotionalText: String?
    let brandName: String?
    let brandIcon: String?
    let displayTime: String?
    let isLoading: Bool
    let onProductTap: (VEngagementProductData) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        products: [VEngagementProductData],
        promotionalText: String? = nil,
        brandName: String? = nil,
        brandIcon: String? = nil,
        displayTime: String? = nil,
        isLoading: Bool = false,
        onProductTap: @escaping (VEngagementProductData) -> Void
    ) {
        self.products = products
        self.promotionalText = promotionalText
        self.brandName = brandName
        self.brandIcon = brandIcon
        self.displayTime = displayTime
        self.isLoading = isLoading
        self.onProductTap = onProductTap
    }
    
    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        
        VStack(alignment: .leading, spacing: VioSpacing.md) {
            // Header
            headerView(colors: colors)
            
            // Promotional text
            if let promotionalText = promotionalText {
                Text(promotionalText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colors.textPrimary)
                    .lineSpacing(2)
                    .padding(.vertical, 4)
            }
            
            // Products grid
            if isLoading {
                loadingSkeleton(colors: colors)
            } else if !products.isEmpty {
                productsGridView(colors: colors)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(VioSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                .fill(colors.surfaceSecondary.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: VioBorderRadius.medium)
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
    }
    
    // MARK: - Header View
    
    private func headerView(colors: AdaptiveColors) -> some View {
        // Get effective brand config (dynamic takes precedence)
        let effectiveBrand = VioConfiguration.shared.effectiveBrandConfiguration
        let displayBrandName: String? = brandName ?? effectiveBrand.name
        let displayBrandIcon: String? = brandIcon ?? effectiveBrand.iconAsset
        
        return HStack(spacing: VioSpacing.xs) {
            // Brand icon - use dynamic config if available
            if let iconAsset = displayBrandIcon {
                Image(iconAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            }
            
            HStack(spacing: VioSpacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    if let brandName = displayBrandName {
                        Text(brandName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(colors.textPrimary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 9))
                            .foregroundColor(colors.primary)
                        
                        Text("Produkt")
                            .font(.system(size: 10))
                            .foregroundColor(colors.textSecondary)
                        
                        if let displayTime = displayTime {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(colors.textTertiary)
                            
                            Text(displayTime)
                                .font(.system(size: 10))
                                .foregroundColor(colors.textSecondary)
                        }
                    }
                }
                
                // Badge alineado a la derecha del nombre
                if displayBrandName != nil {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(colors.info)
                        .padding(.leading, 4)
                }
            }
            
            Spacer()
            
            // Campaign sponsor badge - alineado a la derecha
            // Use dynamic sponsor badge text if available
            HStack {
                Spacer()
                let sponsorText = getSponsorBadgeText()
                CampaignSponsorBadge(
                    text: sponsorText,
                    maxWidth: 80,
                    maxHeight: 24,
                    alignment: .trailing
                )
            }
        }
    }
    
    private func getSponsorBadgeText() -> String {
        // Try dynamic config first
        if let dynamicBrand = VioConfiguration.shared.dynamicBrandConfig,
           let sponsorTexts = dynamicBrand.sponsorBadgeText {
            let currentLanguage = VioLocalization.shared.language
            if let text = sponsorTexts[currentLanguage] {
                return text
            }
        }
        // Fallback to default
        return "Sponset av"
    }
    
    // MARK: - Loading Skeleton
    
    private func loadingSkeleton(colors: AdaptiveColors) -> some View {
        HStack(spacing: VioSpacing.md) {
            ForEach(0..<min(2, products.count), id: \.self) { _ in
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(colors.surfaceSecondary.opacity(0.5))
                        .frame(height: 140)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colors.surfaceSecondary.opacity(0.5))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colors.surfaceSecondary.opacity(0.5))
                        .frame(width: 60, height: 16)
                    
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(colors.surfaceSecondary.opacity(0.5))
                        .frame(height: 36)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 280)
            }
        }
    }
    
    // MARK: - Products Grid View
    
    private func productsGridView(colors: AdaptiveColors) -> some View {
        HStack(spacing: VioSpacing.md) {
            ForEach(products.prefix(2), id: \.productId) { product in
                individualProductCard(product: product, colors: colors)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Individual Product Card
    
    private func individualProductCard(product: VEngagementProductData, colors: AdaptiveColors) -> some View {
        let shouldShowDiscount = VioConfiguration.shared.uiConfiguration.showDiscountBadge && 
                                 product.discountPercentage != nil && 
                                 (product.discountPercentage ?? 0) > 0
        
        return VStack(alignment: .leading, spacing: 10) {
            // Image container
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(colors.surface)
                    .frame(height: 140)
                
                if let url = URL(string: product.imageUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 140)
                            .clipped()
                    } placeholder: {
                        ProgressView()
                            .frame(height: 140)
                    }
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                } else {
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(colors.surfaceSecondary.opacity(0.5))
                        .frame(height: 140)
                }
                
                // Discount badge
                if shouldShowDiscount, let discount = product.discountPercentage {
                    discountBadge(text: "-\(discount)%", colors: colors)
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .cornerRadius(VioBorderRadius.small)
            
            // Product title
            Text(product.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Price
            VStack(alignment: .leading, spacing: 2) {
                Text(product.price)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colors.priceColor)
            }
            
            // Buy button
            Button(action: {
                onProductTap(product)
            }) {
                HStack {
                    Spacer()
                    Text("Kjøp nå")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colors.textOnPrimary)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
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
        .frame(minHeight: 280)
        .layoutPriority(1)
    }
    
    // MARK: - Discount Badge
    
    private func discountBadge(text: String, colors: AdaptiveColors) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(colors.textOnPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(colors.primary)
            )
            .padding(6)
    }
}
