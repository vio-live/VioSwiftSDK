# BACKLOG — Vio.live
> Fuente de verdad de todas las tareas. Actualizado por Viobot.
> Lee también: VIO_TRUTH.md (nomenclatura y arquitectura), SPRINT.md (contexto técnico)

---

## Cómo usar este documento

- **IDs**: VIO-XXX — nunca se reutilizan
- **Estado**: 🔴 blocker · 🟡 en progreso · ⚪ pendiente · ✅ hecho
- **Propietario**: Replit (backend/dashboard) · Viobot/Claude (SDK Swift) · Alan (SDK Kotlin) · Viobot (infra/docs)
- Cuando termines una tarea → cambia el estado a ✅ y añade la fecha

---

## SPRINT ACTIVO — Semana 1 Mar

### VIO-003 · Replit · ⚪ pendiente
**Endpoint historial de chat por broadcast**

Por qué: Cuando el usuario abre el overlay a mitad del partido, debe ver los mensajes anteriores. Sin historial, el chat parece vacío aunque el WebSocket funcione.

Implementar:
  GET /v1/sdk/broadcasts/:broadcastId/chat?apiKey=...&limit=50
  → { broadcastId, messages: [...], count: N }

---

### VIO-004 · Replit · ⚪ pendiente
**Endpoint componentes por locationId**

Por qué: Los banners, countdown y carruseles son la capa de monetización. El desarrollador define slots en su código (locationId). Sin este endpoint los componentes nunca llegan al SDK.

Implementar:
  GET /v1/sdk/components?locationId=sport-banner&apiKey=...&campaignId=35
  → componente activo para ese slot, o vacío si no hay ninguno

---

### VIO-006 · Viobot · 🟡 en progreso
**Validar que branding del Sponsor se aplica en el overlay**

Verificado que llega brand=Elkjøp + logoUrl desde backend. Pendiente confirmar que se renderiza en el overlay en el Simulator.

---

### VIO-007 · Viobot · ✅ 2026-03-01
**Validar flujo contentId → hasEngagement → overlay**

contentId real-madrid-barcelona-2025-01-24 → hasEngagement:true → STEP 3 ✅ → STEP 4 WebSocket → STEP 5 loadEngagement.
Barcelona-PSG → hasEngagement:false → sin overlay. ✅

---

### VIO-008 · Viobot · ⚪ pendiente
**Conectar BackendMatchDataService en MatchHeaderView**

El header muestra 0-0 hardcodeado. Debe mostrar Real Madrid 2-1 Barcelona desde backend.
Archivo: Sources/VioCastingUI/Components/Match/MatchHeaderView.swift
Depende de: VIO-007 ✅

---

### VIO-009 · Viobot · ⚪ pendiente
**Chat en tab "All" mezclado con polls/contests**

Depende de: VIO-003 (endpoint historial chat)

---

## KOTLIN — FUERA DEL SPRINT ACTUAL
> No mezclar con el flujo Swift/backend hasta que esté estabilizado.

### VIO-010 · Alan · ⚪ pendiente (futuro)
**Migrar namespace io.reachu → live.vio en KotlinSDK (191 archivos)**
Cuando atacar: Después de que el flujo Swift + backend esté validado end-to-end.

---

## COMPLETADO

### VIO-001 · Replit · ✅ 2026-02-28
Status buttons "Go Live" / "End" en lista de broadcasts del dashboard.

### VIO-002 · Replit · ✅ 2026-02-28
/v1/campaigns/:id/config devuelve brand=Elkjøp, logoUrl, commerce.enabled. Verificado.

### VIO-005 · Viobot · ✅ 2026-03-01
discoverCampaigns(broadcastId: nil) en ViaplayApp.swift al launch. 1 campaign encontrada.

### VIO-007 · Viobot · ✅ 2026-03-01
contentId flow completo — STEP 1-5 verificados en Simulator.

### VIO-011 · Viobot · ✅ 2026-02-27
Fix 401 ConfigAPIClient.swift — usa Vio App API Key.

### VIO-012 · Viobot · ✅ 2026-02-27
Tipio eliminado del SDK Swift.

### VIO-013 · Viobot · ✅ 2026-02-27
BackendMatchDataService — score/stats/polling fallback 30s.

### VIO-014 · Viobot · ✅ 2026-02-27
BroadcastTeam en modelos — homeTeam/awayTeam en BroadcastValidationResult.

### VIO-015 · Replit · ✅ 2026-02-27
Endpoints match data — /score, /stats, /livescores operativos.

### VIO-016 · Replit · ✅ 2026-02-27
Chat y tweets via WebSocket.

### VIO-017 · Replit · ✅ 2026-02-28
Health check + deploy en autoscale.

### VIO-018 · Viobot · ✅ 2026-02-28
VIO_TRUTH.md v5 — Tipio eliminado, flujo paso a paso.

### VIO-019 · Viobot · ✅ 2026-03-01
Memory leaks corregidos:
- NSCache límites en VioDesignSystem/CachedAsyncImage + GraphQLOpsSingleFile
- monitorPlayerStatus Timer: guardado en controlsTimer, [weak item, weak self]
- startCountdown Timer: @State countdownTimer, [weak self], .onDisappear invalida
- HighlightVideoCard: token guardado en @State loopToken, removeObserver(token) correcto
- BroadcastContextSetup: guard isSettingUp contra llamadas concurrentes SwiftUI
- refreshCampaignsForContext: guard activeCampaigns.isEmpty evita loop infinito

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

_Actualizado: 2026-03-01 21:42 Oslo · Viobot_
