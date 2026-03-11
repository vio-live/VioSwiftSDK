//
//  CachedAsyncImage.swift
//  VioDesignSystem
//
//  AsyncImage with disk and memory caching to avoid loading indicators
//

import SwiftUI
import Combine
import VioCore

#if canImport(UIKit)
import UIKit

/// AsyncImage with caching support to avoid loading indicators
/// Caches images in memory and disk, only shows loading if image is not cached
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var loader: ImageLoader
    
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
    }
    
    public var body: some View {
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
public class ImageLoader: ObservableObject {
    @Published public var image: Image?
    
    private let url: URL?
    private static let cache = NSCache<NSString, UIImage>()
    private static let fileManager = FileManager.default
    
    public init(url: URL?) {
        self.url = url
        load(url: url)
    }
    
    /// Validate if URL is valid for image loading (http/https scheme)
    private static func isValidImageURL(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
    
    public func load(url: URL?) {
        guard let url = url else {
            self.image = nil
            return
        }
        
        guard Self.isValidImageURL(url) else {
            VioLogger.warning("Invalid URL scheme for image: \(url.absoluteString)", component: "ImageLoader")
            self.image = nil
            return
        }
        
        let cacheKey = url.absoluteString as NSString
        
        if let cachedImage = Self.cache.object(forKey: cacheKey) {
            self.image = Image(uiImage: cachedImage)
            return
        }
        
        do {
            if let diskImage = try loadFromDisk(key: cacheKey as String) {
                Self.cache.setObject(diskImage, forKey: cacheKey)
                self.image = Image(uiImage: diskImage)
                return
            }
        } catch {
            VioLogger.warning("Failed to load image from disk cache: \(error)", component: "ImageLoader")
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    Self.cache.setObject(uiImage, forKey: cacheKey)
                    do {
                        try saveToDisk(image: uiImage, key: cacheKey as String)
                    } catch {
                        VioLogger.warning("Failed to save image to disk cache: \(error)", component: "ImageLoader")
                    }
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
        let filename = String(key.hashValue)
        return cacheDir.appendingPathComponent(filename)
    }
    
    private func loadFromDisk(key: String) throws -> UIImage? {
        guard let fileURL = cacheFileURL(key: key) else { return nil }
        let data = try Data(contentsOf: fileURL)
        guard let image = UIImage(data: data) else { return nil }
        return image
    }
    
    private func saveToDisk(image: UIImage, key: String) throws {
        guard let fileURL = cacheFileURL(key: key),
              let data = image.pngData() else {
            throw NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data or file URL"])
        }
        try data.write(to: fileURL)
    }
    
    public static func clearCache(for url: URL?) {
        guard let url = url else { return }
        guard isValidImageURL(url) else { return }
        let cacheKey = url.absoluteString as NSString
        cache.removeObject(forKey: cacheKey)
        let key = cacheKey as String
        if let fileURL = cacheFileURL(key: key) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    public static func clearCache() {
        cache.removeAllObjects()
        if let cacheDir = cacheDirectory() {
            try? fileManager.removeItem(at: cacheDir)
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
    }
}

#else

// MARK: - macOS / CLI fallback (no UIKit)

/// Fallback for non-UIKit platforms (macOS CLI, testing)
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    public var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                content(image)
            } else {
                placeholder()
            }
        }
    }
}

@MainActor
public class ImageLoader: ObservableObject {
    @Published public var image: Image?
    public init(url: URL?) {}
    public func load(url: URL?) {}
    public static func clearCache(for url: URL?) {}
    public static func clearCache() {}
    public static func cacheDirectory() -> URL? { nil }
}

#endif
