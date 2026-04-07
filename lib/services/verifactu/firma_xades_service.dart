import 'dart:typed_data';

// ═══════════════════════════════════════════════════════════════════════════
// EXCEPCIONES
// ═══════════════════════════════════════════════════════════════════════════

/// Excepción específica del módulo de firma electrónica.
class FirmaException implements Exception {
  final String mensaje;
  final String? codigo;
  FirmaException(this.mensaje, {this.codigo});
  @override
  String toString() => codigo != null
      ? '[${codigo!}] FirmaException: $mensaje'
      : 'FirmaException: $mensaje';
}

// ═══════════════════════════════════════════════════════════════════════════
// MODELOS
// ═══════════════════════════════════════════════════════════════════════════

/// Estado del certificado de firma.
enum EstadoCertificado {
  /// Certificado dentro del período de validez.
  valido,

  /// Certificado expirado (notAfter < ahora).
  caducado,

  /// Certificado no activado aún (notBefore > ahora).
  noVigente,

  /// Certificado revocado (OCSP o CRL).
  revocado,

  /// Error indeterminado al verificar el estado.
  error,
}

/// Información del certificado X.509 de firma.
class CertificadoInfo {
  /// Nombre del titular (campo Subject DN).
  final String titular;

  /// Nombre de la CA emisora (campo Issuer DN).
  final String emisor;

  /// Fecha de inicio de validez.
  final DateTime validoDesde;

  /// Fecha de fin de validez.
  final DateTime validoHasta;

  /// Número de serie del certificado (hex).
  final String numeroDeSerie;

  /// Huella SHA-256 del certificado DER (hex).
  final String huellaSha256;

  /// NIF/CIF del titular extraído del Subject DN (OID 2.5.4.5 serialNumber).
  /// Null si no se pudo extraer (certificado de pruebas, etc.).
  final String? nif;

  const CertificadoInfo({
    required this.titular,
    required this.emisor,
    required this.validoDesde,
    required this.validoHasta,
    required this.numeroDeSerie,
    required this.huellaSha256,
    this.nif,
  });

  /// true si la fecha actual está dentro del período de validez.
  bool get estaVigente {
    final ahora = DateTime.now();
    return !ahora.isBefore(validoDesde) && !ahora.isAfter(validoHasta);
  }

  /// Días restantes hasta la expiración (negativo si ya expiró).
  int get diasParaExpirar => validoHasta.difference(DateTime.now()).inDays;

  @override
  String toString() =>
      'CertificadoInfo{titular: $titular, validoHasta: $validoHasta}';
}

/// Resultado de verificar la firma de un registro XML.
class VerificacionFirmaResult {
  /// true si la firma es válida y el certificado está vigente.
  final bool esValida;

  /// Errores encontrados (vacío si la firma es válida).
  final List<String> errores;

  /// Información del certificado hallado en la firma (si se pudo extraer).
  final CertificadoInfo? certificado;

  const VerificacionFirmaResult({
    required this.esValida,
    required this.errores,
    this.certificado,
  });

  factory VerificacionFirmaResult.valida(CertificadoInfo cert) =>
      VerificacionFirmaResult(esValida: true, errores: [], certificado: cert);

  factory VerificacionFirmaResult.invalida(List<String> errores) =>
      VerificacionFirmaResult(esValida: false, errores: errores);
}

// ═══════════════════════════════════════════════════════════════════════════
// INTERFAZ ABSTRACTA
// ═══════════════════════════════════════════════════════════════════════════

/// Interfaz del servicio de firma electrónica XAdES-BES Enveloped.
///
/// Normativa:
/// - ETSI EN 319 132 — XAdES (XML Advanced Electronic Signatures)
/// - Tipo: XAdES-BES Enveloped Signature
/// - Algoritmo firma: RSA-SHA256 (http://www.w3.org/2001/04/xmldsig-more#rsa-sha256)
/// - Algoritmo C14N: http://www.w3.org/TR/2001/REC-xml-c14n-20010315
/// - Obligatorio en: modo NO VERI*FACTU (art. 12 RD 1007/2023)
/// - Exonerado en:   modo VERI*FACTU    (art. 16.3 RD 1007/2023)
abstract class FirmaXadesService {
  // ── FIRMA ────────────────────────────────────────────────────────────────

  /// Firma un registro XML con XAdES-BES Enveloped.
  ///
  /// Devuelve el mismo XML con el bloque [ds:Signature] insertado
  /// antes del cierre del elemento raíz.
  ///
  /// Lanza [FirmaException] si el certificado está caducado o revocado.
  Future<String> firmarRegistro(String xmlRegistro);

  // ── VERIFICACIÓN ─────────────────────────────────────────────────────────

  /// Verifica que el XML contiene una firma XAdES-BES válida.
  ///
  /// Comprueba:
  /// 1. Presencia y estructura del bloque [ds:Signature].
  /// 2. Integridad del digest (SHA-256 del contenido canonicalizado).
  /// 3. Validez de la firma RSA con la clave pública del certificado.
  /// 4. Vigencia del certificado en el momento de la firma.
  Future<VerificacionFirmaResult> verificarFirma(String xmlRegistro);

  // ── CERTIFICADO ──────────────────────────────────────────────────────────

  /// Devuelve información del certificado configurado actualmente.
  Future<CertificadoInfo> obtenerInfoCertificado();

  /// Verifica el estado del certificado (vigencia + no revocado).
  ///
  /// La consulta OCSP para revocación se implementará en fases futuras.
  Future<EstadoCertificado> verificarEstadoCertificado();

  // ── MODO VERIFACTU ────────────────────────────────────────────────────────

  /// Aplica firma según el modo activo.
  ///
  /// - VERI*FACTU (esVerifactu=true):  devuelve el XML intacto (art. 16.3).
  /// - NO VERI*FACTU (esVerifactu=false): firma con XAdES-BES (art. 12).
  Future<String> aplicarFirmaSegunModo(
    String xmlRegistro, {
    required bool esVerifactu,
  }) async {
    if (esVerifactu) return xmlRegistro;
    return firmarRegistro(xmlRegistro);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTENIDOS PARSEADOS DE UN PKCS#12
// (clase interna usada por FirmaXadesPkcs12Service)
// ═══════════════════════════════════════════════════════════════════════════

/// Contenidos extraídos de un archivo PKCS#12.
class Pkcs12Contents {
  /// Clave privada RSA en formato PKCS#8 DER.
  final Uint8List privateKeyDer;

  /// Certificado X.509 en formato DER.
  final Uint8List certificateDer;

  const Pkcs12Contents({
    required this.privateKeyDer,
    required this.certificateDer,
  });
}

