# TASKS_NOW — VioSwiftSDK · Última actualización: 2026-03-03

## 📋 Workspace / Setup (verificado)
- **ViaplayWorkspace.xcworkspace**: Incluye Viaplay + tv2demo. Abrir este workspace para ambos demos.
- **Referencias de paquete**: Viaplay y tv2demo usan `../..` + referencia explícita a VioComplete. Vg sin cambios.
- **NO tocar**: TimelineDataGenerator.swift, demo-static-data.json (ambos demos), flujo estático Barcelona-PSG.
- El timeline demo funciona 100% offline desde datos estáticos. WebSocket y BroadcastContextSetup son capas separadas encima.

## 🔴 BUG CRÍTICO — Memory leak loadEngagement (pendiente resolver)
Al entrar a Real Madrid - Barcelona, la RAM sube sin parar. **Causa confirmada:** `EngagementManager.shared.loadEngagement()`.

**Estado:** loadEngagement está **comentado** en BroadcastContextSetup como workaround. Los polls/contests no cargan.

**Próximos pasos:** Profilar con Instruments, revisar BackendEngagementRepository, EngagementCache, DynamicConfigurationManager, o volumen de datos del backend.

## ✅ Completado
- Fix 401 ConfigAPIClient ✅
- Logo sponsor desde backend ✅
- URLs event-streamer eliminadas ✅
- integrations.commerce parseado ✅
- Tipio eliminado completamente ✅

## 🔴 Hacer ahora — el backend está listo, cerrar el loop en UI

### Datos de test confirmados
```
API Key:   viaplay_api_key_0c611e983b314ff8
Campaign:  35 (Viaplay Demo 2025, sponsor Elkjøp)
contentId: real-madrid-barcelona-2025-01-24
País:      NO
Broadcast: real-madrid-vs-barcelona-2026-02-25 (status: live)
Polls:     15 (¿Quién ganará?) · 16 (¿Quién marcará el primer gol?)
WebSocket: wss://api-dev.vio.live/ws/35
```

### 1. Verificar que BroadcastContextSetup cierra el loop
Con los datos de test, el flujo debe:
1. `GET /v1/sdk/campaigns` → campaña 35
2. `GET /v1/campaigns/35/config` → brand Elkjøp (logoUrl real)
3. `BroadcastContextSetup.setup(contentId: "real-madrid-barcelona-2025-01-24", country: "NO")`
4. → broadcastId: `real-madrid-vs-barcelona-2026-02-25`
5. → WebSocket `/ws/35`
6. → `BackendEngagementTabView` muestra polls 15 y 16

### 2. Verificar logo Elkjøp en UI
`CampaignSponsorBadge` debe cargar:
`https://api-dev.vio.live/objects/uploads/adc65620-01ff-4c66-a7e2-de456495b9d1`
NO debe caer al fallback de DemoDataManager.

### 3. Verificar vio-config.json de la demo Viaplay
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
Solo una apiKey. Sin campaignAdminApiKey ni campaignApiKey.

### 4. Confirmar que demo legacy Barcelona-PSG sigue funcionando
La demo estática (campaignId: 28) no debe romperse.

## ⏸ Deferido
- AnalyticsManager.swift:45 trackAutomaticEvents error — después del lunes
