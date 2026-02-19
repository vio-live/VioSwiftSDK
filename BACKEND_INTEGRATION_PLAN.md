# Plan de Integración Backend - Viaplay Casting Demo

## Objetivo
Duplicar la funcionalidad del demo de Viaplay usando el backend real, paso a paso, creando una campaña y broadcasting real.

---

## Fase 1: Setup Inicial y Configuración

### 1.1 Verificar Backend Disponible
- [ ] Verificar que el backend `socket-server` esté corriendo
- [ ] Verificar endpoints disponibles
- [ ] Verificar autenticación (API key)

### 1.2 Crear Campaña y Broadcasting en Backend
- [ ] Crear campaña de prueba en backend
- [ ] Crear broadcasting asociado a la campaña
- [ ] Obtener `broadcastId` para usar en el demo

### 1.3 Configurar Demo con Backend Real
- [ ] Actualizar `reachu-config.json` con URL del backend real
- [ ] Configurar `broadcastId` en el demo
- [ ] Verificar que `demoMode` esté desactivado

---

## Fase 2: Engagement System (Polls y Contests)

### 2.1 Crear Datos de Prueba en Backend
- [ ] Crear polls en el backend para el broadcasting
- [ ] Crear contests en el backend para el broadcasting
- [ ] Verificar que los datos se carguen correctamente

### 2.2 Conectar EngagementManager
- [ ] Verificar que `EngagementManager` use `BackendEngagementRepository`
- [ ] Probar carga de polls desde backend
- [ ] Probar carga de contests desde backend
- [ ] Verificar paginación funciona

### 2.3 Conectar Votación y Participación
- [ ] Conectar callback `onVote` en `ViaplayCastingActiveView`
- [ ] Conectar callback `onParticipate` en `ViaplayCastingActiveView`
- [ ] Probar envío de votos al backend
- [ ] Probar participación en contests
- [ ] Verificar que userId se envíe correctamente

### 2.4 WebSocket para Actualizaciones en Tiempo Real
- [ ] Conectar WebSocket para recibir actualizaciones de polls
- [ ] Conectar WebSocket para recibir actualizaciones de contests
- [ ] Mostrar resultados actualizados en tiempo real

---

## Fase 3: Chat System

### 3.1 Crear BackendChatRepository
- [ ] Crear protocolo `ChatRepositoryProtocol`
- [ ] Crear `BackendChatRepository` similar a `BackendEngagementRepository`
- [ ] Implementar `loadMessages(broadcastId:limit:offset:)`
- [ ] Implementar `sendMessage(broadcastId:userId:text:)`

### 3.2 Conectar ChatManager
- [ ] Actualizar `ChatManager` para usar `BackendChatRepository`
- [ ] Cargar mensajes históricos desde backend
- [ ] Enviar mensajes al backend
- [ ] Manejar errores y validaciones

### 3.3 WebSocket para Chat en Tiempo Real
- [ ] Conectar WebSocket para recibir mensajes nuevos
- [ ] Actualizar lista de mensajes en tiempo real
- [ ] Obtener viewer count desde backend

---

## Fase 4: WebSocket Unificado

### 4.1 Actualizar WebSocketManager
- [ ] Cambiar URL a backend real (`wss://socket-server/ws/:broadcastId`)
- [ ] Implementar autenticación con API key
- [ ] Implementar suscripción a room por broadcastId
- [ ] Manejar todos los tipos de eventos (polls, contests, products, chat, timeline)

### 4.2 Manejo de Eventos
- [ ] Poll events → actualizar `currentPoll`
- [ ] Contest events → actualizar `currentContest`
- [ ] Product events → actualizar `currentProduct`
- [ ] Chat events → agregar a `ChatManager`
- [ ] Timeline events → agregar a `UnifiedTimelineManager`

### 4.3 Reintentos y Manejo de Errores
- [ ] Implementar reintentos automáticos
- [ ] Manejar desconexiones
- [ ] Logging y debugging

---

## Fase 5: Timeline Events

### 5.1 Crear BackendTimelineRepository
- [ ] Crear protocolo `TimelineRepositoryProtocol`
- [ ] Crear `BackendTimelineRepository`
- [ ] Implementar `loadEvents(broadcastId:videoTime:limit:offset:)`

### 5.2 Conectar UnifiedTimelineManager
- [ ] Actualizar `UnifiedTimelineManager` para usar `BackendTimelineRepository`
- [ ] Cargar eventos históricos desde backend
- [ ] Sincronizar con video time
- [ ] Recibir eventos en tiempo real vía WebSocket

---

## Fase 6: Video Time Synchronization

### 6.1 Enviar Video Time al Backend
- [ ] Enviar video time actual al backend periódicamente
- [ ] Filtrar eventos por video time en requests
- [ ] Sincronizar eventos con posición del video

### 6.2 Eventos Sincronizados con Video
- [ ] Mostrar polls en el momento correcto del video
- [ ] Mostrar productos en el momento correcto
- [ ] Mostrar contests en el momento correcto
- [ ] Mostrar eventos de timeline sincronizados

---

## Fase 7: Testing y Validación

### 7.1 Testing End-to-End
- [ ] Probar flujo completo: crear campaña → crear broadcasting → crear polls/contests
- [ ] Probar votación y participación
- [ ] Probar chat completo
- [ ] Probar eventos en tiempo real
- [ ] Probar sincronización con video

### 7.2 Validación de Datos
- [ ] Verificar que todos los datos se muestren correctamente
- [ ] Verificar que las actualizaciones en tiempo real funcionen
- [ ] Verificar que no haya errores de red
- [ ] Verificar manejo de errores (404, 429, etc.)

---

## Checklist de Verificación

### Antes de Empezar
- [ ] Backend corriendo y accesible
- [ ] API key configurada
- [ ] Branch `feature/viaplay-backend-integration` creada
- [ ] Documentación del backend revisada

### Después de Cada Fase
- [ ] Código commiteado
- [ ] Funcionalidad probada
- [ ] Errores corregidos
- [ ] Documentación actualizada

---

## Notas

- Empezar con Engagement System porque ya está parcialmente implementado
- Luego Chat porque es crítico para la experiencia
- WebSocket unificado al final para consolidar todas las conexiones
- Testing continuo después de cada fase

