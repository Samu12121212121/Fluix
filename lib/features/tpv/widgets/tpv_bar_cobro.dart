import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/tpv_facturacion_service.dart';
import 'package:planeag_flutter/core/config/planes_config.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA: COBRO CON MÉTODOS DE PAGO
// ═════════════════════════════════════════════════════════════════════════════

Future<void> mostrarPantallaCobro(
  BuildContext context,
  String empresaId,
  String mesaId,
  String nombreMesa,
  List<Map<String, dynamic>> lineas,
  double total,
  int comensales,
) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PantallaCobro(
      empresaId: empresaId,
      mesaId: mesaId,
      nombreMesa: nombreMesa,
      lineas: lineas,
      total: total,
      comensales: comensales,
    ),
  );
}

class _PantallaCobro extends StatefulWidget {
  final String empresaId;
  final String mesaId;
  final String nombreMesa;
  final List<Map<String, dynamic>> lineas;
  final double total;
  final int comensales;

  const _PantallaCobro({
    required this.empresaId,
    required this.mesaId,
    required this.nombreMesa,
    required this.lineas,
    required this.total,
    required this.comensales,
  });

  @override
  State<_PantallaCobro> createState() => _PantallaCobroState();
}

class _PantallaCobroState extends State<_PantallaCobro> {
  final _entregadoCtrl = TextEditingController();
  final _propinaCtrl = TextEditingController();
  
  String _metodoPago = 'efectivo';
  double _propina = 0.0;
  bool _procesando = false;

  double get _cambio {
    if (_metodoPago != 'efectivo') return 0.0;
    final entregado = double.tryParse(_entregadoCtrl.text) ?? 0.0;
    final totalConPropina = widget.total + _propina;
    return (entregado - totalConPropina).clamp(0.0, double.infinity);
  }

  @override
  void dispose() {
    _entregadoCtrl.dispose();
    _propinaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F23),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFC8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.point_of_sale, color: Color(0xFF00FFC8)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cobrar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${widget.nombreMesa} • ${widget.comensales} personas',
                        style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _procesando ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Desglose
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2139),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal', style: TextStyle(color: Color(0xFFB0B3C1))),
                      Text(fmt.format(widget.total), style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                  if (_propina > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Propina', style: TextStyle(color: Color(0xFFB0B3C1))),
                        Text(fmt.format(_propina), style: const TextStyle(color: Color(0xFF00FFC8), fontSize: 16)),
                      ],
                    ),
                  ],
                  const Divider(height: 24, color: Color(0xFF2A2E45)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL', style:TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                      Text(
                        fmt.format(widget.total + _propina),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Color(0xFF00FFC8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Propina
            TextField(
              controller: _propinaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) {
                setState(() => _propina = double.tryParse(val) ?? 0.0);
              },
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Propina (opcional)',
                labelStyle: TextStyle(color: Color(0xFFB0B3C1)),
                hintText: '0.00',
                hintStyle: TextStyle(color: Color(0xFF6B6E82)),
                prefixIcon: Icon(Icons.volunteer_activism, color: Color(0xFFFF3296)),
                suffixText: '€',
                suffixStyle: TextStyle(color: Color(0xFFB0B3C1)),
                filled: true,
                fillColor: Color(0xFF1E2139),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [1.0, 2.0, 5.0, 10.0].map((val) {
                return ActionChip(
                  label: Text('$val €'),
                  onPressed: () {
                    setState(() {
                      _propina = val;
                      _propinaCtrl.text = val.toString();
                    });
                  },
                  backgroundColor: const Color(0xFF1E2139),
                  labelStyle: const TextStyle(color: Color(0xFFFF3296)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Método de pago
            const Text('Método de pago', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetodoPagoChip(
                    icono: Icons.payments,
                    label: 'Efectivo',
                    color: const Color(0xFF00FFC8),
                    seleccionado: _metodoPago == 'efectivo',
                    onTap: () => setState(() => _metodoPago = 'efectivo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetodoPagoChip(
                    icono: Icons.credit_card,
                    label: 'Tarjeta',
                    color: const Color(0xFFFF3296),
                    seleccionado: _metodoPago == 'tarjeta',
                    onTap: () => setState(() => _metodoPago = 'tarjeta'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetodoPagoChip(
                    icono: Icons.qr_code,
                    label: 'QR/Bizum',
                    color: const Color(0xFFFF4678),
                    seleccionado: _metodoPago == 'bizum',
                    onTap: () => setState(() => _metodoPago = 'bizum'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Efectivo: entregado y cambio
            if (_metodoPago == 'efectivo') ...[
              TextField(
                controller: _entregadoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Entregado por el cliente',
                  labelStyle: TextStyle(color: Color(0xFFB0B3C1)),
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Color(0xFF6B6E82)),
                  prefixIcon: Icon(Icons.euro, color: Color(0xFF00FFC8)),
                  suffixText: '€',
                  suffixStyle: TextStyle(color: Color(0xFFB0B3C1)),
                  filled: true,
                  fillColor: Color(0xFF1E2139),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [10.0, 20.0, 50.0, 100.0].map((val) {
                  return ActionChip(
                    label: Text('$val €'),
                    onPressed: () => setState(() => _entregadoCtrl.text = val.toString()),
                    backgroundColor: const Color(0xFF1E2139),
                    labelStyle: const TextStyle(color: Color(0xFF00FFC8)),
                  );
                }).toList(),
              ),
              if (_cambio > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFC8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00FFC8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cambio a devolver', style: TextStyle(color: Colors.white)),
                      Text(
                        fmt.format(_cambio),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00FFC8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),

            // Botón confirmar
            FilledButton(
              onPressed: _procesando ? null : _confirmarCobro,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00FFC8),
                foregroundColor: const Color(0xFF0A0F23),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
              ),
              child: _procesando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Confirmar pago ${fmt.format(widget.total + _propina)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

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
      final db = FirebaseFirestore.instance;
      final ventaId = db.collection('_temp').doc().id;
      final pedidoId = db.collection('_temp').doc().id;

      // ── 1. Verificar si tiene facturación automática ─────────────────────
      bool tieneFacturacionAuto = false;
      String? facturaGeneradaId;
      
      try {
        // Obtener suscripción actual para verificar plan
        final suscDoc = await db
            .collection('empresas').doc(widget.empresaId)
            .collection('suscripcion').doc('actual')
            .get();
        
        if (suscDoc.exists) {
          final suscData = suscDoc.data()!;
          final packsActivos = (suscData['packs_activos'] as List?)
              ?.map((e) => e.toString()).toList() ?? [];
          final addonsActivos = (suscData['addons_activos'] as List?)
              ?.map((e) => e.toString()).toList() ?? [];
          
          // Verificar si tiene TPV Profesional o Pack Gestión
          tieneFacturacionAuto = PlanesConfig.tieneFacturacionAutomatica(
            packsActivos: packsActivos,
            addonsActivos: addonsActivos,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Error verificando plan: $e');
      }

      // ── 2. Crear el pedido en Firestore ──────────────────────────────────
      await db.collection('empresas').doc(widget.empresaId).collection('pedidos').doc(pedidoId).set({
        'mesa_id': widget.mesaId,
        'mesa_nombre': widget.nombreMesa,
        'comensales': widget.comensales,
        'lineas': widget.lineas.map((linea) => {
          'producto_nombre': linea['nombre'] ?? '',
          'producto_id': linea['producto_id'] ?? '',
          'categoria_id': linea['categoria_id'] ?? '',
          'cantidad': linea['cantidad'] ?? 1,
          'precio_unitario': linea['precio'] ?? 0.0,
          'iva_porcentaje': linea['iva'] ?? 21.0,
          'subtotal': (linea['precio'] ?? 0.0) * (linea['cantidad'] ?? 1),
        }).toList(),
        'subtotal': widget.total,
        'propina': _propina,
        'total': widget.total + _propina,
        'metodo_pago': _metodoPago,
        'estado_pago': 'pagado',
        'origen': 'presencial',
        if (_metodoPago == 'efectivo') ...{
          'entregado': double.tryParse(_entregadoCtrl.text) ?? 0.0,
          'cambio': _cambio,
        },
        'fecha_creacion': FieldValue.serverTimestamp(),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
        'cliente_nombre': 'Cliente TPV',
        'cliente_telefono': '',
        'cliente_correo': '',
        'cajero_uid': FirebaseFirestore.instance.collection('_temp').doc().id,
      });

      // ── 3. Generar factura automática SI corresponde ─────────────────────
      if (tieneFacturacionAuto) {
        try {
          // Cargar el pedido recién creado
          final pedidoDoc = await db
              .collection('empresas').doc(widget.empresaId)
              .collection('pedidos').doc(pedidoId)
              .get();
          
          if (pedidoDoc.exists) {
            final pedido = Pedido.fromFirestore(pedidoDoc);
            
            // Obtener configuración de facturación TPV
            final tpvFactSvc = TpvFacturacionService();
            final config = await tpvFactSvc.obtenerConfig(widget.empresaId);
            
            // Generar factura automáticamente
            final factura = await tpvFactSvc.generarFacturaPorPedido(
              empresaId: widget.empresaId,
              pedido: pedido,
              config: config,
              usuarioNombre: 'TPV Auto',
            );
            
            facturaGeneradaId = factura.id;
            debugPrint('✅ Factura generada automáticamente: ${factura.numeroFactura}');
          }
        } catch (e) {
          debugPrint('⚠️ Error generando factura automática: $e');
          // No bloqueamos el cobro si falla la facturación
        }
      }

      // ── 4. Crear venta (mantener compatibilidad) ─────────────────────────
      await db.collection('empresas').doc(widget.empresaId).collection('ventas').doc(ventaId).set({
        'mesa_id': widget.mesaId,
        'mesa_nombre': widget.nombreMesa,
        'comensales': widget.comensales,
        'lineas': widget.lineas,
        'subtotal': widget.total,
        'propina': _propina,
        'total': widget.total + _propina,
        'metodo_pago': _metodoPago,
        if (_metodoPago == 'efectivo') ...{
          'entregado': double.tryParse(_entregadoCtrl.text) ?? 0.0,
          'cambio': _cambio,
        },
        'fecha': FieldValue.serverTimestamp(),
        'cajero_uid': FirebaseFirestore.instance.collection('_temp').doc().id,
        'pedido_id': pedidoId,
        if (facturaGeneradaId != null) 'factura_id': facturaGeneradaId,
      });

      // ── 5. Actualizar caja diaria ────────────────────────────────────────
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final cajaRef = db.collection('empresas').doc(widget.empresaId).collection('caja_diaria').doc(hoy);
      
      await db.runTransaction((transaction) async {
        final cajaDoc = await transaction.get(cajaRef);
        
        if (!cajaDoc.exists) {
          // Crear documento de caja si no existe
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
          // Incrementar totales
          final data = cajaDoc.data()!;
          transaction.update(cajaRef, {
            'total_efectivo': (data['total_efectivo'] ?? 0.0) + (_metodoPago == 'efectivo' ? widget.total + _propina : 0.0),
            'total_tarjeta': (data['total_tarjeta'] ?? 0.0) + (_metodoPago == 'tarjeta' ? widget.total + _propina : 0.0),
            'total_bizum': (data['total_bizum'] ?? 0.0) + (_metodoPago == 'bizum' ? widget.total + _propina : 0.0),
            'total_propinas': (data['total_propinas'] ?? 0.0) + _propina,
            'num_tickets': (data['num_tickets'] ?? 0) + 1,
          });
        }
      });

      // ── 6. Liberar mesa ──────────────────────────────────────────────────
      await db.collection('empresas').doc(widget.empresaId).collection('mesas').doc(widget.mesaId).update({
        'estado': 'libre',
        'comensales_actuales': 0,
      });

      // ── 7. Eliminar comanda ──────────────────────────────────────────────
      final comandasSnap = await db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('comandas')
          .where('mesa_id', isEqualTo: widget.mesaId)
          .get();

      for (var doc in comandasSnap.docs) {
        await doc.reference.delete();
      }

      if (!mounted) return;

      // ── 8. Imprimir ticket ───────────────────────────────────────────────
      await _imprimirTicket(ventaId);

      Navigator.pop(context, true); // Cerrar pantalla de cobro
      
      // Mostrar mensaje con indicador de factura si procede
      final mensajeExito = tieneFacturacionAuto && facturaGeneradaId != null
          ? '✅ Cobro realizado • Factura generada automáticamente'
          : '✅ Cobro realizado con éxito';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeExito),
          backgroundColor: const Color(0xFF00FFC8),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _imprimirTicket(String ventaId) async {
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
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text(widget.nombreMesa)),
              pw.Divider(),
              pw.SizedBox(height: 8),
              ...widget.lineas.map((linea) {
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(linea['nombre'] ?? '')),
                    pw.Text(fmt.format(linea['precio'] ?? 0.0)),
                  ],
                );
              }),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(fmt.format(widget.total + _propina), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (_propina > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Propina'),
                    pw.Text(fmt.format(_propina)),
                  ],
                ),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text('Método: ${_metodoPago.toUpperCase()}')),
              if (_metodoPago == 'efectivo' && _cambio > 0)
                pw.Center(child: pw.Text('Cambio: ${fmt.format(_cambio)}')),
              pw.SizedBox(height: 16),
              pw.Center(child: pw.Text('¡Gracias por su visita!')),
              pw.Center(child: pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }
}

class _MetodoPagoChip extends StatelessWidget {
  final IconData icono;
  final String label;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const _MetodoPagoChip({
    required this.icono,
    required this.label,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: seleccionado ? color.withValues(alpha: 0.2) : const Color(0xFF1E2139),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icono, color: seleccionado ? color : const Color(0xFFB0B3C1), size: 32),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: seleccionado ? color : const Color(0xFFB0B3C1),
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA: CIERRE DE CAJA
// ═════════════════════════════════════════════════════════════════════════════

Future<void> mostrarPantallaCierreCaja(BuildContext context, String empresaId) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => _PantallaCierreCaja(empresaId: empresaId)),
  );
}

class _PantallaCierreCaja extends StatelessWidget {
  final String empresaId;

  const _PantallaCierreCaja({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        title: const Text('Cierre de caja'),
        backgroundColor: const Color(0xFF1E2139),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaId)
            .collection('caja_diaria')
            .doc(hoy)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'No hay movimientos de caja hoy',
                style: TextStyle(color: Color(0xFFB0B3C1)),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final efectivo = data['total_efectivo'] ?? 0.0;
          final tarjeta = data['total_tarjeta'] ?? 0.0;
          final bizum = data['total_bizum'] ?? 0.0;
          final propinas = data['total_propinas'] ?? 0.0;
          final numTickets = data['num_tickets'] ?? 0;
          final fondoInicial = data['fondo_inicial'] ?? 0.0;
          final total = efectivo + tarjeta + bizum;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00FFC8), Color(0xFF00D9FF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL DEL DÍA',
                        style: TextStyle(color: Color(0xFF0A0F23), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
fmt.format(total),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A0F23),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$numTickets tickets',
                        style: const TextStyle(color: Color(0xFF0A0F23)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _LineaResumen(label: 'Efectivo', valor: efectivo, icono: Icons.payments, color: const Color(0xFF00FFC8)),
                _LineaResumen(label: 'Tarjeta', valor: tarjeta, icono: Icons.credit_card, color: const Color(0xFFFF3296)),
                _LineaResumen(label: 'Bizum/QR', valor: bizum, icono: Icons.qr_code, color: const Color(0xFFFF4678)),
                const Divider(color: Color(0xFF2A2E45), height: 32),
                _LineaResumen(label: 'Propinas', valor: propinas, icono: Icons.volunteer_activism, color: const Color(0xFFFF4678)),
                _LineaResumen(label: 'Fondo inicial', valor: fondoInicial, icono: Icons.account_balance_wallet, color: const Color(0xFFB0B3C1)),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _confirmarCierre(context, empresaId, hoy, data),
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('Cerrar caja'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2850),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmarCierre(BuildContext context, String empresaId, String fecha, Map<String, dynamic> data) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cierre'),
        content: const Text(
          '¿Cerrar la caja del día? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF2850)),
            child: const Text('Cerrar caja'),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('caja_diaria')
          .doc(fecha)
          .update({
        'abierta': false,
        'cerrada_en': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caja cerrada correctamente')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _LineaResumen extends StatelessWidget {
  final String label;
  final double valor;
  final IconData icono;
  final Color color;

  const _LineaResumen({
    required this.label,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 16),
            ),
          ),
          Text(
            fmt.format(valor),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO: APERTURA DE CAJA (Fondo inicial)
// ═════════════════════════════════════════════════════════════════════════════

Future<void> mostrarDialogoAperturaCaja(BuildContext context, String empresaId) async {
  await showDialog(
    context: context,
    builder: (_) => _DialogoAperturaCaja(empresaId: empresaId),
  );
}

class _DialogoAperturaCaja extends StatefulWidget {
  final String empresaId;

  const _DialogoAperturaCaja({required this.empresaId});

  @override
  State<_DialogoAperturaCaja> createState() => _DialogoAperturaCajaState();
}

class _DialogoAperturaCajaState extends State<_DialogoAperturaCaja> {
  final _fondoCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _fondoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Color(0xFF00FFC8)),
          SizedBox(width: 8),
          Text('Apertura de caja'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Introduce el efectivo inicial en caja:'),
          const SizedBox(height: 16),
          TextField(
            controller: _fondoCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fondo inicial (€)',
              prefixIcon: Icon(Icons.euro),
              hintText: '100.00',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [50.0, 100.0, 150.0, 200.0].map((val) {
              return ActionChip(
                label: Text('$val €'),
                onPressed: () => setState(() => _fondoCtrl.text = val.toString()),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardarApertura,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FFC8)),
          child: _guardando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Abrir caja'),
        ),
      ],
    );
  }

  Future<void> _guardarApertura() async {
    final fondo = double.tryParse(_fondoCtrl.text.trim());
    if (fondo == null || fondo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un importe válido')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('caja_diaria')
          .doc(hoy)
          .set({
        'fecha': hoy,
        'fondo_inicial': fondo,
        'total_efectivo': 0.0,
        'total_tarjeta': 0.0,
        'total_bizum': 0.0,
        'total_propinas': 0.0,
        'num_tickets': 0,
        'abierta': true,
        'abierta_en': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Caja abierta correctamente'),
          backgroundColor: Color(0xFF00FFC8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}







