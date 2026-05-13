---
title: "Direct payment launch — parity with Apple Pay for Stripe + Klarna"
sprint: 2026-05-direct-payment-launch
branch: feat/direct-payment-launch
base: feat/align-multi-sponsor-paths (commit 9e31b93)
last-updated: 2026-05-13
owner: angelo
status: in-flight
---

# Plan — Direct payment launch (Stripe + Klarna → parity with Apple Pay)

> **Source of truth durante el sprint.** Cualquier desviación se actualiza acá primero.
> Cuando cierre, este doc se reescribe como retrospectiva y se mueve a
> `vio-handbook/docs/sprints/2026-05-direct-payment-launch.md`.

## Goal

Reducir el flow de checkout de Stripe y Klarna a **1 tap desde el cart** —
igual que Apple Pay. Después del tap, el SDK del network correspondiente
collecta toda la data necesaria (card, billing address, shipping address,
email, phone) **dentro de su propio sheet**, y el backend procesa la order
por detrás.

## Non-goals

- No tocar el flow de Apple Pay (ya funciona como queremos).
- No tocar el legacy step flow del SDK para hosts que no usan multi-sponsor
  (no scoped) — sigue ahí, just unused para scope.
- No coordinar con Reachu Commerce todavía — primero probamos iOS-only,
  identificamos blockers reales, después coordinamos si hace falta.

## Estado actual (pre-sprint)

| Método | UX desde cart tap |
|---|---|
| **Apple Pay** | tap → `triggerSponsorApplePay` → PassKit sheet → confirm → ✅ done |
| **Stripe** | tap → `enterSponsorCheckoutScope` → `addressStepView` (collect shipping + email) → `orderSummaryStepView` (re-pickear método, redundante) → "Start betaling" → `prepareStripePaymentSheet` → PaymentSheet → confirm → done |
| **Klarna** | tap → `enterSponsorCheckoutScope` → `addressStepView` → `orderSummaryStepView` (re-pickear) → "Start betaling" → `klarnaNativeInit` → KlarnaNativePaymentSheet → confirm → done |

**Fricción que el usuario reportó (2026-05-13):**
"despues de escoger y en la siguiente poner los datos de entrega sale [el
order summary con method selector] denuevo: y recien ahi empieza el flow"

## Hallazgos del análisis (DTOs)

**`KlarnaNativeInitInputDto`** (`PaymentModels.swift:231`): **todos los
campos son opcionales** (`var ... = nil`). Podemos llamar con solo
`countryCode/currency/locale`. Klarna's webview collecta name, address,
phone, email internamente.

**`stripeIntent(returnEphemeralKey:sponsorId:)`** (`PaymentManager.swift:246`):
no toma address inputs. El backend Reachu crea el PaymentIntent solo con
checkoutId. La PaymentSheet de Stripe collecta lo que configuremos via
`billingDetailsCollectionConfiguration`.

**`KlarnaNativeConfirmInputDto`** (`PaymentModels.swift:277`): solo
`authorizationToken` required; address/customer opcionales (vienen en el
response de Klarna webview).

→ **iOS no tiene blockers para implementar el direct-launch para ambos.**

## Bloqueadores potenciales (backend-side, fuera de iOS)

| Blocker | Quién lo controla | Cómo verificar |
|---|---|---|
| **Stripe** — el `CreatePaymentIntentStripe` resolver server-side debe setear `shipping_address_collection` en los params del PaymentIntent para que PaymentSheet le pregunte al user shipping también (no solo billing) | Reachu Commerce | Post-orden, inspect `orders.shipping_address` en DB. Si null → falta config en Reachu |
| **Klarna** — el `ConfirmKlarnaNative` resolver server-side debe extraer address del Klarna response y escribirla al `checkout/order` record | Reachu Commerce | Idem — DB inspect post-orden |

Ambos son fixes en el lado de Reachu Commerce, no de socket-server. Decisión:
**probamos iOS-only primero**. Si la order completa con address bien, no
necesitamos coordinar. Si falta address en el order → identificamos exacto
qué pedirle a Reachu.

## Fases

### Fase 0 — Setup (15 min) ✅

- [x] Branch `feat/direct-payment-launch` off `feat/align-multi-sponsor-paths` (9e31b93)
- [x] Push remote como backup
- [ ] Este doc

### Fase Pago-1 — iOS-only direct launchers (~1-2h)

**1.1 — `triggerSponsorStripe(_:)`**

Mirroring `triggerSponsorApplePay`:

```swift
private func triggerSponsorStripe(_ sponsorCart: CartManager.SponsorCart) {
    let sid = sponsorCart.sponsorId
    Task {
        // 1. Ensure sponsor cart has a checkout
        let checkoutId = sponsorCart.checkoutId
            ?? (await cartManager.createCheckout(forSponsor: sid))
        guard let checkoutId else { /* error */ return }

        // 2. Get PaymentIntent from Reachu via sponsor SDK
        guard let dto = await cartManager.stripeIntent(
            returnEphemeralKey: true,
            sponsorId: sid
        ) else { /* error */ return }

        // 3. Build PaymentSheet config — Stripe collects billing + shipping inline
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName =
            VioConfiguration.shared.sponsor(withId: sid)?.name ?? "Vio"
        config.billingDetailsCollectionConfiguration.address = .full
        config.billingDetailsCollectionConfiguration.email = .always
        config.billingDetailsCollectionConfiguration.phone = .always
        config.billingDetailsCollectionConfiguration.name = .always
        if let ek = dto.ephemeralKeySecret, let cid = dto.customer {
            config.customer = .init(id: cid, ephemeralKeySecret: ek)
        }

        // 4. Present
        let sheet = PaymentSheet(
            paymentIntentClientSecret: dto.clientSecret,
            configuration: config
        )
        sheet.present(from: topMostViewController()) { result in
            handleSponsorStripeResult(result, sponsorId: sid)
        }
    }
}
```

Result handler: mark sponsor cart paid + `clearCart(forSponsor:)` mirroring
Apple Pay path.

**1.2 — `triggerSponsorKlarna(_:)`**

```swift
private func triggerSponsorKlarna(_ sponsorCart: CartManager.SponsorCart) {
    let sid = sponsorCart.sponsorId
    Task {
        let checkoutId = sponsorCart.checkoutId
            ?? (await cartManager.createCheckout(forSponsor: sid))
        guard let checkoutId else { /* error */ return }

        // Minimal init — Klarna webview collects the rest
        let market = cartManager.selectedMarket
        let input = KlarnaNativeInitInputDto(
            countryCode: market?.code ?? sponsorCart.country,
            currency: market?.currencyCode ?? sponsorCart.currency,
            locale: market?.klarnaLocale ?? "en-NO",
            intent: "buy",
            autoCapture: true
            // customer / billingAddress / shippingAddress all nil
            // → Klarna webview will prompt for them
        )

        guard let dto = await cartManager.initKlarnaNative(
            input: input,
            sponsorId: sid
        ) else { /* error */ return }

        klarnaNativeInitData = dto
        pendingKlarnaSponsorId = sid
        // .sheet(item: $klarnaNativeInitData) renders KlarnaNativePaymentSheet
    }
}
```

On authorize callback: `confirmKlarnaNative(authorizationToken:)` with no
customer/address (Klarna already collected → response brings it back →
Reachu extracts).

**1.3 — `handleSponsorCheckoutTap` dispatch switch**

```swift
private func handleSponsorCheckoutTap(_ sponsorCart: CartManager.SponsorCart) {
    guard let raw = sponsorCart.selectedPaymentMethod else { return }
    let method = raw.lowercased().replacingOccurrences(of: "_", with: "")
    switch method {
    case "apple", "applepay":
        triggerSponsorApplePay(sponsorCart)
    case "stripe", "stripelink":
        triggerSponsorStripe(sponsorCart)
    case "klarna":
        triggerSponsorKlarna(sponsorCart)
    default:
        // Fallback to step flow for methods we haven't directly wired
        cartManager.enterSponsorCheckoutScope(sponsorCart.sponsorId)
        checkoutStep = .address
    }
}
```

**Resultado esperado post Fase Pago-1:**

| Método | UX desde cart tap |
|---|---|
| Apple Pay | tap → PassKit sheet (sin cambios) |
| Stripe | tap → **PaymentSheet directo** (sin step flow) |
| Klarna | tap → **Klarna webview directo** (sin step flow) |

### Fase Pago-2 — Smoke test + DB inspection (~30min)

Procesar 2 órdenes reales:

1. **Stripe test card** (`4242 4242 4242 4242`) en Vg con un Maxbo product.
2. **Klarna sandbox** (Klarna playground env) en Vg con otro producto.

Para cada orden completada, inspeccionar Neon DB:

```sql
SELECT id, shipping_address, billing_address, status, created_at
FROM orders -- or checkouts, dependiendo el schema
WHERE created_at > now() - interval '5 minutes'
ORDER BY created_at DESC;
```

**Criterio de éxito**: `shipping_address` no null + contiene los datos
que el user puso en el SDK sheet.

### Fase Pago-2b — Backend gap mitigation (condicional)

Solo si Fase Pago-2 revela que `shipping_address` queda null:

- **Si es Stripe**: hablar con Reachu para que el resolver `CreatePaymentIntentStripe` agregue `shipping_address_collection`. Mientras tanto, fallback: tap Stripe → mini-sheet inline (1 step) con solo shipping address + email → updateCheckout → presentStripe. Más simple que el address full + orderSummary actual, pero no idéntico a Apple Pay.
- **Si es Klarna**: hablar con Reachu para que `ConfirmKlarnaNative` extraiga address del Klarna response. Mientras tanto, parsear el Klarna response en iOS y llamar `updateCheckout` post-confirm.

### Fase Pago-3 — Mark legacy step flow as deprecated for scoped (5min)

Una vez Fase Pago-2 verde:

- Añadir comentario en `addressStepView` y `orderSummaryStepView`:
  `// DEPRECATED for multi-sponsor scope as of <commit>. Used only by legacy single-cart flow. Removed in Fase 5 cleanup.`
- No borrar todavía — el legacy single-cart path (host sin multi-sponsor)
  sigue usándolos.

## Plan de ejecución (resumen)

1. **Pago-1** (~1-2h, iOS code): 3 commits incrementales (Stripe, Klarna, dispatch). Build clean entre cada uno.
2. **Pago-2** (~30min, user test): 2 órdenes reales + DB inspection. Te paso queries listos.
3. **Pago-2b** (condicional): solo si Pago-2 revela gap. Decision point — coord Reachu o fallback iOS.
4. **Pago-3** (~5min, docs): mark deprecated.

Total estimado happy path: **~2h.** Con backend gap: **+2-4 días dependiendo de Reachu**.

## Criterios de "done"

- ✅ Tap "Card" en cart Vg → Stripe PaymentSheet directo, sin step flow → orden completa con shipping correcto en DB.
- ✅ Tap "Klarna" en cart Vg → Klarna webview directo → orden completa con shipping correcto.
- ✅ Tap "Apple Pay" sigue funcionando (regression check).
- ✅ Multi-sponsor flow (TV2) también funciona (regression check).
- ✅ Legacy single-cart flow no afectado (regression check).
- ✅ Build clean iOS via xcodebuild.

## Risks

- **R1**: Stripe PaymentSheet no collecta shipping → orders sin shipping
  → fulfillment fails. Mitigación: Pago-2b plan B.
- **R2**: Klarna init falla con minimal input. Posible si Reachu valida
  email obligatorio antes de Klarna. Mitigación: ver error del init en
  Pago-2; si falla → agregar email-only mini sheet pre-Klarna.
- **R3**: Cancel mid-Klarna-webview / mid-Stripe-sheet deja state stale.
  Mitigación: result handlers limpian estado ya (reuso patrón Apple Pay).
- **R4**: KlarnaNativePaymentSheet ya wired con flow scoped — necesita
  poder dispararse sin scope. Verificar binding del `.sheet(item:)`.

## Reference

- `MULTI-SPONSOR-ALIGNMENT-PLAN.md` (branch `feat/align-multi-sponsor-paths`):
  contexto y constraints de la fase previa.
- `Sources/VioUI/Components/VCheckoutOverlay.swift:352-402`:
  `handleSponsorCheckoutTap` + `triggerSponsorApplePay` (patrón a copiar).
- `Sources/VioUI/Components/VCheckoutOverlay.swift:2703-2747`:
  `prepareStripePaymentSheet` existing (parte se reusa).
- `Sources/VioCore/Sdk/Domain/Models/PaymentModels.swift:231-275`:
  `KlarnaNativeInitInputDto` — confirmación de campos opcionales.
- `Sources/VioUI/Managers/PaymentManager.swift:246`:
  `stripeIntent(returnEphemeralKey:sponsorId:)`.
- `Sources/VioUI/Managers/PaymentManager.swift:100+`:
  `initKlarnaNative(input:sponsorId:)` y `confirmKlarnaNative`.
