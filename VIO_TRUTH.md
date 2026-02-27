# VIO TRUTH — Fuente Absoluta de Verdad
> Este documento es la referencia definitiva para Replit (backend) y Cursor (SDKs).
> Última actualización: 2026-02-27
> Mantenido por: Viobot

---

## ⚠️ NOMENCLATURA — LEER PRIMERO

| Nombre | Qué es | Estado |
|--------|--------|--------|
| **Vio** | Plataforma de engagement para live events (polls, contests, chat, componentes) | Activo — foco principal |
| **Reachu** | Empresa de ecommerce dentro de apps adquirida. GraphQL propio en `graph-ql-dev.vio.live`. SDK de productos. | Adquirida → rebranding pendiente bajo Vio |
| **Tipio** | Servicio de livestream. Producto SEPARADO. NO es Reachu. | No es el foco ahora — futuro lejano |
| **Commerce / Vio Commerce** | Nombre correcto para el módulo Reachu dentro de Vio | Usar este nombre en código nuevo |

### ⚠️ ERROR ACTIVO EN REPLIT (2026-02-27)
Replit renombró `integrations.commerce` → `integrations.tipio` en el backend. **Esto es incorrecto.** Tipio es livestream, no ecommerce. El campo debe llamarse `integrations.commerce` (o `integrations.reachu` como fallback). **Replit debe revertir este rename.**

---

## 1. ARQUITECTURA GLOBAL

```
[Viaplay / TV2 App]
       │
       │  contentId (stream ID del partner)
       ▼
[VioSwiftSDK / VioKotlinSDK]
       │
       ├── GET /v1/sdk/campaigns         → campañas activas + componentes
       ├── GET /v1/sdk/broadcast         → contentId → broadcastId
       ├── GET /v1/campaigns/:id/config  → config + Commerce key
       ├── POST /v1/engagement/polls/:id/vote
       └── WSS /ws/:campaignId
       ▼
[Backend Vio — api-dev.vio.live]
(socket-server / tipiodevelopment/socket-server)
       │
       ▼
[PostgreSQL — Neon Serverless · 19 tablas · Drizzle ORM]

       +── Si integrations.commerce.enabled = true ──▶
       [Reachu/Commerce GraphQL — graph-ql-dev.vio.live]
       (infraestructura completamente separada)
```

### URLs definitivas
| Servicio | URL | Notas |
|----------|-----|-------|
| Backend Vio | `https://api-dev.vio.live` | Único backend Vio |
| Commerce GraphQL | `https://graph-ql-dev.vio.live/graphql` | Infraestructura separada (Reachu) |
| ~~event-streamer-angelo100.replit.app~~ | DEPRECADO | Era el dominio anterior, ahora es api-dev.vio.live |

**El SDK NO debe tener `event-streamer-angelo100.replit.app` hardcodeado en ningún sitio — reemplazar por `api-dev.vio.live`.**

---

## 2. JERARQUÍA DE DATOS

```
Client App (una app móvil — ej. Viaplay iOS)
  └── Campaigns (una o varias por app)
       ├── Sponsor (branding: logo, colores — fuente única de verdad visual)
       ├── Components (carrusel de productos, banners, etc.) — nivel campaña
       └── Broadcasts (partidos, eventos deportivos, cualquier live event)
            ├── Polls
            ├── Contests
            └── Chat
```

**Flujo contentId (NUEVO — prioridad):**
```
App abre stream → contentId (ID interno del partner, ej. Viaplay)
  → GET /v1/sdk/broadcast?contentId=&country=
  → hasEngagement: true → broadcastId → cargar polls/contests/WebSocket
```

**Flujo legacy (mantener funcionando, no romper):**
```
campaignId fijo en vio-config.json → liveShow.campaignId
  → GET /v1/sdk/campaigns → GET /v1/campaigns/:id/config
```

---

## 3. AUTENTICACIÓN — MODELO DEFINITIVO

### Una sola Vio App API Key para todo lo de Vio

```json
// vio-config.json — CORRECTO
{
  "apiKey": "<Vio App API Key>",
  "environment": "development",
  "campaigns": {
    "restAPIBaseURL": "https://api-dev.vio.live",
    "webSocketBaseURL": "https://api-dev.vio.live"
  }
}
```

**No hay `campaignAdminApiKey` ni `campaignApiKey` separados. Una sola key.**

### Commerce key (Reachu) — viene del servidor, nunca del config

```
GET /v1/campaigns/:id/config?apiKey=<Vio App Key>

Response:
{
  "integrations": {
    "commerce": {              ← nombre correcto (NO "tipio")
      "enabled": true,
      "apiKey": "KCXF10Y-...", ← key de Reachu/Commerce (GraphQL)
      "channelId": "ch-xxx"
    }
  }
}
```

Si `enabled: true` → SDK inicializa módulo Commerce con esa key para llamadas a `graph-ql-dev.vio.live`.
Si `enabled: false` → no inicializar Commerce. Es **opcional por campaña**.

### Keys de demo actuales
| Key | Para qué | Valor |
|-----|----------|-------|
| Vio App Key (Viaplay) | Todos los endpoints Vio | `viaplay_api_key_0c611e983b314ff8` |
| Vio App Key (XXL) | Todos los endpoints Vio | `xxl_api_key_507d4014243d8360` |
| Commerce/Reachu Key | GraphQL de productos | `KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S` (viene del servidor) |

---

## 4. ENDPOINTS SDK — REFERENCIA

| Método | Endpoint | Auth | Uso |
|--------|----------|------|-----|
| GET | `/v1/sdk/campaigns` | apiKey | Discovery campañas + componentes nivel campaña |
| GET | `/v1/sdk/broadcast` | apiKey | Validar contentId → broadcastId |
| GET | `/v1/campaigns/:id/config` | apiKey | Config completa + Commerce key |
| GET | `/v1/engagement/polls` | apiKey | Polls activos por broadcastId |
| GET | `/v1/engagement/contests` | apiKey | Contests activos |
| POST | `/v1/engagement/polls/:id/vote` | apiKey | Votar (rate limit: 30/min) |
| POST | `/v1/engagement/contests/:id/participate` | apiKey | Participar (rate limit: 10/min) |
| GET | `/v1/localization/:lang` | apiKey | Traducciones SDK |
| WSS | `/ws/:campaignId` | — | Eventos tiempo real |

**Base URL:** `https://api-dev.vio.live`

---

## 5. WEBSOCKET — EVENTOS

| Evento | Cuándo | Acción SDK |
|--------|--------|------------|
| `broadcast_started` | Broadcast → live | Activar polls/contests/chat |
| `broadcast_ended` | Broadcast → ended | Ocultar engagement; banners siguen |
| `poll_results_updated` | Voto recibido | Actualizar porcentajes |
| `poll` | Admin dispara manual | Mostrar poll overlay |
| `contest` | Admin dispara manual | Mostrar contest overlay |
| `component:activated` | Scheduler | Mostrar componente |
| `component:deactivated` | Scheduler | Ocultar componente |
| `campaign_ended` | Campaña termina | Ocultar todo |

---

## 6. SWIFT SDK — ESTADO (commit 31979a0)

### ✅ Funcionando
- `BroadcastContextSetup` — orquestador contentId flow
- `BackendEngagementTabView` — UI polls/contests desde backend
- `BroadcastValidationService` — GET /v1/sdk/broadcast
- Rebrand completo (0 referencias Reachu en Sources)

### 🔴 Bugs activos
1. **`event-streamer-angelo100.replit.app` hardcodeado** en `OfferBannerModels` y `EventStreamerManager` → reemplazar por `api-dev.vio.live`
2. **`graph-ql-dev.vio.live` hardcodeado** en `SdkClient` y `VCastingVideoPlayer` → debe venir de config o de la Commerce key response

### 🟡 Pendientes
- Parsear `integrations.commerce` en `CampaignConfig` y pasarla al módulo Commerce
- `liveShow.campaignId = 28` era demo hardcodeada — flujo nuevo es contentId, pero legacy debe seguir
- `UnifiedTimelineManager` — esperar definición backend
- `ShareHighlightModal` — descarga pendiente

---

## 7. KOTLIN SDK — BLOCKER

**No hacer ningún demo hasta resolver:**
- 191 archivos con namespace `io.reachu.*` → `live.vio.*`
- Maven: `reachu-kotlin-sdk` → `vio-kotlin-sdk`

---

## 8. INSTRUCCIONES PARA REPLIT

### Pendientes priorizados

```
🔴 URGENTE — Revertir rename incorrecto:
  □ integrations.tipio → integrations.commerce
    (Tipio es livestream, NO ecommerce. El ecommerce es Reachu/Commerce.)

🔴 CRÍTICO:
  □ Transacciones DB en votos y contest participations

🟡 IMPORTANTE:
  □ Confirmar que event-streamer-angelo100.replit.app no aparece en ningún endpoint
  □ Broadcast validator middleware en todos los endpoints de engagement
  □ Paginación en listados

📌 REGLAS:
  - external_id en broadcasts = contentId del partner. No renombrar.
  - WebSocket events broadcast_started/ended se emiten en PUT. No crear endpoint separado.
  - integrations.commerce SIEMPRE presente en config response (enabled: false si no configurado).
  - Legacy (campaignId fijo, /v1/sdk/config) debe seguir funcionando.
```

---

## 9. INSTRUCCIONES PARA CURSOR

### Pendientes priorizados

```
🔴 BLOCKER (Kotlin):
  □ Migrar namespace io.reachu → live.vio (191 archivos)
  □ Maven: reachu-kotlin-sdk → vio-kotlin-sdk

🔴 SWIFT — Urgente:
  □ Eliminar event-streamer-angelo100.replit.app hardcodeado
    → reemplazar por VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
  □ Parsear integrations.commerce en CampaignConfig
    → pasar apiKey al módulo Commerce (Reachu GraphQL)

🟡 SWIFT — Importante:
  □ graph-ql-dev.vio.live debe venir de config, no hardcodeado
  □ ContentId flow es prioridad — BroadcastContextSetup es el orquestador
  □ Legacy (campaignId fijo) debe seguir funcionando

📌 REGLAS:
  - Una sola apiKey en vio-config.json para todo lo de Vio
  - Commerce key viene del servidor → integrations.commerce.apiKey
  - Si integrations.commerce.enabled = false → no inicializar módulo Commerce
  - Branding siempre desde CampaignConfig.brand (del Sponsor)
  - Logging: VioLogger siempre, nunca print()
```

---

## 10. DEMO VIAPLAY — DATOS

| Campo | Valor |
|-------|-------|
| Vio App API Key | `viaplay_api_key_0c611e983b314ff8` |
| contentId demo | `real-madrid-barcelona-2025-01-24` |
| País | `NO` |
| Backend | `https://api-dev.vio.live` |
| campaignId legacy | 28 (XXL — mantener para no romper demo) |

---

## 11. VARIABLES DE ENTORNO BACKEND

| Variable | Requerida | Descripción |
|----------|-----------|-------------|
| `DATABASE_URL` | ✅ | PostgreSQL Neon |
| `SESSION_SECRET` | ✅ | JWT signing |
| `SCHEDULER_INTERVAL_MINUTES` | No | Default: 1 min |
| `USE_QUEUE` | No | Queue processing |
| `REDIS_HOST` | No (prod) | Redis rate limiter + BullMQ |

---

_Actualizado: 2026-02-27 · socket-server@aa00c6a · VioSwiftSDK@251ebd4_
_Mantenido por Viobot — próxima revisión automática: 23:00 Oslo_
