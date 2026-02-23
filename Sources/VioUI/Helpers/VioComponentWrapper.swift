import SwiftUI
import VioCore

/// Helper view wrapper that automatically hides Vio components if market is not available or campaign is not active
/// Use this to wrap any Vio UI components
public struct VioComponentWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        if VioConfiguration.shared.shouldUseSDK && CampaignManager.shared.isCampaignActive {
            content()
        } else {
            EmptyView()
        }
    }
}

extension View {
    /// Conditionally show this view only if Vio SDK market is available and campaign is active
    public func vioOnly() -> some View {
        Group {
            if VioConfiguration.shared.shouldUseSDK && CampaignManager.shared.isCampaignActive {
                self
            } else {
                EmptyView()
            }
        }
    }
}


