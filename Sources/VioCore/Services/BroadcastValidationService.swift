import Foundation

/// Service for validating contentId against the backend before showing engagement.
/// Calls GET /v1/sdk/broadcast?contentId=&country= to resolve external content ID to broadcast.
@MainActor
public enum BroadcastValidationService {

    /// Validate contentId and country against the backend.
    /// - Parameters:
    ///   - contentId: External content ID (e.g. Viaplay stream ID)
    ///   - country: User country code (e.g. "NO")
    /// - Returns: BroadcastValidationResult with hasEngagement and broadcastId when applicable
    public static func validate(contentId: String, country: String) async -> BroadcastValidationResult {
        let config = VioConfiguration.shared
        let baseURL = config.campaignConfiguration.restAPIBaseURL

        // Use campaignApiKey if defined, otherwise apiKey
        let apiKey = config.campaignConfiguration.campaignApiKey.isEmpty
            ? config.apiKey
            : config.campaignConfiguration.campaignApiKey

        guard !apiKey.isEmpty else {
            VioLogger.warning("BroadcastValidationService: No API key configured", component: "BroadcastValidationService")
            return BroadcastValidationResult(hasEngagement: false)
        }

        var components = URLComponents(string: "\(baseURL)/v1/sdk/broadcast")
        components?.queryItems = [
            URLQueryItem(name: "contentId", value: contentId),
            URLQueryItem(name: "country", value: country)
        ]

        guard let url = components?.url else {
            VioLogger.error("BroadcastValidationService: Invalid URL", component: "BroadcastValidationService")
            return BroadcastValidationResult(hasEngagement: false)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.timeoutInterval = 10.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return BroadcastValidationResult(hasEngagement: false)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                VioLogger.debug("BroadcastValidationService: HTTP \(httpResponse.statusCode) - \(body)", component: "BroadcastValidationService")
                return BroadcastValidationResult(hasEngagement: false)
            }

            let result = try JSONDecoder().decode(BroadcastValidationResult.self, from: data)
            VioLogger.debug("BroadcastValidationService: hasEngagement=\(result.hasEngagement), broadcastId=\(result.broadcastId ?? "nil")", component: "BroadcastValidationService")
            return result

        } catch {
            VioLogger.error("BroadcastValidationService: \(error.localizedDescription)", component: "BroadcastValidationService")
            return BroadcastValidationResult(hasEngagement: false)
        }
    }
}
