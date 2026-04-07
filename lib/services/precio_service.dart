import 'package:cloud_firestore/cloud_firestore.dart';

// ── MODELO ────────────────────────────────────────────────────────────────────

enum MotivoCambioPrecio {
  subidaCostes,
  ipc,
  promocion,
  otro;

  String get etiqueta => switch (this) {
        subidaCostes => 'Subida de costes',
        ipc => 'IPC / Actualización anual',
        promocion => 'Promoción',
        otro => 'Otro',
      };
}

class EntradaHistorialPrecio {
  final String id;
  final double precioAnterior;
  final double precioNuevo;
  final DateTime fechaEfectividad; // cuándo entra en vigor
  final DateTime fechaRegistro;   // cuándo se registró
  final MotivoCambioPrecio motivo;
  final String? motivoLibre;
  final String usuarioId;

  const EntradaHistorialPrecio({
    required this.id,
    required this.precioAnterior,
    required this.precioNuevo,
    required this.fechaEfectividad,
    required this.fechaRegistro,
    required this.motivo,
    this.motivoLibre,
    required this.usuarioId,
  });

  double get variacion => precioNuevo - precioAnterior;
  double get variacionPct =>
      precioAnterior > 0 ? (variacion / precioAnterior) * 100 : 0;
  bool get esSubida => variacion > 0;

  factory EntradaHistorialPrecio.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EntradaHistorialPrecio(
      id: doc.id,
      precioAnterior: (d['precio_anterior'] as num).toDouble(),
      precioNuevo: (d['precio_nuevo'] as num).toDouble(),
      fechaEfectividad: _parseTs(d['fecha_efectividad']),
      fechaRegistro: _parseTs(d['fecha_registro']),
      motivo: MotivoCambioPrecio.values.firstWhere(
        (e) => e.name == d['motivo'],
        orElse: () => MotivoCambioPrecio.otro,
      ),
      motivoLibre: d['motivo_libre'] as String?,
      usuarioId: d['usuario_id'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'precio_anterior': precioAnterior,
        'precio_nuevo': precioNuevo,
        'fecha_efectividad': Timestamp.fromDate(fechaEfectividad),
        'fecha_registro': Timestamp.fromDate(fechaRegistro),
        'motivo': motivo.name,
        'motivo_libre': motivoLibre,
        'usuario_id': usuarioId,
      };
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

// ── SERVICIO ──────────────────────────────────────────────────────────────────

/// Gestiona el historial de precios del catálogo.
/// Subcolección: empresas/{empresaId}/catalogo/{productoId}/historial_precios
class PrecioService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _historial(
          String empresaId, String productoId) =>
      _db
          .collection('empresas')
          .doc(empresaId)
          .collection('catalogo')
          .doc(productoId)
          .collection('historial_precios');

  // ── REGISTRAR CAMBIO ──────────────────────────────────────────────────────

  /// Registra el cambio de precio y actualiza el documento del producto.
  Future<void> registrarCambio({
    required String empresaId,
    required String productoId,
    required double precioAnterior,
    required double precioNuevo,
    required MotivoCambioPrecio motivo,
    String? motivoLibre,
    required String usuarioId,
    DateTime? fechaEfectividad,
  }) async {
    if (precioAnterior == precioNuevo) return;

    final ahora = DateTime.now();
    final entrada = EntradaHistorialPrecio(
      id: '',
      precioAnterior: precioAnterior,
      precioNuevo: precioNuevo,
      fechaEfectividad: fechaEfectividad ?? ahora,
      fechaRegistro: ahora,
      motivo: motivo,
      motivoLibre: motivoLibre,
      usuarioId: usuarioId,
    );

    final batch = _db.batch();

    // Añadir entrada al historial
    final histRef = _historial(empresaId, productoId).doc();
    batch.set(histRef, entrada.toFirestore());

    // Actualizar precio en el documento del producto
    final productoRef = _db
        .collection('empresas')
        .doc(empresaId)
        .collection('catalogo')
        .doc(productoId);
    batch.update(productoRef, {
      'precio': precioNuevo,
      'fecha_actualizacion': Timestamp.fromDate(ahora),
      'fecha_ultimo_cambio_precio': Timestamp.fromDate(ahora),
    });

    await batch.commit();
  }

  // ── LISTAR HISTORIAL ──────────────────────────────────────────────────────

  Stream<List<EntradaHistorialPrecio>> historialStream(
      String empresaId, String productoId) =>
      _historial(empresaId, productoId)
          .orderBy('fecha_efectividad', descending: true)
          .snapshots()
          .map((s) =>
              s.docs.map(EntradaHistorialPrecio.fromFirestore).toList());

  // ── PRECIO EN FECHA ───────────────────────────────────────────────────────

  /// Devuelve el precio que estaba vigente en una fecha concreta.
  /// Si no hay historial anterior a esa fecha, devuelve el precio actual.
  Future<double> obtenerPrecioEnFecha(
    String empresaId,
    String productoId,
    DateTime fecha,
  ) async {
    final snap = await _historial(empresaId, productoId)
        .where('fecha_efectividad',
            isLessThanOrEqualTo: Timestamp.fromDate(fecha))
        .orderBy('fecha_efectividad', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      // Devolver precio actual del producto
      final doc = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('catalogo')
          .doc(productoId)
          .get();
      return (doc.data()?['precio'] as num?)?.toDouble() ?? 0;
    }

    final entrada = EntradaHistorialPrecio.fromFirestore(snap.docs.first);
    return entrada.precioNuevo;
  }

  // ── PRODUCTOS SIN ACTUALIZAR ──────────────────────────────────────────────

  /// Devuelve nombres de productos cuyo precio no ha cambiado en >12 meses.
  Future<List<String>> productosConPrecioAntiguoMas12Meses(
      String empresaId) async {
    final limite = DateTime.now().subtract(const Duration(days: 365));
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('catalogo')
        .where('activo', isEqualTo: true)
        .get();

    final resultado = <String>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final fechaUltimo = d['fecha_ultimo_cambio_precio'];
      final fechaCreacion = d['fecha_creacion'];
      DateTime? ultimaFecha;
      if (fechaUltimo != null) {
        ultimaFecha = _parseTs(fechaUltimo);
      } else if (fechaCreacion != null) {
        ultimaFecha = _parseTs(fechaCreacion);
      }
      if (ultimaFecha != null && ultimaFecha.isBefore(limite)) {
        resultado.add(d['nombre'] as String? ?? 'Producto sin nombre');
      }
    }
    return resultado;
  }
}

