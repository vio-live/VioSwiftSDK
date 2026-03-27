// Tests for ModuleConfigurations and CampaignConfiguration
// Covers:
// - commerceApiKey and commerceBaseUrl fields (rename from tipio, commit 98c4da2)
// - CampaignConfiguration: webSocketBaseURL and restAPIBaseURL defaults + custom values
// - webSocketBaseURL must use wss:// protocol (not ws://)
// - restAPIBaseURL must use https:// protocol (not http://)

import XCTest
@testable import VioCore

final class ModuleConfigurationsTests: XCTestCase {

    // MARK: - ModuleConfigurations: commerceApiKey

    func testCommerceApiKeyDefaultIsEmpty() {
        let config = ModuleConfigurations()
        XCTAssertEqual(config.commerceApiKey, "")
    }

    func testCommerceApiKeyCanBeSet() {
        let config = ModuleConfigurations(commerceApiKey: "KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S")
        XCTAssertEqual(config.commerceApiKey, "KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S")
    }

    func testCommerceApiKeyIsString() {
        let config = ModuleConfigurations(commerceApiKey: "test-key")
        XCTAssert(type(of: config.commerceApiKey) == String.self)
    }

    // MARK: - ModuleConfigurations: commerceBaseUrl

    func testCommerceBaseUrlHasDefault() {
        let config = ModuleConfigurations()
        XCTAssertFalse(config.commerceBaseUrl.isEmpty)
    }

    func testCommerceBaseUrlDefaultUsesHttps() {
        let config = ModuleConfigurations()
        XCTAssertTrue(
            config.commerceBaseUrl.hasPrefix("https://"),
            "commerceBaseUrl default debe usar https://, got: \(config.commerceBaseUrl)"
        )
    }

    func testCommerceBaseUrlCanBeSet() {
        let config = ModuleConfigurations(
            commerceApiKey: "key",
            commerceBaseUrl: "https://custom-commerce.example.com"
        )
        XCTAssertEqual(config.commerceBaseUrl, "https://custom-commerce.example.com")
    }

    // MARK: - CampaignConfiguration: webSocketBaseURL

    func testWebSocketBaseURLDefaultIsNotEmpty() {
        let config = CampaignConfiguration.default
        XCTAssertFalse(config.webSocketBaseURL.isEmpty)
    }

    func testWebSocketBaseURLDefaultUsesWssProtocol() {
        // webSocketBaseURL must use wss:// (secure WebSocket) — not ws:// or https://
        let config = CampaignConfiguration.default
        XCTAssertTrue(
            config.webSocketBaseURL.hasPrefix("wss://"),
            "webSocketBaseURL debe usar wss://, got: \(config.webSocketBaseURL)"
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
        // Default should point to api-dev.vio.live (was socket-qa.reachu.io)
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
