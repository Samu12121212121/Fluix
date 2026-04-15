    visitasHoy: 0,
    visitasSemana: 0,
    visitasMes: 0,
    visitasTotal: 0,
    paginasMasVistas: {},
    duracionMediaSegundos: 0,
    tasaRebote: 0,
    visitasMovil: 0,
    visitasDesktop: 0,
    visitasTablet: 0,
    ubicaciones: {},
    referrers: {},
    eventos: {},
    paises: {},
    ultimaActualizacion: null,
    tieneDatos: false,
import 'package:cloud_firestore/cloud_firestore.dart';
/// Servicio para leer métricas de tráfico web guardadas por el script JS del footer.
///
/// El script JavaScript en fluixtech.com escribe en:
/// empresas/{empresaId}/estadisticas/trafico_web
///
/// Aquí solo leemos esos datos desde Firestore (sin llamadas directas a la web).
class AnalyticsWebService {
  static final AnalyticsWebService _i = AnalyticsWebService._();
  factory AnalyticsWebService() => _i;
  AnalyticsWebService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream en tiempo real de las métricas de tráfico web guardadas por el script JS.
  Stream<MetricasTraficoWeb> streamMetricas(String empresaId) {
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('estadisticas')
        .doc('trafico_web')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return MetricasTraficoWeb.vacio();
      }
      return MetricasTraficoWeb.fromMap(doc.data()!);
    });
  }

  /// Lee las métricas una sola vez (para el cache de estadísticas).
  Future<MetricasTraficoWeb> obtenerMetricas(String empresaId) async {
    try {
      final doc = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('trafico_web')
          .get();
      if (!doc.exists || doc.data() == null) return MetricasTraficoWeb.vacio();
      return MetricasTraficoWeb.fromMap(doc.data()!);
    } catch (_) {
      return MetricasTraficoWeb.vacio();
    }
  }

  /// Obtiene el historial diario de visitas para el gráfico (últimos 30 días).
  Future<List<Map<String, dynamic>>> obtenerHistorialDiario(String empresaId) async {
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

/// Modelo de métricas de tráfico web — datos guardados por el script JS del footer.
class MetricasTraficoWeb {
  // Visitantes
  final int visitasHoy;
  final int visitasSemana;
  final int visitasMes;
  final int visitasTotal;

  // Páginas
  final Map<String, int> paginasMasVistas; // ruta → número de visitas
  final double duracionMediaSegundos;      // segundos de media por visita
  final double tasaRebote;                 // 0..100 %

  // Dispositivos
  final int visitasMovil;
  final int visitasDesktop;
  final int visitasTablet;

  // Ubicaciones geográficas
  final Map<String, int> ubicaciones; // ciudad/país → visitas

  // 📊 NUEVO: Origen del tráfico (referrers)
  final Map<String, int> referrers;  // google, directo, facebook, instagram...

  // 🎯 NUEVO: Eventos clave (intención de compra)
  final Map<String, int> eventos;    // click_telefono, click_whatsapp, formulario_enviado...

  // 🌍 NUEVO: Países (agregación rápida)
  final Map<String, int> paises;     // Spain, Mexico...

  // Meta
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
    required this.visitasMovil,
    required this.visitasDesktop,
    required this.visitasTablet,
    required this.ubicaciones,
    required this.referrers,
    required this.eventos,
    required this.paises,
    required this.ultimaActualizacion,
    required this.tieneDatos,
  });

  factory MetricasTraficoWeb.vacio() => const MetricasTraficoWeb(
    visitasHoy: 0,
    visitasSemana: 0,
    visitasMes: 0,
    visitasTotal: 0,
    paginasMasVistas: {},
    duracionMediaSegundos: 0,
    tasaRebote: 0,
    visitasMovil: 0,
    visitasDesktop: 0,
    visitasTablet: 0,
    ubicaciones: {},
    referrers: {},
    eventos: {},
    paises: {},
    ultimaActualizacion: null,
    tieneDatos: false,
  );

  factory MetricasTraficoWeb.fromMap(Map<String, dynamic> m) {
    DateTime? ultimaAct;
    final raw = m['ultima_actualizacion'];
    if (raw is Timestamp) ultimaAct = raw.toDate();
    if (raw is String) ultimaAct = DateTime.tryParse(raw);

    Map<String, int> _toIntMap(dynamic val, {bool decodePaginas = false}) {
      if (val == null) return {};
      if (val is Map) {
        return val.map((k, v) {
          String key = k.toString();
          // El script guarda /ruta/pagina como _ruta_pagina (reemplaza / por _)
          // Lo revertimos para mostrarlo bien en la UI
          if (decodePaginas && !key.startsWith('/')) {
            key = '/' + key.replaceAll('_', '/');
          }
          return MapEntry(key, (v as num?)?.toInt() ?? 0);
        });
      }
      return {};
    }

    return MetricasTraficoWeb(
      visitasHoy: (m['visitas_hoy'] as num?)?.toInt() ?? 0,
      visitasSemana: (m['visitas_semana'] as num?)?.toInt() ?? 0,
      visitasMes: (m['visitas_mes'] as num?)?.toInt() ?? 0,
      visitasTotal: (m['visitas_total'] as num?)?.toInt() ?? 0,
      paginasMasVistas: _toIntMap(m['paginas_mas_vistas'], decodePaginas: true),
      duracionMediaSegundos: (m['duracion_media_segundos'] as num?)?.toDouble() ?? 0,
      tasaRebote: (m['tasa_rebote'] as num?)?.toDouble() ?? 0,
      visitasMovil: (m['visitas_movil'] as num?)?.toInt() ?? 0,
      visitasDesktop: (m['visitas_desktop'] as num?)?.toInt() ?? 0,
      visitasTablet: (m['visitas_tablet'] as num?)?.toInt() ?? 0,
      ubicaciones: _toIntMap(m['ubicaciones']),
      referrers: _toIntMap(m['referrers']),
      eventos: _toIntMap(m['eventos']),
      paises: _toIntMap(m['paises']),
      ultimaActualizacion: ultimaAct,
      tieneDatos: true,
    );
  }

  /// Porcentaje de visitas por dispositivo
  double get pctMovil {
    final total = visitasMovil + visitasDesktop + visitasTablet;
    return total == 0 ? 0 : visitasMovil / total * 100;
  }

  double get pctDesktop {
    final total = visitasMovil + visitasDesktop + visitasTablet;
    return total == 0 ? 0 : visitasDesktop / total * 100;
  }

  double get pctTablet {
    final total = visitasMovil + visitasDesktop + visitasTablet;
    return total == 0 ? 0 : visitasTablet / total * 100;
  }

  String get duracionFormateada {
    if (duracionMediaSegundos < 60) return '${duracionMediaSegundos.toInt()}s';
    final m = (duracionMediaSegundos / 60).floor();
    final s = (duracionMediaSegundos % 60).toInt();
    return '${m}m ${s}s';
  }

  /// Total de eventos registrados
  int get totalEventos => eventos['total'] ?? 0;

  /// Total de referrers (sesiones con origen identificado)
  int get totalReferrers => referrers.values.fold(0, (a, b) => a + b);
}



