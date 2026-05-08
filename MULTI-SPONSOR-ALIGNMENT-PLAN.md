---
title: "Align all paths to multi-sponsor (single storage model)"
sprint: 2026-05-multi-sponsor-alignment
branch: feat/align-multi-sponsor-paths
base: feat/multi-sponsor-checkout-flow
last-updated: 2026-05-08
owner: angelo
status: in-flight
---

# Plan — Align all paths to multi-sponsor (single storage model)

> **Source of truth durante el sprint.** Cualquier desviación se actualiza acá primero.
> Cuando el sprint cierre (merge a develop o abandono), este doc se reescribe como
> retrospectiva y se mueve a `vio-handbook/docs/sprints/2026-05-multi-sponsor-alignment.md`.

## Goal

Eliminar la dualidad legacy / multi-sponsor del SDK. Todas las rutas de add-to-cart
pasan por `cartsBySponsor[sponsorId]`. La UI bifurca por **cantidad de sponsors en
el cart**, no por path de origen del producto. Cuando el sprint cierre, el código
legacy (single-cart `items`, mirror strategy de Q4 L4) ya no existe.

## Non-goals

- No tocamos el contrato de Component template (backend `app_placements`).
  El sponsor ya viene; este sprint solo arregla los call-sites cliente que lo
  ignoraban.
- No agregamos partner externo durante este sprint (no hay pressure de
  back-compat — los únicos consumers son nuestros demos).
- No optimizamos performance ni rediseñamos UX más allá de lo necesario para
  unificar paths.

## Decisions locked (2026-05-08)

1. **Storage = `cartsBySponsor` siempre.** El `items: [CartItem]` legacy y los
   campos espejo (`cartTotal`, `cartId`, `currency`, `country`) desaparecen en
   Fase 5. Durante Fases 1-3 quedan como espejo solo de back-compat con código
   no migrado aún.

2. **Source of truth del sponsorId en client-side = el componente.**
   `activeComponent?.sponsorId` lo provee el backend. El cliente **no** lo
   resuelve con fallbacks a `primarySponsor`. Si llega nil → bug de plumbing
   o de datos (placement sin sponsor en BD), no se papera.

3. **Render mode UI:**
   - **N=1 sponsor cart** → step flow legacy scoped al sponsor único.
     Visualmente idéntico al legacy actual. Method picker oculto, auto-pick
     del primer método disponible. Usuario no se entera de que hay
     multi-sponsor.
   - **N≥2 sponsor carts** → multi-sponsor sections con method picker per
     section. Igual a lo que ya hace VG hoy.
   - **Nunca** se muestra `mainContent` legacy bypass — el render scoped
     reemplaza esa rama.

4. **Q4 L4 mirror strategy se jubila.** `enterSponsorCheckoutScope` /
   `exitSponsorCheckoutScope` actualmente copian campos legacy desde el
   sponsor cart. En Fase 2 se reemplaza por step views que **leen
   directamente del sponsor cart** vía un parámetro inyectado. Sin copia,
   sin desincronización posible.

5. **No partners externos.** Cleanup en Fase 5 puede borrar APIs legacy sin
   warning período. Si entra partner antes de Fase 5 → re-evaluar.

6. **VProductCarousel fallback `?? primarySponsor?.id`** (introducido en
   PR #14 VG demo) se elimina en Fase 1. Era patch defensivo; ahora que el
   plumbing real funciona, sobra.

## End-to-end audit del sponsorId (2026-05-08)

Todo el plumbing **existe**. El bug es que el último hop del flow cart_intent
de TV2 no propaga el sponsorId al overlay de detalle. El resto de los call-sites
legacy son inline adds que ignoran un `activeComponent.sponsorId` disponible.

| Hop | Estado | Acción |
|---|---|---|
| Backend DB `app_placements.sponsor_id` | ✅ presente | (audit script en Fase 1.7) |
| Backend → WS payload `sponsor_id` | ✅ `routes.ts:234` | — |
| WS → iOS `CartIntentEvent.sponsorId` | ✅ parser extrae | — |
| `event.sponsorId` → `CampaignManager.activeCartIntentEvent` | ✅ published | — |
| CampaignManager → `CartIntentProductDetailHost(sponsorId:)` | ✅ ContentView.swift:55 | — |
| Host → `ProductService.loadProduct(productId:, sponsorId:)` | ✅ commerce key correcto | — |
| **Host → `VProductDetailOverlay(sponsorId:)`** | **❌ ContentView.swift:125 dropea param** | **Fase 1.1** |
| User taps Add → `addProduct(... sponsorId:)` | Cae a legacy porque sponsorId nil | Auto-fixea con 1.1 |

## Call-sites legacy auditados

| Archivo | Línea | Estado | Fase |
|---|---|---|---|
| `Demo/tv2demo/.../ContentView.swift` | 125 | sponsorId disponible, no se pasa | **1.1** |
| `Demo/tv2demo/.../TV2VideoPlayer.swift` | 130-156 | DEAD CODE — `currentProduct` nunca se setea | **1.4** |
| `Demo/tv2demo/.../ProductsGridView.swift` | 204 | Grid catalog sin contexto de placement | **1.5** |
| `Demo/Vg/.../VGVideoPlayer.swift` | 72 | Video player demo legacy add | **1.6** |
| `Sources/VioUI/.../VProductSpotlight.swift` | 490 | `activeComponent.sponsorId` disponible, ignorado | **1.2** |
| `Sources/VioUI/.../VCastingVideoPlayer.swift` | 205 | Mismo patrón | **1.3** |
| `Sources/VioUI/.../VProductCarousel.swift` | (fallback `?? primarySponsor?.id`) | Patch defensivo VG #14 | Eliminar al final de Fase 1 |
| `Sources/VioUI/.../VProductDetailOverlay.swift` | 807 | Legacy fallback `addProduct(product, variant:, quantity:)` | **Eliminar en Fase 5** |

## Fases

### Fase 0 — Setup (15 min) ✅

- [x] Crear branch `feat/align-multi-sponsor-paths` off `feat/multi-sponsor-checkout-flow`.
- [x] Push remote como backup.
- [ ] Crear este doc.
- [ ] Crear ADR-0006 draft en `vio-handbook/docs/decisions/0006-storage-is-always-multi-sponsor-cart.md`.

### Fase 1 — Sponsor plumbing en call-sites (1 día)

Un commit pequeño por call-site para que cada uno sea revertible aislado.

- **1.1** `ContentView.swift:125` — pasar `sponsorId: sponsorId` a
  `VProductDetailOverlay`. **Esto solo hace TV2 cart_intent multi-sponsor
  end-to-end.** Verificar con cart_intent real desde Apple TV.
- **1.2** `VProductSpotlight.swift:490` — inline add usa
  `activeComponent?.sponsorId`. Diagnostic log cambia de `🟠 LEGACY` a `🟣 SPONSOR`.
- **1.3** `VCastingVideoPlayer.swift:205` — idem.
- **1.4** `TV2VideoPlayer.swift:130-156` — eliminar bloque entero
  (`TV2ProductOverlay` + `currentProduct` state). Confirmar que ningún otro
  archivo del demo lo set.
- **1.5** `ProductsGridView.swift` — refactor a `init(sponsorId: Int)`.
  Caller (HomeView o donde se instancie) pasa el sponsor explícito. **Si no hay
  sponsor obvio → este view se elimina** (lo decidimos cuando lleguemos).
- **1.6** `VGVideoPlayer.swift` — mismo patrón que 1.5.
- **1.7** Backend audit: script `scripts/inspect-placements-without-sponsor.ts`
  que liste `app_placements` con `sponsor_id IS NULL`. Si hay rows → backfill
  con `campaign.primary_sponsor_id` o flag para fix manual desde dashboard.
- **1.8** Eliminar `?? VioConfiguration.shared.primarySponsor?.id` en
  `VProductCarousel.swift:462`. Si después del audit (1.7) el backend está
  limpio, este patch ya no defiende nada.

**Verificación post-Fase 1:** filtrar logs Xcode por `🟠 LEGACY`. Si no aparece
NUNCA durante un flow normal en Vg + TV2, Fase 1 cerrada.

### Fase 2 — `VCheckoutOverlay` render modes (2-3 días)

Este es el meaty refactor. Eliminar la dependencia de step views sobre
`cartManager.items / cartTotal / cartId / currency / country` legacy.

#### 2.1 — Introducir `CheckoutRenderMode` enum

```swift
private enum CheckoutRenderMode {
    case empty                                              // 0 carts
    case scopedFlow(sponsorCart: SponsorCart)               // 1 cart, o N≥2 con scope
    case multiSponsorList(carts: [SponsorCart])             // N≥2 sin scope (selección)
}

private var renderMode: CheckoutRenderMode {
    let carts = orderedSponsorCarts
    if carts.isEmpty { return .empty }
    if let sid = cartManager.activeCheckoutSponsorId,
       let cart = carts.first(where: { $0.sponsorId == sid }) {
        return .scopedFlow(sponsorCart: cart)
    }
    if carts.count == 1 {
        return .scopedFlow(sponsorCart: carts[0])           // ← N=1: auto-scope
    }
    return .multiSponsorList(carts: carts)
}
```

`isMultiSponsorMode` se elimina o queda como wrapper deprecated.

#### 2.2 — Step views aceptan `sponsorCart: SponsorCart` directo

`addressStepView`, `orderSummaryStepView`, `reviewStepView`, `successStepView`
hoy leen `cartManager.items / cartTotal / cartId / etc.` Refactor:

```swift
private func orderSummaryStepView(sponsorCart: SponsorCart) -> some View {
    // lee sponsorCart.items, sponsorCart.subtotal, sponsorCart.cartId
    // reemplaza referencias a cartManager.items / cartTotal / cartId
}
```

Cada step view se llama desde `body` con el `sponsorCart` resuelto por
`renderMode`.

#### 2.3 — Method picker UX divergente

- **N=1 (`scopedFlow`)** → method picker oculto. Auto-pick:
  ```swift
  sponsorCart.selectedPaymentMethod ?? sponsor.commerce.paymentMethods.first
  ```
  Si no hay métodos disponibles → fallback Apple Pay si device support, sino
  empty state.
- **N≥2 (`multiSponsorList`)** → method picker visible per section como hoy.
  Tap Checkout → seteás `activeCheckoutSponsorId` → re-render llega a
  `scopedFlow`.

#### 2.4 — Mirror strategy stays funcional pero no usada

`enterSponsorCheckoutScope` / `exitSponsorCheckoutScope` no se borran todavía.
Quedan como código muerto que Fase 5 limpia. Tampoco se llaman desde el nuevo
path — el render mode es suficiente.

**Verificación post-Fase 2:** smoke matrix completa Klarna/Vipps/Stripe/ApplePay
× {1, 2} sponsors × Vg + TV2. **Pixel-equivalence** entre N=1 actual y N=1
post-refactor (screenshots side-by-side antes/después).

### Fase 3 — Deprecation guards (4 horas)

```swift
@available(*, deprecated, message: "Use cartsBySponsor[sponsorId] instead")
@Published public var items: [CartItem] = []

@available(*, deprecated, message: "Use addProduct(... sponsorId:) — primary fallback removed")
public func addProduct(_ product: Product, quantity: Int) async { ... }

// idem cartTotal, cartId, currency, country, mainContent, etc.
```

Build → confirmar **0 warnings nuevas** = todos los call-sites internos del SDK
ya migraron. Si aparecen warnings → ese call-site se migra antes de pasar a
Fase 4.

### Fase 4 — Stabilization (~1 semana)

- Uso real durante 1 semana sin ningún `🟠 LEGACY` en logs.
- PR de Fases 1-3 a develop (no Fase 5 todavía — esa va en branch separada
  después de mergear).
- Smoke matrix archivada en `socket-server/docs/CURRENT_STATE.md`.

### Fase 5 — Cleanup (1 día — solo cuando los 6 criterios pasen)

PR único `chore/remove-legacy-cart-paths`:

- Borrar `addProduct(_:variant:quantity:)` y todos los call-sites internos.
- Borrar `@Published var items / cartTotal / cartId / currency / country`
  legacy en CartManager.
- Borrar `mainContent` (rama legacy del checkout overlay).
- Borrar `enterSponsorCheckoutScope/exitSponsorCheckoutScope` mirror logic.
- Borrar `LegacySnapshotForCheckoutScope` struct.
- Borrar línea 807 de `VProductDetailOverlay.swift`.
- Borrar `TV2ProductOverlay` (si confirmamos en 1.4 que es dead code total).
- Mover este doc → renombrado a retrospective →
  `vio-handbook/docs/sprints/2026-05-multi-sponsor-alignment.md`.
- ADR-0006 → `status: live`.

Estimado de líneas borradas: -2000 SDK / -500 tests.

## Criterios de "seguros" para gatillar Fase 5

Los 6 que tienen que pasar **todos**:

1. ✅ `🟠 LEGACY` no aparece en logs durante 1 semana de uso real (Fase 4).
2. ✅ Smoke matrix verde: 4 métodos × {1, 2, 3} sponsors × 2 demos.
3. ✅ Cart_intent flow verde end-to-end en TV2 multi-sponsor.
4. ✅ N=1 caso: pixel-equivalence con legacy actual (regression check).
5. ✅ Build sin warnings de `@available deprecated` (Fase 3 verde).
6. ✅ ADR-0006 mergeado.

Si alguno rojo → no se borra legacy, se itera Fase 1-2-3 hasta verde.

## Riesgos

- **R1: Step views tocan código que paga** (Stripe / Klarna / Vipps).
  Mitigación: smoke matrix por método después de cada commit de Fase 2.
  Cualquier rojo bloquea próximo commit.
- **R2: Q4 L4 mirror strategy entrelazada con otros call paths.** Cambiar el
  modelo puede romper flows en otras branches. Mitigación: Fase 2 SOLO añade
  el render mode nuevo, deja mirror funcional. Cleanup en Fase 5.
- **R3: Backend con placements de `sponsor_id IS NULL`.** Mitigación: 1.7
  detecta y backfilla antes de eliminar el fallback en 1.8.
- **R4: VProductCarousel fallback removal expone bugs latentes.** Mitigación:
  audit de 1.7 + smoke en Vg después de 1.8 antes de pasar a Fase 2.
- **R5: 1 semana de stabilization se siente largo y otra prioridad mete prisa.**
  Mitigación: si pasa, Fase 4 se reduce a 3 días con criterio "ningún issue
  surgido en 3 días de uso real" — pero **nunca** se salta Fase 4 entera.

## Reference

- Q4 L4 handoff: `Q4-L4-HANDOFF.md` (en esta misma branch — relevante porque
  describe el mirror strategy que vamos a jubilar).
- ADR draft: `vio-handbook/docs/decisions/0006-storage-is-always-multi-sponsor-cart.md`.
- Lesson previa: `vio-handbook/docs/lessons/ios26-nested-modal-deadlock.md`
  (relevante para el R1 — testeamos modales con cuidado).
- Backend `cart_intents` schema: `socket-server/shared/schema.ts:702` (`idx_cart_intents_sponsor`).
- WS payload constructor: `socket-server/server/routes.ts:234`.
