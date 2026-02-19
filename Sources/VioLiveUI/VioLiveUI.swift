/// Vio LiveShow UI Components
/// 
/// Provides SwiftUI components for live streaming and interactive shopping experiences

import Foundation
import SwiftUI
import VioCore
import VioLiveShow
import VioDesignSystem

// MARK: - Main LiveUI Export

@available(iOS 15.0, *)
public struct VioLiveUI {
    
    /// Configure LiveUI with VioLiveShow
    public static func configure() {
        // LiveUI initialized
    }
}

// MARK: - Convenience View Modifiers

@available(iOS 15.0, *)
extension View {
    
    /// Adds live stream overlay support to any view
    /// Use this to enable global live stream functionality
    public func liveStreamOverlay() -> some View {
        self.overlay(
            RLiveStreamOverlay()
        )
    }
    
    /// Adds a floating live show indicator
    public func liveShowIndicator(
        position: MiniPlayerPosition = .topRight
    ) -> some View {
        self.overlay(
            RLiveShowFloatingIndicator(position: position) {
                // Show featured stream action will be handled by the app
            }
        )
    }
}

// MARK: - Quick Access Functions

@available(iOS 15.0, *)
extension VioLiveUI {
    
    /// Show a live stream with the specified layout
    @MainActor
    public static func showLiveStream(
        _ stream: LiveStream,
        layout: LiveStreamLayout = .fullScreenOverlay
    ) {
        LiveShowManager.shared.showLiveStream(stream, layout: layout)
    }
    
    /// Show live stream by ID
    @MainActor
    public static func showLiveStream(
        id: String,
        layout: LiveStreamLayout = .fullScreenOverlay
    ) {
        LiveShowManager.shared.showLiveStream(id: id, layout: layout)
    }
    
    /// Show the featured live stream (if any)
    @MainActor
    public static func showFeaturedLiveStream(
        layout: LiveStreamLayout = .fullScreenOverlay
    ) {
        guard let stream = LiveShowManager.shared.featuredLiveStream else { return }
        LiveShowManager.shared.showLiveStream(stream, layout: layout)
    }
    
    /// Hide the current live stream
    @MainActor
    public static func hideLiveStream() {
        LiveShowManager.shared.hideLiveStream()
    }
    
    /// Convert current stream to mini player
    @MainActor
    public static func showMiniPlayer() {
        LiveShowManager.shared.showMiniPlayer()
    }
    
    /// Check if there are active live streams
    @MainActor
    public static var hasActiveLiveStreams: Bool {
        LiveShowManager.shared.hasActiveLiveStreams
    }
    
    /// Get current viewer count across all streams
    @MainActor
    public static var totalViewerCount: Int {
        LiveShowManager.shared.totalViewerCount
    }
}

// MARK: - Demo and Testing

@available(iOS 15.0, *)
extension VioLiveUI {
    
    /// Get demo live stream data for testing
    @MainActor
    public static var demoStream: LiveStream? {
        LiveShowManager.shared.activeStreams.first
    }
    
    /// Get all demo streams
    @MainActor
    public static var demoStreams: [LiveStream] {
        LiveShowManager.shared.activeStreams
    }
    
    /// Simulate new chat message for testing
    @MainActor
    public static func simulateNewChatMessage() {
        LiveShowManager.shared.simulateNewChatMessage()
    }
}
