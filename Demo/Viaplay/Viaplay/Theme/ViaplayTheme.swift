//
//  ViaplayTheme.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI

struct ViaplayTheme {
    // MARK: - Colors
    struct Colors {
        static let pink = Color(red: 1.0, green: 0.2, blue: 0.6) // #FF3366
        static let purple = Color(red: 0.6, green: 0.2, blue: 1.0) // #9933FF
        static let black = Color.black
        static let darkGray = Color(red: 0.08, green: 0.08, blue: 0.08) // Very dark gray
        static let mediumGray = Color(red: 0.2, green: 0.2, blue: 0.2)
        static let lightGray = Color(red: 0.6, green: 0.6, blue: 0.6)
        static let white = Color.white
        
        // Gradient
        static let brandGradient = LinearGradient(
            colors: [pink, purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    // MARK: - Typography
    struct Typography {
        static func largeTitle() -> Font {
            return .system(size: 32, weight: .bold)
        }
        
        static func title() -> Font {
            return .system(size: 24, weight: .bold)
        }
        
        static func headline() -> Font {
            return .system(size: 18, weight: .semibold)
        }
        
        static func body() -> Font {
            return .system(size: 16, weight: .regular)
        }
        
        static func caption() -> Font {
            return .system(size: 14, weight: .regular)
        }
        
        static func small() -> Font {
            return .system(size: 12, weight: .regular)
        }
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
    }
}
