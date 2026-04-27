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

    /// Call once at app boot from `tv2demoApp.init`. Each call declares an
    /// explicit named placement = (name, type, locationId). The dashboard's
    /// "Add placement" picker reads these and operators can ONLY bind
    /// campaign placements to one of these named entries — strict contract.
    ///
    /// To add a new placement (e.g. a banner above the casting overlay):
    /// 1. Call `registerPlacement` here with a unique `name` and the
    ///    locationId your view uses.
    /// 2. In the SwiftUI view at that location, instantiate
    ///    `VProductBanner(locationId: "casting_above")` (or similar).
    /// 3. Reboot the demo. Manifest endpoint upserts the row, dashboard
    ///    picker shows it next time the operator adds a placement.
    @MainActor
    static func registerAll() {
        VioRuntime.registerPlacement(
            name: "Carrusel home (TV2)",
            type: TV2ProductCarouselPlacement.self,
            locationId: "home_top",
            locationDisplayName: "Home — Top"
        )
        VioRuntime.registerPlacement(
            name: "Carrusel pre-kickoff",
            type: TV2ProductCarouselPlacement.self,
            locationId: "match_pre_kickoff",
            locationDisplayName: "Match — Pre-kickoff"
        )
        VioRuntime.registerPlacement(
            name: "Carrusel below-video",
            type: TV2ProductCarouselPlacement.self,
            locationId: "home_below_video",
            locationDisplayName: "Home — Below video"
        )
        VioRuntime.registerPlacement(
            name: "Banner match sidebar",
            type: TV2ProductBannerPlacement.self,
            locationId: "match_sidebar",
            locationDisplayName: "Match — Sidebar"
        )
        VioRuntime.registerPlacement(
            name: "Spotlight casting overlay",
            type: TV2ProductSpotlightPlacement.self,
            locationId: "casting_overlay",
            locationDisplayName: "Casting overlay"
        )

        let registry = VioPlacementRegistry.shared
        print("🧩 [TV2Demo] Placement registry seeded — placements=\(registry.registeredPlacements.count) (components=\(registry.registeredComponents.count) locations=\(registry.registeredLocations.count) auto-derived)")
    }
}
