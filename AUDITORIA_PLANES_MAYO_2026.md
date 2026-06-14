#  AUDITORÍA DE PLANES — FLUIX CRM · Mayo 2026

> Documento de referencia para diseñar los planes de suscripción con módulo TPV/Comandas.  
> Preparado por: GitHub Copilot · Fecha: 11/05/2026

---

## ️ ARQUITECTURA ACTUAL DE MÓDULOS

### Plan Base (310 €/año)
Módulos incluidos por defecto en toda suscripción:
| Módulo | Descripci��n |
|--------|-------------|
| `dashboard` | Resumen del negocio con widgets personalizables |
| `reservas` | Gestión de citas y reservas de clientes |
| `clientes` | CRM, historial y base de datos de clientes |
| `servicios` | Catálogo de servicios, precios y categorías |
| `empleados` | Gestión de equipo y roles de acceso |
| `valoraciones` | Reseñas de Google y gestión de respuestas |
| `estadisticas` | Métricas, KPIs y análisis del negocio |
| `contenido_web` | Gestión del contenido dinámico de la web |

---

###  Pack Gestión (370 €/año)
Módulos adicionales al Plan Base:
| Módulo | Descripción |
|--------|-------------|
| `facturacion` | Facturas con IVA, series, exportación PDF, modelos fiscales |
| `vacaciones` | Control de vacaciones, ausencias y calendario del equipo |
| `tpv` | **Terminal de comandas completo** (mesas, pedidos, cobros, caja) |
| `fichaje` | Control horario con geolocalización para el equipo |

---

###  Pack Fiscal AI (430 €/año)
| Módulo | Descripción |
|--------|-------------|
| `fiscal` | Automatización fiscal con IA (modelos 303, 130, IRPF, IVA) |
| `contabilidad` | Contabilidad básica integrada |
| `verifactu` | Presentación directa a la AEAT (Verifactu) |

---

###  Pack Tienda Online (490 €/año)
| Módulo | Descripción |
|--------|-------------|
| `pedidos` | Catálogo de productos, pedidos online, stock y avisos |

---

###  Add-ons Independientes
| Add-on | Precio | Módulo |
|--------|--------|--------|
| `whatsapp` | 50 €/año | Gestión de pedidos y comunicación por WhatsApp Business |
| `tareas` | Por definir | Productividad y asignación de tareas por usuario |
| `nominas` | 310 €/año | Nóminas automáticas, IRPF, Seguridad Social |
| **`comandas`** ⭐ | **Por definir** | TPV/Comandas para bares y restaurantes |

---

##  MÓDULO COMANDAS (TPV BARES) — Análisis detallado

### ¿Qué hace?
El módulo `comandas` activa el **TPV (Terminal Punto de Venta)** orientado a negocios de hostelería:

- **Gestión de carta**: categorías configurables (bebidas, cañas, copas, platos, vinos, postres…)
- **Mesas**: selección de mesa, apertura y cierre de cuentas
- **Comandas en sala**: el camarero registra pedidos desde el móvil/tablet
- **Cobros**: efectivo, tarjeta, varios métodos de pago
- **Tickets**: impresión o envío por correo/WhatsApp
- **Cierre de caja**: resumen del día, ingresos por categoría
- **Gestión de stock opcional**: aviso cuando un producto se agota

### Cómo activarlo desde Firebase
Para activar el módulo comandas en una empresa sin que tenga el Pack Gestión completo, añadir en Firestore:

```
empresas/{empresaId}/suscripcion/actual
  ├─ addons_activos: ["comandas"]   ← activa el TPV
  ├─ estado: "ACTIVA"
  └─ fecha_fin: <timestamp>
```

O en formato legacy (modulos_activos):
```
  └─ modulos_activos: ["comandas"]   ← también funciona
```

---

##  PROPUESTA DE PLANES CON MÓDULO COMANDAS

El usuario quiere dos planes basados en el módulo TPV/Comandas.  
A continuación se presentan dos opciones de diseño:

---

###  OPCIÓN A — "Plan Bar Esencial" vs "Plan Bar Pro"

#### Plan Bar Esencial (~29 €/mes · 349 €/año)
**Para**: bares y restaurantes que solo necesitan gestionar comandas.
- ✅ `reservas` — para gestionar reservas de mesas
- ✅ `clientes` — base de datos básica de clientes
- ✅ `valoraciones` — ver y responder reseñas de Google
- ✅ `comandas` / `tpv` — **terminal de comandas completo**
- ✅ `estadisticas` — métricas básicas de ventas

>  Sin facturación, sin fichaje, sin fiscal. Solo lo que necesita un bar.

#### Plan Bar Pro (~59 €/mes · 709 €/año)
**Para**: bares/restaurantes que necesitan gestión completa + comandas.
- ✅ Todo el Plan Bar Esencial
- ✅ `facturacion` — facturas a empresas y particulares
- ✅ `fichaje` — control horario del personal
- ✅ `vacaciones` — gestión de ausencias del equipo
- ✅ `whatsapp` — pedidos y reservas por WhatsApp
- ✅ `estadisticas` avanzadas con KPIs de caja

---

###  OPCIÓN B — "Plan Hostelería Básico" vs "Plan Hostelería Completo"

#### Plan Hostelería Básico (~25 €/mes · 299 €/año)
- ✅ Plan Base + módulo `comandas`
- ❌ Sin facturación ni fiscal
- ❌ Sin fichaje

**Composición**: Plan Base (310€) + addon Comandas (≈50€ descuento intro)  
→ Precio orientativo: **299-349 €/año**

#### Plan Hostelería Completo (~49 €/mes · 589 €/año)
- ✅ Plan Base + Pack Gestión (incluye comandas via `tpv`)
- ✅ Facturación, fichaje, vacaciones
- ❌ Sin fiscal/contabilidad

**Composición**: Plan Base (310€) + Pack Gestión (370€) − descuento combo hostelería (~91€)  
→ Precio orientativo: **589-649 €/año**

---

##  COMPARATIVA DE PRECIOS ACTUALES VS COMPETENCIA

| Solución | Precio mensual | Módulos hostelería |
|---------|----------------|-------------------|
| **Fluix CRM Plan Bar Esencial** | ~29 €/mes | Comandas + Reservas + Valoraciones |
| **Fluix CRM Plan Bar Pro** | ~59 €/mes | Comandas + Gestión completa |
| Booksy | ~30-80 €/mes | Solo reservas, sin TPV |
| Glop TPV | 40-70 €/mes | Solo TPV, sin CRM |
| Agora POS | 60-120 €/mes | TPV avanzado, sin gestión de reseñas |
| Cover Manager | 50-90 €/mes | Solo reservas restaurante |

**Conclusión**: Fluix CRM ofrece una propuesta competitiva al combinar TPV + CRM + reseñas en un único SaaS.

---

##  RECOMENDACIONES TÉCNICAS

1. **Activación desde Firebase**: Añadir `addons_activos: ["comandas"]` en Firestore activa el módulo TPV inmediatamente sin redeploy.
2. **Compatibilidad**: El módulo `comandas` es alias del módulo `tpv` ya implementado. Toda la lógica de TPV ya está en `ModuloTpvScreen`.
3. **Verificación**: Si una empresa tiene `packs_activos: ["gestion"]` ya tiene acceso al TPV automáticamente.
4. **Plan futuro**: Cuando se definan los planes finales, crear `packHosteleria` en `planes_config.dart` con `modulosAdicionales: ['tpv', 'reservas']` y precio ~200€/año.

---

##  ESTRUCTURA RECOMENDADA EN FIRESTORE PARA ACTIVAR TPV

### Empresa con sólo el módulo comandas (sin Pack Gestión):
```json
{
  "plan_base": "basico",
  "packs_activos": [],
  "addons_activos": ["comandas"],
  "estado": "ACTIVA",
  "fecha_inicio": "2026-05-11T00:00:00Z",
  "fecha_fin": "2027-05-11T00:00:00Z"
}
```

### Empresa con Pack Gestión completo (TPV ya incluido):
```json
{
  "plan_base": "basico",
  "packs_activos": ["gestion"],
  "addons_activos": [],
  "estado": "ACTIVA",
  "fecha_fin": "2027-05-11T00:00:00Z"
}
```

---

*Última actualización: 11 de mayo de 2026 — Fluix CRM v2.x*
