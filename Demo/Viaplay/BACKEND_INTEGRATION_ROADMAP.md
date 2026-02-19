# Viaplay Demo - Backend Integration Roadmap

## Objetivo
Mantener la demo funcional mientras se conecta gradualmente con el backend real. Usar `DemoDataManager` como sistema de fallback para asegurar que la demo siempre funcione.

## Estado Actual
- ✅ Sistema de configuración de data estática creado (`DemoDataConfiguration`, `DemoDataManager`)
- ✅ JSON con toda la data estática (`demo-static-data.json`)
- ✅ Loader y manager implementados en SDK
- ✅ Integrado en `ReachuConfiguration`
- ✅ Default initializers con valores por defecto
- ✅ Documentación completa creada (`DEMO_DATA_INTEGRATION_GUIDE.md`, `DEMO_DATA_SUMMARY.md`)
- ⏳ Componentes aún usan valores hardcoded (Fase 1 pendiente)
- ⏳ Backend no está completamente conectado (Fase 2 pendiente)

## Fase 1: Migración a DemoDataManager (Mantener Demo Funcional)

### Prioridad Alta - Assets y Logos

#### Tarea 1.1: Migrar componentes de imagen hardcoded
**Estado**: ⏳ Pendiente  
**Componentes afectados**:
- [ ] `CampaignSponsorBadge.swift` - Reemplazar `Image("logo1")` con `DemoDataManager.shared.defaultLogo`
- [ ] `ViaplayOfferBannerView.swift` - Usar `DemoDataManager` para logo y background
- [ ] `SponsorBanner.swift` - Usar `DemoDataManager.shared.defaultLogo`
- [ ] `MatchHeaderView.swift` - Reemplazar `Image("logo1")`
- [ ] `LineupCard.swift` - Reemplazar `Image("logo1")`
- [ ] `CastingContestCard.swift` - Reemplazar `Image("avatar_el")` con `DemoDataManager.shared.defaultAvatar`
- [ ] `CastingProductCard.swift` - Reemplazar `Image("avatar_el")` con `DemoDataManager.shared.defaultAvatar`
- [ ] `HeroSection.swift` - Usar `DemoDataManager` para backgrounds
- [ ] `ViaplayHomeView.swift` - Usar `DemoDataManager` para iconos y logos
- [ ] `SportDetailView.swift` - Usar `DemoDataManager` para backgrounds

**Estrategia**:
```swift
// Antes
Image("logo1")

// Después
if let logoUrl = CampaignManager.shared.currentCampaign?.campaignLogo, 
   let url = URL(string: logoUrl) {
    AsyncImage(url: url)
} else {
    Image(DemoDataManager.shared.defaultLogo)  // Fallback
}
```

#### Tarea 1.2: Migrar countdown del Offer Banner
**Estado**: ⏳ Pendiente  
**Archivo**: `ViaplayOfferBannerView.swift`

**Estrategia**:
```swift
// Antes: Valores hardcoded (2 días, 1 hora, 59 min, 47 seg)
// Después: Calcular desde campaña o usar DemoDataManager
let countdown = calculateCountdownFromCampaign() 
    ?? DemoDataManager.shared.offerBannerCountdown
```

### Prioridad Alta - Product URLs

#### Tarea 1.3: Migrar URLs de productos hardcoded
**Estado**: ⏳ Pendiente  
**Archivos afectados**:
- [ ] `CastingProductCard.swift` - Función `getProductUrl()`
- [ ] `CastingProductCardWrapper.swift` - Función `getProductUrl()`
- [ ] `TimelineDataGenerator.swift` - URLs en eventos de productos

**Estrategia**:
```swift
// Antes: Mapeo hardcoded por ID
if productIdString == "408895" {
    return "https://www.elkjop.no/..."
}

// Después: Usar Product object primero, luego DemoDataManager
func getProductUrl(for product: Product) -> String? {
    // 1. Intentar desde Product object (si tiene URL)
    if let url = product.url {
        return url
    }
    
    // 2. Fallback a DemoDataManager
    return DemoDataManager.shared.productUrl(for: String(product.id))
}
```

### Prioridad Media - Usuarios y Chat

#### Tarea 1.4: Migrar username hardcoded
**Estado**: ⏳ Pendiente  
**Archivo**: `LiveMatchViewModel.swift` línea 265

**Estrategia**:
```swift
// Antes
username: "Angelo"

// Después
username: UserProfile.shared?.username 
    ?? DemoDataManager.shared.defaultUsername
```

#### Tarea 1.5: Migrar usernames de chat demo
**Estado**: ⏳ Pendiente  
**Archivo**: `TimelineDataGenerator.swift`

**Estrategia**: Usar `DemoDataManager.shared.randomChatUsername()` o lista configurada

### Prioridad Media - Match Data

#### Tarea 1.6: Migrar BroadcastId hardcoded
**Estado**: ⏳ Pendiente  
**Archivo**: `MatchModels.swift` línea 115-118

**Estrategia**:
```swift
// Antes: Caso especial para Barcelona-PSG
if title.contains("Barcelona") && title.contains("PSG") {
    return "barcelona-psg-2025-01-23"
}

// Después: Configurable o desde backend
func generateBroadcastId() -> String {
    // 1. Intentar desde configuración o backend
    if let broadcastId = configuredBroadcastId {
        return broadcastId
    }
    
    // 2. Intentar desde mapeo genérico
    let matchKey = createMatchKey(from: title)
    if let mappedId = DemoDataManager.shared.broadcastId(for: matchKey) {
        return mappedId
    }
    
    // 3. Generar dinámicamente
    return generateFromMatchData()
}
```

#### Tarea 1.7: Migrar score hardcoded
**Estado**: ⏳ Pendiente  
**Archivo**: `AllContentFeed.swift` línea 454

**Estrategia**: Usar valores del modelo `Match` primero, luego `DemoDataManager.shared.defaultScore`

### Prioridad Baja - Event IDs

#### Tarea 1.8: Migrar IDs de eventos hardcoded
**Estado**: ⏳ Pendiente  
**Archivo**: `TimelineDataGenerator.swift`

**Estrategia**: Usar `DemoDataManager.shared.contestQuizEventId`, etc.

## Fase 2: Integración con Backend (Mantener Demo Funcional)

### Tarea 2.1: Crear endpoint en backend para demo data
**Estado**: ⏳ Pendiente  
**Endpoint propuesto**: `GET /api/v1/demo-data?campaignId={id}&broadcastId={id}`

**Respuesta esperada**:
```json
{
  "assets": { ... },
  "demoUsers": { ... },
  "productMappings": { ... },
  "eventIds": { ... },
  "matchDefaults": { ... },
  "offerBanner": { ... }
}
```

### Tarea 2.2: Crear DemoDataService en SDK
**Estado**: ⏳ Pendiente  
**Ubicación**: `Sources/ReachuCore/Services/DemoDataService.swift`

**Funcionalidad**:
- Fetch desde backend
- Cache de respuestas
- Fallback a JSON local

### Tarea 2.3: Implementar carga híbrida en DemoDataManager
**Estado**: ⏳ Pendiente  
**Estrategia**: Ver `DEMO_DATA_INTEGRATION_GUIDE.md` - Opción 3 (Híbrido)

### Tarea 2.4: Conectar con CampaignManager para assets
**Estado**: ⏳ Pendiente  
**Objetivo**: Usar `CampaignManager.currentCampaign?.campaignLogo` como fuente principal

### Tarea 2.5: Conectar con Product objects para URLs
**Estado**: ⏳ Pendiente  
**Objetivo**: Verificar si `Product` tiene campo `url` y usarlo primero

### Tarea 2.6: Conectar con UserProfile para username
**Estado**: ⏳ Pendiente  
**Objetivo**: Crear `UserProfile` manager o usar sistema existente

## Fase 3: Deshabilitar demoMode (Producción)

### Tarea 3.1: Cambiar demoMode a false
**Estado**: ⏳ Pendiente  
**Archivo**: `reachu-config.json` línea 165

**Requisitos previos**:
- ✅ Todas las tareas de Fase 1 completadas
- ✅ Backend funcionando correctamente
- ✅ Pruebas completas con datos reales

### Tarea 3.2: Verificar flujo completo con backend
**Estado**: ⏳ Pendiente  
**Checklist**:
- [ ] Votación en polls funciona
- [ ] Participación en contests funciona
- [ ] Productos se cargan correctamente
- [ ] Chat funciona con backend
- [ ] Timeline se sincroniza con backend

## Checklist de Migración por Componente

### Componentes de Assets
- [ ] `CampaignSponsorBadge.swift`
- [ ] `ViaplayOfferBannerView.swift`
- [ ] `SponsorBanner.swift`
- [ ] `MatchHeaderView.swift`
- [ ] `LineupCard.swift`
- [ ] `CastingContestCard.swift`
- [ ] `CastingProductCard.swift`
- [ ] `HeroSection.swift`
- [ ] `ViaplayHomeView.swift`
- [ ] `SportDetailView.swift`

### Componentes de Productos
- [ ] `CastingProductCard.swift`
- [ ] `CastingProductCardWrapper.swift`
- [ ] `TimelineDataGenerator.swift` (eventos de productos)

### Componentes de Usuarios
- [ ] `LiveMatchViewModel.swift` (username)
- [ ] `TimelineDataGenerator.swift` (chat usernames)

### Componentes de Match
- [ ] `MatchModels.swift` (broadcastId)
- [ ] `AllContentFeed.swift` (score)

### Componentes de Eventos
- [ ] `TimelineDataGenerator.swift` (event IDs)

## Notas Importantes

1. **Mantener Demo Funcional**: Siempre tener fallback a `DemoDataManager` para asegurar que la demo funcione
2. **Migración Gradual**: Migrar componente por componente, probando cada uno
3. **Priorizar SDK Data**: Si el SDK provee la data (ej: `Product.url`), usarla primero
4. **Backend como Opción**: Backend debe ser opcional, no requerido para que la demo funcione
5. **Testing Continuo**: Probar después de cada migración que la demo sigue funcionando

## Orden Recomendado de Implementación

1. **Semana 1**: Tareas 1.1 y 1.2 (Assets y Countdown)
2. **Semana 2**: Tareas 1.3 (Product URLs)
3. **Semana 3**: Tareas 1.4 y 1.5 (Usuarios)
4. **Semana 4**: Tareas 1.6 y 1.7 (Match Data)
5. **Semana 5**: Tareas 1.8 (Event IDs)
6. **Semana 6+**: Fase 2 (Integración Backend)

## Referencias

- **Documento Maestro**: `PROJECT_MASTER_DOCUMENTATION.md` ⭐ - Visión consolidada del proyecto
- **Estructura del SDK**: `SDK_STRUCTURE_MAP.md` ⭐ - Mapa completo de estructura
- **Guía de Integración**: `DEMO_DATA_INTEGRATION_GUIDE.md` - Guía completa de Demo Data
- **Estado Actual**: `CURRENT_STATUS.md` - Estado actual del proyecto
- **JSON de Configuración**: `Configuration/demo-static-data.json`
- **Manager**: `Sources/ReachuCore/Managers/DemoDataManager.swift`
- **Configuración**: `Sources/ReachuCore/Configuration/ModuleConfigurations.swift` (DemoDataConfiguration)
- **Loader**: `Sources/ReachuCore/Configuration/ConfigurationLoader.swift` (loadDemoDataConfiguration)
