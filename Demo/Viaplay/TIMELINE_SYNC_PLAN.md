# Timeline Synchronization - Plan de Implementación

## 🎯 Objetivo

Sincronizar todos los eventos (chat, goles, polls, etc.) con el timeline del video para que al navegar por el scrubber solo se muestren los eventos que han ocurrido hasta ese momento.

---

## 📊 Sistema Actual vs Propuesto

### ❌ Sistema Actual (Limitado)

```swift
// Chat messages no tienen timestamp real del video
ChatMessage(
    username: "User",
    text: "Gol!",
    timestamp: Date()  // ← Timestamp de sistema, no del video
)

// Filtrado estimado (no preciso)
let estimatedMinute = (messageIndex * currentFilterMinute) / max(count, 1)
```

**Problemas**:
- Chat messages usan timestamp de sistema (Date())
- Estimación basada en índice del mensaje (impreciso)
- No sincronizado con eventos reales del video
- Al retroceder en el timeline, todos los mensajes aparecen

### ✅ Sistema Propuesto (Sincronizado)

```swift
// Todos los eventos tienen videoTimestamp
protocol TimelineEvent {
    var id: String { get }
    var videoTimestamp: TimeInterval { get }  // Segundos desde inicio del video
    var type: TimelineEventType { get }
}

// Chat message con timestamp del video
ChatMessage(
    username: "User",
    text: "Gol!",
    videoTimestamp: 780.0,  // 13 minutos (13 * 60)
    timestamp: Date()
)

// Filtrado preciso
let visibleEvents = allEvents.filter { 
    $0.videoTimestamp <= currentVideoTime 
}
```

**Beneficios**:
- Sincronización perfecta con video
- Al retroceder, solo aparecen eventos hasta ese momento
- Fácil agregar nuevos tipos de eventos
- Timeline único para todo (chat, goles, polls, etc.)

---

## 🏗️ Arquitectura Propuesta

### 1. Crear TimelineEvent Protocol

```swift
// Models/Timeline/TimelineModels.swift

protocol TimelineEvent: Identifiable {
    var id: String { get }
    var videoTimestamp: TimeInterval { get }  // Segundos desde inicio
    var displayMinute: Int { get }             // Minuto para UI
    var type: TimelineEventType { get }
}

enum TimelineEventType {
    case matchEvent    // Gol, tarjeta, etc.
    case chatMessage   // Mensaje de chat
    case poll          // Poll/encuesta
    case product       // Producto mostrado
    case highlight     // Highlight disponible
    case statistics    // Update de estadísticas
}
```

### 2. Actualizar ChatMessage

```swift
// Models/Chat/ChatModels.swift

struct ChatMessage: Identifiable, TimelineEvent {
    let id = UUID()
    let username: String
    let text: String
    let usernameColor: Color
    let likes: Int
    let timestamp: Date              // Sistema (cuando se creó)
    let videoTimestamp: TimeInterval // Video (cuando apareció en el video)
    
    var displayMinute: Int {
        Int(videoTimestamp / 60)
    }
    
    var type: TimelineEventType {
        .chatMessage
    }
}
```

### 3. Actualizar MatchEvent

```swift
// Models/Match/MatchModels.swift

struct MatchEvent: Identifiable, TimelineEvent {
    let id = UUID()
    let minute: Int
    let type: EventType
    let player: String?
    let team: TeamSide
    let description: String?
    let score: String?
    
    var videoTimestamp: TimeInterval {
        TimeInterval(minute * 60)
    }
    
    var displayMinute: Int { minute }
    
    var timelineType: TimelineEventType {
        .matchEvent
    }
}
```

### 4. Crear UnifiedTimeline Manager

```swift
// Managers/Timeline/UnifiedTimelineManager.swift

@MainActor
class UnifiedTimelineManager: ObservableObject {
    @Published var currentVideoTime: TimeInterval = 0  // Segundos
    @Published var allEvents: [any TimelineEvent] = []
    
    var currentMinute: Int {
        Int(currentVideoTime / 60)
    }
    
    // Eventos visibles hasta el tiempo actual
    var visibleEvents: [any TimelineEvent] {
        allEvents.filter { $0.videoTimestamp <= currentVideoTime }
            .sorted { $0.videoTimestamp < $1.videoTimestamp }
    }
    
    // Filtrar por tipo
    func visibleEvents(ofType type: TimelineEventType) -> [any TimelineEvent] {
        visibleEvents.filter { $0.type == type }
    }
    
    // Agregar evento con timestamp
    func addEvent<T: TimelineEvent>(_ event: T) {
        allEvents.append(event)
    }
    
    // Actualizar tiempo del video
    func updateVideoTime(_ seconds: TimeInterval) {
        currentVideoTime = seconds
    }
    
    // Saltar a un minuto específico
    func jumpToMinute(_ minute: Int) {
        currentVideoTime = TimeInterval(minute * 60)
    }
}
```

### 5. Actualizar ChatManager para usar timestamps de video

```swift
// Managers/Chat/ChatManager.swift

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    
    private let timeline: UnifiedTimelineManager
    
    init(timeline: UnifiedTimelineManager) {
        self.timeline = timeline
    }
    
    private func addSimulatedMessage() {
        let user = simulatedUsers.randomElement()!
        let messageText = simulatedMessages.randomElement()!
        
        // Crear mensaje con timestamp del video actual
        let message = ChatMessage(
            username: user.0,
            text: messageText,
            usernameColor: user.1,
            likes: Int.random(in: 0...12),
            timestamp: Date(),
            videoTimestamp: timeline.currentVideoTime  // ← Timestamp del video
        )
        
        messages.append(message)
        timeline.addEvent(message)  // Agregar al timeline unificado
    }
}
```

### 6. Actualizar LiveMatchViewModel

```swift
// Managers/Match/LiveMatchViewModel.swift

@MainActor
class LiveMatchViewModel: ObservableObject {
    @Published var selectedTab: MatchTab = .all
    
    // Timeline unificado
    let timeline: UnifiedTimelineManager
    
    // Managers ahora usan el timeline
    let chatManager: ChatManager
    let matchSimulation: MatchSimulationManager
    
    init(match: Match) {
        // Crear timeline primero
        self.timeline = UnifiedTimelineManager()
        
        // Pasar timeline a managers
        self.chatManager = ChatManager(timeline: timeline)
        self.matchSimulation = MatchSimulationManager(timeline: timeline)
        //...
    }
    
    // Computed properties basadas en timeline
    var visibleChatMessages: [ChatMessage] {
        timeline.visibleEvents(ofType: .chatMessage)
            .compactMap { $0 as? ChatMessage }
    }
    
    var visibleMatchEvents: [MatchEvent] {
        timeline.visibleEvents(ofType: .matchEvent)
            .compactMap { $0 as? MatchEvent }
    }
    
    // Cuando el usuario mueve el scrubber
    func jumpToMinute(_ minute: Int) {
        timeline.jumpToMinute(minute)
        // Los @Published del timeline actualizarán automáticamente la UI
    }
}
```

### 7. Actualizar VideoTimelineControl

```swift
// Components/Match/VideoTimelineControl.swift

struct VideoTimelineControl: View {
    @ObservedObject var timeline: UnifiedTimelineManager
    let events: [MatchEvent]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ... scrubber UI
                
                Circle()
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let percentage = value.location.x / geometry.size.width
                                let seconds = percentage * 90 * 60  // 90 minutos
                                timeline.updateVideoTime(seconds)
                            }
                    )
            }
        }
    }
}
```

---

## 🔄 Flujo de Sincronización

### Escenario 1: Video avanza (modo LIVE)

```
Segundo 0 (Minuto 0)
├─ Video inicia
├─ currentVideoTime = 0
└─ visibleEvents = [KickOff]

Segundo 780 (Minuto 13)
├─ Video avanza
├─ currentVideoTime = 780
├─ MatchSimulation genera: Gol de A. Diallo (timestamp: 780)
├─ ChatManager genera: "Qué gol!" (timestamp: 782)
└─ visibleEvents = [KickOff, Gol, Chat1, Chat2, ...]

UI se actualiza automáticamente
└─ Solo muestra eventos hasta segundo 780
```

### Escenario 2: Usuario retrocede en timeline

```
Usuario arrastra scrubber a minuto 5

Acción:
├─ timeline.jumpToMinute(5)
├─ currentVideoTime = 300  (5 * 60)
└─ visibleEvents se filtra

Resultado:
├─ Solo aparece KickOff (minuto 0)
├─ Gol de minuto 13 NO aparece
├─ Mensajes de chat después del minuto 5 NO aparecen
└─ UI muestra estado del partido en minuto 5
```

### Escenario 3: Usuario avanza rápido (scrubber)

```
Usuario arrastra scrubber a minuto 45

Acción:
├─ timeline.jumpToMinute(45)
├─ currentVideoTime = 2700
└─ visibleEvents incluye todos hasta minuto 45

Resultado:
├─ Aparecen goles de minuto 13, 32
├─ Aparecen todos los chats hasta minuto 45
├─ Aparecen polls que empezaron antes de minuto 45
└─ Half Time visible
```

---

## 🎨 Visualización en UI

### Timeline Scrubber con Todos los Eventos

```
0'                                                          90'
├────────────────────────────────────────────────────────────┤
│  ⚽    💬💬  🟨    💬  ⚽     💬💬💬  📊    🔴  ⏸  💬    ⚽   │
│  13'  15'   18'   22' 32'   35'     45' 58' 65'  72' 85'  │
└────────────────────────────────────────────────────────────┘
     ↑                                    ↑
    Gol                                 Half Time

Leyenda:
⚽ = Gol (verde)
💬 = Chat message (cyan)
📊 = Poll (naranja)
🟨 = Yellow card (amarillo)
🔴 = Red card (rojo)
⏸ = Half time (blanco)
```

### Feed según Timeline

**Timeline en minuto 30**:
```
All Feed muestra:
├─ 32' Gol B. Mbeumo  ← NO VISIBLE (futuro)
├─ 25' Yellow Card    ← VISIBLE
├─ 22' Chat: "Increíble!" ← VISIBLE
├─ 18' Yellow Card    ← VISIBLE
├─ 15' Chat: "Vamos!" ← VISIBLE
├─ 13' Gol A. Diallo  ← VISIBLE
└─ 0'  Kick-off       ← VISIBLE
```

**Usuario retrocede a minuto 15**:
```
All Feed muestra:
├─ 25' Yellow Card    ← NO VISIBLE (futuro)
├─ 15' Chat: "Vamos!" ← VISIBLE (justo en el límite)
├─ 13' Gol A. Diallo  ← VISIBLE
└─ 0'  Kick-off       ← VISIBLE
```

---

## 📋 Implementación por Pasos

### Paso 1: Crear Protocol y Modelos Base
1. Crear `TimelineModels.swift` con protocol `TimelineEvent`
2. Actualizar `ChatMessage` para implementar protocol
3. Actualizar `MatchEvent` para implementar protocol
4. Agregar `videoTimestamp` a todos los eventos

### Paso 2: Crear UnifiedTimelineManager
1. Crear `UnifiedTimelineManager.swift`
2. Implementar array de eventos unificado
3. Implementar filtrado por tiempo
4. Implementar actualización de tiempo

### Paso 3: Actualizar Managers Existentes
1. Actualizar `ChatManager` para usar timeline
2. Actualizar `MatchSimulationManager` para usar timeline
3. Actualizar `EntertainmentManager` para usar timeline
4. Asegurar que todos los eventos tienen videoTimestamp

### Paso 4: Actualizar LiveMatchViewModel
1. Integrar `UnifiedTimelineManager`
2. Reemplazar `filteredXXX()` con `timeline.visibleEvents()`
3. Actualizar `mixedContentItems()` para usar timeline
4. Conectar con scrubber

### Paso 5: Actualizar UI Components
1. `VideoTimelineControl` → Actualizar timeline en tiempo real
2. `AllContentFeed` → Usar eventos visibles del timeline
3. `ChatListView` → Filtrar por timeline
4. Agregar markers visuales en scrubber

### Paso 6: Testing
1. Verificar sincronización perfecta
2. Probar retroceder/avanzar en timeline
3. Verificar que eventos aparecen/desaparecen correctamente

---

## 🎬 Ejemplo de Datos Sincronizados

### Timeline del Partido Barcelona - PSG

```swift
// Todos los eventos en orden cronológico con videoTimestamp

Timeline:
├─ 0s (0')    - KickOff
├─ 45s (0'45) - Chat: "Arranca el partido! 🔥"
├─ 120s (2')  - Chat: "Vamos Barcelona!"
├─ 300s (5')  - Substitution: Scott por Adams
├─ 320s (5'20)- Chat: "Buen cambio"
├─ 780s (13') - GOL A. Diallo ⚽
├─ 785s (13'05)- Chat: "GOOOOOL!!!"
├─ 787s (13'07)- Chat: "Qué jugada!"
├─ 790s (13'10)- Chat: "Increíble!"
├─ 900s (15') - Poll: "¿Quién ganará?" 📊
├─ 1080s(18') - Yellow Card: Casemiro 🟨
├─ 1500s(25') - Yellow Card: Tavernier 🟨
├─ 1920s(32') - GOL B. Mbeumo ⚽
├─ 2700s(45') - Half Time ⏸
└─ ... hasta 5400s (90')
```

### Usuario en minuto 13 (780s)

**Visible en feed**:
- ✅ 13' - GOL A. Diallo
- ✅ 5' - Substitution
- ✅ 5'20 - Chat: "Buen cambio"
- ✅ 2' - Chat: "Vamos Barcelona!"
- ✅ 0' - KickOff

**NO visible (futuro)**:
- ❌ 13'05 - Chat: "GOOOOOL!!!" (aún no ocurre)
- ❌ 15' - Poll (no ha empezado)
- ❌ 18' - Yellow Card (futuro)

---

## 💻 Código de Implementación

### ChatManager con Timestamps de Video

```swift
@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    
    private weak var timeline: UnifiedTimelineManager?
    
    init(timeline: UnifiedTimelineManager) {
        self.timeline = timeline
    }
    
    func addSimulatedMessage() {
        guard let timeline = timeline else { return }
        
        let user = simulatedUsers.randomElement()!
        let text = simulatedMessages.randomElement()!
        
        // Crear mensaje con timestamp del video ACTUAL
        let message = ChatMessage(
            username: user.0,
            text: text,
            usernameColor: user.1,
            likes: Int.random(in: 0...12),
            timestamp: Date(),
            videoTimestamp: timeline.currentVideoTime
        )
        
        messages.append(message)
        timeline.addEvent(message)
        
        if messages.count > maxMessages {
            messages.removeFirst()
        }
    }
    
    // Pre-generar mensajes para diferentes minutos
    func preGenerateMessages() {
        // Mensajes en minuto 0-1
        addMessage(at: 45, text: "Arranca el partido! 🔥", user: "SportsFan23")
        
        // Mensajes después de gol en minuto 13
        addMessage(at: 785, text: "GOOOOOL!!!", user: "MatchMaster")
        addMessage(at: 787, text: "Qué jugada!", user: "TeamCaptain")
        
        // Mensajes variados durante el partido
        addMessage(at: 1200, text: "Gran partido", user: "CoachView")
        // ... más mensajes pre-generados
    }
    
    private func addMessage(at videoTime: TimeInterval, text: String, user: String) {
        let userInfo = simulatedUsers.first { $0.0 == user }!
        let message = ChatMessage(
            username: userInfo.0,
            text: text,
            usernameColor: userInfo.1,
            likes: Int.random(in: 0...12),
            timestamp: Date(),
            videoTimestamp: videoTime
        )
        messages.append(message)
        timeline?.addEvent(message)
    }
}
```

### LiveMatchViewModel con Timeline Unificado

```swift
@MainActor
class LiveMatchViewModel: ObservableObject {
    @Published var selectedTab: MatchTab = .all
    
    // Timeline unificado
    let timeline: UnifiedTimelineManager
    
    // Managers
    let chatManager: ChatManager
    let matchSimulation: MatchSimulationManager
    
    init(match: Match) {
        self.match = match
        
        // Crear timeline
        self.timeline = UnifiedTimelineManager()
        
        // Inicializar managers con timeline
        self.chatManager = ChatManager(timeline: timeline)
        self.matchSimulation = MatchSimulationManager(timeline: timeline)
        
        // Pre-generar eventos
        preGenerateTimeline()
    }
    
    func preGenerateTimeline() {
        // Pre-cargar mensajes de chat en momentos específicos
        chatManager.preGenerateMessages()
        
        // Los eventos del partido se generan automáticamente
        // en MatchSimulationManager
    }
    
    // Eventos visibles según timeline
    var visibleChatMessages: [ChatMessage] {
        timeline.visibleEvents(ofType: .chatMessage)
            .compactMap { $0 as? ChatMessage }
    }
    
    var visibleMatchEvents: [MatchEvent] {
        timeline.visibleEvents(ofType: .matchEvent)
            .compactMap { $0 as? MatchEvent }
    }
    
    var visiblePolls: [InteractiveComponent] {
        timeline.visibleEvents(ofType: .poll)
            .compactMap { $0 as? InteractiveComponent }
    }
}
```

---

## 🎯 Beneficios de la Sincronización

### 1. Experiencia Realista
- Usuario puede "revivir" el partido
- Chat aparece en el momento exacto que ocurrieron
- Spoilers automáticamente ocultos (al retroceder)

### 2. Replay Perfecto
- Ver qué decía el chat cuando hubo un gol
- Revisar reacciones a eventos específicos
- Timeline completo del partido

### 3. Fácil de Extender
- Agregar productos en momentos específicos
- Polls que aparecen en minutos exactos
- Highlights sincronizados

---

## 📊 Comparación

### Antes (Estimado)
```
Minuto 45 seleccionado
├─ Chat: Muestra TODOS los mensajes (estimación imprecisa)
├─ Eventos: Solo hasta minuto 45 ✅
└─ Inconsistencia entre chat y eventos
```

### Después (Sincronizado)
```
Minuto 45 seleccionado (2700 segundos)
├─ Chat: Solo mensajes con videoTimestamp <= 2700 ✅
├─ Eventos: Solo eventos con videoTimestamp <= 2700 ✅
├─ Polls: Solo polls que empezaron <= 2700 ✅
└─ TODO sincronizado perfectamente
```

---

## ⏱️ Estimación de Tiempo

### Implementación
- **Paso 1**: Crear protocol y modelos (1 hora)
- **Paso 2**: UnifiedTimelineManager (2 horas)
- **Paso 3**: Actualizar managers (2 horas)
- **Paso 4**: Actualizar ViewModel (1 hora)
- **Paso 5**: Actualizar UI (1 hora)
- **Paso 6**: Testing (2 horas)

**Total**: 9 horas

---

## 🚀 Siguiente Acción

¿Quieres que implemente este sistema de timeline sincronizado?

1. Empezaría por crear el protocol `TimelineEvent`
2. Luego el `UnifiedTimelineManager`
3. Actualizar los managers existentes
4. Finalmente conectar con la UI

El resultado será un timeline perfectamente sincronizado donde TODOS los eventos (chat, goles, polls, etc.) aparecen en el momento exacto del video.
