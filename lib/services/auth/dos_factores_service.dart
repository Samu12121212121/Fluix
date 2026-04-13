import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Autenticación de dos factores por SMS (Firebase Phone Auth)
//
// Datos en Firestore usuarios/{uid}:
//   dos_factores_activo:   bool      (2FA habilitado)
//   dos_factores_telefono: string    (número completo: "+34612345678")
//
// Flujo de activación (primera vez en perfil):
//   1. enviarCodigoActivacion(telefono)  →  verificationId
//   2. confirmarActivacion(verificationId, codigo)
//      → linkea el teléfono a la cuenta + guarda en Firestore
//
// Flujo de login (cuando dos_factores_activo == true):
//   1. enviarCodigoVerificacion(telefono)  →  verificationId
//   2. verificarCodigo(verificationId, codigo)  →  bool
// ─────────────────────────────────────────────────────────────────────────────

class DosFactoresService {
  static final DosFactoresService _i = DosFactoresService._();
  factory DosFactoresService() => _i;
  DosFactoresService._();

  static const int _maxIntentos = 3;
  int _intentosFallidos = 0;
  int get intentosFallidos => _intentosFallidos;

  void resetIntentos() => _intentosFallidos = 0;

  // ── LEER CONFIGURACIÓN ────────────────────────────────────────────────────

  Future<({bool activo, String telefono})> obtenerConfig(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();
    final data = doc.data() ?? {};
    return (
      activo: data['dos_factores_activo'] as bool? ?? false,
      telefono: data['dos_factores_telefono'] as String? ?? '',
    );
  }

  // ── ENVIAR CÓDIGO ─────────────────────────────────────────────────────────

  /// Envía SMS al teléfono y devuelve el verificationId.
  /// Compatible con Android (auto-verificación) e iOS.
  Future<String> enviarCodigo({
    required String telefono,
    required void Function(String mensaje) onError,
  }) async {
    final tel = telefono.trim().replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\+\d{7,15}$').hasMatch(tel)) {
      const msg = 'Número inválido. Usa formato internacional: +34612345678';
      onError(msg);
      throw Exception(msg);
    }

    final completer = Completer<String>();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: tel,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {
          debugPrint('2FA auto-completado (Android)');
        },
        verificationFailed: (FirebaseAuthException e) {
          final msg = switch (e.code) {
            'invalid-phone-number'   => 'Número de teléfono no válido.',
            'quota-exceeded'         => 'Demasiadas solicitudes. Inténtalo más tarde.',
            'network-request-failed' => 'Sin conexión. Comprueba tu red.',
            'operation-not-allowed'  => 'Verificación SMS no activada. Contacta con soporte.',
            _                        => 'Error al enviar código: ${e.message}',
          };
          onError(msg);
          if (!completer.isCompleted) completer.completeError(msg);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
      );
    } on PlatformException catch (e) {
      final msg = 'Error de plataforma al enviar SMS: ${e.message ?? e.code}';
      onError(msg);
      if (!completer.isCompleted) completer.completeError(msg);
    } catch (e) {
      final msg = 'Error inesperado al enviar SMS: $e';
      onError(msg);
      if (!completer.isCompleted) completer.completeError(msg);
    }

    return completer.future;
  }

  // ── VERIFICAR CÓDIGO (LOGIN — 2FA check) ─────────────────────────────────

  // ── ANÁLISIS DE CAUSAS POSIBLES DE FALLO EN 2FA ──────────────────────────
  // 1. verificationId caducado: Firebase SMS verificationId expira en ~5 min.
  //    El bug original era que _reenviar() en la UI no actualizaba el verificationId.
  //    FIX APLICADO en pantalla_verificacion_2fa.dart._reenviar().
  // 2. Código incorrecto (el más común): el usuario introduce mal los 6 dígitos.
  //    → devuelve false con 'invalid-verification-code'.
  // 3. session-expired: el SMS completo caducó (>5 min sin verificar).
  //    → se lanza SessionExpiredException que la UI muestra al usuario.
  // 4. Teléfono no vinculado: si el usuario nunca activó 2FA correctamente,
  //    reauthenticateWithCredential falla con user-mismatch → intenta linkWithCredential.
  // 5. Formato SMS vs TOTP: este servicio usa Firebase Phone Auth (SMS), NO TOTP.
  //    No hay problema de timing ni de UTC.
  // 6. Campo Firestore dos_factores_telefono vacío: sin teléfono no se lanza el flujo 2FA.
  // ──────────────────────────────────────────────────────────────────────────

  /// Verifica el código SMS durante el flujo de login.
  /// Devuelve true si es correcto, false si es incorrecto.
  /// Lanza [TooManyAttemptsException] si se superan los intentos.
  ///
  /// IMPORTANTE: usa reauthenticateWithCredential cuando el usuario ya está
  /// autenticado (email/password) para NO cambiar la sesión activa.
  Future<bool> verificarCodigo({
    required String verificationId,
    required String codigo,
  }) async {
    debugPrint('🔐 2FA verificarCodigo → intentosFallidos=$_intentosFallidos');
    if (_intentosFallidos >= _maxIntentos) {
      debugPrint('🔐 2FA → demasiados intentos ($_maxIntentos), lanzando TooManyAttemptsException');
      throw TooManyAttemptsException();
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: codigo,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('🔐 2FA: currentUser=${currentUser?.uid ?? "NULL"} | uid=${currentUser?.uid}');

      if (currentUser != null) {
        // Usuario ya autenticado con email/contraseña.
        // Usar reauthenticateWithCredential para validar el teléfono
        // sin cambiar el usuario en sesión ni crear otra cuenta.
        debugPrint('🔐 2FA: intentando reauthenticateWithCredential...');
        try {
          await currentUser.reauthenticateWithCredential(credential);
          debugPrint('🔐 2FA: reauthenticate OK ✅');
        } on FirebaseAuthException catch (reauthErr) {
          debugPrint('🔐 2FA: reauthenticate error=${reauthErr.code}');
          if (reauthErr.code == 'user-mismatch' ||
              reauthErr.code == 'user-not-found') {
            // Teléfono no vinculado aún — intentar vincularlo
            debugPrint('🔐 2FA: intentando linkWithCredential...');
            try {
              await currentUser.linkWithCredential(credential);
              debugPrint('🔐 2FA: link OK ✅');
            } on FirebaseAuthException catch (linkErr) {
              debugPrint('🔐 2FA: link error=${linkErr.code}');
              final yaVinculado =
                  linkErr.code == 'provider-already-linked' ||
                  linkErr.code == 'credential-already-in-use';
              if (!yaVinculado) {
                _incrementarIntentos();
                return false;
              }
              // Ya vinculado → reintentar reauthenticate
              debugPrint('🔐 2FA: ya vinculado, reintentando reauthenticate...');
              await currentUser.reauthenticateWithCredential(credential);
            }
          } else {
            rethrow;
          }
        }
      } else {
        // Fallback: sign-in directo (el usuario no estaba en sesión)
        debugPrint('🔐 2FA: signInWithCredential (fallback sin sesión activa)');
        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      debugPrint('🔐 2FA: verificación EXITOSA ✅');
      resetIntentos();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('🔐 2FA: FirebaseAuthException code=${e.code} message=${e.message}');
      if (e.code == 'invalid-verification-code' ||
          e.code == 'invalid-verification-id' ||
          e.code == 'invalid-credential') {
        _incrementarIntentos();
        return false;
      }
      if (e.code == 'session-expired') {
        debugPrint('🔐 2FA: session-expired — pedir reenvío de SMS');
        rethrow; // La UI mostrará "código expirado"
      }
      debugPrint('🔐 2FA: error no manejado → devolviendo false');
      _incrementarIntentos();
      return false;
    }
  }

  // ── ACTIVAR 2FA (desde perfil) ────────────────────────────────────────────

  /// Vincula el número de teléfono a la cuenta y activa 2FA en Firestore.
  Future<void> activar2FA({
    required String uid,
    required String verificationId,
    required String codigo,
    required String telefono,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: codigo,
    );

    try {
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'provider-already-linked' &&
          e.code != 'credential-already-in-use') {
        rethrow;
      }
    }

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'dos_factores_activo':   true,
      'dos_factores_telefono': telefono,
    });
  }

  // ── DESACTIVAR 2FA ────────────────────────────────────────────────────────

  Future<void> desactivar2FA(String uid) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
      'dos_factores_activo': false,
    });
    try {
      await FirebaseAuth.instance.currentUser!
          .unlink(PhoneAuthProvider.PROVIDER_ID);
    } catch (_) {}
  }

  // ── PRIVADO ───────────────────────────────────────────────────────────────

  void _incrementarIntentos() {
    _intentosFallidos++;
    if (_intentosFallidos >= _maxIntentos) throw TooManyAttemptsException();
  }
}

class TooManyAttemptsException implements Exception {
  @override
  String toString() =>
      'Se ha superado el límite de intentos. La sesión ha sido cerrada.';
}
