# Uso de Broadcast Context y Auto-Discovery en el Demo

## ✅ Integración Completada

El demo ahora está integrado con las nuevas funcionalidades de Broadcast Context y Auto-Discovery del backend.

## Cómo Funciona

### 1. Broadcast Context Automático

Cuando se abre el video player (`ViaplayVideoPlayer`), automáticamente:

1. **Crea un BroadcastContext** desde el modelo `Match` usando `match.toBroadcastContext()`
2. **Genera un broadcastId único** basado en los equipos y competencia
3. **Llama a `setupBroadcastContext()`** que:
   - Si `autoDiscover: true`: Usa `discoverCampaigns()` para encontrar campañas activas para ese broadcast
   - Si `autoDiscover: false`: Solo establece el broadcast context para filtrar componentes existentes

### 2. Configuración

En `reachu-config.json`:

```json
{
  "campaigns": {
    "autoDiscover": false,  // true = auto-discovery, false = legacy mode
    "channelId": null       // Opcional: ID del canal para broadcast context
  },
  "liveShow": {
    "campaignId": 28        // Solo usado si autoDiscover: false
  }
}
```

### 3. Modos de Operación

#### Modo Auto-Discovery (`autoDiscover: true`)

- ✅ Descubre automáticamente todas las campañas activas para el match
- ✅ Soporta múltiples campañas simultáneas
- ✅ No requiere `campaignId` en configuración
- ✅ Usa solo `apiKey` del SDK (no `campaignAdminApiKey`)

**Ejemplo de uso:**
```swift
// En ViaplayVideoPlayer, automáticamente:
let broadcastContext = match.toBroadcastContext()
await campaignManager.discoverCampaigns(broadcastId: broadcastContext.broadcastId)
await campaignManager.setBroadcastContext(broadcastContext)
```

#### Modo Legacy (`autoDiscover: false`)

- ✅ Usa `campaignId` de `liveShow.campaignId`
- ✅ Carga una sola campaña específica
- ✅ Establece broadcast context para filtrar componentes

**Ejemplo de uso:**
```swift
// En ViaplayVideoPlayer, automáticamente:
let broadcastContext = match.toBroadcastContext()
await campaignManager.setBroadcastContext(broadcastContext)
```

## Generación de Broadcast ID

El helper `match.toBroadcastContext()` genera un `broadcastId` único:

- **Barcelona vs PSG**: `"barcelona-psg-2025-01-23"` (hardcoded para coincidir con backend)
- **Otros matches**: `"{homeTeam}-{awayTeam}-{competition}"` (normalizado a slug)

Ejemplo:
- Match: "Manchester City - Real Madrid" en "UEFA Champions League"
- BroadcastId: `"manchester-city-real-madrid-uefa-champions-league"`

## Componentes Filtrados por Broadcast Context

Una vez establecido el broadcast context:

- ✅ Los componentes (`activeComponents`) se filtran automáticamente por `broadcastContext`
- ✅ Solo se muestran componentes que coinciden con el `broadcastId` actual
- ✅ Los componentes sin `broadcastContext` se muestran para todos los broadcasts (comportamiento legacy)

## Próximos Pasos

### Para Habilitar Auto-Discovery

1. Cambiar `autoDiscover: true` en `reachu-config.json`
2. Asegurarse de que `apiKey` esté configurado correctamente
3. El backend debe tener campañas con `broadcastId` correspondiente

### Para Usar Broadcast Context en Otros Lugares

```swift
import ReachuCore

// Crear broadcast context desde Match
let broadcastContext = match.toBroadcastContext(channelId: 1)

// Establecer en CampaignManager
await CampaignManager.shared.setBroadcastContext(broadcastContext)

// O descubrir campañas para un broadcast específico
await CampaignManager.shared.discoverCampaigns(broadcastId: broadcastContext.broadcastId)
```

## Verificación

Para verificar que funciona:

1. Abrir el video player con un match (ej: Barcelona vs PSG)
2. Revisar logs en consola:
   ```
   🎯 [ViaplayVideoPlayer] Setting up broadcast context: barcelona-psg-2025-01-23
   🎯 [ViaplayVideoPlayer] Auto-discovery enabled, discovering campaigns...
   ```
3. Verificar que `CampaignManager.shared.activeCampaigns` contiene las campañas correctas
4. Verificar que `CampaignManager.shared.activeComponents` está filtrado por broadcast context

## Notas

- El broadcast context se establece automáticamente cuando se abre el video player
- Si cambias de broadcast, el broadcast context se actualiza automáticamente
- Los componentes se filtran en tiempo real según el broadcast context actual
- Backward compatible: funciona con campañas sin broadcast context (legacy)
