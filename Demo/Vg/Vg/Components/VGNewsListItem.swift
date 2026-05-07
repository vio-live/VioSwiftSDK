//
//  VGNewsListItem.swift
//  Vg
//
//  Compact row used inside SISTE NYTT: timestamp on top, headline below,
//  optional small thumbnail on the right. No image is fine — VG renders
//  these as text-only when no media is available.
//

import SwiftUI

struct VGNewsListItem: View {
    let article: VGNewsArticle
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.relativeTime)
                        .font(VGTheme.Typography.newsTimestamp())
                        .foregroundColor(VGTheme.Colors.kickerMuted)

                    Text(article.rawTitle)
                        .font(VGTheme.Typography.newsListHeadline())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let url = article.imageURL {
                    VGNewsRemoteImage(
                        url: url,
                        aspect: .fill,
                        cornerRadius: 4
                    )
                    .frame(width: 88, height: 64)
                    .clipped()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(VGTheme.Colors.burgundy)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}
