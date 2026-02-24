/// Vio Design System
/// 
/// Provides design tokens, base components, and utilities for building
/// consistent UI experiences across Vio applications.

import Foundation
import SwiftUI

/// Main entry point for Vio Design System
public struct VioDesignSystem {
    
    /// Initialize design system
    public static func configure() {
        // Future: Load custom fonts, configure themes, etc.
        print("🎨 Vio Design System initialized")
    }
}

// MARK: - Public Exports

// Export base components
// VioButton is the primary type
// VioToastNotification is the primary type
public typealias VioToastOverlay = VToastOverlay
public typealias VioToastManager = ToastManager
public typealias VioCustomLoader = VCustomLoader

// Export image components
public typealias VioCachedAsyncImage = CachedAsyncImage
public typealias VioImageLoader = ImageLoader
public typealias VioCampaignSponsorBadge = CampaignSponsorBadge
public typealias VioCacheHelper = CacheHelper
