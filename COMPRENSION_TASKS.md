# Comprensión — TASKS_NOW (4 tareas)

## Contexto general

**Dos flujos separados:**
1. **Timeline demo (offline)**: Datos estáticos desde demo-static-data.json. Barcelona-PSG usa Match.barcelonaPSG. 100% offline.
2. **Backend engagement (online)**: contentId → GET /v1/sdk/broadcast → broadcastId → WebSocket → polls/contests. Real Madrid - Barcelona.

**NO tocar:** TimelineDataGenerator, demo-static-data.json, flujo Barcelona-PSG.

---

## Tarea 1: BroadcastContextSetup cierra el loop

**Flujo esperado:**
1. ViaplayApp: `discoverCampaigns()` → campaña 35
2. ViaplayApp: `loadCampaignConfig(35)` → brand Elkjøp (logoUrl) → VioConfiguration
3. Usuario abre Real Madrid - Barcelona → SportDetailView tiene contentId "real-madrid-barcelona-2025-01-24", country "NO"
4. BroadcastContextSetup.setup() → validate(contentId, country) → broadcastId "real-madrid-vs-barcelona-2026-02-25"
5. setBroadcastContext + setEngagementCallbacks (onPollEventReceived, onContestEventReceived)
6. WebSocket conecta a /ws/35
7. Backend envía polls vía WS → EngagementManager.addOrUpdatePoll → BackendEngagementTabView muestra polls 15 y 16

**Estado:** loadEngagement está comentado (memory leak). Los polls llegan vía WebSocket cuando el backend los envía. El loop está cerrado si el backend push inicial vía WS.

**tv2demo:** Usa mismo BroadcastContextSetup (VioCastingUI). Debe tener discoverCampaigns + loadCampaignConfig al launch (ya lo tiene). Falta: aplicar brand/sponsor config a VioConfiguration.

---

## Tarea 2: Logo Elkjøp en UI

**CampaignSponsorBadge:** Usa `sponsorConfig?.logoUrl ?? dynamicBrandConfig?.logoUrl` de VioConfiguration. NO usa DemoDataManager. ✅

**VOfferBannerView:** Usa sponsorConfig/dynamicBrandConfig primero; DemoDataManager solo en fallback (failure, empty). ✅

**Requisito:** loadCampaignConfig debe ejecutarse y actualizar VioConfiguration. ViaplayApp ya lo hace. tv2demo NO aplicaba updateDynamicBrandConfig/updateSponsorConfig — **corregir**.

---

## Tarea 3: vio-config.json Viaplay

**Formato requerido:**
```json
{
  "apiKey": "viaplay_api_key_0c611e983b314ff8",
  "campaigns": {
    "restAPIBaseURL": "https://api-dev.vio.live",
    "webSocketBaseURL": "https://api-dev.vio.live",
    "autoDiscover": true
  }
}
```
Solo apiKey. Sin campaignAdminApiKey ni campaignApiKey. ✅ Viaplay ya correcto.

**tv2demo:** Tiene campaigns con restAPIBaseURL, webSocketBaseURL, autoDiscover. Estructura OK.

---

## Tarea 4: Demo legacy Barcelona-PSG

**Viaplay:** matchContentId para Barcelona-PSG = "barcelona-psg-2025-02-12" (no existe en backend). validate() → hasEngagement: false → return early. createMatchFromDetail() devuelve Match.barcelonaPSG para render estático. ✅

**tv2demo:** TV2Match.barcelonaPSG. Flujo estático. ✅

**No tocar:** Código de Barcelona-PSG.
