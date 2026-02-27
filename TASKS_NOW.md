# TASKS_NOW — Cursor · VioSwiftSDK
**Deadline: Lunes mañana**  
**Objetivo: SDK muestra engagement real desde backend + componentes. Demo lista para TV2 el miércoles.**

---

## 🔴 1. Fix bug 401 — PRIMERO

**Archivo:** `Sources/VioCore/Network/ConfigAPIClient.swift`

El SDK usa la Commerce key (`KCXF10Y-...`) para autenticarse en Vio → 401.
Debe usar la Vio App API Key.

```swift
// ANTES (incorrecto)
private var apiKey: String {
    VioConfiguration.shared.apiKey // ← esta es la Commerce key en el config actual
}

// DESPUÉS (correcto)
private var apiKey: String {
    let campaigns = VioConfiguration.shared.campaignConfiguration
    if !campaigns.campaignApiKey.isEmpty { return campaigns.campaignApiKey }
    if !campaigns.campaignAdminApiKey.isEmpty { return campaigns.campaignAdminApiKey }
    return VioConfiguration.shared.apiKey
}
```

**Verificación:**
```bash
curl "https://api-dev.vio.live/v1/campaigns/28/config?apiKey=xxl_api_key_507d4014243d8360"
# Debe devolver 200 con brand + features + integrations.commerce
```

---

## 🔴 2. Fix logo Elkjøp hardcodeado

**Archivos:**
- `Demo/Viaplay/Viaplay/Components/Common/CampaignSponsorBadge.swift`
- `Demo/Viaplay/Viaplay/Components/ViaplayOfferBannerView.swift`

El logo del sponsor (Elkjøp, XXL, etc.) debe venir de `CampaignConfig.brand.logoUrl` que llega del backend — NO del `DemoDataManager.shared.defaultLogo`.

```swift
// ANTES — fallback a asset local hardcodeado
Image(DemoDataManager.shared.defaultLogo)

// DESPUÉS — usar brand.logoUrl del backend
if let logoUrl = campaignManager.currentCampaignConfig?.brand.logoUrl,
   let url = URL(string: logoUrl) {
    CachedAsyncImage(url: url) { image in image.resizable() }
} else {
    // fallback vacío o placeholder genérico Vio
    Image(systemName: "photo")
}
```

---

## 🔴 3. Eliminar event-streamer URL hardcodeada

**Archivos:**
- `Sources/VioCastingUI/` → buscar `event-streamer-angelo100.replit.app`
- `Sources/VioEngagementSystem/` → buscar también

```swift
// ANTES
"https://event-streamer-angelo100.replit.app"

// DESPUÉS
VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
```

---

## 🔴 4. Parsear `integrations.commerce` en CampaignConfig

El modelo ya tiene `DynamicIntegrationsConfig` con `commerce`. Verificar que:
1. El JSON del backend se parsea correctamente
2. Si `commerce.enabled == true` → pasar `commerce.apiKey` al módulo Commerce
3. Si `commerce.enabled == false` → no inicializar Commerce

---

## 🟡 5. Cleanup Tipio — ver CLEANUP_TIPIO.md

Eliminar:
- `Sources/VioLiveShow/Network/TipioApiClient.swift`
- `Sources/VioLiveShow/Network/TipioWebSocketClient.swift`
- `Sources/VioLiveShow/Models/TipioModels.swift`
- Referencias en `ModuleConfigurations.swift`, `ConfigurationLoader.swift`
- Si `VioLiveShow` queda vacío → evaluar eliminar el módulo

---

## 🟡 6. Verificar loop completo de engagement

Con los fixes anteriores, el SDK debe:
```
1. GET /v1/sdk/campaigns → campañas activas
2. GET /v1/campaigns/:id/config → brand (logo real) + features + commerce key
3. BroadcastContextSetup.setup() → contentId → broadcastId
4. WebSocket /ws/:campaignId → eventos en tiempo real
5. BackendEngagementTabView → muestra polls y contests del backend
```

Probar con:
- `apiKey: viaplay_api_key_0c611e983b314ff8`
- `contentId: real-madrid-barcelona-2025-01-24`
- `country: NO`

---

## ✅ Reglas mientras trabajas

- Una sola `apiKey` en `vio-config.json` para todo lo de Vio
- Commerce key viene del servidor → `integrations.commerce.apiKey`
- Logging: `VioLogger` siempre, nunca `print()`
- Legacy (`campaignId: 28`) debe seguir funcionando — no romper
- Cada fix en un commit separado con mensaje claro

**Cuando termines cada tarea, súbela. Viobot revisa y coordina con Replit.**
