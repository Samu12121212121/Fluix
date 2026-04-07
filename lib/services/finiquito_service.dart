import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/finiquito.dart';
import '../domain/modelos/contabilidad.dart';
import 'contabilidad_service.dart';

/// Servicio CRUD para finiquitos en Firestore.
///
/// Colección: `empresas/{empresaId}/finiquitos/{finiquitoId}`
class FiniquitoService {
  static final FiniquitoService _i = FiniquitoService._();
  factory FiniquitoService() => _i;
  FiniquitoService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ContabilidadService _contaSvc = ContabilidadService();

  // ── REFS ──────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _finiquitos(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('finiquitos');

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda un finiquito (crear o actualizar).
  Future<Finiquito> guardarFiniquito(String empresaId, Finiquito finiquito) async {
    final ref = finiquito.id.isEmpty
        ? _finiquitos(empresaId).doc()
        : _finiquitos(empresaId).doc(finiquito.id);

    final data = finiquito.toMap();
    data['id'] = ref.id;
    await ref.set(data, SetOptions(merge: true));

    return Finiquito.fromMap(data);
  }

  /// Obtiene todos los finiquitos de una empresa (stream).
  Stream<List<Finiquito>> obtenerFiniquitos(String empresaId) {
    return _finiquitos(empresaId)
        .orderBy('fecha_baja', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Finiquito.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Obtiene finiquitos de un empleado específico.
  Stream<List<Finiquito>> obtenerFiniquitosEmpleado(
    String empresaId,
    String empleadoId,
  ) {
    return _finiquitos(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .orderBy('fecha_baja', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Finiquito.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Obtiene un finiquito por ID.
  Future<Finiquito?> obtenerFiniquito(String empresaId, String finiquitoId) async {
    final doc = await _finiquitos(empresaId).doc(finiquitoId).get();
    if (!doc.exists) return null;
    return Finiquito.fromMap({...doc.data()!, 'id': doc.id});
  }

  /// Firma el finiquito.
  Future<void> firmarFiniquito(String empresaId, String finiquitoId) async {
    await _finiquitos(empresaId).doc(finiquitoId).update({
      'estado': EstadoFiniquito.firmado.name,
    });
  }

  /// Marca como pagado y genera gasto contable automáticamente.
  Future<void> pagarFiniquito(String empresaId, String finiquitoId) async {
    final doc = await _finiquitos(empresaId).doc(finiquitoId).get();
    if (!doc.exists) return;

    final finiquito = Finiquito.fromMap({...doc.data()!, 'id': doc.id});

    // Crear gasto contable vinculado
    final gasto = await _contaSvc.guardarGasto(
      empresaId,
      concepto: 'Finiquito ${finiquito.empleadoNombre} — ${finiquito.causaBaja.etiqueta}',
      categoria: CategoriaGasto.personal,
      baseImponible: finiquito.totalBruto,
      porcentajeIva: 0,
      ivaDeducible: false,
      fechaGasto: DateTime.now(),
      notas: 'Generado automáticamente desde módulo de finiquitos. '
          'Causa: ${finiquito.causaBaja.etiqueta}',
      creadoPor: 'sistema_finiquitos',
    );
    await _contaSvc.pagarGasto(empresaId, gasto.id, 'transferencia');

    // Actualizar finiquito
    await _finiquitos(empresaId).doc(finiquitoId).update({
      'estado': EstadoFiniquito.pagado.name,
      'fecha_pago': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Elimina un finiquito (solo borradores).
  Future<void> eliminarFiniquito(String empresaId, String finiquitoId) async {
    final doc = await _finiquitos(empresaId).doc(finiquitoId).get();
    if (doc.exists && doc.data()?['estado'] == 'borrador') {
      await doc.reference.delete();
    }
  }

  /// Resumen de finiquitos por período.
  Future<Map<String, dynamic>> resumenFiniquitos(
    String empresaId,
    int anio,
  ) async {
    final snap = await _finiquitos(empresaId)
        .where('fecha_baja', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(anio, 1, 1)))
        .where('fecha_baja', isLessThan: Timestamp.fromDate(DateTime(anio + 1, 1, 1)))
        .get();

    final finiquitos = snap.docs
        .map((d) => Finiquito.fromMap({...d.data(), 'id': d.id}))
        .toList();

    return {
      'total_finiquitos': finiquitos.length,
      'total_bruto': finiquitos.fold(0.0, (s, f) => s + f.totalBruto),
      'total_indemnizaciones': finiquitos.fold(0.0, (s, f) => s + f.indemnizacion),
      'total_liquido': finiquitos.fold(0.0, (s, f) => s + f.liquidoPercibir),
      'por_causa': _agruparPorCausa(finiquitos),
      'pagados': finiquitos.where((f) => f.estado == EstadoFiniquito.pagado).length,
      'pendientes': finiquitos.where((f) => f.estado != EstadoFiniquito.pagado).length,
    };
  }

  static Map<String, int> _agruparPorCausa(List<Finiquito> finiquitos) {
    final mapa = <String, int>{};
    for (final f in finiquitos) {
      final clave = f.causaBaja.etiqueta;
      mapa[clave] = (mapa[clave] ?? 0) + 1;
    }
    return mapa;
  }
}

