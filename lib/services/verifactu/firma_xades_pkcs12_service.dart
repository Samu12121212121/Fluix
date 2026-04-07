import 'dart:convert';
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';
// Pointycastle — únicamente para operaciones crypto (RSA firma, SHA, 3DES, RC2)
import 'package:pointycastle/export.dart';
import 'firma_xades_service.dart';

/// Implementación de [FirmaXadesService] usando un certificado PKCS#12 (.p12/.pfx).
///
/// Usa ÚNICAMENTE [pointycastle] para:
/// - Parsear el PKCS#12 (RFC 7292) con soporte 3DES y RC2
/// - Parsear el certificado X.509 y extraer Subject/Issuer/Validez/NIF
/// - Firmar con RSA-SHA256 (PKCS#1 v1.5)
///
/// Compatible con certificados FNMT-RCM (Clase 2 CA), AC Camerfirma, ACCV.
class FirmaXadesPkcs12Service implements FirmaXadesService {
  final Uint8List _pkcs12Bytes;
  final String _password;

  Pkcs12Contents? _cached;

  FirmaXadesPkcs12Service._({
    required Uint8List pkcs12Bytes,
    required String password,
  })  : _pkcs12Bytes = pkcs12Bytes,
        _password = password;

  factory FirmaXadesPkcs12Service.fromSecureStorage({
    required Uint8List pkcs12Bytes,
    required String password,
  }) =>
      FirmaXadesPkcs12Service._(
          pkcs12Bytes: pkcs12Bytes, password: password);

  // ═══════════════════════════════════════════════════════════════════════
  // FirmaXadesService — impl
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Future<String> firmarRegistro(String xmlRegistro) async {
    final parsed = _obtenerParsed();
    final estado = await verificarEstadoCertificado();
    switch (estado) {
      case EstadoCertificado.caducado:
        throw FirmaException(
            'El certificado de firma ha caducado. Renuévelo antes de continuar.',
            codigo: 'XADES-001');
      case EstadoCertificado.revocado:
        throw FirmaException('El certificado de firma ha sido revocado.',
            codigo: 'XADES-002');
      case EstadoCertificado.noVigente:
        throw FirmaException(
            'El certificado de firma no es válido todavía.',
            codigo: 'XADES-003');
      case EstadoCertificado.error:
        throw FirmaException(
            'Error al verificar el estado del certificado.',
            codigo: 'XADES-004');
      case EstadoCertificado.valido:
        break;
    }

    final xmlC14n = _canonicalizarXml(xmlRegistro);
    final digestBytes = sha256.convert(utf8.encode(xmlC14n)).bytes;
    final digestB64 = base64.encode(digestBytes);
    final signedInfo = _buildSignedInfo(digestValue: digestB64);
    final signedInfoC14n = _canonicalizarXml(signedInfo);
    final firmaBytes = _firmarRsa(
      datos: Uint8List.fromList(utf8.encode(signedInfoC14n)),
      privateKeyDer: parsed.privateKeyDer,
    );
    final firmaB64 = base64.encode(firmaBytes);
    final certDerB64 = base64.encode(parsed.certificateDer);
    final certDigestB64 =
        base64.encode(sha256.convert(parsed.certificateDer).bytes);
    final signatureBlock = _buildXadesBlock(
      signedInfo: signedInfo,
      signatureValueB64: firmaB64,
      certDerB64: certDerB64,
      certDigestB64: certDigestB64,
      signingTime: DateTime.now(),
    );
    return _insertarFirmaEnXml(xmlRegistro, signatureBlock);
  }

  @override
  Future<VerificacionFirmaResult> verificarFirma(String xmlRegistro) async {
    final errores = <String>[];
    if (!xmlRegistro.contains('<ds:Signature')) {
      return VerificacionFirmaResult.invalida(
          ['XADES-V001: Falta bloque <ds:Signature>']);
    }
    if (!xmlRegistro.contains('<ds:SignedInfo')) {
      errores.add('XADES-V002: Falta bloque <ds:SignedInfo>');
    }
    if (!xmlRegistro.contains('<ds:SignatureValue')) {
      errores.add('XADES-V003: Falta bloque <ds:SignatureValue>');
    }
    if (!xmlRegistro.contains('xades:SigningTime')) {
      errores.add('XADES-V004: Falta xades:SigningTime en QualifyingProperties');
    }
    if (!xmlRegistro.contains('xades:SigningCertificateV2')) {
      errores.add('XADES-V005: Falta xades:SigningCertificateV2');
    }
    if (!xmlRegistro
        .contains('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')) {
      errores.add(
          'XADES-V006: Algoritmo de firma incorrecto (se requiere RSA-SHA256)');
    }

    try {
      final xmlSinFirma = _extraerXmlSinFirma(xmlRegistro);
      final xmlC14n = _canonicalizarXml(xmlSinFirma);
      final digestRecalculado =
          base64.encode(sha256.convert(utf8.encode(xmlC14n)).bytes);
      final digestEnFirma = _extraerDigestValue(xmlRegistro);
      if (digestEnFirma != null && digestEnFirma != digestRecalculado) {
        errores.add(
            'XADES-V007: DigestValue no coincide — el XML fue modificado tras la firma');
      }
    } catch (_) {
      errores.add('XADES-V008: Error al recalcular digest del contenido');
    }

    if (errores.isNotEmpty) return VerificacionFirmaResult.invalida(errores);

    CertificadoInfo? certInfo;
    try {
      final certB64 = _extraerCertificadoDeFirma(xmlRegistro);
      if (certB64 != null) {
        certInfo = _parseCertificadoInfo(base64.decode(certB64));
      }
    } catch (_) {}

    return VerificacionFirmaResult.valida(
      certInfo ??
          CertificadoInfo(
            titular: 'Desconocido',
            emisor: 'Desconocido',
            validoDesde: DateTime(1900),
            validoHasta: DateTime(2100),
            numeroDeSerie: '',
            huellaSha256: '',
          ),
    );
  }

  @override
  Future<CertificadoInfo> obtenerInfoCertificado() async {
    return _parseCertificadoInfo(_obtenerParsed().certificateDer);
  }

  @override
  Future<EstadoCertificado> verificarEstadoCertificado() async {
    try {
      final info = await obtenerInfoCertificado();
      final ahora = DateTime.now();
      if (ahora.isBefore(info.validoDesde)) return EstadoCertificado.noVigente;
      if (ahora.isAfter(info.validoHasta)) return EstadoCertificado.caducado;
      return EstadoCertificado.valido;
    } catch (_) {
      return EstadoCertificado.error;
    }
  }

  @override
  Future<String> aplicarFirmaSegunModo(
    String xmlRegistro, {
    required bool esVerifactu,
  }) async {
    if (esVerifactu) return xmlRegistro;
    return firmarRegistro(xmlRegistro);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PKCS#12 PARSING — asn1lib 1.6.x + pointycastle crypto
  // ═══════════════════════════════════════════════════════════════════════

  Pkcs12Contents _obtenerParsed() =>
      _cached ??= _parsePkcs12(_pkcs12Bytes, _password);

  static Pkcs12Contents _parsePkcs12(Uint8List bytes, String password) {
    final ASN1Sequence pfx;
    try {
      pfx = ASN1Parser(bytes).nextObject() as ASN1Sequence;
    } catch (e) {
      throw FirmaException(
          'Formato .p12 no válido — no se pudo parsear como DER: $e',
          codigo: 'P12-000');
    }

    if (pfx.elements.length < 2) {
      throw FirmaException('PKCS#12 malformado: faltan elementos en PFX',
          codigo: 'P12-001');
    }

    final authSafe = pfx.elements[1] as ASN1Sequence;
    final Uint8List authSafeData;
    try {
      authSafeData = _extraerContentInfoData(authSafe);
    } catch (e) {
      throw FirmaException(
          'Contraseña incorrecta o PKCS#12 corrupto: $e',
          codigo: 'P12-PWD');
    }

    final authenticatedSafe =
        ASN1Parser(authSafeData).nextObject() as ASN1Sequence;

    Uint8List? privateKeyDer;
    Uint8List? certificateDer;

    for (final element in authenticatedSafe.elements) {
      final ci = element as ASN1Sequence;
      if (ci.elements.isEmpty) continue;

      final oid = (ci.elements[0] as ASN1ObjectIdentifier).identifier ?? '';
      List<int>? safeContentsBytes;

      if (oid == '1.2.840.113549.1.7.1') {
        // pkcs7-data: SafeContents sin cifrar
        safeContentsBytes = _extraerContentInfoData(ci).toList();
      } else if (oid == '1.2.840.113549.1.7.6') {
        // pkcs7-encryptedData: SafeContents cifrado
        try {
          safeContentsBytes = _descifrarEncryptedData(ci, password).toList();
        } catch (e) {
          throw FirmaException(
              'Error al descifrar datos del .p12. Verifique la contraseña: $e',
              codigo: 'P12-PWD2');
        }
      }

      if (safeContentsBytes != null) {
        _parseSafeContents(
          Uint8List.fromList(safeContentsBytes),
          password,
          onCertificate: (der) => certificateDer ??= der,
          onPrivateKey: (der) => privateKeyDer ??= der,
        );
      }
    }

    if (privateKeyDer == null) {
      throw FirmaException(
          'No se encontró clave privada en el certificado .p12',
          codigo: 'P12-002');
    }
    if (certificateDer == null) {
      throw FirmaException(
          'No se encontró certificado en el archivo .p12',
          codigo: 'P12-003');
    }

    return Pkcs12Contents(
        privateKeyDer: privateKeyDer!, certificateDer: certificateDer!);
  }

  static Uint8List _extraerContentInfoData(ASN1Sequence ci) {
    if (ci.elements.length < 2) return Uint8List(0);
    final tagged = ci.elements[1];
    final innerBytes = tagged.valueBytes();
    final inner = ASN1Parser(innerBytes).nextObject();
    if (inner is ASN1OctetString) {
      return inner.octets;
    }
    return innerBytes;
  }

  static Uint8List _descifrarEncryptedData(ASN1Sequence ci, String password) {
    if (ci.elements.length < 2) {
      throw FirmaException('EncryptedData malformado', codigo: 'P12-ENC1');
    }
    final content = ci.elements[1];
    final cParser = ASN1Parser(content.valueBytes());
    final encData = cParser.nextObject() as ASN1Sequence;
    if (encData.elements.length < 2) {
      throw FirmaException('EncryptedData malformado (v2)', codigo: 'P12-ENC2');
    }
    final eci = encData.elements[1] as ASN1Sequence;
    if (eci.elements.length < 3) {
      throw FirmaException('EncryptedContentInfo malformado',
          codigo: 'P12-ENC3');
    }
    final algoSeq = eci.elements[1] as ASN1Sequence;
    final algoOid =
        (algoSeq.elements[0] as ASN1ObjectIdentifier).identifier ?? '';
    final encContent = eci.elements[2].valueBytes();
    final algoParams = algoSeq.elements.length > 1
        ? algoSeq.elements[1] as ASN1Sequence
        : ASN1Sequence();

    return _descifrarPbe(
      encContent: encContent,
      algoOid: algoOid,
      algoParams: algoParams,
      password: password,
    );
  }

  static Uint8List _descifrarPbe({
    required Uint8List encContent,
    required String algoOid,
    required ASN1Sequence algoParams,
    required String password,
  }) {
    final pwBytes = _passwordToBmp(password);

    if (algoOid == '1.2.840.113549.1.12.1.3') {
      // pbeWithSHAAnd3KeyTripleDES-CBC
      if (algoParams.elements.length < 2) {
        throw FirmaException('PBEParameter malformado (3DES)',
            codigo: 'P12-PBE1');
      }
      final salt = (algoParams.elements[0] as ASN1OctetString).octets;
      final iterations =
          (algoParams.elements[1] as ASN1Integer).valueAsBigInteger.toInt();
      final keyBytes = _pkcs12KDF(
          hash: 'SHA-1', id: 1, password: pwBytes, salt: salt,
          count: iterations, keyLength: 24);
      final ivBytes = _pkcs12KDF(
          hash: 'SHA-1', id: 2, password: pwBytes, salt: salt,
          count: iterations, keyLength: 8);
      final cipher = CBCBlockCipher(DESedeEngine());
      cipher.init(false, ParametersWithIV(KeyParameter(keyBytes), ivBytes));
      final output = Uint8List(encContent.length);
      var offset = 0;
      while (offset < encContent.length) {
        cipher.processBlock(encContent, offset, output, offset);
        offset += 8;
      }
      return _removePkcs7Padding(output);
    }

    if (algoOid == '1.2.840.113549.1.12.1.6') {
      // pbeWithSHAAnd40BitRC2-CBC
      if (algoParams.elements.length < 2) {
        throw FirmaException('PBEParameter malformado (RC2)',
            codigo: 'P12-PBE2');
      }
      final salt = (algoParams.elements[0] as ASN1OctetString).octets;
      final iterations =
          (algoParams.elements[1] as ASN1Integer).valueAsBigInteger.toInt();
      final keyBytes = _pkcs12KDF(
          hash: 'SHA-1', id: 1, password: pwBytes, salt: salt,
          count: iterations, keyLength: 5);
      final ivBytes = _pkcs12KDF(
          hash: 'SHA-1', id: 2, password: pwBytes, salt: salt,
          count: iterations, keyLength: 8);
      final cipher = CBCBlockCipher(RC2Engine());
      cipher.init(false, ParametersWithIV(KeyParameter(keyBytes), ivBytes));
      final output = Uint8List(encContent.length);
      var offset = 0;
      while (offset < encContent.length) {
        cipher.processBlock(encContent, offset, output, offset);
        offset += cipher.blockSize;
      }
      return _removePkcs7Padding(output);
    }

    throw FirmaException(
      'Algoritmo de cifrado PKCS#12 no soportado: $algoOid',
      codigo: 'P12-004',
    );
  }

  static Uint8List _pkcs12KDF({
    required String hash,
    required int id,
    required List<int> password,
    required List<int> salt,
    required int count,
    required int keyLength,
  }) {
    const v = 64;
    final d = Uint8List(v)..fillRange(0, v, id);
    final s = _rellenarHastaMultiplo(salt, v);
    final p = _rellenarHastaMultiplo(password, v);
    final iBytes = Uint8List(s.length + p.length)
      ..setRange(0, s.length, s)
      ..setRange(s.length, s.length + p.length, p);
    final result = <int>[];
    final hashDigest = SHA1Digest();
    while (result.length < keyLength) {
      var ai = Uint8List.fromList([...d, ...iBytes]);
      for (var i = 0; i < count; i++) {
        final h = Uint8List(hashDigest.digestSize);
        hashDigest
          ..reset()
          ..update(ai, 0, ai.length)
          ..doFinal(h, 0);
        ai = h;
      }
      result.addAll(ai);
      final b = _rellenarHastaMultiplo(ai, v);
      for (var j = 0; j < iBytes.length; j += v) {
        var carry = 1;
        for (var k = v - 1; k >= 0; k--) {
          final sum = (iBytes[j + k] & 0xFF) + (b[k] & 0xFF) + carry;
          iBytes[j + k] = sum & 0xFF;
          carry = sum >> 8;
        }
      }
    }
    return Uint8List.fromList(result.take(keyLength).toList());
  }

  static Uint8List _rellenarHastaMultiplo(List<int> data, int blockSize) {
    if (data.isEmpty) return Uint8List(blockSize);
    final blocks = (data.length + blockSize - 1) ~/ blockSize;
    final padded = Uint8List(blocks * blockSize);
    for (var i = 0; i < padded.length; i++) {
      padded[i] = data[i % data.length];
    }
    return padded;
  }

  static List<int> _passwordToBmp(String password) {
    final bytes = <int>[];
    for (final char in password.runes) {
      bytes.add((char >> 8) & 0xFF);
      bytes.add(char & 0xFF);
    }
    bytes.add(0);
    bytes.add(0);
    return bytes;
  }

  static Uint8List _removePkcs7Padding(Uint8List data) {
    if (data.isEmpty) return data;
    final pad = data.last;
    if (pad == 0 || pad > 16 || data.length < pad) return data;
    return data.sublist(0, data.length - pad);
  }

  static void _parseSafeContents(
    Uint8List bytes,
    String password, {
    required void Function(Uint8List) onCertificate,
    required void Function(Uint8List) onPrivateKey,
  }) {
    final ASN1Object? obj;
    try {
      obj = ASN1Parser(bytes).nextObject();
    } catch (_) {
      return;
    }
    if (obj is! ASN1Sequence) return;

    for (final bagElement in obj.elements) {
      if (bagElement is! ASN1Sequence) continue;
      if (bagElement.elements.isEmpty) continue;

      final bagOid =
          (bagElement.elements[0] as ASN1ObjectIdentifier).identifier ?? '';

      // certBag
      if (bagOid == '1.2.840.113549.1.12.10.1.3') {
        try {
          final bagValue = bagElement.elements[1];
          final certBag =
              ASN1Parser(bagValue.valueBytes()).nextObject() as ASN1Sequence;
          if (certBag.elements.isEmpty) continue;
          final certTypeOid =
              (certBag.elements[0] as ASN1ObjectIdentifier).identifier ?? '';
          if (certTypeOid == '1.2.840.113549.1.9.22.1') {
            final certValueObj = certBag.elements[1];
            final certBytes = certValueObj.valueBytes();
            final certOctet = ASN1Parser(certBytes).nextObject();
            if (certOctet is ASN1OctetString) {
              onCertificate(certOctet.octets);
            } else {
              onCertificate(certBytes);
            }
          }
        } catch (_) {
          continue;
        }
      }

      // pkcs8ShroudedKeyBag
      if (bagOid == '1.2.840.113549.1.12.10.1.2') {
        try {
          final keyDer =
              _descifrarShroudedKey(bagElement.elements[1].valueBytes(), password);
          onPrivateKey(keyDer);
        } catch (_) {
          continue;
        }
      }

      // keyBag — PKCS#8 sin cifrar
      if (bagOid == '1.2.840.113549.1.12.10.1.1') {
        try {
          onPrivateKey(bagElement.elements[1].valueBytes());
        } catch (_) {
          continue;
        }
      }
    }
  }

  static Uint8List _descifrarShroudedKey(Uint8List bytes, String password) {
    final encKeyInfo = ASN1Parser(bytes).nextObject() as ASN1Sequence;
    if (encKeyInfo.elements.length < 2) {
      throw FirmaException('EncryptedPrivateKeyInfo malformado',
          codigo: 'P12-KEY1');
    }
    final algoSeq = encKeyInfo.elements[0] as ASN1Sequence;
    final algoOid =
        (algoSeq.elements[0] as ASN1ObjectIdentifier).identifier ?? '';
    final encData = (encKeyInfo.elements[1] as ASN1OctetString).octets;
    final algoParams = algoSeq.elements.length > 1
        ? algoSeq.elements[1] as ASN1Sequence
        : ASN1Sequence();

    return _descifrarPbe(
      encContent: encData,
      algoOid: algoOid,
      algoParams: algoParams,
      password: password,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RSA FIRMA — pointycastle
  // ═══════════════════════════════════════════════════════════════════════

  static Uint8List _firmarRsa({
    required Uint8List datos,
    required Uint8List privateKeyDer,
  }) {
    final privateKey = _parsearClavePrivadaRsa(privateKeyDer);
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(datos);
    return signature.bytes;
  }

  /// Soporta PKCS#8 (estándar) y PKCS#1 (fallback FNMT).
  static RSAPrivateKey _parsearClavePrivadaRsa(Uint8List der) {
    try {
      final seq = ASN1Parser(der).nextObject() as ASN1Sequence;
      if (seq.elements.length >= 3) {
        final first = seq.elements[0];
        if (first is ASN1Integer && first.valueAsBigInteger == BigInt.zero) {
          final pkcs8Octet = seq.elements[2] as ASN1OctetString;
          return _parsearRsaPrivateKey(pkcs8Octet.octets);
        }
      }
      return _parsearRsaPrivateKey(der);
    } catch (e) {
      throw FirmaException('Error al parsear la clave privada RSA: $e',
          codigo: 'P12-005');
    }
  }

  static RSAPrivateKey _parsearRsaPrivateKey(Uint8List der) {
    final rsaSeq = ASN1Parser(der).nextObject() as ASN1Sequence;
    if (rsaSeq.elements.length < 6) {
      throw FirmaException(
          'RSAPrivateKey malformado: se esperan al menos 6 campos',
          codigo: 'P12-006');
    }
    final modulus = (rsaSeq.elements[1] as ASN1Integer).valueAsBigInteger;
    final privateExp = (rsaSeq.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (rsaSeq.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (rsaSeq.elements[5] as ASN1Integer).valueAsBigInteger;
    return RSAPrivateKey(modulus, privateExp, p, q);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CERTIFICADO X.509 — asn1lib
  // ═══════════════════════════════════════════════════════════════════════

  static CertificadoInfo _parseCertificadoInfo(Uint8List der) {
    try {
      final cert = ASN1Parser(der).nextObject() as ASN1Sequence;
      final tbsCert = cert.elements[0] as ASN1Sequence;

      var idx = 0;
      if (tbsCert.elements[0].tag == 0xA0) idx = 1;

      final serial = (tbsCert.elements[idx++] as ASN1Integer).valueAsBigInteger;
      idx++; // signatureAlgorithm
      final issuerSeq = tbsCert.elements[idx++] as ASN1Sequence;
      final validitySeq = tbsCert.elements[idx++] as ASN1Sequence;
      final subjectSeq = tbsCert.elements[idx] as ASN1Sequence;

      final notBefore = _parsearFechaCert(validitySeq.elements[0]);
      final notAfter = _parsearFechaCert(validitySeq.elements[1]);
      final subjectDN = _parsearDN(subjectSeq);
      final nif = _extraerNifDeDN(subjectDN, subjectSeq);

      return CertificadoInfo(
        titular: subjectDN,
        emisor: _parsearDN(issuerSeq),
        validoDesde: notBefore,
        validoHasta: notAfter,
        numeroDeSerie: serial.toRadixString(16).toUpperCase(),
        huellaSha256: sha256.convert(der).toString(),
        nif: nif,
      );
    } catch (e) {
      throw FirmaException('Error al parsear el certificado X.509: $e',
          codigo: 'P12-007');
    }
  }

  static DateTime _parsearFechaCert(ASN1Object timeObj) {
    final valueStr = String.fromCharCodes(timeObj.valueBytes());
    if (timeObj.tag == 0x17) {
      // UTCTime: YYMMDDHHMMSSZ
      final yy = int.parse(valueStr.substring(0, 2));
      final year = yy >= 50 ? 1900 + yy : 2000 + yy;
      return DateTime.utc(
        year,
        int.parse(valueStr.substring(2, 4)),
        int.parse(valueStr.substring(4, 6)),
        int.parse(valueStr.substring(6, 8)),
        int.parse(valueStr.substring(8, 10)),
        int.parse(valueStr.substring(10, 12)),
      );
    }
    // GeneralizedTime: YYYYMMDDHHMMSSZ
    return DateTime.utc(
      int.parse(valueStr.substring(0, 4)),
      int.parse(valueStr.substring(4, 6)),
      int.parse(valueStr.substring(6, 8)),
      int.parse(valueStr.substring(8, 10)),
      int.parse(valueStr.substring(10, 12)),
      int.parse(valueStr.substring(12, 14)),
    );
  }

  static String _parsearDN(ASN1Sequence seq) {
    final parts = <String>[];
    for (final rdn in seq.elements) {
      // Cada RDN es un SET; en algunos parsers puede venir como ASN1Set o ASN1Sequence
      final rdnElems = rdn is ASN1Set
          ? rdn.elements
          : rdn is ASN1Sequence
              ? rdn.elements
              : <ASN1Object>[];
      for (final atv in rdnElems) {
        if (atv is! ASN1Sequence || atv.elements.length < 2) continue;
        final oid = (atv.elements[0] as ASN1ObjectIdentifier).identifier ?? '';
        final value = atv.elements[1];
        final strVal = _extractStringValue(value);
        final label = _oidToLabel(oid);
        if (label != null && strVal.isNotEmpty) parts.add('$label=$strVal');
      }
    }
    return parts.join(', ');
  }

  static String _extractStringValue(ASN1Object value) {
    try {
      if (value is ASN1UTF8String) return value.utf8StringValue;
      return String.fromCharCodes(value.valueBytes());
    } catch (_) {
      return '';
    }
  }

  /// Extrae el NIF del Subject DN (OID 2.5.4.5 — serialNumber).
  /// FNMT personal: "IDCES-XXXXXXXX"  |  FNMT empresa: "VATES-XXXXXXXX"
  static String? _extraerNifDeDN(String dn, ASN1Sequence subjectSeq) {
    for (final rdn in subjectSeq.elements) {
      final rdnElems = rdn is ASN1Set
          ? rdn.elements
          : rdn is ASN1Sequence
              ? rdn.elements
              : <ASN1Object>[];
      for (final atv in rdnElems) {
        if (atv is! ASN1Sequence || atv.elements.length < 2) continue;
        final oid = (atv.elements[0] as ASN1ObjectIdentifier).identifier ?? '';
        if (oid == '2.5.4.5') {
          var val = _extractStringValue(atv.elements[1]).trim().toUpperCase();
          for (final prefix in ['IDCES-', 'VATES-', 'IDCCA-', 'IDESP-']) {
            if (val.startsWith(prefix)) {
              val = val.substring(prefix.length);
              break;
            }
          }
          if (RegExp(r'^[A-Z0-9]{8,9}$').hasMatch(val)) return val;
        }
      }
    }
    // Fallback: buscar patrón NIF/CIF en el CN
    final cnMatch = RegExp(
            r'[A-HJ-NP-TV-Z][0-9]{7}[0-9A-J]|[0-9]{8}[A-Z]',
            caseSensitive: false)
        .firstMatch(dn.toUpperCase());
    return cnMatch?.group(0)?.toUpperCase();
  }

  static String? _oidToLabel(String oid) => const {
        '2.5.4.3': 'CN',
        '2.5.4.5': 'SN',
        '2.5.4.6': 'C',
        '2.5.4.7': 'L',
        '2.5.4.8': 'ST',
        '2.5.4.10': 'O',
        '2.5.4.11': 'OU',
        '1.2.840.113549.1.9.1': 'E',
        '2.5.4.97': 'OID',
      }[oid];

  // ═══════════════════════════════════════════════════════════════════════
  // XADES XML BUILDING
  // ═══════════════════════════════════════════════════════════════════════

  static String _buildSignedInfo({required String digestValue}) {
    return '''<ds:SignedInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
  <ds:CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
  <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
  <ds:Reference URI="">
    <ds:Transforms>
      <ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
      <ds:Transform Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
    </ds:Transforms>
    <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
    <ds:DigestValue>$digestValue</ds:DigestValue>
  </ds:Reference>
</ds:SignedInfo>''';
  }

  static String _buildXadesBlock({
    required String signedInfo,
    required String signatureValueB64,
    required String certDerB64,
    required String certDigestB64,
    required DateTime signingTime,
  }) {
    final ts = signingTime.toUtc().toIso8601String();
    return '''<ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
              xmlns:xades="http://uri.etsi.org/01903/v1.3.2#"
              Id="Firma-Verifactu">
  $signedInfo
  <ds:SignatureValue Id="SignatureValue">$signatureValueB64</ds:SignatureValue>
  <ds:KeyInfo>
    <ds:X509Data>
      <ds:X509Certificate>$certDerB64</ds:X509Certificate>
    </ds:X509Data>
  </ds:KeyInfo>
  <ds:Object>
    <xades:QualifyingProperties xmlns:xades="http://uri.etsi.org/01903/v1.3.2#"
                                Target="#Firma-Verifactu">
      <xades:SignedProperties Id="SignedProperties">
        <xades:SignedSignatureProperties>
          <xades:SigningTime>$ts</xades:SigningTime>
          <xades:SigningCertificateV2>
            <xades:Cert>
              <xades:CertDigest>
                <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                <ds:DigestValue>$certDigestB64</ds:DigestValue>
              </xades:CertDigest>
            </xades:Cert>
          </xades:SigningCertificateV2>
        </xades:SignedSignatureProperties>
      </xades:SignedProperties>
    </xades:QualifyingProperties>
  </ds:Object>
</ds:Signature>''';
  }

  static String _insertarFirmaEnXml(String xml, String firma) {
    final closeTag = RegExp(r'</\w[^>]*>$');
    final match = closeTag.firstMatch(xml.trimRight());
    if (match == null) {
      throw FirmaException(
          'No se encontró elemento raíz de cierre en el XML',
          codigo: 'XADES-010');
    }
    final pos = xml.lastIndexOf(match.group(0)!);
    return '${xml.substring(0, pos)}\n$firma\n${xml.substring(pos)}';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CANONICALIZACIÓN C14N (simplificada)
  // ═══════════════════════════════════════════════════════════════════════

  static String _canonicalizarXml(String xml) {
    return xml
        .replaceFirst(RegExp(r'<\?xml[^?]*\?>\s*'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll("&apos;", "'");
  }

  static String _extraerXmlSinFirma(String xml) {
    return xml.replaceAll(
        RegExp(r'<ds:Signature[^>]*>.*?</ds:Signature>',
            dotAll: true, caseSensitive: false),
        '');
  }

  static String? _extraerDigestValue(String xml) {
    final match =
        RegExp(r'<ds:DigestValue>(.*?)</ds:DigestValue>').firstMatch(xml);
    return match?.group(1)?.trim();
  }

  static String? _extraerCertificadoDeFirma(String xml) {
    final match =
        RegExp(r'<ds:X509Certificate>(.*?)</ds:X509Certificate>', dotAll: true)
            .firstMatch(xml);
    return match?.group(1)?.trim().replaceAll(RegExp(r'\s'), '');
  }
}





