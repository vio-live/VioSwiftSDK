import Foundation
import VioCore
import VioUI

/// Maps `CartIntentEvent` (SDK WebSocket) into tv2demo overlay models and `Product` for the cart.
enum TV2CartIntentMapping {
    /// Builds `ProductEventData` for `TV2ProductOverlay`; returns nil if `productId` is missing.
    static func productEventData(
        from event: CartIntentEvent,
        currency: String,
        campaignLogo: String?
    ) -> ProductEventData? {
        guard let pid = event.productId, !pid.isEmpty else { return nil }
        let name = event.productName ?? "Product"
        // price and imageUrl are intentionally empty — TV2ProductOverlay
        // fetches real product data (image, price, variants) from Commerce GraphQL
        // using productId. These fields are placeholders to satisfy the model.
        return ProductEventData(
            id: pid,
            productId: pid,
            name: name,
            description: "",
            price: "",
            currency: currency,
            imageUrl: "",
            campaignLogo: campaignLogo
        )
    }

    /// Same conversion path as `TV2ProductOverlay` for add-to-cart from `ProductDto`.
    static func product(from dto: ProductDto) -> Product {
        let cleanDescription = dto.description.map { cleanHTMLString($0) }
        return Product(
            id: dto.id,
            title: dto.title,
            brand: dto.brand,
            description: cleanDescription,
            tags: dto.tags,
            sku: dto.sku,
            quantity: dto.quantity,
            price: Price(
                amount: Float(dto.price.amount),
                currency_code: dto.price.currencyCode,
                amount_incl_taxes: dto.price.amountInclTaxes.map { Float($0) },
                tax_amount: dto.price.taxAmount.map { Float($0) },
                tax_rate: dto.price.taxRate.map { Float($0) },
                compare_at: dto.price.compareAt.map { Float($0) },
                compare_at_incl_taxes: dto.price.compareAtInclTaxes.map { Float($0) }
            ),
            variants: dto.variants.map { v in
                Variant(
                    id: v.id,
                    barcode: v.barcode,
                    price: Price(
                        amount: Float(v.price.amount),
                        currency_code: v.price.currencyCode,
                        amount_incl_taxes: v.price.amountInclTaxes.map { Float($0) },
                        tax_amount: v.price.taxAmount.map { Float($0) },
                        tax_rate: v.price.taxRate.map { Float($0) },
                        compare_at: v.price.compareAt.map { Float($0) },
                        compare_at_incl_taxes: v.price.compareAtInclTaxes.map { Float($0) }
                    ),
                    quantity: v.quantity,
                    sku: v.sku,
                    title: v.title,
                    images: v.images.map {
                        ProductImage(id: $0.id, url: $0.url, width: $0.width, height: $0.height, order: $0.order ?? 0)
                    }
                )
            },
            barcode: dto.barcode,
            options: dto.options.map { Option(id: $0.id, name: $0.name, order: $0.order, values: $0.values) },
            categories: dto.categories?.map { _Category(id: $0.id, name: $0.name) },
            images: dto.images.map {
                ProductImage(id: $0.id, url: $0.url, width: $0.width, height: $0.height, order: $0.order ?? 0)
            },
            product_shipping: nil,
            supplier: dto.supplier,
            supplier_id: dto.supplierId,
            imported_product: dto.importedProduct,
            referral_fee: dto.referralFee,
            options_enabled: dto.optionsEnabled,
            digital: dto.digital,
            origin: dto.origin,
            return: nil
        )
    }

    private static func cleanHTMLString(_ html: String) -> String {
        var cleaned = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
