import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/cambio_salarial.dart';

/// Servicio de historial salarial de empleados
class SalarioService {
  static final SalarioService _i = SalarioService._();
  factory SalarioService() => _i;
  SalarioService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _historial(String empleadoId) =>
      _db.collection('usuarios').doc(empleadoId).collection('historial_salarial');

  // ── REGISTRAR CAMBIO ──────────────────────────────────────────────────────

  Future<CambioSalarial> registrarCambio({
    required String empleadoId,
    required String empresaId,
    required double salarioAnterior,
    required double salarioNuevo,
    required DateTime fechaEfectividad,
    required MotivoCambioSalarial motivo,
    String? notas,
    required String registradoPor,
  }) async {
    final cambio = CambioSalarial(
      id: '',
      empleadoId: empleadoId,
      empresaId: empresaId,
      salarioAnterior: salarioAnterior,
      salarioNuevo: salarioNuevo,
      fechaEfectividad: fechaEfectividad,
      fechaRegistro: DateTime.now(),
      motivo: motivo,
      notas: notas,
      registradoPor: registradoPor,
    );

    final docRef = await _historial(empleadoId).add(cambio.toMap());
    return CambioSalarial(
      id: docRef.id,
      empleadoId: cambio.empleadoId,
      empresaId: cambio.empresaId,
      salarioAnterior: cambio.salarioAnterior,
      salarioNuevo: cambio.salarioNuevo,
      fechaEfectividad: cambio.fechaEfectividad,
      fechaRegistro: cambio.fechaRegistro,
      motivo: cambio.motivo,
      notas: cambio.notas,
      registradoPor: cambio.registradoPor,
    );
  }

  // ── LISTAR HISTORIAL ──────────────────────────────────────────────────────

  Stream<List<CambioSalarial>> listarHistorial(String empleadoId) {
    return _historial(empleadoId)
        .orderBy('fecha_efectividad', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CambioSalarial.fromMap(d.data(), d.id))
            .toList());
  }

  // ── OBTENER SALARIO VIGENTE EN UNA FECHA ──────────────────────────────────

  /// Devuelve el salario bruto anual vigente para [fecha].
  /// Si hay un cambio con fecha_efectividad <= fecha, usa ese.
  /// Si no hay historial, devuelve el salario actual del empleado.
  Future<double> obtenerSalarioEnFecha(String empleadoId, DateTime fecha) async {
    final snap = await _historial(empleadoId)
        .where('fecha_efectividad', isLessThanOrEqualTo: Timestamp.fromDate(fecha))
        .orderBy('fecha_efectividad', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final cambio = CambioSalarial.fromMap(snap.docs.first.data(), snap.docs.first.id);
      return cambio.salarioNuevo;
    }

    // Fallback: salario actual del empleado
    final empDoc = await _db.collection('usuarios').doc(empleadoId).get();
    final datosNomina = empDoc.data()?['datos_nomina'] as Map<String, dynamic>?;
    return (datosNomina?['salario_bruto_anual'] as num?)?.toDouble() ?? 0;
  }

  // ── CAMBIOS FUTUROS PENDIENTES ────────────────────────────────────────────

  Future<List<CambioSalarial>> cambiosFuturos(String empleadoId) async {
    final snap = await _historial(empleadoId)
        .where('fecha_efectividad', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('fecha_efectividad')
        .get();
    return snap.docs
        .map((d) => CambioSalarial.fromMap(d.data(), d.id))
        .toList();
  }

  // ── ÚLTIMO CAMBIO ─────────────────────────────────────────────────────────

  Future<CambioSalarial?> ultimoCambio(String empleadoId) async {
    final snap = await _historial(empleadoId)
        .orderBy('fecha_registro', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return CambioSalarial.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  // ── ALERTAS: EMPLEADOS SIN ACTUALIZACIÓN EN 11+ MESES ────────────────────

  Future<List<Map<String, dynamic>>> empleadosSinActualizacionReciente(
      String empresaId) async {
    final empleadosSnap = await _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('activo', isEqualTo: true)
        .get();

    final limite = DateTime.now().subtract(const Duration(days: 330)); // ~11 meses
    final List<Map<String, dynamic>> resultado = [];

    for (final emp in empleadosSnap.docs) {
      final ultimoSnap = await _historial(emp.id)
          .orderBy('fecha_registro', descending: true)
          .limit(1)
          .get();

      bool necesitaRevision = true;
      if (ultimoSnap.docs.isNotEmpty) {
        final cambio = CambioSalarial.fromMap(
            ultimoSnap.docs.first.data(), ultimoSnap.docs.first.id);
        if (cambio.fechaRegistro.isAfter(limite)) {
          necesitaRevision = false;
        }
      }

      if (necesitaRevision) {
        resultado.add({
          'empleadoId': emp.id,
          'nombre': emp.data()['nombre'] ?? 'Sin nombre',
          'ultimaActualizacion': ultimoSnap.docs.isNotEmpty
              ? (ultimoSnap.docs.first.data()['fecha_registro'] as Timestamp?)
                  ?.toDate()
              : null,
        });
      }
    }
    return resultado;
  }
}

