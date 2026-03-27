# VioSwiftSDK — Contexto iOS / tvOS

> **Regla canónica para Cursor:** `.cursor/rules/vio-swift-sdk-core.mdc` (`alwaysApply: true`). Este archivo es copia ampliada / histórica; mantener alineado cuando cambie el SDK.

> Origen: documentación interna del equipo, **revisada contra el código** en este repo.

## Verificación contra código

| Campo | Valor |
| ----- | ----- |
| Repo | Raíz del Swift Package (p. ej. `VioSwiftSDK` en GitHub `angelosv/VioSwiftSDK`) |
| Git HEAD al revisar | `b85fdf4` (2026-03-27) |
| Tests | `Tests/VioCoreTests/`: del orden de **~11** archivos Swift de test; ejecutar `swift test` para conteo exacto |

**Importante:** Una copia anterior de este doc afirmaba `cart_intent`, `userId` en querystring WS y mensaje `identify`. En **`CampaignWebSocketManager.swift` (HEAD revisado)** no hay coincidencias para `cart_intent`, `userId` en la URL ni `identify`. Los eventos manejados en `handleMessage` incluyen: `campaign_started|ended|paused|resumed`, `component_status_changed`, `component_config_updated`, `config:updated`, `lineup_show`. Si esas features están en otra rama, reintroducir este párrafo cuando se mergee.

---

## Inicialización

`VioSDK` **no** existe como tipo público unificado. Patrones reales:

```swift
// 1) Demos: desde bundle (p. ej. vio-config.json)
ConfigurationLoader.loadConfiguration()

// 2) Programático
VioConfiguration.configure(apiKey: "...")
// o la sobrecarga completa en VioConfiguration.configure(...)
```

Alias útil: `VioConfigurationLoader` → `ConfigurationLoader` (`VioCore.swift`).

`GET /v1/sdk/config` lo consume la capa de campaña (p. ej. `CampaignManager` / rutas de configuración) según `campaignAdminApiKey` vs `apiKey` en `CampaignConfiguration`; ver código para el flujo activo en cada método.

---

## CampaignManager

```swift
CampaignManager.shared            // correcto
VioConfiguration.campaignManager  // no existe
```

## discoverCampaigns

Hay dos entradas:

- `discoverCampaigns(broadcastId: String? = nil)` — **canónico**. Para `/v1/sdk/campaigns` usa `VioConfiguration.shared.apiKey` (no `campaignAdminApiKey`).
- `discoverCampaigns(matchId:)` — **deprecated**; delega en `broadcastId`.

Para evitar ambigüedad de overload en llamadas, usa el parámetro explícito: `await discoverCampaigns(broadcastId: nil)` o `broadcastId: "…"`.

---

## Managers y servicios (resumen)

| Nombre | Módulo | Notas |
| ------ | ------ | ----- |
| `CampaignManager` | VioCore | Singleton; descubrimiento, campaña activa, ofertas |
| `CampaignWebSocketManager` | VioCore | WS por `campaignId` y `baseURL`; eventos listados arriba |
| `DynamicConfigurationManager` | VioCore | Config remota y `config:updated` |
| `VioSessionContext` | VioCore | Contexto por broadcast / `contentId`; no singleton global único |
| `ProductService` | VioUI | Commerce vía GraphQL; cabeceras con **commerce** key donde aplique |
| `ConfigAPIClient` | VioCore | REST de configuración / engagement |
| `BroadcastValidationService` | VioCore | `GET /v1/sdk/broadcast?contentId&country` — usado desde Casting UI |
| `EventStreamerManager` | VioCastingUI | WS demo Replit para eventos de producto/poll/contest en player |
| `ComponentManager` | VioCore (`OfferBannerModels.swift`) | **Atención:** `baseURL` fija `https://event-streamer-angelo100.replit.app` (línea ~493) — alinear con config cuando se apruebe |
| `CacheManager` / `DemoDataManager` | VioCore | Cache y assets demo |

No hay **`VioCommerceService`**; commerce en `ProductService` + `SdkClient` (VioNetwork).

---

## URLs habituales (dev)

| Uso | URL |
| --- | --- |
| API / WS base | `https://api-dev.vio.live` |
| WS campaña | `wss://api-dev.vio.live/ws/{campaignId}` |
| GraphQL commerce | `https://graph-ql-dev.vio.live/graphql` |
| Event streamer demo | `wss://event-streamer-angelo100.replit.app/...` (legacy / demo) |

---

## Demos

Proyectos bajo `Demo/` (tv2demo, Viaplay, etc.). **Claves y campaign IDs:** leer el `vio-config.json` de cada target; no duplicar aquí valores sensibles.

---

## Pendientes conocidos (código actual)

- **ComponentManager** / URL Replit hardcodeada — ver `OfferBannerModels.swift`.
- **tv2demo** puede tener `WebSocketManager` propio frente a `EventStreamerManager` / `VCastingVideoPlayer` — revisar al unificar demo.
- **`cart_intent` / `userId` WS** — documentación previa; **no** presente en el `CampaignWebSocketManager` revisado.

---

## Regla de actualización

Cuando un cambio esté mergeado y probado:

1. Actualizar la sección **Verificación contra código** (HEAD + fecha).
2. Ajustar tablas si cambian managers o eventos WS.
3. Mantener este archivo alineado con [CODEBASE_INDEX.md](CODEBASE_INDEX.md).

---

## Más contexto

- Producto y equipo: [VIO_OVERVIEW.md](VIO_OVERVIEW.md)
- Backend / schema / APIs: [VIO_PLATFORM_CURSOR_CONTEXT.md](VIO_PLATFORM_CURSOR_CONTEXT.md)
