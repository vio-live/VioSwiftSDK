# CLAUDE_QUESTIONS.md — Preguntas pendientes para Angelo

## Contexto
Rama activa: `feature/dynamic-backend-integration`
Viobot implementó: `BackendMatchDataService.swift` — servicio para score, stats, livescores desde backend.

## Implementado ✅
- `BackendMatchDataService` — fetches score, stats, livescores + handle score_update WS

## Pendiente de implementar
- Conectar `BackendMatchDataService` en `MatchStatsView` (reemplazar stats estáticas)
- Conectar score en `MatchHeaderView` (reemplazar 0-0 hardcodeado)
- Conectar livescores en la vista de Live Scores
- Chat via WebSocket (esperar a que Replit implemente el evento chat_message)

## Respuestas de Angelo ✅

**Q1 — Equipos:** Vienen en el broadcast (homeTeam/awayTeam). Se linkea con el ID que pase Viaplay.
**Q2 — Score:** WebSocket `score_update` + polling fallback cada 30s si WS cae. Cancela polling cuando WS reconecta.
**Q3 — Chat:** Aparece mezclado en tab "All" con polls/contests. Ajustable después.

## Preguntas para Angelo

**Q1 — MatchHeaderView**
El header muestra logos de equipos hardcodeados (FC Barcelona / Paris Saint-Germain).
¿Los logos/nombres de los equipos vienen del score endpoint que Replit va a crear,
o los introduce el admin en el dashboard al crear el broadcast?

**Q2 — Polling de score**
Mientras no hay WebSocket score_update, ¿el SDK debe hacer polling periódico del score
(ej. cada 30 segundos) o solo actualiza cuando llega el evento WS?

**Q3 — Chat en AllContentFeed**
El AllContentFeed mezcla polls, contests y chat en un solo feed.
¿El chat debe aparecer en el tab "All" mezclado con polls/contests,
o solo en el tab "Chat"?
