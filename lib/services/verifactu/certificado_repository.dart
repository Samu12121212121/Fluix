import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'firma_xades_service.dart';
import 'firma_xades_pkcs12_service.dart';

/// Repositorio para almacenar y recuperar certificados de firma
/// usando flutter_secure_storage (Keychain en iOS, KeyStore en Android).
///
/// El certificado PKCS#12 (.p12/.pfx) se almacena cifrado en el
/// almacenamiento seguro del dispositivo. Nunca se guarda en texto plano.
class CertificadoRepository {
  final FlutterSecureStorage _storage;

  static const _keyBytes = 'verifactu_cert_bytes';
  static const _keyPassword = 'verifactu_cert_password';
  static const _keyTitular = 'verifactu_cert_titular';
  static const _keyValidoHasta = 'verifactu_cert_valido_hasta';

  CertificadoRepository({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // ── GUARDAR ───────────────────────────────────────────────────────────────

  /// Guarda un certificado PKCS#12 en almacenamiento seguro.
  ///
  /// Valida que el .p12 sea parseable y el certificado esté vigente
  /// ANTES de guardarlo. Lanza [FirmaException] si no es válido.
  Future<CertificadoInfo> guardarCertificado({
    required Uint8List pkcs12Bytes,
    required String password,
  }) async {
    // 1. Validar que se puede parsear y obtener info
    final servicio = FirmaXadesPkcs12Service.fromSecureStorage(
      pkcs12Bytes: pkcs12Bytes,
      password: password,
    );
    final info = await servicio.obtenerInfoCertificado();
    final estado = await servicio.verificarEstadoCertificado();

    if (estado == EstadoCertificado.caducado) {
      throw FirmaException(
        'El certificado ha caducado (${info.validoHasta}). '
        'Importe un certificado vigente.',
        codigo: 'CERT-001',
      );
    }
    if (estado == EstadoCertificado.noVigente) {
      throw FirmaException(
        'El certificado no es válido todavía (válido desde ${info.validoDesde}).',
        codigo: 'CERT-002',
      );
    }
    if (estado != EstadoCertificado.valido) {
      throw FirmaException(
        'No se pudo verificar el estado del certificado.',
        codigo: 'CERT-003',
      );
    }

    // 2. Guardar de forma segura
    await _storage.write(key: _keyBytes, value: base64.encode(pkcs12Bytes));
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyTitular, value: info.titular);
    await _storage.write(
      key: _keyValidoHasta,
      value: info.validoHasta.toIso8601String(),
    );

    return info;
  }

  // ── OBTENER ───────────────────────────────────────────────────────────────

  /// Obtiene el servicio de firma si hay un certificado configurado.
  ///
  /// Devuelve `null` si no hay certificado almacenado.
  Future<FirmaXadesService?> obtenerServicioDeFirma() async {
    final bytesB64 = await _storage.read(key: _keyBytes);
    final password = await _storage.read(key: _keyPassword);
    if (bytesB64 == null || password == null) return null;

    return FirmaXadesPkcs12Service.fromSecureStorage(
      pkcs12Bytes: base64.decode(bytesB64),
      password: password,
    );
  }

  /// Comprueba si hay un certificado configurado.
  Future<bool> tieneCertificadoConfigurado() async {
    return (await _storage.read(key: _keyBytes)) != null;
  }

  /// Devuelve info resumida del certificado almacenado (sin parsearlo).
  ///
  /// Útil para mostrar en la UI sin cargar el .p12 completo.
  Future<({String titular, DateTime validoHasta})?> obtenerResumen() async {
    final titular = await _storage.read(key: _keyTitular);
    final validoHastaStr = await _storage.read(key: _keyValidoHasta);
    if (titular == null || validoHastaStr == null) return null;

    return (
      titular: titular,
      validoHasta: DateTime.parse(validoHastaStr),
    );
  }

  // ── ELIMINAR ──────────────────────────────────────────────────────────────

  /// Elimina el certificado del almacenamiento seguro.
  Future<void> eliminarCertificado() async {
    await _storage.delete(key: _keyBytes);
    await _storage.delete(key: _keyPassword);
    await _storage.delete(key: _keyTitular);
    await _storage.delete(key: _keyValidoHasta);
  }
}

