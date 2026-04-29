import XCTest
@testable import VioCore

@MainActor
final class VioPlacementRegistryTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        VioPlacementRegistry.shared._resetForTesting()
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

    func testUnknownLocationReturnsNil() {
        XCTAssertNil(VioPlacementRegistry.shared.location(forId: "definitely_not_a_real_location"))
    }

    // MARK: - Manifest payload

    func testManifestPayloadEmptyByDefault() {
        let payload = VioPlacementRegistry.shared.manifestPayload()
        XCTAssertEqual((payload["locations"] as? [Any])?.count, 0)
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
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "z_loc"))
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "a_loc"))
        let payload = VioPlacementRegistry.shared.manifestPayload()
        let ids = (payload["locations"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
        XCTAssertEqual(ids, ["a_loc", "z_loc"])
    }

    func testManifestPayloadHasOnlyLocationsKey() {
        // Post-2026-04-27 manifest: only `locations[]` array. The legacy
        // `components[]` and `placements[]` arrays were retired — this
        // test guards against re-introducing them by accident.
        VioPlacementRegistry.shared.registerLocation(VioPlacementLocation(id: "home_top"))
        let payload = VioPlacementRegistry.shared.manifestPayload()
        XCTAssertNotNil(payload["locations"])
        XCTAssertNil(payload["components"])
        XCTAssertNil(payload["placements"])
    }

    // MARK: - Vio entry conveniences

    func testVioRuntimeRegistersLocation() {
        VioRuntime.registerPlacementLocation(VioPlacementLocation(id: "home_top"))
        XCTAssertNotNil(VioPlacementRegistry.shared.location(forId: "home_top"))
    }
}
