import SwiftUI
import VioCore

/// Vio Design System Shadow Tokens
/// Provides standardized shadow styles that adapt to theme configuration
public struct VioShadow {
    
    /// Get shadow color based on theme configuration
    private static func shadowColor(for colorScheme: SwiftUI.ColorScheme) -> Color {
        let config = VioConfiguration.shared.uiConfiguration.shadowConfig
        switch config.cardShadowColor {
        case .black:
            return .black
        case .gray:
            return .gray
        case .adaptive:
            // Use adaptive color based on color scheme
            return colorScheme == .dark ? .white.opacity(0.1) : .black
        case .custom:
            return .black // Fallback
        }
    }
    
    /// Card shadow - Standard shadow for cards and surfaces
    public static func card(for colorScheme: SwiftUI.ColorScheme) -> (color: Color, radius: CGFloat, offset: CGSize) {
        let config = VioConfiguration.shared.uiConfiguration.shadowConfig
        return (
            color: shadowColor(for: colorScheme).opacity(config.cardShadowOpacity),
            radius: config.cardShadowRadius,
            offset: config.cardShadowOffset
        )
    }
    
    /// Button shadow - Subtle shadow for buttons
    public static func button(for colorScheme: SwiftUI.ColorScheme) -> (color: Color, radius: CGFloat, offset: CGSize)? {
        let config = VioConfiguration.shared.uiConfiguration.shadowConfig
        guard config.buttonShadowEnabled else { return nil }
        return (
            color: shadowColor(for: colorScheme).opacity(config.buttonShadowOpacity),
            radius: config.buttonShadowRadius,
            offset: CGSize(width: 0, height: 1)
        )
    }
    
    /// Modal shadow - Strong shadow for modals and overlays
    public static func modal(for colorScheme: SwiftUI.ColorScheme) -> (color: Color, radius: CGFloat, offset: CGSize) {
        let config = VioConfiguration.shared.uiConfiguration.shadowConfig
        return (
            color: shadowColor(for: colorScheme).opacity(config.modalShadowOpacity),
            radius: config.modalShadowRadius,
            offset: CGSize(width: 0, height: 4)
        )
    }
    
    /// Text shadow - Subtle shadow for text readability
    public static func text(for colorScheme: SwiftUI.ColorScheme) -> (color: Color, radius: CGFloat, offset: CGSize) {
        return (
            color: shadowColor(for: colorScheme).opacity(0.5),
            radius: 2,
            offset: CGSize(width: 0, height: 1)
        )
    }
}

/// View extension for easy shadow application
extension View {
    /// Apply card shadow from design system
    public func vioCardShadow(for colorScheme: SwiftUI.ColorScheme) -> some View {
        let shadow = VioShadow.card(for: colorScheme)
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.offset.width, y: shadow.offset.height)
    }
    
    /// Apply button shadow from design system
    public func vioButtonShadow(for colorScheme: SwiftUI.ColorScheme) -> some View {
        if let shadow = VioShadow.button(for: colorScheme) {
            return AnyView(self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.offset.width, y: shadow.offset.height))
        } else {
            return AnyView(self)
        }
    }
    
    /// Apply modal shadow from design system
    public func vioModalShadow(for colorScheme: SwiftUI.ColorScheme) -> some View {
        let shadow = VioShadow.modal(for: colorScheme)
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.offset.width, y: shadow.offset.height)
    }
    
    /// Apply text shadow from design system
    public func vioTextShadow(for colorScheme: SwiftUI.ColorScheme) -> some View {
        let shadow = VioShadow.text(for: colorScheme)
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.offset.width, y: shadow.offset.height)
    }
}

