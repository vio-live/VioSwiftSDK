# Lista de Valores Hardcodeados a Reemplazar

Este documento lista todos los valores hardcodeados encontrados en los componentes del engagement system y sus reemplazos correspondientes usando la configuración del SDK.

## Colores Hardcodeados

### Reemplazos Completados

| Hardcodeado Original | Reemplazo SDK | Ubicación |
|---------------------|---------------|-----------|
| `ViaplayTheme.Colors.pink` | `ReachuColors.primary` | Todos los componentes |
| `ViaplayTheme.Colors.pink.opacity(0.6)` | `ReachuColors.primary.opacity(0.6)` | PollCard, ContestCard |
| `ViaplayTheme.Colors.pink.opacity(0.8)` | `ReachuColors.primary.opacity(0.8)` | Botones, ContestCard |
| `Color.white` | `ReachuColors.textPrimary` | Textos principales |
| `Color.white.opacity(0.3)` | `ReachuColors.textPrimary.opacity(0.3)` | Drag indicators |
| `Color.white.opacity(0.7)` | `ReachuColors.textSecondary` | Textos secundarios |
| `Color.white.opacity(0.8)` | `ReachuColors.textSecondary.opacity(0.8)` | Textos secundarios |
| `Color.white.opacity(0.95)` | `ReachuColors.textPrimary` | Textos principales |
| `Color.black.opacity(0.4)` | `ReachuColors.surface.opacity(0.4)` | Backgrounds de cards |
| `Color(hex: "3A3D5C")` | `ReachuColors.surfaceSecondary` | Botones de opciones |
| `Color(hex: "120019")` | `ReachuColors.background` | Backgrounds |
| `Color.green` | `ReachuColors.success` | Indicadores de éxito |
| `Color.red.opacity(0.8)` | `ReachuColors.error.opacity(0.8)` | Botones de error |
| `Color.white.opacity(0.15)` | `ReachuColors.surfaceSecondary.opacity(0.5)` | Input fields |
| `Color.white.opacity(0.2)` | `ReachuColors.textPrimary.opacity(0.2)` | Progress bar backgrounds |

### Componentes Específicos

#### REngagementPollCard
- ✅ Botones de opciones seleccionadas: `ReachuColors.primary.opacity(0.6)`
- ✅ Botones de opciones no seleccionadas: `ReachuColors.surfaceSecondary`
- ✅ Barras de resultados: `ReachuColors.primary` para fill
- ✅ Texto "Takk for at du stemte!": `ReachuColors.primary`
- ✅ Gradientes de avatar: `ReachuColors.primary` con opacidades
- ✅ Drag indicator: `ReachuColors.textPrimary.opacity(0.3)`
- ✅ Background card: `ReachuColors.surface.opacity(0.4)`

#### REngagementContestCard
- ✅ Botón "Bli med!": `ReachuColors.primary.opacity(0.8)`
- ✅ Texto de premio: `ReachuColors.primary`
- ✅ Rueda de premios: `ReachuColors.primary` con opacidades alternadas
- ✅ Indicador "Du er med!": `ReachuColors.success`
- ✅ ProgressView tint: `ReachuColors.primary`
- ✅ Background de premio: `ReachuColors.surfaceSecondary.opacity(0.5)`

#### REngagementProductCard
- ✅ Precio: `ReachuColors.priceColor` (ya configurado en theme)
- ✅ Botón "Legg til": `ReachuColors.primary.opacity(0.8)`
- ✅ Badge de descuento: `ReachuColors.primary`
- ✅ Checkmark cuando agregado: `ReachuColors.success`
- ✅ Placeholder de imagen: `ReachuColors.surfaceSecondary`

#### ViaplayCastingActiveView
- ✅ Barra de progreso: `ReachuColors.primary`
- ✅ Texto "LIVE": `ReachuColors.primary`
- ✅ Botón Play/Pause: `ReachuColors.primary` con `textOnPrimary`
- ✅ Botón Stop: `ReachuColors.error.opacity(0.8)`
- ✅ Chat input background: `ReachuColors.surfaceSecondary.opacity(0.5)`
- ✅ Chat background: `ReachuColors.surface.opacity(0.4)`
- ✅ Botones de chat: `ReachuColors.primary`

## Otros Valores Hardcodeados

### Tamaños de Fuente
- ✅ Usar tamaños estándar del sistema (14, 12, 10, etc.) - Mantener por ahora
- ⚠️ **Pendiente**: Evaluar si deben moverse a `ReachuTypography` del design system

### Spacing
- ✅ Reemplazados con `ReachuSpacing` (xs, sm, md, lg, xl)
- ✅ Padding horizontal: `ReachuSpacing.md` (16)
- ✅ Padding vertical: `ReachuSpacing.sm` (8)

### Border Radius
- ✅ Reemplazados con `ReachuBorderRadius`
- ✅ Cards: `ReachuBorderRadius.large` (20)
- ✅ Botones: `ReachuBorderRadius.medium` (12)
- ✅ Progress bars: `ReachuBorderRadius.small` (8)

### Shadows
- ✅ Mantener `Color.black.opacity(0.6)` para shadows (estándar de iOS)
- ⚠️ **Pendiente**: Evaluar si deben moverse a `ReachuShadow` del design system

### Imágenes Hardcodeadas
- ✅ `Image("logo1")` → Reemplazado con `CampaignSponsorBadge` del SDK
- ✅ `AsyncImage` → Reemplazado con `CachedAsyncImage` del SDK

### Textos Hardcodeados
- ⚠️ **Pendiente**: Evaluar si deben moverse a localización
  - "Sponset av"
  - "Resultater"
  - "Takk for at du stemte!"
  - "Bli med!"
  - "Du er med!"
  - "Legg til"
  - "Lagt til!"
  - "PREMIER"
  - "Frist:"
  - "Maks deltakere:"
  - "Trekking om Xs..."
  - "Casting to..."
  - "LIVE"
  - "LIVE CHAT"
  - "Send a message..."

## Archivos Migrados

### Componentes Migrados al SDK
- ✅ `ViaplayCastingPollCardView.swift` → `REngagementPollCard.swift`
- ✅ `ViaplayCastingContestCardView.swift` → `REngagementContestCard.swift`
- ✅ `ViaplayCastingProductCardView.swift` → `REngagementProductCard.swift`

### Componentes Base Creados
- ✅ `REngagementCardBase.swift` - Componente base compartido
- ✅ `REngagementDragIndicator.swift` - Indicador de drag
- ✅ `REngagementSponsorBadge.swift` - Badge de sponsor

### Componentes Compartidos Movidos al SDK
- ✅ `CachedAsyncImage.swift` → `ReachuDesignSystem/Components/`
- ✅ `CampaignSponsorBadge.swift` → `ReachuDesignSystem/Components/`

### Archivos Eliminados
- ✅ `ViaplayCastingPollCardView.swift` (demo)
- ✅ `ViaplayCastingContestCardView.swift` (demo)
- ✅ `ViaplayCastingProductCardView.swift` (demo)
- ✅ `EngagementManager.swift` (ReachuCore) → Movido a ReachuEngagementSystem
- ✅ `EngagementModels.swift` (ReachuCore) → Movido a ReachuEngagementSystem

## Valores Pendientes de Reemplazar

### En Otros Componentes del Demo (No Engagement)

Los siguientes componentes aún tienen valores hardcodeados pero NO son parte del engagement system:

1. **ViaplayPollOverlay.swift**
   - `ViaplayTheme.Colors.pink` (múltiples instancias)
   - `Color.white`, `Color.black.opacity(0.4)`
   - `Color(hex: "3A3D5C")`

2. **ViaplayContestOverlay.swift**
   - `ViaplayTheme.Colors.pink` (múltiples instancias)
   - `Color.green`
   - `Color(hex: "120019")`

3. **ViaplayOfferBannerView.swift**
   - `ViaplayTheme.Colors.pink`
   - `Color(hex: "1B1B25")`
   - `Color.white`

4. **Otros componentes del demo**
   - Varios componentes aún usan `ViaplayTheme.Colors.pink`
   - Estos NO son parte del engagement system de casting

## Notas

- Todos los componentes del engagement system de casting ahora usan `ReachuColors.adaptive(for:)` para soportar dark/light mode automático
- Los componentes usan `@Environment(\.colorScheme)` para adaptarse automáticamente
- Los componentes están completamente migrados al SDK y no dependen de valores hardcodeados del demo
- La migración mantiene la misma API pública para facilitar la integración

## Próximos Pasos Recomendados

1. ⚠️ Migrar otros overlays del demo (ViaplayPollOverlay, ViaplayContestOverlay) al SDK
2. ⚠️ Evaluar mover textos hardcodeados a sistema de localización
3. ⚠️ Evaluar crear tokens de tipografía en ReachuTypography
4. ⚠️ Evaluar crear tokens de shadows en ReachuShadow
5. ✅ Testing en light y dark mode
6. ✅ Documentación SwiftDoc para componentes públicos
