import Foundation

// MARK: - Placeholder Models
// These are temporary placeholder models that will be replaced with full implementations

/// Cart model placeholder
public struct Cart: Codable, Identifiable {
    public let id: String
    public let items: [CartItem]
    
    public init(id: String, items: [CartItem] = []) {
        self.id = id
        self.items = items
    }
}

/// Cart item model placeholder
public struct CartItem: Codable, Identifiable {
    public let id: String
    public let productId: Int
    public let quantity: Int
    
    public init(id: String, productId: Int, quantity: Int) {
        self.id = id
        self.productId = productId
        self.quantity = quantity
    }
}

/// Cart cost model placeholder
public struct CartCost: Codable {
    public let subtotal: Float
    public let tax: Float
    public let shipping: Float
    public let total: Float
    
    public init(subtotal: Float, tax: Float, shipping: Float, total: Float) {
        self.subtotal = subtotal
        self.tax = tax
        self.shipping = shipping
        self.total = total
    }
}


/// Checkout model placeholder
public struct Checkout: Codable, Identifiable {
    public let id: String
    public let cartId: String
    
    public init(id: String, cartId: String) {
        self.id = id
        self.cartId = cartId
    }
}

/// Address model placeholder
public struct Address: Codable {
    public let street: String
    public let city: String
    public let country: String
    
    public init(street: String, city: String, country: String) {
        self.street = street
        self.city = city
        self.country = country
    }
}

/// Shipping rate model placeholder
public struct ShippingRate: Codable, Identifiable {
    public let id: String
    public let name: String
    public let price: Float
    
    public init(id: String, name: String, price: Float) {
        self.id = id
        self.name = name
        self.price = price
    }
}

/// Checkout validation model placeholder
public struct CheckoutValidation: Codable {
    public let isValid: Bool
    public let errors: [String]
    
    public init(isValid: Bool, errors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
    }
}

/// Order model placeholder
public struct Order: Codable, Identifiable {
    public let id: String
    public let status: String
    
    public init(id: String, status: String) {
        self.id = id
        self.status = status
    }
}

/// Order tracking model placeholder
public struct OrderTracking: Codable {
    public let orderId: String
    public let status: String
    
    public init(orderId: String, status: String) {
        self.orderId = orderId
        self.status = status
    }
}

/// Order line model placeholder
public struct OrderLine: Codable, Identifiable {
    public let id: String
    public let productId: Int
    public let quantity: Int
    
    public init(id: String, productId: Int, quantity: Int) {
        self.id = id
        self.productId = productId
        self.quantity = quantity
    }
}

/// Return reason enum placeholder
public enum ReturnReason: String, Codable, CaseIterable {
    case defective = "defective"
    case wrongItem = "wrong_item"
    case notAsDescribed = "not_as_described"
    case other = "other"
}

/// Return request model placeholder
public struct ReturnRequest: Codable, Identifiable {
    public let id: String
    public let orderId: String
    public let reason: ReturnReason
    
    public init(id: String, orderId: String, reason: ReturnReason) {
        self.id = id
        self.orderId = orderId
        self.reason = reason
    }
}

/// Payment method model placeholder
public struct PaymentMethod: Codable, Identifiable {
    public let id: String
    public let type: String
    public let name: String
    
    public init(id: String, type: String, name: String) {
        self.id = id
        self.type = type
        self.name = name
    }
}

/// Payment model placeholder
public struct Payment: Codable, Identifiable {
    public let id: String
    public let status: PaymentStatus
    public let amount: Float
    
    public init(id: String, status: PaymentStatus, amount: Float) {
        self.id = id
        self.status = status
        self.amount = amount
    }
}

/// Payment status enum placeholder
public enum PaymentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

/// Apple Pay request model placeholder
public struct ApplePayRequest: Codable {
    public let amount: Float
    public let currency: String
    
    public init(amount: Float, currency: String) {
        self.amount = amount
        self.currency = currency
    }
}

/// Payment method validation model placeholder
public struct PaymentMethodValidation: Codable {
    public let isValid: Bool
    public let errors: [String]
    
    public init(isValid: Bool, errors: [String] = []) {
        self.isValid = isValid
        self.errors = errors
    }
}

/// Product filters model placeholder
public struct ProductFilters: Codable {
    public let categoryId: String?
    public let brandId: String?
    public let priceMin: Float?
    public let priceMax: Float?
    
    public init(categoryId: String? = nil, brandId: String? = nil, priceMin: Float? = nil, priceMax: Float? = nil) {
        self.categoryId = categoryId
        self.brandId = brandId
        self.priceMin = priceMin
        self.priceMax = priceMax
    }
}
