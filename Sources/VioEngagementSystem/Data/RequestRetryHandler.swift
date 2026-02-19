import Foundation
import VioCore

/// Handler for retrying network requests with exponential backoff
struct RequestRetryHandler {
    
    /// Maximum number of retry attempts
    let maxRetries: Int
    
    /// Base delay in seconds for exponential backoff
    let baseDelay: TimeInterval
    
    /// Maximum delay in seconds
    let maxDelay: TimeInterval
    
    init(maxRetries: Int = 3, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 10.0) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }
    
    /// Execute a request with retry logic
    func execute<T>(
        operation: @escaping () async throws -> T,
        shouldRetry: @escaping (Error, Int) -> Bool = { _, _ in true }
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                guard shouldRetry(error, attempt) && attempt < maxRetries - 1 else {
                    throw error
                }
                
                // Calculate delay with exponential backoff
                let delay = min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                VioLogger.debug(
                    "Retrying request (attempt \(attempt + 1)/\(maxRetries)) after \(delay)s delay",
                    component: "RequestRetryHandler"
                )
            }
        }
        
        // If we get here, all retries failed
        throw lastError ?? NSError(domain: "RequestRetryHandler", code: -1)
    }
    
    /// Check if an HTTP status code should trigger a retry
    static func shouldRetryHTTPStatus(_ statusCode: Int) -> Bool {
        // Retry on server errors and specific client errors
        return statusCode == 408 || // Request Timeout
               statusCode == 429 || // Too Many Requests
               statusCode == 500 || // Internal Server Error
               statusCode == 502 || // Bad Gateway
               statusCode == 503 || // Service Unavailable
               statusCode == 504    // Gateway Timeout
    }
    
    /// Check if a URL error is retryable
    static func isRetryableURLError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }
        
        switch urlError.code {
        case .timedOut,
             .networkConnectionLost,
             .notConnectedToInternet,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
