//
//  VEngagementProductCard.swift
//  VioEngagementUI
//
//  Product card component for engagement system
//  Uses SDK colors from configuration instead of hardcoded values
//

import SwiftUI
import VioCore
import VioDesignSystem

/// Product data for engagement card
public struct VEngagementProductData {
    public let productId: String?
    public let name: String
    public let description: String?
    public let price: String
    public let imageUrl: String
    public let discountPercentage: Int?
    
    public init(
        productId: String? = nil,
        name: String,
        description: String? = nil,
        price: String,
        imageUrl: String,
        discountPercentage: Int? = nil
    ) {
        self.productId = productId
        self.name = name
        self.description = description
        self.price = price
        self.imageUrl = imageUrl
        self.discountPercentage = discountPercentage
    }
}

/// Product card component for engagement system
public struct VEngagementProductCard: View {
    let product: VEngagementProductData
    let onAddToCart: () -> Void
    let onDismiss: () -> Void
    let onShowDetail: (() -> Void)?
    
    @State private var showCheckmark = false
    @State private var showProductDetail = false
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        product: VEngagementProductData,
        onAddToCart: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onShowDetail: (() -> Void)? = nil
    ) {
        self.product = product
        self.onAddToCart = onAddToCart
        self.onDismiss = onDismiss
        self.onShowDetail = onShowDetail
    }
    
    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        let shouldShowDiscount = VioConfiguration.shared.uiConfiguration.showDiscountBadge && 
                                 product.discountPercentage != nil && 
                                 (product.discountPercentage ?? 0) > 0
        
        VStack(spacing: VioSpacing.sm) {
                // Drag indicator
                VEngagementDragIndicator(width: 40)
                    .padding(.top, 4)
                
                // Sponsor badge
                VEngagementSponsorBadge()
                
                // Product
                HStack(alignment: .top, spacing: VioSpacing.sm) {
                    // Image
                    ZStack(alignment: .topTrailing) {
                        if let url = URL(string: product.imageUrl) {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .clipped()
                                    .cornerRadius(VioBorderRadius.medium)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                    .fill(colors.surfaceSecondary)
                                    .frame(width: 90, height: 90)
                                    .overlay(
                                        ProgressView()
                                            .tint(colors.textPrimary)
                                    )
                            }
                        } else {
                            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                .fill(colors.surfaceSecondary)
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(colors.textSecondary)
                                )
                        }
                        
                        // Discount badge
                        if shouldShowDiscount, let discount = product.discountPercentage {
                            Text("-\(discount)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(colors.textOnPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(colors.primary)
                                .rotationEffect(.degrees(-10))
                                .offset(x: 8, y: -8)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(product.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colors.textPrimary)
                            .lineLimit(2)
                        
                        if let description = product.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 11))
                                .foregroundColor(colors.textSecondary)
                                .lineLimit(2)
                        }
                        
                        Text(product.price)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colors.priceColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Button
                Button(action: {
                    if let onShowDetail = onShowDetail {
                        onShowDetail()
                    } else {
                        onAddToCart()
                        showCheckmark = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCheckmark = false
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        if showCheckmark {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Lagt til!")
                                .font(.system(size: 13, weight: .semibold))
                        } else {
                            Text("Legg til")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundColor(colors.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                            .fill(showCheckmark ? colors.success : colors.primary.opacity(0.8))
                    )
                }
                .disabled(showCheckmark)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: VioBorderRadius.large)
                    .fill(colors.surface.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: VioBorderRadius.large)
                            .fill(.ultraThinMaterial)
                    )
            )
            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 8)
            .frame(maxWidth: EngagementCardLayout.maxCardWidth)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            // Drag handled
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            onDismiss()
                        }
                    }
            )
    }
}
