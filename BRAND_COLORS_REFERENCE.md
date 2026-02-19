# Brand Colors Reference

Este documento contiene los colores de marca utilizados en los componentes del SDK para referencia y configuración.

## Power Brand Colors

Power utiliza una paleta de colores naranja y azul:

- **Primary Color (Orange)**: `Color.orange` (sistema iOS)
  - Hex aproximado: `#FF9500` (iOS Orange)
  - Uso: Botones principales, badges de descuento, precios destacados, iconos
  - Opacidades comunes: 0.8, 0.6, 0.4, 0.1

- **Secondary Color (Blue)**: `Color.blue` (sistema iOS)
  - Hex aproximado: `#007AFF` (iOS Blue)
  - Uso: Badge de verificación (checkmark.seal.fill)

**Nota**: Estos colores fueron reemplazados por `ReachuColors.primary` y `ReachuColors.info` en el SDK para permitir personalización por campaña.

## Elkjøp Brand Colors

Elkjøp utiliza un verde distintivo como color primario:

- **Primary Color (Green)**: `#69A333`
  - RGB: `rgb(105, 163, 51)`
  - Uso: Botones principales, badges de descuento, precios destacados, iconos
  - Este color debe configurarse en el archivo `reachu-config.json` como `primary` en la configuración del tema

### Configuración en reachu-config.json

Para usar los colores de Elkjøp, configura el tema así:

```json
{
  "theme": {
    "lightColors": {
      "primary": "#69A333",
      "secondary": "#5856D6",
      "success": "#34C759",
      "warning": "#FF9500",
      "error": "#FF3B30",
      "info": "#007AFF",
      "background": "#F2F2F7",
      "surface": "#FFFFFF",
      "surfaceSecondary": "#F9F9F9",
      "textPrimary": "#000000",
      "textSecondary": "#8E8E93",
      "textTertiary": "#C7C7CC",
      "textOnPrimary": "#FFFFFF",
      "border": "#E5E5EA",
      "borderSecondary": "#D1D1D6",
      "priceColor": "#69A333"
    },
    "darkColors": {
      "primary": "#69A333",
      "secondary": "#5E5CE6",
      "success": "#32D74B",
      "warning": "#FF9F0A",
      "error": "#FF453A",
      "info": "#0A84FF",
      "background": "#000000",
      "surface": "#1C1C1E",
      "surfaceSecondary": "#2C2C2E",
      "textPrimary": "#FFFFFF",
      "textSecondary": "#8E8E93",
      "textTertiary": "#48484A",
      "textOnPrimary": "#FFFFFF",
      "border": "#38383A",
      "borderSecondary": "#48484A",
      "priceColor": "#69A333"
    }
  }
}
```

## Migración de Colores Hardcodeados

Todos los componentes del SDK ahora usan `ReachuColors.adaptive(for: colorScheme)` en lugar de colores hardcodeados:

- `Color.orange` → `ReachuColors.primary`
- `Color.blue` → `ReachuColors.info`
- `Color.white` → `ReachuColors.textPrimary`
- `Color.black` → `ReachuColors.background` o `ReachuColors.textPrimary` (según contexto)
- Colores hex hardcodeados → Colores del tema configurado

## Assets de Imágenes

### Power Assets (Legacy - Preservados para referencia)

- **gavekortpower**: Asset completo de concurso con fondo naranja, gift box y gift card
  - Mapeado a: `elkjop_konk` para campañas de Elkjøp
  - Preservado en comentarios del código para referencia

### Elkjøp Assets

- **elkjop_konk**: Asset completo de concurso (equivalente a `gavekortpower` de Power)
  - Incluye: fondo con color primario, gift box, gift card, texto "VINN!"
  - Uso: Para mostrar el componente completo de concurso
  
- **elkjop_gavekort**: Asset solo de gift card
  - Uso: Cuando solo se necesita mostrar la gift card sin el fondo completo

### Mapeo de Assets

El componente `REngagementContestCard` mapea automáticamente:
- `gavekortpower` → `elkjop_konk` (para compatibilidad con datos legacy de Power)
- `elkjop_gavekort` → `elkjop_gavekort` (sin cambios)
- `elkjop_konk` → `elkjop_konk` (sin cambios)

## Componentes Actualizados

Los siguientes componentes ahora usan colores del SDK:

- ✅ `REngagementProductGridCard` - Grid de productos múltiples
- ✅ `REngagementPollCard` - Card de encuestas
- ✅ `REngagementContestCard` - Card de concursos (con mapeo de assets)
- ✅ `REngagementProductCard` - Card de producto individual
- ✅ `REngagementPollOverlay` - Overlay de encuestas
- ✅ `REngagementContestOverlay` - Overlay de concursos
- ✅ `REngagementProductOverlay` - Overlay de productos
