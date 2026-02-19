# 🚀 Quick Start - Entertainment Components

Guía rápida para empezar a usar los componentes de entretenimiento interactivo en Viaplay.

## ⚡ Inicio Rápido (5 minutos)

### 1. Ver la Demo

```swift
// En tu NavigationView o cualquier vista
NavigationLink("Ver Demo de Entertainment") {
    EntertainmentDemoView()
}
```

### 2. Integrar en Video Player Existente

#### Opción A: Usar el Player Mejorado (Recomendado)

```swift
// Reemplaza ViaplayVideoPlayer con:
ViaplayVideoPlayerWithEntertainment(match: myMatch) {
    // onDismiss
}
.environmentObject(cartManager)
```

#### Opción B: Agregar Overlay al Player Actual

```swift
struct MyVideoView: View {
    @StateObject private var entertainmentManager = EntertainmentManager(
        userId: "user-123" // Obtener del sistema de auth
    )
    
    var body: some View {
        ZStack {
            // Tu video player actual
            ViaplayVideoPlayer(match: match) { }
            
            // Agregar overlay de entertainment
            EntertainmentOverlay(manager: entertainmentManager)
        }
        .task {
            await entertainmentManager.loadComponents()
        }
    }
}
```

### 3. Usar Componentes Individuales

```swift
struct MyCustomView: View {
    @StateObject private var manager = EntertainmentManager(userId: "user-123")
    
    var body: some View {
        ScrollView {
            ForEach(manager.activeComponents) { component in
                InteractiveComponentCard(
                    component: component,
                    hasResponded: manager.hasUserResponded(to: component.id),
                    showResults: manager.hasUserResponded(to: component.id),
                    onOptionSelected: { optionId in
                        Task {
                            try await manager.submitResponse(
                                componentId: component.id,
                                selectedOptions: [optionId]
                            )
                        }
                    }
                )
            }
        }
        .task {
            await manager.loadComponents()
        }
    }
}
```

## 📝 Configuración

### Cargar Componentes desde JSON

1. Copia `entertainment-config.json` a tu proyecto
2. Modifica `EntertainmentManager.swift`:

```swift
private func fetchComponentsFromSource() async throws -> [InteractiveComponent] {
    // Cargar desde archivo JSON
    guard let url = Bundle.main.url(
        forResource: "entertainment-config",
        withExtension: "json"
    ) else {
        throw EntertainmentError.configNotFound
    }
    
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    let config = try decoder.decode(EntertainmentConfig.self, from: data)
    return config.entertainment.components
}

// Agregar estructura para decodificar
struct EntertainmentConfig: Codable {
    let entertainment: EntertainmentData
}

struct EntertainmentData: Codable {
    let components: [InteractiveComponent]
}
```

### Conectar con API

```swift
private func fetchComponentsFromAPI() async throws -> [InteractiveComponent] {
    let url = URL(string: "https://api.reachu.io/v1/entertainment/components")!
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    let (data, _) = try await URLSession.shared.data(for: request)
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    return try decoder.decode([InteractiveComponent].self, from: data)
}
```

## 🎯 Casos de Uso Comunes

### 1. Trivia Durante Partido

```json
{
  "id": "trivia-1",
  "type": "trivia",
  "title": "¿Quién marcó el primer gol?",
  "interactionType": "single_choice",
  "options": [
    {"id": "1", "text": "Messi", "value": "messi", "isCorrect": true},
    {"id": "2", "text": "Ronaldo", "value": "ronaldo", "isCorrect": false}
  ],
  "points": 10,
  "timeLimit": 30
}
```

### 2. Encuesta de Opinión

```json
{
  "id": "poll-1",
  "type": "poll",
  "title": "¿Cuál es tu equipo favorito?",
  "interactionType": "single_choice",
  "options": [
    {"id": "1", "text": "Real Madrid", "emoji": "⚪"},
    {"id": "2", "text": "Barcelona", "emoji": "🔵"}
  ],
  "showResults": true
}
```

### 3. Predicción de Evento

```json
{
  "id": "prediction-1",
  "type": "prediction",
  "title": "¿Quién ganará el partido?",
  "interactionType": "single_choice",
  "options": [
    {"id": "1", "text": "Equipo Local", "value": "home"},
    {"id": "2", "text": "Equipo Visitante", "value": "away"},
    {"id": "3", "text": "Empate", "value": "draw"}
  ],
  "points": 20,
  "showResults": false
}
```

### 4. Reacciones Rápidas

```json
{
  "id": "reaction-1",
  "type": "reaction",
  "title": "¡Reacciona al gol!",
  "interactionType": "emoji",
  "options": [
    {"id": "1", "emoji": "🔥", "text": "Increíble"},
    {"id": "2", "emoji": "❤️", "text": "Me encanta"},
    {"id": "3", "emoji": "😮", "text": "Wow"}
  ],
  "allowMultipleResponses": true,
  "timeLimit": 10
}
```

## 🎨 Personalización Rápida

### Cambiar Colores

En `InteractiveComponentCard.swift`:

```swift
private var componentColor: Color {
    switch component.type {
    case .trivia: return .blue      // Cambiar a tu color
    case .quiz: return .purple
    case .poll: return .orange
    // ... etc
    }
}
```

### Cambiar Iconos

En `EntertainmentComponentType.swift`:

```swift
var iconName: String {
    switch self {
    case .trivia: return "questionmark.circle.fill"  // Cambiar icono
    case .quiz: return "brain.head.profile"
    // ... etc
    }
}
```

## 🔍 Debugging

### Ver Logs

```swift
// En EntertainmentManager
print("📊 [Entertainment] Componentes cargados: \(activeComponents.count)")
print("📊 [Entertainment] Usuario respondió: \(componentId)")
```

### Verificar Estado

```swift
// En tu vista
Text("Activos: \(manager.activeComponents.count)")
Text("Próximos: \(manager.upcomingComponents.count)")
Text("Completados: \(manager.completedComponents.count)")
```

## ⚠️ Problemas Comunes

### 1. Componentes no aparecen

**Solución**: Verifica que las fechas sean correctas

```swift
// Usar fechas futuras para testing
let component = InteractiveComponent(
    // ...
    startTime: Date(),  // Ahora
    endTime: Date().addingTimeInterval(300)  // +5 minutos
)
```

### 2. Respuestas no se guardan

**Solución**: Verifica que el componente esté activo

```swift
if component.state != .active {
    print("⚠️ Componente no está activo")
}
```

### 3. Timer no funciona

**Solución**: Verifica que las fechas estén en formato correcto

```swift
// Usar ISO8601 para fechas
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
```

## 📚 Recursos

- **Documentación Completa**: [ENTERTAINMENT_IMPLEMENTATION_GUIDE.md](ENTERTAINMENT_IMPLEMENTATION_GUIDE.md)
- **Resumen**: [ENTERTAINMENT_SUMMARY.md](ENTERTAINMENT_SUMMARY.md)
- **README del Módulo**: [Entertainment-README.md](Documentation/Entertainment-README.md)
- **Configuración de Ejemplo**: [entertainment-config.json](Viaplay/Configuration/entertainment-config.json)

## 🆘 Ayuda

Si tienes problemas:

1. Revisa la documentación completa
2. Verifica los logs en consola
3. Compara con los ejemplos en `EntertainmentDemoView.swift`
4. Revisa la configuración JSON de ejemplo

## ✅ Checklist de Integración

- [ ] Importar archivos de Entertainment
- [ ] Crear instancia de `EntertainmentManager`
- [ ] Agregar `EntertainmentOverlay` al video player
- [ ] Cargar componentes con `loadComponents()`
- [ ] Configurar JSON o conectar API
- [ ] Probar con `EntertainmentDemoView`
- [ ] Personalizar colores e iconos
- [ ] Agregar analytics (opcional)
- [ ] Testing en dispositivo real

## 🎉 ¡Listo!

Ya tienes todo lo necesario para empezar. Si necesitas más detalles, consulta la documentación completa.

---

**Tiempo estimado de integración**: 30-60 minutos  
**Dificultad**: Fácil  
**Soporte**: Ver documentación completa para casos avanzados

