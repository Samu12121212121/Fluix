import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsWebService {
  static final AnalyticsWebService _i = AnalyticsWebService._();
  factory AnalyticsWebService() => _i;
  AnalyticsWebService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Claves de período ────────────────────────────────────────────────────

  static String _hoy() {
    final d = DateTime.now();
    return '${d.year}-${_p(d.month)}-${_p(d.day)}';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  /// Claves de todos los días de la semana ISO actual (lunes → hoy)
  static List<String> _diasSemanaActual() {
    final now  = DateTime.now();
    final lunes = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(
      now.weekday,
          (i) {
        final d = lunes.add(Duration(days: i));
        return '${d.year}-${_p(d.month)}-${_p(d.day)}';
      },
    );
  }

  /// Claves de todos los días del mes actual (1 → hoy)
  static List<String> _diasMesActual() {
    final now = DateTime.now();
    return List.generate(
      now.day,
          (i) {
        final d = DateTime(now.year, now.month, i + 1);
        return '${d.year}-${_p(d.month)}-${_p(d.day)}';
      },
    );
  }

  // ── Stream principal ─────────────────────────────────────────────────────

  /// Combina el doc principal con historico_diario para calcular
  /// visitas_hoy, visitas_semana y visitas_mes de forma fiable,
  /// sin depender de los campos del doc principal que el script
  /// puede resetear incorrectamente en condiciones de carrera.
  Stream<MetricasTraficoWeb> streamMetricas(String empresaId) {
    final mainRef = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('estadisticas')
        .doc('trafico_web');

    final hoy    = _hoy();
    final semana = _diasSemanaActual();
    final mes    = _diasMesActual();

    Map<String, dynamic>?  _lastMain;
    Map<String, int>       _historial = {}; // fecha → visitas
    StreamSubscription?    _sub1, _sub2;
    late StreamController<MetricasTraficoWeb> _ctrl;

    void _emit() {
      if (_lastMain == null) return;

      // Calcular visitas_hoy / semana / mes desde el historial
      final visitasHoy    = _historial[hoy] ?? 0;
      final visitasSemana = semana.fold<int>(0, (s, d) => s + (_historial[d] ?? 0));
      final visitasMes    = mes.fold<int>(0,    (s, d) => s + (_historial[d] ?? 0));

      _ctrl.add(MetricasTraficoWeb.fromMap(
        _lastMain!,
        visitasHoyOverride:    visitasHoy,
        visitasSemanaOverride: visitasSemana,
        visitasMesOverride:    visitasMes,
      ));
    }

    _ctrl = StreamController<MetricasTraficoWeb>(
      onListen: () {
        // Sub 1: doc principal (total, dispositivos, fuentes, ubicaciones…)
        _sub1 = mainRef.snapshots().listen((doc) {
          if (!doc.exists || doc.data() == null) {
            _ctrl.add(MetricasTraficoWeb.vacio());
            return;
          }
          _lastMain = doc.data();
          _emit();
        });

        // Sub 2: historico_diario — últimos 35 días para cubrir semana + mes
        _sub2 = mainRef
            .collection('historico_diario')
            .orderBy('fecha', descending: true)
            .limit(35)
            .snapshots()
            .listen((snap) {
          _historial = {
            for (final d in snap.docs)
              if (d.data()['fecha'] != null)
                d.data()['fecha'] as String:
                (d.data()['visitas'] as num?)?.toInt() ?? 0,
          };
          _emit();
        });
      },
      onCancel: () {
        _sub1?.cancel();
        _sub2?.cancel();
      },
    );

    return _ctrl.stream;
  }

  // ── Consulta puntual ─────────────────────────────────────────────────────

  Future<MetricasTraficoWeb> obtenerMetricas(String empresaId) async {
    try {
      final mainRef = _db
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('trafico_web');

      final doc  = await mainRef.get();
      if (!doc.exists || doc.data() == null) return MetricasTraficoWeb.vacio();

      final hoy    = _hoy();
      final semana = _diasSemanaActual();
      final mes    = _diasMesActual();

      final histSnap = await mainRef
          .collection('historico_diario')
          .orderBy('fecha', descending: true)
          .limit(35)
          .get();

      final hist = <String, int>{
        for (final d in histSnap.docs)
          if (d.data()['fecha'] != null)
            d.data()['fecha'] as String:
            (d.data()['visitas'] as num?)?.toInt() ?? 0,
      };

      return MetricasTraficoWeb.fromMap(
        doc.data()!,
        visitasHoyOverride:    hist[hoy] ?? 0,
        visitasSemanaOverride: semana.fold<int>(0, (s, d) => s + (hist[d] ?? 0)),
        visitasMesOverride:    mes.fold<int>(0,    (s, d) => s + (hist[d] ?? 0)),
      );
    } catch (_) {
      return MetricasTraficoWeb.vacio();
    }
  }

  // ── Historial 30 días ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerHistorialDiario(
      String empresaId) async {
    try {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('trafico_web')
          .collection('historico_diario')
          .orderBy('fecha', descending: true)
          .limit(30)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MetricasTraficoWeb
// ═════════════════════════════════════════════════════════════════════════════

class MetricasTraficoWeb {
  final int visitasHoy;
  final int visitasSemana;
  final int visitasMes;
  final int visitasTotal;

  final Map<String, int> paginasMasVistas;
  final double duracionMediaSegundos;
  final double tasaRebote;

  final int duracionSumaTotal;
  final int duracionCountTotal;
  final int rebotesTotal;
  final int paginasVistasTotal;

  final int visitasMovil;
  final int visitasDesktop;
  final int visitasTablet;

  final Map<String, int> ubicaciones;
  final Map<String, int> ubicacionesCiudad;
  final Map<String, int> referrers;
  final Map<String, int> eventos;
  final Map<String, int> paises;

  final DateTime? ultimaActualizacion;
  final bool tieneDatos;

  const MetricasTraficoWeb({
    required this.visitasHoy,
    required this.visitasSemana,
    required this.visitasMes,
    required this.visitasTotal,
    required this.paginasMasVistas,
    required this.duracionMediaSegundos,
    required this.tasaRebote,
    required this.duracionSumaTotal,
    required this.duracionCountTotal,
    required this.rebotesTotal,
    required this.paginasVistasTotal,
    required this.visitasMovil,
    required this.visitasDesktop,
    required this.visitasTablet,
    required this.ubicaciones,
    required this.ubicacionesCiudad,
    required this.referrers,
    required this.eventos,
    required this.paises,
    required this.ultimaActualizacion,
    required this.tieneDatos,
  });

  factory MetricasTraficoWeb.vacio() => const MetricasTraficoWeb(
    visitasHoy: 0, visitasSemana: 0, visitasMes: 0, visitasTotal: 0,
    paginasMasVistas: {}, duracionMediaSegundos: 0, tasaRebote: 0,
    duracionSumaTotal: 0, duracionCountTotal: 0,
    rebotesTotal: 0, paginasVistasTotal: 0,
    visitasMovil: 0, visitasDesktop: 0, visitasTablet: 0,
    ubicaciones: {}, ubicacionesCiudad: {}, referrers: {},
    eventos: {}, paises: {},
    ultimaActualizacion: null, tieneDatos: false,
  );

  factory MetricasTraficoWeb.fromMap(
      Map<String, dynamic> m, {
        int? visitasHoyOverride,
        int? visitasSemanaOverride,
        int? visitasMesOverride,
      }) {
    // ── Fecha ──────────────────────────────────────────────────────────
    DateTime? ultimaAct;
    final rawF = m['ultima_actualizacion'];
    if (rawF is Timestamp) ultimaAct = rawF.toDate();
    if (rawF is String)    ultimaAct = DateTime.tryParse(rawF);

    // ── Helper ────────────────────────────────────────────────────────
    Map<String, int> toIntMap(dynamic val, {bool decodePaginas = false}) {
      if (val == null || val is! Map) return {};
      return Map.fromEntries(val.entries.map((e) {
        String k = e.key.toString();
        if (decodePaginas && !k.startsWith('/')) {
          k = '/' + k.replaceAll('_', '/');
        }
        return MapEntry(k, (e.value as num?)?.toInt() ?? 0);
      }));
    }

    // ── Duración media ────────────────────────────────────────────────
    final sumaRaw  = (m['duracion_suma_total']  as num?)?.toInt() ?? 0;
    final countRaw = (m['duracion_count_total'] as num?)?.toInt() ?? 0;
    final duracion = countRaw > 0
        ? sumaRaw / countRaw
        : (m['duracion_media_segundos'] as num?)?.toDouble() ?? 0;

    // ── Tasa de rebote ────────────────────────────────────────────────
    final rebotesRaw  = (m['rebotes_total']        as num?)?.toInt() ?? 0;
    final paginasRaw  = (m['paginas_vistas_total'] as num?)?.toInt() ?? 0;
    final rebote = paginasRaw > 0
        ? (rebotesRaw / paginasRaw * 100).clamp(0.0, 100.0)
        : (m['tasa_rebote'] as num?)?.toDouble() ?? 0;

    final ubicacionesMap      = toIntMap(m['ubicaciones']);
    final ubicacionesCiudadMap = toIntMap(m['ubicaciones_ciudad']);
    final visitasTotal = (m['visitas_total'] as num?)?.toInt() ?? 0;

    return MetricasTraficoWeb(
      // Siempre desde historico_diario cuando se pasan los overrides
      visitasHoy:    visitasHoyOverride    ?? (m['visitas_hoy']    as num?)?.toInt() ?? 0,
      visitasSemana: visitasSemanaOverride ?? (m['visitas_semana'] as num?)?.toInt() ?? 0,
      visitasMes:    visitasMesOverride    ?? (m['visitas_mes']    as num?)?.toInt() ?? 0,
      visitasTotal:  visitasTotal,
      paginasMasVistas:     toIntMap(m['paginas_mas_vistas'], decodePaginas: true),
      duracionMediaSegundos: duracion,
      tasaRebote:            rebote,
      duracionSumaTotal:     sumaRaw,
      duracionCountTotal:    countRaw,
      rebotesTotal:          rebotesRaw,
      paginasVistasTotal:    paginasRaw,
      visitasMovil:   (m['visitas_movil']   as num?)?.toInt() ?? 0,
      visitasDesktop: (m['visitas_desktop'] as num?)?.toInt() ?? 0,
      visitasTablet:  (m['visitas_tablet']  as num?)?.toInt() ?? 0,
      ubicaciones:       ubicacionesMap,
      ubicacionesCiudad: ubicacionesCiudadMap,
      referrers: toIntMap(m['referrers']),
      eventos:   toIntMap(m['eventos']),
      paises:    ubicacionesMap,
      ultimaActualizacion: ultimaAct,
      // tieneDatos solo si hay al menos 1 visita total registrada
      tieneDatos: visitasTotal > 0,
    );
  }

  // ── Getters calculados ────────────────────────────────────────────────────

  double get pctMovil {
    final t = visitasMovil + visitasDesktop + visitasTablet;
    return t == 0 ? 0 : visitasMovil / t * 100;
  }
  double get pctDesktop {
    final t = visitasMovil + visitasDesktop + visitasTablet;
    return t == 0 ? 0 : visitasDesktop / t * 100;
  }
  double get pctTablet {
    final t = visitasMovil + visitasDesktop + visitasTablet;
    return t == 0 ? 0 : visitasTablet / t * 100;
  }

  String get duracionFormateada {
    if (duracionMediaSegundos <= 0) return '—';
    if (duracionMediaSegundos < 60) return '${duracionMediaSegundos.toInt()}s';
    final mins = (duracionMediaSegundos / 60).floor();
    final segs = (duracionMediaSegundos % 60).toInt();
    return '${mins}m ${segs}s';
  }

  int get totalEventos   => eventos['total'] ?? 0;
  int get totalReferrers => referrers.values.fold(0, (a, b) => a + b);
}