//
//  VGNewsHeroSplitCard.swift
//  Vg
//
//  Split hero used at the very top of the feed: smaller image on the left,
//  kicker + medium serif headline on the right. Maps to the
//  "Tre døde på cruiseskip: – Nå: Kan ha funnet smittekilden" card.
//

import SwiftUI

struct VGNewsHeroSplitCard: View {
    let article: VGNewsArticle
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(alignment: .top, spacing: 0) {
                VGNewsRemoteImage(
                    url: article.imageURL,
                    aspect: .fill
                )
                .frame(width: 150, height: 200)
                .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    if let kicker = article.kicker {
                        Text(kicker)
                            .font(VGTheme.Typography.newsKicker())
                            .foregroundColor(VGTheme.Colors.kickerMuted)
                    }

                    Text(article.headline)
                        .font(VGTheme.Typography.newsSplitHeadline())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(VGTheme.Colors.burgundy)
        }
        .buttonStyle(.plain)
    }
}
