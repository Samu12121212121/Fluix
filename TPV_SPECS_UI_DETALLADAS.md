# 🎨 Especificaciones UI Detalladas — TPV Multi-Sector

> Documento técnico de diseño visual para implementación  
> PlaneaG v1.0 · Mayo 2026

---

## TPV 2 — Peluquería / Estética ✂️

### Layout general
- **3 columnas en tablet horizontal**
- **Proporciones:** 230px (izquierda) | Flexible (centro) | 290px (derecha)
- **Color principal:** Morado `#6A1B9A`
- **Orientación forzada:** Landscape

---

### 📋 COLUMNA IZQUIERDA — Lista de profesionales (230px)

#### Navegador de fecha (fijo arriba)
```
┌─────────────────────────────┐
│  [◀]  Lun 11 Mayo   [▶]    │  ← Fondo morado, texto blanco
└─────────────────────────────┘
```
- Botones de flecha para navegar días
- Formato: "Día DD Mes" en español
- Al cambiar día se actualiza toda la agenda

#### Lista scrollable de profesionales
Cada fila (profesional) contiene:

```
┌──────────────────────────────────────┐
│ ┃ [AC] Nombre Profesional            │
│ ┃      3 citas · 5.5h libres      ⬤  │
└──────────────────────────────────────┘
```

**Elementos:**
1. **Barra izquierda:** 4px de ancho, color del profesional
2. **Avatar circular:** Iniciales en negrita, fondo color del profesional al 20% de opacidad, texto color sólido
3. **Nombre:** Fuente 13px, peso 600
4. **Stats:** Fuente 11px, color gris, formato "X citas · Y.Yh libres"
5. **Indicador disponibilidad:** Círculo 10px en extremo derecho
   - 🟢 Verde `#4CAF50`: disponible ahora
   - 🟠 Ámbar `#FFA726`: ocupado en cita actual

**Estado seleccionado:**
- Fondo blanco `#FFFFFF`
- Borde izquierdo morado `#6A1B9A` 4px
- Sombra `BoxShadow(color: black12, blurRadius: 4)`

**Paleta de colores por profesional:**
```dart
[
  #7B1FA2,  // morado
  #2E7D32,  // verde
  #BF360C,  // coral
  #1565C0,  // azul
  #00695C,  // teal
  #E65100,  // naranja
  #880E4F,  // rosa
  #37474F,  // gris slate
]
```
Se asignan cíclicamente según orden en Firestore.

#### Botón inferior
```
┌──────────────────────────────────────┐
│                                      │
│         [+] Nueva cita               │  ← Morado, full width
│                                      │
└──────────────────────────────────────┘
```
- Padding: 12px
- `FilledButton` morado, 48px de alto

---

### 📅 COLUMNA CENTRAL — Agenda / Walk-in / Cabinas

#### TabBar (fijo arriba)
```
┌──────────────────────────────────────┐
│  Agenda  │  Walk-in / Cola  │ Cabinas │  ← Fondo morado
└──────────────────────────────────────┘
```
- Indicador blanco debajo del tab activo
- Color texto: blanco activo, blanco60 inactivo

---

#### TAB 1: Agenda (Timeline vertical)

**Estructura:**
```
HH:mm  │  [Contenido del slot]
────────────────────────────────
09:00  │  ┏━━━━━━━━━━━━━━━━━━┓
       │  ┃ Juan Pérez       ┃  ← Borde izq color prof
       │  ┃ Corte + Barba    ┃
       │  ┃ 45 min · 35€     ┃
09:30  │  ┗━━━━━━━━━━━━━━━━━━┛
       │
10:00  │  ┌ · · · · · · · · ┐
       │  │  + Nueva cita    │  ← Borde punteado
       │  └ · · · · · · · · ┘
```

**Especificaciones:**

**Hora (columna izquierda, 48px):**
- Fuente 11px, color gris `Colors.grey`
- Alineado a la derecha
- Padding top 6px

**Línea vertical separadora:**
- 1px, color `Colors.grey.shade200`

**Cita ocupada:**
- Container con:
  - Borde izquierdo 4px del color del profesional asignado
  - Fondo: color del profesional al 10% de opacidad
  - Padding: 10px horizontal, 6px vertical
  - Border radius: 8px
- **Nombre del cliente:** Fuente 13px, peso 700
- **Etiquetas de servicio:** Chips pequeños con fondo color del prof al 20%, texto color prof peso 600, fuente 10px
- **Duración e importe:** Fuente 11px, color gris

**Slot vacío:**
- Container con:
  - Border punteado `BorderStyle.solid` imitando puntos con `Colors.grey.shade300`
  - Border radius: 6px
  - Texto centrado "+ Nueva cita" en gris, fuente 12px
  - Tappable → abre diálogo nueva cita

**Altura por slot:**
- 60px por cada 30 minutos de duración configurada
- Las citas ocupan múltiplos según su duración (ej: 45 min = 90px)

---

#### TAB 2: Walk-in / Cola

**Botón superior:**
```
┌────────────────────────────┐
│  [+] Añadir turno          │  ← Botón morado
└────────────────────────────┘
```

**Lista de turnos:**
```
┌──────────────────────────────────────────────┐
│  ⓵   Cliente sin cita                [Asignar] │
│      Corte express                            │
│      Espera estimada: ~30 min                 │
├──────────────────────────────────────────────┤
│  ⓶   María González             [Asignar] │
│      Tinte + Mechas                           │
│      Espera estimada: ~60 min                 │
└──────────────────────────────────────────────┘
```

**Card por turno:**
- **Número:** Círculo 40px, fondo `#F3E5F5`, texto morado `#6A1B9A` fuente 18px peso 700
- **Nombre cliente:** Fuente 14px peso 600
- **Servicio:** Fuente 12px color gris
- **Espera estimada:** Fuente 11px color gris, calculado como `(índice en cola × 30 min)`
- **Botón Asignar:** `FilledButton` morado, padding compacto, fuente 12px

---

#### TAB 3: Cabinas

**Grid de cabinas/sillones:**
```
┌─────────┐  ┌─────────┐  ┌─────────┐
│  🪑     │  │  🪑     │  │  🪑     │
│ Cabina 1│  │ Cabina 2│  │ Cabina 3│
│  Libre  │  │ Ocupada │  │  Libre  │
└─────────┘  └─────────┘  └─────────┘
```

**Especificaciones:**
- Grid con `maxCrossAxisExtent: 160`, aspect ratio 0.9
- **Tarjeta libre:** Fondo blanco, borde gris claro 1px, icono gris
- **Tarjeta ocupada:** Fondo `#F3E5F5`, borde morado 2px, icono morado
- **Badge estado:** Chip pequeño con "Libre" verde o "Ocupada" morado

---

### 🎫 COLUMNA DERECHA — Cliente + Ticket (290px)

#### Bloque 1: Buscador de cliente

```
┌────────────────────────────────────┐
│  🔍 Buscar cliente…                │
└────────────────────────────────────┘
```

**Al seleccionar cliente:**
```
┌────────────────────────────────────┐
│  [AC]  Ana Cristina                │
│        12 visitas                  │
│                                    │
│  🎨 Rubio miel  🎟 3 sesiones     │
│  💧 Producto Premium               │
└────────────────────────────────────┘
```

**Especificaciones:**
- **Card con fondo:** `#F3E5F5`, borde `#CE93D8`
- **Avatar:** 32px, fondo morado, texto blanco
- **Nombre:** Fuente 13px peso 700
- **Visitas:** Fuente 11px color gris
- **Etiquetas (chips):**
  - Color habitual: fondo `#EDE7F6`, fuente 10px
  - Bono activo: fondo verde claro `#C8E6C9`, fuente 10px
  - Producto: fondo `#EDE7F6`, fuente 10px

---

#### Bloque 2: Catálogo de servicios

**Chips de categoría:**
```
[ Color ]  [ Corte ]  [ Tratamiento ]  [ Uñas ]
```
- `ChoiceChip` morado cuando está seleccionado
- Scroll horizontal

**Lista de servicios disponibles:**
```
Corte hombre               15,00 €  [+]
Corte mujer                25,00 €  [+]
Barba                      10,00 €  [+]
```
- `ListView` compacto, fuente 13px
- Botón `[+]` morado o `[-]` rojo si ya está en el ticket

**Servicios añadidos al ticket (sublista):**
```
┌────────────────────────────────────┐
│  Ticket                            │
│  ────────────────────────          │
│  Corte hombre    15,00 €    ✖     │
│  Tinte           45,00 €    ✖     │
└────────────────────────────────────┘
```
- Separador visual "Ticket"
- Cruz roja para eliminar
- Fuente 12px

---

#### Bloque 3: Footer totales + cobro

```
┌────────────────────────────────────┐
│  Subtotal             60,00 €      │
│  Descuento bono      −15,00 €      │  ← verde
│  ─────────────────────────────     │
│  TOTAL                45,00 €      │  ← grande, morado
│                                    │
│  [    Cobrar 45,00 €    ]          │  ← morado, full width
└────────────────────────────────────┘
```

**Especificaciones:**
- Subtotal: fuente 12px
- Descuento bono: fuente 12px color verde `Colors.green`
- Total: fuente 18px peso 700 color morado
- Botón cobrar: `FilledButton` morado, 48px alto, fuente 15px peso 700

---

## TPV 3 — Tienda / Retail 🛍️

### Layout general
- **2 columnas en tablet horizontal**
- **Proporciones:** Flexible (izquierda, ~65%) | 320px (derecha)
- **Color principal:** Verde oscuro `#1B5E20`
- **Orientación forzada:** Landscape

---

### 📦 COLUMNA IZQUIERDA — Catálogo / Pedidos / Stock (Flexible)

#### Barra superior
```
┌────────────────────────────────────────────────┐
│  🔍 Buscar o escanear…          [Escanear]     │
└────────────────────────────────────────────────┘
```
- TextField grande, casi full width
- Botón "Escanear" verde compacto a la derecha
- Al pulsar Enter → busca por código de barras exacto

#### TabBar
```
┌────────────────────────────────────────────────┐
│  Catálogo  │  Pedidos online ⓿  │  Stock      │
└────────────────────────────────────────────────┘
```
- Badge rojo con número de pedidos "nuevo" sin gestionar

---

#### TAB 1: Catálogo

**Chips de categoría (debajo del TabBar):**
```
[ Todos ]  [ Bebidas ]  [ Snacks ]  [ Electrónica ]
```

**Grid de productos (3-4 columnas):**
```
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ 🍕  [+]  │  │ 🥤  [+]  │  │ 🍫  [+]  │  │ 📱  [+]  │
│          │  │          │  │          │  │          │
│ Pizza    │  │ Refresco │  │ Chocolate│  │ iPhone   │
│ 12,50 €  │  │  2,50 €  │  │  1,80 €  │  │ 899,00 € │
│ ⚠️ 3 ⬤   │  │  🟢 45   │  │  🟢 120  │  │ SIN STOCK│
└──────────┘  └──────────┘  └──────────┘  └──────────┘
```

**Especificaciones tarjeta producto:**
- **Icono categoría:** Representativo, tamaño 32px, parte superior
- **Botón [+]:** Círculo verde 28px, esquina superior derecha, posición absoluta
- **Nombre:** Fuente 13px peso 700, max 2 líneas con ellipsis
- **Precio:** Fuente 14px color verde `#2E7D32`
- **Stock badge:**
  - 🟢 Verde normal: stock > stock_mínimo
  - 🟠 Ámbar + ⚠️: stock ≤ stock_mínimo, fuente 10px
  - Sin stock: tarjeta opacity 0.5, texto "SIN STOCK" en gris, botón [+] deshabilitado

---

#### TAB 2: Pedidos online

**Lista de pedidos:**
```
┌────────────────────────────────────────────────────────┐
│  #0042  │  Carlos Ruiz  │  67,90 €  │ 📦 │ [NUEVO]    │
├────────────────────────────────────────────────────────┤
│  #0041  │  Ana López    │  23,50 €  │ 🏪 │ [PREPARANDO]│
├────────────────────────────────────────────────────────┤
│  #0040  │  Juan Pérez   │ 145,00 €  │ 📦 │ [LISTO]    │
└────────────────────────────────────────────────────────┘
```

**Especificaciones fila:**
- **Número pedido:** Fuente 13px peso 700
- **Nombre cliente:** Fuente 13px
- **Importe:** Fuente 14px peso 600
- **Icono tipo:** 
  - 🏪 `Icons.store` = recogida en tienda
  - 📦 `Icons.local_shipping` = envío a domicilio
- **Badge estado:**
  - NUEVO: verde `#4CAF50`
  - PREPARANDO: ámbar `#FFA726`
  - LISTO: azul `#1976D2`
  - ENVIADO: morado `#7B1FA2`
  - ENTREGADO: gris

**Al tocar pedido:** La columna derecha cambia a modo "Detalle de pedido"

---

#### TAB 3: Stock

**Tabla de productos:**
```
┌──────────────────────────────────────────────────┐
│  Nombre          │ Ref    │ Stock │ Min │ [🔄]  │
├──────────────────────────────────────────────────┤
│  Pizza Margarita │ PZ001  │  ⚠️5  │  10 │ [🔄]  │
│  Coca-Cola 33cl  │ RF002  │  45   │  20 │ [🔄]  │
│  Chocolate Negro │ SN003  │  0    │   5 │ [🔄]  │
└──────────────────────────────────────────────────┘
```

**Especificaciones:**
- Ordenable por nombre o stock (tap en header)
- Si stock < mínimo: texto ámbar + ⚠️
- Si stock = 0: texto rojo
- Botón [🔄] "Ajustar stock": abre bottom sheet con field numérico

---

### 🎫 COLUMNA DERECHA — Ticket / Detalle pedido (320px)

#### MODO 1: Ticket normal

**Header:**
```
┌────────────────────────────────────┐
│  🛒 Venta directa          [🗑️]   │
└────────────────────────────────────┘
```

**Lista de productos añadidos:**
```
┌────────────────────────────────────┐
│  Pizza Margarita                   │
│  [ - ]  2  [ + ]          25,00 €  │
├────────────────────────────────────┤
│  Coca-Cola 33cl                    │
│  [ - ]  1  [ + ]           2,50 €  │
└────────────────────────────────────┘
```

**Buscar cliente:**
```
┌────────────────────────────────────┐
│  👤 Cliente (opcional)             │
│  Ana López Martínez                │  ← Autocomplete
└────────────────────────────────────┘
```

**Código de descuento:**
```
┌────────────────────────────────────┐
│  🎟️ Código descuento   [Aplicar]  │
└────────────────────────────────────┘
```

**Desglose:**
```
┌────────────────────────────────────┐
│  Subtotal              27,50 €     │
│  IVA (21%)              5,78 €     │
│  ───────────────────────────       │
│  TOTAL                 33,28 €     │
└────────────────────────────────────┘
```

**Botones de pago (grid 2 columnas):**
```
┌────────────────┐  ┌────────────────┐
│   💳 Efectivo  │  │  💳 Tarjeta    │
└────────────────┘  └────────────────┘
```

**Botón secundario:**
```
┌────────────────────────────────────┐
│     📦 Preparar para envío         │  ← Outlined button
└────────────────────────────────────┘
```

---

#### MODO 2: Detalle de pedido online

**Header:**
```
┌────────────────────────────────────┐
│  Pedido #0042                 [NUEVO]│
│                                    │
│  [Albarán] [Etiqueta] [Marcar listo]│
└────────────────────────────────────┘
```

**Grid de info (2 columnas):**
```
┌──────────────────┐  ┌──────────────────┐
│ 👤 Cliente       │  │ 📍 Dirección     │
│ Carlos Ruiz      │  │ C/ Mayor 123     │
│ 666 123 456      │  │ 28001 Madrid     │
│ carlos@email.com │  │ España           │
│                  │  │ 📦 MRW Express   │
└──────────────────┘  └──────────────────┘
```

**Lista de productos con checkboxes:**
```
┌────────────────────────────────────┐
│  ☑️ Pizza Margarita × 2            │
│  ☐ Coca-Cola 33cl × 1              │
│  ☑️ Chocolate Negro × 3            │
└────────────────────────────────────┘
```
- Checkboxes persistentes en Firestore (`productosPreparados: []`)
- Al marcar todos → habilita botón "Marcar listo"

**Desglose importes:**
```
┌────────────────────────────────────┐
│  Subtotal              55,00 €     │
│  Gastos envío           5,00 €     │
│  IVA                   12,60 €     │
│  ───────────────────────────       │
│  TOTAL COBRADO         72,60 €     │
└────────────────────────────────────┘
```

**Botón avisar:**
```
┌────────────────────────────────────┐
│     📧 Avisar cliente              │  ← Abre email/SMS
└────────────────────────────────────┘
```
- Texto prefijado: "Su pedido #XXXX está listo para recoger/ha sido enviado"

---

## 🔧 Componentes técnicos comunes

### Diálogo de pago (ambos TPV)

```
┌──────────────────────────────────────┐
│           Método de pago             │
│                                      │
│  ┌────────────────────────────┐     │
│  │         TOTAL              │     │
│  │        45,00 €             │     │  ← Destacado
│  └────────────────────────────┘     │
│                                      │
│  [ Efectivo ]  [ Tarjeta ]  [Mixto] │  ← Chips
│                                      │
│  ─ Si Efectivo: ─                   │
│  Entrega: [______] €                │
│  Cambio:   15,50 €  ← verde        │
│                                      │
│  ─ Si Mixto: ─                      │
│  Efectivo: [______] €               │
│  Tarjeta:  [______] €               │
│                                      │
│        [Cancelar] [Confirmar]       │
└──────────────────────────────────────┘
```

### Cierre de caja (ambos TPV)

**Layout responsive en columnas:**
```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ Total ventas│  │ Tickets     │  │ Ticket medio│
│   456,78 €  │  │     23      │  │   19,86 €   │
└─────────────┘  └─────────────┘  └─────────────┘

┌─────────────────┐  ┌─────────────────┐
│ Método de pago  │  │ Desglose IVA    │
│ Efectivo 123 €  │  │ Base   377,50 € │
│ Tarjeta  333 €  │  │ Cuota   79,28 € │
└─────────────────┘  └─────────────────┘

┌─────────────────┐  ┌─────────────────┐
│ Comparativa     │  │ Top 3 productos │
│ Hoy    456,78 € │  │ 1. Pizza × 45   │
│ Ayer   412,30 € │  │ 2. Refres × 38  │
└─────────────────┘  │ 3. Chocol × 27  │
                     └─────────────────┘
```

**Botones acción:**
- `[🔄 Refrescar]` — Recalcula sin recargar
- `[📄 Z-Report PDF]` — Genera PDF con `pdf` + `printing` package
- `[✅ Cerrar caja]` — Registra en Firestore con confirmación

---

## 📐 Medidas y constantes

```dart
// Peluquería
const kPelColIzquierda = 230.0;
const kPelColDerecha = 290.0;
const kPelColorPrimario = Color(0xFF6A1B9A);
const kPelSlotHeight = 60.0;  // por cada 30 min
const kPelSlotDuration = 30;  // minutos

// Tienda
const kTiendaColDerecha = 320.0;
const kTiendaColorPrimario = Color(0xFF1B5E20);
const kTiendaGridCols = 4;  // columnas del grid de productos
```

---

## 🎨 Sistema de colores

### Peluquería
```dart
primary: Color(0xFF6A1B9A)      // morado
primaryLight: Color(0xFFF3E5F5)
primaryDark: Color(0xFF4A0E6E)
accent: Color(0xFFCE93D8)
```

### Tienda
```dart
primary: Color(0xFF1B5E20)      // verde oscuro
primaryLight: Color(0xFFC8E6C9)
accent: Color(0xFF4CAF50)       // verde claro
warning: Color(0xFFFFA726)      // ámbar
```

---

*Especificaciones UI v1.0 · PlaneaG · Mayo 2026*

