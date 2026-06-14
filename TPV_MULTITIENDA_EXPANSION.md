#  TPV Universal — Expansión a Peluquerías, Estéticas, Tattoo & Tienda Online

> **Objetivo:** convertir el TPV actual (orientado a bares/restaurantes) en un terminal de punto de venta genérico que sirva a cualquier tipo de negocio con o sin mostrador físico.

---

##  Situación actual

El módulo TPV/Comandas actual cubre:

- Gestión de **mesas** y pedidos en sala
- Carta dividida por **categorías** (bebidas, comidas, vinos…)
- Cobro, tickets e impresión
- Cierre de caja diario

El problema: el modelo de "mesa + comanda" es **específico de hostelería** y no encaja en otros negocios.

---

##  Concepto clave: **Modo TPV por tipo de negocio**

En lugar de crear un TPV diferente para cada sector, se define un **`tipoTpv`** en la configuración de empresa. Según ese valor, la interfaz adapta su vocabulario, flujo y funcionalidades automáticamente.

| `tipoTpv`         | Sector                        | "Mesa" se llama… | Flujo principal                          |
|-------------------|-------------------------------|------------------|------------------------------------------|
| `restaurante`     | Bares / Restaurantes          | Mesa             | Comanda → Cobro → Ticket                 |
| `peluqueria`      | Peluquerías / Barberías       | Silla / Turno    | Servicio → Pago → Factura                |
| `estetica`        | Centros de estética / Spa     | Cabina / Cita    | Tratamiento → Pago → Ticket              |
| `tattoo`          | Estudios de tatuaje / Piercing| Sesión           | Depósito → Sesión → Saldo → Cobro final  |
| `tienda`          | Retail / Tienda online        | Pedido / Carrito | Escaneo/selección → Pago → Albarán       |

---

## ️ Arquitectura de la solución

### 1. Campo `tipoTpv` en Firestore

```
empresas/{empresaId}
  └── configuracion_tpv/
        ├── tipoTpv: "peluqueria"        ← nuevo campo
        ├── etiquetaUnidad: "Silla"      ← cómo se llaman las "mesas"
        ├── etiquetaTicket: "Turno"      ← cómo se llaman las comandas
        └── categorias: [...]            ← categorías de servicios/productos
```

### 2. Adaptación de la UI

- **`TpvRootScreen`** lee `tipoTpv` al iniciar y delega a un **layout específico** o adapta etiquetas.
- Las **categorías de carta** se sustituyen por catálogo de servicios o productos según el sector.
- El **grid de "mesas"** puede representar sillas asignadas, cabinas disponibles o un único botón "Venta directa" para tiendas.

### 3. Nuevas funcionalidades por sector

#### ✂️ Peluquería / Barbería
- Asignación de **turno a barbero/estilista**
- Historial de servicios por cliente (color aplicado, largo, etc.)
- Pack de bonos (10 cortes, abono mensual)
- Escaneo de código QR/NFC para identificar cliente habitual

####  Estética / Spa
- Gestión de **cabinas** y tiempos de ocupación
- Control de **productos consumibles** por tratamiento (cantidad usada)
- Bonos de sesiones y suscripciones mensuales
- Historial de piel / ficha de cliente
- Venta de productos de cosmética en el mismo TPV

####  Tatuaje / Piercing
- Flujo de **depósito previo** (señal para reservar sesión)
- Sesión con duración estimada y cobro final (precio/hora o precio cerrado)
- Ficha artística del cliente (referencias, zonas, fechas de sesiones)
- Control de stock de tintas, agujas y material estéril
- Consentimiento informado digital (firma en pantalla)

####  Tienda / E-commerce
- **Modo escaneo** de código de barras con cámara o lector USB
- Carrito de venta rápida con búsqueda por nombre o referencia
- Sincronización bidireccional con **tienda online** (stock compartido)
- Gestión de **devoluciones** y notas de crédito
- Pedidos online que entran como "comandas pendientes" en el TPV

---

##  Integración con Tienda Online

Para negocios con e-commerce (estéticas con venta de cosméticos, tattoo con merchandise, tiendas):

```
Pedido online (web/app cliente)
        │
        ▼
  Firestore: pedidos/{id} con origen = "tiendaOnline"
        │
        ▼
  TPV → pestaña "Pedidos online pendientes"
        │
        ├── Recoger en tienda  → imprimir albarán
        └── Envío              → generar etiqueta + factura
```

### Stock unificado
- Un único colección `productos/{id}` con campo `stock`
- Las ventas TPV y las ventas online descuentan del mismo stock
- Alertas de stock bajo visibles tanto en TPV como en el panel de administración

---

##  Plan de implementación (fases)

### Fase 1 — Configuración de `tipoTpv` *(bajo coste)*
- [ ] Añadir campo `tipoTpv` a `EmpresaModel`
- [ ] Leer el campo en `TpvRootScreen` y cambiar etiquetas dinámicamente
- [ ] Pantalla de configuración en el perfil de empresa para seleccionar el tipo

### Fase 2 — Layouts especializados *(medio)*
- [ ] Layout **"Sillas/Turnos"** (peluquería/estética): sin mesas, grid de profesionales
- [ ] Layout **"Sesiones"** (tattoo): con campo de depósito y precio estimado
- [ ] Layout **"Catálogo"** (tienda): búsqueda+escaneo, sin concepto de mesa

### Fase 3 — Funcionalidades avanzadas *(alto valor)*
- [ ] Ficha de cliente con historial de servicios
- [ ] Bonos y suscripciones recurrentes
- [ ] Control de stock consumible (estética/tattoo)
- [ ] Consentimiento digital (tattoo)
- [ ] Sincronización con tienda online / pedidos externos

### Fase 4 — Tienda online propia *(expansión)*
- [ ] Portal web de cliente para compra de productos o reserva de citas
- [ ] Pasarela de pago online (Redsys, Stripe)
- [ ] Panel de pedidos online integrado en el TPV

---

##  Impacto en el modelo de precios

| Módulo                              | Precio sugerido  |
|-------------------------------------|-----------------|
| TPV básico (cualquier tipo)         | Incluido en plan Gestión |
| Add-on Tienda Online + stock sync   | +15 €/mes       |
| Add-on Fichas de cliente avanzadas  | +8 €/mes        |
| Add-on Bonos y suscripciones        | +10 €/mes       |
| Add-on Consentimiento digital       | +5 €/mes        |

---

## ✅ Resumen

> Un único TPV, **adaptable por tipo de negocio** mediante configuración, sin crear módulos duplicados. El código base es el mismo; cambian las etiquetas, los layouts y las funcionalidades opcionales que se activan como add-ons.

Esto posiciona a PlaneaG como la **solución integral para cualquier negocio de servicios con o sin mostrador físico**, compitiendo directamente con soluciones verticales como Fresha (peluquerías), Square (retail) o Booksy (estética).
