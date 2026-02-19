# Tarjetas de Trello a Crear - Cambios desde Último Merge

## IDs Configurados
- **Board ID:** `5dea6d99c0ea505b4c3a435e` (Reachu Dev)
- **List ID:** `645e0787a4ef6845516d172b` (Backlog)

## Tarjetas a Crear

### 1. Swift SDK: Video Synchronization System

**Nombre:** `Swift SDK: Video Synchronization System`

**Descripción:**
```
Implement video synchronization for polls and contests

**Archivos creados/modificados:**
- `Sources/ReachuEngagementSystem/Managers/VideoSyncManager.swift` (nuevo)
- `Sources/ReachuEngagementSystem/Models/EngagementModels.swift` (actualizado)
- `Sources/ReachuEngagementSystem/Managers/EngagementManager.swift` (actualizado)
- `Sources/ReachuEngagementSystem/Data/BackendEngagementRepository.swift` (actualizado)
- `Demo/Viaplay/Viaplay/Views/ViaplayCastingActiveView.swift` (actualizado)
- `Documentation/VIDEO_SYNC_API_SPEC.md` (nuevo)

**Funcionalidad:**
- Sincronización de polls/contests con tiempo de reproducción del video
- Soporte para videos en vivo y grabados
- Timestamps relativos al inicio del partido (videoStartTime, videoEndTime)
- Fallback a timestamps absolutos para backward compatibility

**Estado:** ✅ Implementado en SDK
```

**Checklist:**
- VideoSyncManager creado y funcionando
- Modelos actualizados con campos de video sync
- EngagementManager integrado con VideoSyncManager
- BackendEngagementRepository parsea nuevos campos
- ViaplayCastingActiveView integrado con VideoSyncManager
- Documentación VIDEO_SYNC_API_SPEC.md creada

**Tags:** `swift`, `sdk`, `video`, `polls`, `integration`, `priority-high`

---

### 2. Swift SDK: Dynamic Configuration System

**Nombre:** `Swift SDK: Dynamic Configuration System`

**Descripción:**
```
Implement dynamic configuration management from backend

**Archivos creados/modificados:**
- `Sources/ReachuCore/Managers/DynamicConfigurationManager.swift` (nuevo)
- `Sources/ReachuCore/Models/DynamicConfigModels.swift` (nuevo)
- `Sources/ReachuCore/Network/ConfigAPIClient.swift` (nuevo)
- `Sources/ReachuCore/Managers/CampaignManager.swift` (actualizado)
- `Sources/ReachuCore/Configuration/ReachuConfiguration.swift` (actualizado)
- `Documentation/BACKEND_API_SPEC.md` (nuevo)
- `Documentation/BACKEND_IMPLEMENTATION_GUIDE.md` (nuevo)
- `Documentation/BACKEND_QA_RESPONSES.md` (nuevo)

**Funcionalidad:**
- Carga de configuración dinámica desde backend
- Caché de configuraciones con TTL
- Invalidación de caché vía WebSocket
- Configuración efectiva que prioriza dinámica sobre estática
- Soporte para brand, engagement, UI, theme, feature flags, localization

**Estado:** ✅ Implementado en SDK
```

**Checklist:**
- DynamicConfigurationManager creado
- DynamicConfigModels definidos
- ConfigAPIClient implementado
- CampaignManager integrado
- ReachuConfiguration actualizado con effectiveBrandConfiguration
- Documentación BACKEND_API_SPEC.md creada
- Documentación BACKEND_IMPLEMENTATION_GUIDE.md creada
- Documentación BACKEND_QA_RESPONSES.md creada

**Tags:** `swift`, `sdk`, `configuration`, `api`, `backend`, `priority-high`

---

### 3. Swift SDK: Engagement Repository Pattern

**Nombre:** `Swift SDK: Engagement Repository Pattern`

**Descripción:**
```
Refactor engagement system to use repository pattern for demo/backend switching

**Archivos creados/modificados:**
- `Sources/ReachuEngagementSystem/Data/EngagementRepositoryProtocol.swift` (nuevo)
- `Sources/ReachuEngagementSystem/Data/BackendEngagementRepository.swift` (nuevo)
- `Sources/ReachuEngagementSystem/Data/DemoEngagementRepository.swift` (nuevo)
- `Sources/ReachuEngagementSystem/Managers/EngagementManager.swift` (refactorizado)
- `Demo/Viaplay/Viaplay/ViaplayApp.swift` (actualizado)

**Funcionalidad:**
- Repository pattern para abstraer fuente de datos
- Demo mode usando datos mock
- Backend mode usando API REST
- Cambio dinámico entre modos según configuración
- Soporte para múltiples partidos simultáneos

**Estado:** ✅ Implementado en SDK
```

**Checklist:**
- EngagementRepositoryProtocol definido
- BackendEngagementRepository implementado
- DemoEngagementRepository implementado
- EngagementManager refactorizado para usar repositorios
- Demo app configurada con closures para conversión de eventos

**Tags:** `swift`, `sdk`, `polls`, `contests`, `demo`, `backend`, `priority-high`

---

### 4. Backend: Video Sync API Implementation

**Nombre:** `Backend: Video Sync API Implementation`

**Descripción:**
```
Implement backend API endpoints for video synchronization

**Endpoints a implementar:**
- `GET /v1/engagement/polls` - Agregar campos videoStartTime, videoEndTime, matchStartTime
- `GET /v1/engagement/contests` - Agregar campos videoStartTime, videoEndTime, matchStartTime
- `GET /v1/engagement/config` - Agregar matchStartTime

**Cambios en base de datos:**
- Agregar columnas video_start_time, video_end_time, match_start_time a polls
- Agregar columnas video_start_time, video_end_time, match_start_time a contests
- Asegurar que matches table tiene match_start_time

**Documentación:** Ver `Documentation/VIDEO_SYNC_API_SPEC.md`

**Estado:** ⏳ Pendiente implementación backend
```

**Checklist:**
- Actualizar esquema de base de datos (polls y contests)
- Implementar campos videoStartTime/videoEndTime en endpoints
- Implementar campo matchStartTime en endpoints
- Actualizar queries SQL para incluir nuevos campos
- Probar endpoints con datos de ejemplo
- Validar cálculo de timestamps relativos

**Tags:** `backend`, `api`, `database`, `video`, `polls`, `contests`, `priority-high`

---

### 5. Backend: Dynamic Configuration API Implementation

**Nombre:** `Backend: Dynamic Configuration API Implementation`

**Descripción:**
```
Implement backend API endpoints for dynamic configuration

**Endpoints a implementar:**
- `GET /v1/campaigns/{campaignId}/config` - Configuración completa de campaña
- `GET /v1/engagement/config` - Configuración de engagement
- `GET /v1/localization/{language}` - Traducciones
- WebSocket event `config:updated` - Invalidación de caché

**Cambios en base de datos:**
- Crear tablas según BACKEND_IMPLEMENTATION_GUIDE.md
- Implementar queries para configuraciones dinámicas
- Implementar sistema de caché con TTL

**Documentación:** Ver `Documentation/BACKEND_API_SPEC.md` y `Documentation/BACKEND_IMPLEMENTATION_GUIDE.md`

**Estado:** ⏳ Pendiente implementación backend
```

**Checklist:**
- Crear tablas según BACKEND_IMPLEMENTATION_GUIDE.md
- Implementar endpoint GET /v1/campaigns/{campaignId}/config
- Implementar endpoint GET /v1/engagement/config
- Implementar endpoint GET /v1/localization/{language}
- Implementar evento WebSocket config:updated
- Implementar sistema de caché con TTL
- Probar endpoints con datos de ejemplo

**Tags:** `backend`, `api`, `database`, `configuration`, `websocket`, `priority-high`

---

## Script para Crear Tarjetas

El script `create_trello_cards_new_features.py` está listo para ejecutarse cuando tengas conexión a internet.

**Para ejecutar:**
```bash
cd /Users/angelo/ReachuSwiftSDK
python3 create_trello_cards_new_features.py
```

**Nota:** Asegúrate de tener las variables de entorno `TRELLO_API_KEY` y `TRELLO_TOKEN` configuradas en el archivo `.env` del servidor MCP de Trello.
