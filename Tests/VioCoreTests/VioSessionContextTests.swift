// Tests for VioSessionContext — covers session initialization, broadcastContext,
// contentId flow, country codes, and multi-session isolation for Viaplay SDK demo

import XCTest
@testable import VioCore

@MainActor
final class VioSessionContextTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultInitCreatesEmptySession() {
        let session = VioSessionContext()

        XCTAssertNil(session.userId)
        XCTAssertNil(session.broadcastContext)
        XCTAssertNil(session.contentId)
        XCTAssertNil(session.country)
        XCTAssertFalse(session.useBackendEngagement)
    }

    func testInitWithAllFields() {
        let ctx = BroadcastContext(broadcastId: "ucl-final-2025")
        let session = VioSessionContext(
            userId: "user-viaplay-12345",
            broadcastContext: ctx,
            contentId: "viaplay-stream-ucl-001",
            country: "NO",
            useBackendEngagement: true
        )

        XCTAssertEqual(session.userId, "user-viaplay-12345")
        XCTAssertEqual(session.broadcastContext?.broadcastId, "ucl-final-2025")
        XCTAssertEqual(session.contentId, "viaplay-stream-ucl-001")
        XCTAssertEqual(session.country, "NO")
        XCTAssertTrue(session.useBackendEngagement)
    }

    // MARK: - forContentId Factory

    func testForContentIdCreatesSessionWithContentIdAndCountry() {
        let session = VioSessionContext.forContentId(
            contentId: "viaplay-12345",
            country: "NO"
        )

        XCTAssertEqual(session.contentId, "viaplay-12345")
        XCTAssertEqual(session.country, "NO")
        XCTAssertNil(session.userId)
    }

    func testForContentIdWithUserId() {
        let session = VioSessionContext.forContentId(
            contentId: "tv2-sport-stream-789",
            country: "NO",
            userId: "viewer-42"
        )

        XCTAssertEqual(session.userId, "viewer-42")
        XCTAssertEqual(session.contentId, "tv2-sport-stream-789")
        XCTAssertEqual(session.country, "NO")
    }

    func testForContentIdSwedenCountry() {
        let session = VioSessionContext.forContentId(contentId: "viaplay-se-001", country: "SE")
        XCTAssertEqual(session.country, "SE")
    }

    func testForContentIdDenmarkCountry() {
        let session = VioSessionContext.forContentId(contentId: "viaplay-dk-001", country: "DK")
        XCTAssertEqual(session.country, "DK")
    }

    // MARK: - Configure (Update)

    func testConfigureUpdatesUserId() {
        let session = VioSessionContext()
        session.configure(userId: "new-user-id")
        XCTAssertEqual(session.userId, "new-user-id")
    }

    func testConfigureUpdatesBroadcastContext() {
        let session = VioSessionContext()
        let ctx = BroadcastContext(broadcastId: "barca-psg-ucl")
        session.configure(broadcastContext: ctx)
        XCTAssertEqual(session.broadcastContext?.broadcastId, "barca-psg-ucl")
    }

    func testConfigureUpdatesCountry() {
        let session = VioSessionContext(country: "NO")
        session.configure(country: "SE")
        XCTAssertEqual(session.country, "SE")
    }

    func testConfigureUpdatesUseBackendEngagement() {
        let session = VioSessionContext()
        XCTAssertFalse(session.useBackendEngagement)

        session.configure(useBackendEngagement: true)
        XCTAssertTrue(session.useBackendEngagement)
    }

    func testConfigureDoesNotOverwriteNilFields() {
        let session = VioSessionContext(userId: "original-user", country: "NO")
        session.configure(contentId: "new-content")

        // userId and country should remain unchanged
        XCTAssertEqual(session.userId, "original-user")
        XCTAssertEqual(session.country, "NO")
        XCTAssertEqual(session.contentId, "new-content")
    }

    // MARK: - Multi-Session Isolation

    func testMultipleSessionsDoNotInterfere() {
        let session1 = VioSessionContext(
            userId: "user-1",
            contentId: "stream-1",
            country: "NO"
        )
        let session2 = VioSessionContext(
            userId: "user-2",
            contentId: "stream-2",
            country: "SE"
        )

        XCTAssertNotEqual(session1.userId, session2.userId)
        XCTAssertNotEqual(session1.contentId, session2.contentId)
        XCTAssertNotEqual(session1.country, session2.country)
    }

    func testUpdatingOneSessionDoesNotAffectAnother() {
        let session1 = VioSessionContext(contentId: "stream-A", country: "NO")
        let session2 = VioSessionContext(contentId: "stream-B", country: "DK")

        session1.configure(country: "GB")

        XCTAssertEqual(session1.country, "GB")
        XCTAssertEqual(session2.country, "DK", "session2 should be unaffected")
    }

    // MARK: - BroadcastContext Integration

    func testSessionWithFullBroadcastContext() {
        let ctx = BroadcastContext(
            broadcastId: "viaplay-ucl-semifinal",
            broadcastName: "Barcelona vs Inter",
            startTime: "2025-04-08T20:00:00Z",
            channelId: 3
        )
        let session = VioSessionContext(broadcastContext: ctx)

        XCTAssertEqual(session.broadcastContext?.broadcastId, "viaplay-ucl-semifinal")
        XCTAssertEqual(session.broadcastContext?.broadcastName, "Barcelona vs Inter")
        XCTAssertEqual(session.broadcastContext?.channelId, 3)
    }
}
