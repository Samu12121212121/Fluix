import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'package:planeag_flutter/services/verifactu/qr_service.dart';
import 'tpv_caja.dart';

export 'tpv_caja.dart' show
    mostrarPantallaCierreCaja, mostrarDialogoAperturaCaja, LineaResumen,
    imprimirTicket, mostrarFacturaTpvSiProcede, MetodoPagoChip;

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Cupón de descuento (inline — sin dependencias circulares)
// ─────────────────────────────────────────────────────────────────────────────

class Cupon {
  final String id;
  final String codigo;
  final double descuento;
  final bool esPorcentaje;
  final bool activo;
  final DateTime? expiracion;
  final int? usoMaximo;
  final int usoActual;

  const Cupon({
    required this.id,
    required this.codigo,
    required this.descuento,
    required this.esPorcentaje,
    required this.activo,
    this.expiracion,
    this.usoMaximo,
    required this.usoActual,
  });

  factory Cupon.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Cupon(
      id: doc.id,
      codigo: (d['codigo'] as String? ?? '').toUpperCase(),
      descuento: (d['descuento'] as num?)?.toDouble() ?? 0.0,
      esPorcentaje: d['es_porcentaje'] as bool? ?? false,
      activo: d['activo'] as bool? ?? false,
      expiracion: (d['expiracion'] as Timestamp?)?.toDate(),
      usoMaximo: d['uso_maximo'] as int?,
      usoActual: (d['uso_actual'] as num?)?.toInt() ?? 0,
    );
  }

  bool get estaAgotado => usoMaximo != null && usoActual >= usoMaximo!;
  bool get estaExpirado =>
      expiracion != null && DateTime.now().isAfter(expiracion!);

  double importeDescuento(double total) {
    if (esPorcentaje) return (total * descuento / 100).clamp(0.0, total);
    return descuento.clamp(0.0, total);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARÁMETROS para guardarCobro / imprimirTicket
// ─────────────────────────────────────────────────────────────────────────────

class CobroParams {
  final String empresaId;
  final String mesaId;
  final String nombreMesa;
  final List<Map<String, dynamic>> lineas;
  final double subtotal;
  final double totalFinal;
  final double propina;
  final double descuentoCupon;
  final String metodoPago;
  final double entregadoEfectivo;
  final double cambio;
  final double efectivoMixto;
  final double tarjetaMixto;
  final String nombreFiado;
  final Cupon? cupon;
  final int comensales;
  final Map<String, double>? importesPorMetodo;

  const CobroParams({
    required this.empresaId,
    required this.mesaId,
    required this.nombreMesa,
    required this.lineas,
    required this.subtotal,
    required this.totalFinal,
    required this.propina,
    required this.descuentoCupon,
    required this.metodoPago,
    required this.entregadoEfectivo,
    required this.cambio,
    required this.efectivoMixto,
    required this.tarjetaMixto,
    required this.nombreFiado,
    required this.cupon,
    required this.comensales,
    this.importesPorMetodo,
  });

  bool get esFiado => metodoPago == 'fiado';
}

// ─────────────────────────────────────────────────────────────────────────────
// GUARDAR COBRO en Firestore
// ─────────────────────────────────────────────────────────────────────────────

Future<CobroResult> guardarCobro(CobroParams p) async {
  final db = FirebaseFirestore.instance;
  final ventaId = db.collection('_tmp').doc().id;
  final pedidoId = db.collection('_tmp').doc().id;

  final Map<String, dynamic> extraMetodo = {
    if (p.metodoPago == 'efectivo') ...{
      'entregado': p.entregadoEfectivo,
      'cambio': p.cambio,
    },
    if (p.metodoPago == 'mixto') ...{
      'efectivo_importe': p.efectivoMixto,
      'tarjeta_importe': p.tarjetaMixto,
    },
    if (p.esFiado) ...{
      'es_fiado': true,
      if (p.nombreFiado.isNotEmpty) 'cliente_fiado': p.nombreFiado,
    },
  };

  final Map<String, dynamic> extraCupon = {
    if (p.cupon != null) ...{
      'cupon_id': p.cupon!.id,
      'cupon_descuento': p.descuentoCupon,
    },
  };

  final lineasFS = p.lineas.map((l) {
    final pvp = (l['precio'] as num?)?.toDouble() ?? 0.0;
    final iva = (l['iva'] as num?)?.toDouble() ?? 21.0;
    final cant = (l['cantidad'] as num?)?.toInt() ?? 1;
    return {
      'producto_nombre': l['nombre'] ?? '',
      'producto_id': l['producto_id'] ?? '',
      'categoria_id': l['categoria_id'] ?? '',
      'cantidad': cant,
      'precio_unitario': pvp / (1 + iva / 100),
      'precio_pvp': pvp,
      'iva_porcentaje': iva,
      'precio_con_iva': true,
      'subtotal': (pvp / (1 + iva / 100)) * cant,
    };
  }).toList();

  final pedidoData = {
    'mesa_id': p.mesaId,
    'mesa_nombre': p.nombreMesa,
    'comensales': p.comensales,
    'num_pagadores': p.comensales,
    'lineas': lineasFS,
    'subtotal': p.subtotal,
    'descuento_cupon': p.descuentoCupon,
    'propina': p.propina,
    'total': p.totalFinal,
    'metodo_pago': p.metodoPago,
    'estado_pago': p.esFiado ? 'pendiente' : 'pagado',
    'origen': 'presencial',
    'es_fiado': p.esFiado,
    ...extraMetodo,
    ...extraCupon,
    'fecha_creacion': FieldValue.serverTimestamp(),
    'fecha_hora': Timestamp.now(),
    'fecha_actualizacion': FieldValue.serverTimestamp(),
    if (p.importesPorMetodo != null && p.importesPorMetodo!.isNotEmpty)
      'importes_por_metodo': p.importesPorMetodo,
    'cliente_nombre': p.esFiado && p.nombreFiado.isNotEmpty
        ? p.nombreFiado
        : 'Cliente TPV',
    'cliente_telefono': '',
    'cliente_correo': '',
  };

  await db
      .collection('empresas')
      .doc(p.empresaId)
      .collection('pedidos')
      .doc(pedidoId)
      .set(pedidoData);

  // QR AEAT
  try {
    final snap = await db.collection('empresas').doc(p.empresaId).get();
    final nif = (snap.data()?['nif'] as String?)?.trim() ?? '';
    if (nif.isNotEmpty) {
      final qrUrl = QrService().generarUrl(
        nifEmisor: nif,
        serie: 'TPV',
        numero: pedidoId.substring(0, 8).toUpperCase(),
        fecha: DateTime.now(),
        importeTotal: p.totalFinal,
      );
      await db
          .collection('empresas')
          .doc(p.empresaId)
          .collection('pedidos')
          .doc(pedidoId)
          .update({'qr_aeat_url': qrUrl});
    }
  } catch (_) {}

  // Cargar pedido creado
  Pedido? pedidoCreado;
  try {
    final doc = await db
        .collection('empresas')
        .doc(p.empresaId)
        .collection('pedidos')
        .doc(pedidoId)
        .get();
    if (doc.exists) pedidoCreado = Pedido.fromFirestore(doc);
  } catch (_) {}

  // Venta (compatibilidad)
  await db
      .collection('empresas')
      .doc(p.empresaId)
      .collection('ventas')
      .doc(ventaId)
      .set({
    'mesa_id': p.mesaId,
    'mesa_nombre': p.nombreMesa,
    'comensales': p.comensales,
    'lineas': p.lineas,
    'subtotal': p.subtotal,
    'propina': p.propina,
    'total': p.totalFinal,
    'metodo_pago': p.metodoPago,
    'estado_pago': p.esFiado ? 'pendiente' : 'pagado',
    'es_fiado': p.esFiado,
    ...extraMetodo,
    ...extraCupon,
    'fecha': FieldValue.serverTimestamp(),
    'pedido_id': pedidoId,
  });

  // Caja diaria (solo si no es fiado)
  if (!p.esFiado) await _actualizarCajaDiaria(db, p);

  // Liberar mesa
  await db
      .collection('empresas')
      .doc(p.empresaId)
      .collection('mesas')
      .doc(p.mesaId)
      .update({'estado': 'libre', 'comensales_actuales': 0});

  // Eliminar comandas
  final comandas = await db
      .collection('empresas')
      .doc(p.empresaId)
      .collection('comandas')
      .where('mesa_id', isEqualTo: p.mesaId)
      .get();
  for (final d in comandas.docs) {
    await d.reference.delete();
  }

  return CobroResult(ventaId: ventaId, pedido: pedidoCreado);
}

Future<void> _actualizarCajaDiaria(
    FirebaseFirestore db, CobroParams p) async {
  final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final ref = db
      .collection('empresas')
      .doc(p.empresaId)
      .collection('caja_diaria')
      .doc(hoy);
  final doc = await ref.get();

  final ef = p.metodoPago == 'efectivo'
      ? p.totalFinal
      : (p.metodoPago == 'mixto' ? p.efectivoMixto : 0.0);
  final ta = p.metodoPago == 'tarjeta'
      ? p.totalFinal
      : (p.metodoPago == 'mixto' ? p.tarjetaMixto : 0.0);
  final bi = p.metodoPago == 'bizum' ? p.totalFinal : 0.0;

  if (!doc.exists) {
    await ref.set({
      'fecha': hoy,
      'total_efectivo': ef,
      'total_tarjeta': ta,
      'total_bizum': bi,
      'total_propinas': p.propina,
      'num_tickets': 1,
      'abierta': true,
    });
  } else {
    final d = doc.data()!;
    await ref.update({
      'total_efectivo': ((d['total_efectivo'] as num?)?.toDouble() ?? 0) + ef,
      'total_tarjeta': ((d['total_tarjeta'] as num?)?.toDouble() ?? 0) + ta,
      'total_bizum': ((d['total_bizum'] as num?)?.toDouble() ?? 0) + bi,
      'total_propinas':
          ((d['total_propinas'] as num?)?.toDouble() ?? 0) + p.propina,
      'num_tickets': ((d['num_tickets'] as num?)?.toInt() ?? 0) + 1,
    });
  }
}

class CobroResult {
  final String ventaId;
  final Pedido? pedido;
  const CobroResult({required this.ventaId, this.pedido});
}

// imprimirTicket, mostrarFacturaTpvSiProcede, MetodoPagoChip
// re-exported via tpv_caja.dart

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Cupón de descuento (stateful — tiene su propio estado de búsqueda)
// ─────────────────────────────────────────────────────────────────────────────

/// Callback: recibe el cupón aplicado (o null al retirar) y el importe
/// de descuento ya calculado.
typedef CuponCallback = void Function(Cupon? cupon, double descuento);

class CuponWidget extends StatefulWidget {
  final String empresaId;
  final double subtotal;
  final CuponCallback onCuponChange;

  const CuponWidget({
    super.key,
    required this.empresaId,
    required this.subtotal,
    required this.onCuponChange,
  });

  @override
  State<CuponWidget> createState() => _CuponWidgetState();
}

class _CuponWidgetState extends State<CuponWidget> {
  final _ctrl = TextEditingController();
  Cupon? _cupon;
  double _descuento = 0.0;
  bool _buscando = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _aplicar() async {
    final codigo = _ctrl.text.trim().toUpperCase();
    if (codigo.isEmpty) return;
    setState(() => _buscando = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('cupones')
          .where('codigo', isEqualTo: codigo).limit(1).get();
      if (!mounted) return;
      if (snap.docs.isEmpty) { _err('Cupón no encontrado'); return; }
      final c = Cupon.fromDoc(snap.docs.first);
      if (!c.activo) { _err('Cupón inactivo'); return; }
      if (c.estaExpirado) { _err('Cupón expirado'); return; }
      if (c.estaAgotado) { _err('Cupón agotado'); return; }
      final d = c.importeDescuento(widget.subtotal);
      setState(() { _cupon = c; _descuento = d; });
      widget.onCuponChange(c, d);
    } catch (_) { if (mounted) _err('Error al verificar el cupón'); }
    finally { if (mounted) setState(() => _buscando = false); }
  }

  void _retirar() {
    setState(() { _cupon = null; _descuento = 0.0; _ctrl.clear(); });
    widget.onCuponChange(null, 0.0);
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  InputDecoration _deco() => const InputDecoration(
    labelText: 'Código de cupón', labelStyle: TextStyle(color: Color(0xFFB0B3C1)),
    hintText: 'PROMO10', hintStyle: TextStyle(color: Color(0xFF6B6E82)),
    prefixIcon: Icon(Icons.local_offer, color: Color(0xFFFFCC00)),
    filled: true, fillColor: Color(0xFF1E2139),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('¿Tienes un cupón?',
            style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 14)),
        iconColor: const Color(0xFFB0B3C1),
        collapsedIconColor: const Color(0xFFB0B3C1),
        children: [
          if (_cupon == null) ...[
            Row(children: [
              Expanded(child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.characters,
                decoration: _deco(),
              )),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _buscando ? null : _aplicar,
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    foregroundColor: const Color(0xFF0A0F23),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20)),
                child: _buscando
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF0A0F23)))
                    : const Text('Aplicar'),
              ),
            ]),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFC8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF00FFC8).withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF00FFC8), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${_cupon!.codigo} — ${fmt.format(_descuento)} de descuento',
                  style: const TextStyle(color: Color(0xFF00FFC8), fontSize: 13),
                )),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Color(0xFF00FFC8), size: 18),
                  onPressed: _retirar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
