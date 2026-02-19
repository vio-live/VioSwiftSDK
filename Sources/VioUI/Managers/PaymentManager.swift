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

    @discardableResult
    public func initKlarnaNative(
        input: KlarnaNativeInitInputDto
    ) async -> InitPaymentKlarnaNativeDto? {
        VioLogger.debug("initKlarnaNative MÉTODO LLAMADO - Thread: \(Thread.current)", component: "PaymentManager")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let id: String?
        if let passed = checkoutId, !passed.isEmpty {
            id = passed
        } else {
            id = await createCheckout()
        }

        guard let checkout = id, !checkout.isEmpty else {
            VioLogger.error("KlarnaNativeInit: missing checkoutId - checkoutId actual: \(String(describing: checkoutId)), id después de createCheckout: \(String(describing: id))", component: "PaymentManager")
            return nil
        }

        VioLogger.debug("KlarnaNativeInit START - checkoutId: \(checkout), countryCode: \(input.countryCode), currency: \(input.currency), locale: \(input.locale), customer.email: \(input.customer?.email ?? "nil"), customer.phone: \(input.customer?.phone ?? "nil")", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.klarnaNativeInit",
                payload: [
                    "checkoutId": checkout,
                    "autoCapture": input.autoCapture as Any
                ]
            )
            let dto = try await sdk.payment.klarnaNativeInit(
                checkoutId: checkout,
                input: input
            )
            checkoutId = dto.checkoutId
            logResponse(
                "sdk.payment.klarnaNativeInit",
                payload: ["sessionId": dto.sessionId, "checkoutId": dto.checkoutId]
            )
            VioLogger.success("KlarnaNativeInit OK sessionId=\(dto.sessionId)", component: "PaymentManager")
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
        shippingAddress: KlarnaNativeAddressInputDto? = nil
    ) async -> ConfirmPaymentKlarnaNativeDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let id: String?
        if let passed = checkoutId, !passed.isEmpty {
            id = passed
        } else {
            id = await createCheckout()
        }

        guard let checkout = id, !checkout.isEmpty else {
            VioLogger.info("KlarnaNativeConfirm: missing checkoutId", component: "PaymentManager")
            return nil
        }

        let input = KlarnaNativeConfirmInputDto(
            authorizationToken: authorizationToken,
            autoCapture: autoCapture,
            customer: customer,
            billingAddress: billingAddress,
            shippingAddress: shippingAddress
        )

        VioLogger.debug("KlarnaNativeConfirm START checkoutId=\(checkout)", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.klarnaNativeConfirm",
                payload: [
                    "checkoutId": checkout,
                    "authorizationToken": authorizationToken
                ]
            )
            let dto = try await sdk.payment.klarnaNativeConfirm(
                checkoutId: checkout,
                input: input
            )
            logResponse(
                "sdk.payment.klarnaNativeConfirm",
                payload: ["orderId": dto.orderId as Any]
            )
            VioLogger.success("KlarnaNativeConfirm OK orderId=\(dto.orderId)", component: "PaymentManager")
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
    public func stripeIntent(returnEphemeralKey: Bool? = true) async -> PaymentIntentStripeDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let id: String?
        if let passed = checkoutId, !passed.isEmpty {
            id = passed
        } else {
            id = await createCheckout()
        }

        guard let checkout = id else {
            VioLogger.info("StripeIntent: missing checkoutId", component: "PaymentManager")
            return nil
        }

        VioLogger.debug("StripeIntent START checkoutId=\(checkout)", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.stripeIntent",
                payload: [
                    "checkoutId": checkout,
                    "returnEphemeralKey": returnEphemeralKey as Any
                ]
            )
            let dto = try await sdk.payment.stripeIntent(
                checkoutId: checkout,
                returnEphemeralKey: returnEphemeralKey
            )
            logResponse(
                "sdk.payment.stripeIntent",
                payload: ["clientSecret": dto.clientSecret as Any]
            )
            VioLogger.success("StripeIntent OK", component: "PaymentManager")
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
        email: String
    ) async -> InitPaymentStripeDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let id: String?
        if let passed = checkoutId, !passed.isEmpty {
            id = passed
        } else {
            id = await createCheckout()
        }

        guard let checkout = id else {
            VioLogger.info("StripeLink: missing checkoutId", component: "PaymentManager")
            return nil
        }

        VioLogger.debug("StripeLink START checkoutId=\(checkout)", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.stripeLink",
                payload: [
                    "checkoutId": checkout,
                    "successUrl": successUrl,
                    "paymentMethod": paymentMethod,
                    "email": email
                ]
            )
            let dto = try await sdk.payment.stripeLink(
                checkoutId: checkout,
                successUrl: successUrl,
                paymentMethod: paymentMethod,
                email: email
            )
            logResponse("sdk.payment.stripeLink")
            VioLogger.success("StripeLink OK", component: "PaymentManager")
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
        returnUrl: String
    ) async -> InitPaymentVippsDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let id: String?
        if let passed = checkoutId, !passed.isEmpty {
            id = passed
        } else {
            id = await createCheckout()
        }

        guard let checkout = id else {
            VioLogger.info("VippsInit: missing checkoutId", component: "PaymentManager")
            return nil
        }

        VioLogger.debug("VippsInit START checkoutId=\(checkout)", component: "PaymentManager")
        do {
            logRequest(
                "sdk.payment.vippsInit",
                payload: [
                    "checkoutId": checkout,
                    "email": email,
                    "returnUrl": returnUrl
                ]
            )
            let dto = try await sdk.payment.vippsInit(
                checkoutId: checkout,
                email: email,
                returnUrl: returnUrl
            )
            logResponse("sdk.payment.vippsInit")
            VioLogger.success("VippsInit OK", component: "PaymentManager")
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
