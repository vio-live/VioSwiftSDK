# Cart Intent Flow — TV → Mobile with Attribution

End-to-end flow of a cart-intent that starts on the Apple TV SDK and terminates on
the TV2 iOS companion app, carrying the attribution chain from the originating
`shoppable_ad` all the way to the `cart_intents` row + the product detail overlay.

Assumes the v2 multi-sponsor backend (`socket-server` on `feature/tv-broadcast-subscribe`
or later) and the v2 iOS SDK bootstrap (`feature/v2-sdk-config` + `feature/tv-cart-intent-attribution`).

## Sequence

```
┌─── Apple TV (VioTVSDK) ──────────────────────────────────────────────┐
│                                                                       │
│  1. WS receives:                                                      │
│     { type: "shoppable_ad", activationId, sponsorId,                  │
│       product, sponsor:{id,name,avatarUrl,logoUrl,primaryColor} }     │
│  2. VioTVManager.activeAd = event                                     │
│  3. VioTVShoppableOverlay renders product + avatarUrl                 │
│  4. User taps "Add to cart" on Siri remote                            │
│  5. Overlay → VioTVManager.sendCartIntent(                             │
│       productId, campaignId,                                          │
│       activationId: activeAd.activationId,      ← attribution         │
│       sponsorId:    activeAd.sponsorId)                               │
│                                                                       │
└────────────────┬──────────────────────────────────────────────────────┘
                 │ POST /api/sdk/tv/cart-intent
                 │ X-API-Key: <tv2 apiKey>
                 │ { externalUserId, productId, activationId }    ← minimal v2 body
                 ▼
┌─── Backend (socket-server) ──────────────────────────────────────────┐
│                                                                       │
│  6. validateApiKey → clientApp                                        │
│  7. getShoppableAdActivation(activationId) → resolve                   │
│       campaignId, sponsorId (avoids the SDK having to send them)      │
│  8. ensureEndUser(clientApp.id, externalUserId) → end_users row       │
│  9. Resolve product name via Commerce GraphQL (best effort)           │
│ 10. Build envelope v1:                                                │
│     { vio_event_type:"cart_intent",                                   │
│       vio_payload:{ product_id, campaign_id, product_name,            │
│                     activation_id, sponsor_id, deeplink, … } }        │
│ 11. Route to mobile:                                                  │
│       ├─ wsUserMap.get(externalUserId) → directWs.send(envelope)      │
│       ├─ (cluster) Redis Pub/Sub → forward to node that owns socket   │
│       └─ (offline) partner webhook / APNs via                         │
│          `notifyCartIntentPartnerFallback` (e.g. the TV2 mock at      │
│          viopartnermockv2.azurewebsites.net)                          │
│ 12. createCartIntent({                                                │
│        endUserId, campaignId, clientAppId, sponsorId,                 │
│        sourceActivationId: activationId,  ← attribution closed        │
│        deliveryMode, userConnected, envelope                           │
│     })                                                                 │
│ 13. 200 OK → { cartIntentId, mode, userConnected, envelope }           │
│                                                                       │
└────────────────┬──────────────────────────────────────────────────────┘
                 │ WS delivery (happy path) or APNs (offline)
                 ▼
┌─── TV2 iOS companion (VioSwiftSDK / Demo/tv2demo) ───────────────────┐
│                                                                       │
│ 14. CampaignWebSocketManager receives                                  │
│       `{ type:"cart_intent", vio_payload:{…} }`                       │
│ 15. CartIntentEvent.parse(jsonData:) decodes                           │
│       → activationId, sponsorId (new in v2), productId, campaignId    │
│ 16. CampaignManager.publishCartIntentIfChanged(event)                  │
│       dedup: skip if activationId matches the one already in flight    │
│       (prevents dual-delivery causing two overlays)                    │
│ 17. CampaignManager.activeCartIntentEvent = event                      │
│ 18. ContentView observes → renders                                     │
│       CartIntentProductDetailHost(productId, sponsorId)                │
│ 19. ProductService.loadProduct(productId, sponsorId: X)                │
│       → CommerceSdkClientProvider.client(forSponsorId: X)              │
│       → uses that sponsor's commerceApiKey                             │
│       → hydrates the product from the sponsor's channel                │
│ 20. VProductDetailOverlay sheet appears — Apple Pay available          │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

## Why attribution matters

Each link in the chain has a concrete reason:

- **`shoppable_ad_activations.id`** stamps the moment the TV dispatched the ad. It's
  the anchor row that later cart-intents, clicks, purchases all point at.
- The Apple TV SDK echoes that `activationId` back on the `POST /api/sdk/tv/cart-intent`
  body, and the backend derives `campaignId + sponsorId` from it — so the SDK can
  ship the **minimum body** (`{ externalUserId, productId, activationId }`).
- `cart_intents.source_activation_id` closes the loop on the analytics side: for
  any cart-intent row you can trace back to the exact ad that triggered it.
- `sponsorId` on the envelope is what lets the iOS SDK pick the right Commerce
  GraphQL key. Without it the product would always be loaded from the primary
  sponsor's channel even when the shoppable_ad came from a secondary.

## Dedup rules (iOS side)

`CampaignManager.publishCartIntentIfChanged(_:)` is the single gate before the
`activeCartIntentEvent` is updated and the overlay opens:

- If incoming `activationId != nil` and matches the last published event's
  `activationId` → **skip**. This is the common dual-delivery case: backend
  sends via WS **and** via partner webhook/APNs as redundancy; both land.
- If incoming `activationId == nil` (legacy mobile cart-intent, no attribution)
  → fall back to comparing `(productId, campaignId)` against the last published.
- Otherwise → publish, log `activationId=X sponsorId=Y` on the apply line.

The backend does **not** dedup on its side today — every inbound `/api/sdk/tv/cart-intent`
creates a new `cart_intents` row. Treat that as an analytics signal (one row per
tap) rather than a unique-event record. Tight rate-limiting should live at the
SDK level, not the backend.

## Per-sponsor Commerce routing

Set up by `feature/v2-sdk-config`:

- `GET /v2/sdk/config` returns `primarySponsor` + `secondarySponsors`, each with
  its own `commerce` block (`apiKey`, `channelId`, `paymentMethods`).
- `VioConfiguration.sponsor(withId:)` and `VioConfiguration.commerce(forSponsorId:)`
  expose the lookup.
- `CommerceSdkClientProvider.client(forSponsorId:)` maintains a per-sponsor cache
  of `SdkClient` instances and is the single entry point for sponsor-scoped
  GraphQL calls.
- `ProductService.loadProduct(productId:currency:country:sponsorId:)` accepts
  an optional `sponsorId` (nil falls back to primary). `CartIntentProductDetailHost`
  wires it up from `CartIntentEvent.sponsorId`.

Today Elkjøp (id 3) and XXL (id 7) share the same Commerce apiKey so the routing
is functionally a no-op; the moment XXL gets its own key in the dashboard the
flow will keep working without code changes.

## Files involved

| Layer | File | Role |
|---|---|---|
| TV SDK | `InteractiveAds-vio/Sources/VioTVCore/VioTVManager.swift` | `sendCartIntent(...)` POSTs with `activationId` + `sponsorId` from `activeAd` |
| TV SDK | `InteractiveAds-vio/Sources/VioTVUI/VioTVShoppableOverlay.swift` | "Add to cart" wires to `sendCartIntent` |
| Backend | `socket-server/server/routes.ts` (`/api/sdk/tv/cart-intent`) | Resolves context from `activationId`, persists + forwards |
| Backend | `socket-server/server/storage.ts` | `getShoppableAdActivation(id:)` helper |
| iOS SDK | `VioCore/Models/CampaignModels.swift` | `CartIntentEvent.activationId` + `.sponsorId` |
| iOS SDK | `VioCore/Managers/CampaignManager.swift` | `publishCartIntentIfChanged(_:)` dedup |
| iOS SDK | `VioCore/Sdk/Core/GraphQL/CommerceSdkClientProvider.swift` | `client(forSponsorId:)` per-sponsor cache |
| iOS SDK | `VioUI/Services/ProductService.swift` | `loadProduct(..., sponsorId:)` |
| Demo | `VioSwiftSDK/Demo/tv2demo/tv2demo/ContentView.swift` | `CartIntentProductDetailHost` propagates `sponsorId` |

## Operational checks when the flow looks broken

- **Mobile app not receiving anything** — the most common cause is a userId
  mismatch. Every piece of the delivery tree keys on the opaque `externalUserId`
  the SDK passes on the WS `identify` message. The TV2 demo pair aligns both
  sides to `demo_user_001` (Apple TV `InteractiveAds_vioApp.configureFromBundle(userIdOverride:)`,
  iOS `CampaignManager.shared.userId` in `tv2demoApp.swift`). If those two
  diverge — partner app changes, stale build, JWT vs hardcoded id — the
  backend's `wsUserMap` lookup misses and the envelope falls through to the
  partner webhook instead of the fast local WS path. Check both apps log the
  same userId at boot.
- **Envelope arrives but overlay doesn't open** — confirm the mobile SDK build
  actually includes `feature/v2-sdk-config` + `feature/tv-cart-intent-attribution`.
  Without the attribution commit, `CartIntentEvent.activationId` is nil, so the
  dedup gate **will** skip duplicates by `(productId, campaignId)` but the rest
  of the flow still works.
- **Product loads from wrong sponsor** — means `sponsorId` isn't propagating.
  Log `[ProductService] GraphQL Authorization: ...` — when the event has a
  sponsorId the source line should read `per-sponsor (id=X)`, not `bootstrap
  primary`.
- **Offline path (webhook / APNs)** — `notifyCartIntentPartnerFallback` POSTs
  to `client_apps.webhook_url` (for TV2 that's the mock server
  `https://viopartnermockv2.azurewebsites.net/api/v1/partner/webhook`). If the
  mock is down, the delivery drops; the `cart_intents` row is still persisted
  with `deliveryMode='webhook'`.
