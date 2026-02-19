# Prompt de Implementación: Sistema de Gestión de Broadcasts

## 🎯 Objetivo

Implementar un sistema completo de gestión de Broadcasts (equivalente a Programs de LiveLike) que permita:
1. Crear y gestionar broadcasts antes de los eventos
2. Asociar campañas a broadcasts
3. Validar broadcasts cuando el SDK los usa
4. Dashboard UI completo para gestión de broadcasts

---

## 📋 Contexto y Arquitectura Actual

### Estado Actual
- ✅ Existe tabla `campaigns` con campo `match_id` (que almacena `broadcastId`)
- ✅ Existe endpoint `GET /v1/sdk/campaigns?broadcastId=...` para auto-discovery
- ✅ El SDK envía `broadcastId` desde el cliente sin validación
- ❌ No existe tabla `broadcasts` independiente
- ❌ No existe API para crear/gestionar broadcasts
- ❌ No existe validación de que `broadcastId` existe

### Arquitectura Propuesta
```
┌─────────────────┐
│   Dashboard UI  │ ← Crear/Editar Broadcasts
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Backend API    │ ← POST/GET/PUT/DELETE /v1/broadcasts
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  broadcasts DB  │ ← Tabla broadcasts (nueva)
│                 │ ← broadcasts.campaign_id → campaigns.id (FK)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  campaigns DB   │ ← Una campaña puede tener múltiples broadcasts
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  polls/contests │ ← Cada broadcast tiene sus polls/contests
└─────────────────┘
```

**Relaciones:**
- **Campaign (1) → Broadcasts (N)**: Una campaña puede tener múltiples broadcasts
- **Broadcast (1) → Campaign (1)**: Un broadcast pertenece a una campaña
- **Broadcast (1) → Polls/Contests (N)**: Cada broadcast tiene sus propios polls/contests

---

## 🗄️ FASE 1: Base de Datos

### 1.1 Crear Tabla `broadcasts`

```sql
CREATE TABLE broadcasts (
    broadcast_id VARCHAR(255) PRIMARY KEY COMMENT 'Identificador único del broadcast (ej: barcelona-psg-2025-01-23)',
    broadcast_name VARCHAR(255) NOT NULL COMMENT 'Nombre legible del broadcast (ej: Barcelona vs PSG)',
    start_time TIMESTAMP NULL COMMENT 'Fecha y hora de inicio del broadcast (ISO 8601)',
    end_time TIMESTAMP NULL COMMENT 'Fecha y hora de fin del broadcast (ISO 8601)',
    channel_id INT NULL COMMENT 'ID del canal asociado (mismo que campaigns.channel_id)',
    status ENUM('upcoming', 'live', 'ended') DEFAULT 'upcoming' COMMENT 'Estado del broadcast',
    metadata JSON NULL COMMENT 'Metadata adicional (equipos, competencia, estadio, etc.)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    created_by INT NULL COMMENT 'ID del usuario que creó el broadcast',
    
    INDEX idx_status (status),
    INDEX idx_channel_id (channel_id),
    INDEX idx_start_time (start_time),
    INDEX idx_status_start_time (status, start_time),
    
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 1.2 Agregar Foreign Key a `campaigns`

```sql
-- Agregar constraint para validar que match_id existe en broadcasts
ALTER TABLE campaigns
ADD CONSTRAINT fk_campaigns_broadcast_id
FOREIGN KEY (match_id) REFERENCES broadcasts(broadcast_id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Crear índice para mejorar performance de queries
CREATE INDEX idx_campaigns_match_id ON campaigns(match_id);
```

### 1.3 Migración de Datos Existentes (Opcional)

```sql
-- Si ya existen campañas con match_id, crear broadcasts automáticamente
INSERT INTO broadcasts (broadcast_id, broadcast_name, start_time, channel_id, status, created_at)
SELECT DISTINCT
    c.match_id,
    COALESCE(c.match_name, c.match_id) as broadcast_name,
    c.match_start_time as start_time,
    c.channel_id,
    CASE
        WHEN c.match_start_time > NOW() THEN 'upcoming'
        WHEN c.match_start_time <= NOW() AND (c.end_date IS NULL OR c.end_date >= NOW()) THEN 'live'
        ELSE 'ended'
    END as status,
    MIN(c.created_at) as created_at
FROM campaigns c
WHERE c.match_id IS NOT NULL
  AND c.match_id NOT IN (SELECT broadcast_id FROM broadcasts)
GROUP BY c.match_id, c.match_name, c.match_start_time, c.channel_id;
```

---

## 🔌 FASE 2: Backend API

### 2.1 Endpoint: POST /v1/broadcasts

**Propósito:** Crear un nuevo broadcast

**Request:**
```json
POST /v1/broadcasts
Content-Type: application/json
Authorization: Bearer {admin_token}

{
  "broadcastId": "barcelona-psg-2025-01-23",  // Opcional: si no se proporciona, auto-generar
  "broadcastName": "Barcelona vs PSG",
  "startTime": "2025-01-23T20:00:00Z",  // ISO 8601
  "endTime": "2025-01-23T22:00:00Z",    // Opcional
  "channelId": 1,                        // Opcional
  "metadata": {                          // Opcional
    "homeTeam": "Barcelona",
    "awayTeam": "PSG",
    "competition": "Champions League",
    "round": "Round of 16",
    "stadium": "Camp Nou"
  }
}
```

**Validaciones:**
1. `broadcastName` es requerido
2. `broadcastId` debe ser único (si se proporciona)
3. Si `broadcastId` no se proporciona, generar automáticamente:
   - Formato: `{channelId}-{timestamp}` o `{name-slug}-{date}`
   - Ejemplo: `1-1706035200` o `barcelona-vs-psg-2025-01-23`
4. `startTime` debe ser válido ISO 8601
5. `endTime` debe ser después de `startTime` (si se proporciona)
6. `channelId` debe existir en tabla `channels` (si se proporciona)
7. `status` se calcula automáticamente:
   - Si `startTime` > ahora → `upcoming`
   - Si `startTime` <= ahora <= `endTime` → `live`
   - Si `endTime` < ahora → `ended`

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "broadcastId": "barcelona-psg-2025-01-23",
    "broadcastName": "Barcelona vs PSG",
    "startTime": "2025-01-23T20:00:00Z",
    "endTime": "2025-01-23T22:00:00Z",
    "channelId": 1,
    "status": "upcoming",
    "metadata": {
      "homeTeam": "Barcelona",
      "awayTeam": "PSG",
      "competition": "Champions League"
    },
    "createdAt": "2025-01-20T10:00:00Z",
    "updatedAt": "2025-01-20T10:00:00Z"
  }
}
```

**Errores:**
- `400 Bad Request`: Validación fallida (campos requeridos, formato inválido)
- `409 Conflict`: `broadcastId` ya existe
- `404 Not Found`: `channelId` no existe (si se proporciona)
- `401 Unauthorized`: Token inválido o sin permisos

---

### 2.2 Endpoint: GET /v1/broadcasts/{broadcastId}

**Propósito:** Obtener detalles de un broadcast específico

**Request:**
```
GET /v1/broadcasts/barcelona-psg-2025-01-23
Authorization: Bearer {admin_token}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "broadcastId": "barcelona-psg-2025-01-23",
    "broadcastName": "Barcelona vs PSG",
    "startTime": "2025-01-23T20:00:00Z",
    "endTime": "2025-01-23T22:00:00Z",
    "channelId": 1,
    "channelName": "XXL iOS Channel",
    "status": "upcoming",
    "metadata": {
      "homeTeam": "Barcelona",
      "awayTeam": "PSG",
      "competition": "Champions League"
    },
    "campaigns": [
      {
        "campaignId": 28,
        "campaignName": "Elkjop Campaign",
        "status": "active"
      }
    ],
    "createdAt": "2025-01-20T10:00:00Z",
    "updatedAt": "2025-01-20T10:00:00Z"
  }
}
```

**Errores:**
- `404 Not Found`: Broadcast no existe
- `401 Unauthorized`: Token inválido

---

### 2.3 Endpoint: GET /v1/broadcasts

**Propósito:** Listar broadcasts con filtros y paginación

**Request:**
```
GET /v1/broadcasts?status=upcoming&channelId=1&page=1&limit=20&sortBy=startTime&sortOrder=asc
Authorization: Bearer {admin_token}
```

**Query Parameters:**
- `status` (opcional): Filtrar por estado (`upcoming`, `live`, `ended`)
- `channelId` (opcional): Filtrar por canal
- `startDate` (opcional): Filtrar broadcasts que empiezan después de esta fecha (ISO 8601)
- `endDate` (opcional): Filtrar broadcasts que terminan antes de esta fecha (ISO 8601)
- `search` (opcional): Buscar por nombre o `broadcastId`
- `page` (opcional, default: 1): Número de página
- `limit` (opcional, default: 20): Resultados por página
- `sortBy` (opcional, default: `startTime`): Campo para ordenar (`startTime`, `createdAt`, `broadcastName`)
- `sortOrder` (opcional, default: `desc`): Orden (`asc`, `desc`)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "broadcasts": [
      {
        "broadcastId": "barcelona-psg-2025-01-23",
        "broadcastName": "Barcelona vs PSG",
        "startTime": "2025-01-23T20:00:00Z",
        "endTime": "2025-01-23T22:00:00Z",
        "channelId": 1,
        "channelName": "XXL iOS Channel",
        "status": "upcoming",
        "campaignsCount": 2,
        "createdAt": "2025-01-20T10:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 45,
      "totalPages": 3
    }
  }
}
```

---

### 2.4 Endpoint: PUT /v1/broadcasts/{broadcastId}

**Propósito:** Actualizar un broadcast existente

**Request:**
```json
PUT /v1/broadcasts/barcelona-psg-2025-01-23
Content-Type: application/json
Authorization: Bearer {admin_token}

{
  "broadcastName": "Barcelona vs PSG - Updated",
  "startTime": "2025-01-23T21:00:00Z",  // Cambiar hora de inicio
  "endTime": "2025-01-23T23:00:00Z",
  "metadata": {
    "homeTeam": "FC Barcelona",
    "awayTeam": "Paris Saint-Germain",
    "competition": "UEFA Champions League"
  }
}
```

**Validaciones:**
- Solo campos proporcionados se actualizan (PATCH-like behavior)
- `broadcastId` NO se puede cambiar
- `status` se recalcula automáticamente basado en `startTime` y `endTime`
- Validaciones similares a POST

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "broadcastId": "barcelona-psg-2025-01-23",
    "broadcastName": "Barcelona vs PSG - Updated",
    "startTime": "2025-01-23T21:00:00Z",
    "endTime": "2025-01-23T23:00:00Z",
    "status": "upcoming",
    "updatedAt": "2025-01-21T15:30:00Z"
  }
}
```

---

### 2.5 Endpoint: DELETE /v1/broadcasts/{broadcastId}

**Propósito:** Eliminar un broadcast (soft delete)

**Request:**
```
DELETE /v1/broadcasts/barcelona-psg-2025-01-23
Authorization: Bearer {admin_token}
```

**Validaciones:**
- No se puede eliminar si tiene campañas activas asociadas
- Si tiene campañas, retornar error con lista de campañas

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Broadcast deleted successfully"
}
```

**Errores:**
- `400 Bad Request`: Broadcast tiene campañas activas asociadas
- `404 Not Found`: Broadcast no existe

---

### 2.6 Modificar: GET /v1/sdk/campaigns (Validación de BroadcastId)

**Cambio requerido:** Validar que `broadcastId` existe antes de buscar campañas

**Código actual (modificar):**
```python
# Pseudocódigo - ANTES
@router.get("/v1/sdk/campaigns")
async def discover_campaigns(broadcastId: Optional[str] = None):
    campaigns = await db.get_active_campaigns(broadcastId=broadcastId)
    return {"campaigns": campaigns}
```

**Código nuevo:**
```python
# Pseudocódigo - DESPUÉS
@router.get("/v1/sdk/campaigns")
async def discover_campaigns(broadcastId: Optional[str] = None):
    # Si se proporciona broadcastId, validar que existe
    if broadcastId:
        broadcast = await db.get_broadcast(broadcastId)
        if not broadcast:
            raise HTTPException(
                status_code=404,
                detail=f"Broadcast '{broadcastId}' not found"
            )
        
        # Verificar que broadcast está activo o upcoming
        if broadcast.status == "ended":
            # Retornar array vacío, no error (broadcast existe pero terminó)
            return {"campaigns": []}
    
    # Continuar con lógica existente
    campaigns = await db.get_active_campaigns(broadcastId=broadcastId)
    return {"campaigns": campaigns}
```

**Comportamiento:**
- Si `broadcastId` no existe → Error 404 con mensaje claro
- Si `broadcastId` existe pero está `ended` → Retornar array vacío (no error)
- Si `broadcastId` existe y está `upcoming` o `live` → Retornar campañas normalmente
- Si no se proporciona `broadcastId` → Comportamiento actual (retornar todas las campañas activas)

---

## 🎨 FASE 3: Frontend/Dashboard UI

### 3.1 Estructura de Navegación

**Agregar nueva sección "Broadcasts" en el menú principal:**
```
Dashboard
├── Campaigns (existente)
├── Broadcasts (NUEVO) ← Agregar aquí
├── Components (existente)
└── Settings (existente)
```

### 3.2 Página: Lista de Broadcasts

**Ruta:** `/broadcasts`

**Componentes:**
1. **Header con acciones:**
   - Título: "Broadcasts"
   - Botón "Create Broadcast" (lleva a formulario de creación)
   - Botón "Refresh" (recargar lista)

2. **Filtros:**
   - Dropdown "Status" (All, Upcoming, Live, Ended)
   - Dropdown "Channel" (todos los canales)
   - Date picker "Start Date" (filtrar por fecha inicio)
   - Date picker "End Date" (filtrar por fecha fin)
   - Input "Search" (buscar por nombre o ID)

3. **Tabla de Broadcasts:**
   ```
   | Broadcast ID | Name | Channel | Start Time | Status | Campaigns | Actions |
   |--------------|------|---------|------------|--------|-----------|---------|
   | barcelona... | Bar.. | XXL iOS | 2025-01-23 | Upcoming | 2 | [Edit] [Delete] |
   ```

   **Columnas:**
   - **Broadcast ID**: Mostrar primeros 20 caracteres + "..."
   - **Name**: Nombre completo
   - **Channel**: Nombre del canal (o "N/A" si no tiene)
   - **Start Time**: Formato legible (ej: "Jan 23, 2025 8:00 PM")
   - **Status**: Badge con color:
     - `upcoming`: Badge azul
     - `live`: Badge verde
     - `ended`: Badge gris
   - **Campaigns**: Número de campañas asociadas (clickeable → ver campañas)
   - **Actions**: Botones Edit y Delete

4. **Paginación:**
   - Mostrar página actual, total de páginas
   - Botones "Previous" y "Next"
   - Selector de resultados por página (10, 20, 50)

**Estados:**
- **Loading**: Mostrar skeleton/spinner
- **Empty**: Mostrar mensaje "No broadcasts found" con botón "Create Broadcast"
- **Error**: Mostrar mensaje de error con botón "Retry"

---

### 3.3 Página: Crear Broadcast

**Ruta:** `/broadcasts/create`

**Formulario:**
```
┌─────────────────────────────────────┐
│ Create Broadcast                     │
├─────────────────────────────────────┤
│ Broadcast ID*                        │
│ [________________] [Auto-generate]   │
│ (Leave empty to auto-generate)       │
│                                      │
│ Broadcast Name*                      │
│ [Barcelona vs PSG____________]        │
│                                      │
│ Channel                              │
│ [Select Channel ▼]                  │
│                                      │
│ Start Time*                          │
│ [📅] [2025-01-23] [🕐] [20:00]      │
│                                      │
│ End Time                             │
│ [📅] [2025-01-23] [🕐] [22:00]      │
│                                      │
│ Metadata (Optional)                  │
│ ┌─────────────────────────────────┐ │
│ │ Home Team: [Barcelona______]   │ │
│ │ Away Team: [PSG_____________]   │ │
│ │ Competition: [Champions League] │ │
│ │ Round: [Round of 16_________]  │ │
│ │ Stadium: [Camp Nou__________]   │ │
│ └─────────────────────────────────┘ │
│                                      │
│ [Cancel] [Create Broadcast]         │
└─────────────────────────────────────┘
```

**Validaciones en Frontend:**
- `broadcastName` es requerido
- `startTime` es requerido y debe ser fecha futura
- `endTime` debe ser después de `startTime`
- `broadcastId` debe ser único (validar con API antes de crear)

**Flujo:**
1. Usuario llena formulario
2. Click "Create Broadcast"
3. Validar campos en frontend
4. Mostrar loading spinner
5. Llamar `POST /v1/broadcasts`
6. Si éxito → Redirigir a `/broadcasts/{broadcastId}` (página de detalles)
7. Si error → Mostrar mensaje de error específico

---

### 3.4 Página: Detalles de Broadcast

**Ruta:** `/broadcasts/{broadcastId}`

**Layout:**
```
┌─────────────────────────────────────┐
│ ← Back to Broadcasts                │
│                                      │
│ Barcelona vs PSG                    │
│ barcelona-psg-2025-01-23            │
│ [Upcoming] [Edit] [Delete]          │
├─────────────────────────────────────┤
│ Details                             │
│ ┌─────────────────────────────────┐ │
│ │ Start Time: Jan 23, 2025 8:00 PM│ │
│ │ End Time: Jan 23, 2025 10:00 PM │ │
│ │ Channel: XXL iOS Channel       │ │
│ │ Status: Upcoming                │ │
│ └─────────────────────────────────┘ │
│                                      │
│ Metadata                            │
│ ┌─────────────────────────────────┐ │
│ │ Home Team: Barcelona            │ │
│ │ Away Team: PSG                  │ │
│ │ Competition: Champions League   │ │
│ └─────────────────────────────────┘ │
│                                      │
│ Associated Campaigns (2)            │
│ ┌─────────────────────────────────┐ │
│ │ [Elkjop Campaign] [View →]    │ │
│ │ [Power Campaign] [View →]     │ │
│ └─────────────────────────────────┘ │
│                                      │
│ [Edit Broadcast] [Delete Broadcast]│
└─────────────────────────────────────┘
```

**Funcionalidades:**
- Ver todos los detalles del broadcast
- Ver campañas asociadas (con link a página de campaña)
- Botón "Edit" → Lleva a página de edición
- Botón "Delete" → Muestra confirmación antes de eliminar

---

### 3.5 Página: Editar Broadcast

**Ruta:** `/broadcasts/{broadcastId}/edit`

**Formulario:** Similar a crear, pero:
- Pre-llenado con datos actuales
- `broadcastId` es readonly (no se puede cambiar)
- Botón "Save Changes" en lugar de "Create Broadcast"

**Flujo:**
1. Cargar datos del broadcast con `GET /v1/broadcasts/{broadcastId}`
2. Pre-llenar formulario
3. Usuario modifica campos
4. Click "Save Changes"
5. Llamar `PUT /v1/broadcasts/{broadcastId}`
6. Si éxito → Redirigir a página de detalles
7. Si error → Mostrar mensaje de error

---

### 3.6 Integración: Crear Campaña con Broadcast

**Modificar página de creación de campaña:**

**Agregar sección "Broadcast Context":**
```
┌─────────────────────────────────────┐
│ Campaign Settings                   │
│ ...                                 │
│                                      │
│ Broadcast Context                   │
│ ┌─────────────────────────────────┐ │
│ │ [ ] Associate with Broadcast    │ │
│ │                                  │ │
│ │ Broadcast: [Select Broadcast ▼]│ │
│ │                                  │ │
│ │ Or create new:                  │ │
│ │ [Create New Broadcast →]        │ │
│ └─────────────────────────────────┘ │
│                                      │
│ [Save Campaign]                     │
└─────────────────────────────────────┘
```

**Comportamiento:**
- Checkbox "Associate with Broadcast"
- Si está marcado → Mostrar dropdown con broadcasts disponibles
- Dropdown filtra por:
  - Status: `upcoming` o `live`
  - Channel: Mismo que el canal de la campaña
- Opción "Create New Broadcast" → Abre modal o nueva página
- Al seleccionar broadcast → Auto-llenar `match_id`, `match_name`, `match_start_time`

---

### 3.7 Componentes Reutilizables

**1. BroadcastStatusBadge:**
```jsx
<BroadcastStatusBadge status="upcoming" />
// Renderiza: <span className="badge badge-blue">Upcoming</span>
```

**2. BroadcastSelector:**
```jsx
<BroadcastSelector
  value={selectedBroadcastId}
  onChange={setSelectedBroadcastId}
  channelId={campaignChannelId}
  status={['upcoming', 'live']}
/>
```

**3. BroadcastForm:**
```jsx
<BroadcastForm
  initialData={broadcast}
  onSubmit={handleSubmit}
  onCancel={handleCancel}
/>
```

---

## 🔄 FASE 4: Flujos de Usuario

### Flujo 1: Crear Broadcast y Asociar Campaña

```
1. Admin va a /broadcasts
2. Click "Create Broadcast"
3. Llena formulario:
   - Name: "Barcelona vs PSG"
   - Start Time: 2025-01-23 20:00
   - Channel: XXL iOS Channel
4. Click "Create Broadcast"
5. Backend crea broadcast → Retorna broadcastId
6. Frontend redirige a /broadcasts/{broadcastId}
7. Admin ve detalles del broadcast
8. Admin va a crear campaña (/campaigns/create)
9. En sección "Broadcast Context":
   - Marca checkbox "Associate with Broadcast"
   - Selecciona "Barcelona vs PSG" del dropdown
10. Backend asocia campaña con broadcast (guarda match_id)
11. Campaña creada con broadcast asociado
```

### Flujo 2: SDK Usa Broadcast (Validación)

```
1. Usuario abre app → Reproduce video
2. App crea BroadcastContext con broadcastId: "barcelona-psg-2025-01-23"
3. SDK llama: GET /v1/sdk/campaigns?broadcastId=barcelona-psg-2025-01-23
4. Backend valida:
   - ¿Existe broadcast "barcelona-psg-2025-01-23"?
   - ✅ Sí existe → Continuar
   - ❌ No existe → Error 404 "Broadcast not found"
5. Backend busca campañas con match_id = "barcelona-psg-2025-01-23"
6. Retorna campañas asociadas
7. SDK muestra widgets/campañas del broadcast
```

### Flujo 3: Broadcast Termina (Auto-update Status)

```
1. Broadcast tiene startTime: 2025-01-23 20:00, endTime: 2025-01-23 22:00
2. Job/cron job corre cada minuto:
   - Busca broadcasts con status="live" y endTime < NOW()
   - Actualiza status a "ended"
3. SDK intenta usar broadcast terminado:
   - GET /v1/sdk/campaigns?broadcastId=...
   - Backend retorna: {"campaigns": []} (no error, pero sin campañas)
```

---

## ✅ Checklist de Implementación

### Backend
- [ ] Crear tabla `broadcasts` con migración
- [ ] Agregar foreign key `campaigns.match_id → broadcasts.broadcast_id`
- [ ] Implementar `POST /v1/broadcasts`
- [ ] Implementar `GET /v1/broadcasts/{broadcastId}`
- [ ] Implementar `GET /v1/broadcasts` (lista con filtros)
- [ ] Implementar `PUT /v1/broadcasts/{broadcastId}`
- [ ] Implementar `DELETE /v1/broadcasts/{broadcastId}`
- [ ] Modificar `GET /v1/sdk/campaigns` para validar broadcastId
- [ ] Agregar tests unitarios para cada endpoint
- [ ] Agregar tests de integración

### Frontend
- [ ] Agregar ruta `/broadcasts` en router
- [ ] Crear componente `BroadcastsList`
- [ ] Crear componente `BroadcastForm` (crear/editar)
- [ ] Crear componente `BroadcastDetails`
- [ ] Crear componente `BroadcastSelector` (para usar en campañas)
- [ ] Agregar sección "Broadcasts" en menú
- [ ] Integrar selector de broadcast en formulario de campaña
- [ ] Agregar validaciones en frontend
- [ ] Agregar manejo de errores
- [ ] Agregar loading states

### Testing
- [ ] Test: Crear broadcast exitosamente
- [ ] Test: Crear broadcast con broadcastId duplicado → Error 409
- [ ] Test: Crear broadcast sin broadcastId → Auto-generar
- [ ] Test: Listar broadcasts con filtros
- [ ] Test: Actualizar broadcast
- [ ] Test: Eliminar broadcast sin campañas → Éxito
- [ ] Test: Eliminar broadcast con campañas → Error 400
- [ ] Test: SDK usa broadcastId válido → Retorna campañas
- [ ] Test: SDK usa broadcastId inválido → Error 404
- [ ] Test: SDK usa broadcastId terminado → Retorna array vacío

---

## 📝 Notas de Implementación

### Auto-generación de BroadcastId

**Estrategia recomendada:**
```python
def generate_broadcast_id(broadcast_name: str, start_time: datetime, channel_id: int = None) -> str:
    # Opción 1: Usar nombre + fecha
    name_slug = slugify(broadcast_name)  # "Barcelona vs PSG" → "barcelona-vs-psg"
    date_str = start_time.strftime("%Y-%m-%d")  # "2025-01-23"
    base_id = f"{name_slug}-{date_str}"
    
    # Verificar unicidad, agregar sufijo si es necesario
    if broadcast_exists(base_id):
        timestamp = int(start_time.timestamp())
        base_id = f"{name_slug}-{date_str}-{timestamp}"
    
    return base_id
```

### Actualización Automática de Status

**Cron Job recomendado:**
```python
# Ejecutar cada minuto
async def update_broadcast_statuses():
    # Actualizar broadcasts que deberían estar "live"
    await db.execute("""
        UPDATE broadcasts
        SET status = 'live'
        WHERE status = 'upcoming'
          AND start_time <= NOW()
          AND (end_time IS NULL OR end_time >= NOW())
    """)
    
    # Actualizar broadcasts que deberían estar "ended"
    await db.execute("""
        UPDATE broadcasts
        SET status = 'ended'
        WHERE status IN ('upcoming', 'live')
          AND end_time IS NOT NULL
          AND end_time < NOW()
    """)
```

### Validación de BroadcastId en Auto-Discovery

**Código Python ejemplo:**
```python
@router.get("/v1/sdk/campaigns")
async def discover_campaigns(
    apiKey: str = Query(...),
    broadcastId: Optional[str] = None,
    matchId: Optional[str] = None  # Backward compatibility
):
    # Validar API key
    client_app = await validate_api_key(apiKey)
    if not client_app:
        raise HTTPException(401, "Invalid API key")
    
    # Usar broadcastId o matchId (backward compatibility)
    effective_broadcast_id = broadcastId or matchId
    
    # Si se proporciona broadcastId, validar que existe
    if effective_broadcast_id:
        broadcast = await db.get_broadcast(effective_broadcast_id)
        if not broadcast:
            raise HTTPException(
                status_code=404,
                detail=f"Broadcast '{effective_broadcast_id}' not found"
            )
        
        # Si broadcast terminó, retornar array vacío (no error)
        if broadcast.status == "ended":
            return {"campaigns": []}
    
    # Buscar campañas activas
    campaigns = await db.get_active_campaigns(
        broadcast_id=effective_broadcast_id,
        channel_id=client_app.channel_id
    )
    
    return {"campaigns": campaigns}
```

---

## 🎯 Priorización

### Sprint 1 (MVP - Crítico)
1. ✅ Tabla `broadcasts` en base de datos
2. ✅ `POST /v1/broadcasts` - Crear broadcast
3. ✅ `GET /v1/broadcasts/{broadcastId}` - Validar broadcast
4. ✅ Modificar `GET /v1/sdk/campaigns` para validar broadcastId
5. ✅ Página lista de broadcasts (básica)

### Sprint 2 (Importante)
6. ✅ `GET /v1/broadcasts` - Listar con filtros
7. ✅ `PUT /v1/broadcasts/{broadcastId}` - Actualizar
8. ✅ `DELETE /v1/broadcasts/{broadcastId}` - Eliminar
9. ✅ Página crear/editar broadcast
10. ✅ Integración con formulario de campaña

### Sprint 3 (Mejoras)
11. ✅ Auto-generación de broadcastId
12. ✅ Cron job para actualizar status automáticamente
13. ✅ Dashboard UI completo con todas las funcionalidades
14. ✅ Tests completos

---

## 📚 Referencias

- Documentación existente: `BACKEND_CAMPAIGNS_IMPLEMENTATION.md`
- Endpoint actual: `GET /v1/sdk/campaigns` (modificar)
- Tabla existente: `campaigns` (agregar FK)

---

**¡Implementar siguiendo este prompt paso a paso!**

---

## 🔄 ACTUALIZACIÓN: Relaciones Campaign ↔ Broadcast

### Modelo de Datos Actualizado

**Relaciones:**
- **Una Campaña → Múltiples Broadcasts** (uno-a-muchos)
- **Un Broadcast → Una Campaña** (muchos-a-uno)
- **Un Broadcast → Múltiples Polls/Contests** (uno-a-muchos)

**Estructura:**
```
Campaign (1) ──< (N) Broadcasts (1) ──< (N) Polls
                              └───< (N) Contests
```

### Cambios en Base de Datos

#### 1. Modificar Tabla `broadcasts` - Agregar `campaign_id`

```sql
-- Agregar campo campaign_id a broadcasts
ALTER TABLE broadcasts
ADD COLUMN campaign_id INT NULL COMMENT 'ID de la campaña a la que pertenece este broadcast' 'ID de la campaña a la que pertenece este broadcast',
ADD INDEX idx_campaign_id (campaign_id),
ADD CONSTRAINT fk_broadcasts_campaign_id
FOREIGN KEY (campaign_id) REFERENCES campaigns(id)
ON DELETE CASCADE
ON UPDATE CASCADE;
```

**Nota:** 
- `campaign_id` es opcional para permitir broadcasts sin campaña (backward compatibility)
- Si se elimina una campaña, se eliminan todos sus broadcasts (CASCADE)
- Un broadcast puede existir sin campaña, pero si tiene campaña, debe ser válida

#### 2. Mantener `campaigns.match_id` (Backward Compatibility)

```sql
-- campaigns.match_id sigue existiendo para backward compatibility
-- Pero ahora representa el broadcastId "principal" o "por defecto" de la campaña
-- La relación real es: broadcasts.campaign_id → campaigns.id
```

**Lógica:**
- `campaigns.match_id` puede seguir usándose para identificar el broadcast "principal"
- Pero la relación real es `broadcasts.campaign_id → campaigns.id`
- Una campaña puede tener múltiples broadcasts, pero uno puede ser el "principal"

#### 3. Tabla `polls` y `contests` ya tienen `broadcast_id`

```sql
-- Los polls y contests ya tienen broadcast_id
-- No necesitan cambios, solo asegurar que broadcast_id existe en broadcasts
ALTER TABLE polls
ADD CONSTRAINT fk_polls_broadcast_id
FOREIGN KEY (broadcast_id) REFERENCES broadcasts(broadcast_id)
ON DELETE CASCADE;

ALTER TABLE contests
ADD CONSTRAINT fk_contests_broadcast_id
FOREIGN KEY (broadcast_id) REFERENCES broadcasts(broadcast_id)
ON DELETE CASCADE;
```

---

### Cambios en Backend API

#### 1. Modificar POST /v1/broadcasts - Agregar `campaignId`

**Request actualizado:**
```json
POST /v1/broadcasts
{
  "broadcastId": "barcelona-psg-2025-01-23",
  "broadcastName": "Barcelona vs PSG",
  "campaignId": 28,  // NUEVO: ID de la campaña a la que pertenece
  "startTime": "2025-01-23T20:00:00Z",
  "endTime": "2025-01-23T22:00:00Z",
  "channelId": 1,
  "metadata": {...}
}
```

**Validaciones:**
- `campaignId` es opcional (puede crear broadcast sin campaña)
- Si se proporciona `campaignId`, debe existir en tabla `campaigns`
- Si `campaignId` no existe → Error 404

**Response actualizado:**
```json
{
  "success": true,
  "data": {
    "broadcastId": "barcelona-psg-2025-01-23",
    "broadcastName": "Barcelona vs PSG",
    "campaignId": 28,
    "campaignName": "Elkjop Campaign",
    "startTime": "2025-01-23T20:00:00Z",
    "endTime": "2025-01-23T22:00:00Z",
    "channelId": 1,
    "status": "upcoming",
    "pollsCount": 3,
    "contestsCount": 1,
    "metadata": {...},
    "createdAt": "2025-01-20T10:00:00Z"
  }
}
```

#### 2. Modificar GET /v1/broadcasts/{broadcastId} - Incluir información de campaña

**Response actualizado:**
```json
{
  "success": true,
  "data": {
    "broadcastId": "barcelona-psg-2025-01-23",
    "broadcastName": "Barcelona vs PSG",
    "campaignId": 28,
    "campaignName": "Elkjop Campaign",
    "campaignLogo": "https://...",
    "startTime": "2025-01-23T20:00:00Z",
    "endTime": "2025-01-23T22:00:00Z",
    "channelId": 1,
    "status": "upcoming",
    "polls": [
      {
        "id": "poll-1",
        "question": "Who will win?",
        "isActive": true
      }
    ],
    "contests": [
      {
        "id": "contest-1",
        "type": "quiz",
        "isActive": true
      }
    ],
    "metadata": {...}
  }
}
```

#### 3. Nuevo Endpoint: GET /v1/campaigns/{campaignId}/broadcasts

**Propósito:** Obtener todos los broadcasts de una campaña

**Request:**
```
GET /v1/campaigns/28/broadcasts?status=upcoming&page=1&limit=20
Authorization: Bearer {admin_token}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "campaignId": 28,
    "campaignName": "Elkjop Campaign",
    "broadcasts": [
      {
        "broadcastId": "barcelona-psg-2025-01-23",
        "broadcastName": "Barcelona vs PSG",
        "startTime": "2025-01-23T20:00:00Z",
        "endTime": "2025-01-23T22:00:00Z",
        "status": "upcoming",
        "pollsCount": 3,
        "contestsCount": 1
      },
      {
        "broadcastId": "real-madrid-chelsea-2025-01-24",
        "broadcastName": "Real Madrid vs Chelsea",
        "startTime": "2025-01-24T20:00:00Z",
        "status": "upcoming",
        "pollsCount": 2,
        "contestsCount": 0
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 2,
      "totalPages": 1
    }
  }
}
```

#### 4. Modificar GET /v1/sdk/campaigns - Soporte para múltiples broadcasts

**Comportamiento actualizado:**
- Si se proporciona `broadcastId` → Retornar campaña asociada a ese broadcast
- Si NO se proporciona `broadcastId` pero la campaña tiene broadcasts → Retornar campaña con lista de broadcasts

**Response cuando hay broadcastId:**
```json
{
  "campaigns": [
    {
      "campaignId": 28,
      "campaignName": "Elkjop Campaign",
      "broadcastId": "barcelona-psg-2025-01-23",
      "broadcastName": "Barcelona vs PSG",
      "components": [...]
    }
  ]
}
```

**Response cuando NO hay broadcastId (pero campaña tiene broadcasts):**
```json
{
  "campaigns": [
    {
      "campaignId": 28,
      "campaignName": "Elkjop Campaign",
      "broadcasts": [
        {
          "broadcastId": "barcelona-psg-2025-01-23",
          "broadcastName": "Barcelona vs PSG",
          "status": "upcoming"
        },
        {
          "broadcastId": "real-madrid-chelsea-2025-01-24",
          "broadcastName": "Real Madrid vs Chelsea",
          "status": "upcoming"
        }
      ],
      "components": [...]
    }
  ]
}
```

---

### Cambios en Frontend/Dashboard UI

#### 1. Modificar Página de Detalles de Campaña

**Agregar sección "Broadcasts":**
```
┌─────────────────────────────────────┐
│ Campaign Details                    │
│ ...                                 │
│                                      │
│ Broadcasts (2)                      │
│ ┌─────────────────────────────────┐ │
│ │ [Barcelona vs PSG] [View →]    │ │
│ │ [Real Madrid vs Chelsea] [View]│ │
│ │                                  │ │
│ │ [+ Add Broadcast]               │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Funcionalidades:**
- Ver lista de broadcasts de la campaña
- Botón "Add Broadcast" → Crear nuevo broadcast asociado a esta campaña
- Click en broadcast → Ir a página de detalles del broadcast

#### 2. Modificar Página de Crear Broadcast

**Agregar selector de campaña:**
```
┌─────────────────────────────────────┐
│ Create Broadcast                     │
├─────────────────────────────────────┤
│ Campaign*                           │
│ [Select Campaign ▼]                 │
│ [Elkjop Campaign]                   │
│                                      │
│ Broadcast ID*                       │
│ [________________] [Auto-generate]   │
│                                      │
│ Broadcast Name*                     │
│ [Barcelona vs PSG____________]      │
│ ...                                  │
└─────────────────────────────────────┘
```

**Comportamiento:**
- `campaignId` es requerido al crear broadcast
- Dropdown muestra todas las campañas activas
- Al seleccionar campaña → Auto-llenar `channelId` de la campaña (opcional)

#### 3. Modificar Página de Detalles de Broadcast

**Mostrar información de campaña:**
```
┌─────────────────────────────────────┐
│ Barcelona vs PSG                    │
│ barcelona-psg-2025-01-23            │
│                                      │
│ Campaign: [Elkjop Campaign] [View →]│
│                                      │
│ Polls (3)                           │
│ ┌─────────────────────────────────┐ │
│ │ [Who will win?] [View →]        │ │
│ │ [Best player?] [View →]         │ │
│ └─────────────────────────────────┘ │
│                                      │
│ Contests (1)                        │
│ ┌─────────────────────────────────┐ │
│ │ [Quiz: Champions League] [View] │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

### Flujos de Usuario Actualizados

#### Flujo 1: Crear Campaña con Múltiples Broadcasts

```
1. Admin crea campaña "Champions League 2025"
2. Admin va a detalles de campaña
3. Click "Add Broadcast"
4. Crea broadcast "Barcelona vs PSG" asociado a campaña
5. Crea broadcast "Real Madrid vs Chelsea" asociado a campaña
6. Cada broadcast tiene sus propios polls/contests
7. SDK puede usar cualquier broadcastId para obtener la campaña
```

#### Flujo 2: SDK Usa Broadcast de una Campaña

```
1. Usuario reproduce video → broadcastId: "barcelona-psg-2025-01-23"
2. SDK llama: GET /v1/sdk/campaigns?broadcastId=barcelona-psg-2025-01-23
3. Backend busca broadcast por broadcastId
4. Encuentra broadcast → campaignId: 28
5. Retorna campaña 28 con componentes
6. SDK carga polls/contests del broadcast específico
```

#### Flujo 3: Ver Todos los Broadcasts de una Campaña

```
1. Admin va a detalles de campaña "Elkjop Campaign"
2. Ve sección "Broadcasts" con lista de broadcasts
3. Click en broadcast → Ve detalles del broadcast
4. Ve polls/contests específicos de ese broadcast
```

---

### Queries SQL Actualizados

#### Obtener broadcasts de una campaña:
```sql
SELECT 
    b.broadcast_id,
    b.broadcast_name,
    b.start_time,
    b.end_time,
    b.status,
    COUNT(DISTINCT p.id) as polls_count,
    COUNT(DISTINCT c.id) as contests_count
FROM broadcasts b
LEFT JOIN polls p ON p.broadcast_id = b.broadcast_id
LEFT JOIN contests c ON c.broadcast_id = b.broadcast_id
WHERE b.campaign_id = :campaignId
GROUP BY b.broadcast_id
ORDER BY b.start_time ASC;
```

#### Obtener campaña desde broadcastId:
```sql
SELECT 
    c.*,
    b.broadcast_id,
    b.broadcast_name,
    b.start_time,
    b.end_time,
    b.status
FROM broadcasts b
JOIN campaigns c ON c.id = b.campaign_id
WHERE b.broadcast_id = :broadcastId;
```

#### Obtener polls/contests de un broadcast:
```sql
-- Polls
SELECT * FROM polls 
WHERE broadcast_id = :broadcastId 
AND is_active = true
ORDER BY video_start_time ASC;

-- Contests
SELECT * FROM contests 
WHERE broadcast_id = :broadcastId 
AND is_active = true
ORDER BY video_start_time ASC;
```

---

### Checklist Actualizado

#### Base de Datos
- [ ] Agregar `campaign_id` a tabla `broadcasts`
- [ ] Agregar foreign key `broadcasts.campaign_id → campaigns.id`
- [ ] Agregar foreign key `polls.broadcast_id → broadcasts.broadcast_id`
- [ ] Agregar foreign key `contests.broadcast_id → broadcasts.broadcast_id`
- [ ] Mantener `campaigns.match_id` para backward compatibility

#### Backend API
- [ ] Modificar `POST /v1/broadcasts` para incluir `campaignId`
- [ ] Modificar `GET /v1/broadcasts/{broadcastId}` para incluir info de campaña
- [ ] Crear `GET /v1/campaigns/{campaignId}/broadcasts`
- [ ] Modificar `GET /v1/sdk/campaigns` para soportar múltiples broadcasts
- [ ] Actualizar validaciones para `campaignId`

#### Frontend
- [ ] Agregar sección "Broadcasts" en detalles de campaña
- [ ] Modificar formulario crear broadcast para incluir selector de campaña
- [ ] Mostrar información de campaña en detalles de broadcast
- [ ] Mostrar polls/contests en detalles de broadcast

---

**Nota:** Esta actualización contempla la relación bidireccional donde:
- Una campaña puede tener múltiples broadcasts
- Un broadcast pertenece a una campaña
- Cada broadcast tiene sus propios polls/contests

---

## 🚀 ACTUALIZACIÓN: Sistema de Programación y Cola de Mensajería

### Objetivo

Agregar funcionalidades críticas para producción:
1. **Programación de Polls/Contests** - Timing relativo al video
2. **Programación de Productos/Campañas** - Mostrar productos en momentos específicos
3. **Sistema de Cola de Mensajería** - Procesar votos/likes/respuestas de forma asíncrona para evitar cuellos de botella

---

## 📅 FASE 5: Sistema de Programación (Scheduling)

### 5.1 Conceptos Clave

**Programación Relativa al Video:**
- Los polls/contests/productos se activan/desactivan en momentos específicos del video
- Usa timestamps relativos al inicio del broadcast (`videoStartTime`, `videoEndTime`)
- El sistema calcula automáticamente cuándo activar/desactivar basándose en el tiempo actual del video

**Ejemplo:**
```
Broadcast inicia: 2025-01-23 20:00:00
Poll debe aparecer: -690 segundos (11:30 antes del inicio)
Poll debe desaparecer: 0 segundos (al inicio del broadcast)
```

### 5.2 Base de Datos - Campos de Programación

#### Modificar Tabla `polls` (si no existen estos campos)

```sql
ALTER TABLE polls
ADD COLUMN IF NOT EXISTS video_start_time INT NULL COMMENT 'Segundos relativos al inicio del broadcast cuando el poll aparece (negativo = antes del inicio)',
ADD COLUMN IF NOT EXISTS video_end_time INT NULL COMMENT 'Segundos relativos al inicio del broadcast cuando el poll desaparece',
ADD COLUMN IF NOT EXISTS broadcast_start_time TIMESTAMP NULL COMMENT 'Timestamp absoluto del inicio del broadcast (para cálculo)',
ADD COLUMN IF NOT EXISTS scheduled_start_time TIMESTAMP NULL COMMENT 'Timestamp absoluto calculado cuando el poll debe activarse',
ADD COLUMN IF NOT EXISTS scheduled_end_time TIMESTAMP NULL COMMENT 'Timestamp absoluto calculado cuando el poll debe desactivarse',
ADD INDEX idx_scheduled_times (scheduled_start_time, scheduled_end_time),
ADD INDEX idx_video_times (video_start_time, video_end_time);
```

#### Modificar Tabla `contests` (similar)

```sql
ALTER TABLE contests
ADD COLUMN IF NOT EXISTS video_start_time INT NULL,
ADD COLUMN IF NOT EXISTS video_end_time INT NULL,
ADD COLUMN IF NOT EXISTS broadcast_start_time TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS scheduled_start_time TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS scheduled_end_time TIMESTAMP NULL,
ADD INDEX idx_scheduled_times (scheduled_start_time, scheduled_end_time);
```

#### Modificar Tabla `campaign_components` (para productos)

```sql
ALTER TABLE campaign_components
ADD COLUMN IF NOT EXISTS video_start_time INT NULL COMMENT 'Segundos relativos al inicio del broadcast cuando el componente aparece',
ADD COLUMN IF NOT EXISTS video_end_time INT NULL COMMENT 'Segundos relativos al inicio del broadcast cuando el componente desaparece',
ADD COLUMN IF NOT EXISTS scheduled_start_time TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS scheduled_end_time TIMESTAMP NULL,
ADD INDEX idx_scheduled_times (scheduled_start_time, scheduled_end_time);
```

### 5.3 Backend API - Endpoints de Programación

#### 5.3.1 POST /v1/engagement/polls - Crear Poll con Programación

**Request:**
```json
POST /v1/engagement/polls
Content-Type: application/json
Authorization: Bearer {admin_token}

{
  "broadcastId": "barcelona-psg-2025-01-23",
  "question": "Who will win?",
  "options": [
    {"text": "Barcelona", "id": "opt1"},
    {"text": "PSG", "id": "opt2"}
  ],
  "scheduling": {
    "videoStartTime": -690,  // 11:30 antes del inicio (segundos relativos)
    "videoEndTime": 0,       // Al inicio del broadcast
    "broadcastStartTime": "2025-01-23T20:00:00Z"  // Timestamp absoluto del inicio
  },
  "isActive": true
}
```

**Validaciones:**
1. `broadcastId` debe existir en tabla `broadcasts`
2. `broadcastStartTime` debe ser válido ISO 8601
3. `videoStartTime` puede ser negativo (antes del inicio)
4. `videoEndTime` debe ser >= `videoStartTime`
5. Calcular `scheduled_start_time` y `scheduled_end_time` automáticamente:
   ```python
   scheduled_start_time = broadcast_start_time + timedelta(seconds=video_start_time)
   scheduled_end_time = broadcast_start_time + timedelta(seconds=video_end_time)
   ```

**Response:**
```json
{
  "success": true,
  "data": {
    "pollId": "poll-abc123",
    "broadcastId": "barcelona-psg-2025-01-23",
    "question": "Who will win?",
    "options": [...],
    "scheduling": {
      "videoStartTime": -690,
      "videoEndTime": 0,
      "broadcastStartTime": "2025-01-23T20:00:00Z",
      "scheduledStartTime": "2025-01-23T19:48:30Z",
      "scheduledEndTime": "2025-01-23T20:00:00Z"
    },
    "isActive": true,
    "createdAt": "2025-01-20T10:00:00Z"
  }
}
```

#### 5.3.2 PUT /v1/engagement/polls/{pollId} - Actualizar Poll y Programación

**Request:**
```json
PUT /v1/engagement/polls/poll-abc123
{
  "question": "Who will win? (Updated)",
  "scheduling": {
    "videoStartTime": -600,  // Cambiar timing
    "videoEndTime": 300
  }
}
```

**Comportamiento:**
- Recalcular `scheduled_start_time` y `scheduled_end_time` si cambia `scheduling`
- Si el poll ya está activo y se cambia el timing, puede requerir reactivación

#### 5.3.3 GET /v1/engagement/polls/scheduled - Obtener Polls Programados

**Request:**
```
GET /v1/engagement/polls/scheduled?broadcastId=barcelona-psg-2025-01-23&status=upcoming
```

**Query Parameters:**
- `broadcastId` (opcional): Filtrar por broadcast
- `status` (opcional): `upcoming`, `active`, `ended`
- `startDate` (opcional): Filtrar por fecha de inicio programada

**Response:**
```json
{
  "success": true,
  "data": {
    "polls": [
      {
        "pollId": "poll-abc123",
        "question": "Who will win?",
        "scheduledStartTime": "2025-01-23T19:48:30Z",
        "scheduledEndTime": "2025-01-23T20:00:00Z",
        "status": "upcoming",
        "timeUntilStart": 690  // segundos hasta que se active
      }
    ]
  }
}
```

#### 5.3.4 Endpoints Similares para Contests

- `POST /v1/engagement/contests` - Crear contest con programación
- `PUT /v1/engagement/contests/{contestId}` - Actualizar contest y programación
- `GET /v1/engagement/contests/scheduled` - Obtener contests programados

#### 5.3.5 POST /v1/campaigns/{campaignId}/components/{componentId}/schedule - Programar Producto

**Request:**
```json
POST /v1/campaigns/28/components/comp-123/schedule
{
  "broadcastId": "barcelona-psg-2025-01-23",
  "scheduling": {
    "videoStartTime": 1800,  // 30 minutos después del inicio
    "videoEndTime": 3600,    // 1 hora después del inicio
    "broadcastStartTime": "2025-01-23T20:00:00Z"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "componentId": "comp-123",
    "broadcastId": "barcelona-psg-2025-01-23",
    "scheduledStartTime": "2025-01-23T20:30:00Z",
    "scheduledEndTime": "2025-01-23T21:00:00Z",
    "status": "scheduled"
  }
}
```

### 5.4 Cron Job para Activación/Desactivación Automática

**Propósito:** Ejecutar cada minuto para activar/desactivar polls/contests/productos según su programación

**Pseudocódigo:**
```python
# Ejecutar cada minuto
async def process_scheduled_items():
    now = datetime.utcnow()
    
    # Activar polls/contests/productos que deben empezar
    await db.execute("""
        UPDATE polls
        SET is_active = true
        WHERE scheduled_start_time <= :now
          AND scheduled_end_time > :now
          AND is_active = false
    """, {"now": now})
    
    # Desactivar polls/contests/productos que deben terminar
    await db.execute("""
        UPDATE polls
        SET is_active = false
        WHERE scheduled_end_time <= :now
          AND is_active = true
    """, {"now": now})
    
    # Lo mismo para contests y campaign_components
    # ...
    
    # Enviar eventos WebSocket a clientes conectados
    await notify_clients_of_status_changes()
```

**Implementación:**
- Usar cron job (ej: `node-cron`, `APScheduler`, `Celery Beat`)
- Ejecutar cada 30 segundos o 1 minuto
- Logging de todas las activaciones/desactivaciones

---

## 🔄 FASE 6: Sistema de Cola de Mensajería (Message Queue)

### 6.1 Arquitectura Propuesta

**Problema:**
- Miles de usuarios votando simultáneamente puede saturar la base de datos
- Escrituras directas a DB causan cuellos de botella
- Necesitamos procesar votos/likes/respuestas de forma asíncrona

**Solución:**
```
Usuario vota → API recibe voto → Enviar a Queue → Worker procesa → Actualizar DB
```

**Stack Recomendado:**
- **Redis + Bull/BullMQ** (Node.js) o **Celery** (Python) o **Sidekiq** (Ruby)
- **RabbitMQ** (más robusto pero más complejo)
- **Amazon SQS** (si usas AWS)

### 6.2 Estructura de Cola

#### 6.2.1 Colas Necesarias

1. **`vote-queue`** - Procesar votos en polls
2. **`contest-participation-queue`** - Procesar participaciones en contests
3. **`like-queue`** - Procesar likes/reacciones
4. **`analytics-queue`** - Procesar eventos de analytics (menos crítico)

#### 6.2.2 Estructura de Mensaje

**Ejemplo para voto:**
```json
{
  "type": "poll_vote",
  "pollId": "poll-abc123",
  "optionId": "opt1",
  "userId": "user-xyz",
  "broadcastId": "barcelona-psg-2025-01-23",
  "timestamp": "2025-01-23T20:15:30Z",
  "metadata": {
    "deviceId": "device-123",
    "sessionId": "session-456"
  }
}
```

### 6.3 Backend API - Modificar Endpoints para Usar Queue

#### 6.3.1 Modificar POST /v1/engagement/polls/{pollId}/vote

**ANTES (Síncrono - Problemático):**
```python
@router.post("/v1/engagement/polls/{pollId}/vote")
async def vote_poll(pollId: str, vote: VoteRequest):
    # Validar voto
    # Actualizar DB directamente
    poll = await db.get_poll(pollId)
    await db.execute("UPDATE polls SET votes = votes + 1 WHERE id = ?", pollId)
    await db.execute("INSERT INTO poll_votes (...) VALUES (...)")
    return {"success": true}
```

**DESPUÉS (Asíncrono con Queue):**
```python
@router.post("/v1/engagement/polls/{pollId}/vote")
async def vote_poll(pollId: str, vote: VoteRequest):
    # Validar que el poll existe y está activo
    poll = await db.get_poll(pollId)
    if not poll or not poll.is_active:
        raise HTTPException(400, "Poll not found or not active")
    
    # Validar que el usuario no haya votado antes (check rápido en cache)
    cache_key = f"poll_vote:{pollId}:{vote.userId}"
    if await redis.exists(cache_key):
        raise HTTPException(400, "User already voted")
    
    # Marcar como "procesando" en cache (TTL corto para evitar duplicados)
    await redis.setex(cache_key, 60, "processing")  # 60 segundos
    
    # Enviar a cola de mensajería
    job = await vote_queue.enqueue({
        "type": "poll_vote",
        "pollId": pollId,
        "optionId": vote.optionId,
        "userId": vote.userId,
        "broadcastId": vote.broadcastId,
        "timestamp": datetime.utcnow().isoformat(),
        "metadata": vote.metadata
    })
    
    # Retornar inmediatamente (no esperar procesamiento)
    return {
        "success": true,
        "message": "Vote queued for processing",
        "jobId": job.id
    }
```

#### 6.3.2 Worker para Procesar Votos

**Pseudocódigo (Python con Celery):**
```python
from celery import Celery

app = Celery('engagement_worker', broker='redis://localhost:6379/0')

@app.task(name='process_poll_vote')
def process_poll_vote(vote_data):
    """
    Procesa un voto de poll de forma asíncrona
    """
    try:
        poll_id = vote_data['pollId']
        option_id = vote_data['optionId']
        user_id = vote_data['userId']
        
        # Validar nuevamente (doble validación)
        poll = db.get_poll(poll_id)
        if not poll or not poll.is_active:
            logger.warning(f"Poll {poll_id} not active, discarding vote")
            return
        
        # Verificar duplicados en DB (última validación)
        existing_vote = db.get_poll_vote(poll_id, user_id)
        if existing_vote:
            logger.warning(f"Duplicate vote from user {user_id}, discarding")
            return
        
        # Actualizar contadores en DB (usar transacción)
        with db.transaction():
            # Incrementar contador de opción
            db.execute("""
                UPDATE poll_options
                SET vote_count = vote_count + 1
                WHERE poll_id = ? AND option_id = ?
            """, poll_id, option_id)
            
            # Incrementar contador total del poll
            db.execute("""
                UPDATE polls
                SET total_votes = total_votes + 1
                WHERE id = ?
            """, poll_id)
            
            # Guardar voto individual (para analytics)
            db.execute("""
                INSERT INTO poll_votes (poll_id, option_id, user_id, broadcast_id, created_at)
                VALUES (?, ?, ?, ?, ?)
            """, poll_id, option_id, user_id, vote_data['broadcastId'], vote_data['timestamp'])
        
        # Publicar evento WebSocket para actualizar clientes
        websocket_manager.broadcast({
            "type": "poll_vote_processed",
            "pollId": poll_id,
            "optionId": option_id,
            "totalVotes": poll.total_votes + 1
        })
        
        logger.info(f"Vote processed successfully: poll={poll_id}, user={user_id}")
        
    except Exception as e:
        logger.error(f"Error processing vote: {e}", exc_info=True)
        # Reintentar si es error transitorio
        if is_retryable_error(e):
            raise  # Celery reintentará automáticamente
        # Si es error permanente, descartar
```

#### 6.3.3 Configuración de Cola (Redis + Bull/BullMQ)

**Ejemplo con Node.js (BullMQ):**
```javascript
import { Queue, Worker } from 'bullmq';

// Crear cola
const voteQueue = new Queue('vote-queue', {
  connection: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
  },
  defaultJobOptions: {
    attempts: 3,  // Reintentar 3 veces
    backoff: {
      type: 'exponential',
      delay: 2000,  // Empezar con 2 segundos
    },
    removeOnComplete: {
      age: 3600,  // Mantener jobs completados por 1 hora
      count: 1000,  // Máximo 1000 jobs completados
    },
    removeOnFail: {
      age: 86400,  // Mantener jobs fallidos por 24 horas
    },
  },
});

// Crear worker
const voteWorker = new Worker('vote-queue', async (job) => {
  const voteData = job.data;
  
  // Procesar voto (similar al código Python arriba)
  await processPollVote(voteData);
  
}, {
  connection: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
  },
  concurrency: 10,  // Procesar 10 votos simultáneamente
  limiter: {
    max: 100,  // Máximo 100 jobs por segundo
    duration: 1000,
  },
});

// Manejar eventos
voteWorker.on('completed', (job) => {
  console.log(`Job ${job.id} completed`);
});

voteWorker.on('failed', (job, err) => {
  console.error(`Job ${job.id} failed:`, err);
});
```

### 6.4 Base de Datos - Tablas para Tracking

#### Tabla `poll_votes` (para analytics y validación de duplicados)

```sql
CREATE TABLE poll_votes (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    poll_id VARCHAR(255) NOT NULL,
    option_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    broadcast_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_poll_user (poll_id, user_id),  -- Un usuario solo puede votar una vez
    INDEX idx_poll_id (poll_id),
    INDEX idx_user_id (user_id),
    INDEX idx_broadcast_id (broadcast_id),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### Tabla `contest_participations` (similar)

```sql
CREATE TABLE contest_participations (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    contest_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    broadcast_id VARCHAR(255) NOT NULL,
    answer_data JSON NULL,  -- Respuestas del usuario
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_contest_user (contest_id, user_id),
    INDEX idx_contest_id (contest_id),
    INDEX idx_user_id (user_id),
    
    FOREIGN KEY (contest_id) REFERENCES contests(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 6.5 Rate Limiting y Protección

#### Rate Limiting por Usuario

```python
# Usar Redis para rate limiting
async def check_rate_limit(user_id: str, action: str) -> bool:
    key = f"rate_limit:{action}:{user_id}"
    current = await redis.incr(key)
    
    if current == 1:
        await redis.expire(key, 60)  # Ventana de 60 segundos
    
    # Permitir máximo 10 votos por minuto por usuario
    return current <= 10
```

#### Validación de Duplicados en Cache

```python
# Verificar duplicados rápidamente en Redis antes de enviar a queue
async def check_duplicate_vote(poll_id: str, user_id: str) -> bool:
    key = f"poll_vote:{poll_id}:{user_id}"
    exists = await redis.exists(key)
    
    if not exists:
        # Marcar como procesando (TTL 5 minutos)
        await redis.setex(key, 300, "processing")
    
    return exists
```

### 6.6 Monitoreo y Métricas

#### Métricas a Monitorear

1. **Tamaño de cola** - Alertar si crece demasiado
2. **Tiempo de procesamiento** - Latencia promedio de jobs
3. **Tasa de fallos** - Porcentaje de jobs que fallan
4. **Throughput** - Votos procesados por segundo

#### Dashboard de Monitoreo

```python
# Endpoint para métricas de cola
@router.get("/v1/admin/queue/metrics")
async def get_queue_metrics():
    return {
        "voteQueue": {
            "waiting": await vote_queue.get_waiting_count(),
            "active": await vote_queue.get_active_count(),
            "completed": await vote_queue.get_completed_count(),
            "failed": await vote_queue.get_failed_count(),
            "avgProcessingTime": await vote_queue.get_avg_processing_time()
        },
        # ... otras colas
    }
```

---

## 🎨 FASE 7: Frontend UI - Programación y Gestión

### 7.1 UI para Crear/Editar Poll con Programación

**Formulario:**
```
┌─────────────────────────────────────┐
│ Create Poll                         │
├─────────────────────────────────────┤
│ Broadcast*                          │
│ [Select Broadcast ▼]                │
│                                      │
│ Question*                           │
│ [Who will win?____________]         │
│                                      │
│ Options*                            │
│ [Barcelona] [Remove]                │
│ [PSG] [Remove]                      │
│ [+ Add Option]                      │
│                                      │
│ Scheduling                          │
│ ┌─────────────────────────────────┐ │
│ │ Broadcast Start Time*           │ │
│ │ [📅] [2025-01-23] [🕐] [20:00] │ │
│ │                                  │ │
│ │ Video Start Time*                │ │
│ │ [Before start: -11:30] [At start: 0:00] │
│ │                                  │ │
│ │ Video End Time*                  │ │
│ │ [At start: 0:00] [After start: +5:00] │
│ │                                  │ │
│ │ Preview:                         │ │
│ │ Poll appears: Jan 23, 19:48:30  │ │
│ │ Poll disappears: Jan 23, 20:00:00│ │
│ └─────────────────────────────────┘ │
│                                      │
│ [Cancel] [Create Poll]              │
└─────────────────────────────────────┘
```

**Funcionalidades:**
- Selector de broadcast (filtrado por campaña)
- Input para `videoStartTime` y `videoEndTime` (en segundos o formato tiempo)
- Preview de timestamps absolutos calculados
- Validación: `videoEndTime` >= `videoStartTime`

### 7.2 UI para Programar Productos/Campañas

**Formulario similar pero para componentes:**
```
┌─────────────────────────────────────┐
│ Schedule Product                    │
├─────────────────────────────────────┤
│ Broadcast*                          │
│ [Select Broadcast ▼]                │
│                                      │
│ Component*                          │
│ [Select Component ▼]                │
│                                      │
│ Scheduling                          │
│ ┌─────────────────────────────────┐ │
│ │ Show product at: [30:00] minutes│ │
│ │ Hide product at: [60:00] minutes │ │
│ │                                  │ │
│ │ Preview:                         │ │
│ │ Product appears: 20:30:00        │ │
│ │ Product disappears: 21:00:00     │ │
│ └─────────────────────────────────┘ │
│                                      │
│ [Cancel] [Schedule]                 │
└─────────────────────────────────────┘
```

### 7.3 UI para Ver Programación

**Timeline View:**
```
┌─────────────────────────────────────┐
│ Broadcast Timeline                   │
│ Barcelona vs PSG                     │
│                                      │
│ Timeline:                            │
│ ┌─────────────────────────────────┐ │
│ │ -11:30 │ -5:00 │ 0:00 │ +30:00 │ │
│ │   │      │      │      │        │ │
│ │ [Poll 1] [Poll 2] [Product]     │ │
│ │   │      │      │      │        │ │
│ │ Start   │      │      │        │ │
│ └─────────────────────────────────┘ │
│                                      │
│ Scheduled Items:                     │
│ • Poll: "Who will win?" (19:48-20:00)│
│ • Poll: "Best player?" (20:00-20:30)│
│ • Product: "Jersey" (20:30-21:00)   │
│                                      │
│ [Edit Schedule] [Add Item]          │
└─────────────────────────────────────┘
```

---

## ✅ Checklist Actualizado

### Backend - Programación
- [ ] Agregar campos de programación a `polls`
- [ ] Agregar campos de programación a `contests`
- [ ] Agregar campos de programación a `campaign_components`
- [ ] Implementar `POST /v1/engagement/polls` con scheduling
- [ ] Implementar `PUT /v1/engagement/polls/{pollId}` con scheduling
- [ ] Implementar `GET /v1/engagement/polls/scheduled`
- [ ] Implementar endpoints similares para contests
- [ ] Implementar `POST /v1/campaigns/{campaignId}/components/{componentId}/schedule`
- [ ] Crear cron job para activación/desactivación automática
- [ ] Implementar cálculo de timestamps absolutos

### Backend - Cola de Mensajería
- [ ] Configurar Redis/BullMQ/Celery
- [ ] Crear cola `vote-queue`
- [ ] Crear cola `contest-participation-queue`
- [ ] Crear cola `like-queue`
- [ ] Crear cola `analytics-queue`
- [ ] Modificar `POST /v1/engagement/polls/{pollId}/vote` para usar queue
- [ ] Modificar `POST /v1/engagement/contests/{contestId}/participate` para usar queue
- [ ] Crear workers para procesar cada cola
- [ ] Implementar rate limiting por usuario
- [ ] Implementar validación de duplicados en cache
- [ ] Crear tabla `poll_votes` para tracking
- [ ] Crear tabla `contest_participations` para tracking
- [ ] Implementar monitoreo de colas
- [ ] Implementar manejo de errores y reintentos

### Frontend - Programación
- [ ] UI para crear poll con scheduling
- [ ] UI para editar poll y cambiar scheduling
- [ ] UI para crear contest con scheduling
- [ ] UI para programar productos/componentes
- [ ] Timeline view para ver programación
- [ ] Preview de timestamps calculados
- [ ] Validación de scheduling en frontend

---

## 📊 Arquitectura Completa

```
┌─────────────────┐
│   Client SDK    │ ← Usuario vota
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Backend API    │ ← POST /v1/engagement/polls/{id}/vote
└────────┬────────┘
         │
         ├─── Validación rápida (cache)
         │
         ▼
┌─────────────────┐
│  Message Queue  │ ← Redis + BullMQ/Celery
│  (vote-queue)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Worker Process │ ← Procesa votos asíncronamente
└────────┬────────┘
         │
         ├─── Actualizar DB
         │
         ▼
┌─────────────────┐
│  WebSocket      │ ← Notificar clientes de cambios
└─────────────────┘
```

---

## 🔧 Configuración de Producción

### Variables de Entorno

```bash
# Redis (Message Queue)
REDIS_HOST=redis.example.com
REDIS_PORT=6379
REDIS_PASSWORD=your_password
REDIS_DB=0

# Queue Configuration
QUEUE_CONCURRENCY=10  # Workers simultáneos
QUEUE_MAX_JOBS_PER_SECOND=100
QUEUE_RETRY_ATTEMPTS=3
QUEUE_RETRY_DELAY=2000

# Rate Limiting
RATE_LIMIT_VOTES_PER_MINUTE=10
RATE_LIMIT_CONTESTS_PER_MINUTE=5

# Cron Job
CRON_SCHEDULE_CHECK_INTERVAL=30  # segundos
```

### Escalabilidad

**Horizontal Scaling:**
- Múltiples workers procesando la misma cola
- Load balancer para API
- Redis Cluster para alta disponibilidad

**Vertical Scaling:**
- Aumentar `QUEUE_CONCURRENCY` según CPU
- Aumentar `QUEUE_MAX_JOBS_PER_SECOND` según capacidad

---

**Nota:** Esta actualización agrega funcionalidades críticas para producción:
- Programación de polls/contests/productos
- Sistema de cola de mensajería para evitar cuellos de botella
- Rate limiting y protección contra abuso
- Monitoreo y métricas

---

## 🎯 Buenas Prácticas Implementadas

### 1. Separación de Responsabilidades
- ✅ API solo valida y encola (no procesa directamente)
- ✅ Workers procesan de forma asíncrona
- ✅ Cron jobs manejan scheduling independientemente
- ✅ Cada componente tiene una responsabilidad clara

### 2. Escalabilidad
- ✅ Cola de mensajería permite escalar workers horizontalmente
- ✅ Rate limiting previene abuso y sobrecarga
- ✅ Caching reduce carga en DB
- ✅ Load balancing para API servers
- ✅ Redis Cluster para alta disponibilidad

### 3. Confiabilidad
- ✅ Reintentos automáticos en workers (exponential backoff)
- ✅ Validación múltiple (API + Worker + DB)
- ✅ Transacciones en DB para consistencia
- ✅ Logging detallado para debugging
- ✅ Manejo de errores robusto

### 4. Performance
- ✅ Respuesta inmediata al usuario (no espera procesamiento)
- ✅ Procesamiento en batch cuando sea posible
- ✅ Índices en DB para queries rápidas
- ✅ Cache para datos frecuentemente accedidos
- ✅ Optimización de queries SQL

### 5. Monitoreo y Observabilidad
- ✅ Métricas de cola (tamaño, latencia, fallos)
- ✅ Alertas cuando cola crece demasiado
- ✅ Dashboard de métricas
- ✅ Logging estructurado
- ✅ Tracing de requests

### 6. Seguridad
- ✅ Rate limiting por usuario
- ✅ Validación de duplicados
- ✅ Autenticación en todos los endpoints admin
- ✅ Sanitización de inputs
- ✅ Protección contra SQL injection

---

## 📊 Arquitectura Completa Final

```
┌─────────────────────────────────────────┐
│         Client SDK (iOS/Android)        │
│  Usuario vota/like/participa en polls   │
└───────────────┬─────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│      Backend API (Load Balanced)        │
│  • Validación rápida                    │
│  • Rate Limiting (Redis)                │
│  • Cache Check                          │
│  • Encolar en Message Queue            │
└───────────────┬─────────────────────────┘
                │
                ├─── Redis Cache ─────────┐
                │                         │
                ▼                         │
┌─────────────────────────────────────────┐│
│      Message Queue (Redis + BullMQ)     ││
│  • vote-queue                          ││
│  • contest-participation-queue          ││
│  • like-queue                          ││
│  • analytics-queue                     ││
└───────────────┬─────────────────────────┘│
                │                         │
                ▼                         │
┌─────────────────────────────────────────┐│
│      Worker Pool (Múltiples Workers)   ││
│  • Procesar votos asíncronamente        ││
│  • Validación doble                     ││
│  • Actualizar DB (transacciones)        ││
│  • Publicar eventos WebSocket          ││
└───────────────┬─────────────────────────┘│
                │                         │
                ├─── Database ────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│      WebSocket Server                   │
│  • Broadcast cambios a clientes         │
│  • Actualizaciones en tiempo real       │
└───────────────┬─────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│      Cron Job (Scheduler)              │
│  • Activar/desactivar polls programados│
│  • Activar/desactivar productos        │
│  • Ejecutar cada 30 segundos           │
└─────────────────────────────────────────┘
```

---

## 📝 Orden de Implementación Recomendado

### Sprint 1: Fundación (Semana 1-2)
1. Configurar Redis
2. Crear tabla broadcasts
3. Implementar endpoints básicos de broadcasts (POST, GET)
4. Configurar Message Queue básico (Redis + BullMQ/Celery)
5. Crear worker básico para procesar votos

### Sprint 2: Programación Básica (Semana 3-4)
6. Agregar campos de scheduling a polls, contests, campaign_components
7. Implementar cálculo de timestamps absolutos
8. Crear cron job para activación/desactivación
9. Implementar POST /v1/engagement/polls con scheduling
10. Modificar endpoint de votos para usar queue

### Sprint 3: Endpoints Completos (Semana 5-6)
11. Implementar PUT/DELETE para polls/contests
12. Implementar endpoints de resultados
13. Implementar endpoints de scheduling para productos
14. Implementar rate limiting
15. Implementar validación de duplicados

### Sprint 4: Frontend Básico (Semana 7-8)
16. UI para crear/editar broadcasts
17. UI para crear/editar polls con scheduling
18. UI para programar productos
19. Timeline view básico

### Sprint 5: Frontend Avanzado (Semana 9-10)
20. Visualización de resultados en tiempo real
21. Timeline view completo
22. Dashboard de métricas básico
23. Gestión completa de polls/contests

### Sprint 6: Optimizaciones (Semana 11-12)
24. Caching estratégico
25. Optimización de queries
26. Monitoreo completo
27. Tests y documentación

---

## 🔍 Detalles Técnicos Adicionales

### Cálculo de Timestamps Absolutos

Pseudocódigo Python:
```python
from datetime import datetime, timedelta
from dateutil import parser

def calculate_scheduled_times(broadcast_start_time_str, video_start_time, video_end_time):
    broadcast_start = parser.isoparse(broadcast_start_time_str)
    scheduled_start = broadcast_start + timedelta(seconds=video_start_time)
    scheduled_end = broadcast_start + timedelta(seconds=video_end_time)
    return scheduled_start, scheduled_end
```

### Validación de Duplicados - Estrategia Multi-Capa

**Capa 1: Cache (Redis) - Más Rápida**
- Verificación inmediata en Redis antes de encolar

**Capa 2: API - Validación Inicial**
- Check cache + marcar como procesando

**Capa 3: Worker - Validación Final**
- Verificación en DB antes de procesar

### Rate Limiting - Sliding Window

Implementar usando Redis Sorted Sets para ventana deslizante:
- Limpiar requests antiguas automáticamente
- Contar requests en ventana de tiempo
- Retornar error 429 si se excede límite

### WebSocket Events

Eventos a implementar:
- poll_activated - Cuando un poll se activa
- poll_deactivated - Cuando un poll se desactiva
- poll_vote_processed - Cuando se procesa un voto
- component_activated - Cuando un producto se activa
- component_deactivated - Cuando un producto se desactiva

### Manejo de Errores en Workers

- Reintentos automáticos con exponential backoff
- Dead letter queue para jobs que fallan permanentemente
- Logging detallado de todos los errores

### Optimización de Queries SQL

- Usar JOINs en lugar de N+1 queries
- Agregación en DB en lugar de en aplicación
- Índices en campos frecuentemente consultados
- Paginación para listas grandes

---

## 🧪 Testing y Validación

### Tests Unitarios Recomendados

1. Tests de cálculo de timestamps
2. Tests de rate limiting
3. Tests de validación de duplicados
4. Tests de workers

### Tests de Integración

1. Test de flujo completo de voto
2. Test de programación automática
3. Test de escalabilidad (múltiples votos simultáneos)

---

## 📚 Referencias y Recursos

### Documentación Técnica
- Redis: https://redis.io/docs/
- BullMQ: https://docs.bullmq.io/ (Node.js)
- Celery: https://docs.celeryq.dev/ (Python)
- WebSocket: https://developer.mozilla.org/en-US/docs/Web/API/WebSocket

### Patrones de Diseño Aplicados
- Message Queue Pattern
- Rate Limiting Pattern
- Caching Pattern
- Cron Job Pattern
- WebSocket Pattern

---

## ✅ Resumen Final

### Lo que se Implementará:

**Backend:**
- ✅ Sistema completo de gestión de broadcasts
- ✅ API CRUD para polls/contests con programación
- ✅ Sistema de cola de mensajería (Redis + BullMQ/Celery)
- ✅ Rate limiting y protección
- ✅ Cron jobs para activación automática
- ✅ WebSocket para actualizaciones en tiempo real

**Frontend:**
- ✅ Dashboard completo para broadcasts
- ✅ UI para crear/gestionar polls/contests
- ✅ Timeline view para programación
- ✅ Visualización de resultados

**Infraestructura:**
- ✅ Redis para message queue y cache
- ✅ Workers escalables
- ✅ Monitoreo y métricas
- ✅ Configuración de producción

### Beneficios:

1. **Escalabilidad**: Puede manejar miles de usuarios simultáneos
2. **Confiabilidad**: Sistema robusto con reintentos y validaciones
3. **Performance**: Respuesta inmediata, procesamiento asíncrono
4. **Flexibilidad**: Programación precisa de contenido
5. **Observabilidad**: Monitoreo completo del sistema

---

**¡Prompt completo y listo para implementación en producción!**
