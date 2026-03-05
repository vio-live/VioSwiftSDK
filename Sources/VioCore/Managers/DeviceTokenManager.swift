import Foundation
#if canImport(UIKit)
import UIKit
import UserNotifications

/// Gestiona el registro del dispositivo en el backend de Vio para push notifications.
/// El broadcaster debe llamar `DeviceTokenManager.shared.registerIfNeeded()` tras configurar el SDK.
public class DeviceTokenManager {
    public static let shared = DeviceTokenManager()
    private init() {}

    private var registeredToken: String?

    /// Solicita permiso de push y registra el deviceToken en el backend.
    /// Llamar después de `VioConfiguration.configure(apiKey:userId:)`
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

    /// Llamar desde AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken
    public func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        guard token != registeredToken else { return }
        registeredToken = token
        VioLogger.info("📱 [DeviceToken] Token recibido: \(token.prefix(12))...")
        Task { await sendToBackend(token: token) }
    }

    /// Llamar desde AppDelegate.didFailToRegisterForRemoteNotificationsWithError
    public func didFailToRegister(error: Error) {
        VioLogger.error("❌ [DeviceToken] Registration failed: \(error.localizedDescription)")
    }

    // MARK: - Private

    private func sendToBackend(token: String) async {
        let config = VioConfiguration.shared
        guard !config.apiKey.isEmpty,
              let campaign = CampaignManager.shared.currentCampaign else {
            VioLogger.warning("⚠️ [DeviceToken] No apiKey o campaña activa — skip register")
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
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 201 {
                VioLogger.info("✅ [DeviceToken] Registrado en backend (userId: \(config.userId))")
            }
        } catch {
            VioLogger.error("❌ [DeviceToken] Backend register error: \(error)")
        }
    }
}
#endif
