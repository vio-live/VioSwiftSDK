# Solución Temporal para Video Time Sync - Implementación Inmediata

**Fecha:** 2026-01-23  
**Objetivo:** Resolver el tema del video time sync con cambios mínimos al backend existente

---

## Estrategia: Solución Híbrida (SDK Local + Backend Opcional)

### Principio
- **SDK filtra localmente** basado en `videoStartTime`/`videoEndTime` (ya funciona)
- **Backend acepta `videoTime` como query param opcional** (cambio mínimo)
- Cuando el usuario hace rewind/forward, el SDK puede refrescar datos con el nuevo tiempo

---

## Cambios Mínimos Requeridos

### 1. Backend: Modificar Endpoints Existentes (Solo agregar query param)

#### 1.1 GET `/v1/engagement/polls?broadcastId=xxx`

**Cambio:** Agregar query param opcional `videoTime`

```typescript
// En server/routes.ts, modificar el handler existente:

app.get('/v1/engagement/polls', async (req, res) => {
  const { broadcastId, videoTime } = req.query;
  
  if (!broadcastId) {
    return res.status(400).json({ error: 'broadcastId is required' });
  }
  
  // Obtener todas las polls del broadcast
  const polls = await db.select()
    .from(polls)
    .where(eq(polls.broadcast_id, broadcastId));
  
  // Si videoTime está presente, filtrar por tiempo de video
  let filteredPolls = polls;
  if (videoTime !== undefined) {
    const videoTimeNum = parseInt(videoTime as string, 10);
    
    filteredPolls = polls.filter(poll => {
      // Si tiene video scheduling, usar esos campos
      if (poll.video_start_time !== null && poll.video_end_time !== null) {
        return videoTimeNum >= poll.video_start_time && 
               videoTimeNum < poll.video_end_time;
      }
      // Si no tiene video scheduling, usar isActive
      return poll.is_active;
    });
  }
  
  // Cargar opciones y calcular porcentajes
  const pollsWithOptions = await Promise.all(
    filteredPolls.map(async (poll) => {
      const options = await db.select()
        .from(pollOptions)
        .where(eq(pollOptions.poll_id, poll.id))
        .orderBy(pollOptions.display_order);
      
      const totalVotes = poll.total_votes || 0;
      const optionsWithPercentages = options.map(opt => ({
        ...opt,
        percentage: totalVotes > 0 
          ? Math.round((opt.vote_count / totalVotes) * 10000) / 100 
          : 0
      }));
      
      return {
        ...poll,
        options: optionsWithPercentages
      };
    })
  );
  
  res.json(pollsWithOptions);
});
```

#### 1.2 GET `/v1/engagement/contests?broadcastId=xxx`

**Cambio:** Mismo patrón, agregar query param `videoTime`

```typescript
app.get('/v1/engagement/contests', async (req, res) => {
  const { broadcastId, videoTime } = req.query;
  
  if (!broadcastId) {
    return res.status(400).json({ error: 'broadcastId is required' });
  }
  
  const contests = await db.select()
    .from(contests)
    .where(eq(contests.broadcast_id, broadcastId));
  
  // Filtrar por videoTime si está presente
  let filteredContests = contests;
  if (videoTime !== undefined) {
    const videoTimeNum = parseInt(videoTime as string, 10);
    
    filteredContests = contests.filter(contest => {
      if (contest.video_start_time !== null && contest.video_end_time !== null) {
        return videoTimeNum >= contest.video_start_time && 
               videoTimeNum < contest.video_end_time;
      }
      return contest.is_active;
    });
  }
  
  res.json(filteredContests);
});
```

**Tiempo de implementación:** ~15 minutos  
**Riesgo:** Muy bajo (solo agregar query param opcional)

---

## 2. SDK iOS: Modificar EngagementManager (Opcional, mejora UX)

### 2.1 Agregar método para refrescar con videoTime

```swift
// En EngagementManager.swift

/// Refresca polls y contests basado en tiempo de video actual
/// Útil cuando el usuario hace rewind/forward durante casting
func refreshEngagement(for broadcastContext: BroadcastContext, videoTime: Int?) async {
    guard let broadcastId = broadcastContext.broadcastId else { return }
    
    // Construir query params
    var queryParams = ["broadcastId": broadcastId]
    if let videoTime = videoTime {
        queryParams["videoTime"] = "\(videoTime)"
    }
    
    // Refrescar polls
    do {
        let polls = try await sdkClient.fetchPolls(
            broadcastId: broadcastId,
            videoTime: videoTime
        )
        // Actualizar estado local
        self.polls = polls
    } catch {
        ReachuLogger.error("Failed to refresh polls: \(error)", component: "EngagementManager")
    }
    
    // Refrescar contests
    do {
        let contests = try await sdkClient.fetchContests(
            broadcastId: broadcastId,
            videoTime: videoTime
        )
        self.contests = contests
    } catch {
        ReachuLogger.error("Failed to refresh contests: \(error)", component: "EngagementManager")
    }
}
```

### 2.2 Modificar VideoSyncManager para refrescar cuando cambia tiempo significativamente

```swift
// En VideoSyncManager.swift

private var lastReportedVideoTime: Int? = nil
private let VIDEO_TIME_REFRESH_THRESHOLD = 10 // segundos

public func updateVideoTime(_ time: Int, reportToBackend: Bool = false) {
    let previousTime = currentVideoTime
    currentVideoTime = time
    
    // Si el cambio es significativo (rewind/forward), refrescar engagement
    if let previous = previousTime,
       let broadcastId = currentBroadcastId,
       abs(time - previous) > VIDEO_TIME_REFRESH_THRESHOLD {
        
        Task { @MainActor in
            await EngagementManager.shared.refreshEngagement(
                for: BroadcastContext(broadcastId: broadcastId),
                videoTime: time
            )
        }
    }
    
    // También refrescar periódicamente (cada 30 segundos)
    if reportToBackend {
        let shouldRefresh = lastReportedVideoTime == nil || 
                           (lastReportedVideoTime.map { abs(time - $0) >= 30 } ?? true)
        
        if shouldRefresh {
            lastReportedVideoTime = time
            Task { @MainActor in
                if let broadcastId = currentBroadcastId {
                    await EngagementManager.shared.refreshEngagement(
                        for: BroadcastContext(broadcastId: broadcastId),
                        videoTime: time
                    )
                }
            }
        }
    }
}
```

**Tiempo de implementación:** ~30 minutos  
**Riesgo:** Bajo (solo mejora, no rompe funcionalidad existente)

---

## 3. Flujo de Funcionamiento

### Escenario Normal (sin cambios)
```
1. Usuario inicia casting
2. SDK carga todas las polls/contests del broadcast
3. SDK filtra localmente basado en videoTime actual
4. Funciona perfectamente ✅
```

### Escenario con Rewind/Forward (con cambios)
```
1. Usuario está en videoTime=300, ve poll activa
2. Usuario hace rewind → videoTime cambia a 150
3. VideoSyncManager detecta cambio > 10 segundos
4. SDK llama refreshEngagement(videoTime: 150)
5. Backend filtra polls/contests activas en videoTime=150
6. SDK actualiza UI con polls/contests correctas ✅
```

---

## 4. Ventajas de Esta Solución

✅ **Mínimos cambios al backend** (solo agregar query param opcional)  
✅ **Backward compatible** (si no se envía videoTime, funciona como antes)  
✅ **No requiere nueva infraestructura** (no necesita WebSocket adicional, ni tracking de dispositivos)  
✅ **Funciona offline** (SDK puede seguir filtrando localmente si falla la red)  
✅ **Mejora UX inmediata** (rewind/forward funciona correctamente)

---

## 5. Limitaciones (Aceptables por ahora)

⚠️ **No sincroniza entre múltiples dispositivos** (cada dispositivo tiene su propio tiempo)  
⚠️ **No emite eventos WebSocket automáticos** (el SDK debe hacer polling)  
⚠️ **No valida votos basado en videoTime** (se puede agregar después)

**Estas limitaciones son aceptables para una solución temporal.**

---

## 6. Plan de Implementación

### Paso 1: Backend (15 min)
1. Modificar `GET /v1/engagement/polls` para aceptar `videoTime` query param
2. Modificar `GET /v1/engagement/contests` para aceptar `videoTime` query param
3. Filtrar resultados basado en `video_start_time`/`video_end_time` si `videoTime` está presente
4. Probar con Postman/curl

### Paso 2: SDK iOS (30 min, opcional)
1. Agregar método `refreshEngagement(videoTime:)` en `EngagementManager`
2. Modificar `VideoSyncManager.updateVideoTime()` para refrescar cuando hay cambios significativos
3. Probar con casting y rewind/forward

### Paso 3: Testing
1. Probar casting normal (sin videoTime) → debe funcionar igual
2. Probar casting con rewind/forward → debe refrescar correctamente
3. Probar offline → debe seguir funcionando con filtrado local

---

## 7. Código de Ejemplo Completo (Backend)

```typescript
// En server/routes.ts, buscar el handler existente y modificarlo:

// ANTES:
app.get('/v1/engagement/polls', async (req, res) => {
  const { broadcastId } = req.query;
  // ... código existente ...
});

// DESPUÉS:
app.get('/v1/engagement/polls', async (req, res) => {
  const { broadcastId, videoTime } = req.query;
  
  if (!broadcastId) {
    return res.status(400).json({ error: 'broadcastId is required' });
  }
  
  // Obtener polls del broadcast
  let polls = await db.select()
    .from(polls)
    .where(eq(polls.broadcast_id, broadcastId));
  
  // Filtrar por videoTime si está presente
  if (videoTime !== undefined) {
    const videoTimeNum = parseInt(videoTime as string, 10);
    polls = polls.filter(poll => {
      // Si tiene video scheduling, usar esos campos
      if (poll.video_start_time !== null && poll.video_end_time !== null) {
        return videoTimeNum >= poll.video_start_time && 
               videoTimeNum < poll.video_end_time;
      }
      // Si no tiene video scheduling, usar isActive
      return poll.is_active;
    });
  } else {
    // Si no hay videoTime, filtrar solo por isActive
    polls = polls.filter(poll => poll.is_active);
  }
  
  // Resto del código existente (cargar opciones, calcular porcentajes, etc.)
  // ... código existente ...
  
  res.json(pollsWithOptions);
});
```

---

## 8. Próximos Pasos (Futuro)

Una vez que esta solución temporal esté funcionando, podemos implementar:

1. **Endpoint POST `/v1/engagement/video-time`** para reportar tiempo activamente
2. **Eventos WebSocket automáticos** cuando polls/contests se activan/desactivan
3. **Validación de votos basada en videoTime**
4. **Sincronización entre múltiples dispositivos**

Pero por ahora, esta solución temporal resuelve el problema inmediato con cambios mínimos.

---

**Fin del Documento**
