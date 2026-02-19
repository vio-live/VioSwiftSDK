# Guía de Implementación Backend - Sistema de Campañas Context-Aware

## Estado de Implementación

✅ **IMPLEMENTADO Y PROBADO** - Todas las funcionalidades descritas en este documento han sido implementadas y verificadas en el backend (Replit).

## Resumen Ejecutivo

Este documento explica los cambios implementados en el backend (Replit) para soportar el nuevo sistema de campañas context-aware del SDK Swift. El sistema permite:

1. **Auto-discovery de campañas** usando solo la API key del SDK (sin necesidad de `campaignAdminApiKey`)
2. **Múltiples campañas simultáneas** asociadas a diferentes partidos (`matchId`)
3. **Componentes filtrados por contexto** (productos, banners, etc. específicos por partido)
4. **Validación de cache** basada en hash de configuración para invalidar cuando cambian las API keys

**Nota:** Este documento NO incluye el sistema de Engagement (polls/contests). Ver `BACKEND_ENGAGEMENT_IMPLEMENTATION.md` para esa funcionalidad.

---

## Conceptos Clave

### 1. MatchContext (Contexto de Partido)

El `MatchContext` es un identificador que asocia campañas y componentes a un partido específico:

```json
{
  "matchId": "barcelona-psg-2025-01-23",
  "matchName": "Barcelona vs PSG",
  "startTime": "2025-01-23T20:00:00Z",
  "channelId": 1,
  "metadata": {
    "competition": "Champions League",
    "round": "Round of 16"
  }
}
```

**Campos:**
- `matchId` (requerido): Identificador único del partido (string)
- `matchName` (opcional): Nombre legible del partido
- `startTime` (opcional): Timestamp ISO 8601 del inicio del partido
- `channelId` (opcional): **Mismo que `campaigns.channelId`** - ID del canal asociado (ej: "XXL iOS Channel"). Es el mismo campo que ya existe en la tabla `campaigns`, no es un ID de stream/TV diferente.
- `metadata` (opcional): Datos adicionales como diccionario

**Nota sobre channelId:**
- El `channelId` dentro de `matchContext` es el **mismo** que el `channelId` existente en la tabla `campaigns`
- Se usa para asociar campañas a channels como "XXL iOS Channel"
- No es un ID de stream/canal de TV diferente - es el mismo concepto
- Si la campaña ya tiene `channelId`, puede incluirse en `matchContext` para consistencia

### 2. Modo Auto-Discovery vs Legacy

**Modo Legacy (actual):**
- Requiere `campaignAdminApiKey` y `campaignId` explícito
- Una sola campaña activa
- Endpoint: `GET /v1/sdk/config?apiKey={campaignAdminApiKey}&campaignId={id}`

**Modo Auto-Discovery (nuevo):**
- Solo requiere la API key del SDK (`apiKey`)
- Descubre automáticamente todas las campañas activas
- Puede filtrar por `matchId` opcional
- Endpoint: `GET /v1/sdk/campaigns?apiKey={sdkApiKey}&matchId={matchId}`

---

## Cambios en Endpoints Existentes

### 1. GET /v1/sdk/config

**Cambio:** Agregar campo opcional `matchContext` en la respuesta.

**Respuesta actual:**
```json
{
  "campaignId": 28,
  "campaignName": "Elkjop",
  "campaignLogo": "https://...",
  "channelId": 1,
  "channelName": "XXL iOS Channel",
  "environment": "production",
  "campaigns": {
    "webSocketBaseURL": "https://dev-campaing.reachu.io",
    "restAPIBaseURL": "https://dev-campaing.reachu.io"
  },
  "marketFallback": {...},
  "features": {...}
}
```

**Respuesta nueva (con matchContext opcional):**
```json
{
  "campaignId": 28,
  "campaignName": "Elkjop",
  "campaignLogo": "https://...",
  "channelId": 1,
  "channelName": "XXL iOS Channel",
  "environment": "production",
  "matchContext": {
    "matchId": "barcelona-psg-2025-01-23",
    "matchName": "Barcelona vs PSG",
    "startTime": "2025-01-23T20:00:00Z",
    "channelId": 1,
    "metadata": {}
  },
  "campaigns": {
    "webSocketBaseURL": "https://dev-campaing.reachu.io",
    "restAPIBaseURL": "https://dev-campaing.reachu.io"
  },
  "marketFallback": {...},
  "features": {...}
}
```

**Lógica Backend:**
- Si la campaña está asociada a un partido, incluir `matchContext`
- Si no está asociada (campaña general), omitir el campo (backward compatible)
- El campo es completamente opcional - no rompe compatibilidad con código existente

### 2. GET /v1/offers (Componentes)

**Cambio:** Agregar campo opcional `matchContext` en cada componente de la respuesta.

**Respuesta actual:**
```json
{
  "campaignId": 28,
  "campaignName": "Elkjop",
  "campaignLogo": "https://...",
  "offers": [
    {
      "id": "product-banner-1",
      "type": "product_banner",
      "name": "Product Banner",
      "config": {...},
      "placement": "top"
    }
  ]
}
```

**Respuesta nueva:**
```json
{
  "campaignId": 28,
  "campaignName": "Elkjop",
  "campaignLogo": "https://...",
  "offers": [
    {
      "id": "product-banner-1",
      "type": "product_banner",
      "name": "Product Banner",
      "config": {...},
      "placement": "top",
      "matchContext": {
        "matchId": "barcelona-psg-2025-01-23",
        "matchName": "Barcelona vs PSG",
        "startTime": "2025-01-23T20:00:00Z",
        "channelId": 1
      }
    }
  ]
}
```

**Lógica Backend:**
- Si el componente está asociado a un partido específico, incluir `matchContext`
- Si es un componente general (sin partido), omitir el campo
- El SDK filtrará automáticamente los componentes según el `matchId` actual
- **Importante:** Si un componente tiene `matchContext`, solo se muestra cuando el SDK tiene ese `matchId` activo

---

## Nuevo Endpoint Requerido

### GET /v1/sdk/campaigns (Auto-Discovery)

✅ **IMPLEMENTADO** - Este endpoint está disponible y funcionando en el backend.

**Propósito:** Descubrir todas las campañas activas usando solo la API key del SDK.

**Request:**
```
GET /v1/sdk/campaigns?apiKey={sdkApiKey}&matchId={matchId}
```

**Headers (Opcional - Recomendado):**
- `X-App-Bundle-ID`: Bundle ID de la app (ej: `com.viaplay.app`) - Usado para identificación automática del cliente
- `X-App-Version`: Versión de la app (ej: `1.2.3`)
- `X-Platform`: Plataforma (ej: `ios`, `android`)

**Query Parameters:**
- `apiKey` (opcional si se usa identificación automática): API key del SDK (no `campaignAdminApiKey`)
- `matchId` (opcional): Filtrar campañas por partido específico

**Nota:** Si se envía el header `X-App-Bundle-ID`, el backend puede identificar automáticamente el cliente y obtener su `apiKey` desde la base de datos, haciendo que el parámetro `apiKey` sea opcional. Ver sección "API Key desde Backend (Recomendado)" para más detalles.

**Respuesta:**
```json
{
  "campaigns": [
    {
      "campaignId": 28,
      "campaignName": "Elkjop",
      "campaignLogo": "https://...",
      "matchContext": {
        "matchId": "barcelona-psg-2025-01-23",
        "matchName": "Barcelona vs PSG",
        "startTime": "2025-01-23T20:00:00Z",
        "channelId": 1
      },
      "isActive": true,
      "startDate": "2025-01-23T19:00:00Z",
      "endDate": "2025-01-23T22:00:00Z",
      "isPaused": false,
      "components": [
        {
          "id": "product-banner-1",
          "type": "product_banner",
          "name": "Product Banner",
          "matchContext": {
            "matchId": "barcelona-psg-2025-01-23"
          },
          "config": {...},
          "status": "active"
        }
      ]
    },
    {
      "campaignId": 29,
      "campaignName": "Power Campaign",
      "matchContext": {
        "matchId": "real-madrid-chelsea-2025-01-24"
      },
      "isActive": true,
      "components": [...]
    }
  ]
}
```

**Lógica Backend:**
1. Validar `apiKey` del SDK (no `campaignAdminApiKey`)
2. Si `matchId` está presente, filtrar campañas que tengan ese `matchId` en su `matchContext`
3. Retornar solo campañas activas:
   - `isActive: true`
   - Dentro de fechas (`startDate` <= ahora <= `endDate`)
   - No pausadas (`isPaused: false`)
4. Incluir componentes activos de cada campaña con su `matchContext`
5. Ordenar por `startDate` (más recientes primero)

**Autenticación:**
- Usar la misma validación que otros endpoints del SDK
- La `apiKey` debe ser válida y tener permisos para ver campañas
- **Diferencia importante:** Este endpoint usa `apiKey` del SDK, NO `campaignAdminApiKey`
- **Clarificación:** El `apiKey` usado aquí es el mismo `client_apps.api_key` que ya existe en la base de datos (ej: `xxl_api_key_507d4014243d8360`)
- **Nota sobre `reachuApiKey`:** Si existe un campo `reachuApiKey` en `client_apps`, puede usarse como alternativa, pero el SDK actualmente usa `client_apps.api_key` para auto-discovery
- **Identificación Automática (Recomendado):** Si se envía el header `X-App-Bundle-ID`, el backend puede identificar automáticamente el cliente y obtener su `apiKey` desde `client_apps` usando el `bundle_id`. Esto hace que el parámetro `apiKey` sea opcional y mejora la seguridad.

**Ejemplo de uso:**
```
# Método tradicional (con apiKey en query)
GET /v1/sdk/campaigns?apiKey=KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S

# Método recomendado (identificación automática)
GET /v1/sdk/campaigns
Headers:
  X-App-Bundle-ID: com.viaplay.app
  X-App-Version: 1.2.3
  X-Platform: ios

# Con matchId específico
GET /v1/sdk/campaigns?matchId=barcelona-psg-2025-01-23
Headers:
  X-App-Bundle-ID: com.viaplay.app
```

---

## API Key desde Backend (Recomendado)

### Problema Actual

Actualmente, el SDK requiere que la `apiKey` esté hardcodeada en el archivo de configuración (`reachu-config.json`). Esto presenta varios problemas:

1. **Seguridad:** La API key está expuesta en el código de la aplicación
2. **Flexibilidad:** Cambiar la API key requiere actualizar la app y hacer un release
3. **Multi-tenant:** Dificulta soportar múltiples clientes con diferentes API keys
4. **Gestión:** No hay forma centralizada de rotar o revocar API keys

### Solución Recomendada: Identificación Automática

El backend puede identificar automáticamente qué cliente está haciendo la petición usando el **Bundle ID** de la aplicación (o similar para Android). Esto permite:

- **Seguridad mejorada:** La API key nunca está en el cliente
- **Flexibilidad:** Cambiar la API key solo requiere cambios en el backend
- **Multi-tenant:** Soporte natural para múltiples clientes
- **Gestión centralizada:** Rotación y revocación de API keys desde el backend

### Implementación Backend

#### Opción 1: Identificación Automática (Recomendada)

**Cambios necesarios:**

1. **Agregar campo `bundle_id` a `client_apps`:**
   ```sql
   ALTER TABLE client_apps
   ADD COLUMN bundle_id VARCHAR(255) NULL UNIQUE,
   ADD INDEX idx_bundle_id (bundle_id);
   ```

2. **Modificar endpoint `/v1/sdk/campaigns`:**
   ```python
   # Pseudocódigo
   def get_campaigns(request):
       # Prioridad 1: Identificación automática por Bundle ID
       bundle_id = request.headers.get('X-App-Bundle-ID')
       if bundle_id:
           client_app = ClientApp.objects.filter(bundle_id=bundle_id).first()
           if client_app:
               api_key = client_app.api_key
           else:
               return error("Bundle ID no encontrado")
       else:
           # Prioridad 2: API key en query parameter (backward compatibility)
           api_key = request.query_params.get('apiKey')
           if not api_key:
               return error("Se requiere apiKey o X-App-Bundle-ID")
       
       # Validar api_key y obtener campañas...
   ```

3. **Lógica de identificación:**
   - Si existe `X-App-Bundle-ID` header:
     - Buscar `client_apps` por `bundle_id`
     - Si se encuentra, usar su `api_key`
     - Si no se encuentra, retornar error 401/404
   - Si NO existe `X-App-Bundle-ID`:
     - Usar `apiKey` del query parameter (backward compatibility)
     - Validar como antes

**Ventajas:**
- ✅ Máxima seguridad (API key nunca en el cliente)
- ✅ Backward compatible (sigue funcionando con `apiKey` en query)
- ✅ Fácil de implementar
- ✅ No requiere cambios en otros endpoints inmediatamente

#### Opción 2: Endpoint de Configuración Inicial

**Nuevo endpoint:** `/v1/sdk/init-config`

**Request:**
```
GET /v1/sdk/init-config
Headers:
  X-App-Bundle-ID: com.viaplay.app
  X-App-Version: 1.2.3
  X-Platform: ios
```

**Response:**
```json
{
  "apiKey": "KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S",
  "restAPIBaseURL": "https://dev-campaing.reachu.io",
  "webSocketBaseURL": "https://dev-campaing.reachu.io",
  "autoDiscover": true,
  "channelId": 1
}
```

**Lógica:**
1. Identificar cliente por `bundle_id`
2. Retornar configuración completa del SDK
3. El SDK usa esta configuración para todas las peticiones posteriores

**Ventajas:**
- ✅ Configuración centralizada
- ✅ Permite cambiar URLs y otros parámetros sin actualizar la app
- ✅ Útil para A/B testing y feature flags

**Desventajas:**
- ⚠️ Requiere un paso adicional de inicialización
- ⚠️ Más complejo de implementar

### Recomendación Final

**Implementar Opción 1 (Identificación Automática)** porque:
- Es más simple y directa
- Mejora la seguridad inmediatamente
- Es backward compatible
- No requiere cambios en el SDK inmediatamente (puede seguir enviando `apiKey` en query como fallback)

**Pasos de implementación:**

1. ✅ Agregar campo `bundle_id` a `client_apps` (migración)
2. ✅ Actualizar endpoint `/v1/sdk/campaigns` para soportar identificación automática
3. ✅ Mantener soporte para `apiKey` en query parameter (backward compatibility)
4. ✅ Documentar el nuevo flujo para el equipo del SDK
5. ⏳ (Futuro) Actualizar SDK para usar identificación automática por defecto

### Compatibilidad hacia atrás

- ✅ El endpoint sigue funcionando con `apiKey` en query parameter
- ✅ Clientes existentes no se ven afectados
- ✅ Nuevos clientes pueden usar identificación automática
- ✅ Transición gradual posible

### Casos de Prueba

**Test 1: Identificación automática exitosa**
```
GET /v1/sdk/campaigns
Headers: X-App-Bundle-ID: com.viaplay.app
Expected: 200 OK con campañas
```

**Test 2: Bundle ID no encontrado**
```
GET /v1/sdk/campaigns
Headers: X-App-Bundle-ID: com.unknown.app
Expected: 401/404 Error
```

**Test 3: Backward compatibility**
```
GET /v1/sdk/campaigns?apiKey=KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S
Expected: 200 OK con campañas (funciona como antes)
```

**Test 4: Prioridad - Bundle ID sobre apiKey**
```
GET /v1/sdk/campaigns?apiKey=WRONG_KEY
Headers: X-App-Bundle-ID: com.viaplay.app
Expected: 200 OK (usa apiKey del bundle_id, ignora query param)
```

---

## Cambios en WebSocket Events

✅ **IMPLEMENTADO** - Los eventos WebSocket ahora incluyen `matchId` opcional.

### Eventos que deben incluir `matchId`

Todos los eventos de WebSocket relacionados con componentes deben incluir `matchId` opcional:

**1. component_status_changed**
```json
{
  "type": "component_status_changed",
  "matchId": "barcelona-psg-2025-01-23",
  "data": {
    "componentId": 8,
    "campaignComponentId": 15,
    "componentType": "product_banner",
    "status": "active",
    "config": {...}
  }
}
```

**2. component_config_updated**
```json
{
  "type": "component_config_updated",
  "matchId": "barcelona-psg-2025-01-23",
  "component": {
    "id": "product-banner-1",
    "type": "product_banner",
    "name": "Product Banner",
    "config": {...},
    "matchContext": {
      "matchId": "barcelona-psg-2025-01-23"
    }
  }
}
```

**3. campaign_started**
```json
{
  "type": "campaign_started",
  "campaignId": 28,
  "matchId": "barcelona-psg-2025-01-23",
  "startDate": "2025-01-23T19:00:00Z",
  "endDate": "2025-01-23T22:00:00Z"
}
```

**Lógica Backend:**
- Si el componente/campaña está asociado a un partido, incluir `matchId` en el evento
- El SDK filtrará automáticamente eventos que no correspondan al `matchId` actual
- Si no hay `matchId`, el evento se aplica a todas las campañas (backward compatible)
- **Importante:** El campo `matchId` es opcional - eventos sin él siguen funcionando

---

## Estructura de Base de Datos

✅ **IMPLEMENTADO** - Todos los campos de match context han sido agregados a la base de datos.

### Tabla: campaigns
```sql
-- Nota: channel_id ya existe en esta tabla
-- Solo agregar los nuevos campos relacionados con matchContext

ALTER TABLE campaigns
ADD COLUMN match_id VARCHAR(255) NULL, -- Nuevo: asociación con partido
ADD COLUMN match_name VARCHAR(255) NULL, -- Nuevo: nombre del partido
ADD COLUMN match_start_time TIMESTAMP NULL, -- Nuevo: hora de inicio del partido
ADD INDEX idx_match_id (match_id);

-- channel_id ya existe, no necesita agregarse
-- Si se incluye channel_id en matchContext, usar el valor existente de campaigns.channel_id
```

**Nota sobre channel_id:**
- El campo `channel_id` **ya existe** en la tabla `campaigns`
- No necesita agregarse nuevamente
- Si se incluye `channelId` en `matchContext`, usar el valor existente de `campaigns.channel_id`
- Es el mismo concepto: asociación a channels como "XXL iOS Channel"

### Tabla: campaign_components
```sql
CREATE TABLE campaign_components (
  id INT PRIMARY KEY,
  campaign_id INT,
  component_id INT, -- Template component ID
  status VARCHAR(50), -- 'active' or 'inactive'
  custom_config JSON,
  match_id VARCHAR(255), -- Nuevo: asociación con partido
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  FOREIGN KEY (campaign_id) REFERENCES campaigns(id),
  INDEX idx_campaign_match (campaign_id, match_id),
  INDEX idx_status (status)
);
```

---

## Migraciones Necesarias

✅ **IMPLEMENTADO** - Todas las migraciones han sido aplicadas a la base de datos.

### Migración 1: Agregar campos de matchContext a campaigns
```sql
-- channel_id ya existe, NO agregarlo de nuevo
ALTER TABLE campaigns
ADD COLUMN match_id VARCHAR(255) NULL,
ADD COLUMN match_name VARCHAR(255) NULL,
ADD COLUMN match_start_time TIMESTAMP NULL,
ADD INDEX idx_match_id (match_id);
```

**Nota:** 
- Todos los campos son NULL para mantener compatibilidad con campañas existentes
- `channel_id` ya existe en la tabla, NO necesita agregarse
- Si se incluye `channelId` en `matchContext`, usar el valor existente de `campaigns.channel_id`

### Migración 2: Agregar match_id a campaign_components
```sql
ALTER TABLE campaign_components
ADD COLUMN match_id VARCHAR(255) NULL,
ADD INDEX idx_campaign_match (campaign_id, match_id);
```

**Nota:** El campo es NULL para componentes generales (sin partido específico).

### Migración 3: Agregar bundle_id a client_apps (Para identificación automática)
```sql
ALTER TABLE client_apps
ADD COLUMN bundle_id VARCHAR(255) NULL UNIQUE,
ADD INDEX idx_bundle_id (bundle_id);
```

**Nota:** 
- Campo opcional para soportar identificación automática de clientes
- `UNIQUE` asegura que cada bundle_id solo esté asociado a un cliente
- Permite que el backend identifique automáticamente qué `apiKey` usar basándose en el Bundle ID de la app
- Ver sección "API Key desde Backend (Recomendado)" para más detalles

---

## Validaciones y Reglas de Negocio

### 1. Validación de matchId
- `matchId` debe ser único por partido
- Formato sugerido: `{home_team}-{away_team}-{date}` (ej: `barcelona-psg-2025-01-23`)
- No debe contener espacios ni caracteres especiales (usar guiones)
- Validar que `matchId` no esté vacío si se proporciona

### 2. Filtrado de Componentes
- Si un componente tiene `matchId`, solo se muestra cuando el SDK tiene ese `matchId` activo
- Si un componente NO tiene `matchId`, se muestra siempre (componente general)
- **Seguridad:** El SDK NO muestra componentes sin `matchId` cuando hay un `matchId` activo (para evitar mostrar componentes de otros partidos)

### 3. Auto-Discovery
- Solo retornar campañas activas (dentro de fechas, no pausadas)
- Si `matchId` está presente en el request, filtrar por ese `matchId`
- Si `matchId` no está presente, retornar todas las campañas activas
- Incluir componentes activos de cada campaña

### 4. Cache Invalidation
- El SDK calcula un hash basado en `campaignId`, `campaignAdminApiKey` y `baseURL`
- Si alguno de estos cambia, el SDK invalida automáticamente el cache
- El backend no necesita hacer nada especial, solo retornar los datos correctos

---

## Flujo de Trabajo Completo

### Escenario 1: Auto-Discovery con matchId

1. **SDK Inicializa:**
   - Lee `autoDiscover: true` de configuración
   - Usa solo `apiKey` del SDK (no `campaignAdminApiKey`)

2. **Usuario selecciona partido:**
   - SDK llama `setMatchContext({ matchId: "barcelona-psg-2025-01-23" })`

3. **SDK descubre campañas:**
   - `GET /v1/sdk/campaigns?apiKey={sdkApiKey}&matchId=barcelona-psg-2025-01-23`
   - Backend retorna solo campañas con ese `matchId`

4. **SDK carga componentes:**
   - Filtra componentes por `matchId` automáticamente
   - Solo muestra componentes que pertenecen al partido actual

5. **WebSocket Events:**
   - Backend envía eventos con `matchId`
   - SDK filtra eventos por `matchId` actual

### Escenario 2: Modo Legacy (sin matchId)

1. **SDK Inicializa:**
   - Lee `autoDiscover: false` y `campaignId: 28`
   - Usa `campaignAdminApiKey` para autenticación

2. **SDK carga campaña:**
   - `GET /v1/sdk/config?apiKey={campaignAdminApiKey}&campaignId=28`
   - Backend retorna configuración (sin `matchContext` si no está asociada)

3. **SDK carga componentes:**
   - `GET /v1/offers?apiKey={campaignAdminApiKey}&campaignId=28`
   - Backend retorna componentes (sin `matchContext` si son generales)

4. **Funciona igual que antes** (backward compatible)

### Escenario 3: Múltiples Campañas Simultáneas

1. **Usuario ve partido 1:**
   - SDK establece `matchId: "barcelona-psg-2025-01-23"`
   - Descubre campaña 28 para ese partido
   - Muestra componentes de campaña 28

2. **Usuario cambia a partido 2:**
   - SDK establece `matchId: "real-madrid-chelsea-2025-01-24"`
   - Descubre campaña 29 para ese partido
   - Oculta componentes de campaña 28
   - Muestra componentes de campaña 29

3. **Backend maneja múltiples campañas:**
   - Cada campaña tiene su propio `matchId`
   - Componentes se filtran automáticamente por `matchId`

---

## Testing y Validación

### Casos de Prueba Recomendados

1. **Auto-Discovery sin matchId:**
   - Debe retornar todas las campañas activas
   - Verificar que componentes sin `matchId` se incluyan

2. **Auto-Discovery con matchId:**
   - Debe retornar solo campañas con ese `matchId`
   - Verificar que componentes se filtren correctamente

3. **WebSocket Events:**
   - Verificar que eventos incluyan `matchId` cuando corresponde
   - Verificar que SDK filtre eventos por `matchId`

4. **Backward Compatibility:**
   - Verificar que endpoints legacy sigan funcionando
   - Verificar que campañas sin `matchId` funcionen correctamente
   - Verificar que componentes sin `matchContext` se muestren en modo legacy

5. **Múltiples Campañas:**
   - Crear 2 campañas con diferentes `matchId`
   - Verificar que auto-discovery retorne ambas cuando no hay filtro
   - Verificar que auto-discovery retorne solo una cuando se filtra por `matchId`

---

## Priorización de Implementación

### Fase 1 (Crítica - MVP) ✅ COMPLETADA
1. ✅ Agregar `matchContext` opcional a `GET /v1/sdk/config`
2. ✅ Agregar `matchContext` opcional a componentes en `GET /v1/offers`
3. ✅ Implementar `GET /v1/sdk/campaigns` (auto-discovery)
4. ✅ Agregar `matchId` a eventos WebSocket existentes
5. ✅ Dashboard UI para Match Context (Match ID, Match Name, Match Start Time)

### Fase 2 (Optimizaciones) ✅ COMPLETADA
6. ✅ Agregar índices de base de datos para `match_id`
7. ✅ Implementar identificación automática por Bundle ID (`X-App-Bundle-ID` header)
8. ✅ Validaciones de `matchId` en backend
9. ✅ Logging y testing de auto-discovery

---

## Preguntas y Respuestas

**P: ¿Qué pasa si una campaña tiene componentes con diferentes `matchId`?**
R: No debería pasar. Una campaña debe tener un solo `matchId` (o ninguno). Los componentes heredan el `matchId` de la campaña, pero pueden tener su propio `matchId` si es necesario.

**P: ¿Qué formato usar para `matchId`?**
R: Cualquier string único. Recomendamos: `{home_team}-{away_team}-{date}` para legibilidad (ej: `barcelona-psg-2025-01-23`).

**P: ¿Los componentes sin `matchId` se muestran siempre?**
R: Sí, pero solo cuando NO hay un `matchId` activo en el SDK. Si hay un `matchId` activo, el SDK oculta componentes sin `matchId` por seguridad.

**P: ¿Cómo validar que un componente pertenece al `matchId` correcto?**
R: El backend debe incluir `matchContext` en la respuesta. El SDK valida automáticamente que `component.matchContext.matchId == currentMatchContext.matchId`.

**P: ¿Qué pasa si una campaña tiene `matchId` pero algunos componentes no?**
R: Esos componentes se ocultan cuando el SDK tiene ese `matchId` activo. Solo se muestran componentes que coinciden con el `matchId` actual.

**P: ¿El `channelId` en `matchContext` es el mismo que `campaigns.channelId`?**
R: Sí, es el mismo. El `channelId` dentro de `matchContext` debe ser el mismo valor que `campaigns.channelId` (ej: ID del canal "XXL iOS Channel"). No es un ID de stream/TV diferente.

**P: ¿Qué `apiKey` usar para auto-discovery?**
R: El endpoint `/v1/sdk/campaigns` usa el mismo `client_apps.api_key` que ya existe (ej: `xxl_api_key_507d4014243d8360`). NO usa `campaignAdminApiKey`.

**P: ¿Dónde se crean los `matchContext`?**
R: Los `matchContext` se crean/asignan cuando se crea o edita una campaña. Puede hacerse de dos formas:
- **Opción 1 (Recomendada):** Agregar UI en el dashboard para que los administradores puedan asignar `matchId`, `matchName`, `matchStartTime` a una campaña
- **Opción 2:** Crear programáticamente desde otro sistema (ej: sistema de gestión de partidos) que sincronice con el sistema de campañas
- **Recomendación:** Empezar con UI en dashboard para flexibilidad, luego puede automatizarse

**P: ¿Se usa `reachuApiKey` en auto-discovery?**
R: Actualmente el SDK usa `client_apps.api_key` para auto-discovery. Si existe un campo `reachuApiKey` en `client_apps`, puede usarse como alternativa en el futuro, pero por ahora usar `api_key`.

---

## Resumen de Implementación Completada

El backend (Replit) ha completado exitosamente la implementación de todas las funcionalidades descritas en este documento:

### ✅ Funcionalidades Implementadas

1. **GET /v1/sdk/campaigns - Auto-Discovery Endpoint**
   - ✅ Soporta autenticación dual: `apiKey` query param O `X-App-Bundle-ID` header
   - ✅ Filtro opcional `matchId` para encontrar campañas de partidos específicos
   - ✅ Retorna todas las campañas activas con sus componentes y `matchContext`

2. **Match Context Support**
   - ✅ Campos en base de datos: `matchId`, `matchName`, `matchStartTime` en `campaigns`
   - ✅ Campo `matchId` en `campaign_components`
   - ✅ Endpoints SDK (`/v1/sdk/config` y `/v1/offers`) incluyen `matchContext` opcional en respuestas
   - ✅ Eventos WebSocket (`campaign_started`, `component_status_changed`, `component_config_updated`) incluyen `matchId` opcional

3. **Dashboard UI**
   - ✅ Nueva sección "Match Context" en Campaign Settings tab
   - ✅ Campos de input para Match ID, Match Name, y Match Start Time
   - ✅ Botones Save y Clear Match Context

4. **Backward Compatibility**
   - ✅ Todos los campos relacionados con match son opcionales
   - ✅ Integraciones existentes continúan funcionando sin modificaciones

### ✅ Testing y Verificación

- ✅ Autenticación con ambos métodos (query param y header) funciona correctamente
- ✅ Filtrado por `matchId` retorna resultados esperados
- ✅ Pruebas de API completadas exitosamente

---

## Cambios Futuros en el SDK (Recomendado)

El backend ya soporta identificación automática por Bundle ID (ver sección "API Key desde Backend"). El SDK puede actualizarse para aprovechar esta funcionalidad y mejorar la seguridad. Estos cambios son **recomendados** pero **opcionales** ya que el backend mantiene compatibilidad hacia atrás.

### Cambios Propuestos en el SDK

**1. Soporte para Headers en Requests**

Modificar `CampaignManager` y otros managers para enviar headers automáticamente:

```swift
// Pseudocódigo
var request = URLRequest(url: url)
request.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-App-Bundle-ID")
request.setValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "", forHTTPHeaderField: "X-App-Version")
request.setValue("ios", forHTTPHeaderField: "X-Platform")
```

**2. Hacer `apiKey` Opcional en Query Parameters**

Cuando se usen headers de identificación automática, el parámetro `apiKey` puede ser opcional:

```swift
// Si se usa identificación automática, no incluir apiKey en query
if useAutoIdentification {
    urlString = "\(baseURL)/v1/sdk/campaigns"
} else {
    urlString = "\(baseURL)/v1/sdk/campaigns?apiKey=\(apiKey)"
}
```

**3. Configuración para Habilitar Identificación Automática**

Agregar flag en configuración:

```json
{
  "campaigns": {
    "useAutoIdentification": true,
    "apiKey": ""  // Opcional cuando useAutoIdentification es true
  }
}
```

**Nota:** El backend ya está implementado y funcionando. El SDK actual funciona correctamente enviando `apiKey` en query parameters. Estos cambios mejoran la seguridad pero son opcionales ya que el backend mantiene compatibilidad hacia atrás.

---

## Contacto y Soporte

Para preguntas sobre la implementación, contactar al equipo del SDK Swift.

**Documentación del SDK:**
- Ver código fuente en: `Sources/ReachuCore/Managers/CampaignManager.swift`
- Ver modelos en: `Sources/ReachuCore/Models/CampaignModels.swift`
- Ver configuración en: `Sources/ReachuCore/Configuration/ModuleConfigurations.swift`
