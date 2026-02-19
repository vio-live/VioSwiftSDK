import Foundation

/// Analytics Configuration
///
/// Configuration for analytics tracking using Mixpanel.
/// Automatically enabled when `mixpanelToken` is provided in the config JSON.
public struct AnalyticsConfiguration {
    public let enabled: Bool
    public let mixpanelToken: String?
    public let apiHost: String? // Para EU: "https://api-eu.mixpanel.com"
    public let trackComponentViews: Bool
    public let trackComponentClicks: Bool
    public let trackImpressions: Bool
    public let trackTransactions: Bool
    public let trackProductEvents: Bool
    public let autocapture: Bool
    public let recordSessionsPercent: Int
    
    public static let `default` = AnalyticsConfiguration(
        enabled: false,
        mixpanelToken: nil,
        apiHost: nil,
        trackComponentViews: true,
        trackComponentClicks: true,
        trackImpressions: true,
        trackTransactions: true,
        trackProductEvents: true,
        autocapture: false,
        recordSessionsPercent: 0
    )
    
    public init(
        enabled: Bool = false,
        mixpanelToken: String? = nil,
        apiHost: String? = nil,
        trackComponentViews: Bool = true,
        trackComponentClicks: Bool = true,
        trackImpressions: Bool = true,
        trackTransactions: Bool = true,
        trackProductEvents: Bool = true,
        autocapture: Bool = false,
        recordSessionsPercent: Int = 0
    ) {
        self.enabled = enabled
        self.mixpanelToken = mixpanelToken
        self.apiHost = apiHost
        self.trackComponentViews = trackComponentViews
        self.trackComponentClicks = trackComponentClicks
        self.trackImpressions = trackImpressions
        self.trackTransactions = trackTransactions
        self.trackProductEvents = trackProductEvents
        self.autocapture = autocapture
        self.recordSessionsPercent = recordSessionsPercent
    }
}





