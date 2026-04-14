# VioSwiftSDK — Índice del codebase

**Documentación de flujo, red y convenciones:** [VIO_SWIFT_SDK.md](VIO_SWIFT_SDK.md) · **Red en desarrollo (simulador, iPhone, Tailscale, túneles):** [DEVELOPMENT_NETWORKING.md](DEVELOPMENT_NETWORKING.md)

> Mapa para agentes y humanos. Verificado con `Package.swift` y árbol `Sources/`.

## Productos SPM (exportados)

Definidos en [`Package.swift`](../Package.swift):

| Product           | Rol breve |
| ----------------- | --------- |
| **VioCore**       | Config, campaña, REST, modelos, WS campaña (`CampaignWebSocketManager`), analytics |
| **VioNetwork**    | Apollo / GraphQL compartido |
| **VioDesignSystem** | UI base, Nuke |
| **VioUI**         | Comercio SwiftUI (productos, checkout iOS: Stripe / Klarna) |
| **VioEngagementSystem** | Polls / contests (lógica + repos) |
| **VioEngagementUI** | UI de engagement |
| **VioCastingUI**  | Partido en vivo: timeline, lineup, casting, `EventStreamerManager`, `VCastingVideoPlayer` |
| **VioComplete**   | Agrega Core + Network + DesignSystem + UI + Engagement + CastingUI |
| **VioTesting**    | Utilidades internas |

## Rutas críticas (por tema)

| Tema | Ruta principal |
| ---- | -------------- |
| Carga `vio-config.json` | `Sources/VioCore/Configuration/ConfigurationLoader.swift` |
| API keys y URLs | `Sources/VioCore/Configuration/VioConfiguration.swift`, `ModuleConfigurations.swift` |
| Orquestación campaña | `Sources/VioCore/Managers/CampaignManager.swift` |
| WS lifecycle campaña | `Sources/VioCore/Managers/CampaignWebSocketManager.swift` |
| Config remota por campaña | `Sources/VioCore/Managers/DynamicConfigurationManager.swift` |
| `contentId` → broadcast | `Sources/VioCore/Services/BroadcastValidationService.swift` |
| REST config / engagement | `Sources/VioCore/Network/ConfigAPIClient.swift` |
| Componentes / offer banner WS (Replit hardcode) | `Sources/VioCore/Models/OfferBannerModels.swift` (`ComponentManager`) |
| Sesión por broadcast | `Sources/VioCore/Managers/VioSessionContext.swift` |
| Productos GraphQL | `Sources/VioUI/Services/ProductService.swift` |
| Red dev / dispositivo físico / bootstrap | [DEVELOPMENT_NETWORKING.md](DEVELOPMENT_NETWORKING.md), `ConfigurationLoader` (`devRestAPIBaseURL`), `CampaignManager` (`/v1/sdk/config`) |
| Casting + validación en player | `Sources/VioCastingUI/Components/Video/VCastingVideoPlayer.swift` |
| Demos | `Demo/` (cada app con su `vio-config.json`) |

## Tests

- Directorio: `Tests/VioCoreTests/` (y otros si se añaden).
- Ejecutar: `swift test` desde la raíz del package.
