//
//  VGTipsOssBanner.swift
//  Vg
//
//  "TIPS OSS" CTA strip used between sections — invites readers to send
//  in their own video/photo. Visual only here (no action wired); good
//  enough for the demo.
//

import SwiftUI

struct VGTipsOssBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("TIPS OSS")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.white)
                .kerning(0.5)

            Text("Har du video eller bilder?")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(VGTheme.Colors.brandRed)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VGTheme.Colors.brandRed.opacity(0.6), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VGTheme.Colors.burgundyDeep)
                )
        )
        .padding(.horizontal, 16)
    }
}
