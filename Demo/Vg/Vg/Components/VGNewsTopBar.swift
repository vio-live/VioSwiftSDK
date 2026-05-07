//
//  VGNewsTopBar.swift
//  Vg
//
//  Top bar of the VG news feed: red VG wordmark on the left, two pill
//  buttons on the right ("Les VG+", "AS"). Stays pinned above the feed.
//

import SwiftUI

struct VGNewsTopBar: View {
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Brand wordmark from Assets.xcassets/vg-logo.imageset (SVG,
            // preserves-vector-representation = true). Falls back to a
            // styled text "VG" if the asset is unavailable.
            Image("vg-logo")
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(height: 28)
                .accessibilityLabel("VG")

            Spacer()

            HStack(spacing: 8) {
                pill(text: "Les VG+", filled: true)
                pill(text: "AS", filled: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VGTheme.Colors.pageBackground)
    }

    private func pill(text: String, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(VGTheme.Colors.brandRed)
            )
    }
}

#Preview {
    VGNewsTopBar()
        .background(VGTheme.Colors.pageBackground)
}
