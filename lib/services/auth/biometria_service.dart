  import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Autenticación biométrica (FaceID / Huella dactilar)
//
// Almacenamiento seguro (flutter_secure_storage):
//   biometria_activa:    "true" | "false"
//   biometria_uid:       UID del usuario que activó la biometría
//   biometria_email:     email para pre-rellenar el campo
//
// Flujo:
//   1. Primer login exitoso → ofrecerActivacion()
//   2. Siguiente apertura → disponible() → mostrar PantallaLoginBiometrico
//   3. Si biometría falla 3 veces → cerrarSesionBiometrica() → login normal
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

  /// True si el dispositivo tiene biometría registrada Y el usuario la activó.
  Future<bool> disponible() async {
    final activa = await _storage.read(key: _keyActiva);
    if (activa != 'true') return false;
    return _soportadoPorDispositivo();
  }

  Future<bool> _soportadoPorDispositivo() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isEnrolled = await _auth.isDeviceSupported();
      return canCheck && isEnrolled;
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
  /// Devuelve [ResultadoBiometrico].
  Future<ResultadoBiometrico> autenticar() async {
    try {
      final soporte = await _soportadoPorDispositivo();
      if (!soporte) {
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
        'NotAvailable'  => BiometriaRazon.noDisponible,
        'NotEnrolled'   => BiometriaRazon.noConfigurada,
        'LockedOut'     => BiometriaRazon.bloqueada,
        'PermanentlyLockedOut' => BiometriaRazon.bloqueada,
        _ => BiometriaRazon.fallida,
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
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<String> labelBoton() async {
    final tipos = await tiposDisponibles();
    if (tipos.contains(BiometricType.face)) return 'Continuar con Face ID';
    if (tipos.contains(BiometricType.fingerprint)) return 'Continuar con huella dactilar';
    return 'Acceso biométrico';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO
// ─────────────────────────────────────────────────────────────────────────────

enum BiometriaRazon {
  noDisponible,
  noConfigurada,
  bloqueada,
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
      BiometriaRazon.noConfigurada => 'No hay biometría configurada en el sistema.',
      BiometriaRazon.bloqueada     => 'Biometría bloqueada. Usa tu PIN para desbloquear.',
      BiometriaRazon.fallida       => 'Autenticación biométrica fallida.',
      null                         => null,
    };
  }
}

