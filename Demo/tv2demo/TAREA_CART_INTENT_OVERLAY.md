# Tarea — `cart_intent` → overlay de producto (second-screen)

**Contexto:** VioSwiftSDK es el SDK de engagement en vivo para broadcasters (TV2, Viaplay). El WebSocket de campaña ya es estable (`wss://ws-dev.vio.live`). El backend puede enviar un evento **`cart_intent`** al dispositivo de un usuario concreto (mapeo `userId` ↔ conexión WS), por ejemplo cuando alguien en **Apple TV** pulsa un producto en un anuncio shoppable y el **iPhone** del mismo hogar debe mostrar la ficha para comprar o añadir al carrito.

**Qué se implementó**

- **SDK (`VioCore`):** `CampaignManager` expone `@Published activeCartIntentEvent` y `dismissCartIntent()`. En `connectWebSocket` se asigna `onCartIntent` del `CampaignWebSocketManager` para actualizar ese estado en el main actor. Se limpia el evento en `campaign_ended`, `campaign_paused` y `disconnect`. `CartIntentEvent` conforma `Equatable` para observadores SwiftUI.
- **Demo tv2demo:** `ContentView` observa `CampaignManager.shared`, muestra **`TV2ProductOverlay`** global encima del resto (`zIndex` 1000). Se reutiliza el fetch existente vía **`ProductFetchViewModel`** dentro del overlay. Helper **`TV2CartIntentMapping`:** mapeo `CartIntentEvent` → `ProductEventData` sintético + `ProductDto` → `Product` para el carrito. Cliente GraphQL con `commerceApiKey` cuando existe, igual que `ProductService`.

**Rama:** `feature/cart-intent-overlay` (base: `feature/tv2-sdk-integration` @ `add4ff2`).

---

## Cómo probarlo (E2E)

1. **Configuración**
   - En la app (p. ej. `tv2demoApp`), `CampaignManager.shared.userId` debe coincidir con el `userId` del POST de prueba (ej. `tv2_demo_user`).
   - Arrancar tv2demo y esperar `discoverCampaigns` → WebSocket **conectado** (`isConnected == true`).

2. **Disparar el intent desde el backend** (simula el tap en TV / panel admin):

```bash
curl -X POST https://api-dev.vio.live/api/campaigns/36/cart-intent \
  -H "Content-Type: application/json" \
  -H "X-API-Key: tv2_api_key_91b4fbf634af4bc5" \
  -d '{"productId": "408841", "userId": "tv2_demo_user"}'
```

Respuesta esperada incluye algo como `"userConnected": true` si el simulador/dispositivo ya tiene WS abierto con ese `userId`.

3. **En el simulador:** debe aparecer el overlay global con datos reales del producto (GraphQL). Cerrar con dismiss llama a `dismissCartIntent()`.

4. **Edge:** segundo `cart_intent` reemplaza el primero; mismo `productId` repetido fuerza nueva presentación vía `cartIntentPresentationID` en `ContentView`.

**Qué necesitas:** API key válida, `campaignId` acorde al entorno, `productId` existente en Commerce, GraphQL URL + `commerceApiKey` / `apiKey` en `vio-config.json`, y el mismo `userId` en app y en el JSON del POST.
