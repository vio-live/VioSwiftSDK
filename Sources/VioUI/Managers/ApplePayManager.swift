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

    // Default merchant id used by PassKit. Backend may override it via applePayInit
    // only when it returns a valid Apple merchant identifier (`merchant.*`).
    private var merchantIdentifier: String = "merchant.live.vio"
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
    
    /// Validates Apple Pay configuration and provides diagnostic information
    public func validateConfiguration() -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []
        
        // Check basic Apple Pay availability
        if !PKPaymentAuthorizationController.canMakePayments() {
            issues.append("Apple Pay not available on this device")
        }
        
        if !PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks) {
            issues.append("No supported payment networks available")
        }
        
        // Check merchant identifier
        if merchantIdentifier.isEmpty {
            issues.append("Merchant identifier is empty")
        } else if !merchantIdentifier.hasPrefix("merchant.") {
            issues.append("Invalid merchant identifier format (should start with 'merchant.')")
        } else {
            // Try to detect entitlement issues early
            let testRequest = PKPaymentRequest()
            testRequest.merchantIdentifier = merchantIdentifier
            testRequest.supportedNetworks = [.visa]
            testRequest.merchantCapabilities = [.capability3DS]
            testRequest.countryCode = "US"
            testRequest.currencyCode = "USD"
            testRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: "Test", amount: NSDecimalNumber(value: 1.0))]
            
            // Note: This doesn't fully validate entitlements, but gives us a basic check
            if !PKPaymentAuthorizationController.canMakePayments() {
                issues.append("Device doesn't support Apple Pay or merchant not entitled")
            }
        }
        
        // Check Stripe configuration
        if STPAPIClient.shared.publishableKey?.isEmpty ?? true {
            issues.append("Stripe publishable key not configured")
        }
        
        return (isValid: issues.isEmpty, issues: issues)
    }
    
    /// Diagnoses Apple Pay certificate and Stripe configuration
    public func diagnoseApplePaySetup() {
        print("🔍 [ApplePayManager] Apple Pay Configuration Diagnosis:")
        print("📱 Device Capabilities:")
        print("   - Apple Pay available: \(PKPaymentAuthorizationController.canMakePayments())")
        print("   - Supported networks available: \(PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks))")
        
        print("🏪 Merchant Configuration:")
        print("   - Merchant ID: \(merchantIdentifier)")
        print("   - Build configuration: \(isDebugBuild ? "DEBUG" : "RELEASE")")
        
        print("🔑 Stripe Configuration:")
        if let key = STPAPIClient.shared.publishableKey {
            print("   - Publishable key: \(key.prefix(20))... (\(key.count) chars)")
            print("   - Key type: \(key.hasPrefix("pk_test_") ? "TEST" : key.hasPrefix("pk_live_") ? "LIVE" : "UNKNOWN")")
        } else {
            print("   - Publishable key: NOT SET")
        }
        
        print("📋 Required Actions:")
        print("   1. Verify merchant ID '\(merchantIdentifier)' exists in Apple Developer Console")
        print("   2. Generate Apple Pay Certificate for this merchant ID")
        print("   3. Upload certificate to Stripe Dashboard: https://dashboard.stripe.com/settings/payments/apple_pay")
        print("   4. Ensure certificate matches the publishable key environment (test/live)")
    }
    
    private var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
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

        // Validate configuration before proceeding (but be flexible with Stripe key)
        let validation = validateConfiguration()
        if !validation.isValid {
            print("❌ [ApplePayManager] Configuration validation failed:")
            for issue in validation.issues {
                print("  - \(issue)")
            }
            
            // Check if the only issue is missing Stripe key (which we might get later)
            let onlyStripeKeyMissing = validation.issues.count == 1 && 
                                     validation.issues.first?.contains("publishable key") == true
            
            if !onlyStripeKeyMissing {
                self.paymentResult = .failure("Apple Pay configuration error: \(validation.issues.first ?? "Unknown error")")
                self.isProcessing = false
                return
            } else {
                print("⚠️ [ApplePayManager] Stripe key missing, but will try to obtain it during setup")
            }
        }

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

        // 4. Fetch Stripe key strictly from backend (no local/hardcoded fallback at runtime)
        var backendStripeKey: String?
        var backendStripeKeySource = "none"
        if let cid = resolvedId {
            print(
                "🔑 [ApplePayManager] stripeIntent start checkoutId=\(cid)"
            )
            do {
                let intent = try await cartManager.sdk.payment.stripeIntent(
                    checkoutId: cid,
                    returnEphemeralKey: false
                )
                if !intent.publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    backendStripeKey = intent.publishableKey
                    backendStripeKeySource = "stripeIntent.publishable_key"
                    print(
                        "🔑 [ApplePayManager] stripeIntent ok backendKey=\(maskedStripeKey(intent.publishableKey))"
                    )
                }
            } catch {
                print("❌ [ApplePayManager] stripeIntent fail: \(error.localizedDescription)")
            }

            do {
                let initDto = try await cartManager.sdk.payment.applePayInit(checkoutId: cid)
                let backendMerchantId = initDto.gatewayMerchantId.trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidAppleMerchantIdentifier(backendMerchantId) {
                    merchantIdentifier = backendMerchantId
                    print("🔐 [ApplePayManager] applePayInit merchantId=\(merchantIdentifier)")
                } else if backendMerchantId.hasPrefix("pk_") {
                    if backendStripeKey == nil {
                        backendStripeKey = backendMerchantId
                        backendStripeKeySource = "applePayInit.gateway_merchant_id(pk_*)"
                    }
                    print(
                        "🔑 [ApplePayManager] applePayInit returned pk_* backendKey=\(maskedStripeKey(backendMerchantId))"
                    )
                } else if !backendMerchantId.isEmpty {
                    print(
                        "⚠️ [ApplePayManager] applePayInit invalid merchantId='\(backendMerchantId)' keeping=\(merchantIdentifier)"
                    )
                }
            } catch {
                print("⚠️ [ApplePayManager] applePayInit fail: \(error.localizedDescription)")
            }
        }

        guard let runtimeBackendStripeKey = backendStripeKey,
              !runtimeBackendStripeKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            print("❌ [ApplePayManager] missing backend Stripe key (stripeIntent/applePayInit). Aborting Apple Pay.")
            paymentResult = .failure("Missing backend Stripe credentials")
            isProcessing = false
            return
        }
        pendingPublishableKey = runtimeBackendStripeKey
        STPAPIClient.shared.publishableKey = runtimeBackendStripeKey
        print(
            "🔑 [ApplePayManager] using backend Stripe key source=\(backendStripeKeySource) key=\(maskedStripeKey(runtimeBackendStripeKey))"
        )

        // Validate merchant identifier
        if merchantIdentifier.isEmpty {
            print("❌ [ApplePayManager] Merchant identifier is empty!")
            paymentResult = .failure("Payment configuration error")
            isProcessing = false
            return
        }

        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantIdentifier
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = [.capability3DS, .capabilityCredit, .capabilityDebit]
        request.countryCode = cartManager.country
        request.currencyCode = cartManager.currency
        
        print(
            "🌐 [ApplePayManager] PKPaymentRequest merchant=\(merchantIdentifier) country=\(request.countryCode) currency=\(request.currencyCode) canPay=\(PKPaymentAuthorizationController.canMakePayments()) canPayNetworks=\(PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks))"
        )
        
        // Validate country and currency codes
        if request.countryCode.count != 2 {
            print("⚠️ [ApplePayManager] Invalid country code: \(request.countryCode)")
        }
        if request.currencyCode.count != 3 {
            print("⚠️ [ApplePayManager] Invalid currency code: \(request.currencyCode)")
        }
        
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
            // Check for common presentation failures
            print("❌ [ApplePayManager] Failed to present Apple Pay sheet")
            
            // Run specific diagnostics for merchant identifier issues
            await diagnoseMerchantIdentifierIssues()
            
            VioLogger.error("Failed to present PKPaymentAuthorizationController", component: "ApplePayManager")
            self.paymentResult = .failure("Apple Pay is not properly configured for this app. Please contact support.")
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

        // Validate Stripe configuration before attempting tokenization
        guard let publishableKey = STPAPIClient.shared.publishableKey, !publishableKey.isEmpty else {
            print("❌ [ApplePayManager] stripe key missing at tokenization stage")
            paymentResult = .failure("Missing backend Stripe credentials")
            return false
        }

        print(
            "🔍 [ApplePayManager] tokenize start merchant=\(merchantIdentifier) publishableKey=\(maskedStripeKey(publishableKey)) network=\(payment.token.paymentMethod.network?.rawValue ?? "unknown") paymentDataBytes=\(payment.token.paymentData.count)"
        )
        if payment.token.paymentData.isEmpty {
            // In some Apple Pay test/simulator flows, `paymentData` can be empty while
            // Stripe still produces a valid test token (`tok_*`). Do not hard-fail here.
            print("⚠️ [ApplePayManager] Payment token data is empty; continuing with Stripe tokenization...")
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
            print("✅ [ApplePayManager] tokenize ok token=\(maskedToken(stripeToken))")
        } catch {
            let nsError = error as NSError
            print(
                "❌ [ApplePayManager] tokenize fail domain=\(nsError.domain) code=\(nsError.code) requestId=\((nsError.userInfo["com.stripe.lib:StripeRequestIDKey"] as? String) ?? "-") message=\(error.localizedDescription)"
            )
            VioLogger.error("Stripe Tokenization Error: \(error.localizedDescription)", component: "ApplePayManager")
            let errorMessage: String
            if nsError.domain == "com.stripe.lib" && nsError.code == 50 {
                errorMessage = "Apple Pay is not properly configured. Please contact support."
            } else if nsError.localizedDescription.contains("merchant") {
                errorMessage = "Merchant configuration error. Please contact support."
            } else if nsError.localizedDescription.contains("decrypt") {
                errorMessage = "Apple Pay certificate error. Please contact support."
            } else {
                errorMessage = "Payment verification failed. Please try again."
            }
            
            paymentResult = .failure(errorMessage)
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
            print(
                "🌐 [ApplePayManager] applePayConfirm request checkoutId=\(finalId) token=\(maskedToken(stripeToken)) shippingPresent=\(shippingAddressInput != nil)"
            )
            let confirmDto = try await cartManager.sdk.payment.applePayConfirm(
                checkoutId: finalId,
                applePayToken: stripeToken,
                email: capturedContact?.emailAddress,
                shippingAddress: shippingAddressInput
            )
            print("🌐 [ApplePayManager] applePayConfirm response status=\(confirmDto.status ?? "nil")")
            
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
    
    /// Attempts to process Apple Pay payment without Stripe tokenization
    /// Some backends can handle Apple Pay tokens directly
    private func processPaymentWithoutStripe(payment: PKPayment, cartManager: CartManager, checkoutId: String) async -> Bool {
        print("🔄 [ApplePayManager] Attempting payment without Stripe tokenization...")
        
        // Convert PKPayment token to base64 for direct backend processing
        let paymentData = payment.token.paymentData
        let base64PaymentData = paymentData.base64EncodedString()
        
        print("🔍 [ApplePayManager] Direct payment data:")
        print("  - Payment data length: \(paymentData.count) bytes")
        print("  - Base64 length: \(base64PaymentData.count) characters")
        print("  - Payment network: \(payment.token.paymentMethod.network?.rawValue ?? "unknown")")
        
        // Prepare shipping address
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
        
        // Try to confirm with the raw Apple Pay token instead of Stripe token
        do {
            cartManager.syncSdkCredentials()
            print("🌐 [ApplePayManager] applePayConfirm with raw token (checkoutId: \(checkoutId))...")
            
            // Use the base64 encoded payment data as the token
            let confirmDto = try await cartManager.sdk.payment.applePayConfirm(
                checkoutId: checkoutId,
                applePayToken: base64PaymentData,
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
            print("🛑 [ApplePayManager] applePayConfirm with raw token failed: \(error.localizedDescription)")
            print("   Backend might not support direct Apple Pay token processing")
            
            // Final fallback - return a descriptive error
            paymentResult = .failure("Payment system configuration error. Please contact support.")
            return false
        }
    }
    
    /// Diagnoses merchant identifier configuration issues
    private func diagnoseMerchantIdentifierIssues() async {
        print("🚨 [ApplePayManager] Merchant Identifier Configuration Issues:")
        print("📋 Current Configuration:")
        print("   - Merchant ID: \(merchantIdentifier)")
        print("   - Build: \(isDebugBuild ? "DEBUG" : "RELEASE")")
        
        print("🔍 Entitlement Check:")
        // Check if we can create a payment request (this will validate entitlements)
        let testRequest = PKPaymentRequest()
        testRequest.merchantIdentifier = merchantIdentifier
        testRequest.supportedNetworks = [.visa] // Minimal network for testing
        testRequest.merchantCapabilities = [.capability3DS]
        testRequest.countryCode = "US"
        testRequest.currencyCode = "USD"
        testRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: "Test", amount: NSDecimalNumber(value: 1.0))]
        
        let canAuthorize = PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.visa])
        print("   - Can make payments: \(canAuthorize)")
        
        print("🛠️ Required Fix:")
        print("   ❌ PROBLEM: Your app doesn't have entitlement for '\(merchantIdentifier)'")
        print("")
        print("   ✅ SOLUTION: Follow these steps:")
        print("   1. Open your project in Xcode")
        print("   2. Select your app target")
        print("   3. Go to 'Signing & Capabilities' tab")
        print("   4. Add 'Apple Pay' capability if not present")
        print("   5. Configure the merchant identifier:")
        print("      - Click '+' to add merchant ID")
        print("      - Enter: \(merchantIdentifier)")
        print("      - Or use an existing one from your Apple Developer account")
        print("")
        print("   📝 Alternative: Update the merchant ID to match your entitlements")
        print("      - Check what merchant IDs are configured in your app")
        print("      - Update the code to use a valid merchant ID")
        print("")
        print("   🌐 Apple Developer Console:")
        print("      - Verify '\(merchantIdentifier)' exists at:")
        print("      - https://developer.apple.com/account/resources/identifiers/list/merchant")
        print("      - Create it if it doesn't exist")
        
        // Try to suggest alternative merchant IDs based on bundle identifier
        if let bundleId = Bundle.main.bundleIdentifier {
            let suggestedMerchant = "merchant.\(bundleId)"
            print("")
            print("   💡 Suggested merchant ID based on bundle: \(suggestedMerchant)")
        }
    }

    private func isValidAppleMerchantIdentifier(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("merchant.") && trimmed.count > "merchant.".count
    }

    private func maskedStripeKey(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "nil" }
        return "\(key.prefix(14))...\(key.suffix(4))"
    }

    private func maskedToken(_ token: String) -> String {
        guard token.count > 12 else { return token }
        return "\(token.prefix(8))...\(token.suffix(4))"
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
