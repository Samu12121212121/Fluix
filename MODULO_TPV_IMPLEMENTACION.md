# 📱 Módulo TPV — Implementación Completa

## ✅ Estado de Implementación

### Completado en `tpv_root_screen.dart` (1358 líneas)

#### 1. Estructura Base
- ✅ Orientación paisaje forzada (`SystemChrome.setPreferredOrientations`)
- ✅ AppBar con botón de salida, icono TPV, chip de modo activo, reloj en tiempo real
- ✅ NavigationRail con 3 destinos (Mesas, Caja, Cierre)
- ✅ Manejo de estado con `StatefulWidget`

#### 2. Modelos de Datos
- ✅ `Mesa` (`lib/domain/modelos/mesa.dart`)
- ✅ `Comanda` y `LineaComanda` (`lib/domain/modelos/comanda.dart`)
- ✅ Integración con `Producto` existente

#### 3. Vista 1: Plano de Mesas
- ✅ Grid de tarjetas de mesa con `StreamBuilder` en tiempo real
- ✅ Filtros por zona (chips)
- ✅ Badges de conteo (libres/ocupadas/reservadas)
- ✅ Colores adaptativos (light/dark mode)
- ✅ Diálogo para crear nueva mesa (solo admin)
- ✅ Panel lateral con resumen y acciones rápidas
- ✅ Navegación a comanda al tocar mesa

#### 4. Vista 2: Layout 60/40 (Catálogo + Comanda)
- ✅ Panel izquierdo: catálogo de productos
  - ✅ Barra de búsqueda en tiempo real
  - ✅ Chips de categoría filtrables
  - ✅ Grid de productos con `StreamBuilder`
  - ✅ Placeholder con inicial si no hay imagen
- ✅ Panel derecho: comanda activa
  - ✅ Header diferenciado (mesa vs. caja rápida)
  - ✅ Lista de líneas con controles +/-
  - ✅ Footer con desglose IVA y total
  - ✅ Botón de cobro
- ✅ Gestión de estado reactivo (sin Navigator.push)

#### 5. Vista 3: Cierre de Caja
- ✅ Layout base con métricas
- ✅ Cards de desglose por método
- ✅ Panel lateral con IVA y comparativa
- ⚠️ **Pendiente**: Cálculo real desde Firestore

#### 6. Firestore Rules
- ✅ Reglas añadidas para `mesas`, `comandas`, `contadores`

---

## ⚠️ Funcionalidades Pendientes de Implementar

### 1. Selector de Variantes (Alta Prioridad)
**Archivo**: `tpv_root_screen.dart` línea ~1150

```dart
// TODO actual:
if (producto.tieneVariantes && producto.variantesDisponibles.isNotEmpty) {
  // TODO: Mostrar VarianteSelectorWidget
  onProductoSeleccionado(producto, null);
}
```

**Implementar**:
```dart
if (producto.tieneVariantes && producto.variantesDisponibles.isNotEmpty) {
  final variante = await showModalBottomSheet<VarianteProducto>(
    context: context,
    builder: (_) => VarianteSelectorWidget(producto: producto),
  );
  if (variante != null) {
    onProductoSeleccionado(producto, variante);
  }
} else {
  onProductoSeleccionado(producto, null);
}
```

### 2. Contador Secuencial de Tickets (Alta Prioridad)
**Archivo**: `tpv_root_screen.dart` línea ~1282

Crear función en `PedidosService`:
```dart
Future<int> obtenerSiguienteNumeroTicket(String empresaId) async {
  final ref = FirebaseFirestore.instance
      .collection('empresas').doc(empresaId)
      .collection('contadores').doc('tickets');
  
  return FirebaseFirestore.instance.runTransaction<int>((txn) async {
    final snap = await txn.get(ref);
    final nuevo = ((snap.data()?['ultimo_numero'] as num?)?.toInt() ?? 0) + 1;
    txn.set(ref, {'ultimo_numero': nuevo}, SetOptions(merge: true));
    return nuevo;
  });
}
```

### 3. Impresión de Ticket BT al Cobrar (Alta Prioridad)
**Archivo**: `tpv_root_screen.dart` método `_cobrar()` línea ~1298

**Implementar**:
```dart
Future<void> _cobrar(BuildContext context) async {
  // 1. Obtener número de ticket
  final numeroTicket = await _obtenerSiguienteNumeroTicket();
  
  // 2. Crear pedido en Firestore
  final pedido = await _crearPedidoDesdeComanda(numeroTicket);
  
  // 3. Imprimir ticket
  final empresaDoc = await FirebaseFirestore.instance
      .collection('empresas').doc(empresaId).get();
  final empresaData = empresaDoc.data();
  
  final ticketData = TicketData(
    numeroTicket: numeroTicket,
    fecha: DateTime.now(),
    lineas: comandaActiva!.lineas.map((l) => TicketLinea(
      nombre: l.nombre,
      cantidad: l.cantidad,
      precioUnitario: l.precioUnitario,
      total: l.total,
    )).toList(),
    total: comandaActiva!.total,
    metodoPago: 'Efectivo', // TODO: método seleccionado
    empresaNombre: empresaData?['nombre'] ?? '',
    empresaNif: empresaData?['nif'] ?? '',
    empresaDireccion: empresaData?['direccion'] ?? '',
  );
  
  try {
    await ImpressoraBluetooth().imprimirTicket(ticketData);
  } catch (e) {
    // Mostrar error pero continuar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al imprimir: $e')),
      );
    }
  }
  
  // 4. Si es mesa, marcar como libre
  if (mesaId != null) {
    await FirebaseFirestore.instance
        .collection('empresas').doc(empresaId)
        .collection('mesas').doc(mesaId)
        .update({
      'estado': 'libre',
      'comanda_id': null,
      'camarero_uid': null,
      'fecha_apertura': null,
    });
  }
  
  onCobrado();
}
```

### 4. Diálogo Método de Pago (Media Prioridad)
**Añadir antes de cobrar**:

```dart
Future<Map<String, dynamic>?> _mostrarDialogoMetodoPago(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _DialogoMetodoPago(total: comandaActiva!.total),
  );
}

class _DialogoMetodoPago extends StatefulWidget {
  final double total;
  const _DialogoMetodoPago({required this.total});
  
  @override
  State<_DialogoMetodoPago> createState() => _DialogoMetodoPagoState();
}

class _DialogoMetodoPagoState extends State<_DialogoMetodoPago> {
  String _metodo = 'efectivo';
  final _entregaCtrl = TextEditingController();
  final _efectivoMixtoCtrl = TextEditingController();
  final _tarjetaMixtoCtrl = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    // ... UI con chips Efectivo/Tarjeta/Mixto
    // Si mixto: dos campos para importes
    // Si efectivo: campo "Entrega cliente" y cálculo de cambio
  }
}
```

### 5. Notas por Línea (Media Prioridad)
**Archivo**: `_LineaComandaCard` línea ~1306

Añadir `onLongPress` a la tarjeta:
```dart
onLongPress: () async {
  final nota = await showDialog<String>(
    context: context,
    builder: (_) => _DialogoNotaLinea(notaActual: linea.notas),
  );
  if (nota != null) {
    // Actualizar línea con nota
  }
}
```

### 6. Carga Real de Datos en Cierre de Caja (Media Prioridad)
**Archivo**: `_CierreDeCaja` línea ~1320

Usar `CierreCajaService` existente:
```dart
Future<Map<String, dynamic>> _calcularCierreHoy() async {
  final hoy = DateTime.now();
  final inicio = DateTime(hoy.year, hoy.month, hoy.day);
  final fin = inicio.add(const Duration(days: 1));
  
  final snap = await FirebaseFirestore.instance
      .collection('empresas').doc(empresaId)
      .collection('pedidos')
      .where('fecha_pedido', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
      .where('fecha_pedido', isLessThan: Timestamp.fromDate(fin))
      .where('estado_pago', isEqualTo: 'pagado')
      .get();
  
  double totalEfectivo = 0;
  double totalTarjeta = 0;
  int numTickets = snap.docs.length;
  
  for (final doc in snap.docs) {
    final data = doc.data();
    final total = (data['importe_total'] as num?)?.toDouble() ?? 0;
    final metodo = data['metodo_pago'] as String?;
    
    switch (metodo) {
      case 'efectivo':
        totalEfectivo += total;
        break;
      case 'tarjeta':
        totalTarjeta += total;
        break;
      case 'mixto':
        totalEfectivo += (data['importe_efectivo'] as num?)?.toDouble() ?? 0;
        totalTarjeta += (data['importe_tarjeta'] as num?)?.toDouble() ?? 0;
        break;
    }
  }
  
  return {
    'total_efectivo': totalEfectivo,
    'total_tarjeta': totalTarjeta,
    'num_tickets': numTickets,
    'total': totalEfectivo + totalTarjeta,
  };
}
```

### 7. Botón Flotante para Crear Productos (Baja Prioridad)
**Archivo**: `_CatalogoPanel` línea ~1150

```dart
Stack(
  children: [
    // ...grid existente...
    if (esAdmin)
      Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton(
          mini: true,
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PantallaCrearProducto(empresaId: empresaId),
            ));
          },
          child: const Icon(Icons.add),
        ),
      ),
  ],
)
```

### 8. Badge de Cantidad en Tarjeta de Producto (Baja Prioridad)
**Archivo**: `_ProductoCard` línea ~1195

Envolver la tarjeta en `Stack` y añadir badge si está en comanda.

### 9. Transferir Mesa y Dividir Cuenta (Baja Prioridad)
Crear diálogos específicos para estas acciones.

---

## 🚀 Cómo Probar el Módulo

### 1. Desplegar Reglas de Firestore
```powershell
firebase deploy --only firestore:rules
```

### 2. Lanzar el Módulo desde Dashboard
En `pantalla_dashboard.dart`, añadir navegación:
```dart
Navigator.of(context).push(MaterialPageRoute(
  fullscreenDialog: true,
  builder: (_) => TpvRootScreen(
    empresaId: _empresaId!,
    esAdmin: _esAdmin,
  ),
));
```

### 3. Crear Datos de Prueba en Firestore Console

#### Crear primeras mesas:
```json
// empresas/{id}/mesas/mesa1
{
  "numero": 1,
  "nombre": "Mesa 1",
  "zona": "Salón",
  "capacidad": 4,
  "estado": "libre",
  "comanda_id": null,
  "camarero_uid": null,
  "fecha_apertura": null
}
```

#### Inicializar contador de tickets:
```json
// empresas/{id}/contadores/tickets
{
  "ultimo_numero": 0
}
```

---

## 📋 Checklist Final de Producción

Antes de activar en producción:

- [ ] Implementar selector de variantes
- [ ] Implementar contador secuencial de tickets
- [ ] Conectar impresión BT al cobro
- [ ] Implementar diálogo método de pago completo
- [ ] Añadir notas por línea (long press)
- [ ] Cargar datos reales en cierre de caja
- [ ] Añadir indicadores de conectividad real (wifi/BT)
- [ ] Probar flujo completo: abrir mesa → añadir productos → cobrar → imprimir
- [ ] Probar flujo caja rápida completo
- [ ] Probar en tablet real en paisaje
- [ ] Validar permisos Firestore con usuarios staff
- [ ] Documentar para el usuario final

---

*Documento generado: Mayo 2026*

