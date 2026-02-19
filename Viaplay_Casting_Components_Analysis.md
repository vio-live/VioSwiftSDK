# Viaplay Casting Demo - Componentes y Funcionalidades

## Resumen Ejecutivo

Este documento lista todos los componentes del demo de Viaplay para casting, sus funcionalidades actuales y qué necesita conectarse con el backend.

---

## 1. Views Principales

### 1.1 ViaplayCastingActiveView
**Ubicación:** `Demo/Viaplay/Viaplay/Views/ViaplayCastingActiveView.swift`

**Funcionalidades Actuales:**
- ✅ Muestra vista cuando casting está activo
- ✅ Header con información del match y botón "Stop Casting"
- ✅ Información del match (título, subtítulo, progreso)
- ✅ Controles de reproducción (play/pause, rewind 30s, forward 30s)
- ✅ Overlays de engagement (polls, productos, contests)
- ✅ Panel de chat expandible/colapsable
- ✅ Floating likes animation
- ✅ Floating cart indicator
- ✅ Sincronización de video time con VideoSyncManager
- ✅ Setup de broadcast context para campaigns

**Estado Backend:**
- ⚠️ Usa `WebSocketManager` local (demo) - necesita conectar con backend WebSocket
- ⚠️ Usa `ChatManager` local (simulación) - necesita conectar con backend chat API
- ⚠️ Usa `EngagementManager` pero con datos demo - ya conectado parcialmente
- ✅ Setup de broadcast context implementado

**Necesita Backend:**
- [ ] Conectar WebSocketManager con backend real (`wss://socket-server`)
- [ ] Conectar ChatManager con backend REST API (`/v1/chat/messages`)
- [ ] Enviar mensajes de chat al backend (`POST /v1/chat/messages`)
- [ ] Enviar likes/reacciones al backend
- [ ] Sincronizar video time con backend para eventos en tiempo real

---

### 1.2 ViaplayVideoPlayer
**Ubicación:** `Demo/Viaplay/Viaplay/Components/ViaplayVideoPlayer.swift`

**Funcionalidades Actuales:**
- ✅ Reproductor de video con AVPlayer
- ✅ Controles de video (play/pause, seek, mute, velocidad)
- ✅ Barra de progreso
- ✅ Overlays de engagement (polls, productos, contests)
- ✅ Chat overlay integrado
- ✅ Live badge
- ✅ Top bar con navegación y botones (share, AirPlay)
- ✅ Bottom controls con controles de reproducción
- ✅ Auto-hide de controles después de 3 segundos
- ✅ Soporte para orientación landscape/portrait
- ✅ Fetch de productos desde GraphQL API
- ✅ Integración con CartManager
- ✅ Setup de broadcast context

**Estado Backend:**
- ⚠️ Usa `WebSocketManager` local - necesita backend WebSocket
- ✅ Fetch de productos desde GraphQL (ya conectado)
- ✅ Integración con EngagementManager (parcialmente conectado)

**Necesita Backend:**
- [ ] Conectar WebSocket para eventos en tiempo real
- [ ] Enviar votos de polls al backend (`POST /v1/engagement/polls/:id/vote`)
- [ ] Enviar participaciones en contests al backend (`POST /v1/engagement/contests/:id/participate`)
- [ ] Sincronizar video time con backend para eventos timeline

---

## 2. Managers y Servicios

### 2.1 WebSocketManager
**Ubicación:** `Demo/Viaplay/Viaplay/Services/WebSocketManager.swift`

**Funcionalidades Actuales:**
- ✅ Conexión WebSocket a servidor demo (`wss://event-streamer-angelo100.replit.app/ws/3`)
- ✅ Recibe eventos de tipo: `product`, `poll`, `contest`
- ✅ Publica `currentPoll`, `currentProduct`, `currentContest`
- ✅ Manejo de desconexión/reconexión
- ✅ Parsing de eventos JSON

**Estado Backend:**
- ❌ Conectado a servidor demo, NO al backend real

**Necesita Backend:**
- [ ] Cambiar URL a backend real (`wss://socket-server/ws/:broadcastId`)
- [ ] Autenticación con API key o token
- [ ] Suscripción a room por broadcastId
- [ ] Manejo de eventos adicionales (chat, timeline events)
- [ ] Reintentos automáticos en caso de desconexión

---

### 2.2 ChatManager
**Ubicación:** `Demo/Viaplay/Viaplay/Managers/Chat/ChatManager.swift`

**Funcionalidades Actuales:**
- ✅ Simulación de mensajes de chat
- ✅ Lista de usuarios simulados con colores
- ✅ Mensajes simulados en noruego
- ✅ Viewer count simulado
- ✅ Integración opcional con UnifiedTimelineManager
- ✅ Carga de mensajes desde timeline
- ✅ Límite de 100 mensajes en memoria

**Estado Backend:**
- ❌ Completamente simulado, NO conectado al backend

**Necesita Backend:**
- [ ] Cargar mensajes desde backend (`GET /v1/chat/messages?broadcastId=...`)
- [ ] Enviar mensajes al backend (`POST /v1/chat/messages`)
- [ ] Recibir mensajes en tiempo real vía WebSocket
- [ ] Obtener viewer count desde backend
- [ ] Moderación de mensajes (reportar, eliminar)
- [ ] Paginación de mensajes históricos

---

### 2.3 CastingManager
**Ubicación:** `Demo/Viaplay/Viaplay/Services/CastingManager.swift`

**Funcionalidades Actuales:**
- ✅ Simulación de dispositivos de casting (Chromecast, AirPlay)
- ✅ Estado de casting (isCasting, isConnecting)
- ✅ Dispositivo seleccionado
- ✅ Lista de dispositivos disponibles (hardcoded)
- ✅ Start/stop casting

**Estado Backend:**
- ❌ Completamente simulado

**Necesita Backend:**
- [ ] Integración con Google Cast SDK o AirPlay SDK real
- [ ] Descubrimiento real de dispositivos
- [ ] Notificar al backend cuando se inicia casting (opcional)
- [ ] Sincronización de estado entre dispositivos

---

### 2.4 UnifiedTimelineManager
**Ubicación:** `Demo/Viaplay/Viaplay/Managers/Timeline/UnifiedTimelineManager.swift`

**Funcionalidades Actuales:**
- ✅ Gestión de timeline unificado para todos los eventos
- ✅ Sincronización con video time
- ✅ Filtrado de eventos por tipo y categoría
- ✅ Soporte para pre-match, first half, half-time, second half
- ✅ Eventos: chat, goals, polls, tweets, products, admin comments, announcements
- ✅ Export/import de eventos (preparado para backend)
- ✅ Type-safe getters para diferentes tipos de eventos

**Estado Backend:**
- ⚠️ Preparado para backend pero NO conectado

**Necesita Backend:**
- [ ] Cargar timeline events desde backend (`GET /v1/timeline/events?broadcastId=...`)
- [ ] Recibir eventos en tiempo real vía WebSocket
- [ ] Sincronizar video time con backend
- [ ] Enviar eventos generados localmente al backend

---

## 3. Componentes UI

### 3.1 ViaplayChatOverlay
**Ubicación:** `Demo/Viaplay/Viaplay/Components/ViaplayChatOverlay.swift`

**Funcionalidades Actuales:**
- ✅ Panel de chat expandible/colapsable con drag gesture
- ✅ Lista de mensajes con scroll automático
- ✅ Input bar para enviar mensajes
- ✅ Botón de like/floating like
- ✅ Sponsor badge integrado
- ✅ Manejo de teclado
- ✅ Soporte para landscape/portrait
- ✅ Integración con ChatManager

**Estado Backend:**
- ⚠️ UI completa pero usa ChatManager simulado

**Necesita Backend:**
- [ ] Conectar con ChatManager real (que use backend)
- [ ] Enviar mensajes al backend cuando se escriben
- [ ] Mostrar mensajes recibidos del backend

---

### 3.2 Engagement Components (REngagementPollCard, REngagementContestCard, REngagementProductCard)
**Ubicación:** `Sources/ReachuEngagementUI/Components/`

**Funcionalidades Actuales:**
- ✅ Display de polls con opciones y votación
- ✅ Display de contests con participación
- ✅ Display de productos con agregar al carrito
- ✅ Auto-dismiss después de duración
- ✅ Integración con EngagementManager

**Estado Backend:**
- ✅ Parcialmente conectado (EngagementManager ya tiene soporte backend)
- ⚠️ Los votos y participaciones aún no se envían al backend en el demo

**Necesita Backend:**
- [ ] Conectar callbacks `onVote` y `onParticipate` con EngagementManager
- [ ] Enviar votos al backend (`POST /v1/engagement/polls/:id/vote`)
- [ ] Enviar participaciones al backend (`POST /v1/engagement/contests/:id/participate`)
- [ ] Recibir actualizaciones de resultados en tiempo real vía WebSocket

---

## 4. Modelos de Datos

### 4.1 Match Models
**Ubicación:** `Demo/Viaplay/Viaplay/Models/MatchModels.swift`

**Funcionalidades Actuales:**
- ✅ Modelo `Match` con información del partido
- ✅ Conversión a `BroadcastContext`
- ✅ Datos demo hardcoded

**Estado Backend:**
- ⚠️ Modelo listo pero datos demo

**Necesita Backend:**
- [ ] Cargar matches desde backend
- [ ] Sincronizar información del match en tiempo real

---

### 4.2 Chat Models
**Ubicación:** `Demo/Viaplay/Viaplay/Models/Chat/ChatModels.swift`

**Funcionalidades Actuales:**
- ✅ Modelo `ChatMessage` con username, text, color, likes, timestamp
- ✅ Soporte para videoTimestamp
- ✅ Conversión a TimelineEvent

**Estado Backend:**
- ✅ Modelo listo para backend

**Necesita Backend:**
- [ ] Mapear desde respuesta del backend
- [ ] Validar datos recibidos

---

### 4.3 Timeline Event Models
**Ubicación:** `Demo/Viaplay/Viaplay/Models/Timeline/`

**Funcionalidades Actuales:**
- ✅ Protocolo `TimelineEvent` con tipos diversos
- ✅ Eventos: ChatMessageEvent, MatchGoalEvent, PollTimelineEvent, TweetEvent, ProductTimelineEvent, AdminCommentEvent, AnnouncementEvent
- ✅ Type-safe wrappers
- ✅ Export/import para backend

**Estado Backend:**
- ✅ Modelos listos para backend

**Necesita Backend:**
- [ ] Mapear desde respuesta del backend
- [ ] Validar y parsear eventos recibidos

---

## 5. Resumen de Conexiones Necesarias

### Prioridad Alta (Core Functionality)

1. **WebSocketManager → Backend**
   - Cambiar URL a backend real
   - Autenticación
   - Suscripción por broadcastId
   - Manejo de eventos: polls, contests, products, chat, timeline

2. **ChatManager → Backend REST API**
   - GET `/v1/chat/messages` para cargar mensajes
   - POST `/v1/chat/messages` para enviar mensajes
   - WebSocket para mensajes en tiempo real
   - Viewer count desde backend

3. **EngagementManager → Backend (Completar)**
   - Ya tiene soporte parcial
   - Conectar callbacks de votos y participaciones
   - Recibir actualizaciones en tiempo real

### Prioridad Media (Enhanced Features)

4. **UnifiedTimelineManager → Backend**
   - GET `/v1/timeline/events` para cargar eventos
   - WebSocket para eventos en tiempo real
   - Sincronización de video time

5. **Video Time Sync**
   - Enviar video time al backend para eventos sincronizados
   - Recibir eventos filtrados por video time

### Prioridad Baja (Nice to Have)

6. **CastingManager → Real SDKs**
   - Integración con Google Cast SDK
   - Integración con AirPlay SDK

---

## 6. Endpoints del Backend Necesarios

### Chat
- `GET /v1/chat/messages?broadcastId=...&limit=...&offset=...`
- `POST /v1/chat/messages` (body: { broadcastId, userId, text })
- WebSocket: `chat:message` event

### Timeline Events
- `GET /v1/timeline/events?broadcastId=...&videoTime=...&limit=...&offset=...`
- WebSocket: `timeline:event` event

### Engagement (Ya implementado parcialmente)
- `GET /v1/engagement/polls?broadcastId=...` ✅
- `POST /v1/engagement/polls/:id/vote` ✅
- `GET /v1/engagement/contests?broadcastId=...` ✅
- `POST /v1/engagement/contests/:id/participate` ✅
- WebSocket: `poll:update`, `contest:update` (necesario)

---

## 7. Plan de Implementación Sugerido

### Fase 1: Chat Backend Integration
1. Crear `BackendChatRepository` similar a `BackendEngagementRepository`
2. Conectar `ChatManager` con el repositorio
3. Implementar envío/recepción de mensajes
4. Conectar WebSocket para mensajes en tiempo real

### Fase 2: WebSocket Backend Integration
1. Actualizar `WebSocketManager` para usar backend real
2. Implementar autenticación y suscripción
3. Manejar todos los tipos de eventos
4. Reintentos y manejo de errores

### Fase 3: Timeline Backend Integration
1. Crear `BackendTimelineRepository`
2. Conectar `UnifiedTimelineManager` con el repositorio
3. Implementar carga de eventos históricos
4. Sincronización con video time

### Fase 4: Engagement Completion
1. Conectar callbacks de votos/participaciones
2. Recibir actualizaciones en tiempo real
3. Mostrar resultados actualizados

---

## 8. Notas Técnicas

- Todos los componentes ya tienen la estructura UI lista
- La mayoría de los managers tienen métodos preparados para backend
- Los modelos están listos para mapear desde JSON del backend
- Falta principalmente la capa de networking y conexión real

