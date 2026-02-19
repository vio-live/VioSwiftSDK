//
//  CachedAsyncImage.swift
//  Viaplay
//
//  AsyncImage with disk and memory caching to avoid loading indicators
//

import SwiftUI
import Combine
import VioCore

/// AsyncImage with caching support to avoid loading indicators
/// Caches images in memory and disk, only shows loading if image is not cached
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var loader: ImageLoader
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                content(image)
            } else {
                placeholder()
            }
        }
        .onChange(of: url) { newUrl in
            loader.load(url: newUrl)
        }
    }
}

/// Image loader with memory and disk caching
@MainActor
class ImageLoader: ObservableObject {
    @Published var image: Image?
    
    private let url: URL?
    private static let cache = NSCache<NSString, UIImage>()
    private static let fileManager = FileManager.default
    
    init(url: URL?) {
        self.url = url
        load(url: url)
    }
    
    /// Validate if URL is valid for image loading (http/https scheme)
    private static func isValidImageURL(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
    
    func load(url: URL?) {
        guard let url = url else {
            self.image = nil
            return
        }
        
        // Validate URL scheme
        guard Self.isValidImageURL(url) else {
            VioLogger.warning("Invalid URL scheme for image: \(url.absoluteString)", component: "ImageLoader")
            self.image = nil
            return
        }
        
        let cacheKey = url.absoluteString as NSString
        
        // Check memory cache first
        if let cachedImage = Self.cache.object(forKey: cacheKey) {
            self.image = Image(uiImage: cachedImage)
            return
        }
        
        // Check disk cache
        do {
            if let diskImage = try loadFromDisk(key: cacheKey as String) {
                Self.cache.setObject(diskImage, forKey: cacheKey)
                self.image = Image(uiImage: diskImage)
                return
            }
        } catch {
            VioLogger.warning("Failed to load image from disk cache: \(error)", component: "ImageLoader")
        }
        
        // Load from network
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    // Save to memory cache
                    Self.cache.setObject(uiImage, forKey: cacheKey)
                    // Save to disk cache
                    do {
                        try saveToDisk(image: uiImage, key: cacheKey as String)
                    } catch {
                        VioLogger.warning("Failed to save image to disk cache: \(error)", component: "ImageLoader")
                    }
                    // Update image
                    await MainActor.run {
                        self.image = Image(uiImage: uiImage)
                    }
                } else {
                    VioLogger.warning("Failed to create UIImage from data for URL: \(url.absoluteString)", component: "ImageLoader")
                }
            } catch {
                VioLogger.error("Failed to load image from network: \(error)", component: "ImageLoader")
            }
        }
    }
    
    static func cacheDirectory() -> URL? {
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let imageCacheDir = cacheDir.appendingPathComponent("CampaignLogos")
        try? fileManager.createDirectory(at: imageCacheDir, withIntermediateDirectories: true)
        return imageCacheDir
    }
    
    private func cacheDirectory() -> URL? {
        return Self.cacheDirectory()
    }
    
    private func cacheFileURL(key: String) -> URL? {
        return Self.cacheFileURL(key: key)
    }
    
    private static func cacheFileURL(key: String) -> URL? {
        guard let cacheDir = cacheDirectory() else { return nil }
        // Use hash of URL as filename to avoid special characters
        let filename = String(key.hashValue)
        return cacheDir.appendingPathComponent(filename)
    }
    
    private func loadFromDisk(key: String) throws -> UIImage? {
        guard let fileURL = cacheFileURL(key: key) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        guard let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    private func saveToDisk(image: UIImage, key: String) throws {
        guard let fileURL = cacheFileURL(key: key),
              let data = image.pngData() else {
            throw NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data or file URL"])
        }
        try data.write(to: fileURL)
    }
    
    /// Clear cache for a specific logo URL (called when logo changes)
    static func clearCache(for url: URL?) {
        guard let url = url else { return }
        
        // Validate URL scheme
        guard isValidImageURL(url) else {
            VioLogger.warning("Cannot clear cache for invalid URL scheme: \(url.absoluteString)", component: "ImageLoader")
            return
        }
        
        let cacheKey = url.absoluteString as NSString
        
        // Remove from memory cache
        cache.removeObject(forKey: cacheKey)
        
        // Remove from disk cache
        let key = cacheKey as String
        if let fileURL = cacheFileURL(key: key) {
            do {
                try fileManager.removeItem(at: fileURL)
                VioLogger.debug("Cleared cache for logo: \(url.absoluteString)", component: "ImageLoader")
            } catch {
                VioLogger.warning("Failed to remove cached logo file: \(error)", component: "ImageLoader")
            }
        }
    }
    
    /// Clear all cached campaign logos (called when configuration changes)
    static func clearCache() {
        cache.removeAllObjects()
        if let cacheDir = cacheDirectory() {
            try? fileManager.removeItem(at: cacheDir)
            // Recreate directory
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }
}
