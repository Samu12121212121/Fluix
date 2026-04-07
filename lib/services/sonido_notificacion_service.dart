import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── TIPOS DE NOTIFICACIÓN ─────────────────────────────────────────────────────

/// Tipos de evento para los que se puede configurar un sonido
enum TipoNotificacion {
  nuevaReserva,
  nuevaValoracion,
  nuevoPedido,
  tareaAsignada,
  suscripcionPorVencer,
  general,
}

extension TipoNotificacionExt on TipoNotificacion {
  String get id {
    switch (this) {
      case TipoNotificacion.nuevaReserva:         return 'nueva_reserva';
      case TipoNotificacion.nuevaValoracion:      return 'nueva_valoracion';
      case TipoNotificacion.nuevoPedido:          return 'nuevo_pedido';
      case TipoNotificacion.tareaAsignada:        return 'tarea_asignada';
      case TipoNotificacion.suscripcionPorVencer: return 'suscripcion_por_vencer';
      case TipoNotificacion.general:              return 'general';
    }
  }

  String get nombre {
    switch (this) {
      case TipoNotificacion.nuevaReserva:         return 'Nueva Reserva';
      case TipoNotificacion.nuevaValoracion:      return 'Nueva Valoración';
      case TipoNotificacion.nuevoPedido:          return 'Nuevo Pedido';
      case TipoNotificacion.tareaAsignada:        return 'Tarea Asignada';
      case TipoNotificacion.suscripcionPorVencer: return 'Suscripción por Vencer';
      case TipoNotificacion.general:              return 'General';
    }
  }

  static TipoNotificacion fromId(String id) {
    return TipoNotificacion.values.firstWhere(
      (t) => t.id == id,
      orElse: () => TipoNotificacion.general,
    );
  }
}

// ── SONIDOS DISPONIBLES ───────────────────────────────────────────────────────

enum SonidoNotif {
  predeterminado,
  urgente,
  suave,
  digital,
  clasico,
  sinSonido,
}

extension SonidoNotifExt on SonidoNotif {
  String get id {
    switch (this) {
      case SonidoNotif.predeterminado: return 'predeterminado';
      case SonidoNotif.urgente:        return 'urgente';
      case SonidoNotif.suave:          return 'suave';
      case SonidoNotif.digital:        return 'digital';
      case SonidoNotif.clasico:        return 'clasico';
      case SonidoNotif.sinSonido:      return 'sin_sonido';
    }
  }

  String get nombre {
    switch (this) {
      case SonidoNotif.predeterminado: return 'Predeterminado';
      case SonidoNotif.urgente:        return 'Urgente';
      case SonidoNotif.suave:          return 'Suave';
      case SonidoNotif.digital:        return 'Digital';
      case SonidoNotif.clasico:        return 'Clásico';
      case SonidoNotif.sinSonido:      return 'Sin sonido';
    }
  }

  String get nombreArchivo {
    switch (this) {
      case SonidoNotif.predeterminado: return 'sounds/notif_default.wav';
      case SonidoNotif.urgente:        return 'sounds/notif_urgente.wav';
      case SonidoNotif.suave:          return 'sounds/notif_suave.wav';
      case SonidoNotif.digital:        return 'sounds/notif_digital.wav';
      case SonidoNotif.clasico:        return 'sounds/notif_clasico.wav';
      case SonidoNotif.sinSonido:      return 'sounds/sin_sonido.wav';
    }
  }

  static SonidoNotif fromId(String id) {
    return SonidoNotif.values.firstWhere(
      (s) => s.id == id,
      orElse: () => SonidoNotif.predeterminado,
    );
  }
}

// ── SERVICIO ──────────────────────────────────────────────────────────────────

/// Servicio para gestionar los sonidos de notificación en primer plano.
/// Las preferencias se guardan en Firestore bajo usuarios/{uid}/configuracion/sonidos
class SonidoNotificacionService {
  static final SonidoNotificacionService _instance =
      SonidoNotificacionService._();
  factory SonidoNotificacionService() => _instance;
  SonidoNotificacionService._();

  final AudioPlayer _player = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Caché local de preferencias para evitar lecturas repetidas
  Map<String, String>? _preferenciasCache;

  // ── LECTURA / ESCRITURA ────────────────────────────────────────────────────

  /// Devuelve el sonido configurado para un tipo de notificación.
  /// Primero usa la caché; si no, lee de Firestore.
  Future<SonidoNotif> obtenerSonido(TipoNotificacion tipo) async {
    if (_preferenciasCache == null) {
      await _cargarPreferencias();
    }
    final id = _preferenciasCache?[tipo.id] ?? SonidoNotif.predeterminado.id;
    return SonidoNotifExt.fromId(id);
  }

  /// Guarda la preferencia de sonido para un tipo en Firestore y en caché.
  Future<void> guardarSonido(TipoNotificacion tipo, SonidoNotif sonido) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _preferenciasCache ??= {};
    _preferenciasCache![tipo.id] = sonido.id;

    try {
      await _firestore
          .collection('usuarios')
          .doc(uid)
          .collection('configuracion')
          .doc('sonidos')
          .set(
        {tipo.id: sonido.id},
        SetOptions(merge: true),
      );
    } catch (e) {
      print('❌ Error guardando preferencia de sonido: $e');
    }
  }

  /// Devuelve el mapa completo tipo → sonido (para la pantalla de ajustes)
  Future<Map<TipoNotificacion, SonidoNotif>> obtenerTodas() async {
    if (_preferenciasCache == null) {
      await _cargarPreferencias();
    }
    final result = <TipoNotificacion, SonidoNotif>{};
    for (final tipo in TipoNotificacion.values) {
      final id = _preferenciasCache?[tipo.id] ?? SonidoNotif.predeterminado.id;
      result[tipo] = SonidoNotifExt.fromId(id);
    }
    return result;
  }

  /// Invalida la caché (útil al hacer logout)
  void limpiarCache() => _preferenciasCache = null;

  // ── REPRODUCCIÓN ──────────────────────────────────────────────────────────

  /// Reproduce el sonido configurado para un tipo de notificación.
  /// Llamar desde [NotificacionesService] cuando llega una notificación en primer plano.
  Future<void> reproducirParaTipo(TipoNotificacion tipo) async {
    final sonido = await obtenerSonido(tipo);
    await reproducir(sonido);
  }

  /// Reproduce un sonido concreto. Útil para preescucha en ajustes.
  Future<void> reproducir(SonidoNotif sonido) async {
    if (sonido == SonidoNotif.sinSonido) return;
    try {
      await _player.stop();
      // Intentar reproducir desde assets
      await _player.play(AssetSource(sonido.nombreArchivo));
    } catch (e) {
      // Si el archivo no existe, intentar con sonido URI del sistema
      try {
        await _player.play(
          UrlSource('content://settings/system/notification_sound'),
        );
      } catch (_) {
        // Silenciar error si no se puede reproducir ningún sonido
        print('⚠️ No se pudo reproducir sonido ${sonido.id}: $e');
      }
    }
  }

  // ── PRIVADO ───────────────────────────────────────────────────────────────

  Future<void> _cargarPreferencias() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _preferenciasCache = {};
      return;
    }
    try {
      final doc = await _firestore
          .collection('usuarios')
          .doc(uid)
          .collection('configuracion')
          .doc('sonidos')
          .get();

      if (doc.exists) {
        _preferenciasCache = Map<String, String>.from(
          (doc.data() ?? {}).map((k, v) => MapEntry(k, v.toString())),
        );
      } else {
        _preferenciasCache = {};
      }
    } catch (e) {
      print('❌ Error cargando preferencias de sonido: $e');
      _preferenciasCache = {};
    }
  }
}



