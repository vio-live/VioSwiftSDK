import Foundation

/// Primary entry point for the Vio SDK.
///
/// Import and configure once — the SDK handles everything else automatically.
///
/// **Minimal setup (recommended):**
/// ```swift
/// // AppDelegate or App.swift
/// VioSDK.configure(apiKey: "your-api-key")
///
/// // When user opens a live stream:
/// VioSDK.setContent(id: stream.contentId)
/// ```
///
/// **Development setup:**
/// ```swift
/// VioSDK.configure(apiKey: "your-dev-key", environment: .sandbox)
/// ```
public enum VioSDK {

    // MARK: - Configuration

    /// Configure the SDK with just your API key.
    /// All other settings (theme, commerce, endpoints) are loaded from the Vio backend.
    /// Call once at app startup — before any stream is opened.
    public static func configure(
        apiKey: String,
        environment: VioEnvironment = .production
    ) {
        VioConfiguration.configure(apiKey: apiKey, environment: environment)
    }

    // MARK: - Content Context

    /// Set the active stream/broadcast context.
    /// Call when the user opens a live stream or broadcast.
    /// The SDK will discover available engagement for this content automatically.
    ///
    /// - Parameter id: The content identifier (e.g., broadcast externalId or stream slug)
    public static func setContent(id: String) {
        let context = BroadcastContext(broadcastId: id)
        Task {
            await CampaignManager.shared.setBroadcastContext(context)
        }
    }

    /// Clear the active content context.
    /// Call when the user leaves the stream or closes the player.
    public static func clearContent() {
        Task {
            await CampaignManager.shared.setBroadcastContext(BroadcastContext(broadcastId: ""))
        }
    }

    // MARK: - State

    /// Whether the SDK has been configured and is ready to use.
    public static var isConfigured: Bool {
        VioConfiguration.shared.isConfigured
    }

    /// The API key currently in use.
    public static var apiKey: String {
        VioConfiguration.shared.apiKey
    }
}
