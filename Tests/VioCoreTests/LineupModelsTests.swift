// Tests for LineupWSEvent — covers LineupShowEvent decoding, timestamp validation,
// optional field handling, and WebSocket payload resilience for Viaplay SDK demo

import XCTest
@testable import VioCore

final class LineupModelsTests: XCTestCase {

    // MARK: - Basic Decoding

    func testLineupShowEventDecodesFullPayload() throws {
        let json = """
        {
            "videoTimestamp": 600.0,
            "kickoffVideoTimestamp": 1200.0,
            "broadcastId": "viaplay-ucl-barca-psg-2025",
            "leadTimeSeconds": 600
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        XCTAssertEqual(event.videoTimestamp, 600.0)
        XCTAssertEqual(event.kickoffVideoTimestamp, 1200.0)
        XCTAssertEqual(event.broadcastId, "viaplay-ucl-barca-psg-2025")
        XCTAssertEqual(event.leadTimeSeconds, 600)
    }

    func testLineupShowEventVideoTimestampIsRequired() {
        let json = """
        {
            "kickoffVideoTimestamp": 1200.0,
            "broadcastId": "test-broadcast"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(LineupShowEvent.self, from: json))
    }

    // MARK: - Optional Fields

    func testLineupShowEventDecodesWithOnlyVideoTimestamp() throws {
        let json = """
        {"videoTimestamp": 300.0}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        XCTAssertEqual(event.videoTimestamp, 300.0)
        XCTAssertNil(event.kickoffVideoTimestamp)
        XCTAssertNil(event.broadcastId)
        XCTAssertNil(event.leadTimeSeconds)
    }

    func testLineupShowEventMissingKickoffTimestampIsNil() throws {
        let json = """
        {"videoTimestamp": 500.0, "broadcastId": "stream-123"}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        XCTAssertNil(event.kickoffVideoTimestamp)
    }

    func testLineupShowEventMissingLeadTimeSecondsIsNil() throws {
        let json = """
        {"videoTimestamp": 600.0, "kickoffVideoTimestamp": 1200.0}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        XCTAssertNil(event.leadTimeSeconds)
    }

    func testLineupShowEventMissingBroadcastIdIsNil() throws {
        let json = """
        {"videoTimestamp": 600.0, "kickoffVideoTimestamp": 1200.0, "leadTimeSeconds": 600}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        XCTAssertNil(event.broadcastId)
    }

    // MARK: - Timestamp Semantics

    func testVideoTimestampIsLessThanOrEqualToKickoffTimestamp() throws {
        let json = """
        {"videoTimestamp": 600.0, "kickoffVideoTimestamp": 1200.0, "leadTimeSeconds": 600}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        if let kickoff = event.kickoffVideoTimestamp {
            XCTAssertLessThanOrEqual(event.videoTimestamp, kickoff,
                "videoTimestamp should be <= kickoffVideoTimestamp (lineup shows before kickoff)")
        }
    }

    func testLeadTimeMatchesTimestampDifference() throws {
        // Backend calculates: videoTimestamp = kickoffVideoTimestamp - leadTimeSeconds
        let json = """
        {"videoTimestamp": 600.0, "kickoffVideoTimestamp": 1200.0, "leadTimeSeconds": 600}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        if let kickoff = event.kickoffVideoTimestamp, let lead = event.leadTimeSeconds {
            let expectedVideo = kickoff - TimeInterval(lead)
            XCTAssertEqual(event.videoTimestamp, expectedVideo, accuracy: 0.001)
        }
    }

    // MARK: - Realistic Scenarios

    func testLineupShowEventUEFACLScenario() throws {
        // Stream starts 20 min before kickoff, lineup shown 10 min before kickoff
        // kickoffVideoTimestamp = 1200s (20 min), lineupVideoTimestamp = 600s (10 min)
        let json = """
        {
            "videoTimestamp": 600.0,
            "kickoffVideoTimestamp": 1200.0,
            "broadcastId": "viaplay-ucl-2025-semifinal",
            "leadTimeSeconds": 600
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        XCTAssertEqual(event.videoTimestamp, 600.0, "Lineup should appear at 10 min mark")
        XCTAssertEqual(event.kickoffVideoTimestamp, 1200.0, "Kickoff at 20 min mark")
        XCTAssertEqual(event.leadTimeSeconds, 600, "10 min lead time")
    }

    func testLineupShowEventZeroVideoTimestamp() throws {
        // Edge case: lineup shown at stream start
        let json = """
        {"videoTimestamp": 0.0, "kickoffVideoTimestamp": 300.0, "leadTimeSeconds": 300}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        XCTAssertEqual(event.videoTimestamp, 0.0)
    }

    func testLineupShowEventLargeTimestamps() throws {
        // Long pre-match coverage: 1 hour before kickoff
        let json = """
        {
            "videoTimestamp": 1800.0,
            "kickoffVideoTimestamp": 3600.0,
            "broadcastId": "viaplay-world-cup-final",
            "leadTimeSeconds": 1800
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        XCTAssertEqual(event.videoTimestamp, 1800.0)
        XCTAssertEqual(event.kickoffVideoTimestamp, 3600.0)
    }

    func testLineupShowEventIntegerVideoTimestamp() throws {
        // Backend may send integer instead of float
        let json = """
        {"videoTimestamp": 600, "kickoffVideoTimestamp": 1200}
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(LineupShowEvent.self, from: json)
        XCTAssertEqual(event.videoTimestamp, 600.0)
    }
}
