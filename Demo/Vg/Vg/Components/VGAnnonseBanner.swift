//
//  VGAnnonseBanner.swift
//  Vg
//
//  Placeholder for an in-feed advertorial slot ("annonse"). For the demo
//  we render the brand badge ("FINN — LEDIGE STILLINGER") + a hero image,
//  matching what vg.no shows. Image source: caller picks (asset or URL).
//

import SwiftUI

struct VGAnnonseBanner: View {
    /// Logo text shown in the white header strip. e.g. "LEDIGE STILLINGER".
    let label: String
    /// Optional asset name from Assets.xcassets to render as the body image.
    /// Falls back to a flat dark plate if nil.
    var assetName: String?
    /// Caption rendered under the image, mimicking the job-ad teaser.
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // "annonse" hint label above the card
            Text("annonse")
                .font(VGTheme.Typography.newsAnnonseLabel())
                .foregroundColor(VGTheme.Colors.annonseLabel)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                // Label header (white strip with FINN-style brand)
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Text("FINN")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.black)

                    Text(label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)

                // Body image
                Group {
                    if let assetName = assetName {
                        Image(assetName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(VGTheme.Colors.burgundyDeep)
                    }
                }
                .frame(height: 220)
                .clipped()

                if let caption = caption {
                    Text(caption)
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 16)
    }
}
