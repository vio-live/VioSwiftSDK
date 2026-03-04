import Foundation

/// Payment methods available for a campaign, configured in the backend dashboard
public struct CheckoutConfig: Codable {
    public let paymentMethods: [PaymentMethod]

    public enum PaymentMethod: String, Codable {
        case applePay = "apple_pay"
        case klarna = "klarna"
        case vipps = "vipps"
        case stripe = "stripe"
    }

    /// Default: Apple Pay if available, fallback to Stripe
    public static let `default` = CheckoutConfig(paymentMethods: [.applePay])

    public var hasApplePay: Bool { paymentMethods.contains(.applePay) }
    public var hasKlarna: Bool { paymentMethods.contains(.klarna) }
    public var hasVipps: Bool { paymentMethods.contains(.vipps) }
}
