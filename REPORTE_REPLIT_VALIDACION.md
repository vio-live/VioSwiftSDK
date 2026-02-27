# Reporte de validación – Vio SDK + Backend (Replit)

**Fecha:** 23 de enero de 2025  
**Contexto:** App demo Viaplay con **VioSwiftSDK** (Demo en `Demo/Viaplay`)

**URL del backend Vio:** `https://api-dev.vio.live`  
**Backend propio (event-streamer en Replit):** `https://event-streamer-angelo100.replit.app` (active-components, WebSocket de componentes)

---

## 1. Resumen de logs observados

| Log | Severidad | Componente |
|-----|-----------|------------|
| `Failed to load campaign config from backend: HTTP error 401 from configuration API` | ⚠️ Warning | DynamicConfigManager |
| `Cache configuration hash mismatch - campaignId or API keys changed` | ℹ️ Info | CacheManager |
| `Image cache cleared due to configuration change` | ℹ️ Info | CacheHelper |
| `Cache cleared` | ℹ️ Info | CacheManager |
| `Campaign ended: 28` | ⚠️ Warning | CampaignManager |
| `Failed to remove cached logo file: ... No such file or directory` | ⚠️ Warning | ImageLoader |

---

## 2. Problema principal: HTTP 401 en configuración de campaña

### Request que falla

- **Endpoint:** `GET {restAPIBaseURL}/v1/campaigns/{campaignId}/config`
- **URL completa (ejemplo):**  
  `https://api-dev.vio.live/v1/campaigns/28/config?apiKey={apiKey}`
- **Método:** GET
- **Headers:** `Content-Type: application/json`

### API key usada por el SDK

El `ConfigAPIClient` usa **`apiKey`** (SDK key principal):

```swift
// ConfigAPIClient.swift
private var apiKey: String {
    VioConfiguration.shared.apiKey
}
// URL: .../v1/campaigns/28/config?apiKey=\(apiKey)
```

**Valor en config:** `KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S`

### Otras keys en la config

| Key | Valor | Uso en SDK |
|-----|-------|------------|
| `apiKey` | `KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S` | ConfigAPIClient, SdkClient, etc. |
| `campaignAdminApiKey` | `xxl_api_key_507d4014243d8360` | CampaignManager (`/v1/sdk/config`, broadcast, etc.) |
| `campaignApiKey` | `viaplay_api_key_0c611e983b314ff8` | Flujo contentId / broadcast (Viaplay) |

### Preguntas para Replit

1. **¿Qué API key debe usarse para `GET /v1/campaigns/{campaignId}/config`?**
   - ¿`apiKey` (SDK key)?
   - ¿`campaignAdminApiKey`?
   - ¿Otra key específica?

2. **¿El endpoint `/v1/campaigns/{campaignId}/config` está activo en `api-dev.vio.live`?**
   - ¿Requiere autenticación distinta (header, otro parámetro)?

3. **¿La campaña 28 existe y está configurada correctamente en el backend?**

---

## 3. Flujo de configuración dinámica

```
DynamicConfigurationManager.loadCampaignConfig(campaignId: 28)
    → ConfigAPIClient.fetchCampaignConfig(campaignId: 28)
    → GET https://api-dev.vio.live/v1/campaigns/28/config?apiKey=KCXF10Y-...
    → 401 Unauthorized
```

Cuando falla, el SDK hace fallback a la configuración local (no bloquea la app).

---

## 4. Otros logs (no críticos)

### Cache cleared

- **Causa:** Hash de configuración cambió (campaña o keys).
- **Comportamiento:** Esperado; se limpia caché y se vuelve a cargar.

### Campaign ended: 28

- **Causa:** WebSocket recibe evento `campaign_ended` para campaña 28.
- **Comportamiento:** Esperado; el SDK limpia estado de esa campaña.

### ImageLoader "couldn't be removed"

- **Causa:** Se intenta borrar un logo en caché que ya no existe (p. ej. tras un `clearCache` completo).
- **Estado:** Corregido en el SDK; ya no se loguea como warning cuando el archivo no existe.

---

## 5. Config de referencia (vio-config.json)

```json
{
  "apiKey": "KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S",
  "campaigns": {
    "webSocketBaseURL": "https://api-dev.vio.live",
    "restAPIBaseURL": "https://api-dev.vio.live",
    "campaignAdminApiKey": "xxl_api_key_507d4014243d8360",
    "campaignApiKey": "viaplay_api_key_0c611e983b314ff8"
  },
  "liveShow": {
    "campaignId": 28
  }
}
```

---

## 6. Todas las URLs usadas en VioSwiftSDK

### URLs desde configuración (vio-config.json)

| Origen | URL | Uso |
|--------|-----|-----|
| `campaigns.restAPIBaseURL` | `https://api-dev.vio.live` | REST API campañas |
| `campaigns.webSocketBaseURL` | `https://api-dev.vio.live` | WebSocket campañas |
| `liveShow.tipio.baseUrl` | `https://stg-dev-microservices.tipioapp.com` | Tipio (productos) |
| `analytics.apiHost` | `https://api-eu.mixpanel.com` | Mixpanel |
| `marketFallback.flag` | `https://flagcdn.com/w320/no.png` | Bandera país |

### URLs hardcodeadas en código (VioEnvironment)

| Origen | URL | Uso |
|--------|-----|-----|
| `VioEnvironment.baseURL` | `https://graph-ql-dev.vio.live` | GraphQL (productos, canal, etc.) |
| `VioEnvironment.graphQLURL` | `https://graph-ql-dev.vio.live/graphql` | SdkClient, VCastingActiveView, VCastingVideoPlayer |

### URLs hardcodeadas (event-streamer / Replit)

| Origen | URL | Uso |
|--------|-----|-----|
| `OfferBannerModels.ComponentManager` | `https://event-streamer-angelo100.replit.app` | Active components REST + WebSocket |
| `EventStreamerManager` | `wss://event-streamer-angelo100.replit.app/ws/3` | Demo event stream (polls, products, contests) |

### Endpoints REST (base = restAPIBaseURL)

| Método | Path | Componente |
|--------|------|------------|
| GET | `/v1/campaigns/{id}/config` | ConfigAPIClient |
| GET | `/v1/engagement/config` | ConfigAPIClient |
| GET | `/v1/localization/{lang}` | ConfigAPIClient |
| GET | `/v1/sdk/config` | CampaignManager |
| GET | `/v1/sdk/campaigns` | CampaignManager |
| GET | `/v1/sdk/broadcast` | BroadcastValidationService |
| GET | `/v1/offers` | CampaignManager |
| GET | `/v1/engagement/polls` | BackendEngagementRepository |
| GET | `/v1/engagement/contests` | BackendEngagementRepository |
| POST | `/v1/engagement/polls/{id}/vote` | BackendEngagementRepository |
| POST | `/v1/engagement/contests/{id}/participate` | BackendEngagementRepository |

### Endpoints event-streamer (base = event-streamer-angelo100.replit.app)

| Método | Path | Componente |
|--------|------|------------|
| GET | `/api/campaigns/{id}/active-components` | ComponentManager (OfferBannerModels) |
| WebSocket | `/ws/{campaignId}` | ComponentManager, EventStreamerManager |

### WebSocket campañas (base = webSocketBaseURL)

| Path | Componente |
|------|------------|
| `wss://{webSocketBaseURL}/ws/{campaignId}` | CampaignWebSocketManager |

---

## 7. Acciones sugeridas para Replit

1. Confirmar qué key usa el backend para `/v1/campaigns/{id}/config`.
2. Verificar que la campaña 28 exista y esté activa.
3. Probar el endpoint manualmente, por ejemplo:
   ```bash
   curl -v "https://api-dev.vio.live/v1/campaigns/28/config?apiKey=KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S"
   ```
4. Si el endpoint requiere `campaignAdminApiKey`, indicarlo para ajustar el SDK.

---

## 8. Posible ajuste en el SDK

Si el backend exige `campaignAdminApiKey` para `/v1/campaigns/{id}/config`, el `ConfigAPIClient` podría cambiarse para usar esa key en lugar de `apiKey`. Pendiente de confirmación de Replit.
