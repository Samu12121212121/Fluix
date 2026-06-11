import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../domain/modelos/cierre_caja.dart';

/// Servicio de cierre de caja diario
class CierreCajaService {
  static final CierreCajaService _i = CierreCajaService._();
  factory CierreCajaService() => _i;
  CierreCajaService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cierresRef(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('cierres_caja');

  CollectionReference<Map<String, dynamic>> _pedidosRef(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('pedidos');

  CollectionReference<Map<String, dynamic>> _aperturasRef(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('aperturas_caja');

  // ── CALCULAR CIERRE (P1: incluye fondo_inicial de la apertura del día) ────

  Future<CierreCaja> calcularCierreCaja(
      String empresaId, DateTime fecha, {double? efectivoReal}) async {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));

    // Buscar apertura del día para obtener fondo_inicial
    final aperturasSnap = await _aperturasRef(empresaId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .orderBy('fecha', descending: true)
        .limit(1)
        .get();

    final fondoInicial = aperturasSnap.docs.isNotEmpty
        ? (aperturasSnap.docs.first.data()['fondo_inicial'] as num?)
                ?.toDouble() ??
            0.0
        : 0.0;

    final snap = await _pedidosRef(empresaId)
        .where('fecha_creacion',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_creacion', isLessThan: Timestamp.fromDate(fin))
        .where('estado_pago', isEqualTo: 'pagado')
        .get();

    double totalEfectivo = 0;
    double totalTarjeta = 0;
    double totalTransferencia = 0;
    double totalVentas = 0;
    final int numTickets = snap.docs.length;
    final Map<String, Map<String, double>> desgloseIva = {};

    const validIva = {0, 4, 10, 21};

    for (final doc in snap.docs) {
      final data = doc.data();
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      final metodo = data['metodo_pago'] as String? ?? 'efectivo';

      totalVentas += total;

      switch (metodo) {
        case 'efectivo':
          totalEfectivo += total;
        case 'tarjeta':
        case 'bizum':
        case 'paypal':
          totalTarjeta += total;
        case 'mixto':
          final efectivoMixto =
              (data['importe_efectivo'] as num?)?.toDouble() ?? 0.0;
          final tarjetaMixto =
              (data['importe_tarjeta'] as num?)?.toDouble() ?? 0.0;
          if (efectivoMixto == 0 && tarjetaMixto == 0) {
            totalEfectivo += total / 2;
            totalTarjeta += total / 2;
          } else {
            totalEfectivo += efectivoMixto;
            totalTarjeta += tarjetaMixto;
          }
        default:
          totalTransferencia += total;
      }

      // Desglose IVA desde líneas del pedido
      final lineas = data['lineas'] as List<dynamic>? ?? [];
      for (final linea in lineas) {
        final l = linea as Map<String, dynamic>;
        final ivaPct = (l['porcentaje_iva'] ?? l['iva_porcentaje'] ?? 21.0) as num;
        final ivaSanitizado = validIva.contains(ivaPct.toInt()) ? ivaPct.toInt() : 21;
        final key = '$ivaSanitizado';
        final cantidad = (l['cantidad'] as num?)?.toDouble() ?? 1.0;
        final precioUnit = (l['precio_unitario'] ?? l['precio'] ?? 0.0) as num;
        final descuento = (l['descuento'] as num?)?.toDouble() ?? 0.0;
        final base = precioUnit.toDouble() * cantidad * (1 - descuento / 100);
        final cuota = base * ivaSanitizado / 100;
        desgloseIva[key] ??= {'base': 0.0, 'cuota': 0.0};
        desgloseIva[key]!['base'] = desgloseIva[key]!['base']! + base;
        desgloseIva[key]!['cuota'] = desgloseIva[key]!['cuota']! + cuota;
      }
    }

    // Efectivo teórico = fondo inicial + ventas en efectivo
    final efectivoTeorico = fondoInicial + totalEfectivo;
    final efectivoRealFinal = efectivoReal ?? efectivoTeorico;
    final diferencia = efectivoRealFinal - efectivoTeorico;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return CierreCaja(
      fecha: inicio,
      totalEfectivo: totalEfectivo,
      totalTarjeta: totalTarjeta,
      totalTransferencia: totalTransferencia,
      totalVentas: totalVentas,
      numTickets: numTickets,
      cerradoPor: uid,
      timestamp: DateTime.now(),
      fondoInicial: fondoInicial,
      efectivoTeorico: efectivoTeorico,
      efectivoReal: efectivoRealFinal,
      diferencia: diferencia,
      desgloseIva: desgloseIva,
    );
  }

  // ── GUARDAR CIERRE ─────────────────────────────────────────────────────────

  /// Guarda el cierre en /empresas/{id}/cierres_caja/{yyyy-MM-dd}.
  /// Lanza [StateError] si ya existe un cierre para ese día.
  Future<void> guardarCierreCaja(
      String empresaId, CierreCaja cierre) async {
    final docId = CierreCaja.claveDocumento(cierre.fecha);
    final ref = _cierresRef(empresaId).doc(docId);

    final existing = await ref.get();
    if (existing.exists) {
      throw StateError(
          'Ya existe un cierre de caja para el día $docId');
    }

    await ref.set(cierre.toMap());
  }

  // ── VERIFICAR CAJA ABIERTA HOY ────────────────────────────────────────────

  /// Devuelve true si existe una apertura de caja para el día indicado (o hoy).
  /// Usado para bloquear ventas cuando la caja no ha sido abierta.
  Future<bool> hayCajaAbiertaHoy(String empresaId, {DateTime? fecha}) async {
    final ref = fecha ?? DateTime.now();
    final inicio = DateTime(ref.year, ref.month, ref.day);
    final fin = inicio.add(const Duration(days: 1));
    try {
      final snap = await _aperturasRef(empresaId)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin))
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── VERIFICAR SI YA EXISTE CIERRE HOY ─────────────────────────────────────

  Future<bool> existeCierreCajaHoy(String empresaId) async {
    final docId = CierreCaja.claveDocumento(DateTime.now());
    final snap = await _cierresRef(empresaId).doc(docId).get();
    return snap.exists;
  }

  // ── STREAM CIERRES ANTERIORES ──────────────────────────────────────────────

  Stream<List<CierreCaja>> getCierresAnteriores(String empresaId) {
    return _cierresRef(empresaId)
        .orderBy('fecha', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CierreCaja.fromMap(d.data(), d.id))
            .toList());
  }

  // ── TURNOS ────────────────────────────────────────────────────────────────

  /// Devuelve el número de turno que corresponde abrir (turnos cerrados hoy + 1).
  Future<int> getTurnoActual(String empresaId) async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));
    final snap = await _aperturasRef(empresaId)
        .where('fecha',
            isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(inicio))
        .where('fecha',
            isLessThan: DateFormat('yyyy-MM-dd').format(fin))
        .get();
    return snap.docs.length + 1;
  }

  /// Abre un nuevo turno de caja aunque ya haya uno cerrado hoy.
  Future<void> abrirTurno(
    String empresaId, {
    double fondoInicial = 0,
    int turno = 1,
  }) async {
    await _aperturasRef(empresaId).add({
      'fecha': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'turno': turno,
      'fondo_inicial': fondoInicial,
      'abierto_at': FieldValue.serverTimestamp(),
      'cajero_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }

  // ── ARQUEO DE DENOMINACIONES ──────────────────────────────────────────────

  /// Guarda el arqueo de billetes y monedas del día.
  /// [denominaciones] ejemplo: {'500': 2, '200': 1, '50': 3, '0.50': 4}
  Future<void> guardarArqueo(
      String empresaId, Map<String, int> denominaciones) async {
    final total = denominaciones.entries.fold<double>(
      0,
      (s, e) => s + (double.tryParse(e.key) ?? 0) * e.value,
    );
    final docId =
        'arqueo_${DateFormat('yyyyMMdd').format(DateTime.now())}';
    await _aperturasRef(empresaId).doc(docId).set({
      'denominaciones': denominaciones,
      'total_contado': total,
      'fecha': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── STREAM CAJA ACTUAL ────────────────────────────────────────────────────

  /// Stream del documento de apertura más reciente del día actual.
  Stream<DocumentSnapshot?> streamCajaActual(String empresaId) {
    final hoy = DateTime.now();
    final fechaStr = DateFormat('yyyy-MM-dd').format(hoy);
    return _aperturasRef(empresaId)
        .where('fecha', isEqualTo: fechaStr)
        .orderBy('abierto_at', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty ? snap.docs.first : null);
  }
}


