# TAREA: Eliminar todo rastro de Tipio del SDK

**Prioridad:** Alta — antes del miércoles  
**Motivo:** Tipio es un producto separado (livestream). No forma parte del SDK de Vio.  
El SDK solo tiene dos módulos: **Vio** (engagement) y **Commerce** (ex-Reachu, ecommerce).

---

## Archivos a eliminar completamente

```
Sources/VioLiveShow/Network/TipioApiClient.swift     ← borrar
Sources/VioLiveShow/Network/TipioWebSocketClient.swift ← borrar
Sources/VioLiveShow/Models/TipioModels.swift          ← borrar
```

Si `VioLiveShow` module queda vacío o sin sentido tras el borrado, evaluar si el módulo entero se elimina.

---

## Archivos a limpiar (quitar referencias Tipio)

### `Sources/VioCore/Configuration/ModuleConfigurations.swift`
- Eliminar `tipioApiKey`, `tipioBaseUrl` de `LiveShowConfiguration`
- Si `LiveShowConfiguration` era solo para Tipio → eliminar la struct entera

### `Sources/VioCore/Configuration/ConfigurationLoader.swift`
- Eliminar carga de `tipioApiKey` / `tipioBaseUrl`

### `Sources/VioCore/Models/DynamicConfigModels.swift`
- Ya correcto: usa `commerce` no `tipio` ✅
- Verificar que no quede ninguna referencia a `tipio`

### `Sources/VioLiveShow/Managers/LiveChatManager.swift`
- Evaluar si usa TipioApiClient/TipioWebSocketClient → si sí, refactorizar o eliminar

### `Sources/VioLiveShow/Manager/LiveShowManager.swift`
- Evaluar si gestiona livestreams de Tipio → si sí, este manager es Tipio y se puede eliminar

### `Sources/VioCastingUI/` (varios archivos)
- Quitar imports de Tipio, reemplazar por Commerce donde aplique

---

## Regla de naming definitiva

| Módulo | Nombre correcto | NO usar |
|--------|----------------|---------|
| Engagement (polls, contests, chat) | `Vio` | — |
| Ecommerce (ex-Reachu, productos, checkout) | `Commerce` | ~~Tipio~~, ~~Reachu~~ |
| Livestream service externo | fuera de scope | No incluir en el SDK |

---

## Verificación final

Después del cleanup:
```bash
grep -rn "tipio\|Tipio" Sources/ --include="*.swift"
```
Resultado esperado: **0 resultados**
