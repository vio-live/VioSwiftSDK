//
//  CacheHelper.swift
//  VioDesignSystem
//
//  Helper to clear image cache when campaign configuration changes
//

import Foundation
import VioCore

/// Helper to manage cache clearing for both campaign data and images
public struct CacheHelper {
    /// Flag to prevent duplicate listener registration
    private static var listenersSetup = false

    /// Validate if URL string is valid for image loading (http/https scheme)
    private static func isValidImageURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// Setup listener for cache clearing notifications
    public static func setupCacheClearingListener() {
        // Prevent duplicate listener registration
        guard !listenersSetup else {
            VioLogger.debug("Cache clearing listeners already setup, skipping", component: "CacheHelper")
            return
        }
        listenersSetup = true
        // Listen for full cache clear (configuration change)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VioCacheCleared"),
            object: nil,
            queue: .main
        ) { _ in
            // Clear image cache when campaign cache is cleared
            ImageLoader.clearCache()
            VioLogger.info("Image cache cleared due to configuration change", component: "CacheHelper")
        }

        // Listen for specific logo changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("VioCampaignLogoChanged"),
            object: nil,
            queue: .main
        ) { notification in
            // Get old logo URL from notification
            if let userInfo = notification.userInfo,
               let oldLogoUrlString = userInfo["oldLogoUrl"] as? String,
               !oldLogoUrlString.isEmpty,
               isValidImageURL(oldLogoUrlString),
               let oldLogoUrl = URL(string: oldLogoUrlString) {
                // Clear specific logo from cache
                ImageLoader.clearCache(for: oldLogoUrl)
                VioLogger.debug("Cleared cache for logo: \(oldLogoUrlString)", component: "CacheHelper")
            }

            // Pre-load new logo if provided
            if let userInfo = notification.userInfo,
               let newLogoUrlString = userInfo["newLogoUrl"] as? String,
               !newLogoUrlString.isEmpty,
               isValidImageURL(newLogoUrlString),
               let newLogoUrl = URL(string: newLogoUrlString) {
                // Pre-load new logo in background with timeout
                Task {
                    do {
                        let configuration = URLSessionConfiguration.default
                        configuration.timeoutIntervalForRequest = 10.0
                        configuration.timeoutIntervalForResource = 10.0
                        let session = URLSession(configuration: configuration)
                        _ = try await session.data(from: newLogoUrl)
                        VioLogger.debug("Pre-loaded new logo: \(newLogoUrlString)", component: "CacheHelper")
                    } catch {
                        VioLogger.warning("Failed to pre-load logo (timeout or error): \(error)", component: "CacheHelper")
                    }
                }
            }
        }
    }

    /// Clear both campaign cache and image cache when configuration changes
    public static func clearAllCaches() {
        // Clear campaign cache (from SDK)
        CacheManager.shared.clearCache()

        // Clear image cache
        ImageLoader.clearCache()

        VioLogger.info("Cleared both campaign cache and image cache", component: "CacheHelper")
    }
}
