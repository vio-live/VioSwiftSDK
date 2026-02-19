import Foundation
import SwiftUI
import VioCore

/// Handles Vipps payment return URLs and status checking
@MainActor
public class VippsPaymentHandler: ObservableObject {
    
    public static let shared = VippsPaymentHandler()
    
    @Published public var isPaymentInProgress = false
    @Published public var currentCheckoutId: String?
    @Published public var paymentStatus: PaymentStatus = .unknown
    
    public enum PaymentStatus {
        case unknown
        case inProgress
        case success
        case failed
        case cancelled
    }
    
    private init() {}
    
    /// Handle URL scheme return from Vipps
    public func handleReturnURL(_ url: URL) {
        VioLogger.debug("Received URL: \(url)", component: "VippsPaymentHandler")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            VioLogger.error("Invalid URL format", component: "VippsPaymentHandler")
            return
        }
        
        // Extract parameters from URL
        var checkoutId: String?
        var status: String?
        var paymentMethod: String?
        
        for item in queryItems {
            switch item.name {
            case "checkout_id":
                checkoutId = item.value
            case "status":
                status = item.value
            case "payment_method":
                paymentMethod = item.value
            default:
                break
            }
        }
        
        VioLogger.debug("Extracted parameters: Checkout ID=\(checkoutId ?? "nil"), Status=\(status ?? "nil"), Payment Method=\(paymentMethod ?? "nil")", component: "VippsPaymentHandler")
        
        // Only handle Vipps payments
        guard paymentMethod == "vipps" else {
            VioLogger.info("Not a Vipps payment, ignoring", component: "VippsPaymentHandler")
            return
        }
        
        // Update status based on URL parameters
        if let status = status {
            switch status.lowercased() {
            case "success":
                self.paymentStatus = .success
                VioLogger.success("Payment successful!", component: "VippsPaymentHandler")
            case "cancelled", "cancel":
                self.paymentStatus = .cancelled
                VioLogger.warning("Payment cancelled", component: "VippsPaymentHandler")
            case "failed", "error":
                self.paymentStatus = .failed
                VioLogger.error("Payment failed", component: "VippsPaymentHandler")
            default:
                self.paymentStatus = .unknown
                VioLogger.warning("Unknown status: \(status)", component: "VippsPaymentHandler")
            }
        }
        
        // Clear in-progress state
        if checkoutId == self.currentCheckoutId {
            self.isPaymentInProgress = false
            self.currentCheckoutId = nil
        }
    }
    
    /// Start tracking a Vipps payment
    public func startPaymentTracking(checkoutId: String) {
        VioLogger.debug("Starting payment tracking for: \(checkoutId)", component: "VippsPaymentHandler")
        self.isPaymentInProgress = true
        self.currentCheckoutId = checkoutId
        self.paymentStatus = .inProgress
    }
    
    /// Stop tracking and reset state
    public func stopPaymentTracking() {
        VioLogger.debug("Stopping payment tracking", component: "VippsPaymentHandler")
        self.isPaymentInProgress = false
        self.currentCheckoutId = nil
        self.paymentStatus = .unknown
    }
    
    /// Check if current URL is a Vipps return URL
    public func isVippsReturnURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return false
        }
        
        // Check if it's a reachu-demo:// URL with payment_method=vipps
        return components.scheme == "reachu-demo" &&
               queryItems.contains { $0.name == "payment_method" && $0.value == "vipps" }
    }
}

/// SwiftUI ViewModifier to handle Vipps payment returns
struct VippsPaymentHandlerModifier: ViewModifier {
    @StateObject private var handler = VippsPaymentHandler.shared
    
    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                if handler.isVippsReturnURL(url) {
                    handler.handleReturnURL(url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .vippsPaymentReturn)) { notification in
                if let url = notification.object as? URL {
                    handler.handleReturnURL(url)
                }
            }
    }
}

extension View {
    /// Add Vipps payment handling to any view
    public func handleVippsPayments() -> some View {
        modifier(VippsPaymentHandlerModifier())
    }
}

public extension Notification.Name {
    static let vippsPaymentReturn = Notification.Name("vippsPaymentReturn")
}
