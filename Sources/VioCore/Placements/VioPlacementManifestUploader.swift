import Foundation

/// Posts the registered placement manifest to
/// `POST /v2/mobile/components/manifest`. The endpoint is idempotent so
/// the SDK calls this on every cold start; partner apps don't need to
/// gate or remember the upload state.
///
/// The actor / concurrency model:
/// - Reads `VioPlacementRegistry.shared` on the main actor (registry is
///   `@MainActor`) — caller must `await` from a Task that hops to main.
/// - Performs the network call off the main actor.
///
/// Errors are non-fatal: the SDK proceeds with bootstrap regardless.
/// Failures are logged but don't propagate; the dashboard simply won't
/// see the new components/locations until the next successful upload.
public enum VioPlacementManifestUploader {

    public struct Response: Decodable, Sendable {
        public let clientAppId: Int
        public let components: [PersistedComponent]
        public let locations: [PersistedLocation]
        public let warnings: [Warning]?

        public struct PersistedComponent: Decodable, Sendable {
            public let type: String
            public let componentId: String
            public let templateName: String?
            public let appComponentId: Int
        }

        public struct PersistedLocation: Decodable, Sendable {
            public let id: Int
            public let locationId: String
            public let displayName: String?
        }

        public struct Warning: Decodable, Sendable {
            public let kind: String
            public let detail: String
        }
    }

    public enum UploadError: Error {
        case invalidBaseURL
        case missingApiKey
        case http(status: Int, body: String?)
        case skipped(reason: String)
    }

    /// Build + POST the manifest. Returns the persisted snapshot.
    ///
    /// The caller is responsible for hopping to the main actor when reading
    /// the registry payload — `VioPlacementRegistry.manifestPayload()` is
    /// `@MainActor`, the network round-trip is not.
    @MainActor
    public static func upload(baseURL: String, apiKey: String) async throws -> Response {
        let registry = VioPlacementRegistry.shared
        let payload = registry.manifestPayload()
        let components = (payload["components"] as? [Any]) ?? []
        let locations = (payload["locations"] as? [Any]) ?? []
        if components.isEmpty && locations.isEmpty {
            // Nothing to upload — short-circuit instead of POSTing an empty
            // body that the backend rejects with 400.
            throw UploadError.skipped(reason: "registry empty (no components or locations declared)")
        }
        guard !apiKey.isEmpty else { throw UploadError.missingApiKey }

        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/v2/mobile/components/manifest") else {
            throw UploadError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UploadError.http(status: -1, body: nil)
        }
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8)
            throw UploadError.http(status: http.statusCode, body: bodyText)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(Response.self, from: data)
    }
}
