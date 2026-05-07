# Q4 L4 — Multi-sponsor unified checkout — Handoff (STUCK)

> **Status (2026-05-06, refreshed 2026-05-07): STUCK / paused mid-implementation.**
> The unified multi-sponsor checkout (per-sponsor method picker → legacy step flow scoped to that sponsor) was 90% wired up but the last fix (`3319396`) is **untested**. Resume from this doc.

**Branch:** `feat/multi-sponsor-checkout-flow` (off `chore/q4-l3-cart-diagnostics`, **local-only, never pushed**)
**Last commit on this branch:** `3319396 fix(q4-l4): cartManager.sdk routes to sponsor SDK when scoped + mirror currentCartId`

## Develop drift since this branch was paused (refreshed 2026-05-07)

`develop` advanced by **1 commit** between when this branch was paused (2026-05-06) and now (2026-05-07):

- `e463c51 feat(vg-demo): VG advertorial flow with end-to-end Apple Pay (#14)` — new VG demo + theme-driven Apple Pay confirmation sheet + a few SDK polish items.

### Files in develop that overlap this branch

The VG PR touched these SDK files. **Rebase / merge develop first** before resuming Q4 L4 work — most are additive, but `ApplePayManager.swift`, `VApplePayButton.swift` and `PaymentRuntimeGuard.swift` are touched on both sides and will likely need a manual merge.

| File | What VG PR did | Q4 L4 already touches? | Conflict risk |
|------|----------------|------------------------|---------------|
| `Sources/VioUI/Managers/ApplePayManager.swift` | Diagnostic prints added then removed pre-merge — function shape unchanged, plus the Q4 L3 logic stays. | Yes — the whole `pay()` flow + `pendingSponsorId` routing | Low (VG only added/removed prints) but **review the area around `pay()` line 180** |
| `Sources/VioUI/Components/VProductCarousel.swift` | Defensive fallback: `sponsorId: activeComponent?.sponsorId ?? VioConfiguration.shared.primarySponsor?.id` so `VProductDetailOverlay` always receives a non-nil sponsor route. | No (Q4 L4 didn't touch this file) | Low |
| `Sources/VioUI/Components/VProductDetailOverlay.swift` | `.preferredColorScheme(...)` + `.presentationBackground(VioColors.background)` (iOS 16.4+) on the body. Image gallery `.fill` → `.fit` + `VioSpacing.lg` horizontal inset. Bottom action bar wrapped in `.regularMaterial`. | No (Q4 L4 doesn't touch the overlay's chrome — only the embedded `VApplePayButton` invocation, which is unchanged) | Low |
| `Sources/VioUI/Components/VApplePayButton.swift` | Bg color `#7000FF` (purple) → `Color.black`. `.presentationBackground(...)` on the chrome helper now reads `VioColors.surface` instead of hardcoded TV2 navy. New `import VioDesignSystem`. | Yes — Q4 L4 wired the `sponsorId` into `applePayButton` and passes through to `pay()`. | **Medium** — both edits touch the same file; merge by hand. |
| `Sources/VioUI/Components/VApplePayConfirmationSheet.swift` | Whole body refactored from hardcoded TV2 colors to `VioColors.adaptive(for:)` tokens. New `import VioDesignSystem`. | No | Low |
| `Sources/VioUI/Components/VProductCard.swift`, `VProductSpotlight.swift` | Image content mode `.fill` → `.fit` with small inset so square products show whole. | No | Low |
| `Sources/VioUI/Managers/PaymentRuntimeGuard.swift` | `ensurePaymentRuntimeReady` skips the defensive `ensureCommerceBootstrapApplied()` when `sdkBootstrapCommerceApiKey` is already set (avoids iOS 26 deadlock during Apple Pay tap). | Yes — Q4 L4 modifies the same function to add scope handling. | **Medium** — review the early-return logic. |

### Recommended resume sequence

```bash
git checkout feat/multi-sponsor-checkout-flow
git fetch origin develop
git merge origin/develop      # expect manual merges in ApplePayManager.swift,
                              # VApplePayButton.swift, PaymentRuntimeGuard.swift
# ... resolve conflicts (Q4 L4 logic + VG polish coexist) ...
git status                    # confirm tree clean
# now run the smoke test below from scratch (it's the same as before, just
# picks up the new SDK polish layer for free)
```

After the merge: `File → Packages → Reset Package Caches`, `Cmd+Shift+K`, `Cmd+R`.

**Don't touch:** `develop` and `main` are intact. Develop now has Q4 L3 PR #11 + #12 polish + VG demo (#14) all landed.

## What this sprint was trying to do

User has multi-sponsor cart support (Q4 L3, already on develop). Each sponsor has its own `SponsorCart` in `cartsBySponsor[sid]`. The **multi-sponsor checkout view (`SponsorCheckoutSection`) was Apple-Pay-only** by Q4 L3 design. User wanted Klarna/Vipps/Stripe back without breaking the legacy single-cart flow.

Two architectural decisions made by user (locked):

1. **Method picker + Checkout button per sponsor section in the cart**. The user picks the payment method for each sponsor *before* tapping Checkout. The flow controller branches by method downstream.
2. **Reuse legacy step flow components** (`VCheckoutOverlay.mainContent` → `addressStepView` → `orderSummaryStepView` → `reviewStepView` → `successStepView`). Do NOT create new components. Modify legacy in-place to be sponsor-aware.

## What works (validated)

- **Phase 1**: per-sponsor method picker chips (`SponsorCheckoutSection.methodPickerRow`) + `Checkout` button. Filtered by `sponsor.commerce.paymentMethods`.
- **Phase 2-4**: Klarna / Vipps / Stripe handlers in `PaymentManager.swift` accept optional `sponsorId: Int? = nil`. When nil, behave as legacy. When set, resolve via `resolvePaymentTarget(sponsorId:component:)` to use the sponsor's SDK + sponsor cart's `checkoutId`. Backward compatible.
- **Apple Pay Pay Now (PDP express)**: `ApplePayManager.pay()` success path branches by `pendingSponsorId`. Sponsor-aware → `markSponsorCartPaid + clearCart(forSponsor:)` (server `cart.delete` + local). Legacy → unchanged. Validated end-to-end with curl: `applePayConfirm` + `cart.delete` both 200.
- **Defensive cart refresh**: on `VCheckoutOverlay.onAppear`, `cartManager.refreshSponsorCartsFromServer()` runs `cart.getById` per non-paid sponsor cart and replaces local items with server truth. Eliminates phantom-item bugs from prior mid-session drift.
- **isPaid reset on re-add**: `addProduct(sponsorId:)` resets `isPaid=false` + `selectedPaymentMethod=nil` when adding to a previously-paid sponsor cart. New transaction.

## What's stuck (must validate before merging)

The user's last test showed scoped step flow (Klarna/Vipps/Stripe via cart's Checkout button) was completely broken because of two bugs in the mirror strategy. **Both fixed in the latest commit `3319396` but UNTESTED.**

### Mirror strategy — the core idea

When user taps "Checkout" on a sponsor section with method != Apple Pay:
1. `cartManager.enterSponsorCheckoutScope(sponsorId)` snapshots the legacy flat fields (items, cartTotal, cartId, checkoutId, currency, country, shipping*, lastDiscount*) and **mirrors the sponsor cart into them**.
2. `isMultiSponsorMode` flips false → body renders legacy `mainContent` (the step flow).
3. The step views read `cartManager.items / cartTotal / cartId / etc.` — which are now sponsor's data.
4. Payment handler calls (Klarna/Vipps/Stripe init/confirm) pass `sponsorId: cartManager.activeCheckoutSponsorId` for SDK routing.
5. Success step's Close → `markSponsorCartPaid + clearCart(forSponsor:) + exitSponsorCheckoutScope(syncBackToSponsor: false)`.

### The two bugs `3319396` fixes

**Bug A — `cartManager.sdk` ignored the scope.** `sdk` was a stored property initialised to the global SDK (primary's apiKey). Even after `enterScope` mirrored data, every legacy `sdk.cart.*` and `sdk.payment.*` call still went through the primary. Fix: `sdk` is now a **computed property** that returns `resolveSponsorSdk(forSponsorId: activeCheckoutSponsorId)` when scoped, falling back to `_legacySdk` (the renamed stored field). `syncSdkCredentials` operates on `_legacySdk` directly — sponsor SDKs are managed per-sponsor by `CommerceSdkClientProvider`, must NOT receive primary credentials.

**Bug B — `currentCartId` not mirrored.** `ensureCartIDForCheckout` (and a few other legacy paths) checks `currentCartId` (internal twin of `cartId`). It was nil during scoped checkout because `enterScope` only mirrored `cartId`. Result: legacy `createCart()` fired, spawning a brand-new cart on the (now-broken) global sdk. The new `4ea96d83-...` cart_id had nothing to do with the sponsor cart we entered scope for. Fix: mirror `currentCartId` alongside `cartId` in `enterScope`/`exitScope`. `LegacySnapshotForCheckoutScope` gets the new field.

### How to validate (when resuming)

Smoke test matrix:

| Method | 1 sponsor | 2 sponsors |
|--------|-----------|-----------|
| Apple Pay (cart Checkout) | ✓ verified pre-3319396 | needs test |
| Apple Pay (PDP Pay Now) | ✓ verified pre-3319396 | n/a (single product) |
| Klarna | **needs test post-3319396** | needs test |
| Vipps | **needs test post-3319396** | needs test |
| Stripe | **needs test post-3319396** | needs test |
| Mixed methods per sponsor | needs test |
| Cancel mid-flow | needs test |
| isPaid → re-add same sponsor | needs test |

Test procedure:
1. Kill demo + relaunch (`cartsBySponsor` clean)
2. Filter Xcode console by `Q4-DIAG`
3. Add items from 2 sponsors with different `paymentMethods`
4. For each sponsor, pick a method + tap Checkout
5. Look for `🟣 enter-checkout-scope sponsorId=X cartId=...`
6. In step flow, look for `🟣 payment-resolve component=X sponsorId=X using sponsor SDK + checkoutId=...`
7. Pay → look for `🟣 exit-checkout-scope` + cart cleared
8. Repeat per sponsor
9. **Bandera roja**: any `🟠 LEGACY` log during scoped checkout means a callsite is bypassing the sponsor routing.

## Diagnostic logs in place (filter by `Q4-DIAG`)

| Log | Where | Purpose |
|-----|-------|---------|
| 🟣 `sdk-resolve sponsorId=X apiKey=...XXXX cache=Y` | `CommerceSdkClientProvider.client(forSponsorId:)` | Each sponsor SDK resolution |
| 🟠 `sdk-resolve FALLBACK→primary` | same | Sponsor has no commerce block — falls back to primary's apiKey |
| 🟣 `addProduct-SPONSOR sponsorId=X productId=P qty=Q` | `CartModule+SponsorCart.addProduct(sponsorId:)` | Multi-sponsor add |
| 🟠 `addProduct-LEGACY` | `CartModule.addProduct(_:variant:quantity:)` | Legacy single-cart add — should NOT fire in multi-sponsor tests |
| 🟣 `ensureSponsorCartId CREATE/REUSE` | `ensureSponsorCartId` | Cart created/reused in sponsor channel |
| 🟣 `createCheckout-SPONSOR` | `createCheckout(forSponsor:)` | Per-sponsor checkout creation |
| 🟣 `payment-resolve component=X sponsorId=X` | `resolvePaymentTarget` | Klarna/Vipps/Stripe routing decision |
| 🟣 `enter-checkout-scope` / `exit-checkout-scope` | `enterSponsorCheckoutScope` / `exit*` | Mirror enter/exit |
| 🟣 `refresh-from-server` | `refreshSponsorCartsFromServer` | Cart open drift correction (with `N→M` suffix when drift was actually corrected) |
| 🟣 `sponsor-cart-reactivated` | `addProduct(sponsorId:)` when isPaid was true | New transaction on previously-paid cart |
| 🟠 `inline-add VProductSpotlight / VCastingVideoPlayer` | inline cart-add buttons in those views | Bypass paths — sponsor info dropped |

## Architecture key files

```
Sources/VioCore/Sdk/Core/GraphQL/CommerceSdkClientProvider.swift
  └─ client(forSponsorId:) returns per-sponsor SdkClient cached in sponsorClients dict
  └─ activeSponsorId: who's the active sponsor for transactions

Sources/VioUI/Managers/CartManager.swift
  └─ activeCheckoutSponsorId: @Published — nil = legacy / non-nil = scoped checkout
  └─ sdk: COMPUTED — sponsor SDK when scoped, _legacySdk otherwise (3319396)
  └─ enterSponsorCheckoutScope / exitSponsorCheckoutScope: mirror strategy
  └─ refreshSponsorCartsFromServer: drift correction on cart open

Sources/VioUI/Managers/CartModule+SponsorCart.swift
  └─ addProduct(sponsorId:): main multi-sponsor cart entry
  └─ ensureSponsorCartId: per-sponsor cart create
  └─ createCheckout(forSponsor:): per-sponsor checkout create
  └─ removeItem(fromSponsor:) / updateQuantity(forSponsor:): mutations
  └─ clearCart(forSponsor:): server cart.delete + local clear
  └─ markSponsorCartPaid: sets isPaid=true (renders Paid banner)
  └─ resolveSponsorSdk(forSponsorId:): the strict per-sponsor resolver

Sources/VioUI/Managers/PaymentManager.swift
  └─ resolvePaymentTarget(sponsorId:component:): central (sdk, checkoutId) resolver
  └─ initKlarnaNative / confirmKlarnaNative / vippsInit / stripeIntent / stripeLink: all accept sponsorId

Sources/VioUI/Managers/ApplePayManager.swift
  └─ pay(... sponsorId:): success path branches by pendingSponsorId — sponsor → markPaid + clearCart(forSponsor:) — legacy → resetCartAndCreateNew

Sources/VioUI/Components/SponsorCheckoutSection.swift
  └─ methodPickerRow: chip strip filtered by sponsor.commerce.paymentMethods
  └─ checkoutButton: disabled until method picked, fires onCheckoutTapped
  └─ paidBanner: rendered when sponsorCart.isPaid

Sources/VioUI/Components/VCheckoutOverlay.swift
  └─ activeCheckoutSponsorId: wraps cartManager.activeCheckoutSponsorId
  └─ isMultiSponsorMode: false when scoped (renders mainContent legacy step flow)
  └─ handleSponsorCheckoutTap: branches by method (Apple Pay direct vs scope+legacy)
  └─ triggerSponsorApplePay + handleScopedApplePayResult: cart-driven Apple Pay
  └─ handleSuccessClose: scoped path = markPaid + clearCart + exitScope, legacy = unchanged
  └─ Apple Pay observer: .onChange(of: applePayManager.paymentResult) { handleScopedApplePayResult }
  └─ 4 payment handler call sites pass sponsorId: cartManager.activeCheckoutSponsorId

Sources/VioUI/Managers/SponsorCart.swift
  └─ selectedPaymentMethod: String? (Q4 L4 — picked in cart, consumed by flow)
  └─ isPaid: Bool (Q4 L4 — Paid banner state)
```

## Frustrations / lessons (re-read before resuming)

The user pushed back on me **multiple times**. Pattern of mistakes I made:

1. **Created new components when legacy could be modified.** First attempt: `SponsorCheckoutFlow.swift` + `VAllDoneSheet.swift`. User was clear they wanted legacy reuse. Reverted in `c9b5687`.
2. **Blamed Commerce / Alan** for 500s instead of investigating iOS first. The `Cart item not remove` 500 was iOS state stale (item never existed server-side) — confirmed empirically with curl. The same applied to `UpdateItem 500` — wrong apiKey + wrong cart_id from the broken mirror.
3. **Built workarounds (`cleanupSponsorCartLocally`)** instead of trusting Commerce's existing `cart.delete`. User was clear: "Commerce supports it, use it as designed." Reverted in `773d03b`.
4. **Assumed concurrency / spec gaps** for things that turned out to be local SDK bugs.

When resuming: **investigate iOS state first. Trust Commerce. Use existing methods. Don't create parallel paths.**

## Pending phases (originally planned)

- **Phase 8**: Pay Now express in PDP — fix qty=1 hardcode + ephemeral cart cleanup (Pay Now is currently NOT actually express — it adds to multi-sponsor cart, pays, then drains via `clearCart(forSponsor:)` — works but conceptually impure).
- **Phase 9**: `VAddedToCartSheet` post-add confirmation sheet (per Claude Design).
- **Phase 10**: cart_id persistence between app sessions (UserDefaults), cleanup inline bypass paths (`VProductSpotlight:485`, `VCastingVideoPlayer:205` add-to-cart without sponsorId), full smoke test matrix, doc updates.

## Out of scope this sprint (explicitly deferred)

- Stripe Connect setup per sponsor channel (Commerce ops responsibility, NOT SDK)
- Q1 primary↔junction sync (Path C drafted, ~1h)
- VProductSlider Phase 2 (~2h 20min)
- Discount synchronization on `discount.apply` (commit was `c2ac842`, unaddressed gap noted in `discount.apply` returning only `{executed, message}` without updated cart state — needs follow-up `cart.getById` post-discount)

## Branch commits in order

```
3319396 fix(q4-l4): cartManager.sdk routes to sponsor SDK when scoped + mirror currentCartId    ← LATEST, untested
c2ac842 fix(q4-l4): defensive re-sync of sponsor carts from server on cart open
1c6175f fix(q4-l4): reset isPaid when re-adding to a previously-paid sponsor cart
773d03b revert(q4-l4): use existing clearCart(forSponsor:), not a local-only workaround
75e16ae fix(q4-l4): cart cleanup after Apple Pay (further refined in 773d03b)
63a7e7e feat(q4-l4): per-sponsor checkout reuses legacy mainContent step flow
c9b5687 revert(q4-l4): delete SponsorCheckoutFlow + VAllDoneSheet, prep for legacy adapt
30dcc17 fix(q4-l4): SponsorCheckoutFlow compile errors    ← orphan, files deleted in c9b5687
5391f94 feat(q4-l4): AllDoneSheet recap                   ← orphan, file deleted in c9b5687
c91d247 feat(q4-l4): per-sponsor success screen           ← orphan
6d04487 feat(q4-l4): per-sponsor checkout flow controller ← orphan
7d96b26 feat(q4-l4): Klarna / Vipps / Stripe handlers sponsor-aware
c52e4c7 feat(q4-l4): per-sponsor method picker + Checkout button in cart
172ae52 (chore/q4-l3-cart-diagnostics base)
```

## Where to pick up

1. Rebuild Xcode against latest commit (`3319396`).
2. Kill + relaunch demo.
3. Run the smoke test matrix above.
4. If green for 1-sponsor cases: proceed to 2-sponsor cases.
5. If any red: **read the Q4-DIAG logs first**, identify whether the failure is iOS-side (most likely now) or Commerce-side (curl repro to confirm).
6. After all green: cleanup phases 8-10, push branch, open PR to develop.
