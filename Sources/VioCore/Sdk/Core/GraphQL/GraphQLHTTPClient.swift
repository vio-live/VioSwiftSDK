import Foundation

public struct GraphQLHTTPResponse {
    public let data: [String: Any]?
    public let errors: [[String: Any]]?
    public let status: Int
}

public final class GraphQLHTTPClient {
    public var baseURL: URL
    public var apiKey: String
    public var timeout: TimeInterval = 30

    private let session: URLSession

    public init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: cfg)
    }

    public func runQuerySafe(query: String, variables: [String: Any]) async throws
        -> GraphQLHTTPResponse
    {
        try await runOperationSafe(query: query, variables: variables)
    }

    public func runMutationSafe(query: String, variables: [String: Any]) async throws
        -> GraphQLHTTPResponse
    {
        try await runOperationSafe(query: query, variables: variables)
    }

    private func runOperationSafe(query: String, variables: [String: Any]) async throws
        -> GraphQLHTTPResponse
    {
        let requestId = String(UUID().uuidString.prefix(8))
        let operation = parseOperation(from: query)
        print("📡 [GraphQLHTTPClient][\(requestId)] POST \(baseURL) [\(operation.kind) \(operation.name)]")
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        print("🔐 [GraphQLHTTPClient][\(requestId)] Authorization=\(maskedApiKey(apiKey))")
        req.setValue(apiKey, forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["query": query, "variables": variables]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            let bodyString = String(data: data, encoding: .utf8) ?? ""

            print("📬 [GraphQLHTTPClient][\(requestId)] Response status: \(status)")
            if status != 200 {
                print("⚠️ [GraphQLHTTPClient][\(requestId)] Non-200 body: \(bodyString)")
            }

            let root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let errors = root["errors"] as? [[String: Any]]
            let dataObj = root["data"] as? [String: Any]

            if let errs = errors, !errs.isEmpty {
                print("❌ [GraphQLHTTPClient][\(requestId)] GraphQL Errors: \(errs)")
                let first = errs[0]
                let message = (first["message"] as? String) ?? "GraphQL error"
                var det: [String: Any] = [:]
                det["messages"] = errs.compactMap { $0["message"] }
                det["codes"] = errs.compactMap { ($0["extensions"] as? [String: Any])?["code"] }
                if let code = (first["extensions"] as? [String: Any])?["code"] as? String {
                    throw GraphQLErrorMapper.fromGqlCode(code, msg: message, details: det)
                } else {
                    throw GraphQLFailure(message, details: det)
                }
            }

            if !(200..<300).contains(status) {
                throw GraphQLErrorMapper.fromStatus(
                    status, msg: "HTTP error", details: ["body": bodyString])
            }

            return GraphQLHTTPResponse(data: dataObj, errors: errors, status: status)
        } catch let e as SdkException {
            throw e
        } catch {
            print("🛑 [GraphQLHTTPClient][\(requestId)] Network failure: \(error.localizedDescription)")
            throw NetworkError("Network failure", details: ["original": String(describing: error)])
        }
    }

    private func maskedApiKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "empty" }
        let prefix = String(trimmed.prefix(6))
        let suffix = String(trimmed.suffix(4))
        return "\(prefix)...\(suffix) (len=\(trimmed.count))"
    }

    private func parseOperation(from query: String) -> (kind: String, name: String) {
        let compact = query.replacingOccurrences(of: "\n", with: " ")
        let tokens = compact
            .split(whereSeparator: { $0.isWhitespace || $0 == "(" || $0 == "{" })
            .map(String.init)
        guard !tokens.isEmpty else { return ("operation", "Unknown") }

        if tokens[0] == "query" || tokens[0] == "mutation" || tokens[0] == "subscription" {
            let kind = tokens[0]
            let name = tokens.count > 1 ? tokens[1] : "Anonymous"
            return (kind, name)
        }
        return ("operation", tokens[0])
    }
}
