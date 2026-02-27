# VIO TRUTH — Fuente Absoluta de Verdad
> Última actualización: 2026-02-27
> Mantenido por: Viobot — coordinador técnico entre Replit, Cursor y Angelo

---

## ⚠️ NOMENCLATURA — LEER PRIMERO

| Nombre | Qué es | Estado |
|--------|--------|--------|
| **Vio** | Plataforma de engagement para live events (polls, contests, chat, componentes) | Activo — foco principal |
| **Commerce (ex-Reachu)** | Módulo de ecommerce — overlay de producto, checkout, integración con sistemas de pago. Empresa adquirida, rebranding en curso. GraphQL en `graph-ql-dev.vio.live` | Módulo opcional por campaña |
| **Tipio** | Servicio de livestream. Producto SEPARADO. NO es Reachu/Commerce. | Futuro lejano — no tocar |

### ⚠️ ERROR ACTIVO EN REPLIT
`integrations.tipio` → debe ser `integrations.commerce`. Tipio es livestream, no ecommerce. **Revertir.**

---

## 🎯 VISIÓN DEL PRODUCTO

Vio es la **segunda pantalla oficial para eventos deportivos.**

El usuario ve el partido en la TV. En el móvil tiene el panel de Vio (integrado en la app de Viaplay/TV2) con:
- **Engagement** (CORE): polls, contests, chat en tiempo real — sincronizados con el partido
- **Commerce** (MONETIZACIÓN): banners, productos, carrusel, mini tienda — comprables en el momento de máxima emoción
- **Info**: estadísticas, live scores, highlights, tweets curados por moderador

**El loop de valor:**
```
Engagement engancha → atención sostenida → Commerce convierte
```

El timing es el producto. Una camiseta del Real Madrid en el minuto 90 tras un gol vale más que cualquier banner.

---

## 🚀 PLAN INMEDIATO — DEMO TV2 (MIÉRCOLES)

### Objetivo
SDK muestra engagement overlay desde el backend real + componentes funcionando.

### Loop que debe cerrar antes del lunes
```
Dashboard (Replit) → programar poll/contest → Backend → SDK iOS muestra en tiempo real
```

### Estado actual
- ✅ Legacy funciona: demo Barcelona-PSG con datos estáticos
- ⚠️ Nuevo flujo: SDK llama al backend pero no cierra el loop (bug 401 + migración en curso)
- El `BroadcastContextSetup` y `BackendEngagementTabView` son el puente entre legacy y nuevo

---

## 📋 TAREAS — REPLIT

### URGENTE (antes del lunes)

**1. Fix: `integrations.tipio` → `integrations.commerce`**
Renombraste mal. Tipio es livestream. El ecommerce es Commerce (ex-Reachu).

**2. Verificar endpoint crítico**
```bash
GET https://api-dev.vio.live/v1/campaigns/28/config?apiKey=xxl_api_key_507d4014243d8360
```
Debe devolver:
```json
{
  "brand": { "name": "XXL Sports", "logoUrl": "...", "iconUrl": "..." },
  "features": { "enablePolls": true, "enableContests": true, "enableChat": true },
  "integrations": {
    "commerce": { "enabled": true/false, "apiKey": "KCXF10Y-...", "channelId": "..." }
  }
}
```

**3. Verificar flujo contentId completo**
```bash
GET https://api-dev.vio.live/v1/sdk/broadcast?contentId=real-madrid-barcelona-2025-01-24&country=NO&apiKey=viaplay_api_key_0c611e983b314ff8
```
Debe devolver `hasEngagement: true` + broadcastId + polls activos.

**4. Transacciones DB en votos** — CRÍTICO para producción
Envolver en transacción Drizzle:
- insert poll_vote
- update poll_options.vote_count  
- update polls.total_votes

**5. Dashboard — que se vea avanzado para la demo**
Asegurarse de que crear campaña → crear broadcast → programar polls/contests fluye sin errores.

### BACKLOG
- Revertir `integrations.tipio` → `integrations.commerce`
- Paginación en listados
- Broadcast validator middleware en todos los endpoints engagement

---

## 📋 TAREAS — CURSOR

### URGENTE (antes del lunes)

**1. Fix bug 401 — `ConfigAPIClient.swift`**
```swift
// ANTES (usa Commerce key — da 401)
private var apiKey: String {
    VioConfiguration.shared.apiKey // KCXF10Y-... ← esta es la Commerce key
}

// DESPUÉS (usa Vio App key)
private var apiKey: String {
    VioConfiguration.shared.campaignConfiguration.campaignApiKey.isEmpty
        ? VioConfiguration.shared.apiKey
        : VioConfiguration.shared.campaignConfiguration.campaignApiKey
}
```

**2. Eliminar URL hardcodeada legacy**
`event-streamer-angelo100.replit.app` aparece en `OfferBannerModels` y `EventStreamerManager`.
→ Reemplazar por `VioConfiguration.shared.campaignConfiguration.restAPIBaseURL`

**3. Cerrar el loop de engagement**
Con el fix del 401, el SDK debe:
- Llamar a `/v1/campaigns/:id/config` → recibir features + commerce key
- Conectar WebSocket → `/ws/:campaignId`  
- Recibir `poll_created` / `broadcast_started` → mostrar `BackendEngagementTabView`
- Polls y contests en tiempo real desde el backend

**4. Parsear `integrations.commerce` en `CampaignConfig`**
El modelo `CampaignConfig` no tiene el campo `integrations`.
Añadir y pasar `commerce.apiKey` al módulo Commerce si `enabled: true`.

**5. Verificar que legacy sigue funcionando**
`campaignId = 28` en `liveShow` debe seguir funcionando para la demo estática.

### BLOCKER (Kotlin — puede esperar al miércoles pero no más)
- Migrar namespace `io.reachu.*` → `live.vio.*` (191 archivos)
- Renombrar Maven: `reachu-kotlin-sdk` → `vio-kotlin-sdk`

---

## 🏗️ ARQUITECTURA GLOBAL

```
[Viaplay / TV2 App]
       │
       │  contentId (stream ID del partner)
       ▼
[VioSwiftSDK / VioKotlinSDK]
       │
       ├── GET /v1/sdk/campaigns         → campañas + componentes
       ├── GET /v1/sdk/broadcast         → contentId → broadcastId + engagement
       ├── GET /v1/campaigns/:id/config  → config + Commerce key
       ├── POST /v1/engagement/polls/:id/vote
       └── WSS /ws/:campaignId
       ▼
[Backend Vio — api-dev.vio.live]
       │
       ├── PostgreSQL (Neon) · 19 tablas · Drizzle ORM
       └── Si commerce.enabled = true ──▶ [graph-ql-dev.vio.live] (infraestructura separada)
```

### URLs definitivas
| Servicio | URL |
|----------|-----|
| Backend Vio | `https://api-dev.vio.live` |
| Dashboard admin | `https://api-dev.vio.live` → login: seleccionar "Reachu-admin" |
| Commerce GraphQL | `https://graph-ql-dev.vio.live/graphql` |
| ~~event-streamer-angelo100.replit.app~~ | DEPRECADO → usar api-dev.vio.live |

---

## 🔐 AUTENTICACIÓN

### SDK — Una sola Vio App Key
```json
{
  "apiKey": "<Vio App API Key>",
  "campaigns": {
    "restAPIBaseURL": "https://api-dev.vio.live",
    "webSocketBaseURL": "https://api-dev.vio.live"
  }
}
```

### Keys de demo
| Key | Para qué |
|-----|----------|
| `viaplay_api_key_0c611e983b314ff8` | Demo Viaplay |
| `xxl_api_key_507d4014243d8360` | Demo XXL / campaña 28 |
| `KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S` | Commerce (GraphQL) — viene del servidor |

### Commerce key — nunca en el config del app
El servidor la entrega en `GET /v1/campaigns/:id/config` → `integrations.commerce.apiKey`.

---

## 📊 JERARQUÍA DE DATOS

```
Client App (ej. Viaplay iOS)
  └── Campaigns (una o varias)
       ├── Sponsor → fuente única de branding (logo, colores)
       ├── Components → banners, carrusel, productos, mini tienda
       │    (el desarrollador define locaciones con IDs, Vio asigna contenido)
       └── Broadcasts → partidos / eventos deportivos
            ├── Polls (pre-programados + tiempo real)
            ├── Contests (pre-programados + tiempo real)
            └── Chat (con tweets curados por moderador de Viaplay)
```

---

## 📡 WEBSOCKET — EVENTOS

| Evento | Cuándo | Acción SDK |
|--------|--------|------------|
| `broadcast_started` | Broadcast → live | Activar polls/contests/chat |
| `broadcast_ended` | Broadcast → ended | Ocultar engagement |
| `poll_results_updated` | Voto recibido | Actualizar porcentajes |
| `poll` | Admin/operador dispara | Mostrar poll overlay |
| `contest` | Admin/operador dispara | Mostrar contest overlay |
| `component:activated` | Scheduler | Mostrar componente |
| `component:deactivated` | Scheduler | Ocultar componente |

---

## 🗓️ DEALS COMERCIALES

| Partner | Estado |
|---------|--------|
| **Viaplay** | 4 reuniones. Jefe de producto. Noruega aprobado internamente. Pendiente decisión escandinava. |
| **TV2** | 2ª reunión el miércoles. Fase temprana. |

---

## 🔮 FUTURO (no tocar ahora)

- Usuarios viendo en móvil también pueden interactuar (ahora solo second screen TV)
- Modelos AI que automatizan el rol del operador — detectan momentos clave y lanzan polls/contests
- Tipio (livestream service) — futuro lejano
- KotlinSDK namespace migration → después del miércoles

---

## 🛠️ VARIABLES DE ENTORNO BACKEND

| Variable | Requerida |
|----------|-----------|
| `DATABASE_URL` | ✅ |
| `SESSION_SECRET` | ✅ |
| `SCHEDULER_INTERVAL_MINUTES` | No (default: 1 min) |
| `USE_QUEUE` | No |
| `REDIS_HOST` | No (prod) |

---

_Actualizado: 2026-02-27 · Coordinado por Viobot_
_Próxima revisión: self-optimize 23:00 Oslo_
