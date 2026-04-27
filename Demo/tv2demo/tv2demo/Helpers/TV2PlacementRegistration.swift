//
//  TV2PlacementRegistration.swift
//  tv2demo
//
//  Demo-side declarations for the placement self-service registry.
//
//  Each conforming type below maps to a canonical components.type row on the
//  backend (rows with is_template = true). The 5 currently-shipped templates
//  are: product_carousel, product_spotlight, product_banner, product_store,
//  offer_banner, banner, countdown.
//
//  When tv2demoApp.init runs `TV2PlacementRegistration.registerAll()`, the
//  SDK registry is populated. On the next `VioSession.start()` (triggered by
//  the demo's existing `discoverCampaigns` call), the manifest endpoint is
//  POSTed and the backend upserts the corresponding app_components +
//  app_component_locations rows for client_app_id = 18 (TV2 demo apiKey).
//
//  The dashboard's "Add placement" picker (Campaign 36 → Components → Add)
//  then auto-populates with these locations and component types — the
//  operator can bind a placement instance without a Vio admin in the loop.
//

import Foundation
import VioCore

/// Carousel for shoppable products. Multi-product, max 8 to keep the UI tight.
struct TV2ProductCarouselPlacement: VioPlacementComponent {
    static var componentType: String { "product_carousel" }
    static var productMode: VioProductBindingMode { .multiple }
    static var maxProducts: Int? { 8 }
}

/// Single-product spotlight (hero treatment).
struct TV2ProductSpotlightPlacement: VioPlacementComponent {
    static var componentType: String { "product_spotlight" }
    static var productMode: VioProductBindingMode { .single }
}

/// Banner (single product, lower density than spotlight).
struct TV2ProductBannerPlacement: VioPlacementComponent {
    static var componentType: String { "product_banner" }
    static var productMode: VioProductBindingMode { .single }
}

enum TV2PlacementRegistration {

    /// Call once at app boot from `tv2demoApp.init`. The order here is the
    /// order the SDK serializes into the manifest payload (sorted
    /// alphabetically by type / id once they hit the registry, so the actual
    /// payload is stable across runs).
    @MainActor
    static func registerAll() {
        // Component types this demo's iOS code knows how to render.
        VioRuntime.registerPlacementComponent(TV2ProductCarouselPlacement.self)
        VioRuntime.registerPlacementComponent(TV2ProductSpotlightPlacement.self)
        VioRuntime.registerPlacementComponent(TV2ProductBannerPlacement.self)

        // Slot locations the demo's layout exposes. The dashboard picker only
        // ever shows these — the operator can't bind a placement to a slot
        // the dev hasn't declared.
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_top",         displayName: "Home — Top"))
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_below_video", displayName: "Home — Below video"))
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "match_sidebar",    displayName: "Match — Sidebar"))
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "match_pre_kickoff",displayName: "Match — Pre-kickoff"))
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "casting_overlay",  displayName: "Casting overlay"))

        let registry = VioPlacementRegistry.shared
        print("🧩 [TV2Demo] Placement registry seeded — components=\(registry.registeredComponents.count) locations=\(registry.registeredLocations.count)")
    }
}
