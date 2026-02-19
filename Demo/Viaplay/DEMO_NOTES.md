# Demo Notes - Timeline Behavior

## ⚠️ IMPORTANT: Demo-Only Behavior

### Timeline Event Display (DEMO ONLY)

**Current Implementation (For Demo)**:
```swift
// Events appear based on SLIDER position, not video time
timeline.currentVideoTime = sliderPosition
// Result: Scrub to min 50 → All events up to min 50 appear instantly
```

**Production Implementation (Real Live Broadcasts)**:
```swift
// Events should only appear as they happen in real-time
timeline.currentVideoTime = liveVideoTime
// Result: Events appear ONLY when they actually occur
// User cannot "see the future" by scrubbing forward
```

### Why Demo is Different

**Demo (Current)**:
- ✅ User can scrub to ANY point and see all events
- ✅ Perfect for testing and showcasing features
- ✅ Lets you explore full 120 minutes instantly
- ❌ Not realistic for live broadcasts (spoilers!)

**Production (Future)**:
- ✅ Events reveal progressively as match happens
- ✅ No spoilers - can't see future events
- ✅ Realistic live broadcast experience
- ✅ User can only scrub BACK to review past moments

### Implementation Change for Production

```swift
// In jumpToMinute():
func jumpToMinute(_ minute: Int) {
    selectedMinute = minute
    
    // Only allow scrubbing BACK (not forward past live)
    let newTime = TimeInterval(minute * 60)
    if newTime <= timeline.liveVideoTime {
        timeline.currentVideoTime = newTime  // Can review past
    } else {
        timeline.currentVideoTime = timeline.liveVideoTime  // Can't see future
    }
    
    objectWillChange.send()
}
```

### Current Settings

- **Demo Mode**: Events based on slider (instant reveal)
- **Live Mode**: Will use progressive reveal when implemented

---

**For now, demo behavior is INTENTIONAL for testing and presentation.**
