//
//  CampaignSponsorBadge.swift
//  VioDesignSystem
//
//  Displays campaign sponsor logo from backend.
//  Source of truth: VioConfiguration.sponsorConfig (section "sponsor" in /v1/campaigns/:id/config)
//  Fallback: VioConfiguration.dynamicBrandConfig.logoUrl (section "brand")
//

import SwiftUI
import VioCore

/// Reusable component for displaying campaign sponsor logo
public struct CampaignSponsorBadge: View {
    let text: String
    let maxWidth: CGFloat?
    let maxHeight: CGFloat
    let alignment: HorizontalAlignment
    
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var config = VioConfiguration.shared
    
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
    
    // Sponsor logo URL: prefer sponsorConfig, fallback to dynamicBrandConfig
    private var logoUrl: URL? {
        let urlString = config.sponsorConfig?.logoUrl ?? config.dynamicBrandConfig?.logoUrl
        guard let s = urlString, !s.isEmpty else { return nil }
        return URL(string: s)
    }
    
    // Sponsor label text from backend or param
    private var sponsorLabel: String {
        // Use sponsorBadgeText from brand config if available (localized)
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return config.dynamicBrandConfig?.sponsorBadgeText?[lang]
            ?? config.dynamicBrandConfig?.sponsorBadgeText?["en"]
            ?? text
    }
    
    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        
        VStack(alignment: alignment, spacing: 2) {
            Text(sponsorLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(colors.textSecondary)
            
            if let url = logoUrl {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                } placeholder: {
                    Rectangle()
                        .fill(colors.surfaceSecondary)
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                }
            } else {
                Rectangle()
                    .fill(colors.surfaceSecondary)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            }
        }
    }
}
