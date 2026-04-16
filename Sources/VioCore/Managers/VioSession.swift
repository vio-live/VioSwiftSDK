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
        if CampaignManager.shared.currentCampaign != nil {
            state = .campaignReady
        } else {
            state = .degraded("No active campaign discovered")
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
