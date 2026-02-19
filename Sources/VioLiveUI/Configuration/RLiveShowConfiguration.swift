import SwiftUI
import VioCore
import VioDesignSystem

/// Configuration for RLiveShowOverlay appearance and behavior
public struct RLiveShowConfiguration {
    
    // MARK: - Layout Configuration
    public struct Layout {
        public let showCloseButton: Bool
        public let showLiveBadge: Bool
        public let showControls: Bool
        public let showChat: Bool
        public let showProducts: Bool
        public let showLikes: Bool
        
        public init(
            showCloseButton: Bool = true,
            showLiveBadge: Bool = true,
            showControls: Bool = true,
            showChat: Bool = true,
            showProducts: Bool = true,
            showLikes: Bool = true
        ) {
            self.showCloseButton = showCloseButton
            self.showLiveBadge = showLiveBadge
            self.showControls = showControls
            self.showChat = showChat
            self.showProducts = showProducts
            self.showLikes = showLikes
        }
        
        public static let `default` = Layout()
        public static let minimal = Layout(
            showCloseButton: true,
            showLiveBadge: true,
            showControls: false,
            showChat: false,
            showProducts: false,
            showLikes: false
        )
    }
    
    // MARK: - Color Configuration
    public struct Colors {
        public let liveBadgeColor: Color
        public let controlsBackground: Color
        public let controlsStroke: Color
        public let controlsTint: Color
        public let chatBackground: Color
        public let productsBackground: Color
        public let overlayBackground: Color
        
        public init(
            liveBadgeColor: Color? = nil,
            controlsBackground: Color? = nil,
            controlsStroke: Color? = nil,
            controlsTint: Color? = nil,
            chatBackground: Color? = nil,
            productsBackground: Color? = nil,
            overlayBackground: Color? = nil
        ) {
            // Use default colors without adaptive computation in init
            
            self.liveBadgeColor = liveBadgeColor ?? .red
            self.controlsBackground = controlsBackground ?? Color.black.opacity(0.4)
            self.controlsStroke = controlsStroke ?? Color.white.opacity(0.2)
            self.controlsTint = controlsTint ?? .white
            self.chatBackground = chatBackground ?? Color.black.opacity(0.7)
            self.productsBackground = productsBackground ?? Color.black.opacity(0.8)
            self.overlayBackground = overlayBackground ?? Color.clear
        }
        
        public static let `default` = Colors()
        
        public static func adaptive(for colorScheme: SwiftUI.ColorScheme) -> Colors {
            let adaptiveColors = VioColors.adaptive(for: colorScheme)
            
            return Colors(
                liveBadgeColor: .red,
                controlsBackground: adaptiveColors.surface.opacity(0.8),
                controlsStroke: adaptiveColors.border,
                controlsTint: adaptiveColors.textPrimary,
                chatBackground: adaptiveColors.surface.opacity(0.9),
                productsBackground: adaptiveColors.surface.opacity(0.95),
                overlayBackground: adaptiveColors.background.opacity(0.1)
            )
        }
    }
    
    // MARK: - Typography Configuration
    public struct Typography {
        public let streamTitleSize: CGFloat
        public let streamSubtitleSize: CGFloat
        public let chatMessageSize: CGFloat
        public let productTitleSize: CGFloat
        public let productPriceSize: CGFloat
        
        public init(
            streamTitleSize: CGFloat = 16,
            streamSubtitleSize: CGFloat = 12,
            chatMessageSize: CGFloat = 14,
            productTitleSize: CGFloat = 14,
            productPriceSize: CGFloat = 16
        ) {
            self.streamTitleSize = streamTitleSize
            self.streamSubtitleSize = streamSubtitleSize
            self.chatMessageSize = chatMessageSize
            self.productTitleSize = productTitleSize
            self.productPriceSize = productPriceSize
        }
        
        public static let `default` = Typography()
        public static let compact = Typography(
            streamTitleSize: 14,
            streamSubtitleSize: 10,
            chatMessageSize: 12,
            productTitleSize: 12,
            productPriceSize: 14
        )
    }
    
    // MARK: - Spacing Configuration
    public struct Spacing {
        public let controlsSpacing: CGFloat
        public let contentPadding: CGFloat
        public let productSpacing: CGFloat
        public let chatPadding: CGFloat
        
        public init(
            controlsSpacing: CGFloat = 16,
            contentPadding: CGFloat = 16,
            productSpacing: CGFloat = 12,
            chatPadding: CGFloat = 16
        ) {
            self.controlsSpacing = controlsSpacing
            self.contentPadding = contentPadding
            self.productSpacing = productSpacing
            self.chatPadding = chatPadding
        }
        
        public static let `default` = Spacing()
        public static let compact = Spacing(
            controlsSpacing: 12,
            contentPadding: 12,
            productSpacing: 8,
            chatPadding: 12
        )
    }
    
    // MARK: - Main Configuration
    public let layout: Layout
    public let colors: Colors
    public let typography: Typography
    public let spacing: Spacing
    
    public init(
        layout: Layout = .default,
        colors: Colors = .default,
        typography: Typography = .default,
        spacing: Spacing = .default
    ) {
        self.layout = layout
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
    }
    
    // MARK: - Presets
    public static let `default` = RLiveShowConfiguration()
    
    public static let minimal = RLiveShowConfiguration(
        layout: .minimal,
        typography: .compact,
        spacing: .compact
    )
    
    public static func adaptive(for colorScheme: SwiftUI.ColorScheme) -> RLiveShowConfiguration {
        return RLiveShowConfiguration(
            colors: .adaptive(for: colorScheme)
        )
    }
}
