import Foundation
import SwiftUI

@MainActor
extension CartManager {

    // MARK: - Market Model
    public struct Market: Identifiable, Equatable {
        public let id: String
        public let code: String
        public let name: String
        public let officialName: String?
        public let flagURL: String?
        public let phoneCode: String
        public let currencyCode: String
        public let currencySymbol: String

        public init(
            code: String,
            name: String,
            officialName: String? = nil,
            flagURL: String? = nil,
            phoneCode: String,
            currencyCode: String,
            currencySymbol: String
        ) {
            self.id = code
            self.code = code
            self.name = name
            self.officialName = officialName
            self.flagURL = flagURL
            self.phoneCode = phoneCode
            self.currencyCode = currencyCode
            self.currencySymbol = currencySymbol
        }
    }

    // MARK: - Cart Item Model
    public struct CartItem: Identifiable, Equatable {

        public struct ShippingOption: Identifiable, Equatable {
            public let id: String
            public let name: String
            public let description: String?
            public let amount: Double
            public let currency: String

            public init(
                id: String,
                name: String,
                description: String? = nil,
                amount: Double,
                currency: String
            ) {
                self.id = id
                self.name = name
                self.description = description
                self.amount = amount
                self.currency = currency
            }
        }

        public let id: String
        public let productId: Int
        public let variantId: String?
        public let variantTitle: String?
        public let title: String
        public let brand: String?
        public let imageUrl: String?
        public let price: Double
        public let currency: String
        public var quantity: Int
        public let sku: String?
        public let supplier: String?
        public let shippingId: String?
        public let shippingName: String?
        public let shippingDescription: String?
        public let shippingAmount: Double?
        public let shippingCurrency: String?
        public let availableShippings: [ShippingOption]

        public init(
            id: String,
            productId: Int,
            variantId: String? = nil,
            variantTitle: String? = nil,
            title: String,
            brand: String? = nil,
            imageUrl: String? = nil,
            price: Double,
            currency: String,
            quantity: Int,
            sku: String? = nil,
            supplier: String? = nil,
            shippingId: String? = nil,
            shippingName: String? = nil,
            shippingDescription: String? = nil,
            shippingAmount: Double? = nil,
            shippingCurrency: String? = nil,
            availableShippings: [ShippingOption] = []
        ) {
            self.id = id
            self.productId = productId
            self.variantId = variantId
            self.variantTitle = variantTitle
            self.title = title
            self.brand = brand
            self.imageUrl = imageUrl
            self.price = price
            self.currency = currency
            self.quantity = quantity
            self.sku = sku
            self.supplier = supplier
            self.shippingId = shippingId
            self.shippingName = shippingName
            self.shippingDescription = shippingDescription
            self.shippingAmount = shippingAmount
            self.shippingCurrency = shippingCurrency
            self.availableShippings = availableShippings
        }
    }

    // MARK: - Cart Errors
    public enum CartError: LocalizedError {
        case noCartId
        case productNotFound
        case invalidQuantity

        public var errorDescription: String? {
            switch self {
            case .noCartId:
                return "No cart ID available"
            case .productNotFound:
                return "Product not found"
            case .invalidQuantity:
                return "Invalid quantity"
            }
        }
    }
}
