# Referencia de Componentización - VioSwiftSDK

Documento de referencia de todos los cambios realizados para dejar el SDK y demos componentizados, dinámicos y listos para cambiar entre demos (Viaplay/Elkjøp, Skistar, etc.) sin hardcodear.

---

## 1. Configuración de Brand (Fuente única)

### Archivos clave
- **`Demo/Viaplay/Viaplay/Configuration/demo-static-data.json`** – Sección `brand` con `name` e `iconAsset`
- **`Demo/Viaplay/Viaplay/Configuration/vio-config.json`** – Sección `brand` (fallback)
- **`Sources/VioCore/Configuration/VioConfiguration.swift`** – Merge de brand en `configure()`
- **`Sources/VioCore/Configuration/ModuleConfigurations.swift`** – `DemoDataConfiguration.brand: BrandConfiguration?`

### Lógica de merge
1. Si `demo-static-data.json` tiene sección `brand` → se usa como fuente única
2. Si no tiene `brand` → se usa `vio-config` y se sincroniza `iconAsset` con `assets.defaultAvatar`

### Ejemplo para nuevo demo (Skistar)
```json
"brand": {
  "name": "Skistar",
  "iconAsset": "avatar_skistar"
}
```

---

## 2. Assets desde Configuración

### DemoDataManager (VioCore)
- `defaultLogo` – Logo por defecto
- `defaultAvatar` – Avatar por defecto (legacy; para brand usar `effectiveBrandConfiguration.iconAsset`)
- `backgroundImage(for:)` – footballField, mainBackground, sportDetail, sportDetailImage
- `brandAsset(for:)` – icon, logo
- `contestAsset(for:)` – giftCard, championsLeagueTickets
- `productUrl(for:)` / `checkoutUrl(for:)` – URLs de productos desde `productMappings`

### VioConfiguration
- `effectiveBrandConfiguration.name` – Nombre de marca
- `effectiveBrandConfiguration.iconAsset` – Avatar/icono de marca (usar en casting cards)

---

## 3. Componentes actualizados (sin hardcode)

### Avatar/Icono de marca
Usan `VioConfiguration.shared.effectiveBrandConfiguration.iconAsset`:
- `Sources/VioCastingUI/Components/Products/RCastingProductCard.swift`
- `Sources/VioCastingUI/Components/Contests/RCastingContestCard.swift`
- `Demo/Viaplay/Viaplay/Components/Products/CastingProductCard.swift`
- `Demo/Viaplay/Viaplay/Components/Contests/CastingContestCard.swift`

### Icon (brandAssets.icon)
Usan `DemoDataManager.shared.brandAsset(for: .icon)`:
- `Sources/VioCastingUI/Components/Match/LineupCard.swift`
- `Sources/VioCastingUI/Components/Timeline/HighlightVideoCard.swift`
- `Sources/VioCastingUI/Components/Statistics/StatPreviewCard.swift`
- `Sources/VioCastingUI/Components/Statistics/FinalStatsCard.swift` (+ `import VioCore`)
- `Sources/VioCastingUI/Components/Social/AdminCommentCard.swift`
- `Demo/Viaplay/...` (versiones equivalentes)
- `Demo/Viaplay/Viaplay/Views/ViaplayHomeView.swift`
- `Demo/Viaplay/Viaplay/Components/HeroSection.swift`

### Logo
Usan `DemoDataManager.shared.brandAsset(for: .logo)`:
- `Demo/Viaplay/Viaplay/Components/HeroSection.swift`
- `Demo/Viaplay/Viaplay/Views/ViaplayHomeView.swift`

### Backgrounds
Usan `DemoDataManager.shared.backgroundImage(for:)`:
- `Sources/VioCastingUI/Components/Promo/ROfferBannerView.swift` – footballField
- `Demo/Viaplay/Viaplay/Components/ViaplayOfferBannerView.swift` – footballField
- `Demo/Viaplay/Viaplay/Components/HeroSection.swift` – mainBackground
- `Demo/Viaplay/Viaplay/Views/SportDetailView.swift` – sportDetail, sportDetailImage

### Labels con nombre de marca
Usan `VioConfiguration.shared.effectiveBrandConfiguration.name`:
- `Sources/VioCastingUI/Models/TimelineEventProtocol.swift` – castingContest, castingProduct
- `Sources/VioCastingUI/Components/Timeline/HighlightVideoCard.swift` – "X Highlights"
- `Sources/VioCastingUI/Components/Statistics/StatPreviewCard.swift` – "X Statistics"
- `Sources/VioCastingUI/Components/Match/LineupCard.swift` – "X Oppstilling"
- `Sources/VioCastingUI/Components/Polls/TimelinePollCard.swift` – "X Avstemning"
- `Sources/VioCastingUI/Components/Polls/PredictionPollCard.swift` – "X Spådom"
- `Sources/VioCastingUI/Components/Polls/ContestCard.swift` – "X Konkurranse"
- `Sources/VioCastingUI/Components/Products/RCastingProductModal.swift` – "Kontakt X for å fullføre kjøpet"

---

## 4. URLs de productos

Usan `DemoDataManager.shared.productUrl(for: productId)`:
- `Sources/VioCastingUI/Components/Products/RCastingProductCard.swift`
- `Sources/VioCastingUI/Components/Products/RCastingProductCardWrapper.swift`
- `Demo/Viaplay/Viaplay/Components/Products/CastingProductCard.swift`
- `Demo/Viaplay/Viaplay/Components/Products/CastingProductCardWrapper.swift`

Configuración en `demo-static-data.json` → `productMappings`.

---

## 5. Debug y prints eliminados

- `Demo/Viaplay/Viaplay/Components/Match/AllContentFeed.swift` – prints de Elkjøp, onAppear debug
- `Sources/VioCastingUI/Components/Polls/PollsListView.swift` – print en onParticipate

---

## 6. Imports necesarios

Componentes que usan `DemoDataManager` o `VioConfiguration` deben tener:
```swift
import VioCore
```

Archivos que lo requieren:
- `FinalStatsCard.swift`
- `StatPreviewCard.swift`
- `LineupCard.swift`
- `HighlightVideoCard.swift`
- `AdminCommentCard.swift`
- `TimelinePollCard.swift`, `PredictionPollCard.swift`, `ContestCard.swift`
- `HeroSection.swift`, `ViaplayHomeView.swift`, `SportDetailView.swift`

---

## 7. Estructura de demo-static-data.json

```json
{
  "brand": {
    "name": "Elkjøp",
    "iconAsset": "avatar_el"
  },
  "assets": {
    "defaultLogo": "default_logo",
    "defaultAvatar": "avatar_el",
    "backgroundImages": {
      "footballField": "football_field_bg",
      "mainBackground": "bg-main",
      "sportDetail": "bg",
      "sportDetailImage": "img1"
    },
    "brandAssets": {
      "icon": "icon ",
      "logo": "logo"
    },
    "contestAssets": {
      "giftCard": "contest_prize_giftcard",
      "championsLeagueTickets": "contest_prize_tickets"
    }
  },
  "productMappings": { ... },
  "timelineEvents": { ... },
  ...
}
```

---

## 8. Checklist para nuevo demo (ej. Skistar)

1. Crear/copiar `demo-static-data.json` con `brand`, `assets`, `productMappings`, etc.
2. Añadir assets al bundle: `avatar_skistar`, icon, logo, backgrounds
3. Ajustar `vio-config.json` si hace falta (theme, colores)
4. No tocar código Swift; todo se configura por JSON

---

## 9. Archivos modificados (resumen)

| Área | Archivos |
|------|----------|
| Config | ModuleConfigurations, ConfigurationLoader, VioConfiguration, demo-static-data.json |
| Casting | RCastingProductCard, RCastingContestCard, RCastingProductCardWrapper, RCastingProductModal |
| Demo Casting | CastingProductCard, CastingContestCard, CastingProductCardWrapper |
| Timeline | TimelineEventProtocol, HighlightVideoCard |
| Match | LineupCard, AllContentFeed |
| Stats | StatPreviewCard, FinalStatsCard |
| Polls | TimelinePollCard, PredictionPollCard, ContestCard, PollsListView |
| Social | AdminCommentCard |
| Promo | ROfferBannerView, ViaplayOfferBannerView |
| Demo Views | HeroSection, ViaplayHomeView, SportDetailView |

---

*Última actualización: sesión de componentización VioSwiftSDK*
