import SwiftUI
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Shared max width for floating engagement cards (screen minus horizontal padding).
enum EngagementCardLayout {
    static var maxCardWidth: CGFloat {
        #if os(iOS) || os(tvOS)
        UIScreen.main.bounds.width - 40
        #else
        560
        #endif
    }
}
