# Vio.live — Contexto general del equipo

> Última actualización del contenido: 2026-03-27. Integrado en el repo para Cursor.

## Qué estamos construyendo

Vio es un sistema de engagement para live streaming deportivo: shopping interactivo y placements en eventos en vivo.

Clientes objetivo:

- **Viaplay** — Noruega (decisión escandinava pendiente)
- **TV2** — demo realizada, interés confirmado

**El SDK es el producto. Un bug = no deal.**

---

## Nomenclatura — CRÍTICO

| Nombre       | Significado                                              |
| ------------ | -------------------------------------------------------- |
| **Vio.live** | Producto actual — usar siempre                           |
| **Reachu**   | Legacy — evitar en código nuevo                         |
| **Tipio**    | Producto separado — no es Vio                             |

---

## Arquitectura general

```
iOS/tvOS (VioSwiftSDK)  ←→  socket-server (Azure AKS)  ←→  Neon PostgreSQL
Android (VioKotlinSDK)  ←→  graph-ql-dev.vio.live (GraphQL / commerce)
```

## URLs (dev)

| Servicio          | URL                                      |
| ----------------- | ---------------------------------------- |
| Backend API       | `https://api-dev.vio.live`               |
| WebSocket campaña | `wss://api-dev.vio.live/ws/{campaignId}` |
| Commerce GraphQL  | `https://graph-ql-dev.vio.live/graphql`  |
| Legacy            | `https://socket-qa.reachu.io`            |

## Claves y demos

**No pegar API keys reales en este archivo.** Usa los JSON de demo bajo `Demo/*/vio-config.json` o secretos locales. Para tabla de clientes/campañas de prueba, ver también [CONTEXT_IOS.md](CONTEXT_IOS.md) (sin valores sensibles en repo público).

---

## Decisiones de arquitectura (permanentes)

- Engagement impulsado por **WebSocket** respecto al backend Vio.
- Colores y assets de marca vienen del **backend**.
- Un broadcast activo por sesión de usuario (modelo mental del SDK).
- `integrations.commerce` en API; **`externalId`** en broadcasts mapea al `contentId` del partner.
- Notificaciones locales vía eventos WS (enfoque agnóstico; sin acoplarse a un proveedor concreto en este doc).

---

## Reglas de trabajo (equipo)

1. Desarrollar en branch → probar → merge.
2. Durante discusión técnica: no implementar hasta orden explícita si así se acuerda en el equipo.
3. Ante duda: alinear en canal de desarrollo antes de cambios grandes.

---

## Contexto en este repositorio (Swift)

| Documento                           | Uso                                              |
| ----------------------------------- | ------------------------------------------------ |
| [CONTEXT_IOS.md](CONTEXT_IOS.md)    | SDK Swift: managers, flujos, verificación código |
| [CODEBASE_INDEX.md](CODEBASE_INDEX.md) | Mapa rápido de targets y rutas                 |
| [VIO_PLATFORM_CURSOR_CONTEXT.md](VIO_PLATFORM_CURSOR_CONTEXT.md) | Backend, schema, OpenAPI, endpoints (socket-server) |

---

## Estado referencial (Mar 2026)

Actualizar cuando cambie la situación real del producto. Para el estado **del código Swift** en este commit, preferir la sección “Verificación contra código” en [CONTEXT_IOS.md](CONTEXT_IOS.md).
