# Preparación para Features Futuras - Guía de Implementación

## 🎯 Objetivo

Este documento especifica qué debe dejarse **preparado y estructurado** en el código actual para facilitar la implementación futura de las features críticas identificadas en el análisis de gaps. No se requiere implementar completamente estas features ahora, pero sí dejar la infraestructura lista.

---

## 📋 Índice

1. [Sistema de Cola de Mensajería](#1-sistema-de-cola-de-mensajería)
2. [Rate Limiting](#2-rate-limiting)
3. [Programación Relativa al Video](#3-programación-relativa-al-video)
4. [Cron Jobs para Polls/Contests](#4-cron-jobs-para-pollscontests)
5. [Validación de BroadcastId](#5-validación-de-broadcastid)
6. [Frontend UI de Programación](#6-frontend-ui-de-programación)

---

## 1. Sistema de Cola de Mensajería

### 1.1 Estructura de Archivos a Crear (Vacíos pero Estructurados)

```
server/
├── queue/
│   ├── index.ts              # Exporta todas las colas y workers
│   ├── queues.ts             # Definición de colas (vacío por ahora)
│   ├── workers.ts            # Definición de workers (vacío por ahora)
│   └── types.ts             # Tipos TypeScript para jobs
├── services/
│   ├── vote-processor.ts    # Lógica de procesamiento de votos (actualmente síncrono)
│   └── contest-processor.ts # Lógica de procesamiento de participaciones (actualmente síncrono)
```

### 1.2 Código a Preparar

#### `server/queue/types.ts`
```typescript
/**
 * Tipos para el sistema de cola de mensajería (futuro)
 * TODO: Implementar cuando se agregue Redis/BullMQ
 */

export interface VoteJobData {
  pollId: number;
  optionId: number;
  userId: string;
  broadcastId: string;
  timestamp: string;
}

export interface ContestParticipationJobData {
  contestId: number;
  userId: string;
  broadcastId: string;
  answers?: Record<string, any>;
  timestamp: string;
}

export interface JobResult {
  success: boolean;
  error?: string;
  data?: any;
}
```

#### `server/queue/queues.ts`
```typescript
/**
 * Configuración de colas de mensajería
 * TODO: Implementar cuando se agregue Redis/BullMQ
 * 
 * Instrucciones futuras:
 * 1. Instalar: npm install bullmq ioredis
 * 2. Configurar conexión Redis en .env
 * 3. Descomentar y configurar las colas
 */

// import { Queue } from 'bullmq';
// import Redis from 'ioredis';

// const redisConnection = new Redis({
//   host: process.env.REDIS_HOST || 'localhost',
//   port: parseInt(process.env.REDIS_PORT || '6379'),
//   password: process.env.REDIS_PASSWORD,
// });

// export const voteQueue = new Queue('vote-queue', {
//   connection: redisConnection,
//   defaultJobOptions: {
//     attempts: 3,
//     backoff: {
//       type: 'exponential',
//       delay: 2000,
//     },
//   },
// });

// export const contestParticipationQueue = new Queue('contest-participation-queue', {
//   connection: redisConnection,
//   defaultJobOptions: {
//     attempts: 3,
//     backoff: {
//       type: 'exponential',
//       delay: 2000,
//     },
//   },
// });

// Placeholder para cuando se implemente
export const voteQueue = null;
export const contestParticipationQueue = null;
```

#### `server/queue/workers.ts`
```typescript
/**
 * Workers para procesar jobs de las colas
 * TODO: Implementar cuando se agregue Redis/BullMQ
 */

// import { Worker } from 'bullmq';
// import { processPollVote } from '../services/vote-processor';
// import { processContestParticipation } from '../services/contest-processor';
// import { redisConnection } from './queues';

// export const voteWorker = new Worker('vote-queue', async (job) => {
//   await processPollVote(job.data);
// }, {
//   connection: redisConnection,
//   concurrency: 10,
//   limiter: {
//     max: 100,
//     duration: 1000,
//   },
// });

// Placeholder
export const voteWorker = null;
export const contestParticipationWorker = null;
```

#### `server/queue/index.ts`
```typescript
/**
 * Exportaciones centralizadas del sistema de cola
 */

export * from './types';
export * from './queues';
export * from './workers';
```

### 1.3 Refactorizar Endpoints para Usar Abstracción

#### `server/routes/engagement.ts` - Modificar endpoints de votos

```typescript
import { voteQueue } from '../queue';
import { processPollVoteSync } from '../services/vote-processor';

router.post('/v1/engagement/polls/:pollId/vote', async (req, res) => {
  const { pollId } = req.params;
  const { optionId, userId, broadcastId } = req.body;
  
  // Validación rápida
  const poll = await db.getPoll(pollId);
  if (!poll || !poll.is_active) {
    return res.status(400).json({ error: 'Poll not found or not active' });
  }
  
  // TODO: Cuando se implemente la cola, cambiar a:
  // if (voteQueue) {
  //   await voteQueue.add('process-vote', {
  //     pollId,
  //     optionId,
  //     userId,
  //     broadcastId,
  //     timestamp: new Date().toISOString(),
  //   });
  //   return res.json({ success: true, message: 'Vote queued for processing' });
  // }
  
  // Por ahora, procesar síncronamente
  try {
    const result = await processPollVoteSync({
      pollId,
      optionId,
      userId,
      broadcastId,
    });
    res.json(result);
  } catch (error) {
    res.status(409).json({ error: error.message });
  }
});
```

### 1.4 Servicio de Procesamiento (Preparado para Refactorizar)

#### `server/services/vote-processor.ts`
```typescript
import { VoteJobData } from '../queue/types';

/**
 * Procesa un voto de poll
 * Actualmente síncrono, pero preparado para ser llamado desde worker
 */
export async function processPollVoteSync(data: VoteJobData) {
  const { pollId, optionId, userId, broadcastId } = data;
  
  // Validación doble
  const poll = await db.getPoll(pollId);
  if (!poll || !poll.is_active) {
    throw new Error('Poll not found or not active');
  }
  
  // Verificar duplicados
  const existing = await db.getPollVote(pollId, userId);
  if (existing) {
    throw new Error('User has already voted on this poll');
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
      [pollId, optionId, userId, broadcastId, new Date()]
    );
  });
  
  // Emitir evento WebSocket
  websocketManager.broadcast({
    type: 'poll_results_updated',
    broadcastId,
    pollId,
    results: await getPollResults(pollId),
  });
  
  return { success: true };
}

/**
 * Versión asíncrona para workers (futuro)
 * TODO: Implementar cuando se agregue la cola
 */
export async function processPollVote(data: VoteJobData) {
  // Por ahora llama a la versión síncrona
  // En el futuro, esta será la función que ejecuta el worker
  return await processPollVoteSync(data);
}
```

### 1.5 Variables de Entorno a Agregar

```bash
# .env.example - Agregar estas variables (comentadas por ahora)

# Redis Configuration (para cola de mensajería - futuro)
# REDIS_HOST=localhost
# REDIS_PORT=6379
# REDIS_PASSWORD=
# REDIS_URL=redis://localhost:6379

# Queue Configuration
# QUEUE_ENABLED=false
# QUEUE_CONCURRENCY=10
# QUEUE_MAX_JOBS_PER_SECOND=100
```

### 1.6 README o Documentación

Crear `server/queue/README.md`:
```markdown
# Sistema de Cola de Mensajería

Este directorio contiene la estructura preparada para implementar un sistema de cola de mensajería usando Redis y BullMQ.

## Estado Actual
- ✅ Estructura de archivos creada
- ✅ Tipos TypeScript definidos
- ✅ Abstracciones preparadas
- ❌ Redis/BullMQ no instalado aún
- ❌ Workers no implementados

## Para Implementar en el Futuro

1. Instalar dependencias:
   ```bash
   npm install bullmq ioredis
   ```

2. Configurar Redis en `.env`

3. Descomentar código en `queues.ts` y `workers.ts`

4. Modificar endpoints en `routes/engagement.ts` para usar colas

5. Ver documentación completa en `REPLIT_IMPLEMENTATION_GAP_ANALYSIS.md`
```

---

## 2. Rate Limiting

### 2.1 Estructura de Archivos

```
server/
├── middleware/
│   ├── rate-limiter.ts      # Middleware de rate limiting (preparado)
│   └── index.ts             # Exportaciones
```

### 2.2 Código a Preparar

#### `server/middleware/rate-limiter.ts`
```typescript
/**
 * Rate Limiter usando Redis
 * TODO: Implementar cuando se agregue Redis
 * 
 * Por ahora, retorna siempre permitido
 * En el futuro, implementará sliding window rate limiting
 */

import { Request, Response, NextFunction } from 'express';

interface RateLimitOptions {
  maxRequests: number;
  windowSeconds: number;
  keyGenerator?: (req: Request) => string;
}

export function createRateLimiter(options: RateLimitOptions) {
  const { maxRequests, windowSeconds, keyGenerator } = options;
  
  return async (req: Request, res: Response, next: NextFunction) => {
    // TODO: Implementar cuando se agregue Redis
    // const redis = getRedisConnection();
    // const key = keyGenerator ? keyGenerator(req) : `rate_limit:${req.ip}`;
    // 
    // const allowed = await checkRateLimit(redis, key, maxRequests, windowSeconds);
    // 
    // if (!allowed) {
    //   return res.status(429).json({
    //     error: 'Rate limit exceeded',
    //     retryAfter: windowSeconds,
    //   });
    // }
    
    // Por ahora, siempre permitir
    next();
  };
}

/**
 * Función helper para verificar rate limit (futuro)
 */
async function checkRateLimit(
  redis: any,
  key: string,
  maxRequests: number,
  windowSeconds: number
): Promise<boolean> {
  // TODO: Implementar sliding window usando Redis Sorted Sets
  // const now = Date.now();
  // const windowStart = now - windowSeconds * 1000;
  // 
  // const pipe = redis.pipeline();
  // pipe.zremrangebyscore(key, 0, windowStart);
  // pipe.zcard(key);
  // pipe.zadd(key, now, `${now}-${Math.random()}`);
  // pipe.expire(key, windowSeconds);
  // const results = await pipe.exec();
  // 
  // const currentCount = results[1][1] as number;
  // return currentCount < maxRequests;
  
  return true; // Placeholder
}

/**
 * Rate limiter específico para votos
 */
export const voteRateLimiter = createRateLimiter({
  maxRequests: 10, // 10 votos por minuto
  windowSeconds: 60,
  keyGenerator: (req) => `rate_limit:vote:${req.body.userId || req.ip}`,
});

/**
 * Rate limiter específico para participaciones en contests
 */
export const contestRateLimiter = createRateLimiter({
  maxRequests: 5, // 5 participaciones por minuto
  windowSeconds: 60,
  keyGenerator: (req) => `rate_limit:contest:${req.body.userId || req.ip}`,
});
```

### 2.3 Usar en Endpoints (Preparado pero Deshabilitado)

```typescript
// server/routes/engagement.ts
import { voteRateLimiter, contestRateLimiter } from '../middleware/rate-limiter';

// TODO: Descomentar cuando se implemente rate limiting
// router.post('/v1/engagement/polls/:pollId/vote', voteRateLimiter, async (req, res) => {
router.post('/v1/engagement/polls/:pollId/vote', async (req, res) => {
  // ... resto del código
});
```

---

## 3. Programación Relativa al Video

### 3.1 Migración de Base de Datos (Agregar Campos)

```sql
-- Migración: Agregar campos de programación relativa al video
-- Estos campos se agregan pero pueden quedar NULL por ahora

ALTER TABLE polls
ADD COLUMN IF NOT EXISTS video_start_time INT NULL,
ADD COLUMN IF NOT EXISTS video_end_time INT NULL,
ADD COLUMN IF NOT EXISTS broadcast_start_time TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS scheduled_start_time TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS scheduled_end_time TIMESTAMP NULL,
ADD INDEX IF NOT EXISTS idx_polls_scheduled_times (scheduled_start_time, scheduled_end_time),
ADD INDEX IF NOT EXISTS idx_polls_video_times (video_start_time, video_end_time);

ALTER TABLE contests
ADD COLUMN IF NOT EXISTS video_start_time INT NULL,
ADD COLUMN IF NOT EXISTS video_end_time INT NULL,
ADD COLUMN IF NOT EXISTS broadcast_start_time TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS scheduled_start_time TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS scheduled_end_time TIMESTAMP NULL,
ADD INDEX IF NOT EXISTS idx_contests_scheduled_times (scheduled_start_time, scheduled_end_time);

ALTER TABLE campaign_components
ADD COLUMN IF NOT EXISTS video_start_time INT NULL,
ADD COLUMN IF NOT EXISTS video_end_time INT NULL,
ADD COLUMN IF NOT EXISTS scheduled_start_time TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS scheduled_end_time TIMESTAMP NULL,
ADD INDEX IF NOT EXISTS idx_components_scheduled_times (scheduled_start_time, scheduled_end_time);
```

### 3.2 Schema TypeScript (Actualizar)

#### `server/db/schemas/polls.ts`
```typescript
import { pgTable, serial, text, timestamp, integer, boolean } from 'drizzle-orm/pg-core';

export const polls = pgTable('polls', {
  id: serial('id').primaryKey(),
  broadcastId: text('broadcast_id').notNull(),
  question: text('question').notNull(),
  startTime: timestamp('start_time'), // Legacy - mantener por compatibilidad
  endTime: timestamp('end_time'),     // Legacy - mantener por compatibilidad
  isActive: boolean('is_active').default(true),
  totalVotes: integer('total_votes').default(0),
  
  // Campos de programación relativa al video (futuro)
  videoStartTime: integer('video_start_time'), // Segundos relativos al inicio del broadcast
  videoEndTime: integer('video_end_time'),     // Segundos relativos al inicio del broadcast
  broadcastStartTime: timestamp('broadcast_start_time'), // Timestamp del inicio del broadcast
  scheduledStartTime: timestamp('scheduled_start_time'), // Calculado: broadcastStartTime + videoStartTime
  scheduledEndTime: timestamp('scheduled_end_time'),     // Calculado: broadcastStartTime + videoEndTime
  
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});
```

### 3.3 Utilidad de Cálculo (Preparada)

#### `server/utils/scheduling.ts`
```typescript
/**
 * Utilidades para calcular timestamps de programación relativa al video
 */

export interface SchedulingInput {
  broadcastStartTime: string;  // ISO 8601
  videoStartTime: number;      // Segundos relativos (puede ser negativo)
  videoEndTime: number;        // Segundos relativos
}

export interface SchedulingOutput {
  scheduledStart: Date;
  scheduledEnd: Date;
}

/**
 * Calcula timestamps absolutos desde tiempos relativos al video
 */
export function calculateScheduledTimes(
  input: SchedulingInput
): SchedulingOutput {
  const broadcastStart = new Date(input.broadcastStartTime);
  
  const scheduledStart = new Date(
    broadcastStart.getTime() + input.videoStartTime * 1000
  );
  const scheduledEnd = new Date(
    broadcastStart.getTime() + input.videoEndTime * 1000
  );
  
  return { scheduledStart, scheduledEnd };
}

/**
 * Valida que los tiempos de programación sean válidos
 */
export function validateScheduling(input: SchedulingInput): {
  valid: boolean;
  error?: string;
} {
  if (input.videoEndTime < input.videoStartTime) {
    return {
      valid: false,
      error: 'videoEndTime must be greater than or equal to videoStartTime',
    };
  }
  
  try {
    const broadcastStart = new Date(input.broadcastStartTime);
    if (isNaN(broadcastStart.getTime())) {
      return {
        valid: false,
        error: 'Invalid broadcastStartTime format',
      };
    }
  } catch (error) {
    return {
      valid: false,
      error: 'Invalid broadcastStartTime format',
    };
  }
  
  return { valid: true };
}
```

### 3.4 Endpoints Preparados para Aceptar Scheduling

#### `server/routes/broadcasts.ts` - Modificar crear poll

```typescript
router.post('/v1/broadcasts/:broadcastId/polls', async (req, res) => {
  const { broadcastId } = req.params;
  const { question, options, scheduling } = req.body;
  
  // Validar que el broadcast existe
  const broadcast = await db.getBroadcast(broadcastId);
  if (!broadcast) {
    return res.status(404).json({ error: 'Broadcast not found' });
  }
  
  let scheduledStartTime = null;
  let scheduledEndTime = null;
  let videoStartTime = null;
  let videoEndTime = null;
  let broadcastStartTime = null;
  
  // Si se proporciona scheduling, calcular timestamps
  if (scheduling) {
    const { calculateScheduledTimes, validateScheduling } = require('../utils/scheduling');
    
    const validation = validateScheduling(scheduling);
    if (!validation.valid) {
      return res.status(400).json({ error: validation.error });
    }
    
    const calculated = calculateScheduledTimes(scheduling);
    scheduledStartTime = calculated.scheduledStart;
    scheduledEndTime = calculated.scheduledEnd;
    videoStartTime = scheduling.videoStartTime;
    videoEndTime = scheduling.videoEndTime;
    broadcastStartTime = scheduling.broadcastStartTime;
  }
  
  // Crear poll con campos de scheduling (pueden ser NULL)
  const poll = await db.createPoll({
    broadcastId,
    question,
    videoStartTime,
    videoEndTime,
    broadcastStartTime,
    scheduledStartTime,
    scheduledEndTime,
    // Si no hay scheduling, usar startTime/endTime legacy si se proporcionan
    startTime: scheduling ? null : req.body.startTime,
    endTime: scheduling ? null : req.body.endTime,
  });
  
  // Crear opciones...
  
  res.json(poll);
});
```

---

## 4. Cron Jobs para Polls/Contests

### 4.1 Estructura Preparada en Scheduler

#### `server/scheduler.ts` - Agregar funciones preparadas

```typescript
import { db } from './db';
import { websocketManager } from './websocket';

/**
 * Procesa polls programados para activar/desactivar automáticamente
 * TODO: Implementar lógica completa cuando se agreguen campos de scheduling
 */
export async function processScheduledPolls() {
  // TODO: Implementar cuando se agreguen campos scheduled_start_time y scheduled_end_time
  // const now = new Date();
  // 
  // // Activar polls que deben empezar
  // const pollsToActivate = await db.execute(`
  //   SELECT id, broadcast_id FROM polls
  //   WHERE scheduled_start_time <= $1
  //     AND scheduled_end_time > $1
  //     AND is_active = false
  // `, [now]);
  // 
  // for (const poll of pollsToActivate) {
  //   await db.execute('UPDATE polls SET is_active = true WHERE id = $1', [poll.id]);
  //   
  //   websocketManager.broadcastToBroadcast(poll.broadcast_id, {
  //     type: 'poll_activated',
  //     pollId: poll.id,
  //     broadcastId: poll.broadcast_id,
  //     timestamp: now.toISOString(),
  //   });
  // }
  // 
  // // Desactivar polls que deben terminar
  // const pollsToDeactivate = await db.execute(`
  //   SELECT id, broadcast_id FROM polls
  //   WHERE scheduled_end_time <= $1
  //     AND is_active = true
  // `, [now]);
  // 
  // for (const poll of pollsToDeactivate) {
  //   await db.execute('UPDATE polls SET is_active = false WHERE id = $1', [poll.id]);
  //   
  //   websocketManager.broadcastToBroadcast(poll.broadcast_id, {
  //     type: 'poll_deactivated',
  //     pollId: poll.id,
  //     broadcastId: poll.broadcast_id,
  //     timestamp: now.toISOString(),
  //   });
  // }
  
  // Por ahora, función vacía
  console.log('[Scheduler] processScheduledPolls - TODO: Implementar cuando se agreguen campos de scheduling');
}

/**
 * Similar para contests
 */
export async function processScheduledContests() {
  // TODO: Implementar similar a processScheduledPolls
  console.log('[Scheduler] processScheduledContests - TODO: Implementar');
}

/**
 * Similar para componentes
 */
export async function processScheduledComponents() {
  // TODO: Implementar similar a processScheduledPolls pero para campaign_components
  console.log('[Scheduler] processScheduledComponents - TODO: Implementar');
}

// En el cron job principal, agregar llamadas (comentadas por ahora)
setInterval(async () => {
  await updateBroadcastStatuses();
  await checkScheduledComponents(); // Ya existe
  
  // TODO: Descomentar cuando se implementen
  // await processScheduledPolls();
  // await processScheduledContests();
  // await processScheduledComponents();
}, 60000);
```

---

## 5. Validación de BroadcastId

### 5.1 Middleware de Validación

#### `server/middleware/broadcast-validator.ts`
```typescript
import { Request, Response, NextFunction } from 'express';
import { db } from '../db';

/**
 * Valida que un broadcastId existe y está en estado válido
 */
export async function validateBroadcastId(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const broadcastId = req.query.broadcastId || req.query.matchId || req.params.broadcastId;
  
  if (!broadcastId) {
    return next(); // No hay broadcastId, continuar sin validar
  }
  
  try {
    const broadcast = await db.getBroadcast(broadcastId as string);
    
    if (!broadcast) {
      return res.status(404).json({
        error: `Broadcast '${broadcastId}' not found`,
        broadcastId,
      });
    }
    
    // Si el broadcast está ended, retornar array vacío (no error)
    if (broadcast.status === 'ended') {
      // Agregar flag para que el handler sepa que debe retornar array vacío
      (req as any).broadcastEnded = true;
    }
    
    // Agregar broadcast al request para uso posterior
    (req as any).broadcast = broadcast;
    
    next();
  } catch (error) {
    console.error('Error validating broadcast:', error);
    return res.status(500).json({ error: 'Error validating broadcast' });
  }
}
```

### 5.2 Usar en Endpoint de Auto-Discovery

#### `server/routes/sdk.ts` - Modificar GET /v1/sdk/campaigns

```typescript
import { validateBroadcastId } from '../middleware/broadcast-validator';

router.get('/v1/sdk/campaigns', validateBroadcastId, async (req, res) => {
  const { apiKey, matchId, broadcastId } = req.query;
  const effectiveBroadcastId = broadcastId || matchId;
  
  // Si el broadcast está ended, retornar array vacío
  if ((req as any).broadcastEnded) {
    return res.json([]);
  }
  
  // Resto de la lógica...
  const campaigns = await db.getCampaignsByBroadcastId(effectiveBroadcastId as string);
  res.json(campaigns);
});
```

---

## 6. Frontend UI de Programación

### 6.1 Componentes Preparados (Estructura)

```
frontend/src/components/
├── scheduling/
│   ├── SchedulingForm.tsx        # Formulario de scheduling (preparado)
│   ├── VideoTimeInput.tsx         # Input para tiempos relativos al video
│   ├── TimelineView.tsx           # Vista de timeline (preparado)
│   └── SchedulingPreview.tsx     # Preview de timestamps calculados
```

### 6.2 Código Preparado

#### `frontend/src/components/scheduling/SchedulingForm.tsx`
```typescript
/**
 * Formulario para programar polls/contests con tiempos relativos al video
 * TODO: Implementar UI completa cuando backend soporte scheduling
 */

import React, { useState } from 'react';

interface SchedulingFormProps {
  broadcastStartTime: string;
  onSubmit: (scheduling: {
    videoStartTime: number;
    videoEndTime: number;
    broadcastStartTime: string;
  }) => void;
}

export function SchedulingForm({ broadcastStartTime, onSubmit }: SchedulingFormProps) {
  const [videoStartTime, setVideoStartTime] = useState<number>(0);
  const [videoEndTime, setVideoEndTime] = useState<number>(300); // 5 minutos por defecto
  
  // TODO: Implementar cálculo de preview
  const calculatePreview = () => {
    const start = new Date(broadcastStartTime);
    const scheduledStart = new Date(start.getTime() + videoStartTime * 1000);
    const scheduledEnd = new Date(start.getTime() + videoEndTime * 1000);
    
    return { scheduledStart, scheduledEnd };
  };
  
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit({
      videoStartTime,
      videoEndTime,
      broadcastStartTime,
    });
  };
  
  return (
    <form onSubmit={handleSubmit} className="scheduling-form">
      <h3>Programación Relativa al Video</h3>
      
      <div className="form-group">
        <label>
          Tiempo de Inicio (segundos relativos al inicio del broadcast):
          <input
            type="number"
            value={videoStartTime}
            onChange={(e) => setVideoStartTime(parseInt(e.target.value))}
            placeholder="Ej: -690 (11:30 antes del inicio)"
          />
        </label>
        <small>Valores negativos = antes del inicio del broadcast</small>
      </div>
      
      <div className="form-group">
        <label>
          Tiempo de Fin (segundos relativos al inicio del broadcast):
          <input
            type="number"
            value={videoEndTime}
            onChange={(e) => setVideoEndTime(parseInt(e.target.value))}
            placeholder="Ej: 0 (al inicio)"
          />
        </label>
      </div>
      
      {/* TODO: Agregar preview de timestamps calculados */}
      <div className="preview">
        <strong>Preview:</strong>
        <p>Inicio programado: {calculatePreview().scheduledStart.toLocaleString()}</p>
        <p>Fin programado: {calculatePreview().scheduledEnd.toLocaleString()}</p>
      </div>
      
      <button type="submit">Guardar Programación</button>
    </form>
  );
}
```

#### `frontend/src/components/scheduling/TimelineView.tsx`
```typescript
/**
 * Vista de timeline para ver programación completa
 * TODO: Implementar visualización completa
 */

import React from 'react';

interface TimelineItem {
  id: string;
  type: 'poll' | 'contest' | 'component';
  name: string;
  scheduledStart: Date;
  scheduledEnd: Date;
}

interface TimelineViewProps {
  broadcastStartTime: Date;
  items: TimelineItem[];
}

export function TimelineView({ broadcastStartTime, items }: TimelineViewProps) {
  // TODO: Implementar visualización de timeline
  return (
    <div className="timeline-view">
      <h3>Programación del Broadcast</h3>
      <div className="timeline">
        {/* TODO: Renderizar items en timeline */}
        {items.map((item) => (
          <div key={item.id} className="timeline-item">
            <span>{item.name}</span>
            <span>{item.scheduledStart.toLocaleTimeString()}</span>
            <span>{item.scheduledEnd.toLocaleTimeString()}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
```

### 6.3 Integrar en Formularios Existentes

#### `frontend/src/pages/broadcasts/broadcast-detail.tsx` - Agregar sección

```typescript
import { SchedulingForm } from '../../components/scheduling/SchedulingForm';

// En el componente de crear poll:
<div className="poll-form">
  <input name="question" />
  {/* ... otros campos ... */}
  
  {/* TODO: Agregar cuando backend soporte scheduling */}
  {/* <SchedulingForm
    broadcastStartTime={broadcast.startTime}
    onSubmit={(scheduling) => {
      // Agregar scheduling al request
      setFormData({ ...formData, scheduling });
    }}
  /> */}
</div>
```

---

## 📝 Checklist de Preparación

### Backend

- [ ] Crear estructura de directorios `server/queue/`
- [ ] Crear tipos TypeScript en `server/queue/types.ts`
- [ ] Crear archivos `queues.ts` y `workers.ts` con código comentado
- [ ] Refactorizar `processPollVote` a servicio separado
- [ ] Crear middleware `rate-limiter.ts` (preparado pero deshabilitado)
- [ ] Ejecutar migración SQL para agregar campos de scheduling
- [ ] Crear `server/utils/scheduling.ts` con funciones de cálculo
- [ ] Modificar endpoints para aceptar `scheduling` object (opcional)
- [ ] Agregar funciones preparadas en `scheduler.ts`
- [ ] Crear middleware `broadcast-validator.ts`
- [ ] Modificar `GET /v1/sdk/campaigns` para usar validación

### Frontend

- [ ] Crear estructura `components/scheduling/`
- [ ] Crear `SchedulingForm.tsx` (preparado pero no integrado)
- [ ] Crear `TimelineView.tsx` (preparado pero no integrado)
- [ ] Agregar comentarios TODO en formularios existentes

### Documentación

- [ ] Crear `server/queue/README.md` con instrucciones futuras
- [ ] Documentar campos nuevos en schema
- [ ] Agregar comentarios TODO en código

---

## 🎯 Resumen

Este documento especifica qué debe dejarse **preparado** para facilitar la implementación futura. No se requiere implementar completamente estas features ahora, pero sí:

1. ✅ **Estructura de archivos** creada
2. ✅ **Tipos TypeScript** definidos
3. ✅ **Código comentado** con instrucciones TODO
4. ✅ **Campos de DB** agregados (pueden quedar NULL)
5. ✅ **Abstracciones** preparadas para facilitar refactorización
6. ✅ **Middleware** creado pero deshabilitado
7. ✅ **Utilidades** preparadas para cálculo

Cuando se decida implementar estas features, será mucho más rápido porque:
- La estructura ya está lista
- Los tipos ya están definidos
- Solo hay que descomentar y configurar
- Los endpoints ya están preparados para aceptar los nuevos datos

---

**Este enfoque permite tener un código limpio y preparado para el futuro sin implementar features incompletas ahora.**
