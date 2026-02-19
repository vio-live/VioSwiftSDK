import Foundation

public enum GraphQLErrorMapper {
    public static func fromStatus(_ status: Int?, msg: String, details: [String: Any]? = nil)
        -> SdkException
    {
        switch status {
        case 401: return AuthException(msg, status: status, details: details)
        case 403: return PermissionException(msg, status: status, details: details)
        case 404: return NotFoundException(msg, status: status, details: details)
        case 408: return TimeoutError(msg, details: details)
        case 429: return RateLimitException(msg, status: status, details: details)
        case 500, 502, 503, 504:
            return ServiceUnavailableException(msg, status: status, details: details)
        case .some(let s) where (400..<500).contains(s):
            return SdkException(msg, code: "HTTP_\(s)", status: status, details: details)
        case .some(let s) where s >= 500:
            return ServiceUnavailableException(msg, status: status, details: details)
        default:
            return NetworkError(msg, status: status, details: details)
        }
    }

    public static func fromGqlCode(_ code: String, msg: String, details: [String: Any]? = nil)
        -> SdkException
    {
        switch code.uppercased() {
        case "UNAUTHENTICATED": return AuthException(msg, details: details)
        case "FORBIDDEN": return PermissionException(msg, details: details)
        case "NOT_FOUND": return NotFoundException(msg, details: details)
        case "BAD_USER_INPUT": return ValidationException(msg, details: details)
        case "RATE_LIMITED": return RateLimitException(msg, details: details)
        case "INTERNAL_SERVER_ERROR": return ServiceUnavailableException(msg, details: details)
        default: return GraphQLFailure("\(code): \(msg)", details: details)
        }
    }
}
