import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Autenticación biométrica (FaceID / Huella dactilar)
//
// Almacenamiento seguro (flutter_secure_storage):
//   biometria_activa:    "true" | "false"
//   biometria_uid:       UID del usuario que activó la biometría
//   biometria_email:     email para pre-rellenar el campo
//
// Flujo:
//   1. Primer login exitoso → _ofrecerBiometria() en pantalla_login.dart
//   2. Siguiente apertura → disponible() → mostrar PantallaLoginBiometrico
//   3. Si biometría falla 3 veces → cerrarSesionBiometrica() → login normal
//
// FACE ID en iOS:
//   - NSFaceIDUsageDescription ya configurado en ios/Runner/Info.plist
//   - El permiso se solicita automáticamente al llamar a authenticate()
//   - NO verificar canCheckBiometrics antes de authenticate(): devuelve false
//     antes de que el usuario conceda el permiso y evitaría mostrar el diálogo
// ─────────────────────────────────────────────────────────────────────────────

class BiometriaService {
  static final BiometriaService _i = BiometriaService._();
  factory BiometriaService() => _i;
  BiometriaService._();

  final LocalAuthentication _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyActiva  = 'biometria_activa';
  static const _keyUid     = 'biometria_uid';
  static const _keyEmail   = 'biometria_email';

  // ── DISPONIBILIDAD ───────────────────────────────────────────────────────

  /// True si el usuario activó la biometría Y el dispositivo la soporta.
  /// Usa isDeviceSupported() (no canCheckBiometrics) para permitir que
  /// el diálogo de permiso de Face ID se muestre en el primer uso.
  Future<bool> disponible() async {
    final activa = await _storage.read(key: _keyActiva);
    if (activa != 'true') return false;
    return dispositivoSoportaBiometria();
  }

  /// True si el dispositivo soporta biometría a nivel de hardware/software.
  /// En iOS, devuelve true incluso antes de conceder el permiso de Face ID.
  Future<bool> dispositivoSoportaBiometria() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  // ── ACTIVAR ──────────────────────────────────────────────────────────────

  Future<void> activar({required String uid, required String email}) async {
    await _storage.write(key: _keyActiva, value: 'true');
    await _storage.write(key: _keyUid,    value: uid);
    await _storage.write(key: _keyEmail,  value: email);
  }

  // ── DESACTIVAR ───────────────────────────────────────────────────────────

  Future<void> desactivar() async {
    await _storage.write(key: _keyActiva, value: 'false');
    await _storage.delete(key: _keyUid);
    await _storage.delete(key: _keyEmail);
  }

  // ── AUTENTICAR ───────────────────────────────────────────────────────────

  /// Muestra el prompt biométrico del SO.
  ///
  /// En iOS, la primera llamada disparará el diálogo de permiso de Face ID
  /// automáticamente (requiere NSFaceIDUsageDescription en Info.plist).
  /// Devuelve [ResultadoBiometrico].
  Future<ResultadoBiometrico> autenticar() async {
    try {
      // Verificar soporte a nivel de dispositivo (hardware/SO)
      // No usar canCheckBiometrics aquí porque en iOS devuelve false
      // hasta que el usuario conceda el permiso de Face ID
      final soporta = await _auth.isDeviceSupported();
      if (!soporta) {
        return ResultadoBiometrico(
          exito: false,
          razon: BiometriaRazon.noDisponible,
        );
      }

      final ok = await _auth.authenticate(
        localizedReason:
            'Usa tu huella dactilar o Face ID para acceder a Fluix CRM',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return ResultadoBiometrico(
        exito: ok,
        razon: ok ? null : BiometriaRazon.fallida,
      );
    } on PlatformException catch (e) {
      final razon = switch (e.code) {
        'NotAvailable'         => BiometriaRazon.noDisponible,
        'NotEnrolled'          => BiometriaRazon.noConfigurada,
        'PasscodeNotSet'       => BiometriaRazon.noConfigurada,
        'LockedOut'            => BiometriaRazon.bloqueada,
        'PermanentlyLockedOut' => BiometriaRazon.bloqueada,
        'UserCancel'           => BiometriaRazon.cancelada,
        'SystemCancel'         => BiometriaRazon.cancelada,
        _                      => BiometriaRazon.fallida,
      };
      return ResultadoBiometrico(exito: false, razon: razon);
    }
  }

  // ── LEER DATOS GUARDADOS ─────────────────────────────────────────────────

  Future<String?> get uidGuardado => _storage.read(key: _keyUid);
  Future<String?> get emailGuardado => _storage.read(key: _keyEmail);
  Future<bool> get estaActiva async =>
      (await _storage.read(key: _keyActiva)) == 'true';

  // ── TIPOS DE BIOMETRÍA DISPONIBLES ──────────────────────────────────────

  Future<List<BiometricType>> tiposDisponibles() async {
    try {
      // canCheckBiometrics solo devuelve true si el permiso está concedido
      // y hay biometría registrada. Usar para UI pero no para bloquear flujo.
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return [];
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<String> labelBoton() async {
    final tipos = await tiposDisponibles();
    if (tipos.contains(BiometricType.face)) return 'Continuar con Face ID';
    if (tipos.contains(BiometricType.fingerprint)) return 'Continuar con huella dactilar';
    // isDeviceSupported puede ser true aunque canCheckBiometrics sea false (pre-permiso)
    final soporta = await _auth.isDeviceSupported();
    if (soporta) return 'Continuar con biometría';
    return 'Acceso biométrico';
  }

  // ── ABRIR AJUSTES ────────────────────────────────────────────────────────

  /// Abre los ajustes de la app en el dispositivo (iOS: Ajustes → Fluix,
  /// Android: Ajustes → Apps → Fluix). Permite al usuario conceder el
  /// permiso de Face ID si lo denegó previamente.
  Future<void> abrirAjustesDispositivo() async {
    try {
      // En iOS 'app-settings:' abre Ajustes → Fluix directamente
      // donde el usuario puede conceder el permiso de Face ID
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final uri = Uri.parse('app-settings:');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      }
      // Android: abre la pantalla de ajustes de la app
      // (no existe un URL scheme directo, pero url_launcher maneja intent)
      final uri = Uri.parse('package:com.fluixtech.crm');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('⚠️ No se pudieron abrir los ajustes: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO
// ─────────────────────────────────────────────────────────────────────────────

enum BiometriaRazon {
  noDisponible,
  noConfigurada,
  bloqueada,
  cancelada,
  fallida,
}

class ResultadoBiometrico {
  final bool exito;
  final BiometriaRazon? razon;

  const ResultadoBiometrico({required this.exito, this.razon});

  String? get mensajeError {
    if (exito) return null;
    return switch (razon) {
      BiometriaRazon.noDisponible  => 'Biometría no disponible en este dispositivo.',
      BiometriaRazon.noConfigurada => 'No hay biometría configurada. Activa Face ID o huella en Ajustes del dispositivo.',
      BiometriaRazon.bloqueada     => 'Biometría bloqueada. Usa tu PIN o contraseña para desbloquear.',
      BiometriaRazon.cancelada     => null, // el usuario canceló voluntariamente
      BiometriaRazon.fallida       => 'Autenticación biométrica fallida.',
      null                         => null,
    };
  }
}

