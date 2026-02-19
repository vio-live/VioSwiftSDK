import Foundation
import SwiftUI
import VioCore

// MARK: - Enums

public enum DynamicComponentType: String, Codable, CaseIterable {
    case featuredProduct = "featured_product"
    case banner = "banner"
}

public enum DynamicComponentPosition: String, Codable, Equatable {
    case top
    case bottom
    case topCenter = "top-center"
    case center
    case bottomCenter = "bottom-center"
    case custom
}

public enum DynamicComponentTrigger: String, Codable, Equatable {
    case streamStart = "stream_start"
    case manual
}

// MARK: - DynamicComponent

public struct DynamicComponent: Identifiable, Decodable, Equatable {
    public let id: String
    public let type: DynamicComponentType
    public let startTime: Date?
    public let endTime: Date?
    public let position: DynamicComponentPosition?
    public let triggerOn: DynamicComponentTrigger?
    public let data: DynamicComponentData
    
    public init(
        id: String,
        type: DynamicComponentType,
        startTime: Date?,
        endTime: Date?,
        position: DynamicComponentPosition?,
        triggerOn: DynamicComponentTrigger?,
        data: DynamicComponentData
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.position = position
        self.triggerOn = triggerOn
        self.data = data
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, data
        case startTime, endTime, position, triggerOn
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.type = try c.decode(DynamicComponentType.self, forKey: .type)
        
        let df = ISO8601DateFormatter()

        // Date decoding
        if let startString = try? c.decodeIfPresent(String.self, forKey: .startTime) {
            self.startTime = df.date(from: startString)
        } else {
            self.startTime = nil
        }

        if let endString = try? c.decodeIfPresent(String.self, forKey: .endTime) {
            self.endTime = df.date(from: endString)
        } else {
            self.endTime = nil
        }
        
        // Optional enum decoding
        self.position = try? c.decodeIfPresent(DynamicComponentPosition.self, forKey: .position)
        self.triggerOn = try? c.decodeIfPresent(DynamicComponentTrigger.self, forKey: .triggerOn)
          
        // Key: delegate 'data' decoding to DynamicComponentData
        // passing the complete decoder, as it needs to read 'type' from the same level.
        self.data = try DynamicComponentData(from: decoder)
    }
}

// MARK: - DynamicComponentData

public enum DynamicComponentData: Decodable, Equatable {
    case featuredProduct(FeaturedProductComponentData)
    case banner(BannerComponentData)

    public init(from decoder: Decoder) throws {
        // Obtenemos el contenedor del componente padre para leer la clave 'type'.
        let container = try decoder.container(keyedBy: DynamicComponent.CodingKeys.self)
        
        let type = try container.decode(DynamicComponentType.self, forKey: .type)
        
        switch type {
        case .featuredProduct:
            self = .featuredProduct(try FeaturedProductComponentData(from: decoder))
        case .banner:
            self = .banner(try BannerComponentData(from: decoder))
        }
    }
    // CodingKeys not needed here.
}

// MARK: - FeaturedProductComponentData

public struct FeaturedProductComponentData: Codable, Equatable {
    public let product: Product
    public let productId: Int?
    public let position: DynamicComponentPosition?
    public let startTime: Date?
    public let endTime: Date?
    public let triggerOn: DynamicComponentTrigger?
    
    //enum CodingKeys: String, CodingKey {
        //case data
    //}
    
    struct Inner: Codable {
        let product: ProductDtoCompat
        let productId: Int?
        let position: DynamicComponentPosition?
        let startTime: String?
        let endTime: String?
        let triggerOn: DynamicComponentTrigger?
    }
    
    //public init(from decoder: Decoder) throws {
        //// Obtenemos el contenedor del componente padre (DynamicComponent)
        //let container = try decoder.container(keyedBy: DynamicComponent.CodingKeys.self)
//        
        //// 2. Decodificamos el objeto 'Inner' DIRECTAMENTE de la clave .data del padre.
        //let inner = try container.decode(Inner.self, forKey: .data) // <-- CORREGIDO
//        
        //self.product = inner.product.asProduct() // DTO to Product conversion
        //self.productId = inner.productId
        //self.position = inner.position
//        
        //let df = ISO8601DateFormatter()
        //self.startTime = inner.startTime.flatMap { df.date(from: $0) }
        //self.endTime = inner.endTime.flatMap { df.date(from: $0) }
        //self.triggerOn = inner.triggerOn
    //}    
    public init( 
        product: Product, 
        productId: Int?, 
        position: DynamicComponentPosition?, 
        startTime: Date?, 
        endTime: Date?, 
        triggerOn: DynamicComponentTrigger? 
    ) { 
        self.product = product 
        self.productId = productId 
        self.position = position 
        self.startTime = startTime 
        self.endTime = endTime 
        self.triggerOn = triggerOn 
    }
    
    public func encode(to encoder: Encoder) throws {
        // 3. Ajustamos Encodable para usar `singleValueContainer` ya que Inner es el objeto.
        var container = encoder.singleValueContainer() 
        let df = ISO8601DateFormatter()
        
        // Product to DTO conversion for encoding
        let inner = Inner(
            product: ProductDtoCompat(from: product),
            productId: productId,
            position: position,
            startTime: startTime.map { df.string(from: $0) },
            endTime: endTime.map { df.string(from: $0) },
            triggerOn: triggerOn
        )
        try container.encode(inner) // <-- CORREGIDO (Codifica Inner directamente)
    }    
}

// Equatable manual para evitar requerir que `Product` sea Equatable
public extension FeaturedProductComponentData {
    static func == (lhs: FeaturedProductComponentData, rhs: FeaturedProductComponentData) -> Bool {
        return lhs.product.id == rhs.product.id
        && lhs.productId == rhs.productId
        && lhs.position == rhs.position
        && lhs.startTime == rhs.startTime
        && lhs.endTime == rhs.endTime
        && lhs.triggerOn == rhs.triggerOn
    }
}

// MARK: - BannerComponentData

public struct BannerComponentData: Codable, Equatable {
    public let title: String?
    public let text: String?
    public let position: DynamicComponentPosition?
    public let animation: String?
    public let duration: TimeInterval?
    public let startTime: Date?
    public let endTime: Date?
    
    //enum CodingKeys: String, CodingKey { case data }
    
    struct Inner: Codable {
        let title: String?
        let text: String?
        let position: DynamicComponentPosition?
        let animation: String?
        let duration: String?
        let startTime: String?
        let endTime: String?
    }
    
    //public init(from decoder: Decoder) throws {
        //// Necesitamos acceder al contenedor principal para obtener la clave 'data'
        //let container = try decoder.container(keyedBy: DynamicComponent.CodingKeys.self)
//        
        //// 1. Decodificamos el objeto 'Inner' DIRECTAMENTE de la clave .data del padre.
        //// Esto asume que el objeto JSON bajo "data" coincide con la estructura de Inner.
        //let inner = try container.decode(Inner.self, forKey: .data) // <--- CORRECTION APPLIED
//        
        //self.title = inner.title
        //self.text = inner.text
        //self.position = inner.position
        //self.animation = inner.animation
//        
        //// String to TimeInterval conversion
        //if let d = inner.duration, let seconds = TimeInterval(d) { 
            //self.duration = seconds 
        //} else { 
            //self.duration = nil 
        //}
//        
        //let df = ISO8601DateFormatter()
        //self.startTime = inner.startTime.flatMap { df.date(from: $0) }
        //self.endTime = inner.endTime.flatMap { df.date(from: $0) }
    //}

 public init( 
    title: String?, 
    text: String?, 
    position: DynamicComponentPosition?, 
    animation: String?, 
    duration: TimeInterval?, 
    startTime: Date?, 
    endTime: Date? 
    ) { 
        self.title = title 
        self.text = text 
        self.position = position 
        self.animation = animation 
        self.duration = duration 
        self.startTime = startTime 
        self.endTime = endTime 
    }
    public func encode(to encoder: Encoder) throws {
        // For encoding, we'll use a container to encode the Inner object
        // directly, as the JSON expects BannerComponentData to be the object
        // that is inside the 'data' key.
        
        var container = encoder.singleValueContainer() // Encode Inner as a single object
        let df = ISO8601DateFormatter()
        
        let inner = Inner(
            title: title,
            text: text,
            position: position,
            animation: animation,
            duration: duration.map { String($0) }, // TimeInterval (Double) to String conversion
            startTime: startTime.map { df.string(from: $0) },
            endTime: endTime.map { df.string(from: $0) }
        )
        // Encode the 'inner' object directly. DynamicComponent will handle
        // the parent container encoding.
        try container.encode(inner)
    }    
}

// MARK: - Lightweight DTO compatibility for provided JSON

// Note: Added required initializers for encoding.

public struct ProductDtoCompat: Codable, Equatable {
    public let id: Int
    public let title: String
    public let sku: String
    public let brand: String?
    public let description: String?
    public let quantity: Int?
    public let price: PriceCompat
    public let variants: [VariantCompat]
    public let barcode: String?
    public let options: [OptionCompat]?
    public let images: [ProductImageCompat]
    public let supplier: String
    public let supplierId: Int?
    public let optionsEnabled: Bool?
    public let digital: Bool
    public let origin: String
    
    // Decodable initializer (Automatic or manual, if not present, uses Codable's automatic)
    // The original was fine, but I leave it implicit as Codable provides it.
    
    // **ADDED: Initializer for reverse conversion (Product -> DTO)**
    public init(from product: Product) {
        self.id = product.id
        self.title = product.title
        self.sku = product.sku ?? ""
        self.brand = product.brand
        self.description = product.description
        self.quantity = product.quantity
        self.price = PriceCompat(from: product.price)
        self.variants = product.variants.map { VariantCompat(from: $0) }
        self.barcode = product.barcode
        self.options = product.options?.map { OptionCompat(from: $0) }
        self.images = product.images.map { ProductImageCompat(from: $0) }
        self.supplier = product.supplier ?? ""
        self.supplierId = product.supplier_id
        self.optionsEnabled = product.options_enabled ?? false
        self.digital = product.digital ?? false
        self.origin = product.origin ?? ""
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, sku, brand, description, quantity, price, variants, barcode, options, images, supplier
        case supplierId = "supplierId"
        case optionsEnabled = "optionsEnabled"
        case digital
        case origin
    }
    
    public func asProduct() -> Product {
        Product(
            id: id,
            title: title,
            brand: brand,
            description: description,
            sku: sku,
            quantity: quantity,
            price: price.asPrice(),
            variants: variants.map { $0.asVariant() },
            barcode: barcode,
            options: options?.map { $0.asOption() },
            images: images.map { $0.asImage() },
            product_shipping: nil,
            supplier: supplier,
            supplier_id: supplierId,
            options_enabled: optionsEnabled ?? false,
            digital: digital,
        )
    }
}

public struct PriceCompat: Codable, Equatable {
    public let amount: String
    public let currencyCode: String
    
    // **ADDED: Initializer for reverse conversion (Price -> DTO)**
    public init(from price: Price) {
        self.amount = String(price.amount)
        self.currencyCode = price.currency_code
    }
    
    enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currencyCode"
    }
    
    public func asPrice() -> Price {
        Price(
            amount: Float(amount) ?? 0,
            currency_code: currencyCode,
            amount_incl_taxes: nil,
            tax_amount: nil,
            tax_rate: nil,
            compare_at: nil,
            compare_at_incl_taxes: nil
        )
    }
}

public struct VariantCompat: Codable, Equatable {
    public let id: String
    public let price: PriceCompat
    public let quantity: Int?
    public let sku: String
    public let title: String
    public let images: [ProductImageCompat]
    
    // **ADDED: Initializer for reverse conversion (Variant -> DTO)**
    public init(from variant: Variant) {
        self.id = variant.id
        self.price = PriceCompat(from: variant.price)
        self.quantity = variant.quantity
        self.sku = variant.sku
        self.title = variant.title
        self.images = variant.images.map { ProductImageCompat(from: $0) }
    }
    
    public func asVariant() -> Variant {
        Variant(id: id, barcode: nil, price: price.asPrice(), quantity: quantity, sku: sku, title: title, images: images.map { $0.asImage() })
    }
}

public struct ProductImageCompat: Codable, Equatable {
    public let id: Int
    public let url: String
    public let order: Int
    public let width: Int?
    public let height: Int?
    
    // **ADDED: Initializer for reverse conversion (ProductImage -> DTO)**
    public init(from image: ProductImage) {
        self.id = Int(image.id) ?? 0
        self.url = image.url
        self.order = image.order
        self.width = image.width
        self.height = image.height
    }
    
    public func asImage() -> ProductImage {
        ProductImage(id: String(id), url: url, width: width, height: height, order: order)
    }
}

public struct OptionCompat: Codable, Equatable {
    public let id: String
    public let name: String
    public let order: Int
    public let values: [String]?
    
    // **ADDED: Initializer for reverse conversion (Option -> DTO)**
    public init(from option: Option) {
        self.id = option.id
        self.name = option.name
        self.order = option.order
        // Convert comma-separated string from Option to array of Strings
        self.values = option.values.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    public func asOption() -> Option {
        Option(id: id, name: name, order: order, values: values?.joined(separator: ", ") ?? "")
    }
}

// MARK: - Helpers (AnyDecodable)

public struct AnyDecodable: Decodable {
    public let value: Any
    public var stringValue: String? { value as? String }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s; return }
        if let i = try? container.decode(Int.self) { value = i; return }
        if let d = try? container.decode(Double.self) { value = d; return }
        if let b = try? container.decode(Bool.self) { value = b; return }
        if let dict = try? container.decode([String: AnyDecodable].self) { value = dict; return }
        if let arr = try? container.decode([AnyDecodable].self) { value = arr; return }
        value = ()
    }
}
