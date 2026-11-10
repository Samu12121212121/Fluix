import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'auth/dos_factores_service.dart';
import 'certificado_firma_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FIRMA ELECTRÓNICA AVANZADA DE DOCUMENTOS — eIDAS art. 26
//
// OTP: Firebase Phone Auth (€0.006/firma) con fallback a hash local.
// Certificado: PDF generado en cliente, guardado en Storage.
//
// Colección: usuarios/{empleadoId}/documentos/{docId}
// Storage:   empleados/{empresaId}/{empleadoId}/firmas_docs/{docId}.png
//            empleados/{empresaId}/{empleadoId}/firmas_docs/{docId}_cert.pdf
// OTPs:      usuarios/{empleadoId}/otps_firma/{docId}  (admin-only en rules)
// ═══════════════════════════════════════════════════════════════════════════════

class DocumentoFirmaService {
  static final DocumentoFirmaService _i = DocumentoFirmaService._();
  factory DocumentoFirmaService() => _i;
  DocumentoFirmaService._();

  final _db      = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _otp2fa  = DosFactoresService();
  final _cert    = CertificadoFirmaService();

  static const int _otpTtlMinutos  = 10;
  static const int _otpMaxIntentos = 3;

  // ── Refs ─────────────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _docRef(String empleadoId, String docId) =>
      _db.collection('usuarios').doc(empleadoId).collection('documentos').doc(docId);

  DocumentReference<Map<String, dynamic>> _otpRef(String empleadoId, String docId) =>
      _db.collection('usuarios').doc(empleadoId).collection('otps_firma').doc(docId);

  // ═══════════════════════════════════════════════════════════════════════════
  // HASH DEL DOCUMENTO — llamar al SUBIR el archivo
  // ═══════════════════════════════════════════════════════════════════════════

  static String hashDocumento(Uint8List bytes) => sha256.convert(bytes).toString();

  // ═══════════════════════════════════════════════════════════════════════════
  // SOLICITAR FIRMA (admin)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> solicitarFirma({
    required String empleadoId,
    required String docId,
    String? mensaje,
    Map<String, dynamic>? zonaFirma,
  }) async {
    await _docRef(empleadoId, docId).update({
      'requiere_firma':   true,
      'estado_firma':     'pendiente',
      'firma_solicitada': FieldValue.serverTimestamp(),
      if (mensaje != null) 'firma_mensaje': mensaje,
      if (zonaFirma != null) 'firma_zona': zonaFirma
      else 'firma_zona': FieldValue.delete(),
    });
    () async {
      try {
        await _db.collection('usuarios').doc(empleadoId).collection('notificaciones').add({
          'titulo':         'Documento para firmar',
          'cuerpo':         'Tienes un documento pendiente de firma en tu portal',
          'tipo':           'firma_documento',
          'entidad_id':     docId,
          'timestamp':      FieldValue.serverTimestamp(),
          'leida':          false,
          'modulo_destino': 'portal_empleado',
        });
      } catch (_) {}
    }();
  }

  Future<void> cancelarSolicitud({
    required String empleadoId,
    required String docId,
  }) async {
    await _docRef(empleadoId, docId).update({
      'requiere_firma':   false,
      'estado_firma':     FieldValue.delete(),
      'firma_solicitada': FieldValue.delete(),
    });
    await _otpRef(empleadoId, docId).delete().catchError((_) {});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OTP — enviar código de verificación
  //
  // Prioridad: Firebase Phone Auth (barato) → hash local (fallback gratuito)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<OtpEnvioResult> enviarOtpFirma({
    required String empleadoId,
    required String docId,
    required String nombreDocumento,
    required String empresaNombre,
    String? empresaId,
  }) async {
    final userDoc  = await _db.collection('usuarios').doc(empleadoId).get();
    final telefono = (userDoc.data()?['telefono'] as String? ?? '').trim();

    // ── Twilio SMS via Cloud Function (fiable en web y móvil) ─────────────────
    if (telefono.isNotEmpty) {
      try {
        final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('enviarOtpSms');
        final result = await fn.call({'empleadoId': empleadoId, 'docId': docId});
        final telParcial = result.data['telefonoParcial'] as String? ?? _telParcial(telefono);
        return OtpEnvioResult(
          enviado:         true,
          telefonoParcial: telParcial,
          tieneTelefono:   true,
          verificationId:  'twilio', // marker para usar verificarOtpSms
        );
      } catch (e) {
        debugPrint('⚠️ Twilio SMS falló, usando fallback hash: $e');
      }
    }

    // ── Fallback: hash local (sin SMS, muestra código en pantalla) ──────────
    final rng    = Random.secure();
    final codigo = (100000 + rng.nextInt(900000)).toString();
    final expira = DateTime.now().add(const Duration(minutes: _otpTtlMinutos));
    final hash   = sha256.convert(utf8.encode('$codigo:$empleadoId:$docId')).toString();

    await _otpRef(empleadoId, docId).set({
      'hash':      hash,
      'expira_en': Timestamp.fromDate(expira),
      'intentos':  0,
      'metodo':    telefono.isNotEmpty ? 'hash_sms' : 'manual',
      'creado_en': FieldValue.serverTimestamp(),
    });

    return OtpEnvioResult(
      enviado:         false,
      telefonoParcial: telefono.isNotEmpty ? _telParcial(telefono) : '(sin teléfono)',
      tieneTelefono:   telefono.isNotEmpty,
      codigoDebug:     codigo,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VERIFICAR OTP
  // ═══════════════════════════════════════════════════════════════════════════

  /// [verificationId] si viene de Firebase Phone Auth; null si viene del fallback hash.
  Future<void> verificarOtp({
    required String empleadoId,
    required String docId,
    required String codigoIngresado,
    String? verificationId,
  }) async {
    // ── Twilio OTP via Cloud Function ──────────────────────────────────────
    if (verificationId == 'twilio') {
      try {
        final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('verificarOtpSms');
        await fn.call({'empleadoId': empleadoId, 'docId': docId, 'codigo': codigoIngresado});
        return; // OK — el hash fue verificado y eliminado en la Cloud Function
      } on FirebaseFunctionsException catch (e) {
        final msg = e.message ?? 'Código incorrecto';
        throw FirmaException(msg);
      }
    }

    // ── Firebase Phone Auth (móvil nativo) ────────────────────────────────
    if (verificationId != null && verificationId != 'twilio') {
      bool ok = false;
      try {
        ok = await _otp2fa.verificarCodigo(
          verificationId: verificationId,
          codigo:         codigoIngresado,
        );
      } on TooManyAttemptsException {
        throw FirmaException('Demasiados intentos incorrectos. Solicita un código nuevo.');
      }
      if (!ok) throw FirmaException('Código incorrecto. Verifica el SMS e inténtalo de nuevo.');

      await _otpRef(empleadoId, docId).set({
        'verificado':    true,
        'verificado_en': FieldValue.serverTimestamp(),
        'metodo':        'firebase_phone',
        'intentos':      0,
        'creado_en':     FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    // ── Fallback: verificación por hash ────────────────────────────────────
    final otpDoc = await _otpRef(empleadoId, docId).get();
    if (!otpDoc.exists) throw FirmaException('Código no encontrado. Solicita uno nuevo.');

    final data     = otpDoc.data()!;
    final expira   = (data['expira_en'] as Timestamp).toDate();
    final intentos = (data['intentos'] as int? ?? 0);

    if (DateTime.now().isAfter(expira)) {
      await _otpRef(empleadoId, docId).delete().catchError((_) {});
      throw FirmaException('El código ha expirado. Solicita uno nuevo.');
    }
    if (intentos >= _otpMaxIntentos) {
      throw FirmaException('Demasiados intentos incorrectos. Solicita un código nuevo.');
    }

    final hashIngresado = sha256
        .convert(utf8.encode('$codigoIngresado:$empleadoId:$docId'))
        .toString();

    if (hashIngresado != data['hash']) {
      await _otpRef(empleadoId, docId).update({'intentos': FieldValue.increment(1)});
      final restantes = _otpMaxIntentos - intentos - 1;
      throw FirmaException(
        'Código incorrecto. ${restantes > 0 ? '$restantes intento${restantes == 1 ? '' : 's'} restante${restantes == 1 ? '' : 's'}.' : 'Sin intentos restantes.'}',
      );
    }

    await _otpRef(empleadoId, docId).update({
      'verificado':    true,
      'verificado_en': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIRMAR DOCUMENTO — OTP ya verificado en este paso
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> firmarDocumento({
    required String empleadoId,
    required String empresaId,
    required String docId,
    required String firmanteUid,
    required String firmanteEmail,
    required Uint8List firmaPng,
  }) async {
    // 1. OTP verificado
    final otpDoc = await _otpRef(empleadoId, docId).get();
    if (!otpDoc.exists || otpDoc.data()?['verificado'] != true) {
      throw FirmaException('Identidad no verificada. Completa el proceso de OTP.');
    }

    // 2. Documento no firmado aún
    final docSnap = await _docRef(empleadoId, docId).get();
    if (!docSnap.exists) throw FirmaException('Documento no encontrado.');
    if (docSnap.data()?['estado_firma'] == 'firmado') {
      throw FirmaException('El documento ya está firmado.');
    }

    final docData          = docSnap.data()!;
    final hashAlmacenado   = docData['hash_documento'] as String?;
    final nombreDocumento  = docData['nombre'] as String? ?? docData['titulo'] as String? ?? 'Documento';
    final categoriaDoc     = docData['categoria'] as String? ?? '';

    // 3. Subir PNG de la firma
    final firmPath = 'empleados/$empresaId/$empleadoId/firmas_docs/$docId.png';
    final firmRef  = _storage.ref().child(firmPath);
    await firmRef.putData(firmaPng, SettableMetadata(contentType: 'image/png'));
    final firmaUrl = await firmRef.getDownloadURL();

    final otpMeta = otpDoc.data()!;
    final ahora   = DateTime.now();

    // 4. Marcar firmado con audit log
    await _docRef(empleadoId, docId).update({
      'estado_firma': 'firmado',
      'firmado':      true,
      'firma_url':    firmaUrl,
      'firma_path':   firmPath,
      'firma_fecha':  FieldValue.serverTimestamp(),
      'firma_uid':    firmanteUid,
      'firma_email':  firmanteEmail,
      'audit_firma': {
        'uid':              firmanteUid,
        'email':            firmanteEmail,
        'otp_metodo':       otpMeta['metodo'] ?? 'manual',
        'otp_verificado_en': otpMeta['verificado_en'],
        'hash_documento':   hashAlmacenado ?? 'no_calculado',
        'hash_verificado':  hashAlmacenado != null,
        'timestamp':        FieldValue.serverTimestamp(),
        'norma_aplicada':   'eIDAS Reglamento (UE) 910/2014 art. 26 — firma electrónica avanzada',
      },
    });

    // 5. Limpiar OTP
    await _otpRef(empleadoId, docId).delete().catchError((_) {});

    // 6. Incrustar firma en el PDF original (solo si es PDF)
    final extension = docData['extension'] as String? ?? '';
    if (extension.toLowerCase() == 'pdf') {
      final storagePath = docData['storage_path'] as String? ?? '';
      final zonaFirma   = docData['firma_zona'] as Map<String, dynamic>?;
      if (storagePath.isNotEmpty) {
        await _incrustarFirmaEnPdf(
          empleadoId:      empleadoId,
          empresaId:       empresaId,
          docId:           docId,
          firmaPng:        firmaPng,
          nombreDocumento: nombreDocumento,
          firmanteEmail:   firmanteEmail,
          fechaFirma:      ahora,
          docStoragePath:  storagePath,
          zonaFirma:       zonaFirma,
        );
      }
    }

    // 7. Generar y guardar certificado PDF (asíncrono, no bloquea al usuario)
    _generarCertificadoEnBackground(
      empleadoId:     empleadoId,
      empresaId:      empresaId,
      docId:          docId,
      nombreDocumento: nombreDocumento,
      categoriaDoc:   categoriaDoc,
      hashDoc:        hashAlmacenado ?? '',
      firmanteUid:    firmanteUid,
      firmanteEmail:  firmanteEmail,
      metodoOtp:      otpMeta['metodo'] as String? ?? 'manual',
      firmaPng:       firmaPng,
      fechaFirma:     ahora,
      empresaId2:     empresaId,
    );

    // 7. Notificar al admin
    () async {
      try {
        await _db.collection('notificaciones').doc(empresaId).collection('items').add({
          'titulo':         'Documento firmado',
          'cuerpo':         'Un empleado ha firmado "$nombreDocumento" correctamente',
          'tipo':           'documento_firmado',
          'entidad_id':     docId,
          'timestamp':      FieldValue.serverTimestamp(),
          'leida':          false,
          'modulo_destino': 'empleados',
        });
      } catch (_) {}
    }();
  }

  // ── Background: genera el PDF certificado sin bloquear la UX ─────────────

  Future<void> _generarCertificadoEnBackground({
    required String empleadoId,
    required String empresaId,
    required String docId,
    required String nombreDocumento,
    required String categoriaDoc,
    required String hashDoc,
    required String firmanteUid,
    required String firmanteEmail,
    required String metodoOtp,
    required Uint8List firmaPng,
    required DateTime fechaFirma,
    required String empresaId2,
  }) async {
    try {
      // Leer datos del firmante
      final userDoc = await _db.collection('usuarios').doc(empleadoId).get();
      final nombre  = userDoc.data()?['nombre'] as String? ?? firmanteEmail;
      final tel     = userDoc.data()?['telefono'] as String? ?? '';

      // Leer nombre de empresa
      final empresaDoc = await _db.collection('empresas').doc(empresaId).get();
      final empresaNombre = empresaDoc.data()?['nombre'] as String? ?? '';

      final metodoTexto = switch (metodoOtp) {
        'firebase_phone' => 'SMS verificado vía Firebase Phone Auth',
        'hash_sms'       => 'SMS verificado por código OTP',
        _                => 'Código de verificación manual',
      };

      final pdfBytes = await _cert.generar(
        nombreDocumento:     nombreDocumento,
        hashDocumento:       hashDoc.isNotEmpty ? hashDoc : '(no calculado)',
        nombreFirmante:      nombre,
        emailFirmante:       firmanteEmail,
        telefonoParcial:     tel.isNotEmpty ? _telParcial(tel) : '(no registrado)',
        uidFirmante:         firmanteUid,
        fechaFirma:          fechaFirma,
        metodoVerificacion:  metodoTexto,
        firmaPng:            firmaPng,
        categoriaDoc:        categoriaDoc,
        empresaNombre:       empresaNombre,
      );

      await _cert.guardarYActualizar(
        empresaId:  empresaId,
        empleadoId: empleadoId,
        docId:      docId,
        pdfBytes:   pdfBytes,
      );
      debugPrint('✅ Certificado de firma generado para doc $docId');
    } catch (e) {
      debugPrint('⚠️ Error generando certificado de firma: $e');
    }
  }

  // ── Consultas ─────────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPendientesFirma(
          String empleadoId) =>
      _db.collection('usuarios').doc(empleadoId).collection('documentos')
          .where('estado_firma', isEqualTo: 'pendiente')
          .snapshots();

  Future<int> contarPendientesFirma(String empleadoId) async {
    final snap = await _db.collection('usuarios').doc(empleadoId)
        .collection('documentos')
        .where('estado_firma', isEqualTo: 'pendiente')
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  // ═══════════════════════════════════════════════════════════════════════════
  // INCRUSTAR FIRMA EN EL PDF ORIGINAL
  //
  // Rasteriza cada página del PDF original con Printing.raster() y añade una
  // página final con la imagen de la firma + datos del firmante.
  // Reemplaza el campo `url` del documento para que el PDF que ve el usuario
  // sea ya la versión firmada.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _incrustarFirmaEnPdf({
    required String empleadoId,
    required String empresaId,
    required String docId,
    required Uint8List firmaPng,
    required String nombreDocumento,
    required String firmanteEmail,
    required DateTime fechaFirma,
    required String docStoragePath,
    Map<String, dynamic>? zonaFirma,
  }) async {
    try {
      // 1. Descargar PDF original desde Storage (máx 20 MB)
      final pdfBytes = await _storage.ref().child(docStoragePath)
          .getData(20 * 1024 * 1024);
      if (pdfBytes == null || pdfBytes.isEmpty) {
        debugPrint('⚠️ _incrustarFirmaEnPdf: no se pudo descargar el PDF');
        return;
      }

      // 2. Nombre del firmante desde Firestore
      String nombreFirmante = firmanteEmail;
      try {
        final u = await _db.collection('usuarios').doc(empleadoId).get();
        nombreFirmante = u.data()?['nombre'] as String? ?? firmanteEmail;
      } catch (_) {}

      // 3. Leer zona de firma desde Firestore (si no se pasó explícitamente)
      final Map<String, dynamic> zona = zonaFirma ??
          ((await _docRef(empleadoId, docId).get())
              .data()?['firma_zona'] as Map<String, dynamic>? ?? {});
      final bool tieneZona = zona.isNotEmpty &&
          zona['pagina'] != null &&
          zona['left_pct'] != null &&
          zona['top_pct'] != null;

      // 4. Rasterizar páginas a 150 DPI
      final paginasPng  = <Uint8List>[];
      final paginasSz   = <(int w, int h)>[];
      await for (final raster in Printing.raster(pdfBytes, dpi: 150)) {
        paginasPng.add(await raster.toPng());
        paginasSz.add((raster.width, raster.height));
      }

      if (paginasPng.isEmpty) {
        debugPrint('⚠️ _incrustarFirmaEnPdf: no se pudieron rasterizar páginas');
        return;
      }

      // 5. Construir nuevo PDF
      final (bold, regular) = await (
        PdfGoogleFonts.interBold(),
        PdfGoogleFonts.interRegular(),
      ).wait;

      final doc = pw.Document();
      final fmt = DateFormat("dd/MM/yyyy HH:mm", 'es_ES');
      final fechaStr = fmt.format(fechaFirma.toLocal());
      final firmaImg = pw.MemoryImage(firmaPng);

      // Páginas originales con firma superpuesta si hay zona
      for (int i = 0; i < paginasPng.length; i++) {
        final (w, h) = paginasSz[i];
        final pw_w = w * 72.0 / 150.0;
        final pw_h = h * 72.0 / 150.0;
        final img = pw.MemoryImage(paginasPng[i]);

        final esLaPaginaConFirma = tieneZona && (zona['pagina'] as int) == i;

        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat(pw_w, pw_h),
          margin: pw.EdgeInsets.zero,
          build: (ctx) {
            if (!esLaPaginaConFirma) {
              return pw.Image(img, fit: pw.BoxFit.fill);
            }
            // Superponer la firma en la zona indicada
            final leftPct  = (zona['left_pct']  as num).toDouble();
            final topPct   = (zona['top_pct']   as num).toDouble();
            const firmaW = 160.0;
            const firmaH =  60.0;
            return pw.Stack(children: [
              pw.Positioned.fill(child: pw.Image(img, fit: pw.BoxFit.fill)),
              pw.Positioned(
                left: leftPct * pw_w - firmaW / 2,
                top:  topPct  * pw_h - firmaH / 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: firmaW, height: firmaH,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: const PdfColor.fromInt(0xFF1D4ED8), width: 0.6),
                        color: const PdfColor.fromInt(0xFFF8FAFC),
                      ),
                      child: pw.Image(firmaImg, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('$nombreFirmante · $fechaStr',
                        style: pw.TextStyle(font: regular, fontSize: 6,
                            color: const PdfColor.fromInt(0xFF6B7280))),
                  ],
                ),
              ),
            ]);
          },
        ));
      }

      // Si no hay zona, añadir página de firma al final
      if (!tieneZona) {
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(50),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1D4ED8)),
                child: pw.Text('FIRMA ELECTRÓNICA AVANZADA — eIDAS art. 26',
                    style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 20),
              pw.Text(nombreDocumento, style: pw.TextStyle(font: bold, fontSize: 13)),
              pw.SizedBox(height: 10),
              pw.Text('Firmado por: $nombreFirmante  ·  $firmanteEmail',
                  style: pw.TextStyle(font: regular, fontSize: 9,
                      color: const PdfColor.fromInt(0xFF374151))),
              pw.Text('Fecha y hora: $fechaStr',
                  style: pw.TextStyle(font: regular, fontSize: 9,
                      color: const PdfColor.fromInt(0xFF374151))),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Firma del empleado:',
                        style: pw.TextStyle(font: bold, fontSize: 9,
                            color: const PdfColor.fromInt(0xFF1D4ED8))),
                    pw.SizedBox(height: 10),
                    pw.Center(child: pw.Container(
                      width: 240, height: 100,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: const PdfColor.fromInt(0xFFD1D5DB)),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Image(firmaImg, fit: pw.BoxFit.contain),
                    )),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 8),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB))),
                ),
                child: pw.Text(
                  'Firmado electrónicamente conforme al Reglamento (UE) 910/2014 (eIDAS) art. 26 '
                  'y Ley 6/2020. Documento generado por Fluix · fluix.es',
                  style: pw.TextStyle(font: regular, fontSize: 7,
                      color: const PdfColor.fromInt(0xFF9CA3AF)),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ));
      }

      final signedBytes = await doc.save();

      // 5. Guardar PDF firmado en Storage
      final signedPath =
          'empleados/$empresaId/$empleadoId/firmas_docs/${docId}_firmado.pdf';
      final ref = _storage.ref().child(signedPath);
      await ref.putData(signedBytes,
          SettableMetadata(contentType: 'application/pdf'));
      final signedUrl = await ref.getDownloadURL();

      // 6. Actualizar `url` del documento al PDF con firma incrustada
      await _docRef(empleadoId, docId).update({
        'url':              signedUrl,
        'storage_path':     signedPath,
        'url_original':     await _storage.ref().child(docStoragePath)
            .getDownloadURL().catchError((_) => ''),
      });

      debugPrint('✅ Firma incrustada en PDF para doc $docId');
    } catch (e) {
      debugPrint('⚠️ _incrustarFirmaEnPdf error: $e');
    }
  }

  String _telParcial(String t) =>
      t.length >= 4 ? '****${t.substring(t.length - 4)}' : '****';

  String _normalizarTelefono(String t) {
    var n = t.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (n.startsWith('00')) n = '+${n.substring(2)}';
    if (!n.startsWith('+')) {
      if (RegExp(r'^[679]').hasMatch(n)) n = '+34$n';
      else n = '+$n';
    }
    return n;
  }
}

// ── Tipos ─────────────────────────────────────────────────────────────────────

class OtpEnvioResult {
  final bool    enviado;
  final String  telefonoParcial;
  final bool    tieneTelefono;
  final String? codigoDebug;    // visible en pantalla solo cuando no hay SMS
  final String? verificationId; // non-null cuando se usa Firebase Phone Auth

  const OtpEnvioResult({
    required this.enviado,
    required this.telefonoParcial,
    required this.tieneTelefono,
    this.codigoDebug,
    this.verificationId,
  });
}

class FirmaException implements Exception {
  final String message;
  FirmaException(this.message);
  @override
  String toString() => message;
}
