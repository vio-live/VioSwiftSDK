# Resumen de tarea — TV2 Demo (WebSocket único + modelos + logs)

Fecha referencia: marzo 2026. Rama habitual: `feature/tv2-sdk-integration`.

## Problema

- Había **dos conexiones WebSocket** al mismo `campaignId`: una correcta a `wss://ws-dev.vio.live` vía `VioConfiguration.wsBaseURL` (`CampaignWebSocketManager`) y otra a la URL legacy `campaignConfiguration.webSocketBaseURL` (`wss://api-dev.vio.live`).
- Origen del segundo socket: **`ComponentManager`** (`Sources/VioCore/Models/OfferBannerModels.swift`) creaba su propio `WebSocketManager` interno usando `webSocketBaseURL` y además hacía **auto-`connect()`** en el `init` del singleton.

## Cambios en el SDK (VioCore)

- **`OfferBannerModels.swift` — `ComponentManager`**
  - Eliminado el `Task { await connect() }` en `init` (evita conectar antes de `discoverCampaigns`).
  - Con **`autoDiscover == true`**: no se crea el WebSocket duplicado; se sincroniza `activeBanner` desde **`CampaignManager.shared.activeComponents`**.
  - Nuevos métodos: `syncActiveBannerFromCampaignManager()`, `refreshActiveBannerFromCampaignManager()` (público).
- **`OfferBannerModels.swift` — `WebSocketManager` interno** (solo si `autoDiscover == false`):
  - URL construida con **`VioConfiguration.shared.wsBaseURL`**, `URLRequest` con **`X-API-Key`**, query **`userId`** (vía `MainActor.run` para leer `CampaignManager.shared.userId`).
- **`CampaignManager.swift`**
  - Tras **`connectWebSocket`**, al conectar el WS, tras **`discoverCampaigns`** (guardado de componentes), y en **`handleComponentStatusChanged`**, **`handleComponentConfigUpdated`**, **`campaign_ended`**, **`campaign_paused`**, se llama a **`ComponentManager.shared.refreshActiveBannerFromCampaignManager()`** cuando aplica.

## Cambios en la demo tv2demo

- **`Configuration/vio-config.json`**: `webSocketBaseURL` y `devWebSocketBaseURL` alineados con **`wss://ws-dev.vio.live`** (REST sigue en `api-dev` donde corresponda).
- **Eliminado** `Services/WebSocketManager.swift` (segunda pila WS + tipos mezclados).
- **Añadido** `Models/TV2LiveEventModels.swift` con los tipos que estaban en el archivo eliminado (`PollEventData`, `PollOption`, `ProductEventData`, `ContestEventData`, wrappers `*Event` para JSON).
- **`tv2demoApp.swift`**: logs de arranque **unificados** con el mismo estilo `🎨 [TV2Demo]` para entorno, GraphQL, REST, WebSocket, `campaignId`, `autoDiscover`, commerce opcional, prefijo de API key; línea final **`WebSocket URL`** completa tras fijar `userId`.

## Resultado esperado

- Una sola conexión de campaña a **`wss://ws-dev.vio.live/ws/{campaignId}`** (salvo modo legacy sin `autoDiscover`).
- Menos errores POSIX 57 por tareas concurrentes / segundo socket invalidado.
- Overlays de casting siguen compilando gracias a **`TV2LiveEventModels.swift`**.
