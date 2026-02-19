# Entertainment Components - Interactive Features

Esta carpeta contiene la implementación de componentes interactivos de entretenimiento diseñados para ser portables al SDK de Reachu.

## 📁 Estructura

```
Entertainment/
├── README.md                           # Este archivo
├── EntertainmentComponentType.swift    # Enums y tipos base
├── EntertainmentModels.swift          # Modelos de datos
├── EntertainmentManager.swift         # Lógica de negocio y estado
└── Views/
    ├── InteractiveComponentCard.swift # Tarjeta individual de componente
    └── EntertainmentOverlay.swift     # Overlay para video player
```

## 🎯 Componentes Principales

### 1. **EntertainmentComponentType.swift**
Define los tipos de componentes interactivos disponibles:
- ✅ Trivia
- ✅ Quiz
- ✅ Poll (Encuestas)
- ✅ Prediction (Predicciones)
- ✅ Reaction (Reacciones)
- ✅ Voting (Votaciones)
- ✅ Challenge (Desafíos)
- ✅ Leaderboard (Tabla de posiciones)

### 2. **EntertainmentModels.swift**
Modelos de datos principales:
- `InteractiveComponent`: Componente interactivo completo
- `InteractionOption`: Opciones de respuesta
- `UserInteractionResponse`: Respuesta del usuario
- `ComponentResults`: Resultados agregados
- `LeaderboardEntry`: Entrada en tabla de posiciones

### 3. **EntertainmentManager.swift**
Gestor principal con:
- Carga y categorización de componentes
- Gestión de estados (upcoming, active, completed)
- Envío de respuestas de usuario
- Actualización automática de estados basada en tiempo
- Integración con backend (preparada para API)

### 4. **Views/**
Componentes de UI:
- `InteractiveComponentCard`: Tarjeta reutilizable para mostrar componentes
- `EntertainmentOverlay`: Overlay que se superpone al video player

## 🚀 Uso en Viaplay

### Integración Básica

```swift
import SwiftUI

struct VideoPlayerView: View {
    @StateObject private var entertainmentManager = EntertainmentManager(userId: "user-123")
    
    var body: some View {
        ZStack {
            // Tu video player
            VideoPlayer()
            
            // Overlay de entretenimiento
            EntertainmentOverlay(manager: entertainmentManager)
        }
        .task {
            await entertainmentManager.loadComponents()
        }
    }
}
```

### Uso Individual de Componentes

```swift
InteractiveComponentCard(
    component: myComponent,
    hasResponded: false,
    showResults: false,
    onOptionSelected: { optionId in
        // Manejar selección
        Task {
            try await manager.submitResponse(
                componentId: myComponent.id,
                selectedOptions: [optionId]
            )
        }
    }
)
```

## 🔄 Migración al SDK

### Paso 1: Crear Módulo en el SDK

```
Sources/
└── ReachuEntertainment/
    ├── Models/
    │   ├── EntertainmentComponentType.swift
    │   └── EntertainmentModels.swift
    ├── Managers/
    │   └── EntertainmentManager.swift
    ├── Views/
    │   ├── InteractiveComponentCard.swift
    │   └── EntertainmentOverlay.swift
    └── ReachuEntertainment.swift
```

### Paso 2: Actualizar Package.swift

```swift
.library(
    name: "ReachuEntertainment",
    targets: ["ReachuEntertainment"]
),

.target(
    name: "ReachuEntertainment",
    dependencies: [
        "ReachuCore",
        "ReachuDesignSystem"
    ]
),
```

### Paso 3: Adaptar para Configuración

El manager debería poder cargar componentes desde:
1. **Configuración JSON** (como reachu-config.json)
2. **API REST** (endpoints de Reachu)
3. **WebSocket** (actualizaciones en tiempo real)

Ejemplo de estructura en config:

```json
{
  "entertainment": {
    "enabled": true,
    "components": [
      {
        "id": "trivia-1",
        "type": "trivia",
        "title": "¿Quién ganó el último Mundial?",
        "interactionType": "single_choice",
        "options": [
          {
            "id": "opt1",
            "text": "Argentina",
            "value": "argentina",
            "isCorrect": true
          }
        ],
        "startTime": "2024-01-15T20:00:00Z",
        "endTime": "2024-01-15T20:05:00Z",
        "points": 10
      }
    ]
  }
}
```

### Paso 4: Integración con ReachuCore

```swift
// En ReachuCore
public class ReachuSDK {
    public let entertainment: EntertainmentManager
    
    public init(config: ReachuConfiguration) {
        self.entertainment = EntertainmentManager(
            userId: config.userId,
            apiClient: self.apiClient,
            websocket: self.websocket
        )
    }
}
```

## 🎨 Personalización

### Temas
Los componentes respetan el sistema de temas de `ReachuDesignSystem`:
- Colores adaptativos (light/dark mode)
- Typography tokens
- Spacing y border radius consistentes

### Extensibilidad

Para agregar nuevos tipos de componentes:

1. Agregar caso en `EntertainmentComponentType`
2. Extender `InteractiveComponent` si es necesario
3. Actualizar `InteractiveComponentCard` para el nuevo tipo
4. Implementar lógica específica en `EntertainmentManager`

## 🔌 Integración con Backend

### Endpoints Necesarios

```
GET    /api/v1/entertainment/components          # Listar componentes
POST   /api/v1/entertainment/components/:id/respond  # Enviar respuesta
GET    /api/v1/entertainment/components/:id/results # Obtener resultados
GET    /api/v1/entertainment/leaderboard          # Tabla de posiciones
```

### WebSocket Events

```
entertainment:component:created    # Nuevo componente
entertainment:component:updated    # Actualización de componente
entertainment:component:started    # Componente activado
entertainment:component:ended      # Componente finalizado
entertainment:results:updated      # Actualización de resultados
entertainment:leaderboard:updated  # Actualización de leaderboard
```

## ✅ Testing

### Unit Tests
- Validación de modelos
- Lógica de categorización de componentes
- Cálculo de resultados y porcentajes
- Manejo de estados y transiciones

### UI Tests
- Interacción con componentes
- Visualización de resultados
- Animaciones y transiciones
- Responsive design

## 📊 Analytics

Eventos a trackear:
- `entertainment_component_viewed`
- `entertainment_component_interacted`
- `entertainment_response_submitted`
- `entertainment_results_viewed`
- `entertainment_leaderboard_viewed`

## 🔐 Consideraciones de Seguridad

- Validar respuestas en el backend
- Rate limiting para prevenir spam
- Verificar timestamps para prevenir respuestas tardías
- Encriptar respuestas sensibles

## 🚧 TODOs

- [ ] Implementar integración real con API
- [ ] Agregar soporte para WebSocket
- [ ] Implementar persistencia local (cache)
- [ ] Agregar animaciones avanzadas
- [ ] Soporte para componentes multimedia (imágenes, videos)
- [ ] Implementar sistema de notificaciones push
- [ ] Agregar accesibilidad (VoiceOver)
- [ ] Tests unitarios completos
- [ ] Documentación de API

## 📝 Notas

Esta implementación está diseñada para ser:
- **Modular**: Fácil de mover al SDK
- **Extensible**: Nuevos tipos de componentes
- **Configurable**: Personalizable vía JSON
- **Performante**: Optimizada para tiempo real
- **Testeable**: Separación clara de responsabilidades

---

**Autor**: Equipo Reachu  
**Fecha**: Diciembre 2025  
**Versión**: 1.0.0

