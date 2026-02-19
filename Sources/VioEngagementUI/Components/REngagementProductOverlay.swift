//
//  VEngagementProductOverlay.swift
//  VioEngagementUI
//
//  Product overlay component for engagement system
//  Uses SDK colors from configuration instead of hardcoded values
//

import SwiftUI
import VioCore
import VioDesignSystem

/// Product overlay component for engagement system
public struct VEngagementProductOverlay: View {
    let product: VEngagementProductData
    let isChatExpanded: Bool
    let isLoading: Bool
    let onAddToCart: () -> Void
    let onShowDetail: (() -> Void)?
    let onDismiss: () -> Void
    
    @State private var showCheckmark = false
    @State private var dragOffset: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private var bottomPadding: CGFloat {
        if isLandscape {
            return isChatExpanded ? 250 : 156
        } else {
            return isChatExpanded ? 250 : 80
        }
    }
    
    public init(
        product: VEngagementProductData,
        isChatExpanded: Bool,
        isLoading: Bool = false,
        onAddToCart: @escaping () -> Void,
        onShowDetail: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.product = product
        self.isChatExpanded = isChatExpanded
        self.isLoading = isLoading
        self.onAddToCart = onAddToCart
        self.onShowDetail = onShowDetail
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        let shouldShowDiscount = VioConfiguration.shared.uiConfiguration.showDiscountBadge && 
                                 product.discountPercentage != nil && 
                                 (product.discountPercentage ?? 0) > 0
        
        VStack(spacing: 0) {
            if isLandscape {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    productCard(colors: colors, shouldShowDiscount: shouldShowDiscount)
                        .frame(width: 280)
                        .padding(.trailing, VioSpacing.md)
                        .padding(.bottom, VioSpacing.md)
                        .offset(x: dragOffset)
                        .gesture(dragGesture)
                }
            } else {
                Spacer()
                productCard(colors: colors, shouldShowDiscount: shouldShowDiscount)
                    .padding(.horizontal, VioSpacing.md)
                    .padding(.bottom, bottomPadding)
                    .offset(y: dragOffset)
                    .gesture(dragGesture)
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isLandscape {
                    if value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                } else {
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                if isLandscape {
                    if value.translation.width > threshold {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                } else {
                    if value.translation.height > threshold {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
            }
    }
    
    private func productCard(colors: AdaptiveColors, shouldShowDiscount: Bool) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: VioSpacing.md) {
                VEngagementDragIndicator(width: 40)
                    .padding(.top, 4)
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(colors.textPrimary)
                        Text("Cargando producto...")
                            .font(.system(size: 10))
                            .foregroundColor(colors.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                
                VEngagementSponsorBadge()
                
                HStack(alignment: .top, spacing: VioSpacing.md) {
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
                    .padding(.vertical, VioSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                            .fill(showCheckmark ? colors.success : colors.primary.opacity(0.8))
                    )
                }
                .disabled(showCheckmark)
            }
            .padding(VioSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VioBorderRadius.large)
                    .fill(colors.surface.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: VioBorderRadius.large)
                            .fill(.ultraThinMaterial)
                    )
            )
            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 8)
        }
    }
}
