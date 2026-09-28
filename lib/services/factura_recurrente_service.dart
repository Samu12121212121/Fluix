import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/factura_recurrente.dart';
import '../domain/modelos/factura.dart';
import 'facturacion_service.dart';

class FacturaRecurrenteService {
  final _db = FirebaseFirestore.instance;

  CollectionReference _col(String empresaId) => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('facturas_recurrentes');

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<FacturaRecurrente> crear({
    required String empresaId,
    required String descripcion,
    required String clienteNombre,
    String? clienteId,
    String? clienteNif,
    String? clienteEmail,
    required double importe,
    double iva = 21,
    required PeriodoRecurrencia periodo,
    required DateTime fechaInicio,
    DateTime? fechaFin,
  }) async {
    final ref = _col(empresaId).doc();
    final fr = FacturaRecurrente(
      id: ref.id,
      empresaId: empresaId,
      descripcion: descripcion,
      clienteNombre: clienteNombre,
      clienteId: clienteId,
      clienteNif: clienteNif,
      clienteEmail: clienteEmail,
      importe: importe,
      iva: iva,
      periodo: periodo,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      proximaEmision: fechaInicio,
      activa: true,
    );
    await ref.set(fr.toFirestore());
    return fr;
  }

  Stream<List<FacturaRecurrente>> listar(String empresaId) => _col(empresaId)
      .orderBy('proxima_emision')
      .snapshots()
      .map((s) => s.docs.map(FacturaRecurrente.fromFirestore).toList());

  Future<void> toggleActiva(String empresaId, FacturaRecurrente fr) =>
      _col(empresaId).doc(fr.id).update({'activa': !fr.activa});

  Future<void> eliminar(String empresaId, String id) =>
      _col(empresaId).doc(id).delete();

  Future<void> actualizar(String empresaId, FacturaRecurrente fr) =>
      _col(empresaId).doc(fr.id).set(fr.toFirestore());

  // ── Emisión manual ────────────────────────────────────────────────────────

  /// Genera la factura del período actual y avanza la próxima emisión.
  Future<Factura> emitirAhora({
    required String empresaId,
    required FacturaRecurrente fr,
    required String usuarioId,
    required String usuarioNombre,
  }) async {
    final svc = FacturacionService();

    final lineas = [
      LineaFactura(
        descripcion: fr.descripcion,
        cantidad: 1,
        precioUnitario: fr.importe,
        porcentajeIva: fr.iva,
      ),
    ];

    final resultado = await svc.crearFactura(
      empresaId: empresaId,
      clienteNombre: fr.clienteNombre,
      lineas: lineas,
      tipo: TipoFactura.servicio,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
    );

    final factura = resultado.factura;

    // Avanzar próxima emisión
    final siguiente = _calcularSiguiente(fr.proximaEmision, fr.periodo);
    final pausar = fr.fechaFin != null && siguiente.isAfter(fr.fechaFin!);
    await _col(empresaId).doc(fr.id).update({
      'proxima_emision': Timestamp.fromDate(siguiente),
      'ultima_emision': Timestamp.fromDate(DateTime.now()),
      'activa': !pausar,
      'facturas_generadas_ids': FieldValue.arrayUnion([factura.id]),
    });

    return factura;
  }

  DateTime _calcularSiguiente(DateTime desde, PeriodoRecurrencia periodo) {
    return switch (periodo) {
      PeriodoRecurrencia.semanal    => desde.add(const Duration(days: 7)),
      PeriodoRecurrencia.mensual    => DateTime(desde.year, desde.month + 1, desde.day),
      PeriodoRecurrencia.bimestral  => DateTime(desde.year, desde.month + 2, desde.day),
      PeriodoRecurrencia.trimestral => DateTime(desde.year, desde.month + 3, desde.day),
      PeriodoRecurrencia.semestral  => DateTime(desde.year, desde.month + 6, desde.day),
      PeriodoRecurrencia.anual      => DateTime(desde.year + 1, desde.month, desde.day),
    };
  }
}
