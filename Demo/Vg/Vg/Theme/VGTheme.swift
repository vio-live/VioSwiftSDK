//
//  VGTheme.swift
//  Vg
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI

struct VGTheme {
    // MARK: - Colors
    struct Colors {
        static let black = Color.black
        static let red = Color(red: 1.0, green: 0.0, blue: 0.0) // Pure Red
        static let darkGray = Color(red: 0.1, green: 0.1, blue: 0.1) // #1A1A1A
        static let mediumGray = Color(red: 0.2, green: 0.2, blue: 0.2) // #2A2A2A
        static let lightGray = Color(red: 0.4, green: 0.4, blue: 0.4) // #4A4A4A
        static let white = Color.white
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.7)
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
    }
}
