# 🚀 PLAN DE IMPLEMENTACIÓN: Facturación Automática TPV

> **Fecha inicio**: 20 Mayo 2026  
> **Duración estimada**: 2-3 semanas  
> **Prioridad**: ALTA  
> **Tipo**: Feature + Bug Fix

---

## 📋 RESUMEN

Implementar sistema de facturación automática para TPVs con dos modalidades:
- **Plan Básico**: Sin facturación automática (solo tickets)
- **Plan Premium**: Con facturación automática al cobrar

---

## 🎯 OBJETIVOS SMART

1. **Específico**: Cada cobro de mesa debe poder generar factura automática si está activado
2. **Medible**: 100% de cobros con facturación activada generan factura en <2seg
3. **Alcanzable**: Reutilizar código existente de `TpvFacturacionService`
4. **Relevante**: Diferenciador comercial entre planes Básico/Premium
5. **Temporal**: Completar en 15 días hábiles

---

## 📦 ENTREGABLES

- [x] Documento de análisis (ANALISIS_FACTURACION_TPV_AUTOMATICA_COMPLETO.md)
- [ ] Migración de colección `ventas` a `pedidos`
- [ ] Integración de facturación en `_confirmarCobro()`
- [ ] Pantalla de configuración de planes
- [ ] Cloud Function de resumen diario
- [ ] Tests de integración end-to-end
- [ ] Documentación de usuario final

---

## 🏗️ ARQUITECTURA DE LA SOLUCIÓN

### Diagrama de Flujo

```
┌─────────────────────────────────────────────────────────────┐
│                    COBRO DE MESA                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
          ┌───────────────────────┐
          │ ¿Método de pago OK?   │
          └─────────┬─────────────┘
                    │ Sí
                    ▼
          ┌───────────────────────┐
          │  Crear PEDIDO         │◄─── Unificar con colección pedidos
          │  (origen: presencial) │
          └─────────┬─────────────┘
                    │
                    ▼
          ┌───────────────────────┐
          │   Actualizar Caja     │
          └─────────┬─────────────┘
                    │
                    ▼
          ┌───────────────────────┐
          │    Liberar Mesa       │
          └─────────┬─────────────┘
                    │
                    ▼
          ┌───────────────────────┐
          │   Imprimir Ticket     │
          └─────────┬─────────────┘
                    │
                    ▼
      ┌─────────────────────────────────┐
      │  Leer ConfiguracionFacturacionTpv│
      └──────────┬──────────────────────┘
                 │
                 ▼
       ┌────────────────────┐
       │ ¿facturacionAutomatica?  │
       └────┬─────────┬─────┘
            │ NO      │ SÍ
            │         │
            ▼         ▼
       ┌────────┐  ┌──────────────────────┐
       │  FIN   │  │   ¿Modo facturación?  │
       └────────┘  └────┬─────────────────┘
                        │
              ┌─────────┴──────────┐
              │                    │
              ▼                    ▼
      ┌──────────────┐    ┌───────────────┐
      │  POR VENTA   │    │ RESUMEN DIARIO│
      │              │    │               │
      │ ↓ Generar    │    │ ↓ Espera a    │
      │   factura    │    │   Cloud Func. │
      │   ahora      │    │   23:30h      │
      └──────┬───────┘    └───────────────┘
             │
             ▼
    ┌────────────────────┐
    │ Generar Factura    │
    │ - Número correlativo│
    │ - IVA desglosado   │
    │ - Vincular pedido  │
    └──────┬─────────────┘
           │
           ▼
    ┌────────────────────┐
    │  ¿VeriFactu activo?│
    └──────┬─────────────┘
           │ SÍ
           ▼
    ┌────────────────────┐
    │ Registrar en AEAT  │
    │ (hash encadenado)  │
    └──────┬─────────────┘
           │
           ▼
       ┌────────┐
       │  FIN   │
       └────────┘
```

---

## 📝 TAREAS DETALLADAS

### SPRINT 1 (Semana 1): Fundación

#### Tarea 1.1: Actualizar Modelo Pedido
**Archivo**: `lib/domain/modelos/pedido.dart`  
**Tiempo estimado**: 2 horas  
**Prioridad**: CRÍTICA

**Cambios necesarios:**

```dart
class Pedido {
  // ...campos existentes...
  
  // 🆕 AGREGAR estos campos
  final double? propina;        // Propina del ticket
  final String? mesaId;         // ID de la mesa (si aplica)
  final String? mesaNombre;     // Nombre de la mesa (ej: "Mesa 5")
  final int? comensales;        // Número de comensales
  
  // Constructor actualizado
  const Pedido({
    // ...parámetros existentes...
    this.propina,
    this.mesaId,
    this.mesaNombre,
    this.comensales,
  });
  
  // Actualizar fromFirestore
  factory Pedido.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Pedido(
      // ...campos existentes...
      propina: (d['propina'] as num?)?.toDouble(),
      mesaId: d['mesa_id'],
      mesaNombre: d['mesa_nombre'],
      comensales: (d['comensales'] as num?)?.toInt(),
    );
  }
  
  // Actualizar toFirestore
  Map<String, dynamic> toFirestore() => {
    // ...campos existentes...
    'propina': propina,
    'mesa_id': mesaId,
    'mesa_nombre': mesaNombre,
    'comensales': comensales,
  };
  
  // Actualizar copyWith
  Pedido copyWith({
    // ...parámetros existentes...
    double? propina,
    String? mesaId,
    String? mesaNombre,
    int? comensales,
  }) => Pedido(
    // ...valores existentes...
    propina: propina ?? this.propina,
    mesaId: mesaId ?? this.mesaId,
    mesaNombre: mesaNombre ?? this.mesaNombre,
    comensales: comensales ?? this.comensales,
  );
}
```

**Checklist:**
- [ ] Añadir campos al modelo
- [ ] Actualizar `fromFirestore`
- [ ] Actualizar `toFirestore`
- [ ] Actualizar `copyWith`
- [ ] Ejecutar tests unitarios

---

#### Tarea 1.2: Refactorizar `_confirmarCobro()` para usar Pedidos
**Archivo**: `lib/features/tpv/widgets/tpv_bar_cobro.dart`  
**Tiempo estimado**: 4 horas  
**Prioridad**: CRÍTICA

**Código actual (líneas 349-454):**
```dart
Future<void> _confirmarCobro() async {
  // ...validaciones...
  
  final db = FirebaseFirestore.instance;
  final ventaId = db.collection('_temp').doc().id;

  // ❌ ANTIGUO: Crear venta en colección 'ventas'
  await db.collection('empresas').doc(widget.empresaId)
    .collection('ventas').doc(ventaId).set({ /* ... */ });
  
  // ...resto del proceso...
}
```

**Código nuevo (REEMPLAZAR):**

```dart
Future<void> _confirmarCobro() async {
  // Validar efectivo
  if (_metodoPago == 'efectivo') {
    final entregado = double.tryParse(_entregadoCtrl.text) ?? 0.0;
    if (entregado < (widget.total + _propina)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El efectivo entregado es insuficiente')),
      );
      return;
    }
  }

  setState(() => _procesando = true);

  try {
    // 🆕 Usar PedidosService
    final pedidosService = PedidosService();
    
    // Convertir líneas de comanda a líneas de pedido
    final lineasPedido = widget.lineas.map((lineaMap) {
      return LineaPedido(
        productoId: lineaMap['producto_id'] as String? ?? '',
        productoNombre: lineaMap['nombre'] as String? ?? '',
        cantidad: (lineaMap['cantidad'] as num?)?.toInt() ?? 1,
        precioUnitario: (lineaMap['precio_unitario'] as num?)?.toDouble() ?? 0.0,
        ivaPorcentaje: (lineaMap['iva_porcentaje'] as num?)?.toDouble() ?? 21.0,
        varianteId: lineaMap['variante_id'] as String?,
        varianteNombre: lineaMap['variante_nombre'] as String?,
        notasLinea: lineaMap['notas'] as String?,
      );
    }).toList();
    
    // Convertir método de pago
    MetodoPago metodoPago;
    switch (_metodoPago) {
      case 'efectivo':
        metodoPago = MetodoPago.efectivo;
        break;
      case 'tarjeta':
        metodoPago = MetodoPago.tarjeta;
        break;
      case 'bizum':
        metodoPago = MetodoPago.bizum;
        break;
      default:
        metodoPago = MetodoPago.efectivo;
    }
    
    // 🆕 CREAR PEDIDO (reemplaza creación de venta)
    final pedido = await pedidosService.crearPedido(
      empresaId: widget.empresaId,
      clienteNombre: widget.nombreMesa, // ej: "Mesa 5"
      lineas: lineasPedido,
      metodoPago: metodoPago,
      origen: OrigenPedido.presencial,  // ← Importante: marca como TPV
      estadoPago: EstadoPago.pagado,    // ← Ya está pagado
      propina: _propina,
      mesaId: widget.mesaId,
      mesaNombre: widget.nombreMesa,
      comensales: widget.comensales,
      importeEfectivo: _metodoPago == 'efectivo' 
        ? widget.total + _propina 
        : 0.0,
      importeTarjeta: _metodoPago == 'tarjeta' 
        ? widget.total + _propina 
        : _metodoPago == 'bizum'
          ? widget.total + _propina
          : 0.0,
      notasInternas: 'Cobro TPV - Mesa: ${widget.nombreMesa}, Comensales: ${widget.comensales}',
    );

    // 🆕 FACTURACIÓN AUTOMÁTICA (si está activada)
    try {
      final tpvFacturacionService = TpvFacturacionService();
      final config = await tpvFacturacionService.obtenerConfig(widget.empresaId);
      
      if (config.facturacionAutomatica && 
          config.modo == ModoFacturacionTpv.porVenta) {
        // Modo: Factura por cada venta
        await tpvFacturacionService.generarFacturaPorPedido(
          empresaId: widget.empresaId,
          pedido: pedido,
          config: config,
          usuarioNombre: 'TPV Auto',
        );
        
        if (!mounted) return;
        // Notificar al usuario (opcional)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Factura generada automáticamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      // Nota: Si modo == resumenDiario, la factura se genera por Cloud Function
    } catch (e) {
      // ⚠️ IMPORTANTE: No bloquear el cobro si falla la facturación
      debugPrint('⚠️ Error en facturación automática: $e');
      // Log del error para revisión posterior
      await FirebaseFirestore.instance
        .collection('_logs_facturacion_errores')
        .add({
          'pedido_id': pedido.id,
          'empresa_id': widget.empresaId,
          'error': e.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });
    }

    // Actualizar caja diaria (igual que antes)
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final cajaRef = FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaId)
      .collection('caja_diaria')
      .doc(hoy);
    
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final cajaDoc = await transaction.get(cajaRef);
      
      if (!cajaDoc.exists) {
        transaction.set(cajaRef, {
          'fecha': hoy,
          'total_efectivo': _metodoPago == 'efectivo' ? widget.total + _propina : 0.0,
          'total_tarjeta': _metodoPago == 'tarjeta' ? widget.total + _propina : 0.0,
          'total_bizum': _metodoPago == 'bizum' ? widget.total + _propina : 0.0,
          'total_propinas': _propina,
          'num_tickets': 1,
          'abierta': true,
        });
      } else {
        final data = cajaDoc.data()!;
        transaction.update(cajaRef, {
          'total_efectivo': (data['total_efectivo'] ?? 0.0) + 
            (_metodoPago == 'efectivo' ? widget.total + _propina : 0.0),
          'total_tarjeta': (data['total_tarjeta'] ?? 0.0) + 
            (_metodoPago == 'tarjeta' ? widget.total + _propina : 0.0),
          'total_bizum': (data['total_bizum'] ?? 0.0) + 
            (_metodoPago == 'bizum' ? widget.total + _propina : 0.0),
          'total_propinas': (data['total_propinas'] ?? 0.0) + _propina,
          'num_tickets': (data['num_tickets'] ?? 0) + 1,
        });
      }
    });

    // Liberar mesa (igual que antes)
    await FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaId)
      .collection('mesas')
      .doc(widget.mesaId)
      .update({
        'estado': 'libre',
        'comensales_actuales': 0,
      });

    // Eliminar comanda (igual que antes)
    final comandasSnap = await FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaId)
      .collection('comandas')
      .where('mesa_id', isEqualTo: widget.mesaId)
      .get();

    for (var doc in comandasSnap.docs) {
      await doc.reference.delete();
    }

    if (!mounted) return;

    // Imprimir ticket (igual que antes)
    await _imprimirTicket(pedido.id);

    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Cobro realizado con éxito'),
        backgroundColor: Color(0xFF00FFC8),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) setState(() => _procesando = false);
  }
}
```

**Imports necesarios:**
```dart
import '../../../services/pedidos_service.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../domain/modelos/configuracion_facturacion_tpv.dart';
```

**Checklist:**
- [ ] Importar servicios necesarios
- [ ] Reemplazar creación de venta por pedido
- [ ] Añadir lógica de facturación condicional
- [ ] Mantener lógica de caja, mesa y comanda
- [ ] Añadir manejo de errores sin bloqueo
- [ ] Probar flujo completo

---

#### Tarea 1.3: Actualizar `_imprimirTicket()`
**Archivo**: `lib/features/tpv/widgets/tpv_bar_cobro.dart`  
**Tiempo estimado**: 1 hora  
**Prioridad**: MEDIA

**Cambio necesario:**

```dart
// ANTES
Future<void> _imprimirTicket(String ventaId) async {
  // ...imprimir ticket...
}

// DESPUÉS
Future<void> _imprimirTicket(String pedidoId) async {
  final pdf = pw.Document();
  final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
  
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'TICKET DE VENTA',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('Pedido: $pedidoId', style: pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text(widget.nombreMesa)),
            pw.Divider(),
            // ...resto igual...
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (_) => pdf.save());
}
```

**Checklist:**
- [ ] Cambiar parámetro de `ventaId` a `pedidoId`
- [ ] Actualizar todas las llamadas a `_imprimirTicket()`
- [ ] Probar impresión

---

### SPRINT 2 (Semana 2): Configuración y UI

#### Tarea 2.1: Crear Pantalla de Configuración

**Archivo nuevo**: `lib/features/configuracion/pantallas/configuracion_facturacion_screen.dart`  
**Tiempo estimado**: 6 horas  
**Prioridad**: ALTA

```dart
import 'package:flutter/material.dart';
import '../../../domain/modelos/configuracion_facturacion_tpv.dart';
import '../../../services/tpv_facturacion_service.dart';

class ConfiguracionFacturacionScreen extends StatefulWidget {
  final String empresaId;
  
  const ConfiguracionFacturacionScreen({
    super.key,
    required this.empresaId,
  });

  @override
  State<ConfiguracionFacturacionScreen> createState() =>
      _ConfiguracionFacturacionScreenState();
}

class _ConfiguracionFacturacionScreenState
    extends State<ConfiguracionFacturacionScreen> {
  final TpvFacturacionService _service = TpvFacturacionService();
  
  ConfiguracionFacturacionTpv? _config;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarConfig();
  }

  Future<void> _cargarConfig() async {
    try {
      final config = await _service.obtenerConfig(widget.empresaId);
      setState(() {
        _config = config;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar configuración: $e')),
      );
    }
  }

  Future<void> _guardarConfig() async {
    if (_config == null) return;
    
    setState(() => _guardando = true);
    try {
      await _service.guardarConfig(widget.empresaId, _config!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configuración guardada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Facturación'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          if (!_cargando && !_guardando)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _guardarConfig,
              tooltip: 'Guardar cambios',
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _config == null
              ? const Center(child: Text('Error al cargar configuración'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildPlanSelector(),
                    const SizedBox(height: 24),
                    if (_config!.facturacionAutomatica) ...[
                      _buildConfiguracionAvanzada(),
                    ],
                  ],
                ),
    );
  }

  Widget _buildPlanSelector() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFF1565C0), size: 28),
                const SizedBox(width: 12),
                Text(
                  'Plan de Facturación',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Plan Básico
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: !_config!.facturacionAutomatica
                      ? const Color(0xFF1565C0)
                      : Colors.grey.shade300,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
                color: !_config!.facturacionAutomatica
                    ? const Color(0xFF1565C0).withOpacity(0.1)
                    : null,
              ),
              child: RadioListTile<bool>(
                value: false,
                groupValue: _config!.facturacionAutomatica,
                onChanged: (val) {
                  setState(() {
                    _config = _config!.copyWith(facturacionAutomatica: val);
                  });
                },
                title: const Text(
                  '💼 Plan Básico',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'TPV con tickets. Facturación manual cuando la necesites.',
                  style: TextStyle(fontSize: 13),
                ),
                secondary: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Incluido',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Plan Premium
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _config!.facturacionAutomatica
                      ? const Color(0xFFFF9800)
                      : Colors.grey.shade300,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _config!.facturacionAutomatica
                    ? const Color(0xFFFF9800).withOpacity(0.1)
                    : null,
              ),
              child: RadioListTile<bool>(
                value: true,
                groupValue: _config!.facturacionAutomatica,
                onChanged: (val) {
                  setState(() {
                    _config = _config!.copyWith(facturacionAutomatica: val);
                  });
                },
                title: const Row(
                  children: [
                    Text(
                      '⭐ Plan Premium',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.auto_awesome, color: Color(0xFFFF9800), size: 20),
                  ],
                ),
                subtitle: const Text(
                  'Facturación automática + VeriFactu + Declaraciones fiscales',
                  style: TextStyle(fontSize: 13),
                ),
                secondary: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '+50€/mes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguracionAvanzada() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración Avanzada',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            
            // Modo de facturación
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo de Facturación'),
              subtitle: Text(_config!.modo.nombre),
              trailing: DropdownButton<ModoFacturacionTpv>(
                value: _config!.modo,
                items: ModoFacturacionTpv.values.map((modo) {
                  return DropdownMenuItem(
                    value: modo,
                    child: Text(modo.nombre),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _config = _config!.copyWith(modo: val);
                    });
                  }
                },
              ),
            ),
            const Divider(),
            
            // Hora de generación (solo si resumen diario)
            if (_config!.modo == ModoFacturacionTpv.resumenDiario) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora de Generación Diaria'),
                subtitle: Text(
                  '${_config!.horaGeneracion.hour.toString().padLeft(2, '0')}:'
                  '${_config!.horaGeneracion.minute.toString().padLeft(2, '0')}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final hora = await showTimePicker(
                      context: context,
                      initialTime: _config!.horaGeneracion,
                    );
                    if (hora != null) {
                      setState(() {
                        _config = _config!.copyWith(horaGeneracion: hora);
                      });
                    }
                  },
                  child: const Text('Cambiar'),
                ),
              ),
              const Divider(),
            ],
            
            // VeriFactu
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activar VeriFactu'),
              subtitle: const Text('Registro automático en AEAT (obligatorio >6M€)'),
              value: _config!.aplicarVeriFactu,
              onChanged: (val) {
                setState(() {
                  _config = _config!.copyWith(aplicarVeriFactu: val);
                });
              },
            ),
            const Divider(),
            
            // Serie de facturación
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Serie de Facturación'),
              subtitle: Text('Ej: ${_config!.serieFactura}2026-0001'),
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  controller: TextEditingController(text: _config!.serieFactura),
                  onChanged: (val) {
                    setState(() {
                      _config = _config!.copyWith(serieFactura: val);
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'TPV-',
                    isDense: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Checklist:**
- [ ] Crear archivo
- [ ] Implementar UI de planes
- [ ] Conectar con `TpvFacturacionService`
- [ ] Validar guardado
- [ ] Probar cambios de configuración

---

#### Tarea 2.2: Añadir Navegación a Configuración

**Archivo**: Menú principal o configuración general  
**Tiempo estimado**: 30 minutos  
**Prioridad**: MEDIA

Añadir botón/tile para acceder a la nueva pantalla:

```dart
ListTile(
  leading: const Icon(Icons.receipt_long),
  title: const Text('Facturación TPV'),
  subtitle: const Text('Configurar facturación automática'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfiguracionFacturacionScreen(empresaId: empresaId),
      ),
    );
  },
),
```

---

### SPRINT 3 (Semana 3): Cloud Function y Testing

#### Tarea 3.1: Crear Cloud Function para Resumen Diario

**Archivo nuevo**: `functions/src/generarFacturasTPVDiarias.ts`  
**Tiempo estimado**: 4 horas  
**Prioridad**: ALTA

```typescript
import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';

/**
 * Cloud Function programada que genera facturas resumen diarias para
 * empresas con facturación automática activada en modo resumenDiario.
 * 
 * Se ejecuta todos los días a las 23:30 (hora de Madrid).
 */
export const generarFacturasTPVDiarias = functions.scheduler.onSchedule({
  schedule: '30 23 * * *',
  timeZone: 'Europe/Madrid',
  memory: '512MiB',
  timeoutSeconds: 540,
  retryConfig: {
    retryCount: 3,
    maxRetryDuration: '600s',
  },
}, async (event) => {
  const db = admin.firestore();
  
  console.log('🚀 Iniciando generación de facturas TPV diarias...');
  
  try {
    // Obtener todas las empresas
    const empresasSnap = await db.collection('empresas').get();
    
    let procesadas = 0;
    let exitosas = 0;
    let fallos = 0;
    
    for (const empresaDoc of empresasSnap.docs) {
      const empresaId = empresaDoc.id;
      
      try {
        // Verificar configuración de facturación
        const configDoc = await db
          .collection('empresas').doc(empresaId)
          .collection('configuracion').doc('facturacionTpv')
          .get();
        
        if (!configDoc.exists) {
          console.log(`⏭️  Empresa ${empresaId}: sin configuración, saltando`);
          continue;
        }
        
        const config = configDoc.data()!;
        
        // Filtros:
        // 1. Facturación automática activada
        // 2. Modo resumen diario
        if (!config.facturacion_automatica) {
          console.log(`⏭️  Empresa ${empresaId}: facturación no automática`);
          continue;
        }
        
        if (config.modo !== 'resumenDiario') {
          console.log(`⏭️  Empresa ${empresaId}: modo != resumenDiario (${config.modo})`);
          continue;
        }
        
        procesadas++;
        
        // Obtener pedidos TPV del día
        const hoy = new Date();
        const inicioHoy = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 0, 0, 0);
        const finHoy = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 23, 59, 59);
        
        const pedidosSnap = await db
          .collection('empresas').doc(empresaId)
          .collection('pedidos')
          .where('origen', '==', 'presencial')  // Solo TPV
          .where('estado_pago', '==', 'pagado')
          .where('fecha_creacion', '>=', admin.firestore.Timestamp.fromDate(inicioHoy))
          .where('fecha_creacion', '<=', admin.firestore.Timestamp.fromDate(finHoy))
          .get();
        
        // Filtrar los que NO tienen factura
        const pedidosSinFactura = pedidosSnap.docs.filter(doc => {
          const data = doc.data();
          return !data.factura_id;
        });
        
        if (pedidosSinFactura.length === 0) {
          console.log(`✅ Empresa ${empresaId}: 0 pedidos pendientes de facturar`);
          continue;
        }
        
        console.log(`📋 Empresa ${empresaId}: ${pedidosSinFactura.length} pedidos pendientes`);
        
        // Agrupar líneas
        const todasLasLineas: any[] = [];
        const pedidosIds: string[] = [];
        
        for (const pedidoDoc of pedidosSinFactura) {
          const pedido = pedidoDoc.data();
          pedidosIds.push(pedidoDoc.id);
          
          if (pedido.lineas && Array.isArray(pedido.lineas)) {
            todasLasLineas.push(...pedido.lineas);
          }
        }
        
        // Generar factura resumen
        const fechaStr = `${hoy.getDate().toString().padLeft(2, '0')}/${(hoy.getMonth() + 1).toString().padLeft(2, '0')}/${hoy.getFullYear()}`;
        
        // Crear documento de factura
        const facturaRef = db
          .collection('empresas').doc(empresaId)
          .collection('facturas')
          .doc();
        
        // Calcular totales
        let subtotal = 0;
        let totalIva = 0;
        
        const lineasFactura = todasLasLineas.map(l => {
          const precioUnitario = l.precio_unitario || 0;
          const cantidad = l.cantidad || 1;
          const ivaPorcentaje = l.iva_porcentaje || 21;
          
          const subtotalLinea = precioUnitario * cantidad;
          const ivaLinea = subtotalLinea * (ivaPorcentaje / 100);
          
          subtotal += subtotalLinea;
          totalIva += ivaLinea;
          
          return {
            descripcion: l.producto_nombre || 'Producto',
            precio_unitario: precioUnitario,
            cantidad: cantidad,
            porcentaje_iva: ivaPorcentaje,
            descuento: 0,
            recargo_equivalencia: 0,
          };
        });
        
        const total = subtotal + totalIva;
        
        // Obtener número de factura (simplificado - en producción usar transacción)
        const contadorRef = db
          .collection('empresas').doc(empresaId)
          .collection('configuracion').doc('facturacion');
        
        const contadorDoc = await contadorRef.get();
        const ultimoNumero = contadorDoc.exists 
          ? (contadorDoc.data()!.ultimo_numero_fac || 0)
          : 0;
        const nuevoNumero = ultimoNumero + 1;
        
        await contadorRef.set({
          ultimo_numero_fac: nuevoNumero,
          anio_ultimo_fac: hoy.getFullYear(),
        }, { merge: true });
        
        const numeroFactura = `F-${hoy.getFullYear()}-${nuevoNumero.toString().padStart(4, '0')}`;
        
        // Guardar factura
        await facturaRef.set({
          empresa_id: empresaId,
          numero_factura: numeroFactura,
          serie: 'fac',
          tipo: 'venta_directa',
          estado: 'pagada',
          cliente_nombre: `Ventas TPV — ${fechaStr}`,
          lineas: lineasFactura,
          subtotal,
          total_iva: totalIva,
          total,
          descuento_global: 0,
          importe_descuento_global: 0,
          porcentaje_irpf: 0,
          retencion_irpf: 0,
          total_recargo_equivalencia: 0,
          dias_vencimiento: 0,
          notas_internas: `Resumen diario TPV: ${pedidosSinFactura.length} ventas`,
          historial: [{
            usuario_id: 'sistema',
            usuario_nombre: 'Cloud Function Auto',
            accion: 'creada',
            descripcion: 'Factura resumen diaria generada automáticamente',
            fecha: FieldValue.serverTimestamp(),
          }],
          fecha_emision: FieldValue.serverTimestamp(),
          fecha_pago: FieldValue.serverTimestamp(),
          fecha_actualizacion: FieldValue.serverTimestamp(),
        });
        
        // Actualizar todos los pedidos con el facturaId
        const batch = db.batch();
        for (const pedidoId of pedidosIds) {
          const pedidoRef = db
            .collection('empresas').doc(empresaId)
            .collection('pedidos').doc(pedidoId);
          
          batch.update(pedidoRef, {
            factura_id: facturaRef.id,
            fecha_actualizacion: FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        
        console.log(`✅ Empresa ${empresaId}: Factura ${numeroFactura} generada con ${lineasFactura.length} líneas`);
        exitosas++;
        
      } catch (error: any) {
        console.error(`❌ Error en empresa ${empresaId}:`, error);
        fallos++;
        
        // Log del error para debugging
        await db.collection('_logs_facturacion_errores').add({
          empresa_id: empresaId,
          error: error.message || String(error),
          timestamp: FieldValue.serverTimestamp(),
          tipo: 'cloud_function_resumen_diario',
        });
      }
    }
    
    console.log(`
    📊 RESUMEN:
    - Empresas procesadas: ${procesadas}
    - Facturas generadas: ${exitosas}
    - Fallos: ${fallos}
    `);
    
  } catch (error) {
    console.error('❌ Error general en generación de facturas:', error);
    throw error;
  }
});
```

**Checklist:**
- [ ] Crear archivo TypeScript
- [ ] Configurar schedule en Firebase Console
- [ ] Desplegar función: `firebase deploy --only functions:generarFacturasTPVDiarias`
- [ ] Verificar logs en Cloud Functions
- [ ] Probar ejecución manual

---

#### Tarea 3.2: Tests de Integración End-to-End

**Archivo nuevo**: `test/integration/facturacion_automatica_test.dart`  
**Tiempo estimado**: 4 horas  
**Prioridad**: ALTA

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:planeag_flutter/services/tpv_facturacion_service.dart';
import 'package:planeag_flutter/services/pedidos_service.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/domain/modelos/configuracion_facturacion_tpv.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late TpvFacturacionService tpvFactService;
  late PedidosService pedidosService;
  
  const empresaId = 'test_empresa_123';
  
  setUp(() {
    firestore = FakeFirebaseFirestore();
    // Configurar servicios con Firestore fake
    // ...
  });
  
  group('Facturación Automática - Plan Básico', () {
    test('Cobro sin facturación automática NO genera factura', () async {
      // GIVEN: Configuración con facturacionAutomatica: false
      final config = ConfiguracionFacturacionTpv(
        facturacionAutomatica: false,
        modo: ModoFacturacionTpv.manual,
      );
      await tpvFactService.guardarConfig(empresaId, config);
      
      // WHEN: Se crea un pedido TPV
      final pedido = await pedidosService.crearPedido(
        empresaId: empresaId,
        clienteNombre: 'Mesa 5',
        lineas: [/* ... */],
        metodoPago: MetodoPago.efectivo,
        origen: OrigenPedido.presencial,
        estadoPago: EstadoPago.pagado,
      );
      
      // THEN: NO se ha generado factura
      expect(pedido.facturaId, isNull);
      
      // Verificar que no hay facturas en Firestore
      final facturasSnap = await firestore
        .collection('empresas/$empresaId/facturas')
        .get();
      expect(facturasSnap.docs, isEmpty);
    });
  });
  
  group('Facturación Automática - Plan Premium (Por Venta)', () {
    test('Cobro con facturación activada genera factura inmediata', () async {
      // GIVEN: Configuración con facturacionAutomatica: true, modo: porVenta
      final config = ConfiguracionFacturacionTpv(
        facturacionAutomatica: true,
        modo: ModoFacturacionTpv.porVenta,
        serieFactura: 'TPV-',
        aplicarVeriFactu: false, // Desactivado para test
      );
      await tpvFactService.guardarConfig(empresaId, config);
      
      // WHEN: Se crea un pedido y se factura
      final pedido = await pedidosService.crearPedido(
        empresaId: empresaId,
        clienteNombre: 'Mesa 5',
        lineas: [
          LineaPedido(
            productoId: 'prod1',
            productoNombre: 'Café',
            cantidad: 2,
            precioUnitario: 1.50,
            ivaPorcentaje: 10.0,
          ),
        ],
        metodoPago: MetodoPago.tarjeta,
        origen: OrigenPedido.presencial,
        estadoPago: EstadoPago.pagado,
      );
      
      // Simular llamada a facturación automática
      final factura = await tpvFactService.generarFacturaPorPedido(
        empresaId: empresaId,
        pedido: pedido,
        config: config,
        usuarioNombre: 'TPV Auto',
      );
      
      // THEN: Se ha generado factura
      expect(factura, isNotNull);
      expect(factura.numeroFactura, startsWith('TPV-'));
      expect(factura.clienteNombre, equals('Mesa 5'));
      expect(factura.lineas.length, equals(1));
      expect(factura.lineas.first.descripcion, equals('Café'));
    });
  });
  
  group('Facturación Automática - Plan Premium (Resumen Diario)', () {
    test('Resumen diario agrupa todos los pedidos del día', () async {
      // GIVEN: Configuración resumen diario
      final config = ConfiguracionFacturacionTpv(
        facturacionAutomatica: true,
        modo: ModoFacturacionTpv.resumenDiario,
        horaGeneracion: TimeOfDay(hour: 23, minute: 30),
      );
      await tpvFactService.guardarConfig(empresaId, config);
      
      // Crear 3 pedidos del día
      final pedidos = <Pedido>[];
      for (int i = 1; i <= 3; i++) {
        final pedido = await pedidosService.crearPedido(
          empresaId: empresaId,
          clienteNombre: 'Mesa $i',
          lineas: [/* ... */],
          metodoPago: MetodoPago.efectivo,
          origen: OrigenPedido.presencial,
          estadoPago: EstadoPago.pagado,
        );
        pedidos.add(pedido);
      }
      
      // WHEN: Se genera el resumen diario
      final fecha = DateTime.now();
      final factura = await tpvFactService.generarFacturaResumenDiario(
        empresaId: empresaId,
        fecha: fecha,
        config: config,
        usuarioNombre: 'Cloud Function',
      );
      
      // THEN: Se ha generado UNA factura con todos los pedidos
      expect(factura, isNotNull);
      expect(factura!.clienteNombre, contains('Ventas TPV'));
      
      // Verificar que todos los pedidos tienen facturaId
      for (final pedido in pedidos) {
        final pedidoActualizado = await pedidosService.obtenerPedido(
          empresaId,
          pedido.id,
        );
        expect(pedidoActualizado.facturaId, equals(factura.id));
      }
    });
  });
}
```

**Checklist:**
- [ ] Crear archivo de tests
- [ ] Implementar tests Plan Básico
- [ ] Implementar tests Plan Premium (por venta)
- [ ] Implementar tests Plan Premium (resumen diario)
- [ ] Ejecutar: `flutter test test/integration/facturacion_automatica_test.dart`
- [ ] Verificar 100% de tests passing

---

### Tareas Adicionales (Opcionales/Mejoras)

#### Tarea Extra 1: Script de Migración de Datos

**Archivo nuevo**: `scripts/migrar_ventas_a_pedidos.dart`  
**Tiempo estimado**: 3 horas  
**Prioridad**: MEDIA (solo si hay datos en `ventas`)

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script para migrar documentos de colección 'ventas' a 'pedidos'
/// USAR CON PRECAUCIÓN - Hacer backup antes
Future<void> main() async {
  await Firebase.initializeApp();
  final db = FirebaseFirestore.instance;
  
  print('🔍 Buscando empresas con ventas...');
  
  final empresasSnap = await db.collection('empresas').get();
  
  for (final empresaDoc in empresasSnap.docs) {
    final empresaId = empresaDoc.id;
    print('\n📋 Procesando empresa: $empresaId');
    
    final ventasSnap = await db
      .collection('empresas/$empresaId/ventas')
      .get();
    
    if (ventasSnap.docs.isEmpty) {
      print('   ✅ Sin ventas, saltando');
      continue;
    }
    
    print('   📦 ${ventasSnap.docs.length} ventas encontradas');
    
    int migradas = 0;
    int errores = 0;
    
    for (final ventaDoc in ventasSnap.docs) {
      try {
        final venta = ventaDoc.data();
        
        // Convertir venta a pedido
        final pedidoData = {
          'empresa_id': empresaId,
          'cliente_nombre': venta['mesa_nombre'] ?? 'Venta TPV',
          'lineas': _convertirLineas(venta['lineas'] ?? []),
          'metodo_pago': _convertirMetodoPago(venta['metodo_pago']),
          'origen': 'presencial',
          'estado_pago': 'pagado',
          'propina': venta['propina'] ?? 0.0,
          'mesa_id': venta['mesa_id'],
          'mesa_nombre': venta['mesa_nombre'],
          'comensales': venta['comensales'],
          'importe_efectivo': venta['entregado'] ?? 0.0,
          'importe_total': venta['total'] ?? 0.0,
          'fecha_creacion': venta['fecha'] ?? FieldValue.serverTimestamp(),
          'fecha_actualizacion': FieldValue.serverTimestamp(),
          '_migrado_de_venta': true,  // Flag para tracking
          '_venta_id_original': ventaDoc.id,
        };
        
        // Crear pedido
        await db
          .collection('empresas/$empresaId/pedidos')
          .doc(ventaDoc.id)  // Mantener mismo ID
          .set(pedidoData);
        
        migradas++;
        
      } catch (e) {
        print('   ❌ Error en venta ${ventaDoc.id}: $e');
        errores++;
      }
    }
    
    print('   ✅ Migradas: $migradas');
    print('   ❌ Errores: $errores');
  }
  
  print('\n✅ Migración completada');
}

List<Map<String, dynamic>> _convertirLineas(List<dynamic> lineasVenta) {
  return lineasVenta.map((l) {
    final linea = l as Map<String, dynamic>;
    return {
      'producto_id': linea['producto_id'] ?? '',
      'producto_nombre': linea['nombre'] ?? '',
      'cantidad': linea['cantidad'] ?? 1,
      'precio_unitario': linea['precio'] ?? 0.0,
      'iva_porcentaje': linea['iva_porcentaje'] ?? 21.0,
    };
  }).toList();
}

String _convertirMetodoPago(dynamic metodo) {
  final metodStr = metodo?.toString() ?? 'efectivo';
  switch (metodStr) {
    case 'tarjeta': return 'tarjeta';
    case 'bizum': return 'bizum';
    case 'paypal': return 'paypal';
    default: return 'efectivo';
  }
}
```

**Ejecución:**
```bash
dart scripts/migrar_ventas_a_pedidos.dart
```

---

#### Tarea Extra 2: Pantalla de Monitoreo

**Archivo nuevo**: `lib/features/facturacion/pantallas/monitor_facturacion_screen.dart`  
**Tiempo estimado**: 4 horas  
**Prioridad**: BAJA

Pantalla para mostrar:
- Estado actual del plan (Básico/Premium)
- Pedidos pendientes de facturar (si modo manual)
- Últimas facturas generadas
- Estado VeriFactu de cada factura
- Botón para generar factura manual

---

## 📊 DEFINICIÓN DE ÉXITO (DoD)

### Criterios de Aceptación

✅ **Funcional:**
- [ ] Plan Básico: Cobros NO generan factura
- [ ] Plan Premium (Por Venta): Cobros generan factura inmediata
- [ ] Plan Premium (Resumen): Cloud Function genera factura a las 23:30
- [ ] Pedidos quedan vinculados a factura (campo `facturaId`)
- [ ] VeriFactu se registra automáticamente (si activo)
- [ ] Errores de facturación NO bloquean cobros

✅ **Técnico:**
- [ ] Colección `ventas` unificada con `pedidos`
- [ ] Modelo `Pedido` actualizado con campos TPV
- [ ] Tests de integración passing (100%)
- [ ] Cloud Function desplegada y probada
- [ ] Logs de errores en Firestore

✅ **UI/UX:**
- [ ] Pantalla de configuración intuitiva
- [ ] Feedback visual al activar/desactivar plan
- [ ] Notificaciones de factura generada (opcional)
- [ ] No degrada experiencia del usuario

---

## 🎯 KPIs DEL PROYECTO

| Métrica | Objetivo | Método de Medición |
|---------|----------|-------------------|
| **Tiempo de facturación** | < 2 segundos | Logs de rendimiento |
| **Tasa de error** | < 1% | Logs de errores / total cobros |
| **Adopción Plan Premium** | 40% usuarios en 3 meses | Analytics |
| **Satisfacción usuario** | NPS > 70 | Encuesta post-implementación |

---

## 📅 CRONOGRAMA GANTT

```
Semana 1: Fundación
├─ Lun-Mar: Actualizar modelo Pedido + Tests
├─ Mié-Jue: Refactorizar _confirmarCobro()
└─ Vie: Tests de integración Sprint 1

Semana 2: Configuración
├─ Lun-Mar: Crear pantalla configuración
├─ Mié: Añadir navegación
├─ Jue: Tests UI
└─ Vie: Review y ajustes

Semana 3: Cloud + Deploy
├─ Lun-Mar: Cloud Function resumen diario
├─ Mié: Tests e2e completos
├─ Jue: Deploy staging + QA
└─ Vie: Deploy producción + Monitoreo

Semana 4 (Buffer): Documentación y mejoras
```

---

## 🚨 RIESGOS Y CONTINGENCIAS

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Datos existentes en `ventas` | Alta | Alto | Script de migración + Rollback plan |
| Fallo facturación bloquea cobros | Media | Crítico | Try-catch sin bloqueo + Logs |
| VeriFactu rechaza facturas | Baja | Medio | Validación previa + Reintentos |
| Cloud Function falla | Baja | Alto | Monitoring + Alertas + Manual fallback |

---

## ✅ CHECKLIST FINAL PRE-DEPLOY

**Antes de desplegar a producción:**

- [ ] Todos los tests passing (unit + integration + e2e)
- [ ] Code review aprobado por al menos 2 personas
- [ ] Documentación actualizada
- [ ] Script de migración probado en staging
- [ ] Cloud Function desplegada y validada en staging
- [ ] Rollback plan documentado
- [ ] Backup de colecciones críticas
- [ ] Monitoring configurado (logs, alertas)
- [ ] Plan de comunicación a usuarios (changelog, email)
- [ ] QA sign-off

---

## 📚 RECURSOS Y REFERENCIAS

### Documentación Interna
- `ANALISIS_FACTURACION_TPV_AUTOMATICA_COMPLETO.md` ← Este documento maestro
- `AUDITORIA_FLUJO_FACTURACION_TPV_COMPLETA.md`
- `GUIA_TPV_MULTI_SECTOR.md`

### Documentación Externa
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Firestore Batched Writes](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Flutter Testing](https://docs.flutter.dev/testing)

### Normativa Fiscal
- RD 1619/2012 (Facturación)
- RD 1007/2023 (VeriFactu)

---

## 📞 CONTACTOS DEL EQUIPO

| Rol | Responsable | Contacto |
|-----|-------------|----------|
| Product Owner | [Nombre] | [Email] |
| Tech Lead | [Nombre] | [Email] |
| QA Lead | [Nombre] | [Email] |
| DevOps | [Nombre] | [Email] |

---

**Última actualización**: 20 Mayo 2026  
**Versión**: 1.0  
**Estado**: ✅ LISTO PARA IMPLEMENTACIÓN

---

## 📝 LOG DE CAMBIOS

| Fecha | Versión | Cambios |
|-------|---------|---------|
| 20/05/2026 | 1.0 | Documento inicial creado |

---

**¡Éxito en la implementación! 🚀**

