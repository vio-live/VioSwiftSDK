import Foundation
import VioCore
import SwiftUI

public protocol CartManagingSDK {
    var cart: CartRepository { get }
    var product: ProductRepository { get }
    var checkout: CheckoutRepository { get }
    var payment: PaymentRepository { get }
    var discount: DiscountRepository { get }
    var market: MarketRepository { get }
}

extension SdkClient: CartManagingSDK {
    public var product: ProductRepository { channel.product }
}

@MainActor
public class CartManager: ObservableObject, LiveShowCartManaging {

    @Published public var items: [CartItem] = []
    @Published public var isCheckoutPresented = false
    @Published public var isLoading = false
    @Published public var cartTotal: Double = 0.0
    @Published public var currency: String = "USD"
    @Published public var country: String = "US"
    @Published public var errorMessage: String?
    @Published public var cartId: String?
    @Published public var checkoutId: String?
    @Published public var lastDiscountCode: String?
    @Published public var lastDiscountId: Int?
    @Published public var products: [Product] = []
    @Published public var isProductsLoading = false
    @Published public var productsErrorMessage: String?
    @Published public var shippingTotal: Double = 0.0
    @Published public var shippingCurrency: String = "USD"
    @Published public var markets: [Market] = []
    @Published public var selectedMarket: Market?
    @Published public var currencySymbol: String = "$"
    @Published public var phoneCode: String = "+1"
    @Published public var flagURL: String?

    internal var currentCartId: String?
    internal var pendingShippingSelections: [String: CartItem.ShippingOption] = [:]
    internal var didLoadMarkets = false
    internal var activeProductRequestID: UUID?
    internal var lastLoadedProductCurrency: String?
    internal var lastLoadedProductCountry: String?

    internal let sdk: CartManagingSDK

    public init(
        sdk: CartManagingSDK? = nil,
        configuration: VioConfiguration = .shared,
        autoBootstrap: Bool = true
    ) {
        if let provided = sdk {
            self.sdk = provided
        } else {
            let baseURL = URL(string: configuration.environment.graphQLURL)!
            let apiKey = configuration.apiKey.isEmpty ? "DEMO_KEY" : configuration.apiKey

            VioLogger.debug("Initializing SDK Client - Base URL: \(baseURL), API Key: \(apiKey.prefix(8))...", component: "CartManager")

            self.sdk = SdkClient(baseUrl: baseURL, apiKey: apiKey)
        }

        let fallback = configuration.marketConfiguration
        let fallbackMarket = Market(
            code: fallback.countryCode,
            name: fallback.countryName,
            officialName: fallback.countryName,
            flagURL: fallback.flagURL,
            phoneCode: fallback.phoneCode,
            currencyCode: fallback.currencyCode,
            currencySymbol: fallback.currencySymbol
        )

        markets = [fallbackMarket]
        selectedMarket = fallbackMarket
        country = fallback.countryCode
        currency = fallback.currencyCode
        currencySymbol = fallback.currencySymbol
        phoneCode = fallback.phoneCode
        flagURL = fallback.flagURL
        shippingCurrency = fallback.currencyCode

        if autoBootstrap {
            Task { [currency, country] in
                // Check if SDK should be used before attempting operations
                guard VioConfiguration.shared.shouldUseSDK else {
                    VioLogger.warning("Skipping cart creation - SDK disabled (market not available)", component: "CartManager")
                    return
                }
                
                VioLogger.debug("init → scheduling createCart(currency:\(currency), country:\(country))", component: "CartManager")
                await createCart(currency: currency, country: country)
                await loadMarketsIfNeeded()
            }
        }
    }

    public func showCheckout() {
        isCheckoutPresented = true
    }

    public func hideCheckout() {
        isCheckoutPresented = false
    }

    internal func iso8601String(from date: Date = Date()) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    internal func logRequest(_ action: String, payload: Any? = nil) {
        if let payload = payload {
            VioLogger.debug("REQUEST: \(action) - Payload: \(String(describing: payload))", component: "CartManager")
        } else {
            VioLogger.debug("REQUEST: \(action)", component: "CartManager")
        }
    }

    internal func logResponse(_ action: String, payload: Any? = nil) {
        if let payload = payload {
            VioLogger.debug("\(action) response: \(String(describing: payload))", component: "CartManager")
        } else {
            VioLogger.debug("\(action) response", component: "CartManager")
        }
    }

    internal func logError(_ action: String, error: Error) {
        VioLogger.error("ERROR: \(action) - Type: \(type(of: error)), Message: \(error.localizedDescription)", component: "CartManager")
    }

    public func getCheckoutStatus(_ checkoutId: String) async -> Bool {
        VioLogger.debug("getCheckoutStatus() with checkoutId: \(checkoutId)", component: "CartManager")

        do {
            let result: GetCheckoutDto = try await sdk.checkout.getById(checkout_id: checkoutId);
            VioLogger.debug("getCheckoutStatus() result: \(result)", component: "CartManager")

            // ✅ Here you validate if Vipps already paid
            if result.status == "SUCCESS" {
                VioLogger.success("Payment confirmed in backend", component: "CartManager")
                return true
            } else {
                VioLogger.debug("Still unpaid: \(result.status)", component: "CartManager")
                return false
            }

        } catch {
            logError("getCheckoutStatus", error: error)
            return false
        }
    }
}

