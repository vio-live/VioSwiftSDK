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
                VioLogger.log("🔕 [DeviceToken] Push permission denied", level: .warning)
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
        VioLogger.log("📱 [DeviceToken] Token recibido: \(token.prefix(12))...", level: .info)
        Task { await sendToBackend(token: token) }
    }

    /// Llamar desde AppDelegate.didFailToRegisterForRemoteNotificationsWithError
    public func didFailToRegister(error: Error) {
        VioLogger.log("❌ [DeviceToken] Registration failed: \(error.localizedDescription)", level: .error)
    }

    // MARK: - Private

    private func sendToBackend(token: String) async {
        let config = VioConfiguration.shared
        guard !config.apiKey.isEmpty,
              let campaign = CampaignManager.shared.currentCampaign else {
            VioLogger.log("⚠️ [DeviceToken] No apiKey o campaña activa — skip register", level: .warning)
            return
        }

        let baseURL = config.campaignConfiguration.restAPIBaseURL
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
                VioLogger.log("✅ [DeviceToken] Registrado en backend (userId: \(config.userId))", level: .info)
            }
        } catch {
            VioLogger.log("❌ [DeviceToken] Backend register error: \(error)", level: .error)
        }
    }
}
#endif
