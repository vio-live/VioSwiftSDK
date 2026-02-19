import Foundation

/// API client for fetching dynamic configurations from backend
struct ConfigAPIClient {
    
    private var campaignRestAPIBaseURL: String {
        VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
    }
    
    private var apiKey: String {
        VioConfiguration.shared.apiKey
    }
    
    /// Fetch campaign configuration
    func fetchCampaignConfig(
        campaignId: Int,
        broadcastId: String? = nil
    ) async throws -> CampaignConfig {
        var urlString = "\(campaignRestAPIBaseURL)/v1/campaigns/\(campaignId)/config?apiKey=\(apiKey)"
        if let broadcastId = broadcastId {
            urlString += "&broadcastId=\(broadcastId)"
            // Also include matchId for backward compatibility with backend
            urlString += "&matchId=\(broadcastId)"
        }
        
        guard let url = URL(string: urlString) else {
            throw ConfigAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConfigAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ConfigAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CampaignConfig.self, from: data)
    }
    
    // Backward compatibility method
    func fetchCampaignConfig(
        campaignId: Int,
        matchId: String? = nil
    ) async throws -> CampaignConfig {
        return try await fetchCampaignConfig(campaignId: campaignId, broadcastId: matchId)
    }
    
    /// Fetch engagement configuration
    func fetchEngagementConfig(broadcastId: String) async throws -> DynamicEngagementConfig {
        var urlString = "\(campaignRestAPIBaseURL)/v1/engagement/config?apiKey=\(apiKey)&broadcastId=\(broadcastId)"
        // Also include matchId for backward compatibility with backend
        urlString += "&matchId=\(broadcastId)"
        
        guard let url = URL(string: urlString) else {
            throw ConfigAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConfigAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ConfigAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let responseWrapper = try decoder.decode(EngagementConfigResponse.self, from: data)
        return responseWrapper.engagement
    }
    
    // Backward compatibility method
    func fetchEngagementConfig(matchId: String) async throws -> DynamicEngagementConfig {
        return try await fetchEngagementConfig(broadcastId: matchId)
    }
    
    /// Fetch localization configuration
    func fetchLocalization(
        language: String,
        campaignId: Int? = nil,
        broadcastId: String? = nil
    ) async throws -> DynamicLocalizationConfig {
        var urlString = "\(campaignRestAPIBaseURL)/v1/localization/\(language)?apiKey=\(apiKey)"
        if let campaignId = campaignId {
            urlString += "&campaignId=\(campaignId)"
        }
        if let broadcastId = broadcastId {
            urlString += "&broadcastId=\(broadcastId)"
            // Also include matchId for backward compatibility with backend
            urlString += "&matchId=\(broadcastId)"
        }
        
        guard let url = URL(string: urlString) else {
            throw ConfigAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConfigAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ConfigAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(DynamicLocalizationConfig.self, from: data)
    }
    
    // Backward compatibility method
    func fetchLocalization(
        language: String,
        campaignId: Int? = nil,
        matchId: String? = nil
    ) async throws -> DynamicLocalizationConfig {
        return try await fetchLocalization(language: language, campaignId: campaignId, broadcastId: matchId)
    }
}

// MARK: - Config API Errors

enum ConfigAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid configuration API URL"
        case .invalidResponse:
            return "Invalid response from configuration API"
        case .httpError(let statusCode):
            return "HTTP error \(statusCode) from configuration API"
        case .decodingError(let error):
            return "Failed to decode configuration: \(error.localizedDescription)"
        }
    }
}
