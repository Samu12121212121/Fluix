import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Renovación automática de token Firebase Auth
//
// Problema: Firebase Auth tokens expiran cada 60 minutos.
// Aunque Firebase SDK renueva el token automáticamente, en algunas condiciones
// de red el token puede quedar en un estado inválido causando errores
// permission-denied en Firestore.
//
// Solución:
//   1. Escuchar idTokenChanges() para detectar cambios de token
//   2. Forzar renovación proactiva cada 45 minutos (antes de que caduque)
//   3. Exponer manejarPermissionDenied() para reintentos controlados
//   4. Callback onSesionInvalida cuando la sesión es completamente inválida
// ─────────────────────────────────────────────────────────────────────────────

class TokenRefreshService {
  static final TokenRefreshService _i = TokenRefreshService._();
  factory TokenRefreshService() => _i;
  TokenRefreshService._();

  static const Duration _intervaloRefresh = Duration(minutes: 45);
  static const int _maxReintentos = 2;

  StreamSubscription<User?>? _tokenSubscription;
  Timer? _refreshTimer;

  /// Callback invocado cuando la sesión es completamente inválida.
  /// El caller debe redirigir al login con un mensaje explicativo.
  void Function(String mensaje)? onSesionInvalida;

  // ── CICLO DE VIDA ─────────────────────────────────────────────────────────

  /// Inicia el servicio. Debe llamarse tras login exitoso.
  void iniciar({void Function(String mensaje)? onSesionInvalida}) {
    this.onSesionInvalida = onSesionInvalida;

    // Cancelar cualquier suscripción previa
    detener();

    // Escuchar cambios de token (se emite cada vez que Firebase renueva el token)
    _tokenSubscription = FirebaseAuth.instance.idTokenChanges().listen(
      (user) {
        if (user != null) {
          debugPrint('🔑 Token ID actualizado — UID: ${user.uid}');
        }
      },
      onError: (dynamic e) {
        debugPrint('❌ Error en idTokenChanges: $e');
      },
    );

    // Renovar token proactivamente cada 45 minutos
    _refreshTimer = Timer.periodic(_intervaloRefresh, (_) {
      _renovarTokenSilenciosamente();
    });

    debugPrint('✅ TokenRefreshService iniciado');
  }

  /// Detiene el servicio. Debe llamarse al cerrar sesión.
  void detener() {
    _tokenSubscription?.cancel();
    _refreshTimer?.cancel();
    _tokenSubscription = null;
    _refreshTimer = null;
  }

  // ── RENOVACIÓN PROACTIVA ──────────────────────────────────────────────────

  /// Fuerza la renovación del token silenciosamente (sin interrumpir al usuario).
  Future<void> _renovarTokenSilenciosamente() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.getIdToken(true); // force: true = ignora caché
      debugPrint('🔑 Token renovado silenciosamente');
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Error renovando token: ${e.code}');
      _evaluarErrorSesion(e);
    } catch (e) {
      debugPrint('⚠️ Error inesperado renovando token: $e — forzando signOut');
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
  }

  // ── MANEJO DE PERMISSION-DENIED ───────────────────────────────────────────

  /// Llama a este método cuando Firestore devuelve [permission-denied].
  /// Intenta renovar el token y devuelve true si lo consiguió
  /// (el caller debe reintentar la operación).
  Future<bool> manejarPermissionDenied({int reintento = 0}) async {
    if (reintento >= _maxReintentos) {
      debugPrint('❌ Máximo de reintentos alcanzado tras permission-denied');
      return false;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        onSesionInvalida?.call(
          'Tu sesión ha expirado. Por favor, inicia sesión de nuevo.',
        );
        return false;
      }

      await user.getIdToken(true);
      debugPrint('🔑 Token renovado tras permission-denied (intento ${reintento + 1})');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ No se pudo renovar token tras permission-denied: ${e.code}');
      _evaluarErrorSesion(e);
      return false;
    } catch (e) {
      debugPrint('❌ Error inesperado al renovar token: $e');
      return false;
    }
  }

  // ── EVALUACIÓN DE ERRORES ─────────────────────────────────────────────────

  void _evaluarErrorSesion(FirebaseAuthException e) {
    const codigosInvalidez = {
      'user-token-expired',
      'user-not-found',
      'invalid-user-token',
      'user-disabled',
      'token-expired',
      'id-token-expired',
    };
    if (codigosInvalidez.contains(e.code)) {
      debugPrint('🔒 TokenRefreshService: sesión inválida (${e.code}) — cerrando sesión');
      onSesionInvalida?.call(
        'Tu sesión ha expirado. Por favor, inicia sesión de nuevo.',
      );
      // Forzar signOut para que authStateChanges() emita null
      // y el StreamBuilder de main.dart redirija a PantallaLogin.
      FirebaseAuth.instance.signOut().catchError((_) {});
    }
  }

  // ── ESTADO ────────────────────────────────────────────────────────────────

  bool get estaActivo => _tokenSubscription != null;
}

