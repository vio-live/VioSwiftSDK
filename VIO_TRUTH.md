# VIO TRUTH — Fuente Absoluta de Verdad
> Este documento es la referencia definitiva para Replit (backend) y Cursor (SDKs).
> Última actualización: 2026-02-27
> Mantenido por: Viobot

---

## 1. ARQUITECTURA GLOBAL

```
[Viaplay / TV2 App]
       │
       │  contentId (stream ID del partner)
       ▼
[VioSwiftSDK / VioKotlinSDK]
       │
       │  GET /v1/sdk/broadcast?contentId=&country=
       │  GET /v1/sdk/campaigns?apiKey=
       │  GET /v1/campaigns/:id/config?apiKey=
       │  POST /v1/engagement/polls/:id/vote
       │  WSS /ws/:campaignId
       ▼
[Backend — api-dev.vio.live]
(socket-server en Replit / tipiodevelopment/socket-server)
       │
       ▼
[PostgreSQL — Neon Serverless]
19 tablas · ORM: Drizzle
```

**Stack backend:** Node.js + TypeScript + Express + Drizzle + WebSocket
**Stack frontend dashboard:** React 18 + Vite + Tailwind + shadcn/ui + TanStack Query
**Stack iOS SDK:** Swift, SPM, modular (VioCore, VioCastingUI, VioEngagementSystem, VioDesignSystem)
**Stack Android SDK:** Kotlin (BLOCKER: namespace aún en io.reachu.*)

---

## 2. AUTENTICACIÓN — MODELO DEFINITIVO

### SDK (cliente móvil)
Una sola key: **Vio App API Key** (`client_apps.api_key` en DB).

```json
// vio-config.json — CORRECTO (Feb 2026)
{
  "apiKey": "viaplay_api_key_0c611e983b314ff8",
  "environment": "development",
  "campaigns": {
    "restAPIBaseURL": "https://api-dev.vio.live",
    "webSocketBaseURL": "https://api-dev.vio.live"
  }
}
```

- `apiKey` → se usa en TODOS los endpoints SDK (`?apiKey=` o `X-Api-Key:`)
- NO hay `campaignAdminApiKey` ni `campaignApiKey` separados en el config
- La **Commerce key** NO va en el config — el backend la entrega en `/v1/campaigns/:id/config` bajo `integrations.commerce.apiKey`

### Admin Dashboard
JWT Bearer Token → `POST /api/auth/token` con `{ reachuUserId }` → token de 7 días.

### Keys actuales de demo
- Viaplay API Key: `viaplay_api_key_0c611e983b314ff8`
- XXL API Key: `xxl_api_key_507d4014243d8360`
- Commerce Key (Reachu): `KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S` ← entregada dinámicamente por el backend

---

## 3. FLUJO SDK COMPLETO (CONTENTID — VIAPLAY)

```
App abre stream con contentId = "real-madrid-barcelona-2025-01-24"

PASO 1: Validar si hay engagement
GET /v1/sdk/broadcast?contentId=real-madrid-barcelona-2025-01-24&country=NO&apiKey=viaplay_api_key_...

  → hasEngagement: false → SDK no hace nada más
  → hasEngagement: true → SDK recibe broadcastId, campaignId, polls, contests activos

PASO 2: Cargar config de campaña
GET /v1/campaigns/{campaignId}/config?apiKey=viaplay_api_key_...

  → brand (desde Sponsor, NO desde campaign.brand_*)
  → features (enablePolls, enableContests, enableChat)
  → integrations.commerce.apiKey (si está configurado)

PASO 3: Conectar WebSocket
WSS /ws/{campaignId}

  → Recibe: poll_created, broadcast_started, broadcast_ended, poll_results_updated

PASO 4: Engagement en tiempo real
POST /v1/engagement/polls/{id}/vote
POST /v1/engagement/contests/{id}/participate
```

**Clase que orquesta esto en Swift:** `BroadcastContextSetup.setup()` — llamada desde `.task` en vistas.

---

## 4. JERARQUÍA DE DATOS

```
Users
  └── Client Apps (api_key único por app)
       └── Campaigns (client_app_id FK directo)
            ├── Sponsor (fuente de branding — logoUrl, avatarUrl, colors)
            ├── Channel (opcional — solo agrupación/legado)
            ├── Broadcasts
            │    ├── external_id ← mapea contentId del partner
            │    ├── Polls (con video scheduling)
            │    └── Contests (con video scheduling)
            └── Components (banners, carruseles, etc.)
```

**CRÍTICO:** El branding viene EXCLUSIVAMENTE del Sponsor vinculado. Los campos `campaign.brand_name`, `campaign.brand_icon_url`, `campaign.brand_logo_url` son LEGACY — solo fallback.

---

## 5. ENDPOINTS SDK — REFERENCIA RÁPIDA

| Método | Endpoint | Auth | Uso |
|--------|----------|------|-----|
| GET | `/v1/sdk/campaigns` | apiKey | Discovery de campañas activas |
| GET | `/v1/sdk/broadcast` | apiKey | Validar contentId → broadcastId |
| GET | `/v1/campaigns/:id/config` | apiKey | Config completa + Commerce key |
| GET | `/v1/engagement/polls` | apiKey | Polls activos por broadcastId |
| GET | `/v1/engagement/contests` | apiKey | Contests activos por broadcastId |
| POST | `/v1/engagement/polls/:id/vote` | apiKey | Votar (rate limit: 30/min) |
| POST | `/v1/engagement/contests/:id/participate` | apiKey | Participar (rate limit: 10/min) |
| GET | `/v1/localization/:lang` | apiKey | Traducciones SDK |
| WSS | `/ws/:campaignId` | — | Eventos en tiempo real |

**Base URL:** `https://api-dev.vio.live`

---

## 6. WEBSOCKET — EVENTOS

| Evento | Cuándo | Acción SDK |
|--------|--------|------------|
| `broadcast_started` | Broadcast → live | Activar polls/contests/chat |
| `broadcast_ended` | Broadcast → ended | Ocultar engagement; banners siguen |
| `poll_results_updated` | Voto recibido | Actualizar porcentajes en UI |
| `poll` | Admin dispara manual | Mostrar poll overlay |
| `contest` | Admin dispara manual | Mostrar contest overlay |
| `component:activated` | Scheduler activa componente | Mostrar componente |
| `component:deactivated` | Scheduler desactiva | Ocultar componente |
| `campaign_ended` | Campaña termina | Ocultar todo |

---

## 7. SWIFT SDK — ESTRUCTURA DE MÓDULOS

```
VioSwiftSDK/
├── Sources/
│   ├── VioCore/                    ← Núcleo: config, networking, managers
│   │   ├── Configuration/
│   │   │   ├── VioConfiguration.swift
│   │   │   ├── ConfigurationLoader.swift   ← Lee vio-config.json
│   │   │   └── ModuleConfigurations.swift
│   │   ├── Managers/
│   │   │   └── CampaignManager.swift       ← Gestión campañas + WebSocket
│   │   ├── Network/
│   │   │   └── ConfigAPIClient.swift       ← GET /v1/campaigns/:id/config
│   │   └── Models/
│   │       └── CampaignModels.swift
│   ├── VioEngagementSystem/        ← Polls, Contests, Engagement
│   │   └── Services/
│   │       └── BroadcastContextSetup.swift ← Orquestador contentId flow ✅ NUEVO
│   ├── VioCastingUI/               ← UI components
│   │   ├── Components/
│   │   │   ├── Engagement/
│   │   │   │   └── BackendEngagementTabView.swift ✅ NUEVO
│   │   │   ├── Video/
│   │   │   │   └── VCastingVideoPlayer.swift
│   │   │   └── Match/
│   │   │       └── MatchContentView.swift
│   │   └── Views/
│   │       └── LiveMatchView.swift
│   └── VioDesignSystem/            ← Tokens de diseño, helpers
└── Demo/
    └── Viaplay/                    ← App demo para Viaplay
        └── Configuration/
            └── vio-config.json     ← Config de referencia
```

---

## 8. ESTADO ACTUAL DEL SWIFT SDK (2026-02-27)

### ✅ Implementado y funcionando
- `BroadcastContextSetup` — orquestador contentId flow (NUEVO)
- `BackendEngagementTabView` — UI de polls/contests desde backend (NUEVO)
- `BroadcastValidationService` — GET /v1/sdk/broadcast
- `CampaignManager` — auto-discovery + WebSocket
- Rebrand completo — 0 referencias Reachu en Sources
- Video player simplificado

### ⚠️ TODOs pendientes (no bloqueantes para Viaplay)
- `UnifiedTimelineManager` — backend no definido aún
- `ShareHighlightModal` — descarga de highlights no implementada
- `LiveShowManager` — product highlighting es stub
- `TipioApiClient` — configuración de Tipio sin definir

### 🔴 Problema activo (ver REPORTE_REPLIT_VALIDACION.md)
- `GET /v1/campaigns/28/config?apiKey=KCXF10Y-...` → 401
- La Commerce key (`KCXF10Y-...`) NO es la App API Key — estaba siendo usada incorrectamente
- Config correcta: `apiKey` = `viaplay_api_key_0c611e983b314ff8` para TODO
- La Commerce key la entrega el backend dinámicamente — NO va en vio-config.json

---

## 9. BACKEND — ESTADO ACTUAL (2026-02-27)

### ✅ Producción-ready
- contentId → broadcastId resolution (`GET /v1/sdk/broadcast`)
- Rate limiting (30/min votos, 10/min contests)
- Video scheduling automático (polls/contests se activan/desactivan solos)
- Queue adapter pattern (SimpleQueue ahora, BullMQ con Redis para prod)
- WebSocket events automáticos en cambios de broadcast status

### 🔴 Pendientes críticos
1. **Transacciones DB** — votos pueden quedar inconsistentes si falla mid-write
2. **Paginación** — endpoints de listado sin paginación
3. **Validación broadcastId** — middleware existe pero no aplicado en todos los endpoints

### Últimos commits relevantes
- `c367da2` — Documentación SDK integration y commerce flow actualizada
- `7a8f246` — API key handling para commerce corregido
- `96cf89f` — Plan contentId para Replit añadido

---

## 10. INSTRUCCIONES PARA REPLIT

### Qué gestiona Replit
- Backend completo: `tipiodevelopment/socket-server`
- Dashboard admin: React en `client/`
- DB: PostgreSQL (Neon) via Drizzle ORM
- URL producción: `https://api-dev.vio.live`

### Reglas para Replit
1. **NUNCA** cambiar la estructura de autenticación sin actualizar este documento
2. El campo `external_id` en `broadcasts` = contentId del partner → no renombrar
3. `integrations.commerce` en la response de `/v1/campaigns/:id/config` es OBLIGATORIO (aunque `enabled: false`)
4. Los WebSocket events `broadcast_started` / `broadcast_ended` se emiten automáticamente en PUT de broadcast — no crear endpoint separado
5. Rate limiting activo en votos y contests — no desactivar

### Pendientes Replit (priorizados)
```
CRÍTICO:
  □ Wrappear vote + contest participation en transacciones DB

IMPORTANTE:
  □ Aplicar broadcast validator middleware a todos los endpoints de engagement
  □ Confirmar que Commerce key se entrega correctamente en /v1/campaigns/:id/config

BACKLOG:
  □ Paginación en listados
  □ Activar BullMQ + Redis para producción
  □ Integrar SchedulingForm UI en broadcast-detail.tsx
```

---

## 11. INSTRUCCIONES PARA CURSOR

### Qué gestiona Cursor
- `VioSwiftSDK` — iOS SDK (Swift, SPM)
- `VioKotlinSDK` — Android SDK (Kotlin) ← BLOCKER namespace

### Reglas para Cursor
1. **NUNCA** hardcodear keys en el SDK — toda key viene de `vio-config.json` o del backend
2. El flujo contentId es la prioridad — `BroadcastContextSetup` es el orquestador
3. Branding siempre desde `CampaignConfig.brand` (que viene del Sponsor en backend) — nunca hardcodear colores
4. Si `integrations.commerce.enabled = false` → no inicializar módulo Commerce
5. El namespace de Kotlin SDK DEBE migrarse: `io.reachu.*` → `live.vio.*` antes de cualquier demo

### Pendientes Cursor (priorizados)
```
BLOCKER (Kotlin):
  □ Migrar namespace io.reachu → live.vio en 191 archivos
  □ Renombrar artefacto Maven: reachu-kotlin-sdk → vio-kotlin-sdk

SWIFT — IMPORTANTE:
  □ Fix 401 en /v1/campaigns/:id/config:
      ConfigAPIClient debe usar VioConfiguration.shared.apiKey (no Commerce key)
  □ Completar BackendEngagementTabView: polling fallback si no hay WS
  □ UnifiedTimelineManager: esperar definición de backend

SWIFT — BACKLOG:
  □ ShareHighlightModal: implementar descarga
  □ LiveShowManager: product highlighting
```

---

## 12. DEMO VIAPLAY — DATOS EXACTOS

| Campo | Valor |
|-------|-------|
| API Key | `viaplay_api_key_0c611e983b314ff8` |
| contentId demo | `real-madrid-barcelona-2025-01-24` |
| País | `NO` (Noruega) |
| Backend | `https://api-dev.vio.live` |
| Validación | `GET /v1/sdk/broadcast?contentId=&country=NO` |
| Campaign ID activo | 28 (verificar en dashboard) |

---

## 13. VARIABLES DE ENTORNO BACKEND

| Variable | Requerida | Descripción |
|----------|-----------|-------------|
| `DATABASE_URL` | ✅ | PostgreSQL (Neon) |
| `SESSION_SECRET` | ✅ | JWT signing secret |
| `SCHEDULER_INTERVAL_MINUTES` | No | Default: 1 min |
| `USE_QUEUE` | No | Activar queue processing |
| `REDIS_HOST` | No (prod) | Activa Redis rate limiter + BullMQ |

---

_Próxima revisión automática: self-optimize nocturno (23:00 Oslo)_
_Actualizado por: Viobot — basado en análisis de socket-server@c367da2 + VioSwiftSDK@31979a0_
