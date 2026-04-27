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

/// Named instance of a placement — the explicit (name, componentType,
/// locationId) tuple the dev's app implements. Replaces the implicit
/// (types × locations) cross-product that older versions of the SDK used.
///
/// The dashboard's "Add placement" picker reads from these. Operator picks
/// one named placement, then assigns sponsor + product list. Cannot bind
/// to a (component, location) combo the dev hasn't declared explicitly.
public struct VioPlacementRegistration: Sendable, Equatable {
    public let name: String
    public let componentType: String
    public let locationId: String
    public let locationDisplayName: String?

    public init(name: String, componentType: String, locationId: String, locationDisplayName: String? = nil) {
        self.name = name
        self.componentType = componentType
        self.locationId = locationId
        self.locationDisplayName = locationDisplayName
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
    /// Named placements indexed by their human name (UNIQUE per app on the
    /// backend). Two indexes mirror the backend's dual-UNIQUE schema so
    /// in-process collisions surface before the manifest round-trip.
    private var placementsByName: [String: VioPlacementRegistration] = [:]
    /// Slot index `(componentType, locationId)` → name, for collision detection.
    private var placementsBySlot: [String: String] = [:]
    private static func slotKey(componentType: String, locationId: String) -> String {
        "\(componentType)|\(locationId)"
    }

    private init() {}

    /// Register a component type. Idempotent — the same `componentType` is
    /// stored once. Subsequent registrations with a different `productMode`
    /// or `maxProducts` overwrite (last writer wins) so devs iterating in
    /// dev mode see their changes reflected immediately.
    ///
    /// **Prefer `registerPlacement(name:type:locationId:)`** for new code —
    /// this method registers the type only, leaving the (type, location)
    /// binding implicit. The named-placement API makes the contract
    /// explicit and prevents the dashboard from offering combos the app
    /// doesn't render.
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
    ///
    /// **Prefer `registerPlacement(name:type:locationId:)`** for new code.
    public func registerLocation(_ location: VioPlacementLocation) {
        locationsById[location.id] = location
    }

    /// Register a named placement instance. Replaces the implicit
    /// (component × location) cross-product with an explicit declaration.
    ///
    /// Auto-populates the legacy `componentsByType` and `locationsById`
    /// indexes too, so views that resolve via `component(forType:)` or
    /// `location(forId:)` keep working even if the partner only uses the
    /// named-placement API.
    ///
    /// Conflict semantics in-process (mirror backend's smart upsert):
    ///  - Same `name` re-registered → overwrite (last writer wins for the
    ///    componentType/locationId fields).
    ///  - Different `name` claiming the same (componentType, locationId)
    ///    slot → reject + log; the dev should pick a distinct location_id
    ///    for A/B variants.
    public func registerPlacement<T: VioPlacementComponent>(
        name: String,
        type: T.Type,
        locationId: String,
        locationDisplayName: String? = nil
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = locationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedLocation.isEmpty else {
            print("⚠️ [VioPlacementRegistry] registerPlacement ignored — empty name or locationId")
            return
        }
        let slotKey = Self.slotKey(componentType: T.componentType, locationId: trimmedLocation)
        if let occupant = placementsBySlot[slotKey], occupant != trimmedName {
            print("⚠️ [VioPlacementRegistry] slot already named '\(occupant)' — refusing to also name it '\(trimmedName)'. Use a distinct locationId for A/B variants.")
            return
        }
        // Drop any prior slot mapping for this name (rename within same SDK boot).
        if let existing = placementsByName[trimmedName] {
            placementsBySlot.removeValue(forKey: Self.slotKey(componentType: existing.componentType, locationId: existing.locationId))
        }
        let registration = VioPlacementRegistration(
            name: trimmedName,
            componentType: T.componentType,
            locationId: trimmedLocation,
            locationDisplayName: locationDisplayName
        )
        placementsByName[trimmedName] = registration
        placementsBySlot[slotKey] = trimmedName

        // Auto-populate legacy indexes — view-side code (`getActiveComponent`
        // etc.) still consults these. Backwards-compat for partners that
        // mix the two APIs and for the manifest endpoint's dual-write path.
        componentsByType[T.componentType] = VioPlacementComponentRegistration(
            componentType: T.componentType,
            productMode: T.productMode,
            maxProducts: T.maxProducts
        )
        locationsById[trimmedLocation] = VioPlacementLocation(
            id: trimmedLocation,
            displayName: locationDisplayName ?? locationsById[trimmedLocation]?.displayName
        )
    }

    /// Snapshot of what's currently registered. Sorted by type/id so manifest
    /// payloads are stable across runs (helpful for telemetry / debugging).
    public var registeredComponents: [VioPlacementComponentRegistration] {
        componentsByType.values.sorted { $0.componentType < $1.componentType }
    }

    public var registeredLocations: [VioPlacementLocation] {
        locationsById.values.sorted { $0.id < $1.id }
    }

    /// Snapshot of named placements registered via `registerPlacement(...)`.
    /// Sorted by `name` so manifest payloads are stable across runs.
    public var registeredPlacements: [VioPlacementRegistration] {
        placementsByName.values.sorted { $0.name < $1.name }
    }

    /// Look up a registered component by type. Returns nil for unknown types.
    public func component(forType type: String) -> VioPlacementComponentRegistration? {
        componentsByType[type]
    }

    /// Look up a registered location by id. Returns nil for unknown ids.
    public func location(forId id: String) -> VioPlacementLocation? {
        locationsById[id]
    }

    /// Look up a named placement. Returns nil for unknown names.
    public func placement(forName name: String) -> VioPlacementRegistration? {
        placementsByName[name]
    }

    /// Look up a named placement by its slot. Returns nil if no placement
    /// has been registered for that (componentType, locationId).
    public func placement(forSlot componentType: String, locationId: String) -> VioPlacementRegistration? {
        guard let name = placementsBySlot[Self.slotKey(componentType: componentType, locationId: locationId)] else {
            return nil
        }
        return placementsByName[name]
    }

    /// Reset state. Used by the SDK test suite — host apps should never call
    /// this in production.
    internal func _resetForTesting() {
        componentsByType.removeAll()
        locationsById.removeAll()
        placementsByName.removeAll()
        placementsBySlot.removeAll()
    }

    // MARK: - Manifest payload

    /// Build the request body for `POST /v2/mobile/components/manifest`.
    /// Three top-level arrays:
    ///   - `placements[]` — v2 named instances (preferred). Each entry is
    ///     `{name, componentType, locationId}`. The dashboard picker reads
    ///     from these.
    ///   - `components[]` — v1 type-only registry. Auto-derived from named
    ///     placements + any types registered via the legacy
    ///     `register(_ type:)` API. Backend dual-writes `app_components`.
    ///   - `locations[]` — v1 slot registry. Auto-derived from named
    ///     placements + any locations from the legacy `registerLocation(_:)`
    ///     API. Backend dual-writes `app_component_locations`.
    ///
    /// Empty arrays are still emitted so the backend can distinguish "I
    /// have nothing to declare" from "I haven't told you about that bucket".
    public func manifestPayload() -> [String: Any] {
        let placements: [[String: Any]] = registeredPlacements.map { reg in
            var dict: [String: Any] = [
                "name": reg.name,
                "componentType": reg.componentType,
                "locationId": reg.locationId,
            ]
            if let display = reg.locationDisplayName {
                dict["locationDisplayName"] = display
            }
            return dict
        }
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
            "placements": placements,
        ]
    }
}
