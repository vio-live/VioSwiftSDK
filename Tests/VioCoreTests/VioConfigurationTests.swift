// Tests for VioConfiguration — covers singleton setup, API key validation,
// environment defaults, and configuration error handling for Viaplay SDK demo

import XCTest
@testable import VioCore

final class VioConfigurationTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Reset shared config to defaults after each test
        VioConfiguration.shared.applySdkBootstrapCommerce(apiKey: nil, graphQLURL: nil)
        VioConfiguration.configure(apiKey: "", environment: .sandbox)
    }

    // MARK: - Basic Configuration

    func testConfigureWithApiKeySetsApiKey() {
        VioConfiguration.configure(apiKey: "vio-test-key-123")

        XCTAssertEqual(VioConfiguration.shared.apiKey, "vio-test-key-123")
    }

    func testConfigureMarksIsConfiguredTrue() {
        VioConfiguration.configure(apiKey: "vio-test-key-123")

        XCTAssertTrue(VioConfiguration.shared.isConfigured)
    }

    func testQuickConfigureDefaultsToProduction() {
        VioConfiguration.configure(apiKey: "vio-test-key-123")

        XCTAssertEqual(VioConfiguration.shared.environment, .production)
    }

    func testConfigureWithExplicitEnvironment() {
        VioConfiguration.configure(apiKey: "vio-test-key", environment: .sandbox)

        XCTAssertEqual(VioConfiguration.shared.environment, .sandbox)
    }

    func testConfigureWithDevelopmentEnvironment() {
        VioConfiguration.configure(apiKey: "vio-dev-key", environment: .development)

        XCTAssertEqual(VioConfiguration.shared.environment, .development)
    }

    // MARK: - API Key Validation

    func testEmptyApiKeyFailsValidation() {
        VioConfiguration.configure(apiKey: "")

        XCTAssertFalse(VioConfiguration.shared.isValidConfiguration)
    }

    func testValidateConfigurationThrowsMissingAPIKeyForEmptyKey() {
        VioConfiguration.configure(apiKey: "")

        XCTAssertThrowsError(try VioConfiguration.shared.validateConfiguration()) { error in
            XCTAssertTrue(error is ConfigurationError)
            guard let configError = error as? ConfigurationError else { return }
            switch configError {
            case .missingAPIKey:
                break // Expected
            default:
                XCTFail("Expected missingAPIKey, got \(configError)")
            }
        }
    }

    func testValidateConfigurationThrowsNotConfiguredBeforeSetup() {
        // Reset to unconfigured state
        let shared = VioConfiguration.shared
        // After resetting with empty apiKey and sandbox, isConfigured is true
        // but apiKey is empty, so it should throw missingAPIKey
        VioConfiguration.configure(apiKey: "")

        XCTAssertThrowsError(try shared.validateConfiguration())
    }

    func testValidateConfigurationSucceedsWithValidKey() {
        VioConfiguration.configure(apiKey: "valid-api-key-for-viaplay")

        XCTAssertNoThrow(try VioConfiguration.shared.validateConfiguration())
    }

    // MARK: - Environment URLs

    func testProductionEnvironmentBaseURL() {
        XCTAssertTrue(VioEnvironment.production.baseURL.contains("vio.live"))
    }

    func testSandboxEnvironmentBaseURL() {
        XCTAssertTrue(VioEnvironment.sandbox.baseURL.contains("vio.live"))
    }

    func testEnvironmentGraphQLURL() {
        let env = VioEnvironment.production
        XCTAssertTrue(env.graphQLURL.hasSuffix("/graphql"))
    }

    func testAllEnvironmentCases() {
        let cases = VioEnvironment.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.development))
        XCTAssertTrue(cases.contains(.sandbox))
        XCTAssertTrue(cases.contains(.production))
    }

    // MARK: - Configuration Errors

    func testConfigurationErrorNotConfiguredDescription() {
        let error = ConfigurationError.notConfigured
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not configured"))
    }

    func testConfigurationErrorMissingAPIKeyDescription() {
        let error = ConfigurationError.missingAPIKey
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("API Key"))
    }

    func testConfigurationErrorFileNotFoundDescription() {
        let error = ConfigurationError.fileNotFound(fileName: "vio-config.json")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("vio-config.json"))
    }

    // MARK: - Module Configurations Defaults

    func testDefaultMarketConfigurationIsUS() {
        let market = MarketConfiguration.default
        XCTAssertEqual(market.countryCode, "US")
        XCTAssertEqual(market.currencyCode, "USD")
    }

    func testDefaultBrandConfigurationIsElkjop() {
        let brand = BrandConfiguration.default
        XCTAssertEqual(brand.name, "Elkjøp")
    }

    func testBrandConfigurationPowerPreset() {
        let brand = BrandConfiguration.power
        XCTAssertEqual(brand.name, "Power")
        XCTAssertEqual(brand.iconAsset, "avatar_power")
    }

    func testShouldUseSDKWhenConfiguredAndMarketAvailable() {
        VioConfiguration.configure(apiKey: "valid-key")

        XCTAssertTrue(VioConfiguration.shared.shouldUseSDK)
    }

    func testDefaultEngagementConfigurationDemoModeOff() {
        let engagement = EngagementConfiguration.default
        XCTAssertFalse(engagement.demoMode)
    }

    func testResolvedSdkApiKeyMatchesRootWhenCampaignOverrideEmpty() {
        VioConfiguration.configure(apiKey: "root-only-key")
        XCTAssertEqual(VioConfiguration.shared.resolvedSdkApiKey, "root-only-key")
    }

    func testResolvedSdkApiKeyUsesCampaignOverrideWhenNonEmpty() {
        let campaign = CampaignConfiguration(
            webSocketBaseURL: "wss://api-dev.vio.live",
            restAPIBaseURL: "https://api-dev.vio.live",
            campaignApiKey: "override-key"
        )
        VioConfiguration.configure(
            apiKey: "root-key",
            campaignConfig: campaign
        )
        XCTAssertEqual(VioConfiguration.shared.resolvedSdkApiKey, "override-key")
    }

    // MARK: - Commerce bootstrap resolution (no root / campaign fallback)

    func testResolvedCommerceEmptyWithoutBootstrap() {
        VioConfiguration.configure(apiKey: "root-key")
        XCTAssertEqual(VioConfiguration.shared.resolvedCommerceApiKey, "")
        XCTAssertEqual(VioConfiguration.shared.resolvedCommerceGraphQLURL, "")
    }

    func testResolvedCommerceUsesBootstrapOnly() {
        VioConfiguration.configure(apiKey: "root-key")
        VioConfiguration.shared.applySdkBootstrapCommerce(
            apiKey: "commerce-key",
            graphQLURL: "https://graph.test"
        )
        XCTAssertEqual(VioConfiguration.shared.resolvedCommerceApiKey, "commerce-key")
        XCTAssertEqual(VioConfiguration.shared.resolvedCommerceGraphQLURL, "https://graph.test/graphql")
    }

    func testResolvedCommerceIgnoresCampaignCommerceFields() {
        let campaign = CampaignConfiguration(
            webSocketBaseURL: "https://api-dev.vio.live",
            restAPIBaseURL: "https://api-dev.vio.live",
            commerceApiKey: "campaign-commerce",
            commerceGraphQLURL: "https://campaign-gql.example/graphql"
        )
        VioConfiguration.configure(apiKey: "root-key", campaignConfig: campaign)
        XCTAssertEqual(VioConfiguration.shared.resolvedCommerceApiKey, "")
        XCTAssertEqual(VioConfiguration.shared.resolvedCommerceGraphQLURL, "")
    }

    func testResolvedCommerceDoesNotFallBackToRootApiKey() {
        VioConfiguration.configure(apiKey: "root-key")
        XCTAssertNotEqual(VioConfiguration.shared.resolvedCommerceApiKey, VioConfiguration.shared.apiKey)
    }

    func testConfigureClearsSdkRemoteConfigSnapshot() {
        let raw = Data("{\"sdkVersion\":\"1\"}".utf8)
        VioConfiguration.shared.storeSdkConfigSnapshotFromBootstrap(raw: raw, typed: nil)
        XCTAssertNotNil(VioConfiguration.shared.lastSdkConfigRawData)

        // Empty apiKey avoids async bootstrap network touching the snapshot after reset.
        VioConfiguration.configure(apiKey: "", environment: .sandbox)
        XCTAssertNil(VioConfiguration.shared.lastSdkConfigRawData)
        XCTAssertNil(VioConfiguration.shared.lastSdkConfig)
    }

    // MARK: - Singleton

    func testSharedInstanceIsSingleton() {
        let a = VioConfiguration.shared
        let b = VioConfiguration.shared
        XCTAssertTrue(a === b)
    }
}
