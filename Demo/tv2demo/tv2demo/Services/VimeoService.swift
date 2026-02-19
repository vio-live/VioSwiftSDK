import Foundation

/// Service to fetch Vimeo video streaming URLs
class VimeoService {
    static let shared = VimeoService()
    
    private let clientId = "948ef884256aba00eef755af8c4651fb018f6403"
    private let clientSecret = "CxJgIC4NV9CpRSSX2Ak0I1eLdH9ZMqV3zkeJC/dslHxLRANMM+XXkL9N0mUFK34u0trhiDAZNi1tRMXc+Di8u79MiOlj/dbkr3SgRZNBaZhPjT1KdT0RWT9+4mVqP7ul"
    
    private var cachedAccessToken: String?
    private var tokenExpirationDate: Date?
    
    private init() {}
    
    /// Get HLS stream URL for a Vimeo video
    /// - Parameter videoId: The Vimeo video ID (e.g., "1124046641")
    /// - Returns: The streaming URL (HLS or progressive MP4)
    func getVideoStreamURL(videoId: String) async throws -> URL {
        print("🔍 [VimeoService] Fetching stream URL for video: \(videoId)")
        
        // For public videos, use the player embed URL directly
        // This works without authentication and extracts the stream from the player config
        let playerURLString = "https://player.vimeo.com/video/\(videoId)?h=b3793bd327"
        guard let playerURL = URL(string: playerURLString) else {
            throw VimeoError.invalidURL
        }
        
        print("📡 [VimeoService] Fetching player config...")
        
        var request = URLRequest(url: playerURL)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ [VimeoService] Failed to fetch player page")
            throw VimeoError.invalidResponse
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw VimeoError.invalidResponse
        }
        
        print("📄 [VimeoService] Player HTML fetched (\(html.count) chars)")
        
        // Extract config JSON from the player HTML
        // The player embeds a JSON config with all stream URLs
        guard let configJSON = extractPlayerConfig(from: html) else {
            print("❌ [VimeoService] Could not extract player config")
            throw VimeoError.streamURLNotFound
        }
        
        print("✅ [VimeoService] Player config extracted")
        
        // Parse the config and extract stream URLs
        guard let streamURL = extractStreamURL(from: configJSON) else {
            print("❌ [VimeoService] No stream URL found in config")
            throw VimeoError.streamURLNotFound
        }
        
        print("✅ [VimeoService] Stream URL found!")
        print("🔗 [VimeoService] URL: \(streamURL.absoluteString.prefix(150))...")
        return streamURL
    }
    
    private func extractPlayerConfig(from html: String) -> String? {
        // Look for the player config object in the HTML
        // Pattern: var config = {...}; or window.playerConfig = {...};
        let patterns = [
            #"var config = (\{[\s\S]*?\});[\s\n]"#,
            #"window\.playerConfig = (\{[\s\S]*?\});"#,
            #"\\"config\\":(\{[^\}]+\})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1 {
                
                let matchRange = match.range(at: 1)
                if let range = Range(matchRange, in: html) {
                    return String(html[range])
                }
            }
        }
        
        return nil
    }
    
    private func extractStreamURL(from configJSON: String) -> URL? {
        // Try to find HLS master playlist URL
        let hlsPattern = #"https://[^"\\]+\.m3u8[^"\\]*"#
        if let regex = try? NSRegularExpression(pattern: hlsPattern, options: []),
           let match = regex.firstMatch(in: configJSON, options: [], range: NSRange(configJSON.startIndex..., in: configJSON)),
           let range = Range(match.range, in: configJSON) {
            
            var urlString = String(configJSON[range])
            urlString = urlString.replacingOccurrences(of: "\\u0026", with: "&")
            urlString = urlString.replacingOccurrences(of: "\\/", with: "/")
            
            if let url = URL(string: urlString) {
                return url
            }
        }
        
        // Try to find progressive MP4 URL as fallback
        let mp4Pattern = #"https://[^"\\]+\.mp4\?[^"\\]+"#
        if let regex = try? NSRegularExpression(pattern: mp4Pattern, options: []),
           let match = regex.firstMatch(in: configJSON, options: [], range: NSRange(configJSON.startIndex..., in: configJSON)),
           let range = Range(match.range, in: configJSON) {
            
            var urlString = String(configJSON[range])
            urlString = urlString.replacingOccurrences(of: "\\u0026", with: "&")
            urlString = urlString.replacingOccurrences(of: "\\/", with: "/")
            
            if let url = URL(string: urlString) {
                return url
            }
        }
        
        return nil
    }
    
    /// Get a fresh access token from Vimeo API
    private func getAccessToken() async throws -> String {
        // Check if we have a cached token that hasn't expired
        if let token = cachedAccessToken,
           let expiration = tokenExpirationDate,
           expiration > Date() {
            return token
        }
        
        // Request a new token
        let url = URL(string: "https://api.vimeo.com/oauth/authorize/client")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Basic auth
        let credentials = "\(clientId):\(clientSecret)"
        let base64Credentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = [
            "grant_type": "client_credentials",
            "scope": "public"
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VimeoError.authenticationFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Cache the token (Vimeo tokens typically last 24 hours)
        cachedAccessToken = tokenResponse.accessToken
        tokenExpirationDate = Date().addingTimeInterval(23 * 3600) // 23 hours to be safe
        
        print("✅ [VimeoService] New access token obtained")
        return tokenResponse.accessToken
    }
}

// MARK: - Models

extension VimeoService {
    struct TokenResponse: Codable {
        let accessToken: String
        let tokenType: String
        let scope: String
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case scope
        }
    }
    
    struct VimeoVideoResponse: Codable {
        let name: String
        let play: PlayInfo?
        
        struct PlayInfo: Codable {
            let hls: HLSInfo?
            let progressive: [ProgressiveInfo]?
            
            struct HLSInfo: Codable {
                let link: String?
            }
            
            struct ProgressiveInfo: Codable {
                let link: String?
                let width: Int?
                let height: Int?
                let quality: String?
            }
        }
    }
}

// MARK: - Errors

enum VimeoError: LocalizedError {
    case invalidURL
    case invalidResponse
    case streamURLNotFound
    case invalidStreamURL
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Vimeo URL"
        case .invalidResponse:
            return "Invalid response from Vimeo"
        case .streamURLNotFound:
            return "Stream URL not found in player HTML"
        case .invalidStreamURL:
            return "Invalid stream URL format"
        case .authenticationFailed:
            return "Failed to authenticate with Vimeo API"
        }
    }
}

