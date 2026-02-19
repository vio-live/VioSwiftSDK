import Foundation
import VioCore

// MARK: - Product Mapping Helpers
extension ProductDto {
    public func toDomainProduct() -> Product {
        Product(
            id: id,
            title: title,
            brand: brand,
            description: description,
            tags: tags,
            sku: sku,
            quantity: quantity,
            price: price.toDomainPrice(),
            variants: variants.map { $0.toDomainVariant() },
            barcode: barcode,
            options: options.isEmpty ? nil : options.map { $0.toDomainOption() },
            categories: categories?.map { $0.toDomainCategory() },
            images: images.map { $0.toDomainImage() },
            product_shipping: productShipping?.map { $0.toDomainProductShipping() },
            supplier: supplier,
            supplier_id: supplierId,
            imported_product: importedProduct,
            referral_fee: referralFee,
            options_enabled: optionsEnabled,
            digital: digital,
            origin: origin,
            return: returnInfo?.toDomainReturnInfo()
        )
    }
}

extension PriceDto {
    public func toDomainPrice() -> Price {
        Price(
            amount: Float(amount),
            currency_code: currencyCode,
            amount_incl_taxes: amountInclTaxes.map(Float.init),
            tax_amount: taxAmount.map(Float.init),
            tax_rate: taxRate.map(Float.init),
            compare_at: compareAt.map(Float.init),
            compare_at_incl_taxes: compareAtInclTaxes.map(Float.init)
        )
    }

    public func toDomainBasePrice() -> BasePrice {
        BasePrice(
            amount: Float(amount),
            currency_code: currencyCode,
            amount_incl_taxes: amountInclTaxes.map(Float.init),
            tax_amount: taxAmount.map(Float.init),
            tax_rate: taxRate.map(Float.init)
        )
    }
}

extension VariantDto {
    public func toDomainVariant() -> Variant {
        Variant(
            id: id,
            barcode: barcode,
            price: price.toDomainPrice(),
            quantity: quantity,
            sku: sku,
            title: title,
            images: images.map { $0.toDomainImage() }
        )
    }
}

extension ProductImageDto {
    public func toDomainImage() -> ProductImage {
        return ProductImage(
            id: id,
            url: url,
            width: width,
            height: height,
            order: order ?? 0
        )
    }
}

extension OptionDto {
    public func toDomainOption() -> Option {
        Option(id: id, name: name, order: order, values: values)
    }
}

extension CategoryDto {
    public func toDomainCategory() -> _Category {
        _Category(id: id, name: name)
    }
}

extension ProductShippingDto {
    public func toDomainProductShipping() -> ProductShipping {
        ProductShipping(
            id: id,
            name: name,
            description: description,
            custom_price_enabled: customPriceEnabled,
            default: defaultOption,
            shipping_country: shippingCountry?.map { $0.toDomainShippingCountry() }
        )
    }
}

extension ShippingCountryDto {
    public func toDomainShippingCountry() -> ShippingCountry {
        ShippingCountry(
            id: id,
            country: country,
            price: price.toDomainBasePrice()
        )
    }
}

extension ReturnInfoDto {
    public func toDomainReturnInfo() -> ReturnInfo {
        ReturnInfo(
            return_right: returnRight,
            return_label: returnLabel,
            return_cost: returnCost.map(Float.init),
            supplier_policy: supplierPolicy,
            return_address: returnAddress?.toDomainReturnAddress()
        )
    }
}

extension ReturnAddressDto {
    public func toDomainReturnAddress() -> ReturnAddress {
        ReturnAddress(
            same_as_business: sameAsBusiness,
            same_as_warehouse: sameAsWarehouse,
            country: country,
            timezone: timezone,
            address: address,
            address_2: address2,
            post_code: postCode,
            return_city: returnCity
        )
    }
}

extension GetAvailableGlobalMarketsDto {
    public func toMarket(fallback: MarketConfiguration) -> CartManager.Market? {
        guard let code = code, !code.isEmpty else { return nil }
        let marketName = name ?? fallback.countryName
        let symbol = currency?.symbol ?? fallback.currencySymbol
        let currencyCode = currency?.code ?? fallback.currencyCode
        let phone = phoneCode ?? fallback.phoneCode
        return CartManager.Market(
            code: code,
            name: marketName,
            officialName: official,
            flagURL: flag,
            phoneCode: phone,
            currencyCode: currencyCode,
            currencySymbol: symbol
        )
    }
}
