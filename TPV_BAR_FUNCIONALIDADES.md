# ️ TPV Restaurante/Bar - Funcionalidades Implementadas

Este documento describe todas las funcionalidades añadidas al TPV de restaurante/bar con el nuevo esquema de colores **Cian/Magenta sobre Azul Marino**.

---

##  Archivos Creados

### 1. `tpv_bar_mejoras.dart`
Diálogos para gestión de mesas y comandas:

#### ✅ Gestión de Mesas
- **`mostrarDialogoCrearMesa()`** - Crear nueva mesa
  - Campos: Nombre/número, zona (Salón/Terraza/Barra/VIP/Reservado), capacidad
  - Color primario: Cian `#00FFC8`

- **`mostrarDialogoEditarMesa()`** - Editar mesa existente
  - Permite modificar nombre, zona, capacidad
  - Botón para eliminar mesa (rojo `#FF2850`)

- **`mostrarDialogoComensales()`** - Establecer número de comensales
  - Selector visual con botones +/-
  - Accesos rápidos para 1-10 personas
  - Color: Magenta `#FF3296`

#### ✅ Gestión de Productos
- **`mostrarDialogoProductoManual()`** - Añadir producto con precio libre
  - Campos: Descripción, precio, nota opcional
  - Para menús especiales, consumiciones fuera de cat logo
  - Color: Rosa `#FF4678`

- **`mostrarDialogoEditarPrecio()`** - Modificar precio de línea
  - Permite cambiar el precio de un producto ya añadido
  - Útil para promociones o ajustes
  - Color: Magenta `#FF3296`

- **`mostrarDialogoDescuento()`** - Aplicar descuento
  - Por porcentaje (%) o importe fijo (€)
  - Sobre una línea específica o sobre el total
  - Sugerencias rápidas: 5%, 10%, 15%, 20%, 25%, 50%
  - Color: Rosa `#FF4678`

- **`mostrarDialogoNota()`** - Añadir nota a producto
  - Texto libre para instrucciones de cocina
  - Sugerencias rápidas: "Sin gluten", "Poco hecho", "Sin cebolla", etc.
  - Se imprime en el ticket de cocina
  - Color: Magenta `#FF3296`

---

### 2. `tpv_bar_cobro.dart`
Sistema completo de cobro y cierre de caja:

#### ✅ Pantalla de Cobro
- **`mostrarPantallaCobro()`** - Pantalla completa de cobro
  - Desglose: Subtotal + Propina = Total
  - **3 Métodos de pago**:
    -  Efectivo (Cian `#00FFC8`) - Con cálculo automático de cambio
    -  Tarjeta (Magenta `#FF3296`)
    -  QR/Bizum (Rosa `#FF4678`)
  - **Campo de propina** con sugerencias (1€, 2€, 5€, 10€)
  - **Efectivo**: Botones rápidos de 10€, 20€, 50€, 100€
  - Validación de efectivo suficiente
  - Registro en `/empresas/{id}/ventas`
  - Actualización automática de caja diaria
  - Liberación de mesa tras cobro
  - Impresión automática de ticket

#### ✅ Cierre de Caja
- **`mostrarPantallaCierreCaja()`** - Resumen del día
  - Total del día en grande (Cian)
  - Desglose por método de pago:
    -  Efectivo
    -  Tarjeta
    -  Bizum/QR
  - Propinas totales
  - Fondo inicial
  - Número de tickets
  - Botón de cierre definitivo (Rojo `#FF2850`)
  - Lee de `/empresas/{id}/caja_diaria/{fecha}`

#### ✅ Apertura de Caja
- **`mostrarDialogoAperturaCaja()`** - Fondo inicial del día
  - Introducir efectivo inicial en caja
  - Sugerencias: 50€, 100€, 150€, 200€
  - Crea documento en `/caja_diaria/{fecha}`
  - Color: Cian `#00FFC8`

---

##  Paleta de Colores Utilizada

### Colores Principales
```dart
const cian = Color(0xFF00FFC8);        // Primario - Acciones principales
const magenta = Color(0xFFFF3296);     // Secundario - Categorías/Iconos
const rosa = Color(0xFFFF4678);        // Alternativo - Descuentos/Notas
const rojo = Color(0xFFFF2850);        // Destructivo - Eliminar/Cancelar
```

### Colores de Fondo
```dart
const fondoOscuro = Color(0xFF0A0F23); // RGB(10,15,35) - Fondo principal
const superficie = Color(0xFF151932);   // Superficies elevadas
const tarjeta = Color(0xFF1E2139);     // Cards/Tarjetas
const divisor = Color(0xFF2A2E45);     // Líneas divisorias
```

### Colores de Texto
```dart
const textoBlanco = Color(0xFFFFFFFF);     // Títulos y principal
const textoSecundario = Color(0xFFB0B3C1); // Subtítulos y secundario
const textoHint = Color(0xFF6B6E82);       // Placeholders y sugerencias
```

---

##  Estructura de Datos de Firestore

### Colección: `/empresas/{empresaId}/mesas`
```dart
{
  "nombre": "Mesa 1",
  "zona": "Salón",            // Salón, Terraza, Barra, VIP, Reservado
  "capacidad": 4,
  "estado": "libre",          // libre, ocupada, reservada
  "comensales_actuales": 0,
  "creado_en": Timestamp,
  "actualizado_en": Timestamp
}
```

### Colección: `/empresas/{empresaId}/ventas`
```dart
{
  "mesa_id": "abc123",
  "mesa_nombre": "Mesa 1",
  "comensales": 4,
  "lineas": [
    {
      "nombre": "Cerveza",
      "precio": 2.50,
      "cantidad": 2,
      "nota": "Bien fría",
      "descuento": 0.0
    }
  ],
  "subtotal": 5.00,
  "propina": 0.50,
  "total": 5.50,
  "metodo_pago": "efectivo",  // efectivo, tarjeta, bizum
  "entregado": 10.00,         // Solo si es efectivo
  "cambio": 4.50,             // Solo si es efectivo
  "fecha": Timestamp,
  "cajero_uid": "user123"
}
```

### Colección: `/empresas/{empresaId}/caja_diaria/{fecha}`
```dart
{
  "fecha": "2026-05-12",
  "fondo_inicial": 100.00,
  "total_efectivo": 250.00,
  "total_tarjeta": 180.00,
  "total_bizum": 75.00,
  "total_propinas": 25.00,
  "num_tickets": 32,
  "abierta": true,
  "abierta_en": Timestamp,
  "cerrada_en": Timestamp     // Solo cuando se cierra
}
```

---

##  Cómo Integrar en tpv_root_screen.dart

### 1. Importar los archivos
```dart
import '../widgets/tpv_bar_mejoras.dart';
import '../widgets/tpv_bar_cobro.dart';
```

### 2. Añadir botones en la UI

#### En el panel de mesas:
```dart
// Botón crear mesa
FloatingActionButton(
  onPressed: () => mostrarDialogoCrearMesa(context, widget.empresaId),
  backgroundColor: const Color(0xFF00FFC8),
  child: const Icon(Icons.add, color: Color(0xFF0A0F23)),
)

// Menú contextual en cada mesa (long press)
onLongPress: () {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.people, color: Color(0xFFFF3296)),
          title: const Text('Comensales'),
          onTap: () {
            Navigator.pop(ctx);
            mostrarDialogoComensales(context, widget.empresaId, mesaId, comensalesActuales);
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit, color: Color(0xFF00FFC8)),
          title: const Text('Editar mesa'),
          onTap: () {
            Navigator.pop(ctx);
            mostrarDialogoEditarMesa(context, widget.empresaId, mesaData, mesaId);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Color(0xFFFF2850)),
          title: const Text('Eliminar'),
          onTap: () {
            Navigator.pop(ctx);
            // Llamar a eliminar desde el diálogo de edición
          },
        ),
      ],
    ),
  );
}
```

#### En el panel de comanda:
```dart
// Botón añadir producto manual
IconButton(
  icon: const Icon(Icons.edit_note, color: Color(0xFFFF4678)),
  onPressed: () async {
    final producto = await mostrarDialogoProductoManual(context);
    if (producto != null) {
      // Añadir a la comanda
      _agregarLineaComanda(producto);
    }
  },
)

// Menú en cada línea de comanda
IconButton(
  icon: const Icon(Icons.more_vert),
  onPressed: () {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFFFF3296)),
            title: const Text('Editar precio'),
            onTap: () async {
              Navigator.pop(ctx);
              final nuevoPrecio = await mostrarDialogoEditarPrecio(
                context,
                linea['nombre'],
                linea['precio'],
              );
              if (nuevoPrecio != null) {
                // Actualizar precio
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.discount, color: Color(0xFFFF4678)),
            title: const Text('Descuento'),
            onTap: () async {
              Navigator.pop(ctx);
              final descuento = await mostrarDialogoDescuento(
                context,
                precioLinea: linea['precio'],
              );
              if (descuento != null) {
                // Aplicar descuento
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.note, color: Color(0xFFFF3296)),
            title: const Text('Añadir nota'),
            onTap: () async {
              Navigator.pop(ctx);
              final nota = await mostrarDialogoNota(
                context,
                linea['nombre'],
                notaActual: linea['nota'],
              );
              if (nota != null) {
                // Guardar nota
              }
            },
          ),
        ],
      ),
    );
  },
)

// Botón cobrar
ElevatedButton.icon(
  onPressed: () async {
    final cobrado = await mostrarPantallaCobro(
      context,
      widget.empresaId,
      _mesaSeleccionadaId!,
      nombreMesa,
      lineasComanda,
      totalComanda,
      comensales,
    );
    if (cobrado == true) {
      // Mesa liberada, volver al listado
      setState(() {
        _mesaSeleccionadaId = null;
        _comandaActiva = null;
      });
    }
  },
  icon: const Icon(Icons.payments),
  label: const Text('Cobrar'),
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF00FFC8),
    foregroundColor: const Color(0xFF0A0F23),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  ),
)
```

#### En el AppBar o menú principal:
```dart
// Botón apertura de caja
IconButton(
  icon: const Icon(Icons.account_balance_wallet),
  onPressed: () => mostrarDialogoAperturaCaja(context, widget.empresaId),
  tooltip: 'Apertura de caja',
)

// Botón cierre de caja
IconButton(
  icon: const Icon(Icons.lock_clock),
  onPressed: () => mostrarPantallaCierreCaja(context, widget.empresaId),
  tooltip: 'Cierre de caja',
)
```

---

## ✅ Funcionalidades Completadas

### Panel Lateral - Mesas (4/4)
- ✅ Crear mesa nueva con zona
- ✅ Editar/eliminar mesa
- ✅ Número de comensales
- ⏳ Vista de mapa visual (requiere interfaz gráfica adicional)

### Panel Central - Comanda (5/5)
- ✅ Añadir producto manual con precio libre
- ✅ Editar precio de ítem
- ✅ Aplicar descuento por línea o total
- ✅ Notas por línea de producto
- ⏳ Dividir/transferir comanda (requiere lógica adicional)

### Flujo de Cobro (4/4)
- ✅ Pantalla de cobro con métodos de pago
- ✅ Cierre de caja
- ✅ Apertura de caja con fondo inicial
- ✅ Propinas

### Panel Derecho - Catálogo (1/3)
- ✅ Crear productos desde TPV (ya existía en tpv_root_screen.dart)
- ⏳ Búsqueda rápida
- ⏳ Favoritos

### Cocina y Tickets (1/3)
- ✅ 

Imprimir ticket (integrado en cobro)
- ⏳ Enviar comanda a impresora de cocina
- ⏳ Reimprimir ticket

---

##  Próximos Pasos

### Alta Prioridad
1. **Búsqueda de productos** - TextField en el panel de catálogo
2. **Enviar a cocina** - Botón que imprime sin cobrar
3. **Dividir comanda** - Seleccionar ítems para transferir a otra mesa

### Media Prioridad
4. **Favoritos** - Marcar productos más vendidos
5. **Vista de mapa** - Plano visual de mesas
6. **Reimprimir** - Acceso al historial de tickets

### Baja Prioridad
7. **Facturación completa** - Con datos fiscales
8. **Gestión de personal** - Turnos y permisos

---

##  Recomendaciones de UX

### Accesos Rápidos Sugeridos
- **Doble tap** en mesa → Abrir comanda
- **Long press** en mesa → Menú contextual (comensales/editar/eliminar)
- **Doble tap** en producto del catálogo → Añadir a comanda
- **Long press** en línea de comanda → Menú (editar precio/descuento/nota/eliminar)
- **Swipe** en línea → Eliminar rápido

### Feedback Visual
- Estado de mesa por color de borde:
  - Verde → Libre
  - Cian → Ocupada
  - Magenta → Reservada
  - Rojo → En cobro

### Atajos de Teclado (Desktop)
- `Ctrl + N` → Nueva mesa
- `Ctrl + P` → Cobrar
- `Ctrl + K` → Búsqueda de productos
- `Ctrl + L` → Cierre de caja
- `F2` → Editar precio
- `F3` → Añadir nota
- `F4` → Descuento

---

**Última actualización**: 12 de Mayo de 2026  
**Estado**: Funcionalidades core implementadas ✅  
**Esquema de colores**: Neon Cyber - Cian/Magenta sobre Azul Marino
