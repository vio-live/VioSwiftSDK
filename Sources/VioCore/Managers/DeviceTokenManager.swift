import Foundation
#if canImport(UIKit)
import UIKit
import UserNotifications

public class DeviceTokenManager {
    public static let shared = DeviceTokenManager()
    private init() {}

    private var registeredToken: String?
    private var pendingToken: String?

    @MainActor
    public func registerIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                VioLogger.warning("🔕 [DeviceToken] Push permission denied")
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    public func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        guard token != registeredToken else { return }
        registeredToken = token
        pendingToken = token
        print("📱 [DeviceToken] Token recibido: \(token.prefix(16))...")
        Task { await sendToBackendWithRetry(token: token) }
    }

    public func didFailToRegister(error: Error) {
        print("❌ [DeviceToken] Registration failed: \(error)")
    }

    /// Llamar cuando el SDK esté READY para reintentar si el token llegó antes
    public func retryPendingRegistration() {
        guard let token = pendingToken, token != registeredToken || pendingToken != nil else { return }
        print("🔄 [DeviceToken] Reintentando registro con token pendiente...")
        Task { await sendToBackendWithRetry(token: token) }
    }

    private func sendToBackendWithRetry(token: String, attempt: Int = 1) async {
        let config = VioConfiguration.shared
        let campaigns = await CampaignManager.shared.activeCampaigns

        guard !config.apiKey.isEmpty, let campaign = campaigns.first else {
            if attempt < 5 {
                print("⏳ [DeviceToken] Campaña no lista, reintentando en 2s (intento \(attempt))...")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await sendToBackendWithRetry(token: token, attempt: attempt + 1)
            } else {
                print("❌ [DeviceToken] Abandonando registro tras 5 intentos")
            }
            return
        }

        let baseURL = await config.campaignConfiguration.restAPIBaseURL
        guard let url = URL(string: "\(baseURL)/api/campaigns/\(campaign.id)/register-device") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "userId": config.userId.isEmpty ? "anonymous" : config.userId,
            "deviceToken": token,
            "platform": "ios"
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            if status == 200 || status == 201 {
                pendingToken = nil
                print("✅ [DeviceToken] Registrado en backend (userId: \(config.userId), campaignId: \(campaign.id))")
            } else {
                print("❌ [DeviceToken] Backend error \(status): \(body.prefix(100))")
            }
        } catch {
            print("❌ [DeviceToken] Backend register error: \(error)")
        }
    }
}
#endif
