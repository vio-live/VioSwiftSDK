# SPRINT ACTIVO — Vio.live
> Documento único de coordinación. Cursor lee esto PRIMERO.
> Actualizado por Viobot. NO editar manualmente.

---

## 🎯 Objetivo esta semana
Demo funcional para TV2 el **miércoles 4 marzo**.
Loop completo: Admin crea poll → SDK lo muestra en tiempo real → usuario vota → resultado en dashboard.

---

## 📍 Estado por capa

| Capa | Estado | Responsable |
|------|--------|-------------|
| Backend (socket-server) | ✅ Endpoints listos | Replit |
| Swift SDK — modelos | ✅ BroadcastTeam, homeTeam/awayTeam | Viobot |
| Swift SDK — BackendMatchDataService | ✅ Score/stats/polling | Viobot |
| Swift SDK — launch init (discoverCampaigns) | ✅ Añadido en ViaplayApp.swift | Viobot |
| Swift SDK — vistas conectadas | ❌ Pendiente validación paso a paso | **Cursor** |
| Kotlin SDK — namespace migrado | ❌ BLOCKER | Alan |

## 🧠 Decisiones de arquitectura (2026-02-28)

### Flujo correcto del SDK (definitivo)

```
App launch (ViaplayApp.init)
  └── CampaignManager.shared.discoverCampaigns()
       ├── GET /v1/sdk/campaigns → campaña activa + componentes
       ├── GET /v1/campaigns/:id/config → branding Sponsor + Commerce key
       └── WebSocket /ws/:campaignId → componentes activos/inactivos

Usuario abre stream (SportDetailView)
  └── VioSessionContext.forContentId("real-madrid-barcelona-2025-01-24", country: "NO")
       └── BroadcastContextSetup.setup()
            ├── GET /v1/sdk/broadcast?contentId=xxx → hasEngagement?
            ├── false → usuario no se entera, pasa de largo
            └── true → mostrar botón casting
                 └── usuario abre overlay
                      └── WebSocket ya conectado → polls/contests/chat/score en tiempo real
```

### Reglas
- `discoverCampaigns()` → al launch, sin broadcastId (descubre todas las campañas activas)
- `setBroadcastContext()` → cuando usuario abre un stream específico
- WebSocket → mismo canal `/ws/:campaignId`, conectado desde el paso 1
- contentId hardcodeado por ahora: `"real-madrid-barcelona-2025-01-24"` country `"NO"`
- Barcelona-PSG → datos demo estáticos (TimelineDataGenerator), sin backend

### Avanzamos paso a paso
1. ✅ App compila
2. 🔄 discoverCampaigns() al launch → ver logs "X campaigns discovered"
3. ⬜ Validar que config/branding del Sponsor llega (logo Elkjøp)
4. ⬜ Validar contentId flow → hasEngagement: true
5. ⬜ Overlay muestra polls activos
6. ⬜ Votar funciona
7. ⬜ Chat en tab "All"
8. ⬜ Score en MatchHeaderView

---

## ✅ Endpoints backend disponibles (listos para usar)

```
GET  /v1/sdk/broadcast?contentId=&country=     → validación + hasEngagement
GET  /v1/sdk/broadcasts/:id/score              → homeTeam, awayTeam, minute, matchStatus
GET  /v1/sdk/broadcasts/:id/stats              → stats del partido
GET  /v1/sdk/livescores                        → todos los partidos activos
POST /api/broadcasts/:id/chat                  → chat via WS
POST /api/broadcasts/:id/tweet                 → tweet via WS
WS   /ws/:campaignId                           → eventos: score_update, chat_message, tweet, poll, contest
```

Test: `apiKey=viaplay_api_key_0c611e983b314ff8`, `contentId=real-madrid-barcelona-2025-01-24`, `country=NO`

---

## 🔴 Tarea activa para Cursor

### TAREA 1 — Conectar BackendMatchDataService en MatchHeaderView
**Archivo:** `Sources/VioCastingUI/Components/Match/MatchHeaderView.swift`
**Qué hacer:**
1. Inyectar `BackendMatchDataService` como `@StateObject` o `@EnvironmentObject`
2. Reemplazar el marcador `0 - 0` hardcodeado con `service.currentScore`
3. Mostrar `homeTeam.name` y `awayTeam.name` desde `BroadcastValidationResult`
4. Llamar `service.fetchScore(broadcastId:country:)` en `.onAppear`
5. Suscribirse a `score_update` WS cuando llegue el evento

### TAREA 2 — Conectar BackendMatchDataService en MatchStatsView  
**Archivo:** `Sources/VioCastingUI/Components/Match/MatchStatsView.swift`
**Qué hacer:**
1. Reemplazar stats hardcodeadas con `service.currentStats`
2. Mostrar `hasStats: false` con estado vacío elegante si no hay datos

### TAREA 3 — Chat en AllContentFeed (tab "All")
**Archivo:** `Sources/VioCastingUI/Components/Engagement/AllContentFeedView.swift` (o similar)
**Qué hacer:**
1. Añadir suscripción WS a evento `chat_message`
2. Mostrar mensajes de chat mezclados con polls/contests en el feed
3. Endpoint historial: `GET /v1/sdk/broadcasts/:id/chat`

---

## 🔀 Branch activa
`feature/dynamic-backend-integration` — todos los commits aquí, NO en main.

---

## ⛔ NO tocar
- `campaignId: 28` (demo XXL legacy) — no romper
- `/v1/sdk/config` endpoint — no modificar
- `integrations.commerce` — nunca renombrar a tipio
- `DemoDataManager` para la demo Barcelona-PSG (datos estáticos, sin backend)

---

## 📋 Handoff protocol
1. Cuando Replit termina algo → actualiza este archivo con ✅ en su fila
2. Cuando Cursor termina algo → actualiza este archivo con ✅ en su fila  
3. Viobot revisa cada 2h y notifica a Angelo si hay bloqueos

_Actualizado: 2026-02-28 · Viobot_
