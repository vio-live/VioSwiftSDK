import SwiftUI

/// Vio Design System Typography Tokens
public struct VioTypography {
    
    // MARK: - Display Text
    public static let largeTitle = Font.largeTitle.weight(.bold)
    public static let title1 = Font.title.weight(.semibold)
    public static let title2 = Font.title2.weight(.semibold)
    public static let title3 = Font.title3.weight(.medium)
    
    // MARK: - Headlines
    public static let headline = Font.headline.weight(.semibold)
    public static let subheadline = Font.subheadline.weight(.medium)
    
    // MARK: - Body Text
    public static let body = Font.body
    public static let bodyBold = Font.body.weight(.semibold)
    public static let callout = Font.callout
    
    // MARK: - Small Text
    public static let footnote = Font.footnote
    public static let caption1 = Font.caption
    public static let caption2 = Font.caption2
    
    // MARK: - Custom Weights
    public static func body(weight: Font.Weight) -> Font {
        return Font.body.weight(weight)
    }
    
    public static func headline(weight: Font.Weight) -> Font {
        return Font.headline.weight(weight)
    }
}
