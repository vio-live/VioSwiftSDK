//
//  CampaignSponsorBadge.swift
//  Viaplay
//
//  Reusable component for displaying campaign sponsor logo
//  Uses VioConfiguration.dynamicBrandConfig.logoUrl (set by DynamicConfigurationManager)
//

import SwiftUI
import VioCore

struct CampaignSponsorBadge: View {
    let text: String
    let maxWidth: CGFloat?
    let maxHeight: CGFloat
    let alignment: HorizontalAlignment
    
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
            
            // Logo from backend: brand.logoUrl only (evita EXC_BAD_ACCESS en campaignManager.currentCampaign?.campaignLogo)
            if let urlString = VioConfiguration.shared.dynamicBrandConfig?.logoUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    case .failure, .empty:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    @unknown default:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    }
                }
            } else {
                Image(systemName: "photo")
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
