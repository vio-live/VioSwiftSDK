import Foundation
import VioCore

@MainActor
extension CartManager {
    @discardableResult
    internal func ensurePaymentRuntimeReady(component: String) async -> Bool {
        await VioUIRuntimeAdapter.controller.ensureCommerceBootstrapApplied()
        syncSdkCredentials()
        guard let cid = await ensureCartIDForCheckout(), !cid.isEmpty else {
            errorMessage = "Cart is not ready for payment."
            VioLogger.warning(
                "Payment runtime not ready: missing cartId",
                component: component)
            return false
        }
        return true
    }
}
