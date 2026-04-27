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

    /// Call once at app boot from `tv2demoApp.init`. To expose a new slot,
    /// add a `registerPlacementLocation(...)` call here AND render the
    /// matching `VProductCarousel(locationId: ...)` (or other view) at the
    /// right place in the layout. After cold-start the operator can create
    /// an `app_placement` against this slot in the dashboard.
    @MainActor
    static func registerAll() {
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_top",         displayName: "Home — Top"))
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_below_video", displayName: "Home — Below video"))
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "match_sidebar",    displayName: "Match — Sidebar"))
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "match_pre_kickoff",displayName: "Match — Pre-kickoff"))
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "casting_overlay",  displayName: "Casting overlay"))

        let registry = VioPlacementRegistry.shared
        print("🧩 [TV2Demo] Slot registry seeded — locations=\(registry.registeredLocations.count)")
    }
}
