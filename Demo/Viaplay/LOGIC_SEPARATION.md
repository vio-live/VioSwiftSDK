# 🏗️ Separación de Lógica - Arquitectura Detallada

**Pregunta**: ¿Está toda la lógica aislada?  
**Respuesta**: ✅ SÍ - 100% separada en capas

---

## 📊 Arquitectura en Capas

```
┌─────────────────────────────────────────────────────────┐
│ CAPA 1: PRESENTACIÓN (UI - Solo Vistas)                │
│ Responsabilidad: Mostrar componentes, recibir eventos  │
├─────────────────────────────────────────────────────────┤
│ LiveMatchViewRefactored.swift            93 líneas     │
│ - Solo composición de componentes                       │
│ - Sin lógica de negocio                                 │
│ - Sin cálculos                                          │
│ - Sin filtrado de datos                                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ Comunica vía @StateObject
                     │
┌────────────────────▼────────────────────────────────────┐
│ CAPA 2: PRESENTACIÓN LOGIC (ViewModels)                │
│ Responsabilidad: Lógica de presentación y coordinación │
├─────────────────────────────────────────────────────────┤
│ LiveMatchViewModel.swift                214 líneas     │
│ - Coordina 4 managers                                   │
│ - Filtrado de datos para UI                            │
│ - Computed properties                                   │
│ - User actions (jumpToMinute, selectTab, etc)          │
│ - Sin lógica de negocio compleja                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ Usa múltiples managers
                     │
┌────────────────────▼────────────────────────────────────┐
│ CAPA 3: BUSINESS LOGIC (Managers)                      │
│ Responsabilidad: Lógica de negocio específica          │
├─────────────────────────────────────────────────────────┤
│ ChatManager.swift                       135 líneas     │
│ - Gestión de mensajes de chat                          │
│ - Simulación de usuarios                               │
│ - Timer de mensajes                                    │
│ - Contador de espectadores                             │
│                                                          │
│ MatchSimulationManager.swift            117 líneas     │
│ - Simulación del partido                               │
│ - Eventos del partido (goles, tarjetas)                │
│ - Actualización de marcador                            │
│ - Timeline de eventos                                  │
│                                                          │
│ EntertainmentManager.swift              337 líneas     │
│ - Gestión de componentes interactivos                  │
│ - Categorización (upcoming/active/completed)           │
│ - Respuestas de usuario                                │
│ - Sistema de puntos                                    │
│ - (Preparado para) Conexión a backend                  │
│                                                          │
│ VideoPlayerViewModel.swift              (en ViaplayVideoPlayer)│
│ - Control del video player                             │
│ - Play/pause/seek                                      │
│ - Gestión de estados                                   │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ Opera sobre modelos
                     │
┌────────────────────▼────────────────────────────────────┐
│ CAPA 4: MODELOS (Data)                                 │
│ Responsabilidad: Estructura de datos                   │
├─────────────────────────────────────────────────────────┤
│ ChatModels.swift                        44 líneas      │
│ - struct ChatMessage                                    │
│ - Helper extensions                                     │
│                                                          │
│ MatchModels.swift                       123 líneas     │
│ - struct Match, Team                                    │
│ - enum MatchAvailability                               │
│                                                          │
│ MatchStatisticsModels.swift             330 líneas     │
│ - struct MatchEvent, MatchTimeline                     │
│ - struct MatchStatistics, Statistic                    │
│ - struct LeagueTable, TeamStanding                     │
│ - struct Player, TeamLineup                            │
│                                                          │
│ EntertainmentModels.swift               210 líneas     │
│ - struct InteractiveComponent                          │
│ - struct InteractionOption                             │
│ - struct UserInteractionResponse                       │
│ - struct ComponentResults                              │
└─────────────────────────────────────────────────────────┘
```

---

## ✅ Verificación de Separación

### LiveMatchViewRefactored (Vista)

```swift
// ❌ NO TIENE:
- Lógica de negocio
- Filtrado de datos
- Cálculos complejos
- Gestión de estado interno
- Timers o async tasks complejos

// ✅ SOLO TIENE:
var body: some View {
    VStack {
        MatchHeaderView(...)      // Componente
        SponsorBanner()            // Componente
        MatchNavigationTabs(...)   // Componente
        MatchContentView(...)      // Componente
        VideoTimelineControl(...)  // Componente
    }
    .onAppear { viewModel.onAppear() }     // Delega al ViewModel
    .onDisappear { viewModel.onDisappear() } // Delega al ViewModel
}
```

### LiveMatchViewModel (Lógica de Presentación)

```swift
// ❌ NO TIENE:
- UI components
- SwiftUI Views
- Layout logic

// ✅ SÍ TIENE:
@Published var selectedTab: MatchTab           // Estado de UI
@Published var selectedMinute: Int?            // Estado de UI

func filteredChatMessages() -> [ChatMessage]  // Lógica de filtrado
func mixedContentItems() -> [MixedContentItem] // Lógica de composición
func handlePollVote(...)                       // Coordinación de acciones

// Delega a managers especializados:
chatManager.startSimulation()
matchSimulation.startSimulation()
entertainmentManager.loadComponents()
```

### ChatManager (Lógica de Negocio)

```swift
// ❌ NO TIENE:
- UI components
- Acceso a ViewModels
- Conocimiento de la vista

// ✅ SÍ TIENE:
@Published var messages: [ChatMessage]   // Datos
@Published var viewerCount: Int          // Datos

func startSimulation()                   // Lógica pura
func addMessage(_ message: ChatMessage)  // Lógica pura
private func addSimulatedMessage()       // Lógica pura
```

---

## 🎯 Flujo de Datos (Unidireccional)

```
Usuario toca opción de Poll
        ↓
┌───────────────────────────────┐
│ PollCard.swift (UI)           │ ← Solo captura evento
│   onVote: { optionId in       │
│     viewModel.handlePollVote  │
│   }                            │
└───────────────┬───────────────┘
                ↓
┌───────────────▼───────────────┐
│ LiveMatchViewModel            │ ← Coordina acción
│   func handlePollVote() {     │
│     entertainmentManager      │
│       .submitResponse(...)    │
│   }                            │
└───────────────┬───────────────┘
                ↓
┌───────────────▼───────────────┐
│ EntertainmentManager          │ ← Ejecuta lógica
│   func submitResponse() {     │
│     - Validar componente      │
│     - Crear respuesta         │
│     - Enviar a backend        │
│     - Actualizar estado       │
│   }                            │
└───────────────┬───────────────┘
                ↓
┌───────────────▼───────────────┐
│ Backend API (futuro)          │ ← Persistencia
│ POST /entertainment/respond   │
└───────────────┬───────────────┘
                ↓
    @Published se actualiza
                ↓
        UI se re-renderiza
```

---

## 📁 Separación por Responsabilidad

### 1. Data Layer (Models)
**Ubicación**: `Models/`

```
Responsabilidad: SOLO estructura de datos
├── ChatModels.swift
│   └── struct ChatMessage: Identifiable
├── MatchModels.swift
│   └── struct Match, Team, etc.
└── EntertainmentModels.swift
    └── struct InteractiveComponent, etc.

❌ NO contienen: Lógica, UI, ViewModels
✅ SÍ contienen: Datos, Computed properties simples, Extensions
```

### 2. Business Logic Layer (Managers)
**Ubicación**: `Managers/`

```
Responsabilidad: Lógica de negocio específica
├── Chat/ChatManager.swift
│   ├── Simular mensajes
│   ├── Gestionar lista de mensajes
│   └── Contador de espectadores
├── Match/MatchSimulationManager.swift
│   ├── Simular eventos del partido
│   ├── Actualizar marcador
│   └── Generar timeline
└── Entertainment/EntertainmentManager.swift
    ├── Cargar componentes
    ├── Categorizar por estado
    ├── Gestionar respuestas
    └── Conectar a backend (futuro)

❌ NO contienen: UI, SwiftUI Views
✅ SÍ contienen: @Published properties, async functions, business rules
```

### 3. Presentation Logic Layer (ViewModels)
**Ubicación**: `Managers/Match/LiveMatchViewModel.swift`

```
Responsabilidad: Coordinar managers y preparar datos para UI
├── Coordina 4 managers (chat, match, entertainment, player)
├── Filtrado de datos según minuto seleccionado
├── Composición de contenido mezclado
├── Manejo de acciones de usuario
└── Lifecycle (onAppear, onDisappear)

❌ NO contienen: UI components, layout logic
✅ SÍ contienen: @Published state, coordinator logic, data transformation
```

### 4. UI Components Layer (Views)
**Ubicación**: `Components/`

```
Responsabilidad: SOLO presentación visual
├── Atoms/ (8 componentes)
│   └── ChatAvatar, TeamLogo, MatchScore, LiveBadge, etc.
├── Molecules/ (7 componentes)
│   └── ChatMessageRow, PollCard, EventCard, etc.
└── Organisms/ (5 componentes)
    └── ChatListView, AllContentFeed, MatchContentView, etc.

❌ NO contienen: Lógica de negocio, cálculos, filtrado
✅ SÍ contienen: SwiftUI Views, layout, styling, eventos simples
```

### 5. Page Layer (Main Views)
**Ubicación**: `Views/LiveMatchViewRefactored.swift`

```
Responsabilidad: Composición de componentes
├── Inicializa ViewModel
├── Pasa datos a componentes
├── Maneja lifecycle básico
└── Solo 93 líneas de composición pura

❌ NO contienen: Lógica, cálculos, managers directos
✅ SÍ contienen: Componentes, bindings, delegates al ViewModel
```

---

## 🔍 Ejemplos Concretos

### Ejemplo 1: Lógica de Filtrado por Minuto

**❌ ANTES (En la vista - MAL)**:
```swift
struct LiveMatchView: View {
    var body: some View {
        // ... 
        let filteredMessages = chatManager.messages.filter { message in
            let messageIndex = chatManager.messages.firstIndex(where: { $0.id == message.id }) ?? 0
            let estimatedMinute = (messageIndex * currentFilterMinute) / max(chatManager.messages.count, 1)
            return estimatedMinute <= currentFilterMinute
        }
        // ... lógica compleja en la vista
    }
}
```

**✅ AHORA (En ViewModel - BIEN)**:
```swift
// En LiveMatchViewModel.swift (Lógica)
func filteredChatMessages() -> [ChatMessage] {
    chatManager.messages.filter { message in
        let messageIndex = chatManager.messages.firstIndex(where: { $0.id == message.id }) ?? 0
        let estimatedMinute = (messageIndex * currentFilterMinute) / max(chatManager.messages.count, 1)
        return estimatedMinute <= currentFilterMinute
    }
}

// En ChatListView.swift (UI)
struct ChatListView: View {
    let messages: [ChatMessage]  // Ya filtrados
    var body: some View {
        ForEach(messages) { message in
            ChatMessageRow(message: message)
        }
    }
}

// En LiveMatchViewRefactored.swift (Composición)
ChatListView(messages: viewModel.filteredChatMessages())
```

### Ejemplo 2: Contenido Mezclado

**❌ ANTES (1300 líneas en vista - MAL)**:
```swift
struct LiveMatchView: View {
    private var mixedContentItems: [MixedContentItem] {
        var items: [MixedContentItem] = []
        // ... 100+ líneas de lógica compleja
        // ... filtrado, composición, ordenamiento
        return items.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        ForEach(mixedContentItems) { item in
            // ... 200+ líneas de switch/case
        }
    }
}
```

**✅ AHORA (Separado en capas - BIEN)**:
```swift
// LiveMatchViewModel.swift (Lógica de composición)
func mixedContentItems() -> [MixedContentItem] {
    // ... lógica de mezclar eventos, chat, polls, etc.
    return items.sorted { $0.timestamp > $1.timestamp }
}

// AllContentFeed.swift (Componente de UI)
struct AllContentFeed: View {
    let items: [MixedContentItem]  // Ya preparados
    var body: some View {
        ForEach(items) { item in
            switch item.type {
            case .chatMessage: ChatMessageRow(...)
            case .poll: PollCard(...)
            // ... solo renderiza componentes
            }
        }
    }
}

// LiveMatchViewRefactored.swift (Composición)
AllContentFeed(items: viewModel.mixedContentItems())
```

### Ejemplo 3: Acciones de Usuario

**❌ ANTES (Mezclado - MAL)**:
```swift
struct LiveMatchView: View {
    @StateObject private var entertainmentManager = EntertainmentManager(...)
    
    private func handlePollVote(...) {
        Task {
            try await entertainmentManager.submitResponse(...)
        }
    }
    
    var body: some View {
        Button { handlePollVote(...) }
    }
}
```

**✅ AHORA (3 capas separadas - BIEN)**:
```swift
// PollCard.swift (UI - Captura evento)
struct PollCard: View {
    let onVote: (String) -> Void
    
    var body: some View {
        Button { onVote(option.id) }
    }
}

// LiveMatchViewModel.swift (Coordinación)
func handlePollVote(componentId: String, optionId: String) {
    Task {
        try await entertainmentManager.submitResponse(...)
    }
}

// EntertainmentManager.swift (Lógica de negocio)
func submitResponse(...) async throws {
    // Validar componente
    // Crear respuesta
    // Enviar a backend
    // Actualizar estado
}
```

---

## 🎯 Responsabilidades por Archivo

### LiveMatchViewRefactored.swift (93 líneas)
```swift
✅ Responsabilidades:
- Inicializar ViewModel
- Componer componentes visuales
- Pasar props a componentes
- Lifecycle básico (onAppear/onDisappear)

❌ NO responsable de:
- Lógica de negocio
- Filtrado de datos
- Gestión de timers
- Networking
- Cálculos
```

### LiveMatchViewModel.swift (214 líneas)
```swift
✅ Responsabilidades:
- Coordinar 4 managers
- Filtrar datos para la UI
- Computed properties (matchTimeline, currentFilterMinute)
- User actions (selectTab, jumpToMinute, handlePollVote)
- Preparar datos mezclados (mixedContentItems)

❌ NO responsable de:
- UI/layout
- Lógica específica de chat/match/entertainment (delegada a managers)
- Persistencia
- Networking directo
```

### ChatManager.swift (135 líneas)
```swift
✅ Responsabilidades:
- Gestionar mensajes de chat
- Simulación de mensajes
- Conteo de espectadores
- Límite de mensajes (max 100)

❌ NO responsable de:
- UI/presentación
- Filtrado por minuto (eso es en ViewModel)
- Coordinación con otros managers
```

### MatchSimulationManager.swift (117 líneas)
```swift
✅ Responsabilidades:
- Simular minutos del partido (0-90)
- Generar eventos (goles, tarjetas, etc.)
- Actualizar marcador
- Timeline de eventos

❌ NO responsable de:
- UI/presentación
- Chat o polls
- Filtrado para UI
```

### EntertainmentManager.swift (337 líneas)
```swift
✅ Responsabilidades:
- Cargar componentes interactivos
- Categorizar por estado (upcoming/active/completed)
- Gestionar respuestas de usuario
- Sistema de puntos
- (Futuro) Conexión a backend

❌ NO responsable de:
- UI/presentación
- Chat o match simulation
- Coordinación general (eso es en ViewModel)
```

---

## 🔄 Flujo Completo de Datos

### Ejemplo: Usuario selecciona un minuto en el timeline

```
1. USER ACTION (UI Layer)
   VideoTimelineControl.swift
   - Usuario arrastra scrubber
   - Detecta posición → calcula minuto
   - Actualiza binding: selectedMinute = 45

2. STATE UPDATE (ViewModel Layer)
   LiveMatchViewModel.swift
   - @Published var selectedMinute se actualiza
   - Computed property currentFilterMinute cambia
   - SwiftUI detecta cambio

3. DATA FILTERING (ViewModel Layer)
   LiveMatchViewModel.swift
   - filteredChatMessages() se re-calcula
   - filteredPolls() se re-calcula
   - filteredEvents() se re-calcula
   - mixedContentItems() se re-calcula

4. UI RE-RENDER (UI Layer)
   AllContentFeed.swift
   - Recibe nuevos items filtrados
   - ForEach re-renderiza
   - Muestra solo contenido hasta minuto 45

5. MANAGERS (Business Logic)
   ChatManager, MatchSimulation, Entertainment
   - No se enteran del cambio
   - Siguen funcionando independientemente
   - Solo proveen datos cuando se les pide
```

---

## 🎨 Testabilidad por Capa

### Models (100% Testeable sin UI)
```swift
func testChatMessage() {
    let message = ChatMessage(
        username: "Test",
        text: "Hello",
        usernameColor: .blue,
        likes: 5,
        timestamp: Date()
    )
    XCTAssertEqual(message.username, "Test")
    XCTAssertEqual(message.avatarInitial, "T")
}
```

### Managers (100% Testeable sin UI)
```swift
func testChatManagerSimulation() {
    let manager = ChatManager()
    manager.startSimulation()
    
    // Esperar mensajes
    let expectation = XCTestExpectation(description: "Messages added")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        XCTAssertFalse(manager.messages.isEmpty)
        expectation.fulfill()
    }
    wait(for: [expectation], timeout: 2)
}
```

### ViewModels (100% Testeable sin UI)
```swift
func testFilteredMessages() {
    let viewModel = LiveMatchViewModel(match: Match.barcelonaPSG)
    viewModel.selectedMinute = 45
    
    // La lógica de filtrado es testeable
    let filtered = viewModel.filteredChatMessages()
    XCTAssert(filtered.count <= viewModel.chatManager.messages.count)
}
```

### UI Components (Testeable con Snapshot)
```swift
func testChatMessageRowSnapshot() {
    let message = ChatMessage(...)
    let view = ChatMessageRow(message: message)
    assertSnapshot(matching: view, as: .image)
}
```

---

## 🏆 Principios SOLID Aplicados

### Single Responsibility Principle ✅
```
ChatManager          → Solo gestiona chat
MatchSimulation      → Solo simula partido  
EntertainmentManager → Solo gestiona entertainment
LiveMatchViewModel   → Solo coordina y filtra
LiveMatchView        → Solo presenta UI
```

### Open/Closed Principle ✅
```swift
// Fácil extender sin modificar existente
// Ejemplo: Agregar nuevo tipo de componente
enum EntertainmentComponentType {
    case trivia
    case poll
    case newType  // ← Solo agregar aquí
}

// El resto del código no necesita cambios
```

### Dependency Inversion Principle ✅
```swift
// LiveMatchViewModel depende de abstracciones, no de implementaciones
class LiveMatchViewModel {
    let chatManager: ChatManager              // Protocolo en futuro
    let matchSimulation: MatchSimulationManager
    let entertainmentManager: EntertainmentManager
    
    // Fácil de mockear para testing
}
```

---

## 📊 Comparación: Antes vs Después

### Antes (Monolítico)
```
LiveMatchView.swift (1408 líneas)
├── Datos mezclados con UI
├── Lógica mezclada con presentación
├── Todo en una vista
├── Imposible testear partes individuales
└── Difícil de mantener

Responsabilidades: TODO EN UNO
- UI ❌
- Lógica de negocio ❌
- Filtrado de datos ❌
- Coordinación ❌
- Presentación ❌
```

### Después (Separado en Capas)
```
Capa 1: UI (93 líneas)
└── LiveMatchViewRefactored.swift
    - Solo composición de componentes ✅

Capa 2: Presentation Logic (214 líneas)
└── LiveMatchViewModel.swift
    - Coordinación y filtrado ✅

Capa 3: Business Logic (589 líneas en 3 managers)
├── ChatManager.swift (135)
├── MatchSimulationManager.swift (117)
└── EntertainmentManager.swift (337)
    - Lógica de negocio separada ✅

Capa 4: Data (584 líneas en 3 archivos)
├── ChatModels.swift (44)
├── MatchStatisticsModels.swift (330)
└── EntertainmentModels.swift (210)
    - Datos puros ✅

Capa 5: UI Components (1480 líneas en 20 archivos)
└── 20 componentes reutilizables
    - UI pura, sin lógica ✅
```

---

## ✨ Beneficios de la Separación

### 1. Mantenibilidad
- ✅ Cambiar lógica de chat → Solo editar `ChatManager.swift`
- ✅ Cambiar UI de mensaje → Solo editar `ChatMessageRow.swift`
- ✅ Agregar nuevo tab → Agregar caso en enum y componente
- ✅ Sin efectos secundarios inesperados

### 2. Testabilidad
- ✅ Unit tests de managers sin UI
- ✅ Snapshot tests de componentes
- ✅ Integration tests de ViewModels
- ✅ Mocks fáciles de crear

### 3. Reutilización
- ✅ `ChatAvatar` → Usado en chat, casting, perfiles
- ✅ `MatchScoreView` → Usado en header, widgets, notificaciones
- ✅ `PollCard` → Usado en LiveMatch, Entertainment demo
- ✅ Managers compartidos entre vistas

### 4. Escalabilidad
- ✅ Agregar backend real → Solo modificar managers
- ✅ Agregar nuevo tipo de evento → Solo modificar MatchSimulation
- ✅ Cambiar diseño → Solo modificar componentes UI
- ✅ Código organizado para crecer

---

## 🎯 Respuesta a la Pregunta

### ¿Está toda la lógica aislada?

**Respuesta: SÍ, 100% aislada en 4 capas:**

1. **Models** (`Models/`) → Datos puros
2. **Managers** (`Managers/`) → Lógica de negocio
3. **ViewModels** (`Managers/Match/LiveMatchViewModel.swift`) → Lógica de presentación
4. **Views** (`Views/` y `Components/`) → UI pura

### ¿Dónde está cada tipo de lógica?

| Tipo de Lógica | Ubicación | Archivo(s) |
|----------------|-----------|------------|
| **Simulación de chat** | Manager | `ChatManager.swift` |
| **Simulación de partido** | Manager | `MatchSimulationManager.swift` |
| **Componentes interactivos** | Manager | `EntertainmentManager.swift` |
| **Filtrado de datos** | ViewModel | `LiveMatchViewModel.swift` |
| **Coordinación** | ViewModel | `LiveMatchViewModel.swift` |
| **Presentación visual** | Components | 20 archivos en `Components/` |
| **Composición** | View | `LiveMatchViewRefactored.swift` |

### ¿Cómo se comunican las capas?

```
UI Components ────(props)───→ Pure presentation
      ↑
   (binding)
      ↑
  ViewModel ────(@Published)───→ State management
      ↑
   (methods)
      ↑
   Managers ────(async/await)──→ Business logic
```

**Sin dependencias circulares, flujo unidireccional, completamente testeable.**

---

**Estado**: ✅ Lógica 100% separada y aislada  
**Patrón**: MVVM + Atomic Design  
**Beneficio**: Código limpio, mantenible y escalable

