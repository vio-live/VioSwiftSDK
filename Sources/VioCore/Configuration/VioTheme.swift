import SwiftUI

/// Theme appearance mode configuration
public enum ThemeMode: String, CaseIterable {
    case automatic = "automatic"  // Follow system appearance
    case light = "light"         // Force light mode
    case dark = "dark"           // Force dark mode
    
    public var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Vio Theme Configuration
///
/// Defines colors, typography, and visual styling for all Vio UI components.
/// Supports automatic dark/light mode switching or manual override.
public struct VioTheme {
    
    // MARK: - Properties
    public let name: String
    public let mode: ThemeMode
    public let lightColors: ColorScheme
    public let darkColors: ColorScheme
    public let typography: TypographyScheme
    public let spacing: SpacingScheme
    public let borderRadius: BorderRadiusScheme
    
    // MARK: - Computed Properties
    
    /// Returns the appropriate color scheme based on current appearance
    public var colors: ColorScheme {
        switch mode {
        case .automatic:
            // This will be resolved in the views using @Environment(\.colorScheme)
            return lightColors
        case .light:
            return lightColors
        case .dark:
            return darkColors
        }
    }
    
    /// Returns colors for a specific color scheme
    public func colors(for colorScheme: SwiftUI.ColorScheme) -> ColorScheme {
        switch mode {
        case .automatic:
            return colorScheme == .dark ? darkColors : lightColors
        case .light:
            return lightColors
        case .dark:
            return darkColors
        }
    }
    
    // MARK: - Initializers
    
    /// Full initializer with separate light and dark color schemes
    public init(
        name: String,
        mode: ThemeMode = .automatic,
        lightColors: ColorScheme,
        darkColors: ColorScheme,
        typography: TypographyScheme = .default,
        spacing: SpacingScheme = .default,
        borderRadius: BorderRadiusScheme = .default
    ) {
        self.name = name
        self.mode = mode
        self.lightColors = lightColors
        self.darkColors = darkColors
        self.typography = typography
        self.spacing = spacing
        self.borderRadius = borderRadius
    }
    
    /// Convenience initializer with single color scheme (used for both light and dark)
    public init(
        name: String,
        mode: ThemeMode = .automatic,
        colors: ColorScheme,
        typography: TypographyScheme = .default,
        spacing: SpacingScheme = .default,
        borderRadius: BorderRadiusScheme = .default
    ) {
        self.init(
            name: name,
            mode: mode,
            lightColors: colors,
            darkColors: .autoDark(from: colors),
            typography: typography,
            spacing: spacing,
            borderRadius: borderRadius
        )
    }
    
    // MARK: - Predefined Themes
    
    /// Default Vio theme with automatic dark/light support
    public static let `default` = VioTheme(
        name: "Vio Default",
        mode: .automatic,
        lightColors: .reachu,
        darkColors: .reachuDark
    )
    
    /// Light theme (forced light mode)
    public static let light = VioTheme(
        name: "Light",
        mode: .light,
        lightColors: .light,
        darkColors: .light
    )
    
    /// Dark theme (forced dark mode)
    public static let dark = VioTheme(
        name: "Dark",
        mode: .dark,
        lightColors: .dark,
        darkColors: .dark
    )
    
    /// Minimal theme with automatic dark/light support
    public static let minimal = VioTheme(
        name: "Minimal",
        mode: .automatic,
        lightColors: .minimal,
        darkColors: .minimalDark
    )
    
    /// Adaptive theme that automatically creates dark variants
    public static func adaptive(
        name: String,
        lightColors: ColorScheme,
        mode: ThemeMode = .automatic
    ) -> VioTheme {
        return VioTheme(
            name: name,
            mode: mode,
            lightColors: lightColors,
            darkColors: .autoDark(from: lightColors)
        )
    }
    
    // Smart defaults are handled by using existing .reachu and .reachuDark schemes
}

// MARK: - Color Scheme

public struct ColorScheme {
    // Brand Colors
    public let primary: Color
    public let secondary: Color
    
    // Semantic Colors
    public let success: Color
    public let warning: Color
    public let error: Color
    public let info: Color
    
    // Background Colors
    public let background: Color
    public let surface: Color
    public let surfaceSecondary: Color
    
    // Text Colors
    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let textOnPrimary: Color  // Text color when displayed on primary color background
    
    // Border Colors
    public let border: Color
    public let borderSecondary: Color
    
    // Product Price Color (customizable)
    public let priceColor: Color
    
    public init(
        primary: Color,
        secondary: Color,
        success: Color = Color(.sRGB, red: 0.204, green: 0.780, blue: 0.349, opacity: 1.0), // #34C759
        warning: Color = Color(.sRGB, red: 1.0, green: 0.584, blue: 0.0, opacity: 1.0), // #FF9500
        error: Color = Color(.sRGB, red: 1.0, green: 0.231, blue: 0.188, opacity: 1.0), // #FF3B30
        info: Color = Color(.sRGB, red: 0.0, green: 0.478, blue: 1.0, opacity: 1.0), // #007AFF
        background: Color = Color(.sRGB, red: 0.949, green: 0.949, blue: 0.969, opacity: 1.0), // #F2F2F7
        surface: Color = .white,
        surfaceSecondary: Color = Color(.sRGB, red: 0.976, green: 0.976, blue: 0.976, opacity: 1.0), // #F9F9F9
        textPrimary: Color = .black,
        textSecondary: Color = Color(.sRGB, red: 0.557, green: 0.557, blue: 0.576, opacity: 1.0), // #8E8E93
        textTertiary: Color = Color(.sRGB, red: 0.780, green: 0.780, blue: 0.800, opacity: 1.0), // #C7C7CC
        textOnPrimary: Color = .white,  // Default to white on primary color
        border: Color = Color(.sRGB, red: 0.898, green: 0.898, blue: 0.918, opacity: 1.0), // #E5E5EA
        borderSecondary: Color = Color(.sRGB, red: 0.820, green: 0.820, blue: 0.839, opacity: 1.0), // #D1D1D6
        priceColor: Color? = nil  // If nil, defaults to primary
    ) {
        self.primary = primary
        self.secondary = secondary
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
        self.background = background
        self.surface = surface
        self.surfaceSecondary = surfaceSecondary
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.textOnPrimary = textOnPrimary
        self.border = border
        self.borderSecondary = borderSecondary
        self.priceColor = priceColor ?? primary  // Default to primary if not specified
    }
}

// MARK: - Predefined Color Schemes

extension ColorScheme {
    // MARK: - Light Color Schemes
    
    /// Default Vio brand colors (light)
    public static let reachu = ColorScheme(
        primary: Color(.sRGB, red: 0.0, green: 0.478, blue: 1.0, opacity: 1.0), // #007AFF
        secondary: Color(.sRGB, red: 0.345, green: 0.337, blue: 0.839, opacity: 1.0) // #5856D6
    )
    
    /// Light color scheme
    public static let light = ColorScheme(
        primary: Color(.sRGB, red: 0.0, green: 0.4, blue: 0.8, opacity: 1.0), // #0066CC
        secondary: Color(.sRGB, red: 0.345, green: 0.337, blue: 0.839, opacity: 1.0) // #5856D6
    )
    
    /// Minimal color scheme (light)
    public static let minimal = ColorScheme(
        primary: Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 1.0), // #333333
        secondary: Color(.sRGB, red: 0.4, green: 0.4, blue: 0.4, opacity: 1.0) // #666666
    )
    
    // MARK: - Dark Color Schemes
    
    /// Default Vio brand colors (dark)
    public static let reachuDark = ColorScheme(
        primary: Color(.sRGB, red: 0.039, green: 0.518, blue: 1.0, opacity: 1.0), // #0A84FF
        secondary: Color(.sRGB, red: 0.369, green: 0.361, blue: 0.902, opacity: 1.0), // #5E5CE6
        success: Color(.sRGB, red: 0.196, green: 0.843, blue: 0.294, opacity: 1.0), // #32D74B
        warning: Color(.sRGB, red: 1.0, green: 0.624, blue: 0.039, opacity: 1.0), // #FF9F0A
        error: Color(.sRGB, red: 1.0, green: 0.271, blue: 0.227, opacity: 1.0), // #FF453A
        info: Color(.sRGB, red: 0.039, green: 0.518, blue: 1.0, opacity: 1.0), // #0A84FF
        background: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0), // #000000
        surface: Color(.sRGB, red: 0.110, green: 0.110, blue: 0.118, opacity: 1.0), // #1C1C1E
        surfaceSecondary: Color(.sRGB, red: 0.173, green: 0.173, blue: 0.180, opacity: 1.0), // #2C2C2E
        textPrimary: Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0), // #FFFFFF
        textSecondary: Color(.sRGB, red: 0.557, green: 0.557, blue: 0.576, opacity: 1.0), // #8E8E93
        textTertiary: Color(.sRGB, red: 0.282, green: 0.282, blue: 0.290, opacity: 1.0), // #48484A
        border: Color(.sRGB, red: 0.220, green: 0.220, blue: 0.227, opacity: 1.0), // #38383A
        borderSecondary: Color(.sRGB, red: 0.282, green: 0.282, blue: 0.290, opacity: 1.0) // #48484A
    )
    
    /// Standard dark color scheme
    public static let dark = ColorScheme(
        primary: Color(.sRGB, red: 0.039, green: 0.518, blue: 1.0, opacity: 1.0), // #0A84FF
        secondary: Color(.sRGB, red: 0.369, green: 0.361, blue: 0.902, opacity: 1.0), // #5E5CE6
        background: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0), // #000000
        surface: Color(.sRGB, red: 0.110, green: 0.110, blue: 0.118, opacity: 1.0), // #1C1C1E
        surfaceSecondary: Color(.sRGB, red: 0.173, green: 0.173, blue: 0.180, opacity: 1.0), // #2C2C2E
        textPrimary: Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0), // #FFFFFF
        textSecondary: Color(.sRGB, red: 0.557, green: 0.557, blue: 0.576, opacity: 1.0), // #8E8E93
        textTertiary: Color(.sRGB, red: 0.282, green: 0.282, blue: 0.290, opacity: 1.0), // #48484A
        border: Color(.sRGB, red: 0.220, green: 0.220, blue: 0.227, opacity: 1.0), // #38383A
        borderSecondary: Color(.sRGB, red: 0.282, green: 0.282, blue: 0.290, opacity: 1.0) // #48484A
    )
    
    /// Minimal color scheme (dark)
    public static let minimalDark = ColorScheme(
        primary: Color(.sRGB, red: 0.8, green: 0.8, blue: 0.8, opacity: 1.0), // #CCCCCC
        secondary: Color(.sRGB, red: 0.6, green: 0.6, blue: 0.6, opacity: 1.0), // #999999
        background: Color(.sRGB, red: 0.067, green: 0.067, blue: 0.067, opacity: 1.0), // #111111
        surface: Color(.sRGB, red: 0.133, green: 0.133, blue: 0.133, opacity: 1.0), // #222222
        surfaceSecondary: Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 1.0), // #333333
        textPrimary: Color(.sRGB, red: 0.933, green: 0.933, blue: 0.933, opacity: 1.0), // #EEEEEE
        textSecondary: Color(.sRGB, red: 0.667, green: 0.667, blue: 0.667, opacity: 1.0), // #AAAAAA
        textTertiary: Color(.sRGB, red: 0.467, green: 0.467, blue: 0.467, opacity: 1.0), // #777777
        border: Color(.sRGB, red: 0.267, green: 0.267, blue: 0.267, opacity: 1.0), // #444444
        borderSecondary: Color(.sRGB, red: 0.333, green: 0.333, blue: 0.333, opacity: 1.0) // #555555
    )
    
    // MARK: - Auto Dark Conversion
    
    /// Automatically creates a dark color scheme from a light one
    public static func autoDark(from lightScheme: ColorScheme) -> ColorScheme {
        return ColorScheme(
            primary: adjustForDarkMode(lightScheme.primary),
            secondary: adjustForDarkMode(lightScheme.secondary),
            success: Color(.sRGB, red: 0.196, green: 0.843, blue: 0.294, opacity: 1.0), // #32D74B
            warning: Color(.sRGB, red: 1.0, green: 0.624, blue: 0.039, opacity: 1.0), // #FF9F0A
            error: Color(.sRGB, red: 1.0, green: 0.271, blue: 0.227, opacity: 1.0), // #FF453A
            info: adjustForDarkMode(lightScheme.info),
            background: Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0), // #000000
            surface: Color(.sRGB, red: 0.110, green: 0.110, blue: 0.118, opacity: 1.0), // #1C1C1E
            surfaceSecondary: Color(.sRGB, red: 0.173, green: 0.173, blue: 0.180, opacity: 1.0), // #2C2C2E
            textPrimary: Color(.sRGB, red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0), // #FFFFFF
            textSecondary: Color(.sRGB, red: 0.557, green: 0.557, blue: 0.576, opacity: 1.0), // #8E8E93
            textTertiary: Color(.sRGB, red: 0.282, green: 0.282, blue: 0.290, opacity: 1.0), // #48484A
            border: Color(.sRGB, red: 0.220, green: 0.220, blue: 0.227, opacity: 1.0), // #38383A
            borderSecondary: Color(.sRGB, red: 0.282, green: 0.282, blue: 0.290, opacity: 1.0), // #48484A
            priceColor: lightScheme.priceColor != lightScheme.primary ? adjustForDarkMode(lightScheme.priceColor) : nil  // Preserve custom priceColor if different from primary
        )
    }
    
    /// Adjusts a color to be suitable for dark mode
    private static func adjustForDarkMode(_ color: Color) -> Color {
        // This is a simplified conversion - in a real implementation,
        // you might want to use more sophisticated color science
        let components = color.cgColor?.components ?? [0, 0, 0, 1]
        let red = components[0]
        let green = components[1] 
        let blue = components[2]
        let alpha = components.count > 3 ? components[3] : 1.0
        
        // Increase brightness for dark mode while maintaining hue
        let brightnessBoost: CGFloat = 0.3
        return Color(.sRGB, 
                    red: min(1.0, red + brightnessBoost),
                    green: min(1.0, green + brightnessBoost),
                    blue: min(1.0, blue + brightnessBoost),
                    opacity: alpha)
    }
}

// MARK: - Typography Scheme

public struct TypographyScheme {
    public let largeTitle: Font
    public let title1: Font
    public let title2: Font
    public let title3: Font
    public let headline: Font
    public let subheadline: Font
    public let body: Font
    public let bodyBold: Font
    public let callout: Font
    public let footnote: Font
    public let caption1: Font
    public let caption2: Font
    
    public init(
        largeTitle: Font = Font.largeTitle.weight(.bold),
        title1: Font = Font.title.weight(.semibold),
        title2: Font = Font.title2.weight(.semibold),
        title3: Font = Font.title3.weight(.medium),
        headline: Font = Font.headline.weight(.semibold),
        subheadline: Font = Font.subheadline.weight(.medium),
        body: Font = Font.body,
        bodyBold: Font = Font.body.weight(.semibold),
        callout: Font = Font.callout,
        footnote: Font = Font.footnote,
        caption1: Font = Font.caption,
        caption2: Font = Font.caption2
    ) {
        self.largeTitle = largeTitle
        self.title1 = title1
        self.title2 = title2
        self.title3 = title3
        self.headline = headline
        self.subheadline = subheadline
        self.body = body
        self.bodyBold = bodyBold
        self.callout = callout
        self.footnote = footnote
        self.caption1 = caption1
        self.caption2 = caption2
    }
    
    public static let `default` = TypographyScheme()
}

// MARK: - Spacing Scheme

public struct SpacingScheme {
    public let xs: CGFloat
    public let sm: CGFloat
    public let md: CGFloat
    public let lg: CGFloat
    public let xl: CGFloat
    public let xxl: CGFloat
    
    public init(
        xs: CGFloat = 4,
        sm: CGFloat = 8,
        md: CGFloat = 16,
        lg: CGFloat = 24,
        xl: CGFloat = 32,
        xxl: CGFloat = 48
    ) {
        self.xs = xs
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
        self.xxl = xxl
    }
    
    public static let `default` = SpacingScheme()
}

// MARK: - Border Radius Scheme

public struct BorderRadiusScheme {
    public let none: CGFloat
    public let small: CGFloat
    public let medium: CGFloat
    public let large: CGFloat
    public let xl: CGFloat
    public let circle: CGFloat
    
    public init(
        none: CGFloat = 0,
        small: CGFloat = 4,
        medium: CGFloat = 8,
        large: CGFloat = 12,
        xl: CGFloat = 16,
        circle: CGFloat = 999
    ) {
        self.none = none
        self.small = small
        self.medium = medium
        self.large = large
        self.xl = xl
        self.circle = circle
    }
    
    public static let `default` = BorderRadiusScheme()
}

// MARK: - Color Extension
// Color.init(hex:) is already defined in VioDesignSystem
