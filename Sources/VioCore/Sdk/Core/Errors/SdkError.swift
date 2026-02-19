import Foundation

public class SdkException: Error, CustomStringConvertible {
    public let message: String
    public let code: String?
    public let status: Int?
    public let details: [String: Any]?
    public let stack: String?

    public init(
        _ message: String, code: String? = nil, status: Int? = nil, details: [String: Any]? = nil,
        stack: String? = nil
    ) {
        self.message = message
        self.code = code
        self.status = status
        self.details = details
        self.stack = stack
    }

    public var description: String {
        "SdkException(\(code ?? "UNKNOWN")): \(message)\(status != nil ? " [HTTP \(status!)]" : "")"
    }
}

public final class ValidationException: SdkException {
    public init(_ message: String, details: [String: Any]? = nil) {
        super.init(message, code: "VALIDATION", details: details)
    }
}
public final class AuthException: SdkException {
    public init(_ message: String, status: Int? = nil, details: [String: Any]? = nil) {
        super.init(message, code: "AUTH", status: status, details: details)
    }
}
public final class PermissionException: SdkException {
    public init(_ message: String, status: Int? = nil, details: [String: Any]? = nil) {
        super.init(message, code: "FORBIDDEN", status: status, details: details)
    }
}
public final class NotFoundException: SdkException {
    public init(_ message: String, status: Int? = nil, details: [String: Any]? = nil) {
        super.init(message, code: "NOT_FOUND", status: status, details: details)
    }
}
public final class RateLimitException: SdkException {
    public init(_ message: String, status: Int? = nil, details: [String: Any]? = nil) {
        super.init(message, code: "RATE_LIMITED", status: status, details: details)
    }
}
public final class ServiceUnavailableException: SdkException {
    public init(_ message: String, status: Int? = nil, details: [String: Any]? = nil) {
        super.init(message, code: "UNAVAILABLE", status: status, details: details)
    }
}
public final class TimeoutError: SdkException {
    public init(_ message: String, details: [String: Any]? = nil) {
        super.init(message, code: "TIMEOUT", details: details)
    }
}
public final class NetworkError: SdkException {
    public init(_ message: String, status: Int? = nil, details: [String: Any]? = nil) {
        super.init(message, code: "NETWORK", status: status, details: details)
    }
}
public final class GraphQLFailure: SdkException {
    public init(_ message: String, details: [String: Any]? = nil) {
        super.init(message, code: "GRAPHQL", details: details)
    }
}
