# CURSOR_TASK_CONTESTS.md
## Tarea: Conectar contests/competitions al backend (Fase 1)

### Rama de trabajo
`feature/contests-v1` (basada en `feature/dynamic-backend-integration`)

### Contexto
Los contests se muestran en el timeline de `AllContentFeed` vía `VCastingContestCard`.
Actualmente los datos vienen de `demo-static-data.json` hardcodeado.
El objetivo es que cuando el backend emita un WS event `contest`, el SDK lo procese y lo muestre en el timeline — igual que ya funciona con `poll`.

### Arquitectura actual
- WS event recibido → `CampaignWebSocketManager.onContestEventReceived` → `BroadcastContextSetup` → `EngagementManager.addOrUpdateContest(contest, broadcastId)`
- Model: `Contest` struct en `VioEngagementSystem`
- Timeline model: `CastingContestEvent` en `Sources/VioCastingUI/Models/TimelineEventModels.swift`
- UI: `VCastingContestCard` en `Sources/VioCastingUI/Components/Contests/VCastingContestCard.swift`
- Feed: `AllContentFeed.swift` case `.castingContest` → `CastingContestCardWrapper`

### Tareas

#### 1. Añadir `imageUrl` a `CastingContestEvent`
Archivo: `Sources/VioCastingUI/Models/TimelineEventModels.swift`
Añadir: `public let imageUrl: String?` al struct `CastingContestEvent`.
Actualizar el inicializador con `imageUrl: String? = nil`.

#### 2. Parsear `imageUrl` en `BroadcastContextSetup.swift`
El JSON del WS event tendrá este formato:
```json
{
  "type": "contest",
  "id": "contest-123",
  "broadcastId": "broadcast-abc",
  "title": "Elkjøp Konkurranse",
  "description": "Delta og vinn...",
  "prize": "To billetter",
  "contestType": "giveaway",
  "imageUrl": "https://api-dev.vio.live/objects/uploads/xxx.jpg"
}
```
Parsear `imageUrl` y pasarlo al `CastingContestEvent(...)`.
También añadir `imageUrl: String?` al struct `Contest` en VioEngagementSystem si no existe.

#### 3. Mostrar imagen en `VCastingContestCard`
Archivo: `Sources/VioCastingUI/Components/Contests/VCastingContestCard.swift`
- Si `contest.imageUrl != nil` → mostrar `CachedAsyncImage` como banner (full width, ~140pt height) con overlay oscuro + título encima
- Si nil → mantener diseño actual con asset local
Usar `CachedAsyncImage` (ya existe en el proyecto).

#### 4. Conectar `EngagementManager` → `LiveMatchViewModel` → `AllContentFeed`
Archivo: `Sources/VioCastingUI/Managers/Match/LiveMatchViewModel.swift`
Observar `EngagementManager.shared.$contestsByBroadcast` y por cada contest nuevo:
- Convertir `Contest` → `CastingContestEvent`
- Añadir al `UnifiedTimelineManager` si no existe (mismo `id`)
Igual al pattern de polls.

#### 5. Actualizar `demo-static-data.json` con imageUrl de demo
Archivos:
- `Demo/Viaplay/Viaplay/Configuration/demo-static-data.json`
- `Demo/tv2demo/tv2demo/Configuration/demo-static-data.json`
Añadir campo a los contests existentes:
`"imageUrl": "https://api-dev.vio.live/objects/uploads/adc65620-01ff-4c66-a7e2-de456495b9d1"`

### Reglas
- `VioLogger` en lugar de `print()`
- Nunca hardcodear URLs
- No tocar Kotlin SDK ni `main`
- Commits en `feature/contests-v1`

### Verificación
1. WS event `contest` llega → aparece en feed como `VCastingContestCard` con imagen del backend
2. Si no hay `imageUrl`, el card muestra diseño anterior sin romper
