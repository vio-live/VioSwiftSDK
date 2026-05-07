//
//  VGNewsRemoteImage.swift
//  Vg
//
//  Thin wrapper around AsyncImage for the news layout — keeps a consistent
//  placeholder background and content fill so cards never collapse while
//  the network is slow.
//

import SwiftUI

struct VGNewsRemoteImage: View {
    let url: URL?
    var aspect: ContentMode = .fill
    var cornerRadius: CGFloat = 0

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: aspect)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(VGTheme.Colors.burgundyDeep)
    }
}
