import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Servicio de notificaciones B2C para clientes finales (módulo Explorar).
///
/// Responsabilidades:
/// - Stream de badge (notificaciones no leídas)
/// - Stream de lista de notificaciones
/// - Marcar una / todas como leídas
/// - Navegación desde tap en push (onMessageOpenedApp)
class ClienteNotificacionesService {
  static final _instance = ClienteNotificacionesService._();
  factory ClienteNotificacionesService() => _instance;
  ClienteNotificacionesService._();

  static const _colNotif = 'notificaciones';

  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Badge — número de notificaciones no leídas ────────────────────────────

  /// Emite el número de notificaciones no leídas en tiempo real.
  /// Devuelve `Stream.value(0)` si no hay sesión activa.
  Stream<int> get streamNoLeidas {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return _fs
        .collection('usuarios')
        .doc(uid)
        .collection(_colNotif)
        .where('leida', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── Lista de notificaciones ───────────────────────────────────────────────

  /// Stream de notificaciones ordenadas por fecha descendente.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamNotificaciones({int limit = 50}) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _fs
        .collection('usuarios')
        .doc(uid)
        .collection(_colNotif)
        .orderBy('creado_en', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  /// Marca una notificación como leída.
  Future<void> marcarLeida(String notifId) async {
    final uid = _uid;
    if (uid == null) return;
    await _fs
        .collection('usuarios')
        .doc(uid)
        .collection(_colNotif)
        .doc(notifId)
        .update({'leida': true});
  }

  /// Marca todas las notificaciones no leídas como leídas (batch).
  Future<void> marcarTodasLeidas() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _fs
        .collection('usuarios')
        .doc(uid)
        .collection(_colNotif)
        .where('leida', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _fs.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'leida': true});
    }
    await batch.commit();
  }

  // ── Deep-link desde tap en push ───────────────────────────────────────────

  /// Registra el handler para cuando el usuario toca una notificación push
  /// con la app en background / terminada.
  ///
  /// [onNavegar] recibe `(tipo, extra)` para que el widget NavigatorProvider
  /// pueda navegar a la pantalla correcta.
  void registrarTapHandler({
    required void Function(String tipo, Map<String, dynamic> extra) onNavegar,
  }) {
    if (kIsWeb) return;
    // App terminada → mensaje inicial
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) _procesarTap(msg.data, onNavegar);
    });
    // App en background → usuario toca notificación
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _procesarTap(msg.data, onNavegar);
    });
  }

  void _procesarTap(
    Map<String, dynamic> data,
    void Function(String tipo, Map<String, dynamic> extra) onNavegar,
  ) {
    final tipo = data['tipo'] as String? ?? 'info';
    onNavegar(tipo, data);
  }

  // ── Destinos de navegación por tipo ──────────────────────────────────────

  /// Devuelve la ruta (o descripción) sugerida para cada tipo de notificación.
  /// El llamante decide cómo navegar.
  static String rutaPorTipo(String tipo) {
    switch (tipo) {
      case 'reserva_confirmada':
      case 'reserva_cancelada':
      case 'reserva_pendiente':
        return '/mis-reservas';
      case 'promo':
        return '/explorar';
      case 'info':
        return '/notificaciones';
      default:
        return '/notificaciones';
    }
  }
}

