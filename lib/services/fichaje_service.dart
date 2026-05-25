import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../domain/modelos/fichaje.dart';

/// Servicio de control horario / fichaje de empleados
class FichajeService {
  static final FichajeService _i = FichajeService._();

  factory FichajeService() => _i;

  FichajeService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _fichajes(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('fichajes');

  // ── FICHAR ENTRADA ────────────────────────────────────────────────────────

  /// Verifica si el empleado ya tiene una entrada activa (sin salida posterior) hoy.
  Future<bool> _tieneEntradaActiva(String empleadoId, String empresaId) async {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);

    final query = await _fichajes(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('eliminado', isEqualTo: false)
        .where(
        'timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;
    final ultimoTipo = query.docs.first.data()['tipo'] as String?;
    // 'entrada' o 'pausa_fin' = sigue "dentro"
    return ultimoTipo == 'entrada' || ultimoTipo == 'pausa_fin';
  }

  Future<RegistroFichaje> ficharEntrada({
    required String empresaId,
    required String empleadoId,
    required String empleadoNombre,
    double? latitud,
    double? longitud,
  }) async {
    // ── Validación: evitar doble entrada ─────────────────────────────────
    final tieneEntrada = await _tieneEntradaActiva(empleadoId, empresaId);
    if (tieneEntrada) {
      throw Exception('Ya tienes una entrada activa. Ficha la salida primero.');
    }

    final registro = RegistroFichaje(
      id: '',
      empleadoId: empleadoId,
      empresaId: empresaId,
      empleadoNombre: empleadoNombre,
      tipo: TipoFichaje.entrada,
      timestamp: DateTime.now(),
      latitud: latitud,
      longitud: longitud,
    );
    final docRef = await _fichajes(empresaId).add(registro.toMap());
    return RegistroFichaje(
      id: docRef.id,
      empleadoId: registro.empleadoId,
      empresaId: registro.empresaId,
      empleadoNombre: registro.empleadoNombre,
      tipo: registro.tipo,
      timestamp: registro.timestamp,
      latitud: registro.latitud,
      longitud: registro.longitud,
    );
  }

  // ── FICHAR SALIDA ─────────────────────────────────────────────────────────

  Future<RegistroFichaje> ficharSalida({
    required String empresaId,
    required String empleadoId,
    required String empleadoNombre,
    double? latitud,
    double? longitud,
    String? firmaTipo,
    bool? firmaConfirmada,
  }) async {
    final registro = RegistroFichaje(
      id: '',
      empleadoId: empleadoId,
      empresaId: empresaId,
      empleadoNombre: empleadoNombre,
      tipo: TipoFichaje.salida,
      timestamp: DateTime.now(),
      latitud: latitud,
      longitud: longitud,
      firmaTipo: firmaTipo,
      firmaConfirmada: firmaConfirmada,
    );
    final docRef = await _fichajes(empresaId).add(registro.toMap());
    return RegistroFichaje(
      id: docRef.id,
      empleadoId: registro.empleadoId,
      empresaId: registro.empresaId,
      empleadoNombre: registro.empleadoNombre,
      tipo: registro.tipo,
      timestamp: registro.timestamp,
      latitud: registro.latitud,
      longitud: registro.longitud,
      firmaTipo: registro.firmaTipo,
      firmaConfirmada: registro.firmaConfirmada,
    );
  }

  // ── FICHAR PAUSA ──────────────────────────────────────────────────────────

  Future<RegistroFichaje> ficharPausaInicio({
    required String empresaId,
    required String empleadoId,
    required String empleadoNombre,
    double? latitud,
    double? longitud,
  }) async {
    final registro = RegistroFichaje(
      id: '',
      empleadoId: empleadoId,
      empresaId: empresaId,
      empleadoNombre: empleadoNombre,
      tipo: TipoFichaje.pausaInicio,
      timestamp: DateTime.now(),
      latitud: latitud,
      longitud: longitud,
    );
    final docRef = await _fichajes(empresaId).add(registro.toMap());
    return RegistroFichaje(
      id: docRef.id,
      empleadoId: registro.empleadoId,
      empresaId: registro.empresaId,
      empleadoNombre: registro.empleadoNombre,
      tipo: registro.tipo,
      timestamp: registro.timestamp,
      latitud: registro.latitud,
      longitud: registro.longitud,
    );
  }

  Future<RegistroFichaje> ficharPausaFin({
    required String empresaId,
    required String empleadoId,
    required String empleadoNombre,
    double? latitud,
    double? longitud,
  }) async {
    final registro = RegistroFichaje(
      id: '',
      empleadoId: empleadoId,
      empresaId: empresaId,
      empleadoNombre: empleadoNombre,
      tipo: TipoFichaje.pausaFin,
      timestamp: DateTime.now(),
      latitud: latitud,
      longitud: longitud,
    );
    final docRef = await _fichajes(empresaId).add(registro.toMap());
    return RegistroFichaje(
      id: docRef.id,
      empleadoId: registro.empleadoId,
      empresaId: registro.empresaId,
      empleadoNombre: registro.empleadoNombre,
      tipo: registro.tipo,
      timestamp: registro.timestamp,
      latitud: registro.latitud,
      longitud: registro.longitud,
    );
  }

  // ── ESTADO ACTUAL ─────────────────────────────────────────────────────────

  /// Obtiene el último fichaje de un empleado hoy para saber si está trabajando
  Stream<RegistroFichaje?> ultimoFichajeHoy(String empresaId,
      String empleadoId) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return _fichajes(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where(
        'timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return RegistroFichaje.fromMap(
          snap.docs.first.data(), snap.docs.first.id);
    });
  }

  // ── FICHAJES DEL DÍA ─────────────────────────────────────────────────────

  Stream<List<RegistroFichaje>> fichajesDelDia(String empresaId,
      String empleadoId, DateTime dia) {
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fin = inicio.add(const Duration(days: 1));
    return _fichajes(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('timestamp', isLessThan: Timestamp.fromDate(fin))
        .orderBy('timestamp')
        .snapshots()
        .map((snap) =>
        snap.docs
            .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
            .toList());
  }

  // ── FICHAJES DE TODOS LOS EMPLEADOS HOY (ADMIN) ──────────────────────────

  Stream<List<RegistroFichaje>> fichajesHoyTodos(String empresaId) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return _fichajes(empresaId)
        .where(
        'timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs
            .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
            .toList());
  }

  // ── CALCULAR HORAS TRABAJADAS EN UN DÍA ───────────────────────────────────

  double calcularHorasDia(List<RegistroFichaje> fichajesDia) {
    final resumen = calcularResumenDia(fichajesDia);
    return resumen.horasNetas;
  }

  ResumenCalculoHoras calcularResumenDia(List<RegistroFichaje> fichajesDia) {
    double minutosBrutos = 0;
    int minutosPausa = 0;
    final List<Map<String, dynamic>> pausas = [];

    RegistroFichaje? entradaActual;
    RegistroFichaje? pausaActual;

    for (final f in fichajesDia) {
      switch (f.tipo) {
        case TipoFichaje.entrada:
          entradaActual = f;
        case TipoFichaje.pausaInicio:
          pausaActual = f;
        case TipoFichaje.pausaFin:
          if (pausaActual != null) {
            final duracion = f.timestamp
                .difference(pausaActual.timestamp)
                .inMinutes;
            minutosPausa += duracion;
            pausas.add({
              'inicio': pausaActual.timestamp,
              'fin': f.timestamp,
              'duracion_minutos': duracion,
            });
            pausaActual = null;
          }
        case TipoFichaje.salida:
          if (entradaActual != null) {
            minutosBrutos += f.timestamp
                .difference(entradaActual.timestamp)
                .inMinutes;
            entradaActual = null;
          }
      }
    }

    if (entradaActual != null) {
      minutosBrutos += DateTime
          .now()
          .difference(entradaActual.timestamp)
          .inMinutes;
    }

    final horasBrutas = minutosBrutos / 60.0;
    final horasNetas = ((minutosBrutos - minutosPausa) / 60.0)
        .clamp(0.0, double.infinity);

    return ResumenCalculoHoras(
      horasBrutas: horasBrutas,
      minutasPausa: minutosPausa,
      horasNetas: horasNetas,
      pausas: pausas,
    );
  }


  // ── EDITAR FICHAJE (ADMIN) ────────────────────────────────────────────────

  Future<void> editarFichaje(String empresaId, String fichajeId,
      DateTime nuevoTimestamp,
      {String? motivo}) async {
    final doc = await _fichajes(empresaId).doc(fichajeId).get();

    await _fichajes(empresaId)
        .doc(fichajeId)
        .collection('historial')
        .add({
      'valor_anterior': doc.data(),
      'editado_por': FirebaseAuth.instance.currentUser?.uid,
      'editado_en': FieldValue.serverTimestamp(),
      'motivo': motivo,
    });

    await _fichajes(empresaId).doc(fichajeId).update({
      'timestamp': Timestamp.fromDate(nuevoTimestamp),
      'editado_por_admin': true,
      'editado_por': FirebaseAuth.instance.currentUser?.uid,
      'editado_en': FieldValue.serverTimestamp(),
    });
  }

  // ── ELIMINAR FICHAJE (ADMIN) ──────────────────────────────────────────────
  Future<void> eliminarFichaje(String empresaId, String fichajeId) async {
    final doc = await _fichajes(empresaId).doc(fichajeId).get();
    await _fichajes(empresaId).doc(fichajeId).update({
      'eliminado': true,
      'eliminado_por': FirebaseAuth.instance.currentUser?.uid,
      'eliminado_en': FieldValue.serverTimestamp(),
      'valor_original_antes_borrar': doc.data(),
    });
  }

  // ── RESUMEN SEMANAL ───────────────────────────────────────────────────────

  Future<List<ResumenDiaFichaje>> resumenSemanal(String empresaId,
      String empleadoId, DateTime semana) async {
    // semana es el lunes de la semana
    final lunes = semana.subtract(Duration(days: semana.weekday - 1));
    final domingo = lunes.add(const Duration(days: 7));

    final snap = await _fichajes(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(lunes))
        .where('timestamp', isLessThan: Timestamp.fromDate(domingo))
        .orderBy('timestamp')
        .get();

    final fichajes = snap.docs
        .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
        .toList();

    // Agrupar por día
    final Map<String, List<RegistroFichaje>> porDia = {};
    for (final f in fichajes) {
      final key = DateFormat('yyyy-MM-dd').format(f.timestamp);
      porDia.putIfAbsent(key, () => []).add(f);
    }

    final List<ResumenDiaFichaje> resumen = [];
    for (int i = 0; i < 7; i++) {
      final dia = lunes.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(dia);
      final fichajesDia = porDia[key] ?? [];
      final horas = calcularHorasDia(fichajesDia);
      final entrada = fichajesDia.isNotEmpty &&
          fichajesDia.first.tipo == TipoFichaje.entrada
          ? fichajesDia.first.timestamp
          : null;
      final salida = fichajesDia.isNotEmpty &&
          fichajesDia.last.tipo == TipoFichaje.salida
          ? fichajesDia.last.timestamp
          : null;

      resumen.add(ResumenDiaFichaje(
        fecha: dia,
        empleadoId: empleadoId,
        entrada: entrada,
        salida: salida,
        horasTrabajadas: horas,
        horasExtra: horas > 8 ? horas - 8 : null,
        fichajePendiente: entrada != null && salida == null,
      ));
    }
    return resumen;
  }

  // ── EXPORTAR CSV ──────────────────────────────────────────────────────────

  Future<String> exportarCsv(
      String empresaId,
      DateTime desde,
      DateTime hasta, {
        String? empleadoId,
        Map<String, dynamic> datosEmpresa = const {},
      }) async {
    final snap = await _fichajes(empresaId)
        .where('timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('timestamp', isLessThan: Timestamp.fromDate(hasta))
        .orderBy('timestamp')
        .get();

    final todos = snap.docs
        .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
        .where((f) => !f.eliminado)
        .where((f) => empleadoId == null || f.empleadoId == empleadoId)
        .toList();

    final nombreEmpresa =
        datosEmpresa['nombre'] as String? ?? 'Empresa';
    final cif = datosEmpresa['cif'] as String? ?? '';
    final email = datosEmpresa['email'] as String? ?? '';
    final telefono = datosEmpresa['telefono'] as String? ?? '';
    final fmtFecha = DateFormat('dd/MM/yyyy');
    final fmtHora = DateFormat('HH:mm');

    final buffer = StringBuffer();
    buffer.writeln(
        'Empresa: $nombreEmpresa | CIF: $cif | Email: $email | Teléfono: $telefono');
    buffer.writeln(
        'Período: ${fmtFecha.format(desde)} - ${fmtFecha.format(hasta)}');
    buffer.writeln();
    buffer.writeln(
        'Empleado,DNI,Fecha,Día semana,Hora entrada,Hora salida,'
            'Horas brutas,Minutos pausa,Horas netas,Horas extra,Editado,Notas');

    final porEmpleadoDia = <String, Map<String, List<RegistroFichaje>>>{};
    for (final f in todos) {
      final diaKey = DateFormat('yyyy-MM-dd').format(f.timestamp);
      porEmpleadoDia
          .putIfAbsent(f.empleadoId, () => {})
          .putIfAbsent(diaKey, () => [])
          .add(f);
    }

    for (final entry in porEmpleadoDia.entries) {
      for (final diaEntry in entry.value.entries) {
        final fichajesDia = diaEntry.value
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final resumen = calcularResumenDia(fichajesDia);
        final entrada = fichajesDia
            .where((f) => f.tipo == TipoFichaje.entrada)
            .map((f) => fmtHora.format(f.timestamp))
            .firstOrNull ?? '';
        final salida = fichajesDia
            .where((f) => f.tipo == TipoFichaje.salida)
            .map((f) => fmtHora.format(f.timestamp))
            .lastOrNull ?? '';
        final fecha =
        DateFormat('dd/MM/yyyy').format(fichajesDia.first.timestamp);
        final diaSemana = DateFormat('EEEE', 'es_ES')
            .format(fichajesDia.first.timestamp);
        final editado =
        fichajesDia.any((f) => f.editadoPorAdmin) ? 'Sí' : 'No';
        final notas = fichajesDia
            .map((f) => f.notas ?? '')
            .where((n) => n.isNotEmpty)
            .join(' | ');
        final horasExtra = resumen.horasNetas > 8
            ? (resumen.horasNetas - 8).toStringAsFixed(2)
            : '0';
        final nombre = fichajesDia.first.empleadoNombre;

        buffer.writeln(
            '$nombre,,${fecha},$diaSemana,$entrada,$salida,'
                '${resumen.horasBrutas.toStringAsFixed(2)},'
                '${resumen.minutasPausa},'
                '${resumen.horasNetas.toStringAsFixed(2)},'
                '$horasExtra,$editado,$notas');
      }
    }
    return buffer.toString();
  }
  Future<String> exportarCsvInspeccion(
      String empresaId,
      DateTime desde,
      DateTime hasta, {
        String? empleadoId,
        Map<String, dynamic> datosEmpresa = const {},
      }) async {
    final snap = await _fichajes(empresaId)
        .where('timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('timestamp', isLessThan: Timestamp.fromDate(hasta))
        .orderBy('timestamp')
        .get();

    final todos = snap.docs
        .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
        .where((f) => !f.eliminado)
        .where((f) => empleadoId == null || f.empleadoId == empleadoId)
        .toList();

    final nombreEmpresa = datosEmpresa['nombre'] as String? ?? 'Empresa';
    final cif = datosEmpresa['cif'] as String? ?? '';
    final email = datosEmpresa['email'] as String? ?? '';
    final telefono = datosEmpresa['telefono'] as String? ?? '';
    final fmtFecha = DateFormat('dd/MM/yyyy');
    final fmtHora = DateFormat('HH:mm');

    final buffer = StringBuffer();
    buffer.writeln(
        'Empresa: $nombreEmpresa | CIF: $cif | Email: $email | Teléfono: $telefono');
    buffer.writeln(
        'Período: ${fmtFecha.format(desde)} - ${fmtFecha.format(hasta)}');
    buffer.writeln();
    buffer.writeln(
        'Empleado,DNI,Fecha,Día semana,Hora entrada,Hora salida,'
            'Horas brutas,Minutos pausa,Horas netas,Horas extra,Editado,Notas');

    final porEmpleadoDia = <String, Map<String, List<RegistroFichaje>>>{};
    for (final f in todos) {
      final diaKey = DateFormat('yyyy-MM-dd').format(f.timestamp);
      porEmpleadoDia
          .putIfAbsent(f.empleadoId, () => {})
          .putIfAbsent(diaKey, () => [])
          .add(f);
    }

    for (final empEntry in porEmpleadoDia.entries) {
      for (final diaEntry in empEntry.value.entries) {
        final fichajesDia = diaEntry.value
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final resumen = calcularResumenDia(fichajesDia);
        final entrada = fichajesDia
            .where((f) => f.tipo == TipoFichaje.entrada)
            .map((f) => fmtHora.format(f.timestamp))
            .firstOrNull ?? '';
        final salida = fichajesDia
            .where((f) => f.tipo == TipoFichaje.salida)
            .map((f) => fmtHora.format(f.timestamp))
            .lastOrNull ?? '';
        final fecha = fmtFecha.format(fichajesDia.first.timestamp);
        final diaSemana = DateFormat('EEEE', 'es_ES')
            .format(fichajesDia.first.timestamp);
        final editado =
        fichajesDia.any((f) => f.editadoPorAdmin) ? 'Sí' : 'No';
        final notas = fichajesDia
            .map((f) => f.notas ?? '')
            .where((n) => n.isNotEmpty)
            .join(' | ');
        final horasExtra = resumen.horasNetas > 8
            ? (resumen.horasNetas - 8).toStringAsFixed(2)
            : '0';

        buffer.writeln(
            '${fichajesDia.first.empleadoNombre},,$fecha,$diaSemana,'
                '$entrada,$salida,'
                '${resumen.horasBrutas.toStringAsFixed(2)},'
                '${resumen.minutasPausa},'
                '${resumen.horasNetas.toStringAsFixed(2)},'
                '$horasExtra,$editado,$notas');
      }
    }
    return buffer.toString();
  }
  // ── ALERTAS: FICHAJES PENDIENTES (>9 HORAS) ──────────────────────────────

  Future<List<RegistroFichaje>> fichajesPendientesAlerta(
      String empresaId) async {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final limite = hoy.subtract(const Duration(hours: 9));

    final snap = await _fichajes(empresaId)
        .where('tipo', isEqualTo: 'entrada')
        .where(
        'timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(limite))
        .get();

    final entradas = snap.docs
        .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
        .toList();

    // Filtrar los que no tienen salida después
    final List<RegistroFichaje> sinSalida = [];
    for (final entrada in entradas) {
      final salidaSnap = await _fichajes(empresaId)
          .where('empleado_id', isEqualTo: entrada.empleadoId)
          .where('tipo', isEqualTo: 'salida')
          .where(
          'timestamp', isGreaterThan: Timestamp.fromDate(entrada.timestamp))
          .limit(1)
          .get();
      if (salidaSnap.docs.isEmpty) {
        sinSalida.add(entrada);
      }
    }
    return sinSalida;
  }
}
class ResumenCalculoHoras {
  final double horasBrutas;
  final int minutasPausa;
  final double horasNetas;
  final List<Map<String, dynamic>> pausas;

  const ResumenCalculoHoras({
    required this.horasBrutas,
    required this.minutasPausa,
    required this.horasNetas,
    required this.pausas,
  });
}


