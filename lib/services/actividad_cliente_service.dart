import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/actividad_cliente.dart';

/// Servicio para registrar y consultar el historial de actividad de clientes.
/// Los eventos se almacenan en: empresas/{id}/clientes/{id}/actividad/{id}
class ActividadClienteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _actividad(
    String empresaId,
    String clienteId,
  ) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .doc(clienteId)
          .collection('actividad');

  // ── REGISTRAR EVENTO ──────────────────────────────────────────────────────

  Future<void> registrarEvento({
    required String empresaId,
    required String clienteId,
    required TipoEventoActividad tipo,
    required String descripcion,
    String? documentoId,
    double? importe,
    String? estado,
    String? servicio,
    String? profesional,
    String? numeroFactura,
    TipoNotaManual? tipoNota,
    String? textoNota,
    String? creadoPorId,
    String? creadoPorNombre,
  }) async {
    final ref = _actividad(empresaId, clienteId).doc();
    final evento = ActividadCliente(
      id: ref.id,
      clienteId: clienteId,
      tipo: tipo,
      descripcion: descripcion,
      fecha: DateTime.now(),
      documentoId: documentoId,
      importe: importe,
      estado: estado,
      servicio: servicio,
      profesional: profesional,
      numeroFactura: numeroFactura,
      tipoNota: tipoNota,
      textoNota: textoNota,
      creadoPorId: creadoPorId,
      creadoPorNombre: creadoPorNombre,
    );
    await ref.set(evento.toFirestore());

    // Actualizar última actividad del cliente (excepto notas manuales)
    if (tipo != TipoEventoActividad.notaManual) {
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('clientes')
          .doc(clienteId)
          .update({
        'ultima_actividad': DateTime.now().toIso8601String(),
        'ultima_visita': DateTime.now().toIso8601String(),
      });
    }
  }

  // ── CONSULTAR HISTORIAL (paginado) ────────────────────────────────────────

  /// Obtiene las primeras [limit] actividades ordenadas por fecha desc.
  Future<List<ActividadCliente>> obtenerHistorial({
    required String empresaId,
    required String clienteId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _actividad(empresaId, clienteId)
        .orderBy('fecha', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    return snap.docs.map(ActividadCliente.fromFirestore).toList();
  }

  /// Stream del historial completo (para tiempo real).
  Stream<List<ActividadCliente>> watchHistorial({
    required String empresaId,
    required String clienteId,
    int limit = 20,
  }) {
    return _actividad(empresaId, clienteId)
        .orderBy('fecha', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ActividadCliente.fromFirestore).toList());
  }

  // ── REGISTRAR NOTA MANUAL ─────────────────────────────────────────────────

  Future<void> registrarNotaManual({
    required String empresaId,
    required String clienteId,
    required String texto,
    required TipoNotaManual tipoNota,
    required String usuarioId,
    required String usuarioNombre,
  }) async {
    final etiquetaTipo = switch (tipoNota) {
      TipoNotaManual.llamada => '📞 Llamada',
      TipoNotaManual.visita => '🏠 Visita',
      TipoNotaManual.email => '📧 Email',
      TipoNotaManual.notaInterna => '📝 Nota interna',
    };

    await registrarEvento(
      empresaId: empresaId,
      clienteId: clienteId,
      tipo: TipoEventoActividad.notaManual,
      descripcion: '$etiquetaTipo: $texto',
      tipoNota: tipoNota,
      textoNota: texto,
      creadoPorId: usuarioId,
      creadoPorNombre: usuarioNombre,
    );
  }

  // ── HELPERS PARA TRIGGERS AUTOMÁTICOS ─────────────────────────────────────

  Future<void> registrarFacturaEmitida({
    required String empresaId,
    required String clienteId,
    required String facturaId,
    required String numeroFactura,
    required double importe,
    required String estado,
  }) =>
      registrarEvento(
        empresaId: empresaId,
        clienteId: clienteId,
        tipo: TipoEventoActividad.facturaEmitida,
        descripcion: 'Factura $numeroFactura emitida por ${importe.toStringAsFixed(2)} €',
        documentoId: facturaId,
        importe: importe,
        estado: estado,
        numeroFactura: numeroFactura,
      );

  Future<void> registrarFacturaCobrada({
    required String empresaId,
    required String clienteId,
    required String facturaId,
    required String numeroFactura,
    required double importe,
  }) =>
      registrarEvento(
        empresaId: empresaId,
        clienteId: clienteId,
        tipo: TipoEventoActividad.facturaCobrada,
        descripcion: 'Factura $numeroFactura cobrada (${importe.toStringAsFixed(2)} €)',
        documentoId: facturaId,
        importe: importe,
        estado: 'pagada',
        numeroFactura: numeroFactura,
      );

  Future<void> registrarCitaCreada({
    required String empresaId,
    required String clienteId,
    required String reservaId,
    required String servicio,
    required DateTime fechaCita,
    String? profesional,
  }) =>
      registrarEvento(
        empresaId: empresaId,
        clienteId: clienteId,
        tipo: TipoEventoActividad.citaCreada,
        descripcion: 'Cita creada: $servicio',
        documentoId: reservaId,
        servicio: servicio,
        profesional: profesional,
      );

  Future<void> registrarCitaCompletada({
    required String empresaId,
    required String clienteId,
    required String reservaId,
    required String servicio,
  }) =>
      registrarEvento(
        empresaId: empresaId,
        clienteId: clienteId,
        tipo: TipoEventoActividad.citaCompletada,
        descripcion: 'Cita completada: $servicio',
        documentoId: reservaId,
        servicio: servicio,
        estado: 'completada',
      );

  Future<void> registrarPedidoCreado({
    required String empresaId,
    required String clienteId,
    required String pedidoId,
    required double importe,
  }) =>
      registrarEvento(
        empresaId: empresaId,
        clienteId: clienteId,
        tipo: TipoEventoActividad.pedidoCreado,
        descripcion: 'Pedido creado por ${importe.toStringAsFixed(2)} €',
        documentoId: pedidoId,
        importe: importe,
        estado: 'pendiente',
      );

  Future<void> registrarPedidoEntregado({
    required String empresaId,
    required String clienteId,
    required String pedidoId,
    required double importe,
  }) =>
      registrarEvento(
        empresaId: empresaId,
        clienteId: clienteId,
        tipo: TipoEventoActividad.pedidoEntregado,
        descripcion: 'Pedido entregado (${importe.toStringAsFixed(2)} €)',
        documentoId: pedidoId,
        importe: importe,
        estado: 'entregado',
      );
}

