//
//  CampaignSponsorBadge.swift
//  Viaplay
//
//  Reusable component for displaying campaign sponsor logo
//  Uses CampaignManager to get the logo dynamically
//

import SwiftUI
import VioCore

struct CampaignSponsorBadge: View {
    let text: String
    let maxWidth: CGFloat?
    let maxHeight: CGFloat
    let alignment: HorizontalAlignment
    
    @StateObject private var campaignManager = CampaignManager.shared
    
    init(
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
    
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            // Campaign logo from CampaignManager with caching
            if let logoUrl = campaignManager.currentCampaign?.campaignLogo, let url = URL(string: logoUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                } placeholder: {
                    // Only show placeholder if not cached (will be instant if cached)
                    Image(DemoDataManager.shared.defaultLogo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                }
            } else {
                // Fallback to hardcoded logo if no campaign logo
                Image(DemoDataManager.shared.defaultLogo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CampaignSponsorBadge()
        CampaignSponsorBadge(maxWidth: 50, maxHeight: 16, alignment: .trailing)
        CampaignSponsorBadge(text: "Presented by", maxWidth: 80, maxHeight: 24)
    }
    .padding()
    .background(Color.black)
}
