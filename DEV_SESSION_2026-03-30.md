# DEV SESSION — 2026-03-30
> Archivo compartido Amy ↔ Cursor. Amy escribe contexto y decisiones. Cursor escribe estado, preguntas y próximos pasos.
> Angelo coordina desde Discord #dev.

---

## Estado actual [Amy — 23:46]

### Branch activa
`feature/cart-intent-overlay` base: `feature/tv2-sdk-integration` @ `add4ff2`

### Qué está implementado (commit `de88a2b`)
- ✅ `CampaignManager.activeCartIntentEvent` (@Published) + `dismissCartIntent()`
- ✅ Overlay global en `ContentView` ZStack zIndex 1000
- ✅ `TV2CartIntentMapping` helper — mapeo CartIntentEvent → ProductEventData
- ✅ `discoverCampaigns` movido a `ContentView.onAppear`

### Decisión confirmada con Angelo
- `price` e `imageUrl` en `ProductEventData` son **placeholders vacíos** — intencional
- Los datos reales vienen de Commerce GraphQL usando `productId`
- Añadir comentario explícito en `TV2CartIntentMapping.productEventData()`:

```swift
// price and imageUrl are intentionally empty — TV2ProductOverlay
// fetches real product data (image, price, variants) from Commerce GraphQL
// using productId. These fields are placeholders to satisfy the model.
```

### Pendiente verificar
1. ¿Compila sin errores en `feature/cart-intent-overlay`?
2. ¿El overlay aparece en simulador cuando llega cart_intent por WS?
3. ¿`ProductFetchViewModel` hace el fetch GraphQL correctamente desde el overlay global (ContentView)?
4. ¿Loading state visible mientras llega el producto?

### Test E2E desde terminal
```bash
curl -X POST https://api-dev.vio.live/api/campaigns/36/cart-intent \
  -H "Content-Type: application/json" \
  -H "X-API-Key: tv2_api_key_91b4fbf634af4bc5" \
  -d '{"productId": "408841", "userId": "tv2_demo_user"}'
```
- `userId` en app: `tv2_demo_user` (seteado en `tv2demoApp.init`)
- WS debe estar conectado antes de disparar el curl
- Respuesta esperada: `"userConnected": true`

### Config de entorno
- REST: `https://api-dev.vio.live`
- WS: `wss://ws-dev.vio.live`
- GraphQL: `https://graph-ql-dev.vio.live/graphql`
- `commerceApiKey`: en `vio-config.json` → `liveShowConfiguration.commerceBaseUrl` + `commerceApiKey`
- `campaignId`: 36 | `apiKey`: `tv2_api_key_91b4fbf634af4bc5`

---

## Log de cambios

| Hora | Quién | Qué |
|------|-------|-----|
| 23:46 | Amy | Archivo creado, estado inicial documentado |

---

## Cursor — escribe aquí tu estado y preguntas

- **Pull:** `origin/feature/cart-intent-overlay` traído (`dde985a` — instrucciones overlay SDK).
- **Implementado:** `ContentView` usa `VEngagementProductOverlay` + `CartIntentEngagementOverlayHost` (paridad con `VCastingVideoPlayer`): `ProductFetchViewModel`, `isLoading`, sheet `VProductDetailOverlay`. `TV2CartIntentMapping` solo cart + descripción; eliminado `ProductEventData` para este flujo.


---

## Corrección urgente [Amy — 23:51]

### Problema
El overlay que aparece es `TV2ProductOverlay` (custom del demo). El correcto es `VEngagementProductOverlay` de `VioEngagementUI` — es el overlay nativo del SDK, con los colores y diseño de Vio.

### Fix requerido en `ContentView.swift`

**Reemplazar:**
```swift
import VioUI  // o el import que se esté usando
// ...
TV2ProductOverlay(
    productEvent: productEvent,
    ...
)
```

**Por:**
```swift
import VioEngagementUI

// En el ZStack, reemplazar TV2ProductOverlay por:
VEngagementProductOverlay(
    product: VEngagementProductData(
        productId: event.productId,
        name: event.productName ?? "Product",
        description: nil,
        price: "",        // fetched via GraphQL — intentional placeholder
        imageUrl: ""      // fetched via GraphQL — intentional placeholder
    ),
    isChatExpanded: false,
    isLoading: true,      // true hasta que GraphQL responda
    onAddToCart: {
        // fetch product via Commerce GraphQL → cartManager.addProduct
    },
    onDismiss: {
        CampaignManager.shared.dismissCartIntent()
    }
)
.zIndex(1000)
```

### Modelo `VEngagementProductData`
```swift
public struct VEngagementProductData {
    public let productId: String?
    public let name: String
    public let description: String?
    public let price: String
    public let imageUrl: String
    public let discountPercentage: Int?
}
```

### Commerce GraphQL fetch
`VEngagementProductOverlay` tiene `isLoading: Bool` — pasar `true` mientras llega el fetch de GraphQL, luego actualizar el estado con los datos reales (precio, imagen). Reutilizar `ProductFetchViewModel` igual que antes.

### `TV2CartIntentMapping`
Ya no es necesario el helper `productEventData()` — reemplazado por mapeo directo a `VEngagementProductData`. Mantener solo `product(from: ProductDto)` para el carrito.

---

| Hora | Quién | Qué |
|------|-------|-----|
| 23:51 | Amy | Corrección: usar VEngagementProductOverlay, no TV2ProductOverlay |
