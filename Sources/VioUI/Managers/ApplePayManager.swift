import Foundation
import SwiftUI
import VioCore

#if os(iOS)
import Contacts
import PassKit
import StripeApplePay
import StripePayments

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
        .vPay,
        .discover,
        .chinaUnionPay
    ]

    @Published public var isProcessing = false
    @Published public var paymentResult: PaymentResult?

    public enum PaymentResult: Equatable {
        case success
        case failure(String)
        case cancelled
    }

    public var isApplePayAvailable: Bool {
        PKPaymentAuthorizationController.canMakePayments()
    }

    private var pendingCheckoutId: String?
    public var capturedContact: PKContact?
    private var pendingPublishableKey: String?
    private var pendingCartManager: CartManager?

    public func pay(
        product: Product? = nil,
        variant: Variant? = nil,
        productName: String? = nil,
        amount: Double? = nil,
        checkoutId: String? = nil,
        cartManager: CartManager
    ) async {
        self.isProcessing = true
        self.paymentResult = nil
        self.pendingCartManager = cartManager

        var resolvedId = checkoutId
        
        // 1. Ensure Cart exists
        if cartManager.cartId == nil {
            VioLogger.debug("Apple Pay: No Cart ID, ensuring cart...", component: "ApplePayManager")
            await cartManager.ensureCartIDForCheckout()
        }
        
        // 2. Add product to cart if provided (Direct Buy Flow)
        if let p = product {
            VioLogger.debug("Apple Pay: Direct Buy - Adding product \(p.title) to cart...", component: "ApplePayManager")
            await cartManager.addProduct(p, variant: variant, quantity: 1)
        }
        
        // 3. Create Checkout from Cart (The ID we need for Payment mutations)
        if let cartId = cartManager.cartId {
            VioLogger.debug("Apple Pay: Creating checkout from cart \(cartId)...", component: "ApplePayManager")
            do {
                let checkoutDto = try await cartManager.sdk.checkout.create(cart_id: cartId)
                resolvedId = checkoutDto.id
                VioLogger.debug("Apple Pay: Checkout created: \(resolvedId ?? "nil")", component: "ApplePayManager")
            } catch {
                VioLogger.error("Apple Pay: Failed to create checkout: \(error.localizedDescription)", component: "ApplePayManager")
                // Fallback to cartId if checkout creation fails (some backends use them interchangeably)
                resolvedId = resolvedId ?? cartId
            }
        }

        self.pendingCheckoutId = resolvedId
        VioLogger.debug("Apple Pay start — resolved ID: \(resolvedId ?? "demo-mode")", component: "ApplePayManager")

        // 4. Fetch Stripe intent and applePayInit
        if let cid = resolvedId {
            let intent = try? await cartManager.sdk.payment.stripeIntent(checkoutId: cid, returnEphemeralKey: false)
            self.pendingPublishableKey = intent?.publishableKey
            if let pubKey = intent?.publishableKey {
                STPAPIClient.shared.publishableKey = pubKey
            }
            
            print("🌐 [ApplePayManager] Calling applePayInit(checkoutId: \(cid))...")
            do {
                let initDto = try await cartManager.sdk.payment.applePayInit(checkoutId: cid)
                print("✅ [ApplePayManager] applePayInit success: \(initDto.gateway ?? "nil")")
            } catch {
                print("⚠️ [ApplePayManager] applePayInit failed: \(error.localizedDescription)")
            }
        }

        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantIdentifier
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = [.capability3DS, .capabilityCredit, .capabilityDebit]
        request.countryCode = cartManager.country
        request.currencyCode = cartManager.currency
        
        print("🌐 [ApplePayManager] Request: Country=\(request.countryCode), Currency=\(request.currencyCode), Merchant=\(merchantIdentifier)")
        print("🌐 [ApplePayManager] canMakePayments: \(PKPaymentAuthorizationController.canMakePayments())")
        print("🌐 [ApplePayManager] canMakePayments(networks): \(PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks))")
        
        // Shipping/Billing requirements
        request.requiredShippingContactFields = [.postalAddress, .name, .emailAddress]
        request.requiredBillingContactFields = [.postalAddress, .name]        
        // Set payment summary items
        var summaryItems: [PKPaymentSummaryItem] = []
        let merchantName = VioConfiguration.shared.brandConfiguration.name
        if cartManager.items.isEmpty, let name = productName, let amt = amount {
            // Standalone product payment
            let price = NSDecimalNumber(value: amt)
            summaryItems.append(PKPaymentSummaryItem(label: name, amount: price))
            summaryItems.append(PKPaymentSummaryItem(label: merchantName, amount: price))
        } else {
            // Cart-based payment
            for item in cartManager.items {
                let itemAmt = NSDecimalNumber(value: item.price * Double(item.quantity))
                summaryItems.append(PKPaymentSummaryItem(label: item.title, amount: itemAmt))
            }
            if cartManager.shippingTotal > 0 {
                summaryItems.append(PKPaymentSummaryItem(label: "Shipping", amount: NSDecimalNumber(value: cartManager.shippingTotal)))
            }
            summaryItems.append(PKPaymentSummaryItem(label: merchantName, amount: NSDecimalNumber(value: cartManager.cartTotal + cartManager.shippingTotal)))
        }
        request.paymentSummaryItems = summaryItems
        for item in summaryItems {
            print("  - [\(item.label)]: \(item.amount.stringValue)")
        }

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        print("🌐 [ApplePayManager] Presenting Apple Pay sheet...")
        let presented = await controller.present()
        if !presented {
            VioLogger.error("Failed to present PKPaymentAuthorizationController", component: "ApplePayManager")
            self.paymentResult = .failure("Failed to show Apple Pay")
            self.isProcessing = false
        }
    }

    /// Internal helper to tokenize and confirm with backend
    private func tokenizeAndConfirm(payment: PKPayment, cartManager: CartManager) async -> Bool {
        var checkoutId = pendingCheckoutId
        
        // Final fallback if pendingCheckoutId was missed
        if checkoutId == nil {
            checkoutId = cartManager.checkoutId ?? cartManager.cartId
        }

        guard let finalId = checkoutId else {
            VioLogger.warning("❌ [ApplePayManager] No checkoutId found! Cannot call confirm mutation.", component: "ApplePayManager")
            paymentResult = .failure("No active checkout session. Please try again.")
            return false
        }

        // 1. Tokenize with Stripe
        print("🌐 [ApplePayManager] Tokenizing PKPayment with Stripe... (Key: \(STPAPIClient.shared.publishableKey ?? "nil"))")
        let stripeToken: String
        do {
            print("🌐 [ApplePayManager] Calling STPAPIClient.createToken...")
            let token: STPToken = try await withCheckedThrowingContinuation { continuation in
                STPAPIClient.shared.createToken(with: payment) { token, error in
                    if let error = error {
                        print("❌ [ApplePayManager] Stripe creation callback error: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let token = token {
                        print("✅ [ApplePayManager] Stripe creation callback success: \(token.tokenId)")
                        continuation.resume(returning: token)
                    } else {
                        print("❌ [ApplePayManager] Stripe creation callback: Unknown error")
                        continuation.resume(throwing: NSError(domain: "ApplePayManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown Stripe error"]))
                    }
                }
            }
            stripeToken = token.tokenId
            print("✅ [ApplePayManager] Passed Stripe tokenization: \(stripeToken)")
        } catch {
            print("❌ [ApplePayManager] Stripe tokenization failed: \(error.localizedDescription)")
            VioLogger.error("Stripe Tokenization Error: \(error.localizedDescription)", component: "ApplePayManager")
            paymentResult = .failure("Payment verification failed")
            return false
        }

        // 2. Prepare shipping address
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

        // 3. Confirm with backend
        do {
            cartManager.syncSdkCredentials()
            print("🌐 [ApplePayManager] applePayConfirm(checkoutId: \(finalId)) via GraphQL...")
            print("🌐 [ApplePayManager] token: \(stripeToken)")
            let confirmDto = try await cartManager.sdk.payment.applePayConfirm(
                checkoutId: finalId,
                applePayToken: stripeToken,
                email: capturedContact?.emailAddress,
                shippingAddress: shippingAddressInput
            )
            print("🌐 [ApplePayManager] confirm response received status: \(confirmDto.status ?? "nil")")
            
            if confirmDto.status == "SUCCESS" {
                print("✅ [ApplePayManager] applePayConfirm SUCCESS (orderId: \(confirmDto.orderId ?? "—"))")
                paymentResult = .success
                return true
            } else {
                print("⚠️ [ApplePayManager] applePayConfirm status: \(confirmDto.status ?? "UNKNOWN")")
                paymentResult = .failure("Payment failed: \(confirmDto.status ?? "unknown error")")
                return false
            }
        } catch {
            print("🛑 [ApplePayManager] applePayConfirm GraphQL error: \(error.localizedDescription)")
            VioLogger.error("Confirm Mutation Error: \(error.localizedDescription)", component: "ApplePayManager")
            paymentResult = .failure(error.localizedDescription)
            return false
        }
    }
    // MARK: - Summary Item Helpers
    
    private func buildSummaryItems(cartManager: CartManager) -> [PKPaymentSummaryItem] {
        var summaryItems: [PKPaymentSummaryItem] = []
        let merchantName = VioConfiguration.shared.brandConfiguration.name
        
        // Add items
        for item in cartManager.items {
            let label = "\(item.quantity)x \(item.title)"
            let amount = NSDecimalNumber(value: item.price * Double(item.quantity))
            summaryItems.append(PKPaymentSummaryItem(label: label, amount: amount))
        }
        
        // Add shipping if selected
        let shippingTotal = cartManager.shippingTotal
        if shippingTotal > 0 {
            summaryItems.append(PKPaymentSummaryItem(label: "Shipping", amount: NSDecimalNumber(value: shippingTotal)))
        }
        
        // Add grand total
        let total = NSDecimalNumber(value: cartManager.cartTotal + shippingTotal)
        summaryItems.append(PKPaymentSummaryItem(label: merchantName, amount: total, type: .final))
        
        return summaryItems
    }
}

extension ApplePayManager: PKPaymentAuthorizationControllerDelegate {

    public func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectShippingContact contact: PKContact,
        handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void
    ) {
        Task { @MainActor in
            guard let cartManager = self.pendingCartManager else {
                completion(PKPaymentRequestShippingContactUpdate(errors: nil, paymentSummaryItems: [], shippingMethods: []))
                return
            }
            
            // 1. Update cart country to get regional shipping options
            if let countryCode = contact.postalAddress?.isoCountryCode {
                print("🌐 [ApplePayManager] Shipping address changed to \(countryCode). Updating cart...")
                _ = try? await cartManager.sdk.cart.update(cart_id: cartManager.cartId ?? "", shipping_country: countryCode)
                _ = await cartManager.refreshShippingOptions()
            }
            
            // 2. Fetch shipping methods from the first item (Vio currently handles shipping per item)
            // For Apple Pay, we present the options of the first item as the available methods for the whole order
            let shippingMethods: [PKShippingMethod] = cartManager.items.first?.availableShippings.map { option in
                let method = PKShippingMethod(label: option.name, amount: NSDecimalNumber(value: option.amount))
                method.identifier = option.id
                method.detail = option.description
                return method
            } ?? []
            
            // 3. Update summary items
            let summaryItems = buildSummaryItems(cartManager: cartManager)
            
            completion(PKPaymentRequestShippingContactUpdate(
                errors: nil,
                paymentSummaryItems: summaryItems,
                shippingMethods: shippingMethods
            ))
        }
    }

    public func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectShippingMethod shippingMethod: PKShippingMethod,
        handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void
    ) {
        Task { @MainActor in
            guard let cartManager = self.pendingCartManager, let optionId = shippingMethod.identifier else {
                completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: []))
                return
            }
            
            print("🌐 [ApplePayManager] Shipping method selected: \(shippingMethod.label) (\(optionId))")
            
            // Apply this shipping option to all items in the cart (Standard Apple Pay behavior)
            for item in cartManager.items {
                cartManager.setShippingOption(for: item.id, optionId: optionId)
            }
            
            // Recalculate totals
            let summaryItems = buildSummaryItems(cartManager: cartManager)
            completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: summaryItems))
        }
    }

    public func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        capturedContact = payment.shippingContact
        Task { @MainActor in
            guard let cartManager = self.pendingCartManager else {
                VioLogger.error("No CartManager available in delegate", component: "ApplePayManager")
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            
            // Sync final shipping selections to backend before confirming
            _ = await cartManager.applyCheapestShippingPerSupplier() // This actually applies all PENDING selections
            
            // Use the tokenization helper
            let success = await self.tokenizeAndConfirm(payment: payment, cartManager: cartManager)
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
}
#endif
