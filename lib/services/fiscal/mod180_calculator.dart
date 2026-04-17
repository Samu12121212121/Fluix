import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD.180 CALCULATOR — Resumen anual retenciones arrendamientos (por arrendador)
// Par anual del Modelo 115 trimestral.
// Art. 180 RIRPF — presentación en enero del año siguiente.
// ═══════════════════════════════════════════════════════════════════════════════

class Mod180Calculator {
  static final Mod180Calculator _i = Mod180Calculator._();
  factory Mod180Calculator() => _i;
  Mod180Calculator._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _modelos180(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('modelos180');

  CollectionReference<Map<String, dynamic>> _facturasRecibidas(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('facturas_recibidas');

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Modelo180Result> calcular({
    required String empresaId,
    required int ejercicio,
  }) async {
    // Rango del ejercicio completo
    final inicio = DateTime(ejercicio, 1, 1);
    final fin = DateTime(ejercicio + 1, 1, 1);

    final snap = await _facturasRecibidas(empresaId)
        .where('es_arrendamiento', isEqualTo: true)
        .where('fecha_recepcion',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_recepcion', isLessThan: Timestamp.fromDate(fin))
        .get();

    // Agrupar por arrendador (NIF único)
    final porArrendador = <String, _DatosArrendador>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final estado = data['estado'] as String? ?? '';
      if (estado == 'rechazada') continue;

      final nif = ((data['nif_arrendador'] ?? data['nif_proveedor']) as String? ?? '')
          .trim()
          .toUpperCase();
      if (nif.isEmpty) continue;

      final base = (data['base_imponible'] as num?)?.toDouble() ?? 0.0;
      final retencion = _calcularRetencion(base);

      // Desglose trimestral
      final fechaRecepcion = (data['fecha_recepcion'] as Timestamp).toDate();
      final q = ((fechaRecepcion.month - 1) ~/ 3) + 1;

      final ar = porArrendador.putIfAbsent(
        nif,
        () => _DatosArrendador(
          nif: nif,
          nombre: (data['nombre_proveedor'] as String?) ?? '',
          direccion: (data['concepto_arrendamiento'] as String?) ?? '',
        ),
      );
      ar.base += base;
      ar.retencion += retencion;
      ar.numFacturas += 1;
      ar.trimestres[q - 1] += retencion;
    }

    // Construir lista de arrendadores
    final arrendadores = porArrendador.values.map((a) {
      return Arrendador180(
        nif: a.nif,
        nombre: a.nombre,
        direccionInmueble: a.direccion,
        baseAnual: _r2(a.base),
        retencionAnual: _r2(a.retencion),
        numFacturas: a.numFacturas,
        retencionQ1: _r2(a.trimestres[0]),
        retencionQ2: _r2(a.trimestres[1]),
        retencionQ3: _r2(a.trimestres[2]),
        retencionQ4: _r2(a.trimestres[3]),
      );
    }).toList();

    final c01 = arrendadores.length;
    final c02 = _r2(arrendadores.fold(0.0, (s, a) => s + a.baseAnual));
    final c03 = _r2(arrendadores.fold(0.0, (s, a) => s + a.retencionAnual));

    return Modelo180Result(
      ejercicio: ejercicio,
      empresaId: empresaId,
      c01: c01,
      c02: c02,
      c03: c03,
      arrendadores: arrendadores,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCIA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> guardar(Modelo180Result result) async {
    final docId = '${result.ejercicio}';
    await _modelos180(result.empresaId).doc(docId).set(
      result.toFirestore(),
      SetOptions(merge: true),
    );
  }

  Future<Modelo180Result?> cargar(String empresaId, int ejercicio) async {
    final doc = await _modelos180(empresaId).doc('$ejercicio').get();
    if (!doc.exists) return null;
    return Modelo180Result.fromFirestore(doc.data()!, empresaId);
  }

  Stream<List<Map<String, dynamic>>> obtenerHistorico(String empresaId) {
    return _modelos180(empresaId)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(5)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  static double _r2(double v) => (v * 100).roundToDouble() / 100;

  /// Retención arrendamiento: 19% (truncado a 2 decimales, no redondeo)
  static double _calcularRetencion(double base) => (base * 19).floorToDouble() / 100;
}

// ─── Modelos de datos ─────────────────────────────────────────────────────────

class Arrendador180 {
  final String nif;
  final String nombre;
  final String direccionInmueble;
  final double baseAnual;
  final double retencionAnual;
  final int numFacturas;
  final double retencionQ1;
  final double retencionQ2;
  final double retencionQ3;
  final double retencionQ4;

  const Arrendador180({
    required this.nif,
    required this.nombre,
    required this.direccionInmueble,
    required this.baseAnual,
    required this.retencionAnual,
    required this.numFacturas,
    required this.retencionQ1,
    required this.retencionQ2,
    required this.retencionQ3,
    required this.retencionQ4,
  });
}

class Modelo180Result {
  final int ejercicio;
  final String empresaId;
  final int c01;        // nº arrendadores
  final double c02;     // base total
  final double c03;     // retenciones totales
  final List<Arrendador180> arrendadores;

  const Modelo180Result({
    required this.ejercicio,
    required this.empresaId,
    required this.c01,
    required this.c02,
    required this.c03,
    required this.arrendadores,
  });

  Map<String, dynamic> toFirestore() => {
    'ejercicio': ejercicio,
    'modelo': '180',
    'c01': c01,
    'c02': c02,
    'c03': c03,
    'arrendadores': arrendadores
        .map((a) => {
              'nif': a.nif,
              'nombre': a.nombre,
              'direccion_inmueble': a.direccionInmueble,
              'base_anual': a.baseAnual,
              'retencion_anual': a.retencionAnual,
              'num_facturas': a.numFacturas,
              'retencion_q1': a.retencionQ1,
              'retencion_q2': a.retencionQ2,
              'retencion_q3': a.retencionQ3,
              'retencion_q4': a.retencionQ4,
            })
        .toList(),
    'fecha_calculo': FieldValue.serverTimestamp(),
    'estado': 'calculado',
  };

  factory Modelo180Result.fromFirestore(
      Map<String, dynamic> data, String empresaId) {
    final arrs = (data['arrendadores'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((a) => Arrendador180(
              nif: a['nif'] as String? ?? '',
              nombre: a['nombre'] as String? ?? '',
              direccionInmueble: a['direccion_inmueble'] as String? ?? '',
              baseAnual: (a['base_anual'] as num?)?.toDouble() ?? 0,
              retencionAnual: (a['retencion_anual'] as num?)?.toDouble() ?? 0,
              numFacturas: (a['num_facturas'] as int?) ?? 0,
              retencionQ1: (a['retencion_q1'] as num?)?.toDouble() ?? 0,
              retencionQ2: (a['retencion_q2'] as num?)?.toDouble() ?? 0,
              retencionQ3: (a['retencion_q3'] as num?)?.toDouble() ?? 0,
              retencionQ4: (a['retencion_q4'] as num?)?.toDouble() ?? 0,
            ))
        .toList();

    return Modelo180Result(
      ejercicio: (data['ejercicio'] as int?) ?? 0,
      empresaId: empresaId,
      c01: (data['c01'] as int?) ?? 0,
      c02: (data['c02'] as num?)?.toDouble() ?? 0,
      c03: (data['c03'] as num?)?.toDouble() ?? 0,
      arrendadores: arrs,
    );
  }
}

class _DatosArrendador {
  final String nif;
  final String nombre;
  final String direccion;
  double base = 0;
  double retencion = 0;
  int numFacturas = 0;
  final List<double> trimestres = [0, 0, 0, 0];

  _DatosArrendador({
    required this.nif,
    required this.nombre,
    required this.direccion,
  });
}

