import Foundation
import VioCore

/// Metrics for tracking engagement API requests
struct EngagementRequestMetrics {
    let endpoint: String
    let broadcastId: String
    let duration: TimeInterval
    let statusCode: Int?
    let error: Error?
    let responseSize: Int?
    let retryCount: Int
    
    /// Log metrics with structured logging
    func log() {
        let success = error == nil && (statusCode.map { (200...299).contains($0) } ?? false)
        
        // Structured logging with metadata
        let metadataString = [
            "endpoint=\(endpoint)",
            "broadcastId=\(broadcastId)",
            "duration_ms=\(Int(duration * 1000))",
            "status_code=\(statusCode ?? -1)",
            "success=\(success)",
            "error=\(error?.localizedDescription ?? "none")",
            "response_size_bytes=\(responseSize ?? 0)",
            "retry_count=\(retryCount)"
        ].joined(separator: ", ")
        
        VioLogger.info(
            "Engagement request completed - \(metadataString)",
            component: "BackendEngagementRepository"
        )
        
        // Track analytics if configured
        Task { @MainActor in
            AnalyticsManager.shared.track("engagement_request", properties: [
                "endpoint": endpoint,
                "broadcast_id": broadcastId,
                "success": success,
                "duration_ms": Int(duration * 1000),
                "status_code": statusCode ?? -1,
                "retry_count": retryCount
            ])
        }
    }
}
