# Guía de Activación Completa V2.0 - Para Replit
# Activar Features con Implementación Simple (Testing) → Migrar a Redis (Producción)

## 📋 Índice

1. [Resumen Ejecutivo](#resumen)
2. [Estado Actual](#estado-actual)
3. [Fase 5: Video Scheduling](#fase-5)
4. [Fase 6: Message Queue con Adapter](#fase-6)
5. [Rate Limiting con Adapter](#rate-limiting)
6. [Migración a Producción](#produccion)
7. [Testing](#testing)
8. [Checklist](#checklist)

---

## Resumen Ejecutivo {#resumen}

**Objetivo:** Activar todas las features ahora mismo usando implementaciones simples (in-memory), dejando el código listo para migrar a Redis/Google Cloud solo cambiando variables de entorno.

**Estrategia:** Adapter Pattern - Misma interfaz, diferentes implementaciones.

**Para Testing (Ahora):**
```bash
USE_QUEUE=true
QUEUE_ENABLED=false  # No Redis aún
```

**Para Producción (Después):**
```bash
USE_QUEUE=true
QUEUE_ENABLED=true
REDIS_HOST=your-redis-host
```

---

## Estado Actual {#estado-actual}

### ✅ Implementado y Activo
- Broadcasts CRUD
- Polls & Voting
- Contests & Participation
- WebSocket Events
- Broadcast Scheduler
- Dashboard UI
- Vote/Contest Processor Services
- Video Scheduling DB fields
- Video Scheduling Utils
- Queue Types & Structure

### ⏸ Preparado pero No Activo
- Scheduled Polls/Contests (comentado en scheduler.ts)
- Queue Implementation (comentado)
- Queue Workers (comentado)
- Rate Limiter (passthrough)

---

## Fase 5: Video Scheduling {#fase-5}

### Paso 1: Descomentar en `server/scheduler.ts`

```typescript
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
    
    websocketManager.broadcastToBroadcast(poll.broadcast_id, {
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
    
    websocketManager.broadcastToBroadcast(poll.broadcast_id, {
      type: 'poll_deactivated',
      pollId: poll.id,
      broadcastId: poll.broadcast_id,
      timestamp: now.toISOString(),
    });
  }
}

async function processScheduledContests() {
  // Similar para contests...
  const now = new Date();
  const contestsToActivate = await db.execute(`
    SELECT id, broadcast_id FROM contests
    WHERE scheduled_start_time <= $1
      AND scheduled_end_time > $1
      AND is_active = false
  `, [now]);
  
  for (const contest of contestsToActivate) {
    await db.execute('UPDATE contests SET is_active = true WHERE id = $1', [contest.id]);
    websocketManager.broadcastToBroadcast(contest.broadcast_id, {
      type: 'contest_activated',
      contestId: contest.id,
      broadcastId: contest.broadcast_id,
      timestamp: now.toISOString(),
    });
  }
  
  const contestsToDeactivate = await db.execute(`
    SELECT id, broadcast_id FROM contests
    WHERE scheduled_end_time <= $1
      AND is_active = true
  `, [now]);
  
  for (const contest of contestsToDeactivate) {
    await db.execute('UPDATE contests SET is_active = false WHERE id = $1', [contest.id]);
    websocketManager.broadcastToBroadcast(contest.broadcast_id, {
      type: 'contest_deactivated',
      contestId: contest.id,
      broadcastId: contest.broadcast_id,
      timestamp: now.toISOString(),
    });
  }
}

// En el cron job principal:
setInterval(async () => {
  await updateBroadcastStatuses();
  await checkScheduledComponents();
  await processScheduledPolls();      // ← Descomentar
  await processScheduledContests();   // ← Descomentar
}, 60000);
```

---

## Fase 6: Message Queue con Adapter {#fase-6}

### Paso 1: Crear `server/queue/queue-adapter.ts`

```typescript
/**
 * Queue Adapter Pattern
 * Permite cambiar implementación (simple → Redis) sin modificar código
 */

export interface QueueAdapter {
  add(queueName: string, jobName: string, data: any, options?: any): Promise<void>;
  process(queueName: string, processor: (job: any) => Promise<any>): void;
  close(): Promise<void>;
}

export interface Job {
  id: string;
  data: any;
  attemptsMade: number;
}

/**
 * Implementación SIMPLE: In-memory queue para testing
 */
class SimpleQueueAdapter implements QueueAdapter {
  private queues: Map<string, Array<{ id: string; data: any; attempts: number }>>;
  private processors: Map<string, (job: any) => Promise<any>>;
  private processing: boolean;
  private intervalId: NodeJS.Timeout | null;

  constructor() {
    this.queues = new Map();
    this.processors = new Map();
    this.processing = false;
    this.intervalId = null;
    this.startProcessing();
  }

  async add(queueName: string, jobName: string, data: any, options?: any): Promise<void> {
    if (!this.queues.has(queueName)) {
      this.queues.set(queueName, []);
    }

    const jobId = options?.jobId || `${queueName}-${jobName}-${Date.now()}-${Math.random()}`;
    const queue = this.queues.get(queueName)!;
    
    const exists = queue.find(j => j.id === jobId);
    if (exists) {
      console.log(`[SimpleQueue] Job ${jobId} already exists, skipping`);
      return;
    }

    queue.push({ id: jobId, data, attempts: 0 });
    console.log(`[SimpleQueue] Added job ${jobId} to queue ${queueName} (size: ${queue.length})`);
  }

  process(queueName: string, processor: (job: any) => Promise<any>): void {
    this.processors.set(queueName, processor);
    console.log(`[SimpleQueue] Registered processor for queue ${queueName}`);
  }

  private startProcessing(): void {
    if (this.processing) return;
    this.processing = true;

    this.intervalId = setInterval(async () => {
      for (const [queueName, queue] of this.queues.entries()) {
        if (queue.length === 0) continue;
        const processor = this.processors.get(queueName);
        if (!processor) continue;

        const job = queue.shift()!;
        try {
          console.log(`[SimpleQueue] Processing job ${job.id} from ${queueName}`);
          await processor({ id: job.id, data: job.data, attemptsMade: job.attempts });
          console.log(`[SimpleQueue] ✅ Job ${job.id} completed`);
        } catch (error) {
          console.error(`[SimpleQueue] ❌ Job ${job.id} failed:`, error);
          job.attempts++;
          if (job.attempts < 3) {
            queue.push(job);
            console.log(`[SimpleQueue] Retrying job ${job.id} (attempt ${job.attempts + 1}/3)`);
          } else {
            console.error(`[SimpleQueue] Job ${job.id} failed after 3 attempts`);
          }
        }
      }
    }, 100);
  }

  async close(): Promise<void> {
    this.processing = false;
    if (this.intervalId) clearInterval(this.intervalId);
    this.queues.clear();
    this.processors.clear();
  }
}

/**
 * Implementación con BullMQ (producción)
 */
class BullMQAdapter implements QueueAdapter {
  private queues: Map<string, any>;
  private workers: Map<string, any>;
  private redisConnection: any;

  constructor(redisConnection: any) {
    this.queues = new Map();
    this.workers = new Map();
    this.redisConnection = redisConnection;
  }

  async add(queueName: string, jobName: string, data: any, options?: any): Promise<void> {
    if (!this.queues.has(queueName)) {
      const { Queue } = require('bullmq');
      this.queues.set(queueName, new Queue(queueName, {
        connection: this.redisConnection,
        defaultJobOptions: {
          attempts: 3,
          backoff: { type: 'exponential', delay: 2000 },
        },
      }));
    }
    await this.queues.get(queueName)!.add(jobName, data, options);
  }

  process(queueName: string, processor: (job: any) => Promise<any>): void {
    if (this.workers.has(queueName)) return;
    const { Worker } = require('bullmq');
    const worker = new Worker(queueName, processor, {
      connection: this.redisConnection,
      concurrency: parseInt(process.env.QUEUE_CONCURRENCY || '10'),
    });
    this.workers.set(queueName, worker);
  }

  async close(): Promise<void> {
    for (const worker of this.workers.values()) await worker.close();
    for (const queue of this.queues.values()) await queue.close();
  }
}

export function createQueueAdapter(): QueueAdapter {
  const useRedis = process.env.QUEUE_ENABLED === 'true' && 
                   (process.env.REDIS_HOST || process.env.REDIS_URL);

  if (useRedis) {
    try {
      const Redis = require('ioredis');
      const redisConnection = new Redis({
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
        password: process.env.REDIS_PASSWORD || undefined,
        ...(process.env.REDIS_URL && { url: process.env.REDIS_URL }),
      });
      console.log('[Queue] ✅ Using BullMQ adapter with Redis');
      return new BullMQAdapter(redisConnection);
    } catch (error) {
      console.error('[Queue] ❌ Redis failed, using Simple:', error);
      return new SimpleQueueAdapter();
    }
  } else {
    console.log('[Queue] ✅ Using Simple in-memory adapter (testing)');
    return new SimpleQueueAdapter();
  }
}

let queueAdapterInstance: QueueAdapter | null = null;

export function getQueueAdapter(): QueueAdapter {
  if (!queueAdapterInstance) {
    queueAdapterInstance = createQueueAdapter();
  }
  return queueAdapterInstance;
}
```

### Paso 2: Modificar `server/queue/queues.ts`

```typescript
import { getQueueAdapter } from './queue-adapter';

const adapter = getQueueAdapter();

export const voteQueue = {
  add: async (jobName: string, data: any, options?: any) => {
    await adapter.add('vote-processing', jobName, data, options);
  },
};

export const contestParticipationQueue = {
  add: async (jobName: string, data: any, options?: any) => {
    await adapter.add('contest-participation', jobName, data, options);
  },
};

export { adapter };
```

### Paso 3: Modificar `server/queue/workers.ts`

```typescript
import { adapter } from './queues';
import { processVoteAsync } from '../services/vote-processor';
import { processParticipationAsync } from '../services/contest-processor';

export function initializeWorkers(storage: any) {
  console.log('[Workers] 🚀 Initializing...');

  adapter.process('vote-processing', async (job: any) => {
    console.log(`[Worker] Processing vote ${job.id}`);
    const result = await processVoteAsync(storage, job.data);
    if (!result.success) throw new Error(result.error);
    return result;
  });

  adapter.process('contest-participation', async (job: any) => {
    console.log(`[Worker] Processing contest ${job.id}`);
    const result = await processParticipationAsync(storage, job.data);
    if (!result.success) throw new Error(result.error);
    return result;
  });

  console.log('[Workers] ✅ Initialized');
}
```

### Paso 4: Modificar Endpoints en `server/routes.ts`

```typescript
import { voteQueue } from './queue/queues';
import { processVoteSync } from './services/vote-processor';

const useQueue = process.env.USE_QUEUE !== 'false';

router.post('/v1/engagement/polls/:pollId/vote', async (req, res) => {
  const { pollId } = req.params;
  const { optionId, userId, broadcastId } = req.body;
  
  const poll = await storage.getPoll(pollId);
  if (!poll || !poll.is_active) {
    return res.status(400).json({ error: 'Poll not found or not active' });
  }
  
  if (useQueue) {
    try {
      await voteQueue.add('vote', {
        pollId: parseInt(pollId),
        optionId: parseInt(optionId),
        userId,
        broadcastId,
        timestamp: new Date().toISOString(),
      }, {
        jobId: `vote-${pollId}-${userId}`,
      });
      return res.json({ success: true, message: 'Vote queued' });
    } catch (error) {
      console.error('Queue error:', error);
    }
  }
  
  // Fallback síncrono
  try {
    const result = await processVoteSync(storage, pollId, optionId, userId, broadcastId);
    res.json(result);
  } catch (error: any) {
    res.status(409).json({ error: error.message });
  }
});
```

### Paso 5: Inicializar en `server/index.ts`

```typescript
import { initializeWorkers } from './queue/workers';

const startServer = async () => {
  // ... código existente ...
  console.log('[Server] Initializing queue system...');
  await initializeWorkers(storage);
  console.log('[Server] ✅ Queue system ready');
  // ... resto ...
};
```

### Paso 6: `.env`

```bash
USE_QUEUE=true
QUEUE_ENABLED=false
```

---

## Rate Limiting con Adapter {#rate-limiting}

### Modificar `server/middleware/rate-limiter.ts`

```typescript
import { Request, Response, NextFunction } from 'express';

interface RateLimitOptions {
  maxRequests: number;
  windowSeconds: number;
  keyGenerator?: (req: Request) => string;
}

class SimpleRateLimiter {
  private requests: Map<string, Array<number>>;

  constructor() {
    this.requests = new Map();
    setInterval(() => {
      const now = Date.now();
      for (const [key, timestamps] of this.requests.entries()) {
        const filtered = timestamps.filter(ts => now - ts < 60000);
        if (filtered.length === 0) {
          this.requests.delete(key);
        } else {
          this.requests.set(key, filtered);
        }
      }
    }, 60000);
  }

  async check(key: string, maxRequests: number, windowSeconds: number) {
    const now = Date.now();
    const windowStart = now - windowSeconds * 1000;

    if (!this.requests.has(key)) {
      this.requests.set(key, []);
    }

    const timestamps = this.requests.get(key)!;
    const validTimestamps = timestamps.filter(ts => ts > windowStart);
    this.requests.set(key, validTimestamps);

    const currentCount = validTimestamps.length;
    const allowed = currentCount < maxRequests;
    const remaining = Math.max(0, maxRequests - currentCount - 1);
    const resetAt = now + windowSeconds * 1000;

    if (allowed) {
      validTimestamps.push(now);
      this.requests.set(key, validTimestamps);
    }

    return { allowed, remaining, resetAt };
  }
}

class RedisRateLimiter {
  private redis: any;

  constructor(redis: any) {
    this.redis = redis;
  }

  async check(key: string, maxRequests: number, windowSeconds: number) {
    const now = Date.now();
    const windowStart = now - windowSeconds * 1000;

    const pipe = this.redis.pipeline();
    pipe.zremrangebyscore(key, 0, windowStart);
    pipe.zcard(key);
    pipe.zadd(key, now, `${now}-${Math.random()}`);
    pipe.expire(key, windowSeconds);
    const results = await pipe.exec();

    if (!results) {
      return { allowed: true, remaining: maxRequests, resetAt: now + windowSeconds * 1000 };
    }

    const currentCount = results[1][1] as number;
    const allowed = currentCount < maxRequests;
    const remaining = Math.max(0, maxRequests - currentCount - 1);
    const resetAt = now + windowSeconds * 1000;

    return { allowed, remaining, resetAt };
  }
}

let rateLimiterInstance: SimpleRateLimiter | RedisRateLimiter | null = null;

function getRateLimiter() {
  if (rateLimiterInstance) return rateLimiterInstance;

  const useRedis = process.env.REDIS_HOST || process.env.REDIS_URL;
  
  if (useRedis) {
    try {
      const Redis = require('ioredis');
      const redis = new Redis({
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
        password: process.env.REDIS_PASSWORD || undefined,
        ...(process.env.REDIS_URL && { url: process.env.REDIS_URL }),
      });
      console.log('[RateLimiter] ✅ Using Redis');
      rateLimiterInstance = new RedisRateLimiter(redis);
    } catch (error) {
      console.error('[RateLimiter] ❌ Redis failed, using Simple:', error);
      rateLimiterInstance = new SimpleRateLimiter();
    }
  } else {
    console.log('[RateLimiter] ✅ Using Simple (testing)');
    rateLimiterInstance = new SimpleRateLimiter();
  }

  return rateLimiterInstance;
}

export function createRateLimiter(options: RateLimitOptions) {
  const { maxRequests, windowSeconds, keyGenerator } = options;
  
  return async (req: Request, res: Response, next: NextFunction) => {
    const limiter = getRateLimiter();
    const key = keyGenerator ? keyGenerator(req) : `rate_limit:${req.ip}`;
    
    try {
      const limit = await limiter.check(key, maxRequests, windowSeconds);
      
      if (!limit.allowed) {
        return res.status(429).json({
          error: 'Rate limit exceeded',
          retryAfter: Math.ceil((limit.resetAt - Date.now()) / 1000),
          limit: maxRequests,
          window: windowSeconds,
        });
      }
      
      res.setHeader('X-RateLimit-Limit', maxRequests.toString());
      res.setHeader('X-RateLimit-Remaining', limit.remaining.toString());
      res.setHeader('X-RateLimit-Reset', limit.resetAt.toString());
      
      next();
    } catch (error) {
      console.error('Rate limit error:', error);
      next();
    }
  };
}

export const rateLimitPresets = {
  voting: {
    maxRequests: 30,
    windowSeconds: 60,
    keyGenerator: (req: Request) => `rate_limit:vote:${req.body.userId || req.ip}`,
  },
  participation: {
    maxRequests: 10,
    windowSeconds: 60,
    keyGenerator: (req: Request) => `rate_limit:contest:${req.body.userId || req.ip}`,
  },
};
```

**Activar en endpoints:**
```typescript
import { createRateLimiter, rateLimitPresets } from './middleware/rate-limiter';

router.post('/v1/engagement/polls/:pollId/vote', 
  createRateLimiter(rateLimitPresets.voting),
  handler
);
```

---

## Migración a Producción {#produccion}

### Cuando Estés Listo

**Solo cambiar `.env`:**
```bash
USE_QUEUE=true
QUEUE_ENABLED=true
REDIS_HOST=your-redis-host
REDIS_PASSWORD=your-password
```

**Instalar:**
```bash
npm install bullmq ioredis
```

**✅ Mismo código, usando Redis.**

---

## Testing {#testing}

### Video Scheduling
1. Crear broadcast
2. Crear poll con `videoStartTime`, `videoEndTime`, `broadcastStartTime`
3. Verificar `scheduledStartTime` y `scheduledEndTime` calculados
4. Esperar cron job (o ajustar tiempos)
5. Verificar eventos WebSocket

### Message Queue
1. Ver logs: `[Queue] ✅ Using Simple in-memory adapter`
2. Crear voto → respuesta: `"Vote queued for processing"`
3. Ver logs: `[SimpleQueue] ✅ Job completed`
4. Verificar voto en DB

### Rate Limiting
1. Hacer 31 requests rápidas
2. Request 31 → 429
3. Verificar headers `X-RateLimit-*`

---

## Checklist {#checklist}

### Fase 5
- [ ] Descomentar `processScheduledPolls()` y `processScheduledContests()`
- [ ] Descomentar llamadas en cron job
- [ ] Verificar endpoints aceptan scheduling

### Fase 6
- [ ] Crear `queue-adapter.ts`
- [ ] Modificar `queues.ts` para usar adapter
- [ ] Modificar `workers.ts` para usar adapter
- [ ] Modificar endpoints para usar colas
- [ ] Agregar `initializeWorkers()` en `index.ts`
- [ ] Configurar `USE_QUEUE=true`

### Rate Limiting
- [ ] Modificar `rate-limiter.ts` con adapter
- [ ] Activar en endpoints
- [ ] Probar bloqueo

### Producción
- [ ] Configurar Redis
- [ ] Instalar `bullmq` y `ioredis`
- [ ] Actualizar `.env`
- [ ] Verificar logs

---

**Versión:** 2.0
**Fecha:** 2026-01-23
