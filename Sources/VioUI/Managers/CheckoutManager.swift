import Foundation
import VioCore

@MainActor
extension CartManager {

    @discardableResult
    public func createCheckout() async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let cid = await ensureCartIDForCheckout() else {
            VioLogger.info("Create: missing cartId", component: "CheckoutManager")
            return nil
        }

        VioLogger.debug("Create START cartId=\(cid)", component: "CheckoutManager")
        do {
            logRequest("sdk.checkout.create", payload: ["cart_id": cid])
            let dto = try await sdk.checkout.create(cart_id: cid)
            let chkId = extractCheckoutId(dto)
            checkoutId = chkId
            logResponse(
                "sdk.checkout.create",
                payload: ["checkoutId": chkId as Any]
            )
            VioLogger.success("Create OK checkoutId=\(chkId ?? "nil")", component: "CheckoutManager")
            return chkId
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.checkout.create", error: error)
            VioLogger.error("Create FAIL \(msg)", component: "CheckoutManager")
            return nil
        }
    }

    @discardableResult
    public func updateCheckout(
        checkoutId: String? = nil,
        email: String? = nil,
        successUrl: String? = nil,
        cancelUrl: String? = nil,
        paymentMethod: String? = nil,
        shippingAddress: [String: Any]? = nil,
        billingAddress: [String: Any]? = nil,
        acceptsTerms: Bool = true,
        acceptsPurchaseConditions: Bool = true
    ) async -> UpdateCheckoutDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let chkId: String?
        if let passed = checkoutId, !passed.isEmpty {
            chkId = passed
        } else {
            chkId = await createCheckout()
        }

        guard let id = chkId, !id.isEmpty else {
            VioLogger.info("Update: missing checkoutId", component: "CheckoutManager")
            return nil
        }

        VioLogger.debug("Update START checkoutId=\(id)", component: "CheckoutManager")
        do {
            logRequest(
                "sdk.checkout.update",
                payload: [
                    "checkout_id": id,
                    "email": email as Any,
                    "success_url": successUrl as Any,
                    "cancel_url": cancelUrl as Any,
                    "payment_method": paymentMethod as Any
                ]
            )
            let dto = try await sdk.checkout.update(
                checkout_id: id,
                status: nil,
                email: email,
                success_url: successUrl,
                cancel_url: cancelUrl,
                payment_method: paymentMethod,
                shipping_address: shippingAddress,
                billing_address: billingAddress,
                buyer_accepts_terms_conditions: acceptsTerms,
                buyer_accepts_purchase_conditions: acceptsPurchaseConditions
            )
            logResponse("sdk.checkout.update", payload: ["checkoutId": id])
            VioLogger.success("Update OK", component: "CheckoutManager")
            return dto
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.checkout.update", error: error)
            VioLogger.error("Update FAIL \(msg)", component: "CheckoutManager")
            return nil
        }
    }

    @discardableResult
    public func getCheckoutById(checkoutId: String) async -> GetCheckoutDto? {
        guard !checkoutId.isEmpty else {
            VioLogger.info("GetById: empty checkoutId", component: "CheckoutManager")
            return nil
        }

        VioLogger.debug("GetById START checkoutId=\(checkoutId)", component: "CheckoutManager")
        do {
            logRequest("sdk.checkout.getById", payload: ["checkout_id": checkoutId])
            let dto = try await sdk.checkout.getById(checkout_id: checkoutId)
            logResponse("sdk.checkout.getById", payload: ["status": dto.status as Any])
            VioLogger.success("GetById OK status=\(dto.status ?? "unknown")", component: "CheckoutManager")
            return dto
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            logError("sdk.checkout.getById", error: error)
            VioLogger.error("GetById FAIL \(msg)", component: "CheckoutManager")
            return nil
        }
    }

    internal func extractCheckoutId<T: Encodable>(_ dto: T) -> String? {
        guard
            let data = try? JSONEncoder().encode(dto),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return (dict["checkout_id"] as? String)
            ?? (dict["checkoutId"] as? String)
            ?? (dict["id"] as? String)
    }
}
