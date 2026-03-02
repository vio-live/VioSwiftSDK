//
//  SponsorAvatarView.swift
//  VioDesignSystem
//
//  Avatar circular del sponsor — usa sponsor.avatarUrl del backend.
//  Todos los componentes del SDK usan este view para el icono del sponsor.
//

import SwiftUI
import VioCore

/// Avatar circular del sponsor — fuente: sponsor.avatarUrl (backend)
public struct SponsorAvatarView: View {
    let size: CGFloat
    
    @ObservedObject private var config = VioConfiguration.shared
    
    public init(size: CGFloat = 32) {
        self.size = size
    }
    
    public var body: some View {
        Group {
            if let url = SponsorAssets.avatarUrl {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } placeholder: {
                    sponsorFallback
                }
            } else {
                sponsorFallback
            }
        }
        .frame(width: size, height: size)
    }
    
    private var sponsorFallback: some View {
        Circle()
            .fill(SponsorAssets.primaryColor)
            .overlay(
                Text(String(SponsorAssets.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(SponsorAssets.textOnPrimary)
            )
    }
}
