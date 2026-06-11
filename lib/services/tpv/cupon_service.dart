import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/modelos/cupon.dart';

class CuponService {
  static final CuponService _i = CuponService._();
  factory CuponService() => _i;
  CuponService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cuponesRef(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('cupones');

  // ── BUSCAR POR CÓDIGO (case-insensitive) ──────────────────────────────────

  Future<Cupon?> buscarPorCodigo(String empresaId, String codigo) async {
    final codigoNorm = codigo.trim().toUpperCase();
    final snap = await _cuponesRef(empresaId)
        .where('codigo', isEqualTo: codigoNorm)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Cupon.fromFirestore(snap.docs.first);
  }

  // ── VALIDAR Y APLICAR ─────────────────────────────────────────────────────

  /// Busca el cupón, valida que sea aplicable al [total] dado,
  /// incrementa [usos_actuales] en Firestore y devuelve el [Cupon].
  /// Devuelve null si el código no existe o no es válido para ese total.
  Future<Cupon?> aplicarCupon(
      String empresaId, String codigo, double total) async {
    final cupon = await buscarPorCodigo(empresaId, codigo);
    if (cupon == null) return null;
    if (cupon.calcularDescuento(total) <= 0) return null;

    await _cuponesRef(empresaId).doc(cupon.id).update({
      'usos_actuales': FieldValue.increment(1),
    });

    return cupon;
  }

  // ── CRUD ADMIN ────────────────────────────────────────────────────────────

  Future<void> guardar(String empresaId, Cupon cupon) async {
    final data = cupon.toFirestore();
    // Normaliza el código en Firestore para búsquedas case-insensitive
    data['codigo'] = cupon.codigo.trim().toUpperCase();
    if (cupon.id.isEmpty) {
      await _cuponesRef(empresaId).add(data);
    } else {
      await _cuponesRef(empresaId).doc(cupon.id).set(data);
    }
  }

  Future<void> eliminar(String empresaId, String cuponId) async {
    await _cuponesRef(empresaId).doc(cuponId).delete();
  }

  Stream<List<Cupon>> streamCupones(String empresaId) {
    return _cuponesRef(empresaId)
        .orderBy('codigo')
        .snapshots()
        .map((snap) => snap.docs.map(Cupon.fromFirestore).toList());
  }
}
