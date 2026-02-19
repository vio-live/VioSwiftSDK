import Foundation

private func decodeLossyDouble<K>(_ container: KeyedDecodingContainer<K>, key: K)
    -> Double?
{
    if let v = try? container.decodeIfPresent(Double.self, forKey: key) { return v }
    if let s = try? container.decodeIfPresent(String.self, forKey: key) { return Double(s) }
    if let i = try? container.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
    return nil
}
private func decodeLossyInt<K>(_ container: KeyedDecodingContainer<K>, key: K)
    -> Int?
{
    if let v = try? container.decodeIfPresent(Int.self, forKey: key) { return v }
    if let s = try? container.decodeIfPresent(String.self, forKey: key) { return Int(s) }
    if let d = try? container.decodeIfPresent(Double.self, forKey: key) { return Int(d) }
    return nil
}

public struct PriceDataDto: Codable, Equatable {
    public let amount: Double
    public let currencyCode: String
    public let compareAt: Double?
    public let discount: Double?
    public let amountInclTaxes: Double?
    public let compareAtInclTaxes: Double?
    public let taxAmount: Double?
    public let taxRate: Double?

    enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case compareAt = "compare_at"
        case discount
        case amountInclTaxes = "amount_incl_taxes"
        case compareAtInclTaxes = "compare_at_incl_taxes"
        case taxAmount = "tax_amount"
        case taxRate = "tax_rate"
    }

    public init(
        amount: Double, currencyCode: String, compareAt: Double?, discount: Double?,
        amountInclTaxes: Double?, compareAtInclTaxes: Double?, taxAmount: Double?, taxRate: Double?
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.compareAt = compareAt
        self.discount = discount
        self.amountInclTaxes = amountInclTaxes
        self.compareAtInclTaxes = compareAtInclTaxes
        self.taxAmount = taxAmount
        self.taxRate = taxRate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.amount = decodeLossyDouble(c, key: .amount) ?? 0.0
        self.currencyCode = try c.decode(String.self, forKey: .currencyCode)
        self.compareAt = decodeLossyDouble(c, key: .compareAt)
        self.discount = decodeLossyDouble(c, key: .discount)
        self.amountInclTaxes = decodeLossyDouble(c, key: .amountInclTaxes)
        self.compareAtInclTaxes = decodeLossyDouble(c, key: .compareAtInclTaxes)
        self.taxAmount = decodeLossyDouble(c, key: .taxAmount)
        self.taxRate = decodeLossyDouble(c, key: .taxRate)
    }
}

public struct ShippingPriceDto: Codable, Equatable {
    public let amount: Double
    public let currencyCode: String
    public let amountInclTaxes: Double?
    public let taxAmount: Double?
    public let taxRate: Double?

    enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case amountInclTaxes = "amount_incl_taxes"
        case taxAmount = "tax_amount"
        case taxRate = "tax_rate"
    }

    public init(
        amount: Double, currencyCode: String, amountInclTaxes: Double?, taxAmount: Double?,
        taxRate: Double?
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.amountInclTaxes = amountInclTaxes
        self.taxAmount = taxAmount
        self.taxRate = taxRate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.amount = decodeLossyDouble(c, key: .amount) ?? 0.0
        self.currencyCode = try c.decode(String.self, forKey: .currencyCode)
        self.amountInclTaxes = decodeLossyDouble(c, key: .amountInclTaxes)
        self.taxAmount = decodeLossyDouble(c, key: .taxAmount)
        self.taxRate = decodeLossyDouble(c, key: .taxRate)
    }
}

public struct ShippingDto: Codable, Equatable {
    public let id: String
    public let name: String
    public let description: String?
    public let price: ShippingPriceDto
}

// ProductImageDto is defined in ProductModels.swift to avoid duplication

public struct VariantOptionDto: Codable, Equatable {
    public let option: String
    public let value: String
}

public struct PriceLineItemAvailableShippingDto: Codable, Equatable {
    public let amount: Double?
    public let currencyCode: String?
    public let amountInclTaxes: Double?
    public let taxAmount: Double?
    public let taxRate: Double?

    enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case amountInclTaxes = "amount_incl_taxes"
        case taxAmount = "tax_amount"
        case taxRate = "tax_rate"
    }

    public init(
        amount: Double?, currencyCode: String?, amountInclTaxes: Double?, taxAmount: Double?,
        taxRate: Double?
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.amountInclTaxes = amountInclTaxes
        self.taxAmount = taxAmount
        self.taxRate = taxRate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.amount = decodeLossyDouble(c, key: .amount)
        self.currencyCode = try c.decodeIfPresent(String.self, forKey: .currencyCode)
        self.amountInclTaxes = decodeLossyDouble(c, key: .amountInclTaxes)
        self.taxAmount = decodeLossyDouble(c, key: .taxAmount)
        self.taxRate = decodeLossyDouble(c, key: .taxRate)
    }
}

public struct LineItemAvailableShippingDto: Codable, Equatable {
    public let id: String?
    public let name: String?
    public let description: String?
    public let countryCode: String?
    public let price: PriceLineItemAvailableShippingDto

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case countryCode = "country_code"
        case price
    }
}

public struct LineItemDto: Codable, Equatable {
    public let id: String
    public let supplier: String
    public let image: [ProductImageDto]?
    public let sku: String?
    public let barcode: String?
    public let brand: String?
    public let productId: Int
    public let title: String?
    public let variantId: Int?
    public let variantTitle: String?
    public let variant: [VariantOptionDto]
    public let quantity: Int
    public let price: PriceDataDto
    public let shipping: ShippingDto?
    public let availableShippings: [LineItemAvailableShippingDto]?

    enum CodingKeys: String, CodingKey {
        case id, supplier, image, sku, barcode, brand, title, variant, quantity, price, shipping
        case productId = "product_id"
        case variantId = "variant_id"
        case variantTitle = "variant_title"
        case availableShippings = "available_shippings"
    }

    public init(
        id: String, supplier: String, image: [ProductImageDto]?, sku: String?, barcode: String?,
        brand: String?, productId: Int, title: String?, variantId: Int?, variantTitle: String?,
        variant: [VariantOptionDto], quantity: Int, price: PriceDataDto, shipping: ShippingDto?,
        availableShippings: [LineItemAvailableShippingDto]?
    ) {
        self.id = id
        self.supplier = supplier
        self.image = image
        self.sku = sku
        self.barcode = barcode
        self.brand = brand
        self.productId = productId
        self.title = title
        self.variantId = variantId
        self.variantTitle = variantTitle
        self.variant = variant
        self.quantity = quantity
        self.price = price
        self.shipping = shipping
        self.availableShippings = availableShippings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.supplier = try c.decode(String.self, forKey: .supplier)
        self.image = try c.decodeIfPresent([ProductImageDto].self, forKey: .image)
        self.sku = try c.decodeIfPresent(String.self, forKey: .sku)
        self.barcode = try c.decodeIfPresent(String.self, forKey: .barcode)
        self.brand = try c.decodeIfPresent(String.self, forKey: .brand)
        self.productId = decodeLossyInt(c, key: .productId) ?? 0
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        self.variantId = decodeLossyInt(c, key: .variantId)
        self.variantTitle = try c.decodeIfPresent(String.self, forKey: .variantTitle)
        self.variant = (try c.decodeIfPresent([VariantOptionDto].self, forKey: .variant)) ?? []
        self.quantity = decodeLossyInt(c, key: .quantity) ?? 0
        self.price = try c.decode(PriceDataDto.self, forKey: .price)
        self.shipping = try c.decodeIfPresent(ShippingDto.self, forKey: .shipping)
        self.availableShippings = try c.decodeIfPresent(
            [LineItemAvailableShippingDto].self, forKey: .availableShippings)
    }
}

public struct CartDto: Codable, Equatable {
    public let availableShippingCountries: [String]
    public let cartId: String
    public let currency: String
    public let customerSessionId: String
    public let lineItems: [LineItemDto]
    public let shippingCountry: String?
    public let subtotal: Double
    public let shipping: Double

    enum CodingKeys: String, CodingKey {
        case availableShippingCountries = "available_shipping_countries"
        case cartId = "cart_id"
        case currency
        case customerSessionId = "customer_session_id"
        case lineItems = "line_items"
        case shippingCountry = "shipping_country"
        case subtotal
        case shipping
    }

    public init(
        availableShippingCountries: [String], cartId: String, currency: String,
        customerSessionId: String, lineItems: [LineItemDto], shippingCountry: String?,
        subtotal: Double, shipping: Double
    ) {
        self.availableShippingCountries = availableShippingCountries
        self.cartId = cartId
        self.currency = currency
        self.customerSessionId = customerSessionId
        self.lineItems = lineItems
        self.shippingCountry = shippingCountry
        self.subtotal = subtotal
        self.shipping = shipping
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.availableShippingCountries =
            (try c.decodeIfPresent([String].self, forKey: .availableShippingCountries)) ?? []
        self.cartId = try c.decode(String.self, forKey: .cartId)
        self.currency = try c.decode(String.self, forKey: .currency)
        self.customerSessionId = try c.decode(String.self, forKey: .customerSessionId)
        self.lineItems = (try c.decodeIfPresent([LineItemDto].self, forKey: .lineItems)) ?? []
        self.shippingCountry = try c.decodeIfPresent(String.self, forKey: .shippingCountry)
        self.subtotal = decodeLossyDouble(c, key: .subtotal) ?? 0.0
        self.shipping = decodeLossyDouble(c, key: .shipping) ?? 0.0
    }
}

public struct RemoveCartDto: Codable, Equatable {
    public let success: Bool
    public let message: String
}

public struct SupplierLineItemsBySupplierDto: Codable, Equatable {
    public let id: Int?
    public let name: String?

    enum CodingKeys: String, CodingKey { case id, name }

    public init(id: Int?, name: String?) {
        self.id = id
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decodeIfPresent(Int.self, forKey: .id) {
            self.id = i
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .id), let i = Int(s) {
            self.id = i
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .id) {
            self.id = Int(d)
        } else {
            self.id = nil
        }
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
    }
}

public struct GetLineItemsBySupplierDto: Codable, Equatable {
    public let supplier: SupplierLineItemsBySupplierDto?
    public let availableShippings: [LineItemAvailableShippingDto]?
    public let lineItems: [LineItemDto]

    enum CodingKeys: String, CodingKey {
        case supplier
        case availableShippings = "available_shippings"
        case lineItems = "line_items"
    }
}

public struct PriceDataInput {
    public let currency: String
    public let tax: Double?
    public let unitPrice: Double?

    public init(currency: String, tax: Double? = nil, unitPrice: Double? = nil) {
        self.currency = currency
        self.tax = tax
        self.unitPrice = unitPrice
    }
    public func toJSON() -> [String: Any] {
        var m: [String: Any] = ["currency": currency]
        if let tax { m["tax"] = tax }
        if let unitPrice { m["unit_price"] = unitPrice }
        return m
    }
}

public struct LineItemInput {
    public let productId: Int?
    public let variantId: Int?
    public let quantity: Int?
    public let priceData: PriceDataInput?

    public init(
        productId: Int? = nil, variantId: Int? = nil, quantity: Int? = nil,
        priceData: PriceDataInput? = nil
    ) {
        self.productId = productId
        self.variantId = variantId
        self.quantity = quantity
        self.priceData = priceData
    }
    public func toJSON() -> [String: Any] {
        var m: [String: Any] = [:]
        if let productId { m["product_id"] = productId }
        if let variantId { m["variant_id"] = variantId }
        if let quantity { m["quantity"] = quantity }
        if let priceData { m["price_data"] = priceData.toJSON() }
        return m
    }
}

public typealias GetCartDto = CartDto
public typealias CreateCartDto = CartDto
public typealias UpdateCartDto = CartDto
public typealias CreateItemToCartDto = CartDto
public typealias UpdateItemToCartDto = CartDto
public typealias RemoveItemToCartDto = CartDto
