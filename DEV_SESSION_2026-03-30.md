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

<!-- Cursor: usa esta sección para reportar compilación, errores, preguntas -->


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

---

## CORRECCIÓN ARQUITECTURA — URGENTE [Amy — 00:02]

### El problema con lo implementado
Cursor implementó un sistema nuevo (`activeCartIntentEvent` @Published + overlay custom en ContentView). **Eso está mal.** Ya existe una arquitectura completa en el SDK para esto.

### La arquitectura correcta: DynamicComponentManager

El SDK tiene:
- `DynamicComponentManager.shared` — singleton que registra/activa/desactiva componentes
- `DynamicComponentRenderer` — View que observa el manager y renderiza todo automáticamente
- `FeaturedProductComponentView` — el componente visual de producto ya construido
- `DynamicComponent(.featuredProduct(FeaturedProductComponentData(product:...)))` — el modelo

`DynamicComponentRenderer` ya está embebido en `VLiveShowOverlay` con zIndex 10,000,000. Es el sistema de overlays dinámicos del SDK.

### Qué hay que hacer — reescribir el approach

**Revertir en `ContentView.swift`:**
- Eliminar el overlay de `TV2ProductOverlay` / `VEngagementProductOverlay`
- Eliminar `@ObservedObject var campaignManager`
- Eliminar `cartIntentPresentationID`
- Solo añadir: `DynamicComponentRenderer().zIndex(10_000_000)`

**Revertir en `CampaignManager.swift`:**
- Eliminar `@Published activeCartIntentEvent`
- Eliminar `dismissCartIntent()`

**Nuevo handler en `CampaignManager` cuando llega `cart_intent`:**
```swift
// En el handler de cart_intent del CampaignWebSocketManager:
campaignWebSocket?.onCartIntent = { [weak self] event in
    guard let productId = event.productId else { return }
    Task { @MainActor in
        // 1. Fetch product from Commerce GraphQL
        let product = await self?.fetchProduct(id: productId)
        guard let product = product else { return }
        
        // 2. Register + activate via DynamicComponentManager
        let component = DynamicComponent(
            id: "cart-intent-\(productId)",
            type: .featuredProduct,
            startTime: nil,          // activate immediately
            endTime: Date().addingTimeInterval(30), // 30s auto-dismiss
            position: .bottom,
            triggerOn: .streamStart,
            data: .featuredProduct(FeaturedProductComponentData(
                product: product,
                productId: Int(productId),
                position: .bottom,
                startTime: nil,
                endTime: Date().addingTimeInterval(30),
                triggerOn: .streamStart
            ))
        )
        DynamicComponentManager.shared.register(component)
    }
}
```

**Commerce GraphQL fetch — reutilizar `ProductService` o `SdkClient`:**
Ver `Sources/VioUI/Services/ProductService.swift` — ya tiene el fetch por productId.

### Lo que NO hay que tocar
- `TV2CartIntentMapping` — eliminar completamente (no se necesita)
- `TAREA_CART_INTENT_OVERLAY.md` — actualizar con la nueva arquitectura

### Confirmar en el archivo cuando termines
Escribe tu estado + cualquier pregunta sobre el fetch de Commerce o la estructura de `DynamicComponent` abajo.

| Hora | Quién | Qué |
|------|-------|-----|
| 00:02 | Amy | Corrección arquitectura — usar DynamicComponentManager, no overlay custom |
