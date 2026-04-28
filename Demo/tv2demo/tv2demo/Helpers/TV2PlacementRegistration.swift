//
//  TV2PlacementRegistration.swift
//  tv2demo
//
//  Demo-side slot registration for the placement system (post 2026-04-27
//  pivot). The SDK declares ONLY the slot locations the app's UI exposes;
//  named app_placements (template + name + locationId) are created by the
//  operator/admin in the dashboard `/apps/:id` "Add from library" form.
//
//  Cold-start flow:
//    1. tv2demoApp.init runs `TV2PlacementRegistration.registerAll()` →
//       VioPlacementRegistry stores the locations.
//    2. CampaignManager.fetchAndApplySdkBootstrapNow runs the manifest
//       upload → POST /v2/mobile/components/manifest with `locations[]`.
//    3. Backend upserts app_component_locations and soft-deprecates any
//       location not in the new payload.
//    4. Operator goes to dashboard `/apps/18` → Placements → "Add from
//       library" and picks template + name + locationId from this list.
//

import Foundation
import VioCore

enum TV2PlacementRegistration {

    /// Call once at app boot from `tv2demoApp.init`. **Rule for the dev**:
    /// every slot id registered here MUST be rendered by a placement view
    /// somewhere in the layout (`VProductCarousel(locationId: ...)`, etc).
    /// Otherwise the dashboard offers an operator a slot the app doesn't
    /// actually render to — operator creates a placement, nothing happens.
    ///
    /// To add a new slot:
    ///   1. Add a `registerPlacementLocation(...)` call here.
    ///   2. Render the matching placement view in the SwiftUI layout.
    ///   3. Cold-start the app — the manifest endpoint upserts the slot.
    ///   4. Tell the operator/admin the slot is available.
    @MainActor
    static func registerAll() {
        // Rendered by HomeView.swift  → VProductCarousel(locationId: "home_top", layout: "compact")
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_top",          displayName: "Home — Top"))

        // Rendered by HomeView.swift  → VProductSpotlight(locationId: "home_spotlight")
        // Featured product (single-product hero) right below the "Direkte" rail
        // on the Home tab. Renders nothing until an operator binds a campaign
        // component — pure layout-friendly placeholder.
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_spotlight",    displayName: "Home — Featured product"))

        // Rendered by HomeView.swift  → VOfferBanner(locationId: "home_offer")
        // Promo banner with countdown + sponsor logo + CTA deeplink. Sits
        // directly below the hardcoded OfferBannerView during the
        // migration window so an operator can A/B compare the dynamic
        // version against the legacy hardcoded one. The hardcoded view
        // gets removed once the dynamic flow is validated end-to-end.
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_offer",        displayName: "Home — Offer banner (promo with countdown)"))

        // Rendered by HomeView.swift  → VProductBanner(locationId: "home_product_banner")
        // Single-product banner with bg image + CTA + optional sponsor
        // logo overlay. Layout preset (compact / standard / large)
        // adjusts height + font sizes from the dashboard. Mounted
        // below the carousel to give the operator a separate slot
        // from `home_offer` (offer_banner = countdown promo,
        // product_banner = single-product feature). Sprint 2026-04-28
        // PM Phase 2.
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_product_banner", displayName: "Home — Product banner (single product)"))

        // Rendered by HomeView.swift  → VProductStore(locationId: "home_store")
        // Multi-sponsor product grid (Phase 2). Operator curates
        // products from any campaign sponsor; tap opens detail
        // modal (one at a time). Lives at the bottom of the Home
        // tab as a "shop" section.
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_store",         displayName: "Home — Multi-sponsor product store"))

        // Rendered by MatchDetailView.swift  → VProductCarousel(locationId: "match_pre_kickoff", layout: "compact")
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "match_pre_kickoff", displayName: "Match — Pre-kickoff"))

        let registry = VioPlacementRegistry.shared
        print("🧩 [TV2Demo] Slot registry seeded — locations=\(registry.registeredLocations.count)")
    }
}
