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

  /// Envía SMS al teléfono y devuelve el verificationId (o un completer).
  /// Compatible con Android (auto-verificación) e iOS.
  Future<String> enviarCodigo({
    required String telefono,
    required void Function(String mensaje) onError,
  }) async {
    // ── Normalizar y validar formato E.164 ──────────────────────────────
    final tel = telefono.trim().replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\+\d{7,15}$').hasMatch(tel)) {
      const msg = 'Número inválido. Usa formato internacional: +34612345678';
      onError(msg);
      throw msg;
    }

    final completer = Completer<String>();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: tel,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {
          // Android: auto-completado (no se usa para 2FA manual, lo ignoramos)
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

  /// Verifica el código SMS durante el flujo de login.
  /// Devuelve true si es correcto, false si es incorrecto.
  /// Lanza [TooManyAttemptsException] si se superan los intentos.
  Future<bool> verificarCodigo({
    required String verificationId,
    required String codigo,
  }) async {
    if (_intentosFallidos >= _maxIntentos) {
      throw TooManyAttemptsException();
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: codigo,
      );

      // Intento de sign-in para validar el código (si el teléfono está
      // vinculado a la cuenta, devuelve el mismo usuario).
      final result = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final currentUid = result.user?.uid;
      final expectedUid = FirebaseAuth.instance.currentUser?.uid ?? currentUid;

      if (currentUid == expectedUid) {
        resetIntentos();
        return true;
      }
      _incrementarIntentos();
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code' ||
          e.code == 'invalid-verification-id') {
        _incrementarIntentos();
        return false;
      }
      rethrow;
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

    // Vincular teléfono a la cuenta de Firebase Auth
    try {
      await FirebaseAuth.instance.currentUser!
          .linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // Si ya estaba vinculado, continuar
      if (e.code != 'provider-already-linked' &&
          e.code != 'credential-already-in-use') {
        rethrow;
      }
    }

    // Guardar en Firestore
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
    // Desvincula el proveedor de teléfono si está vinculado
    try {
      await FirebaseAuth.instance.currentUser!
          .unlink(PhoneAuthProvider.PROVIDER_ID);
    } catch (_) {}
  }

  // ── PRIVADO ────────────────────────────────────────────────────────────────

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

