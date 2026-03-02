# VIO TRUTH — Fuente Absoluta de Verdad
> Última actualización: 2026-03-02
> Mantenido por: Viobot

---

## ⚠️ NOMENCLATURA — LEER PRIMERO

| Nombre | Qué es | Estado |
|--------|--------|--------|
| **Vio** | Plataforma de engagement para live events (polls, contests, chat, componentes) | Activo — foco principal |
| **Commerce (ex-Reachu)** | Módulo de ecommerce — overlay de producto, checkout. GraphQL en `graph-ql-dev.vio.live` | Módulo opcional por campaña |
| **Tipio** | NO EXISTE. Nombre eliminado. Cualquier referencia a Tipio es un bug. | ❌ ELIMINAR si aparece |

### Reglas de naming — sin excepciones
- `integrations.commerce` → correcto ✅
- `integrations.tipio` → BUG ❌
- Commerce key → viene del servidor en `integrations.commerce.apiKey` ✅
- Tipio key → NO existe ❌

---

## 🎯 VISIÓN DEL PRODUCTO

Vio es la **segunda pantalla oficial para eventos deportivos.**

El usuario ve el partido en la TV. En el móvil tiene el panel de Vio (integrado en la app de Viaplay/TV2) con:
- **Engagement** (CORE): polls, contests, chat en tiempo real — sincronizados con el partido
- **Commerce** (MONETIZACIÓN): banners, productos, carrusel, mini tienda — comprables en el momento de máxima emoción
- **Info**: estadísticas, live scores, score en tiempo real

**El loop de valor:**
```
Engagement engancha → atención sostenida → Commerce convierte
```

---

## 🪜 PRIORIDAD DE DESARROLLO — PASO A PASO

Avanzamos en este orden. No saltar pasos.

```
1. SDK inicializa correctamente (una apiKey, carga campaña)
2. SDK muestra branding del Sponsor (logo, colores)
3. SDK resuelve contentId → broadcast → hasEngagement
4. WebSocket conecta y recibe eventos en tiempo real
5. Polls y contests se muestran y se puede votar
6. Chat funciona en tab "All" mezclado con engagement
7. Score y stats en tiempo real (BackendMatchDataService)
8. Componentes del dashboard (product_carousel, banner, countdown)
9. Commerce módulo (cuando esté completamente definido)
```

**Hoy: pasos 1-5. No avanzar sin validar cada paso.**

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
       ├── PostgreSQL (Neon) · Drizzle ORM
       └── Si commerce.enabled = true ──▶ [graph-ql-dev.vio.live] (infraestructura separada)
```

### URLs definitivas
| Servicio | URL |
|----------|-----|
| Backend Vio | `https://api-dev.vio.live` |
| Commerce GraphQL | `https://graph-ql-dev.vio.live/graphql` |
| ~~event-streamer-angelo100.replit.app~~ | DEPRECADO → usar api-dev.vio.live |

---

## 🔐 AUTENTICACIÓN — UNA SOLA KEY

```json
// vio-config.json — SOLO ESTO
{
  "apiKey": "<Vio App API Key>",
  "restAPIBaseURL": "https://api-dev.vio.live",
  "webSocketBaseURL": "https://api-dev.vio.live"
}
```

- Una sola `apiKey` para TODOS los endpoints Vio
- La Commerce key la entrega el servidor en `integrations.commerce.apiKey`
- Nunca hardcodear la Commerce key en el config del app

### Keys de demo
| Key | Cliente |
|-----|---------|
| `viaplay_api_key_0c611e983b314ff8` | Viaplay |
| `xxl_api_key_507d4014243d8360` | XXL / campaña 28 |
| `KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S` | Commerce GraphQL (solo viene del servidor) |

---

## 📊 JERARQUÍA DE DATOS

```
Client App (ej. Viaplay iOS)
  └── Campaigns
       ├── Sponsor → ÚNICA fuente de branding (logo, colores)
       ├── Components → banners, carrusel, countdown (locationId)
       └── Broadcasts → partidos / eventos
            ├── Polls (activos + tiempo real)
            ├── Contests (activos + tiempo real)
            ├── Chat (mezclado en tab "All")
            └── Match Data (score, stats — BackendMatchDataService)
```

**Channels:** Ignorar por ahora. Son legacy opcionales. No bloquean nada.

---

## 📡 WEBSOCKET — EVENTOS

| Evento | Cuándo | Acción SDK |
|--------|--------|------------|
| `broadcast_started` | Broadcast → live | Activar polls/contests/chat |
| `broadcast_ended` | Broadcast → ended | Ocultar engagement |
| `poll_results_updated` | Voto recibido | Actualizar porcentajes |
| `poll` | Admin dispara | Mostrar poll overlay |
| `contest` | Admin dispara | Mostrar contest overlay |
| `chat_message` | Usuario envía chat | Añadir al feed "All" |
| `tweet` | Admin dispara | Añadir al feed "All" |
| `score_update` | Admin actualiza score | Actualizar MatchHeaderView |
| `component:activated` | Scheduler | Mostrar componente |
| `component:deactivated` | Scheduler | Ocultar componente |

---

## 🧩 COMPONENTES — PENDIENTE CONSOLIDAR

Los siguientes componentes existen en el backend pero necesitan consolidación de nombre + implementación en el SDK iOS:

| Tipo | Estado backend | Estado SDK |
|------|---------------|------------|
| `banner` | ✅ | ✅ parcial |
| `offer_banner` | ✅ | ✅ parcial |
| `countdown` | ✅ | ❌ pendiente |
| `product_carousel` | ✅ | ❌ pendiente |
| `product_banner` | ✅ | ❌ pendiente |
| `product_store` | ✅ | ❌ pendiente |

**Tarea pendiente:** Consolidar nombres y estructura JSON entre backend y SDK antes de implementar.

---

## 🔄 FLUJO DE INICIALIZACIÓN SDK (orden correcto)

```
1. GET /v1/sdk/campaigns
   → campañas activas + componentes de campaña
   → SDK guarda lista de campañas

2. GET /v1/campaigns/:id/config
   → brand del Sponsor (logo, colores)
   → features (polls, contests, chat)
   → integrations.commerce (enabled, apiKey)
   → SDK aplica branding

3. (al abrir stream)
   GET /v1/sdk/broadcast?contentId=xxx&country=NO
   → hasEngagement true/false
   → si true: broadcastId, polls activos, contests activos

4. WebSocket wss://api-dev.vio.live/ws/:campaignId
   → eventos en tiempo real

5. POST /v1/engagement/polls/:id/vote
   → votar
```

---

## 🔴 ENDPOINTS NUEVOS (score, chat, tweets)

```
GET  /v1/sdk/broadcasts/:id/score     → score en tiempo real
GET  /v1/sdk/broadcasts/:id/stats     → stats del partido
GET  /v1/sdk/livescores               → partidos activos
POST /api/broadcasts/:id/chat         → chat → WS chat_message
POST /api/broadcasts/:id/tweet        → tweet → WS tweet
GET  /health                          → health check
```

---

## ⚠️ BUG CONOCIDO — Memory leak loadEngagement (2026-03-02)

**Síntoma:** Al entrar a Real Madrid - Barcelona, la RAM sube de forma continua hasta tener que cerrar la app.

**Causa confirmada:** `EngagementManager.shared.loadEngagement()` en BroadcastContextSetup.

**Workaround:** loadEngagement está comentado en BroadcastContextSetup.swift. Los polls y contests no se cargan hasta resolver.

**Pendiente:** Profilar con Instruments, revisar BackendEngagementRepository, EngagementCache, DynamicConfigurationManager.

---

## ⛔ REGLAS — NUNCA ROMPER

1. `campaignId: 28` (demo XXL legacy) — sigue funcionando siempre
2. `/v1/sdk/config` — no modificar estructura de respuesta
3. `integrations.commerce` — nunca renombrar a tipio
4. Branding siempre desde `CampaignConfig.brand` (sponsor) — nunca hardcodear
5. `VioLogger` en Swift — nunca `print()`
6. URLs siempre desde config — nunca hardcodear `api-dev.vio.live`

---

## 🗓️ DEALS COMERCIALES

| Partner | Estado |
|---------|--------|
| **Viaplay** | 4 reuniones. Noruega aprobado internamente. Pendiente decisión escandinava. |
| **TV2** | 2ª reunión próxima. Fase temprana. |

---

_Actualizado: 2026-03-02 · Viobot_
