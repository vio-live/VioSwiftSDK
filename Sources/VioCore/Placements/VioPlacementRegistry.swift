import Foundation

// MARK: - Public API: how a partner declares a placement component

/// How many products a placement component is bound to.
///
/// Drives the operator's product-picker UX in the dashboard. The backend's
/// `app_components` table doesn't enforce this — it's an SDK-side hint that
/// the dashboard reads when scaffolding the picker.
public enum VioProductBindingMode: String, Codable, Sendable {
    /// Single product. Picker is a 1-of-N selector.
    case single
    /// Multiple products (max optional). Picker is a multi-select.
    case multiple
    /// All products from a category / sponsor catalog. Picker is a category
    /// picker; the actual product list resolves at render time.
    case category
}

/// Descriptor a partner provides at app boot to register a SwiftUI placement
/// component. Conforming types are usually thin wrappers around the existing
/// `VProductCarousel`, `VProductSpotlight`, ... views; partners can also
/// fork the templates and conform their custom types.
///
/// The single source of truth for the link between this Swift type and the
/// dashboard's "Add placement" picker is `componentType` — it must match a
/// `components.type` row on the backend (rows with `is_template = true`).
/// The manifest endpoint resolves it via `getCanonicalComponentByType`.
///
/// To register at app boot:
///
/// ```swift
/// VioPlacementRegistry.shared.register(MyTV2Carousel.self)
/// ```
///
/// or via the convenience entry on `Vio`:
///
/// ```swift
/// Vio.registerPlacementComponent(MyTV2Carousel.self)
/// ```
public protocol VioPlacementComponent {
    /// Backend-recognized type. Examples: `"product_carousel"`,
    /// `"product_spotlight"`, `"product_banner"`. Custom types must be
    /// pre-registered globally on the backend (rows in `components` with
    /// `is_template = true`); the manifest endpoint warns on unknown types
    /// rather than silently accepting them.
    static var componentType: String { get }

    /// How many products this placement renders. Drives the dashboard picker.
    static var productMode: VioProductBindingMode { get }

    /// Cap on `productMode == .multiple`. Nil → unlimited.
    static var maxProducts: Int? { get }
}

/// Default to nil for partners that don't care about a cap.
public extension VioPlacementComponent {
    static var maxProducts: Int? { nil }
}

// MARK: - Public API: how a partner declares a slot location

/// A slot in the partner's app layout where a placement may render. Declared
/// at app boot so the dashboard's "Add placement" location picker only ever
/// offers slots the dev's code actually exposes.
///
/// `id` mirrors the string the dev writes in their layout, and the same string
/// the operator binds to via `campaign_components.location_id`. Keep it short
/// and stable (treat it like an analytics event name) — renaming an id is a
/// breaking change for any campaign already configured against it.
public struct VioPlacementLocation: Sendable, Equatable {
    public let id: String
    public let displayName: String?

    public init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = displayName
    }
}

// MARK: - Internal model: what the registry stores

/// Type-erased descriptor of a registered component. Used by the manifest
/// upload + by the upcoming `VioPlacementSlot` resolver. Not generic so it
/// can sit in a homogeneous array.
public struct VioPlacementComponentRegistration: Sendable, Equatable {
    public let componentType: String
    public let productMode: VioProductBindingMode
    public let maxProducts: Int?

    public init(componentType: String, productMode: VioProductBindingMode, maxProducts: Int? = nil) {
        self.componentType = componentType
        self.productMode = productMode
        self.maxProducts = maxProducts
    }
}

// MARK: - Registry

/// Process-wide registry of placement components and locations the partner has
/// declared. Single source of truth that:
///
/// 1. The manifest upload reads to build the request body for
///    `POST /v2/mobile/components/manifest`.
/// 2. The future `VioPlacementSlot(locationId:)` resolver reads to look up the
///    Swift type to instantiate when a campaign instance binds to that slot.
///
/// The registry is intentionally **additive** — duplicate registrations of
/// the same type (or location id) collapse to a single entry. Partners can
/// safely re-register on hot reload / debug rebuild without ballooning state.
@MainActor
public final class VioPlacementRegistry {
    public static let shared = VioPlacementRegistry()

    private var componentsByType: [String: VioPlacementComponentRegistration] = [:]
    private var locationsById: [String: VioPlacementLocation] = [:]

    private init() {}

    /// Register a component type. Idempotent — the same `componentType` is
    /// stored once. Subsequent registrations with a different `productMode`
    /// or `maxProducts` overwrite (last writer wins) so devs iterating in
    /// dev mode see their changes reflected immediately.
    public func register<T: VioPlacementComponent>(_ type: T.Type) {
        let reg = VioPlacementComponentRegistration(
            componentType: T.componentType,
            productMode: T.productMode,
            maxProducts: T.maxProducts
        )
        componentsByType[reg.componentType] = reg
    }

    /// Register a location id. Idempotent — same `id` is stored once.
    /// `displayName` is overwritten on re-register (matches backend upsert
    /// semantics so dev can rename slots).
    public func registerLocation(_ location: VioPlacementLocation) {
        locationsById[location.id] = location
    }

    /// Snapshot of what's currently registered. Sorted by type/id so manifest
    /// payloads are stable across runs (helpful for telemetry / debugging).
    public var registeredComponents: [VioPlacementComponentRegistration] {
        componentsByType.values.sorted { $0.componentType < $1.componentType }
    }

    public var registeredLocations: [VioPlacementLocation] {
        locationsById.values.sorted { $0.id < $1.id }
    }

    /// Look up a registered component by type. Returns nil for unknown types.
    public func component(forType type: String) -> VioPlacementComponentRegistration? {
        componentsByType[type]
    }

    /// Look up a registered location by id. Returns nil for unknown ids.
    public func location(forId id: String) -> VioPlacementLocation? {
        locationsById[id]
    }

    /// Reset state. Used by the SDK test suite — host apps should never call
    /// this in production.
    internal func _resetForTesting() {
        componentsByType.removeAll()
        locationsById.removeAll()
    }

    // MARK: - Manifest payload

    /// Build the request body for `POST /v2/mobile/components/manifest`.
    /// Empty arrays are still emitted so the backend can distinguish
    /// "I have no components/locations" from "I haven't told you about either".
    public func manifestPayload() -> [String: Any] {
        let components: [[String: Any]] = registeredComponents.map { reg in
            var dict: [String: Any] = [
                "type": reg.componentType,
                "productMode": reg.productMode.rawValue,
            ]
            if let max = reg.maxProducts {
                dict["maxProducts"] = max
            }
            return dict
        }
        let locations: [[String: Any]] = registeredLocations.map { loc in
            var dict: [String: Any] = ["id": loc.id]
            if let name = loc.displayName {
                dict["displayName"] = name
            }
            return dict
        }
        return [
            "components": components,
            "locations": locations,
        ]
    }
}
