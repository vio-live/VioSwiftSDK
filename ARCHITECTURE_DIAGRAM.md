# Swift SDK and Backend Architecture

```mermaid
graph TB
    subgraph "Swift SDK - UI Layer"
        UI[UI Components<br/>REngagementPollCard<br/>REngagementContestCard]
    end
    
    subgraph "Swift SDK - Manager Layer"
        EM[EngagementManager<br/>Singleton<br/>@Published Properties]
        VSM[VideoSyncManager<br/>Video Synchronization]
    end
    
    subgraph "Swift SDK - Repository Layer"
        ERP[EngagementRepositoryProtocol<br/>Protocol]
        BER[BackendEngagementRepository<br/>Backend Implementation]
        DER[DemoEngagementRepository<br/>Demo Implementation]
    end
    
    subgraph "Swift SDK - Data Layer"
        EC[EngagementCache<br/>In-Memory Cache]
        NC[NetworkClient<br/>URLSession]
        RH[RequestRetryHandler<br/>Retry Logic]
        UD[UserDefaults<br/>Persistent userId]
    end
    
    subgraph "Swift SDK - Models"
        PM[Poll Model]
        CM[Contest Model]
        PRM[PollResults Model]
        EMODEL[EngagementError]
    end
    
    subgraph "Backend - REST API"
        EP1[GET /v1/engagement/polls<br/>Query: broadcastId, limit, offset]
        EP2[POST /v1/engagement/polls/:pollId/vote<br/>Body: userId, optionId, broadcastId]
        EP3[GET /v1/engagement/contests<br/>Query: broadcastId, limit, offset]
        EP4[POST /v1/engagement/contests/:contestId/participate<br/>Body: userId, broadcastId, answers]
    end
    
    subgraph "Backend - Service Layer"
        VS[VoteProcessor<br/>Processes Votes]
        CS[ContestProcessor<br/>Processes Participations]
        RL[RateLimiter<br/>Request Limiting]
    end
    
    subgraph "Backend - Database"
        DB[(PostgreSQL<br/>Polls, Contests<br/>Votes, Participations)]
    end
    
    %% Data Loading Flow
    UI -->|loadEngagement| EM
    EM -->|loadPolls/loadContests| ERP
    ERP -->|implements| BER
    ERP -->|implements| DER
    
    BER -->|check cache| EC
    BER -->|fetch data| NC
    BER -->|retry logic| RH
    BER -->|get/create| UD
    
    NC -->|GET request| EP1
    NC -->|GET request| EP3
    
    EP1 -->|validate broadcastId| DB
    EP3 -->|validate broadcastId| DB
    EP1 -->|return polls + pagination| NC
    EP3 -->|return contests + pagination| NC
    
    NC -->|decode response| BER
    BER -->|validate data| PM
    BER -->|validate data| CM
    BER -->|cache results| EC
    BER -->|return models| EM
    
    EM -->|store| PM
    EM -->|store| CM
    EM -->|sync time| VSM
    
    %% Voting Flow
    UI -->|voteInPoll| EM
    EM -->|validate poll| PM
    EM -->|check hasVoted| EM
    EM -->|voteInPoll| ERP
    ERP -->|submitVote| BER
    
    BER -->|getOrCreateUserId| UD
    BER -->|convert to Int| BER
    BER -->|POST request| NC
    NC -->|POST /polls/:id/vote| EP2
    
    EP2 -->|rate limit check| RL
    EP2 -->|process vote| VS
    VS -->|atomic transaction| DB
    EP2 -->|return success| NC
    NC -->|handle response| BER
    BER -->|invalidate cache| EC
    BER -->|return| EM
    EM -->|update local state| EM
    EM -->|optimistic update| PRM
    
    %% Participation Flow
    UI -->|participateInContest| EM
    EM -->|validate contest| CM
    EM -->|participateInContest| ERP
    ERP -->|submitParticipation| BER
    
    BER -->|getOrCreateUserId| UD
    BER -->|convert to Int| BER
    BER -->|POST request| NC
    NC -->|POST /contests/:id/participate| EP4
    
    EP4 -->|rate limit check| RL
    EP4 -->|process participation| CS
    CS -->|atomic transaction| DB
    EP4 -->|return success| NC
    NC -->|handle response| BER
    BER -->|invalidate cache| EC
    BER -->|return| EM
    EM -->|update local state| EM
    
    %% Error Handling
    EP1 -->|404| EMODEL
    EP3 -->|404| EMODEL
    EP2 -->|429| EMODEL
    EP4 -->|429| EMODEL
    NC -->|network error| EMODEL
    BER -->|throw| EMODEL
    EM -->|catch| EMODEL
    
    style EM fill:#e1f5ff
    style BER fill:#fff4e1
    style EP1 fill:#e8f5e9
    style EP2 fill:#e8f5e9
    style EP3 fill:#e8f5e9
    style EP4 fill:#e8f5e9
    style DB fill:#f3e5f5
    style EC fill:#fff9c4
    style UD fill:#fff9c4
```

## Main Flows

### 1. Loading Polls/Contests
1. UI calls `EngagementManager.loadEngagement()`
2. Manager delegates to `BackendEngagementRepository`
3. Repository checks cache first
4. If no cache, makes HTTP request with pagination
5. Backend validates `broadcastId` and returns paginated data
6. Repository decodes, validates, and caches results
7. Manager updates published state
8. UI updates automatically

### 2. Voting in Poll
1. UI calls `EngagementManager.voteInPoll()`
2. Manager validates poll exists and is active
3. Manager checks user hasn't voted
4. Repository gets/creates persistent `userId`
5. Repository converts IDs to Int and makes POST request
6. Backend validates rate limit and processes vote atomically
7. Repository invalidates cache and returns
8. Manager optimistically updates local state

### 3. Participating in Contest
1. Similar to voting flow but for contests
2. Includes optional `answers` in body
3. Backend processes participation atomically

## Key Components

- **EngagementManager**: Singleton that coordinates the entire system
- **BackendEngagementRepository**: Implementation that connects with backend
- **EngagementCache**: In-memory cache to reduce requests
- **RequestRetryHandler**: Handles automatic retries
- **VideoSyncManager**: Syncs polls/contests with video time
- **UserDefaults**: Stores persistent userId across sessions

## Implemented Features

- ✅ Pagination (limit, offset)
- ✅ Automatic persistent userId
- ✅ Smart caching
- ✅ Automatic retries
- ✅ Data validation
- ✅ Error handling (404, 429, etc.)
- ✅ Type conversion (String → Int)
- ✅ Backend rate limiting
- ✅ Atomic transactions in backend
