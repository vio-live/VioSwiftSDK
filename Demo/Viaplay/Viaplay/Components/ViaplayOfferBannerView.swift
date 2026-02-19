//
//  ViaplayOfferBannerView.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI
import VioCore

/// Offer Banner View - Static version
/// Banner promocional con imagen de fondo para ofertas especiales
struct ViaplayOfferBannerView: View {
    let title: String
    let subtitle: String?
    
    @StateObject private var campaignManager = CampaignManager.shared
    
    init(
        title: String = "Ukens tilbud",
        subtitle: String? = "Se denne ukes beste tilbud"
    ) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        ZStack {
            // Background layer
            backgroundLayer
            
            // Content in two columns
            HStack(alignment: .center, spacing: 16) {
                // Left column: Logo, title, subtitle, countdown
                VStack(alignment: .leading, spacing: 4) {
                    // Campaign logo from CampaignManager
                    if let logoUrl = campaignManager.currentCampaign?.campaignLogo, let url = URL(string: logoUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 16)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 16)
                            case .failure:
                                Image(DemoDataManager.shared.defaultLogo)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 16)
                            @unknown default:
                                Image(DemoDataManager.shared.defaultLogo)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 16)
                            }
                        }
                    } else {
                        // Fallback to hardcoded logo if no campaign logo
                        Image(DemoDataManager.shared.defaultLogo)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 16)
                    }
                    
                    // Title
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Subtitle
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    // Countdown static (values hardcoded)
                    staticCountdown
                }
                
                Spacer()
                
                // Right column: Discount badge + Button (centered vertically)
                VStack(spacing: 8) {
                    // Discount badge
                    Text("Opp til 30%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(hex: "1B1B25"))
                        )
                    
                    // Button
                    HStack(spacing: 6) {
                        Text("Se alle tilbud")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ViaplayTheme.Colors.pink)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 160)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Background
    
    private var backgroundLayer: some View {
        ZStack(alignment: .leading) {
            // Background with image and overlays
            ZStack {
                // Background image (football field)
                Image(DemoDataManager.shared.backgroundImage(for: .footballField))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                
                // Dark overlay para legibilidad
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .clipped()
        }
    }
    
    // MARK: - Static Countdown
    
    private var staticCountdown: some View {
        HStack(spacing: 4) {
            // Días
            CountdownUnit(value: 2, label: "dager")
            
            // Horas
            CountdownUnit(value: 1, label: "time")
            
            // Minutos
            CountdownUnit(value: 59, label: "min")
            
            // Segundos
            CountdownUnit(value: 47, label: "sek")
        }
        .padding(.vertical, 3)
    }
}

/// Countdown Unit Component (estilo analógico)
struct CountdownUnit: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 1) {
            // Dígitos
            Text(String(format: "%02d", value))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 24)
                .padding(.vertical, 2)
                .padding(.horizontal, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            
            // Label
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "1B1B25")
            .ignoresSafeArea()
        
        ViaplayOfferBannerView()
            .padding(.horizontal, 16)
    }
    .preferredColorScheme(.dark)
}

