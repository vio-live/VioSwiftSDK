import Foundation

public struct GraphQLHTTPResponse {
    public let data: [String: Any]?
    public let errors: [[String: Any]]?
    public let status: Int
}

public final class GraphQLHTTPClient {
    public let baseURL: URL
    public let apiKey: String
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
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["query": query, "variables": variables]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, resp) = try await session.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1

            let root = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let errors = root["errors"] as? [[String: Any]]
            let dataObj = root["data"] as? [String: Any]

            if let errs = errors, !errs.isEmpty {
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
                let body = String(data: data, encoding: .utf8)
                throw GraphQLErrorMapper.fromStatus(
                    status, msg: "HTTP error", details: ["body": body ?? ""])
            }

            return GraphQLHTTPResponse(data: dataObj, errors: errors, status: status)
        } catch let e as SdkException {
            throw e
        } catch {
            throw NetworkError("Network failure", details: ["original": String(describing: error)])
        }
    }
}
