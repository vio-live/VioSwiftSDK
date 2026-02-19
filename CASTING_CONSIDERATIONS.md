# Consideraciones Adicionales para Casting - Análisis del Demo Viaplay

**Fecha:** 2026-01-23  
**Basado en:** Demo Viaplay (`ViaplayCastingActiveView.swift`)  
**Comparado con:** Infraestructura Backend (`CURSOR_SDK_INFRASTRUCTURE.md`)

---

## Resumen Ejecutivo

El demo de Viaplay muestra funcionalidades de casting que requieren consideraciones adicionales en el backend. Este documento identifica las brechas y propone mejoras.

---

## 1. Funcionalidades Actuales en el Demo Viaplay

### 1.1 Setup de Broadcast Context
✅ **Implementado en el demo:**
- `setupBroadcastContext()`: Crea `BroadcastContext` desde `Match` model
- Auto-discovery de campañas por `broadcastId`
- Carga de engagement data (`loadEngagement(for: broadcastContext)`)

**Backend actual:** ✅ Soporta auto-discovery via `/v1/sdk/campaigns?broadcastId=xxx`

### 1.2 Video Synchronization
✅ **Implementado en el demo:**
- `VideoSyncManager.shared.setBroadcastStartTime()`: Establece tiempo de inicio del broadcast
- `VideoSyncManager.shared.updateVideoTime()`: Actualiza tiempo de video cada segundo
- Filtrado de polls/contests basado en `videoStartTime`/`videoEndTime`

**Backend actual:** ✅ Campos `video_start_time`, `video_end_time`, `scheduled_start_time`, `scheduled_end_time` existen en DB

### 1.3 WebSocket para Eventos en Tiempo Real
✅ **Implementado en el demo:**
- `WebSocketManager` conecta a WebSocket
- Recibe eventos: `currentPoll`, `currentContest`, `currentProduct`
- Muestra overlays cuando llegan eventos

**Backend actual:** ✅ WebSocket por `campaignId` (`/ws/:campaignId`), emite eventos `poll`, `contest`, `product`

### 1.4 Controles de Playback
✅ **Implementado en el demo:**
- Play/Pause
- Rewind 30s / Forward 30s
- Barra de progreso
- Tiempo actual del video

**Backend actual:** ⚠️ **NO SOPORTADO** - El backend no tiene endpoints para sincronizar controles de playback

---

## 2. Brechas Identificadas

### 2.1 Sincronización de Tiempo de Video entre Dispositivos

**Problema:**
- El demo actualiza `VideoSyncManager` localmente cada segundo
- Si múltiples dispositivos están casteando el mismo broadcast, cada uno tiene su propio tiempo
- No hay sincronización entre dispositivos

**Solución Propuesta:**

#### 2.1.1 Endpoint para Reportar Tiempo de Video

```typescript
POST /v1/engagement/video-time
Authorization: API Key (opcional, para analytics)
Body: {
  broadcastId: "barcelona-psg-2025-01-23",
  videoTime: 300,  // segundos desde inicio
  deviceId?: "device-123",  // opcional
  userId?: "user-abc"  // opcional
}

Response 200: {
  broadcastId: "barcelona-psg-2025-01-23",
  serverTime: "2025-01-23T20:05:00Z",
  videoTime: 300,
  activePolls: [...],  // polls activas en este momento
  activeContests: [...]
}
```

**Uso:**
- El SDK iOS llama este endpoint cada 5-10 segundos durante casting
- El backend puede calcular qué polls/contests deberían estar activos
- El backend puede emitir eventos WebSocket cuando polls/contests se activan/desactivan

#### 2.1.2 WebSocket Event para Video Time Sync

```typescript
// Evento emitido por el backend cuando detecta cambio de tiempo significativo
{
  type: "video_time_sync",
  broadcastId: "barcelona-psg-2025-01-23",
  videoTime: 300,
  serverTime: "2025-01-23T20:05:00Z",
  activePolls: [1, 2],  // IDs de polls activas
  activeContests: [3]
}
```

**Uso:**
- El backend emite este evento cuando detecta que un poll/contest debería activarse/desactivarse
- Los clientes pueden sincronizar su tiempo local con el servidor

---

### 2.2 Endpoint para Obtener Polls/Contests Activas por Tiempo de Video

**Problema:**
- El demo actualmente carga todas las polls/contests y las filtra localmente
- Si el tiempo de video cambia (rewind/forward), necesita recargar datos

**Solución Propuesta:**

```typescript
GET /v1/engagement/polls?broadcastId=xxx&videoTime=300
GET /v1/engagement/contests?broadcastId=xxx&videoTime=300

Response 200:
{
  polls: [
    {
      id: 1,
      question: "...",
      isActive: true,  // activa en videoTime=300
      videoStartTime: 240,
      videoEndTime: 360,
      options: [...]
    }
  ],
  contests: [...],
  currentVideoTime: 300,
  broadcastStartTime: "2025-01-23T20:00:00Z"
}
```

**Uso:**
- El SDK puede llamar este endpoint cuando el usuario hace rewind/forward
- El backend filtra automáticamente basado en `videoTime`

---

### 2.3 WebSocket por Broadcast ID (no solo Campaign ID)

**Problema Actual:**
- WebSocket se conecta por `campaignId`: `/ws/:campaignId`
- Pero los eventos de engagement (polls, contests) están asociados a `broadcastId`
- Si una campaña tiene múltiples broadcasts, todos los clientes reciben eventos de todos los broadcasts

**Solución Propuesta:**

#### Opción A: WebSocket por Broadcast ID

```typescript
// Nueva ruta WebSocket
ws://HOST/ws/broadcast/:broadcastId

// Eventos específicos del broadcast
{
  type: "poll_activated",
  broadcastId: "barcelona-psg-2025-01-23",
  pollId: 1,
  videoTime: 300
}
```

#### Opción B: Filtrar eventos por Broadcast ID en el cliente

```typescript
// Mantener `/ws/:campaignId` pero incluir broadcastId en eventos
{
  type: "poll_activated",
  campaignId: 1,
  broadcastId: "barcelona-psg-2025-01-23",  // nuevo campo
  pollId: 1,
  videoTime: 300
}
```

**Recomendación:** Opción B (más simple, no requiere cambios grandes)

---

### 2.4 Eventos de Activación/Desactivación Basados en Video Time

**Problema:**
- El scheduler actual activa/desactiva polls/contests basado en `scheduled_start_time`/`scheduled_end_time` (tiempo absoluto)
- Pero durante casting, el usuario puede hacer rewind/forward, cambiando el tiempo de video relativo
- Necesitamos eventos cuando el tiempo de video cruza los umbrales `videoStartTime`/`videoEndTime`

**Solución Propuesta:**

```typescript
// Nuevos eventos WebSocket
{
  type: "poll_activated_by_video_time",
  broadcastId: "barcelona-psg-2025-01-23",
  pollId: 1,
  videoTime: 300,
  videoStartTime: 300,
  videoEndTime: 600
}

{
  type: "poll_deactivated_by_video_time",
  broadcastId: "barcelona-psg-2025-01-23",
  pollId: 1,
  videoTime: 601,
  videoStartTime: 300,
  videoEndTime: 600
}
```

**Implementación:**
- Cuando el SDK reporta `videoTime` via `POST /v1/engagement/video-time`
- El backend calcula qué polls/contests deberían activarse/desactivarse
- Emite eventos WebSocket si hay cambios

---

### 2.5 Manejo de Dispositivos Múltiples Casteando el Mismo Broadcast

**Problema:**
- Si múltiples usuarios castean el mismo broadcast, cada uno tiene su propio tiempo de video
- Los votos/participaciones deberían ser consistentes independientemente del dispositivo

**Solución Propuesta:**

#### 2.5.1 Tracking de Dispositivos Activos

```typescript
// Nuevo endpoint (opcional, para analytics)
POST /v1/engagement/casting/start
Body: {
  broadcastId: "barcelona-psg-2025-01-23",
  deviceId: "device-123",
  userId?: "user-abc",
  deviceName?: "Living TV"
}

POST /v1/engagement/casting/stop
Body: {
  broadcastId: "barcelona-psg-2025-01-23",
  deviceId: "device-123"
}
```

#### 2.5.2 Validación de Votos Basada en Tiempo de Video

```typescript
// Al votar, validar que el poll está activo en el tiempo de video actual
POST /v1/engagement/polls/:pollId/vote
Body: {
  optionId: 1,
  userId: "user-abc",
  broadcastId: "barcelona-psg-2025-01-23",
  videoTime: 350  // nuevo campo opcional
}

// Backend valida:
// - Si videoTime está dentro de videoStartTime..videoEndTime
// - Si no, retorna 400 Bad Request: "Poll is not active at this video time"
```

---

### 2.6 Sincronización de Estado de Broadcast (Live vs Recorded)

**Problema:**
- El demo asume que el broadcast está "LIVE" siempre
- Pero en realidad, el usuario puede estar viendo un broadcast grabado (VOD)
- El backend necesita distinguir entre:
  - **Live broadcast:** Tiempo de video = tiempo real desde `start_time`
  - **Recorded/VOD:** Tiempo de video = posición en el video grabado

**Solución Propuesta:**

```typescript
// Nuevo campo en BroadcastContext y endpoints
GET /v1/engagement/polls?broadcastId=xxx&videoTime=300&isLive=true

// O mejor, detectar automáticamente:
// - Si videoTime está cerca del tiempo real desde start_time → LIVE
// - Si videoTime está muy atrás → VOD/Recorded
```

---

## 3. Cambios Propuestos en el Backend

### 3.1 Nuevos Endpoints

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/v1/engagement/video-time` | POST | Reportar tiempo de video actual |
| `/v1/engagement/polls?broadcastId=xxx&videoTime=300` | GET | Obtener polls activas en tiempo de video específico |
| `/v1/engagement/contests?broadcastId=xxx&videoTime=300` | GET | Obtener contests activas en tiempo de video específico |
| `/v1/engagement/casting/start` | POST | Registrar inicio de casting (opcional) |
| `/v1/engagement/casting/stop` | POST | Registrar fin de casting (opcional) |

### 3.2 Nuevos Eventos WebSocket

| Evento | Cuándo se emite |
|--------|----------------|
| `video_time_sync` | Cuando el backend detecta cambio de tiempo significativo |
| `poll_activated_by_video_time` | Cuando un poll se activa por tiempo de video |
| `poll_deactivated_by_video_time` | Cuando un poll se desactiva por tiempo de video |
| `contest_activated_by_video_time` | Cuando un contest se activa por tiempo de video |
| `contest_deactivated_by_video_time` | Cuando un contest se desactiva por tiempo de video |

### 3.3 Modificaciones a Endpoints Existentes

#### 3.3.1 POST `/v1/engagement/polls/:pollId/vote`

**Agregar validación opcional:**

```typescript
Body: {
  optionId: 1,
  userId: "user-abc",
  broadcastId: "barcelona-psg-2025-01-23",
  videoTime?: 350  // nuevo campo opcional
}

// Validación:
if (videoTime !== undefined) {
  const poll = await getPoll(pollId);
  if (poll.videoStartTime && poll.videoEndTime) {
    if (videoTime < poll.videoStartTime || videoTime >= poll.videoEndTime) {
      return 400 Bad Request: "Poll is not active at this video time";
    }
  }
}
```

#### 3.3.2 GET `/v1/engagement/polls?broadcastId=xxx`

**Agregar filtrado por videoTime:**

```typescript
Query params:
  broadcastId: string (requerido)
  videoTime?: number (opcional, segundos)

// Si videoTime está presente:
// - Filtrar polls donde videoStartTime <= videoTime < videoEndTime
// - Retornar solo polls activas en ese momento
```

---

## 4. Cambios Propuestos en el SDK iOS

### 4.1 Nuevo Método en EngagementManager

```swift
/// Reporta el tiempo de video actual al backend
/// Debe llamarse periódicamente durante casting (cada 5-10 segundos)
func reportVideoTime(_ time: Int, for broadcastContext: BroadcastContext) async {
    // POST /v1/engagement/video-time
    // Body: { broadcastId, videoTime }
}
```

### 4.2 Modificación en VideoSyncManager

```swift
/// Actualiza el tiempo de video y reporta al backend si está en modo casting
func updateVideoTime(_ time: Int, reportToBackend: Bool = false) {
    currentVideoTime = time
    
    if reportToBackend {
        // Reportar al backend cada 5-10 segundos (throttle)
        Task {
            await EngagementManager.shared.reportVideoTime(time, for: currentBroadcastContext)
        }
    }
}
```

### 4.3 Manejo de Eventos WebSocket Nuevos

```swift
// En WebSocketManager, agregar handlers para:
- video_time_sync
- poll_activated_by_video_time
- poll_deactivated_by_video_time
- contest_activated_by_video_time
- contest_deactivated_by_video_time
```

---

## 5. Priorización

### Alta Prioridad (Crítico para Casting)
1. ✅ **Endpoint para reportar video time** (`POST /v1/engagement/video-time`)
2. ✅ **Filtrado de polls/contests por videoTime** (`GET /v1/engagement/polls?videoTime=xxx`)
3. ✅ **Eventos WebSocket de activación/desactivación por video time**

### Media Prioridad (Mejoras UX)
4. ⚠️ **WebSocket por broadcastId** (o filtrar eventos por broadcastId)
5. ⚠️ **Validación de votos basada en videoTime**

### Baja Prioridad (Nice to Have)
6. 📋 **Tracking de dispositivos activos** (`/v1/engagement/casting/start|stop`)
7. 📋 **Distinción Live vs VOD** (puede detectarse automáticamente)

---

## 6. Implementación Sugerida

### Fase 1: Endpoints Básicos
- Implementar `POST /v1/engagement/video-time`
- Modificar `GET /v1/engagement/polls` para aceptar `videoTime` query param
- Modificar `GET /v1/engagement/contests` para aceptar `videoTime` query param

### Fase 2: Eventos WebSocket
- Emitir `poll_activated_by_video_time` cuando se detecta activación
- Emitir `poll_deactivated_by_video_time` cuando se detecta desactivación
- Emitir `video_time_sync` periódicamente (cada 30 segundos)

### Fase 3: Validaciones
- Validar `videoTime` al votar/participar
- Filtrar eventos WebSocket por `broadcastId` si el cliente lo solicita

---

## 7. Ejemplo de Flujo Completo

### Escenario: Usuario castea broadcast y hace rewind

```
1. Usuario inicia casting → ViaplayCastingActiveView aparece
2. SDK: setupBroadcastContext() → descubre campañas
3. SDK: setupVideoSync() → establece broadcastStartTime
4. SDK: startVideoTimeTimer() → actualiza videoTime cada segundo
5. SDK: reportVideoTime(300) → POST /v1/engagement/video-time { videoTime: 300 }
6. Backend: Calcula polls activas en videoTime=300
7. Backend: Emite WebSocket event "poll_activated_by_video_time" si hay cambios
8. SDK: Recibe evento → muestra poll en overlay
9. Usuario hace rewind → videoTime cambia a 150
10. SDK: reportVideoTime(150) → POST /v1/engagement/video-time { videoTime: 150 }
11. Backend: Detecta que poll se desactivó → emite "poll_deactivated_by_video_time"
12. SDK: Oculta poll del overlay
```

---

## 8. Notas Adicionales

- **Throttling:** El SDK debe hacer throttle de `reportVideoTime()` para no saturar el backend (máximo cada 5-10 segundos)
- **Offline Support:** Si el dispositivo está offline, el SDK debe seguir funcionando con filtrado local basado en `videoStartTime`/`videoEndTime`
- **Backward Compatibility:** Todos los cambios deben ser opcionales y no romper clientes existentes que no usan casting

---

**Fin del Documento**
