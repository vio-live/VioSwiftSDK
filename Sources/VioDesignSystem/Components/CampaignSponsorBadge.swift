//
//  CampaignSponsorBadge.swift
//  VioDesignSystem
//
//  Reusable component for displaying campaign sponsor logo
//  Uses VioConfiguration.dynamicBrandConfig.logoUrl (set by DynamicConfigurationManager)
//

import SwiftUI
import VioCore

/// Reusable component for displaying campaign sponsor logo
/// Uses CampaignManager to get the logo dynamically with caching
public struct CampaignSponsorBadge: View {
    let text: String
    let maxWidth: CGFloat?
    let maxHeight: CGFloat
    let alignment: HorizontalAlignment
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        text: String = "Sponset av",
        maxWidth: CGFloat? = nil,
        maxHeight: CGFloat = 24,
        alignment: HorizontalAlignment = .leading
    ) {
        self.text = text
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.alignment = alignment
    }
    
    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        
        VStack(alignment: alignment, spacing: 2) {
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(colors.textSecondary)
            
            // Logo from VioConfiguration.dynamicBrandConfig (evita EXC_BAD_ACCESS en campaignManager.currentCampaign?.campaignLogo)
            if let urlString = VioConfiguration.shared.dynamicBrandConfig?.logoUrl, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                } placeholder: {
                    // Placeholder will be instant if cached
                    Rectangle()
                        .fill(colors.surfaceSecondary)
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                }
            } else {
                // Fallback placeholder if no campaign logo
                Rectangle()
                    .fill(colors.surfaceSecondary)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            }
        }
    }
}
