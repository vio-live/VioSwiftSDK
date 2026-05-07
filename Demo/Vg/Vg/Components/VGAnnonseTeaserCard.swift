//
//  VGAnnonseTeaserCard.swift
//  Vg
//
//  In-feed advertorial teaser ("Annonsørinnhold"). Rendered on a WHITE
//  card so it visually breaks from the burgundy news feed (mirrors the
//  exact layout vg.no uses for its in-feed advertorials):
//
//      [ANNONSØRINNHOLD .................. <sponsor logo>]
//      [                hero image                       ]
//      [Headline (big serif, black)                      ]
//
//  Tapping it opens the full advertorial sheet (MaxboArticleView).
//

import SwiftUI

struct VGAnnonseTeaserCard: View {
    let imageURL: URL?
    let kicker: String
    let headline: String
    /// Sponsor logo from `VioConfiguration.shared.primarySponsor`. Rendered
    /// in the top-right of the white card next to the ANNONSØRINNHOLD
    /// label. Falls back to a small text label if the URL is nil or the
    /// image fails to decode.
    let brandLogoURL: URL?
    /// Optional fallback text shown if the logo URL is unavailable or the
    /// image fails to load.
    var brandFallback: String = "Annonse"
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 0) {
                // Top header row: "ANNONSØRINNHOLD" label + sponsor logo
                HStack(alignment: .center, spacing: 12) {
                    Text("ANNONSØRINNHOLD")
                        .font(.system(size: 12, weight: .bold))
                        .kerning(0.6)
                        .foregroundColor(.black)

                    Spacer(minLength: 8)

                    sponsorLogoOrText
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // Hero image (full bleed within the white card)
                VGNewsRemoteImage(url: imageURL, aspect: .fill)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .padding(.horizontal, 0)

                // Kicker (gray, small serif) — matches "Tre døde på cruiseskip:" style
                if !kicker.isEmpty {
                    Text(kicker)
                        .font(VGTheme.Typography.newsKicker())
                        .foregroundColor(Color.black.opacity(0.55))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                // Big serif headline on white
                Text(headline)
                    .font(VGTheme.Typography.newsHeroHeadline())
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
        }
        .buttonStyle(.plain)
    }

    /// Sponsor logo image (transparent background, fits within fixed
    /// height) — falls back to a small label if the URL is missing or
    /// the image fails to decode.
    @ViewBuilder
    private var sponsorLogoOrText: some View {
        if let url = brandLogoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 22)
                default:
                    fallbackText
                }
            }
            .frame(maxHeight: 22)
        } else {
            fallbackText
        }
    }

    private var fallbackText: some View {
        Text(brandFallback)
            .font(.system(size: 13, weight: .black))
            .foregroundColor(.black)
    }
}
