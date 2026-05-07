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

        // VG news layout palette (matches vg.no app screenshots).
        /// Outer page background + top bar — the darkest tone of the
        /// palette. Sits between cards so card boundaries visually pop.
        static let pageBackground = Color(red: 0.11, green: 0.0, blue: 0.0) // #1C0000
        /// Card / box surface — slightly lighter wine. Used as `.background`
        /// on every news card so the card edges are visible against
        /// `pageBackground`.
        static let burgundy = Color(red: 0.196, green: 0.0, blue: 0.0) // #320000
        /// Deepest tone — used inside cards for accent surfaces (e.g. the
        /// "Vis flere" pill, the TIPS OSS banner stroke fill).
        static let burgundyDeep = Color(red: 0.07, green: 0.0, blue: 0.0) // #120000
        /// Pure VG brand red used in pills, breaking-news kickers and CTAs.
        static let brandRed = Color(red: 0.90, green: 0.10, blue: 0.13) // #E61A22
        /// Muted/dimmed kicker text on burgundy background.
        static let kickerMuted = Color(red: 0.60, green: 0.50, blue: 0.50) // ~#998080
        /// Annonse / advertorial label tint.
        static let annonseLabel = Color(red: 0.75, green: 0.70, blue: 0.70)
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

        // News layout typography — VG uses a heavy serif for headlines.
        // We approximate with `Georgia-Bold` (system font, no asset needed).
        static func newsHeroHeadline() -> Font {
            .custom("Georgia-Bold", size: 44, relativeTo: .largeTitle)
        }

        static func newsSplitHeadline() -> Font {
            .custom("Georgia-Bold", size: 26, relativeTo: .title2)
        }

        static func newsGridHeadline() -> Font {
            .custom("Georgia-Bold", size: 24, relativeTo: .title3)
        }

        static func newsListHeadline() -> Font {
            .system(size: 17, weight: .bold)
        }

        static func newsKicker() -> Font {
            .custom("Georgia", size: 16, relativeTo: .callout)
        }

        static func newsSectionLabel() -> Font {
            .system(size: 28, weight: .black)
        }

        static func newsAnnonseLabel() -> Font {
            .system(size: 12, weight: .regular)
        }

        static func newsTimestamp() -> Font {
            .system(size: 13, weight: .medium)
        }
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }
}
