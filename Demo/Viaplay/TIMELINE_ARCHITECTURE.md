# Timeline Architecture - Extensible for Any Match

## 🎯 Current Implementation

The timeline system is **fully extensible** and works with any match data.

### How It Works

**Match Data** (`MatchModels.swift`):
```swift
struct Match {
    let homeTeam: Team
    let awayTeam: Team
    let competition: String
    let venue: String
    // ...
}

struct Team {
    let name: String        // "FC Barcelona", "Paris Saint-Germain"
    let shortName: String  // "Barcelona", "PSG"
    let logo: String
}
```

**Components Use Match Data**:
- `MatchHeaderView(match: match, ...)` → Uses `match.homeTeam.name`, `match.awayTeam.name`
- `TeamLogoView(team: match.homeTeam)` → Displays team name and logo
- Automatically adapts to any match

### Current Demo: Barcelona vs PSG

```swift
Match.barcelonaPSG = Match(
    homeTeam: Team(name: "FC Barcelona", shortName: "Barcelona", ...),
    awayTeam: Team(name: "Paris Saint-Germain", shortName: "PSG", ...),
    competition: "UEFA Champions League",
    venue: "Camp Nou"
)
```

### For Other Matches

Simply create a new Match instance:

```swift
Match.realMadridManCity = Match(
    homeTeam: Team(name: "Real Madrid", shortName: "Madrid", logo: "..."),
    awayTeam: Team(name: "Manchester City", shortName: "City", logo: "..."),
    competition: "UEFA Champions League",
    venue: "Santiago Bernabéu"
)
```

Components automatically use the new match data!

## 🔄 Timeline System Features

### Dual Timeline (Live + User Position)
- **liveVideoTime**: Real broadcast time (always advancing)
- **currentVideoTime**: User's position (can be behind for replay)
- **isLive**: Boolean indicator

### Progressive Reveal
- Event markers only show up to live position
- No spoilers for future events
- Perfect for live broadcasts

### Event Types Supported
- Match events (goals, cards, subs)
- Commentary (play-by-play)
- Chat messages
- Tweets from players
- Polls
- Contests
- Highlights with video
- Statistics updates
- Admin comments

All events are **match-agnostic** and can be generated for any match!

## 📝 Adding a New Match

1. Create Match data:
```swift
let newMatch = Match(
    homeTeam: yourHomeTeam,
    awayTeam: yourAwayTeam,
    ...
)
```

2. Generate timeline (optional - can come from backend):
```swift
TimelineDataGenerator.generate[MatchName]Timeline()
```

3. Pass to view:
```swift
LiveMatchViewRefactored(match: newMatch) { }
```

Done! All components adapt automatically.

## 🔌 Backend Integration (Future)

When connecting to backend:

```swift
// Fetch match data
let match = try await api.getMatch(id: broadcastId)

// Fetch timeline events
let events = try await api.getTimelineEvents(broadcastId: broadcastId)
timeline.addWrappedEvents(events)

// WebSocket for live updates
ws.onEvent { event in
    timeline.addEvent(event)
}
```

No code changes needed in UI components!

---

**Current Status**: Demo uses Barcelona vs PSG, but system is **100% ready for any match**.
