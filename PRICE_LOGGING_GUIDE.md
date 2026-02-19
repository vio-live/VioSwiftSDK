# Price Flow Logging Guide

Este documento describe los logs agregados para rastrear el flujo de precios desde la UI hasta el cart.

## 📊 Logs Agregados

### 1. RProductCard - Cuando se muestra el producto en listas/grids

**Archivo**: `Sources/ReachuUI/Components/RProductCard.swift`  
**Ubicación**: En `priceView` (línea ~377)

```
💰 [RProductCard] Showing product: {product_title}
💰 [RProductCard] Price amount: {price.amount}
💰 [RProductCard] Price with taxes: {price.amount_incl_taxes}
💰 [RProductCard] Display amount: {price.displayAmount}
💰 [RProductCard] Currency: {price.currency_code}
```

**Cuándo se ve**: Cada vez que un producto aparece en pantalla (slider, grid, list, etc.)

---

### 2. RProductDetailOverlay - Cuando se abre el detalle del producto

**Archivo**: `Sources/ReachuUI/Components/RProductDetailOverlay.swift`  
**Ubicación**: En `productInfoSection` (línea ~382)

```
🎯 [RProductDetailOverlay] Product detail opened
🎯 [RProductDetailOverlay] Product: {product_title}
🎯 [RProductDetailOverlay] Product ID: {product_id}
🎯 [RProductDetailOverlay] Base price amount: {price.amount}
🎯 [RProductDetailOverlay] Price with taxes: {price.amount_incl_taxes}
🎯 [RProductDetailOverlay] Current price with taxes: {currentPriceWithTaxes}
🎯 [RProductDetailOverlay] Currency: {currency_code}
🎯 [RProductDetailOverlay] Formatted display: {formatted_price}
```

**Cuándo se ve**: Cuando el usuario toca un producto para ver detalles

---

### 3. CartModule.addProduct - Cuando se agrega al cart

**Archivo**: `Sources/ReachuUI/Managers/CartModule.swift`  
**Ubicación**: En función `addProduct` (línea ~501)

```
🛒 [CartModule] ========== ADD PRODUCT TO CART ==========
🛒 [CartModule] Product: {product_title}
🛒 [CartModule] Product ID: {product_id}
🛒 [CartModule] Base price amount: {price.amount}
🛒 [CartModule] Price with taxes: {price.amount_incl_taxes}
🛒 [CartModule] Currency: {currency_code}
🛒 [CartModule] Quantity to add: {quantity}
```

**Si hay variante seleccionada**:
```
🛒 [CartModule] Variant selected: {variant_title}
🛒 [CartModule] Variant price amount: {variant.price.amount}
🛒 [CartModule] Variant price with taxes: {variant.price.amount_incl_taxes}
```

**Cuándo se ve**: Cuando el usuario presiona "Add to Cart"

---

### 4. CartModule.sync - Cuando el backend responde

**Archivo**: `Sources/ReachuUI/Managers/CartModule.swift`  
**Ubicación**: En función `sync(from:)` (línea ~155)

```
🔄 [CartModule] ========== SYNC FROM BACKEND ==========
🔄 [CartModule] Cart ID: {cart_id}
🔄 [CartModule] Currency: {currency}
🔄 [CartModule] Line items count: {count}
```

**Para cada producto en el cart**:
```
🔄 [CartModule] --- Line Item ---
🔄 [CartModule] Product: {product_title}
🔄 [CartModule] Product ID: {product_id}
🔄 [CartModule] Backend price amount: {backend_price.amount}
🔄 [CartModule] Backend price with taxes: {backend_price.amount_incl_taxes}
🔄 [CartModule] Quantity: {quantity}
```

**Cálculo de totales**:
```
🔄 [CartModule] Item '{title}': price={price} × qty={quantity} = {itemTotal}
```

**Final del sync**:
```
🔄 [CartModule] ========== SYNC COMPLETE ==========
🔄 [CartModule] Cart Total: {cartTotal}
🔄 [CartModule] Currency: {currency}
🔄 [CartModule] Total items in cart: {count}
```

**Cuándo se ve**: Después de agregar/actualizar/eliminar items del cart

---

## 🔍 Cómo Usar los Logs

### Escenario: Rastrear precio incorrecto en cart

1. **Buscar el producto en la lista**:
   ```
   💰 [RProductCard] Showing product: FC Barcelona Jersey
   💰 [RProductCard] Price amount: 758.0
   💰 [RProductCard] Price with taxes: 758.0
   ```

2. **Abrir detalle del producto**:
   ```
   🎯 [RProductDetailOverlay] Product: FC Barcelona Jersey
   🎯 [RProductDetailOverlay] Base price amount: 758.0
   🎯 [RProductDetailOverlay] Price with taxes: 758.0
   ```

3. **Agregar al cart**:
   ```
   🛒 [CartModule] Product: FC Barcelona Jersey
   🛒 [CartModule] Base price amount: 758.0
   🛒 [CartModule] Price with taxes: 758.0
   ```

4. **Respuesta del backend**:
   ```
   🔄 [CartModule] Product: FC Barcelona Jersey
   🔄 [CartModule] Backend price amount: 8934.72  ← ⚠️ PRECIO DIFERENTE
   🔄 [CartModule] Backend price with taxes: 8934.72
   ```

5. **Total calculado**:
   ```
   🔄 [CartModule] Item 'FC Barcelona Jersey': price=8934.72 × qty=1 = 8934.72
   🔄 [CartModule] Cart Total: 8934.72
   ```

### Interpretación

Si ves precios diferentes entre los pasos 1-3 y el paso 4:
- **El problema está en el backend de Reachu**
- El producto tiene un precio diferente en la base de datos del backend
- El SDK está enviando el `productId` correcto pero el backend devuelve otro precio

## 🐛 Posibles Problemas y Soluciones

### Problema 1: Backend devuelve precio diferente

**Síntoma**:
```
🛒 [CartModule] Base price amount: 758.0
🔄 [CartModule] Backend price amount: 8934.72  ← Diferente
```

**Causa**: El backend tiene un precio diferente registrado para ese producto.

**Soluciones**:
1. Corregir el precio en el backend de Reachu
2. Enviar `priceData` en el `LineItemInput` para override (actualmente se envía `nil`)

### Problema 2: Variante tiene precio diferente

**Síntoma**:
```
🛒 [CartModule] Base price amount: 758.0
🛒 [CartModule] Variant price amount: 950.0  ← Variante más cara
```

**Causa**: Variantes pueden tener precios diferentes (esto es normal).

**Verificación**: Asegurar que se muestra el precio de la variante en la UI.

### Problema 3: Conversión de moneda incorrecta

**Síntoma**:
```
💰 [RProductCard] Currency: NOK
🔄 [CartModule] Currency: EUR  ← Moneda diferente
```

**Causa**: Backend puede estar convirtiendo moneda.

**Verificación**: Revisar configuración de mercado y moneda en `reachu-config.json`.

## 📝 Ejemplo de Log Completo

```
💰 [RProductCard] Showing product: FC Barcelona Dri-Fit Jersey
💰 [RProductCard] Price amount: 758.0
💰 [RProductCard] Price with taxes: 758.0
💰 [RProductCard] Display amount: NOK 758.00
💰 [RProductCard] Currency: NOK

🎯 [RProductDetailOverlay] Product detail opened
🎯 [RProductDetailOverlay] Product: FC Barcelona Dri-Fit Jersey
🎯 [RProductDetailOverlay] Product ID: 12345
🎯 [RProductDetailOverlay] Base price amount: 758.0
🎯 [RProductDetailOverlay] Price with taxes: 758.0
🎯 [RProductDetailOverlay] Current price with taxes: 758.0
🎯 [RProductDetailOverlay] Currency: NOK
🎯 [RProductDetailOverlay] Formatted display: kr 758.00

🛒 [CartModule] ========== ADD PRODUCT TO CART ==========
🛒 [CartModule] Product: FC Barcelona Dri-Fit Jersey
🛒 [CartModule] Product ID: 12345
🛒 [CartModule] Base price amount: 758.0
🛒 [CartModule] Price with taxes: 758.0
🛒 [CartModule] Currency: NOK
🛒 [CartModule] Quantity to add: 1

🔄 [CartModule] ========== SYNC FROM BACKEND ==========
🔄 [CartModule] Cart ID: cart_abc123
🔄 [CartModule] Currency: NOK
🔄 [CartModule] Line items count: 1
🔄 [CartModule] --- Line Item ---
🔄 [CartModule] Product: FC Barcelona Dri-Fit Jersey
🔄 [CartModule] Product ID: 12345
🔄 [CartModule] Backend price amount: 8934.72  ← ⚠️ DIFERENTE!
🔄 [CartModule] Backend price with taxes: 8934.72
🔄 [CartModule] Quantity: 1
🔄 [CartModule] Item 'FC Barcelona Dri-Fit Jersey': price=8934.72 × qty=1 = 8934.72
🔄 [CartModule] ========== SYNC COMPLETE ==========
🔄 [CartModule] Cart Total: 8934.72
🔄 [CartModule] Currency: NOK
🔄 [CartModule] Total items in cart: 1
```

## 🎯 Próximos Pasos

1. **Ejecutar la app** en Viaplay demo
2. **Agregar un producto** al cart
3. **Revisar los logs** en Xcode console
4. **Comparar precios** entre UI y backend
5. **Reportar hallazgos** al equipo de Reachu si el backend tiene precios incorrectos

## 🔧 Eliminar Logs (Producción)

Para producción, estos logs deberían estar envueltos en:

```swift
#if DEBUG
print("...")
#endif
```

O usar el sistema de logging de Reachu:

```swift
ReachuLogger.debug("...", component: "CartModule")
```


