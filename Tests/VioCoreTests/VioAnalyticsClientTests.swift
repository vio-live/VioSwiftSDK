import XCTest
@testable import VioCore

/// Contract-v1 transport — wire format, sessions, queue and retry semantics.
/// Uses injected UserDefaults/clock/sender so no I/O happens.
@MainActor
final class VioAnalyticsClientTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "vio-analytics-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeClient(
        now: Date = Date(),
        onSend: @escaping ([VioAnalyticsClient.WireEvent], String, String?) async -> Bool = { _, _, _ in true }
    ) -> (VioAnalyticsClient, sent: () -> [[VioAnalyticsClient.WireEvent]]) {
        let client = VioAnalyticsClient(defaults: defaults)
        var currentNow = now
        client.now = { currentNow }
        var batches: [[VioAnalyticsClient.WireEvent]] = []
        client.sender = { batch, base, key in
            batches.append(batch)
            return await onSend(batch, base, key)
        }
        client.start(eventsBase: "https://events.test") { "test-key" }
        _ = currentNow // silence unused warning when not advanced
        return (client, { batches })
    }

    func testWireFormatIsSnakeCaseContractV1() throws {
        let (client, _) = makeClient()
        client.track(
            name: "component_impression",
            context: .init(campaignId: 44, campaignComponentId: 512, sponsorId: 9, variant: "top-b"),
            commerce: .init(items: [.init(productId: "408948", price: 300)], value: 300, currency: "NOK"),
            props: ["source": .string("carousel")]
        )

        // Encode the queued event exactly as the transport would.
        let mirror = Mirror(reflecting: client)
        guard let queue = mirror.descendant("queue") as? [VioAnalyticsClient.WireEvent],
              let event = queue.last else {
            return XCTFail("event not queued")
        }
        let data = try JSONEncoder().encode(event)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["name"] as? String, "component_impression")
        XCTAssertEqual(json["surface"] as? String, VioAnalyticsClient.surface)
        XCTAssertNotNil(json["event_id"])
        XCTAssertNotNil(json["sdk_version"])
        XCTAssertTrue((json["session_id"] as? String)?.hasPrefix("s-") ?? false)
        XCTAssertTrue((json["anon_id"] as? String)?.hasPrefix("a-") ?? false)
        let context = try XCTUnwrap(json["context"] as? [String: Any])
        XCTAssertEqual(context["campaign_component_id"] as? Int, 512)
        XCTAssertEqual(context["variant"] as? String, "top-b")
        let commerce = try XCTUnwrap(json["commerce"] as? [String: Any])
        let items = try XCTUnwrap(commerce["items"] as? [[String: Any]])
        XCTAssertEqual(items.first?["product_id"] as? String, "408948")
    }

    func testSessionStartEmittedOnceAndAnonPersists() {
        let (client, _) = makeClient()
        client.track(name: "view_item")
        client.track(name: "view_item")

        let mirror = Mirror(reflecting: client)
        let queue = mirror.descendant("queue") as? [VioAnalyticsClient.WireEvent] ?? []
        let names = queue.map(\.name)
        XCTAssertEqual(names.filter { $0 == "session_start" }.count, 1)
        XCTAssertEqual(names.filter { $0 == "view_item" }.count, 2)

        // Anon id survives a new client on the same defaults (same device).
        let (client2, _) = makeClient()
        XCTAssertEqual(client.anonId, client2.anonId)
    }

    func testSessionRotatesAfterThirtyMinutesIdle() {
        let start = Date()
        let client = VioAnalyticsClient(defaults: defaults)
        var currentNow = start
        client.now = { currentNow }
        client.sender = { _, _, _ in true }
        client.start(eventsBase: "https://events.test") { "test-key" }

        client.track(name: "view_item")
        let firstSession = client.currentSessionId

        currentNow = start.addingTimeInterval(31 * 60) // 31 min idle
        client.track(name: "view_item")
        let secondSession = client.currentSessionId

        XCTAssertNotEqual(firstSession, secondSession)
        XCTAssertTrue(secondSession.hasPrefix("s-"))
    }

    func testFlushRetriesWithSameEventIdsAfterFailure() async {
        var succeed = false
        let (client, sent) = makeClient(onSend: { _, _, _ in succeed })

        client.track(name: "view_item")
        await client.flush() // fails — stays queued, backoff armed
        XCTAssertEqual(sent().count, 1)

        await client.flush() // inside backoff window — no send
        XCTAssertEqual(sent().count, 1)

        // Move past backoff and let it succeed.
        let mirror = Mirror(reflecting: client)
        _ = mirror
        succeed = true
        client.now = { Date().addingTimeInterval(30) }
        await client.flush()
        XCTAssertEqual(sent().count, 2)
        let firstIds = sent()[0].map(\.eventId)
        let retryIds = sent()[1].map(\.eventId)
        XCTAssertEqual(firstIds, retryIds) // stable ids — collector dedupes
    }

    func testQueueDropsOldestBeyondCap() {
        let (client, _) = makeClient(onSend: { _, _, _ in false })
        for index in 0..<620 {
            client.track(name: "view_item", props: ["i": .int(index)])
        }
        let mirror = Mirror(reflecting: client)
        let queue = mirror.descendant("queue") as? [VioAnalyticsClient.WireEvent] ?? []
        XCTAssertLessThanOrEqual(queue.count, 500)
        // The newest event survived the cap.
        XCTAssertEqual(queue.last?.props?["i"], .int(619))
    }
}
