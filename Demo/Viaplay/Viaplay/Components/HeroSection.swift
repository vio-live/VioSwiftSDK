//
//  HeroSection.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI
import VioCore

struct HeroSection: View {
    let content: HeroContent
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Image from config
                Image(DemoDataManager.shared.backgroundImage(for: .mainBackground))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: 500)
                    .clipped()
                
                // Dark gradient overlay (fade to background color)
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.clear,
                        Color(hex: "1B1B25").opacity(0.3),
                        Color(hex: "1B1B25").opacity(0.7),
                        Color(hex: "1B1B25")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geometry.size.width, height: 500)
                
                    VStack(spacing: 0) {
                        // Header with Logo and Avatar
                        HStack {
                            Spacer()
                            
                            // Viaplay Icon + Logo from assets
                            HStack(alignment: .center, spacing: 0) {
                                Image(DemoDataManager.shared.brandAsset(for: .icon))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                
                                Image(DemoDataManager.shared.brandAsset(for: .logo))
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundColor(.white)
                                    .frame(height: 24)
                                    .offset(x: -30)
                            }
                            .offset(x: 15) // Compensar el offset del logo para centrar el conjunto
                            
                            Spacer()
                            
                            // Avatar/Profile circle (instead of boombox icon)
                            Circle()
                                .fill(Color.cyan.opacity(0.3))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.cyan)
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 50)
                        
                        Spacer()
                        
                        // Content at bottom
                        VStack(alignment: .center, spacing: 10) {
                            // Title (centered)
                            Text(content.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Description (centered)
                            Text(content.description)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Action Buttons (centered) - Same size for both
                            HStack(spacing: 10) {
                                // Play Button (Pink/Magenta) - Same size as Les mer
                                Button(action: {}) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 140, height: 44)
                                        .background(
                                            Color(red: 0.96, green: 0.08, blue: 0.42) // Magenta/Pink #F51569
                                        )
                                        .cornerRadius(10)
                                }
                                
                                // Les mer Button (Dark Gray) - Same size as Crown
                                Button(action: {}) {
                                    Text("Les mer")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 140, height: 44)
                                        .background(Color(red: 0.23, green: 0.24, blue: 0.27))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.top, 6)
                        }
                        .frame(maxWidth: geometry.size.width)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                    }
            }
            .frame(width: geometry.size.width, height: 500)
        }
        .frame(height: 500)
    }
}

#Preview {
    HeroSection(content: HeroContent.mock)
        .background(Color.black)
}
