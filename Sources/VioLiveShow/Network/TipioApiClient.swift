import Foundation
import VioCore

/// API client for Tipio.no integration
public class TipioApiClient {
    
    // MARK: - Properties
    private let baseUrl: String
    private let apiKey: String
    private let session: URLSession
    
    // MARK: - Initialization
    public init(baseUrl: String, apiKey: String, session: URLSession = .shared) {
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.session = session
    }
    
    // MARK: - Convenience Initializer
    /// Initialize with configuration from VioConfiguration
    public convenience init() {
        let config = VioConfiguration.shared.liveShowConfiguration
        
        // Use configuration values, fallback to defaults if empty
        let baseUrl = config.tipioBaseUrl.isEmpty ? "https://stg-dev-microservices.tipioapp.com" : config.tipioBaseUrl
        let apiKey = config.tipioApiKey.isEmpty ? "KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S" : config.tipioApiKey
        
        self.init(baseUrl: baseUrl, apiKey: apiKey)
    }
    
    // MARK: - API Methods
    
    /// Fetch a livestream by ID
    /// - Parameter id: The livestream ID
    /// - Returns: TipioLiveStream object
    public func getLiveStream(id: Int) async throws -> TipioLiveStream {
        let endpoint = "/api/livestreams/\(id)"
        let url = try buildURL(endpoint: endpoint)
        
        print("🔗 [Tipio] Fetching livestream: \(id)")
        
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        do {
            let liveStream = try JSONDecoder().decode(TipioLiveStream.self, from: data)
            print("✅ [Tipio] Successfully fetched livestream: \(liveStream.title)")
            return liveStream
        } catch {
            print("❌ [Tipio] Failed to decode livestream: \(error)")
            throw TipioApiError(code: "DECODE_ERROR", message: "Failed to decode livestream data")
        }
    }
    
    /// Fetch active livestreams
    /// - Returns: Array of active TipioLiveStream objects
    public func getActiveLiveStreams() async throws -> [TipioLiveStream] {
        let endpoint = "/api/stg/livestreams/active"
        let url = try buildURL(endpoint: endpoint)
        
        print("🔗 [Tipio] Fetching active livestreams")
        print("🔗 [Tipio] Building request url=> \(url)")        
        let request = try buildRequest(url: url, method: "GET")
        print("🔗 [Tipio] Request builded, call GET")        
        let (data, response) = try await session.data(for: request)
        print("🔗 [Tipio] Request called")        
        
        try validateResponse(response)
        
        do {
            let streams = try JSONDecoder().decode([TipioLiveStream].self, from: data)
            
            print("✅ [Tipio] Successfully fetched \(streams.count) active livestreams")
            
            // Debug: Print each stream's details
            for (index, stream) in streams.enumerated() {
                print("🔍 [Tipio] Stream \(index + 1):")
                print("   - ID: \(stream.id)")
                print("   - Title: '\(stream.title)'")
                print("   - LiveStreamId: \(stream.liveStreamId)")
                print("   - Broadcasting: \(stream.broadcasting)")
                print("   - Thumbnail: \(stream.thumbnail ?? "nil")")
            }
            
            return streams            
        } catch {
            print("❌ [Tipio] Failed to decode active livestreams: \(error)")
            print("❌ [Tipio] Raw response data: \(String(data: data, encoding: .utf8) ?? "Could not decode as string")")
            throw TipioApiError(code: "DECODE_ERROR", message: "Failed to decode active livestreams")
        }
    }
    
    /// Start a livestream
    /// - Parameter id: The livestream ID to start
    /// - Returns: Status response
    public func startLiveStream(id: Int) async throws -> TipioStatusResponse {
        let endpoint = "/api/livestreams/\(id)/start"
        let url = try buildURL(endpoint: endpoint)
        
        print("🚀 [Tipio] Starting livestream: \(id)")
        
        let request = try buildRequest(url: url, method: "POST")
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        do {
            let statusResponse = try JSONDecoder().decode(TipioStatusResponse.self, from: data)
            print("✅ [Tipio] Successfully started livestream: \(id)")
            return statusResponse
        } catch {
            print("❌ [Tipio] Failed to start livestream: \(error)")
            throw TipioApiError(code: "START_ERROR", message: "Failed to start livestream")
        }
    }
    
    /// Stop a livestream
    /// - Parameter id: The livestream ID to stop
    /// - Returns: Status response
    public func stopLiveStream(id: Int) async throws -> TipioStatusResponse {
        let endpoint = "/api/livestreams/\(id)/stop"
        let url = try buildURL(endpoint: endpoint)
        
        print("⏹️ [Tipio] Stopping livestream: \(id)")
        
        let request = try buildRequest(url: url, method: "POST")
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        do {
            let statusResponse = try JSONDecoder().decode(TipioStatusResponse.self, from: data)
            print("✅ [Tipio] Successfully stopped livestream: \(id)")
            return statusResponse
        } catch {
            print("❌ [Tipio] Failed to stop livestream: \(error)")
            throw TipioApiError(code: "STOP_ERROR", message: "Failed to stop livestream")
        }
    }
    
    /// Get viewer count for a livestream
    /// - Parameter id: The livestream ID
    /// - Returns: Current viewer count
    public func getViewerCount(id: Int) async throws -> Int {
        let endpoint = "/api/livestreams/\(id)/viewers"
        let url = try buildURL(endpoint: endpoint)
        
        let request = try buildRequest(url: url, method: "GET")
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        do {
            let viewerData = try JSONDecoder().decode(TipioViewerCountData.self, from: data)
            return viewerData.count
        } catch {
            print("❌ [Tipio] Failed to get viewer count: \(error)")
            throw TipioApiError(code: "VIEWER_COUNT_ERROR", message: "Failed to get viewer count")
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildURL(endpoint: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: baseUrl + endpoint) else {
            throw TipioApiError(code: "INVALID_URL", message: "Failed to build URL")
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw TipioApiError(code: "INVALID_URL", message: "Failed to build URL")
        }
        
        return url
    }
    
    private func buildRequest(url: URL, method: String, body: Data? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("VioSDK/1.0", forHTTPHeaderField: "User-Agent")
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TipioApiError(code: "INVALID_RESPONSE", message: "Invalid response type")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            break // Success
        case 401:
            throw TipioApiError(code: "UNAUTHORIZED", message: "Invalid API key")
        case 404:
            throw TipioApiError(code: "NOT_FOUND", message: "Resource not found")
        case 429:
            throw TipioApiError(code: "RATE_LIMITED", message: "Rate limit exceeded")
        case 500...599:
            throw TipioApiError(code: "SERVER_ERROR", message: "Server error")
        default:
            throw TipioApiError(code: "HTTP_ERROR", message: "HTTP error: \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Error Types

public enum TipioApiClientError: LocalizedError {
    case invalidConfiguration
    case networkError(Error)
    case decodingError(Error)
    case apiError(TipioApiError)
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid Tipio API configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .apiError(let error):
            return "API error: \(error.message)"
        }
    }
}

// MARK: - Configuration Extension

extension VioConfiguration {
    /// Get Tipio API client configured with current settings
    public var tipioApiClient: TipioApiClient {
        // TODO: Add tipio configuration to LiveShowConfiguration
        return TipioApiClient()
    }
}
