import Foundation
import VioCore

/// Product fetcher implementation that uses ProductService (same path as carousel).
/// Ensures openProduct overlay shows identical data to carousel.
@MainActor
final class ProductServiceProductFetcher: VioSDKProductFetcher {

    func fetchProduct(id: String, currency: String, country: String) async -> Product? {
        do {
            return try await ProductService.shared.loadProduct(
                productId: id,
                currency: currency,
                country: country
            )
        } catch {
            VioLogger.warning("ProductServiceProductFetcher failed for id=\(id): \(error)", component: "VioUI+OpenProduct")
            return nil
        }
    }
}

/// Registers ProductServiceProductFetcher with VioSDK. Call early (e.g. from ContentView onAppear)
/// so openProduct uses ProductService (same query as carousel) instead of CommerceProductFetcher.
@MainActor
public func registerVioOpenProductFetcherIfNeeded() {
    guard !VioOpenProductRegistration.hasRegistered else { return }
    VioOpenProductRegistration.hasRegistered = true
    VioSDK.registerProductFetcher(ProductServiceProductFetcher())
}

private enum VioOpenProductRegistration {
    static var hasRegistered = false
}
