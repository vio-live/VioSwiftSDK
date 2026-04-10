import Foundation
import SwiftUI
import VioCore

#if os(iOS)
import Contacts
import PassKit

// Orchestrates PKPaymentRequest + optional Stripe via CartManager.stripeIntent().
@MainActor
public final class ApplePayManager: NSObject, ObservableObject {

    public static let shared = ApplePayManager()

    private var merchantIdentifier = "merchant.live.vio"
    /// Same list on `PKPaymentRequest` and for PassKit probes. Maestro covers many NO/EU debit wallets; avoid rare networks that can make the aggregate `canMakePayments(usingNetworks:…)` falsely negative in some regions.
    private let supportedNetworks: [PKPaymentNetwork] = [
        .visa,
        .masterCard,
        .amex,
        .maestro,
    ]
    private let merchantCapabilities: PKMerchantCapability = [.threeDSecure, .credit, .debit]

    @Published public var isProcessing = false
    @Published public var paymentResult: ApplePayResult? = nil
    @Published public var capturedContact: PKContact? = nil

    /// True when the device has Apple Pay and at least one card. We intentionally **do not** gate on `canMakePayments(usingNetworks:capabilities:)` for UI: that API often returns false for valid EU/NO wallets while the sheet still works; eligibility is enforced when presenting `PKPaymentRequest`.
    public var isApplePayAvailable: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return PKPaymentAuthorizationController.canMakePayments()
        #endif
    }

    public func pay(
        productName: String,
        amount: Double,
        cartManager: CartManager
    ) async {
        guard isApplePayAvailable else {
            VioLogger.warning("Apple Pay not available on this device", component: "ApplePayManager")
            paymentResult = .failed("Apple Pay not available on this device")
            return
        }

        isProcessing = true
        paymentResult = nil

        let intent = await cartManager.stripeIntent(returnEphemeralKey: false)
        if intent != nil {
            VioLogger.debug("stripeIntent OK — Stripe PaymentIntent ready", component: "ApplePayManager")
        }

        self.pendingCheckoutId = cartManager.checkoutId
        
        // Initialize Apple Pay on backend to get gateway/merchant info (similar to Google Pay)
        if let checkoutId = cartManager.checkoutId {
            do {
                let initDto = try await cartManager.sdk.payment.applePayInit(checkoutId: checkoutId)
                self.merchantIdentifier = initDto.gatewayMerchantId
                VioLogger.debug("Apple Pay init OK, merchantId: \(initDto.gatewayMerchantId)", component: "ApplePayManager")
            } catch {
                VioLogger.error("Apple Pay init failed: \(error.localizedDescription)", component: "ApplePayManager")
            }
        }

        self.pendingPublishableKey = intent?.publishableKey

        guard amount > 0, amount.isFinite else {
            VioLogger.error("Apple Pay invalid amount=\(amount)", component: "ApplePayManager")
            isProcessing = false
            paymentResult = .failed("Invalid payment amount")
            return
        }

        let countryCode = Self.normalizedRegionCode(from: cartManager.country)
        let currencyCode = Self.normalizedCurrencyCode(from: cartManager.currency)

        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantIdentifier
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = merchantCapabilities
        request.countryCode = countryCode
        request.currencyCode = currencyCode
        request.requiredShippingContactFields = [.name, .emailAddress, .phoneNumber, .postalAddress]

        #if targetEnvironment(simulator)
        let demoContact = PKContact()
        var demoName = PersonNameComponents()
        demoName.givenName = "Angelo"
        demoName.familyName = "Sepulveda"
        demoContact.name = demoName
        demoContact.emailAddress = "angelo@vio.live"
        demoContact.phoneNumber = CNPhoneNumber(stringValue: "+47 900 00 000")
        let demoAddress = CNMutablePostalAddress()
        demoAddress.street = "Karl Johans gate 1"
        demoAddress.city = "Oslo"
        demoAddress.postalCode = "0154"
        demoAddress.isoCountryCode = "NO"
        demoAddress.country = "Norway"
        demoContact.postalAddress = demoAddress
        request.shippingContact = demoContact
        #endif

        let rounding = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 2,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let amountDecimal = NSDecimalNumber(value: amount).rounding(accordingToBehavior: rounding)
        let lineLabel = Self.summaryLineLabel(from: productName)
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(label: lineLabel, amount: amountDecimal),
            PKPaymentSummaryItem(label: "Vio Live", amount: amountDecimal),
        ]

        VioLogger.debug(
            "Apple Pay present — merchant=\(merchantIdentifier) country=\(countryCode) currency=\(currencyCode) amount=\(amountDecimal) labelLen=\(lineLabel.count)",
            component: "ApplePayManager",
        )

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        self.pendingCartManager = cartManager
        let presented = await controller.present()

        if !presented {
            VioLogger.error(
                "PKPaymentAuthorizationController.present() returned false — check In-App Payments entitlement (merchant id), ISO country/currency, and Apple Pay on the App ID in the developer portal",
                component: "ApplePayManager",
            )
            isProcessing = false
            paymentResult = .failed("Could not present Apple Pay")
        }
    }

    /// ISO 3166-1 alpha-2 for `PKPaymentRequest.countryCode`.
    private static func normalizedRegionCode(from raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.count == 2, t.allSatisfy({ $0.isLetter }) { return t }
        let fb = VioConfiguration.shared.marketConfiguration.countryCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if fb.count == 2, fb.allSatisfy({ $0.isLetter }) { return fb }
        return "US"
    }

    /// ISO 4217 for `PKPaymentRequest.currencyCode` (never symbols like \"kr\").
    private static func normalizedCurrencyCode(from raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.count == 3, t.allSatisfy({ $0.isLetter }) { return t }
        let fb = VioConfiguration.shared.marketConfiguration.currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if fb.count == 3, fb.allSatisfy({ $0.isLetter }) { return fb }
        return "USD"
    }

    private static func summaryLineLabel(from productName: String) -> String {
        let trimmed = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let max = 64
        guard trimmed.count > max else { return trimmed.isEmpty ? "Order" : trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: max - 1)
        return String(trimmed[..<idx]) + "…"
    }

    private var pendingCheckoutId: String?
    private var pendingPublishableKey: String?
    private var pendingCartManager: CartManager?
}

extension ApplePayManager: PKPaymentAuthorizationControllerDelegate {

    public func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        capturedContact = payment.shippingContact
        if let contact = payment.shippingContact {
            let name = [contact.name?.givenName, contact.name?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            VioLogger.debug(
                "Apple Pay contact — name: \(name), email: \(contact.emailAddress ?? "—")",
                component: "ApplePayManager"
            )
        }
        Task { @MainActor in
            guard let cartManager = self.pendingCartManager else {
                VioLogger.error("No CartManager available in delegate", component: "ApplePayManager")
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            let success = await self.confirmWithBackend(paymentToken: payment.token, cartManager: cartManager)
            if success {
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            } else {
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

    private func confirmWithBackend(paymentToken: PKPaymentToken, cartManager: CartManager) async -> Bool {
        guard let checkoutId = pendingCheckoutId else {
            VioLogger.warning("No checkoutId — demo mode: simulating success", component: "ApplePayManager")
            paymentResult = .success
            return true
        }

        var shippingAddressInput: ApplePayAddressInputDto? = nil
        if let contact = capturedContact, let addr = contact.postalAddress {
            shippingAddressInput = ApplePayAddressInputDto(
                firstName: contact.name?.givenName,
                lastName: contact.name?.familyName,
                address1: addr.street,
                city: addr.city,
                province: addr.state,
                zip: addr.postalCode,
                country: addr.isoCountryCode,
                countryCode: addr.isoCountryCode
            )
        }

        do {
            VioLogger.debug("Sending Apple Pay confirmation to backend via GraphQL", component: "ApplePayManager")
            let tokenString = paymentToken.paymentData.base64EncodedString()
            let confirmDto = try await cartManager.sdk.payment.applePayConfirm(
                checkoutId: checkoutId,
                applePayToken: tokenString,
                email: capturedContact?.emailAddress,
                shippingAddress: shippingAddressInput
            )
            
            if confirmDto.status == "SUCCESS" {
                VioLogger.success("Apple Pay payment confirmed by backend", component: "ApplePayManager")
                paymentResult = .success
                return true
            } else {
                VioLogger.error("Backend returned non-success status for Apple Pay: \(confirmDto.status)", component: "ApplePayManager")
                paymentResult = .failed("Payment confirmation failed with status: \(confirmDto.status)")
                return false
            }
        } catch {
            VioLogger.error("Error during Apple Pay confirmation: \(error.localizedDescription)", component: "ApplePayManager")
            paymentResult = .failed("Network or server error")
            return false
        }
    }
}

#else

@MainActor
public final class ApplePayManager: ObservableObject {
    public static let shared = ApplePayManager()
    @Published public var isProcessing = false
    @Published public var paymentResult: ApplePayResult? = nil
    public var isApplePayAvailable: Bool { false }
    public func pay(productName: String, amount: Double, cartManager: CartManager) async {}
}

#endif

public enum ApplePayResult: Equatable {
    case success
    case failed(String)
    case cancelled
}
