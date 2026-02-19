import SwiftUI

/// Vio Design System Button Component
public struct VButton: View {
    
    // MARK: - Style
    public enum Style {
        case primary
        case secondary
        case tertiary
        case destructive
        case ghost
    }
    
    // MARK: - Size
    public enum Size {
        case small
        case medium
        case large
        
        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: VioSpacing.xs, leading: VioSpacing.sm, bottom: VioSpacing.xs, trailing: VioSpacing.sm)
            case .medium:
                return EdgeInsets(top: VioSpacing.sm, leading: VioSpacing.md, bottom: VioSpacing.sm, trailing: VioSpacing.md)
            case .large:
                return EdgeInsets(top: VioSpacing.md, leading: VioSpacing.lg, bottom: VioSpacing.md, trailing: VioSpacing.lg)
            }
        }
        
        var font: Font {
            switch self {
            case .small:
                return VioTypography.footnote
            case .medium:
                return VioTypography.body
            case .large:
                return VioTypography.headline
            }
        }
    }
    
    // MARK: - Properties
    private let title: String
    private let style: Style
    private let size: Size
    private let action: () -> Void
    private let isLoading: Bool
    private let isDisabled: Bool
    private let icon: String?
    
    // MARK: - Initializer
    public init(
        title: String,
        style: Style = .primary,
        size: Size = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.icon = icon
        self.action = action
    }
    
    // MARK: - Body
    public var body: some View {
        Button(action: action) {
            HStack(spacing: VioSpacing.xs) {
                if isLoading {
                    VCustomLoader(style: .rotate, size: size == .small ? 16 : size == .medium ? 20 : 24, color: foregroundColor, speed: 1.5)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(size.font)
                }
                
                Text(title)
                    .font(size.font)
            }
            .padding(size.padding)
            .foregroundColor(foregroundColor)
            .background(
                Group {
                    if style == .primary {
                        RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VioColors.primary,
                                        VioColors.primary.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                    .stroke(VioColors.primary.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                            .fill(backgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                    .stroke(borderColor, lineWidth: borderWidth)
                            )
                    }
                }
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled || isLoading) ? 0.6 : 1.0)
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return VioColors.primary
        case .secondary:
            return VioColors.secondary
        case .tertiary:
            return VioColors.surface
        case .destructive:
            return VioColors.error
        case .ghost:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .secondary, .destructive:
            return .white
        case .tertiary:
            return VioColors.textPrimary
        case .ghost:
            return VioColors.primary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .secondary, .destructive:
            return Color.clear
        case .tertiary:
            return VioColors.border
        case .ghost:
            return VioColors.primary
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary, .secondary, .destructive:
            return 0
        case .tertiary, .ghost:
            return 1
        }
    }
}

// MARK: - Previews
#Preview("Button Styles") {
    VStack(spacing: VioSpacing.md) {
        VButton(title: "Primary Button", style: .primary) {
            print("Primary tapped")
        }
        
        VButton(title: "Secondary Button", style: .secondary) {
            print("Secondary tapped")
        }
        
        VButton(title: "Tertiary Button", style: .tertiary) {
            print("Tertiary tapped")
        }
        
        VButton(title: "Destructive Button", style: .destructive) {
            print("Destructive tapped")
        }
        
        VButton(title: "Ghost Button", style: .ghost) {
            print("Ghost tapped")
        }
        
        VButton(title: "With Icon", style: .primary, icon: "heart.fill") {
            print("Icon button tapped")
        }
        
        VButton(title: "Loading", style: .primary, isLoading: true) {
            print("Loading button tapped")
        }
        
        VButton(title: "Disabled", style: .primary, isDisabled: true) {
            print("Disabled button tapped")
        }
    }
    .padding()
}

#Preview("Button Sizes") {
    VStack(spacing: VioSpacing.md) {
        VButton(title: "Small Button", style: .primary, size: .small) {
            print("Small tapped")
        }
        
        VButton(title: "Medium Button", style: .primary, size: .medium) {
            print("Medium tapped")
        }
        
        VButton(title: "Large Button", style: .primary, size: .large) {
            print("Large tapped")
        }
    }
    .padding()
}
