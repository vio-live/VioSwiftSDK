# Development networking (REST / WebSocket / physical devices)

## What `environment: "development"` does

`ConfigurationLoader` resolves campaign hosts from `vio-config.json` → `campaigns`:

| Keys | Used when |
|------|-----------|
| `devRestAPIBaseURL`, `devWebSocketBaseURL` (or `devWsBaseURL`) | `environment` is **`development`** |
| `restAPIBaseURL`, `webSocketBaseURL` / `wsBaseURL` | `testing`, `sandbox`, `production` |

The TV2 demo keeps **local/mock** URLs under the `dev*` keys (see `Demo/tv2demo/.../vio-config.json`). **Non-development** envs point at `https://api-dev.vio.live` / `wss://…` so builds without a local backend still resolve.

## Simulator vs physical iPhone

- **Simulator** uses the **Mac’s network stack**. If the Mac can reach your mock (e.g. Tailscale IP `100.x`, or `127.0.0.1` when the server runs on the same machine), the simulator usually can too.
- **Physical device** has its **own** routing. An address like `http://100.84.x.x:5001` is typically a **Tailscale** (or similar overlay) address. The phone must be on the **same tailnet** (e.g. **Tailscale installed and signed in on the iPhone**) or use a host that is routable from the public Internet.

If `GET /v1/sdk/config` **times out** (`NSURLError -1001`) from the phone but works in the simulator, this mismatch is the first thing to check—not GraphQL or commerce decode.

## Push notifications vs REST

**Remote notifications** are delivered by **Apple (APNs)**. The app does not need to open a TCP connection to your mock to **receive** a push.

**Bootstrap and campaigns** use **direct HTTP** to `campaignConfiguration.restAPIBaseURL` (e.g. `GET /v1/sdk/config`, `GET /v1/sdk/campaigns`). That **does** require the device to reach that host. So you can see **pushes working** while **bootstrap fails** if the phone cannot route to the dev IP.

## Commerce bootstrap

After a successful **`GET /v1/sdk/config` (HTTP 2xx)**, the SDK stores the snapshot and applies `commerce.apiKey` / GraphQL endpoint for `ProductService`. Until that request succeeds, `commerceNotConfigured` is expected if the overlay relies on bootstrap credentials.

## Current demo default (development)

The TV2 `vio-config` **`development`** hosts point at a **tunnelled dev API** (example in repo: `https://api-local-angelo.vio.live` and `wss://api-local-angelo.vio.live`). Replace with your own tunnel or LAN/Tailscale URL as needed; **do not commit secrets** (use local config or env-specific files for API keys).

## More robust approach: tunnel from the backend

Relying on **Tailscale (or LAN IP) on every developer phone** works but is operationally heavier.

A **sturdier** pattern for “phone + CI + external testers” is to expose the dev API over **HTTPS on a public hostname** via a **tunnel** controlled next to the backend, for example:

- **Cloudflare Tunnel**, **ngrok**, **Tailscale Funnel**, or similar  
- The app (or `vio-config`) then uses `https://your-dev-tunnel.example/...` instead of a raw `100.x` IP. **TLS** and **stable DNS** improve compatibility with ATS and with networks that block odd ports or non-HTTP traffic.

The SDK does not mandate a specific tunnel; choose what your backend team runs. Long term, **api-dev** (or another shared dev host) remains the default for builds that should not depend on a developer laptop.

## Bootstrap deduplication (`GET /v1/sdk/config`)

`CampaignManager` coalesces overlapping calls to the same bootstrap (same SDK `apiKey` + `campaignConfiguration.restAPIBaseURL`): concurrent callers share one in-flight request. After a **successful** HTTP 2xx, repeated calls within **45 seconds** skip the network if a snapshot is already stored (reduces duplicate work when `VioConfiguration.configure`, `discoverCampaigns`, and overlays/notifications all trigger bootstrap). `reinitialize()` clears coalesce state. For a full credential refresh, call `VioConfiguration.configure` again (it resets the remote config snapshot).

## Related code

- `ConfigurationLoader.createCampaignConfiguration` — `development` → `devRestAPIBaseURL` / `devWebSocketBaseURL`
- `CampaignManager.fetchAndApplySdkBootstrap` — `GET /v1/sdk/config` (coalescing + short freshness skip)
- `VioConfiguration.resolvedCommerceApiKey` / `resolvedCommerceGraphQLURL` — bootstrap-only commerce for `ProductService`

## Recent hardening summary

The SDK startup and commerce/payment flows were hardened to reduce race conditions, duplicate requests, and log noise:

- Bootstrap and discovery now use serialized in-flight execution in `CampaignManager` to avoid duplicated concurrent requests.
- Discovery now reuses warm in-memory state for the same `broadcastId + apiKey` instead of re-fetching immediately at startup.
- `VioConfiguration.applySdkBootstrapCommerce(...)` now emits `.vioCommerceBootstrapDidApply` only when commerce credentials actually change.
- `ConfigurationLoader` and `VCheckoutOverlay` now initialize commerce clients using resolved bootstrap credentials (`resolvedCommerceGraphQLURL`, `resolvedCommerceApiKey`).
- `CartModule`, `MarketManager`, and `ProductService` now perform one bounded retry after bootstrap refresh on auth-related failures.
- `ApplePayManager` now validates backend cart sync before checkout, uses backend-first Stripe key resolution (`applePayInit` first, `stripeIntent` fallback), and handles optional/pending confirm statuses.
- Repeated high-volume debug logs were removed from product/detail/cart startup paths to make runtime diagnostics actionable.
