# Backend API Specification - Dynamic Configuration

This document specifies the API endpoints required for dynamic configuration management in the Reachu SDK.

## Base URL

All endpoints use the campaign REST API base URL configured in `campaignConfiguration.restAPIBaseURL`.

Example: `https://dev-campaing.reachu.io`

## Authentication

All endpoints require authentication via `apiKey` query parameter (SDK API key, same as used for other SDK endpoints).

**Note:** This is different from `/v1/sdk/config` which uses `campaignAdminApiKey`. The new endpoints use the standard SDK `apiKey` for consistency with other SDK endpoints.

## Relationship to Existing Endpoints

### `/v1/sdk/config` (Existing)
- **Purpose:** General SDK configuration (not campaign-specific)
- **Auth:** Uses `campaignAdminApiKey` (different from SDK API key)
- **Returns:** Basic component and offer configuration
- **Status:** Maintained for backward compatibility

### `/v1/campaigns/{campaignId}/config` (New)
- **Purpose:** Complete dynamic campaign configuration
- **Auth:** Uses SDK `apiKey` (same as other SDK endpoints)
- **Returns:** Brand, engagement, UI, features specific to campaign
- **Status:** New endpoint for dynamic configuration

**Recommendation:** Both endpoints coexist. The new endpoint provides more comprehensive and campaign-specific configuration.

---

## Endpoint 1: Campaign Configuration

**GET** `/v1/campaigns/{campaignId}/config`

Fetches complete campaign configuration including brand, engagement, UI, and feature flags.

### Path Parameters

- `campaignId` (required): Campaign ID (integer)

### Query Parameters

- `apiKey` (required): SDK API key
- `broadcastId` (optional): Broadcast ID for broadcast-specific overrides (also accepts `matchId` for backward compatibility)

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
  "campaignId": 28,
  "version": "1.0.0",
  "brand": {
    "name": "Elkjøp",
    "iconAsset": "avatar_el",
    "iconUrl": "https://cdn.reachu.io/brands/elkjop/avatar.png",
    "logoUrl": "https://cdn.reachu.io/brands/elkjop/logo.png",
    "sponsorBadgeText": {
      "no": "Sponset av",
      "en": "Sponsored by",
      "sv": "Sponsrad av"
    }
  },
```

**Field Details:**
- `brand.name`: Brand name displayed in engagement components. Default: Campaign name or "Reachu"
- `brand.iconAsset`: Local asset name in app bundle (e.g., "avatar_el"). Default: "avatar_default"
- `brand.iconUrl`: CDN URL for brand icon. Optional, if null SDK uses `iconAsset`
- `brand.logoUrl`: CDN URL for brand logo. Optional
- `brand.sponsorBadgeText`: Map of language codes to sponsor badge text. Default values:
  - "no": "Sponset av"
  - "en": "Sponsored by"
  - "sv": "Sponsrad av"
  "engagement": {
    "demoMode": false,
    "defaultPollDuration": 300,
    "defaultContestDuration": 600,
    "maxVotesPerPoll": 1,
    "maxContestsPerMatch": 10,
    "enableRealTimeUpdates": true,
    "updateInterval": 1000
  },
```

**Field Details:**
- `engagement.demoMode`: Enable demo mode (use mock data). **IMPORTANT:** Should be `false` in production. Only `true` for testing when backend is unavailable.
- `engagement.defaultPollDuration`: Default poll duration in seconds. Default: `300` (5 minutes)
- `engagement.defaultContestDuration`: Default contest duration in seconds. Default: `600` (10 minutes)
- `engagement.maxVotesPerPoll`: Maximum votes per user per poll. Default: `1`
- `engagement.maxContestsPerMatch`: Maximum contests per match. Default: `10`
- `engagement.enableRealTimeUpdates`: Enable WebSocket real-time updates. Default: `true`
- `engagement.updateInterval`: Polling interval in milliseconds if WebSocket unavailable. Default: `1000`
  "ui": {
    "theme": {
      "primaryColor": "#69A333",
      "secondaryColor": "#9933FF"
    },
```

**Field Details:**
- `ui.theme.primaryColor`: Primary brand color in hex format. Optional, if null SDK uses theme from local config. Default: `#007AFF`
- `ui.theme.secondaryColor`: Secondary brand color in hex format. Optional. Default: `#5856D6`
    "components": {
      "cart": {
        "position": "bottomRight",
        "displayMode": "iconOnly",
        "size": "small"
      },
      "discountBadge": {
        "enabled": true,
        "text": "-30%",
        "position": "topRight"
      }
    }
  },
  "features": {
    "enableLiveStreaming": true,
    "enableProductCatalog": true,
    "enableEngagement": true,
    "enablePolls": true,
    "enableContests": true
  },
```

**Field Details:**
- All feature flags are boolean toggles configurable per campaign in dashboard
- Default values: All `true` (all features enabled by default)
- These flags allow enabling/disabling features per campaign without app updates
  "cache": {
    "ttl": 300,
    "version": "1.0.0"
  }
}
```

### Error Responses

**400 Bad Request**
```json
{
  "error": "Invalid campaignId or apiKey",
  "code": "INVALID_PARAMETERS"
}
```

**404 Not Found**
```json
{
  "error": "Campaign not found",
  "code": "CAMPAIGN_NOT_FOUND"
}
```

**500 Internal Server Error**
```json
{
  "error": "Internal server error",
  "code": "INTERNAL_ERROR"
}
```

---

## Endpoint 2: Engagement Configuration

**GET** `/v1/engagement/config`

Fetches engagement-specific configuration for a match.

### Query Parameters

- `apiKey` (required): SDK API key
- `broadcastId` (required): Broadcast ID (also accepts `matchId` for backward compatibility)

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
  "broadcastId": "barcelona-psg-2024",
  "matchId": "barcelona-psg-2024", // Backward compatibility
  "engagement": {
    "demoMode": false,
    "defaultPollDuration": 300,
    "defaultContestDuration": 600,
    "maxVotesPerPoll": 1,
    "enableRealTimeUpdates": true
  },
  "cache": {
    "ttl": 300
  }
}
```

### Error Responses

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
  "error": "Engagement config not found for broadcastId",
  "code": "CONFIG_NOT_FOUND"
}
```

---

## Endpoint 3: Localization

**GET** `/v1/localization/{language}`

Fetches localized strings for a specific language and optionally campaign/match.

### Path Parameters

- `language` (required): Language code (e.g., "no", "en", "sv")

### Query Parameters

- `apiKey` (required): SDK API key
- `campaignId` (optional): Campaign ID for campaign-specific translations
- `broadcastId` (optional): Broadcast ID for broadcast-specific translations (also accepts `matchId` for backward compatibility)

### Response

**Status:** `200 OK`

**Headers:**
```
Content-Type: application/json
Cache-Control: public, max-age=3600
```

**Body:**
```json
{
  "language": "no",
  "campaignId": 28,
  "translations": {
    "sponsorBadge": "Sponset av",
    "voteButton": "Stem",
    "participateButton": "Delta",
    "pollClosed": "Avstemningen er stengt",
    "alreadyVoted": "Du har allerede stemt",
    "contestEnded": "Konkurransen er avsluttet"
  },
  "dateFormat": "dd.MM.yyyy",
  "timeFormat": "HH:mm",
  "cache": {
    "ttl": 3600
  }
}
```

### Error Responses

**400 Bad Request**
```json
{
  "error": "Invalid language code",
  "code": "INVALID_LANGUAGE"
}
```

**404 Not Found**
```json
{
  "error": "Translations not found for language",
  "code": "TRANSLATIONS_NOT_FOUND"
}
```

---

## WebSocket Event: Config Updated

**Event Type:** `config:updated`

Sent when configuration changes and clients should invalidate cache and reload.

### Event Payload

```json
{
  "type": "config:updated",
  "campaignId": 28,
  "broadcastId": "barcelona-psg-2024",
  "matchId": "barcelona-psg-2024", // Backward compatibility
  "sections": ["brand", "engagement"],
  "version": "1.0.1"
}
```

### Fields

- `type`: Always `"config:updated"`
- `campaignId`: Campaign ID affected (integer)
- `broadcastId`: Broadcast ID affected (string, optional, also accepts `matchId` for backward compatibility)
- `sections`: Array of configuration sections that changed (e.g., `["brand", "engagement", "ui"]`)
- `version`: New configuration version (string)

### SDK Action

When receiving this event, the SDK should:
1. Invalidate cached configuration for the affected campaign/match
2. Reload configuration from the appropriate endpoint
3. Update `ReachuConfiguration` with new values
4. Notify subscribed components of changes

---

## Database Schema Recommendations

See `BACKEND_IMPLEMENTATION_GUIDE.md` for detailed database schema, table structures, and implementation recommendations.

## Implementation Notes

### Caching

- Campaign config: TTL 5 minutes (300 seconds)
- Engagement config: TTL 5 minutes (300 seconds)
- Localization: TTL 1 hour (3600 seconds)
- Backend should include `Cache-Control` headers
- SDK will respect TTL but may invalidate earlier via WebSocket

### Versioning

- Configuration includes a `version` field
- SDK can use this to detect changes
- Backend should increment version when config changes

### Fallback Strategy

- If backend is unavailable, SDK falls back to local JSON configuration
- SDK merges backend config with local defaults
- Local config takes precedence for critical settings (e.g., API keys)

### Performance

- Endpoints should respond within 200ms
- Use CDN for static assets (icons, logos)
- Consider compression for large translation files
