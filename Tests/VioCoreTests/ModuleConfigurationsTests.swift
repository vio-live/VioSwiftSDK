// Tests for CampaignConfiguration (JSON `campaigns.*` module config).
// Covers:
// - commerceApiKey / commerceGraphQLURL (legacy JSON; ProductService uses bootstrap only)
// - webSocketBaseURL and restAPIBaseURL defaults + custom values
// - restAPIBaseURL must use https:// protocol (not http://)

import XCTest
@testable import VioCore

final class ModuleConfigurationsTests: XCTestCase {

    // MARK: - CampaignConfiguration: commerce (JSON legacy)

    func testCommerceApiKeyDefaultIsEmpty() {
        let config = CampaignConfiguration.default
        XCTAssertEqual(config.commerceApiKey, "")
    }

    func testCommerceApiKeyCanBeSet() {
        let config = CampaignConfiguration(
            webSocketBaseURL: "wss://api-dev.vio.live",
            restAPIBaseURL: "https://api-dev.vio.live",
            commerceApiKey: "KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S"
        )
        XCTAssertEqual(config.commerceApiKey, "KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S")
    }

    func testCommerceApiKeyIsString() {
        let config = CampaignConfiguration(
            webSocketBaseURL: "wss://api-dev.vio.live",
            restAPIBaseURL: "https://api-dev.vio.live",
            commerceApiKey: "test-key"
        )
        XCTAssert(type(of: config.commerceApiKey) == String.self)
    }

    func testCommerceGraphQLURLDefaultIsNil() {
        let config = CampaignConfiguration.default
        XCTAssertNil(config.commerceGraphQLURL)
    }

    func testCommerceGraphQLURLCanBeSet() {
        let config = CampaignConfiguration(
            webSocketBaseURL: "wss://api-dev.vio.live",
            restAPIBaseURL: "https://api-dev.vio.live",
            commerceApiKey: "key",
            commerceGraphQLURL: "https://custom-commerce.example.com/graphql"
        )
        XCTAssertEqual(config.commerceGraphQLURL, "https://custom-commerce.example.com/graphql")
    }

    // MARK: - CampaignConfiguration: webSocketBaseURL

    func testWebSocketBaseURLDefaultIsNotEmpty() {
        let config = CampaignConfiguration.default
        XCTAssertFalse(config.webSocketBaseURL.isEmpty)
    }

    func testWebSocketBaseURLDefaultUsesHttps() {
        // Default matches ``CampaignConfiguration`` initializer (host URL shared with REST in many setups).
        let config = CampaignConfiguration.default
        XCTAssertTrue(
            config.webSocketBaseURL.hasPrefix("https://"),
            "webSocketBaseURL default should use https://, got: \(config.webSocketBaseURL)"
        )
    }

    func testWebSocketBaseURLCanBeSetWithWss() {
        let config = CampaignConfiguration(
            webSocketBaseURL: "wss://api-dev.vio.live",
            restAPIBaseURL: "https://api-dev.vio.live",
            campaignApiKey: ""
        )
        XCTAssertEqual(config.webSocketBaseURL, "wss://api-dev.vio.live")
    }

    func testWebSocketBaseURLPointsToVioLive() {
        // Validates the URL updated in commit 85fd6c3 (Maxi, Mar 25)
        // Default should point to api-dev.vio.live
        let config = CampaignConfiguration.default
        XCTAssertTrue(
            config.webSocketBaseURL.contains("vio.live"),
            "webSocketBaseURL debe apuntar a vio.live, got: \(config.webSocketBaseURL)"
        )
    }

    // MARK: - CampaignConfiguration: restAPIBaseURL

    func testRestAPIBaseURLDefaultIsNotEmpty() {
        let config = CampaignConfiguration.default
        XCTAssertFalse(config.restAPIBaseURL.isEmpty)
    }

    func testRestAPIBaseURLDefaultUsesHttps() {
        // restAPIBaseURL must use https:// — not http://
        let config = CampaignConfiguration.default
        XCTAssertTrue(
            config.restAPIBaseURL.hasPrefix("https://"),
            "restAPIBaseURL debe usar https://, got: \(config.restAPIBaseURL)"
        )
    }

    func testRestAPIBaseURLPointsToVioLive() {
        // Validates the URL updated in commit 85fd6c3 (Maxi, Mar 25)
        let config = CampaignConfiguration.default
        XCTAssertTrue(
            config.restAPIBaseURL.contains("vio.live"),
            "restAPIBaseURL debe apuntar a vio.live, got: \(config.restAPIBaseURL)"
        )
    }

    func testRestAPIBaseURLCanBeSet() {
        let config = CampaignConfiguration(
            webSocketBaseURL: "wss://api-dev.vio.live",
            restAPIBaseURL: "https://api-dev.vio.live",
            campaignApiKey: ""
        )
        XCTAssertEqual(config.restAPIBaseURL, "https://api-dev.vio.live")
    }

    // MARK: - CampaignConfiguration: campaignApiKey

    func testCampaignApiKeyDefaultIsEmpty() {
        let config = CampaignConfiguration.default
        XCTAssertEqual(config.campaignApiKey, "")
    }

    func testCampaignApiKeyCanBeSet() {
        let config = CampaignConfiguration(
            webSocketBaseURL: "wss://api-dev.vio.live",
            restAPIBaseURL: "https://api-dev.vio.live",
            campaignApiKey: "viaplay_api_key_0c611e983b314ff8"
        )
        XCTAssertEqual(config.campaignApiKey, "viaplay_api_key_0c611e983b314ff8")
    }
}
