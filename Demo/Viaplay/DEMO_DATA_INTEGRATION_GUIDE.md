# Demo Data Integration Guide

**Última actualización**: Enero 23, 2026  
**Estado**: ✅ Infraestructura completa, ⏳ Migración pendiente

## Overview

Este documento explica cómo usar el sistema de configuración de data estática del demo y cómo migrarlo a datos dinámicos del backend en el futuro.

## Estado Actual del Sistema

### ✅ Completado
- ✅ `DemoDataConfiguration` struct creada en `ModuleConfigurations.swift`
- ✅ `DemoDataManager` singleton implementado
- ✅ `demo-static-data.json` creado con toda la data estática
- ✅ `ConfigurationLoader.loadDemoDataConfiguration()` implementado
- ✅ Integrado en `ReachuConfiguration` (carga automática)
- ✅ Default initializers con valores por defecto
- ✅ Documentación completa creada

### ⏳ Pendiente (Ver [BACKEND_INTEGRATION_ROADMAP.md](BACKEND_INTEGRATION_ROADMAP.md))
- ⏳ Migrar componentes hardcoded a usar `DemoDataManager` (Fase 1)
- ⏳ Crear endpoint en backend para demo data (Fase 2)
- ⏳ Implementar carga híbrida (Fase 2)
- ⏳ Conectar con `CampaignManager` y `Product` objects (Fase 2)

## Referencias Cruzadas

- **[PROJECT_MASTER_DOCUMENTATION.md](PROJECT_MASTER_DOCUMENTATION.md)** ⭐ - Documento maestro consolidado
- **[BACKEND_INTEGRATION_ROADMAP.md](BACKEND_INTEGRATION_ROADMAP.md)** ⭐ - Roadmap completo de integración
- **[SDK_STRUCTURE_MAP.md](SDK_STRUCTURE_MAP.md)** - Mapa de estructura del SDK
- **[CURRENT_STATUS.md](CURRENT_STATUS.md)** - Estado actual del proyecto

## Estructura Actual

### Archivos Creados

1. **`demo-static-data.json`**: Archivo JSON con toda la data estática del demo
2. **`DemoDataConfiguration`**: Estructura en `ModuleConfigurations.swift`
3. **`DemoDataManager`**: Manager singleton para acceder fácilmente a la data
4. **Loader**: Función `ConfigurationLoader.loadDemoDataConfiguration()` para cargar desde JSON

### Ubicación del JSON

El archivo JSON debe estar en el bundle de la app:
- **Demo**: `/Demo/Viaplay/Viaplay/Configuration/demo-static-data.json`
- **Producción**: Debe agregarse al bundle del proyecto

## Uso Actual

### Cargar Configuración

La configuración se carga automáticamente cuando se inicializa `ReachuConfiguration`:

```swift
// En App.swift o AppDelegate
ConfigurationLoader.loadConfiguration()
// La demo data se carga automáticamente si existe el archivo JSON
```

### Acceder a la Data

```swift
// Usar DemoDataManager para acceso fácil
let logo = DemoDataManager.shared.defaultLogo
let avatar = DemoDataManager.shared.defaultAvatar

// Obtener URLs de productos
if let productUrl = DemoDataManager.shared.productUrl(for: "408895") {
    // Usar URL
}

// Obtener event IDs
let quizEventId = DemoDataManager.shared.contestQuizEventId

// Obtener countdown del banner
let countdown = DemoDataManager.shared.offerBannerCountdown
```

## Migración a Backend/Configuración Dinámica

### Opción 1: Integrar en `reachu-config.json`

**Ventajas:**
- Todo en un solo archivo de configuración
- Fácil de mantener
- Ya existe el sistema de carga

**Implementación:**

1. Mover la sección `demoData` a `reachu-config.json`:
```json
{
  "demoData": {
    "assets": { ... },
    "demoUsers": { ... },
    "productMappings": { ... }
  }
}
```

2. Agregar loader en `ConfigurationLoader.loadFromJSON()`:
```swift
if let demoDataJson = config.demoData {
    let demoDataConfig = createDemoDataConfiguration(from: demoDataJson)
    ReachuConfiguration.shared.demoDataConfiguration = demoDataConfig
}
```

### Opción 2: Cargar desde Backend API

**Ventajas:**
- Data completamente dinámica
- Puede cambiar sin actualizar la app
- Permite personalización por cliente/campaña

**Implementación:**

1. Crear endpoint en backend:
```
GET /api/v1/demo-data?campaignId={id}&broadcastId={id}
```

2. Crear servicio en SDK:
```swift
public class DemoDataService {
    static func fetchDemoData(
        campaignId: Int? = nil,
        broadcastId: String? = nil
    ) async throws -> DemoDataConfiguration {
        // Llamar al endpoint
        // Parsear respuesta
        // Retornar DemoDataConfiguration
    }
}
```

3. Actualizar `ReachuConfiguration`:
```swift
// En el método configure o en un método separado
Task {
    do {
        let demoData = try await DemoDataService.fetchDemoData(
            campaignId: campaignConfiguration.campaignId,
            broadcastId: broadcastContext?.broadcastId
        )
        await MainActor.run {
            ReachuConfiguration.shared.demoDataConfiguration = demoData
        }
    } catch {
        // Fallback a JSON local
        ReachuConfiguration.shared.demoDataConfiguration = 
            ConfigurationLoader.loadDemoDataConfiguration()
    }
}
```

### Opción 3: Híbrido (Recomendado)

**Estrategia:**
- Usar JSON local como fallback/default
- Cargar desde backend si está disponible
- Cachear respuesta del backend

**Implementación:**

```swift
public class DemoDataManager {
    private var cachedConfig: DemoDataConfiguration?
    private var lastFetchDate: Date?
    private let cacheTimeout: TimeInterval = 3600 // 1 hora
    
    func loadDemoData(
        fromBackend: Bool = true,
        campaignId: Int? = nil,
        broadcastId: String? = nil
    ) async {
        // 1. Intentar cargar desde backend si está habilitado
        if fromBackend, shouldFetchFromBackend() {
            do {
                let config = try await DemoDataService.fetchDemoData(
                    campaignId: campaignId,
                    broadcastId: broadcastId
                )
                cachedConfig = config
                lastFetchDate = Date()
                ReachuConfiguration.shared.demoDataConfiguration = config
                return
            } catch {
                ReachuLogger.warning("Failed to load demo data from backend: \(error)", component: "DemoData")
            }
        }
        
        // 2. Fallback a JSON local
        let localConfig = ConfigurationLoader.loadDemoDataConfiguration()
        ReachuConfiguration.shared.demoDataConfiguration = localConfig
    }
    
    private func shouldFetchFromBackend() -> Bool {
        guard let lastFetch = lastFetchDate else { return true }
        return Date().timeIntervalSince(lastFetch) > cacheTimeout
    }
}
```

## Prioridades de Migración

### Fase 1: Assets (Alta Prioridad)
- **Actual**: Hardcoded en componentes
- **Objetivo**: Cargar desde `CampaignManager.currentCampaign?.campaignLogo`
- **Migración**: Usar `DemoDataManager` como fallback

### Fase 2: Product Mappings (Alta Prioridad)
- **Actual**: URLs hardcoded por ID
- **Objetivo**: Obtener desde objeto `Product` del SDK
- **Migración**: Si `Product.url` existe, usarlo; sino usar `DemoDataManager`

### Fase 3: Demo Users (Media Prioridad)
- **Actual**: Usernames hardcoded
- **Objetivo**: Obtener desde perfil de usuario o backend
- **Migración**: Usar `DemoDataManager` como fallback

### Fase 4: Event IDs (Baja Prioridad)
- **Actual**: IDs hardcoded
- **Objetivo**: Generar dinámicamente o obtener del backend
- **Migración**: Mantener en JSON hasta que backend los provea

### Fase 5: Match Defaults (Media Prioridad)
- **Actual**: BroadcastId y score hardcoded
- **Objetivo**: Obtener del modelo `Match` o backend
- **Migración**: Usar valores del modelo `Match` primero, luego `DemoDataManager`

### Fase 6: Offer Banner (Media Prioridad)
- **Actual**: Countdown hardcoded
- **Objetivo**: Calcular desde fecha de expiración de campaña
- **Migración**: Calcular dinámicamente desde `CampaignManager`

## Ejemplo de Uso en Componentes

### Antes (Hardcoded):
```swift
Image("logo1")  // Hardcoded
let username = "Angelo"  // Hardcoded
let productUrl = "https://www.elkjop.no/..."  // Hardcoded
```

### Después (Usando DemoDataManager):
```swift
// Assets
Image(DemoDataManager.shared.defaultLogo)

// Username
let username = DemoDataManager.shared.defaultUsername

// Product URL
let productUrl = DemoDataManager.shared.productUrl(for: productId) 
    ?? product.url  // Fallback a Product object
```

### Futuro (Backend):
```swift
// Assets - desde CampaignManager
if let logoUrl = CampaignManager.shared.currentCampaign?.campaignLogo {
    AsyncImage(url: URL(string: logoUrl))
} else {
    Image(DemoDataManager.shared.defaultLogo)  // Fallback
}

// Username - desde UserProfile
let username = UserProfile.shared.username 
    ?? DemoDataManager.shared.defaultUsername  // Fallback

// Product URL - desde Product object
let productUrl = product.url 
    ?? DemoDataManager.shared.productUrl(for: String(product.id))  // Fallback
```

## Recomendaciones

1. **Mantener JSON como fallback**: Siempre tener valores por defecto en JSON
2. **Priorizar datos del SDK**: Si el SDK provee la data (ej: `Product.url`), usarla primero
3. **Backend como fuente principal**: Cuando esté disponible, cargar desde backend
4. **Cache inteligente**: Cachear respuestas del backend para evitar llamadas innecesarias
5. **Logging**: Registrar cuando se usa fallback para identificar qué falta migrar

## Testing

Para probar la migración:

1. **Modo Demo (JSON)**: Asegurar que `demo-static-data.json` existe y se carga
2. **Modo Backend**: Simular respuesta del backend y verificar que se usa
3. **Modo Fallback**: Deshabilitar backend y verificar que usa JSON
4. **Modo Híbrido**: Verificar que usa backend cuando está disponible, JSON cuando no

## Próximos Pasos

1. ✅ Crear estructura `DemoDataConfiguration`
2. ✅ Crear `DemoDataManager`
3. ✅ Crear loader desde JSON
4. ✅ Integrar en `ReachuConfiguration`
5. ✅ Documentación completa
6. ⏳ Migrar componentes para usar `DemoDataManager` (Fase 1 - Ver [BACKEND_INTEGRATION_ROADMAP.md](BACKEND_INTEGRATION_ROADMAP.md))
7. ⏳ Crear endpoint en backend para demo data (Fase 2)
8. ⏳ Implementar carga desde backend (Fase 2)
9. ⏳ Implementar cache (Fase 2)
10. ⏳ Migrar gradualmente cada componente (Fase 1)

**Para más detalles sobre el plan de migración, consulta [BACKEND_INTEGRATION_ROADMAP.md](BACKEND_INTEGRATION_ROADMAP.md)**
