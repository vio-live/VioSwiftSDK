import XCTest
@testable import VioCore

final class SdkRemoteConfigTests: XCTestCase {

    private let sampleJSON = """
    {
        "sdkVersion": "0.2.0",
        "clientApp": { "id": 18, "name": "TV2", "apiKey": "tv2_api_key_test" },
        "endpoints": {
            "restBase": "http://127.0.0.1:5001",
            "webSocketBase": "ws://127.0.0.1:5001",
            "commerceGraphQL": "https://graph-ql-dev.vio.live"
        },
        "features": {
            "engagement": true,
            "adPlacements": true,
            "commerce": true,
            "lineup": true
        },
        "commerce": {
            "apiKey": "COMMERCE_KEY_123",
            "endpoint": "https://graph-ql-dev.vio.live"
        },
        "theme": { "primaryColor": null, "accentColor": null },
        "markets": [],
        "campaign": {
            "id": 36,
            "campaignId": 36,
            "campaignName": "Tv2 Demo Campaign",
            "campaignLogo": null,
            "isActive": false,
            "isPaused": "false",
            "startDate": "2026-03-02T19:33:00.000Z",
            "endDate": "2026-04-13T23:59:59.000Z"
        }
    }
    """

    func testDecodeSdkRemoteConfigWithStringIsPaused() throws {
        let data = try XCTUnwrap(sampleJSON.data(using: .utf8))
        let cfg = try JSONDecoder().decode(SdkRemoteConfig.self, from: data)
        XCTAssertEqual(cfg.sdkVersion, "0.2.0")
        XCTAssertEqual(cfg.clientApp?.id, 18)
        XCTAssertEqual(cfg.clientApp?.name, "TV2")
        XCTAssertEqual(cfg.features?.commerce, true)
        XCTAssertEqual(cfg.campaign?.isPaused, false)
        XCTAssertEqual(cfg.markets?.count, 0)
        XCTAssertEqual(cfg.commerce?.apiKey, "COMMERCE_KEY_123")
    }

    func testCommerceCredentialsFeaturesCommerceTrue() throws {
        let data = try XCTUnwrap(sampleJSON.data(using: .utf8))
        let cfg = try JSONDecoder().decode(SdkRemoteConfig.self, from: data)
        let (key, gql) = cfg.commerceCredentialsForBootstrap()
        XCTAssertEqual(key, "COMMERCE_KEY_123")
        XCTAssertNotNil(gql)
        XCTAssertFalse(gql?.isEmpty ?? true)
    }

    func testCommerceCredentialsFeaturesCommerceFalseIgnoresCommerceBlock() throws {
        var obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(sampleJSON.utf8)) as? [String: Any])
        var features = (obj["features"] as? [String: Any]) ?? [:]
        features["commerce"] = false
        obj["features"] = features
        let data = try JSONSerialization.data(withJSONObject: obj, options: [])
        let cfg = try JSONDecoder().decode(SdkRemoteConfig.self, from: data)
        let (key, gql) = cfg.commerceCredentialsForBootstrap()
        XCTAssertNil(key)
        XCTAssertNil(gql)
    }
}
