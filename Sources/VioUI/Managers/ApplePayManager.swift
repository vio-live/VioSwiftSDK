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

    /// Shown when the cart never got a server id (e.g. offline, SDK disabled, or `addProduct` fell back to local-only).
    private static let cartNotSyncedUserMessage =
        "Cannot start Apple Pay: cart could not be synced with the server. Check your connection and try again."

    /// Ensures `createCart` ran and `cartId` / `currentCartId` exist before we mutate the cart for payment.
    private func prepareServerCart(cartManager: CartManager) async -> Bool {
        cartManager.syncSdkCredentials()
        guard VioConfiguration.shared.shouldUseSDK else {
            VioLogger.error("Apple Pay: shouldUseSDK is false — no server cart", component: "ApplePayManager")
            return false
        }
        await cartManager.ensureCartIDForCheckout()
        if let id = cartManager.cartId, !id.isEmpty { return true }
        await cartManager.createCart(currency: cartManager.currency, country: cartManager.country)
        if let id = cartManager.cartId, !id.isEmpty { return true }
        if let id = cartManager.currentCartId, !id.isEmpty { return true }
        return false
    }

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
        merchantIdentifier = "merchant.live.vio"
        cartManager.syncSdkCredentials()

        var resolvedId: String? = {
            guard let raw = checkoutId else { return nil }
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }()

        // 1. Server-backed cart must exist before add/checkout. Otherwise `addProduct` can use
        // `addProductLocally` and we would show Apple Pay totals that never match the backend.
        let serverCartReady = await prepareServerCart(cartManager: cartManager)
        if !serverCartReady {
            paymentResult = .failure(Self.cartNotSyncedUserMessage)
            isProcessing = false
            return
        }

        // 2. Add product to cart if provided (Direct Buy Flow)
        if let p = product {
            VioLogger.debug("Apple Pay: Direct Buy - Adding product \(p.title) to cart...", component: "ApplePayManager")
            await cartManager.addProduct(p, variant: variant, quantity: 1)
            if let err = cartManager.errorMessage, !err.isEmpty {
                VioLogger.error("Apple Pay: cart error after addProduct: \(err)", component: "ApplePayManager")
                paymentResult = .failure(Self.cartNotSyncedUserMessage)
                isProcessing = false
                return
            }
        }

        // 3. Create Checkout from Cart (payment mutations require checkout id, not cart id)

        guard let cartId = cartManager.cartId, !cartId.isEmpty else {
            VioLogger.error("Apple Pay: no cart id after setup (likely local-only cart)", component: "ApplePayManager")
            paymentResult = .failure(Self.cartNotSyncedUserMessage)
            isProcessing = false
            return
        }

        if resolvedId == nil {
            VioLogger.debug("Apple Pay: Creating checkout from cart \(cartId)...", component: "ApplePayManager")
            do {
                let checkoutDto = try await cartManager.sdk.checkout.create(cart_id: cartId)
                let trimmedCheckout = checkoutDto.id.trimmingCharacters(in: .whitespacesAndNewlines)
                resolvedId = trimmedCheckout.isEmpty ? nil : trimmedCheckout
                cartManager.checkoutId = resolvedId
                VioLogger.debug("Apple Pay: Checkout created: \(resolvedId ?? "nil")", component: "ApplePayManager")
            } catch {
                VioLogger.error("Apple Pay: Failed to create checkout: \(error.localizedDescription)", component: "ApplePayManager")
                paymentResult = .failure("Could not start checkout. \(error.localizedDescription)")
                isProcessing = false
                return
            }
        }

        guard let cid = resolvedId, !cid.isEmpty else {
            VioLogger.error("Apple Pay: missing checkout id after create", component: "ApplePayManager")
            paymentResult = .failure("Checkout is not ready. Try again.")
            isProcessing = false
            return
        }

        self.pendingCheckoutId = cid
        VioLogger.debug("Apple Pay start — checkoutId=\(cid)", component: "ApplePayManager")

        // 4. Stripe PaymentIntent publishable key (required for STPAPIClient tokenization in test/live)
        do {
            print(
                "🍏 [ApplePayManager] StripeIntent START checkoutId=\(cid) graphQL=\(VioConfiguration.shared.resolvedCommerceGraphQLURL)"
            )
            let intent = try await cartManager.sdk.payment.stripeIntent(checkoutId: cid, returnEphemeralKey: false)
            let pubKey = intent.publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
            pendingPublishableKey = pubKey.isEmpty ? nil : pubKey
            guard !pubKey.isEmpty else {
                VioLogger.error("Apple Pay: stripeIntent returned no publishableKey", component: "ApplePayManager")
                paymentResult = .failure("Payment setup incomplete (no Stripe key).")
                isProcessing = false
                return
            }
            STPAPIClient.shared.publishableKey = pubKey
        } catch let sdkError as SdkException {
            print(
                "🍏 [ApplePayManager] StripeIntent FAIL code=\(sdkError.code ?? "nil") status=\(sdkError.status.map(String.init) ?? "nil") message=\(sdkError.message) details=\(sdkError.details ?? [:])"
            )
            VioLogger.error(
                "Apple Pay: stripeIntent failed code=\(sdkError.code ?? "nil") status=\(sdkError.status.map(String.init) ?? "nil") details=\(sdkError.details ?? [:])",
                component: "ApplePayManager")
            paymentResult = .failure("Could not prepare payment: \(sdkError.message)")
            isProcessing = false
            return
        } catch {
            print("🍏 [ApplePayManager] StripeIntent FAIL non-sdk error=\(String(describing: error))")
            VioLogger.error("Apple Pay: stripeIntent failed: \(error.localizedDescription)", component: "ApplePayManager")
            paymentResult = .failure("Could not prepare payment: \(error.localizedDescription)")
            isProcessing = false
            return
        }

        // 5. Apple Pay on backend: merchant id must match PassKit / Stripe Apple Pay config
        do {
            print("🍏 [ApplePayManager] ApplePayInit START checkoutId=\(cid)")
            let initDto = try await cartManager.sdk.payment.applePayInit(checkoutId: cid)
            let mid = initDto.gatewayMerchantId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mid.isEmpty {
                merchantIdentifier = mid
            }
            VioLogger.debug(
                "Apple Pay init OK — gateway=\(initDto.gateway) merchantId=\(merchantIdentifier)",
                component: "ApplePayManager")
        } catch let sdkError as SdkException {
            print(
                "🍏 [ApplePayManager] ApplePayInit FAIL code=\(sdkError.code ?? "nil") status=\(sdkError.status.map(String.init) ?? "nil") message=\(sdkError.message) details=\(sdkError.details ?? [:])"
            )
            VioLogger.warning(
                "Apple Pay init failed code=\(sdkError.code ?? "nil") status=\(sdkError.status.map(String.init) ?? "nil") details=\(sdkError.details ?? [:])",
                component: "ApplePayManager")
        } catch {
            print("🍏 [ApplePayManager] ApplePayInit FAIL non-sdk error=\(String(describing: error))")
            VioLogger.warning(
                "Apple Pay init failed (using default merchant): \(error.localizedDescription)",
                component: "ApplePayManager")
        }

        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantIdentifier
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = [.capability3DS, .capabilityCredit, .capabilityDebit]
        request.countryCode = Self.normalizedRegionCode(from: cartManager.country)
        request.currencyCode = Self.normalizedCurrencyCode(from: cartManager.currency)

        // Shipping/Billing requirements
        request.requiredShippingContactFields = [.postalAddress, .name, .emailAddress]
        request.requiredBillingContactFields = [.postalAddress, .name]
        // Set payment summary items (last line must be total; use .final for the charged total)
        var summaryItems: [PKPaymentSummaryItem] = []
        let merchantName = VioConfiguration.shared.brandConfiguration.name
        if cartManager.items.isEmpty, let name = productName, let amt = amount {
            let price = Self.roundedDecimal(amount: amt)
            summaryItems.append(PKPaymentSummaryItem(label: Self.summaryLineLabel(from: name), amount: price))
            summaryItems.append(PKPaymentSummaryItem(label: merchantName, amount: price, type: .final))
        } else {
            for item in cartManager.items {
                let itemAmt = Self.roundedDecimal(amount: item.price * Double(item.quantity))
                summaryItems.append(PKPaymentSummaryItem(label: Self.summaryLineLabel(from: item.title), amount: itemAmt))
            }
            if cartManager.shippingTotal > 0 {
                summaryItems.append(
                    PKPaymentSummaryItem(
                        label: "Shipping",
                        amount: Self.roundedDecimal(amount: cartManager.shippingTotal)))
            }
            let grand = cartManager.cartTotal + cartManager.shippingTotal
            summaryItems.append(
                PKPaymentSummaryItem(
                    label: merchantName,
                    amount: Self.roundedDecimal(amount: grand),
                    type: .final))
        }
        request.paymentSummaryItems = summaryItems

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        let presented = await controller.present()
        if !presented {
            VioLogger.error("Failed to present PKPaymentAuthorizationController", component: "ApplePayManager")
            self.paymentResult = .failure("Failed to show Apple Pay")
            self.isProcessing = false
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

    /// ISO 4217 for `PKPaymentRequest.currencyCode`.
    private static func normalizedCurrencyCode(from raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.count == 3, t.allSatisfy({ $0.isLetter }) { return t }
        let fb = VioConfiguration.shared.marketConfiguration.currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if fb.count == 3, fb.allSatisfy({ $0.isLetter }) { return fb }
        return "USD"
    }

    private static func summaryLineLabel(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let max = 64
        guard trimmed.count > max else { return trimmed.isEmpty ? "Order" : trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: max - 1)
        return String(trimmed[..<idx]) + "…"
    }

    private static func roundedDecimal(amount: Double) -> NSDecimalNumber {
        let behavior = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 2,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false)
        return NSDecimalNumber(value: amount).rounding(accordingToBehavior: behavior)
    }

    private static func normalizedPaymentStatus(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Internal helper to tokenize and confirm with backend
    private func tokenizeAndConfirm(payment: PKPayment, cartManager: CartManager) async -> Bool {
        var checkoutId = pendingCheckoutId
        
        // Final fallback: only real checkout id (never cart id — confirm expects checkout)
        if checkoutId == nil {
            checkoutId = cartManager.checkoutId
        }

        guard let finalId = checkoutId else {
            VioLogger.warning("❌ [ApplePayManager] No checkoutId found! Cannot call confirm mutation.", component: "ApplePayManager")
            paymentResult = .failure("No active checkout session. Please try again.")
            return false
        }

        // 1. Tokenize with Stripe
        let stripeToken: String
        do {
            let token: STPToken = try await withCheckedThrowingContinuation { continuation in
                STPAPIClient.shared.createToken(with: payment) { token, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let token = token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ApplePayManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown Stripe error"]))
                    }
                }
            }
            stripeToken = token.tokenId
        } catch {
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
            let shippingKeys = shippingAddressInput.map { addr in
                [
                    ("firstName", addr.firstName),
                    ("lastName", addr.lastName),
                    ("address1", addr.address1),
                    ("address2", addr.address2),
                    ("city", addr.city),
                    ("province", addr.province),
                    ("zip", addr.zip),
                    ("country", addr.country),
                    ("countryCode", addr.countryCode),
                ]
                .compactMap { $0.1 == nil ? nil : $0.0 }
                .sorted()
            } ?? []
            let hasEmail = (capturedContact?.emailAddress?.isEmpty == false)
            VioLogger.debug(
                "ApplePayConfirm PREP checkoutId=\(finalId) tokenPrefix=\(String(stripeToken.prefix(12))) tokenLength=\(stripeToken.count) tokenIsStripeTok=\(stripeToken.hasPrefix("tok_")) emailPresent=\(hasEmail) shippingPresent=\(shippingAddressInput != nil) shippingKeys=\(shippingKeys)",
                component: "ApplePayManager")
            let confirmDto = try await cartManager.sdk.payment.applePayConfirm(
                checkoutId: finalId,
                applePayToken: stripeToken,
                email: capturedContact?.emailAddress,
                shippingAddress: shippingAddressInput
            )

            let normalizedStatus = Self.normalizedPaymentStatus(confirmDto.status)
            VioLogger.debug(
                "ApplePayConfirm RESULT statusRaw=\(confirmDto.status) statusNormalized=\(normalizedStatus) orderId=\(confirmDto.orderId ?? "nil")",
                component: "ApplePayManager")
            if normalizedStatus == "SUCCESS" {
                paymentResult = .success
                return true
            } else {
                paymentResult = .failure("Payment failed: \(confirmDto.status)")
                return false
            }
        } catch {
            VioLogger.error("Confirm Mutation Error: \(error.localizedDescription)", component: "ApplePayManager")
            paymentResult = .failure(error.localizedDescription)
            return false
        }
    }
    // MARK: - Summary Item Helpers
    
    private func buildSummaryItems(cartManager: CartManager) -> [PKPaymentSummaryItem] {
        var summaryItems: [PKPaymentSummaryItem] = []
        let merchantName = VioConfiguration.shared.brandConfiguration.name

        for item in cartManager.items {
            let label = Self.summaryLineLabel(from: "\(item.quantity)x \(item.title)")
            let amount = Self.roundedDecimal(amount: item.price * Double(item.quantity))
            summaryItems.append(PKPaymentSummaryItem(label: label, amount: amount))
        }

        let shippingTotal = cartManager.shippingTotal
        if shippingTotal > 0 {
            summaryItems.append(
                PKPaymentSummaryItem(
                    label: "Shipping",
                    amount: Self.roundedDecimal(amount: shippingTotal)))
        }

        let total = Self.roundedDecimal(amount: cartManager.cartTotal + shippingTotal)
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

#else

@MainActor
public final class ApplePayManager: ObservableObject {
    public static let shared = ApplePayManager()
    @Published public var isProcessing = false
    @Published public var paymentResult: PaymentResult?

    public enum PaymentResult: Equatable {
        case success
        case failure(String)
        case cancelled
    }

    public var isApplePayAvailable: Bool { false }

    public func pay(
        product: Product? = nil,
        variant: Variant? = nil,
        productName: String? = nil,
        amount: Double? = nil,
        checkoutId: String? = nil,
        cartManager: CartManager
    ) async {}
}

#endif
