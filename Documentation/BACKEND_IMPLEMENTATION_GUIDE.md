# Backend Implementation Guide - Dynamic Configuration

## Respuestas a Preguntas de Implementación

### 1. Endpoint existente vs nuevo

**Pregunta:** ¿`/v1/campaigns/{campaignId}/config` reemplaza `/v1/sdk/config` o coexisten?

**Respuesta:** Coexisten con propósitos diferentes:

- **`/v1/sdk/config`** (existente):
  - Propósito: Configuración general del SDK (no específica de campaña)
  - Usa `campaignAdminApiKey` (diferente del SDK API key)
  - Retorna configuración básica de componentes y ofertas
  - Se mantiene para compatibilidad con código legacy

- **`/v1/campaigns/{campaignId}/config`** (nuevo):
  - Propósito: Configuración completa y dinámica por campaña
  - Usa SDK `apiKey` (mismo que otros endpoints del SDK)
  - Retorna brand, engagement, UI, features específicos de la campaña
  - Diseñado para configuración dinámica sin actualizar la app

**Recomendación:** Mantener ambos endpoints. El nuevo endpoint es más completo y específico por campaña.

---

### 2. Datos de marca (brand)

**Pregunta:** ¿De dónde vienen `iconAsset`, `logoUrl`, `sponsorBadgeText`? ¿Necesitamos agregarlos a la BD?

**Respuesta:** Estos campos deben agregarse a la base de datos de campañas:

**Estructura sugerida en BD:**

```sql
-- Tabla: campaigns
ALTER TABLE campaigns ADD COLUMN brand_name VARCHAR(255);
ALTER TABLE campaigns ADD COLUMN brand_icon_asset VARCHAR(255);
ALTER TABLE campaigns ADD COLUMN brand_icon_url TEXT;
ALTER TABLE campaigns ADD COLUMN brand_logo_url TEXT;

-- Tabla: campaign_translations (nueva tabla para textos traducidos)
CREATE TABLE campaign_translations (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(id),
    language_code VARCHAR(10), -- 'no', 'en', 'sv', etc.
    sponsor_badge_text VARCHAR(255),
    UNIQUE(campaign_id, language_code)
);
```

**Valores por defecto (si no se configuran):**
- `brand_name`: Usar nombre de la campaña o "Reachu"
- `iconAsset`: "avatar_default" (asset local en la app)
- `iconUrl`: null (usar asset local)
- `logoUrl`: null
- `sponsorBadgeText`: Valores por defecto por idioma:
  - "no": "Sponset av"
  - "en": "Sponsored by"
  - "sv": "Sponsrad av"

**Dashboard:** Agregar sección "Brand Configuration" en el editor de campaña con:
- Campo de texto para `brand_name`
- Upload de imágenes para `iconUrl` y `logoUrl`
- Campo para `iconAsset` (nombre del asset local)
- Editor de traducciones para `sponsorBadgeText` por idioma

---

### 3. Configuración de engagement

**Pregunta:** ¿Los valores como `demoMode`, `defaultPollDuration`, `maxVotesPerPoll` son configurables por campaña o usamos defaults?

**Respuesta:** Configurables por campaña con valores por defecto sensatos:

**Estructura sugerida en BD:**

```sql
-- Tabla: campaign_engagement_config (nueva tabla)
CREATE TABLE campaign_engagement_config (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(id),
    demo_mode BOOLEAN DEFAULT false,
    default_poll_duration INTEGER DEFAULT 300, -- segundos (5 min)
    default_contest_duration INTEGER DEFAULT 600, -- segundos (10 min)
    max_votes_per_poll INTEGER DEFAULT 1,
    max_contests_per_match INTEGER DEFAULT 10,
    enable_real_time_updates BOOLEAN DEFAULT true,
    update_interval INTEGER DEFAULT 1000, -- ms
    UNIQUE(campaign_id)
);
```

**Valores por defecto recomendados:**
- `demoMode`: `false` (solo true para testing/demo)
- `defaultPollDuration`: `300` (5 minutos)
- `defaultContestDuration`: `600` (10 minutos)
- `maxVotesPerPoll`: `1`
- `maxContestsPerMatch`: `10`
- `enableRealTimeUpdates`: `true`
- `updateInterval`: `1000` (1 segundo)

**Dashboard:** Agregar sección "Engagement Settings" en el editor de campaña con toggles y campos numéricos para estos valores.

**Nota importante:** `demoMode` debe ser `false` en producción. Solo se usa `true` para desarrollo/testing cuando el backend no está disponible.

---

### 4. Localizaciones

**Pregunta:** ¿Tenemos un sistema de traducciones existente o necesitamos crear uno?

**Respuesta:** Necesitamos crear/expandir el sistema de traducciones:

**Estructura sugerida en BD:**

```sql
-- Tabla: sdk_translations (nueva tabla para traducciones del SDK)
CREATE TABLE sdk_translations (
    id SERIAL PRIMARY KEY,
    language_code VARCHAR(10) NOT NULL, -- 'no', 'en', 'sv', etc.
    campaign_id INTEGER REFERENCES campaigns(id), -- NULL = traducciones globales
    match_id VARCHAR(255), -- NULL = traducciones por campaña o globales
    translation_key VARCHAR(100) NOT NULL, -- 'sponsorBadge', 'voteButton', etc.
    translation_value TEXT NOT NULL,
    date_format VARCHAR(50) DEFAULT 'dd.MM.yyyy',
    time_format VARCHAR(50) DEFAULT 'HH:mm',
    UNIQUE(language_code, campaign_id, match_id, translation_key)
);

-- Índices para búsqueda rápida
CREATE INDEX idx_sdk_translations_lang ON sdk_translations(language_code);
CREATE INDEX idx_sdk_translations_campaign ON sdk_translations(campaign_id);
CREATE INDEX idx_sdk_translations_match ON sdk_translations(match_id);
```

**Prioridad de traducciones (de más específica a menos específica):**
1. `match_id` + `campaign_id` + `language_code` (más específica)
2. `campaign_id` + `language_code` (específica de campaña)
3. `language_code` solamente (global, fallback)

**Traducciones requeridas (keys mínimas):**
- `sponsorBadge`: "Sponset av" (no), "Sponsored by" (en)
- `voteButton`: "Stem" (no), "Vote" (en)
- `participateButton`: "Delta" (no), "Participate" (en)
- `pollClosed`: "Avstemningen er stengt" (no), "Poll is closed" (en)
- `alreadyVoted`: "Du har allerede stemt" (no), "You have already voted" (en)
- `contestEnded`: "Konkurransen er avsluttet" (no), "Contest has ended" (en)

**Dashboard:** Agregar editor de traducciones con:
- Selector de idioma
- Lista de keys de traducción
- Campos de texto para cada traducción
- Posibilidad de copiar traducciones de otra campaña/idioma

---

### 5. UI Theme

**Pregunta:** ¿Los colores `primaryColor` y `secondaryColor` se añaden como campos editables en el dashboard?

**Respuesta:** Sí, como campos opcionales en el dashboard:

**Estructura sugerida en BD:**

```sql
-- Tabla: campaign_ui_config (nueva tabla)
CREATE TABLE campaign_ui_config (
    id SERIAL PRIMARY KEY,
    campaign_id INTEGER REFERENCES campaigns(id),
    primary_color VARCHAR(7) DEFAULT '#007AFF', -- Hex color
    secondary_color VARCHAR(7) DEFAULT '#5856D6',
    -- Component-specific configs pueden ir en JSONB
    component_configs JSONB, -- { "cart": {...}, "discountBadge": {...} }
    UNIQUE(campaign_id)
);
```

**Valores por defecto:**
- `primaryColor`: `#007AFF` (iOS blue estándar)
- `secondaryColor`: `#5856D6` (iOS purple estándar)

**Dashboard:** Agregar sección "UI Theme" con:
- Color picker para `primaryColor`
- Color picker para `secondaryColor`
- Editor JSON para `component_configs` (opcional, puede ser avanzado)

**Nota:** Estos colores son opcionales. Si no se configuran, el SDK usa los colores del tema configurado localmente en `reachu-config.json`.

---

### 6. Feature flags

**Pregunta:** ¿Los campos como `enableLiveStreaming`, `enablePolls`, etc. son toggles configurables por campaña?

**Respuesta:** Sí, son toggles configurables por campaña:

**Estructura sugerida en BD:**

```sql
-- Tabla: campaign_feature_flags (nueva tabla)
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

**Valores por defecto (todos `true`):**
- `enableLiveStreaming`: `true`
- `enableProductCatalog`: `true`
- `enableEngagement`: `true`
- `enablePolls`: `true`
- `enableContests`: `true`

**Dashboard:** Agregar sección "Feature Flags" con toggles para cada feature.

**Uso:** Estos flags permiten habilitar/deshabilitar features específicas por campaña sin necesidad de actualizar la app.

---

## Plan de Implementación Recomendado

### Fase 1: Base de Datos (Semana 1)

1. **Crear nuevas tablas:**
   - `campaign_translations` (para sponsorBadgeText)
   - `campaign_engagement_config`
   - `sdk_translations`
   - `campaign_ui_config`
   - `campaign_feature_flags`

2. **Agregar columnas a tabla `campaigns`:**
   - `brand_name`
   - `brand_icon_asset`
   - `brand_icon_url`
   - `brand_logo_url`

3. **Migraciones:**
   - Scripts de migración para datos existentes
   - Valores por defecto para todas las nuevas columnas

### Fase 2: Endpoints REST (Semana 2)

1. **Implementar `/v1/campaigns/{campaignId}/config`:**
   - Agregar lógica para combinar datos de todas las tablas
   - Merge de configs por campaña con defaults
   - Manejo de `matchId` opcional para overrides

2. **Implementar `/v1/engagement/config`:**
   - Query a `campaign_engagement_config` por `matchId`
   - Fallback a defaults si no existe config específica

3. **Implementar `/v1/localization/{language}`:**
   - Query a `sdk_translations` con prioridad:
     1. match_id + campaign_id + language
     2. campaign_id + language
     3. language solamente (global)
   - Retornar objeto con todas las traducciones

### Fase 3: Dashboard UI (Semana 3)

1. **Agregar secciones al editor de campaña:**
   - "Brand Configuration"
   - "Engagement Settings"
   - "UI Theme"
   - "Feature Flags"
   - "Translations"

2. **Formularios:**
   - Inputs para todos los campos
   - Validación de formatos (colores hex, duraciones, etc.)
   - Preview de cambios

### Fase 4: WebSocket Events (Semana 4)

1. **Implementar evento `config:updated`:**
   - Emitir cuando se actualice cualquier configuración
   - Incluir `sections` afectadas
   - Incrementar `version` automáticamente

2. **Triggers en BD:**
   - Trigger para detectar cambios en tablas de config
   - Emitir evento WebSocket automáticamente

---

## Ejemplo de Query para `/v1/campaigns/{campaignId}/config`

```sql
SELECT 
    c.id as campaign_id,
    c.brand_name,
    c.brand_icon_asset,
    c.brand_icon_url,
    c.brand_logo_url,
    -- Engagement config
    ec.demo_mode,
    ec.default_poll_duration,
    ec.default_contest_duration,
    ec.max_votes_per_poll,
    ec.max_contests_per_match,
    ec.enable_real_time_updates,
    ec.update_interval,
    -- UI config
    uc.primary_color,
    uc.secondary_color,
    uc.component_configs,
    -- Feature flags
    ff.enable_live_streaming,
    ff.enable_product_catalog,
    ff.enable_engagement,
    ff.enable_polls,
    ff.enable_contests
FROM campaigns c
LEFT JOIN campaign_engagement_config ec ON c.id = ec.campaign_id
LEFT JOIN campaign_ui_config uc ON c.id = uc.campaign_id
LEFT JOIN campaign_feature_flags ff ON c.id = ff.campaign_id
WHERE c.id = $1;
```

Luego agregar traducciones de `sponsorBadgeText` desde `campaign_translations`.

---

## Consideraciones Importantes

1. **Backward Compatibility:**
   - Todos los campos nuevos deben ser opcionales
   - Si no existen, usar valores por defecto sensatos
   - El SDK maneja fallback automáticamente

2. **Performance:**
   - Cachear respuestas en Redis (TTL: 5 minutos)
   - Invalidar cache cuando se actualice configuración
   - Usar índices en BD para queries rápidas

3. **Validación:**
   - Validar formatos (colores hex, duraciones positivas, etc.)
   - Validar que `campaignId` existe antes de retornar config
   - Validar que `apiKey` tiene acceso a la campaña

4. **Seguridad:**
   - Verificar que `apiKey` tiene permisos para la campaña
   - No exponer información sensible en configs
   - Sanitizar URLs de imágenes antes de retornarlas

---

## Prioridades de Implementación

**Alta prioridad (MVP):**
1. Endpoint `/v1/campaigns/{campaignId}/config` con brand y engagement básicos
2. Tablas de BD mínimas (brand_name, engagement_config básico)
3. Valores por defecto funcionando

**Media prioridad:**
4. Sistema de traducciones completo
5. UI Theme configuración
6. Feature flags

**Baja prioridad:**
7. Dashboard UI completo
8. WebSocket events automáticos
9. Cache avanzado
