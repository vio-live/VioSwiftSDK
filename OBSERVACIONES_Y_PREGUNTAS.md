# Observaciones y Preguntas – Vio Platform

**Fecha:** 2026-01-27  
**Propósito:** Reflexiones del asistente tras revisar CURSOR_CONTEXT, VIO_TRUTH, CURSOR_SDK_INFRASTRUCTURE y el SDK Swift. Incluye preguntas para aclarar.

---

## 1. Lo que entiendo

### API Keys
- **Vio App API Key:** Una por Client App. Va en `vio-config.json` como `apiKey` raíz. Se usa en todos los endpoints SDK.
- **Commerce key (ex-Reachu):** Módulo de ecommerce. NO va en config estático; el backend la envía en `GET /v1/campaigns/:id/config` → `integrations.commerce.apiKey`.
- **Tipio:** Servicio de livestream. Producto SEPARADO de Commerce. NO es Reachu. (VIO_TRUTH v4 aclara esta distinción; el SDK tenía nomenclatura confusa.)

### SDK Swift
- Ya adaptado al modelo de una sola Vio App Key.
- `ConfigAPIClient`, `CampaignManager` usan `campaignApiKey.isEmpty ? apiKey : campaignApiKey`.
- `CampaignConfig` (DynamicConfigModels) aún no tiene `integrations.commerce`; si el backend ya lo envía, el SDK no lo parsea ni usa.

### Flujo
- Paso 1: `GET /v1/sdk/campaigns` al lanzar la app.
- Paso 2: `GET /v1/sdk/broadcast?contentId=xxx` al abrir un stream.
- Config dinámica: `GET /v1/campaigns/:id/config` devuelve brand, engagement, y (según docs) `integrations.commerce.apiKey`.

---

## 2. Observaciones

1. **Nomenclatura Tipio vs Commerce:** VIO_TRUTH v4 aclara: Tipio = livestream (producto separado), Commerce = ex-Reachu (ecommerce). El código usa `tipioApiKey` en LiveShowConfiguration para TipioApiClient (livestream); Commerce key debe venir de `integrations.commerce.apiKey` (backend).

2. **Commerce key en el SDK:** El modelo `CampaignConfig` no incluye `integrations`. Si el backend ya devuelve `integrations.commerce.apiKey`, el SDK Swift no la consume. Habría que añadir el campo y un `updateDynamicCommerceConfig()` (o similar).

3. **Flujo legacy vs nuevo:** El SDK aún soporta `GET /v1/sdk/config?campaignId=` (legacy) y `campaignId` fijo en `liveShow`. El flujo nuevo (contentId → broadcast) coexiste con el legacy.

4. **CURSOR_CONTEXT vs VIO_TRUTH:** CURSOR_CONTEXT es más operativo (archivos, comandos, pendientes). VIO_TRUTH es el contrato conceptual (keys, flujo, jerarquía). Ambos se complementan.

---

## 3. Preguntas para responder

### API Keys y Commerce
1. ¿El backend ya devuelve `integrations.commerce.apiKey` en `GET /v1/campaigns/:id/config`? Si sí, ¿en qué estructura exacta (ej. `{ "integrations": { "commerce": { "apiKey": "KCXF10Y-..." } } }`)?
2. ¿Tipio y Commerce comparten infra (tipioapp.com) o son completamente separados? (TipioApiClient usa fallback KCXF10Y que es Commerce key.)
3. ¿La Commerce key se usa solo para Commerce (ex-Reachu), o hay otros proveedores de commerce en el futuro?

### SDK y Flujo
4. ¿El SDK Swift debe priorizar el flujo contentId → broadcast sobre el legacy (campaignId fijo)?
5. ¿Hay planes de deprecar `GET /v1/sdk/config` en favor de `GET /v1/campaigns/:id/config`?

### Backend
6. ¿`integrations` en la respuesta de campaigns config incluye solo commerce, o habrá más (ej. analytics, payment)?
7. ¿La Commerce key se almacena en la DB (ej. en campaigns o client_apps) o se resuelve de otra forma?

---

## 4. Sugerencias

- VIO_TRUTH v4 ya documenta: Commerce = ex-Reachu, Tipio = livestream (producto separado).
- Si el backend ya envía `integrations.commerce`, implementar en el SDK Swift el parseo y uso de esa key.
- Mantener CURSOR_CONTEXT y VIO_TRUTH sincronizados cuando cambie el modelo de keys o flujos.

---

**Siguiente paso:** Responder las preguntas y actualizar docs/código según las respuestas.
