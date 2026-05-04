import Foundation

/// Translation keys used throughout the Vio SDK
/// Use these keys to reference translations in your configuration file
public enum VioTranslationKey: String, CaseIterable {
    // MARK: - Common
    case addToCart = "common.addToCart"
    case remove = "common.remove"
    case close = "common.close"
    case cancel = "common.cancel"
    case confirm = "common.confirm"
    case continueButton = "common.continue"
    case back = "common.back"
    case next = "common.next"
    case done = "common.done"
    case loading = "common.loading"
    case error = "common.error"
    case success = "common.success"
    case retry = "common.retry"
    case apply = "common.apply"
    case save = "common.save"
    case edit = "common.edit"
    case delete = "common.delete"
    
    // MARK: - Cart
    case cart = "cart.title"
    case cartEmpty = "cart.empty"
    case cartEmptyMessage = "cart.emptyMessage"
    /// Q4 L3 Fase C polish (2026-05-04): "paid" word, used after a
    /// sponsor's items are successfully charged in multi-sponsor cart.
    /// Rendered as "<sponsor name> <paid>", e.g. "XXL paid".
    case cartSponsorPaid = "cart.sponsorPaid"
    case itemCount = "cart.itemCount"
    case items = "cart.items"
    case item = "cart.item"
    case quantity = "cart.quantity"
    case subtotal = "cart.subtotal"
    case total = "cart.total"
    case shipping = "cart.shipping"
    case tax = "cart.tax"
    case discount = "cart.discount"
    case removeItem = "cart.removeItem"
    case updateQuantity = "cart.updateQuantity"
    
    // MARK: - Checkout
    case checkout = "checkout.title"
    case proceedToCheckout = "checkout.proceed"
    case initiatePayment = "checkout.initiatePayment"
    case completePurchase = "checkout.completePurchase"
    case purchaseComplete = "checkout.purchaseComplete"
    case purchaseCompleteMessage = "checkout.purchaseCompleteMessage"
    case purchaseCompleteMessageKlarna = "checkout.purchaseCompleteMessageKlarna"
    case paymentFailed = "checkout.paymentFailed"
    case paymentFailedMessage = "checkout.paymentFailedMessage"
    case tryAgain = "checkout.tryAgain"
    case goBack = "checkout.goBack"
    case processingPayment = "checkout.processingPayment"
    case processingPaymentMessage = "checkout.processingPaymentMessage"
    case verifyingPayment = "checkout.verifyingPayment"
    
    // MARK: - Address
    case shippingAddress = "address.shipping"
    case billingAddress = "address.billing"
    case firstName = "address.firstName"
    case lastName = "address.lastName"
    case email = "address.email"
    case phone = "address.phone"
    case address = "address.address"
    case city = "address.city"
    case state = "address.state"
    case zip = "address.zip"
    case country = "address.country"
    case phoneColon = "address.phoneColon"
    
    // MARK: - Payment
    case paymentMethod = "payment.method"
    case selectPaymentMethod = "payment.selectMethod"
    case noPaymentMethods = "payment.noMethods"
    case paymentSchedule = "payment.schedule"
    case downPaymentDueToday = "payment.downPaymentDueToday"
    case installment = "payment.installment"
    case payNext = "payment.payNext"
    case confirmWithKlarna = "payment.confirmWithKlarna"
    case cancelPayment = "payment.cancel"
    case klarnaCheckout = "payment.klarnaCheckout"
    case connectingKlarna = "payment.connectingKlarna"
    
    // MARK: - Product
    case productDetails = "product.details"
    case productDescription = "product.description"
    case options = "product.options"
    case inStock = "product.inStock"
    case outOfStock = "product.outOfStock"
    case sku = "product.sku"
    case supplier = "product.supplier"
    case category = "product.category"
    case stock = "product.stock"
    case available = "product.available"
    case noImageAvailable = "product.noImage"
    
    // MARK: - Order
    case orderSummary = "order.summary"
    case orderId = "order.id"
    case reviewOrder = "order.review"
    case orderReviewContent = "order.reviewContent"
    case productSummary = "order.productSummary"
    case totalForItem = "order.totalForItem"
    case colors = "order.colors"
    
    // MARK: - Shipping
    case shippingOptions = "shipping.options"
    case shippingRequired = "shipping.required"
    case noShippingMethods = "shipping.noMethods"
    case shippingCalculated = "shipping.calculated"
    case totalShipping = "shipping.total"
    
    // MARK: - Discount
    case discountCode = "discount.code"
    case discountApplied = "discount.applied"
    case discountRemoved = "discount.removed"
    case invalidDiscountCode = "discount.invalid"
    
    // MARK: - Validation
    case required = "validation.required"
    case invalidEmail = "validation.invalidEmail"
    case invalidPhone = "validation.invalidPhone"
    case invalidAddress = "validation.invalidAddress"
    
    // MARK: - Errors
    case networkError = "error.network"
    case serverError = "error.server"
    case unknownError = "error.unknown"
    case tryAgainLater = "error.tryAgainLater"
    
    // MARK: - Default English Values
    
    /// Default English translations for all keys
    public static let defaultEnglish: [String: String] = [
        // Common
        "common.addToCart": "Add to Cart",
        "common.remove": "Remove",
        "common.close": "Close",
        "common.cancel": "Cancel",
        "common.confirm": "Confirm",
        "common.continue": "Continue",
        "common.back": "Back",
        "common.next": "Next",
        "common.done": "Done",
        "common.loading": "Loading...",
        "common.error": "Error",
        "common.success": "Success",
        "common.retry": "Retry",
        "common.apply": "Apply",
        "common.save": "Save",
        "common.edit": "Edit",
        "common.delete": "Delete",
        
        // Cart
        "cart.title": "Cart",
        "cart.empty": "Your cart is empty",
        "cart.emptyMessage": "Add products to continue with checkout",
        "cart.itemCount": "Items",
        "cart.items": "items",
        "cart.item": "item",
        "cart.quantity": "Quantity",
        "cart.subtotal": "Subtotal",
        "cart.total": "Total",
        "cart.shipping": "Shipping",
        "cart.tax": "Tax",
        "cart.discount": "Discount",
        "cart.removeItem": "Remove item",
        "cart.updateQuantity": "Update quantity",
        
        // Checkout
        "checkout.title": "Checkout",
        "checkout.proceed": "Proceed to Checkout",
        "checkout.initiatePayment": "Initiate Payment",
        "checkout.completePurchase": "Complete Purchase",
        "checkout.purchaseComplete": "Purchase Complete!",
        "checkout.purchaseCompleteMessage": "Your order has been confirmed. You'll receive an email confirmation shortly.",
        "checkout.purchaseCompleteMessageKlarna": "You'll pay in 4x interest-free. We'll send you a reminder a few days before each payment.",
        "checkout.paymentFailed": "Payment Failed",
        "checkout.paymentFailedMessage": "Your payment could not be processed. Please try again.",
        "checkout.tryAgain": "Try Again",
        "checkout.goBack": "Go Back",
        "checkout.processingPayment": "Processing Payment",
        "checkout.processingPaymentMessage": "Please complete your payment in Vipps...",
        "checkout.verifyingPayment": "Verifying payment...",
        
        // Address
        "address.shipping": "Shipping Address",
        "address.billing": "Billing Address",
        "address.firstName": "First Name",
        "address.lastName": "Last Name",
        "address.email": "Email",
        "address.phone": "Phone",
        "address.address": "Address",
        "address.city": "City",
        "address.state": "State",
        "address.zip": "ZIP",
        "address.country": "Country",
        "address.phoneColon": "Phone :",
        
        // Payment
        "payment.method": "Payment method",
        "payment.selectMethod": "Select a payment method to continue",
        "payment.noMethods": "No payment methods available",
        "payment.schedule": "Payment Schedule",
        "payment.downPaymentDueToday": "Down payment due today",
        "payment.installment": "Installment",
        "payment.payNext": "Pay next",
        "payment.confirmWithKlarna": "Confirm with Klarna",
        "payment.cancel": "Cancel",
        "payment.klarnaCheckout": "Klarna Checkout",
        "payment.connectingKlarna": "Connecting with Klarna...",
        
        // Product
        "product.details": "Details",
        "product.description": "Description",
        "product.options": "Options",
        "product.inStock": "In Stock",
        "product.outOfStock": "Out of Stock",
        "product.sku": "SKU",
        "product.supplier": "Supplier",
        "product.category": "Category",
        "product.stock": "Stock",
        "product.available": "available",
        "product.noImage": "No Image Available",
        
        // Order
        "order.summary": "Order Summary",
        "order.id": "Order ID:",
        "order.review": "Review Order",
        "order.reviewContent": "Order review content...",
        "order.productSummary": "Product Summary",
        "order.totalForItem": "Total for this item:",
        "order.colors": "Colors:",
        
        // Shipping
        "shipping.options": "Shipping Options",
        "shipping.required": "Required",
        "shipping.noMethods": "No shipping methods available for this order yet.",
        "shipping.calculated": "Shipping is calculated automatically for this order.",
        "shipping.total": "Total shipping",
        
        // Discount
        "discount.code": "Discount Code",
        "discount.applied": "Discount applied",
        "discount.removed": "Discount removed",
        "discount.invalid": "Invalid discount code",
        
        // Validation
        "validation.required": "This field is required",
        "validation.invalidEmail": "Please enter a valid email address",
        "validation.invalidPhone": "Please enter a valid phone number",
        "validation.invalidAddress": "Please enter a complete address",
        
        // Errors
        "error.network": "Network error. Please check your connection.",
        "error.server": "Server error. Please try again later.",
        "error.unknown": "An unknown error occurred",
        "error.tryAgainLater": "Please try again later"
    ]
}

