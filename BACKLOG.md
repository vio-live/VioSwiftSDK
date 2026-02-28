# BACKLOG — Vio.live
> Fuente de verdad de todas las tareas. Actualizado por Viobot.
> Lee también: VIO_TRUTH.md (nomenclatura y arquitectura), SPRINT.md (contexto técnico)

---

## Cómo usar este documento

- **IDs**: VIO-XXX — nunca se reutilizan
- **Estado**: 🔴 blocker · 🟡 en progreso · ⚪ pendiente · ✅ hecho
- **Propietario**: Replit (backend/dashboard) · Cursor (SDK Swift) · Alan (SDK Kotlin) · Viobot (infra/docs)
- Cuando termines una tarea → cambia el estado a ✅ y añade la fecha

---

## SPRINT ACTIVO — Semana 28 feb

### VIO-001 · Replit · ✅ 2026-02-28
**Editar status de broadcast desde el dashboard**

Fix aplicado:
- Select de status (upcoming/live/ended) en el dialog de edición del broadcast ✅ (ya estaba)
- Botones rápidos en la lista: "Go Live" (verde, solo en upcoming) + "End" (rojo, solo en live) ✅ nuevo
- Backend emite broadcast_started / broadcast_ended via WebSocket al cambiar status ✅ (ya estaba)
- Toast de confirmación con mensaje específico por estado ✅
- Tests e2e pasados: flujo completo upcoming → live → ended verificado ✅

---

### VIO-002 · Replit · ✅ 2026-02-28
**Verificar /v1/campaigns/:id/config devuelve branding completo**

Verificado 17:28 Oslo — brand.name: Elkjøp, logoUrl presente.
Pendiente confirmar que el SDK lo recibe correctamente (depende de VIO-005).

---

### VIO-003 · Replit · ✅ 2026-02-28
**Endpoint historial de chat por broadcast**

Verificado en producción:
  GET /v1/sdk/broadcasts/real-madrid-vs-barcelona-2026-02-25/chat?apiKey=...&limit=5
  → { broadcastId, messages: [...], count: 5 }
Responde correctamente con mensajes del broadcast.

---

### VIO-004 · Replit · ✅ 2026-02-28
**Endpoint componentes por locationId**

Verificado en producción:
  GET /v1/sdk/components?locationId=sport-banner&apiKey=...&campaignId=35
  → { components: [], count: 0 }
Endpoint existe y responde. Retorna vacío si no hay componentes con ese locationId configurados.

---

### VIO-005 · Cursor · 🟡 en progreso
**Inicializar CampaignManager al arrancar la app**

Por qué: Con autoDiscover: true, el SDK necesita llamar a discoverCampaigns() al launch. Sin esto, el SDK está configurado pero nunca conecta al backend.

Fix aplicado: ViaplayApp.swift → Task { await CampaignManager.shared.discoverCampaigns() }
Validar: Logs deben mostrar "Campaigns discovered: 1 active" al arrancar.

---

### VIO-006 · Cursor · ⚪ pendiente
**Validar que branding del Sponsor se aplica en el overlay**

Por qué: El SDK recibe brand.logoUrl del backend. Confirmar que MatchHeaderView y el overlay muestran el logo de Elkjøp en lugar de un placeholder.
Depende de: VIO-005 completado y VIO-002 verificado.

---

### VIO-007 · Cursor · ⚪ pendiente
**Validar flujo contentId → hasEngagement → overlay**

Por qué: Este es el corazón del producto. El usuario abre el stream de Real Madrid en Viaplay → el SDK resuelve el contentId → hasEngagement: true → aparece el botón de casting.

contentId demo: real-madrid-barcelona-2025-01-24 · país: NO
Depende de: VIO-005 completado.

---

### VIO-008 · Cursor · ⚪ pendiente
**Conectar BackendMatchDataService en MatchHeaderView**

Por qué: El header muestra 0-0 hardcodeado. Debe mostrar Real Madrid 2-1 Barcelona desde el backend.
Archivo: Sources/VioCastingUI/Components/Match/MatchHeaderView.swift
Depende de: VIO-007 completado.

---

### VIO-009 · Cursor · ⚪ pendiente
**Chat en tab "All" mezclado con polls/contests**

Por qué: El tab "All" es el feed principal. Polls, contests y chat deben aparecer mezclados cronológicamente.
Depende de: VIO-003 (endpoint historial chat) + VIO-007.

---

---

## COMPLETADO

### VIO-011 · Viobot · ✅ 2026-02-27
Fix 401 en ConfigAPIClient.swift — SDK usaba Commerce key para autenticarse en Vio.

### VIO-012 · Viobot · ✅ 2026-02-27
Eliminar Tipio del SDK Swift — TipioApiClient, TipioWebSocketClient, TipioModels eliminados.

### VIO-013 · Viobot · ✅ 2026-02-27
BackendMatchDataService — score/stats/polling fallback 30s si WS cae.

### VIO-014 · Viobot · ✅ 2026-02-27
BroadcastTeam en modelos — BroadcastValidationResult incluye homeTeam/awayTeam.

### VIO-015 · Replit · ✅ 2026-02-27
Endpoints match data — /score, /stats, /livescores operativos.

### VIO-016 · Replit · ✅ 2026-02-27
Chat y tweets via WebSocket — chat_message y tweet eventos funcionando.

### VIO-017 · Replit · ✅ 2026-02-28
Health check + deploy en autoscale — /health responde, deploy estable.

### VIO-018 · Viobot · ✅ 2026-02-28
VIO_TRUTH.md v5 — Tipio eliminado, flujo paso a paso, componentes pendientes.

---

## KOTLIN — FUERA DEL SPRINT ACTUAL
> No mezclar con el flujo Swift/backend hasta que esté estabilizado.

### VIO-010 · Alan · ⚪ pendiente (futuro)
**Migrar namespace io.reachu → live.vio en KotlinSDK (191 archivos)**

Por qué: Cualquier integrador Android de Viaplay o TV2 verá "import io.reachu.VioUI". Mata la venta.
Alcance: Package, Maven groupId/artifactId, README.
Cuando atacar: Después de que el flujo Swift + backend esté validado end-to-end.

---

## DATOS DE DEMO

| Campo | Valor |
|-------|-------|
| apiKey Viaplay | viaplay_api_key_0c611e983b314ff8 |
| campaignId | 35 |
| contentId | real-madrid-barcelona-2025-01-24 |
| broadcastId | real-madrid-vs-barcelona-2026-02-25 |
| país | NO |
| Score demo | Real Madrid 2 - 1 Barcelona, min 65 |
| Sponsor | Elkjøp |
| Polls activos | 15 (¿Quién ganará?) + 16 (¿Quién marcará el primer gol?) |
| Campaña expira | 2026-03-04 |

---

_Actualizado: 2026-02-28 17:36 Oslo · Viobot_
