import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el contexto de empresa activa para usuarios multi-sede.
///
/// Modelo de datos en `usuarios/{uid}`:
///   empresa_id:    String  — empresa principal (siempre presente, backward-compat)
///   empresa_ids:   List    — todas las empresas gestionadas (opcional, solo multi-sede)
///
/// La sede activa se persiste en SharedPreferences para sobrevivir reinicios.
/// Si el usuario solo tiene una empresa, este servicio es transparente.
class MultisedeService {
  static const _kPrefsKey = 'empresa_activa_id';

  static final MultisedeService _i = MultisedeService._();
  factory MultisedeService() => _i;
  MultisedeService._();

  // ── Leer el ID de empresa activo ──────────────────────────────────────────

  /// Devuelve el ID de empresa que debe usarse en esta sesión.
  ///
  /// Prioridad: SharedPreferences → empresa_id del usuario.
  /// Solo devuelve un ID de SharedPreferences si sigue siendo válido
  /// (pertenece a la lista de empresas del usuario).
  Future<String?> obtenerEmpresaActiva() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_kPrefsKey);

    final userData = await _leerUsuario(uid);
    if (userData == null) return null;

    final principal = userData['empresa_id'] as String?;
    final todos = _extraerIds(userData, principal);

    // Si hay un ID guardado en prefs y sigue siendo válido, usarlo
    if (guardado != null && todos.contains(guardado)) {
      return guardado;
    }

    // Si solo tiene una empresa, guardarlo y devolverlo
    if (todos.length <= 1) {
      if (principal != null) await guardarEmpresaActiva(principal);
      return principal;
    }

    // Multi-sede sin selección previa → null (el router mostrará el selector)
    return null;
  }

  /// Devuelve la lista de todas las empresas del usuario, en orden.
  Future<List<SedeInfo>> obtenerSedes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final userData = await _leerUsuario(uid);
    if (userData == null) return [];

    final principal = userData['empresa_id'] as String?;
    final ids = _extraerIds(userData, principal);

    if (ids.isEmpty) return [];

    // Cargar nombres de empresa en paralelo
    final futures = ids.map((id) => FirebaseFirestore.instance
        .collection('empresas')
        .doc(id)
        .get());
    final snaps = await Future.wait(futures);

    return List.generate(ids.length, (i) {
      final snap = snaps[i];
      final d = snap.data() ?? {};
      final nombre = (d['perfil'] as Map?)?['nombre'] as String? ??
          d['nombre'] as String? ??
          'Sede ${i + 1}';
      final logoUrl = (d['perfil'] as Map?)?['logo_url'] as String?;
      return SedeInfo(
        empresaId: ids[i],
        nombre: nombre,
        logoUrl: logoUrl,
        esPrincipal: ids[i] == principal,
      );
    });
  }

  // ── Guardar empresa activa ────────────────────────────────────────────────

  Future<void> guardarEmpresaActiva(String empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, empresaId);
  }

  Future<void> limpiarEmpresaActiva() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
  }

  // ── Añadir/quitar sedes (solo plataforma admin) ───────────────────────────

  Future<void> vincularEmpresa({
    required String uid,
    required String empresaId,
  }) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'empresa_ids': FieldValue.arrayUnion([empresaId]),
    });
  }

  Future<void> desvincularEmpresa({
    required String uid,
    required String empresaId,
  }) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'empresa_ids': FieldValue.arrayRemove([empresaId]),
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _leerUsuario(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  List<String> _extraerIds(Map<String, dynamic> data, String? principal) {
    final extra = List<String>.from(data['empresa_ids'] as List? ?? []);
    final todos = <String>{
      if (principal != null && principal.isNotEmpty) principal,
      ...extra,
    }.toList();
    return todos;
  }
}

class SedeInfo {
  final String empresaId;
  final String nombre;
  final String? logoUrl;
  final bool esPrincipal;

  const SedeInfo({
    required this.empresaId,
    required this.nombre,
    this.logoUrl,
    required this.esPrincipal,
  });
}
