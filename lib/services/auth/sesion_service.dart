import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Política de sesión y cierre automático por inactividad
//
// Responsabilidades:
//   1. Cerrar sesión automáticamente tras 30 min de inactividad.
//   2. Detectar cuánto tiempo estuvo la app en background y, si supera
//      30 min, forzar logout al volver a primer plano (resumed).
//   3. Forzar refresh del token al volver de background para que el
//      OverlayState / Navigator ya tenga un contexto actualizado.
//
// Uso:
//   – Llamar a SesionService().iniciar() tras login exitoso.
//   – Llamar a SesionService().registrarActividad() en cada gesto del usuario
//     (normalmente desde un GestureDetector en la raíz de la app).
//   – Llamar a SesionService().manejarResumen() desde
//     didChangeAppLifecycleState(AppLifecycleState.resumed).
//   – Llamar a SesionService().registrarPausa() desde
//     didChangeAppLifecycleState(AppLifecycleState.paused).
//   – Llamar a SesionService().detener() al hacer logout.
// ─────────────────────────────────────────────────────────────────────────────

class SesionService {
  // Singleton
  static final SesionService _i = SesionService._();
  factory SesionService() => _i;
  SesionService._();

  // ── Configuración ─────────────────────────────────────────────────────────
  static const Duration _tiempoInactividad = Duration(minutes: 30);

  // ── Estado interno ────────────────────────────────────────────────────────
  Timer? _timerInactividad;
  DateTime? _momentoPausa;

  /// Callback para redirigir al login cuando la sesión expira.
  /// Debe asignarse al iniciar el servicio y apuntar a un método que
  /// use el NavigatorState raíz (sin BuildContext almacenado en caché).
  void Function()? onSesionExpirada;

  bool _activo = false;

  // ── CICLO DE VIDA DEL SERVICIO ────────────────────────────────────────────

  /// Inicia el servicio. Llamar tras login exitoso.
  void iniciar({required void Function() onSesionExpirada}) {
    this.onSesionExpirada = onSesionExpirada;
    _activo = true;
    _reiniciarTimer();
    debugPrint('✅ SesionService iniciado (timeout: ${_tiempoInactividad.inMinutes} min)');
  }

  /// Detiene todos los timers. Llamar al hacer logout.
  void detener() {
    _timerInactividad?.cancel();
    _timerInactividad = null;
    _momentoPausa = null;
    _activo = false;
    onSesionExpirada = null;
    debugPrint('🛑 SesionService detenido');
  }

  // ── ACTIVIDAD DEL USUARIO ─────────────────────────────────────────────────

  /// Registra una interacción del usuario y reinicia el contador de inactividad.
  /// Debe llamarse desde el GestureDetector raíz de la app.
  void registrarActividad() {
    if (!_activo) return;
    _reiniciarTimer();
  }

  // ── LIFECYCLE DE LA APP ───────────────────────────────────────────────────

  /// Registra el momento en que la app pasa a background.
  void registrarPausa() {
    _momentoPausa = DateTime.now();
    // Pausar el timer mientras la app está en segundo plano para evitar
    // que expire sin que el usuario haya tenido la posibilidad de actuar.
    _timerInactividad?.cancel();
    debugPrint('⏸️ SesionService: app en background (${_momentoPausa!.toIso8601String()})');
  }

  /// Maneja el retorno de la app a primer plano.
  ///
  /// Flujo:
  ///   1. Si la app estuvo más de 30 min en background → logout inmediato.
  ///   2. Si hay usuario activo → forzar refresh de token para que Firebase
  ///      SDK y Firestore tengan credenciales frescas antes de cualquier UI.
  ///   3. Reiniciar el timer de inactividad.
  Future<void> manejarResumen() async {
    debugPrint('▶️ SesionService: app vuelve a primer plano');

    // ── 1. Verificar tiempo en background ────────────────────────────────
    if (_momentoPausa != null) {
      final tiempoEnBackground = DateTime.now().difference(_momentoPausa!);
      _momentoPausa = null;

      if (tiempoEnBackground >= _tiempoInactividad) {
        debugPrint(
          '⏰ SesionService: más de ${_tiempoInactividad.inMinutes} min en background '
          '(${tiempoEnBackground.inMinutes} min) → cerrando sesión',
        );
        await _cerrarSesion();
        return;
      }
    }

    // ── 2. Forzar refresh del token ───────────────────────────────────────
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Sin usuario → notificar (el StreamBuilder debería haberlo manejado ya)
      onSesionExpirada?.call();
      return;
    }

    try {
      await user.getIdToken(true); // force = true → ignora caché
      debugPrint('🔑 SesionService: token refrescado al volver de background');
    } catch (e) {
      debugPrint('❌ SesionService: error al refrescar token: $e');
      // Si falla el refresh, la sesión es inválida
      await _cerrarSesion();
      return;
    }

    // ── 3. Reiniciar timer de inactividad ─────────────────────────────────
    if (_activo) _reiniciarTimer();
  }

  // ── PRIVADOS ──────────────────────────────────────────────────────────────

  void _reiniciarTimer() {
    _timerInactividad?.cancel();
    _timerInactividad = Timer(_tiempoInactividad, () async {
      debugPrint('⏰ SesionService: timer de inactividad expirado → cerrando sesión');
      await _cerrarSesion();
    });
  }

  Future<void> _cerrarSesion() async {
    detener();
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('🔓 SesionService: sesión cerrada');
    } catch (e) {
      debugPrint('⚠️ SesionService: error al cerrar sesión: $e');
    }
    // El StreamBuilder de authStateChanges en main.dart detectará
    // user == null y redirigirá automáticamente a PantallaLogin.
    // Pero también llamamos el callback por si hay lógica adicional.
    onSesionExpirada?.call();
  }
}

