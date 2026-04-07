 import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de registro individual de tiempo.
class RegistroTiempo {
  final String id;
  final String tareaId;
  final String usuarioId;
  final DateTime inicio;
  final DateTime? fin;
  final int segundos;
  final bool esManual;
  final String? nota;

  const RegistroTiempo({
    required this.id,
    required this.tareaId,
    required this.usuarioId,
    required this.inicio,
    this.fin,
    required this.segundos,
    this.esManual = false,
    this.nota,
  });

  factory RegistroTiempo.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return RegistroTiempo(
      id: doc.id,
      tareaId: d['tarea_id'] as String? ?? '',
      usuarioId: d['usuario_id'] as String? ?? '',
      inicio: _parseTs(d['inicio']),
      fin: d['fin'] != null ? _parseTs(d['fin']) : null,
      segundos: d['segundos'] as int? ?? 0,
      esManual: d['es_manual'] as bool? ?? false,
      nota: d['nota'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'tarea_id': tareaId,
        'usuario_id': usuarioId,
        'inicio': Timestamp.fromDate(inicio),
        'fin': fin != null ? Timestamp.fromDate(fin!) : null,
        'segundos': segundos,
        'es_manual': esManual,
        'nota': nota,
      };

  String get duracionFormateada {
    final h = segundos ~/ 3600;
    final m = (segundos % 3600) ~/ 60;
    final s = segundos % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }
}

/// Servicio de control de tiempo para tareas.
///
/// Usa la subcolección: empresas/{id}/tareas/{id}/registros_tiempo
/// Persiste el cronómetro activo en SharedPreferences para sobrevivir reinicios.
class TiempoTareaService {
  static final TiempoTareaService _i = TiempoTareaService._();
  factory TiempoTareaService() => _i;
  TiempoTareaService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _persistTimer;
  String? _empresaIdActivo;
  String? _tareaIdActivo;
  String? _usuarioIdActivo;
  DateTime? _inicioActivo;

  static const _kPrefEmpresaId = 'cronometro_empresa_id';
  static const _kPrefTareaId   = 'cronometro_tarea_id';
  static const _kPrefUsuarioId = 'cronometro_usuario_id';
  static const _kPrefInicio    = 'cronometro_inicio';

  CollectionReference<Map<String, dynamic>> _col(
    String empresaId,
    String tareaId,
  ) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('tareas')
          .doc(tareaId)
          .collection('registros_tiempo');

  // ── INICIAR ──────────────────────────────────────────────────────────────

  /// Inicia el cronómetro para la tarea indicada.
  /// Si había uno activo previamente, lo guarda antes de iniciar el nuevo.
  Future<void> iniciar({
    required String empresaId,
    required String tareaId,
    required String usuarioId,
  }) async {
    // Si hay uno activo distinto, pausarlo primero
    if (_tareaIdActivo != null && _tareaIdActivo != tareaId) {
      await pausar(
        empresaId: _empresaIdActivo!,
        tareaId: _tareaIdActivo!,
        usuarioId: _usuarioIdActivo!,
      );
    }

    _empresaIdActivo = empresaId;
    _tareaIdActivo = tareaId;
    _usuarioIdActivo = usuarioId;
    _inicioActivo = DateTime.now();

    // Guardar en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefEmpresaId, empresaId);
    await prefs.setString(_kPrefTareaId, tareaId);
    await prefs.setString(_kPrefUsuarioId, usuarioId);
    await prefs.setString(_kPrefInicio, _inicioActivo!.toIso8601String());

    // Guardar a Firestore cada 30 segundos para resiliencia
    _persistTimer?.cancel();
    _persistTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_inicioActivo == null) return;
      final seg = DateTime.now().difference(_inicioActivo!).inSeconds;
      await _actualizarRegistroEnProgreso(empresaId, tareaId, usuarioId, seg);
    });
  }

  // ── PAUSAR ───────────────────────────────────────────────────────────────

  /// Pausa el cronómetro y guarda el tiempo transcurrido.
  Future<RegistroTiempo?> pausar({
    required String empresaId,
    required String tareaId,
    required String usuarioId,
  }) async {
    _persistTimer?.cancel();
    _persistTimer = null;

    final inicio = _inicioActivo ?? await _recuperarInicio();
    _limpiarEstadoActivo();

    if (inicio == null) return null;

    final ahora = DateTime.now();
    final segundos = ahora.difference(inicio).inSeconds;
    if (segundos < 5) return null; // Ignorar menos de 5 segundos

    return _guardarRegistro(
      empresaId: empresaId,
      tareaId: tareaId,
      usuarioId: usuarioId,
      inicio: inicio,
      fin: ahora,
      segundos: segundos,
      esManual: false,
    );
  }

  // ── AÑADIR MANUAL ────────────────────────────────────────────────────────

  /// Añade un registro de tiempo manual.
  Future<RegistroTiempo> annadirManual({
    required String empresaId,
    required String tareaId,
    required String usuarioId,
    required int segundos,
    required DateTime fecha,
    String? nota,
  }) =>
      _guardarRegistro(
        empresaId: empresaId,
        tareaId: tareaId,
        usuarioId: usuarioId,
        inicio: fecha,
        fin: fecha.add(Duration(seconds: segundos)),
        segundos: segundos,
        esManual: true,
        nota: nota,
      );

  // ── STREAMS ──────────────────────────────────────────────────────────────

  Stream<List<RegistroTiempo>> registrosStream(
    String empresaId,
    String tareaId,
  ) =>
      _col(empresaId, tareaId)
          .orderBy('inicio', descending: true)
          .snapshots()
          .map((s) => s.docs.map(RegistroTiempo.fromFirestore).toList());

  Future<int> calcularTotalSegundos(String empresaId, String tareaId) async {
    final snap = await _col(empresaId, tareaId).get();
    return snap.docs
        .map(RegistroTiempo.fromFirestore)
        .fold<int>(0, (sum, r) => sum + r.segundos);
  }

  // ── REPORTE ──────────────────────────────────────────────────────────────

  /// Devuelve registros de tiempo agrupados por empleado para un período.
  Future<Map<String, int>> reportePorEmpleado({
    required String empresaId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final tareasSnap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .get();

    final mapa = <String, int>{};
    for (final tarea in tareasSnap.docs) {
      final registros = await _col(empresaId, tarea.id)
          .where('inicio', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
          .where('inicio', isLessThanOrEqualTo: Timestamp.fromDate(hasta))
          .get();
      for (final r in registros.docs) {
        final reg = RegistroTiempo.fromFirestore(r);
        mapa[reg.usuarioId] = (mapa[reg.usuarioId] ?? 0) + reg.segundos;
      }
    }
    return mapa;
  }

  /// Ranking de tareas por tiempo invertido.
  Future<List<MapEntry<String, int>>> rankingTareasPorTiempo({
    required String empresaId,
  }) async {
    final tareasSnap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .get();

    final mapa = <String, int>{};
    for (final tarea in tareasSnap.docs) {
      final total = await calcularTotalSegundos(empresaId, tarea.id);
      if (total > 0) mapa[tarea.id] = total;
    }

    return mapa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  // ── RECUPERACIÓN AL INICIAR APP ──────────────────────────────────────────

  /// Llama esto al iniciar la app para recuperar un cronómetro en curso.
  Future<CronometroRecuperado?> recuperarCronometroActivo() async {
    final prefs = await SharedPreferences.getInstance();
    final empresaId = prefs.getString(_kPrefEmpresaId);
    final tareaId   = prefs.getString(_kPrefTareaId);
    final usuarioId = prefs.getString(_kPrefUsuarioId);
    final inicioStr = prefs.getString(_kPrefInicio);

    if (empresaId == null || tareaId == null || usuarioId == null || inicioStr == null) {
      return null;
    }

    final inicio = DateTime.tryParse(inicioStr);
    if (inicio == null) return null;

    _empresaIdActivo = empresaId;
    _tareaIdActivo   = tareaId;
    _usuarioIdActivo = usuarioId;
    _inicioActivo    = inicio;

    return CronometroRecuperado(
      empresaId: empresaId,
      tareaId: tareaId,
      usuarioId: usuarioId,
      inicio: inicio,
    );
  }

  bool get hayCronometroActivo => _inicioActivo != null;
  String? get tareaIdActiva => _tareaIdActivo;
  DateTime? get inicioActivo => _inicioActivo;

  // ── PRIVADOS ─────────────────────────────────────────────────────────────

  Future<RegistroTiempo> _guardarRegistro({
    required String empresaId,
    required String tareaId,
    required String usuarioId,
    required DateTime inicio,
    required DateTime? fin,
    required int segundos,
    required bool esManual,
    String? nota,
  }) async {
    final ref = _col(empresaId, tareaId).doc();
    final reg = RegistroTiempo(
      id: ref.id,
      tareaId: tareaId,
      usuarioId: usuarioId,
      inicio: inicio,
      fin: fin,
      segundos: segundos,
      esManual: esManual,
      nota: nota,
    );
    await ref.set(reg.toFirestore());
    return reg;
  }

  Future<void> _actualizarRegistroEnProgreso(
    String empresaId,
    String tareaId,
    String usuarioId,
    int segundos,
  ) async {
    // Guardar un doc temporal "en_progreso" que se reemplaza cada 30s
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('tareas')
        .doc(tareaId)
        .collection('registros_tiempo')
        .doc('_en_progreso')
        .set({
      'tarea_id': tareaId,
      'usuario_id': usuarioId,
      'inicio': Timestamp.fromDate(_inicioActivo!),
      'fin': null,
      'segundos': segundos,
      'es_manual': false,
      'en_progreso': true,
    });
  }

  Future<DateTime?> _recuperarInicio() async {
    final prefs = await SharedPreferences.getInstance();
    final inicioStr = prefs.getString(_kPrefInicio);
    return inicioStr != null ? DateTime.tryParse(inicioStr) : null;
  }

  void _limpiarEstadoActivo() {
    _empresaIdActivo = null;
    _tareaIdActivo   = null;
    _usuarioIdActivo = null;
    _inicioActivo    = null;
    SharedPreferences.getInstance().then((p) {
      p.remove(_kPrefEmpresaId);
      p.remove(_kPrefTareaId);
      p.remove(_kPrefUsuarioId);
      p.remove(_kPrefInicio);
    });
  }
}

class CronometroRecuperado {
  final String empresaId;
  final String tareaId;
  final String usuarioId;
  final DateTime inicio;
  CronometroRecuperado({
    required this.empresaId,
    required this.tareaId,
    required this.usuarioId,
    required this.inicio,
  });
  int get segundosTranscurridos => DateTime.now().difference(inicio).inSeconds;
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

