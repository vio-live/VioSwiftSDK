# TASK #165 — locationId slot system en SDK

## Objetivo
El desarrollador usa `locationId` en lugar de `componentId` hardcodeado.
El SDK busca el componente activo para ese slot desde el backend.

## Cambios requeridos

### 1. CampaignManager — añadir getActiveComponent(locationId:)

En `Sources/VioCore/Managers/CampaignManager.swift`:

```swift
/// Get active component by locationId (slot)
public func getActiveComponent(locationId: String) -> Component? {
    return activeComponents.first { 
        $0.locationId == locationId && $0.isActive 
    }
}
```

### 2. Component model — añadir locationId

En `Sources/VioCore/Models/CampaignModels.swift`, struct `Component`:
```swift
public let locationId: String?  // añadir este campo
```

Y en el init y decode.

### 3. VProductBanner — añadir locationId param

En `Sources/VioUI/Components/VProductBanner.swift`:
```swift
// Añadir constructor alternativo
public init(locationId: String, showAddToCartButton: Bool = false) {
    self.componentId = nil
    self.locationId = locationId
    ...
}

// activeComponent: buscar por locationId si componentId es nil
private var activeComponent: Component? {
    if let lid = locationId {
        return campaignManager.getActiveComponent(locationId: lid)
    }
    return campaignManager.getActiveComponent(type: "product_banner", componentId: componentId)
}
```

### 4. VProductCarousel — mismo patrón que VProductBanner

### 5. VProductStore, VProductSpotlight — mismo patrón

### 6. ComponentStatusChangedEvent — incluir locationId

En el decode del evento WS `component_status_changed`, incluir `locationId` si viene.

### 7. CampaignManager.activeComponents — incluir locationId del WS event

Cuando se actualiza `activeComponents` desde el WS event, preservar `locationId`.

## Uso final en la demo

```swift
// SportDetailView.swift
VProductBanner(locationId: "sport-detail-banner")
VProductCarousel(locationId: "sport-detail-carousel", layout: "compact")
```

## Nota
El `Component` struct necesita `locationId` para que `getActiveComponent(locationId:)` funcione.
El backend ya devuelve `locationId` en `GET /v1/sdk/components`.
