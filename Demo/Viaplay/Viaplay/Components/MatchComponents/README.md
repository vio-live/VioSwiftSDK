# Match Components - Componentes Reutilizables de Partidos

Componentes modulares y reutilizables para mostrar información de partidos de fútbol.

## 📦 Componentes Disponibles

### 1. **LeagueTableView**
Tabla de clasificación de liga con estadísticas de equipos.

**Uso:**
```swift
LeagueTableView(leagueTable: LeagueTable.premierLeague)
```

**Características:**
- Muestra ranking, equipo, partidos jugados, victorias, empates, derrotas
- Diferencia de goles con colores (verde/rojo)
- Puntos totales
- Colores por posición (verde para top 3, púrpura para top 5)

### 2. **MatchStatsView**
Estadísticas comparativas del partido con gráficos de barras.

**Uso:**
```swift
MatchStatsView(statistics: MatchStatistics.mock(for: match))
```

**Características:**
- Comparación lado a lado de estadísticas
- Gráficos de barras visuales
- Soporte para porcentajes y valores absolutos
- Estadísticas: posesión, pases, tiros, corners, etc.

### 3. **MatchTimelineView**
Timeline de eventos del partido (goles, tarjetas, sustituciones).

**Uso:**
```swift
MatchTimelineView(
    timeline: MatchTimeline.mock(for: match),
    homeTeam: match.homeTeam,
    awayTeam: match.awayTeam
)
```

**Características:**
- Eventos ordenados cronológicamente
- Línea vertical central con minutos
- Eventos de equipo local a la izquierda, visitante a la derecha
- Soporte para: goles, tarjetas, sustituciones, kick-off

### 4. **MatchLineupView**
Alineaciones de ambos equipos con visualización en campo de fútbol.

**Uso:**
```swift
MatchLineupView(
    homeLineup: .mockHome(for: match),
    awayLineup: .mockAway(for: match)
)
```

**Características:**
- Campo de fútbol visual con líneas
- Jugadores posicionados en el campo
- Formación de cada equipo
- Lista de jugadores con números y posiciones
- Indicador de capitán

## 📊 Modelos de Datos

### LeagueTable
```swift
struct LeagueTable {
    let season: String
    let teams: [TeamStanding]
}
```

### MatchStatistics
```swift
struct MatchStatistics {
    let homeTeam: Team
    let awayTeam: Team
    let stats: [Statistic]
}
```

### MatchTimeline
```swift
struct MatchTimeline {
    let events: [MatchEvent]
}
```

### TeamLineup
```swift
struct TeamLineup {
    let team: Team
    let formation: String
    let players: [Player]
    let substitutes: [Player]
    let coach: String?
}
```

## 🎨 Personalización

Todos los componentes usan:
- Color de fondo: `Color(hex: "1B1B25")`
- Texto blanco con opacidades variables
- Diseño dark mode optimizado

## 📝 Ejemplo de Integración Completa

```swift
struct MatchDetailView: View {
    let match: Match
    @State private var selectedTab: MatchTab = .timeline
    
    var body: some View {
        VStack {
            // Navigation tabs
            navigationTabs
            
            // Content based on selected tab
            Group {
                switch selectedTab {
                case .timeline:
                    MatchTimelineView(
                        timeline: .mock(for: match),
                        homeTeam: match.homeTeam,
                        awayTeam: match.awayTeam
                    )
                case .stats:
                    MatchStatsView(statistics: .mock(for: match))
                case .lineup:
                    MatchLineupView(
                        homeLineup: .mockHome(for: match),
                        awayLineup: .mockAway(for: match)
                    )
                case .table:
                    LeagueTableView(leagueTable: .premierLeague)
                }
            }
        }
    }
}
```

## ✅ Características

- ✅ Componentes modulares y reutilizables
- ✅ Diseño consistente con tema oscuro
- ✅ Datos mock incluidos para testing
- ✅ Fácil de integrar en cualquier vista
- ✅ Responsive y adaptable
- ✅ Sin dependencias externas

## 🔄 Integración en LiveMatchView

Estos componentes están integrados en `LiveMatchView` y se pueden cambiar usando las pestañas de navegación:
- **Timeline**: Eventos del partido
- **Stats**: Estadísticas comparativas
- **Lineup**: Alineaciones en campo
- **Table**: Tabla de clasificación


