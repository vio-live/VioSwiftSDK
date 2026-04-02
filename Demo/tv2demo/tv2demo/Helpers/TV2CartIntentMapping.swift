import Foundation
import VioCore
import VioUI

/// Maps Commerce `ProductDto` → domain `Product` and display strings for SDK overlays (tv2demo).
enum TV2CartIntentMapping {
    /// Price string for `VEngagementProductData` (tax-inclusive when available).
    static func formatDisplayPrice(_ price: PriceDto) -> String {
        let priceToShow = price.amountInclTaxes ?? price.amount
        return "\(price.currencyCode) \(String(format: "%.2f", priceToShow))"
    }

    /// Discount % for `VEngagementProductData` / badges.
    static func discountPercentage(from product: ProductDto?) -> Int? {
        guard let product else { return nil }
        let currentPrice = product.price.amountInclTaxes ?? product.price.amount
        let originalPrice = product.price.compareAtInclTaxes ?? product.price.compareAt
        guard let compareAt = originalPrice, compareAt > currentPrice else { return nil }
        let discount = ((compareAt - currentPrice) / compareAt) * 100
        return Int(discount.rounded())
    }

    /// Plain description for engagement overlay (strips HTML from GraphQL).
    static func engagementDescription(from dto: ProductDto?) -> String? {
        guard let raw = dto?.description, !raw.isEmpty else { return nil }
        let t = cleanHTMLString(raw)
        return t.isEmpty ? nil : t
    }

    /// Same conversion path used across tv2demo for add-to-cart from `ProductDto`.
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
