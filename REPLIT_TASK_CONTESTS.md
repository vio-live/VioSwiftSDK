# REPLIT_TASK_CONTESTS.md
## Tarea: Dashboard de Concursos (Fase 1)

### Objetivo
Permitir crear y gestionar concursos (contests) desde el dashboard de Replit,
con los campos necesarios para que el SDK los pueda mostrar correctamente.

### Backend — schema
El schema de `contests` en `shared/schema.ts` ya existe con:
- id, broadcastId, title, description, prize, contestType, startTime, endTime, isActive

**Nuevo campo a añadir**:
```typescript
imageUrl: varchar("image_url", { length: 1000 })
```
Migrar con drizzle.

### API ya existente
- `POST /api/broadcasts/:broadcastId/contests` — crear contest
- `GET /api/broadcasts/:broadcastId/contests` — listar contests
- `PUT /api/contests/:contestId` — actualizar contest
- `DELETE /api/contests/:contestId` — eliminar contest

Actualizar `POST` y `PUT` para incluir `imageUrl` en el body y persistirlo.

### WebSocket — emisión al crear
Cuando se crea o activa un contest desde el dashboard, emitir evento WS al broadcast:
```json
{
  "type": "contest",
  "broadcastId": "broadcast-abc",
  "id": "contest-123",
  "title": "Elkjøp Konkurranse",
  "description": "Delta og vinn to billetter til Champions League",
  "prize": "To billetter til Champions League",
  "contestType": "giveaway",
  "imageUrl": "https://...",
  "isActive": true,
  "timestamp": 1234567890
}
```

### Dashboard UI
En la sección de Broadcasts (o tab Engagement), añadir sub-sección "Concursos":

**Formulario de creación**:
- `title` — input text (requerido)
- `description` — textarea
- `prize` — input text (ej: "To billetter til Champions League")
- `contestType` — select: "giveaway" | "quiz" | "prediction"
- `imageUrl` — input URL (imagen para mostrar en el SDK)
- `isActive` — toggle (default: true)
- Botón "Crear Concurso" → POST /api/broadcasts/:id/contests

**Lista de contests activos**:
- Mostrar contests del broadcast activo
- Botón "Activar/Desactivar" por contest (toggle isActive + emitir WS)
- Botón "Eliminar"

### Validaciones
- `title` requerido, max 500 chars
- `contestType` debe ser "giveaway", "quiz", o "prediction"
- `imageUrl` debe ser URL válida si se provee

### Importante
- El WS event debe seguir el formato exacto de arriba — el SDK lo parsea por campo
- `broadcastId` debe incluirse en el evento WS (el SDK filtra por broadcastId activo)
- Reutilizar el pattern ya existente de polls para la emisión WS

### Verificación
1. Crear contest desde dashboard → aparece en lista
2. Activar toggle → SDK recibe WS event `contest` y muestra el card
3. Si se provee `imageUrl` → el SDK muestra la imagen en el card
