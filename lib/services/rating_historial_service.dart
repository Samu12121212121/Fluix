import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio para gestión del historial de rating mensual.
/// Calcula el rating medio localmente sobre las reseñas en Firestore.
class RatingHistorialService {
  static final RatingHistorialService _i = RatingHistorialService._();
  factory RatingHistorialService() => _i;
  RatingHistorialService._();

  final _db = FirebaseFirestore.instance;

  // ── Guardar / actualizar snapshot del mes actual ──────────────────────────

  /// Calcula el rating medio de las reseñas almacenadas en Firestore
  /// y guarda/actualiza el snapshot del mes actual.
  /// Se llama cada vez que se sincronizan reseñas.
  Future<void> guardarOActualizarSnapshotMes(String empresaId) async {
    try {
      final ahora = DateTime.now();
      final mesKey =
          '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';

      // Leer todas las reseñas
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .get();

      final total = snap.docs.length;
      if (total == 0) return;

      final sumaRatings = snap.docs.fold<double>(
        0,
        (s, d) =>
            s +
            ((d.data()['calificacion'] ?? d.data()['estrellas'] ?? 5) as num)
                .toDouble(),
      );
      final ratingMedio = sumaRatings / total;

      // Contar reseñas nuevas en el mes actual
      final inicioMes = DateTime(ahora.year, ahora.month, 1);
      final resenasNuevasMes = snap.docs.where((d) {
        final fecha = _parseFecha(d.data()['fecha']);
        return fecha.isAfter(inicioMes);
      }).length;

      // Solo un snapshot por mes → sobrescribir
      await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('rating_historial')
          .doc(mesKey)
          .set({
        'mes': mesKey,
        'ratingMedio': double.parse(ratingMedio.toStringAsFixed(2)),
        'totalResenasEnFirestore': total,
        'resenasNuevasMes': resenasNuevasMes,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // No bloquear el flujo principal
      print('⚠️ Error guardando snapshot: $e');
    }
  }

  // ── Obtener historial ─────────────────────────────────────────────────────

  /// Obtiene el historial de snapshots ordenados por mes.
  /// Devuelve máximo 12 meses.
  Future<List<RatingSnapshot>> obtenerHistorial(String empresaId) async {
    try {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('rating_historial')
          .orderBy('mes', descending: false)
          .limitToLast(12)
          .get();

      return snap.docs
          .map((d) => RatingSnapshot.fromMap(d.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Calcular tendencia ────────────────────────────────────────────────────

  /// Compara el último mes con el promedio de los 3 anteriores.
  /// Devuelve positivo si mejora, negativo si empeora.
  double? calcularTendencia(List<RatingSnapshot> historial) {
    if (historial.length < 2) return null;

    final ultimo = historial.last.ratingMedio;
    final anteriores = historial.length >= 4
        ? historial.sublist(historial.length - 4, historial.length - 1)
        : historial.sublist(0, historial.length - 1);

    if (anteriores.isEmpty) return null;

    final promedioAnteriores =
        anteriores.fold<double>(0, (s, r) => s + r.ratingMedio) /
            anteriores.length;

    return double.parse(
        (ultimo - promedioAnteriores).toStringAsFixed(2));
  }

  // ── KPIs calculados en cliente ────────────────────────────────────────────

  /// Calcula los KPIs directamente desde Firestore local.
  Future<KPIsRating> calcularKPIs(String empresaId) async {
    try {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .get();

      final total = snap.docs.length;
      if (total == 0) {
        return const KPIsRating(
            ratingMedio: 0,
            totalResenas: 0,
            sinResponder: 0,
            cambioBrutoMensual: null);
      }

      final sumaRatings = snap.docs.fold<double>(
        0,
        (s, d) =>
            s +
            ((d.data()['calificacion'] ?? d.data()['estrellas'] ?? 5) as num)
                .toDouble(),
      );
      final ratingMedio = sumaRatings / total;

      final sinResponder = snap.docs
          .where((d) =>
              (d.data()['respuesta'] == null ||
                  (d.data()['respuesta'] as String?)?.isEmpty == true))
          .length;

      // Cambio vs mes anterior (desde historial)
      final historial = await obtenerHistorial(empresaId);
      double? cambioBruto;
      if (historial.length >= 2) {
        final ultimo = historial.last.ratingMedio;
        final anterior = historial[historial.length - 2].ratingMedio;
        cambioBruto =
            double.parse((ultimo - anterior).toStringAsFixed(2));
      }

      return KPIsRating(
        ratingMedio:
            double.parse(ratingMedio.toStringAsFixed(1)),
        totalResenas: total,
        sinResponder: sinResponder,
        cambioBrutoMensual: cambioBruto,
      );
    } catch (_) {
      return const KPIsRating(
          ratingMedio: 0,
          totalResenas: 0,
          sinResponder: 0,
          cambioBrutoMensual: null);
    }
  }

  // ── Distribución de estrellas ─────────────────────────────────────────────

  Future<Map<int, int>> calcularDistribucion(String empresaId) async {
    final resultado = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    try {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .get();

      for (final d in snap.docs) {
        final cal =
            ((d.data()['calificacion'] ?? d.data()['estrellas'] ?? 5) as num)
                .toInt()
                .clamp(1, 5);
        resultado[cal] = (resultado[cal] ?? 0) + 1;
      }
    } catch (_) {}
    return resultado;
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  DateTime _parseFecha(dynamic f) {
    if (f is Timestamp) return f.toDate();
    if (f is String) return DateTime.tryParse(f) ?? DateTime.now();
    return DateTime.now();
  }
}

// ── Modelos ───────────────────────────────────────────────────────────────────

class RatingSnapshot {
  final String mes; // "YYYY-MM"
  final double ratingMedio;
  final int totalResenasEnFirestore;
  final int resenasNuevasMes;
  final DateTime? timestamp;

  const RatingSnapshot({
    required this.mes,
    required this.ratingMedio,
    required this.totalResenasEnFirestore,
    required this.resenasNuevasMes,
    this.timestamp,
  });

  factory RatingSnapshot.fromMap(Map<String, dynamic> map) => RatingSnapshot(
        mes: map['mes'] as String? ?? '',
        ratingMedio:
            (map['ratingMedio'] as num?)?.toDouble() ?? 0.0,
        totalResenasEnFirestore:
            (map['totalResenasEnFirestore'] as num?)?.toInt() ?? 0,
        resenasNuevasMes:
            (map['resenasNuevasMes'] as num?)?.toInt() ?? 0,
        timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
      );

  /// Etiqueta del eje X del gráfico (e.g., "Ene", "Feb")
  String get etiquetaMes {
    final partes = mes.split('-');
    if (partes.length < 2) return mes;
    final meses = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final numMes = int.tryParse(partes[1]) ?? 1;
    return meses[numMes.clamp(1, 12)];
  }
}

class KPIsRating {
  final double ratingMedio;
  final int totalResenas;
  final int sinResponder;
  final double? cambioBrutoMensual;

  const KPIsRating({
    required this.ratingMedio,
    required this.totalResenas,
    required this.sinResponder,
    required this.cambioBrutoMensual,
  });
}

