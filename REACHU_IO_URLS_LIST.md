# Lista de URLs vio.live en VioSwiftSDK

URLs actualizadas al backend Vio (vio.live).

---

## Mapeo Reachu → Vio

| Reachu (antiguo) | Vio (nuevo) |
|------------------|-------------|
| `api-qa.reachu.io` | `api-ecom-dev.vio.live` |
| `graph-ql-dev.reachu.io` | `graph-ql-dev.vio.live` |
| `api.reachu.io` | `api-ecom.vio.live` |
| `dev-campaing.reachu.io` | `api-dev.vio.live` |
| `campaing.reachu.io` | `api.vio.live` |

---

## 1. GraphQL API (ecommerce/productos)

| URL | Archivo | Uso |
|-----|---------|-----|
| `https://graph-ql-dev.vio.live` | `Sources/VioCore/Configuration/VioConfiguration.swift` | Endpoint GraphQL para sandbox/dev/production |
| `https://api-ecom.vio.live/graphql` | `Demo/tv2demo/tv2demo/Components/TV2ProductOverlay.swift` | GraphQL para overlay de productos TV2 |
| `https://api-ecom.vio.live/graphql` | `Demo/tv2demo/tv2demo/Components/CastingProductCard.swift` | GraphQL para casting product card |

---

## 2. Campaigns (WebSocket + REST)

| URL | Archivo | Uso |
|-----|---------|-----|
| `https://api-dev.vio.live` | `Sources/VioCore/Configuration/ModuleConfigurations.swift` | Default WebSocket/REST para campañas |
| `https://api-dev.vio.live` | `Sources/VioCore/Configuration/ConfigurationLoader.swift` | Comentarios de ejemplo |
| `https://api.vio.live` | `Sources/VioCore/Configuration/ConfigurationLoader.swift` | Comentario REST API producción |
| `wss://api-dev.vio.live/ws/{campaignId}` | `Demo/Vg/Vg/Services/WebSocketManager.swift` | WebSocket campañas demo Vg |

---

## 3. Components API (LiveShow dinámico)

| URL | Archivo | Uso |
|-----|---------|-----|
| `https://api-ecom-dev.vio.live/api/components/stream/{streamId}` | `Sources/VioLiveUI/Components/DynamicComponentsService.swift` | API de componentes dinámicos por stream |

---

## 4. Timeline API (documentación / ejemplos)

| URL | Archivo | Uso |
|-----|---------|-----|
| `https://api-ecom.vio.live/timeline/broadcast/{broadcastId}/events` | `Demo/Viaplay/TIMELINE_SYSTEM.md` | Ejemplo GET eventos timeline |
| `https://api-ecom.vio.live/timeline/chat/message` | `Demo/Viaplay/TIMELINE_SYSTEM.md` | Ejemplo POST mensaje chat |
| `wss://api-ecom.vio.live/timeline/broadcast/{broadcastId}` | `Demo/Viaplay/TIMELINE_SYSTEM.md` | Ejemplo WebSocket timeline |
