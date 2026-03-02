//
//  CampaignSponsorBadge.swift
//  VioDesignSystem
//
//  Displays campaign sponsor badge.
//  Source of truth: VioConfiguration.sponsorConfig (section "sponsor" in /v1/campaigns/:id/config)
//  - sponsorConfig.logoUrl    → logo shown in badge ("Sponset av Elkjøp")
//  - sponsorConfig.avatarUrl  → icon inside polls/contests (NOT used here)
//  - sponsorConfig.primaryColor → badge background color
//

import SwiftUI
import VioCore

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
    
    private var logoUrl: URL? {
        let sponsorLogo = config.sponsorConfig?.logoUrl
        let brandLogo = config.dynamicBrandConfig?.logoUrl
        let s = sponsorLogo ?? brandLogo
        if let s = s, !s.isEmpty, let url = URL(string: s) {
            return url
        }
        VioLogger.debug("CampaignSponsorBadge: no logo — sponsorConfig.logoUrl=\(sponsorLogo ?? "nil"), dynamicBrandConfig.logoUrl=\(brandLogo ?? "nil")", component: "CampaignSponsorBadge")
        return nil
    }
    
    private var badgeBackground: Color {
        if let hex = config.sponsorConfig?.primaryColor {
            return Color(hex: hex) ?? Color.clear
        }
        return Color.clear
    }
    
    private var sponsorLabel: String {
        let lang = Locale.current.languageCode ?? "en"
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
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(badgeBackground.opacity(badgeBackground == .clear ? 0 : 0.15))
                .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(colors.surfaceSecondary)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            }
        }
    }
}
