import Foundation

/// Errors from `VioCampaignPartnerAPI` (`/api/campaigns/...` routes).
public enum VioCampaignPartnerAPIError: Error, Sendable {
    case missingApiKey
    case invalidURL
    case httpError(statusCode: Int, body: String?)
}

/// HTTP API for partner flows authenticated with the SDK app API key (`x-api-key`).
/// Base URL: `VioConfiguration.shared.campaignConfiguration.restAPIBaseURL`.
@MainActor
public enum VioCampaignPartnerAPI {

    /// POST `/api/campaigns/:campaignId/cart-intent`
    public static func sendCartIntent(
        campaignId: Int,
        userId: String,
        productId: String,
        productName: String? = nil
    ) async throws {
        let key = VioConfiguration.shared.resolvedSdkApiKey
        guard !key.isEmpty else { throw VioCampaignPartnerAPIError.missingApiKey }

        let base = VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/campaigns/\(campaignId)/cart-intent") else {
            throw VioCampaignPartnerAPIError.invalidURL
        }

        struct Body: Encodable {
            let userId: String
            let productId: String
            let productName: String?
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.httpBody = try JSONEncoder().encode(Body(
            userId: userId,
            productId: productId,
            productName: productName
        ))
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VioCampaignPartnerAPIError.httpError(statusCode: -1, body: nil)
        }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8)
            throw VioCampaignPartnerAPIError.httpError(statusCode: http.statusCode, body: text)
        }
    }

    /// POST `/api/campaigns/:campaignId/register-device` — registers APNs/FCM token for offline push (when supported by API).
    public static func registerDevice(
        campaignId: Int,
        userId: String,
        deviceToken: String,
        platform: String = "ios"
    ) async throws {
        let key = VioConfiguration.shared.resolvedSdkApiKey
        guard !key.isEmpty else { throw VioCampaignPartnerAPIError.missingApiKey }

        let base = VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/campaigns/\(campaignId)/register-device") else {
            throw VioCampaignPartnerAPIError.invalidURL
        }

        struct Body: Encodable {
            let userId: String
            let deviceToken: String
            let platform: String
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.httpBody = try JSONEncoder().encode(Body(
            userId: userId,
            deviceToken: deviceToken,
            platform: platform
        ))
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VioCampaignPartnerAPIError.httpError(statusCode: -1, body: nil)
        }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8)
            throw VioCampaignPartnerAPIError.httpError(statusCode: http.statusCode, body: text)
        }
    }
}
