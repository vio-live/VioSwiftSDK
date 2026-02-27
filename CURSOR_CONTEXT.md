# CURSOR_CONTEXT.md — Para Cursor (Swift + Kotlin SDKs)

Hola Cursor. Este documento es tu contexto de trabajo para los SDKs de Vio.live.

Lee también: `VIO_TRUTH.md` — es la fuente absoluta de verdad del sistema.

---

## Quién eres y qué haces

Trabajas sobre dos repositorios:
- **VioSwiftSDK** — iOS SDK (Swift, SPM, privado)
- **VioKotlinSDK** — Android SDK (Kotlin, público)

Tu trabajo: mantener los SDKs en sync con el backend (`api-dev.vio.live`), implementar nuevas features, y garantizar calidad antes de demos con Viaplay y TV2.

---

## Estado actual — Swift SDK (commit 31979a0)

### Lo que acaba de llegar (nuevos archivos):
- `BroadcastContextSetup.swift` — orquestador del flujo contentId. Es el punto de entrada para cualquier integración de streaming.
- `BackendEngagementTabView.swift` — UI de polls y contests consumiendo el backend directamente.

### BUG ACTIVO — Prioridad alta
`ConfigAPIClient` usa la Commerce key (`KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S`) para llamar a `/v1/campaigns/:id/config` → recibe 401.

**Fix:** Usar `VioConfiguration.shared.apiKey` (la Vio App API Key) en lugar de la Commerce key.

```swift
// ConfigAPIClient.swift — línea que debe cambiar:
// ❌ Incorrecto — usa Commerce key
private var apiKey: String { VioConfiguration.shared.commerceApiKey }

// ✅ Correcto — usa la Vio App API Key
private var apiKey: String { VioConfiguration.shared.apiKey }
```

### TODOs pendientes (no bloqueantes para Viaplay demo)
- `UnifiedTimelineManager` — esperar definición de backend
- `ShareHighlightModal` — implementar descarga de highlights
- `LiveShowManager` — product highlighting es stub
- `TipioApiClient` — configuración de Tipio sin definir

---

## Estado actual — Kotlin SDK

### BLOCKER CRÍTICO — No hacer ningún demo hasta resolver esto
El namespace del SDK sigue siendo `io.reachu.*` en 191 archivos.

Cualquier integrador de Viaplay o TV2 que importe el SDK verá:
```kotlin
import io.reachu.VioUI      // ← Esto mata la venta
import io.reachu.VioCore    // ← Reachu no es Vio
```

**Migración necesaria:**
- Package: `io.reachu.*` → `live.vio.*`
- Maven groupId: `io.github.reachudevteam` → `io.github.angelosv` (o equivalente Vio)
- Maven artifactId: `reachu-kotlin-sdk` → `vio-kotlin-sdk`
- README: actualizar imports de ejemplo

---

## Reglas que siempre debes respetar

1. **Una sola API key en vio-config.json** — `apiKey` para todo. La Commerce key la entrega el backend dinámicamente en `/v1/campaigns/:id/config` bajo `integrations.commerce.apiKey`
2. **Branding desde Sponsor** — nunca hardcodear colores ni logos. Viene de `CampaignConfig.brand`
3. **ContentId es el flujo principal** — `BroadcastContextSetup` es el orquestador, no tocar su interfaz pública sin consultar
4. **Si `integrations.commerce.enabled = false`** → no inicializar módulo Commerce
5. **Logging** — usar `VioLogger` siempre, nunca `print()`

---

## Preguntas para ti, Cursor

1. ¿Puedes confirmar exactamente en qué línea de `ConfigAPIClient.swift` está el bug del 401?
2. ¿Qué dependencias tiene `BroadcastContextSetup` que podríamos necesitar actualizar si cambia el backend?
3. ¿Cuánto esfuerzo estimas la migración de namespace en KotlinSDK? ¿Hay riesgos de breaking changes para integradores actuales?
4. ¿Hay algo en el código que veas que no esté en este documento y que debería estar?

Cuéntanos lo que ves. Angelo toma las decisiones finales.
