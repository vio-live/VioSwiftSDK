# SDK Infrastructure - Documentacion Completa

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
│  Cron cada 1 minuto: componentes + broadcasts               │
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
                 │    ├── Polls (encuestas)
                 │    │    ├── Poll Options (opciones)
                 │    │    └── Poll Votes (votos)
                 │    └── Contests (concursos)
                 │         └── Contest Participations
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

### 5.7 Broadcasts (SDK - Publico)

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
Body: { "optionId": 1, "userId": "user123", "broadcastId": "barcelona-psg-2025-01-23" }

Response 200:
{
  "message": "Vote recorded",
  "results": {
    "id": 1,
    "question": "...",
    "totalVotes": 151,
    "options": [
      { "id": 1, "text": "Messi", "voteCount": 81, "percentage": 53.64 }
    ]
  }
}

Response 409: { "message": "User has already voted on this poll" }
```

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
Body: { "userId": "user123", "broadcastId": "barcelona-psg-2025-01-23", "answers": {...} }

Response 200: { "message": "Participation recorded", ... }
Response 409: { "message": "User has already participated in this contest" }
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
| GET | `/api/client-apps?userId=X` | Listar apps del usuario |
| GET | `/api/client-apps/:id` | Obtener app |
| POST | `/api/client-apps` | Crear app (genera API Key) |
| PATCH | `/api/client-apps/:id` | Actualizar app |
| POST | `/api/client-apps/:id/regenerate-key` | Regenerar API Key |
| DELETE | `/api/client-apps/:id` | Eliminar app |
| GET | `/api/client-apps/:id/channels` | Canales de la app |

### 6.3 Channels
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/channels?userId=X` | Listar canales |

### 6.4 Campaigns
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/campaigns?userId=X` | Listar campanas |
| GET | `/api/campaigns/:id` | Obtener campana |
| POST | `/api/campaigns` | Crear campana |
| PUT | `/api/campaigns/:id` | Actualizar campana |
| DELETE | `/api/campaigns/:id` | Eliminar campana |
| PATCH | `/api/campaigns/:id/toggle-pause` | Pausar/reanudar campana |

### 6.5 Campaign Config
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET/PUT | `/api/campaigns/:id/engagement-config` | Config de engagement |
| GET/PUT | `/api/campaigns/:id/ui-config` | Config de UI/tema |
| GET/PUT | `/api/campaigns/:id/feature-flags` | Feature flags |

### 6.6 Components
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/components` | Listar componentes |
| POST | `/api/components` | Crear componente |
| GET | `/api/components/:id` | Obtener componente |
| PATCH | `/api/components/:id` | Actualizar componente |
| DELETE | `/api/components/:id` | Eliminar componente |
| GET | `/api/components/usage` | Uso en campanas |
| GET | `/api/components/:id/availability` | Disponibilidad |

### 6.7 Campaign Components
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/campaigns/:id/components` | Componentes de campana |
| GET | `/api/campaigns/:id/active-components` | Solo activos (iOS) |
| POST | `/api/campaigns/:id/components` | Anadir componente a campana |
| PATCH | `/api/campaigns/:id/components/:cId` | Cambiar status |
| PATCH | `/api/campaigns/:id/components/:cId/config` | Cambiar config |
| DELETE | `/api/campaigns/:id/components/:cId` | Quitar componente |

### 6.8 Events
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/events?campaignId=X` | Listar eventos |
| POST | `/api/events/product` | Crear evento producto |
| POST | `/api/events/poll` | Crear evento encuesta |
| POST | `/api/events/contest` | Crear evento concurso |
| POST | `/api/events/:campaignId` | Evento generico |

### 6.9 Broadcasts (Dashboard)
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/broadcasts?status=X&campaignId=Y` | Listar broadcasts |
| GET | `/api/broadcasts/:broadcastId` | Obtener broadcast + polls + contests |
| POST | `/api/broadcasts` | Crear broadcast |
| PUT | `/api/broadcasts/:broadcastId` | Actualizar broadcast |
| DELETE | `/api/broadcasts/:broadcastId` | Eliminar broadcast |

### 6.10 Polls (Dashboard)
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/broadcasts/:broadcastId/polls` | Polls del broadcast |
| POST | `/api/broadcasts/:broadcastId/polls` | Crear poll con opciones |
| PUT | `/api/polls/:pollId` | Actualizar poll (isActive, etc.) |
| DELETE | `/api/polls/:pollId` | Eliminar poll |
| GET | `/api/polls/:pollId/results` | Resultados con porcentajes |

### 6.11 Contests (Dashboard)
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/broadcasts/:broadcastId/contests` | Contests del broadcast |
| POST | `/api/broadcasts/:broadcastId/contests` | Crear contest |
| PUT | `/api/contests/:contestId` | Actualizar contest |
| DELETE | `/api/contests/:contestId` | Eliminar contest |

### 6.12 Broadcasts (Admin v1 - Bearer Auth)
| Metodo | Ruta | Auth | Descripcion |
|--------|------|------|-------------|
| POST | `/v1/broadcasts` | Bearer | Crear broadcast |
| GET | `/v1/broadcasts?status=X&campaignId=Y` | Bearer | Listar broadcasts |
| GET | `/v1/broadcasts/:broadcastId` | Bearer | Obtener broadcast |
| PUT | `/v1/broadcasts/:broadcastId` | Bearer | Actualizar broadcast |
| DELETE | `/v1/broadcasts/:broadcastId` | Bearer | Eliminar broadcast |
| GET | `/v1/campaigns/:campaignId/broadcasts` | Bearer | Broadcasts de campana |
| POST | `/v1/broadcasts/:broadcastId/polls` | Bearer | Crear poll |
| GET | `/v1/broadcasts/:broadcastId/polls` | Bearer | Polls del broadcast |
| PUT | `/v1/polls/:pollId` | Bearer | Actualizar poll |
| DELETE | `/v1/polls/:pollId` | Bearer | Eliminar poll |
| GET | `/v1/polls/:pollId/results` | Bearer | Resultados poll |
| POST | `/v1/broadcasts/:broadcastId/contests` | Bearer | Crear contest |
| GET | `/v1/broadcasts/:broadcastId/contests` | Bearer | Contests del broadcast |
| PUT | `/v1/contests/:contestId` | Bearer | Actualizar contest |
| DELETE | `/v1/contests/:contestId` | Bearer | Eliminar contest |
| GET | `/v1/contests/:contestId/participations` | Bearer | Participaciones |

---

## 7. Eventos WebSocket <a name="eventos-websocket"></a>

### Conexion

```
ws://HOST/ws/:campaignId
wss://HOST/ws/:campaignId  (produccion)
```

Cada campana tiene su propio canal aislado. Los clientes se conectan a un campaignId y reciben solo eventos de esa campana.

### Eventos que recibe el SDK

| Evento | Cuando se envia | Payload |
|--------|----------------|---------|
| `campaign_started` | Campana inicia (startDate alcanzada) | `{ type, campaignId, startDate, endDate, matchId? }` |
| `campaign_ended` | Campana finaliza (endDate alcanzada) | `{ type, campaignId, endDate }` |
| `campaign_paused` | Admin pausa campana | `{ type, campaignId, timestamp }` |
| `campaign_resumed` | Admin reanuda campana | `{ type, campaignId, timestamp }` |
| `component_status_changed` | Componente se activa/desactiva | `{ type, campaignId, componentId, status, component: {id, type, name, config}, matchId? }` |
| `component_config_updated` | Config de componente cambia | `{ type, campaignId, componentId, component: {id, type, name, config}, matchId? }` |
| `config:updated` | Config de engagement/UI cambia | `{ type, campaignId, matchId?, sections: ['engagement'|'ui'], version, timestamp }` |
| `product` | Evento de producto enviado | `{ type: 'product', data: {...}, campaignLogo?, timestamp }` |
| `poll` | Evento de encuesta enviado | `{ type: 'poll', data: {...}, campaignLogo?, timestamp }` |
| `contest` | Evento de concurso enviado | `{ type: 'contest', data: {...}, campaignLogo?, timestamp }` |
| `poll_results_updated` | Alguien vota en una encuesta | `{ type, broadcastId, pollId, results: { question, totalVotes, options: [{id, text, voteCount, percentage}] } }` |
| `broadcast_status_changed` | Broadcast cambia de estado | `{ type, broadcastId, status }` |

---

## 8. Sistema de Broadcasts <a name="sistema-de-broadcasts"></a>

### Concepto
Un Broadcast representa una transmision en vivo o evento (ej: un partido de futbol). Se asocia opcionalmente a una Campaign.

### Ciclo de vida
```
upcoming ──(startTime alcanzada)──> live ──(endTime alcanzada)──> ended
```

El Scheduler revisa cada minuto y transiciona automaticamente.

### Generacion de Broadcast ID
```
broadcastName: "Barcelona vs PSG"
startTime: "2025-01-23T20:00:00Z"

broadcastId = slugify("Barcelona vs PSG") + "-" + "2025-01-23"
           = "barcelona-vs-psg-2025-01-23"

Si ya existe: "barcelona-vs-psg-2025-01-23-1706012345678"
```

### Crear Broadcast (Body)
```json
{
  "broadcastName": "Barcelona vs PSG",
  "campaignId": 1,
  "channelId": null,
  "startTime": "2025-01-23T20:00:00Z",
  "endTime": "2025-01-23T23:00:00Z",
  "metadata": { "league": "Champions League", "round": "Quarter Final" }
}
```

---

## 9. Sistema de Engagement (Polls y Contests) <a name="sistema-de-engagement"></a>

### 9.1 Polls (Encuestas)

**Crear Poll:**
```json
POST /api/broadcasts/:broadcastId/polls
{
  "question": "Mejor jugador del partido?",
  "options": ["Messi", "Mbappe", "Dembele"]
}
```

**Votar (SDK):**
```json
POST /v1/engagement/polls/:pollId/vote
{
  "optionId": 1,
  "userId": "user-abc-123",
  "broadcastId": "barcelona-psg-2025-01-23"
}
```

- Un usuario solo puede votar 1 vez por poll (UNIQUE constraint)
- Despues de votar, se emite `poll_results_updated` via WebSocket
- Los porcentajes se calculan: `(voteCount / totalVotes) * 100`, redondeado a 2 decimales

### 9.2 Contests (Concursos)

**Tipos disponibles:** quiz, giveaway, trivia, prediction

**Crear Contest:**
```json
POST /api/broadcasts/:broadcastId/contests
{
  "title": "Win a Jersey",
  "description": "Answer correctly to win",
  "prize": "Signed Jersey",
  "contestType": "giveaway"
}
```

**Participar (SDK):**
```json
POST /v1/engagement/contests/:contestId/participate
{
  "userId": "user-abc-123",
  "broadcastId": "barcelona-psg-2025-01-23",
  "answers": { "q1": "answer1" }
}
```

- Un usuario solo puede participar 1 vez por contest (UNIQUE constraint)

---

## 10. Configuracion Dinamica <a name="configuracion-dinamica"></a>

Cada campana puede tener configuraciones personalizadas:

### Brand
- `brandName`, `brandIconAsset`, `brandIconUrl`, `brandLogoUrl`

### Engagement Config
- `demoMode`: Modo demo (sin datos reales)
- `defaultPollDuration`: Duracion de polls en segundos (default: 300)
- `defaultContestDuration`: Duracion de contests en segundos (default: 600)
- `maxVotesPerPoll`: Maximo votos por poll (default: 1)
- `maxContestsPerMatch`: Maximo concursos por match (default: 10)
- `enableRealTimeUpdates`: Updates en tiempo real (default: true)
- `updateInterval`: Intervalo de actualizacion en ms (default: 1000)

### UI Config
- `primaryColor`: Color primario (default: #007AFF)
- `secondaryColor`: Color secundario (default: #5856D6)
- `componentConfigs`: Configs visuales de componentes

### Feature Flags
- `enableLiveStreaming`: Streaming en vivo
- `enableProductCatalog`: Catalogo de productos
- `enableEngagement`: Engagement general
- `enablePolls`: Encuestas
- `enableContests`: Concursos

Cuando se actualizan, se emite `config:updated` via WebSocket.

---

## 11. Scheduler / Cron Jobs <a name="scheduler"></a>

**Archivo:** `server/scheduler.ts`

Ejecuta cada 1 minuto (configurable via `SCHEDULER_INTERVAL_MINUTES`):

1. **checkScheduledComponents()**: Activa/desactiva componentes de campana segun sus `scheduledTime` y `endTime`
2. **updateBroadcastStatuses()**: Transiciona broadcasts:
   - `upcoming` → `live` (cuando `now >= startTime`)
   - `live` → `ended` (cuando `now >= endTime`)
   - Emite `broadcast_status_changed` via WebSocket

---

## 12. Paginas del Dashboard <a name="paginas-dashboard"></a>

| Ruta | Pagina | Archivo |
|------|--------|---------|
| `/` | Campanas (inicio) | `campaigns.tsx` |
| `/campaigns` | Lista de campanas | `campaigns.tsx` |
| `/campaigns/new` | Crear campana | `new-campaign.tsx` |
| `/campaign/:id/dashboard` | Dashboard de campana | `campaign-dashboard.tsx` |
| `/campaign/:id/advanced` | Campana avanzada | `advanced-campaign.tsx` |
| `/campaign/:id/admin` | Admin de campana | `admin.tsx` |
| `/campaign/:name/:id` | Viewer publico | `campaign-viewer.tsx` |
| `/broadcasts` | Lista de broadcasts | `broadcasts.tsx` |
| `/broadcasts/:broadcastId` | Detalle de broadcast | `broadcast-detail.tsx` |
| `/components` | Libreria de componentes | `components.tsx` |
| `/client-apps` | Gestion de API Keys | `client-apps.tsx` |
| `/user-session` | Sesion de usuario | `user-session.tsx` |
| `/viewer` | Viewer general | `viewer.tsx` |
| `/docs` | Documentacion | `docs.tsx` |

---

## 13. Flujos Completos <a name="flujos-completos"></a>

### Flujo 1: Setup Inicial (SDK iOS)

```
1. Dashboard: Crear User → POST /api/users/ensure
2. Dashboard: Crear Client App → POST /api/client-apps (obtiene apiKey)
3. Dashboard: Crear Channel → (automatico con Client App)
4. Dashboard: Crear Campaign → POST /api/campaigns
5. iOS SDK: GET /v1/sdk/campaigns?apiKey=xxx (descubre campanas activas)
6. iOS SDK: Conectar WebSocket ws://host/ws/:campaignId
7. iOS SDK: GET /v1/campaigns/:id/config?apiKey=xxx (obtiene config completa)
```

### Flujo 2: Broadcast con Engagement

```
1. Dashboard: Crear Broadcast → POST /api/broadcasts { broadcastName, campaignId, startTime, endTime }
2. Dashboard: Crear Poll → POST /api/broadcasts/:broadcastId/polls { question, options }
3. Dashboard: Crear Contest → POST /api/broadcasts/:broadcastId/contests { title, contestType }
4. Scheduler: Cuando startTime llega → status: "upcoming" → "live"
5. iOS SDK: GET /v1/engagement/polls?broadcastId=xxx (obtiene polls activas)
6. iOS SDK: POST /v1/engagement/polls/:pollId/vote (vota)
7. WebSocket: Recibe poll_results_updated (resultados actualizados en real-time)
8. iOS SDK: GET /v1/engagement/contests?broadcastId=xxx (obtiene contests)
9. iOS SDK: POST /v1/engagement/contests/:contestId/participate (participa)
10. Scheduler: Cuando endTime llega → status: "live" → "ended"
11. WebSocket: Recibe broadcast_status_changed { status: "ended" }
```

### Flujo 3: Producto en Tiempo Real

```
1. Dashboard: POST /api/events/product { campaignId, data: { name, price, imageUrl, ... } }
2. Backend: Guarda en DB + broadcast via WebSocket
3. iOS SDK: Recibe evento `product` en WebSocket
4. iOS SDK: Muestra el producto en la UI
```

### Flujo 4: Segmentacion de Usuarios

```
1. Dashboard: Campaign Settings → Enable segmentation
   - Seleccionar paises: ["MX", "AR", "CO"]
   - Porcentaje: 50%
2. iOS SDK: GET /v1/offers?apiKey=xxx&campaignId=1&userId=user123&userCountry=MX
3. Backend: 
   - Verifica si userCountry esta en targetCountries
   - Calcula SHA256(userId:campaignId) % 100 < targetPercentage
   - Si pasa: devuelve ofertas
   - Si no: devuelve array vacio
```

---

## Variables de Entorno

| Variable | Descripcion |
|----------|-------------|
| `DATABASE_URL` | URL de conexion PostgreSQL |
| `SESSION_SECRET` | Secret para JWT tokens |
| `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` | Conexion DB individual |
| `SCHEDULER_INTERVAL_MINUTES` | Intervalo del cron (default: 1) |
| `DEFAULT_OBJECT_STORAGE_BUCKET_ID` | Bucket de Object Storage |

---

## Fases Pendientes (Diferidas)

### Fase 5: Scheduling con Video Timing
- Sincronizacion de engagement con timestamps del video
- Video timeline markers
- Activacion de polls/contests en momentos especificos del stream

### Fase 6: Redis/Bull Message Queue
- Cola de mensajes para procesamiento asincrono
- Rate limiting de votos
- Agregacion de eventos en batch
- Alta disponibilidad y escalabilidad horizontal
