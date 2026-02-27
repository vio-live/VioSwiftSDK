# Respuestas de Angelo — 2026-02-27

## P1 — ¿Backend devuelve integrations.commerce?
**Sí.** Replit ya lo confirmó y está en producción.
`GET /v1/campaigns/35/config?apiKey=viaplay_api_key_0c611e983b314ff8` devuelve `integrations.commerce` correctamente.

## P2 — ¿Priorizar contentId flow sobre legacy?
**Sí.** ContentId es el flujo principal ahora.
Legacy (`campaignId: 28`) debe seguir funcionando pero no es el foco.

## P3 — AnalyticsManager.swift error trackAutomaticEvents
**Apuntado para después del lunes.** No tocar ahora — no bloquea la demo.

## Datos de test confirmados (Replit)
- Campaign ID: 35 (Viaplay Demo 2025, sponsor Elkjøp)
- API Key: `viaplay_api_key_0c611e983b314ff8`
- contentId: `real-madrid-barcelona-2025-01-24`
- País: `NO`
- Broadcast: `real-madrid-vs-barcelona-2026-02-25` — status: live
- Polls activos: 15 y 16

## Próximo paso
Verificar el loop completo en el SDK:
1. `GET /v1/sdk/campaigns?apiKey=viaplay_api_key_0c611e983b314ff8` → campaña 35
2. `GET /v1/campaigns/35/config` → brand Elkjøp + integrations.commerce
3. `BroadcastContextSetup.setup()` con contentId `real-madrid-barcelona-2025-01-24`
4. WebSocket `/ws/35` → eventos
5. `BackendEngagementTabView` → polls 15 y 16 visibles

Confirmar que el logo de Elkjøp carga desde el backend (no hardcodeado) y que los polls aparecen en la UI.
