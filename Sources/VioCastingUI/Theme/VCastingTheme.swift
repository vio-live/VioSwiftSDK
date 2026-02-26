//
//  VCastingTheme.swift
//  VioCastingUI
//

import SwiftUI

/// Theme for casting UI - colors, spacing, typography
/// Can be extended to read from VioConfiguration.theme
public struct VCastingTheme {
    public struct Colors {
        public static let pink = Color(red: 1.0, green: 0.2, blue: 0.6)
        public static let purple = Color(red: 0.6, green: 0.2, blue: 1.0)
        public static let black = Color.black
        public static let darkGray = Color(red: 0.08, green: 0.08, blue: 0.08)
        public static let mediumGray = Color(red: 0.2, green: 0.2, blue: 0.2)
        public static let lightGray = Color(red: 0.6, green: 0.6, blue: 0.6)
        public static let white = Color.white

        public static let brandGradient = LinearGradient(
            colors: [pink, purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public struct Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    public struct Typography {
        public static func largeTitle() -> Font { .system(size: 32, weight: .bold) }
        public static func title() -> Font { .system(size: 24, weight: .bold) }
        public static func headline() -> Font { .system(size: 18, weight: .semibold) }
        public static func body() -> Font { .system(size: 16, weight: .regular) }
        public static func caption() -> Font { .system(size: 14, weight: .regular) }
        public static func small() -> Font { .system(size: 12, weight: .regular) }
    }

    public struct CornerRadius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let extraLarge: CGFloat = 20
    }
}
