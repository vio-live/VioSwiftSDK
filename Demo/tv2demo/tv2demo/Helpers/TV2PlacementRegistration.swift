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

        // Rendered by MatchDetailView.swift  → VProductCarousel(locationId: "match_pre_kickoff", layout: "compact")
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "match_pre_kickoff", displayName: "Match — Pre-kickoff"))

        let registry = VioPlacementRegistry.shared
        print("🧩 [TV2Demo] Slot registry seeded — locations=\(registry.registeredLocations.count)")
    }
}
