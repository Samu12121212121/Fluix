#  Guía TPV Multi-Sector — PlaneaG

> Versión 1.0 · Mayo 2026  
> El sistema tiene **3 modos de TPV** que se activan según el tipo de negocio configurado en cada empresa. Un único acceso desde el dashboard, tres experiencias distintas.

---

##  Índice

1. [Cómo cambiar el tipo de TPV de una empresa](#1-cómo-cambiar-el-tipo-de-tpv-de-una-empresa)
2. [TPV Bar / Restaurante](#2-tpv-bar--restaurante-)
3. [TPV Peluquería / Estética](#3-tpv-peluquería--estética-)
4. [TPV Tienda / Retail](#4-tpv-tienda--retail-)
5. [Lo que comparten los 3 TPV](#5-lo-que-comparten-los-3-tpv)
6. [Estructura Firestore por tipo](#6-estructura-firestore-por-tipo)

---

## 1. Cómo cambiar el tipo de TPV de una empresa

### Desde la app (admin)

1. Abre el **Dashboard** de la empresa.
2. Ve a **Configuración → Configuración Facturación TPV** (icono ⚙️ en el menú del TPV o desde el perfil de empresa).
3. En la sección **"TIPO DE NEGOCIO (TPV)"** elige una de las tres opciones:

| Opción | Cuándo usarla |
|---|---|
|  **Bar / Restaurante** | Negocios con mesas, pedidos en sala, carta |
| ✂️ **Peluquería / Estética** | Centros con sillones o cabinas, servicios por cliente |
| ️ **Tienda / Retail** | Tiendas físicas, venta directa, control de stock |

4. Pulsa **"GUARDAR CONFIGURACIÓN"**.
5. La próxima vez que alguien acceda al TPV desde el dashboard, se abrirá el modo correcto automáticamente.

### Desde Firestore (administrador de plataforma)

```
empresas/{empresaId}
  └── tipo_tpv: "bar" | "peluqueria_estetica" | "tienda"
```

- Si el campo no existe o tiene un valor desconocido → carga el TPV de **bar por defecto** (retrocompatibilidad total).

---

## 2. TPV Bar / Restaurante 

**Color:** Azul (color primario del tema)  
**Acceso:** `TpvRootScreen`  
**Colecciones Firestore:** `mesas`, `comandas`, `pedidos`, `catalogo`

### Flujo principal

```
Plano de mesas → toca mesa → catálogo de carta → añade productos → Cobrar → ticket impreso
                                                                          → cierre de caja
```

### Funciones disponibles

#### ️ Plano de mesas
- **Ver todas las mesas** organizadas en un grid por zonas (Salón, Terraza, etc.)
- **Filtrar por zona** con chips horizontales scrollables
- **Badges en tiempo real:** cuántas mesas están libres , ocupadas  o reservadas 
- **Tarjeta de mesa** muestra: número, zona, estado y — si está ocupada — el importe acumulado en tiempo real desde Firestore
- **Añadir nueva mesa** (solo admin): botón `+` abre un diálogo con número, nombre, zona y capacidad
- **Resumen del turno** en el panel lateral derecho: ventas del día en € (stream en tiempo real), número de tickets y mesas servidas

####  Comanda de mesa
- Al tocar una mesa libre o ocupada se abre la vista **Catálogo + Comanda** (60/40)
- El header muestra el **nombre real de la mesa** (leído en tiempo real de Firestore)
- **Añadir productos**: tap en tarjeta de producto → si tiene variantes (talla, punto de cocción, etc.) abre un bottom sheet de selección
- **Ajustar cantidad** con botones `+` / `−` por línea; bajar a 0 elimina la línea
- **Subtotal, IVA y TOTAL** calculados automáticamente
- La comanda se **sincroniza en Firestore** cada vez que cambia (así si el camarero cambia de dispositivo no pierde la comanda)

####  Cobrar
1. Botón "Cobrar X €" → diálogo de método de pago
2. Elige: **Efectivo** (calcula cambio automáticamente), **Tarjeta** o **Mixto** (reparte entre ambos)
3. Al confirmar:
   - Genera número de ticket atómico (contador en Firestore, nunca se repite)
   - Crea el pedido en `pedidos/{empresaId}/{id}`
   - Si la facturación automática está activada → genera factura
   - Libera la mesa (estado → libre)
   - Imprime ticket por Bluetooth si hay impresora configurada

####  Transferir comanda
- Botón `⇄` en el header de la comanda activa
- Lista las mesas **libres** disponibles
- Mueve la comanda a la mesa seleccionada: batch update en Firestore (mesa origen libera, mesa destino ocupa)
- El TPV vuelve al plano automáticamente

#### ✂️ Dividir comanda
- Botón `⊢` en el header (activo cuando hay más de 1 línea)
- Checkboxes para seleccionar qué artículos se separan
- Los artículos seleccionados crean una **nueva comanda** sin mesa (disponible en Caja rápida)
- Los artículos que quedan se mantienen en la misma mesa

#### ⚡ Caja rápida
- Accesible desde el NavigationRail o desde el botón del panel de mesas
- Venta directa sin asignar mesa (para llevar, mostrador, etc.)
- Header "Venta directa" con icono ⚡

####  Cierre de caja
- Accesible desde el icono de resumen en la parte inferior del NavigationRail
- **Métricas del día:** total ventas, número de tickets, ticket medio
- **Desglose por método de pago:** efectivo vs. tarjeta con porcentaje visual
- **Comparativa:** hoy vs. ayer
- **Top 3 productos** más vendidos del día
- **Desglose IVA al 10%** (hostelería) con base imponible y cuota
- **Botón Z-Report PDF:** genera y abre un PDF imprimible con todo el resumen
- **Botón "Cerrar caja":** registra el cierre en `cierres_caja/{empresaId}/{id}` con confirmación previa

---

## 3. TPV Peluquería / Estética ✂️

**Color:** Morado `#6A1B9A`  
**Acceso:** `TpvPeluqueriaScreen`  
**Colecciones Firestore:** `sillones`, `comandas`, `pedidos`, `catalogo`

### Flujo principal

```
Plano de sillones → toca sillón → catálogo de servicios → añade servicios → Cobrar → ticket impreso
                                                                                   → cierre de caja
```

### Funciones disponibles

####  Plano de sillones
- **Grid de sillones** con el mismo sistema que las mesas pero con vocabulario de peluquería
- **Tarjeta de sillón** muestra:
  - Icono de silla 
  - Nombre del sillón
  - Estado (Libre / Ocupado) con colores verde / morado
  - **Nombre del profesional** asignado (si está ocupado)
  - Importe acumulado en el sillón
- **Añadir sillón** (solo admin): número y nombre
- **Resumen del turno** en panel lateral: ventas del día en stream tiempo real

#### ✂️ Cita en sillón
- Al tocar un sillón se abre la vista **Catálogo de servicios + Ticket** (60/40)
- El header muestra el nombre real del sillón (desde Firestore)
- Los servicios están en la misma colección `catalogo` — se configuran igual que los productos pero con nombre de servicios (Corte, Tinte, Mechas, Manicura, etc.)
- Las variantes funcionan igual: por ejemplo "Tinte — Corto / Medio / Largo" con precios distintos
- Al iniciar la cita se crea una comanda en Firestore con `mesa_id = sillonId`
- El sillón pasa a estado "ocupado" en Firestore

####  Cobrar
- Mismo flujo que el bar pero con dialog en **morado**
- Solo Efectivo o Tarjeta (sin mixto en esta versión)
- Al cobrar:
  - Libera el sillón (estado → libre)
  - Marca la comanda como cobrada
  - Crea el pedido en `pedidos`
  - Imprime ticket si hay impresora BT

#### ⚡ Caja directa
- Desde el NavigationRail, botón "Caja"
- Venta sin asignar sillón (productos de mostrador, propinas, venta de champús, etc.)

####  Cierre de caja
- Mismo sistema que el bar pero con acento morado
- IVA al **21%** (servicios de peluquería son tipo general)
- Z-Report PDF
- Top servicios más realizados

---

## 4. TPV Tienda / Retail ️

**Color:** Verde oscuro `#1B5E20`  
**Acceso:** `TpvTiendaScreen`  
**Colecciones Firestore:** `catalogo` (con campo `stock`), `pedidos`

### Flujo principal

```
Catálogo → busca / escanea producto → añade al ticket → Cobrar → (descuenta stock) → ticket impreso
```

> **Sin plano de mesas ni sillones.** Se abre directamente en modo venta.

### Funciones disponibles

####  Catálogo con stock
- Layout 60/40 directo (sin navegación lateral)
- **Grid de productos** con filtro por categoría y buscador
- **Badge de stock** en cada tarjeta:
  -  Verde → stock por encima del mínimo
  -  Ámbar + ⚠️ → stock bajo (igual o menor que `stock_minimo`)
  - Tarjeta desaturada + "SIN STOCK" → stock = 0, no se puede añadir
- El campo `stock_minimo` se configura directamente en Firestore en el documento del producto (`catalogo/{id}`)

####  Lector de código de barras
- El buscador funciona como input para lectores USB o Bluetooth:
  - El lector envía el código y pulsa **Enter** automáticamente
  - El sistema busca en `catalogo` por el campo `codigo_barras`
  - Si encuentra coincidencia exacta → añade el producto directamente al ticket y limpia el campo
  - Si no coincide → actúa como búsqueda por nombre
- Para añadir `codigo_barras` a un producto, editar el documento en Firestore:
  ```
  catalogo/{empresaId}/{productoId}
    └── codigo_barras: "8410000123456"
  ```

####  Ticket de venta directa
- Header fijo " Venta directa"
- Líneas con `+` / `−` por artículo
- Botón limpiar ticket (papelera)

####  Cobrar con descuento de stock
- **Efectivo**, **Tarjeta** o **Mixto**
- Al confirmar el cobro, además de crear el pedido, **descuenta el stock** de cada producto vendido:
  ```
  catalogo/{empresaId}/{productoId}
    stock: FieldValue.increment(-cantidad)
  ```
  - Si el campo `stock` no existe en el documento → se ignora silenciosamente (sin bloquear la venta)
  - Si el stock ya es 0 en el momento de la compra → la tarjeta estaba desactivada, no llega a cobrar

####  Cierre de caja
- Accesible desde el icono `` en el **AppBar** (toggle — no hay NavigationRail)
- Al pulsar de nuevo vuelve a la pantalla de ventas
- IVA al **21%** (retail tipo general)
- Comparativa hoy vs. ayer
- Z-Report PDF descargable
- Top productos vendidos

---

## 5. Lo que comparten los 3 TPV

| Función | Bar | Peluquería | Tienda |
|---|:---:|:---:|:---:|
| Número de ticket atómico (sin duplicados) | ✅ | ✅ | ✅ |
| Cobro efectivo + cambio | ✅ | ✅ | ✅ |
| Cobro tarjeta | ✅ | ✅ | ✅ |
| Cobro mixto (efectivo + tarjeta) | ✅ | ❌ | ✅ |
| Facturación automática | ✅ | ✅ | ✅ |
| Impresora BT térmica | ✅ | ✅ | ✅ |
| Variantes de producto/servicio | ✅ | ✅ | ✅ |
| Cierre de caja diario | ✅ | ✅ | ✅ |
| Z-Report PDF | ✅ | ✅ | ✅ |
| Reloj + indicador WiFi + BT | ✅ | ✅ | ✅ |
| Orientación horizontal forzada | ✅ | ✅ | ✅ |

---

## 6. Estructura Firestore por tipo

### Todos los tipos

```
empresas/{empresaId}
  ├── tipo_tpv: "bar" | "peluqueria_estetica" | "tienda"
  ├── catalogo/{productoId}
  │     ├── nombre, categoria, precio, iva_porcentaje
  │     ├── activo: bool
  │     ├── tiene_variantes: bool
  │     ├── variantes: [{nombre, precio_modificador, precio_efectivo, sku}]
  │     ├── stock: int          ← solo relevante para tienda
  │     ├── stock_minimo: int   ← solo relevante para tienda
  │     └── codigo_barras: string  ← solo relevante para tienda
  ├── pedidos/{pedidoId}
  │     ├── importe_total, metodo_pago, importe_efectivo, importe_tarjeta
  │     ├── fecha_hora, estado_pago: "pagado"
  │     ├── numero_ticket, origen: "presencial"
  │     └── lineas: [{producto_nombre, cantidad, precio_unitario, iva_porcentaje}]
  └── contadores/tickets
        └── ultimo: int   ← se incrementa con transaction en cada cobro
```

### Solo bar/restaurante

```
empresas/{empresaId}
  ├── mesas/{mesaId}
  │     ├── numero, nombre, zona, capacidad
  │     ├── estado: "libre" | "ocupada" | "reservada"
  │     ├── comanda_id, camarero_uid, fecha_apertura
  └── comandas/{comandaId}
        ├── mesa_id, camarero_uid, estado: "abierta" | "cobrada"
        ├── apertura, importe_total
        └── lineas: [{producto_id, nombre, cantidad, precio_unitario, iva_porcentaje}]
```

### Solo peluquería/estética

```
empresas/{empresaId}
  ├── sillones/{sillonId}
  │     ├── numero, nombre, zona
  │     ├── estado: "libre" | "ocupado"
  │     ├── comanda_id, empleado_uid, empleado_nombre
  │     ├── servicio_actual, importe_comanda, fecha_apertura
  └── comandas/{comandaId}   ← misma estructura que bar
```

### Cierre de caja (todos)

```
empresas/{empresaId}
  └── cierres_caja/{cierreId}
        ├── fecha, total, efectivo, tarjeta
        ├── num_tickets, ticket_medio
        └── top_productos: [{nombre, cantidad}]
```

---

## 7. Cómo añadir productos/servicios al catálogo

El catálogo es **el mismo para los 3 tipos de TPV** — solo cambia cómo se muestran (con stock en tienda, como servicios en peluquería, como carta en bar).

### Desde la app (módulo Catálogo/Servicios)

1. Ve al módulo **Servicios** o **Catálogo** del dashboard.
2. Crea un nuevo producto/servicio con nombre, categoría, precio e IVA.
3. Si tiene variantes (tallas, acabados, duraciones), activa "Tiene variantes" y añádelas.
4. Para tienda: escribe el código de barras en el campo correspondiente y establece el stock inicial.

### Desde Firestore (masivo)

```
empresas/{empresaId}/catalogo/{nuevoId}
  nombre: "Corte de pelo hombre"
  categoria: "Cortes"
  precio: 15.00
  iva_porcentaje: 21
  activo: true
  tiene_variantes: false
  variantes: []
```

---

*Documento generado automáticamente · PlaneaG v1.0.15 · 2026*
