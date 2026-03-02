//
//  SponsorAssets.swift
//  VioDesignSystem
//
//  Fuente única de verdad para todos los assets y colores del sponsor.
//  Todos los componentes del SDK leen de aquí — nunca hardcodean.
//  Los datos vienen de VioConfiguration.sponsorConfig (backend /v1/campaigns/:id/config → sponsor).
//

import SwiftUI
import VioCore

@MainActor
public struct SponsorAssets {
    
    // MARK: - Assets
    
    /// Logo del sponsor para el badge "Sponset av Elkjøp"
    public static var logoUrl: URL? {
        let s = VioConfiguration.shared.sponsorConfig?.logoUrl
            ?? VioConfiguration.shared.dynamicBrandConfig?.logoUrl
        guard let str = s, !str.isEmpty else { return nil }
        return URL(string: str)
    }
    
    /// Avatar circular del sponsor — aparece en headers de polls, contests, tweets
    public static var avatarUrl: URL? {
        let s = VioConfiguration.shared.sponsorConfig?.avatarUrl
            ?? VioConfiguration.shared.dynamicBrandConfig?.iconUrl
        guard let str = s, !str.isEmpty else { return nil }
        return URL(string: str)
    }
    
    /// Nombre del sponsor (e.g., "Elkjøp")
    public static var name: String {
        VioConfiguration.shared.sponsorConfig?.name
            ?? VioConfiguration.shared.dynamicBrandConfig?.name
            ?? ""
    }
    
    // MARK: - Colors
    
    /// Color primario del sponsor — bordes, fondos de acento, botones CTA
    public static var primaryColor: Color {
        guard let hex = VioConfiguration.shared.sponsorConfig?.primaryColor else {
            return Color.white.opacity(0.15)
        }
        return Color(hex: hex) ?? Color.white.opacity(0.15)
    }
    
    /// Color secundario del sponsor
    public static var secondaryColor: Color {
        guard let hex = VioConfiguration.shared.sponsorConfig?.secondaryColor else {
            return primaryColor
        }
        return Color(hex: hex) ?? primaryColor
    }
    
    /// Color de texto con contraste óptimo sobre primaryColor (WCAG — no hardcodear nunca)
    public static var textOnPrimary: Color {
        guard let hex = VioConfiguration.shared.sponsorConfig?.primaryColor else {
            return .white
        }
        return contrastingText(for: hex)
    }
    
    // MARK: - Localized text
    
    /// Texto del badge localizado ("Sponset av" / "Sponsored by")
    public static var badgeText: String {
        let lang = Locale.current.languageCode ?? "en"
        // sponsor.badgeText tiene prioridad, fallback a brand.sponsorBadgeText
        return VioConfiguration.shared.sponsorConfig?.badgeText?[lang]
            ?? VioConfiguration.shared.sponsorConfig?.badgeText?["en"]
            ?? VioConfiguration.shared.dynamicBrandConfig?.sponsorBadgeText?[lang]
            ?? VioConfiguration.shared.dynamicBrandConfig?.sponsorBadgeText?["en"]
            ?? "Sponsored by"
    }
    
    // MARK: - Private helpers
    
    /// Calcula color de texto con contraste WCAG sobre un color de fondo hex
    /// Luminosidad relativa > 0.179 → texto negro (fondo claro), si no → blanco
    static func contrastingText(for hex: String) -> Color {
        var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return .white }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        
        // sRGB linearization
        func linearize(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let lum = 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
        return lum > 0.179 ? Color.black : Color.white
    }
}
