# SDK Infrastructure - Documentacion Completa para Cursor
# Ultima actualizacion: 2026-02-09
# Version: 3.0 - Fases 5 y 6 ACTIVAS (Video Scheduling + Queue + Rate Limiting)

## Indice

1. [Arquitectura General](#arquitectura-general)
2. [Jerarquia de Datos](#jerarquia-de-datos)
3. [Base de Datos - Todas las Tablas](#base-de-datos)
4. [Autenticacion](#autenticacion)
5. [Endpoints SDK (para Swift/iOS)](#endpoints-sdk)
6. [Endpoints Admin (Dashboard)](#endpoints-admin)
7. [Eventos WebSocket](#eventos-websocket)
8. [Sistema de Broadcasts](#sistema-de-broadcasts)
9. [Sistema de Engagement (Polls y Contests)](#sistema-de-engagement)
10. [Configuracion Dinamica](#configuracion-dinamica)
11. [Scheduler / Cron Jobs](#scheduler)
12. [Paginas del Dashboard](#paginas-dashboard)
13. [Flujos Completos](#flujos-completos)
14. [Servicios Extraidos](#servicios)
15. [Middleware Activo](#middleware)
16. [Sistema de Colas - Adapter Pattern](#queue-system)
17. [Video Scheduling (Activo)](#video-scheduling)
18. [Rate Limiting (Activo)](#rate-limiting)
19. [Componentes UI de Scheduling](#scheduling-ui)
20. [Variables de Entorno](#variables-entorno)
21. [Guia de Transicion a Produccion (Redis)](#produccion)

---

## 1. Arquitectura General <a name="arquitectura-general"></a>

```
┌─────────────────────────────────────────────────────────────┐
│                      FRONTEND (React + Vite)                │
│  Puerto 5000 - Tailwind CSS + shadcn/ui + TanStack Query    │
│  Routing: Wouter | Real-time: useWebSocket hook             │
├─────────────────────────────────────────────────────────────┤
│                      BACKEND (Express.js)                   │
│  Puerto 5000 (mismo puerto) | CORS habilitado               │
│  Auth: JWT Bearer (admin) + API Key (SDK)                   │
├─────────────────────────────────────────────────────────────┤
│                      WebSocket Server (ws)                  │
│  Canales aislados por campaign: /ws/:campaignId             │
├─────────────────────────────────────────────────────────────┤
│                      PostgreSQL (Neon)                      │
│  ORM: Drizzle | 19 tablas | Schemas: Zod                   │
├─────────────────────────────────────────────────────────────┤
│                      Object Storage (Replit)                │
│  Logos, imagenes de campanas                                │
├─────────────────────────────────────────────────────────────┤
│                      Scheduler Service                      │
│  Cron cada 1 minuto: componentes + broadcasts +             │
│  polls/contests (video scheduling activo)                   │
├─────────────────────────────────────────────────────────────┤
│              ✅ Message Queue (Adapter Pattern)              │
│  SimpleQueueAdapter (in-memory) activo ahora                │
│  BullMQAdapter (Redis) listo para produccion                │
├─────────────────────────────────────────────────────────────┤
│              ✅ Rate Limiter (Adapter Pattern)               │
│  SimpleRateLimiter (in-memory Map) activo ahora             │
│  RedisRateLimiter (sliding window sorted sets) para prod    │
└─────────────────────────────────────────────────────────────┘
```

**Stack Tecnologico:**
- Runtime: Node.js + TypeScript
- Frontend: React 18 + Vite + Tailwind CSS + shadcn/ui
- Backend: Express.js
- Base de datos: PostgreSQL (Neon Serverless)
- ORM: Drizzle ORM
- Validacion: Zod
- Real-time: WebSocket (`ws` library)
- State Management: TanStack Query v5
- Routing: Wouter

**Estructura de Archivos Completa:**
```
server/
├── index.ts                    # Entry point (inicializa workers si USE_QUEUE=true)
├── routes.ts                   # Todos los endpoints API y SDK
├── storage.ts                  # Interface de storage + implementacion PostgreSQL
├── scheduler.ts                # Cron jobs (componentes + broadcasts + polls/contests scheduling)
├── vite.ts                     # Configuracion Vite
├── queue/                      # ✅ Sistema de colas ACTIVO (Adapter Pattern)
│   ├── queue-adapter.ts        # SimpleQueueAdapter + BullMQAdapter
│   ├── types.ts                # Tipos: VoteJobData, ContestParticipationJobData, etc.
│   ├── queues.ts               # voteQueue, contestParticipationQueue, broadcastStatusQueue
│   └── workers.ts              # Workers: vote-processing, contest-participation
├── services/                   # ✅ Logica extraida FUNCIONAL
│   ├── vote-processor.ts       # processPollVoteSync + WebSocket broadcast
│   └── contest-processor.ts    # processContestParticipationSync
├── middleware/                  # ✅ Middleware ACTIVO
│   ├── rate-limiter.ts         # SimpleRateLimiter (in-memory) + RedisRateLimiter
│   └── broadcast-validator.ts  # Validacion de broadcastId (funcional)
└── utils/
    └── scheduling.ts           # Calculo de timestamps relativos al video

shared/
└── schema.ts                   # Modelos Drizzle + Zod schemas (19 tablas)

client/src/
├── pages/
│   ├── campaigns.tsx           # Lista de campanas
│   ├── campaign-dashboard.tsx  # Dashboard de campana (tabs)
│   ├── broadcasts.tsx          # Lista de broadcasts
│   ├── broadcast-detail.tsx    # Detalle broadcast (tabs: overview, polls, contests)
│   ├── components.tsx          # Libreria de componentes
│   └── ...
└── components/
    └── scheduling/             # Componentes de scheduling (preparados, no integrados)
        ├── SchedulingForm.tsx   # Formulario de scheduling
        ├── VideoTimeInput.tsx   # Input de tiempo video
        └── TimelineView.tsx    # Vista de timeline visual
```

---

## 2. Jerarquia de Datos <a name="jerarquia-de-datos"></a>

```
Users (agencias/marcas)
  └── Client Apps (aplicaciones moviles/web)
       └── Channels (canales de marketing)
            └── Campaigns (campanas de eventos)
                 ├── Components (componentes UI)
                 ├── Events (productos, polls, contests legados)
                 ├── Broadcasts (transmisiones/partidos)
                 │    ├── Polls (encuestas) ← con video scheduling activo
                 │    │    ├── Poll Options (opciones)
                 │    │    └── Poll Votes (votos) ← rate limited + queue-ready
                 │    └── Contests (concursos) ← con video scheduling activo
                 │         └── Contest Participations ← rate limited + queue-ready
                 ├── Engagement Config
                 ├── UI Config
                 ├── Feature Flags
                 └── Translations
```

**Relaciones clave:**
- Un User tiene muchas Client Apps
- Una Client App tiene muchos Channels
- Un Channel tiene muchas Campaigns
- Una Campaign tiene muchos Broadcasts (opcional)
- Un Broadcast tiene muchos Polls y Contests
- Un Poll tiene muchas Options y Votes
- Un Contest tiene muchas Participations

---

## 3. Base de Datos - Todas las Tablas <a name="base-de-datos"></a>

### 3.1 `users`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| reachu_user_id | varchar(255) UNIQUE | ID externo del usuario |
| email | text | Email opcional |
| name | text | Nombre opcional |
| firebase_token | text | Token FCM para push notifications |
| created_at | timestamp | Fecha de creacion |

### 3.2 `client_apps`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| user_id | integer FK→users | Propietario |
| name | varchar(255) | Nombre de la app |
| bundle_id | varchar(255) UNIQUE | Bundle ID (com.example.app) |
| api_key | text UNIQUE | API Key para autenticacion SDK |
| reachu_api_key | text | API Key de Reachu (opcional) |
| created_at | timestamp | Fecha de creacion |

### 3.3 `channels`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| client_app_id | integer FK→client_apps | App propietaria |
| name | varchar(255) | Nombre del canal |
| description | text | Descripcion |
| dynamic_config | json | Configuracion dinamica |
| created_at | timestamp | Fecha de creacion |

### 3.4 `campaigns`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| user_id | integer FK→users | Propietario |
| channel_id | integer FK→channels | Canal asociado |
| name | varchar(255) | Nombre de la campana |
| logo | text | URL del logo |
| description | text | Descripcion |
| start_date | timestamp | Fecha de inicio |
| end_date | timestamp | Fecha de fin |
| is_paused | varchar(10) | 'true'/'false' - estado de pausa |
| reachu_channel_id | varchar(255) | ID canal Reachu |
| reachu_api_key | text | API Key Reachu |
| tipio_liveshow_id | varchar(255) | ID de Tipio Liveshow |
| tipio_livestream_data | json | Datos de livestream |
| is_segmented | varchar(10) | 'true'/'false' - targeting activo |
| target_countries | text[] | Paises objetivo (ISO codes) |
| target_percentage | integer | Porcentaje de usuarios (1-100) |
| match_id | varchar(255) | ID del partido/match |
| match_name | varchar(255) | Nombre del partido |
| match_start_time | timestamp | Inicio del partido |
| brand_name | varchar(255) | Nombre de marca |
| brand_icon_asset | varchar(255) | Asset del icono de marca |
| brand_icon_url | text | URL del icono de marca |
| brand_logo_url | text | URL del logo de marca |
| created_at | timestamp | Fecha de creacion |

### 3.5 `broadcasts`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| broadcast_id | varchar PK | Slug auto-generado (ej: "barcelona-psg-2025-01-23") |
| broadcast_name | varchar(255) | Nombre del broadcast |
| campaign_id | integer FK→campaigns | Campana asociada (opcional) |
| channel_id | integer FK→channels | Canal asociado (opcional) |
| start_time | timestamp | Hora de inicio |
| end_time | timestamp | Hora de fin |
| status | varchar(50) | 'upcoming', 'live', 'ended' |
| metadata | json | Datos adicionales |
| created_by | integer FK→users | Usuario creador |
| created_at | timestamp | Fecha de creacion |
| updated_at | timestamp | Ultima actualizacion |

### 3.6 `polls`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| broadcast_id | varchar FK→broadcasts | Broadcast asociado |
| question | text | Pregunta de la encuesta |
| start_time | timestamp | Inicio (opcional) |
| end_time | timestamp | Fin (opcional) |
| is_active | boolean | Si esta activa (default: true) |
| total_votes | integer | Contador de votos totales |
| video_start_time | integer | Segundos desde inicio del video |
| video_end_time | integer | Segundos desde inicio del video |
| broadcast_start_time | timestamp | Timestamp del inicio del broadcast |
| scheduled_start_time | timestamp | Calculado: broadcastStartTime + videoStartTime |
| scheduled_end_time | timestamp | Calculado: broadcastStartTime + videoEndTime |
| created_at | timestamp | Fecha de creacion |
| updated_at | timestamp | Ultima actualizacion |

### 3.7 `poll_options`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| poll_id | integer FK→polls | Encuesta padre |
| text | varchar(255) | Texto de la opcion |
| vote_count | integer | Contador de votos |
| display_order | integer | Orden de presentacion |
| created_at | timestamp | Fecha de creacion |

### 3.8 `poll_votes`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| poll_id | integer FK→polls | Encuesta votada |
| option_id | integer FK→poll_options | Opcion seleccionada |
| user_id | varchar | ID del usuario que voto |
| broadcast_id | varchar | Broadcast del contexto |
| created_at | timestamp | Fecha del voto |
| **UNIQUE** | (poll_id, user_id) | Un voto por usuario por encuesta |

### 3.9 `contests`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| broadcast_id | varchar FK→broadcasts | Broadcast asociado |
| title | varchar(255) | Titulo del concurso |
| description | text | Descripcion |
| prize | varchar(255) | Premio |
| contest_type | varchar(50) | 'quiz', 'giveaway', 'trivia', 'prediction' |
| start_time | timestamp | Inicio (opcional) |
| end_time | timestamp | Fin (opcional) |
| is_active | boolean | Si esta activo (default: true) |
| video_start_time | integer | Segundos desde inicio del video |
| video_end_time | integer | Segundos desde inicio del video |
| broadcast_start_time | timestamp | Timestamp del inicio del broadcast |
| scheduled_start_time | timestamp | Calculado: broadcastStartTime + videoStartTime |
| scheduled_end_time | timestamp | Calculado: broadcastStartTime + videoEndTime |
| created_at | timestamp | Fecha de creacion |
| updated_at | timestamp | Ultima actualizacion |

### 3.10 `contest_participations`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| contest_id | integer FK→contests | Concurso |
| user_id | varchar | ID del participante |
| broadcast_id | varchar | Broadcast del contexto |
| answers | json | Respuestas (para quiz) |
| created_at | timestamp | Fecha de participacion |
| **UNIQUE** | (contest_id, user_id) | Una participacion por usuario |

### 3.11 `components`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | varchar PK (UUID) | ID unico generado |
| type | varchar(100) | Tipo (Banner, Countdown, Carousel, etc.) |
| name | varchar(255) | Nombre del componente |
| config | json | Configuracion del componente |
| is_template | varchar(10) | 'true'/'false' - si es plantilla |
| created_at | timestamp | Fecha de creacion |

### 3.12 `campaign_components`
| Columna | Tipo | Descripcion |
|---------|------|-------------|
| id | serial PK | ID auto-incremental |
| campaign_id | integer FK→campaigns | Campana |
| component_id | varchar FK→components | Componente |
| instance_name | varchar(255) | Nombre de instancia |
| status | varchar(20) | 'active', 'inactive' |
| custom_config | json | Config personalizada |
| scheduled_time | timestamp | Activacion programada |
| end_time | timestamp | Desactivacion programada |
| activated_at | timestamp | Cuando fue activado |
| match_id | varchar(255) | Match asociado |
| video_start_time | integer | Segundos desde inicio del video |
| video_end_time | integer | Segundos desde inicio del video |
| scheduled_start_time | timestamp | Calculado para activacion |
| scheduled_end_time | timestamp | Calculado para desactivacion |
| updated_at | timestamp | Ultima actualizacion |

### 3.13-3.18 Tablas de configuracion
- **`events`**: Eventos de campana (product, poll, contest)
- **`campaign_form_state`**: Estado de formularios del dashboard
- **`scheduled_components`**: Componentes programados
- **`campaign_translations`**: Traducciones de sponsor badge
- **`campaign_engagement_config`**: Config de engagement (duracion polls, demo mode, etc.)
- **`campaign_ui_config`**: Tema UI (colores primarios/secundarios)
- **`campaign_feature_flags`**: Feature flags (streaming, catalog, engagement, polls, contests)
- **`sdk_translations`**: Traducciones SDK por idioma/campana/match

---

## 4. Autenticacion <a name="autenticacion"></a>

### 4.1 Bearer Token (JWT) - Para Admin/v1 endpoints

```
POST /api/auth/token
Body: { "reachuUserId": "user123" }
Response: { "token": "eyJhbGciOi...", "expiresIn": "7d" }
```

- Algoritmo: HS256
- Secret: `SESSION_SECRET` (env var)
- Expiracion: 7 dias
- Header: `Authorization: Bearer <token>`
- Se usa en todos los endpoints `/v1/broadcasts`, `/v1/polls`, `/v1/contests`

### 4.2 API Key - Para SDK endpoints

```
GET /v1/sdk/campaigns?apiKey=<api_key>
# O via header:
GET /v1/sdk/campaigns
X-Api-Key: <api_key>
# O via Bundle ID:
GET /v1/sdk/campaigns
X-App-Bundle-ID: com.example.app
```

- La API Key se genera al crear un Client App
- Se valida contra la tabla `client_apps.api_key`
- Se usa en endpoints `/v1/sdk/*`, `/v1/offers`, `/v1/campaigns/*/config`, `/v1/engagement/config`, `/v1/localization/*`

### 4.3 Sin Auth - Dashboard interno

- Los endpoints `/api/*` (excepto `/api/auth/token`) no requieren autenticacion
- Proteccion por sesion simulada en el frontend (localStorage `reachu_simulated_user_id`)

---

## 5. Endpoints SDK (para Swift/iOS) <a name="endpoints-sdk"></a>

Estos son los endpoints que consume el SDK de iOS. Cursor necesita conocer cada uno para implementar las llamadas desde Swift.

### 5.1 Auto-Discovery de Campanas

```http
GET /v1/sdk/campaigns?apiKey=<key>&matchId=<optional>
Authorization: API Key (query param, header, o Bundle ID)

Response 200:
[
  {
    "id": 1,
    "name": "Champions League Final",
    "logo": "https://...",
    "startDate": "2025-01-23T20:00:00Z",
    "endDate": "2025-01-23T23:00:00Z",
    "isPaused": "false",
    "matchContext": {
      "matchId": "match-123",
      "matchName": "Barcelona vs PSG",
      "startTime": "2025-01-23T20:00:00Z"
    },
    "components": [
      {
        "id": "uuid",
        "type": "ProductSpotlight",
        "name": "Sponsor Product",
        "status": "active",
        "config": { ... }
      }
    ]
  }
]
```

### 5.2 Configuracion SDK

```http
GET /v1/sdk/config?apiKey=<key>&campaignId=<id>
Authorization: API Key

Response 200:
{
  "campaignId": 1,
  "campaignName": "Champions League Final",
  "channelId": 1,
  "channelName": "XXL Home",
  "components": [ ... ],
  "deeplinks": { ... },
  "branding": { ... },
  "matchContext": { ... }
}
```

### 5.3 Configuracion Dinamica Completa

```http
GET /v1/campaigns/:campaignId/config?apiKey=<key>&matchId=<optional>
Authorization: API Key

Response 200:
{
  "campaignId": 1,
  "brand": {
    "name": "Nike",
    "iconAsset": "nike_icon",
    "iconUrl": "https://...",
    "logoUrl": "https://..."
  },
  "engagement": {
    "demoMode": false,
    "defaultPollDuration": 300,
    "defaultContestDuration": 600,
    "maxVotesPerPoll": 1,
    "enableRealTimeUpdates": true,
    "updateInterval": 1000
  },
  "ui": {
    "primaryColor": "#007AFF",
    "secondaryColor": "#5856D6",
    "componentConfigs": { ... }
  },
  "features": {
    "enableLiveStreaming": true,
    "enableProductCatalog": true,
    "enableEngagement": true,
    "enablePolls": true,
    "enableContests": true
  },
  "translations": { ... },
  "match": {
    "matchId": "match-123",
    "matchName": "Barcelona vs PSG",
    "startTime": "2025-01-23T20:00:00Z"
  }
}
```

Cache-Control: `public, max-age=300` (5 min)

### 5.4 Configuracion de Engagement por Match

```http
GET /v1/engagement/config?apiKey=<key>&matchId=<match-id>
Authorization: API Key

Response 200:
{
  "matchId": "match-123",
  "campaignId": 1,
  "engagement": { ... },
  "features": { ... }
}
```

### 5.5 Localizacion

```http
GET /v1/localization/:language?apiKey=<key>&campaignId=<optional>&matchId=<optional>
Authorization: API Key
Idiomas soportados: no, en, sv, es, de, fr, da, fi

Response 200:
{
  "language": "es",
  "translations": {
    "sponsor_badge": "Patrocinado por",
    "poll_title": "Encuesta",
    ...
  },
  "formats": {
    "dateFormat": "dd.MM.yyyy",
    "timeFormat": "HH:mm"
  }
}
```

Cache-Control: `public, max-age=3600` (1 hora)

### 5.6 Ofertas/Productos

```http
GET /v1/offers?apiKey=<key>&campaignId=<id>&userId=<optional>&userCountry=<optional>
Authorization: API Key

Response 200:
{
  "campaignId": 1,
  "campaignName": "...",
  "channelId": 1,
  "channelName": "...",
  "matchContext": { ... },
  "offers": [
    {
      "componentId": "uuid",
      "componentType": "ProductSpotlight",
      "componentName": "Nike Shoes",
      "config": { "imageUrl": "https://...", "price": "99.99", ... },
      "matchId": "match-123"
    }
  ]
}
```

Filtrado por targeting: Si `userId`/`userCountry` no coinciden con segmentacion, devuelve array vacio.

### 5.7 Engagement SDK - Polls (Publico, Rate Limited)

```http
GET /v1/engagement/polls?broadcastId=<id>
Response 200:
[
  {
    "id": 1,
    "broadcastId": "barcelona-psg-2025-01-23",
    "question": "Mejor jugador del partido?",
    "isActive": true,
    "totalVotes": 150,
    "options": [
      { "id": 1, "text": "Messi", "voteCount": 80, "percentage": 53.33 },
      { "id": 2, "text": "Mbappe", "voteCount": 70, "percentage": 46.67 }
    ]
  }
]
```

```http
POST /v1/engagement/polls/:pollId/vote
Rate Limit: 30 req/min por userId
Body: { "optionId": 1, "userId": "user123", "broadcastId": "barcelona-psg-2025-01-23" }

# Modo sincrono (USE_QUEUE != true):
Response 200:
{
  "success": true,
  "results": {
    "id": 1,
    "question": "...",
    "totalVotes": 151,
    "options": [
      { "id": 1, "text": "Messi", "voteCount": 81, "percentage": 53.64 }
    ]
  }
}

# Modo queue (USE_QUEUE=true):
Response 200:
{
  "success": true,
  "queued": true,
  "message": "Vote queued for processing"
}

Response 409: { "message": "User has already voted on this poll" }
Response 429: { "error": "Rate limit exceeded", "retryAfter": 45 }
```

### 5.8 Engagement SDK - Contests (Publico, Rate Limited)

```http
GET /v1/engagement/contests?broadcastId=<id>
Response 200:
[
  {
    "id": 1,
    "broadcastId": "barcelona-psg-2025-01-23",
    "title": "Win a Jersey",
    "contestType": "giveaway",
    "isActive": true,
    "prize": "Signed Jersey"
  }
]
```

```http
POST /v1/engagement/contests/:contestId/participate
Rate Limit: 10 req/min por userId
Body: { "userId": "user123", "broadcastId": "barcelona-psg-2025-01-23", "answers": {...} }

# Modo sincrono:
Response 201: { "id": 1, "contestId": 1, "userId": "user123", ... }

# Modo queue:
Response 201: { "success": true, "queued": true, "message": "Participation queued for processing" }

Response 409: { "message": "User has already participated in this contest" }
Response 429: { "error": "Rate limit exceeded", "retryAfter": 55 }
```

---

## 6. Endpoints Admin (Dashboard) <a name="endpoints-admin"></a>

### 6.1 Usuarios
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| POST | `/api/users/ensure` | Crear/obtener usuario + token JWT |
| POST | `/api/auth/token` | Generar token JWT |
| GET | `/api/users` | Listar usuarios |
| GET | `/api/users/:id` | Obtener usuario por ID |
| POST | `/api/users` | Crear usuario |
| PATCH | `/api/users/:id` | Actualizar usuario |

### 6.2 Client Apps
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/client-apps?userId=<id>` | Listar apps del usuario |
| POST | `/api/client-apps` | Crear client app (auto-genera apiKey) |
| PATCH | `/api/client-apps/:id` | Actualizar client app |
| DELETE | `/api/client-apps/:id` | Eliminar client app |

### 6.3 Channels
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/channels?clientAppId=<id>` | Listar canales |
| POST | `/api/channels` | Crear canal |
| PATCH | `/api/channels/:id` | Actualizar canal |
| DELETE | `/api/channels/:id` | Eliminar canal |

### 6.4 Campaigns
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/campaigns?userId=<id>` | Listar campanas |
| GET | `/api/campaigns/:id` | Obtener campana |
| POST | `/api/campaigns` | Crear campana |
| PATCH | `/api/campaigns/:id` | Actualizar campana |
| DELETE | `/api/campaigns/:id` | Eliminar campana |
| PUT | `/api/campaigns/:id/pause` | Pausar campana |
| PUT | `/api/campaigns/:id/resume` | Reanudar campana |

### 6.5 Components
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/components` | Listar todos los componentes |
| GET | `/api/components/:id` | Obtener componente |
| POST | `/api/components` | Crear componente |
| PUT | `/api/components/:id` | Actualizar componente |
| DELETE | `/api/components/:id` | Eliminar componente |

### 6.6 Campaign Components
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/campaigns/:id/components` | Listar componentes de campana |
| POST | `/api/campaigns/:id/components` | Agregar componente a campana |
| PUT | `/api/campaigns/:id/components/:compId` | Actualizar instancia |
| DELETE | `/api/campaigns/:id/components/:compId` | Eliminar instancia |

### 6.7 Broadcasts (Dashboard)
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/broadcasts?status=<s>&campaignId=<id>` | Listar broadcasts |
| GET | `/api/broadcasts/:broadcastId` | Obtener broadcast |
| POST | `/api/broadcasts` | Crear broadcast |
| PUT | `/api/broadcasts/:broadcastId` | Actualizar broadcast |
| DELETE | `/api/broadcasts/:broadcastId` | Eliminar broadcast |

### 6.8 Polls (Dashboard) - Con Video Scheduling
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/broadcasts/:broadcastId/polls` | Listar polls |
| POST | `/api/broadcasts/:broadcastId/polls` | Crear poll (acepta videoStartTime/videoEndTime/broadcastStartTime) |
| PUT | `/api/polls/:pollId` | Actualizar poll |
| DELETE | `/api/polls/:pollId` | Eliminar poll |

### 6.9 Contests (Dashboard) - Con Video Scheduling
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/broadcasts/:broadcastId/contests` | Listar contests |
| POST | `/api/broadcasts/:broadcastId/contests` | Crear contest (acepta videoStartTime/videoEndTime/broadcastStartTime) |
| PUT | `/api/contests/:contestId` | Actualizar contest |
| DELETE | `/api/contests/:contestId` | Eliminar contest |

### 6.10 Broadcasts Admin (v1 - Bearer Auth)
| Metodo | Ruta | Auth | Descripcion |
|--------|------|------|-------------|
| POST | `/v1/broadcasts` | Bearer | Crear broadcast |
| GET | `/v1/broadcasts` | Bearer | Listar broadcasts |
| GET | `/v1/broadcasts/:id` | Bearer | Obtener broadcast |
| PUT | `/v1/broadcasts/:id` | Bearer | Actualizar broadcast |
| DELETE | `/v1/broadcasts/:id` | Bearer | Eliminar broadcast |
| POST | `/v1/broadcasts/:id/polls` | Bearer | Crear poll (con video scheduling) |
| GET | `/v1/broadcasts/:id/polls` | Bearer | Listar polls |
| GET | `/v1/polls/:id/results` | Bearer | Resultados de poll |
| POST | `/v1/broadcasts/:id/contests` | Bearer | Crear contest (con video scheduling) |
| GET | `/v1/broadcasts/:id/contests` | Bearer | Listar contests |

### 6.11 Configuracion Dinamica (Dashboard)
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/campaigns/:id/engagement-config` | Obtener config engagement |
| PUT | `/api/campaigns/:id/engagement-config` | Actualizar config engagement |
| GET | `/api/campaigns/:id/ui-config` | Obtener config UI |
| PUT | `/api/campaigns/:id/ui-config` | Actualizar config UI |
| GET | `/api/campaigns/:id/feature-flags` | Obtener feature flags |
| PUT | `/api/campaigns/:id/feature-flags` | Actualizar feature flags |
| GET | `/api/campaigns/:id/translations` | Obtener traducciones |
| PUT | `/api/campaigns/:id/translations` | Actualizar traducciones |
| GET | `/api/sdk-translations/:language` | Obtener traducciones SDK |
| PUT | `/api/sdk-translations/:language` | Actualizar traducciones SDK |

---

## 7. Eventos WebSocket <a name="eventos-websocket"></a>

### Conexion

```
ws://<host>/ws/:campaignId
```

Cada cliente se conecta a un canal especifico de campaign. Los eventos se emiten solo a los clientes de esa campaign.

### Tipos de Eventos

| Tipo | Trigger | Payload |
|------|---------|---------|
| `component:activated` | Componente activado | `{ type, componentId, config }` |
| `component:deactivated` | Componente desactivado | `{ type, componentId }` |
| `event:new` | Nuevo evento creado | `{ type, data: { eventId, eventType, ... } }` |
| `event:saved` | Evento guardado | `{ type, data: { eventId, ... } }` |
| `campaign:paused` | Campana pausada | `{ type, campaignId }` |
| `campaign:resumed` | Campana reanudada | `{ type, campaignId }` |
| `broadcast:status_changed` | Estado de broadcast cambio | `{ type, broadcastId, status }` |
| `poll_results_updated` | Votos actualizados | `{ type, pollId, broadcastId, totalVotes, options: [...] }` |
| `config:updated` | Config dinamica cambio | `{ type, campaignId, section }` |

**Nota:** `poll_results_updated` ahora se emite desde `vote-processor.ts` via `setVoteBroadcastFunction`, permitiendo que tanto el procesamiento sincrono como el queue-based emitan WebSocket events.

---

## 8. Sistema de Broadcasts <a name="sistema-de-broadcasts"></a>

### Ciclo de vida

```
upcoming → live → ended
```

- **upcoming**: `startTime` en el futuro
- **live**: `startTime` en el pasado, `endTime` en el futuro
- **ended**: `endTime` en el pasado

### Auto-transicion (Scheduler)

El scheduler verifica cada minuto:
1. Broadcasts `upcoming` cuyo `startTime` ya paso → cambia a `live`
2. Broadcasts `live` cuyo `endTime` ya paso → cambia a `ended`
3. Emite evento WebSocket `broadcast:status_changed` en cada transicion

### Slug Generation

```
broadcastName: "Barcelona vs PSG"
date: "2025-01-23"
→ broadcastId: "barcelona-vs-psg-2025-01-23"
```

Si hay colision, agrega sufijo numerico: `barcelona-vs-psg-2025-01-23-2`

---

## 9. Sistema de Engagement (Polls y Contests) <a name="sistema-de-engagement"></a>

### 9.1 Flujo de Votacion (con Queue Fallback)

```
1. Cliente envia POST /v1/engagement/polls/:pollId/vote
   Body: { optionId, userId, broadcastId }

2. Rate Limiter verifica: 30 req/min por userId (SimpleRateLimiter in-memory)
   Si excede → 429 Too Many Requests

3. Si USE_QUEUE=true:
   → Job se encola en voteQueue (SimpleQueueAdapter o BullMQAdapter)
   → Response: { success: true, queued: true }
   → Worker procesa asincrono: processPollVote()
   → WebSocket broadcast via setVoteBroadcastFunction

4. Si USE_QUEUE != true (default actual):
   → processPollVoteSync() se ejecuta directamente
   → Verifica poll activa, usuario no ha votado
   → Crea voto, actualiza contadores
   → Calcula porcentajes
   → WebSocket broadcast de resultados
   → Response: { success: true, results: {...} }
```

### 9.2 Flujo de Participacion en Contest (con Queue Fallback)

```
1. Cliente envia POST /v1/engagement/contests/:contestId/participate
   Body: { userId, broadcastId, answers }

2. Rate Limiter: 10 req/min por userId

3. Si USE_QUEUE=true:
   → Job se encola en contestParticipationQueue
   → Response: { success: true, queued: true }

4. Si USE_QUEUE != true:
   → processContestParticipationSync() se ejecuta directamente
   → Verifica contest activo, usuario no ha participado
   → Crea participacion
   → Response: participation object
```

### 9.3 Video Scheduling de Polls/Contests

Los 4 endpoints de creacion (POST) aceptan campos opcionales de video scheduling:

```json
{
  "question": "Mejor jugador?",
  "options": ["Messi", "Mbappe"],
  "videoStartTime": 300,
  "videoEndTime": 600,
  "broadcastStartTime": "2025-01-23T20:00:00Z"
}
```

Backend calcula automaticamente:
- `scheduledStartTime` = broadcastStartTime + videoStartTime (20:05:00)
- `scheduledEndTime` = broadcastStartTime + videoEndTime (20:10:00)

Validacion:
- `videoEndTime` >= `videoStartTime`
- `broadcastStartTime` debe ser ISO timestamp valido

---

## 10. Configuracion Dinamica <a name="configuracion-dinamica"></a>

4 tablas independientes por campana:

| Tabla | Campos Clave | Endpoint Dashboard | Endpoint SDK |
|-------|-------------|-------------------|--------------|
| `campaign_engagement_config` | demoMode, defaultPollDuration, maxVotesPerPoll, enableRealTimeUpdates, updateInterval | PUT `/api/campaigns/:id/engagement-config` | GET `/v1/campaigns/:id/config` |
| `campaign_ui_config` | primaryColor, secondaryColor, componentConfigs | PUT `/api/campaigns/:id/ui-config` | GET `/v1/campaigns/:id/config` |
| `campaign_feature_flags` | enableLiveStreaming, enableProductCatalog, enableEngagement, enablePolls, enableContests | PUT `/api/campaigns/:id/feature-flags` | GET `/v1/campaigns/:id/config` |
| `sdk_translations` | language, campaignId, matchId, translations | PUT `/api/sdk-translations/:language` | GET `/v1/localization/:language` |

Al actualizar cualquier config, se emite evento WebSocket `config:updated` a todos los clientes de la campana.

---

## 11. Scheduler / Cron Jobs <a name="scheduler"></a>

**Archivo:** `server/scheduler.ts`
**Intervalo:** Configurable via `SCHEDULER_INTERVAL_MINUTES` (default: 1 minuto)

### Funciones activas cada minuto:

1. **processScheduledComponents()**: Activa/desactiva componentes segun `scheduled_time`/`end_time`
2. **processScheduledBroadcasts()**: Transiciona broadcasts upcoming→live→ended
3. **processScheduledPolls()**: ✅ ACTIVO - Auto-activa/desactiva polls segun `scheduledStartTime`/`scheduledEndTime`
4. **processScheduledContests()**: ✅ ACTIVO - Auto-activa/desactiva contests segun scheduling

### Logica de processScheduledPolls:
```
Para cada poll con scheduledStartTime Y scheduledEndTime:
  Si now >= scheduledStartTime AND poll.isActive == false:
    → UPDATE poll SET isActive = true
    → Log: "Auto-activated poll X"
  Si now >= scheduledEndTime AND poll.isActive == true:
    → UPDATE poll SET isActive = false
    → Log: "Auto-deactivated poll X"
```

Misma logica para contests.

---

## 12. Paginas del Dashboard <a name="paginas-dashboard"></a>

| Ruta | Pagina | Descripcion |
|------|--------|-------------|
| `/` | Home/Campaigns | Lista de campanas del usuario |
| `/campaigns` | Campaigns | Lista completa de campanas |
| `/campaign/:id` | Campaign Dashboard | Tabs: Overview, Events, Scheduled, Components, Integrations, Settings |
| `/broadcasts` | Broadcasts | Lista de broadcasts con filtros |
| `/broadcast/:id` | Broadcast Detail | Tabs: Overview, Polls, Contests |
| `/components` | Component Library | Libreria de componentes reutilizables |
| `/viewer/:id` | Campaign Viewer | Vista publica del viewer |
| `/docs` | Documentation | Documentacion de la API |

---

## 13. Flujos Completos <a name="flujos-completos"></a>

### Flujo 1: Setup Completo

```
1. Frontend: Login/registro → POST /api/users/ensure
2. Crear Client App → POST /api/client-apps (genera apiKey)
3. Crear Channel → POST /api/channels
4. Crear Campaign → POST /api/campaigns
5. Crear Component → POST /api/components
6. Asignar Component → POST /api/campaigns/:id/components
7. Activar Component → PUT /api/campaigns/:id/components/:compId { status: "active" }
8. SDK conecta → WebSocket /ws/:campaignId
9. SDK recibe → component:activated event
```

### Flujo 2: Broadcast con Engagement

```
1. POST /api/broadcasts { broadcastName: "Barcelona vs PSG", startTime, endTime, campaignId }
2. POST /api/broadcasts/:id/polls {
     question: "MVP del partido?",
     options: ["Messi", "Mbappe"],
     videoStartTime: 300,
     videoEndTime: 600,
     broadcastStartTime: "2025-01-23T20:00:00Z"
   }
3. Backend calcula scheduledStartTime/scheduledEndTime
4. Scheduler: A las 20:05 → activa poll automaticamente
5. SDK: GET /v1/engagement/polls?broadcastId=xxx → recibe poll activa
6. SDK: POST /v1/engagement/polls/:pollId/vote (rate limited 30/min)
   → processPollVoteSync o queue
   → WebSocket: poll_results_updated a todos los clientes
7. Scheduler: A las 20:10 → desactiva poll automaticamente
```

### Flujo 3: SDK Auto-Discovery

```
1. SDK iOS: GET /v1/sdk/campaigns?apiKey=<key>
2. SDK iOS: GET /v1/campaigns/:id/config?apiKey=<key>
3. SDK iOS: WebSocket connect /ws/:campaignId
4. SDK iOS: Recibe eventos en real-time
5. SDK iOS: GET /v1/engagement/polls?broadcastId=<id>
6. SDK iOS: POST /v1/engagement/polls/:pollId/vote
```

### Flujo 4: Geo-Targeting

```
1. Dashboard: Configurar campana con isSegmented=true, targetCountries=["NO","SE"], targetPercentage=50
2. SDK: GET /v1/offers?apiKey=<key>&campaignId=1&userId=user123&userCountry=NO
3. Backend:
   - Verifica si userCountry esta en targetCountries
   - Calcula SHA256(userId:campaignId) % 100 < targetPercentage
   - Si pasa: devuelve ofertas
   - Si no: devuelve array vacio
```

---

## 14. Servicios Extraidos <a name="servicios"></a>

### 14.1 Vote Processor (`server/services/vote-processor.ts`)

Logica de procesamiento de votos extraida del route handler. Incluye WebSocket broadcast.

```typescript
import { processPollVoteSync, setVoteBroadcastFunction } from './services/vote-processor';

setVoteBroadcastFunction(broadcastToCampaignImpl);

const result = await processPollVoteSync({
  pollId: 1,
  optionId: 2,
  userId: "user123",
  broadcastId: "barcelona-psg-2025-01-23"
});
// result: { success: boolean, error?: string, data?: PollResults }
```

**Flujo interno:**
1. Verifica que la poll existe y esta activa
2. Verifica que el usuario no ha votado
3. Registra el voto (UNIQUE constraint previene duplicados)
4. Actualiza contadores (option.voteCount, poll.totalVotes)
5. Calcula porcentajes
6. Emite WebSocket `poll_results_updated` via broadcastFn
7. Retorna resultados completos

### 14.2 Contest Processor (`server/services/contest-processor.ts`)

```typescript
import { processContestParticipationSync } from './services/contest-processor';

const result = await processContestParticipationSync({
  contestId: 1,
  userId: "user123",
  broadcastId: "barcelona-psg-2025-01-23",
  answers: { q1: "A" }
});
// result: { success: boolean, error?: string, data?: ContestParticipation }
```

---

## 15. Middleware Activo <a name="middleware"></a>

### 15.1 Rate Limiter (`server/middleware/rate-limiter.ts`)

**Estado:** ✅ ACTIVO con Adapter Pattern

Dos implementaciones intercambiables:

| Implementacion | Cuando se usa | Almacenamiento |
|---------------|---------------|----------------|
| `SimpleRateLimiter` | Sin Redis (default) | In-memory Map con cleanup cada 60s |
| `RedisRateLimiter` | Con REDIS_HOST/REDIS_URL | Sorted sets con sliding window |

La seleccion es automatica: si `REDIS_HOST` o `REDIS_URL` estan configuradas → Redis, sino → Simple.

```typescript
import { createRateLimiter, rateLimitPresets } from './middleware/rate-limiter';

app.post('/v1/engagement/polls/:pollId/vote',
  createRateLimiter(rateLimitPresets.voting),  // 30 req/min por userId
  handler
);

app.post('/v1/engagement/contests/:contestId/participate',
  createRateLimiter(rateLimitPresets.participation),  // 10 req/min por userId
  handler
);
```

**Presets disponibles:**
| Preset | Max Requests | Window | Key |
|--------|-------------|--------|-----|
| `voting` | 30 | 60s | `rate_limit:vote:{userId or IP}` |
| `participation` | 10 | 60s | `rate_limit:contest:{userId or IP}` |
| `sdkPublic` | 60 | 60s | `rate_limit:sdk:{IP}` |
| `adminApi` | 100 | 60s | `rate_limit:admin:{IP}` |

**Response headers:**
- `X-RateLimit-Limit`: Max requests
- `X-RateLimit-Remaining`: Requests restantes
- `X-RateLimit-Reset`: Timestamp de reset

**Response 429:**
```json
{
  "error": "Rate limit exceeded",
  "retryAfter": 45,
  "limit": 30,
  "window": 60
}
```

### 15.2 Broadcast Validator (`server/middleware/broadcast-validator.ts`)

**Estado:** ✅ Funcional

```typescript
import { validateBroadcastId } from './middleware/broadcast-validator';

app.post('/v1/engagement/polls/:pollId/vote',
  validateBroadcastId,
  handler
);
```

Extrae `broadcastId` de `req.params`, `req.body`, o `req.query`. Si el broadcast no existe, devuelve 404.

---

## 16. Sistema de Colas - Adapter Pattern <a name="queue-system"></a>

**Estado:** ✅ ACTIVO con Adapter Pattern
**Archivos:** `server/queue/`

### 16.1 Arquitectura Adapter Pattern

```
┌───────────────────────────────────────────┐
│          QueueAdapter Interface            │
│  add(queue, job, data, options)            │
│  process(queue, processor)                 │
│  close()                                   │
├───────────────┬───────────────────────────┤
│ SimpleQueue   │ BullMQAdapter             │
│ Adapter       │ (Redis)                   │
│ ✅ Activo ahora │ Listo para produccion   │
│ In-memory     │ Requiere: bullmq+ioredis  │
│ 100ms polling │ Event-driven              │
│ 3 retries     │ Configurable retries      │
└───────────────┴───────────────────────────┘
```

### 16.2 SimpleQueueAdapter (activo por default)

- Almacena jobs en Map<string, Array>
- Polling cada 100ms para procesar jobs
- 3 reintentos por job con backoff
- Deduplicacion por jobId
- Sin dependencias externas

### 16.3 BullMQAdapter (para produccion)

- Requiere: `npm install bullmq ioredis`
- Se activa con: `QUEUE_ENABLED=true` + `REDIS_HOST`
- Workers con concurrencia configurable (`QUEUE_CONCURRENCY`)
- Backoff exponencial automatico

### 16.4 Colas Definidas (`server/queue/queues.ts`)

```typescript
import { voteQueue, contestParticipationQueue, broadcastStatusQueue, isQueueEnabled } from './queue/queues';

// Encolar voto
await voteQueue.add('process-vote', { pollId, optionId, userId, broadcastId }, {
  jobId: `vote-${pollId}-${userId}`,
});

// Encolar participacion
await contestParticipationQueue.add('process-participation', { contestId, userId, broadcastId, answers }, {
  jobId: `participate-${contestId}-${userId}`,
});

// Verificar si queue esta habilitada
if (isQueueEnabled()) { ... }  // USE_QUEUE === 'true'
```

### 16.5 Workers (`server/queue/workers.ts`)

Se inicializan en `server/index.ts` solo si `USE_QUEUE=true`:

```typescript
import { initializeWorkers } from './queue/workers';
import { isQueueEnabled } from './queue/queues';

if (isQueueEnabled()) {
  initializeWorkers();
}
```

Workers registrados:
- `vote-processing`: Procesa votos usando `processPollVote()` de vote-processor.ts
- `contest-participation`: Procesa participaciones usando `processContestParticipation()`

### 16.6 Tipos de Jobs (`server/queue/types.ts`)

```typescript
interface VoteJobData {
  pollId: number;
  optionId: number;
  userId: string;
  broadcastId: string;
  timestamp?: string;
}

interface ContestParticipationJobData {
  contestId: number;
  userId: string;
  broadcastId: string;
  answers?: Record<string, any>;
  timestamp?: string;
}

interface BroadcastStatusJobData {
  broadcastId: string;
  newStatus: 'upcoming' | 'live' | 'ended';
  timestamp?: string;
}

interface JobResult {
  success: boolean;
  error?: string;
  data?: any;
}
```

---

## 17. Video Scheduling (Activo) <a name="video-scheduling"></a>

**Estado:** ✅ ACTIVO - Scheduler procesando, endpoints aceptando campos
**Archivo:** `server/utils/scheduling.ts`

### 17.1 Utilidades de Calculo

```typescript
import { calculateScheduledTimes, validateScheduling } from './utils/scheduling';

// Validar campos de scheduling
const validation = validateScheduling({
  broadcastStartTime: "2025-01-23T20:00:00Z",
  videoStartTime: 300,
  videoEndTime: 600
});
// validation: { valid: true } o { valid: false, error: "mensaje" }

// Calcular timestamps absolutos
const scheduled = calculateScheduledTimes({
  broadcastStartTime: "2025-01-23T20:00:00Z",
  videoStartTime: 300,   // 5 min
  videoEndTime: 600       // 10 min
});
// scheduled: {
//   scheduledStart: Date("2025-01-23T20:05:00Z"),
//   scheduledEnd: Date("2025-01-23T20:10:00Z")
// }
```

### 17.2 Campos de DB (todos nullable)

Campos en `polls`, `contests`, y `campaign_components`:

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| `video_start_time` | integer | Segundos desde el inicio del broadcast/video |
| `video_end_time` | integer | Segundos desde el inicio del broadcast/video |
| `broadcast_start_time` | timestamp | Timestamp del inicio del broadcast (solo polls/contests) |
| `scheduled_start_time` | timestamp | Calculado: broadcastStartTime + videoStartTime |
| `scheduled_end_time` | timestamp | Calculado: broadcastStartTime + videoEndTime |

### 17.3 Endpoints que aceptan Video Scheduling

Los 4 endpoints de creacion aceptan campos opcionales:

| Endpoint | Acepta Video Scheduling |
|----------|------------------------|
| `POST /v1/broadcasts/:id/polls` | ✅ videoStartTime, videoEndTime, broadcastStartTime |
| `POST /v1/broadcasts/:id/contests` | ✅ videoStartTime, videoEndTime, broadcastStartTime |
| `POST /api/broadcasts/:id/polls` | ✅ videoStartTime, videoEndTime, broadcastStartTime |
| `POST /api/broadcasts/:id/contests` | ✅ videoStartTime, videoEndTime, broadcastStartTime |

---

## 18. Rate Limiting (Activo) <a name="rate-limiting"></a>

**Estado:** ✅ ACTIVO en endpoints de engagement

### Endpoints protegidos actualmente:

| Endpoint | Preset | Limite |
|----------|--------|--------|
| `POST /v1/engagement/polls/:pollId/vote` | voting | 30 req/min por userId |
| `POST /v1/engagement/contests/:contestId/participate` | participation | 10 req/min por userId |

### Presets disponibles para uso futuro:

| Preset | Max | Window | Para |
|--------|-----|--------|------|
| `sdkPublic` | 60 | 60s | Endpoints SDK publicos de lectura |
| `adminApi` | 100 | 60s | Endpoints admin |

---

## 19. Componentes UI de Scheduling <a name="scheduling-ui"></a>

**Estado:** Creados, NO integrados en paginas existentes
**Archivos:** `client/src/components/scheduling/`

### 19.1 SchedulingForm

Formulario completo para configurar scheduling de polls/contests relativo al video.

```tsx
import { SchedulingForm } from '@/components/scheduling/SchedulingForm';

<SchedulingForm
  broadcastStartTime="2025-01-23T20:00:00Z"
  onScheduleChange={(schedule) => {
    // schedule: { videoStartTime, videoEndTime, scheduledStartTime, scheduledEndTime }
  }}
  initialValues={{ videoStartTime: 300, videoEndTime: 600 }}
/>
```

### 19.2 VideoTimeInput

Input especializado para tiempo de video (formato HH:MM:SS o segundos).

```tsx
import { VideoTimeInput } from '@/components/scheduling/VideoTimeInput';

<VideoTimeInput
  value={300}
  onChange={(seconds) => setVideoTime(seconds)}
  label="Inicio en video"
  format="hms" // "hms" | "seconds"
/>
```

### 19.3 TimelineView

Visualizacion de timeline del broadcast mostrando cuando se activan polls/contests.

```tsx
import { TimelineView } from '@/components/scheduling/TimelineView';

<TimelineView
  broadcastStartTime="2025-01-23T20:00:00Z"
  broadcastEndTime="2025-01-23T23:00:00Z"
  items={[
    { type: 'poll', title: 'MVP Poll', videoStartTime: 300, videoEndTime: 600 },
    { type: 'contest', title: 'Giveaway', videoStartTime: 900, videoEndTime: 1200 }
  ]}
/>
```

---

## 20. Variables de Entorno <a name="variables-entorno"></a>

### Actuales (en uso)

| Variable | Descripcion | Requerida |
|----------|-------------|-----------|
| `DATABASE_URL` | URL de conexion PostgreSQL | ✅ Si |
| `SESSION_SECRET` | Secret para JWT tokens | ✅ Si |
| `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` | Conexion DB individual | Auto |
| `SCHEDULER_INTERVAL_MINUTES` | Intervalo del cron (default: 1) | No |
| `DEFAULT_OBJECT_STORAGE_BUCKET_ID` | Bucket de Object Storage | No |
| `USE_QUEUE` | Activar procesamiento via colas (default: undefined → sincrono) | No |

### Para Produccion con Redis

| Variable | Default | Descripcion |
|----------|---------|-------------|
| `REDIS_HOST` | localhost | Host de Redis (activa RedisRateLimiter automaticamente) |
| `REDIS_PORT` | 6379 | Puerto de Redis |
| `REDIS_PASSWORD` | (vacio) | Password de Redis |
| `REDIS_URL` | (vacio) | URL completa de Redis (alternativa a HOST/PORT) |
| `QUEUE_ENABLED` | false | Activar BullMQAdapter (requiere Redis + bullmq) |
| `QUEUE_CONCURRENCY` | 10 | Workers concurrentes por cola |
| `USE_QUEUE` | false | Activar encolamiento en endpoints vote/participate |

---

## 21. Guia de Transicion a Produccion (Redis) <a name="produccion"></a>

### Lo que ya funciona sin Redis:

| Feature | Implementacion | Estado |
|---------|---------------|--------|
| Rate Limiting | SimpleRateLimiter (in-memory Map) | ✅ Funcional |
| Queue Processing | SimpleQueueAdapter (in-memory) | ✅ Funcional |
| Video Scheduling | Scheduler con DB queries | ✅ Funcional |
| Vote/Contest Processing | Sincrono directo | ✅ Funcional |
| WebSocket Broadcast | Directo desde vote-processor | ✅ Funcional |

### Para activar Redis en produccion:

**Paso 1:** Instalar dependencias
```bash
npm install bullmq ioredis
```

**Paso 2:** Configurar variables de entorno
```
REDIS_HOST=your-redis-host
REDIS_PORT=6379
REDIS_PASSWORD=your-password
QUEUE_ENABLED=true
USE_QUEUE=true
```

**Paso 3:** Nada mas. El Adapter Pattern se encarga de todo:
- `createRateLimiter` detecta `REDIS_HOST` → usa `RedisRateLimiter`
- `getQueueAdapter` detecta `QUEUE_ENABLED=true` + Redis → usa `BullMQAdapter`
- `isQueueEnabled()` detecta `USE_QUEUE=true` → endpoints encolan en vez de procesar sincrono
- `initializeWorkers()` se activa automaticamente en `server/index.ts`

### Comparacion In-Memory vs Redis:

| Aspecto | In-Memory (actual) | Redis (produccion) |
|---------|--------------------|--------------------|
| Rate Limiting | Map con cleanup 60s | Sorted sets, sliding window |
| Queue Jobs | Array con polling 100ms | BullMQ event-driven |
| Persistencia | Se pierde en restart | Persistente |
| Multi-instancia | No (solo 1 proceso) | Si (multiples workers) |
| Retry | 3 intentos basicos | Configurable con backoff exponencial |
| Monitoring | Logs basicos | Bull Board dashboard |

---

## Resumen de Estado por Feature (v3.0)

| Feature | Estado | Fase | Archivos Clave |
|---------|--------|------|----------------|
| Broadcasts CRUD | ✅ Activo | 1-2 | routes.ts, storage.ts |
| Polls & Voting | ✅ Activo | 3 | routes.ts, storage.ts |
| Contests & Participation | ✅ Activo | 3 | routes.ts, storage.ts |
| WebSocket Events | ✅ Activo | 3 | routes.ts, vote-processor.ts |
| Broadcast Scheduler | ✅ Activo | 4 | scheduler.ts |
| Dashboard UI | ✅ Activo | 4 | broadcasts.tsx, broadcast-detail.tsx |
| JWT Auth (v1) | ✅ Activo | 2 | routes.ts |
| SDK Endpoints | ✅ Activo | 2 | routes.ts |
| Broadcast Validator | ✅ Activo | 5 | middleware/broadcast-validator.ts |
| Vote Processor Service | ✅ Activo + WS broadcast | 5 | services/vote-processor.ts |
| Contest Processor Service | ✅ Activo | 5 | services/contest-processor.ts |
| Video Scheduling DB | ✅ Activo | 5 | schema.ts |
| Video Scheduling Utils | ✅ Activo | 5 | utils/scheduling.ts |
| Video Scheduling Endpoints | ✅ 4 endpoints aceptan campos | 5 | routes.ts |
| Scheduled Polls/Contests | ✅ Activo en scheduler | 5 | scheduler.ts |
| Video Scheduling UI | ⏸ Componentes creados, no integrados | 5 | components/scheduling/ |
| Queue Adapter Pattern | ✅ Activo (SimpleQueueAdapter) | 6 | queue/queue-adapter.ts |
| Queue Definitions | ✅ Activo | 6 | queue/queues.ts |
| Queue Workers | ✅ Activo (se inician si USE_QUEUE=true) | 6 | queue/workers.ts |
| Rate Limiter | ✅ Activo (SimpleRateLimiter) | 6 | middleware/rate-limiter.ts |
| Vote/Participate Queue Fallback | ✅ Activo (sincrono/queue) | 6 | routes.ts |
| Worker Initialization | ✅ Activo en index.ts | 6 | index.ts |
