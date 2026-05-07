//
//  VGNewsSectionHeader.swift
//  Vg
//
//  Big serif/wordmark-style label used to separate sections in the feed.
//  Reproduces the "SISTE NYTT" header from VG with optional uppercase weight.
//

import SwiftUI

struct VGNewsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(VGTheme.Typography.newsSectionLabel())
            .foregroundColor(VGTheme.Colors.kickerMuted)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
