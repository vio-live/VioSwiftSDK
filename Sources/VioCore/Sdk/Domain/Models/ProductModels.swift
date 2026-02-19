import Foundation

private enum Lossy {
    static func double(_ m: [String: Any], _ k: String) -> Double? {
        if let v = m[k] as? Double { return v }
        if let v = m[k] as? Int { return Double(v) }
        if let v = m[k] as? String { return Double(v) }
        return nil
    }
    static func int(_ m: [String: Any], _ k: String) -> Int? {
        if let v = m[k] as? Int { return v }
        if let v = m[k] as? Double { return Int(v) }
        if let v = m[k] as? String { return Int(v) }
        return nil
    }
    static func bool(_ m: [String: Any], _ k: String) -> Bool? {
        if let v = m[k] as? Bool { return v }
        return nil
    }
}

private func decodeLossyDouble<K>(_ c: KeyedDecodingContainer<K>, key k: K) -> Double?
{
    if let v = try? c.decodeIfPresent(Double.self, forKey: k) { return v }
    if let s = try? c.decodeIfPresent(String.self, forKey: k) { return Double(s) }
    if let i = try? c.decodeIfPresent(Int.self, forKey: k) { return Double(i) }
    return nil
}
private func decodeLossyInt<K>(_ c: KeyedDecodingContainer<K>, key k: K) -> Int? {
    if let v = try? c.decodeIfPresent(Int.self, forKey: k) { return v }
    if let s = try? c.decodeIfPresent(String.self, forKey: k) { return Int(s) }
    if let d = try? c.decodeIfPresent(Double.self, forKey: k) { return Int(d) }
    return nil
}
private func decodeLossyBool<K>(_ c: KeyedDecodingContainer<K>, key k: K) -> Bool? {
    if let v = try? c.decodeIfPresent(Bool.self, forKey: k) { return v }
    return nil
}

public struct PriceDto: Codable, Equatable {
    public let amount: Double
    public let currencyCode: String
    public let compareAt: Double?
    public let amountInclTaxes: Double?
    public let compareAtInclTaxes: Double?
    public let taxAmount: Double?
    public let taxRate: Double?

    enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case compareAt = "compare_at"
        case amountInclTaxes = "amount_incl_taxes"
        case compareAtInclTaxes = "compare_at_incl_taxes"
        case taxAmount = "tax_amount"
        case taxRate = "tax_rate"
    }

    public init(
        amount: Double,
        currencyCode: String,
        compareAt: Double? = nil,
        amountInclTaxes: Double? = nil,
        compareAtInclTaxes: Double? = nil,
        taxAmount: Double? = nil,
        taxRate: Double? = nil
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.compareAt = compareAt
        self.amountInclTaxes = amountInclTaxes
        self.compareAtInclTaxes = compareAtInclTaxes
        self.taxAmount = taxAmount
        self.taxRate = taxRate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.amount = decodeLossyDouble(c, key: .amount) ?? 0.0
        self.currencyCode = (try? c.decode(String.self, forKey: .currencyCode)) ?? ""
        self.compareAt = decodeLossyDouble(c, key: .compareAt)
        self.amountInclTaxes = decodeLossyDouble(c, key: .amountInclTaxes)
        self.compareAtInclTaxes = decodeLossyDouble(c, key: .compareAtInclTaxes)
        self.taxAmount = decodeLossyDouble(c, key: .taxAmount)
        self.taxRate = decodeLossyDouble(c, key: .taxRate)
    }
}

public struct ProductImageDto: Codable, Equatable {
    public let id: String
    public let url: String
    public let width: Int?
    public let height: Int?
    public let order: Int?

    enum CodingKeys: String, CodingKey { case id, url, width, height, order }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? ""
        self.url = (try? c.decode(String.self, forKey: .url)) ?? ""
        self.width = decodeLossyInt(c, key: .width)
        self.height = decodeLossyInt(c, key: .height)
        self.order = decodeLossyInt(c, key: .order)
    }
}

public struct OptionDto: Codable, Equatable {
    public let id: String
    public let name: String
    public let order: Int
    public let values: String

    enum CodingKeys: String, CodingKey { case id, name, order, values }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? ""
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.order = decodeLossyInt(c, key: .order) ?? 0
        self.values = (try? c.decode(String.self, forKey: .values)) ?? ""
    }
}

public struct CategoryDto: Codable, Equatable {
    public let id: Int
    public let name: String

    enum CodingKeys: String, CodingKey { case id, name }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = decodeLossyInt(c, key: .id) ?? 0
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
    }
}

public struct VariantDto: Codable, Equatable {
    public let id: String
    public let barcode: String?
    public let quantity: Int?
    public let sku: String
    public let title: String
    public let price: PriceDto
    public let images: [ProductImageDto]

    enum CodingKeys: String, CodingKey {
        case id, barcode, quantity, sku, title, price, images
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? ""
        self.barcode = try? c.decodeIfPresent(String.self, forKey: .barcode)
        self.quantity = decodeLossyInt(c, key: .quantity)
        self.sku = (try? c.decode(String.self, forKey: .sku)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.price =
            (try? c.decode(PriceDto.self, forKey: .price))
            ?? PriceDto(
                amount: 0.0, currencyCode: "", compareAt: nil, amountInclTaxes: nil,
                compareAtInclTaxes: nil, taxAmount: nil, taxRate: nil)
        self.images = (try? c.decodeIfPresent([ProductImageDto].self, forKey: .images)) ?? []
    }

    public init(
        id: String, barcode: String?, quantity: Int?, sku: String, title: String, price: PriceDto,
        images: [ProductImageDto]
    ) {
        self.id = id
        self.barcode = barcode
        self.quantity = quantity
        self.sku = sku
        self.title = title
        self.price = price
        self.images = images
    }
}

public struct ShippingCountryDto: Codable, Equatable {
    public let id: String
    public let country: String
    public let price: PriceDto
}

public struct ProductShippingDto: Codable, Equatable {
    public let id: String
    public let name: String
    public let description: String?
    public let customPriceEnabled: Bool
    public let defaultOption: Bool
    public let shippingCountry: [ShippingCountryDto]?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case customPriceEnabled = "custom_price_enabled"
        case defaultOption = "default"
        case shippingCountry = "shipping_country"
    }
}

public struct ReturnAddressDto: Codable, Equatable {
    public let address: String?
    public let address2: String?
    public let country: String?
    public let postCode: String?
    public let returnCity: String?
    public let sameAsBusiness: Bool?
    public let sameAsWarehouse: Bool?
    public let timezone: String?

    enum CodingKeys: String, CodingKey {
        case address
        case address2 = "address_2"
        case country
        case postCode = "post_code"
        case returnCity = "return_city"
        case sameAsBusiness = "same_as_business"
        case sameAsWarehouse = "same_as_warehouse"
        case timezone
    }
}

public struct ReturnInfoDto: Codable, Equatable {
    public let returnAddress: ReturnAddressDto?
    public let returnCost: Double?
    public let returnLabel: String?
    public let returnRight: Bool?
    public let supplierPolicy: String?

    enum CodingKeys: String, CodingKey {
        case returnAddress = "return_address"
        case returnCost = "return_cost"
        case returnLabel = "return_label"
        case returnRight = "return_right"
        case supplierPolicy = "supplier_policy"
    }
}

public struct ProductDto: Codable, Equatable {
    public let id: Int
    public let title: String
    public let sku: String
    public let supplier: String
    public let brand: String?
    public let barcode: String?
    public let origin: String
    public let description: String?
    public let digital: Bool
    public let optionsEnabled: Bool
    public let quantity: Int?
    public let referralFee: Int?
    public let importedProduct: Bool?
    public let tags: String?
    public let supplierId: Int?

    public let price: PriceDto
    public let images: [ProductImageDto]
    public let variants: [VariantDto]
    public let options: [OptionDto]
    public let categories: [CategoryDto]?
    public let productShipping: [ProductShippingDto]?
    public let returnInfo: ReturnInfoDto?

    enum CodingKeys: String, CodingKey {
        case id, title, sku, supplier, brand, barcode, origin, description, digital, quantity, tags
        case optionsEnabled = "options_enabled"
        case referralFee = "referral_fee"
        case importedProduct = "imported_product"
        case supplierId = "supplier_id"
        case price, images, variants, options, categories
        case productShipping = "product_shipping"
        case returnInfo = "return"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = decodeLossyInt(c, key: .id) ?? 0
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.sku = (try? c.decode(String.self, forKey: .sku)) ?? ""
        self.supplier = (try? c.decode(String.self, forKey: .supplier)) ?? ""
        self.brand = try? c.decodeIfPresent(String.self, forKey: .brand)
        self.barcode = try? c.decodeIfPresent(String.self, forKey: .barcode)
        self.origin = (try? c.decode(String.self, forKey: .origin)) ?? ""
        self.description = try? c.decodeIfPresent(String.self, forKey: .description)
        self.digital = decodeLossyBool(c, key: .digital) ?? false
        self.optionsEnabled = decodeLossyBool(c, key: .optionsEnabled) ?? false
        self.quantity = decodeLossyInt(c, key: .quantity)
        self.referralFee = decodeLossyInt(c, key: .referralFee)
        self.importedProduct = decodeLossyBool(c, key: .importedProduct)
        self.tags = try? c.decodeIfPresent(String.self, forKey: .tags)
        self.supplierId = decodeLossyInt(c, key: .supplierId)

        self.images = (try? c.decodeIfPresent([ProductImageDto].self, forKey: .images)) ?? [ProductImageDto]()
        self.variants = (try? c.decodeIfPresent([VariantDto].self, forKey: .variants)) ?? [VariantDto]()
        self.options = (try? c.decodeIfPresent([OptionDto].self, forKey: .options)) ?? [OptionDto]()

        if let raw = try? c.decodeIfPresent([CategoryDto].self, forKey: .categories) {
            var seen = Set<Int>()
            var out: [CategoryDto] = []
            for cat in raw where !seen.contains(cat.id) {
                seen.insert(cat.id)
                out.append(cat)
            }
            self.categories = out
        } else {
            self.categories = nil
        }

        self.productShipping = try? c.decodeIfPresent(
            [ProductShippingDto].self, forKey: .productShipping)
        self.returnInfo = try? c.decodeIfPresent(ReturnInfoDto.self, forKey: .returnInfo)

        if let p = try? c.decodeIfPresent(PriceDto.self, forKey: .price) {
            self.price = p
        } else if let v = variants.first {
            self.price = v.price
        } else {
            self.price = PriceDto(
                amount: 0.0, currencyCode: "", compareAt: nil, amountInclTaxes: nil,
                compareAtInclTaxes: nil, taxAmount: nil, taxRate: nil)
        }
    }
}
