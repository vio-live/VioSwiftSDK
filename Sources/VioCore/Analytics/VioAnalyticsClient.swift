import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Vio Analytics — contract-v1 transport for iOS/tvOS (F5).
///
/// Sends events to the Vio collector (`vio-live/vio-analytics`,
/// `POST <eventsBase>/v1/events`), which owns raw storage (ClickHouse) and
/// any vendor fan-out server-side. THE SDK NEVER TALKS TO VENDORS — the
/// legacy Mixpanel path in `AnalyticsManager` is kept only for hosts that
/// still link it, and is scheduled for removal.
///
/// Wire contract: `vio-analytics/docs/EVENTS_CONTRACT.md` (snake_case JSON,
/// additive-only v1). Mechanics per the contract's platform table:
///   - `anon_id` persists in UserDefaults (`vio.anon.v1`)
///   - rolling 30-min session (`vio.session.v1`), `session_start` on rotation
///   - batch flush: 20 events / 5 s / app-background
///   - offline queue persisted to disk (Application Support), capped at 500
///     drop-oldest; `event_id` is stable so retries are dedupe-safe
///   - clients never name their tenant — the api key does.
@MainActor
public final class VioAnalyticsClient {

    public static let shared = VioAnalyticsClient()

    // MARK: - Tunables (contract-aligned)

    static let sessionTTL: TimeInterval = 30 * 60
    static let flushInterval: TimeInterval = 5
    static let flushAtCount = 20
    static let maxQueue = 500
    static let maxBatch = 500
    static let retryBackoff: [TimeInterval] = [2, 4, 8]
    static let anonKey = "vio.anon.v1"
    static let sessionKey = "vio.session.v1"
    static let sdkVersion = "1.0.0" // keep in sync with release tags

    // MARK: - Wire format

    /// Minimal JSON value so `props`/`commerce` stay type-safe end to end.
    public indirect enum JSONValue: Encodable, Equatable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case array([JSONValue])
        case object([String: JSONValue])

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value): try container.encode(value)
            case .int(let value): try container.encode(value)
            case .double(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .object(let value): try container.encode(value)
            }
        }

        /// Best-effort bridge from legacy `[String: Any]` metadata.
        static func from(_ any: Any) -> JSONValue? {
            switch any {
            case let value as String: return .string(value)
            case let value as Bool: return .bool(value)
            case let value as Int: return .int(value)
            case let value as Double: return .double(value)
            case let value as [Any]: return .array(value.compactMap(from))
            case let value as [String: Any]:
                return .object(value.compactMapValues(from))
            default: return nil
            }
        }
    }

    public struct Context: Encodable, Equatable {
        public var campaignId: Int?
        public var broadcastId: String?
        public var campaignComponentId: Int?
        public var appPlacementId: Int?
        public var locationId: String?
        public var componentTemplateId: String?
        public var sponsorId: Int?
        public var activationId: Int?
        public var tvSessionId: Int?
        public var contentUrl: String?
        public var variant: String?

        public init(
            campaignId: Int? = nil, broadcastId: String? = nil,
            campaignComponentId: Int? = nil, appPlacementId: Int? = nil,
            locationId: String? = nil, componentTemplateId: String? = nil,
            sponsorId: Int? = nil, activationId: Int? = nil,
            tvSessionId: Int? = nil, contentUrl: String? = nil,
            variant: String? = nil
        ) {
            self.campaignId = campaignId
            self.broadcastId = broadcastId
            self.campaignComponentId = campaignComponentId
            self.appPlacementId = appPlacementId
            self.locationId = locationId
            self.componentTemplateId = componentTemplateId
            self.sponsorId = sponsorId
            self.activationId = activationId
            self.tvSessionId = tvSessionId
            self.contentUrl = contentUrl
            self.variant = variant
        }

        enum CodingKeys: String, CodingKey {
            case campaignId = "campaign_id"
            case broadcastId = "broadcast_id"
            case campaignComponentId = "campaign_component_id"
            case appPlacementId = "app_placement_id"
            case locationId = "location_id"
            case componentTemplateId = "component_template_id"
            case sponsorId = "sponsor_id"
            case activationId = "activation_id"
            case tvSessionId = "tv_session_id"
            case contentUrl = "content_url"
            case variant
        }
    }

    public struct Item: Encodable, Equatable {
        public var productId: String
        public var name: String?
        public var brand: String?
        public var variantId: String?
        public var price: Double?
        public var quantity: Int?

        public init(
            productId: String, name: String? = nil, brand: String? = nil,
            variantId: String? = nil, price: Double? = nil, quantity: Int? = nil
        ) {
            self.productId = productId
            self.name = name
            self.brand = brand
            self.variantId = variantId
            self.price = price
            self.quantity = quantity
        }

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case name, brand
            case variantId = "variant_id"
            case price, quantity
        }
    }

    public struct Commerce: Encodable, Equatable {
        public var items: [Item]?
        public var value: Double?
        public var currency: String?
        public var orderId: String?
        public var paymentMethod: String?

        public init(
            items: [Item]? = nil, value: Double? = nil, currency: String? = nil,
            orderId: String? = nil, paymentMethod: String? = nil
        ) {
            self.items = items
            self.value = value
            self.currency = currency
            self.orderId = orderId
            self.paymentMethod = paymentMethod
        }

        enum CodingKeys: String, CodingKey {
            case items, value, currency
            case orderId = "order_id"
            case paymentMethod = "payment_method"
        }
    }

    struct WireEvent: Encodable {
        let eventId: String
        let name: String
        let ts: String
        let surface: String
        let sdkVersion: String
        let sessionId: String
        let anonId: String
        var externalUserId: String?
        var context: Context?
        var commerce: Commerce?
        var props: [String: JSONValue]?

        enum CodingKeys: String, CodingKey {
            case eventId = "event_id"
            case name, ts, surface
            case sdkVersion = "sdk_version"
            case sessionId = "session_id"
            case anonId = "anon_id"
            case externalUserId = "external_user_id"
            case context, commerce, props
        }
    }

    // MARK: - State

    private var enabled = false
    private var eventsBase = ""
    private var apiKeyProvider: () -> String? = { nil }
    private var queue: [WireEvent] = []
    private var externalUserId: String?
    private var flushTimer: Timer?
    private var retryAttempt = 0
    private var retryNotBefore: Date = .distantPast
    private var flushing = false

    private var sessionId: String?
    private var sessionStartedAt: Date = .distantPast

    // Injectable for tests.
    let defaults: UserDefaults
    var now: () -> Date = { Date() }
    /// Test seam: replaces the HTTP send. Returns true on success.
    var sender: (([WireEvent], String, String?) async -> Bool)?

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Activate the collector transport. Called from `AnalyticsManager.configure`.
    public func start(eventsBase: String, apiKeyProvider: @escaping () -> String?) {
        self.eventsBase = eventsBase.hasSuffix("/") ? String(eventsBase.dropLast()) : eventsBase
        self.apiKeyProvider = apiKeyProvider
        self.enabled = true
        loadPersistedQueue()
        ensureSession()

        flushTimer?.invalidate()
        let timer = Timer(timeInterval: Self.flushInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.flush() }
        }
        RunLoop.main.add(timer, forMode: .common)
        flushTimer = timer

        #if canImport(UIKit) && (os(iOS) || os(tvOS))
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.flush()
                self?.persistQueue()
            }
        }
        #endif
    }

    public func stop() {
        enabled = false
        flushTimer?.invalidate()
        flushTimer = nil
    }

    /// Partner's opaque user id. NEVER auto-derived from emails/PII.
    public func identify(_ externalUserId: String?) {
        self.externalUserId = externalUserId
    }

    /// Current rolling session id — `AnalyticsManager` scopes its
    /// once-per-session impression guard to this.
    public var currentSessionId: String {
        ensureSession()
        return sessionId ?? ""
    }

    public func track(
        name: String,
        context: Context? = nil,
        commerce: Commerce? = nil,
        props: [String: JSONValue]? = nil
    ) {
        guard enabled else { return }
        ensureSession()
        guard let session = sessionId else { return }

        let event = WireEvent(
            eventId: UUID().uuidString.lowercased(),
            name: name,
            ts: isoFormatter.string(from: now()),
            surface: Self.surface,
            sdkVersion: Self.sdkVersion,
            sessionId: session,
            anonId: anonId,
            externalUserId: externalUserId,
            context: context,
            commerce: commerce,
            props: props
        )
        queue.append(event)
        if queue.count > Self.maxQueue {
            queue.removeFirst(queue.count - Self.maxQueue) // drop oldest
        }
        if queue.count >= Self.flushAtCount {
            Task { await flush() }
        }
    }

    public func flush() async {
        guard enabled, !flushing, !queue.isEmpty else { return }
        guard now() >= retryNotBefore else { return }
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else { return } // not initialized yet — hold

        flushing = true
        defer { flushing = false }
        let batch = Array(queue.prefix(Self.maxBatch))

        let ok: Bool
        if let sender {
            ok = await sender(batch, eventsBase, apiKey)
        } else {
            ok = await send(batch: batch, apiKey: apiKey)
        }

        if ok {
            queue.removeFirst(min(batch.count, queue.count))
            retryAttempt = 0
        } else {
            // Same event_ids stay queued — the collector dedupes retries.
            let backoff = Self.retryBackoff[min(retryAttempt, Self.retryBackoff.count - 1)]
            retryAttempt += 1
            retryNotBefore = now().addingTimeInterval(backoff)
        }
    }

    // MARK: - Transport

    private func send(batch: [WireEvent], apiKey: String) async -> Bool {
        struct Envelope: Encodable {
            let apiKey: String
            let sentAt: String
            let events: [WireEvent]
            enum CodingKeys: String, CodingKey {
                case apiKey
                case sentAt = "sent_at"
                case events
            }
        }
        guard let url = URL(string: "\(eventsBase)/v1/events") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        do {
            request.httpBody = try JSONEncoder().encode(
                Envelope(apiKey: apiKey, sentAt: isoFormatter.string(from: now()), events: batch)
            )
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            if http.statusCode == 401 || http.statusCode == 400 {
                // Config problem, not transient — drop rather than loop forever.
                return true
            }
            return http.statusCode == 202
        } catch {
            return false
        }
    }

    // MARK: - Identity & session

    var anonId: String {
        if let existing = defaults.string(forKey: Self.anonKey) { return existing }
        let fresh = "a-\(UUID().uuidString.lowercased())"
        defaults.set(fresh, forKey: Self.anonKey)
        return fresh
    }

    private struct StoredSession: Codable {
        let id: String
        let ts: TimeInterval
        let startedAt: TimeInterval
    }

    private func ensureSession() {
        let current = now()
        if sessionId == nil,
           let data = defaults.data(forKey: Self.sessionKey),
           let stored = try? JSONDecoder().decode(StoredSession.self, from: data),
           current.timeIntervalSince1970 - stored.ts < Self.sessionTTL {
            sessionId = stored.id
            sessionStartedAt = Date(timeIntervalSince1970: stored.startedAt)
        } else if let data = defaults.data(forKey: Self.sessionKey),
                  let stored = try? JSONDecoder().decode(StoredSession.self, from: data),
                  current.timeIntervalSince1970 - stored.ts >= Self.sessionTTL {
            sessionId = nil // idle too long — rotate
        }

        if sessionId == nil {
            let fresh = "s-\(UUID().uuidString.lowercased())"
            sessionId = fresh
            sessionStartedAt = current
            persistSession()
            track(name: "session_start")
        } else {
            persistSession()
        }
    }

    private func persistSession() {
        guard let sessionId else { return }
        let stored = StoredSession(
            id: sessionId,
            ts: now().timeIntervalSince1970,
            startedAt: sessionStartedAt.timeIntervalSince1970
        )
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: Self.sessionKey)
        }
    }

    // MARK: - Offline persistence

    private var queueFileURL: URL? {
        guard let dir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vio-analytics-queue.json")
    }

    private func persistQueue() {
        guard let url = queueFileURL else { return }
        if queue.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        // WireEvent is Encodable-only; persist as raw JSON array.
        if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadPersistedQueue() {
        guard let url = queueFileURL,
              let data = try? Data(contentsOf: url) else { return }
        try? FileManager.default.removeItem(at: url)
        // Decode loosely — a queue we can't read is dropped, never crashes.
        if let restored = try? JSONDecoder().decode([RestoredEvent].self, from: data) {
            let events = restored.map(\.wire)
            queue.insert(contentsOf: events.suffix(Self.maxQueue), at: 0)
        }
    }

    /// Decodable twin of WireEvent for queue restore (WireEvent stays Encodable-only).
    private struct RestoredEvent: Decodable {
        let event_id: String
        let name: String
        let ts: String
        let surface: String
        let sdk_version: String
        let session_id: String
        let anon_id: String
        let external_user_id: String?

        var wire: WireEvent {
            WireEvent(
                eventId: event_id, name: name, ts: ts, surface: surface,
                sdkVersion: sdk_version, sessionId: session_id, anonId: anon_id,
                externalUserId: external_user_id, context: nil, commerce: nil, props: nil
            )
        }
    }

    // MARK: - Platform

    static var surface: String {
        #if os(tvOS)
        return "tvos"
        #else
        return "ios"
        #endif
    }
}

// MARK: - Environment → collector URL

extension VioEnvironment {
    /// Analytics collector base for this environment (override via
    /// `AnalyticsConfiguration.eventsBase`).
    public var eventsURL: String {
        switch self {
        case .development, .testing, .sandbox:
            return "https://events-dev.vio.live"
        case .production:
            return "https://events.vio.live"
        }
    }
}
