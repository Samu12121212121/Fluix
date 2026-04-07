import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'verifactu/firma_xades_service.dart';
import 'verifactu/firma_xades_pkcs12_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO CENTRALIZADO DE CERTIFICADO DIGITAL FISCAL
//
// Gestiona UN solo certificado PKCS#12 por empresa, accesible desde:
//   - Módulo Verifactu
//   - Módulo MOD 390, 303, 111, 115, 130...
//   - Cualquier módulo fiscal que requiera firma
//
// Almacenamiento:
//   - Bytes del .p12: flutter_secure_storage (cifrado en Keychain/KeyStore)
//   - Metadatos (titular, expiry, nif): Firestore (no sensible)
//   - Historial (últimos 3): Firestore
// ═══════════════════════════════════════════════════════════════════════════════

/// Estado del certificado digital para la UI.
enum EstadoCertDigital {
  /// Certificado válido, dentro del período de validez.
  valido,
  /// Expira en menos de 60 días.
  proximoAExpirar,
  /// Sin certificado configurado.
  sinCertificado,
  /// Certificado expirado.
  expirado,
  /// Error al cargar el certificado.
  error,
}

/// Metadata del certificado almacenada en Firestore.
class CertificadoDigitalMeta {
  final String titular;
  final String emisor;
  final String? nif;
  final DateTime validoDesde;
  final DateTime validoHasta;
  final String numeroDeSerie;
  final String huellaSha256;
  final DateTime fechaSubida;
  final String? nombreArchivo;

  const CertificadoDigitalMeta({
    required this.titular,
    required this.emisor,
    this.nif,
    required this.validoDesde,
    required this.validoHasta,
    required this.numeroDeSerie,
    required this.huellaSha256,
    required this.fechaSubida,
    this.nombreArchivo,
  });

  /// Días que quedan para la expiración (negativo si ya expiró).
  int get diasParaExpirar => validoHasta.difference(DateTime.now()).inDays;

  bool get estaVigente {
    final ahora = DateTime.now();
    return !ahora.isBefore(validoDesde) && !ahora.isAfter(validoHasta);
  }

  EstadoCertDigital get estado {
    if (!estaVigente) {
      return DateTime.now().isAfter(validoHasta)
          ? EstadoCertDigital.expirado
          : EstadoCertDigital.error;
    }
    if (diasParaExpirar <= 60) return EstadoCertDigital.proximoAExpirar;
    return EstadoCertDigital.valido;
  }

  factory CertificadoDigitalMeta.fromFirestore(Map<String, dynamic> d) =>
      CertificadoDigitalMeta(
        titular: d['titular'] ?? '',
        emisor: d['emisor'] ?? '',
        nif: d['nif'],
        validoDesde: _parseTs(d['valido_desde']),
        validoHasta: _parseTs(d['valido_hasta']),
        numeroDeSerie: d['numero_serie'] ?? '',
        huellaSha256: d['huella_sha256'] ?? '',
        fechaSubida: _parseTs(d['fecha_subida']),
        nombreArchivo: d['nombre_archivo'],
      );

  Map<String, dynamic> toFirestore() => {
        'titular': titular,
        'emisor': emisor,
        'nif': nif,
        'valido_desde': Timestamp.fromDate(validoDesde),
        'valido_hasta': Timestamp.fromDate(validoHasta),
        'numero_serie': numeroDeSerie,
        'huella_sha256': huellaSha256,
        'fecha_subida': Timestamp.fromDate(fechaSubida),
        'nombre_archivo': nombreArchivo,
      };

  static DateTime _parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

/// Servicio centralizado de gestión del certificado digital fiscal.
///
/// Uso:
/// ```dart
/// final svc = CertificadoDigitalService(empresaId: empresaId);
/// await svc.cargarCertificado(bytes: p12Bytes, password: '1234', nombreArchivo: 'fnmt.p12');
/// final servFirma = await svc.obtenerServicioDeFirma();
/// ```
class CertificadoDigitalService {
  static const _keyBytes = 'cert_digital_bytes';
  static const _keyPassword = 'cert_digital_password';
  static const int _maxHistorial = 3;

  final String empresaId;
  final FirebaseFirestore _db;
  final FlutterSecureStorage _storage;

  CertificadoDigitalService({
    required this.empresaId,
    FirebaseFirestore? db,
    FlutterSecureStorage? storage,
  })  : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // ─── REFERENCIAS FIRESTORE ─────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> get _certRef => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('configuracion')
      .doc('certificado_digital');

  CollectionReference<Map<String, dynamic>> get _historialRef => _db
      .collection('empresas')
      .doc(empresaId)
      .collection('certificados_historial');

  // ─── CARGAR (SUBIR) CERTIFICADO ────────────────────────────────────────────

  /// Carga un nuevo certificado PKCS#12, lo valida y lo almacena de forma segura.
  ///
  /// Parámetros:
  /// - [bytes]: contenido del archivo .p12/.pfx
  /// - [password]: contraseña del archivo
  /// - [nifEmpresa]: NIF de la empresa para verificar que coincide con el cert
  /// - [nombreArchivo]: nombre del archivo (para mostrar en UI)
  ///
  /// Lanza [FirmaException] si:
  /// - La contraseña es incorrecta (P12-PWD)
  /// - El certificado está expirado (CERT-001)
  /// - El NIF no coincide (CERT-NIF)
  /// - El formato es inválido (P12-000)
  Future<CertificadoDigitalMeta> cargarCertificado({
    required Uint8List bytes,
    required String password,
    String? nifEmpresa,
    String? nombreArchivo,
  }) async {
    // 1. Parsear y validar el .p12
    final servicio = FirmaXadesPkcs12Service.fromSecureStorage(
      pkcs12Bytes: bytes,
      password: password,
    );

    final CertificadoInfo info;
    try {
      info = await servicio.obtenerInfoCertificado();
    } catch (e) {
      if (e is FirmaException) rethrow;
      throw FirmaException(
          'Error al leer el certificado. Verifique la contraseña: $e',
          codigo: 'P12-READ');
    }

    // 2. Verificar vigencia
    final estado = await servicio.verificarEstadoCertificado();
    if (estado == EstadoCertificado.caducado) {
      throw FirmaException(
          'El certificado ha caducado (${_fmtDate(info.validoHasta)}). '
          'Importe un certificado vigente.',
          codigo: 'CERT-001');
    }
    if (estado == EstadoCertificado.noVigente) {
      throw FirmaException(
          'El certificado no es válido todavía '
          '(válido desde ${_fmtDate(info.validoDesde)}).',
          codigo: 'CERT-002');
    }

    // 3. Verificar NIF si se proporciona
    if (nifEmpresa != null &&
        nifEmpresa.isNotEmpty &&
        info.nif != null &&
        info.nif!.toUpperCase() != nifEmpresa.toUpperCase()) {
      throw FirmaException(
          'El NIF del certificado (${info.nif}) no coincide con el de la empresa ($nifEmpresa). '
          'Asegúrese de usar el certificado correcto.',
          codigo: 'CERT-NIF');
    }

    // 4. Guardar bytes en secure storage
    await _storage.write(key: _keyBytes, value: base64.encode(bytes));
    await _storage.write(key: _keyPassword, value: password);

    // 5. Construir metadata
    final meta = CertificadoDigitalMeta(
      titular: info.titular,
      emisor: info.emisor,
      nif: info.nif,
      validoDesde: info.validoDesde,
      validoHasta: info.validoHasta,
      numeroDeSerie: info.numeroDeSerie,
      huellaSha256: info.huellaSha256,
      fechaSubida: DateTime.now(),
      nombreArchivo: nombreArchivo,
    );

    // 6. Guardar metadata en Firestore
    await _certRef.set({
      ...meta.toFirestore(),
      'activo': true,
    });

    // 7. Añadir al historial (mantener los últimos _maxHistorial)
    await _guardarEnHistorial(meta);

    return meta;
  }

  // ─── OBTENER ───────────────────────────────────────────────────────────────

  /// Obtiene la metadata del certificado activo (sin cargar el .p12).
  Future<CertificadoDigitalMeta?> obtenerMeta() async {
    final doc = await _certRef.get();
    if (!doc.exists || doc.data() == null) return null;
    return CertificadoDigitalMeta.fromFirestore(doc.data()!);
  }

  /// Stream de la metadata del certificado activo.
  Stream<CertificadoDigitalMeta?> metaStream() {
    return _certRef.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return CertificadoDigitalMeta.fromFirestore(snap.data()!);
    });
  }

  /// Obtiene el servicio de firma si hay un certificado configurado.
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
  Future<bool> tieneCertificado() async =>
      (await _storage.read(key: _keyBytes)) != null;

  // ─── VALIDAR ───────────────────────────────────────────────────────────────

  /// Verifica el estado actual del certificado.
  Future<EstadoCertDigital> validar() async {
    final tieneBytes = await tieneCertificado();
    if (!tieneBytes) return EstadoCertDigital.sinCertificado;
    final meta = await obtenerMeta();
    if (meta == null) return EstadoCertDigital.sinCertificado;
    return meta.estado;
  }

  bool estaExpirado(CertificadoDigitalMeta meta) =>
      DateTime.now().isAfter(meta.validoHasta);

  String? getNIF(CertificadoDigitalMeta meta) => meta.nif;

  String getRazonSocial(CertificadoDigitalMeta meta) => meta.titular;

  DateTime getFechaExpiracion(CertificadoDigitalMeta meta) => meta.validoHasta;

  // ─── HISTORIAL ─────────────────────────────────────────────────────────────

  /// Obtiene los últimos [_maxHistorial] certificados subidos.
  Future<List<CertificadoDigitalMeta>> obtenerHistorial() async {
    final snap = await _historialRef
        .orderBy('fecha_subida', descending: true)
        .limit(_maxHistorial)
        .get();
    return snap.docs
        .map((d) => CertificadoDigitalMeta.fromFirestore(d.data()))
        .toList();
  }

  // ─── ELIMINAR ──────────────────────────────────────────────────────────────

  /// Elimina el certificado activo del dispositivo y de Firestore.
  Future<void> eliminarCertificado() async {
    await _storage.delete(key: _keyBytes);
    await _storage.delete(key: _keyPassword);
    await _certRef.delete();
  }

  // ─── PRIVADO ───────────────────────────────────────────────────────────────

  Future<void> _guardarEnHistorial(CertificadoDigitalMeta meta) async {
    // Añadir nueva entrada
    await _historialRef.add(meta.toFirestore());

    // Limpiar entradas antiguas (mantener solo _maxHistorial)
    final snap = await _historialRef
        .orderBy('fecha_subida', descending: true)
        .get();

    if (snap.docs.length > _maxHistorial) {
      final aEliminar = snap.docs.sublist(_maxHistorial);
      final batch = _db.batch();
      for (final doc in aEliminar) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

