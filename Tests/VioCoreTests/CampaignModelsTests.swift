// Tests for CampaignModels — covers BroadcastContext, Campaign, OfferBannerConfig,
// WebSocket events, and JSON decoding resilience for Viaplay SDK demo

import XCTest
@testable import VioCore

final class CampaignModelsTests: XCTestCase {

    // MARK: - BroadcastContext

    func testBroadcastContextInitWithRequiredFields() {
        let ctx = BroadcastContext(broadcastId: "barcelona-psg-2025-ucl")

        XCTAssertEqual(ctx.broadcastId, "barcelona-psg-2025-ucl")
        XCTAssertNil(ctx.broadcastName)
        XCTAssertNil(ctx.startTime)
        XCTAssertNil(ctx.channelId)
        XCTAssertNil(ctx.metadata)
    }

    func testBroadcastContextInitWithAllFields() {
        let ctx = BroadcastContext(
            broadcastId: "barca-psg-ucl-r16",
            broadcastName: "Barcelona vs PSG",
            startTime: "2025-01-23T20:00:00Z",
            channelId: 42,
            metadata: ["competition": "UEFA Champions League"]
        )

        XCTAssertEqual(ctx.broadcastName, "Barcelona vs PSG")
        XCTAssertEqual(ctx.channelId, 42)
        XCTAssertEqual(ctx.metadata?["competition"], "UEFA Champions League")
    }

    func testBroadcastContextDecodesFromBroadcastIdJSON() throws {
        let json = """
        {"broadcastId": "nrk-sport-live-2025", "broadcastName": "Eliteserien Live"}
        """.data(using: .utf8)!

        let ctx = try JSONDecoder().decode(BroadcastContext.self, from: json)
        XCTAssertEqual(ctx.broadcastId, "nrk-sport-live-2025")
        XCTAssertEqual(ctx.broadcastName, "Eliteserien Live")
    }

    func testBroadcastContextDecodesFromLegacyMatchIdJSON() throws {
        let json = """
        {"matchId": "legacy-match-123", "matchName": "Rosenborg vs Bodø/Glimt"}
        """.data(using: .utf8)!

        let ctx = try JSONDecoder().decode(BroadcastContext.self, from: json)
        XCTAssertEqual(ctx.broadcastId, "legacy-match-123")
        XCTAssertEqual(ctx.broadcastName, "Rosenborg vs Bodø/Glimt")
    }

    func testBroadcastContextEquatable() {
        let a = BroadcastContext(broadcastId: "abc", broadcastName: "Match A")
        let b = BroadcastContext(broadcastId: "abc", broadcastName: "Match A")
        XCTAssertEqual(a, b)
    }

    func testBroadcastContextRoundTripsJSON() throws {
        let original = BroadcastContext(
            broadcastId: "tv2-sport-ucl",
            broadcastName: "Real Madrid vs Man City",
            startTime: "2025-03-11T21:00:00Z",
            channelId: 7
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BroadcastContext.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Campaign

    func testCampaignInitWithIdOnly() {
        let campaign = Campaign(id: 42)

        XCTAssertEqual(campaign.id, 42)
        XCTAssertNil(campaign.startDate)
        XCTAssertNil(campaign.endDate)
        XCTAssertNil(campaign.isPaused)
    }

    func testCampaignWithNoDatesIsActive() {
        let campaign = Campaign(id: 1)
        XCTAssertEqual(campaign.currentState, .active)
    }

    func testCampaignWithFutureStartDateIsUpcoming() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let futureDate = formatter.string(from: Date().addingTimeInterval(86400))
        let campaign = Campaign(id: 2, startDate: futureDate)
        XCTAssertEqual(campaign.currentState, .upcoming)
    }

    func testCampaignWithPastEndDateIsEnded() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let pastDate = formatter.string(from: Date().addingTimeInterval(-86400))
        let campaign = Campaign(id: 3, endDate: pastDate)
        XCTAssertEqual(campaign.currentState, .ended)
    }

    func testCampaignDecodesFromJSON() throws {
        let json = """
        {
            "id": 14,
            "startDate": "2025-01-20T18:00:00.000Z",
            "endDate": "2025-01-20T22:00:00.000Z",
            "isPaused": false,
            "campaignLogo": "https://cdn.elkjop.no/logo.png"
        }
        """.data(using: .utf8)!

        let campaign = try JSONDecoder().decode(Campaign.self, from: json)
        XCTAssertEqual(campaign.id, 14)
        XCTAssertEqual(campaign.campaignLogo, "https://cdn.elkjop.no/logo.png")
        XCTAssertEqual(campaign.isPaused, false)
    }

    func testCampaignDecodesIsPausedAsString() throws {
        let json = """
        {"id": 15, "isPaused": "true"}
        """.data(using: .utf8)!

        let campaign = try JSONDecoder().decode(Campaign.self, from: json)
        XCTAssertEqual(campaign.isPaused, true)
    }

    func testCampaignEquatable() {
        let a = Campaign(id: 10, startDate: "2025-01-01T00:00:00Z")
        let b = Campaign(id: 10, startDate: "2025-01-01T00:00:00Z")
        XCTAssertEqual(a, b)
    }

    // MARK: - BroadcastValidationResult

    func testBroadcastValidationResultHasEngagement() {
        let result = BroadcastValidationResult(
            hasEngagement: true,
            broadcastId: "viaplay-ucl-2025",
            broadcastName: "UCL Semi-Final",
            status: "active",
            campaignId: 14,
            websocketChannel: "ws-ucl-semi"
        )

        XCTAssertTrue(result.hasEngagement)
        XCTAssertEqual(result.broadcastId, "viaplay-ucl-2025")
        XCTAssertEqual(result.campaignId, 14)
    }

    func testBroadcastValidationResultNoEngagement() {
        let result = BroadcastValidationResult(hasEngagement: false)
        XCTAssertFalse(result.hasEngagement)
        XCTAssertNil(result.broadcastId)
    }

    func testBroadcastValidationResultDecodesFromJSON() throws {
        let json = """
        {"hasEngagement": true, "broadcastId": "stream-001", "status": "active", "campaignId": 7}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(BroadcastValidationResult.self, from: json)
        XCTAssertTrue(result.hasEngagement)
        XCTAssertEqual(result.campaignId, 7)
    }

    // MARK: - CampaignState

    func testCampaignStateRawValues() {
        XCTAssertEqual(CampaignState.upcoming.rawValue, "upcoming")
        XCTAssertEqual(CampaignState.active.rawValue, "active")
        XCTAssertEqual(CampaignState.ended.rawValue, "ended")
    }

    // MARK: - WebSocket Events

    func testCampaignWebSocketEventInit() {
        let event = CampaignWebSocketEvent(type: "campaign_started", campaignId: 14)
        XCTAssertEqual(event.type, "campaign_started")
        XCTAssertEqual(event.campaignId, 14)
    }

    func testCampaignStartedEventInit() {
        let event = CampaignStartedEvent(
            campaignId: 14,
            startDate: "2025-01-23T20:00:00Z",
            broadcastId: "ucl-barca-psg"
        )
        XCTAssertEqual(event.type, "campaign_started")
        XCTAssertEqual(event.broadcastId, "ucl-barca-psg")
    }

    func testCampaignEndedEventInit() {
        let event = CampaignEndedEvent(
            campaignId: 14,
            endDate: "2025-01-23T22:00:00Z"
        )
        XCTAssertEqual(event.type, "campaign_ended")
    }

    func testCampaignPausedEventInit() {
        let event = CampaignPausedEvent(campaignId: 14)
        XCTAssertEqual(event.type, "campaign_paused")
    }

    func testCampaignResumedEventInit() {
        let event = CampaignResumedEvent(campaignId: 14)
        XCTAssertEqual(event.type, "campaign_resumed")
    }

    // MARK: - OfferBannerConfig

    func testOfferBannerConfigInitWithRequiredFields() {
        let config = OfferBannerConfig(
            logoUrl: "https://cdn.elkjop.no/sponsor-logo.png",
            title: "Elkjøp Black Friday",
            countdownEndDate: "2025-11-29T23:59:59Z",
            discountBadgeText: "Spar 40%",
            ctaText: "Kjøp nå"
        )

        XCTAssertEqual(config.logoUrl, "https://cdn.elkjop.no/sponsor-logo.png")
        XCTAssertEqual(config.title, "Elkjøp Black Friday")
        XCTAssertEqual(config.discountBadgeText, "Spar 40%")
        XCTAssertEqual(config.ctaText, "Kjøp nå")
        XCTAssertNil(config.subtitle)
        XCTAssertNil(config.backgroundImageUrl)
        XCTAssertNil(config.deeplinkUrl)
    }

    func testOfferBannerConfigDecodesFromJSON() throws {
        let json = """
        {
            "logoUrl": "https://cdn.elkjop.no/logo.png",
            "title": "Match Day Deal",
            "countdownEndDate": "2025-01-23T22:00:00Z",
            "discountBadgeText": "-30%",
            "ctaText": "Shop Now",
            "backgroundColor": "#1A1A2E",
            "overlayOpacity": 0.7
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(OfferBannerConfig.self, from: json)
        XCTAssertEqual(config.backgroundColor, "#1A1A2E")
        XCTAssertEqual(config.overlayOpacity, 0.7)
    }

    func testOfferBannerConfigSupportsDeeplinkField() throws {
        let json = """
        {
            "logoUrl": "https://cdn.elkjop.no/logo.png",
            "title": "Deal",
            "countdownEndDate": "2025-12-31T00:00:00Z",
            "discountBadgeText": "-50%",
            "ctaText": "Go",
            "deeplink": "elkjop://product/123"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(OfferBannerConfig.self, from: json)
        XCTAssertEqual(config.deeplinkUrl, "elkjop://product/123")
    }

    func testOfferBannerConfigEquatable() {
        let a = OfferBannerConfig(
            logoUrl: "logo.png", title: "Sale",
            countdownEndDate: "2025-12-31T00:00:00Z",
            discountBadgeText: "-20%", ctaText: "Buy"
        )
        let b = OfferBannerConfig(
            logoUrl: "logo.png", title: "Sale",
            countdownEndDate: "2025-12-31T00:00:00Z",
            discountBadgeText: "-20%", ctaText: "Buy"
        )
        XCTAssertEqual(a, b)
    }

    // MARK: - AnyCodable

    func testAnyCodableDecodesString() throws {
        let json = "\"hello\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: json)
        XCTAssertEqual(decoded.value as? String, "hello")
    }

    func testAnyCodableDecodesInt() throws {
        let json = "42".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: json)
        XCTAssertEqual(decoded.value as? Int, 42)
    }

    func testAnyCodableDecodesBool() throws {
        let json = "true".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: json)
        XCTAssertEqual(decoded.value as? Bool, true)
    }

    func testAnyCodableRoundTrips() throws {
        let original = AnyCodable("Elkjøp Norge")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? String, "Elkjøp Norge")
    }
}
