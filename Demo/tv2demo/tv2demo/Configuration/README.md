# ReachuSDK Configuration for TV2 Demo

## 📁 Ubicación

El archivo de configuración debe estar en el bundle de la app:

```
tv2demo/
└── Configuration/
    └── reachu-config.json  ← Archivo de configuración
```

---

## 🔧 Cómo Usar

### 1. Cargar Configuración al Iniciar la App

En `tv2demoApp.swift`:

```swift
import SwiftUI
import ReachuCore

@main
struct tv2demoApp: App {
    init() {
        // Carga la configuración automáticamente
        // Busca "reachu-config.json" en el bundle de la app
        ConfigurationLoader.loadConfiguration()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
```

### 2. Cargar Configuración Específica (Opcional)

Si tienes múltiples configuraciones:

```swift
// Cargar configuración específica
ConfigurationLoader.loadConfiguration(fileName: "reachu-config-production")

// O con variable de entorno
// REACHU_CONFIG_TYPE=production
ConfigurationLoader.loadConfiguration()
// Buscaría: "reachu-config-production.json"
```

---

## 🎨 Estructura del Archivo JSON

El archivo `reachu-config.json` define:

### **1. API Configuration**
```json
{
  "api": {
    "baseURL": "https://api.reachu.io",
    "apiKey": "your-api-key",
    "environment": "development"
  }
}
```

### **2. Theme (Light/Dark)**
```json
{
  "theme": {
    "name": "TV2 Dark Theme",
    "mode": "dark",
    "darkColors": {
      "primary": "#7B5FFF",
      "background": "#1A1625",
      "surface": "#2B2438"
    }
  }
}
```

### **3. Typography**
```json
{
  "typography": {
    "fontFamily": "System",
    "sizes": {
      "largeTitle": 32,
      "title": 24,
      "body": 16
    }
  }
}
```

### **4. Spacing & Border Radius**
```json
{
  "spacing": {
    "xs": 4,
    "sm": 8,
    "md": 16
  },
  "borderRadius": {
    "small": 8,
    "medium": 12
  }
}
```

### **5. Features (Enable/Disable)**
```json
{
  "features": {
    "enableLiveStreaming": true,
    "enableProductCatalog": true,
    "enableCheckout": true
  }
}
```

---

## 🎯 Modos de Tema

El SDK soporta 3 modos:

| Modo | Descripción |
|------|-------------|
| `"automatic"` | Cambia automáticamente entre light/dark según el sistema |
| `"light"` | Siempre usa tema claro |
| `"dark"` | Siempre usa tema oscuro (recomendado para TV2) |

**Configuración en JSON:**
```json
{
  "theme": {
    "mode": "dark"
  }
}
```

---

## 🔄 Actualizar Configuración en Runtime

Si necesitas cambiar la configuración mientras la app está corriendo:

```swift
import ReachuCore

// Recargar configuración
ConfigurationLoader.loadConfiguration()

// O cargar desde string JSON
let jsonString = """
{
  "theme": {
    "mode": "light"
  }
}
"""
try? ConfigurationLoader.loadFromJSONString(jsonString)
```

---

## 📱 Usar Colores del Tema

Una vez cargada la configuración:

```swift
import SwiftUI
import ReachuDesignSystem

struct MyView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text("Hello")
            .foregroundColor(ReachuColors.adaptive(for: colorScheme).textPrimary)
            .background(ReachuColors.adaptive(for: colorScheme).background)
    }
}
```

O usa el tema estático:

```swift
Text("Static")
    .foregroundColor(ReachuColors.textPrimary)
    .background(ReachuColors.background)
```

---

## 🐛 Debugging

El SDK imprime logs de configuración:

```
🔧 [Config] Loading specific config: reachu-config.json
📄 [Config] Loading configuration from: reachu-config.json
✅ [Config] Configuration loaded successfully: TV2 Demo Configuration
🎨 [Config] Theme mode: dark
🌙 [Config] Dark primary: #7B5FFF
```

Si no encuentra el archivo:

```
⚠️ [Config] No config file found in bundle, using SDK defaults
✅ [Config] Applied default SDK configuration
```

---

## ⚠️ Importante

1. **El archivo debe estar en el bundle de la app**
   - Arrastra `reachu-config.json` al proyecto en Xcode
   - Asegúrate de que esté en el target de la app

2. **El archivo debe ser válido JSON**
   - Usa un validador JSON si tienes errores

3. **Los colores deben ser hexadecimales**
   - Formato: `"#RRGGBB"` o `"#RRGGBBAA"`
   - Ejemplo: `"#7B5FFF"`, `"#1A1625"`

4. **No incluir la extensión `.json` al cargar**
   ```swift
   // ✅ Correcto
   ConfigurationLoader.loadConfiguration(fileName: "reachu-config")
   
   // ❌ Incorrecto
   ConfigurationLoader.loadConfiguration(fileName: "reachu-config.json")
   ```

---

## 🎯 Ejemplo Completo

```swift
// tv2demoApp.swift
import SwiftUI
import ReachuCore
import ReachuDesignSystem

@main
struct tv2demoApp: App {
    init() {
        // 1. Cargar configuración de TV2
        ConfigurationLoader.loadConfiguration()
        
        // 2. Verificar que se cargó
        let config = ReachuConfiguration.shared
        print("📱 App: \(config.brand?.name ?? "Unknown")")
        print("🎨 Theme: \(config.theme.mode)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
```

---

**¿Necesitas ayuda?** Revisa los ejemplos en `/Demo/ReachuDemoApp/`

