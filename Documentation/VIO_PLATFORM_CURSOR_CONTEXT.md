> **Uso en este repo:** Referencia de **plataforma Vio** y del monorepo **socket-server** (Express/React/Postgres). No sustituye el árbol de carpetas de VioSwiftSDK. Para Swift, leer primero [CONTEXT_IOS.md](CONTEXT_IOS.md) y [CODEBASE_INDEX.md](CODEBASE_INDEX.md).

# Vio — Real-Time Event Broadcasting Platform

## What is Vio?

Vio is a multi-tenant SaaS platform for managing real-time event broadcasts with interactive engagement (polls, contests, ads, shoppable products). Built with React + Express + PostgreSQL + WebSockets.

## Tech Stack

- **Frontend:** React 18 + Vite + TypeScript, Tailwind CSS, Radix UI / shadcn/ui, TanStack Query v5, Wouter routing, Lucide React icons, Recharts (analytics charts)
- **Backend:** Express.js + TypeScript, Drizzle ORM, PostgreSQL (Neon Serverless), ws WebSockets
- **Auth:** JWT Bearer tokens (admin APIs), API keys (SDK endpoints), session-based (dashboard)
- **Storage:** Replit Object Storage for file uploads, Uppy as upload client
- **Docs:** OpenAPI 3.0 specification (`openapi.yaml`, ~5700 lines, 80 endpoints)

## Known External Services (NOT part of this repo)

- **`event-streamer-angelo100.replit.app`** — DEPRECATED domain. Same backend code as this repo, different old deployment. The iOS SDK has this URL hardcoded in `OfferBannerModels` and `EventStreamerManager` — should be replaced with `restAPIBaseURL` from config. All endpoints already exist in `api-dev.vio.live`. Nothing to implement here.
- **`graph-ql-dev.vio.live/graphql`** — Separate GraphQL backend, not managed in this repo. Used by `SdkClient` and `VCastingVideoPlayer` in the iOS SDK. Out of scope.
- **`stg-dev-microservices.tipioapp.com`** — Tipio external API server. The iOS SDK calls it directly using the Commerce key received from `integrations.commerce.apiKey` in the config endpoint. Vio does not proxy or interact with it.

## Project Structure

```
shared/schema.ts           — Single source of truth: Drizzle tables, Zod schemas, TypeScript types
server/routes.ts            — All API routes (~4000 lines)
server/storage.ts           — IStorage interface + DatabaseStorage implementation
server/analytics.ts         — Analytics endpoints (8 SQL-based endpoints)
server/db.ts                — Drizzle database connection
server/scheduler.ts         — In-memory component scheduler
server/middleware/           — Rate limiter, broadcast validator
server/services/            — Vote processor, contest processor
client/src/App.tsx           — Wouter router with all page routes
client/src/components/AppLayout.tsx — Main shell (sidebar nav + header + content area)
client/src/components/ui/    — shadcn/ui component library
client/src/components/dashboard/ — Campaign dashboard tab components
client/src/pages/            — All page components
client/src/pages/analytics.tsx — Full analytics page with drill-down views
client/src/contexts/         — ThemeContext (dark/light), UserContext (session)
client/src/lib/queryClient.ts — TanStack Query config + apiRequest helper
openapi.yaml                — OpenAPI 3.0 specification (80 endpoints, 17 tag groups)
```

## Data Model Hierarchy

Users → Client Apps → Campaigns → Broadcasts → Polls/Contests

Note: Channels are OPTIONAL metadata at campaign level. Campaigns link directly to apps via `campaigns.client_app_id`.
The SDK discovers campaigns by clientAppId directly — NOT through channels.

Key tables: `users`, `sponsors`, `client_apps`, `channels`, `campaigns`, `components`, `campaign_components`, `broadcasts`, `polls`, `poll_options`, `poll_votes`, `contests`, `contest_participations`, `broadcast_ads`, `broadcast_products`, `chat_messages`, `events`, `scheduled_components`

Configuration tables: `campaign_translations`, `campaign_engagement_config`, `campaign_ui_config`, `campaign_feature_flags`, `sdk_translations`

Schema additions (Feb 2026):
- `broadcasts.viewerCount` (integer, default 0) — current viewer count
- `broadcasts.peakViewers` (integer, default 0) — peak concurrent viewers
- `broadcasts.externalId` (varchar 255, nullable) — partner content ID (e.g. Viaplay stream ID). Index on `(externalId, campaignId)`. Lookup is scoped to clientApp via campaign.clientAppId.
- `broadcasts.duration` (integer, seconds) — added to polls table; exposed in createPoll/updatePoll and broadcast detail
- `broadcast_ads` — ads linked to a broadcast (name, description, imageUrl, ctaUrl, adType, duration as varchar, isActive, displayOrder)
- `broadcast_products` — shoppable products (name, subtitle, price/originalPrice as varchar NOT integer, buyUrl, status, displayOrder)
- `chat_messages` — live chat per broadcast (username, message, createdAt)

Schema additions (Mar 2026):
- `campaign_components.locationId` (varchar 100, nullable) — SDK slot identifier (e.g. `"sport-detail-banner"`, `"sport-detail-carousel"`). Used by SDK to query `GET /v1/sdk/components?locationId=`. Set by operator in dashboard when adding a component to a campaign.
- `polls.broadcastId` / `contests.broadcastId` (added to event schema) — included in WS events so SDK can filter by broadcast
- `sponsors.badgeText` — localized badge text object `{ no, en, sv }` returned in config endpoint as `sponsor.badgeText`
- `broadcasts.sportmonksFixtureId` (integer, nullable) — Sportmonks fixture ID linked to this broadcast
- `broadcasts.homeTeamName`, `broadcasts.awayTeamName` (varchar 255, nullable) — team display names
- `broadcasts.homeTeamLogo`, `broadcasts.awayTeamLogo` (varchar 500, nullable) — CDN URLs of team logo images
- `broadcasts.matchStartingAt` (timestamp, nullable) — official match start time from Sportmonks
- `broadcasts.leagueName` (varchar 255, nullable) — league/competition name (e.g. "Scottish Premiership")
- `sportmonks_cache` — caches Sportmonks API responses. TTL diferenciado: **fixtures = 6 horas**, **leagues = 2 días**. Fields: `cacheType` (varchar), `leagueId` (integer nullable), `dateFrom`/`dateTo` (varchar nullable), `data` (JSONB), `updatedAt` (timestamp)
- `sponsors.commerceApiKey` (varchar 255, nullable) — Commerce module API key per sponsor (previously stored at campaign level as `campaigns.reachuApiKey`)
- `sponsors.commerceChannelId` (varchar 255, nullable) — Commerce channel ID per sponsor (previously `campaigns.reachuChannelId`)
- `broadcasts.metadata` (JSONB) — arbitrary JSON. Key sub-field: `matchEvents` — array of `{ minute, type, label, team? }`. Types: `kickoff`, `goal`, `fulltime`, `poll`, `contest`, `shoppable_ad`. Powers the EventTimeline horizontal scrubber. Also stores `homeTeamId`/`awayTeamId` (integer) written by the Create Broadcast modal when the operator picks a Sportmonks fixture.
- `broadcasts.showLineup` (boolean, default false) — operator toggle: when `true` the lineup section is delivered to SDK viewers. Persisted via `PUT /api/broadcasts/:id`.
- `broadcasts.startedAt` (timestamp, nullable) — auto-set to `NOW()` when status transitions to `'live'` for the first time; used to compute `videoTimestamp` for the `lineup_show` WS event.

All schemas, insert schemas, and types are exported from `shared/schema.ts`.

### Known Schema Issues (Pending Migration)
- Boolean flags stored as `varchar("true"/"false")` instead of proper `boolean` columns (e.g., `campaigns.isPaused`, `isSegmented`, feature flags). Should be migrated to `boolean` with defaults.
- Some foreign key columns may lack indexes for analytics-heavy queries (e.g., `poll_votes.broadcast_id`, `contest_participations.user_id`).

## API Layers

### Dashboard APIs (`/api/*`) — Session-based
Internal CRUD for all entities. Used by the React frontend.
- `/api/campaigns`, `/api/broadcasts`, `/api/components`, `/api/sponsors`, `/api/client-apps`, etc.
- Broadcast sub-resources:
  - `/api/broadcasts/:broadcastId/polls` — CRUD polls
  - `/api/broadcasts/:broadcastId/contests` — CRUD contests
  - `/api/broadcasts/:broadcastId/ads` — GET / POST broadcast ads
  - `/api/broadcasts/ads/:id` — PUT / DELETE individual ad
  - `/api/broadcasts/:broadcastId/products` — GET / POST shoppable products
  - `/api/broadcasts/products/:id` — PUT / DELETE individual product
  - `/api/broadcasts/:broadcastId/chat` — GET / POST live chat messages
  - `/api/broadcasts/:broadcastId/analytics` — GET real analytics (polls, contests, viewers, votes)
  - `/api/seed-demo` (POST) — Seeds ads, products, and chat messages into a broadcast for demo purposes
- Sportmonks proxy (with server-side cache):
  - `GET /api/sportmonks/leagues` — All leagues available in Sportmonks account (2-day cache in `sportmonks_cache` table)
  - `GET /api/sportmonks/fixtures?leagueId=X&dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD` — Fixtures filtered by league and date range (6-hour cache). **IMPORTANTE:** el parámetro `?leagues=X` de Sportmonks no filtra bien — el servidor ignora ese param, trae todos los fixtures del día con `per_page=150` y aplica `f.league_id === leagueId` server-side ANTES de guardar en caché. Solo datos ya filtrados van a la DB. Cache diferenciada: `isCacheValidFor(cached, FIXTURE_CACHE_TTL_MS)` (6h) vs `LEAGUE_CACHE_TTL_MS` (2d).
  - `GET /api/sportmonks/fixture/:fixtureId/result` — Full fixture result: score, teams, filtered events (goals, cards, kickoff, HT, FT). In-memory cache: 30s for live matches, 5min for FT. Response: `{ fixtureId, homeTeam, awayTeam, homeScore, awayScore, status, date, league, events[] }`. Events: `{ minute, type, label }` where type ∈ kickoff | goal | owngoal | yellowcard | redcard | halftime | fulltime | var | penalty.

### Admin APIs (`/v1/*`) — JWT Bearer Auth (`requireBearerAuth`)
External admin access for broadcasts, polls, contests.
- `/v1/broadcasts` — CRUD
- `/v1/broadcasts/:broadcastId/polls` — Poll management
- `/v1/broadcasts/:broadcastId/contests` — Contest management

### SDK APIs (`/v1/sdk/*`, `/v1/engagement/*`) — API Key Auth or X-App-Bundle-ID header
Mobile SDK integration endpoints. Two-step initialization flow:

**Step 1 — on app launch:**
- `GET /v1/sdk/campaigns` — Returns ALL active campaigns + campaign-level components (banners, carousels) for the app. Auth: `X-App-Bundle-ID` header or `X-Api-Key` / `?apiKey=`.

**Step 2 — on content open:**
- `GET /v1/sdk/broadcast?contentId=xxx&country=NO` — Resolves `contentId` → `externalId` on `broadcasts` table → returns `{ hasEngagement: true/false }`. If true, includes `broadcastId`, `campaignId`, `websocketChannel`, `campaignComponents`, and `broadcastComponents` (polls, contests, chat).
  - Cache: `hasEngagement: false` → `Cache-Control: public, max-age=30`. `hasEngagement: true` → `Cache-Control: private, max-age=10` + `ETag`.
  - Country filter: if `country` param sent, checks `campaign.targetCountries`. Null/empty = all countries.

**Engagement:**
- `/v1/engagement/polls/:pollId/vote` — Cast votes (rate-limited)
- `/v1/engagement/contests/:contestId/participate` — Participate (rate-limited)
- `/v1/offers` — Product offers with geo-targeting
- `/v1/localization/:language` — i18n strings

**Other SDK:**
- `/v1/sdk/config` — Zero-config endpoint for Swift SDK. Requires only `apiKey` (no `campaignId`). Auto-detects active campaign. Returns `{ clientApp, endpoints, features, commerce, theme, markets }`. Commerce key sourced from `sponsors.commerceApiKey` (fallback `campaigns.reachuApiKey`).

### API Key Architecture (definitive model — Feb 2026)

**App level — hardcoded in `vio-config.json`:**
```json
{
  "apiKey": "<Vio App API Key>",
  "restAPIBaseURL": "https://api-dev.vio.live",
  "webSocketBaseURL": "https://api-dev.vio.live"
}
```
- ONE single Vio App API Key per client app (`client_apps.api_key`)
- Used for ALL Vio backend endpoints — no separate `campaignAdminApiKey` or `campaignApiKey`
- Authenticated via `?apiKey=` query param or `X-Api-Key:` header

**Campaign level — delivered by the server:**
The Commerce module API key is NOT hardcoded in the app. The SDK reads it from `GET /v1/campaigns/:id/config`:
```json
{
  "integrations": {
    "commerce": {
      "enabled": true,
      "apiKey": "COMMERCE-KEY-HERE",
      "channelId": "commerce-channel-id"
    }
  }
}
```
- `enabled: false` → do not initialize the Commerce module
- Stored in DB as `campaigns.reachuApiKey` / `campaigns.reachuChannelId` (internal field names, never exposed publicly)
- Configured in the dashboard: Campaign Settings → Commerce Integration section

### Analytics APIs (`/api/analytics/*`) — Session-based
SQL-based analytics with drill-down hierarchy: Global → App → Campaign → Broadcast.
- `/api/analytics/overview` — Platform-wide KPIs (apps, campaigns, broadcasts, engagement totals)
- `/api/analytics/engagement` — Top campaigns, top components, broadcast activity (30 days)
- `/api/analytics/geographic` — Geographic distribution by target countries
- `/api/analytics/apps/:appId` — Per-app detail with campaign breakdown
- `/api/analytics/campaigns/:campaignId` — Campaign detail: polls with vote distribution, contests, components, engagement timeline
- `/api/analytics/broadcasts/:broadcastId` — Broadcast detail: poll results, contests, vote timeline
- `/api/analytics/sponsors` — Sponsor performance ranking
- `/api/analytics/compare` — Side-by-side comparison (campaigns or broadcasts by IDs)

### OpenAPI Documentation
Full OpenAPI 3.0 spec at `openapi.yaml` with 17 tag groups:
- Admin API (Bearer): Broadcasts, Polls, Contests
- SDK: Discovery, Configuration, Engagement, Localization, Offers
- Dashboard: Apps, Channels, Campaigns, Sponsors, Components, Broadcasts (internal), Events, File Upload
- Analytics: All analytics endpoints

## Design System — Monochromatic Dark Theme

- **Background:** `#0a0e1a` (solid, no gradients)
- **Cards/surfaces:** `#141824` with `border-white/10`
- **Text:** White primary, `text-gray-400` secondary, `text-gray-500` muted
- **Primary accent:** White bg + black text for active buttons/nav
- **Status badges:** Live = white bg + pulse dot, Upcoming = bordered, Ended = low opacity
- **Broadcast colors:** Blue = polls, Purple = contests, Green = ads
- **Icons:** Lucide React only (never FontAwesome, never emojis)
- **Charts:** Recharts with white/gray fills, `#2a3142` grid lines, tooltip bg `#141824`
- **No blue/purple gradients** — strict monochromatic palette

## Key Pages & Their Purpose

### Analytics (`/analytics`)
Full analytics dashboard with drill-down navigation (no page reload, state-based):
- **Global Dashboard:** 8 KPI stat cards, broadcast activity bar chart (30 days), geographic distribution, top campaigns table (clickable for drill-down), top components progress bars, sponsor performance
- **App Drill-Down:** App KPIs, campaign list with engagement totals
- **Campaign Drill-Down:** 6 KPI cards, engagement timeline (line chart: votes + participations), polls with vote distribution bars, contests list, components grid, segmentation info
- **Broadcast Drill-Down:** 5 KPIs, vote timeline bar chart, poll results with vote bars, contest results
- Error and loading states for all data fetching. Route protected by RequireAuth.

### Broadcast Detail (`/broadcasts/:broadcastId`)
Full broadcast management view with split layout. **All data is real — zero hardcoded mocks.**
- **Header:** Broadcast name + Live/Upcoming/Ended badge + real stats (Viewers from `viewerCount`, Total Votes from analytics, Status). "Load Demo" button calls `POST /api/seed-demo` to seed ads/products/chat.
- **Event Timeline (redesigned Mar 2026):** Horizontal scrubber 0'–90'. Displays merged events: Sportmonks match events (goals, cards, kickoff, FT) fused with engagement events (polls, contests, shoppable_ads) from `broadcast.metadata.matchEvents`. Merge strategy: Sportmonks is authoritative for match-day events; metadata is authoritative for poll/contest/shoppable_ad. Colored dots: blue=poll, purple=contest, green=shoppable_ad, yellow=goal, grey=kickoff/fulltime. Minute tick labels at 0', 15', 30', 45', 60', 75', 90'. Hover tooltips with minute, label, vote count. Refetches every 60s when broadcast is live.
- **MatchDataCard** (`client/src/components/match-data-card.tsx`): Rendered after EventTimeline. Fetches `GET /api/sportmonks/fixture/:id/result`. Shows team logos + score, match date, league name, and key event timeline (goals, cards). Hidden (returns null) when `sportmonksFixtureId` is null. Has a manual refresh button.
- **Active Engagement:** Poll cards with blue color-coding, vote progress bars, create/toggle/delete
- **Contests & Trivia:** Contest cards with purple color-coding, create/toggle/delete
- **Shoppable Ads (redesigned Mar 2026):** 3-panel layout:
  1. **Pre-programmed Slots** — Add Slot dialog (sponsor, products, trigger type, auto-execute toggle). Fire/Delete per slot. Endpoints: `GET/POST /api/broadcasts/:id/sponsor-slots`, `DELETE /api/broadcasts/:id/sponsor-slots/:slotId`, `POST /api/broadcasts/:id/sponsor-slots/:slotId/execute`.
  2. **Quick Fire** — Ad-hoc fire: select sponsor from campaign + product from that sponsor's Commerce catalog. Fires immediately via `POST /api/broadcasts/:id/trigger-shoppable-ad` with Commerce key from `sponsor.commerceApiKey`.
  3. **Session Log** — Recent shoppable ad fire events for this session.
- **Scheduled Ads:** Loads from `GET /api/broadcasts/:id/ads`. Empty state if none. Delete with confirmation dialog.
- **Shoppable Products:** 4-column grid, loads from `GET /api/broadcasts/:id/products`. Shows price/originalPrice (varchar), status badge, buy URL. Each product has "Fire Ad" button using sponsor's Commerce key.
- **Right Sidebar:**
  - **Live Chat tab:** Real messages from `GET /api/broadcasts/:id/chat`, auto-refresh every 10s. Send button posts to `POST /api/broadcasts/:id/chat`. Message input supports Enter key. Disabled (read-only) when `status='ended'` with informational banner.
  - **Analytics tab:** Real data from `GET /api/broadcasts/:id/analytics` — viewerCount, peakViewers, totalVotes, activePolls, activeContests, chat message count.

### Component Library (`/components`)
4-column grid, type icons, filter pills, Templates-only toggle. Detail page at `/components/:id` with iOS Swift integration code and campaign usage.

### Campaign Dashboard (`/campaigns/:campaignId`)
Tabbed: **Overview | Broadcasts | Components | Sponsors | Analytics | Settings**. Tab navigation via callback-based `onNavigateTab` prop (not DOM manipulation). The "Live" tab was removed Mar-09-2026 — `EventsTab` and `ScheduledTab` no longer exist in this view.
- **Overview tab:** Campaign stats + list of broadcasts. Each broadcast card shows home/away team logo (`TeamLogo` component, defined in `OverviewTab.tsx`) alongside the broadcast name and status badge.
- **Settings tab:** Contains `<SettingsTab>` + `<IntegrationsTab>`. Sections: Basic Information, Campaign Schedule, Channel Assignment (optional), Commerce Integration, Targeting & Segmentation, Engagement Settings, Feature Flags, Danger Zone. Styled with raw divs + `border-white/10` (NOT shadcn Cards). Campaign Logo, Match Context, and UI Theme sections were removed — branding comes from Sponsor.
- **Analytics tab:** Real broadcast performance data. Queries `GET /api/broadcasts?campaignId=X` on tab activation. Shows KPI cards (total broadcasts, live count, total viewers, peak viewers) + per-broadcast table with status badges.
- **Broadcasts tab:** Create/list/delete broadcasts. "New Broadcast" form has an **"External Content ID"** field that maps to `broadcasts.externalId`. Each card has a pencil icon to edit name/externalId/status/dates via PUT.

### Create Broadcast Modal (`/broadcasts`)
Dialog to create a new broadcast. Fields: name, description, campaign, start/end times, External Content ID. Includes "Link to a Match" section with league selector + fixture picker from Sportmonks. **Both fixture and externalId are required** — submit button stays disabled until both are filled. On fixture select, auto-fills broadcast name and team/logo fields.

### Broadcast Detail (`/broadcasts/:broadcastId`)
- **"Send Live" buttons on Polls:** Each active poll card has a "Send Live" button → `POST /api/events/poll` with `{ question, options, duration, campaignId: broadcast.campaignId }` → fires WS event to connected SDK clients.
- **"Send Live" buttons on Contests:** Each contest card has a "Send Live" button → `POST /api/events/contest` with contest data + `campaignId`.

### Sponsor Management (`/sponsors`)
CRUD with logo/avatar uploads + primary/secondary color config.

### API Documentation (`/docs`)
Interactive OpenAPI documentation viewer.

## Conventions & Rules

### Code Style
- TypeScript strict mode everywhere
- Shared types from `shared/schema.ts` — never duplicate type definitions
- Use `createInsertSchema` from `drizzle-zod` for insert validation
- TanStack Query v5 object form only: `useQuery({ queryKey: ['key'] })`
- Use `apiRequest` from `@/lib/queryClient` for mutations
- Always invalidate query cache after mutations
- Always add `data-testid` to interactive and display elements
- For hierarchical query keys use arrays: `queryKey: ['/api/resource', id]` not template literals

### Database
- Schema changes: edit `shared/schema.ts` then run `npm run db:push`
- Never write raw SQL migrations
- Use `npm run db:push --force` if data-loss warning appears
- Never change primary key column types (serial ↔ varchar)
- Analytics queries use direct `db.execute(sql\`...\`)` for performance (not storage interface)

### Routing
- Frontend: Wouter (`Link`, `useLocation`, `useParams`)
- Use `@/components/AppLayout` as page wrapper
- Register new routes in `client/src/App.tsx`
- Protected routes wrap with `<RequireAuth>`

### Styling
- Tailwind CSS utility classes
- shadcn/ui components from `@/components/ui/`
- Always use Lucide React icons
- Follow the monochromatic dark theme (see Design System above)
- No `dark:` prefix needed for new code — theme is always dark

### Files You Must NOT Modify
- `vite.config.ts`
- `server/vite.ts`
- `drizzle.config.ts`
- `package.json` (use package manager tools instead)

### Storage Interface
- All DB operations go through `IStorage` in `server/storage.ts`
- Routes in `server/routes.ts` should be thin — delegate to storage
- Validate request bodies with Zod schemas before passing to storage
- Analytics is the exception — uses direct SQL via `server/analytics.ts`

## WebSocket Architecture

Isolated channels per campaign: `/ws/:campaignId`

**Events emitted by the server to SDK clients:**

| Event | Trigger | SDK Action |
|-------|---------|------------|
| `campaign_started` | Campaign start date reached or admin-triggered | Activate campaign-level components |
| `campaign_ended` | Campaign end date reached or admin-triggered | Hide everything |
| `campaign_paused` | Admin pauses campaign | Hide everything temporarily |
| `campaign_resumed` | Admin resumes campaign | Show campaign components again |
| `broadcast_started` | Broadcast status changes to `'live'` | Activate broadcast-level components (polls, contests, chat) |
| `broadcast_ended` | Broadcast status changes to `'ended'` | Hide broadcast components only; campaign banners/carousels remain |
| `poll` | Admin fires via EventsTab or "Send Live" button | Show poll overlay |
| `contest` | Admin fires via EventsTab or "Send Live" button | Show contest overlay |
| `product` | Admin fires via EventsTab | Show shoppable card |

All events include `{ type, campaignId, timestamp }`. Broadcast events also include `broadcastId` and `broadcastName`.

**Important:** `broadcast_ended` fires automatically when `PUT /api/broadcasts/:id` or `PUT /v1/broadcasts/:id` changes `status` to `'ended'`. Same for `broadcast_started` on `status → 'live'`. No manual trigger needed.

## Sidebar Navigation Order

Dashboard → Apps → Campaigns → Sponsors → Broadcasts → Components → Analytics → Docs

## Environment

- Dev server: `npm run dev` (Express + Vite on port 5000)
- DB: PostgreSQL via `DATABASE_URL`
- Object storage: Replit built-in, env vars `PUBLIC_OBJECT_SEARCH_PATHS`, `AZURE_CONTAINER`
- Session: `SESSION_SECRET` env var
- Auth: JWT tokens use `SESSION_SECRET` for signing

## Fixes & Features (Mar 2026)

- **Login demo user renamed:** Quick Access button `reachu-admin` → `vio-admin`. DB updated: `users.reachu_user_id = 'vio-admin'` (was `'reachu-admin'`, user ID 2). Use `vio-admin` to log in as admin in dev and production.

### Dashboard audit — batch T001–T007 (Mar 2026)

**Dashboard (`/`):**
- `GET /api/analytics/deltas` — nuevo endpoint que calcula % de cambio de viewers y engagement en últimos 7 días vs anteriores 7. Usado en el dashboard para los KPI deltas.
- "New Campaign" button navega a `/campaigns/new` (no abre modal inline).
- App cards sin logo/iconUrl muestran placeholder de iniciales con color determinístico (hash del nombre de la app).
- "Upcoming Campaigns" filtra por `startDate` dentro de los próximos 7 días; empty state si no hay ninguna.

**Apps + App Detail:**
- `/apps`: viewer count total = suma de `viewerCount` de todos los broadcasts de campañas de esa app. TV2 ~34K, Viaplay ~72K.
- Un solo botón "Manage" por app (sin duplicados Edit/Settings).
- `/apps/:id`: `broadcastCount` real por campaña. "Live Broadcasts" stat = solo `status='live'`. Icono `Calendar` junto a fechas (no `Users`). Status badges: Active=teal, Paused=amber, Archived/Ended=gray.

**Campaigns (`/campaigns`):**
- Nombres de país completos via `Intl.DisplayNames` (ej: "NO" → "Norway").
- Nombre + avatar del sponsor visibles en tarjetas.
- Columna "Engagement" = suma de votos de polls + participaciones en contests (enriquecido en `GET /api/campaigns`).
- Badge colors: Active=teal, Paused=amber, Upcoming=gray, Ended=dark gray.

**Campaign Dashboard:**
- Analytics tab pre-fetched al cargar la página (`enabled: true`, no lazy).
- Poll results: porcentaje + votos absolutos "45% (234 votos)".
- Commerce API key save unificado con el resto del formulario.
- **Tab "Live" ELIMINADO (Mar-09-2026):** Tabs actuales: Overview · Broadcasts · Components · Sponsors · Analytics · Settings. `EventsTab`, `ScheduledTab` y `Zap` icon removidos de `campaign-dashboard.tsx`.
- **Team logos en Overview tab (Mar-09-2026):** `OverviewTab.tsx` muestra logos de equipo (home/away) en cada broadcast card cuando `homeTeamLogo`/`awayTeamName` están disponibles. Componente `TeamLogo` definido en `OverviewTab.tsx`.

**Broadcasts (`/broadcasts`):**
- Viewer count desde `broadcast.viewerCount` directamente (no de metadata).
- Upcoming broadcasts muestran "Starts Mar 10 · 19:00".
- Icono `Users` para viewers, `BarChart3` para polls.
- Un solo search bar contextual; global header search oculto via `hideSearch` prop en `AppLayout`.
- Botón "Filter" dummy eliminado.

**Broadcast Detail (`/broadcasts/:id`):**
- Event timeline: progreso real `activeEvents / totalEvents * 100`. Botones Play/Skip/Maximize funcionales.
- Array `topValues` hardcodeado eliminado.
- Live chat deshabilitado (read-only) cuando `status='ended'` con banner informativo.
- **"Load Demo" button ELIMINADO** del header (Mar-09-2026). Ya no existe en producción.
- `POST /api/broadcasts/:broadcastId/trigger-shoppable-ad` — sin Bearer auth, dispara shoppable ad con log de sesión.
- **Header stats (Mar-09-2026):** Viewers · Total Votes · **Engagement Rate** (`Math.round(totalVotes / viewers * 100) + '%'`, muestra `'--'` si alguno es 0) · Status.
- **Poll vote label (Mar-09-2026):** "votos" → "votes". Formato: `(4,928 votes)`.
- **Sponsor slots endpoint (Mar-09-2026):** `POST /api/broadcasts/:id/sponsor-slots` ahora retorna `detail` con el mensaje real del error de DB (antes solo "Failed to create sponsor slot"). Usar `sponsorId=3` (Elkjøp) o `sponsorId=4` (Torshov) — `sponsorId=1` NO existe en la DB.
- **Contest edit modal (Mar-09-2026):** `ContestCard` tiene botón de lápiz (Pencil icon) que abre un Dialog de edición. Campos: Title, Description, Image (ImageUploadWithPreview — soporta upload a Object Storage y URL manual), Prize, Type (vote/trivia/prediction). Llama a `PUT /api/contests/:id` al guardar. Invalida `['/api/broadcasts', broadcastId, 'contests']` en cache.

**Sponsors (`/sponsors`):**
- Default colors al crear: `primaryColor: '#3d8b7a'`, `secondaryColor: '#141824'`.
- Labels "Primary" / "Secondary" visibles junto a los color pickers.
- SDK badge preview en tarjeta (rect redondeado con primaryColor, logo/iniciales y nombre).

**Components (`/components`):**
- Config preview por tipo: banner→thumbnail, countdown→fecha, carousel→cantidad productos.
- Badge "Test" si el nombre contiene "test".
- Altura dinámica (`min-h`, no `h-48`). isTemplate como boolean. Filtros `offer_banner`, `product_store`, `product_banner`. Botón usa `<Button>` de shadcn/ui.

**Analytics (`/analytics`):**
- `useChartTheme()` usa `useState` + `useEffect` + `MutationObserver` para detectar cambios de tema.
- Empty state cuando no hay datos: "No hay actividad de broadcasts en los últimos X días".
- Barras con mayor contraste en dark mode (`#3d8b7a`).
- KPI cards con subtexto explicativo ("X templates", "X activos").
- Back button en drill-down muestra nombre del destino ("← TV2 Demo App").
- Selector de período: Today / 7d / 30d.

**AppLayout:**
- Nueva prop `hideSearch: boolean` — oculta el search bar global del header en páginas con su propio search contextual (ej: `/broadcasts`).

**Create Broadcast modal (UI-01 — Mar 2026):**
- Modal rediseñado a `max-w-5xl` con dos secciones explícitas.
- **Sección 1 — Link Match Context** (top, prominente): grid de 3 columnas (liga, fecha, búsqueda) + lista scrollable de fixtures de Sportmonks. Cada fixture muestra logos de equipos (home/away), nombres y hora de kick-off. Estado seleccionado: borde azul + fondo tintado + checkmark. Al seleccionar → auto-rellena Broadcast Name y Start Time.
- **Liga dropdown restringido (Mar-09-2026):** Solo muestra 4 ligas: Champions League (2), Europa League (5), Premier League (8), La Liga (564). Filtro aplicado en frontend: `leagues.filter(l => [2, 5, 8, 564].includes(l.id))`. El endpoint `/api/sportmonks/leagues` sigue retornando todas las ligas del plan; el filtro es únicamente de presentación.
- **Sección 2 — Broadcast Information**: Broadcast Name (auto-filled), Campaign, Description, External Content ID (con helper text), Start/End Time side-by-side.
- Interfaces actualizadas para usar el formato del servidor: `startingAt`, `homeTeam.logoUrl`, `awayTeam.logoUrl` (no `participants`).
- `handleFixtureSelect` auto-rellena nombre y start time, respetando valores ya escritos por el operador.
- `externalId` incluido en el form y enviado al crear el broadcast.
- **Traducido a inglés (Mar-09-2026):** Toda la UI del modal está ahora en inglés. Labels, placeholders, empty states y botones. Ej: "Liga / Competición"→"League / Competition", "Seleccionar liga..."→"Select league...", "Fecha del partido"→"Match date", "Campaña *"→"Campaign *", "Cancelar"→"Cancel", "Crear Broadcast"→"Create Broadcast". Broadcasts List también traduce "votos"→"votes".

**Demo Data (NO MODIFICAR):**
- TV2 app (campaign 36, client_app id=18): `tv2-eliteserien-live-2026-03-08` (Brann vs Molde, ~18.7K viewers live). `barcelona-psg-2026-03-03` (ended, 34200 viewers, peak 41K, 3 polls, 1 contest, 11 matchEvents).
- Viaplay app (campaigns 35/33/31, client_app id=17): `viaplay-atletico-psg-2026-03-08` (live, 19.6K viewers, peak 24K, 3 polls 45.4K votes, 1 contest, 9 matchEvents, **3 sponsor slots**: id=21 min35 [19], id=11 min45 [17,18], id=22 min70 [20]). `real-madrid-vs-barcelona-2026-02-25` (ended, 29K viewers, peak 35K, 6 polls 68.1K votes, 2 contests, 11 matchEvents).
- Broadcasts con `created_at` distribuidos en los últimos 30 días para el chart de analytics.
- Viaplay apiKey: `viaplay_api_key_0c611e983b314ff8` → campaign 35. Commerce key: `KCXF10Y-W5T4PCR-GG5119A-Z64SQ9S`.
- **Sponsors DB:** SkiStar=id2, Elkjøp=id3 (commerceApiKey seeded), Torshov Sport=id4 (commerceApiKey seeded). Sponsor id=1 DOES NOT EXIST.
- **Broadcast products** (`viaplay-atletico-psg-2026-03-08`): id=17 (Barça jersey, Torshov), id=18 (PSG jersey, Torshov), id=19 (Samsung 75" TV, Elkjøp), id=20 (Samsung Soundbar, Elkjøp).
- client_app name was "VIaplay" (typo) → fixed to "Viaplay" in DB (Mar-09-2026).

**Commerce API key — moved to Sponsor level (Mar 2026):**
- `sponsors.commerceApiKey` + `sponsors.commerceChannelId` added to schema via `npm run db:push`.
- All shoppable ad routes now use `sponsor.commerceApiKey` (not `campaign.reachuApiKey`).
- Sponsor create/edit form includes Commerce API Key + Channel ID fields.
- `campaigns.reachuApiKey` / `campaigns.reachuChannelId` preserved in DB for backward compatibility but no longer the active source for shoppable ads.

**Sponsor Moments — 3-panel section (formerly "Shoppable Ads", renamed Mar-12-2026):**
- Panel 1 "Pre-programmed Slots": Add Slot dialog (sponsor, **slot type**, trigger type, auto-execute). Endpoints: `GET/POST /api/broadcasts/:id/sponsor-slots`, `DELETE /api/broadcasts/:id/sponsor-slots/:slotId`, `POST /api/broadcasts/:id/sponsor-slots/:slotId/execute`.
- Panel 2 "Quick Fire": sponsor dropdown + product from sponsor's Commerce catalog. Fires via `POST /api/broadcasts/:id/trigger-shoppable-ad` with Commerce key from `sponsor.commerceApiKey`.
- Panel 3 "Session Log": Tracks ad fire events for the current session.
- **Slot types** (`broadcast_sponsor_slots.type` varchar, default `'product'`): `product` (product picker), `lead` (title/fields/cta), `poll_cta` (pollId/message/cta), `contest_cta` (contestId/message/cta), `link` (url/title/cta). Each type stores its config in `broadcast_sponsor_slots.config` (JSONB). Type badge shown in slot list. Backward-compatible: existing slots have `type='product'`, `config={}`.

**EventTimeline — horizontal scrubber redesign (Mar 2026):**
- Completely replaced old vertical list with a horizontal 0'–90' scrubber.
- Takes `matchEvents` from `broadcast.metadata.matchEvents` (JSONB) + `broadcastStatus` as props alongside polls/contests.
- Colored dots: blue=poll, purple=contest, green=shoppable_ad, yellow=goal, grey=kickoff/fulltime.
- Minute labels at 0', 15', 30', 45', 60', 75', 90'. Half-time divider line at 50%.
- Hover tooltips with minute, event label, vote count (for polls).
- Stats row: "events fired" counter + "engagement events" counter.
- Bottom footer: total event count + match status (Live / 90' FT / Scheduled).

**Dashboard viewer count fix (Mar 2026):**
- Live Broadcasts table on the dashboard now reads `viewerCount` directly from `broadcast.viewerCount` column (was hardcoded `--`).

**Campaign → App linking fix (Mar 2026):**
- Campaign 36 (TV2 Barcelona-PSG) → linked to app 18 via `campaign.clientAppId`.
- Campaign 35 (Viaplay) → linked to app 17 (was already correct).

## Fixes & Features (Feb 2026)

- **admin.tsx:** `productForms`, `pollForms`, `contestForms` now initialize empty (single blank entry). No Apple/PSG hardcoded demo data. Forms still persist to DB via `/api/form-state`.
- **app-detail.tsx:** Stats cards no longer show fake trend badges (↑12%, ↑8%, etc.). Values are computed from real DB data.
- **broadcast-detail.tsx:** Zero hardcoded data. "Load Demo" button seeds demo data. "Send Live" buttons on polls and contests dispatch real-time WebSocket events to SDK clients.
- **campaign-dashboard.tsx:** Tabs reorganized to Overview | Broadcasts | Components | Sponsors | Analytics | Settings (tab "Live" added in Feb, removed Mar-09-2026). "New Broadcast" form includes "External Content ID" field. Broadcast cards have a pencil icon for inline editing.
- **EventsTab.tsx:** No demo data. Forms start empty and auto-save per campaign. Event Log panel removed. Campaign Logo section removed entirely.
- **SettingsTab.tsx (Feb 2026 — latest):** Removed Campaign Logo, Match Context, and UI Theme sections. Remaining 8 sections: Basic Information, Campaign Schedule, Channel Assignment (optional — "No channel" option available), Commerce Integration, Targeting & Segmentation, Engagement Settings, Feature Flags, Danger Zone. Fully restyled with raw divs + `border-white/10` (removed all shadcn Card usage). Style matches OverviewTab.
- **Commerce Integration (Feb 2026, updated Mar 2026):** "Reachu Integration" renamed to "Commerce Integration" in UI and docs. The Commerce API key was originally stored in `campaigns.reachuApiKey`, but as of Mar 2026 it is stored at the **sponsor level** (`sponsors.commerceApiKey` + `sponsors.commerceChannelId`). The key is exposed via `GET /v1/campaigns/:id/config` → `response.integrations.commerce.apiKey` so the SDK reads it dynamically. `integrations.commerce` block is always present in the response (`enabled: false` when no key configured).
- **Config endpoint `/v1/campaigns/:id/config` (Feb 2026):** Authorization now supports direct match (`campaign.clientAppId === clientApp.id`) OR channel legacy fallback. No longer returns 400 when campaign has no channel assigned. Channel references use optional chaining (`channel?.id`, `channel?.name`).
- **Brand data in SDK config:** `brand.name`, `brand.iconUrl`, `brand.logoUrl` come from the linked Sponsor. Legacy campaign brand fields used only as fallback.

## SDK contentId Architecture (Feb 2026)

### vio-config.json — ONE Vio App API Key only
```json
{
  "apiKey": "<Vio App API Key>",
  "restAPIBaseURL": "https://api-dev.vio.live",
  "webSocketBaseURL": "https://api-dev.vio.live"
}
```
- `apiKey` = `client_apps.api_key` in the DB — identifies the client (Viaplay, XXL, etc.)
- Used for ALL Vio endpoints: `/v1/sdk/*`, `/v1/campaigns/*/config`, `/v1/engagement/*`, `/v1/offers`
- NO `campaignAdminApiKey`, NO `campaignApiKey`. One key for everything Vio.
- The Commerce key is NOT in this file — delivered dynamically by the server via `/v1/campaigns/{id}/config`.

### SDK Initialization Flow (4 steps)

**Step 1 — App launch:**
```
GET /v1/sdk/campaigns?apiKey=<key>
```
Returns all active campaigns + campaign-level components (banners, carousels). Shown regardless of what the user is watching.

**Step 2 — Campaign config (on launch or campaign switch):**
```
GET /v1/campaigns/{id}/config?apiKey=<key>
```
Returns dynamic campaign config. The `integrations.commerce` block is **always** present:
```json
{
  "integrations": {
    "commerce": {
      "enabled": true,
      "apiKey": "COMMERCE-KEY-HERE",
      "channelId": "commerce-channel-id"
    }
  }
}
```
- `enabled: true` → SDK initializes Commerce module with that key.
- `enabled: false` (apiKey is null) → do not initialize Commerce module.
- Source in DB (Mar 2026+): `sponsors.commerceApiKey` + `sponsors.commerceChannelId` (from the sponsor linked to the campaign). `campaigns.reachuApiKey` preserved in DB for backward compatibility but no longer the active source.
- The Commerce key comes from the server — the SDK uses it to call the external Commerce system directly, bypassing the Vio backend. Vio is a secure key distributor only.

**Step 3 — Stream open:**
```
GET /v1/sdk/broadcast?contentId={id}&country={CC}&apiKey=<key>
```
Resolves `contentId` → `broadcasts.externalId` → campaign. Returns `hasEngagement: true/false`.
`externalId` is set by the admin in the "External Content ID" field when creating/editing a broadcast.

Response when `hasEngagement: true`:
```json
{
  "hasEngagement": true,
  "broadcastId": "...",
  "broadcastName": "...",
  "status": "live",
  "campaignId": 42,
  "websocketChannel": "/ws/42",
  "campaignComponents": [...],
  "broadcastComponents": {
    "chat": { "enabled": true },
    "polls": [{ "id": 1, "question": "...", "isActive": true, "duration": 60, "options": [...] }],
    "contests": [{ "id": 2, "title": "...", "isActive": true }]
  }
}
```
Cache: `hasEngagement: false` → `public, max-age=30`; `hasEngagement: true` → `private, max-age=10` + ETag.

**Step 4 — Real-time interaction:**
- WebSocket: `wss://api-dev.vio.live/ws/{campaignId}` — events: `poll_created`, `broadcast_started`, `broadcast_ended`, etc.
- Vote: `POST /v1/engagement/polls/{id}/vote?apiKey=<key>`
- Contest: `POST /v1/engagement/contests/{id}/participate?apiKey=<key>`
- Always the same single Vio App API Key.

### WS events for broadcast lifecycle
- `broadcast_started` → fired when `status` changes to `'live'` on any PUT broadcast route
- `broadcast_ended` → fired when `status` changes to `'ended'` on any PUT broadcast route

## Deployment & Scaling Architecture

### Estado actual (Feb 2026) — `autoscale` deployment target

El servidor corre en modo **Autoscale** (`deploymentTarget = "autoscale"`). Este es el target que funciona de forma estable en Replit para este proyecto.

**Historial de la decisión:** Se intentó `vm` (Always-On) en múltiples ocasiones. El servidor arrancaba correctamente (puerto abierto en ~320ms, app lista en ~1.7s), corría sin errores durante 60+ segundos con el scheduler funcionando — pero el health check de Replit seguía marcando el deployment como fallido sin una razón técnica clara en los logs. El `autoscale` resolvió el problema inmediatamente en el primer intento.

**Run command actual:** `node dist/index.js` (usa el auto-start code en `server/index.ts` que enlaza el puerto antes de cargar las rutas).
**Build command:** `npm run build` (Vite + esbuild frontend + backend).

#### Comportamiento en autoscale (instancia única actual)
- WebSockets funcionan porque hay una sola instancia (sin problema de cross-instance broadcasting)
- El scheduler (`server/scheduler.ts`) vive en RAM de esa instancia — funciona igual que en `vm`
- Si el tráfico sube y Replit escala a múltiples instancias, aparecen los bloqueantes documentados abajo

#### Bloqueante al escalar — WebSockets con estado
Los WebSockets son conexiones TCP persistentes atadas a una instancia de servidor específica. Si el SDK del cliente A está conectado a la instancia 1, y el dashboard admin dispara un evento desde la instancia 2, el cliente A nunca recibe el mensaje.

Flujo actual:
```
Admin (dashboard) → POST /api/broadcasts/:id/chat
                 → broadcastToCampaign(campaignId, event) [in-process]
                 → wss://host/ws/42 → todos los SDKs conectados ✅
```

Con múltiples instancias sin solución:
```
Admin → Instancia 2 → broadcastToCampaign() → solo SDKs en instancia 2 ❌
                                             → SDKs en instancia 1 NO reciben ❌
```

#### Bloqueante al escalar — Scheduler en memoria
`server/scheduler.ts` es un `setInterval` que vive en RAM. Con múltiples instancias, cada instancia tendría su propio scheduler duplicado activando/desactivando componentes varias veces.

---

### Opciones para escalar (sin implementar, "puerta abierta")

#### Opción A — Redis Pub/Sub + BullMQ (camino más limpio)
**Nivel de esfuerzo: medio**

Reemplazar `broadcastToCampaign()` en memoria por publicación en un canal Redis. Cada instancia se suscribe a Redis y reenvía los mensajes a sus clientes WebSocket locales.

```
Admin → Instancia 2 → Redis PUBLISH ws:campaign:42 → Instancia 1 (suscrita) → SDKs ✅
                                                     → Instancia 2 (suscrita) → SDKs ✅
```

Para el scheduler: usar **BullMQ** (ya está parcialmente preparado — hay un `QueueAdapter` en el código con `USE_QUEUE=true` como flag). BullMQ usa Redis y garantiza que los jobs se ejecutan una sola vez aunque haya múltiples instancias.

**Cambios requeridos:**
- `server/routes.ts`: `broadcastToCampaign` publica en Redis en lugar de iterar websockets locales
- `server/scheduler.ts`: migrar a BullMQ jobs con `removeOnComplete`
- Nueva variable de entorno: `REDIS_URL`
- El WebSocket server sigue en cada instancia, pero actúa solo como "último tramo" desde Redis

#### Opción B — Servicio WebSocket dedicado (separación de responsabilidades)
**Nivel de esfuerzo: alto**

Mantener un servidor `vm` pequeño dedicado solo a WebSockets. Las instancias autoscale del API le notifican vía HTTP interno cuando ocurre un evento.

```
Admin → API (autoscale) → POST ws-server.internal/notify → WS Server (vm) → SDKs ✅
```

Ventaja: el API es completamente stateless. Desventaja: complejidad operacional, dos servicios que mantener.

#### Opción C — WebSocket as a Service (Pusher / Ably / Soketi)
**Nivel de esfuerzo: bajo, pero dependencia externa**

Delegar los WebSockets a un servicio externo. El backend solo llama a su API REST para hacer broadcast; no mantiene conexiones.

```
Admin → API (autoscale) → Pusher.trigger("campaign-42", "poll", data) → SDKs ✅
```

El SDK iOS conecta directamente a Pusher/Ably en lugar de al servidor Vio. Requiere cambios en el SDK iOS.

---

### Lo que ya está preparado en el código

| Pieza | Estado | Notas |
|-------|--------|-------|
| BullMQ queue adapter | ✅ Código existe | Activar con `USE_QUEUE=true` env var |
| `broadcastToCampaign()` exportada | ✅ | Función aislada, fácil de reemplazar con Redis publish |
| `QueueAdapter` pattern | ✅ | `server/queue/` ya abstrae el proveedor |
| Redis no configurado | ❌ | Añadir `REDIS_URL` y librerías `ioredis` |
| WS broadcasting acoplado al proceso | ❌ | `broadcastToCampaign` itera sobre `wss.clients` local |

### Decisión actual
**Autoscale, instancia única, sin escalar por ahora.** Para el tráfico actual una sola instancia es suficiente y los WebSockets/scheduler funcionan correctamente. Cuando sea necesario escalar, **Opción A (Redis Pub/Sub + BullMQ)** es el camino recomendado porque:
- Mantiene la arquitectura WebSocket nativa (sin cambios en el SDK iOS)
- BullMQ ya está parcialmente integrado
- Redis es compatible con Replit Secrets y Neon Stack

## Fixes & Features (Mar 2026 — Session 5 — UI-07 + UI-08: Lineup)

### UI-07 — Lineup Endpoints

- **`GET /api/broadcasts/:broadcastId/lineup`** — Dashboard endpoint. Returns `{ available, home, away }` where each team has `{ teamName, formation, players[] }`. Players have `{ id, name, jerseyNumber, position }`. Position mapping: `G` → `goalkeeper`, `D` → `defender`, `M` → `midfielder`, `F/A` → `attacker`.
- **`GET /v1/sdk/broadcasts/:broadcastId/lineup`** — SDK endpoint (API Key auth). Same response shape.
- **Cache:** `cacheType = 'lineup_{fixtureId}'`, TTL = 30 min. Stored in `sportmonks_cache`.
- **Team ID resolution:** `homeTeamId` and `awayTeamId` are read from `broadcasts.metadata.homeTeamId/awayTeamId` (set when operator selects a fixture in the Create Broadcast modal — `broadcasts.tsx` writes `metadata.homeTeamId/awayTeamId` from Sportmonks `participants[]`). Fallback: splits players by first two distinct `team_id` values in the Sportmonks lineups response.
- **LineupSection component** (`broadcast-detail.tsx`) — Displayed after MatchDataCard. Shows home/away player lists with jersey numbers and position icons. Refresh button triggers manual refetch.

### UI-08 — Show Lineup Toggle + Send Lineup Now

- **Schema additions:**
  - `broadcasts.showLineup` — `boolean("show_lineup").notNull().default(false)`. Controls whether lineup is delivered to SDK viewers.
  - `broadcasts.startedAt` — `timestamp("started_at")`. Auto-set to `NOW()` when broadcast status transitions to `'live'` for the first time (via `PUT /api/broadcasts/:id`).
- **`PUT /api/broadcasts/:broadcastId`** — Now accepts `showLineup: boolean`. Auto-sets `startedAt` on first `status → 'live'` transition if `startedAt` is null.
- **`POST /api/broadcasts/:broadcastId/send-lineup`** — Manual trigger. Sends `lineup_show` WS event to all SDK clients on the campaign channel. Requires `showLineup = true` and `sportmonksFixtureId` linked. `videoTimestamp = max(0, kickoffVideoTimestamp - 600)` (10 min lead). Tracked in-memory via `lineupSentMap`.
- **LineupSection upgraded:** Toggle "Show lineup to viewers" (calls PUT with `showLineup`) + "Send lineup now" button (calls send-lineup POST) + "Not yet sent / Sent at HH:MM" status. Button disabled when toggle is OFF.
- **WS event payload to SDK:**
  ```json
  { "type": "lineup_show", "videoTimestamp": 1800, "kickoffVideoTimestamp": 2400,
    "broadcastId": "...", "leadTimeSeconds": 600, "timestamp": "..." }
  ```

## Fixes & Features (Mar 2026 — Session 4)

### TASK-SPORTMONKS-DEFINITIVE — Fix definitivo de cache y filtrado por liga

- **TTL diferenciado:** `FIXTURE_CACHE_TTL_MS = 6h`, `LEAGUE_CACHE_TTL_MS = 2d`. Antes ambos usaban 2 días. Función `isCacheValidFor(cache, ttlMs)` reemplaza la anterior `isCacheValid`.
- **`?leagues=X` eliminado de la URL:** El parámetro no filtra correctamente en el plan actual de Sportmonks (devuelve fixtures de otras ligas). Ahora el servidor fetch todos los fixtures del día con `/fixtures/between/${dateFrom}/${dateTo}?per_page=150&include=participants` y filtra server-side con `f.league_id === leagueId`.
- **Cache limpio:** Solo los fixtures ya filtrados se guardan en `sportmonks_cache`. Datos contaminados previos eliminados (`DELETE FROM sportmonks_cache WHERE cache_type='fixtures'` — 11 filas).
- **`leagueId` incluido en fixture response:** Cada fixture ahora incluye `leagueId: f.league_id` en el objeto retornado, confirmando el filtro correcto.
- **Verificado:** CL 2026-03-10 → 4 fixtures, todos `leagueId=2`. Championship → 6 fixtures, cero contaminación. Segunda llamada → 38ms (cache hit) vs 584ms (API call).

## Fixes & Features (Mar 2026 — Session 2)

### TASK-UI-02 — Match Data & Sportmonks Integration

- **`GET /api/sportmonks/fixture/:fixtureId/result`** — New endpoint. Returns structured match result: `{ fixtureId, homeTeam, awayTeam, homeScore, awayScore, status, date, league, events[] }`. Events filtered to key types only (no substitutions). In-memory cache: 30s when live, 5min when FT.

- **MatchDataCard** (`client/src/components/match-data-card.tsx`) — New component rendered after EventTimeline in broadcast detail. Shows scoreboard (team logos + score), match date, league name, and a visual timeline of key events (goals, cards, HT, FT). Returns null if no `sportmonksFixtureId`. Manual refresh button. Queries Sportmonks every 60s when broadcast is live.

- **EventTimeline — Sportmonks event fusion** — The `mergedMatchEvents` computed value in `BroadcastDetailPage` merges:
  - Sportmonks events (goals, cards, kickoff, fulltime) → authoritative for match-day event types
  - `broadcast.metadata.matchEvents` (polls, contests, shoppable_ads) → authoritative for engagement events
  - Result sorted by minute, passed to EventTimeline. Falls back to pure metadata if no Sportmonks data.

- **MatchDataSection removed** — The old manual score form (home/away team names, score inputs, minute, status dropdown, "Update Score & Send Live" button) has been fully replaced by MatchDataCard.

- **Create Broadcast — required fields** — Submit button now disabled unless `selectedFixture` and `externalId` are both set. Prevents creating broadcasts without a linked Sportmonks fixture and Content ID.

## Fixes & Features (Mar 2026 — Session 7 — TASK-ZERO-CONFIG-BACKEND)

### Task 1 — `GET /v1/sdk/config` zero-config

Endpoint rewritten. No longer requires `campaignId` parameter.

**New behavior:**
1. Authenticates via `?apiKey=` (existing `validateApiKey` middleware)
2. Auto-detects active campaign: `getClientAppCampaigns(clientApp.id)` → first `status='active'` with dates valid today → fallback to most recent
3. Commerce key: first `sponsor.commerceApiKey` from campaign sponsors → fallback to `campaign.reachuApiKey`
4. Endpoints block: `restBase` + `webSocketBase` computed from `req.protocol://req.get('host')`

**Response shape (actual):**
```json
{
  "clientApp": { "id": 17, "name": "Viaplay", "apiKey": "<Vio App API Key>" },
  "endpoints": {
    "restBase": "https://api-dev.vio.live",
    "webSocketBase": "wss://api-dev.vio.live",
    "commerceGraphQL": "https://graph-ql-dev.vio.live/graphql"
  },
  "features": { "engagement": true, "adPlacements": true, "commerce": true, "lineup": true },
  "commerce": { "apiKey": "KCXF10Y-...", "endpoint": "https://graph-ql-dev.vio.live/graphql" },
  "theme": { "primaryColor": null, "accentColor": null },
  "markets": []
}
```
Note: `commerce` is `null` when no Commerce API key is configured. `features.commerce` mirrors this as a boolean flag.

Verified: `GET /v1/sdk/config?apiKey=viaplay_api_key_0c611e983b314ff8` → clientApp id=17, campaign 35, `commerce.apiKey = "KCXF10Y-..."` ✅

### Task 2 — UI rename: "Shoppable Ads" / "Shoppable Products" → "Sponsor Moments"

Changed in `client/src/pages/broadcast-detail.tsx`:
- `ShoppableProductsSection` h2: "Shoppable Products" → "Sponsor Moments"
- `ShoppableAdTriggerSection` h2: "Shoppable Ads" → "Sponsor Moments"
- Dialog description: "Pre-program a shoppable ad" → "Pre-program a sponsor moment"

Not changed: component names, data-testid attributes, API endpoints, DB table names.

### Task 3 — Sponsor Moment slot types

**Schema:** `broadcast_sponsor_slots.type` varchar(50) DEFAULT `'product'`; `broadcast_sponsor_slots.config` JSON DEFAULT `'{}'`. Columns already existed in DB — added to Drizzle schema definition and explicit SELECT lists in `getBroadcastSponsorSlots` (plural) and `getBroadcastSponsorSlot` (singular).

**Five slot types:**
| Type | Config fields |
|------|---------------|
| `product` | `productIds[]` (existing picker) |
| `lead` | `title`, `fields` (email/phone/name), `cta` |
| `poll_cta` | `pollId`, `message`, `cta` |
| `contest_cta` | `contestId`, `message`, `cta` |
| `link` | `url`, `title`, `cta` |

**UI:** Dialog has a type dropdown + dynamic field section per type. Slot list shows a type badge. Backward-compatible: existing rows return `type='product'`, `config={}`.

### TASK-BACKEND-REVIEW — 4 bugs fixed (also this session)

1. **`fetchLineupData` split:** Pure data-fetching function using `sportmonksFetch`; thin `fetchLineup` wrapper. Eliminates silent auth failure on cold start.
2. **Lineup stampede prevention:** `lineupInFlight = new Map<string, Promise<any>>()` — N concurrent cache-miss requests collapse into 1 Sportmonks call.
3. **`fixtureResultCache` LRU:** Eviction at 200 entries (FIFO on Map insertion order).
4. **Scheduler N+1 eliminated:** `processScheduledPolls` / `processScheduledContests` use 1 JOIN query each. New storage methods: `getScheduledPollsForLiveBroadcasts()` and `getScheduledContestsForLiveBroadcasts()`.

## Architect Review Notes (Feb 2026)

Pending improvements identified by architecture review:
1. **Critical:** Migrate varchar boolean flags to proper `boolean` columns with defaults and NOT NULL
2. **Critical:** Remove default JWT secret fallback — should hard-fail if `SESSION_SECRET` is missing
3. **Important:** Add missing indexes on high-fanout FK columns used by analytics queries
4. **Important:** Wrap multi-step storage operations in database transactions
5. **Important:** Audit and enforce auth consistently across all route groups
6. **Minor:** Restrict CORS in production
7. ~~**Minor:** Optimize scheduler to avoid N+1 query patterns~~ — **DONE** (Session 7: JOIN-based scheduler methods)
