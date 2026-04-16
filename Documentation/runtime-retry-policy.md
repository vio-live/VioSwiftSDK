# Runtime Retry/Fallback Policy

This document defines the canonical runtime retry/fallback rules used by the SDK-first flow.
Source of truth in code: `VioRuntimeRetryPolicy`.

## Domain Policies

- Campaign REST/WS bootstrap
  - REST fallback retries: `1` (`campaignRestFallbackRetryCount`).
  - Purpose: allow a single failover pass to dev-safe endpoints without creating oscillation.
- Commerce bootstrap
  - Retry count: `1` (`commerceBootstrapRetryCount`).
  - Purpose: one immediate retry before reporting degraded runtime state.
- WebSocket reconnect
  - Max attempts: `5` (`webSocketMaxReconnectAttempts`).
  - Backoff: exponential with max delay `30s` (`webSocketMaxBackoffSeconds`).
- Stripe intent provisioning (Apple Pay)
  - Ordered strategy: `[false, nil]` for `returnEphemeralKey` (`applePayStripeIntentReturnEphemeralKeyModes`).
  - Purpose: deterministic backend-first key resolution.
- Confirm payment
  - Retries: `0` (`confirmPaymentRetryCount`).
  - Purpose: avoid duplicate charge attempts on ambiguous gateway state.

## Notes

- Managers should consume policy constants and avoid ad-hoc retry decisions.
- If policy values change, update both `VioRuntimeRetryPolicy` and this document in the same PR.
