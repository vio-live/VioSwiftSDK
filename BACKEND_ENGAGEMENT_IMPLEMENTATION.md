# Guía de Implementación Backend - Sistema de Engagement (Polls y Contests)

## Resumen Ejecutivo

Este documento explica la implementación del sistema de Engagement (polls y contests) para el SDK Swift. Este sistema permite:

1. **Polls asociadas a partidos específicos** (`matchId`)
2. **Contests asociados a partidos específicos** (`matchId`)
3. **Votación en tiempo real** con actualizaciones vía WebSocket
4. **Participación en contests** con respuestas/quiz

**Nota:** Este sistema es completamente nuevo y no existe en el backend actual. Se puede implementar después de completar el sistema de campañas context-aware.

**Estado:** ⏳ Pendiente de implementación - No crítico para MVP

---

## Conceptos Clave

### 1. Poll (Encuesta)

Una poll es una pregunta con múltiples opciones donde los usuarios pueden votar. Cada poll está asociada a un partido específico (`matchId`).

**Características:**
- Una pregunta con múltiples opciones
- Cada opción tiene un contador de votos
- Porcentajes calculados automáticamente
- Tiempo de inicio y fin
- Estado activo/inactivo

### 2. Contest (Concurso)

Un contest es un concurso asociado a un partido donde los usuarios pueden participar. Puede ser un quiz o un giveaway.

**Tipos:**
- `quiz`: Concurso con preguntas y respuestas
- `giveaway`: Sorteo simple

---

## Endpoints Requeridos

### 1. GET /v1/engagement/polls

**Propósito:** Obtener polls activas para un partido específico.

**Request:**
```
GET /v1/engagement/polls?apiKey={sdkApiKey}&matchId={matchId}
```

**Query Parameters:**
- `apiKey` (requerido): API key del SDK
- `matchId` (requerido): ID del partido

**Respuesta:**
```json
{
  "polls": [
    {
      "id": "poll-1",
      "matchId": "barcelona-psg-2025-01-23",
      "question": "Hvem vinner denne kampen?",
      "options": [
        {
          "id": "opt1",
          "text": "Barcelona",
          "voteCount": 3456,
          "percentage": 65.0
        },
        {
          "id": "opt2",
          "text": "PSG",
          "voteCount": 1234,
          "percentage": 23.0
        },
        {
          "id": "opt3",
          "text": "Uavgjort",
          "voteCount": 645,
          "percentage": 12.0
        }
      ],
      "startTime": "2025-01-23T20:00:00Z",
      "endTime": "2025-01-23T21:00:00Z",
      "isActive": true,
      "totalVotes": 5335
    }
  ]
}
```

**Lógica Backend:**
- Filtrar polls por `matchId` (requerido)
- Solo retornar polls activas:
  - `isActive: true`
  - Dentro de fechas (`startTime` <= ahora <= `endTime`)
- Calcular `percentage` automáticamente basado en `voteCount` y `totalVotes`
- Ordenar por `startTime` (más recientes primero)
- Si no hay polls activas, retornar array vacío

**Validaciones:**
- `matchId` es requerido - retornar error 400 si falta
- `apiKey` debe ser válida

**Errores:**
```json
// matchId faltante
{
  "error": "matchId is required",
  "code": "MISSING_MATCH_ID"
}

// matchId inválido
{
  "error": "Invalid matchId",
  "code": "INVALID_MATCH_ID"
}
```

---

### 2. POST /v1/engagement/polls/{pollId}/vote

**Propósito:** Registrar un voto en una poll.

**Request:**
```json
{
  "apiKey": "sdk_api_key_...",
  "matchId": "barcelona-psg-2025-01-23",
  "optionId": "opt1"
}
```

**Headers:**
```
Content-Type: application/json
```

**Validaciones Backend:**
1. Verificar que `pollId` existe
2. Verificar que la poll pertenece al `matchId` especificado (`poll.matchId == request.matchId`)
3. Verificar que la poll está activa:
   - `isActive: true`
   - Dentro de fechas (`startTime` <= ahora <= `endTime`)
4. Verificar que `optionId` existe en la poll
5. Verificar que el usuario no ha votado antes:
   - Usar `deviceId` o `sessionId` del SDK
   - Verificar en tabla `poll_votes`
6. Incrementar `voteCount` de la opción seleccionada
7. Actualizar `totalVotes` de la poll
8. Recalcular `percentage` de todas las opciones
9. Enviar evento WebSocket `poll_results_updated` con resultados actualizados

**Respuesta exitosa:**
```json
{
  "success": true,
  "pollId": "poll-1",
  "optionId": "opt1",
  "updatedResults": {
    "totalVotes": 5336,
    "options": [
      {
        "optionId": "opt1",
        "voteCount": 3457,
        "percentage": 65.0
      },
      {
        "optionId": "opt2",
        "voteCount": 1234,
        "percentage": 23.0
      },
      {
        "optionId": "opt3",
        "voteCount": 645,
        "percentage": 12.0
      }
    ]
  }
}
```

**Errores:**
```json
// Poll no encontrada
{
  "error": "Poll not found",
  "code": "POLL_NOT_FOUND"
}

// Poll cerrada
{
  "error": "Poll is no longer active",
  "code": "POLL_CLOSED"
}

// Usuario ya votó
{
  "error": "You have already voted in this poll",
  "code": "ALREADY_VOTED"
}

// matchId no coincide
{
  "error": "Poll does not belong to this match",
  "code": "MATCH_ID_MISMATCH"
}

// Opción inválida
{
  "error": "Invalid optionId",
  "code": "INVALID_OPTION"
}
```

**Códigos HTTP:**
- `200`: Voto registrado exitosamente
- `400`: Error de validación (datos faltantes o inválidos)
- `404`: Poll no encontrada
- `409`: Conflicto (usuario ya votó)
- `500`: Error del servidor

---

### 3. GET /v1/engagement/contests

**Propósito:** Obtener contests activos para un partido específico.

**Request:**
```
GET /v1/engagement/contests?apiKey={sdkApiKey}&matchId={matchId}
```

**Query Parameters:**
- `apiKey` (requerido): API key del SDK
- `matchId` (requerido): ID del partido

**Respuesta:**
```json
{
  "contests": [
    {
      "id": "contest-1",
      "matchId": "barcelona-psg-2025-01-23",
      "title": "Power Konkurranse",
      "description": "Delta og vinn et gavekort på 5000kr ved å svare på et lite quiz",
      "prize": "Gavekort på 5000kr",
      "contestType": "quiz",
      "startTime": "2025-01-23T20:15:00Z",
      "endTime": "2025-01-23T20:45:00Z",
      "isActive": true
    },
    {
      "id": "contest-2",
      "matchId": "barcelona-psg-2025-01-23",
      "title": "Power Konkurranse",
      "description": "Delta og vinn to billetter til Champions League",
      "prize": "To billetter til Champions League",
      "contestType": "giveaway",
      "startTime": "2025-01-23T20:30:00Z",
      "endTime": "2025-01-23T21:00:00Z",
      "isActive": true
    }
  ]
}
```

**Lógica Backend:**
- Similar a polls: filtrar por `matchId` (requerido)
- Solo retornar contests activos:
  - `isActive: true`
  - Dentro de fechas (`startTime` <= ahora <= `endTime`)
- Ordenar por `startTime` (más recientes primero)
- Si no hay contests activos, retornar array vacío

**Validaciones:**
- `matchId` es requerido
- `apiKey` debe ser válida

---

### 4. POST /v1/engagement/contests/{contestId}/participate

**Propósito:** Registrar participación en un contest.

**Request:**
```json
{
  "apiKey": "sdk_api_key_...",
  "matchId": "barcelona-psg-2025-01-23",
  "answers": {
    "question1": "answer1",
    "question2": "answer2"
  }
}
```

**Headers:**
```
Content-Type: application/json
```

**Validaciones Backend:**
1. Verificar que `contestId` existe
2. Verificar que el contest pertenece al `matchId` especificado (`contest.matchId == request.matchId`)
3. Verificar que el contest está activo:
   - `isActive: true`
   - Dentro de fechas (`startTime` <= ahora <= `endTime`)
4. Verificar que el usuario no ha participado antes:
   - Usar `deviceId` o `sessionId` del SDK
   - Verificar en tabla `contest_participations`
5. Si es tipo `quiz`, validar respuestas (opcional - puede ser validación básica)
6. Guardar participación con respuestas
7. Retornar confirmación

**Respuesta exitosa:**
```json
{
  "success": true,
  "contestId": "contest-1",
  "message": "Du har deltatt i konkurransen!",
  "participationId": "part-12345"
}
```

**Errores:**
```json
// Contest no encontrado
{
  "error": "Contest not found",
  "code": "CONTEST_NOT_FOUND"
}

// Contest cerrado
{
  "error": "Contest is no longer active",
  "code": "CONTEST_CLOSED"
}

// Usuario ya participó
{
  "error": "You have already participated in this contest",
  "code": "ALREADY_PARTICIPATED"
}

// matchId no coincide
{
  "error": "Contest does not belong to this match",
  "code": "MATCH_ID_MISMATCH"
}
```

**Códigos HTTP:**
- `200`: Participación registrada exitosamente
- `400`: Error de validación
- `404`: Contest no encontrado
- `409`: Conflicto (usuario ya participó)
- `500`: Error del servidor

---

## WebSocket Events

### Nuevo Evento: poll_results_updated

**Propósito:** Notificar actualizaciones de resultados de polls en tiempo real.

**Estructura:**
```json
{
  "type": "poll_results_updated",
  "matchId": "barcelona-psg-2025-01-23",
  "pollId": "poll-1",
  "results": {
    "totalVotes": 5336,
    "options": [
      {
        "optionId": "opt1",
        "voteCount": 3457,
        "percentage": 65.0
      },
      {
        "optionId": "opt2",
        "voteCount": 1234,
        "percentage": 23.0
      },
      {
        "optionId": "opt3",
        "voteCount": 645,
        "percentage": 12.0
      }
    ]
  }
}
```

**Lógica Backend:**
- Enviar este evento después de cada voto registrado exitosamente
- Incluir `matchId` para que el SDK filtre correctamente
- El SDK actualizará los resultados localmente sin necesidad de recargar
- Enviar a todos los clientes conectados al WebSocket del partido

**Cuándo enviar:**
- Inmediatamente después de registrar un voto
- Incluir resultados completos actualizados
- Asegurar que `matchId` coincida con el partido de la poll

---

## Estructura de Base de Datos

### Tabla: polls
```sql
CREATE TABLE polls (
  id VARCHAR(255) PRIMARY KEY,
  match_id VARCHAR(255) NOT NULL, -- Requerido: cada poll pertenece a un partido
  question TEXT NOT NULL,
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,
  total_votes INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_match_active (match_id, is_active, start_time, end_time),
  INDEX idx_active (is_active, start_time, end_time)
);
```

### Tabla: poll_options
```sql
CREATE TABLE poll_options (
  id VARCHAR(255) PRIMARY KEY,
  poll_id VARCHAR(255) NOT NULL,
  text VARCHAR(500) NOT NULL,
  vote_count INT DEFAULT 0,
  display_order INT DEFAULT 0, -- Para ordenar opciones
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE,
  INDEX idx_poll (poll_id)
);
```

### Tabla: poll_votes
```sql
CREATE TABLE poll_votes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  poll_id VARCHAR(255) NOT NULL,
  option_id VARCHAR(255) NOT NULL,
  user_id VARCHAR(255) NOT NULL, -- deviceId o sessionId del SDK
  match_id VARCHAR(255) NOT NULL, -- Para validación
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE,
  FOREIGN KEY (option_id) REFERENCES poll_options(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_poll (poll_id, user_id), -- Un voto por usuario
  INDEX idx_poll (poll_id),
  INDEX idx_match (match_id),
  INDEX idx_user (user_id)
);
```

### Tabla: contests
```sql
CREATE TABLE contests (
  id VARCHAR(255) PRIMARY KEY,
  match_id VARCHAR(255) NOT NULL, -- Requerido
  title VARCHAR(500) NOT NULL,
  description TEXT,
  prize VARCHAR(500),
  contest_type VARCHAR(50) NOT NULL, -- 'quiz' o 'giveaway'
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_match_active (match_id, is_active, start_time, end_time),
  INDEX idx_active (is_active, start_time, end_time)
);
```

### Tabla: contest_participations
```sql
CREATE TABLE contest_participations (
  id INT PRIMARY KEY AUTO_INCREMENT,
  contest_id VARCHAR(255) NOT NULL,
  user_id VARCHAR(255) NOT NULL, -- deviceId o sessionId del SDK
  match_id VARCHAR(255) NOT NULL, -- Para validación
  answers JSON, -- Para quizzes: {"question1": "answer1", "question2": "answer2"}
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (contest_id) REFERENCES contests(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_contest (contest_id, user_id), -- Una participación por usuario
  INDEX idx_contest (contest_id),
  INDEX idx_match (match_id),
  INDEX idx_user (user_id)
);
```

---

## Migraciones Necesarias

### Migración 1: Crear tablas de polls
```sql
CREATE TABLE polls (
  id VARCHAR(255) PRIMARY KEY,
  match_id VARCHAR(255) NOT NULL,
  question TEXT NOT NULL,
  start_time TIMESTAMP NULL,
  end_time TIMESTAMP NULL,
  is_active BOOLEAN DEFAULT TRUE,
  total_votes INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_match_active (match_id, is_active, start_time, end_time),
  INDEX idx_active (is_active, start_time, end_time)
);

CREATE TABLE poll_options (
  id VARCHAR(255) PRIMARY KEY,
  poll_id VARCHAR(255) NOT NULL,
  text VARCHAR(500) NOT NULL,
  vote_count INT DEFAULT 0,
  display_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE,
  INDEX idx_poll (poll_id)
);

CREATE TABLE poll_votes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  poll_id VARCHAR(255) NOT NULL,
  option_id VARCHAR(255) NOT NULL,
  user_id VARCHAR(255) NOT NULL,
  match_id VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (poll_id) REFERENCES polls(id) ON DELETE CASCADE,
  FOREIGN KEY (option_id) REFERENCES poll_options(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_poll (poll_id, user_id),
  INDEX idx_poll (poll_id),
  INDEX idx_match (match_id),
  INDEX idx_user (user_id)
);
```

### Migración 2: Crear tablas de contests
```sql
CREATE TABLE contests (
  id VARCHAR(255) PRIMARY KEY,
  match_id VARCHAR(255) NOT NULL,
  title VARCHAR(500) NOT NULL,
  description TEXT,
  prize VARCHAR(500),
  contest_type VARCHAR(50) NOT NULL,
  start_time TIMESTAMP NULL,
  end_time TIMESTAMP NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_match_active (match_id, is_active, start_time, end_time),
  INDEX idx_active (is_active, start_time, end_time)
);

CREATE TABLE contest_participations (
  id INT PRIMARY KEY AUTO_INCREMENT,
  contest_id VARCHAR(255) NOT NULL,
  user_id VARCHAR(255) NOT NULL,
  match_id VARCHAR(255) NOT NULL,
  answers JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (contest_id) REFERENCES contests(id) ON DELETE CASCADE,
  UNIQUE KEY unique_user_contest (contest_id, user_id),
  INDEX idx_contest (contest_id),
  INDEX idx_match (match_id),
  INDEX idx_user (user_id)
);
```

---

## Validaciones y Reglas de Negocio

### 1. Validación de matchId
- `matchId` es REQUERIDO para polls y contests
- Debe coincidir exactamente con el `matchId` del recurso
- Validar que `matchId` en el request coincida con el `matchId` del poll/contest

### 2. Validación de Votos
- Un usuario solo puede votar UNA vez por poll
- Usar `deviceId` o `sessionId` para identificar usuarios únicos
- Validar que la poll esté activa antes de registrar voto
- Validar que `optionId` pertenezca a la poll

### 3. Cálculo de Porcentajes
- Calcular automáticamente después de cada voto
- Fórmula: `percentage = (voteCount / totalVotes) * 100`
- Redondear a 2 decimales
- Actualizar en tiempo real vía WebSocket

### 4. Validación de Participaciones
- Un usuario solo puede participar UNA vez por contest
- Validar que el contest esté activo
- Si es tipo `quiz`, validar respuestas (opcional)

### 5. Filtrado de Polls/Contests
- Solo retornar polls/contests activas para el `matchId` especificado
- Validar que `matchId` en el request coincida con el `matchId` del recurso
- No retornar polls/contests de otros partidos

---

## Flujo de Trabajo Completo

### Escenario: Usuario vota en poll

1. **SDK carga polls:**
   - `GET /v1/engagement/polls?apiKey={sdkApiKey}&matchId=barcelona-psg-2025-01-23`
   - Backend retorna polls activas para ese partido

2. **Usuario selecciona opción:**
   - SDK muestra poll con opciones
   - Usuario toca una opción

3. **SDK envía voto:**
   - `POST /v1/engagement/polls/{pollId}/vote`
   - Body: `{ "apiKey": "...", "matchId": "...", "optionId": "opt1" }`

4. **Backend valida y procesa:**
   - Valida `matchId` coincide
   - Valida poll está activa
   - Valida usuario no ha votado
   - Incrementa `voteCount`
   - Actualiza `totalVotes`
   - Recalcula porcentajes

5. **Backend envía WebSocket:**
   - Evento `poll_results_updated` con resultados actualizados
   - Todos los clientes conectados reciben actualización

6. **SDK actualiza UI:**
   - Recibe evento WebSocket
   - Actualiza resultados localmente
   - Muestra nuevos porcentajes en tiempo real

---

## Testing y Validación

### Casos de Prueba Recomendados

1. **Cargar polls:**
   - Verificar que solo retorna polls del `matchId` especificado
   - Verificar que solo retorna polls activas
   - Verificar cálculo de porcentajes

2. **Votar en poll:**
   - Verificar validación de `matchId`
   - Verificar validación de poll activa
   - Verificar que usuario no puede votar dos veces
   - Verificar actualización de contadores
   - Verificar envío de evento WebSocket

3. **Cargar contests:**
   - Similar a polls

4. **Participar en contest:**
   - Verificar validación de `matchId`
   - Verificar validación de contest activo
   - Verificar que usuario no puede participar dos veces
   - Verificar guardado de respuestas (si es quiz)

5. **WebSocket Events:**
   - Verificar que eventos incluyan `matchId`
   - Verificar que SDK filtre eventos por `matchId`
   - Verificar formato correcto de resultados

---

## Priorización de Implementación

### ⏳ Fase Futura (No Crítica)

Este sistema puede implementarse después de completar el sistema de campañas context-aware. No es crítico para el MVP.

**Orden sugerido:**
1. Crear tablas de base de datos
2. Implementar `GET /v1/engagement/polls`
3. Implementar `POST /v1/engagement/polls/{pollId}/vote`
4. Implementar evento WebSocket `poll_results_updated`
5. Implementar `GET /v1/engagement/contests`
6. Implementar `POST /v1/engagement/contests/{contestId}/participate`

---

## Preguntas y Respuestas

**P: ¿Cómo identificar usuarios únicos?**
R: Usar `deviceId` o `sessionId` generado por el SDK. El SDK puede generar un ID único por dispositivo usando `UIDevice.current.identifierForVendor`.

**P: ¿Qué pasa si un usuario vota dos veces?**
R: El backend debe rechazar el segundo voto con error `ALREADY_VOTED` (409). La validación se hace con `UNIQUE KEY unique_user_poll` en la base de datos.

**P: ¿Cómo manejar usuarios anónimos?**
R: Usar `deviceId` o `sessionId` para identificar usuarios únicos. No se requiere autenticación de usuario.

**P: ¿Los porcentajes se calculan en tiempo real?**
R: Sí, después de cada voto se recalculan y se envían vía WebSocket a todos los clientes conectados.

**P: ¿Qué formato usar para `matchId`?**
R: Debe coincidir con el formato usado en el sistema de campañas. Recomendamos: `{home_team}-{away_team}-{date}`.

---

## Contacto y Soporte

Para preguntas sobre la implementación, contactar al equipo del SDK Swift.

**Documentación del SDK:**
- Ver código fuente en: `Sources/ReachuCore/Managers/EngagementManager.swift`
- Ver modelos en: `Sources/ReachuCore/Models/EngagementModels.swift`
