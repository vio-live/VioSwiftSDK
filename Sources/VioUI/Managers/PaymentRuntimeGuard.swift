import Foundation
import VioCore

@MainActor
extension CartManager {
    @discardableResult
    internal func ensurePaymentRuntimeReady(component: String) async -> Bool {
        // Defensive bootstrap: only fire if commerce credentials haven't
        // been applied yet (fresh install or auth invalidation). The
        // launch-time bootstrap already populated `sdkBootstrapCommerceApiKey`
        // on a normal session, so re-firing here would be a wasted
        // round-trip that, on iOS 17+/26 in particular, has been
        // observed to deadlock with concurrent payment-flow Tasks at
        // `await MainActor.run` inside the bootstrap success path.
        let cfg = VioConfiguration.shared
        let bootstrapApplied = (cfg.sdkBootstrapCommerceApiKey?.isEmpty == false)
        if !bootstrapApplied {
            await VioUIRuntimeAdapter.controller.ensureCommerceBootstrapApplied()
        }
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
