import XCTest
@testable import VioCore

@MainActor
final class VioPlacementRegistryTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        VioPlacementRegistry.shared._resetForTesting()
    }

    // MARK: - Component registration

    private struct FakeCarousel: VioPlacementComponent {
        static var componentType: String { "product_carousel" }
        static var productMode: VioProductBindingMode { .multiple }
        static var maxProducts: Int? { 8 }
    }

    private struct FakeSpotlight: VioPlacementComponent {
        static var componentType: String { "product_spotlight" }
        static var productMode: VioProductBindingMode { .single }
    }

    private struct FakeCarouselV2: VioPlacementComponent {
        static var componentType: String { "product_carousel" }
        static var productMode: VioProductBindingMode { .multiple }
        static var maxProducts: Int? { 12 } // changed value to verify last-writer-wins
    }

    func testRegistersComponentByType() {
        VioPlacementRegistry.shared.register(FakeCarousel.self)
        let resolved = VioPlacementRegistry.shared.component(forType: "product_carousel")
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.productMode, .multiple)
        XCTAssertEqual(resolved?.maxProducts, 8)
    }

    func testRegisterIsIdempotentByType() {
        VioPlacementRegistry.shared.register(FakeCarousel.self)
        VioPlacementRegistry.shared.register(FakeCarousel.self)
        XCTAssertEqual(VioPlacementRegistry.shared.registeredComponents.count, 1)
    }

    func testReregisterOverwritesWithLatestValues() {
        VioPlacementRegistry.shared.register(FakeCarousel.self)
        XCTAssertEqual(VioPlacementRegistry.shared.component(forType: "product_carousel")?.maxProducts, 8)
        VioPlacementRegistry.shared.register(FakeCarouselV2.self)
        XCTAssertEqual(VioPlacementRegistry.shared.component(forType: "product_carousel")?.maxProducts, 12)
        XCTAssertEqual(VioPlacementRegistry.shared.registeredComponents.count, 1)
    }

    func testMaxProductsDefaultsToNil() {
        VioPlacementRegistry.shared.register(FakeSpotlight.self)
        XCTAssertNil(VioPlacementRegistry.shared.component(forType: "product_spotlight")?.maxProducts)
    }

    func testRegisteredComponentsSortedByType() {
        VioPlacementRegistry.shared.register(FakeSpotlight.self)
        VioPlacementRegistry.shared.register(FakeCarousel.self)
        let types = VioPlacementRegistry.shared.registeredComponents.map { $0.componentType }
        XCTAssertEqual(types, ["product_carousel", "product_spotlight"])
    }

    func testUnknownTypeReturnsNil() {
        XCTAssertNil(VioPlacementRegistry.shared.component(forType: "definitely_not_a_real_type"))
    }

    // MARK: - Location registration

    func testRegistersLocation() {
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "home_top", displayName: "Home — Top"))
        let resolved = VioPlacementRegistry.shared.location(forId: "home_top")
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.displayName, "Home — Top")
    }

    func testRegisterLocationIsIdempotent() {
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "match_sidebar", displayName: "Match Sidebar"))
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "match_sidebar", displayName: "Match Sidebar"))
        XCTAssertEqual(VioPlacementRegistry.shared.registeredLocations.count, 1)
    }

    func testReregisterLocationUpdatesDisplayName() {
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "home_top", displayName: "v1"))
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "home_top", displayName: "v2"))
        XCTAssertEqual(VioPlacementRegistry.shared.location(forId: "home_top")?.displayName, "v2")
        XCTAssertEqual(VioPlacementRegistry.shared.registeredLocations.count, 1)
    }

    func testRegisteredLocationsSortedById() {
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "z_loc"))
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "a_loc"))
        let ids = VioPlacementRegistry.shared.registeredLocations.map { $0.id }
        XCTAssertEqual(ids, ["a_loc", "z_loc"])
    }

    func testLocationDisplayNameDefaultsToNil() {
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "home_top"))
        XCTAssertNil(VioPlacementRegistry.shared.location(forId: "home_top")?.displayName)
    }

    // MARK: - Manifest payload

    func testManifestPayloadEmptyByDefault() {
        let payload = VioPlacementRegistry.shared.manifestPayload()
        XCTAssertEqual((payload["components"] as? [Any])?.count, 0)
        XCTAssertEqual((payload["locations"] as? [Any])?.count, 0)
    }

    func testManifestPayloadIncludesComponents() {
        VioPlacementRegistry.shared.register(FakeCarousel.self)
        VioPlacementRegistry.shared.register(FakeSpotlight.self)
        let payload = VioPlacementRegistry.shared.manifestPayload()
        let comps = payload["components"] as? [[String: Any]] ?? []
        XCTAssertEqual(comps.count, 2)
        XCTAssertTrue(comps.contains { ($0["type"] as? String) == "product_carousel" && ($0["productMode"] as? String) == "multiple" && ($0["maxProducts"] as? Int) == 8 })
        XCTAssertTrue(comps.contains { ($0["type"] as? String) == "product_spotlight" && ($0["productMode"] as? String) == "single" && $0["maxProducts"] == nil })
    }

    func testManifestPayloadIncludesLocations() {
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "home_top", displayName: "Home Top"))
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "match_sidebar"))
        let payload = VioPlacementRegistry.shared.manifestPayload()
        let locs = payload["locations"] as? [[String: Any]] ?? []
        XCTAssertEqual(locs.count, 2)
        XCTAssertTrue(locs.contains { ($0["id"] as? String) == "home_top" && ($0["displayName"] as? String) == "Home Top" })
        XCTAssertTrue(locs.contains { ($0["id"] as? String) == "match_sidebar" && $0["displayName"] == nil })
    }

    func testManifestPayloadOrderingIsStable() {
        // Register out of alphabetical order; payload should still emit in
        // sorted order (tested separately above for the registry getters,
        // but worth verifying the payload reflects the same).
        VioPlacementRegistry.shared.register(FakeSpotlight.self)
        VioPlacementRegistry.shared.register(FakeCarousel.self)
        let payload = VioPlacementRegistry.shared.manifestPayload()
        let types = (payload["components"] as? [[String: Any]])?.compactMap { $0["type"] as? String } ?? []
        XCTAssertEqual(types, ["product_carousel", "product_spotlight"])
    }

    // MARK: - Vio entry conveniences

    func testVioRuntimeRegistersComponent() {
        VioRuntime.registerPlacementComponent(FakeCarousel.self)
        XCTAssertNotNil(VioPlacementRegistry.shared.component(forType: "product_carousel"))
    }

    func testVioRuntimeRegistersLocation() {
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_top"))
        XCTAssertNotNil(VioPlacementRegistry.shared.location(forId: "home_top"))
    }

    // MARK: - Named placements (v2 API)

    func testRegisterPlacementStoresNamedInstance() {
        VioRuntime.registerPlacement(
            name: "Carrusel home",
            type: FakeCarousel.self,
            locationId: "home_top",
            locationDisplayName: "Home — Top"
        )
        let placement = VioPlacementRegistry.shared.placement(forName: "Carrusel home")
        XCTAssertNotNil(placement)
        XCTAssertEqual(placement?.componentType, "product_carousel")
        XCTAssertEqual(placement?.locationId, "home_top")
        XCTAssertEqual(placement?.locationDisplayName, "Home — Top")
    }

    func testRegisterPlacementAlsoPopulatesLegacyIndexes() {
        // Backwards compat: views still resolve via component(forType:) and
        // location(forId:). Named placements must auto-derive both.
        VioRuntime.registerPlacement(
            name: "Spot home",
            type: FakeSpotlight.self,
            locationId: "home_below_video"
        )
        XCTAssertNotNil(VioPlacementRegistry.shared.component(forType: "product_spotlight"))
        XCTAssertNotNil(VioPlacementRegistry.shared.location(forId: "home_below_video"))
    }

    func testRegisterPlacementByNameIsIdempotent() {
        VioRuntime.registerPlacement(name: "Carrusel home", type: FakeCarousel.self, locationId: "home_top")
        VioRuntime.registerPlacement(name: "Carrusel home", type: FakeCarousel.self, locationId: "home_top")
        XCTAssertEqual(VioPlacementRegistry.shared.registeredPlacements.count, 1)
    }

    func testRegisterPlacementSlotConflictRejectsSecondName() {
        // Two distinct names claiming the same (componentType, locationId)
        // → the second is rejected (locked decision: slot is unique).
        VioRuntime.registerPlacement(name: "First", type: FakeCarousel.self, locationId: "home_top")
        VioRuntime.registerPlacement(name: "Second", type: FakeCarousel.self, locationId: "home_top")
        XCTAssertEqual(VioPlacementRegistry.shared.registeredPlacements.count, 1)
        XCTAssertEqual(VioPlacementRegistry.shared.placement(forName: "First")?.locationId, "home_top")
        XCTAssertNil(VioPlacementRegistry.shared.placement(forName: "Second"))
    }

    func testRegisterPlacementSameNameDifferentSlotMovesIt() {
        // Re-registering an existing name with a different slot updates
        // the slot mapping (rename within the same SDK boot — dev edited
        // their `locationId` arg).
        VioRuntime.registerPlacement(name: "Carrusel", type: FakeCarousel.self, locationId: "home_top")
        VioRuntime.registerPlacement(name: "Carrusel", type: FakeCarousel.self, locationId: "match_pre_kickoff")
        XCTAssertEqual(VioPlacementRegistry.shared.registeredPlacements.count, 1)
        XCTAssertEqual(VioPlacementRegistry.shared.placement(forName: "Carrusel")?.locationId, "match_pre_kickoff")
        // Old slot freed up — another name can claim it now.
        VioRuntime.registerPlacement(name: "Otro", type: FakeCarousel.self, locationId: "home_top")
        XCTAssertEqual(VioPlacementRegistry.shared.placement(forName: "Otro")?.locationId, "home_top")
    }

    func testPlacementLookupBySlotAndName() {
        VioRuntime.registerPlacement(name: "Carrusel home", type: FakeCarousel.self, locationId: "home_top")
        XCTAssertEqual(
            VioPlacementRegistry.shared.placement(forSlot: "product_carousel", locationId: "home_top")?.name,
            "Carrusel home"
        )
        XCTAssertNil(VioPlacementRegistry.shared.placement(forSlot: "product_carousel", locationId: "unknown"))
    }

    func testEmptyNameOrLocationIsRejected() {
        VioRuntime.registerPlacement(name: "", type: FakeCarousel.self, locationId: "home_top")
        VioRuntime.registerPlacement(name: "Carrusel", type: FakeCarousel.self, locationId: "")
        VioRuntime.registerPlacement(name: "  ", type: FakeCarousel.self, locationId: "home_top")
        XCTAssertEqual(VioPlacementRegistry.shared.registeredPlacements.count, 0)
    }

    func testManifestPayloadIncludesPlacements() {
        VioRuntime.registerPlacement(
            name: "Carrusel home",
            type: FakeCarousel.self,
            locationId: "home_top",
            locationDisplayName: "Home — Top"
        )
        VioRuntime.registerPlacement(name: "Spot match", type: FakeSpotlight.self, locationId: "match_sidebar")
        let payload = VioPlacementRegistry.shared.manifestPayload()
        let placements = payload["placements"] as? [[String: Any]] ?? []
        XCTAssertEqual(placements.count, 2)
        XCTAssertTrue(placements.contains {
            ($0["name"] as? String) == "Carrusel home"
                && ($0["componentType"] as? String) == "product_carousel"
                && ($0["locationId"] as? String) == "home_top"
                && ($0["locationDisplayName"] as? String) == "Home — Top"
        })
        XCTAssertTrue(placements.contains {
            ($0["name"] as? String) == "Spot match"
                && ($0["componentType"] as? String) == "product_spotlight"
                && ($0["locationId"] as? String) == "match_sidebar"
                && $0["locationDisplayName"] == nil
        })
    }

    func testManifestPayloadAlsoIncludesLegacyArraysForBackwardsCompat() {
        // When dev uses ONLY the v2 API, the manifest still emits
        // components[] + locations[] — auto-derived. The backend's
        // dual-write path keeps app_components + app_component_locations
        // populated for views that still consult them.
        VioRuntime.registerPlacement(name: "Carrusel home", type: FakeCarousel.self, locationId: "home_top")
        let payload = VioPlacementRegistry.shared.manifestPayload()
        XCTAssertEqual((payload["components"] as? [Any])?.count, 1)
        XCTAssertEqual((payload["locations"] as? [Any])?.count, 1)
        XCTAssertEqual((payload["placements"] as? [Any])?.count, 1)
    }
}
