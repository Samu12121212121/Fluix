import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CERTIFICADO DE FIRMA ELECTRÓNICA AVANZADA (eIDAS art. 26)
//
// Genera un PDF de evidencia que complementa al documento firmado.
// Storage: empleados/{empresaId}/{empleadoId}/firmas_docs/{docId}_cert.pdf
// ═══════════════════════════════════════════════════════════════════════════════

class CertificadoFirmaService {
  static final CertificadoFirmaService _i = CertificadoFirmaService._();
  factory CertificadoFirmaService() => _i;
  CertificadoFirmaService._();

  final _storage = FirebaseStorage.instance;
  final _db      = FirebaseFirestore.instance;

  static const _kAzul   = PdfColor.fromInt(0xFF1D4ED8);
  static const _kGris   = PdfColor.fromInt(0xFF6B7280);
  static const _kBorde  = PdfColor.fromInt(0xFFE5E7EB);
  static const _kVerde  = PdfColor.fromInt(0xFF059669);
  static const _kFondo  = PdfColor.fromInt(0xFFF8FAFC);

  // ── Generar bytes del PDF certificado ───────────────────────────────────────

  Future<Uint8List> generar({
    required String nombreDocumento,
    required String hashDocumento,
    required String nombreFirmante,
    required String emailFirmante,
    required String telefonoParcial,
    required String uidFirmante,
    required DateTime fechaFirma,
    required String metodoVerificacion,
    required Uint8List firmaPng,
    String categoriaDoc = '',
    String empresaNombre = '',
  }) async {
    final (regular, bold) = await (
      PdfGoogleFonts.interRegular(),
      PdfGoogleFonts.interBold(),
    ).wait;

    final italic = await PdfGoogleFonts.interRegular();

    final doc  = pw.Document();
    final logo = pw.MemoryImage(firmaPng);
    final fmt  = DateFormat("dd/MM/yyyy 'a las' HH:mm:ss 'UTC'", 'es_ES');
    final fechaStr = fmt.format(fechaFirma.toLocal());

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(bold, empresaNombre),
          pw.SizedBox(height: 20),
          _buildSeccion('DOCUMENTO', bold, [
            _fila('Nombre',    nombreDocumento,  regular),
            if (categoriaDoc.isNotEmpty)
            _fila('Categoría', categoriaDoc,     regular),
            _fila('Hash SHA-256', _truncarHash(hashDocumento), regular, mono: true),
          ]),
          pw.SizedBox(height: 12),
          _buildSeccion('FIRMANTE', bold, [
            _fila('Nombre',   nombreFirmante,    regular),
            _fila('Email',    emailFirmante,     regular),
            _fila('Teléfono', telefonoParcial,   regular),
            _fila('UID',      uidFirmante,       regular, mono: true),
          ]),
          pw.SizedBox(height: 12),
          _buildSeccionFirma(logo, bold, regular),
          pw.SizedBox(height: 12),
          _buildSeccion('VERIFICACIÓN', bold, [
            _fila('Fecha y hora',  fechaStr,              regular),
            _fila('Método',        metodoVerificacion,    regular),
            _fila('Estado',        'VERIFICADO ✓',        bold, verde: true),
          ]),
          pw.Spacer(),
          _buildFooter(italic),
        ],
      ),
    ));

    return doc.save();
  }

  // ── Guardar en Storage y actualizar Firestore ────────────────────────────────

  Future<String> guardarYActualizar({
    required String empresaId,
    required String empleadoId,
    required String docId,
    required Uint8List pdfBytes,
  }) async {
    final path = 'empleados/$empresaId/$empleadoId/firmas_docs/${docId}_cert.pdf';
    final ref  = _storage.ref().child(path);

    await ref.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
    final url = await ref.getDownloadURL();

    await _db
        .collection('usuarios').doc(empleadoId)
        .collection('documentos').doc(docId)
        .update({'certificado_url': url, 'certificado_path': path});

    return url;
  }

  // ── Widgets internos ─────────────────────────────────────────────────────────

  pw.Widget _buildHeader(pw.Font bold, String empresa) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: const pw.BoxDecoration(color: _kAzul),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('CERTIFICADO DE FIRMA ELECTRÓNICA AVANZADA',
              style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text('Reglamento (UE) 910/2014 — eIDAS art. 26 · Ley 6/2020',
              style: pw.TextStyle(fontSize: 8, color: const PdfColor(1, 1, 1, 0.7))),
        ]),
        if (empresa.isNotEmpty)
          pw.Text(empresa,
              style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white)),
      ],
    ),
  );

  pw.Widget _buildSeccion(String titulo, pw.Font bold, List<pw.Widget> filas) =>
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _kBorde),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const pw.BoxDecoration(
                color: _kFondo,
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(6),
                  topRight: pw.Radius.circular(6),
                ),
              ),
              child: pw.Text(titulo,
                  style: pw.TextStyle(font: bold, fontSize: 9, color: _kAzul)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(children: filas),
            ),
          ],
        ),
      );

  pw.Widget _buildSeccionFirma(pw.MemoryImage img, pw.Font bold, pw.Font regular) =>
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _kBorde),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const pw.BoxDecoration(
                color: _kFondo,
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(6),
                  topRight: pw.Radius.circular(6),
                ),
              ),
              child: pw.Text('FIRMA',
                  style: pw.TextStyle(font: bold, fontSize: 9, color: _kAzul)),
            ),
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Container(
                  width: 200, height: 80,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _kBorde),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Image(img, fit: pw.BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      );

  pw.Widget _buildFooter(pw.Font font) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _kBorde)),
    ),
    child: pw.Text(
      'Este certificado acredita la firma electrónica avanzada conforme al Reglamento (UE) 910/2014 '
      '(eIDAS) art. 26 y la Ley 6/2020 de medidas urgentes de impulso de la Administración Electrónica. '
      'Documento vinculante para contratos laborales (Estatuto de los Trabajadores art. 8.4). '
      'Generado por Fluix · fluix.es',
      style: pw.TextStyle(font: font, fontSize: 7, color: _kGris),
      textAlign: pw.TextAlign.center,
    ),
  );

  pw.Widget _fila(String label, String valor, pw.Font regular, {
    bool mono  = false,
    bool verde = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text('$label:',
                  style: pw.TextStyle(fontSize: 8.5, color: _kGris)),
            ),
            pw.Expanded(
              child: pw.Text(
                valor,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  color: verde ? _kVerde : PdfColors.black,
                  fontStyle: mono ? pw.FontStyle.normal : pw.FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      );

  String _truncarHash(String hash) =>
      hash.length > 32 ? '${hash.substring(0, 16)}…${hash.substring(hash.length - 16)}' : hash;
}
