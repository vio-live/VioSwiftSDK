import Foundation
import SwiftUI

/// Session context for a single broadcast/session.
/// Injected (not singleton) to support multi-session (e.g., 2+ simultaneous broadcasts).
/// Provides userId and broadcastContext to engagement, products, ads, and casting overlay.
@MainActor
public final class VioSessionContext: ObservableObject {

    /// User ID for engagement (votes, contests). When nil, BackendEngagementRepository uses local UUID.
    @Published public var userId: String?

    /// Broadcast context for this session. Used for auto-discovery and component filtering.
    @Published public var broadcastContext: BroadcastContext?

    /// Content ID for contentId flow (e.g. Viaplay stream ID). When set, triggers validation via GET /v1/sdk/broadcast.
    @Published public var contentId: String?

    /// Country code for contentId validation (e.g. "NO").
    @Published public var country: String?

    /// When true, EngagementManager uses BackendEngagementRepository even if demoMode is enabled.
    /// Set after BroadcastValidationService returns hasEngagement: true.
    @Published public var useBackendEngagement: Bool = false

    public init(
        userId: String? = nil,
        broadcastContext: BroadcastContext? = nil,
        contentId: String? = nil,
        country: String? = nil,
        useBackendEngagement: Bool = false
    ) {
        self.userId = userId
        self.broadcastContext = broadcastContext
        self.contentId = contentId
        self.country = country
        self.useBackendEngagement = useBackendEngagement
    }

    /// Convenience initializer for contentId flow
    public static func forContentId(contentId: String, country: String, userId: String? = nil) -> VioSessionContext {
        VioSessionContext(userId: userId, contentId: contentId, country: country)
    }

    /// Configure or update session context
    public func configure(
        userId: String? = nil,
        broadcastContext: BroadcastContext? = nil,
        contentId: String? = nil,
        country: String? = nil,
        useBackendEngagement: Bool? = nil
    ) {
        if let userId = userId {
            self.userId = userId
        }
        if let broadcastContext = broadcastContext {
            self.broadcastContext = broadcastContext
        }
        if let contentId = contentId {
            self.contentId = contentId
        }
        if let country = country {
            self.country = country
        }
        if let useBackendEngagement = useBackendEngagement {
            self.useBackendEngagement = useBackendEngagement
        }
    }
}
