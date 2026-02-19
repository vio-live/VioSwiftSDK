# Video Synchronization API Specification

This document specifies the API changes required for video synchronization of polls and contests in the Reachu SDK.

## Overview

The SDK now supports synchronizing polls and contests with video playback time using relative timestamps (seconds relative to broadcast start) instead of only absolute timestamps. This allows engagement events to appear/disappear based on the video playback position, supporting both live and recorded videos.

## Base URL

All endpoints use the campaign REST API base URL configured in `campaignConfiguration.restAPIBaseURL`.

Example: `https://dev-campaing.reachu.io`

## Authentication

All endpoints require authentication via `apiKey` query parameter (SDK API key).

---

## Endpoint 1: Get Polls

**GET** `/v1/engagement/polls`

Fetches polls for a specific broadcast, now including video synchronization timestamps.

### Query Parameters

- `apiKey` (required): SDK API key
- `broadcastId` (required): Broadcast identifier (also accepts `matchId` for backward compatibility)

### Response

**Status:** `200 OK`

**Headers:**
```
Content-Type: application/json
Cache-Control: public, max-age=300
```

**Body:**
```json
{
  "polls": [
    {
      "id": "poll-123",
      "broadcastId": "barcelona-psg-2025-01-23",
      "broadcastId": "barcelona-psg-2025-01-23",
  "matchId": "barcelona-psg-2025-01-23", // Backward compatibility
      "question": "Liker du Barcelona sitt startoppstilling?",
      "options": [
        {
          "id": "yes",
          "text": "Ja, bra 11!",
          "voteCount": 0,
          "percentage": 0.0
        },
        {
          "id": "no",
          "text": "Nei, ikke bra",
          "voteCount": 0,
          "percentage": 0.0
        }
      ],
      
      // Absolute timestamps (backward compatibility)
      "startTime": "2025-01-23T19:48:30Z",
      "endTime": "2025-01-23T20:00:00Z",
      
      // NEW: Video synchronization timestamps (relative to broadcast start)
      "videoStartTime": -690,  // 11:30 before broadcast start (in seconds)
      "videoEndTime": 0,        // At broadcast start
      "broadcastStartTime": "2025-01-23T20:00:00Z",  // Absolute timestamp of broadcast start
      
      "isActive": true,
      "totalVotes": 0
    }
  ],
  "broadcastStartTime": "2025-01-23T20:00:00Z"  // Broadcast start time at root level (optional)
}
```

### Field Details

#### Video Synchronization Fields

- `videoStartTime` (Integer, optional): Time in seconds relative to broadcast start when poll should appear. Negative values indicate before broadcast start (e.g., -690 = 11:30 before start).
- `videoEndTime` (Integer, optional): Time in seconds relative to broadcast start when poll should disappear. Zero (0) indicates at broadcast start.
- `broadcastStartTime` (ISO 8601 timestamp, optional): Absolute timestamp of broadcast start time. Can be provided at poll level or root level.

#### Backward Compatibility

- `startTime` and `endTime` (absolute timestamps) are maintained for backward compatibility
- If `videoStartTime`/`videoEndTime` are not provided, SDK will fallback to using `endTime` for filtering

### Examples

#### Example 1: Poll Before Broadcast Start

```json
{
  "id": "poll-pre-match",
  "videoStartTime": -690,  // 11:30 before broadcast start
  "videoEndTime": 0,       // At broadcast start
  "broadcastStartTime": "2025-01-23T20:00:00Z"
}
```

**Behavior:** Poll appears 11:30 before broadcast start and disappears at broadcast start.

#### Example 2: Poll During Broadcast

```json
{
  "id": "poll-during-broadcast",
  "videoStartTime": 300,   // 5 minutes after broadcast start
  "videoEndTime": 600,     // 10 minutes after broadcast start
  "broadcastStartTime": "2025-01-23T20:00:00Z"
}
```

**Behavior:** Poll appears at minute 5 and disappears at minute 10 of the broadcast.

---

## Endpoint 2: Get Contests

**GET** `/v1/engagement/contests`

Fetches contests for a specific broadcast, now including video synchronization timestamps.

### Query Parameters

- `apiKey` (required): SDK API key
- `broadcastId` (required): Broadcast identifier (also accepts `matchId` for backward compatibility)

### Response

**Status:** `200 OK`

**Body:**
```json
{
  "contests": [
    {
      "id": "contest-123",
      "broadcastId": "barcelona-psg-2025-01-23",
      "broadcastId": "barcelona-psg-2025-01-23",
  "matchId": "barcelona-psg-2025-01-23", // Backward compatibility
      "title": "Win a Gift Card",
      "description": "Participate and win a 500 NOK gift card",
      "prize": "500 NOK Gift Card",
      "contestType": "giveaway",
      
      // Absolute timestamps (backward compatibility)
      "startTime": "2025-01-23T19:48:30Z",
      "endTime": "2025-01-23T20:00:00Z",
      
      // NEW: Video synchronization timestamps
      "videoStartTime": -690,
      "videoEndTime": 0,
      "broadcastStartTime": "2025-01-23T20:00:00Z",
      
      "isActive": true
    }
  ],
  "broadcastStartTime": "2025-01-23T20:00:00Z"
}
```

### Field Details

Same video synchronization fields as polls:
- `videoStartTime` (Integer, optional)
- `videoEndTime` (Integer, optional)
- `broadcastStartTime` (ISO 8601 timestamp, optional)

---

## Endpoint 3: Get Engagement Config

**GET** `/v1/engagement/config`

Fetches engagement configuration for a specific broadcast, now including broadcast start time.

### Query Parameters

- `apiKey` (required): SDK API key
- `broadcastId` (required): Broadcast identifier (also accepts `matchId` for backward compatibility)

### Response

**Status:** `200 OK`

**Body:**
```json
{
  "broadcastId": "barcelona-psg-2025-01-23",
  "matchId": "barcelona-psg-2025-01-23", // Backward compatibility
  "broadcastStartTime": "2025-01-23T20:00:00Z",
  "engagement": {
    "demoMode": false,
    "defaultPollDuration": 300,
    "defaultContestDuration": 600,
    "maxVotesPerPoll": 1,
    "maxContestsPerBroadcast": 10,
    "enableRealTimeUpdates": true,
    "updateInterval": 1000
  },
  "cache": {
    "ttl": 300
  }
}
```

### Field Details

- `broadcastStartTime` (ISO 8601 timestamp, optional): Absolute timestamp of broadcast start time. Used by SDK to calculate when polls/contests should appear based on video time.

---

## Database Schema Changes

### Table: `polls`

Add new columns for video synchronization:

```sql
ALTER TABLE polls ADD COLUMN video_start_time INTEGER;
ALTER TABLE polls ADD COLUMN video_end_time INTEGER;
ALTER TABLE polls ADD COLUMN match_start_time TIMESTAMP;
```

**Column Descriptions:**
- `video_start_time`: Time in seconds relative to broadcast start when poll should appear
- `video_end_time`: Time in seconds relative to broadcast start when poll should disappear
- `match_start_time`: Absolute timestamp of broadcast start (can be denormalized from matches table)

### Table: `contests`

Add same columns:

```sql
ALTER TABLE contests ADD COLUMN video_start_time INTEGER;
ALTER TABLE contests ADD COLUMN video_end_time INTEGER;
ALTER TABLE contests ADD COLUMN match_start_time TIMESTAMP;
```

### Table: `matches`

Ensure broadcast start time is available:

```sql
CREATE TABLE IF NOT EXISTS matches (
    id VARCHAR(255) PRIMARY KEY,
    match_start_time TIMESTAMP NOT NULL,
    -- other fields...
);
```

---

## Calculation Logic

### How to Calculate `videoStartTime` and `videoEndTime`

1. **Determine broadcast start time:** Get the absolute timestamp when the broadcast starts
2. **Calculate relative times:**
   - `videoStartTime = (pollStartTime - broadcastStartTime) in seconds`
   - `videoEndTime = (pollEndTime - broadcastStartTime) in seconds`

### Example Calculation

**Broadcast starts:** `2025-01-23T20:00:00Z`
**Poll should appear:** `2025-01-23T19:48:30Z` (11:30 before)
**Poll should disappear:** `2025-01-23T20:00:00Z` (at broadcast start)

**Calculation:**
- `videoStartTime = (19:48:30 - 20:00:00) = -690 seconds`
- `videoEndTime = (20:00:00 - 20:00:00) = 0 seconds`

---

## Migration Guide

### For Existing Data

1. **Calculate video timestamps:**
   - Use existing `startTime` and `endTime` fields
   - Get `broadcastStartTime` from matches table
   - Calculate `videoStartTime` and `videoEndTime` as described above

2. **Update database:**
   ```sql
   UPDATE polls 
   SET video_start_time = EXTRACT(EPOCH FROM (start_time - match_start_time))::INTEGER,
       video_end_time = EXTRACT(EPOCH FROM (end_time - match_start_time))::INTEGER,
       match_start_time = match_start_time
   FROM matches
   WHERE polls.match_id = matches.id;
   ```

3. **Backfill match_start_time:**
   ```sql
   UPDATE polls p
   SET match_start_time = m.match_start_time
   FROM matches m
   WHERE p.match_id = m.id;
   ```

---

## SDK Behavior

### Video Time Synchronization

1. **SDK receives polls/contests** with `videoStartTime`, `videoEndTime`, and `broadcastStartTime`
2. **App provides current video time** (from video player/casting) via `VideoSyncManager.updateVideoTime()`
3. **SDK filters polls/contests** based on:
   - If `videoStartTime` and `videoEndTime` are available: use video time
   - If not: fallback to absolute `endTime` (backward compatibility)

### Filtering Logic

A poll/contest is active if:
- `currentVideoTime >= videoStartTime` AND `currentVideoTime < videoEndTime`
- OR (if video sync not available): `currentTime < endTime` (absolute timestamp)

---

## Error Responses

**400 Bad Request**
```json
{
  "error": "Missing required parameter: broadcastId (or matchId for backward compatibility)",
  "code": "MISSING_PARAMETER"
}
```

**404 Not Found**
```json
{
  "error": "Polls not found for broadcastId",
  "code": "NOT_FOUND"
}
```

---

## Notes

- All new fields (`videoStartTime`, `videoEndTime`, `broadcastStartTime`) are optional for backward compatibility
- If `broadcastStartTime` is provided at root level, it applies to all polls/contests in the response
- Individual polls/contests can override `broadcastStartTime` if needed
- Negative `videoStartTime` values indicate events before broadcast start (pre-match polls)
- Zero `videoEndTime` indicates events that end exactly at broadcast start
