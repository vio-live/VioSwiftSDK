import Foundation

@MainActor
public final class VioSession: ObservableObject {
    public static let shared = VioSession()

    public enum State: Equatable {
        case idle
        case bootstrapping
        case campaignReady
        case commerceReady
        case degraded(String)
        case stopped
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var lastBroadcastId: String?

    private init() {}

    public func start(broadcastId: String? = nil) async {
        state = .bootstrapping
        lastBroadcastId = broadcastId
        await ensureCommerceBootstrapApplied()
        if case .degraded = state {
            return
        }
        state = .commerceReady
        await CampaignManager.shared.discoverCampaigns(broadcastId: broadcastId)
        // Best-effort: upload the placement registry manifest so the dashboard
        // sees what this app implements + which slots it exposes. Failures
        // are non-fatal; the dashboard simply won't see the new entries
        // until the next successful upload. Tied to start (not init) so the
        // upload happens on every cold start and survives partner apps that
        // restart the SDK without restarting the process.
        await uploadPlacementManifestIfPossible()
        if CampaignManager.shared.currentCampaign != nil {
            state = .campaignReady
        } else {
            state = .degraded("No active campaign discovered")
        }
    }

    /// Posts the placement registry to `/v2/mobile/components/manifest`. No-ops
    /// when the registry is empty (partner hasn't called
    /// `Vio.registerPlacementComponent(...)` / `registerPlacementLocation(...)`).
    /// Logs and swallows all errors — this is best-effort orchestration, not
    /// part of the bootstrap critical path.
    @MainActor
    private func uploadPlacementManifestIfPossible() async {
        let cfg = VioConfiguration.shared
        let baseURL = cfg.campaignConfiguration.restAPIBaseURL
        let apiKey = cfg.resolvedSdkApiKey
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            VioLogger.debug("Manifest upload skipped — base URL or API key not yet resolved", component: "VioSession")
            return
        }
        do {
            let response = try await VioPlacementManifestUploader.upload(baseURL: baseURL, apiKey: apiKey)
            VioLogger.success(
                "Placement manifest uploaded — components=\(response.components.count) locations=\(response.locations.count) warnings=\(response.warnings?.count ?? 0)",
                component: "VioSession"
            )
            for w in response.warnings ?? [] {
                VioLogger.warning("Manifest warning [\(w.kind)]: \(w.detail)", component: "VioSession")
            }
        } catch VioPlacementManifestUploader.UploadError.skipped(let reason) {
            VioLogger.debug("Manifest upload skipped — \(reason)", component: "VioSession")
        } catch {
            VioLogger.warning("Manifest upload failed (non-fatal): \(error)", component: "VioSession")
        }
    }

    public func refresh() async {
        await start(broadcastId: lastBroadcastId)
    }

    public func stop() {
        CampaignManager.shared.disconnect()
        state = .stopped
    }

    public func setUserContext(userId: String?) {
        let trimmed = userId?.trimmingCharacters(in: .whitespacesAndNewlines)
        CampaignManager.shared.userId = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    public func submitPushToken(_ tokenHex: String) {
        CampaignManager.shared.submitApnsDeviceTokenForVioRegister(tokenHex)
    }

    /// Runtime-first path used by VioUI payment orchestration.
    public func ensureCommerceBootstrapApplied() async {
        let attempts = max(1, VioRuntimeRetryPolicy.commerceBootstrapRetryCount + 1)
        for index in 0..<attempts {
            await CampaignManager.shared.ensureCommerceBootstrapApplied()
            if !VioConfiguration.shared.resolvedCommerceGraphQLURL.isEmpty {
                if state == .idle || state == .bootstrapping {
                    state = .commerceReady
                }
                return
            }
            if index < attempts - 1 {
                continue
            }
            state = .degraded("Commerce bootstrap could not be resolved")
        }
    }
}
