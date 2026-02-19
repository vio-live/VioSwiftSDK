import Foundation

// MARK: - Product Models

/// Core Product model that mirrors the GraphQL schema
public struct Product: Identifiable, Codable {
    public let id: Int
    public let title: String
    public let brand: String?
    public let description: String?
    public let tags: String?
    public let sku: String
    public let quantity: Int?
    public let price: Price
    public let variants: [Variant]
    public let barcode: String?
    public let options: [Option]?
    public let categories: [_Category]?
    public let images: [ProductImage]
    public let product_shipping: [ProductShipping]?
    public let supplier: String
    public let supplier_id: Int?
    public let imported_product: Bool?
    public let referral_fee: Int?
    public let options_enabled: Bool
    public let digital: Bool
    public let origin: String
    public let `return`: ReturnInfo?  // 'return' is a reserved keyword, use backticks

    public init(
        id: Int,
        title: String,
        brand: String? = nil,
        description: String? = nil,
        tags: String? = nil,
        sku: String,
        quantity: Int? = nil,
        price: Price,
        variants: [Variant] = [],
        barcode: String? = nil,
        options: [Option]? = nil,
        categories: [_Category]? = nil,
        images: [ProductImage] = [],
        product_shipping: [ProductShipping]? = nil,
        supplier: String,
        supplier_id: Int? = nil,
        imported_product: Bool? = nil,
        referral_fee: Int? = nil,
        options_enabled: Bool = false,
        digital: Bool = false,
        origin: String = "",
        `return`: ReturnInfo? = nil
    ) {
        self.id = id
        self.title = title
        self.brand = brand
        self.description = description
        self.tags = tags
        self.sku = sku
        self.quantity = quantity
        self.price = price
        self.variants = variants
        self.barcode = barcode
        self.options = options
        self.categories = categories
        self.images = images
        self.product_shipping = product_shipping
        self.supplier = supplier
        self.supplier_id = supplier_id
        self.imported_product = imported_product
        self.referral_fee = referral_fee
        self.options_enabled = options_enabled
        self.digital = digital
        self.origin = origin
        self.`return` = `return`
    }
}

/// Product price information
public struct Price: Codable, Equatable {
    public let amount: Float
    public let currency_code: String
    public let amount_incl_taxes: Float?
    public let tax_amount: Float?
    public let tax_rate: Float?
    public let compare_at: Float?
    public let compare_at_incl_taxes: Float?

    public init(
        amount: Float,
        currency_code: String,
        amount_incl_taxes: Float? = nil,
        tax_amount: Float? = nil,
        tax_rate: Float? = nil,
        compare_at: Float? = nil,
        compare_at_incl_taxes: Float? = nil
    ) {
        self.amount = amount
        self.currency_code = currency_code
        self.amount_incl_taxes = amount_incl_taxes
        self.tax_amount = tax_amount
        self.tax_rate = tax_rate
        self.compare_at = compare_at
        self.compare_at_incl_taxes = compare_at_incl_taxes
    }

    /// Formatted display string for the price
    public var displayAmount: String {
        // Use price with taxes if available (what customer actually pays)
        let priceToShow = amount_incl_taxes ?? amount
        return "\(currency_code) \(String(format: "%.2f", priceToShow))"
    }

    /// Formatted display string for compare at price (original/before discount)
    public var displayCompareAtAmount: String? {
        // Use compare at price with taxes if available, otherwise base compare at
        if let compareAtWithTaxes = compare_at_incl_taxes {
            return "\(currency_code) \(String(format: "%.2f", compareAtWithTaxes))"
        } else if let compareAt = compare_at {
            return "\(currency_code) \(String(format: "%.2f", compareAt))"
        }
        return nil
    }
}

/// Product variant information
public struct Variant: Identifiable, Codable {
    public let id: String
    public let barcode: String?
    public let price: Price
    public let quantity: Int?
    public let sku: String
    public let title: String
    public let images: [ProductImage]

    public init(
        id: String,
        barcode: String? = nil,
        price: Price,
        quantity: Int? = nil,
        sku: String,
        title: String,
        images: [ProductImage] = []
    ) {
        self.id = id
        self.barcode = barcode
        self.price = price
        self.quantity = quantity
        self.sku = sku
        self.title = title
        self.images = images
    }
}

/// Product image information
public struct ProductImage: Identifiable, Codable {
    public let id: String
    public let url: String
    public let width: Int?
    public let height: Int?
    public let order: Int

    public init(
        id: String,
        url: String,
        width: Int? = nil,
        height: Int? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.url = url
        self.width = width
        self.height = height
        self.order = order
    }
}

/// Product option information
public struct Option: Codable {
    public let id: String
    public let name: String
    public let order: Int
    public let values: String  // This might be an array of strings in real data, adjust if needed

    public init(id: String, name: String, order: Int, values: String) {
        self.id = id
        self.name = name
        self.order = order
        self.values = values
    }
}

/// Product category information
public struct _Category: Codable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

/// Product shipping information
public struct ProductShipping: Codable {
    public let id: String
    public let name: String
    public let description: String?
    public let custom_price_enabled: Bool
    public let `default`: Bool  // 'default' is a reserved keyword
    public let shipping_country: [ShippingCountry]?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        custom_price_enabled: Bool = false,
        `default`: Bool = false,
        shipping_country: [ShippingCountry]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.custom_price_enabled = custom_price_enabled
        self.`default` = `default`
        self.shipping_country = shipping_country
    }
}

/// Shipping country information
public struct ShippingCountry: Codable {
    public let id: String
    public let country: String
    public let price: BasePrice

    public init(id: String, country: String, price: BasePrice) {
        self.id = id
        self.country = country
        self.price = price
    }
}

/// Base price structure
public struct BasePrice: Codable {
    public let amount: Float
    public let currency_code: String
    public let amount_incl_taxes: Float?
    public let tax_amount: Float?
    public let tax_rate: Float?

    public init(
        amount: Float,
        currency_code: String,
        amount_incl_taxes: Float? = nil,
        tax_amount: Float? = nil,
        tax_rate: Float? = nil
    ) {
        self.amount = amount
        self.currency_code = currency_code
        self.amount_incl_taxes = amount_incl_taxes
        self.tax_amount = tax_amount
        self.tax_rate = tax_rate
    }
}

/// Return information
public struct ReturnInfo: Codable {
    public let return_right: Bool?
    public let return_label: String?
    public let return_cost: Float?
    public let supplier_policy: String?
    public let return_address: ReturnAddress?

    public init(
        return_right: Bool? = nil,
        return_label: String? = nil,
        return_cost: Float? = nil,
        supplier_policy: String? = nil,
        return_address: ReturnAddress? = nil
    ) {
        self.return_right = return_right
        self.return_label = return_label
        self.return_cost = return_cost
        self.supplier_policy = supplier_policy
        self.return_address = return_address
    }
}

/// Return address information
public struct ReturnAddress: Codable {
    public let same_as_business: Bool?
    public let same_as_warehouse: Bool?
    public let country: String?
    public let timezone: String?
    public let address: String?
    public let address_2: String?
    public let post_code: String?
    public let return_city: String?

    public init(
        same_as_business: Bool? = nil,
        same_as_warehouse: Bool? = nil,
        country: String? = nil,
        timezone: String? = nil,
        address: String? = nil,
        address_2: String? = nil,
        post_code: String? = nil,
        return_city: String? = nil
    ) {
        self.same_as_business = same_as_business
        self.same_as_warehouse = same_as_warehouse
        self.country = country
        self.timezone = timezone
        self.address = address
        self.address_2 = address_2
        self.post_code = post_code
        self.return_city = return_city
    }
}
