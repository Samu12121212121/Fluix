import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/modelo115.dart';
import '../../domain/modelos/factura_recibida.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD.115 CALCULATOR — Retenciones IRPF arrendamientos locales de negocio
// Art. 101.6 LIRPF — 19% sobre base de arrendamiento
// Trimestral puro (NO acumulativo)
// ═══════════════════════════════════════════════════════════════════════════════

class Mod115Calculator {
  static final Mod115Calculator _i = Mod115Calculator._();
  factory Mod115Calculator() => _i;
  Mod115Calculator._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _modelos115(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('modelos115');

  CollectionReference<Map<String, dynamic>> _facturasRecibidas(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('facturas_recibidas');

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Modelo115> calcular({
    required String empresaId,
    required int ejercicio,
    required String trimestre,
    double c04Manual = 0,
    bool esComplementaria = false,
    String? nJustificanteAnterior,
    String? ibanDomiciliacion,
  }) async {
    final rango = Modelo115.rangoTrimestre(ejercicio, trimestre);

    // Obtener facturas recibidas con esArrendamiento=true del trimestre
    final facturas = await _obtenerFacturasArrendamiento(
      empresaId, rango.inicio, rango.fin,
    );

    // Agrupar por arrendador (NIF único)
    final porArrendador = <String, _DatosArrendador>{};
    for (final f in facturas) {
      final nif = (f.nifArrendador ?? f.nifProveedor).trim().toUpperCase();
      final datos = porArrendador.putIfAbsent(nif, () => _DatosArrendador(
        nif: nif,
        nombre: f.nombreProveedor,
      ));
      datos.base += f.baseImponible;
    }

    // [01] Nº perceptores distintos
    final c01 = porArrendador.length;

    // [02] Base de retenciones
    final c02 = _r2(porArrendador.values.fold(0.0, (s, a) => s + a.base));

    // [03] Retenciones practicadas = [02] × 0.19
    // Redondeo hacia abajo (truncar a 2 decimales)
    final c03 = (c02 * 19).floor() / 100;

    // Determinar tipo declaración
    final c05 = _r2(c03 - c04Manual);
    TipoDeclaracion115 tipo;
    if (c05 <= 0 && !esComplementaria) {
      tipo = TipoDeclaracion115.negativa;
    } else if (ibanDomiciliacion != null && ibanDomiciliacion.isNotEmpty) {
      tipo = TipoDeclaracion115.domiciliacion;
    } else {
      tipo = TipoDeclaracion115.ingreso;
    }

    // Construir detalle de arrendadores
    final arrendadores = porArrendador.values.map((a) {
      final ret = (a.base * 19).floor() / 100;
      return ArrendadorDetalle(
        nif: a.nif,
        nombre: a.nombre,
        baseImponible: _r2(a.base),
        retencion: ret,
      );
    }).toList();

    final docRef = _modelos115(empresaId).doc();

    return Modelo115(
      id: docRef.id,
      empresaId: empresaId,
      ejercicio: ejercicio,
      trimestre: trimestre,
      fechaGeneracion: DateTime.now(),
      c01: c01,
      c02: c02,
      c03: c03,
      c04: _r2(c04Manual),
      tipoDeclaracion: tipo,
      esComplementaria: esComplementaria,
      nJustificanteAnterior: nJustificanteAnterior,
      ibanDomiciliacion: ibanDomiciliacion,
      arrendadores: arrendadores,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSULTAS FIRESTORE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<FacturaRecibida>> _obtenerFacturasArrendamiento(
    String empresaId, DateTime inicio, DateTime fin,
  ) async {
    final snap = await _facturasRecibidas(empresaId)
        .where('es_arrendamiento', isEqualTo: true)
        .where('fecha_recepcion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_recepcion', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs
        .map((d) => FacturaRecibida.fromFirestore(d))
        .where((f) => f.estado != EstadoFacturaRecibida.rechazada)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCIA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> guardar(String empresaId, Modelo115 modelo) async {
    final existente = await _modelos115(empresaId)
        .where('ejercicio', isEqualTo: modelo.ejercicio)
        .where('trimestre', isEqualTo: modelo.trimestre)
        .limit(1)
        .get();

    if (existente.docs.isNotEmpty) {
      await existente.docs.first.reference.update(modelo.toFirestore());
    } else {
      await _modelos115(empresaId).doc(modelo.id).set(modelo.toFirestore());
    }
  }

  Future<void> marcarPresentado(String empresaId, String docId) async {
    await _modelos115(empresaId).doc(docId).update({'estado': 'presentado'});
  }

  Stream<List<Modelo115>> obtenerTodos(String empresaId, int ejercicio) {
    return _modelos115(empresaId)
        .where('ejercicio', isEqualTo: ejercicio)
        .orderBy('trimestre')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Modelo115.fromFirestore(d)).toList());
  }

  static double _r2(double v) => (v * 100).roundToDouble() / 100;
}

class _DatosArrendador {
  final String nif;
  final String nombre;
  double base = 0;

  _DatosArrendador({required this.nif, required this.nombre});
}

