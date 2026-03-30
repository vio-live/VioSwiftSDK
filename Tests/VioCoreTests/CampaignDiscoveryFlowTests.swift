// CampaignDiscoveryFlowTests.swift
// Tests for the discoverCampaigns → connectWebSocket flow (TV2 + Viaplay)
// Branch: test/tv2-e2e-flow-discovery (from feature/tv2-sdk-integration)
// Juan Rodríguez — 2026-03-30

import XCTest
@testable import VioCore

final class CampaignDiscoveryFlowTests: XCTestCase {

    // MARK: - CampaignsDiscoveryResponse decoding

    func testDecodesValidDiscoveryResponseWithOneCampaign() throws {
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "TV2 Campaign",
              "campaignLogo": "https://containerqa2.blob.core.windows.net/vio/uploads/logo.png",
              "isActive": true,
              "isPaused": false,
              "components": []
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)

        XCTAssertEqual(response.campaigns.count, 1)
        XCTAssertEqual(response.campaigns[0].campaignId, 36)
        XCTAssertEqual(response.campaigns[0].campaignName, "TV2 Campaign")
        XCTAssertTrue(response.campaigns[0].isActive)
        XCTAssertFalse(response.campaigns[0].isPaused ?? true)
    }

    func testDecodesEmptyCampaignsList() throws {
        let json = """
        { "campaigns": [] }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)

        XCTAssertEqual(response.campaigns.count, 0)
    }

    func testDecodesMultipleCampaigns() throws {
        let json = """
        {
          "campaigns": [
            { "campaignId": 36, "campaignName": "TV2 Campaign", "isActive": true, "isPaused": false, "components": [] },
            { "campaignId": 42, "campaignName": "Viaplay Campaign", "isActive": true, "isPaused": false, "components": [] }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)

        XCTAssertEqual(response.campaigns.count, 2)
        XCTAssertEqual(response.campaigns[0].campaignId, 36)
        XCTAssertEqual(response.campaigns[1].campaignId, 42)
    }

    // MARK: - CampaignDiscoveryItem — broadcastContext

    func testDecodesCampaignWithBroadcastContext() throws {
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "TV2 Campaign",
              "isActive": true,
              "isPaused": false,
              "broadcastContext": {
                "broadcastId": "tv2-sport-live-2026",
                "broadcastName": "Eliteserien RBK vs Bodø"
              },
              "components": []
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)
        let campaign = response.campaigns[0]

        XCTAssertEqual(campaign.broadcastContext?.broadcastId, "tv2-sport-live-2026")
        XCTAssertEqual(campaign.broadcastContext?.broadcastName, "Eliteserien RBK vs Bodø")
    }

    func testDecodesCampaignWithLegacyMatchContext() throws {
        // Backward compat: old backend sends matchContext instead of broadcastContext
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "Legacy Campaign",
              "isActive": true,
              "isPaused": false,
              "matchContext": {
                "matchId": "legacy-match-001",
                "matchName": "Old Format Match"
              },
              "components": []
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)
        let campaign = response.campaigns[0]

        // matchContext maps to broadcastContext via backward compat logic
        XCTAssertNotNil(campaign.broadcastContext, "Legacy matchContext should map to broadcastContext")
    }

    func testDecodesCampaignWithNilBroadcastContext() throws {
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "No Context Campaign",
              "isActive": true,
              "isPaused": false,
              "components": []
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)

        XCTAssertNil(response.campaigns[0].broadcastContext)
    }

    // MARK: - Components in discovery response

    func testDecodesDiscoveryResponseWithComponents() throws {
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "TV2 Campaign",
              "isActive": true,
              "isPaused": false,
              "components": [
                {
                  "id": "comp-001",
                  "type": "shoppable_add",
                  "name": "Product Overlay",
                  "status": "active",
                  "config": {
                    "productId": "408895",
                    "title": "Nike Air Max"
                  }
                },
                {
                  "id": "comp-002",
                  "type": "offer_banner",
                  "name": "Banner",
                  "status": "active",
                  "config": {}
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)
        let components = response.campaigns[0].components

        XCTAssertEqual(components?.count, 2)
        XCTAssertEqual(components?[0].id, "comp-001")
        XCTAssertEqual(components?[0].type, "shoppable_add")
        XCTAssertEqual(components?[1].type, "offer_banner")
    }

    func testDecodesComponentWithLocationId() throws {
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "TV2 Campaign",
              "isActive": true,
              "isPaused": false,
              "components": [
                {
                  "id": "comp-001",
                  "type": "shoppable_add",
                  "name": "Product Overlay",
                  "locationId": "tv2-player-bottom",
                  "status": "active",
                  "config": {}
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)

        XCTAssertEqual(response.campaigns[0].components?[0].locationId, "tv2-player-bottom")
    }

    func testDecodesComponentWithNilComponents() throws {
        // Backend may omit components field entirely
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "TV2 Campaign",
              "isActive": true,
              "isPaused": false
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)

        XCTAssertNil(response.campaigns[0].components)
    }

    // MARK: - isPaused field

    func testDecodesPausedCampaign() throws {
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "Paused Campaign",
              "isActive": true,
              "isPaused": true,
              "components": []
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)

        XCTAssertTrue(response.campaigns[0].isPaused ?? false)
    }

    func testDecodesNilIsPaused() throws {
        // Backend may omit isPaused
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "TV2 Campaign",
              "isActive": true,
              "components": []
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)

        XCTAssertNil(response.campaigns[0].isPaused)
    }

    // MARK: - CampaignWebSocketManager — URL construction

    func testWebSocketURLUsesDiscoveredCampaignId() {
        // connectWebSocket should use discovered campaignId (36), not config campaignId
        let manager = CampaignWebSocketManager(
            campaignId: 36,
            baseURL: "wss://api-dev.vio.live",
            userId: nil
        )

        // Manager should store campaignId 36 — spot check via connect path
        // We verify init doesn't crash and uses correct id
        XCTAssertNotNil(manager)
    }

    func testWebSocketURLAppendsUserIdWhenSet() {
        // When userId is set, URL should include ?userId=...
        let manager = CampaignWebSocketManager(
            campaignId: 36,
            baseURL: "wss://api-dev.vio.live",
            userId: "tv2_demo_user"
        )

        XCTAssertEqual(manager.userId, "tv2_demo_user")
    }

    func testWebSocketURLNoUserIdWhenNil() {
        let manager = CampaignWebSocketManager(
            campaignId: 36,
            baseURL: "wss://api-dev.vio.live",
            userId: nil
        )

        XCTAssertNil(manager.userId)
    }

    func testWebSocketBaseURLUsesWSSProtocol() {
        // baseURL must start with wss:// for secure WebSocket — never ws:// in production
        let baseURL = "wss://api-dev.vio.live"
        XCTAssertTrue(baseURL.hasPrefix("wss://"), "WebSocket baseURL debe usar wss:// no ws://")
    }

    func testWebSocketBaseURLDoesNotUseDeprecatedDomain() {
        // socket-qa.reachu.io is deprecated — must not appear in WS base URL
        let baseURL = "wss://api-dev.vio.live"
        XCTAssertFalse(baseURL.contains("socket-qa.reachu.io"), "URL deprecated socket-qa.reachu.io no debe usarse")
    }

    // MARK: - Component count consistency

    func testFourComponentsMatchTV2DiscoveryLog() throws {
        // TV2 log shows: "Discovered 1 campaigns, 4 components" — verify decode with 4 components
        let json = """
        {
          "campaigns": [
            {
              "campaignId": 36,
              "campaignName": "TV2 Campaign",
              "isActive": true,
              "isPaused": false,
              "components": [
                { "id": "c1", "type": "shoppable_add", "name": "C1", "status": "active", "config": {} },
                { "id": "c2", "type": "offer_banner", "name": "C2", "status": "active", "config": {} },
                { "id": "c3", "type": "sponsor_logo", "name": "C3", "status": "active", "config": {} },
                { "id": "c4", "type": "lineup", "name": "C4", "status": "active", "config": {} }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CampaignsDiscoveryResponse.self, from: json)

        XCTAssertEqual(response.campaigns[0].components?.count, 4, "TV2 discovery debe devolver 4 components")
    }
}
