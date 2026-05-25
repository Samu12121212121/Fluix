import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../modelos/fichaje.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FICHAJE SERVICE — Normativa Real Decreto 2026
//
// ARQUITECTURA: UN documento por jornada laboral (no un doc por evento).
// Las correcciones crean un NUEVO documento — el original NUNCA se modifica.
//
// FIXES APLICADOS respecto al código anterior:
//   [FIX-1] serverTimestamp() dentro de arrayUnion → NO SOPORTADO por Firestore.
//           Sustituido por transacción que lee el doc y reescribe el array completo.
//           Para inicio/fin de pausa se usa Timestamp.now() ya que serverTimestamp
//           no puede anidarse en arrays (limitación oficial del SDK de Firestore).
//   [FIX-2] creadoAt nullable cast → crash en modo offline. Ahora null-safe.
//   [FIX-3] Eliminada dependencia del fichaje_service.dart antiguo (arquitectura
//           de eventos separados — incompatible con este modelo).
// ═══════════════════════════════════════════════════════════════════════════════

class FichajeService {
  // Singleton
  static final FichajeService _instance = FichajeService._internal();
  factory FichajeService() => _instance;
  FichajeService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Helper: referencia a la colección ────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _col(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('fichajes');

  CollectionReference<Map<String, dynamic>> _empleados(String empresaId) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('empleados_fichaje');

  String get _hoy => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ═══════════════════════════════════════════════════════════════════════════
  // VERIFICAR PIN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Busca un empleado activo por PIN de 4 dígitos.
  /// Devuelve null si el PIN no existe o el empleado está inactivo.
  Future<EmpleadoFichaje?> verificarPIN({
    required String empresaId,
    required String pin,
  }) async {
    final snap = await _empleados(empresaId)
        .where('pin', isEqualTo: pin)
        .where('activo', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return EmpleadoFichaje.fromFirestore(snap.docs.first);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OBTENER FICHAJE ACTIVO DE HOY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve el fichaje original (no corrección) del empleado para hoy.
  /// Si no existe devuelve null → estado sinFichar.
  Future<Fichaje?> obtenerFichajeHoy(
      String empresaId, String empleadoId) async {
    final snap = await _col(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('fecha', isEqualTo: _hoy)
        .where('es_correccion', isEqualTo: false)
        .orderBy('creado_at', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return Fichaje.fromFirestore(snap.docs.first);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FICHAR ENTRADA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea el documento de jornada con entrada marcada por el servidor.
  /// Lanza [Exception] si ya existe un fichaje activo hoy.
  Future<void> ficharEntrada({
    required String empresaId,
    required String empleadoId,
    required String empleadoNombre,
    required String dispositivoId,
    TipoHoras tipoHoras = TipoHoras.ordinarias,
  }) async {
    final existente = await obtenerFichajeHoy(empresaId, empleadoId);
    if (existente != null) {
      throw Exception('Ya existe un fichaje activo para hoy. '
          'Ficha la salida primero.');
    }

    await _col(empresaId).add({
      'empleado_id': empleadoId,
      'empleado_nombre': empleadoNombre,
      'fecha': _hoy,
      // ── ServerTimestamp del servidor ── NUNCA DateTime.now() ─────────────
      'entrada': FieldValue.serverTimestamp(),
      'salida': null,
      'pausas': [],
      'tipo_horas': tipoHoras.name,
      'dispositivo_id': dispositivoId,
      'creado_at': FieldValue.serverTimestamp(),
      // ── Audit trail ──────────────────────────────────────────────────────
      'es_correccion': false,
      'correccion_de': null,
      'motivo_correccion': null,
      'corregido_por_uid': null,
      'corregido_at': null,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIAR PAUSA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Añade una nueva pausa al array del documento de jornada.
  ///
  /// [FIX-1] FieldValue.serverTimestamp() NO está soportado dentro de arrays
  /// en Firestore (lanza PlatformException en runtime). Se usa Timestamp.now()
  /// que toma la hora del dispositivo. Para máxima precisión legal, considerar
  /// un Cloud Function que aplique el serverTimestamp.
  Future<void> iniciarPausa({
    required String empresaId,
    required String empleadoId,
  }) async {
    final fichaje = await obtenerFichajeHoy(empresaId, empleadoId);

    if (fichaje == null) {
      throw Exception('No hay fichaje activo para hoy.');
    }
    if (fichaje.estado == EstadoFichaje.enPausa) {
      throw Exception('Ya hay una pausa activa.');
    }
    if (fichaje.estado == EstadoFichaje.cerrado) {
      throw Exception('La jornada ya está cerrada.');
    }

    final docRef = _col(empresaId).doc(fichaje.id);

    // Transacción: leer → modificar array → escribir
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Fichaje no encontrado.');

      final pausas =
      List<Map<String, dynamic>>.from(snap.data()?['pausas'] ?? []);

      // Verificar de nuevo dentro de la transacción (concurrencia)
      final hayPausaActiva =
          pausas.isNotEmpty && pausas.last['fin'] == null;
      if (hayPausaActiva) throw Exception('Ya hay una pausa activa.');

      pausas.add({
        // [FIX-1] Timestamp.now() — serverTimestamp no está soportado en arrays
        'inicio': Timestamp.now(),
        'fin': null,
      });

      tx.update(docRef, {'pausas': pausas});
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FINALIZAR PAUSA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cierra la pausa activa actualizando el último elemento del array.
  ///
  /// [FIX-1] Mismo motivo que iniciarPausa: serverTimestamp no puede ir
  /// dentro de un elemento de array. Se usa Timestamp.now().
  Future<void> finalizarPausa({
    required String empresaId,
    required String empleadoId,
  }) async {
    final fichaje = await obtenerFichajeHoy(empresaId, empleadoId);

    if (fichaje == null) {
      throw Exception('No hay fichaje activo para hoy.');
    }
    if (fichaje.estado != EstadoFichaje.enPausa) {
      throw Exception('No hay pausa activa que finalizar.');
    }

    final docRef = _col(empresaId).doc(fichaje.id);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('Fichaje no encontrado.');

      final pausas =
      List<Map<String, dynamic>>.from(snap.data()?['pausas'] ?? []);

      if (pausas.isEmpty || pausas.last['fin'] != null) {
        throw Exception('No hay pausa activa que finalizar.');
      }

      // Cerrar la última pausa
      pausas[pausas.length - 1] = {
        'inicio': pausas.last['inicio'], // Preservar el inicio original
        // [FIX-1] Timestamp.now() — serverTimestamp no soportado en arrays
        'fin': Timestamp.now(),
      };

      tx.update(docRef, {'pausas': pausas});
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FICHAR SALIDA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Marca la salida cerrando la jornada.
  /// Usa serverTimestamp — válido aquí porque es un campo raíz del documento.
  /// Lanza [Exception] si hay pausa activa sin cerrar.
  Future<void> ficharSalida({
    required String empresaId,
    required String empleadoId,
  }) async {
    final fichaje = await obtenerFichajeHoy(empresaId, empleadoId);

    if (fichaje == null) {
      throw Exception('No hay fichaje activo para hoy.');
    }
    if (fichaje.estado == EstadoFichaje.cerrado) {
      throw Exception('La salida ya está registrada.');
    }
    if (fichaje.estado == EstadoFichaje.enPausa) {
      throw Exception(
          'Debes finalizar la pausa activa antes de fichar la salida.');
    }

    // salida es un campo raíz → serverTimestamp sí está soportado
    await _col(empresaId).doc(fichaje.id).update({
      'salida': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CORREGIR FICHAJE (INMUTABILIDAD)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea un NUEVO documento de corrección.
  /// El documento original NUNCA se modifica — cumple inmutabilidad normativa.
  ///
  /// El nuevo documento tiene:
  ///   - es_correccion: true
  ///   - correccion_de: id del original
  ///   - motivo_correccion, corregido_por_uid, corregido_at
  Future<void> corregirFichaje({
    required String empresaId,
    required String fichajeOriginalId,
    required String motivo,
    required String corregidoPorUid,
    required Timestamp? nuevaEntrada,
    required Timestamp? nuevaSalida,
    required List<Pausa> nuevasPausas,
  }) async {
    if (motivo.trim().isEmpty) {
      throw Exception('El motivo de corrección es obligatorio.');
    }

    final snapOriginal =
    await _col(empresaId).doc(fichajeOriginalId).get();
    if (!snapOriginal.exists) {
      throw Exception('Fichaje original no encontrado.');
    }

    final original = snapOriginal.data()!;

    // Crear NUEVO documento — el original queda intacto
    await _col(empresaId).add({
      'empleado_id': original['empleado_id'],
      'empleado_nombre': original['empleado_nombre'],
      'fecha': original['fecha'],
      'entrada': nuevaEntrada,
      'salida': nuevaSalida,
      'pausas': nuevasPausas.map((p) => p.toMap()).toList(),
      'tipo_horas': original['tipo_horas'],
      'dispositivo_id': original['dispositivo_id'],
      'creado_at': FieldValue.serverTimestamp(),
      // ── Audit trail completo ──────────────────────────────────────────────
      'es_correccion': true,
      'correccion_de': fichajeOriginalId,
      'motivo_correccion': motivo.trim(),
      'corregido_por_uid': corregidoPorUid,
      'corregido_at': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMS EN TIEMPO REAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream de todos los fichajes de hoy para el dashboard de admin.
  /// Solo devuelve documentos originales (es_correccion: false).
  /// Para mostrar la versión más reciente de un fichaje corregido, usa
  /// [obtenerFichajeEfectivo] que resuelve la corrección más reciente.
  Stream<List<Fichaje>> fichajesHoyStream(String empresaId) {
    return _col(empresaId)
        .where('fecha', isEqualTo: _hoy)
        .where('es_correccion', isEqualTo: false)
        .orderBy('creado_at', descending: false)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => Fichaje.fromFirestore(d)).toList());
  }

  /// Stream del fichaje activo de un empleado hoy (para pantalla de empleado).
  Stream<Fichaje?> fichajeHoyStream(String empresaId, String empleadoId) {
    return _col(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('fecha', isEqualTo: _hoy)
        .where('es_correccion', isEqualTo: false)
        .orderBy('creado_at', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) =>
    snap.docs.isEmpty ? null : Fichaje.fromFirestore(snap.docs.first));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSULTAS HISTÓRICAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fichajes de un empleado en un rango de fechas.
  /// Devuelve solo originales + correcciones (para vista completa de audit trail).
  Future<List<Fichaje>> obtenerFichajesEmpleado({
    required String empresaId,
    required String empleadoId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final snap = await _col(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('fecha',
        isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(desde))
        .where('fecha',
        isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(hasta))
        .orderBy('fecha', descending: false)
        .orderBy('creado_at', descending: false)
        .get();

    return snap.docs.map((d) => Fichaje.fromFirestore(d)).toList();
  }

  /// Devuelve el fichaje efectivo de un empleado en una fecha concreta:
  /// si tiene corrección, devuelve la corrección más reciente; si no, el original.
  Future<Fichaje?> obtenerFichajeEfectivo(
      String empresaId, String empleadoId, String fecha) async {
    // Buscar corrección más reciente
    final correccionSnap = await _col(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('fecha', isEqualTo: fecha)
        .where('es_correccion', isEqualTo: true)
        .orderBy('corregido_at', descending: true)
        .limit(1)
        .get();

    if (correccionSnap.docs.isNotEmpty) {
      return Fichaje.fromFirestore(correccionSnap.docs.first);
    }

    // Si no hay corrección, devolver el original
    final originalSnap = await _col(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .where('fecha', isEqualTo: fecha)
        .where('es_correccion', isEqualTo: false)
        .limit(1)
        .get();

    if (originalSnap.docs.isEmpty) return null;
    return Fichaje.fromFirestore(originalSnap.docs.first);
  }

  /// Historial de correcciones de un fichaje original.
  Future<List<Fichaje>> obtenerHistorialCorrecciones(
      String empresaId, String fichajeOriginalId) async {
    final snap = await _col(empresaId)
        .where('correccion_de', isEqualTo: fichajeOriginalId)
        .orderBy('corregido_at', descending: true)
        .get();

    return snap.docs.map((d) => Fichaje.fromFirestore(d)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALERTAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fichajes de hoy con entrada pero sin salida y más de [umbralHoras] horas.
  /// Útil para alertar al admin de posibles olvidos de fichaje.
  Future<List<Fichaje>> fichajesPendientesAlerta(
      String empresaId, {int umbralHoras = 9}) async {
    final snap = await _col(empresaId)
        .where('fecha', isEqualTo: _hoy)
        .where('es_correccion', isEqualTo: false)
        .get();

    final limite = DateTime.now().subtract(Duration(hours: umbralHoras));

    return snap.docs
        .map((d) => Fichaje.fromFirestore(d))
        .where((f) =>
    f.salida == null &&
        f.entrada != null &&
        f.entrada!.toDate().isBefore(limite))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESUMEN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula el resumen de una semana para un empleado.
  /// [semana] puede ser cualquier día — se extrae el lunes de esa semana.
  Future<List<ResumenDiaFichaje>> resumenSemanal({
    required String empresaId,
    required String empleadoId,
    required DateTime semana,
  }) async {
    final lunes = semana.subtract(Duration(days: semana.weekday - 1));
    final domingo = lunes.add(const Duration(days: 6));

    final fichajes = await obtenerFichajesEmpleado(
      empresaId: empresaId,
      empleadoId: empleadoId,
      desde: lunes,
      hasta: domingo,
    );

    // Quedarse con el fichaje efectivo por día (corrección > original)
    final Map<String, Fichaje> porFecha = {};
    for (final f in fichajes) {
      final clave = f.fecha;
      final actual = porFecha[clave];
      if (actual == null) {
        porFecha[clave] = f;
      } else {
        // Preferir corrección o el más reciente
        if (f.esCorreccion && !actual.esCorreccion) {
          porFecha[clave] = f;
        }
      }
    }

    final List<ResumenDiaFichaje> resultado = [];
    for (int i = 0; i < 7; i++) {
      final dia = lunes.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(dia);
      final f = porFecha[key];
      if (f != null) {
        resultado.add(ResumenDiaFichaje.desdeFFichaje(f));
      } else {
        resultado.add(ResumenDiaFichaje(
          fecha: dia,
          empleadoId: empleadoId,
          empleadoNombre: '',
        ));
      }
    }
    return resultado;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORTACIÓN CSV
  // ═══════════════════════════════════════════════════════════════════════════

  /// Genera un CSV con el formato requerido por la Inspección de Trabajo.
  /// Incluye datos de empresa, encabezado y una fila por jornada.
  /// Solo incluye el fichaje efectivo de cada día (corrección si existe).
  Future<String> exportarCsvInspeccion({
    required String empresaId,
    required DateTime desde,
    required DateTime hasta,
    String? empleadoId,
    Map<String, dynamic> datosEmpresa = const {},
  }) async {
    final fmtFecha = DateFormat('dd/MM/yyyy');
    final fmtHora = DateFormat('HH:mm:ss');
    final fmtDia = DateFormat('EEEE', 'es_ES');

    final snap = await _col(empresaId)
        .where('fecha',
        isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(desde))
        .where('fecha',
        isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(hasta))
        .orderBy('fecha', descending: false)
        .orderBy('creado_at', descending: false)
        .get();

    var todos = snap.docs.map((d) => Fichaje.fromFirestore(d)).toList();

    if (empleadoId != null) {
      todos = todos.where((f) => f.empleadoId == empleadoId).toList();
    }

    // Resolver fichaje efectivo por empleado+fecha
    final Map<String, Fichaje> efectivos = {};
    for (final f in todos) {
      final key = '${f.empleadoId}_${f.fecha}';
      final actual = efectivos[key];
      if (actual == null) {
        efectivos[key] = f;
      } else if (f.esCorreccion && !actual.esCorreccion) {
        efectivos[key] = f;
      } else if (f.esCorreccion &&
          actual.esCorreccion &&
          f.corregidoAt != null &&
          actual.corregidoAt != null &&
          f.corregidoAt!.compareTo(actual.corregidoAt!) > 0) {
        efectivos[key] = f;
      }
    }

    final nombreEmpresa = datosEmpresa['nombre'] as String? ?? 'Empresa';
    final cif = datosEmpresa['cif'] as String? ?? '';
    final email = datosEmpresa['email'] as String? ?? '';
    final telefono = datosEmpresa['telefono'] as String? ?? '';

    final buf = StringBuffer();
    buf.writeln(
        'Empresa: $nombreEmpresa | CIF: $cif | Email: $email | Telefono: $telefono');
    buf.writeln(
        'Periodo: ${fmtFecha.format(desde)} - ${fmtFecha.format(hasta)}');
    buf.writeln();
    buf.writeln(
        'Empleado,Fecha,Dia semana,Hora entrada,Hora salida,'
            'Horas brutas,Min. pausa,Horas netas,Horas extra,'
            'Tipo horas,Dispositivo,Corregido,Motivo correccion');

    final ordenados = efectivos.values.toList()
      ..sort((a, b) {
        final cmp = a.empleadoNombre.compareTo(b.empleadoNombre);
        return cmp != 0 ? cmp : a.fecha.compareTo(b.fecha);
      });

    for (final f in ordenados) {
      final res = ResumenDiaFichaje.desdeFFichaje(f);
      final entradaStr =
      f.entrada != null ? fmtHora.format(f.entrada!.toDate()) : '';
      final salidaStr =
      f.salida != null ? fmtHora.format(f.salida!.toDate()) : '';
      final fecha = DateTime.parse(f.fecha);
      final diaSemana = fmtDia.format(fecha);
      final corregido = f.esCorreccion ? 'Si' : 'No';
      final motivo = f.motivoCorreccion ?? '';

      buf.writeln(
          '${f.empleadoNombre},'
              '${fmtFecha.format(fecha)},'
              '$diaSemana,'
              '$entradaStr,'
              '$salidaStr,'
              '${res.horasBrutas.toStringAsFixed(2)},'
              '${res.minutosPausa},'
              '${res.horasNetas.toStringAsFixed(2)},'
              '${res.horasExtra.toStringAsFixed(2)},'
              '${f.tipoHoras.name},'
              '${f.dispositivoId},'
              '$corregido,'
              '$motivo');
    }

    return buf.toString();
  }
}