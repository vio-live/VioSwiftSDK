import Foundation
import VioCore

@MainActor
extension CartManager {

    @discardableResult
    public func initKlarna(countryCode: String, href: String, email: String?) async
        -> InitPaymentKlarnaDto?
    {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard await ensurePaymentRuntimeReady(component: "PaymentManager") else { return nil }

        let id: String?
        if let passed = checkoutId, !passed.isEmpty {
            id = passed
        } else {
            id = await createCheckout()
        }

        guard let checkout = id else {
            VioLogger.info("KlarnaInit: missing checkoutId", component: "PaymentManager")
            return nil
        }

        VioLogger.debug("KlarnaInit START checkoutId=\(checkout)", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.klarnaInit",
                payload: [
                    "checkoutId": checkout,
                    "countryCode": countryCode,
                    "href": href,
                    "email": email as Any
                ]
            )
            let dto = try await sdk.payment.klarnaInit(
                checkoutId: checkout,
                countryCode: countryCode,
                href: href,
                email: email
            )
            logResponse("sdk.payment.klarnaInit")
            VioLogger.success("KlarnaInit OK", component: "PaymentManager")
            return dto
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.payment.klarnaInit", error: error)
            VioLogger.error("KlarnaInit FAIL \(msg)", component: "PaymentManager")
            return nil
        }
    }

    /// Q4 L4 (2026-05-06): resolves the (sdk, checkoutId) pair for a
    /// payment method call. When `sponsorId` is set, both come from
    /// the sponsor's SDK + sponsor cart (channel isolation). When nil,
    /// falls back to the legacy `cartManager.sdk` + `cartManager.checkoutId`.
    /// Used by the new sponsor-aware Klarna / Vipps / Stripe handlers
    /// below so each one routes through the right Commerce channel.
    internal func resolvePaymentTarget(
        sponsorId: Int?,
        component: String
    ) async -> (sdk: CartManagingSDK, checkoutId: String)? {
        // 1. Resolve checkoutId
        let resolvedCheckoutId: String?
        if let sid = sponsorId {
            // Q4 L4 mirror correction (2026-05-08): when we're already
            // scoped to this sponsor (`activeCheckoutSponsorId == sid`),
            // the legacy `checkoutId` field has been populated by the step
            // flow's createCheckout + updateCheckout (address bound).
            // Prefer it over `sponsorCart.checkoutId` which is only synced
            // back on `exitSponsorCheckoutScope`. Without this, Stripe /
            // Klarna would create a SECOND empty checkout via
            // `createCheckout(forSponsor:)` — with no address bound — and
            // Reachu's `CreatePaymentIntentStripe` 500s because the
            // checkout is missing customer/billing data.
            //
            // Apple Pay flow doesn't hit this because it bypasses the
            // step flow and calls `createCheckout(forSponsor:)` directly
            // before `applePayInit`, then collects address via PKContact.
            //
            // Once Fase 2 retires the mirror entirely (step views read
            // `sponsorCart` directly), this whole branch collapses.
            if activeCheckoutSponsorId == sid,
               let scopedLegacy = checkoutId, !scopedLegacy.isEmpty {
                resolvedCheckoutId = scopedLegacy
                print("🟣 [Q4-DIAG payment-resolve REUSE-SCOPED-CHECKOUT] sponsorId=\(sid) checkoutId=\(scopedLegacy) (from step flow)")
            } else if let cid = sponsorCart(forSponsorId: sid)?.checkoutId, !cid.isEmpty {
                resolvedCheckoutId = cid
            } else {
                resolvedCheckoutId = await createCheckout(forSponsor: sid)
            }
        } else if let passed = checkoutId, !passed.isEmpty {
            resolvedCheckoutId = passed
        } else {
            resolvedCheckoutId = await createCheckout()
        }

        guard let checkout = resolvedCheckoutId, !checkout.isEmpty else {
            VioLogger.error("\(component): missing checkoutId (sponsorId=\(sponsorId.map(String.init) ?? "nil"))", component: "PaymentManager")
            return nil
        }

        // 2. Resolve SDK (sponsor's per-channel client when sponsorId set)
        let activeSdk: CartManagingSDK
        if let sid = sponsorId, let sponsorSdk = resolveSponsorSdk(forSponsorId: sid) {
            activeSdk = sponsorSdk
            print("🟣 [Q4-DIAG payment-resolve] component=\(component) sponsorId=\(sid) using sponsor SDK + checkoutId=\(checkout)")
        } else {
            activeSdk = sdk
            print("🟣 [Q4-DIAG payment-resolve] component=\(component) sponsorId=nil using legacy SDK + checkoutId=\(checkout)")
        }

        return (activeSdk, checkout)
    }

    @discardableResult
    public func initKlarnaNative(
        input: KlarnaNativeInitInputDto,
        sponsorId: Int? = nil
    ) async -> InitPaymentKlarnaNativeDto? {
        VioLogger.debug("initKlarnaNative MÉTODO LLAMADO - Thread: \(Thread.current) sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard await ensurePaymentRuntimeReady(component: "PaymentManager") else { return nil }

        guard let target = await resolvePaymentTarget(sponsorId: sponsorId, component: "KlarnaNativeInit") else {
            return nil
        }
        let activeSdk = target.sdk
        let checkout = target.checkoutId

        VioLogger.debug("KlarnaNativeInit START - checkoutId: \(checkout), sponsorId: \(sponsorId.map(String.init) ?? "nil"), countryCode: \(input.countryCode), currency: \(input.currency), locale: \(input.locale), customer.email: \(input.customer?.email ?? "nil"), customer.phone: \(input.customer?.phone ?? "nil")", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.klarnaNativeInit",
                payload: [
                    "checkoutId": checkout,
                    "sponsorId": sponsorId as Any,
                    "autoCapture": input.autoCapture as Any
                ]
            )
            let dto = try await activeSdk.payment.klarnaNativeInit(
                checkoutId: checkout,
                input: input
            )
            // Only mirror to the legacy `cartManager.checkoutId` when this
            // was a legacy (non-sponsor) call — the sponsor cart already
            // owns its checkoutId via `createCheckout(forSponsor:)`.
            if sponsorId == nil {
                checkoutId = dto.checkoutId
            }
            logResponse(
                "sdk.payment.klarnaNativeInit",
                payload: ["sessionId": dto.sessionId, "checkoutId": dto.checkoutId]
            )
            VioLogger.success("KlarnaNativeInit OK sessionId=\(dto.sessionId) sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
            return dto
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.payment.klarnaNativeInit", error: error)
            if let sdkError = error as? SdkException {
                VioLogger.error("KlarnaNativeInit FAIL - Type: \(type(of: error)), Message: \(msg), SdkException: \(sdkError.description)", component: "PaymentManager")
            } else {
                VioLogger.error("KlarnaNativeInit FAIL - Type: \(type(of: error)), Message: \(msg)", component: "PaymentManager")
            }
            return nil
        }
    }

    @discardableResult
    public func confirmKlarnaNative(
        authorizationToken: String,
        autoCapture: Bool? = nil,
        customer: KlarnaNativeCustomerInputDto? = nil,
        billingAddress: KlarnaNativeAddressInputDto? = nil,
        shippingAddress: KlarnaNativeAddressInputDto? = nil,
        sponsorId: Int? = nil
    ) async -> ConfirmPaymentKlarnaNativeDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard await ensurePaymentRuntimeReady(component: "PaymentManager") else { return nil }

        guard let target = await resolvePaymentTarget(sponsorId: sponsorId, component: "KlarnaNativeConfirm") else {
            return nil
        }
        let activeSdk = target.sdk
        let checkout = target.checkoutId

        let input = KlarnaNativeConfirmInputDto(
            authorizationToken: authorizationToken,
            autoCapture: autoCapture,
            customer: customer,
            billingAddress: billingAddress,
            shippingAddress: shippingAddress
        )

        VioLogger.debug("KlarnaNativeConfirm START checkoutId=\(checkout) sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.klarnaNativeConfirm",
                payload: [
                    "checkoutId": checkout,
                    "sponsorId": sponsorId as Any,
                    "authorizationToken": authorizationToken
                ]
            )
            let dto = try await activeSdk.payment.klarnaNativeConfirm(
                checkoutId: checkout,
                input: input
            )
            logResponse(
                "sdk.payment.klarnaNativeConfirm",
                payload: ["orderId": dto.orderId as Any]
            )
            VioLogger.success("KlarnaNativeConfirm OK orderId=\(dto.orderId) sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
            return dto
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.payment.klarnaNativeConfirm", error: error)
            VioLogger.error("KlarnaNativeConfirm FAIL \(msg)", component: "PaymentManager")
            return nil
        }
    }

    public func klarnaNativeOrder(
        orderId: String,
        userId: String? = nil
    ) async -> KlarnaNativeOrderDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        VioLogger.debug("KlarnaNativeOrder START orderId=\(orderId)", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.klarnaNativeOrder",
                payload: ["orderId": orderId, "userId": userId as Any]
            )
            let dto = try await sdk.payment.klarnaNativeOrder(
                orderId: orderId,
                userId: userId
            )
            logResponse(
                "sdk.payment.klarnaNativeOrder",
                payload: ["status": dto.status as Any]
            )
            VioLogger.success("KlarnaNativeOrder OK status=\(dto.status ?? "-")", component: "PaymentManager")
            return dto
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.payment.klarnaNativeOrder", error: error)
            VioLogger.error("KlarnaNativeOrder FAIL \(msg)", component: "PaymentManager")
            return nil
        }
    }

    @discardableResult
    public func stripeIntent(
        returnEphemeralKey: Bool? = true,
        sponsorId: Int? = nil
    ) async -> PaymentIntentStripeDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard await ensurePaymentRuntimeReady(component: "PaymentManager") else { return nil }

        guard let target = await resolvePaymentTarget(sponsorId: sponsorId, component: "StripeIntent") else {
            return nil
        }
        let activeSdk = target.sdk
        let checkout = target.checkoutId

        VioLogger.debug("StripeIntent START checkoutId=\(checkout) sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.stripeIntent",
                payload: [
                    "checkoutId": checkout,
                    "sponsorId": sponsorId as Any,
                    "returnEphemeralKey": returnEphemeralKey as Any
                ]
            )
            let dto = try await activeSdk.payment.stripeIntent(
                checkoutId: checkout,
                returnEphemeralKey: returnEphemeralKey
            )
            logResponse(
                "sdk.payment.stripeIntent",
                payload: ["clientSecret": dto.clientSecret as Any]
            )
            VioLogger.success("StripeIntent OK sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
            return dto
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.payment.stripeIntent", error: error)
            VioLogger.error("StripeIntent FAIL \(msg)", component: "PaymentManager")
            return nil
        }
    }

    @discardableResult
    public func stripeLink(
        successUrl: String,
        paymentMethod: String,
        email: String,
        sponsorId: Int? = nil
    ) async -> InitPaymentStripeDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard await ensurePaymentRuntimeReady(component: "PaymentManager") else { return nil }

        guard let target = await resolvePaymentTarget(sponsorId: sponsorId, component: "StripeLink") else {
            return nil
        }
        let activeSdk = target.sdk
        let checkout = target.checkoutId

        VioLogger.debug("StripeLink START checkoutId=\(checkout) sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.stripeLink",
                payload: [
                    "checkoutId": checkout,
                    "sponsorId": sponsorId as Any,
                    "successUrl": successUrl,
                    "paymentMethod": paymentMethod,
                    "email": email
                ]
            )
            let dto = try await activeSdk.payment.stripeLink(
                checkoutId: checkout,
                successUrl: successUrl,
                paymentMethod: paymentMethod,
                email: email
            )
            logResponse("sdk.payment.stripeLink")
            VioLogger.success("StripeLink OK sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
            return dto
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.payment.stripeLink", error: error)
            VioLogger.error("StripeLink FAIL \(msg)", component: "PaymentManager")
            return nil
        }
    }

    @discardableResult
    public func vippsInit(
        email: String,
        returnUrl: String,
        sponsorId: Int? = nil
    ) async -> InitPaymentVippsDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard await ensurePaymentRuntimeReady(component: "PaymentManager") else { return nil }

        guard let target = await resolvePaymentTarget(sponsorId: sponsorId, component: "VippsInit") else {
            return nil
        }
        let activeSdk = target.sdk
        let checkout = target.checkoutId

        VioLogger.debug("VippsInit START checkoutId=\(checkout) sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.vippsInit",
                payload: [
                    "checkoutId": checkout,
                    "sponsorId": sponsorId as Any,
                    "email": email,
                    "returnUrl": returnUrl
                ]
            )
            let dto = try await activeSdk.payment.vippsInit(
                checkoutId: checkout,
                email: email,
                returnUrl: returnUrl
            )
            logResponse("sdk.payment.vippsInit")
            VioLogger.success("VippsInit OK sponsorId=\(sponsorId.map(String.init) ?? "nil")", component: "PaymentManager")
            return dto
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.payment.vippsInit", error: error)
            VioLogger.error("VippsInit FAIL \(msg)", component: "PaymentManager")
            return nil
        }
    }
}
