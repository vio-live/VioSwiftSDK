import Foundation
import PassKit
import SwiftUI
import VioCore

// MARK: - Apple Pay Manager
// Orchestrates PKPaymentRequest + Stripe via CartManager.stripeIntent()
// Merchant ID: merchant.live.vio (replace placeholder with real ID from developer.apple.com)

@MainActor
public class ApplePayManager: NSObject, ObservableObject {

    public static let shared = ApplePayManager()

    // MARK: - Constants
    private let merchantIdentifier = "merchant.live.vio"
    private let supportedNetworks: [PKPaymentNetwork] = [.visa, .masterCard, .amex]
    private let merchantCapabilities: PKMerchantCapability = [.threeDSecure, .credit, .debit]

    // MARK: - State
    @Published public var isProcessing = false
    @Published public var paymentResult: ApplePayResult? = nil

    // MARK: - Device Support
    public var isApplePayAvailable: Bool {
        #if targetEnvironment(simulator)
        // Simulator always shows Apple Pay button for demo purposes
        return true
        #else
        return PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks)
        #endif
    }

    // MARK: - Initiate Payment
    public func pay(
        productName: String,
        priceNOK: Double,
        cartManager: CartManager
    ) async {
        guard isApplePayAvailable else {
            VioLogger.warning("Apple Pay not available on this device", component: "ApplePayManager")
            paymentResult = .failed("Apple Pay not available on this device")
            return
        }

        isProcessing = true
        paymentResult = nil

        // 1. Try to get Stripe PaymentIntent via Commerce
        // In demo mode, we proceed even without a clientSecret
        let intent = await cartManager.stripeIntent(returnEphemeralKey: false)
        if intent != nil {
            VioLogger.debug("stripeIntent OK — Stripe PaymentIntent ready", component: "ApplePayManager")
        } else {
            VioLogger.warning("stripeIntent unavailable — proceeding in demo mode", component: "ApplePayManager")
        }

        self.pendingClientSecret = intent?.clientSecret
        self.pendingPublishableKey = intent?.publishableKey

        // 2. Build PKPaymentRequest
        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantIdentifier
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = merchantCapabilities
        request.countryCode = "NO"
        request.currencyCode = "NOK"
        // Request name, email, phone and shipping address from the user's Apple Pay wallet
        request.requiredShippingContactFields = [.name, .emailAddress, .phoneNumber, .postalAddress]
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: productName,
                amount: NSDecimalNumber(value: priceNOK)
            ),
            PKPaymentSummaryItem(
                label: "Vio Live",
                amount: NSDecimalNumber(value: priceNOK)
            )
        ]

        // 3. Present Apple Pay sheet
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        let presented = await controller.present()

        if !presented {
            VioLogger.error("PKPaymentAuthorizationController failed to present", component: "ApplePayManager")
            isProcessing = false
            paymentResult = .failed("Could not present Apple Pay")
        }
    }

    // MARK: - Private
    private var pendingClientSecret: String?
    private var pendingPublishableKey: String?

    // Captured from Apple Pay sheet
    public private(set) var capturedContact: PKContact? = nil
}

// MARK: - PKPaymentAuthorizationControllerDelegate
extension ApplePayManager: PKPaymentAuthorizationControllerDelegate {

    public func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        // Capture buyer info from Apple Pay wallet
        capturedContact = payment.shippingContact
        if let contact = payment.shippingContact {
            let name = [contact.name?.givenName, contact.name?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let email = contact.emailAddress ?? "—"
            let phone = contact.phoneNumber?.stringValue ?? "—"
            VioLogger.debug("Apple Pay contact — name: \(name), email: \(email), phone: \(phone)", component: "ApplePayManager")
        }
        VioLogger.debug("Apple Pay authorized — confirming with backend", component: "ApplePayManager")

        Task { @MainActor in
            let success = await self.confirmWithBackend(paymentToken: payment.token)
            if success {
                VioLogger.success("Payment confirmed ✅", component: "ApplePayManager")
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            } else {
                VioLogger.error("Payment confirmation failed", component: "ApplePayManager")
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            }
        }
    }

    public func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            Task { @MainActor in
                self.isProcessing = false
                if self.paymentResult == nil {
                    self.paymentResult = .cancelled
                }
            }
        }
    }

    // MARK: - Backend Confirmation
    private func confirmWithBackend(paymentToken: PKPaymentToken) async -> Bool {
        guard let clientSecret = pendingClientSecret else {
            VioLogger.warning("No clientSecret — demo mode: simulating success", component: "ApplePayManager")
            paymentResult = .success
            return true
        }

        let backendUrl = VioConfiguration.shared.campaignConfiguration.restAPIBaseURL + "/api/checkout/confirm-apple-pay"
        guard let url = URL(string: backendUrl) else {
            paymentResult = .success
            return true
        }

        // Build buyer info from captured contact
        var buyerInfo: [String: Any] = [:]
        if let contact = capturedContact {
            buyerInfo["name"] = [contact.name?.givenName, contact.name?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            buyerInfo["email"] = contact.emailAddress ?? ""
            buyerInfo["phone"] = contact.phoneNumber?.stringValue ?? ""
            if let addr = contact.postalAddress {
                buyerInfo["address"] = [
                    "street": addr.street,
                    "city": addr.city,
                    "state": addr.state,
                    "postalCode": addr.postalCode,
                    "country": addr.isoCountryCode
                ]
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "clientSecret": clientSecret,
            "applePayToken": paymentToken.paymentData.base64EncodedString(),
            "buyer": buyerInfo
        ])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                paymentResult = .success
                return true
            } else {
                paymentResult = .failed("Payment confirmation failed")
                return false
            }
        } catch {
            // Backend endpoint not yet implemented — demo mode: simulate success
            VioLogger.warning("Backend confirm not available — demo mode success", component: "ApplePayManager")
            paymentResult = .success
            return true
        }
    }
}

// MARK: - Result Type
public enum ApplePayResult: Equatable {
    case success
    case failed(String)
    case cancelled
}
