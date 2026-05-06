# VioSwiftSDK.xcworkspace

Abre **`VioSwiftSDK.xcworkspace`** (no un `.xcodeproj` suelto) para trabajar con todas las demos consumiendo el SDK local en una sola sesión de Xcode. Si abres dos `.xcodeproj` distintos en paralelo, Xcode entra en conflicto resolviendo el mismo `XCLocalSwiftPackageReference` y empieza a fallar la build.

En el navegador deberías ver **al mismo nivel**: los dos *Package* (VioSwiftSDK + VioTVSDK) y **cuatro proyectos** (Vg, Viaplay, tv2demo, tv2demo-appletv), sin depender de un grupo plegado.

| Referencia | Contenido |
| ---------- | --------- |
| `Package.swift` (raíz) | **VioSwiftSDK** (iOS package: VioCore, VioUI, VioDesignSystem, VioComplete, …) |
| `../Documents/GitHub/InteractiveAds-vio/Package.swift` | **VioTVSDK** (`VioTV`, tvOS) |
| `Demo/Vg/Vg.xcodeproj` | Demo iOS VG |
| `Demo/Viaplay/Viaplay.xcodeproj` | Demo iOS Viaplay |
| `Demo/tv2demo/tv2demo.xcodeproj` | Demo iOS TV2 |
| `Demo/tv2demo-appletv/tv2demo-appletv.xcodeproj` | Demo **tvOS** (vía enlace simbólico) |

## Enlace `Demo/tv2demo-appletv`

Para que el proyecto Apple TV aparezca **dentro de `Demo/`** en el repo y en Xcode, existe un **symlink**:

`Demo/tv2demo-appletv` → `../../Documents/GitHub/InteractiveAds-vio/Demo/tv2demo-appletv`

Solo funciona si el repo está en el mismo sitio que tu carpeta `Documents` habitual (p. ej. `~/VioSwiftSDK` y `~/Documents/GitHub/InteractiveAds-vio`). Si clonas en otra ruta, recrea el enlace:

```bash
cd /path/to/VioSwiftSDK
rm -f Demo/tv2demo-appletv
ln -s "../../Documents/GitHub/InteractiveAds-vio/Demo/tv2demo-appletv" Demo/tv2demo-appletv
```

(Ajusta la rama derecha si `InteractiveAds-vio` está en otro sitio.)

## Requisito de rutas (VioTV package)

- `InteractiveAds-vio` en `~/Documents/GitHub/InteractiveAds-vio`.

Si mueves uno de los repos, vuelve a enlazar el proyecto o el `Package.swift` en el workspace (clic derecho → Add Files, o edita `contents.xcworkspacedata`).

## Correr el demo Apple TV

1. Cierra y vuelve a abrir **`VioSwiftSDK.xcworkspace`** tras añadir esquemas nuevos.
2. En el selector de esquema elige **`TV2 Demo (Apple TV)`** (esquema compartido del workspace) o **`tv2demo-appletv`** (viene del `.xcodeproj` de InteractiveAds-vio).
3. **Destino:** abre el menú junto al esquema (no uses iPhone). **Product → Destination** → un **Apple TV** o **Apple TV 4K** Simulator. Las apps tvOS no se ejecutan en simulador iPhone; si el destino es iPhone, el Run puede fallar o no ofrecer el destino correcto.
4. Si no ves simuladores Apple TV: **Xcode → Settings → Platforms** e instala **tvOS**.
5. El target referencia el SPM local `../..` respecto a `Demo/tv2demo-appletv` (raíz de InteractiveAds-vio). **File → Packages → Reset Package Caches** si falla la resolución.

### No aparece el esquema / Apple TV

- **Product → Scheme → Manage Schemes…** y marca **Show** para `tv2demo-appletv` y para **`TV2 Demo (Apple TV)`**.
- Quita el filtro del desplegable de esquemas (campo de búsqueda vacío).

## Si una demo iOS falla a resolver el SDK

Síntoma típico: abres VG, Viaplay o tv2demo en Xcode aislado y el indexer / build error "missing package product". Es porque **dos sesiones de Xcode no pueden consumir simultáneamente la misma `XCLocalSwiftPackageReference`** — chocan en `DerivedData`/SourceControl cache.

Solución:
1. Cierra todas las ventanas Xcode (`Cmd+Q`).
2. Abre **solo `VioSwiftSDK.xcworkspace`**.
3. En el selector de esquema elige la demo (Vg, Viaplay, tv2demo, tv2demo-appletv).
4. Si todavía falla: **File → Packages → Reset Package Caches**, y luego **Product → Clean Build Folder** (`Cmd+Shift+K`).
