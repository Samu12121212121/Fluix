import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // ── CALCULAR CIERRE ────────────────────────────────────────────────────────

  Future<CierreCaja> calcularCierreCaja(
      String empresaId, DateTime fecha) async {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));

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
    int numTickets = snap.docs.length;

    for (final doc in snap.docs) {
      final data = doc.data();
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      final metodo = data['metodo_pago'] as String? ?? 'efectivo';

      totalVentas += total;

      switch (metodo) {
        case 'efectivo':
          totalEfectivo += total;
          break;
        case 'tarjeta':
        case 'bizum':
        case 'paypal':
          totalTarjeta += total;
          break;
        case 'mixto':
          // En mixto repartir equitativamente
          totalEfectivo += total / 2;
          totalTarjeta += total / 2;
          break;
        default:
          totalTransferencia += total;
      }
    }

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
}


