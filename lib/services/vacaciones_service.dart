import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vacacion_model.dart';
import '../models/saldo_vacaciones_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// RESULTADO DE SOLAPAMIENTO DE AUSENCIAS
// ═══════════════════════════════════════════════════════════════════════════════

class ResultadoSolapamiento {
  final int empleadosAusentes;
  final int totalEmpleados;
  final double porcentaje;
  final List<String> nombresAusentes;

  const ResultadoSolapamiento({
    required this.empleadosAusentes,
    required this.totalEmpleados,
    required this.porcentaje,
    required this.nombresAusentes,
  });

  /// Conflicto si ≥50 % del equipo ausente y al menos 2 empleados.
  bool get esConflicto =>
      empleadosAusentes >= 2 && totalEmpleados > 0 && porcentaje >= 50;

  static const ResultadoSolapamiento vacio = ResultadoSolapamiento(
    empleadosAusentes: 0,
    totalEmpleados: 0,
    porcentaje: 0,
    nombresAusentes: [],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE VACACIONES Y AUSENCIAS
// ═══════════════════════════════════════════════════════════════════════════════

class VacacionesService {
  static final VacacionesService _i = VacacionesService._();
  factory VacacionesService() => _i;
  VacacionesService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Días de vacaciones por convenio (días naturales / año) ──────────────────
  static const Map<String, int> diasPorConvenio = {
    'hosteleria-guadalajara': 30,
    'comercio-guadalajara': 30,
    'peluqueria-estetica-gimnasios': 30,
    'industrias-carnicas-guadalajara-2025': 31,
    'veterinarios-guadalajara-2026': 30,
    'construccion-obras-publicas-guadalajara': 30,
  };
  static const int diasLegalesET = 30; // art. 38 ET — mínimo legal

  // ── REFS ────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _solicitudes(String empresaId) =>
      _db.collection('vacaciones').doc(empresaId).collection('solicitudes');

  DocumentReference<Map<String, dynamic>> _saldoDoc(
          String empresaId, String empleadoId) =>
      _db.collection('vacaciones').doc(empresaId).collection('saldos').doc(empleadoId);

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULOS PUROS (sin Firestore — testeables unitariamente)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Diferencia en días entre dos fechas, inmune a DST.
  /// Normaliza a UTC para evitar que el cambio de horario (CET↔CEST)
  /// haga que inDays pierda un día al truncar.
  static int _diffDias(DateTime from, DateTime to) {
    return DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
  }

  static int calcularDiasLaborables(DateTime inicio, DateTime fin) {
    final a = DateTime.utc(inicio.year, inicio.month, inicio.day);
    final b = DateTime.utc(fin.year, fin.month, fin.day);
    int count = 0;
    DateTime current = a;
    while (!current.isAfter(b)) {
      if (current.weekday >= DateTime.monday &&
          current.weekday <= DateTime.friday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  static int calcularDiasNaturales(DateTime inicio, DateTime fin) {
    final a = DateTime(inicio.year, inicio.month, inicio.day);
    final b = DateTime(fin.year, fin.month, fin.day);
    return b.difference(a).inDays + 1;
  }

  static double calcularDiasDevengados({
    required DateTime fechaInicioContrato,
    required DateTime fechaCalculo,
    required int diasConvenio,
    required int anio,
  }) {
    // El devengo se calcula sobre el año en cuestión
    final inicioAnio = DateTime(anio, 1, 1);
    final finAnio = DateTime(anio, 12, 31);

    // Inicio real = máximo entre inicio contrato e inicio del año
    final inicioReal = fechaInicioContrato.isAfter(inicioAnio)
        ? fechaInicioContrato
        : inicioAnio;
    // Fin real = mínimo entre fecha cálculo y fin de año
    final finReal = fechaCalculo.isBefore(finAnio) ? fechaCalculo : finAnio;

    if (finReal.isBefore(inicioReal)) return 0;

    final diasTrabajados = finReal.difference(inicioReal).inDays + 1;
    final diasAnio = _diasEnAnio(anio);
    return (diasTrabajados / diasAnio) * diasConvenio;
  }

  /// Calcula el descuento en nómina por ausencia injustificada.
  static double calcularDescuentoAusencia({
    required double salarioBrutoMensual,
    required int diasMes,
    required int diasAusencia,
  }) {
    if (diasMes <= 0 || diasAusencia <= 0) return 0;
    return (salarioBrutoMensual / diasMes) * diasAusencia;
  }

  /// Devuelve los días del convenio para un sector dado.
  static int diasVacacionesPorSector(String? sector) {
    switch (sector?.toLowerCase().trim()) {
      case 'hosteleria':
        return diasPorConvenio['hosteleria-guadalajara']!;
      case 'comercio':
        return diasPorConvenio['comercio-guadalajara']!;
      case 'peluqueria':
        return diasPorConvenio['peluqueria-estetica-gimnasios']!;
      case 'carniceria':
      case 'industrias_carnicas':
        return diasPorConvenio['industrias-carnicas-guadalajara-2025']!;
      case 'veterinarios':
      case 'veterinaria':
      case 'clinica_veterinaria':
        return diasPorConvenio['veterinarios-guadalajara-2026']!;
      default:
        return diasLegalesET;
    }
  }

  /// Días en un año (considera bisiestos).
  static int _diasEnAnio(int anio) {
    if (anio % 4 != 0) return 365;
    if (anio % 100 != 0) return 366;
    if (anio % 400 != 0) return 365;
    return 366;
  }

  /// Días del mes concreto.
  static int diasEnMes(int anio, int mes) {
    return DateTime(anio, mes + 1, 0).day;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD SOLICITUDES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea una nueva solicitud de vacaciones/ausencia.
  Future<SolicitudVacaciones> crearSolicitud(
    String empresaId,
    SolicitudVacaciones solicitud,
  ) async {
    final ref = _solicitudes(empresaId).doc();
    final data = solicitud.copyWith(id: ref.id).toMap();
    data['id'] = ref.id;
    await ref.set(data);
    return SolicitudVacaciones.fromMap(data);
  }

  /// Aprueba una solicitud y actualiza el saldo.
  Future<void> aprobarSolicitud(String empresaId, String solicitudId) async {
    final doc = await _solicitudes(empresaId).doc(solicitudId).get();
    if (!doc.exists) return;
    final solicitud = SolicitudVacaciones.fromMap({...doc.data()!, 'id': doc.id});
    if (solicitud.estado != EstadoSolicitud.solicitado) return;

    await _solicitudes(empresaId).doc(solicitudId).update({
      'estado': EstadoSolicitud.aprobado.name,
    });

    // Actualizar saldo si es de tipo vacaciones
    if (solicitud.tipo == TipoAusencia.vacaciones) {
      await _actualizarSaldoDisfrutado(
        empresaId,
        solicitud.empleadoId,
        solicitud.fechaInicio.year,
        solicitud.diasNaturales.toDouble(),
      );
    }
  }

  /// Rechaza una solicitud.
  Future<void> rechazarSolicitud(
    String empresaId,
    String solicitudId, {
    String? motivo,
  }) async {
    await _solicitudes(empresaId).doc(solicitudId).update({
      'estado': EstadoSolicitud.rechazado.name,
      if (motivo != null) 'notas': motivo,
    });
  }

  /// Obtiene todas las solicitudes de la empresa.
  Stream<List<SolicitudVacaciones>> obtenerSolicitudes(String empresaId) {
    return _solicitudes(empresaId)
        .orderBy('fecha_creacion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => SolicitudVacaciones.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Obtiene solicitudes de un empleado.
  Stream<List<SolicitudVacaciones>> obtenerSolicitudesEmpleado(
    String empresaId,
    String empleadoId,
  ) {
    return _solicitudes(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .orderBy('fecha_creacion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => SolicitudVacaciones.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Obtiene solicitudes aprobadas que afectan a un mes concreto (para nómina).
  Future<List<SolicitudVacaciones>> obtenerAusenciasMes(
    String empresaId,
    int anio,
    int mes, {
    String? empleadoId,
  }) async {
    final inicioMes = DateTime(anio, mes, 1);
    final finMes = DateTime(anio, mes + 1, 0, 23, 59, 59);

    Query<Map<String, dynamic>> query = _solicitudes(empresaId)
        .where('estado', isEqualTo: EstadoSolicitud.aprobado.name);

    if (empleadoId != null) {
      query = query.where('empleado_id', isEqualTo: empleadoId);
    }

    final snap = await query.get();
    final todas = snap.docs
        .map((d) => SolicitudVacaciones.fromMap({...d.data(), 'id': d.id}))
        .toList();

    // Filtrar las que se solapan con el mes dado
    return todas.where((s) {
      return s.fechaInicio.isBefore(finMes) &&
          s.fechaFin.isAfter(inicioMes);
    }).toList();
  }

  /// Calcula cuántos días de una solicitud caen en un mes concreto.
  static int diasEnMesDeSolicitud(
    SolicitudVacaciones solicitud,
    int anio,
    int mes,
  ) {
    final inicioMes = DateTime(anio, mes, 1);
    final finMes = DateTime(anio, mes + 1, 0);

    final inicio = solicitud.fechaInicio.isAfter(inicioMes)
        ? solicitud.fechaInicio
        : inicioMes;
    final fin = solicitud.fechaFin.isBefore(finMes)
        ? solicitud.fechaFin
        : finMes;

    if (fin.isBefore(inicio)) return 0;
    return fin.difference(inicio).inDays + 1;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SALDOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula y devuelve el saldo de vacaciones de un empleado.
  Future<SaldoVacaciones> calcularSaldo(
    String empresaId,
    String empleadoId,
    int anio, {
    String? sector,
  }) async {
    // Obtener datos del empleado
    final empDoc = await _db.collection('usuarios').doc(empleadoId).get();
    final datos = empDoc.data();
    final datosNomina =
        datos?['datos_nomina'] as Map<String, dynamic>? ?? {};

    final fechaInicioContrato = datosNomina['fecha_inicio_contrato'] != null
        ? _parseDate(datosNomina['fecha_inicio_contrato'])
        : DateTime(anio, 1, 1);

    final sectorEmp = sector ??
        datosNomina['sector_empresa'] as String? ??
        datos?['sector'] as String?;

    final diasConvenio = diasVacacionesPorSector(sectorEmp);
    final devengados = calcularDiasDevengados(
      fechaInicioContrato: fechaInicioContrato,
      fechaCalculo: DateTime.now(),
      diasConvenio: diasConvenio,
      anio: anio,
    );

    // Obtener días disfrutados del año (solicitudes aprobadas tipo vacaciones)
    final snap = await _solicitudes(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('tipo', isEqualTo: TipoAusencia.vacaciones.valor)
        .where('estado', isEqualTo: EstadoSolicitud.aprobado.name)
        .get();

    double disfrutados = 0;
    for (final doc in snap.docs) {
      final s = SolicitudVacaciones.fromMap({...doc.data(), 'id': doc.id});
      // Solo contar los días que caen en el año solicitado
      if (s.fechaInicio.year == anio || s.fechaFin.year == anio) {
        disfrutados += s.diasNaturales;
      }
    }

    // Obtener arrastre de año anterior
    double arrastre = 0;
    final saldoAnterior = await _obtenerSaldoAlmacenado(empresaId, empleadoId, anio - 1);
    if (saldoAnterior != null && saldoAnterior.diasPendientes > 0) {
      // Solo se pueden disfrutar hasta el 31/01 del año siguiente
      final limiteArrastre = DateTime(anio, 1, 31);
      if (DateTime.now().isBefore(limiteArrastre) ||
          DateTime.now().isAtSameMomentAs(limiteArrastre)) {
        arrastre = saldoAnterior.diasPendientes;
      }
    }

    final saldo = SaldoVacaciones(
      empleadoId: empleadoId,
      anio: anio,
      diasDevengados: double.parse(devengados.toStringAsFixed(2)),
      diasDisfrutados: disfrutados,
      diasPendientes:
          double.parse((devengados - disfrutados).toStringAsFixed(2)),
      diasPendientesAnoAnterior: arrastre,
      ultimaActualizacion: DateTime.now(),
    );

    // Guardar saldo calculado
    await _guardarSaldo(empresaId, saldo);

    return saldo;
  }

  Future<SaldoVacaciones?> _obtenerSaldoAlmacenado(
    String empresaId,
    String empleadoId,
    int anio,
  ) async {
    final snap = await _db
        .collection('vacaciones')
        .doc(empresaId)
        .collection('saldos')
        .where('empleado_id', isEqualTo: empleadoId)
        .where('anio', isEqualTo: anio)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return SaldoVacaciones.fromMap(snap.docs.first.data());
  }

  Future<void> _guardarSaldo(String empresaId, SaldoVacaciones saldo) async {
    await _saldoDoc(empresaId, '${saldo.empleadoId}_${saldo.anio}')
        .set(saldo.toMap(), SetOptions(merge: true));
  }

  Future<void> _actualizarSaldoDisfrutado(
    String empresaId,
    String empleadoId,
    int anio,
    double diasNuevos,
  ) async {
    final docId = '${empleadoId}_$anio';
    final ref = _db
        .collection('vacaciones')
        .doc(empresaId)
        .collection('saldos')
        .doc(docId);
    final doc = await ref.get();
    if (doc.exists) {
      final saldo = SaldoVacaciones.fromMap(doc.data()!);
      final actualizado = saldo.copyWith(
        diasDisfrutados: saldo.diasDisfrutados + diasNuevos,
        diasPendientes: saldo.diasPendientes - diasNuevos,
        ultimaActualizacion: DateTime.now(),
      );
      await ref.set(actualizado.toMap(), SetOptions(merge: true));
    } else {
      // Calcular saldo si no existe
      await calcularSaldo(empresaId, empleadoId, anio);
    }
  }

  /// Obtiene saldo almacenado como stream.
  Stream<SaldoVacaciones?> obtenerSaldoStream(
    String empresaId,
    String empleadoId,
    int anio,
  ) {
    return _saldoDoc(empresaId, '${empleadoId}_$anio')
        .snapshots()
        .map((s) => s.exists ? SaldoVacaciones.fromMap(s.data()!) : null);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTEGRACIÓN CON NÓMINA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula el descuento total por ausencias injustificadas de un empleado en un mes.
  Future<double> calcularDescuentoMes(
    String empresaId,
    String empleadoId,
    int anio,
    int mes,
    double salarioBrutoMensual,
  ) async {
    final ausencias = await obtenerAusenciasMes(
      empresaId,
      anio,
      mes,
      empleadoId: empleadoId,
    );

    double totalDescuento = 0;
    final dias = diasEnMes(anio, mes);

    for (final a in ausencias) {
      if (a.tipo == TipoAusencia.ausenciaInjustificada) {
        final diasEnEsteMes = diasEnMesDeSolicitud(a, anio, mes);
        totalDescuento += calcularDescuentoAusencia(
          salarioBrutoMensual: salarioBrutoMensual,
          diasMes: dias,
          diasAusencia: diasEnEsteMes,
        );
      }
    }

    return totalDescuento;
  }

  /// Obtiene las líneas informativas de ausencias/permisos para la nómina.
  Future<List<Map<String, dynamic>>> obtenerLineasNomina(
    String empresaId,
    String empleadoId,
    int anio,
    int mes,
    double salarioBrutoMensual,
  ) async {
    final ausencias = await obtenerAusenciasMes(
      empresaId,
      anio,
      mes,
      empleadoId: empleadoId,
    );

    final lineas = <Map<String, dynamic>>[];
    final dias = diasEnMes(anio, mes);

    for (final a in ausencias) {
      final diasEnEsteMes = diasEnMesDeSolicitud(a, anio, mes);
      if (diasEnEsteMes <= 0) continue;

      if (a.tipo == TipoAusencia.ausenciaInjustificada) {
        final descuento = calcularDescuentoAusencia(
          salarioBrutoMensual: salarioBrutoMensual,
          diasMes: dias,
          diasAusencia: diasEnEsteMes,
        );
        lineas.add({
          'concepto': 'Ausencia injustificada ($diasEnEsteMes días)',
          'importe': -descuento,
          'tipo': 'descuento',
        });
      } else if (a.tipo == TipoAusencia.permisoRetribuido) {
        final nombre = a.subtipo?.etiqueta ?? 'Permiso retribuido';
        lineas.add({
          'concepto': '$nombre ($diasEnEsteMes días)',
          'importe': 0.0,
          'tipo': 'informativo',
        });
      } else if (a.tipo == TipoAusencia.vacaciones) {
        lineas.add({
          'concepto': 'Vacaciones ($diasEnEsteMes días)',
          'importe': 0.0,
          'tipo': 'informativo',
        });
      } else if (a.tipo == TipoAusencia.ausenciaJustificada) {
        lineas.add({
          'concepto': 'Ausencia justificada ($diasEnEsteMes días)',
          'importe': 0.0,
          'tipo': 'informativo',
        });
      }
    }

    return lineas;
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  /// Elimina una solicitud (solo si está en estado solicitado).
  Future<void> eliminarSolicitud(String empresaId, String solicitudId) async {
    final doc = await _solicitudes(empresaId).doc(solicitudId).get();
    if (!doc.exists) return;
    final estado = doc.data()?['estado'] as String?;
    if (estado == EstadoSolicitud.solicitado.name) {
      await doc.reference.delete();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOLAPAMIENTO Y VISIBILIDAD CALENDARIO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtiene TODAS las solicitudes del mes (aprobadas + pendientes + rechazadas).
  /// Útil para el calendario visual que muestra todos los estados.
  Future<List<SolicitudVacaciones>> obtenerTodasAusenciasMes(
    String empresaId,
    int anio,
    int mes, {
    String? empleadoId,
  }) async {
    final inicioMes = DateTime(anio, mes, 1);
    final finMes = DateTime(anio, mes + 1, 0, 23, 59, 59);

    Query<Map<String, dynamic>> query = _solicitudes(empresaId);
    if (empleadoId != null) {
      query = query.where('empleado_id', isEqualTo: empleadoId);
    }

    final snap = await query.get();
    final todas = snap.docs
        .map((d) => SolicitudVacaciones.fromMap({...d.data(), 'id': d.id}))
        .toList();

    return todas.where((s) {
      return s.fechaInicio.isBefore(finMes) && s.fechaFin.isAfter(inicioMes);
    }).toList();
  }

  /// Detecta cuántos empleados tienen solicitudes APROBADAS que se solapan
  /// con el período dado (excluyendo opcionalmente a un empleado concreto).
  /// Se usa para alertar al manager antes de aprobar.
  Future<ResultadoSolapamiento> detectarSolapamiento(
    String empresaId,
    DateTime inicio,
    DateTime fin, {
    String? excluirEmpleadoId,
  }) async {
    // Obtener todas las solicitudes aprobadas de la empresa
    final snap = await _solicitudes(empresaId)
        .where('estado', isEqualTo: EstadoSolicitud.aprobado.name)
        .get();

    final todas = snap.docs
        .map((d) => SolicitudVacaciones.fromMap({...d.data(), 'id': d.id}))
        .toList();

    // Filtrar las que se solapan con el período dado
    final solapadas = todas.where((s) {
      if (excluirEmpleadoId != null && s.empleadoId == excluirEmpleadoId) {
        return false;
      }
      final inicioSol = DateTime(s.fechaInicio.year, s.fechaInicio.month, s.fechaInicio.day);
      final finSol = DateTime(s.fechaFin.year, s.fechaFin.month, s.fechaFin.day);
      final inicioRef = DateTime(inicio.year, inicio.month, inicio.day);
      final finRef = DateTime(fin.year, fin.month, fin.day);
      return inicioSol.isBefore(finRef.add(const Duration(days: 1))) &&
          finSol.isAfter(inicioRef.subtract(const Duration(days: 1)));
    }).toList();

    // Empleados únicos ausentes
    final Map<String, String> empleadosAusentes = {};
    for (final s in solapadas) {
      empleadosAusentes[s.empleadoId] =
          s.empleadoNombre ?? s.empleadoId;
    }

    // Total de empleados activos de la empresa
    int totalEmpleados = 0;
    try {
      final empSnap = await _db
          .collection('usuarios')
          .where('empresa_id', isEqualTo: empresaId)
          .where('activo', isEqualTo: true)
          .get();
      totalEmpleados = empSnap.docs.length;
    } catch (_) {
      totalEmpleados = empleadosAusentes.length + 1; // fallback
    }

    final ausentes = empleadosAusentes.length;
    final porcentaje =
        totalEmpleados > 0 ? (ausentes / totalEmpleados) * 100.0 : 0.0;

    return ResultadoSolapamiento(
      empleadosAusentes: ausentes,
      totalEmpleados: totalEmpleados,
      porcentaje: porcentaje,
      nombresAusentes: empleadosAusentes.values.toList(),
    );
  }
}




