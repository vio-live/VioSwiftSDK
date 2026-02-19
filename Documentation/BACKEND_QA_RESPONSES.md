# Respuestas a Preguntas de Replit - Dynamic Configuration

## Resumen Ejecutivo

Este documento responde las preguntas del equipo de Replit sobre la implementación del sistema de configuración dinámica.

---

## 1. Endpoint existente vs nuevo

**Pregunta:** ¿`/v1/campaigns/{campaignId}/config` reemplaza `/v1/sdk/config` o coexisten?

**Respuesta:** **Coexisten** - tienen propósitos diferentes:

| Endpoint | Propósito | Auth | Uso |
|----------|-----------|------|-----|
| `/v1/sdk/config` (existente) | Configuración general del SDK | `campaignAdminApiKey` | Mantener para compatibilidad |
| `/v1/campaigns/{campaignId}/config` (nuevo) | Config dinámica por campaña | SDK `apiKey` | Nuevo, más completo |

**Acción:** Mantener ambos endpoints. El nuevo es más específico y completo.

---

## 2. Datos de marca (brand)

**Pregunta:** ¿De dónde vienen `iconAsset`, `logoUrl`, `sponsorBadgeText`? ¿Necesitamos agregarlos a la BD?

**Respuesta:** **Sí, agregar a la base de datos:**

### Campos a agregar a tabla `campaigns`:
- `brand_name` VARCHAR(255)
- `brand_icon_asset` VARCHAR(255) - Nombre del asset local (ej: "avatar_el")
- `brand_icon_url` TEXT - URL del CDN (opcional)
- `brand_logo_url` TEXT - URL del logo (opcional)

### Nueva tabla `campaign_translations`:
```sql
CREATE TABLE campaign_translations (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(id),
    language_code VARCHAR(10),
    sponsor_badge_text VARCHAR(255),
    UNIQUE(campaign_id, language_code)
);
```

### Valores por defecto:
- `brand_name`: Nombre de la campaña o "Reachu"
- `iconAsset`: "avatar_default"
- `sponsorBadgeText` por idioma:
  - "no": "Sponset av"
  - "en": "Sponsored by"
  - "sv": "Sponsrad av"

**Dashboard:** Agregar sección "Brand Configuration" con campos para nombre, upload de imágenes, y editor de traducciones.

---

## 3. Configuración de engagement

**Pregunta:** ¿Los valores como `demoMode`, `defaultPollDuration`, `maxVotesPerPoll` son configurables por campaña o usamos defaults?

**Respuesta:** **Configurables por campaña con valores por defecto:**

### Nueva tabla `campaign_engagement_config`:
```sql
CREATE TABLE campaign_engagement_config (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(id),
    demo_mode BOOLEAN DEFAULT false,
    default_poll_duration INTEGER DEFAULT 300,
    default_contest_duration INTEGER DEFAULT 600,
    max_votes_per_poll INTEGER DEFAULT 1,
    max_contests_per_match INTEGER DEFAULT 10,
    enable_real_time_updates BOOLEAN DEFAULT true,
    update_interval INTEGER DEFAULT 1000,
    UNIQUE(campaign_id)
);
```

### Valores por defecto recomendados:
- `demoMode`: **`false`** (solo `true` para testing)
- `defaultPollDuration`: `300` (5 minutos)
- `defaultContestDuration`: `600` (10 minutos)
- `maxVotesPerPoll`: `1`
- `maxContestsPerMatch`: `10`
- `enableRealTimeUpdates`: `true`
- `updateInterval`: `1000` ms

**Dashboard:** Agregar sección "Engagement Settings" con toggles y campos numéricos.

**IMPORTANTE:** `demoMode` debe ser `false` en producción. Solo `true` para desarrollo cuando el backend no está disponible.

---

## 4. Localizaciones

**Pregunta:** ¿Tenemos un sistema de traducciones existente o necesitamos crear uno?

**Respuesta:** **Necesitamos crear/expandir el sistema:**

### Nueva tabla `sdk_translations`:
```sql
CREATE TABLE sdk_translations (
    id SERIAL PRIMARY KEY,
    language_code VARCHAR(10) NOT NULL,
    campaign_id INTEGER REFERENCES campaigns(id), -- NULL = global
    match_id VARCHAR(255), -- NULL = por campaña o global
    translation_key VARCHAR(100) NOT NULL,
    translation_value TEXT NOT NULL,
    date_format VARCHAR(50) DEFAULT 'dd.MM.yyyy',
    time_format VARCHAR(50) DEFAULT 'HH:mm',
    UNIQUE(language_code, campaign_id, match_id, translation_key)
);
```

### Prioridad de traducciones (más específica primero):
1. `match_id` + `campaign_id` + `language_code`
2. `campaign_id` + `language_code`
3. `language_code` solamente (global)

### Traducciones mínimas requeridas:
- `sponsorBadge`: "Sponset av" (no), "Sponsored by" (en)
- `voteButton`: "Stem" (no), "Vote" (en)
- `participateButton`: "Delta" (no), "Participate" (en)
- `pollClosed`: "Avstemningen er stengt" (no), "Poll is closed" (en)
- `alreadyVoted`: "Du har allerede stemt" (no), "You have already voted" (en)
- `contestEnded`: "Konkurransen er avsluttet" (no), "Contest has ended" (en)

**Dashboard:** Agregar editor de traducciones con selector de idioma y campos por key.

---

## 5. UI Theme

**Pregunta:** ¿Los colores `primaryColor` y `secondaryColor` se añaden como campos editables en el dashboard?

**Respuesta:** **Sí, como campos opcionales:**

### Nueva tabla `campaign_ui_config`:
```sql
CREATE TABLE campaign_ui_config (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(id),
    primary_color VARCHAR(7) DEFAULT '#007AFF',
    secondary_color VARCHAR(7) DEFAULT '#5856D6',
    component_configs JSONB, -- Opcional: configs avanzadas
    UNIQUE(campaign_id)
);
```

### Valores por defecto:
- `primaryColor`: `#007AFF` (iOS blue estándar)
- `secondaryColor`: `#5856D6` (iOS purple estándar)

**Dashboard:** Agregar sección "UI Theme" con color pickers.

**Nota:** Si no se configuran, el SDK usa los colores del tema local en `reachu-config.json`.

---

## 6. Feature flags

**Pregunta:** ¿Los campos como `enableLiveStreaming`, `enablePolls`, etc. son toggles configurables por campaña?

**Respuesta:** **Sí, toggles configurables por campaña:**

### Nueva tabla `campaign_feature_flags`:
```sql
CREATE TABLE campaign_feature_flags (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(id),
    enable_live_streaming BOOLEAN DEFAULT true,
    enable_product_catalog BOOLEAN DEFAULT true,
    enable_engagement BOOLEAN DEFAULT true,
    enable_polls BOOLEAN DEFAULT true,
    enable_contests BOOLEAN DEFAULT true,
    UNIQUE(campaign_id)
);
```

### Valores por defecto:
Todos `true` (todas las features habilitadas por defecto).

**Dashboard:** Agregar sección "Feature Flags" con toggles para cada feature.

**Uso:** Permiten habilitar/deshabilitar features por campaña sin actualizar la app.

---

## Plan de Implementación Simplificado

### Fase 1: Base de Datos (Prioridad Alta)
1. Agregar columnas a `campaigns`: `brand_name`, `brand_icon_asset`, `brand_icon_url`, `brand_logo_url`
2. Crear `campaign_engagement_config` con valores por defecto
3. Crear `campaign_feature_flags` con todos en `true`
4. Crear `campaign_translations` para `sponsorBadgeText`
5. Crear `sdk_translations` para traducciones generales

### Fase 2: Endpoints (Prioridad Alta)
1. Implementar `/v1/campaigns/{campaignId}/config` - Combinar datos de todas las tablas
2. Implementar `/v1/engagement/config` - Query por `matchId`
3. Implementar `/v1/localization/{language}` - Query con prioridad (match > campaign > global)

### Fase 3: Dashboard (Prioridad Media)
1. Agregar secciones al editor de campaña:
   - Brand Configuration
   - Engagement Settings
   - Feature Flags
   - Translations Editor

### Fase 4: WebSocket (Prioridad Baja)
1. Implementar evento `config:updated` cuando cambie cualquier config
2. Triggers en BD para emitir eventos automáticamente

---

## Ejemplo de Query para Endpoint Principal

```sql
SELECT 
    c.id as campaign_id,
    c.brand_name,
    c.brand_icon_asset,
    c.brand_icon_url,
    c.brand_logo_url,
    -- Engagement
    COALESCE(ec.demo_mode, false) as demo_mode,
    COALESCE(ec.default_poll_duration, 300) as default_poll_duration,
    COALESCE(ec.default_contest_duration, 600) as default_contest_duration,
    COALESCE(ec.max_votes_per_poll, 1) as max_votes_per_poll,
    COALESCE(ec.max_contests_per_match, 10) as max_contests_per_match,
    COALESCE(ec.enable_real_time_updates, true) as enable_real_time_updates,
    COALESCE(ec.update_interval, 1000) as update_interval,
    -- UI
    COALESCE(uc.primary_color, '#007AFF') as primary_color,
    COALESCE(uc.secondary_color, '#5856D6') as secondary_color,
    -- Features
    COALESCE(ff.enable_live_streaming, true) as enable_live_streaming,
    COALESCE(ff.enable_product_catalog, true) as enable_product_catalog,
    COALESCE(ff.enable_engagement, true) as enable_engagement,
    COALESCE(ff.enable_polls, true) as enable_polls,
    COALESCE(ff.enable_contests, true) as enable_contests
FROM campaigns c
LEFT JOIN campaign_engagement_config ec ON c.id = ec.campaign_id
LEFT JOIN campaign_ui_config uc ON c.id = uc.campaign_id
LEFT JOIN campaign_feature_flags ff ON c.id = ff.campaign_id
WHERE c.id = $1;
```

Luego agregar `sponsorBadgeText` desde `campaign_translations` agrupado por idioma.

---

## Consideraciones Importantes

1. **Todos los campos son opcionales** - Si no existen, usar valores por defecto
2. **Backward compatibility** - El SDK maneja fallback automáticamente
3. **Performance** - Cachear respuestas (Redis, TTL 5 min)
4. **Validación** - Validar formatos (hex colors, duraciones positivas)
5. **Seguridad** - Verificar que `apiKey` tiene acceso a la campaña

---

## Contacto

Para más detalles técnicos, ver:
- `BACKEND_API_SPEC.md` - Especificación completa de endpoints
- `BACKEND_IMPLEMENTATION_GUIDE.md` - Guía detallada de implementación
