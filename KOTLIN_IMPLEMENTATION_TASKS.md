# Tareas de Implementación para Kotlin SDK - Cache de Logos de Campaña

## Contexto General

En el SDK de Swift se implementó un sistema completo de cache e invalidación inteligente de logos de campaña. El objetivo es evitar que los usuarios vean un loading cada vez que se muestra un logo, y asegurar que cuando cambia la configuración de una campaña (logo, fechas, estado, matchContext), el cache se invalide automáticamente para reflejar los cambios inmediatamente.

### Problema que Resuelve

1. **Loading innecesario**: Sin cache, cada vez que se muestra un logo hay un pequeño loading
2. **Cambios no reflejados**: Si cambia el logo de una campaña, el cache viejo sigue mostrándose
3. **Falta de robustez**: No había validación de URLs, manejo de errores, ni logging consistente

### Solución Implementada

Sistema de cache en dos niveles (memoria + disco) con invalidación inteligente basada en cambios de configuración de campaña, incluyendo validación robusta y manejo de errores.

---

## Tarea 1: Sistema de Cache de Imágenes con Invalidación Específica

### Contexto
Necesitamos cachear los logos de campaña para evitar loading, pero también invalidar específicamente un logo cuando cambia, sin limpiar todo el cache.

### Implementación Requerida

**Archivo:** Crear `CachedImageLoader.kt` o similar en el módulo de UI/demo

**Funcionalidades:**

1. **Cache en memoria y disco**
   - Usar `LruCache` para memoria (similar a `NSCache` en Swift)
   - Usar `File` API para cache en disco
   - Directorio sugerido: `context.cacheDir/campaignLogos/`

2. **Función para invalidar logo específico**
   ```kotlin
   fun clearCacheForUrl(url: String?) {
       // Validar URL primero (ver Tarea 2)
       // Limpiar de memoria (LruCache)
       // Eliminar archivo del disco si existe
   }
   ```

3. **Función para limpiar todo el cache**
   ```kotlin
   fun clearAllCache() {
       // Limpiar memoria
       // Eliminar directorio completo del disco
   }
   ```

4. **Carga de imágenes con cache**
   - Verificar memoria primero
   - Si no está, verificar disco
   - Si no está, cargar de red y guardar en ambos

### Por qué es importante
Permite invalidar solo el logo que cambió, manteniendo otros logos en cache. Esto es más eficiente que limpiar todo cuando solo cambia un logo.

---

## Tarea 2: Validación de URLs y Manejo de Errores

### Contexto
Necesitamos asegurar que solo procesamos URLs válidas (http/https) y manejar errores gracefully para evitar crashes.

### Implementación Requerida

**Archivo:** Mismo archivo de Tarea 1

**Funcionalidades:**

1. **Función de validación de URL**
   ```kotlin
   private fun isValidImageUrl(url: String?): Boolean {
       if (url.isNullOrBlank()) return false
       return try {
           val uri = Uri.parse(url)
           val scheme = uri.scheme?.lowercase()
           scheme == "http" || scheme == "https"
       } catch (e: Exception) {
           false
       }
   }
   ```

2. **Validar antes de procesar**
   - En `clearCacheForUrl()`: validar antes de limpiar
   - En `loadImage()`: validar antes de cargar
   - Loggear warning si URL es inválida

3. **Manejo de errores**
   - Try-catch en operaciones de disco (leer/escribir archivos)
   - Try-catch en operaciones de red
   - Loggear errores pero no crashear la app

### Por qué es importante
Previene crashes por URLs malformadas o errores de disco/red. Solo acepta http/https para evitar intentar cachear recursos locales o datos inline.

---

## Tarea 3: Detección de Cambios en Configuración de Campaña

### Contexto
Cuando cambia cualquier configuración de la campaña (logo, fechas, estado, matchContext), necesitamos detectarlo y invalidar el cache del logo apropiado.

### Implementación Requerida

**Archivo:** `CampaignManager.kt` o equivalente

**Funcionalidades:**

1. **En `fetchCampaignInfo()` o equivalente**
   ```kotlin
   // Guardar campaña anterior
   val existingCampaign = currentCampaign
   val oldLogoUrl = existingCampaign?.campaignLogo
   
   // Crear nueva campaña con datos del servidor
   val newCampaign = Campaign(...)
   val newLogoUrl = newCampaign.campaignLogo
   
   // Comparar campañas (usar equals() o data class comparison)
   val campaignChanged = existingCampaign != newCampaign
   
   if (campaignChanged) {
       val logoChanged = oldLogoUrl != newLogoUrl
       
       if (logoChanged && oldLogoUrl != null) {
           // Logo cambió - invalidar logo viejo
           postNotification("CampaignLogoChanged", mapOf(
               "oldLogoUrl" to oldLogoUrl,
               "newLogoUrl" to (newLogoUrl ?: "")
           ))
       } else if (!logoChanged && newLogoUrl != null) {
           // Otros campos cambiaron - invalidar logo actual por si cambió branding
           postNotification("CampaignLogoChanged", mapOf(
               "oldLogoUrl" to newLogoUrl,
               "newLogoUrl" to (newLogoUrl ?: "")
           ))
       }
       
       // Pre-cargar nuevo logo si cambió
       if (logoChanged && newLogoUrl != null) {
           preloadLogo(newLogoUrl)
       }
   }
   ```

2. **En `discoverCampaigns()` o equivalente**
   - Mismo comportamiento: comparar campaña vieja vs nueva
   - Detectar cambios y postear notificación si corresponde

3. **En `handleCampaignStarted()` o equivalente**
   - Después de actualizar la campaña, comparar con la anterior
   - Si hay cambios, postear notificación `CampaignLogoChanged`

### Por qué es importante
Asegura que los cambios en la configuración de campaña se reflejen inmediatamente sin necesidad de reiniciar la app. Detecta específicamente qué cambió para invalidar solo lo necesario.

---

## Tarea 4: Sistema de Notificaciones para Invalidación

### Contexto
Necesitamos un mecanismo para comunicar cambios de logo desde el SDK hacia el código del demo/app que maneja el cache de imágenes.

### Implementación Requerida

**Archivo:** `CampaignManager.kt` o archivo de notificaciones

**Funcionalidades:**

1. **Crear constante de notificación**
   ```kotlin
   companion object {
       const val NOTIFICATION_CAMPAIGN_LOGO_CHANGED = "ReachuCampaignLogoChanged"
   }
   ```

2. **Función helper para postear notificación**
   ```kotlin
   private fun postNotification(name: String, userInfo: Map<String, String>) {
       // Usar EventBus, BroadcastReceiver, o sistema de notificaciones de Android
       // Enviar userInfo con oldLogoUrl y newLogoUrl
   }
   ```

3. **Postear notificación en los lugares correctos**
   - Cuando cambia el logo en `fetchCampaignInfo()`
   - Cuando cambia el logo en `discoverCampaigns()`
   - Cuando cambia configuración en `handleCampaignStarted()`
   - Cuando termina campaña en `handleCampaignEnded()`

### Por qué es importante
Separa responsabilidades: el SDK detecta cambios y notifica, el código del demo/app maneja el cache de imágenes. Esto permite que el SDK sea independiente del sistema de cache específico usado en el demo.

---

## Tarea 5: Listener para Invalidación de Cache en el Demo

### Contexto
El código del demo/app necesita escuchar las notificaciones del SDK y limpiar el cache de imágenes cuando corresponda.

### Implementación Requerida

**Archivo:** Crear `CacheHelper.kt` en el módulo del demo

**Funcionalidades:**

1. **Flag para prevenir listeners duplicados**
   ```kotlin
   private var listenersSetup = false
   ```

2. **Función para configurar listeners**
   ```kotlin
   fun setupCacheClearingListener() {
       if (listenersSetup) {
           Log.d("CacheHelper", "Listeners already setup, skipping")
           return
       }
       listenersSetup = true
       
       // Registrar listener para "ReachuCacheCleared" (limpieza completa)
       // Registrar listener para "ReachuCampaignLogoChanged" (limpieza específica)
   }
   ```

3. **Handler para limpieza específica de logo**
   ```kotlin
   private fun handleLogoChanged(userInfo: Map<String, String>) {
       val oldLogoUrl = userInfo["oldLogoUrl"]
       val newLogoUrl = userInfo["newLogoUrl"]
       
       // Validar URLs (ver Tarea 2)
       if (!oldLogoUrl.isNullOrBlank() && isValidImageUrl(oldLogoUrl)) {
           CachedImageLoader.clearCacheForUrl(oldLogoUrl)
           Log.d("CacheHelper", "Cleared cache for logo: $oldLogoUrl")
       }
       
       // Pre-cargar nuevo logo con timeout
       if (!newLogoUrl.isNullOrBlank() && isValidImageUrl(newLogoUrl)) {
           preloadLogoWithTimeout(newLogoUrl, timeoutSeconds = 10)
       }
   }
   ```

4. **Pre-carga con timeout**
   ```kotlin
   private fun preloadLogoWithTimeout(url: String, timeoutSeconds: Int) {
       // Usar Coroutine con timeout
       // Si timeout, loggear warning pero no fallar
   }
   ```

### Por qué es importante
Centraliza la lógica de limpieza de cache en el demo. Previene listeners duplicados y maneja timeouts para evitar bloqueos.

---

## Tarea 6: Preservar Logo en Estados de Campaña

### Contexto
Cuando una campaña se pausa, reanuda, o termina, necesitamos preservar o limpiar el logo apropiadamente.

### Implementación Requerida

**Archivo:** `CampaignManager.kt`

**Funcionalidades:**

1. **En `handleCampaignPaused()`**
   ```kotlin
   // Asegurar que se preserve campaignLogo al crear nueva campaña
   currentCampaign = Campaign(
       id = campaign.id,
       startDate = campaign.startDate,
       endDate = campaign.endDate,
       isPaused = true,
       campaignLogo = campaign.campaignLogo  // IMPORTANTE: Preservar logo
   )
   ```

2. **En `handleCampaignEnded()`**
   ```kotlin
   // Obtener logo antes de actualizar campaña
   val logoToClear = currentCampaign?.campaignLogo
   
   // Actualizar campaña...
   
   // Limpiar logo del cache cuando termina
   if (logoToClear != null) {
       postNotification("CampaignLogoChanged", mapOf(
           "oldLogoUrl" to logoToClear,
           "newLogoUrl" to ""
       ))
   }
   ```

3. **En `handleCampaignResumed()`**
   - Ya debería preservar el logo (similar a paused)
   - Verificar que funcione correctamente

### Por qué es importante
Evita perder el logo cuando la campaña cambia de estado. Cuando termina, limpia el logo del cache para liberar espacio.

---

## Tarea 7: Logging Consistente

### Contexto
Necesitamos logging consistente en todo el sistema para facilitar debugging y monitoreo.

### Implementación Requerida

**Archivos:** Todos los archivos modificados

**Funcionalidades:**

1. **Usar sistema de logging del SDK**
   - Si existe `ReachuLogger` o equivalente, usarlo
   - Si no, usar `Log` de Android con tags consistentes

2. **Niveles de logging apropiados**
   - `Log.d()` / `ReachuLogger.debug()`: Para información de debugging
   - `Log.i()` / `ReachuLogger.info()`: Para eventos importantes
   - `Log.w()` / `ReachuLogger.warning()`: Para advertencias (URLs inválidas, timeouts)
   - `Log.e()` / `ReachuLogger.error()`: Para errores (fallos de red, disco)

3. **Tags consistentes**
   - "ImageLoader" para operaciones de cache de imágenes
   - "CacheHelper" para manejo de listeners y limpieza
   - "CampaignManager" para detección de cambios

### Por qué es importante
Facilita debugging en producción y desarrollo. Permite identificar problemas rápidamente con logs estructurados.

---

## Tarea 8: Componente UI para Mostrar Logo con Cache

### Contexto
Necesitamos un componente reutilizable que muestre el logo de campaña usando el sistema de cache.

### Implementación Requerida

**Archivo:** Crear componente UI (ej: `CampaignLogoView.kt`)

**Funcionalidades:**

1. **Componente que use CachedImageLoader**
   ```kotlin
   @Composable
   fun CampaignLogoView(
       logoUrl: String?,
       modifier: Modifier = Modifier,
       contentDescription: String? = null
   ) {
       // Obtener logoUrl de CampaignManager
       // Usar CachedImageLoader para cargar imagen
       // Mostrar placeholder mientras carga (solo si no está en cache)
       // Mostrar fallback si falla la carga
   }
   ```

2. **Integración con CampaignManager**
   - Observar `currentCampaign?.campaignLogo`
   - Actualizar automáticamente cuando cambia

3. **Placeholder inteligente**
   - Solo mostrar loading si imagen no está en cache
   - Si está en cache, mostrar inmediatamente sin loading

### Por qué es importante
Proporciona una API simple y consistente para mostrar logos en toda la app. Maneja automáticamente el cache y los estados de carga.

---

## Resumen de Archivos a Crear/Modificar

### Nuevos Archivos
1. `CachedImageLoader.kt` - Sistema de cache de imágenes
2. `CacheHelper.kt` - Helper para listeners y limpieza (en demo)
3. `CampaignLogoView.kt` - Componente UI (opcional pero recomendado)

### Archivos a Modificar
1. `CampaignManager.kt` - Detección de cambios y notificaciones
2. Archivos de notificaciones/eventos - Sistema de notificaciones

---

## Flujo Completo

```
1. CampaignManager detecta cambio en configuración
   ↓
2. Compara campaña vieja vs nueva
   ↓
3. Si logo cambió → Postea notificación con oldLogoUrl
   Si otros campos cambiaron → Postea notificación con logo actual
   ↓
4. CacheHelper escucha notificación
   ↓
5. CachedImageLoader.clearCacheForUrl(oldLogoUrl)
   ↓
6. Logo viejo eliminado de memoria y disco
   ↓
7. Pre-carga nuevo logo con timeout
   ↓
8. UI muestra nuevo logo inmediatamente (desde cache)
```

---

## Casos de Prueba Sugeridos

1. **Cambio de logo en misma campaña**
   - Cambiar logo en backend
   - Verificar que logo viejo se invalida
   - Verificar que nuevo logo se carga y muestra

2. **Cambio de fechas/estado**
   - Cambiar fechas de campaña
   - Verificar que logo actual se invalida (por si cambió branding)

3. **Finalización de campaña**
   - Terminar campaña
   - Verificar que logo se limpia del cache

4. **URL inválida**
   - Intentar usar URL con esquema no soportado
   - Verificar que se rechaza con logging apropiado

5. **Timeout de red**
   - Simular red lenta
   - Verificar que timeout funciona y no bloquea

6. **Listeners duplicados**
   - Llamar setupCacheClearingListener() múltiples veces
   - Verificar que solo se registra una vez

---

## Notas Adicionales

- El sistema debe ser backward compatible: si no hay cache, debe funcionar igual que antes
- El cache debe persistir entre sesiones de la app (disco)
- Considerar límite de tamaño para el cache en disco
- Los logos deben tener TTL o invalidación basada en cambios de configuración (ya implementado)
