import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/alerta_contrato.dart';

/// Servicio para gestionar alertas de vencimiento de contratos
class AlertasContratoService {
  static final AlertasContratoService _i = AlertasContratoService._();
  factory AlertasContratoService() => _i;
  AlertasContratoService._();

  final _db = FirebaseFirestore.instance;

  // ── ALERTAS ACTIVAS ───────────────────────────────────────────────────────

  Stream<List<AlertaContrato>> alertasActivas(String empresaId) {
    return _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final List<AlertaContrato> alertas = [];
      final ahora = DateTime.now();

      for (final doc in snap.docs) {
        final data = doc.data();
        final dn = data['datos_nomina'] as Map<String, dynamic>?;
        if (dn == null) continue;

        final tipoStr = dn['tipo_contrato'] as String?;
        if (tipoStr == null || tipoStr == 'indefinido') continue;

        final fechaFinRaw = dn['fecha_fin_contrato'];
        DateTime? fechaFin;
        if (fechaFinRaw is Timestamp) fechaFin = fechaFinRaw.toDate();
        else if (fechaFinRaw is String) fechaFin = DateTime.tryParse(fechaFinRaw);

        if (fechaFin == null) continue;

        final diasRestantes = fechaFin.difference(ahora).inDays;
        if (diasRestantes > 60) continue; // Solo alertar ≤ 60 días

        final fechaInicioRaw = dn['fecha_inicio_contrato'];
        DateTime? fechaInicio;
        if (fechaInicioRaw is Timestamp) fechaInicio = fechaInicioRaw.toDate();
        else if (fechaInicioRaw is String) fechaInicio = DateTime.tryParse(fechaInicioRaw);

        final tipo = TipoContratoAlerta.values.firstWhere(
          (t) => t.name == tipoStr,
          orElse: () => TipoContratoAlerta.temporal,
        );

        alertas.add(AlertaContrato(
          empleadoId: doc.id,
          empleadoNombre: data['nombre'] ?? 'Sin nombre',
          tipoContrato: tipo,
          fechaInicio: fechaInicio ?? ahora,
          fechaFin: fechaFin,
          diasRestantes: diasRestantes,
          nivel: AlertaContrato.calcularNivel(diasRestantes),
        ));
      }

      alertas.sort((a, b) => a.diasRestantes.compareTo(b.diasRestantes));
      return alertas;
    });
  }

  // ── RENOVACIONES ──────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _renovaciones(String empleadoId) =>
      _db.collection('usuarios').doc(empleadoId).collection('renovaciones');

  Stream<List<RenovacionContrato>> listarRenovaciones(String empleadoId) {
    return _renovaciones(empleadoId)
        .orderBy('fecha_renovacion', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RenovacionContrato.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> renovarContrato({
    required String empleadoId,
    required TipoContratoAlerta tipoAnterior,
    required TipoContratoAlerta tipoNuevo,
    required DateTime fechaFinAnterior,
    required DateTime fechaFinNueva,
    required String renovadoPor,
    String? notas,
  }) async {
    final renovacion = RenovacionContrato(
      id: '',
      empleadoId: empleadoId,
      tipoAnterior: tipoAnterior,
      tipoNuevo: tipoNuevo,
      fechaFinAnterior: fechaFinAnterior,
      fechaFinNueva: fechaFinNueva,
      fechaRenovacion: DateTime.now(),
      notas: notas,
      renovadoPor: renovadoPor,
    );

    await _renovaciones(empleadoId).add(renovacion.toMap());

    // Actualizar datos del empleado
    await _db.collection('usuarios').doc(empleadoId).update({
      'datos_nomina.tipo_contrato': tipoNuevo.name,
      'datos_nomina.fecha_fin_contrato': fechaFinNueva.toIso8601String(),
    });
  }
}

