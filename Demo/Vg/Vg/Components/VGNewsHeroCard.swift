//
//  VGNewsHeroCard.swift
//  Vg
//
//  Full-width hero card: image on top, kicker + giant serif headline below.
//  Used for the second hero slot ("- USA har tabbet seg ut" in the screenshot).
//

import SwiftUI

struct VGNewsHeroCard: View {
    let article: VGNewsArticle
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 8) {
                VGNewsRemoteImage(
                    url: article.imageURL,
                    aspect: .fill
                )
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .clipped()

                if let kicker = article.kicker {
                    Text(kicker)
                        .font(VGTheme.Typography.newsKicker())
                        .foregroundColor(VGTheme.Colors.kickerMuted)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                Text(article.headline)
                    .font(VGTheme.Typography.newsHeroHeadline())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VGTheme.Colors.burgundy)
        }
        .buttonStyle(.plain)
    }
}
