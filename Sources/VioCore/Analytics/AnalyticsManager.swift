import Foundation
#if canImport(Mixpanel)
import Mixpanel

// Typealias to facilitate usage
public typealias AnalyticsPropertyValue = MixpanelType
#else
// Fallback when Mixpanel is not available
public typealias AnalyticsPropertyValue = Any
#endif

/// Analytics Manager
///
/// Centralized analytics tracking system using Mixpanel.
/// Automatically initializes when `mixpanelToken` is provided in configuration.
@MainActor
public class AnalyticsManager {
    public static let shared = AnalyticsManager()
    
    #if canImport(Mixpanel)
    private var mixpanelInstance: MixpanelInstance?
    #endif
    
    private var configuration: AnalyticsConfiguration = .default
    private var sessionId: String = UUID().uuidString
    private var impressionTimers: [String: Date] = [:]
    private var trackedComponentViews: Set<String> = [] // To avoid cumulative tracking (once per session)
    private var componentViewCounts: [String: Int] = [:] // Total view counter per component (for CPM)
    
    private init() {}
    
    // MARK: - Configuration
    
    public func configure(_ config: AnalyticsConfiguration) {
        self.configuration = config
        
        guard config.enabled, let token = config.mixpanelToken, !token.isEmpty else {
            return
        }
        
        #if canImport(Mixpanel)
        // Initialize Mixpanel with basic configuration
        #if os(iOS) || os(tvOS)
        mixpanelInstance = Mixpanel.initialize(
            token: token,
            trackAutomaticEvents: config.autocapture,
            optOutTrackingByDefault: false,
            superProperties: [:]
        )
        #else
        mixpanelInstance = Mixpanel.initialize(
            token: token,
            optOutTrackingByDefault: false,
            superProperties: [:]
        )
        #endif
        
        // Disable Mixpanel logging to avoid unnecessary logs
        // Note: If you need to debug, you can enable this temporarily
        mixpanelInstance?.loggingEnabled = false
        
        // Configure automatic flush (Mixpanel does this by default, but we make it explicit)
        // Events are automatically sent in batches, but we can also force flush if needed
        
        // Configure server URL if specified (for EU region)
        if let apiHost = config.apiHost {
            mixpanelInstance?.serverURL = apiHost
        }
        
        // Set session ID
        mixpanelInstance?.registerSuperProperties(["session_id": sessionId])
        
        // Set SDK version
        mixpanelInstance?.registerSuperProperties([
            "sdk_version": "1.0.0",
            "sdk_platform": "ios"
        ])
        
        #else
        // SDK de Mixpanel no disponible
        #endif
    }
    
    // MARK: - User Identification
    
    public func identify(_ userId: String) {
        #if canImport(Mixpanel)
        mixpanelInstance?.identify(distinctId: userId)
        #endif
    }
    
    public func setUserProperties(_ properties: [String: AnalyticsPropertyValue]) {
        #if canImport(Mixpanel)
        var mixpanelProperties: [String: MixpanelType] = [:]
        for (key, value) in properties {
            if let mixpanelValue = value as? MixpanelType {
                mixpanelProperties[key] = mixpanelValue
            }
        }
        mixpanelInstance?.people.set(properties: mixpanelProperties)
        #endif
    }
    
    // MARK: - Component Tracking
    
    public func trackComponentView(
        componentId: String,
        componentType: String,
        componentName: String? = nil,
        campaignId: Int? = nil,
        metadata: [String: Any]? = nil
    ) {
        guard configuration.trackComponentViews else { return }
        
        // Get project and campaign information from global configuration
        let projectId = VioConfiguration.shared.apiKey
        let currentCampaignId = campaignId ?? CampaignManager.shared.currentCampaign?.id
        
        var properties: [String: AnalyticsPropertyValue] = [
            "component_id": componentId,
            "component_type": componentType,
            "project_id": projectId,  // API Key as project identifier
            "project_api_key": projectId  // Also as api_key for compatibility
        ]
        
        if let name = componentName {
            properties["component_name"] = name
        }
        
        if let campaignId = currentCampaignId {
            properties["campaign_id"] = campaignId
        }
        
        // Add metadata
        if let metadata = metadata {
            for (key, value) in metadata {
                #if canImport(Mixpanel)
                if let mixpanelValue = value as? MixpanelType {
                    properties[key] = mixpanelValue
                }
                #else
                // Sin Mixpanel, aceptar cualquier valor
                properties[key] = value
                #endif
            }
        }
        
        // Event name basado en tipo de componente (sin prefijo Vio)
        let eventName = "\(componentType.capitalized.replacingOccurrences(of: "_", with: " ")) Viewed"
        
        // Total views counter (for CPM - Cost Per Mille)
        // This counter increments every time the component is viewed, even if already tracked
        let viewKey = "\(componentId)-\(componentType)"
        let totalViewCount = (componentViewCounts[viewKey] ?? 0) + 1
        componentViewCounts[viewKey] = totalViewCount
        
        // Add total view count to properties (important for CPM)
        properties["total_view_count"] = totalViewCount
        properties["view_count"] = totalViewCount // Also as view_count for compatibility
        
        // Cumulative tracking: only track once per component per session
        // This avoids saturating Mixpanel with duplicate events from the same component
        let isFirstViewInSession = !trackedComponentViews.contains(viewKey)
        
        if isFirstViewInSession {
            // First time this component is viewed in this session
            trackedComponentViews.insert(viewKey)
            
            // Track component-specific event (only once per session)
            track(eventName, properties: properties)
            
            // Track unified "Component Viewed" event (only once per session)
            track("Component Viewed", properties: properties)
        }
        
        // IMPORTANT: Always track impression event for CPM
        // This event is tracked every time the component is viewed, regardless of whether it was already seen
        // Allows correct billing by CPM (Cost Per Mille)
        // We use a specific event name for component impressions
        track("Component Impression Count", properties: properties)
        
        // Start timer for impression (viewing duration)
        if configuration.trackImpressions {
            impressionTimers[componentId] = Date()
        }
    }
    
    public func trackComponentClick(
        componentId: String,
        componentType: String,
        action: String,
        componentName: String? = nil,
        campaignId: Int? = nil,
        metadata: [String: Any]? = nil
    ) {
        guard configuration.trackComponentClicks else { return }
        
        var properties: [String: AnalyticsPropertyValue] = [
            "component_id": componentId,
            "component_type": componentType,
            "action": action
        ]
        
        if let name = componentName {
            properties["component_name"] = name
        }
        
        if let campaignId = campaignId {
            properties["campaign_id"] = campaignId
        }
        
        if let metadata = metadata {
            for (key, value) in metadata {
                #if canImport(Mixpanel)
                if let mixpanelValue = value as? MixpanelType {
                    properties[key] = mixpanelValue
                }
                #else
                // Sin Mixpanel, aceptar cualquier valor
                properties[key] = value
                #endif
            }
        }
        
        let eventName = "\(componentType.capitalized.replacingOccurrences(of: "_", with: " ")) Clicked"
        
        track(eventName, properties: properties)
    }
    
    public func trackComponentImpression(
        componentId: String,
        componentType: String,
        duration: TimeInterval
    ) {
        guard configuration.trackImpressions else { return }
        
        let properties: [String: AnalyticsPropertyValue] = [
            "component_id": componentId,
            "component_type": componentType,
            "duration_seconds": duration
        ]
        
        track("Component Impression", properties: properties)
    }
    
    // MARK: - Product Tracking
    
    public func trackProductViewed(
        productId: String,
        productName: String,
        productPrice: Double? = nil,
        productCurrency: String? = nil,
        source: String? = nil,
        componentId: String? = nil,
        componentType: String? = nil
    ) {
        guard configuration.trackProductEvents else { return }
        
        var properties: [String: AnalyticsPropertyValue] = [
            "product_id": productId,
            "product_name": productName
        ]
        
        if let price = productPrice {
            properties["product_price"] = price
        }
        
        if let currency = productCurrency {
            properties["product_currency"] = currency
        }
        
        if let source = source {
            properties["source"] = source
        }
        
        if let componentId = componentId {
            properties["component_id"] = componentId
        }
        
        if let componentType = componentType {
            properties["component_type"] = componentType
        }
        
        track("Product Viewed", properties: properties)
    }
    
    public func trackProductAddedToCart(
        productId: String,
        productName: String,
        quantity: Int = 1,
        productPrice: Double? = nil,
        productCurrency: String? = nil,
        source: String? = nil,
        componentId: String? = nil
    ) {
        guard configuration.trackProductEvents else { return }
        
        var properties: [String: AnalyticsPropertyValue] = [
            "product_id": productId,
            "product_name": productName,
            "quantity": quantity
        ]
        
        if let price = productPrice {
            properties["product_price"] = price
            properties["revenue"] = price * Double(quantity)
        }
        
        if let currency = productCurrency {
            properties["currency"] = currency
        }
        
        if let source = source {
            properties["source"] = source
        }
        
        if let componentId = componentId {
            properties["component_id"] = componentId
        }
        
        track("Product Added to Cart", properties: properties)
    }
    
    // MARK: - Transaction Tracking
    
    public func trackCheckoutStarted(
        checkoutId: String,
        cartValue: Double,
        currency: String,
        productCount: Int,
        userEmail: String? = nil,
        userFirstName: String? = nil,
        userLastName: String? = nil,
        userId: String? = nil
    ) {
        guard configuration.trackTransactions else { return }
        
        // Identify user if we have email or userId
        if let email = userEmail, !email.isEmpty {
            identify(email)
            #if canImport(Mixpanel)
            var userProperties: [String: AnalyticsPropertyValue] = [
                "email": email as! AnalyticsPropertyValue,
                "last_checkout_date": Date().timeIntervalSince1970 as! AnalyticsPropertyValue
            ]
            
            // Add full name if available
            var fullName: String? = nil
            if let firstName = userFirstName, !firstName.isEmpty {
                userProperties["$first_name"] = firstName as! AnalyticsPropertyValue
                fullName = firstName
            }
            if let lastName = userLastName, !lastName.isEmpty {
                userProperties["$last_name"] = lastName as! AnalyticsPropertyValue
                if let firstName = fullName {
                    fullName = "\(firstName) \(lastName)"
                } else {
                    fullName = lastName
                }
            }
            
            // Set full name if available
            if let name = fullName, !name.isEmpty {
                userProperties["$name"] = name as! AnalyticsPropertyValue
            }
            
            setUserProperties(userProperties)
            #endif
        } else if let userId = userId, !userId.isEmpty {
            identify(userId)
        }
        
        var properties: [String: AnalyticsPropertyValue] = [
            "checkout_id": checkoutId,
            "cart_value": cartValue,
            "currency": currency,
            "product_count": productCount
        ]
        
        if let email = userEmail {
            properties["user_email"] = email
        }
        
        if let firstName = userFirstName, !firstName.isEmpty {
            properties["user_first_name"] = firstName
        }
        
        if let lastName = userLastName, !lastName.isEmpty {
            properties["user_last_name"] = lastName
        }
        
        track("Checkout Started", properties: properties)
    }
    
    public func trackTransaction(
        checkoutId: String,
        transactionId: String? = nil,
        revenue: Double,
        currency: String,
        paymentMethod: String,
        products: [[String: Any]],
        discount: Double? = nil,
        shipping: Double? = nil,
        tax: Double? = nil
    ) {
        guard configuration.trackTransactions else { return }
        
        var properties: [String: AnalyticsPropertyValue] = [
            "checkout_id": checkoutId,
            "revenue": revenue,
            "currency": currency,
            "payment_method": paymentMethod,
            "product_count": products.count
        ]
        
        if let transactionId = transactionId {
            properties["transaction_id"] = transactionId
        }
        
        if let discount = discount {
            properties["discount"] = discount
        }
        
        if let shipping = shipping {
            properties["shipping"] = shipping
        }
        
        if let tax = tax {
            properties["tax"] = tax
        }
        
        // Convertir productos a formato Mixpanel
        #if canImport(Mixpanel)
        var mixpanelProducts: [[String: MixpanelType]] = []
        for product in products {
            var mixpanelProduct: [String: MixpanelType] = [:]
            for (key, value) in product {
                if let mixpanelValue = value as? MixpanelType {
                    mixpanelProduct[key] = mixpanelValue
                }
            }
            mixpanelProducts.append(mixpanelProduct)
        }
        properties["products"] = mixpanelProducts as! AnalyticsPropertyValue
        #else
        properties["products"] = products
        #endif
        
        track("Checkout Completed", properties: properties)
        
        // Track revenue en Mixpanel People
        #if canImport(Mixpanel)
        mixpanelInstance?.people.trackCharge(amount: revenue, properties: [
            "currency": currency,
            "checkout_id": checkoutId
        ])
        #endif
    }
    
    // MARK: - Generic Track
    
    public func track(_ eventName: String, properties: [String: AnalyticsPropertyValue]? = nil) {
        #if canImport(Mixpanel)
        guard let mixpanel = mixpanelInstance else { return }
        
        // Convert properties to MixpanelType format correctly
        var finalProperties: [String: MixpanelType] = [:]
        
        // Add base properties
        finalProperties["session_id"] = sessionId
        finalProperties["timestamp"] = Date().timeIntervalSince1970
        
        // Add properties passed as parameter
        if let properties = properties {
            for (key, value) in properties {
                if let mixpanelValue = value as? MixpanelType {
                    finalProperties[key] = mixpanelValue
                } else {
                    // Convert basic types to MixpanelType
                    switch value {
                    case let stringValue as String:
                        finalProperties[key] = stringValue
                    case let intValue as Int:
                        finalProperties[key] = intValue
                    case let doubleValue as Double:
                        finalProperties[key] = doubleValue
                    case let boolValue as Bool:
                        finalProperties[key] = boolValue
                    default:
                        // Try to convert to String as last resort
                        finalProperties[key] = String(describing: value)
                    }
                }
            }
        }
        
        // Track event according to Mixpanel documentation
        // Events automatically appear in Lexicon when tracked for the first time
        mixpanel.track(event: eventName, properties: finalProperties)
        
        // Note: Mixpanel automatically sends events in batches every ~60 seconds
        // If you need to see events immediately in Lexicon during development,
        // you can call mixpanel.flush() but this may affect performance
        #endif
    }
    
    /// Send events immediately to Mixpanel (useful for testing/debugging)
    /// In production, Mixpanel automatically sends in batches
    public func flush() {
        #if canImport(Mixpanel)
        mixpanelInstance?.flush()
        #endif
    }
    
    // MARK: - Impression Tracking Helper
    
    public func endImpression(componentId: String, componentType: String) {
        guard let startTime = impressionTimers[componentId] else { return }
        let duration = Date().timeIntervalSince(startTime)
        impressionTimers.removeValue(forKey: componentId)
        
        // Only track if visible for more than 1 second
        if duration >= 1.0 {
            trackComponentImpression(
                componentId: componentId,
                componentType: componentType,
                duration: duration
            )
        }
    }
}

