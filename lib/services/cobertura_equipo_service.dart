import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vacacion_model.dart';
import 'festivos_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE COBERTURA DE EQUIPO
// Calcula disponibilidad de personal por día para alertas de cobertura.
// ═══════════════════════════════════════════════════════════════════════════════

enum NivelCobertura { verde, amarillo, rojo }

class CoberturaDia {
  final DateTime fecha;
  final int totalEmpleados;
  final int empleadosAusentes;
  final int empleadosPresentes;
  final double porcentajePresentes;
  final NivelCobertura nivel;
  final List<EmpleadoAusente> ausentes;
  final bool esFestivo;
  final String? nombreFestivo;

  const CoberturaDia({
    required this.fecha,
    required this.totalEmpleados,
    required this.empleadosAusentes,
    required this.empleadosPresentes,
    required this.porcentajePresentes,
    required this.nivel,
    this.ausentes = const [],
    this.esFestivo = false,
    this.nombreFestivo,
  });

  bool get esCritico => nivel == NivelCobertura.rojo;
}

class EmpleadoAusente {
  final String empleadoId;
  final String nombre;
  final TipoAusencia tipoAusencia;

  const EmpleadoAusente({
    required this.empleadoId,
    required this.nombre,
    required this.tipoAusencia,
  });
}

class ResultadoVerificacionCobertura {
  final bool hayRiesgo;
  final int empleadosDisponibles;
  final int totalEmpleados;
  final int minimoRequerido;
  final List<DateTime> diasCriticos;
  final String mensaje;

  const ResultadoVerificacionCobertura({
    required this.hayRiesgo,
    required this.empleadosDisponibles,
    required this.totalEmpleados,
    required this.minimoRequerido,
    this.diasCriticos = const [],
    required this.mensaje,
  });
}

class CoberturaEquipoService {
  static final CoberturaEquipoService _i = CoberturaEquipoService._();
  factory CoberturaEquipoService() => _i;
  CoberturaEquipoService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final FestivosService _festSvc = FestivosService();

  // ── CONFIGURACIÓN ──────────────────────────────────────────────────────────

  /// Obtiene el mínimo de empleados presentes configurado (porcentaje 0-100).
  Future<int> obtenerMinimoPorcentaje(String empresaId) async {
    final doc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('vacaciones')
        .get();
    return (doc.data()?['minimo_cobertura_porcentaje'] as num?)?.toInt() ?? 50;
  }

  /// Guarda el mínimo de cobertura.
  Future<void> guardarMinimoPorcentaje(
      String empresaId, int porcentaje) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('vacaciones')
        .set(
      {'minimo_cobertura_porcentaje': porcentaje},
      SetOptions(merge: true),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO DE COBERTURA POR DÍA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula la cobertura de un día específico.
  Future<CoberturaDia> calcularCoberturaDia(
    String empresaId,
    DateTime fecha,
  ) async {
    final dia = DateTime(fecha.year, fecha.month, fecha.day);

    // Total empleados activos
    final empSnap = await _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('activo', isEqualTo: true)
        .get();
    final totalEmpleados = empSnap.docs.length;
    final empleadosMap = <String, String>{};
    for (final doc in empSnap.docs) {
      empleadosMap[doc.id] = doc.data()['nombre'] as String? ?? 'Empleado';
    }

    // Solicitudes aprobadas que cubren ese día
    final solSnap = await _db
        .collection('vacaciones')
        .doc(empresaId)
        .collection('solicitudes')
        .where('estado', isEqualTo: EstadoSolicitud.aprobado.name)
        .get();

    final ausentes = <EmpleadoAusente>[];
    final idsAusentes = <String>{};

    for (final doc in solSnap.docs) {
      final data = doc.data();
      final inicioSol = _parseDate(data['fecha_inicio']);
      final finSol = _parseDate(data['fecha_fin']);
      final inicioNorm = DateTime(inicioSol.year, inicioSol.month, inicioSol.day);
      final finNorm = DateTime(finSol.year, finSol.month, finSol.day);

      if (!dia.isBefore(inicioNorm) && !dia.isAfter(finNorm)) {
        final empId = data['empleado_id'] as String? ?? '';
        if (empId.isNotEmpty && !idsAusentes.contains(empId)) {
          idsAusentes.add(empId);
          ausentes.add(EmpleadoAusente(
            empleadoId: empId,
            nombre: data['empleado_nombre'] as String? ??
                empleadosMap[empId] ??
                'Empleado',
            tipoAusencia:
                TipoAusenciaExt.fromString(data['tipo'] as String?),
          ));
        }
      }
    }

    // Festivo
    final esFestivo = await _festSvc.esFestivo(empresaId, dia);
    final nombreFestivo =
        esFestivo ? await _festSvc.nombreFestivo(empresaId, dia) : null;

    final presentes = totalEmpleados - ausentes.length;
    final porcentaje =
        totalEmpleados > 0 ? (presentes / totalEmpleados) * 100.0 : 100.0;

    NivelCobertura nivel;
    if (porcentaje >= 80) {
      nivel = NivelCobertura.verde;
    } else if (porcentaje >= 50) {
      nivel = NivelCobertura.amarillo;
    } else {
      nivel = NivelCobertura.rojo;
    }

    return CoberturaDia(
      fecha: dia,
      totalEmpleados: totalEmpleados,
      empleadosAusentes: ausentes.length,
      empleadosPresentes: presentes,
      porcentajePresentes: porcentaje,
      nivel: nivel,
      ausentes: ausentes,
      esFestivo: esFestivo,
      nombreFestivo: nombreFestivo,
    );
  }

  /// Calcula la cobertura de un rango de días (optimizado: una sola query).
  Future<List<CoberturaDia>> calcularCoberturaSemana(
    String empresaId,
    DateTime lunes,
  ) async {
    final dias = List.generate(
        7, (i) => DateTime(lunes.year, lunes.month, lunes.day + i));
    final primerDia = dias.first;
    final ultimoDia = dias.last;

    // Total empleados activos
    final empSnap = await _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('activo', isEqualTo: true)
        .get();
    final totalEmpleados = empSnap.docs.length;
    final empleadosMap = <String, String>{};
    for (final doc in empSnap.docs) {
      empleadosMap[doc.id] = doc.data()['nombre'] as String? ?? 'Empleado';
    }

    // Todas las solicitudes aprobadas (una sola query)
    final solSnap = await _db
        .collection('vacaciones')
        .doc(empresaId)
        .collection('solicitudes')
        .where('estado', isEqualTo: EstadoSolicitud.aprobado.name)
        .get();

    // Festivos del rango
    final Set<DateTime> festivos = {};
    final Map<DateTime, String> nombresFestivos = {};
    for (int anio = primerDia.year; anio <= ultimoDia.year; anio++) {
      final lista = await _festSvc.obtenerFestivos(empresaId, anio);
      for (final f in lista) {
        festivos.add(f.fechaNormalizada);
        nombresFestivos[f.fechaNormalizada] = f.nombre;
      }
    }

    // Precalcular ausentes por día
    final Map<DateTime, List<EmpleadoAusente>> ausentesPorDia = {};
    for (final d in dias) {
      ausentesPorDia[d] = [];
    }

    for (final doc in solSnap.docs) {
      final data = doc.data();
      final inicioSol = _parseDate(data['fecha_inicio']);
      final finSol = _parseDate(data['fecha_fin']);
      final inicioNorm =
          DateTime(inicioSol.year, inicioSol.month, inicioSol.day);
      final finNorm = DateTime(finSol.year, finSol.month, finSol.day);

      for (final d in dias) {
        if (!d.isBefore(inicioNorm) && !d.isAfter(finNorm)) {
          final empId = data['empleado_id'] as String? ?? '';
          if (empId.isNotEmpty) {
            final yaEsta =
                ausentesPorDia[d]!.any((a) => a.empleadoId == empId);
            if (!yaEsta) {
              ausentesPorDia[d]!.add(EmpleadoAusente(
                empleadoId: empId,
                nombre: data['empleado_nombre'] as String? ??
                    empleadosMap[empId] ??
                    'Empleado',
                tipoAusencia:
                    TipoAusenciaExt.fromString(data['tipo'] as String?),
              ));
            }
          }
        }
      }
    }

    // Construir resultado
    return dias.map((d) {
      final ausentes = ausentesPorDia[d] ?? [];
      final presentes = totalEmpleados - ausentes.length;
      final porcentaje =
          totalEmpleados > 0 ? (presentes / totalEmpleados) * 100.0 : 100.0;

      NivelCobertura nivel;
      if (porcentaje >= 80) {
        nivel = NivelCobertura.verde;
      } else if (porcentaje >= 50) {
        nivel = NivelCobertura.amarillo;
      } else {
        nivel = NivelCobertura.rojo;
      }

      return CoberturaDia(
        fecha: d,
        totalEmpleados: totalEmpleados,
        empleadosAusentes: ausentes.length,
        empleadosPresentes: presentes,
        porcentajePresentes: porcentaje,
        nivel: nivel,
        ausentes: ausentes,
        esFestivo: festivos.contains(d),
        nombreFestivo: nombresFestivos[d],
      );
    }).toList();
  }

  /// Obtiene los días críticos (cobertura < mínimo) en un rango.
  Future<List<CoberturaDia>> obtenerDiasCriticos(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final resultado = <CoberturaDia>[];
    final minimoPorcentaje = await obtenerMinimoPorcentaje(empresaId);
    DateTime current = DateTime(inicio.year, inicio.month, inicio.day);
    final end = DateTime(fin.year, fin.month, fin.day);

    while (!current.isAfter(end)) {
      // Solo días laborables
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        final cobertura = await calcularCoberturaDia(empresaId, current);
        if (cobertura.porcentajePresentes < minimoPorcentaje) {
          resultado.add(cobertura);
        }
      }
      current = current.add(const Duration(days: 1));
    }
    return resultado;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VERIFICACIÓN ANTES DE APROBAR
  // ═══════════════════════════════════════════════════════════════════════════

  /// Verifica la cobertura antes de aprobar una solicitud.
  /// Devuelve un resultado con alerta si quedarían por debajo del mínimo.
  Future<ResultadoVerificacionCobertura> verificarAntesDeAprobar(
    String empresaId,
    DateTime fechaInicio,
    DateTime fechaFin,
    String empleadoId,
  ) async {
    final minimoPorcentaje = await obtenerMinimoPorcentaje(empresaId);

    // Total empleados activos
    final empSnap = await _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('activo', isEqualTo: true)
        .get();
    final totalEmpleados = empSnap.docs.length;
    final minimoRequerido = (totalEmpleados * minimoPorcentaje / 100).ceil();

    // Solicitudes aprobadas existentes
    final solSnap = await _db
        .collection('vacaciones')
        .doc(empresaId)
        .collection('solicitudes')
        .where('estado', isEqualTo: EstadoSolicitud.aprobado.name)
        .get();

    final diasCriticos = <DateTime>[];
    int peorDisponibles = totalEmpleados;

    DateTime current = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    final end = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);

    while (!current.isAfter(end)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        // Contar cuántos ya ausentes ese día
        final idsAusentes = <String>{};
        for (final doc in solSnap.docs) {
          final data = doc.data();
          final ini = _parseDate(data['fecha_inicio']);
          final f = _parseDate(data['fecha_fin']);
          final iniN = DateTime(ini.year, ini.month, ini.day);
          final fN = DateTime(f.year, f.month, f.day);
          if (!current.isBefore(iniN) && !current.isAfter(fN)) {
            idsAusentes.add(data['empleado_id'] as String? ?? '');
          }
        }
        idsAusentes.add(empleadoId); // Añadir el que pide vacaciones
        idsAusentes.remove('');

        final disponibles = totalEmpleados - idsAusentes.length;
        if (disponibles < peorDisponibles) peorDisponibles = disponibles;
        if (disponibles < minimoRequerido) {
          diasCriticos.add(current);
        }
      }
      current = current.add(const Duration(days: 1));
    }

    final hayRiesgo = diasCriticos.isNotEmpty;
    final mensaje = hayRiesgo
        ? '⚠️ Si apruebas estas vacaciones, solo quedarán $peorDisponibles '
            'empleados disponibles (mínimo: $minimoRequerido). '
            'Hay ${diasCriticos.length} día${diasCriticos.length > 1 ? 's' : ''} '
            'con cobertura crítica.'
        : '✅ La cobertura del equipo se mantiene correcta.';

    return ResultadoVerificacionCobertura(
      hayRiesgo: hayRiesgo,
      empleadosDisponibles: peorDisponibles,
      totalEmpleados: totalEmpleados,
      minimoRequerido: minimoRequerido,
      diasCriticos: diasCriticos,
      mensaje: mensaje,
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}



