import XCTest
@testable import VioCore
@testable import VioUI

@MainActor
final class CartManagerModulesTests: XCTestCase {
    override func setUp() async throws {
        VioConfiguration.configure(
            apiKey: "TEST_KEY",
            environment: .development,
            marketConfig: MarketConfiguration(
                countryCode: "US",
                countryName: "United States",
                currencyCode: "USD",
                currencySymbol: "$",
                phoneCode: "+1",
                flagURL: nil
            )
        )
    }

    func testUpdateCartTotalAggregatesLineItems() {
        let manager = makeManager(autoBootstrap: false)
        manager.items = [
            CartManager.CartItem(
                id: "1",
                productId: 100,
                title: "Shirt",
                price: 30,
                currency: "USD",
                quantity: 1
            ),
            CartManager.CartItem(
                id: "2",
                productId: 101,
                title: "Cap",
                price: 15,
                currency: "USD",
                quantity: 2
            )
        ]

        manager.updateCartTotal()

        XCTAssertEqual(manager.cartTotal, 60)
        XCTAssertEqual(manager.shippingCurrency, "USD")
    }

    func testSyncFromCartDtoPopulatesPublishedValues() {
        let manager = makeManager(autoBootstrap: false)
        let dto = SampleFactory.makeCartDto(lineItems: [SampleFactory.makeLineItemDto()])

        manager.sync(from: dto)

        XCTAssertEqual(manager.currentCartId, dto.cartId)
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.cartTotal, dto.subtotal)
    }

    func testCreateCartUsesCartRepository() async {
        let cartRepository = MockCartRepository()
        cartRepository.createResult = SampleFactory.makeCartDto()
        let sdk = MockSdkProvider(cart: cartRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)

        await manager.createCart(currency: "EUR", country: "DE")

        XCTAssertEqual(cartRepository.createCaptured?.currency, "EUR")
        XCTAssertEqual(manager.currentCartId, cartRepository.createResult?.cartId)
    }

    func testAddProductCallsUpdateWhenItemAlreadyExists() async {
        let cartRepository = MockCartRepository()
        cartRepository.updateItemResult = SampleFactory.makeCartDto(subtotal: 80)
        let sdk = MockSdkProvider(cart: cartRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)

        let product = SampleFactory.makeProductForCart(id: 1, price: 20)
        manager.items = [CartManager.CartItem(
            id: "item",
            productId: 1,
            variantId: nil,
            title: "Item",
            price: 20,
            currency: "USD",
            quantity: 1
        )]
        manager.currentCartId = "cart-1"

        await manager.addProduct(product, quantity: 1)

        XCTAssertEqual(cartRepository.updateItemCaptured?.cartId, "cart-1")
        XCTAssertEqual(cartRepository.updateItemCaptured?.quantity, 2)
    }

    func testAddProductCallsAddItemForNewProduct() async {
        let cartRepository = MockCartRepository()
        cartRepository.addItemResult = SampleFactory.makeCartDto(subtotal: 40)
        let sdk = MockSdkProvider(cart: cartRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)
        manager.currentCartId = "cart-2"

        let product = SampleFactory.makeProductForCart(id: 5, price: 20)
        await manager.addProduct(product, quantity: 2)

        XCTAssertEqual(cartRepository.addItemCaptured?.cartId, "cart-2")
        XCTAssertEqual(cartRepository.addItemCaptured?.lineItems.first?.quantity, 2)
    }

    func testRemoveItemUsesCartRepositoryWhenCartExists() async {
        let cartRepository = MockCartRepository()
        cartRepository.deleteItemResult = SampleFactory.makeCartDto(lineItems: [])
        let sdk = MockSdkProvider(cart: cartRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)
        manager.currentCartId = "cart-3"

        let item = CartManager.CartItem(
            id: "item-3",
            productId: 10,
            title: "Bag",
            price: 10,
            currency: "USD",
            quantity: 1
        )
        manager.items = [item]

        await manager.removeItem(item)

        XCTAssertEqual(cartRepository.deleteItemCaptured?.cartId, "cart-3")
        XCTAssertTrue(manager.items.isEmpty)
    }

    func testUpdateQuantityFallsBackToLocalWhenNoCartId() async {
        let cartRepository = MockCartRepository()
        let sdk = MockSdkProvider(cart: cartRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)

        manager.items = [CartManager.CartItem(
            id: "local",
            productId: 1,
            title: "Local",
            price: 10,
            currency: "USD",
            quantity: 2
        )]

        await manager.updateQuantity(for: manager.items[0], to: 5)

        XCTAssertEqual(manager.items.first?.quantity, 5)
        XCTAssertNil(cartRepository.updateItemCaptured)
    }

    func testRefreshShippingOptionsPopulatesMetadata() async {
        let cartRepository = MockCartRepository()
        cartRepository.getLineItemsResult = [SampleFactory.makeLineItemsBySupplierDto()]
        let sdk = MockSdkProvider(cart: cartRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)
        manager.currentCartId = "cart-shipping"
        manager.items = [CartManager.CartItem(
            id: "line-123",
            productId: 1,
            title: "Item",
            price: 10,
            currency: "USD",
            quantity: 1
        )]

        let refreshed = await manager.refreshShippingOptions()

        XCTAssertTrue(refreshed)
        XCTAssertEqual(cartRepository.getLineItemsCaptured, "cart-shipping")
        XCTAssertEqual(manager.items.first?.shippingId, "ship-option")
    }

    func testLoadProductsUsesProductRepository() async {
        let productRepository = MockProductRepository()
        productRepository.getResult = [SampleFactory.makeProductDto(id: 11, price: 12)]
        let sdk = MockSdkProvider(product: productRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)

        await manager.reloadProducts()

        XCTAssertEqual(manager.products.count, 1)
        XCTAssertEqual(productRepository.capturedParams?.useCache, false)
    }

    func testLoadMarketsTakesRepositoryValues() async {
        let marketRepository = MockMarketRepository()
        marketRepository.availableResult = [SampleFactory.makeMarketDto(code: "FR", currency: "EUR")]
        let sdk = MockSdkProvider(market: marketRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)

        await manager.loadMarketsIfNeeded()

        XCTAssertTrue(manager.markets.contains { $0.code == "FR" })
        XCTAssertEqual(manager.selectedMarket?.code, VioConfiguration.shared.marketConfiguration.countryCode)
    }

    func testCheckoutCreateAndUpdateCallsRepositories() async {
        let checkoutRepository = MockCheckoutRepository()
        checkoutRepository.createResult = CreateCheckoutDto(id: "chk-100", status: "open", checkoutUrl: nil)
        let sdk = MockSdkProvider(checkout: checkoutRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)
        manager.currentCartId = "cart-100"

        _ = await manager.createCheckout()
        let updated = await manager.updateCheckout(email: "user@test.com")

        XCTAssertEqual(manager.checkoutId, "chk-100")
        XCTAssertEqual(checkoutRepository.updateCaptured?.email, "user@test.com")
        XCTAssertEqual(updated?.id, "chk-100")
    }

    func testPaymentMethodsForwardToRepository() async {
        let paymentRepository = MockPaymentRepository()
        paymentRepository.stripeIntentResult = SampleFactory.makeStripeIntent()
        paymentRepository.stripeLinkResult = InitPaymentStripeDto(checkoutUrl: "https://stripe", orderId: 44)
        paymentRepository.klarnaInitResult = InitPaymentKlarnaDto(orderId: "ord", status: "ok", locale: "en_US", htmlSnippet: "<div></div>")
        paymentRepository.klarnaNativeInitResult = SampleFactory.makeKlarnaNativeInit()
        paymentRepository.klarnaNativeConfirmResult = ConfirmPaymentKlarnaNativeDto(orderId: "order", checkoutId: "chk", fraudStatus: nil, order: nil)
        paymentRepository.klarnaNativeOrderResult = SampleFactory.makeKlarnaNativeOrder()
        let sdk = MockSdkProvider(payment: paymentRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)
        manager.checkoutId = "chk-pay"

        let stripeIntent = await manager.stripeIntent(returnEphemeralKey: false)
        let stripeLink = await manager.stripeLink(successUrl: "https://succ", paymentMethod: "card", email: "mail@test.com")
        let klarna = await manager.initKlarna(countryCode: "US", href: "https://klarna", email: nil)
        let klarnaNative = await manager.initKlarnaNative(input: KlarnaNativeInitInputDto())
        let confirmation = await manager.confirmKlarnaNative(authorizationToken: "token")
        let order = await manager.klarnaNativeOrder(orderId: "order-1")

        XCTAssertEqual(paymentRepository.lastStripeIntentCheckoutId, "chk-pay")
        XCTAssertEqual(stripeIntent?.clientSecret, paymentRepository.stripeIntentResult.clientSecret)
        XCTAssertEqual(stripeLink?.checkoutUrl, "https://stripe")
        XCTAssertEqual(klarna?.orderId, "ord")
        XCTAssertEqual(klarnaNative?.checkoutId, "chk")
        XCTAssertEqual(confirmation?.orderId, "order")
        XCTAssertEqual(order?.orderId, paymentRepository.klarnaNativeOrderResult.orderId)
    }

    func testDiscountOperations() async {
        let discountRepository = MockDiscountRepository()
        discountRepository.applyResult = ApplyDiscountDto(executed: true, message: "OK")
        let sdk = MockSdkProvider(discount: discountRepository)
        let manager = makeManager(sdk: sdk, autoBootstrap: false)
        manager.currentCartId = "cart-disc"

        let created = await manager.discountCreate(code: "DESCUENTO", percentage: 10)
        let applied = await manager.discountApply(code: "descuento")
        let removed = await manager.discountRemoveApplied(code: "DESCUENTO")
        let deleted = await manager.discountDelete(discountId: 1)

        XCTAssertEqual(created, 1)
        XCTAssertTrue(applied)
        XCTAssertTrue(removed)
        XCTAssertTrue(deleted)
        XCTAssertEqual(discountRepository.lastApplyCartId, "cart-disc")
    }

    // MARK: - Helpers

    private func makeManager(
        sdk: CartManagingSDK = MockSdkProvider(),
        autoBootstrap: Bool = true
    ) -> CartManager {
        CartManager(sdk: sdk, configuration: VioConfiguration.shared, autoBootstrap: autoBootstrap)
    }
}

// MARK: - Sample Factory

private enum SampleFactory {
    static func makeCartDto(
        lineItems: [LineItemDto] = [makeLineItemDto()],
        subtotal: Double = 20,
        shipping: Double = 0
    ) -> CartDto {
        CartDto(
            availableShippingCountries: ["US"],
            cartId: "cart-id",
            currency: "USD",
            customerSessionId: "session",
            lineItems: lineItems,
            shippingCountry: "US",
            subtotal: subtotal,
            shipping: shipping
        )
    }

    static func makeLineItemDto(id: String = "line-123") -> LineItemDto {
        LineItemDto(
            id: id,
            supplier: "Vio",
            image: nil,
            sku: nil,
            barcode: nil,
            brand: nil,
            productId: 1,
            title: "Item",
            variantId: nil,
            variantTitle: nil,
            variant: [],
            quantity: 1,
            price: PriceDataDto(
                amount: 20,
                currencyCode: "USD",
                compareAt: nil,
                discount: nil,
                amountInclTaxes: nil,
                compareAtInclTaxes: nil,
                taxAmount: nil,
                taxRate: nil
            ),
            shipping: nil,
            availableShippings: nil
        )
    }

    static func makeLineItemsBySupplierDto() -> GetLineItemsBySupplierDto {
        GetLineItemsBySupplierDto(
            supplier: SupplierLineItemsBySupplierDto(id: nil, name: "Supplier"),
            availableShippings: [
                LineItemAvailableShippingDto(
                    id: "ship-option",
                    name: "Default",
                    description: nil,
                    countryCode: "US",
                    price: PriceLineItemAvailableShippingDto(
                        amount: 5,
                        currencyCode: "USD",
                        amountInclTaxes: nil,
                        taxAmount: nil,
                        taxRate: nil
                    )
                )
            ],
            lineItems: [
                LineItemDto(
                    id: "line-123",
                    supplier: "Vio",
                    image: nil,
                    sku: nil,
                    barcode: nil,
                    brand: nil,
                    productId: 1,
                    title: "Item",
                    variantId: nil,
                    variantTitle: nil,
                    variant: [],
                    quantity: 1,
                    price: PriceDataDto(
                        amount: 10,
                        currencyCode: "USD",
                        compareAt: nil,
                        discount: nil,
                        amountInclTaxes: nil,
                        compareAtInclTaxes: nil,
                        taxAmount: nil,
                        taxRate: nil
                    ),
                    shipping: ShippingDto(
                        id: "ship-option",
                        name: "Standard",
                        description: nil,
                        price: ShippingPriceDto(
                            amount: 5,
                            currencyCode: "USD",
                            amountInclTaxes: nil,
                            taxAmount: nil,
                            taxRate: nil
                        )
                    ),
                    availableShippings: nil
                )
            ]
        )
    }

    static func makeProductForCart(id: Int = 1, price: Double = 10) -> Product {
        Product(
            id: id,
            title: "Product",
            brand: nil,
            description: nil,
            tags: nil,
            sku: "SKU-\(id)",
            quantity: 10,
            price: Price(amount: Float(price), currency_code: "USD"),
            variants: [],
            barcode: nil,
            options: nil,
            categories: nil,
            images: [],
            product_shipping: nil,
            supplier: "Supplier",
            supplier_id: nil,
            imported_product: nil,
            referral_fee: nil,
            options_enabled: false,
            digital: false,
            origin: "",
            return: nil
        )
    }

    static func makeDomainProduct(id: Int = 1, price: Double = 10) -> Product {
        Product(
            id: id,
            title: "Product",
            brand: nil,
            description: nil,
            tags: nil,
            sku: "SKU-\(id)",
            quantity: 10,
            price: Price(amount: Float(price), currency_code: "USD"),
            variants: [],
            barcode: nil,
            options: nil,
            categories: nil,
            images: [],
            product_shipping: nil,
            supplier: "Supplier",
            supplier_id: nil,
            imported_product: nil,
            referral_fee: nil,
            options_enabled: false,
            digital: false,
            origin: "",
            return: nil
        )
    }

    static func makeMarketDto(code: String = "CA", currency: String = "CAD") -> GetAvailableGlobalMarketsDto {
        GetAvailableGlobalMarketsDto(
            code: code,
            name: "Market",
            official: nil,
            flag: nil,
            phoneCode: "+1",
            currency: CurrencyMarketsDto(code: currency, name: "Dollar", symbol: "$")
        )
    }

    static func makeStripeIntent() -> PaymentIntentStripeDto {
        PaymentIntentStripeDto(
            clientSecret: "secret",
            customer: "cus",
            publishableKey: "pk",
            ephemeralKey: nil
        )
    }

    static func makeKlarnaNativeInit() -> InitPaymentKlarnaNativeDto {
        InitPaymentKlarnaNativeDto(
            clientToken: "token",
            sessionId: "session",
            purchaseCountry: "US",
            purchaseCurrency: "USD",
            cartId: "cart",
            checkoutId: "chk",
            paymentMethodCategories: nil
        )
    }

    static func makeKlarnaNativeOrder() -> KlarnaNativeOrderDto {
        KlarnaNativeOrderDto(
            orderId: "order",
            status: "captured",
            locale: nil,
            htmlSnippet: nil,
            purchaseCountry: "US",
            purchaseCurrency: "USD",
            orderAmount: 100,
            orderTaxAmount: nil,
            paymentMethodCategories: nil,
            orderLines: nil
        )
    }

    static func makeProductDto(id: Int = 1, price: Double = 10) -> ProductDto {
        let payload: [String: Any] = [
            "id": id,
            "title": "Product",
            "sku": "SKU-\(id)",
            "supplier": "Supplier",
            "brand": NSNull(),
            "barcode": NSNull(),
            "origin": "",
            "description": NSNull(),
            "digital": false,
            "quantity": 10,
            "tags": NSNull(),
            "options_enabled": false,
            "referral_fee": NSNull(),
            "imported_product": false,
            "supplier_id": NSNull(),
            "price": [
                "amount": price,
                "currency_code": "USD",
                "compare_at": NSNull(),
                "amount_incl_taxes": NSNull(),
                "compare_at_incl_taxes": NSNull(),
                "tax_amount": NSNull(),
                "tax_rate": NSNull()
            ],
            "variants": [],
            "options": [],
            "categories": NSNull(),
            "images": [],
            "product_shipping": NSNull(),
            "return": NSNull()
        ]

        let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
        return try! JSONDecoder().decode(ProductDto.self, from: data)
    }
}

// MARK: - Mocks

private enum MockError: Error { case unimplemented }

private final class MockProductRepository: ProductRepository {
    var getResult: [ProductDto] = []
    var capturedParams: (currency: String?, image: String?, useCache: Bool, shippingCountry: String?)?

    func get(
        currency: String?,
        imageSize: String?,
        barcodeList: [String]?,
        categoryIds: [Int]?,
        productIds: [Int]?,
        skuList: [String]?,
        useCache: Bool,
        shippingCountryCode: String?
    ) async throws -> [ProductDto] {
        capturedParams = (currency, imageSize, useCache, shippingCountryCode)
        return getResult
    }

    func getByCategoryId(categoryId: Int, currency: String?, imageSize: String, shippingCountryCode: String?) async throws -> [ProductDto] { throw MockError.unimplemented }
    func getByCategoryIds(categoryIds: [Int], currency: String?, imageSize: String, shippingCountryCode: String?) async throws -> [ProductDto] { throw MockError.unimplemented }
    func getByParams(currency: String?, imageSize: String, sku: String?, barcode: String?, productId: Int?, shippingCountryCode: String?) async throws -> ProductDto { throw MockError.unimplemented }
    func getByIds(productIds: [Int], currency: String?, imageSize: String, useCache: Bool, shippingCountryCode: String?) async throws -> [ProductDto] { throw MockError.unimplemented }
    func getBySkus(sku: String, productId: Int?, currency: String?, imageSize: String, shippingCountryCode: String?) async throws -> [ProductDto] { throw MockError.unimplemented }
    func getByBarcodes(barcode: String, productId: Int?, currency: String?, imageSize: String, shippingCountryCode: String?) async throws -> [ProductDto] { throw MockError.unimplemented }
}

private final class MockCartRepository: CartRepository {
    var createResult: CartDto? = SampleFactory.makeCartDto()
    var createCaptured: (session: String, currency: String, country: String?)?

    var addItemResult: CartDto? = SampleFactory.makeCartDto()
    var addItemCaptured: (cartId: String, lineItems: [LineItemInput])?

    var updateItemResult: CartDto? = SampleFactory.makeCartDto()
    var updateItemCaptured: (cartId: String, itemId: String, shippingId: String?, quantity: Int?)?

    var deleteItemResult: CartDto? = SampleFactory.makeCartDto(lineItems: [])
    var deleteItemCaptured: (cartId: String, itemId: String)?

    var getLineItemsResult: [GetLineItemsBySupplierDto] = []
    var getLineItemsCaptured: String?

    func getById(cart_id: String) async throws -> CartDto { throw MockError.unimplemented }

    func create(customer_session_id: String, currency: String, shippingCountry: String?) async throws -> CartDto {
        createCaptured = (customer_session_id, currency, shippingCountry)
        return createResult ?? SampleFactory.makeCartDto()
    }

    func update(cart_id: String, shipping_country: String) async throws -> CartDto { throw MockError.unimplemented }

    func delete(cart_id: String) async throws -> RemoveCartDto { throw MockError.unimplemented }

    func addItem(cart_id: String, line_items: [LineItemInput]) async throws -> CartDto {
        addItemCaptured = (cart_id, line_items)
        return addItemResult ?? SampleFactory.makeCartDto()
    }

    func updateItem(cart_id: String, cart_item_id: String, shipping_id: String?, quantity: Int?) async throws -> CartDto {
        updateItemCaptured = (cart_id, cart_item_id, shipping_id, quantity)
        return updateItemResult ?? SampleFactory.makeCartDto()
    }

    func deleteItem(cart_id: String, cart_item_id: String) async throws -> CartDto {
        deleteItemCaptured = (cart_id, cart_item_id)
        return deleteItemResult ?? SampleFactory.makeCartDto(lineItems: [])
    }

    func getLineItemsBySupplier(cart_id: String) async throws -> [GetLineItemsBySupplierDto] {
        getLineItemsCaptured = cart_id
        return getLineItemsResult
    }
}

private final class MockCheckoutRepository: CheckoutRepository {
    var createResult: CreateCheckoutDto = CreateCheckoutDto(id: "chk", status: "open", checkoutUrl: nil)
    var createCaptured: String?
    var updateCaptured: (
        checkoutId: String,
        email: String?,
        successUrl: String?,
        cancelUrl: String?,
        paymentMethod: String?
    )?

    func getById(checkout_id: String) async throws -> GetCheckoutDto { throw MockError.unimplemented }

    func create(cart_id: String) async throws -> CreateCheckoutDto {
        createCaptured = cart_id
        return createResult
    }

    func update(
        checkout_id: String,
        status: String?,
        email: String?,
        success_url: String?,
        cancel_url: String?,
        payment_method: String?,
        shipping_address: [String: Any]?,
        billing_address: [String: Any]?,
        buyer_accepts_terms_conditions: Bool,
        buyer_accepts_purchase_conditions: Bool
    ) async throws -> UpdateCheckoutDto {
        updateCaptured = (checkout_id, email, success_url, cancel_url, payment_method)
        return UpdateCheckoutDto(id: checkout_id, status: status ?? "", checkoutUrl: success_url)
    }

    func delete(checkout_id: String) async throws -> RemoveCheckoutDto { throw MockError.unimplemented }
}

private final class MockPaymentRepository: PaymentRepository {
    var stripeIntentResult: PaymentIntentStripeDto = SampleFactory.makeStripeIntent()
    var stripeLinkResult: InitPaymentStripeDto = InitPaymentStripeDto(checkoutUrl: "https://stripe", orderId: 1)
    var klarnaInitResult: InitPaymentKlarnaDto = InitPaymentKlarnaDto(orderId: "ord", status: "ok", locale: "en_US", htmlSnippet: "<div></div>")
    var klarnaNativeInitResult: InitPaymentKlarnaNativeDto = SampleFactory.makeKlarnaNativeInit()
    var klarnaNativeConfirmResult: ConfirmPaymentKlarnaNativeDto = ConfirmPaymentKlarnaNativeDto(orderId: "order", checkoutId: "chk", fraudStatus: nil, order: nil)
    var klarnaNativeOrderResult: KlarnaNativeOrderDto = SampleFactory.makeKlarnaNativeOrder()

    var lastStripeIntentCheckoutId: String?
    var lastStripeIntentEphemeralKey: Bool?

    func getAvailableMethods() async throws -> [GetAvailablePaymentMethodsDto] { [] }

    func stripeIntent(checkoutId: String, returnEphemeralKey: Bool?) async throws -> PaymentIntentStripeDto {
        lastStripeIntentCheckoutId = checkoutId
        lastStripeIntentEphemeralKey = returnEphemeralKey
        return stripeIntentResult
    }

    func stripeLink(checkoutId: String, successUrl: String, paymentMethod: String, email: String) async throws -> InitPaymentStripeDto {
        return stripeLinkResult
    }

    func klarnaInit(checkoutId: String, countryCode: String, href: String, email: String?) async throws -> InitPaymentKlarnaDto {
        return klarnaInitResult
    }

    func vippsInit(checkoutId: String, email: String, returnUrl: String) async throws -> InitPaymentVippsDto {
        return InitPaymentVippsDto(paymentUrl: returnUrl)
    }

    func klarnaNativeInit(checkoutId: String, input: KlarnaNativeInitInputDto) async throws -> InitPaymentKlarnaNativeDto {
        return klarnaNativeInitResult
    }

    func klarnaNativeConfirm(checkoutId: String, input: KlarnaNativeConfirmInputDto) async throws -> ConfirmPaymentKlarnaNativeDto {
        return klarnaNativeConfirmResult
    }

    func klarnaNativeOrder(orderId: String, userId: String?) async throws -> KlarnaNativeOrderDto {
        return klarnaNativeOrderResult
    }
}

private final class MockDiscountRepository: DiscountRepository {
    var applyResult: ApplyDiscountDto = ApplyDiscountDto(executed: false, message: "")
    var lastApplyCode: String?
    var lastApplyCartId: String?

    func get() async throws -> [GetDiscountsDto] { [] }
    func getByChannel() async throws -> [GetDiscountsDto] { [] }
    func getById(discountId: Int) async throws -> GetDiscountByIdDto { GetDiscountByIdDto(id: discountId, code: "CODE", percentage: 10) }
    func getType(id: Int?, type: String?) async throws -> [GetDiscountTypeDto] { [] }
    func add(code: String, percentage: Int, startDate: String, endDate: String, typeId: Int) async throws -> AddDiscountDto {
        AddDiscountDto(id: 1, code: code, percentage: percentage, startDate: startDate, endDate: endDate)
    }
    func apply(code: String, cartId: String) async throws -> ApplyDiscountDto {
        lastApplyCode = code
        lastApplyCartId = cartId
        return applyResult
    }
    func deleteApplied(code: String, cartId: String) async throws -> DeleteAppliedDiscountDto {
        DeleteAppliedDiscountDto(executed: true, message: "removed")
    }
    func delete(discountId: Int) async throws -> DeleteDiscountDto { DeleteDiscountDto(executed: true, message: "deleted") }
    func update(discountId: Int, code: String?, percentage: Int?, startDate: String?, endDate: String?, products: [Int]?) async throws -> UpdateDiscountDto {
        UpdateDiscountDto(id: discountId, code: code, percentage: percentage, startDate: startDate, endDate: endDate)
    }
    func verify(verifyDiscountId: Int?, code: String?) async throws -> VerifyDiscountDto {
        VerifyDiscountDto(valid: true, message: "", discount: nil)
    }
}

private final class MockMarketRepository: MarketRepository {
    var availableResult: [GetAvailableGlobalMarketsDto] = []
    func getAvailable() async throws -> [GetAvailableGlobalMarketsDto] { availableResult }
}

private struct MockSdkProvider: CartManagingSDK {
    var cart: CartRepository
    var product: ProductRepository
    var checkout: CheckoutRepository
    var payment: PaymentRepository
    var discount: DiscountRepository
    var market: MarketRepository

    init(
        cart: CartRepository = MockCartRepository(),
        product: ProductRepository = MockProductRepository(),
        checkout: CheckoutRepository = MockCheckoutRepository(),
        payment: PaymentRepository = MockPaymentRepository(),
        discount: DiscountRepository = MockDiscountRepository(),
        market: MarketRepository = MockMarketRepository()
    ) {
        self.cart = cart
        self.product = product
        self.checkout = checkout
        self.payment = payment
        self.discount = discount
        self.market = market
    }
}
