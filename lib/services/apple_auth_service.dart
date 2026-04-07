// ═══════════════════════════════════════════════════════════════════════════════
// APPLE SIGN-IN SERVICE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Obligatorio para publicar en App Store si se ofrece login con terceros.
// Usa sign_in_with_apple + Firebase Auth.
//
// Requisitos previos (Apple Developer Console):
//   1. Registrar App ID con capability "Sign In with Apple"
//   2. Crear Service ID para web callback (si se necesita web)
//   3. Habilitar proveedor Apple en Firebase Console → Authentication → Sign-in method
//
// Seguridad:
//   - Se genera un nonce aleatorio de 32 bytes
//   - Se envía su hash SHA-256 a Apple
//   - Firebase valida nonce + idToken
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthService {
  AppleAuthService._();
  static final instance = AppleAuthService._();

  // ═════════════════════════════════════════════════════════════════════════════
  // DISPONIBILIDAD
  // ═════════════════════════════════════════════════════════════════════════════

  /// Devuelve true si Apple Sign-In está disponible en este dispositivo.
  /// - iOS 13+: siempre disponible
  /// - Android/Web: no disponible (sin Service ID web configurado)
  static Future<bool> isAvailable() async {
    try {
      return await SignInWithApple.isAvailable();
    } catch (_) {
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // SIGN IN
  // ═════════════════════════════════════════════════════════════════════════════

  /// Inicia sesión con Apple y devuelve el [UserCredential] de Firebase.
  ///
  /// Lanza [SignInWithAppleAuthorizationException] si el usuario cancela.
  /// Lanza [FirebaseAuthException] si Firebase rechaza el token.
  static Future<UserCredential> signIn() async {
    // 1. Generar nonce criptográficamente seguro
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    // 2. Solicitar credencial a Apple
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    // 3. Crear OAuthCredential para Firebase
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    // 4. Iniciar sesión en Firebase
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(oauthCredential);

    // 5. Actualizar displayName si Apple lo proporcionó (solo la primera vez)
    //    Apple solo envía el nombre en el PRIMER login. Después no lo vuelve a dar.
    final user = userCredential.user;
    if (user != null && _shouldUpdateDisplayName(user, appleCredential)) {
      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((s) => s != null && s.isNotEmpty).join(' ');

      if (fullName.isNotEmpty) {
        await user.updateDisplayName(fullName);
        // Recargar para que displayName se refleje inmediatamente
        await user.reload();
      }
    }

    return userCredential;
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // HELPERS PRIVADOS
  // ═════════════════════════════════════════════════════════════════════════════

  /// Genera un nonce alfanumérico criptográficamente seguro de [length] caracteres.
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Calcula el hash SHA-256 del string y lo devuelve en hexadecimal.
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Determina si debemos actualizar el displayName.
  /// Apple solo envía nombre completo en el primer login.
  static bool _shouldUpdateDisplayName(
      User user, AuthorizationCredentialAppleID appleCredential) {
    // Si el usuario ya tiene displayName, no sobreescribir
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return false;
    }
    // Si Apple no envió nombre, no hay nada que actualizar
    if ((appleCredential.givenName == null ||
            appleCredential.givenName!.isEmpty) &&
        (appleCredential.familyName == null ||
            appleCredential.familyName!.isEmpty)) {
      return false;
    }
    return true;
  }

  /// Extrae el nombre para mostrar de las credenciales Apple.
  /// Útil para crear el documento de usuario en Firestore.
  static String getDisplayName(
      AuthorizationCredentialAppleID appleCredential, User user) {
    // Intentar nombre de Apple
    final fullName = [
      appleCredential.givenName,
      appleCredential.familyName,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;

    // Fallback: displayName de Firebase
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }

    // Fallback: email (puede ser relay de Apple)
    final email = user.email ?? appleCredential.email ?? '';
    if (email.contains('@privaterelay.appleid.com')) {
      return 'Usuario Apple';
    }
    return email.split('@').first;
  }
}

