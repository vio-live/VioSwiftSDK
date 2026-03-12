import Foundation

/// Fetches remote SDK configuration from the Vio backend.
/// Called once at SDK initialization with only the apiKey.
/// Endpoint: GET /v1/sdk/config?apiKey=<apiKey>
final class VioSDKConfigService {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchConfig(apiKey: String, baseURL: String) async -> RemoteSDKConfig? {
        let urlString = "\(baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/v1/sdk/config?apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else {
            VioLogger.error("[VioSDKConfigService] Invalid URL: \(urlString)")
            return nil
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                VioLogger.warning("[VioSDKConfigService] Non-2xx response from \(urlString)")
                return nil
            }
            let config = try JSONDecoder().decode(RemoteSDKConfig.self, from: data)
            VioLogger.info("[VioSDKConfigService] Remote config loaded for apiKey: \(String(apiKey.prefix(12)))...")
            return config
        } catch {
            VioLogger.warning("[VioSDKConfigService] Failed to fetch remote config: \(error.localizedDescription). SDK will use defaults.")
            return nil
        }
    }
}
