# Viaplay Demo

**Última actualización**: Enero 23, 2026

Demo funcional que integra el SDK de Vio para mostrar e-commerce, engagement y casting en un contexto de streaming deportivo.

---

## 🚀 Inicio Rápido

```bash
open Demo/Viaplay/Viaplay.xcodeproj
# Cmd+B → Cmd+R → Navegar a Sport → Partido → Ver Live
```

### Simulador iOS

- **Ventana negra “External Display”:** Esa ventana es la salida simulada AirPlay/TV. La UI del demo solo vive en la ventana del **iPhone** (sin ese subtítulo). Ciérrala o **Simulator → I/O → External Display → None**.
- El target Viaplay declara **`UISupportsMultipleScenes = NO`** para una sola escena (menos ventanas fantasma en Xcode recientes).
- Líneas `CoreTelephony` / `commcenter` en consola: **ruido normal** del simulador; no indican fallo de la app.

---

## Arquitectura Actual

El Demo consume componentes del SDK y mantiene solo la capa de presentación específica de Viaplay:

```
Viaplay Demo
├── SDK (VioCastingUI, VioCore, VioUI, VioDesignSystem)
│   ├── LiveMatchView (chat, timeline, polls, stats)
│   ├── CampaignManager, CartManager
│   └── DynamicComponentRenderer
│
└── Demo (layout y navegación)
    ├── ViaplayHomeView, SportView, SportDetailView
    ├── HeroSection, CategoryCard, RentBuyCard, etc.
    └── DemoDataManager (datos estáticos)
```

**Vistas principales:**
- `SportDetailView` → abre `LiveMatchView` (VioCastingUI) al tocar "Ver Live"
- `ViaplayHomeView` → home con categorías y contenido
- `SportView` → lista de partidos

**Componentes del Demo (layout):**
- `HeroSection`, `CategoryButton`, `CategoryCard`, `VisualEffectBlur`
- `RentBuyCard`, `ContinueWatchingCard`, `ViaplayOfferBannerView`
- `CampaignSponsorBadge`, `CachedAsyncImage`

---

## Configuración

### Archivos de configuración

| Archivo | Descripción |
|---------|-------------|
| `Configuration/vio-config.json` | Tema Viaplay, API key, campaign ID |
| `Configuration/demo-static-data.json` | Datos estáticos del demo |
| `Configuration/entertainment-config.json` | Componentes de engagement |
| `Configuration/vio-translations.json` | Traducciones |

### DemoDataManager

Acceso a datos estáticos del demo:

```swift
// Assets
Image(DemoDataManager.shared.defaultLogo)
Image(DemoDataManager.shared.backgroundImage(for: .sportDetail))

// URLs de productos
if let url = DemoDataManager.shared.productUrl(for: "408895") { ... }

// IDs de eventos
let quizEventId = DemoDataManager.shared.contestQuizEventId

// Countdown del banner
let countdown = DemoDataManager.shared.offerBannerCountdown
```

La configuración se carga automáticamente con `ConfigurationLoader.loadConfiguration()`.

**Migración futura:** El `demo-static-data.json` puede reemplazarse por un endpoint de backend o integrarse en `vio-config.json`. Ver `ModuleConfigurations.swift` para la estructura `DemoDataConfiguration`.

---

## Broadcast Context

El video player establece automáticamente el broadcast context desde el match. Ver **[VIO_SWIFT_SDK.md](../../Documentation/VIO_SWIFT_SDK.md)** (sección «Broadcast context y auto-discovery») para auto-discovery y `vio-config.json`.

---

## Timeline (modo demo)

En modo demo, los eventos del timeline se muestran según la posición del slider (no el tiempo real del video). Esto permite explorar todo el partido para pruebas. En producción, los eventos se revelan progresivamente según el tiempo real.

---

## Generar iconos de app

```bash
./generate_app_icons.sh <imagen_1024x1024.png>
```

Genera todos los tamaños necesarios en `Viaplay/Assets.xcassets/AppIcon.appiconset/`.

---

## Documentación adicional

- **[Documentation/Configuration-README.md](Documentation/Configuration-README.md)** – Detalles de `vio-config.json`
- **[VIO_SWIFT_SDK.md](../../Documentation/VIO_SWIFT_SDK.md)** – Flujo del SDK, REST/WebSocket/GraphQL y broadcast context

---

## Troubleshooting

**El proyecto no compila**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
open Demo/Viaplay/Viaplay.xcodeproj
```

**Los componentes de campaña no aparecen**
- Revisar `campaignId` en `vio-config.json`
- Revisar logs de conexión a Tipio en consola
