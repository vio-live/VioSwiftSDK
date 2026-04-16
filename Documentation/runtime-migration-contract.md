# Runtime Migration Contract

This SDK keeps legacy entrypoints operational while migrating integrations to the runtime contract.

## Preferred Contract

- Use `VioRuntime.startSession(...)` (or `VioSession.shared.start(...)`) to bootstrap runtime.
- Use `VioSession.shared.ensureCommerceBootstrapApplied()` for payment-readiness bootstrap.
- Keep app integration minimal: initialize SDK config, start runtime session, mount UI components.

## Legacy Compatibility

- `CampaignManager.initializeCampaign()` remains available but is deprecated.
- `CampaignManager.ensureCommerceBootstrapApplied()` remains available but is deprecated.
- Existing payment APIs in `CartManager` keep behavior, but now rely on shared runtime guard.

## Migration Guidance

1. Move startup orchestration from app screens into `VioRuntime` session calls.
2. Remove direct app-layer calls to `CampaignManager.shared` for checkout/payment readiness.
3. Keep UI composition in app; keep flow orchestration and retries in SDK runtime.
