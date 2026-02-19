import Foundation
import VioCore
import VioDesignSystem
import SwiftUI

#if os(iOS)
    import UIKit
#endif

@MainActor
extension CartManager {

    struct ShippingSyncData {
        let shippingId: String?
        let shippingName: String?
        let shippingDescription: String?
        let shippingAmount: Double?
        let shippingCurrency: String?
        let options: [CartItem.ShippingOption]
    }

    // MARK: - Cart Lifecycle

    public func createCart(currency: String = "USD", country: String = "US") async {
        // Check if SDK should be used before attempting operations
        guard VioConfiguration.shared.shouldUseSDK else {
            VioLogger.warning("Skipping cart creation - SDK disabled (market not available)", component: "CartModule")
            return
        }
        
        if currentCartId != nil {
            VioLogger.debug("createCart skipped — existing cartId=\(currentCartId ?? "nil")", component: "CartModule")
            return
        }
        isLoading = true
        errorMessage = nil

        let session = "ios-\(UUID().uuidString)"
        VioLogger.debug("createCart START session=\(session) currency=\(currency) country=\(country)", component: "CartModule")
        logRequest(
            "sdk.cart.create",
            payload: [
                "session": session,
                "currency": currency,
                "country": country
            ]
        )

        do {
            let dto = try await sdk.cart.create(
                customer_session_id: session,
                currency: currency,
                shippingCountry: country
            )
            sync(from: dto)
        } catch let e as SdkException {
            errorMessage = e.description
            logError("sdk.cart.create", error: e)
            VioLogger.error("createCart FAIL \(e.description)", component: "CartModule")
        } catch {
            errorMessage = error.localizedDescription
            logError("sdk.cart.create", error: error)
            VioLogger.error("createCart FAIL \(error.localizedDescription)", component: "CartModule")
        }

        isLoading = false
    }

    // MARK: - Products

    public func loadProductsIfNeeded() async {
        if !products.isEmpty { return }
        await loadProducts()
    }

    public func reloadProducts() async {
        await loadProducts(useCache: false)
    }

    internal func loadProducts(
        currency: String? = nil,
        shippingCountryCode: String? = nil,
        imageSize: String = "large",
        useCache: Bool = true
    ) async {
        let requestedCurrency = currency ?? self.currency
        let requestedCountry = shippingCountryCode ?? self.country
        let shouldUseCache =
            useCache
            && lastLoadedProductCurrency == requestedCurrency
            && lastLoadedProductCountry == requestedCountry

        let requestID = UUID()
        activeProductRequestID = requestID
        isProductsLoading = true
        productsErrorMessage = nil

        do {
            logRequest(
                "sdk.product.get",
                payload: [
                    "currency": requestedCurrency,
                    "country": requestedCountry,
                    "imageSize": imageSize,
                    "useCache": shouldUseCache
                ]
            )
            let dtoProducts = try await sdk.product.get(
                currency: requestedCurrency,
                imageSize: imageSize,
                barcodeList: nil,
                categoryIds: nil,
                productIds: nil,
                skuList: nil,
                useCache: shouldUseCache,
                shippingCountryCode: requestedCountry
            )

            guard activeProductRequestID == requestID else { return }

            products = dtoProducts.map { $0.toDomainProduct() }
            logResponse(
                "sdk.product.get",
                payload: [
                    "count": dtoProducts.count,
                    "currency": requestedCurrency,
                    "country": requestedCountry
                ]
            )
            lastLoadedProductCurrency = requestedCurrency
            lastLoadedProductCountry = requestedCountry
            isProductsLoading = false
            activeProductRequestID = nil
        } catch let sdkError as SdkException {
            guard activeProductRequestID == requestID else { return }

            productsErrorMessage = sdkError.description
            logError("sdk.product.get", error: sdkError)
            products = []
            isProductsLoading = false
            activeProductRequestID = nil
        } catch {
            guard activeProductRequestID == requestID else { return }

            productsErrorMessage = error.localizedDescription
            logError("sdk.product.get", error: error)
            products = []
            isProductsLoading = false
            activeProductRequestID = nil
        }
    }

    // MARK: - Sync

    internal func sync(from cart: CartDto) {
        print("🔄 [CartModule] ========== SYNC FROM BACKEND ==========")
        print("🔄 [CartModule] Cart ID: \(cart.cartId)")
        print("🔄 [CartModule] Currency: \(cart.currency)")
        print("🔄 [CartModule] Line items count: \(cart.lineItems.count)")
        
        currentCartId = cart.cartId
        currency = cart.currency
        country = cart.shippingCountry ?? country

        items = cart.lineItems.map { line in
            print("🔄 [CartModule] --- Line Item ---")
            print("🔄 [CartModule] Product: \(line.title ?? "Unknown")")
            print("🔄 [CartModule] Product ID: \(line.productId)")
            print("🔄 [CartModule] Backend price amount: \(line.price.amount)")
            print("🔄 [CartModule] Backend price with taxes: \(line.price.amountInclTaxes ?? 0.0)")
            print("🔄 [CartModule] Quantity: \(line.quantity)")
            let sortedImages = (line.image ?? []).sorted { lhs, rhs in
                let lOrder = lhs.order ?? 0
                let rOrder = rhs.order ?? 0
                return lOrder < rOrder
            }
            let imageUrl = sortedImages.first?.url

            let shipping = line.shipping
            let shippingCurrency = shipping?.price.currencyCode ?? cart.currency
            let availableShippings = (line.availableShippings ?? []).compactMap {
                option -> CartItem.ShippingOption? in
                guard let id = option.id, !id.isEmpty else { return nil }
                // Use price with taxes if available (what customer actually pays)
                // Always prioritize amount_incl_taxes if it exists (even if 0.0)
                let amount: Double = {
                    if let inclTaxes = option.price.amountInclTaxes {
                        return inclTaxes
                    }
                    return option.price.amount ?? 0.0
                }()
                let currency = option.price.currencyCode ?? cart.currency
                return CartItem.ShippingOption(
                    id: id,
                    name: option.name ?? "Shipping",
                    description: option.description,
                    amount: amount,
                    currency: currency
                )
            }

            // Use price with taxes if available (what customer actually pays)
            let productPrice = line.price.amountInclTaxes ?? line.price.amount
            // Use shipping price with taxes if available (what customer actually pays)
            // Always prioritize amount_incl_taxes if it exists (even if 0.0)
            let shippingPrice: Double? = {
                if let inclTaxes = shipping?.price.amountInclTaxes {
                    return inclTaxes
                }
                return shipping?.price.amount
            }()

            return CartItem(
                id: line.id,
                productId: line.productId,
                variantId: line.variantId.map { String($0) },
                variantTitle: line.variantTitle,
                title: line.title ?? "",
                brand: line.brand,
                imageUrl: imageUrl,
                price: productPrice,
                currency: line.price.currencyCode,
                quantity: line.quantity,
                sku: line.sku,
                supplier: line.supplier,
                shippingId: shipping?.id,
                shippingName: shipping?.name,
                shippingDescription: shipping?.description,
                shippingAmount: shippingPrice,
                shippingCurrency: shippingCurrency,
                availableShippings: availableShippings
            )
        }

        // Recalculate cartTotal using prices with taxes from items (what customer actually pays)
        cartTotal = items.reduce(0) { total, item in
            let itemTotal = item.price * Double(item.quantity)
            print("🔄 [CartModule] Item '\(item.title)': price=\(item.price) × qty=\(item.quantity) = \(itemTotal)")
            return total + itemTotal
        }
        
        print("🔄 [CartModule] ========== SYNC COMPLETE ==========")
        print("🔄 [CartModule] Cart Total: \(cartTotal)")
        print("🔄 [CartModule] Currency: \(currency)")
        print("🔄 [CartModule] Total items in cart: \(items.count)")
        
        // Recalculate shippingTotal using shipping prices with taxes from items (what customer actually pays)
        shippingTotal = items.reduce(0) { total, item in
            total + (item.shippingAmount ?? 0.0)
        }
        shippingCurrency =
            items.first(where: { $0.shippingCurrency != nil })?.shippingCurrency
            ?? cart.currency

        if let selected = selectedMarket {
            currencySymbol = selected.currencySymbol
            phoneCode = selected.phoneCode
            flagURL = selected.flagURL
        }
    }

    // MARK: - Shipping

    @discardableResult
    public func refreshShippingOptions() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let cid = await ensureCartIDForCheckout() else {
            VioLogger.info("refreshShippingOptions: missing cartId", component: "CartModule")
            return false
        }

        do {
            logRequest("sdk.cart.getLineItemsBySupplier", payload: ["cart_id": cid])
            let groups = try await sdk.cart.getLineItemsBySupplier(cart_id: cid)
            logResponse(
                "sdk.cart.getLineItemsBySupplier",
                payload: ["groupCount": groups.count]
            )
            var shippingData: [String: ShippingSyncData] = [:]

            for group in groups {
                let options: [CartItem.ShippingOption] = (group.availableShippings ?? [])
                    .compactMap { option in
                        guard let id = option.id, !id.isEmpty else { return nil }
                        // Use price with taxes if available (what customer actually pays)
                        // Always prioritize amount_incl_taxes if it exists (even if 0.0)
                        let amount: Double = {
                            if let inclTaxes = option.price.amountInclTaxes {
                                return inclTaxes
                            }
                            return option.price.amount ?? 0.0
                        }()
                        let currency = option.price.currencyCode ?? currency
                        return CartItem.ShippingOption(
                            id: id,
                            name: option.name ?? "Shipping",
                            description: option.description,
                            amount: amount,
                            currency: currency
                        )
                    }

                for li in group.lineItems {
                    guard items.contains(where: { $0.id == li.id }) else { continue }

                    let shipping = li.shipping
                    let shippingCurrency = shipping?.price.currencyCode ?? currency
                    // Use shipping price with taxes if available (what customer actually pays)
                    // Always prioritize amount_incl_taxes if it exists (even if 0.0)
                    let shippingPrice: Double? = {
                        if let inclTaxes = shipping?.price.amountInclTaxes {
                            return inclTaxes
                        }
                        return shipping?.price.amount
                    }()

                    shippingData[li.id] = ShippingSyncData(
                        shippingId: shipping?.id,
                        shippingName: shipping?.name,
                        shippingDescription: shipping?.description,
                        shippingAmount: shippingPrice,
                        shippingCurrency: shippingCurrency,
                        options: options
                    )
                }
            }

            if !shippingData.isEmpty {
                applyShippingMetadata(shippingData)
            }

            return true

        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            errorMessage = msg
            logError("sdk.cart.getLineItemsBySupplier", error: error)
            VioLogger.error("refreshShippingOptions FAIL \(msg)", component: "CartModule")
            return false
        }
    }

    public func setShippingOption(for itemId: String, optionId: String) {
        guard let itemIndex = items.firstIndex(where: { $0.id == itemId }) else { return }
        let item = items[itemIndex]
        guard let option = item.availableShippings.first(where: { $0.id == optionId }) else {
            return
        }

        items[itemIndex] = CartItem(
            id: item.id,
            productId: item.productId,
            variantId: item.variantId,
            variantTitle: item.variantTitle,
            title: item.title,
            brand: item.brand,
            imageUrl: item.imageUrl,
            price: item.price,
            currency: item.currency,
            quantity: item.quantity,
            sku: item.sku,
            supplier: item.supplier,
            shippingId: option.id,
            shippingName: option.name,
            shippingDescription: option.description,
            shippingAmount: option.amount,
            shippingCurrency: option.currency,
            availableShippings: item.availableShippings
        )

        pendingShippingSelections[itemId] = option
        recalcShippingTotalsFromItems()
    }

    @discardableResult
    public func applyCheapestShippingPerSupplier() async -> Int {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let cid = await ensureCartIDForCheckout() else {
            VioLogger.info("applyCheapestShippingPerSupplier: missing cartId", component: "CartModule")
            return 0
        }

        let selections = pendingShippingSelections
        guard !selections.isEmpty else {
            VioLogger.info("applyCheapestShippingPerSupplier: no pending selections", component: "CartModule")
            return 0
        }

        var updatedCount = 0
        var lastResponse: CartDto?
        var succeededIds: [String] = []

        for (itemId, option) in selections {
            do {
                logRequest(
                    "sdk.cart.updateItem",
                    payload: [
                        "cart_id": cid,
                        "cart_item_id": itemId,
                        "shipping_id": option.id
                    ]
                )
                let dto = try await sdk.cart.updateItem(
                    cart_id: cid,
                    cart_item_id: itemId,
                    shipping_id: option.id,
                    quantity: nil
                )
                logResponse(
                    "sdk.cart.updateItem",
                    payload: [
                        "cartId": dto.cartId,
                        "itemCount": dto.lineItems.count,
                        "shippingUpdatedItem": itemId
                    ]
                )
                lastResponse = dto
                succeededIds.append(itemId)
                updatedCount += 1
            } catch let error as SdkException {
                errorMessage = error.description
                logError("sdk.cart.updateItem", error: error)
                VioLogger.warning("updateItem(shipping) failed for \(itemId): \(error.description)", component: "CartModule")
            } catch {
                errorMessage = error.localizedDescription
                logError("sdk.cart.updateItem", error: error)
                VioLogger.warning("updateItem(shipping) failed for \(itemId): \(error.localizedDescription)", component: "CartModule")
            }
        }

        for itemId in succeededIds {
            pendingShippingSelections.removeValue(forKey: itemId)
        }

        if let dto = lastResponse {
            sync(from: dto)
            _ = await refreshShippingOptions()
        } else {
            recalcShippingTotalsFromItems()
        }

        VioLogger.success("Shipping updated for \(updatedCount) item(s)", component: "CartModule")
        return updatedCount
    }

    private func applyShippingMetadata(_ metadata: [String: ShippingSyncData]) {
        guard !metadata.isEmpty else { return }

        items = items.map { item in
            guard let info = metadata[item.id] else { return item }

            var updated = CartItem(
                id: item.id,
                productId: item.productId,
                variantId: item.variantId,
                variantTitle: item.variantTitle,
                title: item.title,
                brand: item.brand,
                imageUrl: item.imageUrl,
                price: item.price,
                currency: item.currency,
                quantity: item.quantity,
                sku: item.sku,
                supplier: item.supplier,
                shippingId: info.shippingId ?? item.shippingId,
                shippingName: info.shippingName ?? item.shippingName,
                shippingDescription: info.shippingDescription ?? item.shippingDescription,
                shippingAmount: info.shippingAmount ?? item.shippingAmount,
                shippingCurrency: info.shippingCurrency ?? item.shippingCurrency,
                availableShippings: info.options.isEmpty ? item.availableShippings : info.options
            )

            if let pending = pendingShippingSelections[item.id] {
                updated = CartItem(
                    id: updated.id,
                    productId: updated.productId,
                    variantId: updated.variantId,
                    variantTitle: updated.variantTitle,
                    title: updated.title,
                    brand: updated.brand,
                    imageUrl: updated.imageUrl,
                    price: updated.price,
                    currency: updated.currency,
                    quantity: updated.quantity,
                    sku: updated.sku,
                    supplier: updated.supplier,
                    shippingId: pending.id,
                    shippingName: pending.name,
                    shippingDescription: pending.description,
                    shippingAmount: pending.amount,
                    shippingCurrency: pending.currency,
                    availableShippings: updated.availableShippings.isEmpty ? [pending] : updated.availableShippings
                )
            }

            return updated
        }

        recalcShippingTotalsFromItems()
    }

    // MARK: - Items

    public func addProduct(_ product: Product, quantity: Int) async {
        await addProduct(product, variant: nil, quantity: quantity)
    }

    public func addProduct(
        _ product: Product,
        variant: VioCore.Variant? = nil,
        quantity: Int = 1
    ) async {
        print("🛒 [CartModule] ========== ADD PRODUCT TO CART ==========")
        print("🛒 [CartModule] Product: \(product.title)")
        print("🛒 [CartModule] Product ID: \(product.id)")
        print("🛒 [CartModule] Base price amount: \(product.price.amount)")
        print("🛒 [CartModule] Price with taxes: \(product.price.amount_incl_taxes ?? 0.0)")
        print("🛒 [CartModule] Currency: \(product.price.currency_code)")
        print("🛒 [CartModule] Quantity to add: \(quantity)")
        
        isLoading = true
        errorMessage = nil

        let previousCount = itemCount
        let selectedVariant = variant ?? product.variants.first
        let selectedVariantId = selectedVariant?.id
        
        if let v = selectedVariant {
            print("🛒 [CartModule] Variant selected: \(v.title)")
            print("🛒 [CartModule] Variant price amount: \(v.price.amount)")
            print("🛒 [CartModule] Variant price with taxes: \(v.price.amount_incl_taxes ?? 0.0)")
        }

        let hadExistingItem = items.contains {
            $0.productId == product.id && $0.variantId == selectedVariantId
        }

        do {
            guard let cid = await ensureCartIDForCheckout() else {
                addProductLocally(product, variant: selectedVariant, quantity: quantity)
                updateCartTotal()
                ToastManager.shared.showSuccess(
                    hadExistingItem
                        ? "Updated \(product.title) quantity in cart"
                        : "Added \(product.title) to cart"
                )
                isLoading = false
                triggerFeedbackIfNeeded(previousCount: previousCount)
                return
            }

            if let existingItem = items.first(where: {
                $0.productId == product.id && $0.variantId == selectedVariantId
            }) {
                let newQuantity = existingItem.quantity + quantity
                logRequest(
                    "sdk.cart.updateItem",
                    payload: [
                        "cart_id": cid,
                        "cart_item_id": existingItem.id,
                        "quantity": newQuantity
                    ]
                )
                let dto = try await sdk.cart.updateItem(
                    cart_id: cid,
                    cart_item_id: existingItem.id,
                    shipping_id: nil,
                    quantity: newQuantity
                )
                logResponse(
                    "sdk.cart.updateItem",
                    payload: ["cartId": dto.cartId, "itemCount": dto.lineItems.count]
                )
                sync(from: dto)
                ToastManager.shared.showSuccess("Updated \(product.title) quantity in cart")
            } else {
                let variantIdInt = selectedVariantId.flatMap { Int($0) }
                let line = LineItemInput(
                    productId: product.id,
                    variantId: variantIdInt,
                    quantity: quantity,
                    priceData: nil
                )
                logRequest(
                    "sdk.cart.addItem",
                    payload: [
                        "cart_id": cid,
                        "productId": product.id,
                        "variantId": variantIdInt as Any,
                        "quantity": quantity
                    ]
                )
                let dto = try await sdk.cart.addItem(
                    cart_id: cid,
                    line_items: [line]
                )
                logResponse(
                    "sdk.cart.addItem",
                    payload: ["cartId": dto.cartId, "itemCount": dto.lineItems.count]
                )
                sync(from: dto)
                products.append(product)
                ToastManager.shared.showSuccess("Added \(product.title) to cart")
            }
        } catch let error as SdkException {
            errorMessage = error.description
            logError("sdk.cart.update/addItem", error: error)
            VioLogger.error("addProduct FAIL \(error.description)", component: "CartModule")
            addProductLocally(product, variant: selectedVariant, quantity: quantity)
            ToastManager.shared.showWarning("Using local cart for \(product.title) (sync error)")
        } catch {
            errorMessage = error.localizedDescription
            logError("sdk.cart.update/addItem", error: error)
            VioLogger.error("addProduct FAIL \(error.localizedDescription)", component: "CartModule")
            addProductLocally(product, variant: selectedVariant, quantity: quantity)
            ToastManager.shared.showWarning("Added \(product.title) locally due to error")
        }

        updateCartTotal()
        isLoading = false
        triggerFeedbackIfNeeded(previousCount: previousCount)
    }

    public func removeItem(_ item: CartItem) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var didSyncFromServer = false

        if let cid = currentCartId, !cid.isEmpty {
            do {
                logRequest(
                    "sdk.cart.deleteItem",
                    payload: ["cart_id": cid, "cart_item_id": item.id]
                )
                let dto = try await sdk.cart.deleteItem(
                    cart_id: cid,
                    cart_item_id: item.id
                )
                logResponse(
                    "sdk.cart.deleteItem",
                    payload: ["cartId": dto.cartId, "itemCount": dto.lineItems.count]
                )
                sync(from: dto)
                didSyncFromServer = true
            } catch let error as SdkException {
                errorMessage = error.description
                logError("sdk.cart.deleteItem", error: error)
                VioLogger.warning("SDK.deleteItem failed: \(error.description)", component: "CartModule")
            } catch {
                errorMessage = error.localizedDescription
                logError("sdk.cart.deleteItem", error: error)
                VioLogger.warning("SDK.deleteItem failed: \(error.localizedDescription)", component: "CartModule")
            }
        } else {
            VioLogger.info("removeItem: skipped SDK call (missing cartId)", component: "CartModule")
        }

        if !didSyncFromServer {
            removeItemLocally(item)
        }

        if let index = products.firstIndex(where: { $0.id == item.productId }) {
            products.remove(at: index)
        }
        updateCartTotal()
        ToastManager.shared.showInfo("Removed \(item.title) from cart")
    }

    public func updateQuantity(for item: CartItem, to newQuantity: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var didSyncFromServer = false

        if let cid = currentCartId, !cid.isEmpty {
            do {
                let dto: CartDto
                if newQuantity <= 0 {
                    logRequest(
                        "sdk.cart.deleteItem",
                        payload: ["cart_id": cid, "cart_item_id": item.id]
                    )
                    dto = try await sdk.cart.deleteItem(
                        cart_id: cid,
                        cart_item_id: item.id
                    )
                    logResponse(
                        "sdk.cart.deleteItem",
                        payload: ["cartId": dto.cartId, "itemCount": dto.lineItems.count]
                    )
                } else {
                    logRequest(
                        "sdk.cart.updateItem",
                        payload: [
                            "cart_id": cid,
                            "cart_item_id": item.id,
                            "quantity": newQuantity
                        ]
                    )
                    dto = try await sdk.cart.updateItem(
                        cart_id: cid,
                        cart_item_id: item.id,
                        shipping_id: nil,
                        quantity: newQuantity
                    )
                    logResponse(
                        "sdk.cart.updateItem",
                        payload: ["cartId": dto.cartId, "itemCount": dto.lineItems.count]
                    )
                }
                sync(from: dto)
                didSyncFromServer = true
            } catch let error as SdkException {
                errorMessage = error.description
                logError("sdk.cart.updateItem", error: error)
                VioLogger.warning("SDK.updateItem failed: \(error.description)", component: "CartModule")
            } catch {
                errorMessage = error.localizedDescription
                logError("sdk.cart.updateItem", error: error)
                VioLogger.warning("SDK.updateItem failed: \(error.localizedDescription)", component: "CartModule")
            }
        } else {
            VioLogger.info("updateQuantity: skipped SDK call (missing cartId)", component: "CartModule")
        }

        if !didSyncFromServer {
            updateQuantityLocally(for: item, to: newQuantity)
        }

        updateCartTotal()
    }

    public func clearCart() async {
        isLoading = true
        errorMessage = nil

        items = []
        cartTotal = 0.0
        shippingTotal = 0.0
        shippingCurrency = currency

        isLoading = false
    }
    
    public func resetCartAndCreateNew() async {        
        items = []
        cartTotal = 0.0
        shippingTotal = 0.0
        shippingCurrency = currency
        checkoutId = nil
        lastDiscountCode = nil
        lastDiscountId = nil
        pendingShippingSelections.removeAll()
        
        currentCartId = nil
        cartId = nil
        
        await createCart(currency: currency, country: country)
    }

    public var itemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Helpers

    internal func updateCartTotal() {
        cartTotal = items.reduce(0) { total, item in
            total + (item.price * Double(item.quantity))
        }

        if let firstCurrency = items.first?.currency, !firstCurrency.isEmpty {
            currency = firstCurrency
        } else if currency.isEmpty {
            currency = "USD"
        }

        if items.isEmpty {
            shippingTotal = 0.0
            shippingCurrency = currency
        }
    }

    private func addProductLocally(
        _ product: Product,
        variant: VioCore.Variant? = nil,
        quantity: Int
    ) {
        let variantId = variant?.id
        let variantTitle = variant?.title

        if let index = items.firstIndex(where: {
            $0.productId == product.id && $0.variantId == variantId
        }) {
            items[index].quantity += quantity
            recalcShippingTotalsFromItems()
            return
        }

        let sortedImages = product.images.sorted { lhs, rhs in
            lhs.order < rhs.order
        }
        let imageUrl = sortedImages.first?.url

        // Use price with taxes if available, otherwise base price
        let priceToUse = product.price.amount_incl_taxes ?? product.price.amount
        
        let cartItem = CartItem(
            id: UUID().uuidString,
            productId: product.id,
            variantId: variantId,
            variantTitle: variantTitle,
            title: product.title,
            brand: product.brand,
            imageUrl: imageUrl,
            price: Double(priceToUse),
            currency: product.price.currency_code,
            quantity: quantity,
            sku: product.sku,
            supplier: product.supplier
        )

        items.append(cartItem)
        recalcShippingTotalsFromItems()
    }

    private func removeItemLocally(_ item: CartItem) {
        items.removeAll { $0.id == item.id }
        recalcShippingTotalsFromItems()
    }

    private func updateQuantityLocally(for item: CartItem, to newQuantity: Int) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            if newQuantity <= 0 {
                items.remove(at: index)
            } else {
                items[index].quantity = newQuantity
            }
            recalcShippingTotalsFromItems()
        }
    }

    private func triggerFeedbackIfNeeded(previousCount: Int) {
        #if os(iOS)
            if itemCount > previousCount {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        #endif
    }

    internal func recalcShippingTotalsFromItems() {
        var total: Double = 0.0
        var detectedCurrency: String?

        for item in items {
            if let amount = item.shippingAmount {
                total += amount
            }
            if detectedCurrency == nil,
                let cur = item.shippingCurrency,
                !cur.isEmpty
            {
                detectedCurrency = cur
            }
        }

        shippingTotal = total
        shippingCurrency = detectedCurrency ?? currency
    }

    @discardableResult
    internal func ensureCartIDForCheckout() async -> String? {
        if let id = currentCartId { return id }
        await createCart(currency: currency, country: country)
        return currentCartId
    }
}
