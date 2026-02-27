# VIO BEST PRACTICES
> Para Replit (backend) y Cursor/Claude (SDKs)
> Visión final: segunda pantalla oficial para eventos deportivos — Viaplay, TV2 y más.

---

## 🎯 VISIÓN FINAL — siempre en mente

```
Usuario ve partido en TV
       ↓
Abre Viaplay/TV2 en el móvil
       ↓
Vio SDK activa el panel de segunda pantalla
       ↓
Engagement en tiempo real (polls, contests, chat)
       ↓
Commerce en el momento de máxima emoción (productos, checkout)
       ↓
Datos deportivos sincronizados (score, stats, highlights)
```

Cada decisión técnica debe filtrar por: ¿esto nos acerca a que Viaplay/TV2 puedan integrarlo en producción?

---

## 🏗️ ARQUITECTURA — principios

### 1. Requests + WebSocket, no solo uno
- **Requests (REST):** datos iniciales al cargar (campañas, config, historial de chat, score actual)
- **WebSocket:** actualizaciones en tiempo real (nuevos polls, votos, chat, score_update)
- Nunca confiar solo en WS — siempre tener fallback REST
- Nunca hacer polling si hay WS disponible — solo como fallback

### 2. Estructura ahora, datos reales después
- Si un feed externo no está disponible → implementar el endpoint con datos manuales
- El contrato del API (nombres de campos, estructura JSON) no cambia cuando llegue el feed real
- El SDK nunca debe saber si los datos son manuales o de un feed externo

### 3. Legacy nunca se rompe
- `campaignId: 28`, `/v1/sdk/config` deben seguir funcionando siempre
- Nuevas features en nuevos endpoints — no modificar los existentes de forma destructiva
- Si hay que cambiar un campo, usar alias y mantener el antiguo

---

## 🔴 BACKEND — Replit

### API Design
```
✅ /v1/sdk/*         → endpoints públicos del SDK (requieren apiKey)
✅ /api/*            → endpoints del dashboard admin (requieren JWT)
✅ /ws/:campaignId   → WebSocket (sin auth, campaignId como scope)
```

### WebSocket — eventos estándar
Todos los eventos siguen este formato exacto:
```json
{ "type": "event_name", "data": { ... } }
```

Eventos implementados:
- `broadcast_started` / `broadcast_ended`
- `poll_results_updated` / `poll` / `contest`
- `component:activated` / `component:deactivated`

Eventos por implementar:
- `chat_message` → `{ type, broadcastId, username, message, timestamp }`
- `tweet` → `{ type, username, via, text, metrics }`
- `score_update` → `{ type, home, away, minute }`

### DB
- Transacciones Drizzle para cualquier operación multi-tabla
- Índices en `broadcastId` para todas las tablas de engagement
- Chat guardado por `broadcastId` — nunca mezclar broadcasts

### Seguridad
- `validateApiKey` en todos los endpoints `/v1/sdk/*`
- `validateBroadcastId` en todos los endpoints de engagement
- Rate limiting activo: 30/min votos, 10/min contests — no desactivar

### Escalabilidad futura
- Queue adapter pattern ya implementado (SimpleQueue → BullMQ con Redis)
- Cuando llegue Redis: solo cambiar el adapter, nada más
- Los endpoints no saben si hay queue o no

---

## 📱 SDK — Cursor/Claude (Swift + Kotlin)

### Arquitectura Swift
```
VioCore          → config, networking, modelos base
VioEngagementSystem → BroadcastContextSetup, servicios de negocio
VioCastingUI     → vistas y componentes UI
VioDesignSystem  → tokens, helpers visuales
VioUI            → componentes Commerce (ex-Reachu)
```

### Reglas de código
```swift
// ✅ Siempre VioLogger
VioLogger.debug("mensaje", component: "NombreClase")

// ❌ Nunca print()
print("debug")

// ✅ apiKey siempre desde VioConfiguration
VioConfiguration.shared.apiKey

// ❌ Nunca hardcodear keys
"viaplay_api_key_0c611e983b314ff8"

// ✅ URLs siempre desde config
VioConfiguration.shared.campaignConfiguration.restAPIBaseURL

// ❌ Nunca hardcodear URLs
"https://api-dev.vio.live"
```

### Patrón REST + WebSocket en el SDK
```swift
// Al inicializar una vista:
1. REST → cargar datos iniciales (score, polls activos, historial chat)
2. WebSocket → suscribirse a updates
3. Si WS se desconecta → startPolling(interval: 30)
4. Cuando WS reconecta → stopPolling()
```

### Branding
- Siempre desde `CampaignConfig.brand` (viene del Sponsor en backend)
- Nunca hardcodear logos, colores, nombres de sponsors
- Si `brand.logoUrl` es nil → placeholder genérico Vio, no imagen local

### Modelos
- `BroadcastValidationResult` → incluye `homeTeam`, `awayTeam` ← NUEVO
- `BroadcastTeam` → `name`, `logoUrl`, `externalId`
- `MatchScore`, `MatchStats`, `LiveScores` → en `BackendMatchDataService`
- `IntegrationsConfig.commerce` → nunca `tipio`

### Escalabilidad futura
- `BackendMatchDataService` acepta feeds externos sin cambiar la interfaz
- `BroadcastTeam.externalId` permite linkear con IDs de Viaplay/TV2
- Chat preparado para cola de mensajes (solo cambia el transport)

---

## 🔄 WORKFLOW DE DESARROLLO

```
1. Viobot revisa ambos repos cada 15 min (GitHub Actions notifica en #alertas)
2. Angelo aprueba cambios de arquitectura
3. Replit implementa backend → sube → notificación #alertas
4. Claude/Cursor implementa SDK → sube → notificación #alertas
5. Viobot revisa, detecta inconsistencias, coordina
6. Self-optimize nocturno actualiza MEMORY.md
```

### Branches
- `main` → siempre deployable, no rompe legacy
- `feature/*` → nuevas features, PR antes de merge
- Nunca force push a main salvo emergencia

### Commits
```
feat: nueva feature
fix: bug fix
docs: documentación
chore: limpieza
ci: CI/CD
refactor: refactor sin cambio de comportamiento
```

---

## 📋 CHECKLIST antes de cada PR

- [ ] Legacy sigue funcionando
- [ ] No hay keys hardcodeadas
- [ ] No hay URLs hardcodeadas
- [ ] WebSocket eventos siguen el formato `{ type, data }`
- [ ] `integrations.commerce` (no `tipio`)
- [ ] `VioLogger` en lugar de `print()`
- [ ] Transacciones DB en operaciones multi-tabla
- [ ] `validateApiKey` en endpoints SDK

---

_Actualizado: 2026-02-27 · Mantenido por Viobot_
