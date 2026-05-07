//
//  VGNewsGridCard.swift
//  Vg
//
//  Smaller card used inside a 2x2 grid: image on top (full bleed inside the
//  card), kicker + headline stacked below. Maps to the "Hytte i full fyr",
//  "Splittes: – Spesielt", etc. cards.
//

import SwiftUI

struct VGNewsGridCard: View {
    let article: VGNewsArticle
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 6) {
                VGNewsRemoteImage(
                    url: article.imageURL,
                    aspect: .fill
                )
                .frame(height: 160)
                .clipped()

                if let kicker = article.kicker {
                    Text(kicker)
                        .font(VGTheme.Typography.newsKicker())
                        .foregroundColor(VGTheme.Colors.kickerMuted)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                        .lineLimit(1)
                }

                Text(article.headline)
                    .font(VGTheme.Typography.newsGridHeadline())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)

                // Push residual breathing room to the bottom so two cards
                // sharing a row read as a coherent block even when one
                // headline is 1 line and the other is 3.
                Spacer(minLength: 0)
            }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(VGTheme.Colors.burgundy)
        }
        .buttonStyle(.plain)
    }
}
