//
//  VgPlacementRegistration.swift
//  Vg
//
//  Mirrors the TV2 demo's `TV2PlacementRegistration.registerAll()` —
//  declares the slot locations the VG app actually renders so the manifest
//  upload (POST /v2/mobile/components/manifest) lists them and the
//  dashboard "Add from library" picker offers them. Without this, the
//  manifest is empty and the SDK can short-circuit during cold-start.
//

import Foundation
import VioCore

enum VgPlacementRegistration {
    /// Call once from `VgApp.init`. Every `id` registered here MUST be
    /// rendered by a placement view somewhere (`VProductCarousel(componentId:
    /// "...")`, etc.) — otherwise the dashboard would offer the operator a
    /// slot the app never paints into.
    @MainActor
    static func registerAll() {
        // Top product carousel — rendered 3x inside MaxboArticleView and
        // also mounted on the home dashboard (campaign component 117).
        VioRuntime.registerPlacementLocation(
            VioPlacementLocation(id: "home_top",
                                 displayName: "Home — Product carousel")
        )

        // Featured-product spotlight — used by single-product showcases
        // (campaign component 119, productId 408903).
        VioRuntime.registerPlacementLocation(
            VioPlacementLocation(id: "product_spotlight",
                                 displayName: "Article — Featured product spotlight")
        )

        // Full-store grid — campaign component 118.
        VioRuntime.registerPlacementLocation(
            VioPlacementLocation(id: "home_store",
                                 displayName: "Home — Product store grid")
        )
    }
}
