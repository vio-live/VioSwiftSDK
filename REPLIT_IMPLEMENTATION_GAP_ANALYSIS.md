# Análisis: Qué Falta en la Implementación de Replit

## 📊 Resumen Ejecutivo

Replit ha implementado una base sólida del sistema, pero faltan funcionalidades críticas que están especificadas en nuestro prompt. Este documento identifica las brechas y qué falta implementar.

---

## ✅ LO QUE REplit YA IMPLEMENTÓ

### 1. Base de Datos
- ✅ Tabla `broadcasts` con campos básicos
- ✅ Tabla `polls` con estructura básica
- ✅ Tabla `poll_options` y `poll_votes`
- ✅ Tabla `contests` y `contest_participations`
- ✅ Relación `broadcasts.campaign_id → campaigns.id`
- ✅ Relación `polls.broadcast_id → broadcasts.broadcast_id`

### 2. Backend API - Broadcasts
- ✅ `POST /v1/broadcasts` - Crear broadcast
- ✅ `GET /v1/broadcasts` - Listar broadcasts
- ✅ `GET /v1/broadcasts/:broadcastId` - Obtener detalles
- ✅ `PUT /v1/broadcasts/:broadcastId` - Actualizar
- ✅ `DELETE /v1/broadcasts/:broadcastId` - Eliminar
- ✅ `GET /v1/campaigns/:campaignId/broadcasts` - Broadcasts de campaña

### 3. Backend API - Polls/Contests
- ✅ `POST /v1/broadcasts/:broadcastId/polls` - Crear poll
- ✅ `GET /v1/broadcasts/:broadcastId/polls` - Listar polls
- ✅ `PUT /v1/polls/:pollId` - Actualizar poll
- ✅ `DELETE /v1/polls/:pollId` - Eliminar poll
- ✅ `GET /v1/polls/:pollId/results` - Resultados
- ✅ Similar para contests

### 4. Scheduler Básico
- ✅ Cron job cada 1 minuto
- ✅ Actualiza status de broadcasts (`upcoming` → `live` → `ended`)
- ✅ Activa/desactiva componentes programados

### 5. WebSocket Events
- ✅ `poll_results_updated` - Cuando se vota
- ✅ `broadcast_status_changed` - Cuando cambia status
- ✅ Eventos de campaña y componentes

---

## ❌ LO QUE FALTA (Crítico)

### 1. ❌ **Campos de Programación Relativa al Video**

**Lo que Replit tiene:**
- `polls.start_time` y `polls.end_time` (timestamps absolutos)
- `contests.start_time` y `contests.end_time` (timestamps absolutos)
- `campaign_components.scheduled_time` y `end_time` (timestamps absolutos)

**Lo que falta:**
- ❌ `polls.video_start_time` (INT - segundos relativos al inicio del broadcast)
- ❌ `polls.video_end_time` (INT - segundos relativos)
- ❌ `polls.broadcast_start_time` (TIMESTAMP - para cálculo)
- ❌ `polls.scheduled_start_time` (TIMESTAMP - calculado automáticamente)
- ❌ `polls.scheduled_end_time` (TIMESTAMP - calculado automáticamente)
- ❌ Lo mismo para `contests`
- ❌ Lo mismo para `campaign_components`

**Impacto:**
- No se puede programar polls/contests/productos relativos al tiempo del video
- No hay sincronización con el timeline del video
- Los usuarios no pueden programar "mostrar poll 5 minutos antes del inicio"

**Nota:** El SDK Swift YA soporta `videoStartTime` y `videoEndTime` en los modelos, pero el backend no los acepta ni calcula.

---

### 2. ❌ **Sistema de Cola de Mensajería (Message Queue)**

**Lo que Replit tiene:**
- ❌ Nada - Los votos se procesan síncronamente

**Lo que falta:**
- ❌ Redis configurado
- ❌ BullMQ/Celery/Sidekiq instalado
- ❌ Cola `vote-queue`
- ❌ Cola `contest-participation-queue`
- ❌ Workers para procesar votos asíncronamente
- ❌ Modificación de `POST /v1/engagement/polls/:pollId/vote` para usar queue

**Impacto:**
- **CRÍTICO**: Con muchos usuarios votando simultáneamente, la DB se saturará
- Los endpoints de votos son síncronos (lento)
- No hay protección contra picos de tráfico
- No hay rate limiting efectivo

**Código actual (problemático):**
```typescript
// Replit actualmente hace esto (síncrono):
POST /v1/engagement/polls/:pollId/vote
→ Validar
→ Actualizar DB directamente
→ Retornar respuesta
```

**Debería ser:**
```typescript
// Debería ser así (asíncrono):
POST /v1/engagement/polls/:pollId/vote
→ Validar rápidamente
→ Encolar en Redis queue
→ Retornar inmediatamente
→ Worker procesa en background
```

---

### 3. ❌ **Rate Limiting por Usuario**

**Lo que Replit tiene:**
- ❌ Solo validación de duplicados en DB (lento)

**Lo que falta:**
- ❌ Rate limiting usando Redis
- ❌ Sliding window rate limiter
- ❌ Límites configurables por acción (votos/minuto, participaciones/minuto)
- ❌ Validación rápida en cache antes de encolar

**Impacto:**
- Usuarios pueden hacer spam de votos
- No hay protección contra abuso
- Validación de duplicados es lenta (consulta DB cada vez)

---

### 4. ❌ **Cálculo Automático de Timestamps Absolutos**

**Lo que Replit tiene:**
- Usuario debe proporcionar `start_time` y `end_time` absolutos

**Lo que falta:**
- ❌ Cálculo automático de `scheduled_start_time` y `scheduled_end_time` desde `video_start_time` y `video_end_time`
- ❌ Endpoint que acepte tiempos relativos al video
- ❌ Validación de que `broadcastStartTime` existe

**Ejemplo de lo que falta:**
```json
// Request debería poder ser así:
POST /v1/broadcasts/:broadcastId/polls
{
  "question": "Who will win?",
  "options": [...],
  "scheduling": {
    "videoStartTime": -690,  // 11:30 antes del inicio
    "videoEndTime": 0,       // Al inicio
    "broadcastStartTime": "2025-01-23T20:00:00Z"
  }
}

// Backend debería calcular:
scheduled_start_time = broadcastStartTime + videoStartTime
scheduled_end_time = broadcastStartTime + videoEndTime
```

---

### 5. ❌ **Cron Job para Activación/Desactivación de Polls/Contests**

**Lo que Replit tiene:**
- ✅ Cron job para broadcasts (status changes)
- ✅ Cron job para componentes (`scheduled_time`)

**Lo que falta:**
- ❌ Cron job para activar/desactivar polls según `scheduled_start_time` y `scheduled_end_time`
- ❌ Cron job para activar/desactivar contests según scheduling
- ❌ Emisión de eventos WebSocket cuando polls/contests se activan/desactivan

**Código que falta:**
```typescript
// En scheduler.ts, agregar:
async function processScheduledPolls() {
  const now = new Date();
  
  // Activar polls que deben empezar
  await db.execute(`
    UPDATE polls
    SET is_active = true
    WHERE scheduled_start_time <= $1
      AND scheduled_end_time > $1
      AND is_active = false
  `, [now]);
  
  // Desactivar polls que deben terminar
  await db.execute(`
    UPDATE polls
    SET is_active = false
    WHERE scheduled_end_time <= $1
      AND is_active = true
  `, [now]);
  
  // Emitir eventos WebSocket
  // ...
}
```

---

### 6. ❌ **Endpoints de Scheduling para Productos/Componentes**

**Lo que Replit tiene:**
- `campaign_components.scheduled_time` y `end_time` (absolutos)

**Lo que falta:**
- ❌ Endpoint `POST /v1/campaigns/:campaignId/components/:componentId/schedule`
- ❌ Campos `video_start_time` y `video_end_time` en `campaign_components`
- ❌ Cálculo automático de `scheduled_time` desde tiempos relativos

---

### 7. ❌ **Validación de BroadcastId en Auto-Discovery**

**Lo que Replit tiene:**
- `GET /v1/sdk/campaigns?apiKey=xxx&matchId=xxx` funciona

**Lo que falta:**
- ❌ Validación de que `broadcastId` existe antes de buscar campañas
- ❌ Error 404 claro si `broadcastId` no existe
- ❌ Retornar array vacío si broadcast existe pero está `ended`

**Código que falta:**
```typescript
// En GET /v1/sdk/campaigns
if (broadcastId) {
  const broadcast = await db.getBroadcast(broadcastId);
  if (!broadcast) {
    throw new HTTPException(404, `Broadcast '${broadcastId}' not found`);
  }
  if (broadcast.status === 'ended') {
    return { campaigns: [] };  // No error, pero sin campañas
  }
}
```

---

### 8. ❌ **Monitoreo de Colas**

**Lo que falta:**
- ❌ Endpoint `/v1/admin/queue/metrics`
- ❌ Métricas de tamaño de cola
- ❌ Métricas de latencia de procesamiento
- ❌ Métricas de tasa de fallos
- ❌ Alertas cuando cola crece demasiado

---

### 9. ⚠️ **Frontend UI - Programación**

**Lo que Replit tiene:**
- ✅ UI básica para crear polls/contests
- ✅ UI para listar broadcasts

**Lo que falta:**
- ❌ UI para programar polls con tiempos relativos al video
- ❌ UI para programar productos/componentes
- ❌ Timeline view para ver programación completa
- ❌ Preview de timestamps calculados
- ❌ Inputs para `videoStartTime` y `videoEndTime`

---

### 10. ⚠️ **Optimizaciones de Performance**

**Lo que falta:**
- ❌ Caching de polls/contests activos en Redis
- ❌ Caching de resultados de polls (TTL corto)
- ❌ Validación de duplicados en cache antes de DB
- ❌ Optimización de queries SQL (JOINs en lugar de N+1)

---

## 📋 Checklist Detallado: Qué Falta

### Backend - Programación Relativa al Video

#### Base de Datos
- [ ] Agregar `video_start_time INT` a tabla `polls`
- [ ] Agregar `video_end_time INT` a tabla `polls`
- [ ] Agregar `broadcast_start_time TIMESTAMP` a tabla `polls`
- [ ] Agregar `scheduled_start_time TIMESTAMP` a tabla `polls`
- [ ] Agregar `scheduled_end_time TIMESTAMP` a tabla `polls`
- [ ] Agregar índices `idx_scheduled_times` y `idx_video_times` en `polls`
- [ ] Lo mismo para tabla `contests`
- [ ] Agregar `video_start_time` y `video_end_time` a `campaign_components`

#### Backend API
- [ ] Modificar `POST /v1/broadcasts/:broadcastId/polls` para aceptar `scheduling` object
- [ ] Implementar cálculo de `scheduled_start_time` y `scheduled_end_time`
- [ ] Modificar `PUT /v1/polls/:pollId` para recalcular scheduling si cambia
- [ ] Crear endpoint `GET /v1/engagement/polls/scheduled` para polls programados
- [ ] Lo mismo para contests
- [ ] Crear endpoint `POST /v1/campaigns/:campaignId/components/:componentId/schedule`

#### Cron Job
- [ ] Agregar función `processScheduledPolls()` al scheduler
- [ ] Agregar función `processScheduledContests()` al scheduler
- [ ] Agregar función `processScheduledComponents()` al scheduler
- [ ] Emitir eventos WebSocket cuando polls/contests se activan/desactivan

---

### Backend - Sistema de Cola de Mensajería

#### Infraestructura
- [ ] Instalar Redis (si no está instalado)
- [ ] Instalar BullMQ (Node.js) o Celery (Python)
- [ ] Configurar conexión a Redis
- [ ] Crear cola `vote-queue`
- [ ] Crear cola `contest-participation-queue`
- [ ] Crear cola `like-queue` (si se usa)
- [ ] Crear cola `analytics-queue` (opcional)

#### Workers
- [ ] Crear worker para procesar `vote-queue`
- [ ] Crear worker para procesar `contest-participation-queue`
- [ ] Implementar validación doble en workers
- [ ] Implementar transacciones en DB
- [ ] Implementar reintentos con exponential backoff
- [ ] Implementar dead letter queue para jobs fallidos

#### Modificar Endpoints
- [ ] Modificar `POST /v1/engagement/polls/:pollId/vote` para usar queue
- [ ] Modificar `POST /v1/engagement/contests/:contestId/participate` para usar queue
- [ ] Agregar validación rápida en cache antes de encolar
- [ ] Retornar respuesta inmediata (no esperar procesamiento)

#### Rate Limiting
- [ ] Implementar `RateLimiter` usando Redis Sorted Sets
- [ ] Agregar rate limiting a endpoint de votos
- [ ] Agregar rate limiting a endpoint de participaciones
- [ ] Configurar límites por variable de entorno

#### Validación de Duplicados
- [ ] Implementar check rápido en Redis cache
- [ ] Marcar como "procesando" en cache (TTL corto)
- [ ] Validación final en worker antes de procesar

---

### Backend - Validación y Mejoras

- [ ] Modificar `GET /v1/sdk/campaigns` para validar `broadcastId`
- [ ] Retornar error 404 si `broadcastId` no existe
- [ ] Retornar array vacío si broadcast está `ended`
- [ ] Agregar monitoreo de colas (`/v1/admin/queue/metrics`)
- [ ] Implementar caching de polls/contests activos
- [ ] Optimizar queries SQL (usar JOINs)

---

### Frontend - UI de Programación

- [ ] Agregar sección "Scheduling" en formulario de crear poll
- [ ] Inputs para `videoStartTime` y `videoEndTime`
- [ ] Selector de `broadcastStartTime`
- [ ] Preview de timestamps absolutos calculados
- [ ] Validación: `videoEndTime` >= `videoStartTime`
- [ ] Lo mismo para formulario de crear contest
- [ ] UI para programar productos/componentes
- [ ] Timeline view para ver programación completa
- [ ] Visualización de items programados en timeline

---

## 🎯 Priorización: Qué Implementar Primero

### 🔴 Crítico (Sprint 1)
1. **Sistema de Cola de Mensajería**
   - Sin esto, el sistema se caerá con muchos usuarios
   - Implementar Redis + BullMQ
   - Modificar endpoints de votos para usar queue
   - Crear workers básicos

2. **Rate Limiting**
   - Protección básica contra abuso
   - Implementar usando Redis

3. **Validación de BroadcastId**
   - Modificar auto-discovery para validar
   - Retornar errores claros

### 🟡 Importante (Sprint 2)
4. **Campos de Programación Relativa al Video**
   - Agregar campos a DB
   - Implementar cálculo de timestamps
   - Modificar endpoints para aceptar scheduling

5. **Cron Job para Polls/Contests**
   - Activar/desactivar automáticamente
   - Emitir eventos WebSocket

### 🟢 Opcional (Sprint 3)
6. **Frontend UI de Programación**
   - Timeline view
   - Formularios mejorados

7. **Monitoreo y Optimizaciones**
   - Métricas de cola
   - Caching estratégico

---

## 📊 Comparación: Replit vs Nuestro Prompt

| Feature | Replit | Nuestro Prompt | Estado |
|---------|--------|----------------|--------|
| Tabla broadcasts | ✅ | ✅ | ✅ Completo |
| API CRUD broadcasts | ✅ | ✅ | ✅ Completo |
| Crear polls/contests | ✅ | ✅ | ✅ Completo |
| Programación relativa al video | ❌ | ✅ | ❌ Falta |
| Sistema de cola de mensajería | ❌ | ✅ | ❌ Falta |
| Rate limiting | ❌ | ✅ | ❌ Falta |
| Cron job para polls/contests | ❌ | ✅ | ❌ Falta |
| Validación broadcastId | ❌ | ✅ | ❌ Falta |
| Timeline UI | ❌ | ✅ | ❌ Falta |
| Monitoreo de colas | ❌ | ✅ | ❌ Falta |

---

## 🔧 Código Específico que Falta

### 1. Migración de Base de Datos

```sql
-- Agregar campos de programación a polls
ALTER TABLE polls
ADD COLUMN video_start_time INT NULL,
ADD COLUMN video_end_time INT NULL,
ADD COLUMN broadcast_start_time TIMESTAMP NULL,
ADD COLUMN scheduled_start_time TIMESTAMP NULL,
ADD COLUMN scheduled_end_time TIMESTAMP NULL,
ADD INDEX idx_scheduled_times (scheduled_start_time, scheduled_end_time),
ADD INDEX idx_video_times (video_start_time, video_end_time);

-- Lo mismo para contests
ALTER TABLE contests
ADD COLUMN video_start_time INT NULL,
ADD COLUMN video_end_time INT NULL,
ADD COLUMN broadcast_start_time TIMESTAMP NULL,
ADD COLUMN scheduled_start_time TIMESTAMP NULL,
ADD COLUMN scheduled_end_time TIMESTAMP NULL,
ADD INDEX idx_scheduled_times (scheduled_start_time, scheduled_end_time);

-- Para campaign_components
ALTER TABLE campaign_components
ADD COLUMN video_start_time INT NULL,
ADD COLUMN video_end_time INT NULL,
ADD COLUMN scheduled_start_time TIMESTAMP NULL,
ADD COLUMN scheduled_end_time TIMESTAMP NULL,
ADD INDEX idx_scheduled_times (scheduled_start_time, scheduled_end_time);
```

### 2. Configuración de Redis y BullMQ

```typescript
// Instalar: npm install bullmq ioredis

// server/queue.ts
import { Queue, Worker } from 'bullmq';
import Redis from 'ioredis';

const redisConnection = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD,
});

export const voteQueue = new Queue('vote-queue', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000,
    },
  },
});

export const voteWorker = new Worker('vote-queue', async (job) => {
  const voteData = job.data;
  await processPollVote(voteData);
}, {
  connection: redisConnection,
  concurrency: 10,
  limiter: {
    max: 100,
    duration: 1000,
  },
});
```

### 3. Modificar Endpoint de Votos

```typescript
// ANTES (síncrono - problemático):
router.post('/v1/engagement/polls/:pollId/vote', async (req, res) => {
  const { pollId } = req.params;
  const { optionId, userId, broadcastId } = req.body;
  
  // Validar y actualizar DB directamente
  await db.execute('UPDATE polls SET total_votes = total_votes + 1 WHERE id = ?', [pollId]);
  await db.execute('INSERT INTO poll_votes (...) VALUES (...)');
  
  res.json({ success: true });
});

// DESPUÉS (asíncrono con queue):
router.post('/v1/engagement/polls/:pollId/vote', async (req, res) => {
  const { pollId } = req.params;
  const { optionId, userId, broadcastId } = req.body;
  
  // Validación rápida
  const poll = await db.getPoll(pollId);
  if (!poll || !poll.is_active) {
    return res.status(400).json({ error: 'Poll not found or not active' });
  }
  
  // Check duplicados en cache (rápido)
  const cacheKey = `poll_vote:${pollId}:${userId}`;
  if (await redis.exists(cacheKey)) {
    return res.status(409).json({ error: 'User already voted' });
  }
  
  // Marcar como procesando
  await redis.setex(cacheKey, 300, 'processing');
  
  // Encolar
  await voteQueue.add('process-vote', {
    pollId,
    optionId,
    userId,
    broadcastId,
    timestamp: new Date().toISOString(),
  });
  
  // Retornar inmediatamente
  res.json({ 
    success: true, 
    message: 'Vote queued for processing' 
  });
});
```

### 4. Worker para Procesar Votos

```typescript
// server/workers/vote-worker.ts
async function processPollVote(voteData: {
  pollId: number;
  optionId: number;
  userId: string;
  broadcastId: string;
  timestamp: string;
}) {
  const { pollId, optionId, userId, broadcastId } = voteData;
  
  // Validación doble
  const poll = await db.getPoll(pollId);
  if (!poll || !poll.is_active) {
    logger.warn(`Poll ${pollId} not active, discarding vote`);
    return;
  }
  
  // Verificar duplicados en DB
  const existing = await db.getPollVote(pollId, userId);
  if (existing) {
    logger.warn(`Duplicate vote from user ${userId}, discarding`);
    return;
  }
  
  // Procesar en transacción
  await db.transaction(async (tx) => {
    await tx.execute(
      'UPDATE poll_options SET vote_count = vote_count + 1 WHERE poll_id = ? AND id = ?',
      [pollId, optionId]
    );
    await tx.execute(
      'UPDATE polls SET total_votes = total_votes + 1 WHERE id = ?',
      [pollId]
    );
    await tx.execute(
      'INSERT INTO poll_votes (poll_id, option_id, user_id, broadcast_id, created_at) VALUES (?, ?, ?, ?, ?)',
      [pollId, optionId, userId, broadcastId, voteData.timestamp]
    );
  });
  
  // Emitir evento WebSocket
  websocketManager.broadcast({
    type: 'poll_results_updated',
    broadcastId,
    pollId,
    results: await getPollResults(pollId),
  });
}
```

### 5. Cálculo de Timestamps Absolutos

```typescript
// server/utils/scheduling.ts
export function calculateScheduledTimes(
  broadcastStartTime: string,  // ISO 8601
  videoStartTime: number,      // segundos relativos (puede ser negativo)
  videoEndTime: number         // segundos relativos
): { scheduledStart: Date; scheduledEnd: Date } {
  const broadcastStart = new Date(broadcastStartTime);
  
  const scheduledStart = new Date(broadcastStart.getTime() + videoStartTime * 1000);
  const scheduledEnd = new Date(broadcastStart.getTime() + videoEndTime * 1000);
  
  return { scheduledStart, scheduledEnd };
}

// Uso en endpoint:
router.post('/v1/broadcasts/:broadcastId/polls', async (req, res) => {
  const { scheduling } = req.body;
  
  if (scheduling) {
    const { scheduledStart, scheduledEnd } = calculateScheduledTimes(
      scheduling.broadcastStartTime,
      scheduling.videoStartTime,
      scheduling.videoEndTime
    );
    
    // Guardar en DB
    await db.createPoll({
      ...req.body,
      scheduled_start_time: scheduledStart,
      scheduled_end_time: scheduledEnd,
      video_start_time: scheduling.videoStartTime,
      video_end_time: scheduling.videoEndTime,
      broadcast_start_time: scheduling.broadcastStartTime,
    });
  }
});
```

### 6. Cron Job para Polls/Contests

```typescript
// server/scheduler.ts - Agregar estas funciones

async function processScheduledPolls() {
  const now = new Date();
  
  // Activar polls que deben empezar
  const pollsToActivate = await db.execute(`
    SELECT id, broadcast_id FROM polls
    WHERE scheduled_start_time <= $1
      AND scheduled_end_time > $1
      AND is_active = false
  `, [now]);
  
  for (const poll of pollsToActivate) {
    await db.execute('UPDATE polls SET is_active = true WHERE id = $1', [poll.id]);
    
    // Emitir evento WebSocket
    websocketManager.broadcastToCampaign(poll.broadcast_id, {
      type: 'poll_activated',
      pollId: poll.id,
      broadcastId: poll.broadcast_id,
      timestamp: now.toISOString(),
    });
  }
  
  // Desactivar polls que deben terminar
  const pollsToDeactivate = await db.execute(`
    SELECT id, broadcast_id FROM polls
    WHERE scheduled_end_time <= $1
      AND is_active = true
  `, [now]);
  
  for (const poll of pollsToDeactivate) {
    await db.execute('UPDATE polls SET is_active = false WHERE id = $1', [poll.id]);
    
    websocketManager.broadcastToCampaign(poll.broadcast_id, {
      type: 'poll_deactivated',
      pollId: poll.id,
      broadcastId: poll.broadcast_id,
      timestamp: now.toISOString(),
    });
  }
}

// Ejecutar cada minuto junto con otros cron jobs
setInterval(async () => {
  await processScheduledPolls();
  await processScheduledContests();
  await processScheduledComponents();
}, 60000);  // 1 minuto
```

### 7. Rate Limiter

```typescript
// server/middleware/rate-limiter.ts
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

export async function rateLimit(
  key: string,
  maxRequests: number,
  windowSeconds: number
): Promise<{ allowed: boolean; remaining: number }> {
  const now = Date.now();
  const windowStart = now - windowSeconds * 1000;
  
  // Limpiar requests antiguas y contar
  const pipe = redis.pipeline();
  pipe.zremrangebyscore(key, 0, windowStart);
  pipe.zcard(key);
  pipe.zadd(key, now, `${now}-${Math.random()}`);
  pipe.expire(key, windowSeconds);
  const results = await pipe.exec();
  
  const currentCount = results[1][1] as number;
  const allowed = currentCount < maxRequests;
  const remaining = Math.max(0, maxRequests - currentCount - 1);
  
  return { allowed, remaining };
}

// Uso en endpoint:
router.post('/v1/engagement/polls/:pollId/vote', async (req, res) => {
  const { userId } = req.body;
  
  // Rate limiting
  const limit = await rateLimit(`rate_limit:vote:${userId}`, 10, 60);
  if (!limit.allowed) {
    return res.status(429).json({
      error: 'Rate limit exceeded',
      retryAfter: 60,
    });
  }
  
  // Continuar con lógica...
});
```

---

## 📝 Resumen de Gaps

### Gaps Críticos (Bloquean Producción)
1. ❌ **Sistema de Cola de Mensajería** - Sin esto, el sistema se caerá con carga alta
2. ❌ **Rate Limiting** - Sin esto, usuarios pueden hacer spam
3. ❌ **Validación de BroadcastId** - Sin esto, no hay validación de broadcasts

### Gaps Importantes (Funcionalidad Incompleta)
4. ❌ **Programación Relativa al Video** - No se puede programar contenido relativo al video
5. ❌ **Cron Job para Polls/Contests** - No se activan/desactivan automáticamente
6. ❌ **Cálculo de Timestamps** - Usuario debe calcular manualmente

### Gaps Opcionales (Mejoras)
7. ⚠️ **Frontend UI de Programación** - Falta timeline view
8. ⚠️ **Monitoreo** - Falta dashboard de métricas
9. ⚠️ **Caching** - Falta caching estratégico

---

## 🎯 Recomendación

**Priorizar implementación de:**
1. **Sistema de Cola de Mensajería** (Sprint 1 - Crítico)
2. **Rate Limiting** (Sprint 1 - Crítico)
3. **Campos de Programación** (Sprint 2 - Importante)
4. **Cron Job para Polls/Contests** (Sprint 2 - Importante)
5. **Frontend UI** (Sprint 3 - Opcional)

---

**Este análisis identifica exactamente qué falta para tener un sistema completo y robusto listo para producción.**
