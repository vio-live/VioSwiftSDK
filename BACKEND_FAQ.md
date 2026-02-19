# FAQ - Preguntas Frecuentes sobre Implementación Backend

## Estado de Implementación

✅ **IMPLEMENTADO Y PROBADO** - Todas las funcionalidades descritas en este documento han sido implementadas y verificadas en el backend (Replit).

## Respuestas a Preguntas del Equipo de Replit

### 1. channel_id en campaigns

**Pregunta:** Ya existe `channelId` en la tabla `campaigns` (lo usamos para asociar campañas a channels como "XXL iOS Channel"). ¿El `channelId` dentro de `matchContext` es el mismo o es diferente (ej: ID del stream/canal de TV)?

**Respuesta:**
- **Es el mismo.** El `channelId` dentro de `matchContext` es el mismo que el `channelId` existente en la tabla `campaigns`.
- Se usa para asociar campañas a channels como "XXL iOS Channel".
- **NO es un ID de stream/canal de TV diferente** - es el mismo concepto.
- Si la campaña ya tiene `channelId`, puede incluirse en `matchContext` para consistencia.
- **No necesita agregarse como campo nuevo** - usar el valor existente de `campaigns.channel_id`.

**Ejemplo:**
```sql
-- campaigns.channel_id ya existe (ej: 1 = "XXL iOS Channel")
-- En matchContext, usar el mismo valor:
{
  "matchContext": {
    "matchId": "barcelona-psg-2025-01-23",
    "channelId": 1  // Mismo que campaigns.channel_id
  }
}
```

---

### 2. API Key para Auto-Discovery

**Pregunta:** El endpoint `/v1/sdk/campaigns` usa `apiKey` que sería el mismo `client_apps.api_key` que ya tenemos, ¿correcto? (ej: `xxl_api_key_507d4014243d8360`)

**Respuesta:**
- **Sí, correcto.** El endpoint `/v1/sdk/campaigns` usa el mismo `client_apps.api_key` que ya existe.
- Ejemplo: `xxl_api_key_507d4014243d8360`
- **NO usa `campaignAdminApiKey`** - ese es solo para endpoints legacy como `/v1/sdk/config`.
- La validación debe ser la misma que otros endpoints del SDK que usan `client_apps.api_key`.

**Ejemplo de request:**
```
GET /v1/sdk/campaigns?apiKey=xxl_api_key_507d4014243d8360&matchId=barcelona-psg-2025-01-23
```

**Validación Backend:**
```sql
-- Validar que apiKey existe en client_apps
SELECT * FROM client_apps WHERE api_key = 'xxl_api_key_507d4014243d8360';
```

---

### 3. ¿Dónde se crean los matchContext?

**Pregunta:** ¿Necesito agregar UI en el dashboard para que puedan crear/asignar partidos a campañas? ¿O esto se hace programáticamente desde otro sistema?

**Respuesta:**
- **Ambas opciones son válidas.** Puede implementarse de dos formas:

**Opción 1: UI en Dashboard (Recomendada para empezar)**
- Agregar campos en el formulario de creación/edición de campañas:
  - `matchId` (text input)
  - `matchName` (text input)
  - `matchStartTime` (datetime picker)
- Esto permite flexibilidad y control manual
- **Ventaja:** Fácil de implementar, permite testing manual
- **Desventaja:** Requiere entrada manual

**Opción 2: Programático (Recomendada para producción)**
- Crear desde otro sistema (ej: sistema de gestión de partidos)
- Sincronizar automáticamente cuando se crea un partido
- **Ventaja:** Automático, menos errores
- **Desventaja:** Requiere integración con otro sistema

**Recomendación:**
1. **Empezar con UI en dashboard** para MVP y testing
2. **Luego automatizar** cuando el sistema de partidos esté listo

**Ejemplo de UI sugerida:**
```
Campaign Form:
├── Basic Info (name, logo, dates, etc.)
├── Channel Selection (existing)
└── Match Context (NEW)
    ├── Match ID: [text input]
    ├── Match Name: [text input]
    └── Match Start Time: [datetime picker]
    └── [ ] Associate campaign with match
```

---

### 4. reachuApiKey

**Pregunta:** El campo que acabamos de agregar a `client_apps`, ¿se usará en este nuevo flujo de auto-discovery?

**Respuesta:**
- **No por ahora.** Actualmente el SDK usa `client_apps.api_key` para auto-discovery.
- Si existe un campo `reachuApiKey` en `client_apps`, puede usarse como alternativa en el futuro.
- **Por ahora:** Usar `client_apps.api_key` para mantener consistencia con otros endpoints del SDK.
- **Futuro:** Si se decide usar `reachuApiKey`, puede agregarse como alternativa o reemplazo, pero requiere cambios en el SDK también.

**Recomendación:**
- Usar `client_apps.api_key` para auto-discovery
- Mantener `reachuApiKey` para otros propósitos si es necesario
- Si en el futuro se quiere cambiar, coordinar con el equipo del SDK

---

### 5. API Key desde Backend

**Pregunta:** ¿La API key del SDK debe venir del backend en lugar de estar hardcodeada en la app?

**Respuesta:**

**Sí, es altamente recomendado** por las siguientes razones:

1. **Seguridad mejorada:** La API key nunca está expuesta en el código del cliente
2. **Flexibilidad:** Cambiar la API key solo requiere cambios en el backend, no un nuevo release de la app
3. **Multi-tenant:** Facilita soportar múltiples clientes con diferentes API keys
4. **Gestión centralizada:** Permite rotar o revocar API keys desde el backend

**Implementación Recomendada:**

**Opción 1: Identificación Automática (Recomendada)**

El backend identifica automáticamente qué cliente está haciendo la petición usando el **Bundle ID** de la aplicación:

1. **Agregar campo `bundle_id` a `client_apps`:**
   ```sql
   ALTER TABLE client_apps
   ADD COLUMN bundle_id VARCHAR(255) NULL UNIQUE,
   ADD INDEX idx_bundle_id (bundle_id);
   ```

2. **Modificar endpoint `/v1/sdk/campaigns` para soportar identificación automática:**
   - Si existe header `X-App-Bundle-ID`:
     - Buscar `client_apps` por `bundle_id`
     - Usar su `api_key` automáticamente
     - El parámetro `apiKey` en query se vuelve opcional
   - Si NO existe `X-App-Bundle-ID`:
     - Usar `apiKey` del query parameter (backward compatibility)

3. **Headers a soportar:**
   - `X-App-Bundle-ID`: Bundle ID de la app (ej: `com.viaplay.app`)
   - `X-App-Version`: Versión de la app (opcional, para logging)
   - `X-Platform`: Plataforma (opcional, `ios` o `android`)

**Ejemplo de Request:**
```
GET /v1/sdk/campaigns
Headers:
  X-App-Bundle-ID: com.viaplay.app
  X-App-Version: 1.2.3
  X-Platform: ios
```

**Ventajas:**
- ✅ Máxima seguridad (API key nunca en el cliente)
- ✅ Backward compatible (sigue funcionando con `apiKey` en query)
- ✅ Fácil de implementar
- ✅ No requiere cambios inmediatos en el SDK (puede seguir enviando `apiKey` como fallback)

**Opción 2: Endpoint de Configuración Inicial**

Crear un nuevo endpoint `/v1/sdk/init-config` que retorne toda la configuración del SDK (incluyendo `apiKey`) basándose en el Bundle ID.

**Ventajas:**
- ✅ Configuración centralizada
- ✅ Permite cambiar URLs y otros parámetros sin actualizar la app

**Desventajas:**
- ⚠️ Requiere un paso adicional de inicialización
- ⚠️ Más complejo de implementar

**Recomendación:**

Implementar **Opción 1 (Identificación Automática)** porque es más simple, segura y backward compatible.

**Pasos de Implementación:**

1. ✅ Agregar campo `bundle_id` a `client_apps` (migración)
2. ✅ Actualizar endpoint `/v1/sdk/campaigns` para soportar identificación automática
3. ✅ Mantener soporte para `apiKey` en query parameter (backward compatibility)
4. ✅ Documentar el nuevo flujo
5. ⏳ (Futuro) Actualizar SDK para usar identificación automática por defecto

**Compatibilidad hacia atrás:**

- ✅ El endpoint sigue funcionando con `apiKey` en query parameter
- ✅ Clientes existentes no se ven afectados
- ✅ Nuevos clientes pueden usar identificación automática
- ✅ Transición gradual posible

**Casos de Prueba:**

1. **Identificación automática exitosa:**
   ```
   GET /v1/sdk/campaigns
   Headers: X-App-Bundle-ID: com.viaplay.app
   Expected: 200 OK con campañas
   ```

2. **Bundle ID no encontrado:**
   ```
   GET /v1/sdk/campaigns
   Headers: X-App-Bundle-ID: com.unknown.app
   Expected: 401/404 Error
   ```

3. **Backward compatibility:**
   ```
   GET /v1/sdk/campaigns?apiKey=KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S
   Expected: 200 OK con campañas (funciona como antes)
   ```

4. **Prioridad - Bundle ID sobre apiKey:**
   ```
   GET /v1/sdk/campaigns?apiKey=WRONG_KEY
   Headers: X-App-Bundle-ID: com.viaplay.app
   Expected: 200 OK (usa apiKey del bundle_id, ignora query param)
   ```

**Nota:** Ver sección completa "API Key desde Backend (Recomendado)" en `BACKEND_CAMPAIGNS_IMPLEMENTATION.md` para más detalles.

---

## Resumen de Observaciones Confirmadas

✅ **Los campos `match_id`, `match_name`, `match_start_time` se agregarían a `campaigns`**
- Correcto. Estos son los nuevos campos necesarios.

✅ **`match_id` también se agrega a `campaign_components`**
- Correcto. Permite que componentes específicos tengan su propio `matchId` si es necesario.

✅ **Todo es backward compatible - campos opcionales**
- Correcto. Todos los nuevos campos son NULL por defecto, no rompen campañas existentes.

✅ **El nuevo endpoint `/v1/sdk/campaigns` es el principal cambio**
- Correcto. Este es el endpoint más importante para auto-discovery.

✅ **Los WebSocket events necesitan incluir `matchId` opcional**
- Correcto. Agregar `matchId` opcional a eventos existentes para filtrado.

---

## Checklist de Implementación

### Fase 1: Preparación
- [ ] Agregar campos `match_id`, `match_name`, `match_start_time` a tabla `campaigns`
- [ ] Agregar campo `match_id` a tabla `campaign_components`
- [ ] Crear índices para `match_id`
- [ ] Verificar que `channel_id` ya existe (no agregar de nuevo)

### Fase 2: Endpoints
- [ ] Agregar `matchContext` opcional a respuesta de `GET /v1/sdk/config`
- [ ] Agregar `matchContext` opcional a componentes en `GET /v1/offers`
- [ ] Implementar nuevo endpoint `GET /v1/sdk/campaigns`
- [ ] Validar que usa `client_apps.api_key` (no `campaignAdminApiKey`)

### Fase 3: WebSocket
- [ ] Agregar `matchId` opcional a evento `component_status_changed`
- [ ] Agregar `matchId` opcional a evento `component_config_updated`
- [ ] Agregar `matchId` opcional a evento `campaign_started`

### Fase 4: UI (Opcional para MVP)
- [ ] Agregar campos de `matchContext` al formulario de campañas
- [ ] Validar formato de `matchId` en frontend
- [ ] Mostrar `matchContext` en lista de campañas

---

## Ejemplos de Código

### Validación de apiKey en Auto-Discovery
```sql
-- En el endpoint GET /v1/sdk/campaigns
SELECT * FROM client_apps 
WHERE api_key = :apiKey 
AND is_active = true;

-- Si no existe, retornar 401 Unauthorized
```

### Query para Auto-Discovery con matchId
```sql
SELECT 
  c.id as campaign_id,
  c.name as campaign_name,
  c.logo_url as campaign_logo,
  c.match_id,
  c.match_name,
  c.match_start_time,
  c.channel_id,
  c.start_date,
  c.end_date,
  c.is_paused,
  -- Componentes activos
  (SELECT JSON_ARRAYAGG(
    JSON_OBJECT(
      'id', cc.id,
      'type', comp.type,
      'name', comp.name,
      'status', cc.status,
      'matchContext', JSON_OBJECT(
        'matchId', cc.match_id
      ),
      'config', cc.custom_config
    )
  )
  FROM campaign_components cc
  JOIN components comp ON cc.component_id = comp.id
  WHERE cc.campaign_id = c.id 
  AND cc.status = 'active'
  ) as components
FROM campaigns c
WHERE c.is_paused = false
  AND (c.start_date IS NULL OR c.start_date <= NOW())
  AND (c.end_date IS NULL OR c.end_date >= NOW())
  AND (:matchId IS NULL OR c.match_id = :matchId)
ORDER BY c.start_date DESC;
```

### Incluir matchContext en respuesta de /v1/sdk/config
```javascript
// Pseudocódigo
const campaign = await getCampaign(campaignId);

const response = {
  campaignId: campaign.id,
  campaignName: campaign.name,
  campaignLogo: campaign.logo_url,
  channelId: campaign.channel_id,
  // ... otros campos existentes
  
  // Nuevo: matchContext opcional
  ...(campaign.match_id && {
    matchContext: {
      matchId: campaign.match_id,
      matchName: campaign.match_name,
      startTime: campaign.match_start_time,
      channelId: campaign.channel_id, // Mismo que arriba
      metadata: {}
    }
  })
};
```

---

## Contacto

Para más preguntas, contactar al equipo del SDK Swift.
