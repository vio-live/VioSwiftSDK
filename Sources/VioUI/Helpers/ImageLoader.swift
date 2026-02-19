import SwiftUI
import Foundation
import VioDesignSystem
import VioCore

#if os(iOS)
import UIKit
#endif

/// Custom image loader that uses URLSession for better control and error handling
@MainActor
class ImageLoader: ObservableObject {
    @Published var image: Image?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var url: URL?
    private var task: URLSessionDataTask?
    
    private static let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        // Agregar User-Agent para evitar bloqueos
        configuration.httpAdditionalHeaders = [
            "User-Agent": "VioSwiftSDK/1.0 (iOS)"
        ]
        return URLSession(configuration: configuration)
    }()
    
    func load(url: URL?) {
        guard let url = url else {
            self.error = NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            return
        }
        
        // Cancel previous task if any
        task?.cancel()
        
        self.url = url
        self.isLoading = true
        self.error = nil
        
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30
        request.setValue("VioSwiftSDK/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("image/png,image/jpeg,image/*;q=0.8", forHTTPHeaderField: "Accept")
        
        task = Self.urlSession.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error
                    self.isLoading = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.error = NSError(domain: "ImageLoader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.isLoading = false
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.error = NSError(domain: "ImageLoader", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                    self.isLoading = false
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    self.error = NSError(domain: "ImageLoader", code: -3, userInfo: [NSLocalizedDescriptionKey: "Empty data"])
                    self.isLoading = false
                    return
                }
                
                #if os(iOS)
                guard let uiImage = UIImage(data: data) else {
                    self.error = NSError(domain: "ImageLoader", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    self.isLoading = false
                    return
                }
                
                self.image = Image(uiImage: uiImage)
                self.isLoading = false
                #else
                self.error = NSError(domain: "ImageLoader", code: -5, userInfo: [NSLocalizedDescriptionKey: "Platform not supported"])
                self.isLoading = false
                #endif
            }
        }
        
        task?.resume()
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}

/// SwiftUI view that uses ImageLoader for reliable image loading
public struct LoadedImage: View {
    public let url: URL?
    public let placeholder: AnyView
    public let errorView: AnyView
    
    @StateObject private var loader = ImageLoader()
    
    public init(
        url: URL?,
        placeholder: AnyView = AnyView(VCustomLoader(style: .rotate, size: 30)),
        errorView: AnyView? = nil
    ) {
        self.url = url
        self.placeholder = placeholder
        self.errorView = errorView ?? AnyView(Image(systemName: "photo"))
    }
    
    public var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
            } else if loader.isLoading {
                placeholder
            } else if loader.error != nil {
                errorView
            } else {
                placeholder
            }
        }
        .onAppear {
            loader.load(url: url)
        }
        .onChange(of: url) { newURL in
            loader.load(url: newURL)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}

