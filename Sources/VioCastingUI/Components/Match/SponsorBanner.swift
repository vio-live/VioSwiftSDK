//
//  SponsorBanner.swift
//  Viaplay
//
//  Molecular component: Sponsor banner
//

import SwiftUI
import VioCore

struct SponsorBanner: View {
    let logoName: String
    let text: String
    
    @ObservedObject private var config = VioConfiguration.shared
    
    init(logoName: String? = nil, text: String = "Sponset av") {
        self.logoName = logoName ?? DemoDataManager.shared.defaultLogo
        self.text = text
    }
    
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            // Logo: sponsorConfig (sponsor section) o dynamicBrandConfig (brand section)
            let urlString = config.sponsorConfig?.logoUrl ?? config.dynamicBrandConfig?.logoUrl
            if let s = urlString, !s.isEmpty, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 20)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 20)
                    case .failure:
                        Image(logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 20)
                    @unknown default:
                        Image(logoName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 20)
                    }
                }
            } else {
                // Fallback to config logo if no campaign logo
                Image(logoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 20)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "1F1E26"))
    }
}

#Preview {
    VStack(spacing: 0) {
        SponsorBanner()
        SponsorBanner(logoName: DemoDataManager.shared.defaultLogo, text: "Presented by")
    }
}


