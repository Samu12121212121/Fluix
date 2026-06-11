import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../domain/modelos/pedido.dart';
import '../domain/modelos/factura.dart';
import '../domain/modelos/configuracion_facturacion_tpv.dart';
import 'facturacion_service.dart';

class TpvFacturacionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FacturacionService _factSvc = FacturacionService();

  // ── CONFIGURACIÓN ──────────────────────────────────────────────────────────

  Future<ConfiguracionFacturacionTpv> obtenerConfig(String empresaId) async {
    final doc = await _db
        .collection('empresas').doc(empresaId)
        .collection('configuracion').doc('facturacionTpv').get();
    if (!doc.exists || doc.data() == null) return const ConfiguracionFacturacionTpv();
    return ConfiguracionFacturacionTpv.fromMap(doc.data()!);
  }

  Future<void> guardarConfig(String empresaId, ConfiguracionFacturacionTpv config) async {
    await _db
        .collection('empresas').doc(empresaId)
        .collection('configuracion').doc('facturacionTpv')
        .set(config.toMap());
  }

  // ── MODO 1: FACTURA POR PEDIDO ─────────────────────────────────────────────

  Future<Factura> generarFacturaPorPedido({
    required String empresaId,
    required Pedido pedido,
    required ConfiguracionFacturacionTpv config,
    String usuarioId = '',
    String usuarioNombre = 'TPV',
    String? terminalId,
    String? clienteNombreOverride,
    String? clienteEmailOverride,
    String? clienteNifOverride,
  }) async {
    if (pedido.facturaId != null) {
      throw Exception('Este pedido ya tiene factura: ${pedido.facturaId}');
    }
    final nombreCliente = clienteNombreOverride?.isNotEmpty == true
        ? clienteNombreOverride!
        : pedido.clienteNombre.isNotEmpty ? pedido.clienteNombre : 'Cliente TPV';
    final datosFiscales = clienteNifOverride?.isNotEmpty == true
        ? DatosFiscales(nif: clienteNifOverride)
        : null;
    final resultado = await _factSvc.crearFactura(
      empresaId: empresaId,
      clienteNombre: nombreCliente,
      clienteTelefono: pedido.clienteTelefono,
      clienteCorreo: clienteEmailOverride ?? pedido.clienteCorreo,
      datosFiscales: datosFiscales,
      lineas: _pedidoALineas(pedido),
      metodoPago: _convertirMetodo(pedido.metodoPago),
      pedidoId: pedido.id,
      tipo: TipoFactura.venta_directa,
      notasInternas: 'Ticket TPV #${pedido.numeroTicket}',
      fechaOperacion: pedido.fechaCreacion,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      diasVencimiento: config.diasVencimiento,
      estadoInicial: EstadoFactura.pagada,
      terminalId: terminalId,
    );
    await _marcarFacturado(empresaId, pedido.id, resultado.factura.id);
    return resultado.factura;
  }

  // ── MODO 2: RESUMEN DIARIO ─────────────────────────────────────────────────

  Future<Factura?> generarFacturaResumenDiario({
    required String empresaId,
    required DateTime fecha,
    required ConfiguracionFacturacionTpv config,
    String usuarioId = '',
    String usuarioNombre = 'TPV Auto',
  }) async {
    final pedidos = await obtenerPedientesfacturar(
      empresaId,
      DateTimeRange(
        start: DateTime(fecha.year, fecha.month, fecha.day),
        end: DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59),
      ),
      config: config,
    );
    if (pedidos.isEmpty) return null;

    final lineas = pedidos.expand(_pedidoALineas).toList();
    final fechaStr = '${fecha.day.toString().padLeft(2,'0')}/${fecha.month.toString().padLeft(2,'0')}/${fecha.year}';

    // Desglose por método de pago
    final desglose = <String, double>{};
    for (final p in pedidos) {
      final metodo = p.metodoPago.name;
      desglose[metodo] = (desglose[metodo] ?? 0) + p.total;
    }

    final resultado = await _factSvc.crearFactura(
      empresaId: empresaId,
      clienteNombre: 'Cierre diario TPV — $fechaStr',
      lineas: lineas,
      tipo: TipoFactura.venta_directa,
      notasInternas: 'Cierre diario TPV: ${pedidos.length} ticket${pedidos.length != 1 ? 's' : ''}',
      fechaOperacion: DateTime(fecha.year, fecha.month, fecha.day, 23, 59),
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      diasVencimiento: config.diasVencimiento,
      estadoInicial: EstadoFactura.pagada,
      ticketIds: pedidos.map((p) => p.id).toList(),
      desgloseMetodoPago: desglose,
    );
    final batch = _db.batch();
    for (final p in pedidos) {
      batch.update(_refPedido(empresaId, p.id), {
        'factura_id': resultado.factura.id,
        'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
    return resultado.factura;
  }

  // ── MODO 3: SELECCIÓN MANUAL ───────────────────────────────────────────────

  Future<Factura> facturarSeleccion({
    required String empresaId,
    required List<Pedido> pedidos,
    required ConfiguracionFacturacionTpv config,
    String usuarioId = '',
    String usuarioNombre = 'TPV',
  }) async {
    if (pedidos.isEmpty) throw Exception('No hay pedidos seleccionados');
    final lineas = pedidos.expand(_pedidoALineas).toList();
    final resultado = await _factSvc.crearFactura(
      empresaId: empresaId,
      clienteNombre: 'Ventas TPV — Selección manual',
      lineas: lineas,
      tipo: TipoFactura.venta_directa,
      notasInternas: '${pedidos.length} pedidos. Total: ${pedidos.fold<double>(0,(s,p)=>s+p.total).toStringAsFixed(2)}€',
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
      diasVencimiento: config.diasVencimiento,
      estadoInicial: EstadoFactura.pagada,
    );
    final batch = _db.batch();
    for (final p in pedidos) {
      batch.update(_refPedido(empresaId, p.id), {
        'factura_id': resultado.factura.id,
        'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
    return resultado.factura;
  }

  // ── PEDIDOS PENDIENTES ────────────────────────────────────────────────────

  Future<List<Pedido>> obtenerPedientesfacturar(
    String empresaId,
    DateTimeRange rango, {
    ConfiguracionFacturacionTpv? config,
  }) async {
    final snap = await _db
        .collection('empresas').doc(empresaId).collection('pedidos')
        .where('origen', whereIn: ['presencial', 'tpvExterno'])
        .where('estado_pago', isEqualTo: EstadoPago.pagado.name)
        .where('fecha_creacion', isGreaterThanOrEqualTo: Timestamp.fromDate(rango.start))
        .where('fecha_creacion', isLessThanOrEqualTo: Timestamp.fromDate(rango.end))
        .get();

    var lista = snap.docs.map(Pedido.fromFirestore).where((p) => p.facturaId == null).toList();

    if (config != null) {
      lista = lista.where((p) {
        if (p.metodoPago == MetodoPago.efectivo && !config.incluirPedidosEfectivo) return false;
        if (p.metodoPago == MetodoPago.tarjeta  && !config.incluirPedidosTarjeta)  return false;
        if (p.metodoPago == MetodoPago.mixto    && !config.incluirPedidosMixto)    return false;
        return true;
      }).toList();
    }
    lista.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
    return lista;
  }

  Stream<int> contarPendientesStream(String empresaId) {
    final hace30 = DateTime.now().subtract(const Duration(days: 30));
    return _db
        .collection('empresas').doc(empresaId).collection('pedidos')
        .where('origen', whereIn: ['presencial', 'tpvExterno'])
        .where('estado_pago', isEqualTo: EstadoPago.pagado.name)
        .where('fecha_creacion', isGreaterThanOrEqualTo: Timestamp.fromDate(hace30))
        .snapshots()
        .map((s) => s.docs
            .map(Pedido.fromFirestore)
            .where((p) => p.facturaId == null)
            .length);
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  DocumentReference _refPedido(String empresaId, String pedidoId) =>
      _db.collection('empresas').doc(empresaId).collection('pedidos').doc(pedidoId);

  Future<void> _marcarFacturado(String empresaId, String pedidoId, String facturaId) =>
      _refPedido(empresaId, pedidoId).update({
        'factura_id': facturaId,
        'fecha_actualizacion': Timestamp.fromDate(DateTime.now()),
      });

  List<LineaFactura> _pedidoALineas(Pedido pedido) =>
      pedido.lineas.map((l) => LineaFactura(
        descripcion: l.productoNombre,
        precioUnitario: l.precioUnitario,
        cantidad: l.cantidad,
        porcentajeIva: l.ivaPorcentaje,
        descuento: 0,  // LineaPedido no tiene campo descuento, usar 0 por defecto
      )).toList();

  MetodoPagoFactura? _convertirMetodo(MetodoPago m) => switch (m) {
    MetodoPago.tarjeta  => MetodoPagoFactura.tarjeta,
    MetodoPago.paypal   => MetodoPagoFactura.paypal,
    MetodoPago.bizum    => MetodoPagoFactura.bizum,
    MetodoPago.efectivo => MetodoPagoFactura.efectivo,
    MetodoPago.mixto    => null,
  };
}


