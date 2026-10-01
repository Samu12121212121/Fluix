import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/modelos/factura.dart';
import '../domain/modelos/contabilidad.dart';
import '../domain/modelos/pdf_template.dart';
import 'verifactu_service.dart';
import 'verifactu/qr_service.dart';
// Servicio de la feature de plantillas (usa la misma colección que la UI)
import '../features/pdf_templates/data/pdf_template_service.dart' as uiTplSvc;
import '../features/pdf_templates/domain/models/pdf_template.dart' as uiTpl;

// ── Caché de fuentes: se descargan una sola vez y se reutilizan ─────────────
class _FC {
  static pw.Font? _nR, _nB, _nI, _iR, _iB;

  static Future<(pw.Font, pw.Font)> get nB async {
    _nR ??= await PdfGoogleFonts.nunitoRegular();
    _nB ??= await PdfGoogleFonts.nunitoBold();
    return (_nR!, _nB!);
  }

  static Future<(pw.Font, pw.Font, pw.Font)> get nBI async {
    _nR ??= await PdfGoogleFonts.nunitoRegular();
    _nB ??= await PdfGoogleFonts.nunitoBold();
    _nI ??= await PdfGoogleFonts.nunitoItalic();
    return (_nR!, _nB!, _nI!);
  }

  static Future<(pw.Font, pw.Font)> get iB async {
    _iR ??= await PdfGoogleFonts.interRegular();
    _iB ??= await PdfGoogleFonts.interBold();
    return (_iR!, _iB!);
  }
}

class PdfService {
  static final _db = FirebaseFirestore.instance;

  // ── AUDIT TRAIL DE PLANTILLA (R8) ────────────────────────────────────────
  // Guarda qué plantilla generó el PDF, cuándo y en qué versión.
  // Imprescindible para reproducibilidad legal en auditorías Verifactu.
  static void _registrarPlantillaUsada(
    String empresaId,
    String facturaId,
    String plantillaId,
    String plantillaNombre,
  ) {
    if (empresaId.isEmpty || facturaId.isEmpty || plantillaId.isEmpty) return;
    _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas')
        .doc(facturaId)
        .update({
      'pdf_plantilla_id': plantillaId,
      'pdf_plantilla_nombre': plantillaNombre,
      'pdf_generado_at': FieldValue.serverTimestamp(),
    }).catchError((Object e) {
      debugPrint('⚠️ [PDF-R8] Error registrando plantilla en factura: $e');
    });
  }

  // ── LOG DE FALLBACKS — visible en Crashlytics (móvil release) ────────────
  static void _logFallback(String key, String reason, [StackTrace? stack]) {
    if (!kIsWeb && !kDebugMode) {
      FirebaseCrashlytics.instance.recordError(
        Exception('PDF fallback: $key — $reason'),
        stack,
        reason: key,
        fatal: false,
      );
    }
    debugPrint('📊 [PDF-FALLBACK] $key: $reason');
  }

  // ── GENERAR Y COMPARTIR PDF ──────────────────────────────────────────────

  static Future<void> generarYCompartirFacturaPdf(
    BuildContext context,
    Factura factura,
    String empresaId,
  ) async {
    try {
      final bytes = await generarFacturaPdfConDatos(factura, empresaId);
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('📄 PDF Generado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Descargar PDF',
                    onPressed: () => Printing.sharePdf(
                      bytes: bytes,
                      filename: '${factura.numeroFactura}.pdf',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Compartir PDF',
                    onPressed: () => Printing.sharePdf(
                      bytes: bytes,
                      filename: '${factura.numeroFactura}.pdf',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.print),
                    tooltip: 'Imprimir',
                    onPressed: () => Printing.layoutPdf(
                      onLayout: (_) async => bytes,
                      name: '${factura.numeroFactura}.pdf',
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      final msg = e is TimeoutException
          ? '⏱ Tiempo agotado generando el PDF. Inténtalo de nuevo.'
          : '❌ Error generando PDF: $e';

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ── CARGAR DATOS EMPRESA ─────────────────────────────────────────────────

  /// Devuelve el mejor campo de nombre disponible, excluyendo campos que
  /// habitualmente contienen el tipo de negocio en lugar del nombre real.
  static String? _resolverNombreEmpresa(Map<String, dynamic> data) {
    final perfil = data['perfil'] as Map<String, dynamic>? ?? {};
    final candidatos = [
      perfil['nombre_empresa'],
      perfil['nombre'],
      data['nombre'],
    ];
    final tipoNegocio = (data['tipo_negocio'] as String? ?? '').toLowerCase();
    for (final c in candidatos) {
      if (c == null) continue;
      final s = c.toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != tipoNegocio) return s;
    }
    // Último recurso: cualquier cosa no vacía
    return candidatos.whereType<String>().firstWhere(
      (s) => s.trim().isNotEmpty, orElse: () => '');
  }

  static Future<Map<String, String>> _cargarDatosEmpresa(String empresaId) async {
    try {
      // Cargar documento raíz y config de facturación en paralelo
      final futures = await Future.wait([
        _db.collection('empresas').doc(empresaId).get(),
        // Config TPV de facturación (puede tener nombre_empresa sobreescrito)
        _db.collection('empresas').doc(empresaId)
            .collection('configuracion').doc('facturacionTpv').get(),
      ]);

      final raiz = futures[0] as DocumentSnapshot<Map<String, dynamic>>;
      final configFact = futures[1] as DocumentSnapshot<Map<String, dynamic>>;

      if (!raiz.exists) return {};

      final data = raiz.data() ?? {};
      final perfil = data['perfil'] as Map<String, dynamic>? ?? {};
      final cfg = configFact.data() ?? {};

      // Prioridad: perfil (doc raíz) primero, TPV config como fallback fiscal
      final nombreEmpresa = (
        data['nombre_empresa'] ??          // guardado desde "Mi empresa" en perfil
        data['razon_social'] ??            // razón social en raíz
        data['nombre_fiscal'] ??           // nombre fiscal
        data['nombre_negocio'] ??          // nombre negocio
        perfil['nombre_empresa'] ??        // nombre empresa en perfil anidado
        cfg['nombre_empresa'] ??           // ajustes de facturación TPV
        cfg['razon_social'] ??             // razón social en config TPV
        _resolverNombreEmpresa(data)       // último recurso: data['nombre']
      )?.toString() ?? '';

      debugPrint('📄 [PDF] Empresa: $empresaId → nombre="$nombreEmpresa"');

      return {
        'nombre': nombreEmpresa.isEmpty ? 'Mi Empresa' : nombreEmpresa,
        'cif': (data['nif'] ?? data['cif'] ?? cfg['nif'] ?? cfg['cif'] ?? '').toString(),
        'direccion': (data['direccion'] ?? data['domicilio_fiscal'] ?? perfil['direccion'] ?? cfg['domicilio_fiscal'] ?? '').toString(),
        'telefono': (data['telefono'] ?? perfil['telefono'] ?? cfg['telefono'] ?? '').toString(),
        'correo': (data['correo'] ?? data['email_contacto'] ?? perfil['correo'] ?? cfg['correo'] ?? '').toString(),
        'iban': (data['iban_empresa'] ?? cfg['iban'] ?? '').toString(),
        'logo_url': (data['logo_url'] ?? perfil['logo_url'] ?? '').toString(),
      };
    } catch (e) {
      debugPrint('❌ Error cargando datos empresa: $e');
      return {};
    }
  }

  // ── DESCARGAR LOGO ────────────────────────────────────────────────────────

  static Future<Uint8List?> _descargarLogo(String? logoUrl) async {
    if (logoUrl == null || logoUrl.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse(logoUrl))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }

  // ── GENERAR PDF BYTES ─────────────────────────────────────────────────────

  static Future<Uint8List> _generarPdfBytes({
    required Factura factura,
    required String nombreEmpresa,
    String? cifEmpresa,
    String? direccionEmpresa,
    String? telefonoEmpresa,
    String? correoEmpresa,
    String? ibanEmpresa,
    Uint8List? logoBytes,
    Uint8List? qrVerifactuBytes,
    bool esVerifactu = false,
    String? colorPrimarioTemplate,
    String? colorSecundarioTemplate,
    double margenHorizontal = 36,
    double margenVertical = 36,
  }) async {
    // Usar colores de la plantilla si están disponibles
    final colorCabecera = factura.esRectificativa
        ? PdfColor.fromHex('#D32F2F')
        : (colorPrimarioTemplate != null ? PdfColor.fromHex(colorPrimarioTemplate) : PdfColor.fromHex('#1565C0'));
    final colorAzul    = colorPrimarioTemplate != null ? PdfColor.fromHex(colorPrimarioTemplate) : PdfColor.fromHex('#1565C0');
    final colorAzulOsc = colorSecundarioTemplate != null ? PdfColor.fromHex(colorSecundarioTemplate) : PdfColor.fromHex('#0D47A1');
    final colorGris    = PdfColor.fromHex('#757575');
    final colorLinea   = PdfColor.fromHex('#E0E0E0');
    final colorFondoBg = PdfColor.fromHex('#F5F9FF');
    final colorAccent  = PdfColor.fromHex('#00ACC1');
    final colorRojo    = PdfColor.fromHex('#D32F2F');

    // ── Pre-calcular desglose de IVA por tipo impositivo ─────────────────
    final Map<double, double> _basesPorIva = {};
    final Map<double, double> _cuotasPorIva = {};
    final double _factor = factura.descuentoGlobal > 0
        ? (1.0 - factura.descuentoGlobal / 100.0)
        : 1.0;
    for (final l in factura.lineas) {
      final pct = l.porcentajeIva;
      _basesPorIva[pct] = (_basesPorIva[pct] ?? 0) + l.subtotalSinIva * _factor;
      _cuotasPorIva[pct] = (_cuotasPorIva[pct] ?? 0) + l.importeIva * _factor;
    }
    final sortedRates = _basesPorIva.keys.toList()..sort();
    final double _baseImponibleTotal =
        factura.subtotal - factura.importeDescuentoGlobal;

    // ── Detectar si alguna línea tiene descuento o recargo ────────────────
    final bool _hayDescuentoLinea = factura.lineas.any((l) => l.descuento > 0);

    // ── Fuente con soporte € (Latin Extended) ────────────────────────────────
    final (fontRegular, fontBold, fontItalic) = await _FC.nBI;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
        boldItalic: fontItalic,
      ),
    );

    // ── Sello diagonal "PAGADA" — solo cuando estado == pagada ──────────────
    final bool _mostrarSelloPagada = factura.estado == EstadoFactura.pagada;

    pw.Widget _buildSelloPagada() => pw.Transform.rotate(
      angle: -0.52, // ~-30 grados en radianes
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#2E7D32'), width: 3),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          'PAGADA',
          style: pw.TextStyle(
            color: PdfColor.fromHex('#2E7D32'),
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: margenHorizontal, vertical: margenVertical),
          // Sello PAGADA solapado sobre página 1 sin desplazar el contenido
          buildForeground: _mostrarSelloPagada
              ? (ctx) => ctx.pageNumber == 1
                  ? pw.Center(child: _buildSelloPagada())
                  : pw.SizedBox()
              : null,
        ),
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        build: (ctx) => [
          // ── CABECERA ─────────────────────────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: colorCabecera,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Columna izquierda: logo + datos emisor
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoBytes != null) ...[
                        pw.Container(
                          width: 58,
                          height: 58,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Image(pw.MemoryImage(logoBytes),
                                fit: pw.BoxFit.contain),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              nombreEmpresa,
                              style: pw.TextStyle(
                                  fontSize: 16,
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold),
                            ),
                            if (cifEmpresa != null && cifEmpresa.isNotEmpty) ...[
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'NIF/CIF: $cifEmpresa',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColor.fromHex('#E0E0E0')),
                              ),
                            ],
                            if (direccionEmpresa != null &&
                                direccionEmpresa.isNotEmpty) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                direccionEmpresa,
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColor.fromHex('#E0E0E0')),
                              ),
                            ],
                            if (telefonoEmpresa != null &&
                                telefonoEmpresa.isNotEmpty)
                              pw.Text(
                                'Tel: $telefonoEmpresa',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColor.fromHex('#BDBDBD')),
                              ),
                            if (correoEmpresa != null && correoEmpresa.isNotEmpty)
                              pw.Text(
                                correoEmpresa,
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColor.fromHex('#BDBDBD')),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                // Columna derecha: datos factura
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      factura.numeroFactura,
                      style: pw.TextStyle(
                          fontSize: 14,
                          color: colorAccent,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Emisión: ${_fmtDate(factura.fechaEmision)}',
                      style: pw.TextStyle(
                          fontSize: 9, color: PdfColor.fromHex('#E0E0E0')),
                    ),
                    // Fecha de operación solo si difiere de la emisión
                    if (factura.fechaOperacion != null &&
                        _fmtDate(factura.fechaOperacion!) !=
                            _fmtDate(factura.fechaEmision))
                      pw.Text(
                        'Operación: ${_fmtDate(factura.fechaOperacion!)}',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColor.fromHex('#E0E0E0'),
                            fontStyle: pw.FontStyle.italic),
                      ),
                    if (factura.fechaVencimiento != null)
                      pw.Text(
                        'Vencimiento: ${_fmtDate(factura.fechaVencimiento!)}',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColor.fromHex('#E0E0E0')),
                      ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: _estadoColor(factura.estado),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        _lblEstado(factura.estado),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── BLOQUE RECTIFICATIVA ──────────────────────────────────────
          if (factura.esRectificativa && factura.facturaOriginalNumero != null) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFF3E0'),
                border: pw.Border.all(color: colorRojo, width: 1.5),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RECTIFICA A LA FACTURA',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: colorRojo,
                        letterSpacing: 1),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Nº ${factura.facturaOriginalNumero}'
                    '${factura.facturaOriginalFecha != null ? "  de fecha  ${_fmtDate(factura.facturaOriginalFecha!)}" : ""}',
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black),
                  ),
                  pw.SizedBox(height: 6),
                  if (factura.motivoRectificacion != null)
                    pw.Text(
                      'Motivo: ${factura.motivoRectificacion!.etiqueta}',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.black),
                    ),
                  if (factura.motivoRectificacionTexto != null &&
                      factura.motivoRectificacionTexto!.isNotEmpty)
                    pw.Text(
                      factura.motivoRectificacionTexto!,
                      style: pw.TextStyle(fontSize: 9, color: colorGris),
                    ),
                  if (factura.metodoRectificacion != null)
                    pw.Text(
                      'Método: ${factura.metodoRectificacion!.etiqueta}',
                      style: pw.TextStyle(fontSize: 9, color: colorGris),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── DATOS DEL DESTINATARIO ────────────────────────────────────
          pw.Text(
            'FACTURAR A:',
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: colorAzul,
                letterSpacing: 1.2),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: colorFondoBg,
              border: pw.Border.all(color: colorLinea),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  factura.clienteNombre,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                // Razón social si es distinta del nombre
                if (factura.datosFiscales?.razonSocial != null &&
                    factura.datosFiscales!.razonSocial!.trim().isNotEmpty &&
                    factura.datosFiscales!.razonSocial!.trim() !=
                        factura.clienteNombre.trim())
                  pw.Text(
                    factura.datosFiscales!.razonSocial!,
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: colorGris,
                        fontWeight: pw.FontWeight.bold),
                  ),
                if (factura.datosFiscales?.nif != null)
                  pw.Text(
                    'NIF/CIF: ${factura.datosFiscales!.nif}',
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: colorGris,
                        fontWeight: pw.FontWeight.bold),
                  ),
                if (factura.datosFiscales?.direccion != null)
                  pw.Text(
                    factura.datosFiscales!.direccion!,
                    style: pw.TextStyle(fontSize: 10, color: colorGris),
                  ),
                if (factura.clienteCorreo != null)
                  pw.Text(
                    factura.clienteCorreo!,
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: colorGris,
                        letterSpacing: 0.3),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── CABECERA DE TABLA ─────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              color: colorAzulOsc,
              borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(8),
                  topRight: pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(
                    'DESCRIPCIÓN',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ),
                pw.SizedBox(
                  width: 36,
                  child: pw.Text(
                    'CANT',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(
                  width: 60,
                  child: pw.Text(
                    'P.UNIT',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                if (_hayDescuentoLinea)
                  pw.SizedBox(
                    width: 32,
                    child: pw.Text(
                      'DTO',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                pw.SizedBox(
                  width: 30,
                  child: pw.Text(
                    'IVA',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(
                  width: 65,
                  child: pw.Text(
                    'BASE IMP.',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // ── FILAS DE LÍNEAS ───────────────────────────────────────────
          ...factura.lineas.asMap().entries.map((e) {
            final l = e.value;
            final bg = e.key.isEven
                ? PdfColors.white
                : PdfColor.fromHex('#FAFBFC');
            return pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: pw.BoxDecoration(
                color: bg,
                border: pw.Border(
                    bottom: pw.BorderSide(color: colorLinea, width: 0.5)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      l.descripcion,
                      style:
                          pw.TextStyle(fontSize: 10, color: PdfColors.black),
                    ),
                  ),
                  pw.SizedBox(
                    width: 36,
                    child: pw.Text(
                      '${l.cantidad}',
                      style: pw.TextStyle(
                          fontSize: 10, color: PdfColors.black),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(
                    width: 60,
                    child: pw.Text(
                      '${l.precioUnitario.toStringAsFixed(2)} €',
                      style: pw.TextStyle(
                          fontSize: 10, color: PdfColors.black),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  if (_hayDescuentoLinea)
                    pw.SizedBox(
                      width: 32,
                      child: pw.Text(
                        l.descuento > 0
                            ? '${l.descuento.toStringAsFixed(0)}%'
                            : '—',
                        style:
                            pw.TextStyle(fontSize: 9, color: colorGris),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  pw.SizedBox(
                    width: 30,
                    child: pw.Text(
                      '${l.porcentajeIva.toStringAsFixed(0)}%',
                      style: pw.TextStyle(fontSize: 10, color: colorGris),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(
                    width: 65,
                    child: pw.Text(
                      '${l.subtotalSinIva.toStringAsFixed(2)} €',
                      style: pw.TextStyle(
                          fontSize: 10, color: PdfColors.black),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),

          pw.Divider(color: colorLinea),
          pw.SizedBox(height: 10),

          // ── TOTALES ───────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  // Base imponible
                  _rowTotal(
                    'Base imponible',
                    '${_baseImponibleTotal.toStringAsFixed(2)} €',
                    colorGris,
                    fontSize: 11,
                  ),
                  if (factura.descuentoGlobal > 0)
                    _rowTotal(
                      'Descuento (${factura.descuentoGlobal.toStringAsFixed(0)}%)',
                      '-${factura.importeDescuentoGlobal.toStringAsFixed(2)} €',
                      PdfColor.fromHex('#E65100'),
                      fontSize: 11,
                    ),
                  // Desglose IVA por tipo
                  if (sortedRates.length <= 1)
                    _rowTotal(
                      'IVA ${sortedRates.isNotEmpty ? sortedRates.first.toStringAsFixed(0) : '0'}%',
                      '${factura.totalIva.toStringAsFixed(2)} €',
                      colorGris,
                      fontSize: 11,
                    )
                  else
                    ...sortedRates.map((rate) => _rowTotal(
                          'IVA ${rate.toStringAsFixed(0)}%',
                          '${(_cuotasPorIva[rate] ?? 0).toStringAsFixed(2)} €',
                          colorGris,
                          fontSize: 11,
                        )),
                  if (factura.totalRecargoEquivalencia > 0)
                    _rowTotal(
                      'Recargo equiv.',
                      '${factura.totalRecargoEquivalencia.toStringAsFixed(2)} €',
                      colorGris,
                      fontSize: 11,
                    ),
                  if (factura.porcentajeIrpf > 0)
                    _rowTotal(
                      'IRPF ${factura.porcentajeIrpf.toStringAsFixed(0)}%',
                      '-${factura.retencionIrpf.toStringAsFixed(2)} €',
                      colorGris,
                      fontSize: 11,
                    ),
                  pw.Divider(color: colorLinea),
                  _rowTotal(
                    'TOTAL',
                    '${factura.total.toStringAsFixed(2)} €',
                    colorAzul,
                    bold: true,
                    fontSize: 14,
                  ),
                ],
              ),
            ),
          ),

          // ── FORMA DE PAGO ─────────────────────────────────────────────
          if (factura.metodoPago != null) ...[
            pw.SizedBox(height: 16),
            pw.Divider(color: colorLinea),
            pw.SizedBox(height: 8),
            pw.Text(
              'FORMA DE PAGO',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: colorAzul,
                  letterSpacing: 1),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: colorFondoBg,
                border: pw.Border.all(color: colorLinea),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Método: ${_lblPago(factura.metodoPago)}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  if (factura.metodoPago == MetodoPagoFactura.transferencia &&
                      ibanEmpresa != null &&
                      ibanEmpresa.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'IBAN: $ibanEmpresa',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── NOTAS PARA EL CLIENTE ─────────────────────────────────────
          if (factura.notasCliente != null &&
              factura.notasCliente!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Notas:',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: colorGris),
            ),
            pw.Text(
              factura.notasCliente!,
              style: pw.TextStyle(fontSize: 9, color: colorGris),
            ),
          ],

          // ── SELLO PROFORMA (solo si es proforma) ─────────────────────
          if (factura.esProforma) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColor.fromHex('#009688'), width: 2),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'PRESUPUESTO',
                    style: pw.TextStyle(
                        color: PdfColor.fromHex('#009688'),
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],

          // ── QR VERIFACTU ──────────────────────────────────────────────
          if (qrVerifactuBytes != null && qrVerifactuBytes.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColor.fromHex('#E0E0E0')),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (esVerifactu)
                        pw.Text(
                          'Factura verificable en la sede electrónica de la AEAT',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0D47A1'),
                          ),
                        ),
                      pw.Text(
                        'VERI*FACTU',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0D47A1'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Escanea el QR para verificar esta factura en la AEAT',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColor.fromHex('#757575'),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.SizedBox(
                  width: 57,
                  height: 57,
                  child: pw.Image(pw.MemoryImage(qrVerifactuBytes)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  // ── GENERAR DESDE FIRESTORE ───────────────────────────────────────────────

  /// Comprueba si la empresa tiene activado el motor de plantillas completo.
  /// Se almacena en empresas/{id}/pdf_config/config → motor_nuevo_enabled: true.
  /// Permite rollout gradual: activar empresa a empresa antes de generalizar.
  static Future<bool> _motorNuevoEnabled(String empresaId) async {
    try {
      final doc = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('pdf_config')
          .doc('config')
          .get();
      return doc.data()?['motor_nuevo_enabled'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List> generarFacturaPdfConDatos(
      Factura factura, String empresaId, {bool registrarAuditoria = false}) async {
    final empresa = await _cargarDatosEmpresa(empresaId);
    final nombreEmpresa = empresa['nombre'] ?? '';
    final cifEmpresa = empresa['cif'];
    final direccionEmpresa = empresa['direccion'];
    final telefonoEmpresa = empresa['telefono'];
    final correoEmpresa = empresa['correo'];
    final ibanEmpresa = empresa['iban'];
    final logoUrl = empresa['logo_url'];

    // Descargar logo (solo en plataformas no web, para evitar problemas CORS)
    final Uint8List? logoBytes = kIsWeb ? null : await _descargarLogo(logoUrl);

    // ── Buscar plantilla default para este tipo de documento ─────────────────
    uiTpl.PdfTemplate? tpl;
    String? colorPrimario;
    String? colorSecundario;
    try {
      final svc = uiTplSvc.PdfTemplateService();
      final tipoUi = factura.esRectificativa
          ? uiTpl.TipoDocumentoPdf.facturaRectificativa
          : factura.esProforma
              ? uiTpl.TipoDocumentoPdf.presupuesto
              : uiTpl.TipoDocumentoPdf.factura;
      tpl = await svc.getPlantillaDefault(empresaId, tipoUi);
      if (tpl != null) {
        colorPrimario   = tpl.colorPrimario;
        colorSecundario = tpl.colorSecundario;
        debugPrint('🎨 [PDF] Plantilla "${tpl.nombre}" [${tpl.estiloLayout}] → $colorPrimario');
      } else {
        debugPrint('⚠️ [PDF] Sin plantilla default para tipo=${tipoUi.id} empresa=$empresaId');
        _logFallback('pdf_no_template', 'tipo=${tipoUi.id} empresa=$empresaId');
      }
    } catch (e) {
      debugPrint('⚠️ [PDF] Error buscando plantilla: $e');
      _logFallback('pdf_template_error', e.toString());
    }

    // ── Generar QR Verifactu ─────────────────────────────────────────────────
    Uint8List? qrBytes;
    bool esVerifactu = false;
    if (factura.verifactu != null && !factura.esProforma) {
      try {
        final datos = DatosVerifactu.fromMap(factura.verifactu!);
        esVerifactu = datos.estado != EstadoVerifactu.error;
        final qrSvc = QrService();
        final qrUrl = datos.urlVerificacion ??
            qrSvc.generarUrl(
              nifEmisor: datos.nifEmisor,
              serie: '',
              numero: datos.numeroFactura.isNotEmpty
                  ? datos.numeroFactura
                  : factura.numeroFactura,
              fecha: factura.fechaEmision,
              importeTotal: factura.total,
            );
        if (!kIsWeb && qrUrl.isNotEmpty) {
          qrBytes = await qrSvc.generarImagenQr(qrUrl);
        }
      } catch (_) {}
    }

    // ── Aplicar plantilla si existe (siempre — ya no hay feature flag) ──────────
    // _generarPdfConTemplate aplica colores, márgenes y estiloLayout del template.
    // Si algo falla, el catch cae al camino legacy con los colores extraídos.
    if (tpl != null) {
      try {
        final bytes = await _generarPdfConTemplate(
          factura: factura,
          tpl: tpl,
          empresa: empresa,
          logoBytes: logoBytes,
          qrBytes: qrBytes,
          esVerifactu: esVerifactu,
        );
        if (registrarAuditoria && factura.id.isNotEmpty) {
          _registrarPlantillaUsada(empresaId, factura.id, tpl.id, tpl.nombre);
        }
        return bytes;
      } catch (e, st) {
        debugPrint('❌ [PDF] _generarPdfConTemplate falló, fallback a clasico: $e');
        _logFallback('pdf_motor_nuevo_failed', e.toString(), st);
      }
    }

    // ── Camino legacy (hardcodeado con colores del template) ─────────────────
    if (registrarAuditoria && factura.id.isNotEmpty && tpl != null) {
      _registrarPlantillaUsada(empresaId, factura.id, tpl.id, tpl.nombre);
    }
    return _generarPdfBytes(
      factura: factura,
      nombreEmpresa: nombreEmpresa.isEmpty ? 'Mi Empresa' : nombreEmpresa,
      cifEmpresa: cifEmpresa?.isNotEmpty == true ? cifEmpresa : null,
      direccionEmpresa: direccionEmpresa?.isNotEmpty == true ? direccionEmpresa : null,
      telefonoEmpresa: telefonoEmpresa?.isNotEmpty == true ? telefonoEmpresa : null,
      correoEmpresa: correoEmpresa?.isNotEmpty == true ? correoEmpresa : null,
      ibanEmpresa: ibanEmpresa?.isNotEmpty == true ? ibanEmpresa : null,
      logoBytes: logoBytes,
      qrVerifactuBytes: qrBytes,
      esVerifactu: esVerifactu,
      colorPrimarioTemplate: colorPrimario,
      colorSecundarioTemplate: colorSecundario,
    );
  }

  /// Motor nuevo: aplica el layout y estilo completo del template.
  /// Actualmente soporta todos los estiloLayout con datos reales.
  /// Si el layout no tiene soporte completo, usa 'clasico' como fallback seguro.
  static Future<Uint8List> _generarPdfConTemplate({
    required Factura factura,
    required uiTpl.PdfTemplate tpl,
    required Map<String, String> empresa,
    Uint8List? logoBytes,
    Uint8List? qrBytes,
    bool esVerifactu = false,
  }) async {
    // Todos los layouts actuales usan _generarPdfBytes con los parámetros
    // completos del template (colores, márgenes). El estiloLayout controla
    // layouts especializados cuando sus builders soporten datos reales.
    // Por ahora el motor_nuevo garantiza: colores + márgenes + tipo correcto.
    final margenH = tpl.margenHorizontal.toDouble();
    final margenV = tpl.margenVertical.toDouble();

    // Parámetros comunes para todos los layouts
    final nombreEmpresa = empresa['nombre']?.isNotEmpty == true ? empresa['nombre']! : 'Mi Empresa';
    final cifEmpresa    = empresa['cif']?.isNotEmpty == true ? empresa['cif'] : null;
    final dirEmpresa    = empresa['direccion']?.isNotEmpty == true ? empresa['direccion'] : null;
    final telEmpresa    = empresa['telefono']?.isNotEmpty == true ? empresa['telefono'] : null;
    final correoEmpresa = empresa['correo']?.isNotEmpty == true ? empresa['correo'] : null;
    final ibanEmpresa   = empresa['iban']?.isNotEmpty == true ? empresa['iban'] : null;

    switch (tpl.estiloLayout) {
      // 'linea' → Minimalista, Púrpura: acento de línea + header blanco
      case 'linea':
        return _generarPdfLineaFactura(
          factura: factura,
          primario: tpl.colorPrimario,
          nombreEmpresa: nombreEmpresa,
          cifEmpresa: cifEmpresa,
          direccionEmpresa: dirEmpresa,
          correoEmpresa: correoEmpresa,
          ibanEmpresa: ibanEmpresa,
          logoBytes: logoBytes,
          qrBytes: qrBytes,
          esVerifactu: esVerifactu,
          margenH: margenH,
          margenV: margenV,
        );
      // 'bold' → Esmeralda, Burdeos: cabecera grande con empresa prominente
      case 'bold':
        return _generarPdfBoldFactura(
          factura: factura,
          primario: tpl.colorPrimario,
          secundario: tpl.colorSecundario,
          nombreEmpresa: nombreEmpresa,
          cifEmpresa: cifEmpresa,
          ibanEmpresa: ibanEmpresa,
          correoEmpresa: correoEmpresa,
          logoBytes: logoBytes,
          qrBytes: qrBytes,
          esVerifactu: esVerifactu,
        );
      // Layouts del selector de diseño — pasan datos reales de Factura
      case 'd1_corp':
        return _pdfD1Corp(primario: tpl.colorPrimario, nombreEmpresa: nombreEmpresa,
            cifEmpresa: cifEmpresa, logoBytes: logoBytes,
            anio: factura.fechaEmision.year, factura: factura);
      case 'd2_minimal':
        return _pdfD2Minimal(nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
            logoBytes: logoBytes, anio: factura.fechaEmision.year, factura: factura);
      case 'd3_hero':
        return _pdfD3Hero(primario: tpl.colorPrimario, nombreEmpresa: nombreEmpresa,
            cifEmpresa: cifEmpresa, logoBytes: logoBytes,
            anio: factura.fechaEmision.year, factura: factura);
      case 'd4_sidebar':
        return _pdfD4Sidebar(primario: tpl.colorPrimario, nombreEmpresa: nombreEmpresa,
            cifEmpresa: cifEmpresa, logoBytes: logoBytes,
            anio: factura.fechaEmision.year, factura: factura);
      case 'd5_cards':
        return _pdfD5Cards(primario: tpl.colorPrimario, nombreEmpresa: nombreEmpresa,
            cifEmpresa: cifEmpresa, logoBytes: logoBytes,
            anio: factura.fechaEmision.year, factura: factura);
      case 'd6_dark':
        return _pdfD6Dark(primario: tpl.colorPrimario, nombreEmpresa: nombreEmpresa,
            cifEmpresa: cifEmpresa, logoBytes: logoBytes,
            anio: factura.fechaEmision.year, factura: factura);
      case 'd7_exec':
        return _pdfD7Exec(nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
            logoBytes: logoBytes, anio: factura.fechaEmision.year, factura: factura);
      // 'clasico', 'nazari' y cualquier otro → layout estándar con colores del template
      default:
        return _generarPdfBytes(
          factura: factura,
          nombreEmpresa: nombreEmpresa,
          cifEmpresa: cifEmpresa,
          direccionEmpresa: dirEmpresa,
          telefonoEmpresa: telEmpresa,
          correoEmpresa: correoEmpresa,
          ibanEmpresa: ibanEmpresa,
          logoBytes: logoBytes,
          qrVerifactuBytes: qrBytes,
          esVerifactu: esVerifactu,
          colorPrimarioTemplate: tpl.colorPrimario,
          colorSecundarioTemplate: tpl.colorSecundario,
          margenHorizontal: margenH,
          margenVertical: margenV,
        );
    }
  }

  // ── GENERADOR PDF PRESUPUESTO (R6) ──────────────────────────────────────
  // Un presupuesto usa los mismos datos que una Factura pero:
  //  - Busca la plantilla de tipo TipoDocumentoPdf.presupuesto
  //  - Usa la cabecera de color de esa plantilla
  //  - NO genera QR Verifactu (no es un documento fiscal)
  //  - Añade aviso de "Sin efecto fiscal" en el footer
  static Future<Uint8List> generarPresupuestoPdf(
    Factura factura,
    String empresaId, {
    bool registrarAuditoria = false,
  }) async {
    final empresa = await _cargarDatosEmpresa(empresaId);
    final logoBytes = kIsWeb ? null : await _descargarLogo(empresa['logo_url']);

    uiTpl.PdfTemplate? tpl;
    String? colorPrimario;
    String? colorSecundario;
    try {
      final svc = uiTplSvc.PdfTemplateService();
      tpl = await svc.getPlantillaDefault(empresaId, uiTpl.TipoDocumentoPdf.presupuesto);
      if (tpl != null) {
        colorPrimario   = tpl.colorPrimario;
        colorSecundario = tpl.colorSecundario;
        debugPrint('💼 [PDF-PRESUPUESTO] Plantilla "${tpl.nombre}" → $colorPrimario');
      } else {
        _logFallback('presupuesto_no_template', 'empresa=$empresaId');
      }
    } catch (e) {
      _logFallback('presupuesto_template_error', e.toString());
    }

    // Añadir aviso de presupuesto en notas si están vacías
    final facturaParaPdf = factura.notasCliente == null || factura.notasCliente!.isEmpty
        ? factura.copyWith(
            notasCliente: 'PRESUPUESTO — Sin efecto fiscal. '
                'Válido 30 días desde la fecha de emisión.',
          )
        : factura;

    // Aplicar plantilla (incluidos layouts d1-d7) si existe
    if (tpl != null) {
      try {
        final bytes = await _generarPdfConTemplate(
          factura: facturaParaPdf,
          tpl: tpl,
          empresa: empresa,
          logoBytes: logoBytes,
          qrBytes: null, // presupuesto no tiene QR Verifactu
          esVerifactu: false,
        );
        if (registrarAuditoria && factura.id.isNotEmpty) {
          _registrarPlantillaUsada(empresaId, factura.id, tpl.id, tpl.nombre);
        }
        return bytes;
      } catch (e, st) {
        debugPrint('❌ [PDF-PRESUPUESTO] template falló, fallback: $e');
        _logFallback('presupuesto_motor_failed', e.toString(), st);
      }
    }

    // Fallback legacy
    if (registrarAuditoria && factura.id.isNotEmpty && tpl != null) {
      _registrarPlantillaUsada(empresaId, factura.id, tpl.id, tpl.nombre);
    }
    return _generarPdfBytes(
      factura: facturaParaPdf,
      nombreEmpresa: empresa['nombre']?.isNotEmpty == true ? empresa['nombre']! : 'Mi Empresa',
      cifEmpresa: empresa['cif']?.isNotEmpty == true ? empresa['cif'] : null,
      direccionEmpresa: empresa['direccion']?.isNotEmpty == true ? empresa['direccion'] : null,
      telefonoEmpresa: empresa['telefono']?.isNotEmpty == true ? empresa['telefono'] : null,
      correoEmpresa: empresa['correo']?.isNotEmpty == true ? empresa['correo'] : null,
      ibanEmpresa: empresa['iban']?.isNotEmpty == true ? empresa['iban'] : null,
      logoBytes: logoBytes,
      colorPrimarioTemplate: colorPrimario ?? '#2E7D32',
      colorSecundarioTemplate: colorSecundario ?? '#1B5E20',
      margenHorizontal: tpl?.margenHorizontal ?? 36,
      margenVertical: tpl?.margenVertical ?? 36,
    );
  }

  // ── VER FACTURA EN PANTALLA ───────────────────────────────────────────────

  static Future<void> verFacturaPdf(
    BuildContext context,
    Factura factura,
    String empresaId,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await generarFacturaPdfConDatos(factura, empresaId);
      if (!context.mounted) return;
      Navigator.of(context).pop();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(factura.numeroFactura),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Compartir PDF',
                  onPressed: () => Printing.sharePdf(
                    bytes: bytes,
                    filename: '${factura.numeroFactura}.pdf',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Imprimir',
                  onPressed: () => Printing.layoutPdf(
                    onLayout: (_) async => bytes,
                    name: '${factura.numeroFactura}.pdf',
                  ),
                ),
              ],
            ),
            body: PdfPreview(
              build: (_) async => bytes,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        final msg = e is TimeoutException
            ? '⏱ Tiempo agotado generando el PDF. Inténtalo de nuevo.'
            : '❌ Error generando PDF: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  // ── PREVISUALIZAR PLANTILLA ──────────────────────────────────────────────────

  /// Genera los bytes del PDF de muestra con el layout seleccionado del template.
  static Future<Uint8List> generarPreviewBytes(
    uiTpl.PdfTemplate plantilla,
    String empresaId,
  ) async {
    final empresa = await _cargarDatosEmpresa(empresaId);
    final logoBytes = kIsWeb ? null : await _descargarLogo(empresa['logo_url']);
    final ahora = DateTime.now();
    final nombreEmpresa = empresa['nombre'] ?? 'Fluix Studio';
    final cifEmpresa    = empresa['cif'] as String?;
    final dir           = empresa['direccion'] as String?;
    final tel           = empresa['telefono'] as String?;
    final correo        = empresa['correo'] as String?;
    final iban          = empresa['iban'] as String?;

    // Tipos que necesitan preview especializado (no de factura)
    // ── Informes: 7 diseños del HTML informe.html ─────────────────────────
    final esInformeHoras = plantilla.tipo == uiTpl.TipoDocumentoPdf.horasEmpleado ||
        plantilla.tipo == uiTpl.TipoDocumentoPdf.fichajes;
    final esInformeInterno = plantilla.tipo == uiTpl.TipoDocumentoPdf.informeInterno;

    if (esInformeHoras || esInformeInterno) {
      final accentColor = esInformeHoras ? '#2E5A50' : '#3A3A40';
      final priColor = plantilla.colorPrimario.isNotEmpty
          ? plantilla.colorPrimario : accentColor;

      switch (plantilla.estiloLayout) {
        case 'd1_corp':
          return _pdfInformeD1(primario: priColor, esHoras: esInformeHoras,
              nombreEmpresa: nombreEmpresa, logoBytes: logoBytes, anio: ahora.year);
        case 'd2_minimal':
          return _pdfInformeD2(primario: priColor, esHoras: esInformeHoras,
              nombreEmpresa: nombreEmpresa, logoBytes: logoBytes, anio: ahora.year);
        case 'd3_hero':
          return _pdfInformeD3(primario: priColor, esHoras: esInformeHoras,
              nombreEmpresa: nombreEmpresa, logoBytes: logoBytes, anio: ahora.year);
        default:
          return _generarPdfHoras(
            primario: priColor, secundario: plantilla.colorSecundario,
            nombreEmpresa: nombreEmpresa, logoBytes: logoBytes, anio: ahora.year);
      }
    }

    switch (plantilla.estiloLayout) {
      // ── 7 diseños factura ──────────────────────────────────────────────────
      case 'd1_corp':
        return _pdfD1Corp(primario: plantilla.colorPrimario,
            nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
            logoBytes: logoBytes, anio: ahora.year,
            tipoDoc: plantilla.tipo.label.toUpperCase());
      case 'd2_minimal':
        return _pdfD2Minimal(nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
            logoBytes: logoBytes, anio: ahora.year,
            tipoDoc: plantilla.tipo.label.toUpperCase());
      case 'd3_hero':
        return _pdfD3Hero(primario: plantilla.colorPrimario,
            nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
            logoBytes: logoBytes, anio: ahora.year);
      case 'd4_sidebar':
        return _pdfD4Sidebar(primario: plantilla.colorPrimario,
            nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
            logoBytes: logoBytes, anio: ahora.year,
            tipoDoc: plantilla.tipo.label.toUpperCase());
      case 'd5_cards':
        return _pdfD5Cards(primario: plantilla.colorPrimario,
            nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
            logoBytes: logoBytes, anio: ahora.year,
            tipoDoc: plantilla.tipo.label.toUpperCase());
      case 'd6_dark':
        return _pdfD6Dark(primario: plantilla.colorPrimario,
            nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
            logoBytes: logoBytes, anio: ahora.year,
            tipoDoc: plantilla.tipo.label.toUpperCase());
      case 'd7_exec':
        return _pdfD7Exec(nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
            logoBytes: logoBytes, anio: ahora.year,
            tipoDoc: plantilla.tipo.label.toUpperCase());
      // ────────────────────────────────────────────────────────────────────────
      case 'nazari':
        return _generarPdfNazari(
          primario: plantilla.colorPrimario,
          nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
          logoBytes: logoBytes, anio: ahora.year,
          tipoDoc: plantilla.tipo.label.toUpperCase(),
        );
      case 'linea':
        return _generarPdfLinea(
          primario: plantilla.colorPrimario, secundario: plantilla.colorSecundario,
          nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
          logoBytes: logoBytes, anio: ahora.year,
          tipoDoc: plantilla.tipo.label.toUpperCase(),
        );
      case 'bold':
        return _generarPdfBold(
          primario: plantilla.colorPrimario, secundario: plantilla.colorSecundario,
          nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
          logoBytes: logoBytes, anio: ahora.year,
          tipoDoc: plantilla.tipo.label.toUpperCase(),
        );
      default: // 'clasico'
        final facturaMustra = Factura(
          id: 'preview', empresaId: empresaId,
          numeroFactura: 'FAC-${ahora.year}-0001',
          tipo: TipoFactura.venta_directa, estado: EstadoFactura.pagada,
          clienteNombre: 'Cliente Ejemplo S.L.', clienteCorreo: 'cliente@ejemplo.com',
          datosFiscales: const DatosFiscales(nif: 'B12345678'),
          lineas: const [
            LineaFactura(descripcion: 'Servicio de diseño web', cantidad: 3, precioUnitario: 250.0),
            LineaFactura(descripcion: 'Mantenimiento mensual', cantidad: 1, precioUnitario: 150.0),
          ],
          subtotal: 900.0, totalIva: 189.0, total: 1089.0,
          descuentoGlobal: 0, importeDescuentoGlobal: 0,
          porcentajeIrpf: 0, retencionIrpf: 0, totalRecargoEquivalencia: 0,
          diasVencimiento: 30, metodoPago: MetodoPagoFactura.transferencia,
          historial: [], fechaEmision: ahora,
          fechaVencimiento: ahora.add(const Duration(days: 30)), flujo: 'ingreso',
        );
        return _generarPdfBytes(
          factura: facturaMustra,
          nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
          direccionEmpresa: dir, telefonoEmpresa: tel,
          correoEmpresa: correo, ibanEmpresa: iban,
          logoBytes: logoBytes,
          colorPrimarioTemplate: plantilla.colorPrimario,
          colorSecundarioTemplate: plantilla.colorSecundario,
        );
    }
  }

  // ── Layout 'nazari' — paper limpio, sin cabecera de color ────────────────
  static Future<Uint8List> _generarPdfNazari({
    required String primario,
    required String nombreEmpresa,
    String? cifEmpresa,
    Uint8List? logoBytes,
    required int anio,
    String tipoDoc = 'FACTURA',
    String numDoc = '',
  }) async {
    final colAcc  = PdfColor.fromHex(primario);
    final colInk  = PdfColor.fromHex('#26262B');
    final colSoft = PdfColor.fromHex('#6B6B73');
    final colFaint= PdfColor.fromHex('#A8A8AE');
    final colLine = PdfColor.fromHex('#E8E8E6');
    final (fontR, fontB) = await _FC.iB;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));

    final numero = numDoc.isNotEmpty ? numDoc : '$tipoDoc-$anio-0001';
    final hoy = DateTime.now();
    final hoyStr = '${hoy.day.toString().padLeft(2,'0')}/${hoy.month.toString().padLeft(2,'0')}/${hoy.year}';
    final vencStr = '${(hoy.month % 12 + 1).toString().padLeft(2,'0')}/${hoy.year}';

    final lineas = [
      ('Licencia TPV — Plan Pro', 'Suscripción mensual', 1, 49.0),
      ('Soporte técnico premium', 'Servicio adicional', 1, 25.0),
      ('Consultoría de negocio', 'Sesión 2h', 2, 90.0),
    ];
    final subtotal = lineas.fold(0.0, (s, l) => s + l.$3 * l.$4);
    final iva = subtotal * 0.21;
    final total = subtotal + iva;

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 52, vertical: 48),
      ),
      build: (ctx) => [
        // ── Header: empresa izquierda / doc badge + número derecha ───────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Empresa
            pw.Row(children: [
              pw.Container(
                width: 40, height: 40,
                decoration: pw.BoxDecoration(
                  color: PdfColor(colAcc.red, colAcc.green, colAcc.blue, 0.13),
                  borderRadius: pw.BorderRadius.circular(9),
                ),
                alignment: pw.Alignment.center,
                child: logoBytes != null
                    ? pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain)
                    : pw.Text(
                        nombreEmpresa.isNotEmpty ? nombreEmpresa[0].toUpperCase() : 'F',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: colAcc),
                      ),
              ),
              pw.SizedBox(width: 10),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: colInk)),
                if (cifEmpresa?.isNotEmpty == true)
                  pw.Text('CIF $cifEmpresa', style: pw.TextStyle(fontSize: 9, color: colSoft)),
                pw.Text('hola@fluix.com', style: pw.TextStyle(fontSize: 9, color: colSoft)),
              ]),
            ]),
            // Badge + número
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor(colAcc.red, colAcc.green, colAcc.blue, 0.13),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Text(tipoDoc, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: colAcc)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Nº $numero', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: colInk)),
              pw.SizedBox(height: 2),
              pw.Text('Fecha de emisión: $hoyStr', style: pw.TextStyle(fontSize: 10, color: colSoft)),
            ]),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: colLine, thickness: 2),
        pw.SizedBox(height: 20),
        // ── Parties ──────────────────────────────────────────────────────────
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _nazariLabel('Emisor', colFaint),
            pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: colInk)),
            pw.Text('CIF ${cifEmpresa ?? 'B12345678'}\nCalle Mayor 12, Madrid', style: pw.TextStyle(fontSize: 10, color: colSoft, lineSpacing: 2)),
          ])),
          pw.SizedBox(width: 24),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _nazariLabel('Cliente', colFaint),
            pw.Text('Cliente Ejemplo S.L.', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: colInk)),
            pw.Text('CIF B87654321\nCalle Sol 5, 28002 Madrid', style: pw.TextStyle(fontSize: 10, color: colSoft, lineSpacing: 2)),
          ])),
        ]),
        pw.SizedBox(height: 20),
        // ── Meta row ─────────────────────────────────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: colLine),
            borderRadius: pw.BorderRadius.circular(7),
          ),
          child: pw.Row(children: [
            _nazariMetaCell('Fecha emisión', hoyStr, colFaint, colInk, border: false),
            _nazariMetaDiv(colLine),
            _nazariMetaCell('Vencimiento', vencStr, colFaint, colInk, border: false),
            _nazariMetaDiv(colLine),
            _nazariMetaCell('Forma de pago', 'Transferencia', colFaint, colInk, border: false),
            _nazariMetaDiv(colLine),
            _nazariMetaCell('Estado', 'Pagada', colFaint, colAcc, border: false),
          ]),
        ),
        pw.SizedBox(height: 20),
        // ── Tabla ─────────────────────────────────────────────────────────────
        pw.Table(
          border: pw.TableBorder(bottom: pw.BorderSide(color: colLine, width: 1)),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FixedColumnWidth(36),
            2: const pw.FixedColumnWidth(70),
            3: const pw.FixedColumnWidth(70),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: colLine, width: 2))),
              children: [
                for (final h in ['CONCEPTO', 'CANT.', 'PRECIO', 'IMPORTE'])
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colFaint, letterSpacing: 0.4)),
                  ),
              ],
            ),
            ...lineas.asMap().entries.map((e) {
              final isLast = e.key == lineas.length - 1;
              return pw.TableRow(
                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: isLast ? colLine : PdfColor(0.94, 0.94, 0.94), width: 1))),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10), child:
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(e.value.$1, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: colInk)),
                      pw.SizedBox(height: 1),
                      pw.Text(e.value.$2, style: pw.TextStyle(fontSize: 9, color: colSoft)),
                    ])),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10), child:
                    pw.Text('${e.value.$3}', style: pw.TextStyle(fontSize: 11, color: colInk))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10), child:
                    pw.Text('€${e.value.$4.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, color: colInk))),
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10), child:
                    pw.Text('€${(e.value.$3 * e.value.$4).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: colInk))),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 16),
        // ── Totales ───────────────────────────────────────────────────────────
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.SizedBox(width: 240, child: pw.Column(children: [
            _nazariTotalRow('Base imponible', '€${subtotal.toStringAsFixed(2)}', colSoft, colInk, bold: false),
            pw.SizedBox(height: 6),
            _nazariTotalRow('IVA (21%)', '€${iva.toStringAsFixed(2)}', colSoft, colInk, bold: false),
            pw.SizedBox(height: 6),
            pw.Divider(color: colInk, thickness: 2),
            pw.SizedBox(height: 6),
            _nazariTotalRow('Total', '€${total.toStringAsFixed(2)}', colInk, colAcc, bold: true, fontSize: 14),
          ])),
        ]),
        pw.SizedBox(height: 24),
        pw.Divider(color: colLine, thickness: 1),
        pw.SizedBox(height: 16),
        // ── Footer ────────────────────────────────────────────────────────────
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _nazariLabel('Datos de pago', colFaint),
            pw.Text('IBAN: ES00 0000 0000 0000 0000\nTitular: $nombreEmpresa\nConcepto: $tipoDoc $numero',
                style: pw.TextStyle(fontSize: 9, color: colSoft, lineSpacing: 2)),
          ])),
          pw.SizedBox(width: 24),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _nazariLabel('Notas', colFaint),
            pw.Text('Gracias por confiar en nosotros. Para cualquier consulta, contáctenos.',
                style: pw.TextStyle(fontSize: 9, color: colSoft, lineSpacing: 2)),
          ])),
        ]),
        pw.SizedBox(height: 16),
        // ── Nota legal ────────────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 12),
          decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(
            color: colLine, width: 1, style: pw.BorderStyle.dashed))),
          child: pw.Text(
            'Documento emitido conforme al Real Decreto 1619/2012. Operación no exenta de IVA.',
            style: pw.TextStyle(fontSize: 8, color: colFaint),
          ),
        ),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _nazariLabel(String text, PdfColor color) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Text(text.toUpperCase(),
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
            color: color, letterSpacing: 0.6)),
  );

  static pw.Widget _nazariMetaDiv(PdfColor color) =>
    pw.Container(width: 1, height: 40, color: color);

  static pw.Widget _nazariMetaCell(
    String label, String value, PdfColor labelColor, PdfColor valueColor, {bool border = true}) =>
    pw.Expanded(child: pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 8, color: labelColor, letterSpacing: 0.4)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: valueColor)),
      ]),
    ));

  static pw.Widget _nazariTotalRow(String label, String value,
      PdfColor labelColor, PdfColor valueColor, {bool bold = false, double fontSize = 11}) =>
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: fontSize, color: labelColor,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold, color: valueColor)),
    ]);

  // ══════════════════════════════════════════════════════════════════════════
  // 7 DISEÑOS DE FACTURA — fieles al HTML factudiseño.html
  // ══════════════════════════════════════════════════════════════════════════

  static const _lineasDemo = [
    ('Licencia TPV — Plan Pro', 1, 49.0, 21.0),
    ('Terminal de pago (alquiler mensual)', 2, 15.0, 21.0),
    ('Soporte técnico prioritario', 1, 20.0, 21.0),
  ];
  static double get _demoBase => _lineasDemo.fold(0.0, (s, l) => s + l.$2 * l.$3);
  static double get _demoIva  => _demoBase * 0.21;
  static double get _demoTotal=> _demoBase + _demoIva;

  static String _fmtNum(double v) => '€${v.toStringAsFixed(2).replaceAll('.', ',')}';
  static String _fmtAnio(int a) => '${DateTime.now().day.toString().padLeft(2,'0')}/${DateTime.now().month.toString().padLeft(2,'0')}/$a';

  // ── Helpers para datos reales vs demo en layouts _pdfD* ──────────────────────
  static String _dNumFactura(Factura? f, int anio) =>
      f?.numeroFactura ?? 'FAC-$anio-0001';
  static String _dFecha(Factura? f, int anio) => f != null
      ? '${f.fechaEmision.day.toString().padLeft(2, '0')}/${f.fechaEmision.month.toString().padLeft(2, '0')}/${f.fechaEmision.year}'
      : _fmtAnio(anio);
  static String _dClienteNombre(Factura? f) => f?.clienteNombre ?? 'Cliente Ejemplo S.L.';
  static String _dClienteNif(Factura? f) {
    final nif = f?.datosFiscales?.nif;
    return nif != null && nif.isNotEmpty ? 'NIF $nif' : 'NIF B12345678';
  }
  static double _dBase(Factura? f)  => f?.subtotal  ?? _demoBase;
  static double _dIva(Factura? f)   => f?.totalIva  ?? _demoIva;
  static double _dTotal(Factura? f) => f?.total     ?? _demoTotal;
  static String _capitalizar(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  static String _dTipoDoc(Factura? f, [String? override]) {
    if (override != null) return override;
    if (f == null) return 'FACTURA';
    if (f.esRectificativa) return 'FACTURA RECTIFICATIVA';
    if (f.esProforma) return 'PRESUPUESTO';
    return 'FACTURA';
  }

  // Lista de líneas normalizada para los layouts _pdfD*
  static List<({String desc, int qty, double price, double total, double iva})> _dLineas(Factura? f) {
    if (f == null) {
      return _lineasDemo
          .map((l) => (desc: l.$1, qty: l.$2, price: l.$3, total: l.$2 * l.$3, iva: l.$4))
          .toList();
    }
    return f.lineas
        .map((l) => (desc: l.descripcion, qty: l.cantidad, price: l.precioUnitario,
                     total: l.subtotalSinIva, iva: l.porcentajeIva))
        .toList();
  }

  // ── Bloques legales compartidos por todos los layouts D* ─────────────────
  // Art. 15 RD 1619/2012: bloque obligatorio en facturas rectificativas.
  static pw.Widget _dBloqueRectificativa(Factura f) =>
    pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF3E0'),
        border: pw.Border.all(color: PdfColor.fromHex('#D32F2F'), width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('RECTIFICA A LA FACTURA',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#D32F2F'), letterSpacing: 0.8)),
        pw.SizedBox(height: 3),
        pw.Text(
          'Nº ${f.facturaOriginalNumero ?? '—'}'
          '${f.facturaOriginalFecha != null ? "   Fecha: ${_fmtDate(f.facturaOriginalFecha!)}" : ""}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        if (f.motivoRectificacion != null) ...[
          pw.SizedBox(height: 3),
          pw.Text('Motivo: ${f.motivoRectificacion!.etiqueta}',
              style: pw.TextStyle(fontSize: 9)),
        ],
        if (f.metodoRectificacion != null)
          pw.Text('Método: ${f.metodoRectificacion!.etiqueta}',
              style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#757575'))),
        if (f.motivoRectificacionTexto != null && f.motivoRectificacionTexto!.isNotEmpty)
          pw.Text(f.motivoRectificacionTexto!,
              style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#757575'))),
        pw.SizedBox(height: 4),
        pw.Text('Emitida conforme al Art. 15 del R.D. 1619/2012.',
            style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#9E9E9E'))),
      ]),
    );

  // Proforma: texto "NO ES FACTURA" obligatorio para evitar confusión legal.
  static pw.Widget _dBloqueProforma() =>
    pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E65100'), width: 2),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text('DOCUMENTO SIN VALIDEZ FISCAL',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#E65100'), letterSpacing: 1)),
        pw.SizedBox(height: 3),
        pw.Text('Este documento no constituye factura a efectos del R.D. 1619/2012. No genera obligación de pago.',
            style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#757575'))),
      ]),
    );

  // Footer legal adaptado al tipo de documento.
  static String _dFooterLegal(Factura? f) {
    if (f?.esRectificativa == true) {
      return 'Factura rectificativa emitida conforme al Art. 15 del R.D. 1619/2012.';
    }
    if (f?.esProforma == true) {
      return 'Documento sin validez fiscal. No constituye factura según el R.D. 1619/2012.';
    }
    return 'Factura emitida conforme al Real Decreto 1619/2012.';
  }

  // ── D1: Clásico Corporativo ───────────────────────────────────────────────
  static Future<Uint8List> _pdfD1Corp({
    required String primario, required String nombreEmpresa,
    String? cifEmpresa, Uint8List? logoBytes, required int anio,
    Factura? factura, String? tipoDoc,
  }) async {
    final navy = PdfColor.fromHex(primario.isNotEmpty ? primario : '#1B2A4A');
    final (fontR, fontB) = await _FC.nB;
    final pdf   = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final _lineas = _dLineas(factura);

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero),
      build: (ctx) => [
        // Band header
        pw.Container(
          width: double.infinity, padding: const pw.EdgeInsets.fromLTRB(48, 36, 48, 36),
          color: navy,
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(nombreEmpresa.toUpperCase(), style: pw.TextStyle(color: PdfColors.white,
                  fontSize: 18, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
              pw.SizedBox(height: 4),
              pw.Text('${cifEmpresa != null ? 'CIF $cifEmpresa · ' : ''}Madrid',
                  style: pw.TextStyle(color: PdfColor(0.67, 0.71, 0.80), fontSize: 10)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(_dTipoDoc(factura, tipoDoc), style: pw.TextStyle(color: PdfColors.white,
                  fontSize: 22, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              pw.SizedBox(height: 4),
              pw.Text('Nº ${_dNumFactura(factura, anio)} · ${_dFecha(factura, anio)}',
                  style: pw.TextStyle(color: PdfColor(0.67, 0.71, 0.80), fontSize: 11)),
            ]),
          ]),
        ),
        // Body
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(48, 28, 48, 32),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // Parties
            pw.Row(children: [
              pw.Expanded(child: _d1Party('Emisor', nombreEmpresa,
                  cifEmpresa != null ? 'CIF $cifEmpresa\nMadrid' : 'Madrid')),
              pw.SizedBox(width: 24),
              pw.Expanded(child: _d1Party('Cliente', _dClienteNombre(factura),
                  '${_dClienteNif(factura)}')),
            ]),
            pw.Divider(color: PdfColor.fromHex('#E5E5E5'), height: 32),
            // Bloque legal rectificativa (Art. 15 RD 1619/2012)
            if (factura?.esRectificativa == true) _dBloqueRectificativa(factura!),
            // Table
            _d1Table(navy, _lineas),
            pw.SizedBox(height: 20),
            // Totals
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.SizedBox(width: 280, child: pw.Column(children: [
                _d1TRow('Base imponible', _fmtNum(_dBase(factura))),
                _d1TRow('IVA', _fmtNum(_dIva(factura))),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: pw.BoxDecoration(color: navy, borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Total', style: pw.TextStyle(color: PdfColors.white,
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_fmtNum(_dTotal(factura)), style: pw.TextStyle(color: PdfColors.white,
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
              ])),
            ]),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColor.fromHex('#E5E5E5'), height: 1),
            pw.SizedBox(height: 16),
            pw.Row(children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('DATOS DE PAGO', style: pw.TextStyle(fontSize: 9,
                    fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1a1a1a'), letterSpacing: 0.4)),
                pw.SizedBox(height: 4),
                pw.Text('IBAN: ES00 0000 0000 0000 0000\nTitular: $nombreEmpresa',
                    style: pw.TextStyle(fontSize: 10.5, color: PdfColor.fromHex('#666'), lineSpacing: 3)),
              ])),
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('NOTAS', style: pw.TextStyle(fontSize: 9,
                    fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1a1a1a'), letterSpacing: 0.4)),
                pw.SizedBox(height: 4),
                pw.Text('Gracias por confiar en $nombreEmpresa. Vencimiento: ${_fmtAnio(anio)}.',
                    style: pw.TextStyle(fontSize: 10.5, color: PdfColor.fromHex('#666'), lineSpacing: 3)),
              ])),
            ]),
            pw.SizedBox(height: 20),
            // Disclaimer proforma (bloque centrado con borde)
            if (factura?.esProforma == true) ...[
              pw.Center(child: _dBloqueProforma()),
              pw.SizedBox(height: 12),
            ],
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 12),
              decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(
                  color: PdfColor.fromHex('#E5E5E5'), width: 1,
                  style: pw.BorderStyle.dashed))),
              child: pw.Text(_dFooterLegal(factura),
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#999'))),
            ),
          ]),
        ),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _d1Party(String lbl, String name, String detail) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(lbl.toUpperCase(), style: pw.TextStyle(fontSize: 9,
          color: PdfColor.fromHex('#8A8A8A'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.6)),
      pw.SizedBox(height: 5),
      pw.Text(name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(detail, style: pw.TextStyle(fontSize: 10.5,
          color: PdfColor.fromHex('#555'), lineSpacing: 3)),
    ]);

  static pw.Widget _d1Table(PdfColor navy,
      List<({String desc, int qty, double price, double total, double iva})> lineas) {
    return pw.Table(
      columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FixedColumnWidth(36),
          2: const pw.FixedColumnWidth(60), 3: const pw.FixedColumnWidth(36),
          4: const pw.FixedColumnWidth(60)},
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: navy),
          children: ['CONCEPTO', 'CANT.', 'PRECIO', 'IVA', 'IMPORTE'].map((h) =>
            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white,
                  fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.4)))).toList(),
        ),
        ...lineas.asMap().entries.map((e) => pw.TableRow(
          decoration: pw.BoxDecoration(
              color: e.key.isEven ? PdfColors.white : PdfColor.fromHex('#F8F9FB')),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(12),
                child: pw.Text(e.value.desc, style: const pw.TextStyle(fontSize: 11))),
            pw.Padding(padding: const pw.EdgeInsets.all(12),
                child: pw.Text('${e.value.qty}', style: const pw.TextStyle(fontSize: 11))),
            pw.Padding(padding: const pw.EdgeInsets.all(12),
                child: pw.Text(_fmtNum(e.value.price), style: const pw.TextStyle(fontSize: 11))),
            pw.Padding(padding: const pw.EdgeInsets.all(12),
                child: pw.Text('${e.value.iva.toInt()}%', style: const pw.TextStyle(fontSize: 11))),
            pw.Padding(padding: const pw.EdgeInsets.all(12),
                child: pw.Text(_fmtNum(e.value.total),
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
          ],
        )),
      ],
    );
  }

  static pw.Widget _d1TRow(String l, String r) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(l, style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#555'))),
        pw.Text(r, style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#555'))),
      ]));

  // ── D2: Minimalista ───────────────────────────────────────────────────────
  static Future<Uint8List> _pdfD2Minimal({
    required String nombreEmpresa, String? cifEmpresa,
    Uint8List? logoBytes, required int anio,
    Factura? factura, String? tipoDoc,
  }) async {
    final (fontR, fontB) = await _FC.nB;
    final pdf   = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final ink   = PdfColor.fromHex('#222');
    final soft  = PdfColor.fromHex('#888');
    final faint = PdfColor.fromHex('#BBB');
    final _lineas = _dLineas(factura);

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 64, vertical: 60)),
      build: (ctx) => [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(nombreEmpresa.toUpperCase(), style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
            pw.SizedBox(height: 6),
            pw.Text(cifEmpresa != null ? 'CIF $cifEmpresa — Madrid' : 'Madrid',
                style: pw.TextStyle(fontSize: 9, color: soft, letterSpacing: 0.5)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(_dTipoDoc(factura, tipoDoc), style: pw.TextStyle(
                fontSize: 9, color: soft, letterSpacing: 3)),
            pw.SizedBox(height: 6),
            pw.Text(_dNumFactura(factura, anio), style: pw.TextStyle(
                fontSize: 24, fontWeight: pw.FontWeight.normal, color: ink)),
          ]),
        ]),
        pw.SizedBox(height: 50),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FACTURADO A', style: pw.TextStyle(
                fontSize: 8.5, color: faint, letterSpacing: 1.5)),
            pw.SizedBox(height: 8),
            pw.Text(_dClienteNombre(factura), style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text(_dClienteNif(factura),
                style: pw.TextStyle(fontSize: 10, color: soft, lineSpacing: 4)),
          ])),
          pw.SizedBox(width: 80),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FECHA', style: pw.TextStyle(
                fontSize: 8.5, color: faint, letterSpacing: 1.5)),
            pw.SizedBox(height: 8),
            pw.Text('Emisión: ${_dFecha(factura, anio)}',
                style: pw.TextStyle(fontSize: 10, color: soft)),
            pw.Text('Vto: 30 días',
                style: pw.TextStyle(fontSize: 10, color: soft)),
          ]),
        ]),
        pw.SizedBox(height: factura?.esRectificativa == true ? 16 : 50),
        // Bloque legal rectificativa (Art. 15 RD 1619/2012)
        if (factura?.esRectificativa == true) ...[
          _dBloqueRectificativa(factura!),
          pw.SizedBox(height: 24),
        ],
        // Table minimal
        pw.Table(
          columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FixedColumnWidth(40),
              2: const pw.FixedColumnWidth(70), 3: const pw.FixedColumnWidth(70)},
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(border: pw.Border(
                  bottom: pw.BorderSide(color: ink, width: 1))),
              children: ['CONCEPTO', 'CANT.', 'PRECIO', 'IMPORTE'].map((h) =>
                pw.Padding(padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Text(h, style: pw.TextStyle(fontSize: 8.5,
                      color: faint, letterSpacing: 1)))).toList(),
            ),
            ..._lineas.map((l) => pw.TableRow(
              decoration: pw.BoxDecoration(border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColor.fromHex('#F0F0F0')))),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 14),
                    child: pw.Text(l.desc, style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold, color: ink))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 14),
                    child: pw.Text('${l.qty}', style: pw.TextStyle(fontSize: 12, color: soft))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 14),
                    child: pw.Text(_fmtNum(l.price), style: pw.TextStyle(fontSize: 12, color: soft))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 14),
                    child: pw.Text(_fmtNum(l.total), style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold, color: ink))),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 36),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.SizedBox(width: 260, child: pw.Column(children: [
            _d2TRow('Base imponible', _fmtNum(_dBase(factura)), soft, ink),
            _d2TRow('IVA', _fmtNum(_dIva(factura)), soft, ink),
            pw.SizedBox(height: 6),
            pw.Divider(color: ink, thickness: 1),
            pw.SizedBox(height: 8),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total', style: pw.TextStyle(fontSize: 20, color: ink)),
              pw.Text(_fmtNum(_dTotal(factura)), style: pw.TextStyle(fontSize: 22, color: ink)),
            ]),
          ])),
        ]),
        pw.SizedBox(height: 24),
        // Disclaimer proforma
        if (factura?.esProforma == true) ...[
          pw.Center(child: _dBloqueProforma()),
          pw.SizedBox(height: 16),
        ],
        pw.Row(children: [
          pw.Expanded(child: _d2FooterCol('PAGO', 'IBAN ES00 0000 0000 0000 0000\nTransferencia bancaria')),
          pw.SizedBox(width: 60),
          pw.Expanded(child: _d2FooterCol('NOTAS', _dFooterLegal(factura))),
        ]),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _d2TRow(String l, String r, PdfColor soft, PdfColor ink) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 7),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(l, style: pw.TextStyle(fontSize: 11, color: soft)),
        pw.Text(r, style: pw.TextStyle(fontSize: 11, color: soft)),
      ]));

  static pw.Widget _d2FooterCol(String lbl, String val) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(lbl, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#222'),
          fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
      pw.SizedBox(height: 5),
      pw.Text(val, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#999'), lineSpacing: 4)),
    ]);

  // ── D3: Moderno Hero ──────────────────────────────────────────────────────
  static Future<Uint8List> _pdfD3Hero({
    required String primario, required String nombreEmpresa,
    String? cifEmpresa, Uint8List? logoBytes, required int anio,
    Factura? factura,
  }) async {
    final heroColor = PdfColor.fromHex(primario.isNotEmpty ? primario : '#7C6CF0');
    final (fontR, fontB) = await _FC.nB;
    final pdf   = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final _lineas = _dLineas(factura);

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero),
      build: (ctx) => [
        // Hero
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(48, 44, 48, 36),
          color: heroColor,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(nombreEmpresa, style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.Text(cifEmpresa != null ? 'CIF $cifEmpresa · Madrid' : 'Madrid',
                    style: pw.TextStyle(fontSize: 11,
                        color: PdfColor(1, 1, 1, 0.75))),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Total a pagar', style: pw.TextStyle(fontSize: 11,
                    color: PdfColor(1, 1, 1, 0.75))),
                pw.Text(_fmtNum(_dTotal(factura)), style: pw.TextStyle(
                    fontSize: 34, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ]),
            ]),
            pw.SizedBox(height: 20),
            pw.Row(children: [
              _d3Pill('Factura Nº ${_dNumFactura(factura, anio)}'),
              pw.SizedBox(width: 10),
              _d3Pill('Emitida ${_dFecha(factura, anio)}'),
              pw.SizedBox(width: 10),
              _d3Pill('Vence 30 días'),
            ]),
          ]),
        ),
        // Body
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(48, 32, 48, 32),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(children: [
              pw.Expanded(child: _d3Card('Emisor', nombreEmpresa,
                  cifEmpresa != null ? 'CIF $cifEmpresa' : '', heroColor)),
              pw.SizedBox(width: 20),
              pw.Expanded(child: _d3Card('Cliente', _dClienteNombre(factura),
                  _dClienteNif(factura), heroColor)),
            ]),
            pw.SizedBox(height: factura?.esRectificativa == true ? 16 : 28),
            // Bloque legal rectificativa (Art. 15 RD 1619/2012)
            if (factura?.esRectificativa == true) ...[
              _dBloqueRectificativa(factura!),
              pw.SizedBox(height: 12),
            ],
            pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FixedColumnWidth(36),
                  2: const pw.FixedColumnWidth(60), 3: const pw.FixedColumnWidth(36),
                  4: const pw.FixedColumnWidth(60)},
              children: [
                pw.TableRow(children: ['CONCEPTO', 'CANT.', 'PRECIO', 'IVA', 'IMPORTE'].map((h) =>
                  pw.Padding(padding: const pw.EdgeInsets.only(left: 12, bottom: 10),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 9,
                        color: PdfColor.fromHex('#AAA'), letterSpacing: 0.5, fontWeight: pw.FontWeight.bold)))).toList()),
                ..._lineas.map((l) => pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFfafafc)),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(l.desc, style: pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('${l.qty}', style: pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(_fmtNum(l.price), style: pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('${l.iva.toInt()}%', style: pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(_fmtNum(l.total), style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold))),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.SizedBox(width: 270, child: pw.Column(children: [
                _simpleTRow('Base imponible', _fmtNum(_dBase(factura))),
                _simpleTRow('IVA', _fmtNum(_dIva(factura))),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1a1a1a'),
                      borderRadius: pw.BorderRadius.circular(12)),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Total', style: pw.TextStyle(color: PdfColors.white,
                        fontSize: 17, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_fmtNum(_dTotal(factura)), style: pw.TextStyle(
                        color: PdfColor(0.72, 0.68, 1.0), fontSize: 17,
                        fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
              ])),
            ]),
            // Disclaimer proforma + footer legal
            if (factura?.esProforma == true) ...[
              pw.SizedBox(height: 10),
              pw.Center(child: _dBloqueProforma()),
            ],
            pw.SizedBox(height: 12),
            pw.Text(_dFooterLegal(factura),
                style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#AAA'))),
          ]),
        ),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _d3Pill(String t) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: pw.BoxDecoration(
      color: PdfColor(1, 1, 1, 0.15), borderRadius: pw.BorderRadius.circular(20)),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 10.5, color: PdfColors.white)));

  static pw.Widget _d3Card(String lbl, String name, String detail, PdfColor c) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor(c.red, c.green, c.blue, 0.06),
        borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lbl.toUpperCase(), style: pw.TextStyle(fontSize: 9, color: c,
            fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
        pw.SizedBox(height: 5),
        pw.Text(name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        if (detail.isNotEmpty) pw.Text(detail,
            style: pw.TextStyle(fontSize: 10.5, color: PdfColor.fromHex('#666'))),
      ]),
    );

  // ── D4: Sidebar Dividido ──────────────────────────────────────────────────
  static Future<Uint8List> _pdfD4Sidebar({
    required String primario, required String nombreEmpresa,
    String? cifEmpresa, Uint8List? logoBytes, required int anio,
    Factura? factura, String? tipoDoc,
  }) async {
    final dark   = PdfColor.fromHex('#1a1a1a');
    final accent = PdfColor(0.72, 0.68, 1.0); // purple-ish
    final (fontR, fontB) = await _FC.nB;
    final pdf    = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final _lineas = _dLineas(factura);

    pdf.addPage(pw.Page(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero),
      build: (ctx) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        // Sidebar
        pw.Container(
          width: 200,
          color: dark,
          padding: const pw.EdgeInsets.all(26),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(width: 38, height: 38,
              decoration: pw.BoxDecoration(color: PdfColor(0.55, 0.52, 0.82),
                  borderRadius: pw.BorderRadius.circular(10)),
              child: pw.Center(child: pw.Text(
                nombreEmpresa.isNotEmpty ? nombreEmpresa[0].toUpperCase() : 'F',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 18,
                    fontWeight: pw.FontWeight.bold)))),
            pw.SizedBox(height: 18),
            pw.Text(nombreEmpresa, style: pw.TextStyle(color: PdfColors.white,
                fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(cifEmpresa != null ? 'CIF $cifEmpresa\nMadrid' : 'Madrid',
                style: pw.TextStyle(fontSize: 10, color: PdfColor(0.6, 0.6, 0.6), lineSpacing: 3)),
            pw.SizedBox(height: 24),
            _d4SideBlock('Facturado a', _dClienteNombre(factura), _dClienteNif(factura)),
            _d4SideBlock('Nº Factura', _dNumFactura(factura, anio), ''),
            _d4SideBlock('Emisión', _dFecha(factura, anio), ''),
            pw.Spacer(),
            pw.Divider(color: PdfColor(0.2, 0.2, 0.2), height: 16),
            pw.Text('Total a pagar', style: pw.TextStyle(fontSize: 9,
                color: PdfColor(0.6, 0.6, 0.6), letterSpacing: 0.4)),
            pw.SizedBox(height: 4),
            pw.Text(_fmtNum(_dTotal(factura)), style: pw.TextStyle(
                color: accent, fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
        // Main
        pw.Expanded(child: pw.Padding(
          padding: const pw.EdgeInsets.all(34),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(tipoDoc != null ? _capitalizar(tipoDoc) : 'Factura de servicios', style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Año $anio', style: pw.TextStyle(
                fontSize: 11, color: PdfColor.fromHex('#888'))),
            // Bloque legal rectificativa (Art. 15 RD 1619/2012)
            if (factura?.esRectificativa == true) ...[
              _dBloqueRectificativa(factura!),
              pw.SizedBox(height: 12),
            ] else pw.SizedBox(height: 24),
            pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FixedColumnWidth(36),
                  2: const pw.FixedColumnWidth(60), 3: const pw.FixedColumnWidth(60)},
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(border: pw.Border(
                      bottom: pw.BorderSide(color: dark, width: 2))),
                  children: ['CONCEPTO', 'CANT.', 'PRECIO', 'IMPORTE'].map((h) =>
                    pw.Padding(padding: const pw.EdgeInsets.only(left: 8, bottom: 10),
                      child: pw.Text(h, style: pw.TextStyle(fontSize: 9,
                          color: PdfColor.fromHex('#BBB'), letterSpacing: 0.4)))).toList()),
                ..._lineas.map((l) => pw.TableRow(
                  decoration: pw.BoxDecoration(border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColor.fromHex('#EEE')))),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: pw.Text(l.desc, style: pw.TextStyle(fontSize: 11,
                            fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(12),
                        child: pw.Text('${l.qty}', style: const pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(_fmtNum(l.price), style: const pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(12),
                        child: pw.Text(_fmtNum(l.total), style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold))),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.SizedBox(width: 220, child: pw.Column(children: [
                _simpleTRow('Base imponible', _fmtNum(_dBase(factura))),
                _simpleTRow('IVA', _fmtNum(_dIva(factura))),
              ])),
            ]),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F7F7F7'),
                  borderRadius: pw.BorderRadius.circular(10)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('DATOS DE PAGO', style: pw.TextStyle(fontSize: 9,
                    fontWeight: pw.FontWeight.bold, letterSpacing: 0.4)),
                pw.SizedBox(height: 4),
                pw.Text('IBAN ES00 0000 0000 0000 0000 — Transferencia bancaria. Gracias por confiar en $nombreEmpresa.',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#666'), lineSpacing: 3)),
              ]),
            ),
            if (factura?.esProforma == true) ...[
              pw.SizedBox(height: 10),
              pw.Center(child: _dBloqueProforma()),
            ],
            pw.SizedBox(height: 8),
            pw.Text(_dFooterLegal(factura),
                style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#AAA'))),
          ]),
        )),
      ]),
    ));
    return pdf.save();
  }

  static pw.Widget _d4SideBlock(String lbl, String val, String sub) =>
    pw.Padding(padding: const pw.EdgeInsets.only(bottom: 20), child:
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lbl.toUpperCase(), style: pw.TextStyle(fontSize: 8.5,
            color: PdfColor(0.47, 0.47, 0.47), letterSpacing: 0.6)),
        pw.SizedBox(height: 4),
        pw.Text(val, style: pw.TextStyle(color: PdfColors.white,
            fontSize: 12, fontWeight: pw.FontWeight.bold)),
        if (sub.isNotEmpty) pw.Text(sub,
            style: pw.TextStyle(fontSize: 10, color: PdfColor(0.67, 0.67, 0.67))),
      ]));

  // ── D5: Tarjetas por línea ────────────────────────────────────────────────
  static Future<Uint8List> _pdfD5Cards({
    required String primario, required String nombreEmpresa,
    String? cifEmpresa, Uint8List? logoBytes, required int anio,
    Factura? factura, String? tipoDoc,
  }) async {
    final green  = PdfColor.fromHex(primario.isNotEmpty ? primario : '#3E9C63');
    final (fontR, fontB) = await _FC.nB;
    final pdf    = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final _lineas = _dLineas(factura);

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(44, 40, 44, 40)),
      build: (ctx) => [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 17,
                fontWeight: pw.FontWeight.bold)),
            pw.Text(cifEmpresa != null ? 'CIF $cifEmpresa · Madrid' : 'Madrid',
                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#999'))),
          ]),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor(green.red, green.green, green.blue, 0.1),
              borderRadius: pw.BorderRadius.circular(20)),
            child: pw.Text('${tipoDoc != null ? _capitalizar(tipoDoc) : 'Factura'} No ${_dNumFactura(factura, anio)}',
                style: pw.TextStyle(color: green, fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold))),
        ]),
        pw.SizedBox(height: 18),
        pw.Text(_fmtNum(_dTotal(factura)), style: pw.TextStyle(fontSize: 32,
            fontWeight: pw.FontWeight.bold)),
        pw.Text('Total a pagar — ${_dFecha(factura, anio)}',
            style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#888'))),
        pw.SizedBox(height: 24),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('EMISOR', style: pw.TextStyle(fontSize: 9,
                color: PdfColor.fromHex('#AAA'), fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ])),
          pw.SizedBox(width: 40),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 9,
                color: PdfColor.fromHex('#AAA'), fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(_dClienteNombre(factura), style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ])),
        ]),
        pw.Divider(height: 28, borderStyle: pw.BorderStyle.dashed,
            color: PdfColor.fromHex('#EEE')),
        // Bloque legal rectificativa (Art. 15 RD 1619/2012)
        if (factura?.esRectificativa == true) ...[
          _dBloqueRectificativa(factura!),
          pw.SizedBox(height: 12),
        ],
        pw.Text('CONCEPTOS FACTURADOS', style: pw.TextStyle(fontSize: 10,
            color: PdfColor.fromHex('#AAA'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
        pw.SizedBox(height: 12),
        ..._lineas.map((l) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FAFAFA'),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColor.fromHex('#F0F0F0'))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Row(children: [
              pw.Container(width: 36, height: 36,
                decoration: pw.BoxDecoration(
                  color: PdfColor(green.red, green.green, green.blue, 0.1),
                  borderRadius: pw.BorderRadius.circular(9)),
                child: pw.Center(child: pw.Text('*',
                    style: pw.TextStyle(color: green, fontSize: 14, fontWeight: pw.FontWeight.bold)))),
              pw.SizedBox(width: 14),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(l.desc, style: pw.TextStyle(fontSize: 12,
                    fontWeight: pw.FontWeight.bold)),
                pw.Text('${l.qty} ud. · IVA ${l.iva.toInt()}%',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#999'))),
              ]),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(_fmtNum(l.total), style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ]),
          ]),
        )),
        pw.Divider(height: 24, borderStyle: pw.BorderStyle.dashed,
            color: PdfColor.fromHex('#EEE')),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.SizedBox(width: 260, child: pw.Column(children: [
            _simpleTRow('Base imponible', _fmtNum(_dBase(factura))),
            _simpleTRow('IVA', _fmtNum(_dIva(factura))),
            pw.SizedBox(height: 8),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Total', style: pw.TextStyle(fontSize: 20,
                  fontWeight: pw.FontWeight.bold)),
              pw.Text(_fmtNum(_dTotal(factura)), style: pw.TextStyle(fontSize: 20,
                  fontWeight: pw.FontWeight.bold)),
            ]),
          ])),
        ]),
        pw.SizedBox(height: 24),
        pw.Center(child: pw.Text(
          'IBAN ES00 0000 0000 0000 0000 · Transferencia · Gracias por confiar en $nombreEmpresa',
          style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#999')),
          textAlign: pw.TextAlign.center)),
        if (factura?.esProforma == true) ...[
          pw.SizedBox(height: 12),
          pw.Center(child: _dBloqueProforma()),
        ],
        pw.SizedBox(height: 8),
        pw.Text(_dFooterLegal(factura),
            style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#AAA'))),
      ],
    ));
    return pdf.save();
  }

  // ── D6: Dark Mode ─────────────────────────────────────────────────────────
  static Future<Uint8List> _pdfD6Dark({
    required String primario, required String nombreEmpresa,
    String? cifEmpresa, Uint8List? logoBytes, required int anio,
    Factura? factura, String? tipoDoc,
  }) async {
    final bgCol  = PdfColor.fromHex('#0F0F13');
    final surf   = PdfColor.fromHex('#17171D');
    final border = PdfColor.fromHex('#24242C');
    final accent = PdfColor.fromHex(primario.isNotEmpty ? primario : '#A79BFF');
    final textW  = PdfColor.fromHex('#E8E8EA');
    final textS  = PdfColor.fromHex('#8A8A94');
    final (fontR, fontB) = await _FC.nB;
    final pdf    = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final _lineas = _dLineas(factura);

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(48),
          theme: pw.ThemeData.withFont(base: fontR, bold: fontB)),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(color: bgCol, border: pw.Border.all(color: border),
              borderRadius: pw.BorderRadius.circular(14)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(nombreEmpresa, style: pw.TextStyle(color: textW,
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(cifEmpresa != null ? 'CIF $cifEmpresa' : '',
                    style: pw.TextStyle(fontSize: 10, color: textS)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColor(accent.red, accent.green, accent.blue, 0.15),
                    borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Text(_dTipoDoc(factura, tipoDoc), style: pw.TextStyle(
                      color: accent, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5))),
                pw.SizedBox(height: 8),
                pw.Text(_dNumFactura(factura, anio), style: pw.TextStyle(
                    color: textW, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(_dFecha(factura, anio), style: pw.TextStyle(fontSize: 10, color: textS)),
              ]),
            ]),
            pw.SizedBox(height: 20),
            pw.Row(children: [
              pw.Expanded(child: _d6Card('Emisor', nombreEmpresa,
                  cifEmpresa != null ? 'CIF $cifEmpresa' : '', surf, border, textW, textS)),
              pw.SizedBox(width: 20),
              pw.Expanded(child: _d6Card('Cliente', _dClienteNombre(factura),
                  _dClienteNif(factura), surf, border, textW, textS)),
            ]),
            // Bloque legal rectificativa (Art. 15 RD 1619/2012)
            if (factura?.esRectificativa == true) ...[
              _dBloqueRectificativa(factura!),
              pw.SizedBox(height: 12),
            ] else pw.SizedBox(height: 20),
            // Table header
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: 8), child:
              pw.Row(children: ['CONCEPTO', 'CANT.', 'PRECIO', 'IMPORTE'].asMap().entries.map((e) =>
                e.key == 0
                  ? pw.Expanded(child: pw.Text(e.value, style: pw.TextStyle(
                      fontSize: 8.5, color: textS, letterSpacing: 0.5)))
                  : pw.SizedBox(width: 55, child: pw.Text(e.value, textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 8.5, color: textS, letterSpacing: 0.5)))
              ).toList())),
            pw.Divider(color: border, height: 1),
            ..._lineas.map((l) => pw.Column(children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10), child:
                pw.Row(children: [
                  pw.Expanded(child: pw.Text(l.desc, style: pw.TextStyle(
                      color: textW, fontSize: 11, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: 55, child: pw.Text('${l.qty}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(color: textS, fontSize: 11))),
                  pw.SizedBox(width: 55, child: pw.Text(_fmtNum(l.price),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(color: textS, fontSize: 11))),
                  pw.SizedBox(width: 55, child: pw.Text(_fmtNum(l.total),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(color: textW, fontSize: 11,
                          fontWeight: pw.FontWeight.bold))),
                ])),
              pw.Divider(color: PdfColor.fromHex('#1D1D24'), height: 1),
            ])),
            pw.SizedBox(height: 16),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.SizedBox(width: 260, child: pw.Column(children: [
                _d6TRow('Base imponible', _fmtNum(_dBase(factura)), textS),
                _d6TRow('IVA', _fmtNum(_dIva(factura)), textS),
                pw.SizedBox(height: 6),
                pw.Divider(color: border, height: 1),
                pw.SizedBox(height: 8),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Total', style: pw.TextStyle(color: textW,
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_fmtNum(_dTotal(factura)), style: pw.TextStyle(
                      color: accent, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                ]),
              ])),
            ]),
            pw.SizedBox(height: 20),
            pw.Divider(color: border, height: 1),
            pw.SizedBox(height: 14),
            pw.Row(children: [
              pw.Expanded(child: _d6FooterCol('PAGO',
                  'IBAN ES00 0000 0000 0000 0000', textS, textW)),
              pw.Expanded(child: _d6FooterCol('NOTAS',
                  _dFooterLegal(factura), textS, textW)),
            ]),
            if (factura?.esProforma == true) ...[
              pw.SizedBox(height: 10),
              pw.Center(child: _dBloqueProforma()),
            ],
          ]),
        ),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _d6Card(String lbl, String name, String detail,
      PdfColor surf, PdfColor border, PdfColor textW, PdfColor textS) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(color: surf, border: pw.Border.all(color: border),
          borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lbl.toUpperCase(), style: pw.TextStyle(fontSize: 8.5,
            color: textS, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
        pw.SizedBox(height: 5),
        pw.Text(name, style: pw.TextStyle(color: textW,
            fontSize: 12, fontWeight: pw.FontWeight.bold)),
        if (detail.isNotEmpty) pw.Text(detail,
            style: pw.TextStyle(fontSize: 10, color: textS)),
      ]));

  static pw.Widget _d6TRow(String l, String r, PdfColor c) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child:
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(l, style: pw.TextStyle(fontSize: 11, color: c)),
        pw.Text(r, style: pw.TextStyle(fontSize: 11, color: c)),
      ]));

  static pw.Widget _d6FooterCol(String lbl, String val, PdfColor textS, PdfColor textW) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(lbl, style: pw.TextStyle(fontSize: 9, color: textW,
          fontWeight: pw.FontWeight.bold, letterSpacing: 0.4)),
      pw.SizedBox(height: 4),
      pw.Text(val, style: pw.TextStyle(fontSize: 10, color: textS, lineSpacing: 3)),
    ]);

  // ── D7: Compacto Ejecutivo ────────────────────────────────────────────────
  static Future<Uint8List> _pdfD7Exec({
    required String nombreEmpresa, String? cifEmpresa,
    Uint8List? logoBytes, required int anio,
    Factura? factura, String? tipoDoc,
  }) async {
    final (fontR, fontB) = await _FC.nB;
    final pdf   = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final _lineas = _dLineas(factura);
    final ink   = PdfColor.fromHex('#1a1a1a');
    final light = PdfColor.fromHex('#F2F2F2');
    final soft  = PdfColor.fromHex('#555');
    final green = PdfColor.fromHex('#3E9C63');

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32)),
      build: (ctx) => [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: ink, width: 2))),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 15,
                  fontWeight: pw.FontWeight.bold)),
              pw.Text(cifEmpresa != null ? 'CIF $cifEmpresa' : 'Madrid',
                  style: pw.TextStyle(fontSize: 10, color: soft)),
            ]),
            // Stamp
            pw.Transform.rotate(angle: 0.14, child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: green, width: 2.5),
                borderRadius: pw.BorderRadius.circular(5)),
              child: pw.Text('PAGADO', style: pw.TextStyle(color: green,
                  fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
            )),
          ]),
        ),
        pw.SizedBox(height: 12),
        // Meta grid
        pw.Table(
          border: pw.TableBorder.all(color: ink, width: 1),
          columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth(),
              2: pw.FlexColumnWidth(), 3: pw.FlexColumnWidth()},
          children: [
            pw.TableRow(children: [
              _d7Cell('${tipoDoc ?? 'FACTURA'} Nº', _dNumFactura(factura, anio), light, soft, ink),
              _d7Cell('EMISIÓN', _dFecha(factura, anio), light, soft, ink),
              _d7Cell('CLIENTE', _dClienteNombre(factura), light, soft, ink),
              _d7Cell('TOTAL', _fmtNum(_dTotal(factura)), light, soft, ink, bold: true),
            ]),
          ],
        ),
        pw.SizedBox(height: 12),
        // Table
        pw.Table(
          border: pw.TableBorder.all(color: ink, width: 1),
          columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FixedColumnWidth(40),
              2: const pw.FixedColumnWidth(60), 3: const pw.FixedColumnWidth(60)},
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: light),
              children: ['CONCEPTO', 'CANT.', 'PRECIO', 'IMPORTE'].map((h) =>
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(h, style: pw.TextStyle(fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold, letterSpacing: 0.3)))).toList()),
            ..._lineas.map((l) => pw.TableRow(
              decoration: pw.BoxDecoration(border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColor.fromHex('#DDD')))),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(l.desc, style: const pw.TextStyle(fontSize: 11))),
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${l.qty}', style: const pw.TextStyle(fontSize: 11))),
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_fmtNum(l.price), style: const pw.TextStyle(fontSize: 11))),
                pw.Padding(padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_fmtNum(l.total), style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold))),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 10),
        // Totals box
        pw.Table(
          border: pw.TableBorder.all(color: ink, width: 1),
          children: [
            _d7TRow2('Base imponible', _fmtNum(_dBase(factura)), ink, PdfColors.white),
            _d7TRow2('IVA', _fmtNum(_dIva(factura)), ink, PdfColors.white),
            _d7TRow2('TOTAL', _fmtNum(_dTotal(factura)), PdfColors.white, ink, bold: true),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 10),
          decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(
              color: ink, style: pw.BorderStyle.dashed))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(
              'IBAN ES00 0000 0000 0000 0000 — Transferencia bancaria',
              style: pw.TextStyle(fontSize: 9, color: soft, lineSpacing: 3)),
            pw.SizedBox(height: 3),
            pw.Text(_dFooterLegal(factura),
                style: pw.TextStyle(fontSize: 8, color: soft)),
            if (factura?.esProforma == true) ...[
              pw.SizedBox(height: 8),
              _dBloqueProforma(),
            ],
          ]),
        ),
        if (factura?.esRectificativa == true) ...[
          pw.SizedBox(height: 10),
          _dBloqueRectificativa(factura!),
        ],
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _d7Cell(String lbl, String val,
      PdfColor bg, PdfColor soft, PdfColor ink, {bool bold = false}) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(9),
      color: bg,
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lbl, style: pw.TextStyle(fontSize: 8, color: soft, letterSpacing: 0.3)),
        pw.SizedBox(height: 2),
        pw.Text(val, style: pw.TextStyle(fontSize: 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: ink)),
      ]));

  static pw.TableRow _d7TRow2(String l, String r,
      PdfColor fg, PdfColor bg, {bool bold = false}) =>
    pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: [
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Text(l, style: pw.TextStyle(fontSize: 11,
                color: fg, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Text(r, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11,
                color: fg, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
      ]);

  // ── Shared helper ────────────────────────────────────────────────────────
  static pw.Widget _simpleTRow(String l, String r) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child:
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(l, style: pw.TextStyle(fontSize: 11.5, color: PdfColor.fromHex('#666'))),
        pw.Text(r, style: pw.TextStyle(fontSize: 11.5, color: PdfColor.fromHex('#666'))),
      ]));

  // ══════════════════════════════════════════════════════════════════════════
  // INFORMES — 3 diseños del HTML informe.html
  // ══════════════════════════════════════════════════════════════════════════

  // Datos demo compartidos
  static const _infLineas = [
    ('Lun 28/10', '09:00', '17:30', '30m', '8h 00m'),
    ('Mar 29/10', '09:00', '17:30', '30m', '8h 00m'),
    ('Mié 30/10', '09:00', '19:00', '30m', '9h 30m'),
    ('Jue 31/10', '09:00', '17:30', '30m', '8h 00m'),
  ];
  static const _infNombre = 'Samuel Martín Ortega';
  static const _infPuesto = 'Encargado de sala';

  // D1: Clásico Corporativo para informes
  static Future<Uint8List> _pdfInformeD1({
    required String primario, required bool esHoras,
    required String nombreEmpresa, Uint8List? logoBytes, required int anio,
  }) async {
    final bandColor = PdfColor.fromHex(primario);
    final (fontR, fontB) = await _FC.nB;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final titulo = esHoras ? 'INFORME DE HORAS' : 'INFORME INTERNO';
    final subDoc = esHoras ? 'Octubre $anio · $nombreEmpresa' : 'Cierre de caja diario';

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero),
      build: (ctx) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(48, 36, 48, 36),
          color: bandColor,
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(nombreEmpresa.toUpperCase(), style: pw.TextStyle(color: PdfColors.white,
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(esHoras ? 'Departamento: Sala y Barra' : 'Local: Restaurante Centro',
                  style: pw.TextStyle(color: PdfColor(1,1,1,0.75), fontSize: 10)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(titulo, style: pw.TextStyle(color: PdfColors.white,
                  fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              pw.Text(subDoc, style: pw.TextStyle(color: PdfColor(1,1,1,0.75), fontSize: 11)),
            ]),
          ]),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(48, 28, 48, 32),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (esHoras) ...[
              pw.Row(children: [
                pw.Expanded(child: _infParty('Empleado', _infNombre, _infPuesto)),
                pw.SizedBox(width: 24),
                pw.Expanded(child: _infParty('Supervisor', 'Laura Gómez', 'Responsable RRHH')),
              ]),
              pw.Divider(color: PdfColor.fromHex('#E5E5E5'), height: 28),
              // KPIs
              pw.Row(children: [
                _infKpi('168h', 'Horas trabajadas', bandColor),
                pw.SizedBox(width: 12),
                _infKpi('6h', 'Horas extra', PdfColor.fromHex('#E65100')),
                pw.SizedBox(width: 12),
                _infKpi('0h', 'Ausencias', PdfColor.fromHex('#757575')),
              ]),
              pw.SizedBox(height: 20),
              // Tabla
              pw.Table(
                columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FixedColumnWidth(50),
                    2: const pw.FixedColumnWidth(50), 3: const pw.FixedColumnWidth(50),
                    4: const pw.FixedColumnWidth(60)},
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: bandColor),
                    children: ['FECHA','ENTRADA','SALIDA','PAUSA','TOTAL'].map((h) =>
                      pw.Padding(padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white,
                            fontSize: 9.5, fontWeight: pw.FontWeight.bold)))).toList()),
                  ..._infLineas.asMap().entries.map((e) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: e.key.isEven ? PdfColors.white : PdfColor.fromHex('#F8F9FB')),
                    children: [e.value.$1,e.value.$2,e.value.$3,e.value.$4,e.value.$5].map((v) =>
                      pw.Padding(padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(v, style: const pw.TextStyle(fontSize: 11)))).toList())),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: pw.BoxDecoration(color: bandColor,
                      borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text('Total horas trabajadas: 33h 30m',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ]),
            ] else ...[
              // Informe interno cierre de caja
              pw.Text('Cierre de caja diario', style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#888'))),
              pw.SizedBox(height: 20),
              pw.Row(children: [
                _infKpi('€2.480', 'Ventas totales', bandColor),
                pw.SizedBox(width: 12),
                _infKpi('142', 'Nº tickets', bandColor),
                pw.SizedBox(width: 12),
                _infKpi('€17,46', 'Ticket medio', bandColor),
              ]),
              pw.SizedBox(height: 20),
              pw.Table(
                columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FixedColumnWidth(80),
                    2: const pw.FixedColumnWidth(80), 3: const pw.FixedColumnWidth(60)},
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: bandColor),
                    children: ['MÉTODO DE PAGO','Nº OPERACIONES','IMPORTE','%'].map((h) =>
                      pw.Padding(padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white,
                            fontSize: 9.5, fontWeight: pw.FontWeight.bold)))).toList()),
                  ...['Tarjeta|98|€1.720,00|69%', 'Efectivo|38|€620,00|25%',
                       'Bizum/App|6|€140,00|6%'].asMap().entries.map((e) {
                    final parts = e.value.split('|');
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: e.key.isEven ? PdfColors.white : PdfColor.fromHex('#F8F9FB')),
                      children: parts.map((v) => pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text(v, style: const pw.TextStyle(fontSize: 11)))).toList());
                  }),
                ],
              ),
            ],
            pw.SizedBox(height: 24),
            _infFirmas(),
          ]),
        ),
      ],
    ));
    return pdf.save();
  }

  // D2: Minimalista para informes
  static Future<Uint8List> _pdfInformeD2({
    required String primario, required bool esHoras,
    required String nombreEmpresa, Uint8List? logoBytes, required int anio,
  }) async {
    final acc = PdfColor.fromHex(primario);
    final (fontR, fontB) = await _FC.nB;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final titulo = esHoras ? 'INFORME DE HORAS' : 'INFORME INTERNO';

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(64, 60, 64, 60)),
      build: (ctx) => [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(nombreEmpresa.toUpperCase(), style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
            pw.Text(esHoras ? 'RRHH · Octubre $anio' : 'OPERACIONES · ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#999'), letterSpacing: 0.5)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(titulo, style: pw.TextStyle(
                fontSize: 9, color: PdfColor.fromHex('#999'), letterSpacing: 3)),
            pw.Text(esHoras ? _infNombre : 'Cierre diario', style: pw.TextStyle(
                fontSize: 22, color: PdfColor.fromHex('#222'))),
          ]),
        ]),
        pw.SizedBox(height: 30),
        pw.Text(esHoras ? 'Horas acumuladas en el período' : 'Resumen de operaciones del día',
            style: pw.TextStyle(fontSize: 10, color: acc)),
        pw.SizedBox(height: 10),
        pw.Row(children: esHoras
            ? [_infKpiMin('168h', 'Horas'), _infKpiMin('6h', 'Extra'), _infKpiMin('0h', 'Ausencias')]
            : [_infKpiMin('€2.480', 'Ventas'), _infKpiMin('142', 'Tickets'), _infKpiMin('€17,46', 'Ticket medio')]),
        pw.SizedBox(height: 30),
        pw.Divider(color: PdfColor.fromHex('#222'), height: 1),
        pw.SizedBox(height: 16),
        if (esHoras) ...[
          pw.Table(
            columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FixedColumnWidth(50),
                2: const pw.FixedColumnWidth(50), 3: const pw.FixedColumnWidth(60)},
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColor.fromHex('#222')))),
                children: ['FECHA','ENTRADA','SALIDA','TOTAL'].map((h) =>
                  pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8.5,
                        color: PdfColor.fromHex('#BBB'), letterSpacing: 1)))).toList()),
              ..._infLineas.map((l) => pw.TableRow(
                decoration: pw.BoxDecoration(border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColor.fromHex('#F0F0F0')))),
                children: [l.$1, l.$2, l.$3, l.$5].map((v) =>
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 14),
                    child: pw.Text(v, style: const pw.TextStyle(fontSize: 12)))).toList())),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Divider(color: PdfColor.fromHex('#222'), height: 1),
              pw.SizedBox(height: 8),
              pw.Text('Total: 33h 30m', style: pw.TextStyle(fontSize: 20,
                  color: PdfColor.fromHex('#222'))),
            ]),
          ]),
        ],
        pw.SizedBox(height: 40),
        _infFirmas(),
      ],
    ));
    return pdf.save();
  }

  // D3: Hero para informes
  static Future<Uint8List> _pdfInformeD3({
    required String primario, required bool esHoras,
    required String nombreEmpresa, Uint8List? logoBytes, required int anio,
  }) async {
    final heroColor = PdfColor.fromHex(primario);
    final (fontR, fontB) = await _FC.nB;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final titulo = esHoras ? 'INFORME DE HORAS' : 'INFORME INTERNO';
    final kpiVal = esHoras ? '33h 30m' : '€2.480';
    final kpiLbl = esHoras ? 'Horas acumuladas' : 'Ventas del día';

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero),
      build: (ctx) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(48, 44, 48, 36),
          color: heroColor,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(nombreEmpresa, style: pw.TextStyle(color: PdfColors.white,
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(esHoras ? 'Departamento: Sala' : 'Local: Restaurante Centro',
                    style: pw.TextStyle(fontSize: 11, color: PdfColor(1,1,1,0.75))),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(kpiLbl, style: pw.TextStyle(color: PdfColor(1,1,1,0.75), fontSize: 11)),
                pw.Text(kpiVal, style: pw.TextStyle(color: PdfColors.white,
                    fontSize: 34, fontWeight: pw.FontWeight.bold)),
              ]),
            ]),
            pw.SizedBox(height: 20),
            pw.Row(children: [
              _d3Pill(titulo),
              pw.SizedBox(width: 10),
              _d3Pill(esHoras ? _infNombre : DateFormat('dd/MM/yyyy').format(DateTime.now())),
              pw.SizedBox(width: 10),
              _d3Pill('Octubre $anio'),
            ]),
          ]),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(48, 28, 48, 32),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(children: esHoras
                ? [_infKpi('168h', 'Horas\ntrabajadas', heroColor), pw.SizedBox(width: 12),
                   _infKpi('6h', 'Horas\nextra', PdfColor.fromHex('#E65100')), pw.SizedBox(width: 12),
                   _infKpi('0h', 'Ausencias', PdfColor.fromHex('#757575')), pw.SizedBox(width: 12),
                   _infKpi('21', 'Días\ntrabajados', heroColor)]
                : [_infKpi('€2.480', 'Ventas', heroColor), pw.SizedBox(width: 12),
                   _infKpi('142', 'Tickets', heroColor), pw.SizedBox(width: 12),
                   _infKpi('€17,46', 'Ticket\nmedio', heroColor), pw.SizedBox(width: 12),
                   _infKpi('€86', 'Propinas', PdfColor.fromHex('#E65100'))]),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColor.fromHex('#E5E5E5'), height: 1),
            pw.SizedBox(height: 16),
            if (esHoras)
              pw.Table(
                columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FixedColumnWidth(50),
                    2: const pw.FixedColumnWidth(50), 3: const pw.FixedColumnWidth(60)},
                children: [
                  pw.TableRow(children: ['FECHA','ENTRADA','SALIDA','TOTAL'].map((h) =>
                    pw.Padding(padding: const pw.EdgeInsets.only(left: 10, bottom: 8),
                      child: pw.Text(h, style: pw.TextStyle(fontSize: 9,
                          color: PdfColor.fromHex('#AAA'), fontWeight: pw.FontWeight.bold)))).toList()),
                  ..._infLineas.map((l) => pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFfafafc)),
                    children: [l.$1, l.$2, l.$3, l.$5].map((v) =>
                      pw.Padding(padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(v, style: const pw.TextStyle(fontSize: 11)))).toList())),
                ]),
            pw.SizedBox(height: 24),
            _infFirmas(),
          ]),
        ),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _infParty(String lbl, String name, String sub) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(lbl.toUpperCase(), style: pw.TextStyle(fontSize: 9,
          color: PdfColor.fromHex('#8A8A8A'), fontWeight: pw.FontWeight.bold, letterSpacing: 0.6)),
      pw.SizedBox(height: 4),
      pw.Text(name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Text(sub, style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#555'))),
    ]);

  static pw.Widget _infKpi(String val, String lbl, PdfColor c) =>
    pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor(c.red, c.green, c.blue, 0.07),
        borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lbl, style: pw.TextStyle(fontSize: 8.5,
            color: PdfColor.fromHex('#999'), letterSpacing: 0.4)),
        pw.SizedBox(height: 5),
        pw.Text(val, style: pw.TextStyle(fontSize: 18,
            fontWeight: pw.FontWeight.bold, color: c)),
      ]),
    ));

  static pw.Widget _infKpiMin(String val, String lbl) =>
    pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(lbl, style: pw.TextStyle(fontSize: 8.5,
          color: PdfColor.fromHex('#BBB'), letterSpacing: 1)),
      pw.SizedBox(height: 4),
      pw.Text(val, style: pw.TextStyle(fontSize: 20, color: PdfColor.fromHex('#222'))),
    ]));

  static pw.Widget _infFirmas() => pw.Row(children: [
    pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(height: 1, color: PdfColor.fromHex('#999'),
          margin: const pw.EdgeInsets.only(bottom: 6)),
      pw.Text('Firma del empleado', style: pw.TextStyle(
          fontSize: 10.5, color: PdfColor.fromHex('#666'))),
    ])),
    pw.SizedBox(width: 36),
    pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(height: 1, color: PdfColor.fromHex('#999'),
          margin: const pw.EdgeInsets.only(bottom: 6)),
      pw.Text('Firma del responsable', style: pw.TextStyle(
          fontSize: 10.5, color: PdfColor.fromHex('#666'))),
    ])),
  ]);

  // ── Preview de Horas / Fichajes ──────────────────────────────────────────
  static Future<Uint8List> _generarPdfHoras({
    required String primario, required String secundario,
    required String nombreEmpresa, Uint8List? logoBytes, required int anio,
  }) async {
    final colPrim = PdfColor.fromHex(primario);
    final colSec  = PdfColor.fromHex(secundario);
    final (fontR, fontB) = await _FC.nB;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));

    final fichajes = [
      ('01/$anio', '09:00', '18:00', '8h 00m', false),
      ('02/$anio', '08:45', '17:30', '7h 45m', false),
      ('03/$anio', '09:15', '19:30', '10h 15m', true),
      ('04/$anio', '09:00', '18:00', '8h 00m', false),
      ('05/$anio', '08:30', '17:00', '8h 30m', false),
    ];

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
      ),
      build: (ctx) => [
        // Cabecera
        pw.Container(
          width: double.infinity, padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: colPrim, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (logoBytes != null) ...[
                pw.Image(pw.MemoryImage(logoBytes), width: 40, height: 40),
                pw.SizedBox(height: 6),
              ],
              pw.Text(nombreEmpresa, style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Reporte de Horas', style: pw.TextStyle(color: PdfColor(1,1,1,0.7), fontSize: 9)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('RRHH-$anio-001', style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('Período: 01-05/$anio', style: pw.TextStyle(color: PdfColor(1,1,1,0.7), fontSize: 9)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 14),
        // Info empleado
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F5F9FF'),
            border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('EMPLEADO', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: colPrim, letterSpacing: 1)),
              pw.SizedBox(height: 2),
              pw.Text('Juan García López', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('Desarrollador Senior · Dpto. Tecnología', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#757575'))),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('DNI: 12345678A', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#757575'))),
              pw.Text('Contrato: Indefinido', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#757575'))),
            ]),
          ]),
        ),
        pw.SizedBox(height: 14),
        // Tabla fichajes
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: colSec),
              children: [
                for (final h in ['FECHA', 'ENTRADA', 'SALIDA', 'DURACIÓN', 'EXTRA'])
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7), child:
                    pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.5))),
              ],
            ),
            ...fichajes.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(
                color: e.key.isEven ? PdfColors.white : PdfColor.fromHex('#F8FAFF'),
                border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#E8EAF0'), width: 0.5)),
              ),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child:
                  pw.Text(e.value.$1, style: pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child:
                  pw.Text(e.value.$2, style: pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child:
                  pw.Text(e.value.$3, style: pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child:
                  pw.Text(e.value.$4, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child:
                  pw.Text(e.value.$5 ? 'Si' : '', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#E65100'), fontWeight: pw.FontWeight.bold))),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 14),
        // Resumen
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor(colPrim.red, colPrim.green, colPrim.blue, 0.06),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColor(colPrim.red, colPrim.green, colPrim.blue, 0.2)),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _statHoras('Total horas', '42h 30m', colPrim),
            _statHoras('Horas ordinarias', '40h 00m', PdfColor.fromHex('#2E7D32')),
            _statHoras('Horas extra', '2h 30m', PdfColor.fromHex('#E65100')),
            _statHoras('Días trabajados', '5 / 5', colPrim),
          ]),
        ),
        pw.SizedBox(height: 14),
        // Firmas
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Aprobado por: ________________', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#757575'))),
          pw.Text('Empleado: ________________', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#757575'))),
        ]),
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColor.fromHex('#E0E0E0')),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text(
          'Reporte de horas — Documento interno · $nombreEmpresa',
          style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#BDBDBD')),
        )),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _statHoras(String label, String valor, PdfColor color) =>
    pw.Column(children: [
      pw.Text(valor, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#757575'))),
    ]);

  // ── Preview de Informe Interno ────────────────────────────────────────────
  static Future<Uint8List> _generarPdfInforme({
    required String primario, required String secundario,
    required String nombreEmpresa, Uint8List? logoBytes, required int anio,
  }) async {
    final colPrim = PdfColor.fromHex(primario);
    final (fontR, fontB, fontI) = await _FC.nBI;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB, italic: fontI));

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 42),
      ),
      build: (ctx) => [
        // Cabecera
        pw.Container(
          width: double.infinity, padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: colPrim, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Row(children: [
              if (logoBytes != null) ...[
                pw.Container(
                  decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(4)),
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Image(pw.MemoryImage(logoBytes), width: 36, height: 36),
                ),
                pw.SizedBox(width: 10),
              ],
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(nombreEmpresa, style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text('Informe Interno', style: pw.TextStyle(color: PdfColor(1,1,1,0.7), fontSize: 9)),
              ]),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('INF-$anio-001', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('${DateTime.now().day.toString().padLeft(2,'0')}/${DateTime.now().month.toString().padLeft(2,'0')}/$anio',
                  style: pw.TextStyle(color: PdfColor(1,1,1,0.7), fontSize: 9)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 16),
        // Título documento
        pw.Text('INFORME INTERNO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: colPrim, letterSpacing: 1.5)),
        pw.SizedBox(height: 2),
        pw.Text('CLASIFICACIÓN: CONFIDENCIAL · Uso interno exclusivo',
            style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#757575'), fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColor(colPrim.red, colPrim.green, colPrim.blue, 0.3), thickness: 1.5),
        pw.SizedBox(height: 14),
        // Meta del informe
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor(colPrim.red, colPrim.green, colPrim.blue, 0.05),
            border: pw.Border.all(color: PdfColor(colPrim.red, colPrim.green, colPrim.blue, 0.15)),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(children: [
            _filaInforme('Departamento:', 'Recursos Humanos / Dirección', colPrim),
            pw.SizedBox(height: 4),
            _filaInforme('Elaborado por:', 'Responsable de RRHH', colPrim),
            pw.SizedBox(height: 4),
            _filaInforme('Destinatario:', 'Dirección General', colPrim),
            pw.SizedBox(height: 4),
            _filaInforme('Período analizado:', 'Enero – Diciembre $anio', colPrim),
          ]),
        ),
        pw.SizedBox(height: 16),
        // Resumen ejecutivo
        pw.Text('Resumen ejecutivo', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: colPrim)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Este informe presenta los resultados y conclusiones del análisis realizado durante el período indicado. '
          'Se detallan los indicadores clave, las incidencias detectadas y las recomendaciones para su resolución.',
          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#424242'), lineSpacing: 3),
        ),
        pw.SizedBox(height: 14),
        // Cuerpo del informe (simulado)
        pw.Text('Contenido del informe', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: colPrim)),
        pw.SizedBox(height: 6),
        pw.Text(
          '1. Análisis de situación actual\n\n'
          'Los datos recopilados durante el período muestran una evolución positiva en los indicadores '
          'principales. Se han identificado áreas de mejora que se detallan en las secciones siguientes.\n\n'
          '2. Conclusiones y observaciones\n\n'
          'Tras el análisis realizado, se concluye que los objetivos planteados se han cumplido en un 87% '
          'de los casos, con desviaciones menores explicadas en el anexo adjunto.',
          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#424242'), lineSpacing: 3),
        ),
        pw.SizedBox(height: 14),
        pw.Divider(color: PdfColor.fromHex('#E0E0E0')),
        pw.SizedBox(height: 10),
        // Firmas
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Elaborado por:', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#9E9E9E'))),
            pw.SizedBox(height: 16),
            pw.Container(width: 110, height: 1, color: PdfColor.fromHex('#BDBDBD')),
            pw.SizedBox(height: 2),
            pw.Text('Firma y cargo', style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#BDBDBD'))),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Revisado por:', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#9E9E9E'))),
            pw.SizedBox(height: 16),
            pw.Container(width: 110, height: 1, color: PdfColor.fromHex('#BDBDBD')),
            pw.SizedBox(height: 2),
            pw.Text('Firma y cargo', style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#BDBDBD'))),
          ]),
        ]),
        pw.SizedBox(height: 16),
        pw.Center(child: pw.Text(
          'CONFIDENCIAL — Documento de circulación interna restringida · $nombreEmpresa',
          style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#BDBDBD')),
        )),
      ],
    ));
    return pdf.save();
  }

  static pw.Widget _filaInforme(String label, String valor, PdfColor colPrim) =>
    pw.Row(children: [
      pw.SizedBox(width: 110, child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: colPrim))),
      pw.Expanded(child: pw.Text(valor, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#424242')))),
    ]);

  // ── Layout 'linea' — minimalista con acento de línea ─────────────────────
  static Future<Uint8List> _generarPdfLinea({
    required String primario, required String secundario,
    required String nombreEmpresa, String? cifEmpresa,
    Uint8List? logoBytes, required int anio, String? tipoDoc,
  }) async {
    final colPrim = PdfColor.fromHex(primario);
    final (fontR, fontB) = await _FC.nB;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final lineas = [
      ('Servicio de consultoría', 5, 180.0, 21.0),
      ('Diseño de identidad corporativa', 1, 1200.0, 21.0),
      ('Hosting y mantenimiento web', 12, 45.0, 21.0),
    ];
    final subtotal = lineas.fold(0.0, (s, l) => s + l.$2 * l.$3);
    final iva = subtotal * 0.21;
    final total = subtotal + iva;

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 44),
      ),
      build: (ctx) => [
        // Línea de color en la parte superior
        pw.Container(height: 4, color: colPrim),
        pw.SizedBox(height: 24),
        // Header: logo/nombre empresa + número factura a la derecha
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), width: 56, height: 56)
              else
                pw.Container(
                  width: 50, height: 50,
                  decoration: pw.BoxDecoration(color: colPrim, borderRadius: pw.BorderRadius.circular(6)),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    nombreEmpresa.substring(0, 1).toUpperCase(),
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#111827'))),
              if (cifEmpresa?.isNotEmpty == true)
                pw.Text(cifEmpresa!, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#9CA3AF'))),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(tipoDoc ?? 'FACTURA', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: colPrim, letterSpacing: 3)),
              pw.Text('FAC-$anio-0001', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#374151'))),
              pw.SizedBox(height: 4),
              pw.Text('Fecha: ${DateTime.now().day}/${DateTime.now().month}/$anio', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'))),
              pw.Text('Vence: 30 días', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'))),
            ]),
          ],
        ),
        pw.SizedBox(height: 28),
        // Línea divisora sutil
        pw.Divider(color: PdfColor.fromHex('#E5E7EB'), thickness: 1),
        pw.SizedBox(height: 16),
        // Sección cliente
        pw.Text('FACTURAR A:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colPrim, letterSpacing: 1.5)),
        pw.SizedBox(height: 4),
        pw.Text('Cliente Ejemplo S.L.', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#111827'))),
        pw.Text('CIF: B12345678  ·  cliente@ejemplo.com  ·  +34 600 000 000',
            style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'))),
        pw.SizedBox(height: 24),
        // Tabla
        pw.Table(
          border: pw.TableBorder(bottom: pw.BorderSide(color: PdfColor.fromHex('#E5E7EB'))),
          columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2)},
          children: [
            // Cabecera
            pw.TableRow(
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: colPrim, width: 2))),
              children: [
                for (final h in ['DESCRIPCIÓN', 'CANT.', 'PRECIO', 'IMPORTE'])
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child:
                    pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#374151'), letterSpacing: 0.5))),
              ],
            ),
            // Líneas
            ...lineas.map((l) => pw.TableRow(
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#F3F4F6'), width: 1))),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child:
                  pw.Text(l.$1, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#111827')))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child:
                  pw.Text('${l.$2}', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#374151')))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child:
                  pw.Text('${l.$3.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#374151')))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child:
                  pw.Text('${(l.$2 * l.$3).toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#111827'), fontWeight: pw.FontWeight.bold))),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 16),
        // Totales (alineados a la derecha)
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.SizedBox(width: 220, child: pw.Column(children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Subtotal', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'))),
              pw.Text('${subtotal.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#374151'))),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('IVA 21%', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'))),
              pw.Text('${iva.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#374151'))),
            ]),
            pw.SizedBox(height: 6),
            pw.Divider(color: colPrim, thickness: 1.5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#111827'))),
              pw.Text('${total.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: colPrim)),
            ]),
          ])),
        ]),
        pw.SizedBox(height: 32),
        // Footer minimalista
        pw.Divider(color: PdfColor.fromHex('#E5E7EB')),
        pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Pago por transferencia bancaria', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#9CA3AF'))),
          pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colPrim)),
        ]),
      ],
    ));
    return pdf.save();
  }

  // ── Layout 'bold' — cabecera grande, tipografía impactante ───────────────
  static Future<Uint8List> _generarPdfBold({
    required String primario, required String secundario,
    required String nombreEmpresa, String? cifEmpresa,
    Uint8List? logoBytes, required int anio, String? tipoDoc,
  }) async {
    final colPrim  = PdfColor.fromHex(primario);
    final colSecun = PdfColor.fromHex(secundario);
    final (fontR, fontB) = await _FC.nB;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));
    final lineas = [
      ('Consultoría estratégica', 8, 120.0),
      ('Desarrollo de plataforma digital', 1, 3500.0),
      ('Soporte técnico mensual', 6, 90.0),
      ('Formación del equipo', 2, 450.0),
    ];
    final subtotal = lineas.fold(0.0, (s, l) => s + l.$2 * l.$3);
    final iva = subtotal * 0.21;

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
      ),
      build: (ctx) => [
        // Cabecera full-width con mucho color
        pw.Container(
          width: double.infinity, padding: const pw.EdgeInsets.fromLTRB(40, 36, 40, 32),
          color: colPrim,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              if (logoBytes != null)
                pw.Container(
                  decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(8)),
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Image(pw.MemoryImage(logoBytes), width: 44, height: 44),
                )
              else
                pw.Container(
                  width: 48, height: 48,
                  decoration: pw.BoxDecoration(color: PdfColor(1, 1, 1, 0.2), borderRadius: pw.BorderRadius.circular(8)),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    nombreEmpresa.substring(0, 1).toUpperCase(),
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('FAC-$anio-0001', style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.9), fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Fecha: ${DateTime.now().day}/${DateTime.now().month}/$anio',
                    style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
              ]),
            ]),
            pw.SizedBox(height: 20),
            pw.Text(tipoDoc ?? 'FACTURA', style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.55), fontSize: 10, letterSpacing: 4, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(nombreEmpresa, style: pw.TextStyle(color: PdfColors.white, fontSize: 26, fontWeight: pw.FontWeight.bold)),
            if (cifEmpresa?.isNotEmpty == true)
              pw.Text(cifEmpresa!, style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.65), fontSize: 10)),
            pw.SizedBox(height: 16),
            // Total destacado en la cabecera
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: pw.BoxDecoration(color: PdfColor(1, 1, 1, 0.15), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                pw.Text('TOTAL A PAGAR: ', style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.8), fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('${(subtotal + iva).toStringAsFixed(2)} €',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
          ]),
        ),
        // Línea de acento
        pw.Container(height: 5, color: colSecun),
        // Contenido (con márgenes laterales)
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 20, 40, 32),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // Cliente
            pw.Row(children: [
              pw.Container(width: 4, height: 40, color: colPrim),
              pw.SizedBox(width: 12),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('FACTURAR A', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colPrim, letterSpacing: 1.5)),
                pw.Text('Cliente Ejemplo S.L.', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#111827'))),
                pw.Text('CIF: B12345678  ·  cliente@ejemplo.com', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'))),
              ]),
            ]),
            pw.SizedBox(height: 24),
            // Tabla
            pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2)},
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: colPrim),
                  children: [
                    for (final h in ['DESCRIPCIÓN', 'CANT.', 'PRECIO', 'IMPORTE'])
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child:
                        pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.5))),
                  ],
                ),
                ...lineas.asMap().entries.map((e) => pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: e.key.isEven ? PdfColor.fromHex('#FAFAFA') : PdfColors.white,
                  ),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child:
                      pw.Text(e.value.$1, style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child:
                      pw.Text('${e.value.$2}', style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child:
                      pw.Text('${e.value.$3.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child:
                      pw.Text('${(e.value.$2 * e.value.$3).toStringAsFixed(2)} €',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F9FAFB'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
                ),
                child: pw.Column(children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Subtotal', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'))),
                    pw.Text('${subtotal.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 9)),
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('IVA 21%', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B7280'))),
                    pw.Text('${iva.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 9)),
                  ]),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: colPrim, thickness: 1.5),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${(subtotal + iva).toStringAsFixed(2)} €',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: colPrim)),
                  ]),
                ]),
              ),
            ]),
          ]),
        ),
      ],
    ));
    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILDERS CON DATOS REALES — layout 'linea' y 'bold' para facturas reales
  // ══════════════════════════════════════════════════════════════════════════

  /// Layout 'linea' con datos reales de la Factura.
  static Future<Uint8List> _generarPdfLineaFactura({
    required Factura factura,
    required String primario,
    required String nombreEmpresa,
    String? cifEmpresa,
    String? direccionEmpresa,
    String? telefonoEmpresa,
    String? correoEmpresa,
    String? ibanEmpresa,
    Uint8List? logoBytes,
    Uint8List? qrBytes,
    bool esVerifactu = false,
    double margenH = 48,
    double margenV = 44,
  }) async {
    final colPrim = PdfColor.fromHex(primario);
    final colGris = PdfColor.fromHex('#6B7280');
    final colTxt  = PdfColor.fromHex('#111827');
    final colSep  = PdfColor.fromHex('#E5E7EB');
    final colFila = PdfColor.fromHex('#F3F4F6');
    final (fontR, fontB, fontI) = await _FC.nBI;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB, italic: fontI));

    final subtotal = factura.subtotal - factura.importeDescuentoGlobal;
    final fmt = (double v) => '${v.toStringAsFixed(2)} €';
    final fmtDate = (DateTime d) =>
        '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.symmetric(horizontal: margenH, vertical: margenV),
      ),
      build: (ctx) => [
        // Línea de acento
        pw.Container(height: 4, color: colPrim),
        pw.SizedBox(height: 24),
        // Header: empresa + número
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), width: 52, height: 52)
              else
                pw.Container(
                  width: 44, height: 44,
                  decoration: pw.BoxDecoration(color: colPrim, borderRadius: pw.BorderRadius.circular(6)),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    nombreEmpresa.isNotEmpty ? nombreEmpresa[0].toUpperCase() : 'E',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: colTxt)),
              if (cifEmpresa?.isNotEmpty == true)
                pw.Text('NIF: $cifEmpresa', style: pw.TextStyle(fontSize: 9, color: colGris)),
              if (direccionEmpresa?.isNotEmpty == true)
                pw.Text(direccionEmpresa!, style: pw.TextStyle(fontSize: 9, color: colGris)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(
                factura.esRectificativa ? 'RECTIFICATIVA' : factura.esProforma ? 'PRESUPUESTO' : 'FACTURA',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: colPrim, letterSpacing: 2),
              ),
              pw.Text(factura.numeroFactura, style: pw.TextStyle(fontSize: 11, color: colTxt, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Emisión: ${fmtDate(factura.fechaEmision)}', style: pw.TextStyle(fontSize: 9, color: colGris)),
              if (factura.fechaVencimiento != null)
                pw.Text('Vence: ${fmtDate(factura.fechaVencimiento!)}', style: pw.TextStyle(fontSize: 9, color: colGris)),
            ]),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Divider(color: colSep, thickness: 1),
        pw.SizedBox(height: 14),
        // Cliente
        pw.Text('FACTURAR A:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colPrim, letterSpacing: 1.5)),
        pw.SizedBox(height: 4),
        pw.Text(factura.clienteNombre, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: colTxt)),
        pw.Text([
          if (factura.datosFiscales?.nif?.isNotEmpty == true) 'NIF: ${factura.datosFiscales!.nif}',
          if (factura.clienteCorreo?.isNotEmpty == true) factura.clienteCorreo!,
        ].join('  ·  '), style: pw.TextStyle(fontSize: 9, color: colGris)),
        pw.SizedBox(height: 22),
        // Tabla de líneas
        pw.Table(
          border: pw.TableBorder(bottom: pw.BorderSide(color: colSep)),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: colPrim, width: 2))),
              children: [
                for (final h in ['DESCRIPCIÓN', 'CANT.', 'P.UNIT.', 'IMPORTE'])
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child:
                    pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colGris, letterSpacing: 0.5))),
              ],
            ),
            ...factura.lineas.map((l) => pw.TableRow(
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: colFila, width: 1))),
              children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child:
                  pw.Text(l.descripcion, style: pw.TextStyle(fontSize: 10, color: colTxt))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child:
                  pw.Text('${l.cantidad}', style: pw.TextStyle(fontSize: 10, color: colGris))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child:
                  pw.Text(fmt(l.precioUnitario), style: pw.TextStyle(fontSize: 10, color: colGris))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child:
                  pw.Text(fmt(l.subtotalSinIva), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colTxt))),
              ],
            )),
          ],
        ),
        pw.SizedBox(height: 16),
        // Totales
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.SizedBox(width: 230, child: pw.Column(children: [
            _rowTotal('Base imponible', fmt(subtotal), colGris, fontSize: 9),
            if (factura.descuentoGlobal > 0)
              _rowTotal('Descuento (${factura.descuentoGlobal.toStringAsFixed(0)}%)',
                  '-${fmt(factura.importeDescuentoGlobal)}', PdfColor.fromHex('#E65100'), fontSize: 9),
            _rowTotal('IVA', fmt(factura.totalIva), colGris, fontSize: 9),
            if (factura.porcentajeIrpf > 0)
              _rowTotal('IRPF ${factura.porcentajeIrpf.toStringAsFixed(0)}%',
                  '-${fmt(factura.retencionIrpf)}', colGris, fontSize: 9),
            pw.SizedBox(height: 6),
            pw.Divider(color: colPrim, thickness: 1.5),
            _rowTotal('TOTAL', fmt(factura.total), colPrim, bold: true, fontSize: 13),
          ])),
        ]),
        // Forma de pago
        if (factura.metodoPago != null) ...[
          pw.SizedBox(height: 16),
          pw.Divider(color: colSep),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Pago: ${_lblPago(factura.metodoPago)}',
                style: pw.TextStyle(fontSize: 8, color: colGris)),
            if (ibanEmpresa?.isNotEmpty == true && factura.metodoPago == MetodoPagoFactura.transferencia)
              pw.Text('IBAN: $ibanEmpresa', style: pw.TextStyle(fontSize: 8, color: colTxt, fontWeight: pw.FontWeight.bold)),
          ]),
        ],
        // Notas
        if (factura.notasCliente?.isNotEmpty == true) ...[
          pw.SizedBox(height: 8),
          pw.Text(factura.notasCliente!, style: pw.TextStyle(fontSize: 8, color: colGris, fontStyle: pw.FontStyle.italic)),
        ],
        // QR Verifactu
        if (qrBytes != null && qrBytes.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Divider(color: colSep),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Expanded(child: pw.Text(
              esVerifactu ? 'Factura verificable en la AEAT (VERI*FACTU)' : 'VERI*FACTU',
              style: pw.TextStyle(fontSize: 7, color: colGris),
            )),
            pw.SizedBox(width: 57, height: 57, child: pw.Image(pw.MemoryImage(qrBytes))),
          ]),
        ],
        // Footer
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          if (correoEmpresa?.isNotEmpty == true)
            pw.Text(correoEmpresa!, style: pw.TextStyle(fontSize: 7, color: colGris)),
          pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: colPrim)),
        ]),
      ],
    ));
    return pdf.save();
  }

  /// Layout 'bold' con datos reales de la Factura.
  static Future<Uint8List> _generarPdfBoldFactura({
    required Factura factura,
    required String primario,
    required String secundario,
    required String nombreEmpresa,
    String? cifEmpresa,
    String? direccionEmpresa,
    String? ibanEmpresa,
    String? correoEmpresa,
    Uint8List? logoBytes,
    Uint8List? qrBytes,
    bool esVerifactu = false,
  }) async {
    final colPrim  = PdfColor.fromHex(primario);
    final colSecun = PdfColor.fromHex(secundario);
    final colTxt   = PdfColor.fromHex('#111827');
    final colGris  = PdfColor.fromHex('#6B7280');
    final colLight = PdfColor(1, 1, 1, 0.15);
    final (fontR, fontB) = await _FC.nB;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: fontR, bold: fontB));

    final subtotal = factura.subtotal - factura.importeDescuentoGlobal;
    final fmt = (double v) => '${v.toStringAsFixed(2)} €';
    final fmtDate = (DateTime d) =>
        '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
      ),
      build: (ctx) => [
        // Cabecera full-width
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(40, 32, 40, 28),
          color: colPrim,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              if (logoBytes != null)
                pw.Container(
                  decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(8)),
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Image(pw.MemoryImage(logoBytes), width: 44, height: 44),
                )
              else
                pw.Container(
                  width: 48, height: 48,
                  decoration: pw.BoxDecoration(color: colLight, borderRadius: pw.BorderRadius.circular(8)),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    nombreEmpresa.isNotEmpty ? nombreEmpresa[0].toUpperCase() : 'E',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(factura.numeroFactura,
                    style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.9), fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Emisión: ${fmtDate(factura.fechaEmision)}',
                    style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
                if (factura.fechaVencimiento != null)
                  pw.Text('Vence: ${fmtDate(factura.fechaVencimiento!)}',
                      style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 9)),
              ]),
            ]),
            pw.SizedBox(height: 16),
            pw.Text(
              factura.esRectificativa ? 'FACTURA RECTIFICATIVA' : factura.esProforma ? 'PRESUPUESTO' : 'FACTURA',
              style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.55), fontSize: 9, letterSpacing: 3, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(nombreEmpresa,
                style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
            if (cifEmpresa?.isNotEmpty == true)
              pw.Text(cifEmpresa!, style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.65), fontSize: 10)),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: pw.BoxDecoration(color: colLight, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                pw.Text('TOTAL: ', style: pw.TextStyle(color: PdfColor(1, 1, 1, 0.8), fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(fmt(factura.total), style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
          ]),
        ),
        pw.Container(height: 5, color: colSecun),
        // Contenido
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(40, 20, 40, 32),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // Cliente
            pw.Row(children: [
              pw.Container(width: 4, height: 40, color: colPrim),
              pw.SizedBox(width: 12),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('FACTURAR A', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: colPrim, letterSpacing: 1.5)),
                pw.Text(factura.clienteNombre, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: colTxt)),
                pw.Text([
                  if (factura.datosFiscales?.nif?.isNotEmpty == true) 'NIF: ${factura.datosFiscales!.nif}',
                  if (factura.clienteCorreo?.isNotEmpty == true) factura.clienteCorreo!,
                ].join('  ·  '), style: pw.TextStyle(fontSize: 9, color: colGris)),
              ]),
            ]),
            pw.SizedBox(height: 20),
            // Tabla
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: colPrim),
                  children: [
                    for (final h in ['DESCRIPCIÓN', 'CANT.', 'P.UNIT.', 'IMPORTE'])
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8), child:
                        pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.5))),
                  ],
                ),
                ...factura.lineas.asMap().entries.map((e) => pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: e.key.isEven ? PdfColor.fromHex('#FAFAFA') : PdfColors.white,
                  ),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child:
                      pw.Text(e.value.descripcion, style: pw.TextStyle(fontSize: 10, color: colTxt))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child:
                      pw.Text('${e.value.cantidad}', style: pw.TextStyle(fontSize: 10, color: colGris))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child:
                      pw.Text(fmt(e.value.precioUnitario), style: pw.TextStyle(fontSize: 10, color: colGris))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child:
                      pw.Text(fmt(e.value.subtotalSinIva),
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colTxt))),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 18),
            // Totales
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F9FAFB'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
                ),
                child: pw.Column(children: [
                  _rowTotal('Base imponible', fmt(subtotal), colGris, fontSize: 9),
                  if (factura.descuentoGlobal > 0) ...[
                    pw.SizedBox(height: 4),
                    _rowTotal('Descuento (${factura.descuentoGlobal.toStringAsFixed(0)}%)',
                        '-${fmt(factura.importeDescuentoGlobal)}', PdfColor.fromHex('#E65100'), fontSize: 9),
                  ],
                  pw.SizedBox(height: 4),
                  _rowTotal('IVA', fmt(factura.totalIva), colGris, fontSize: 9),
                  if (factura.porcentajeIrpf > 0) ...[
                    pw.SizedBox(height: 4),
                    _rowTotal('IRPF ${factura.porcentajeIrpf.toStringAsFixed(0)}%',
                        '-${fmt(factura.retencionIrpf)}', colGris, fontSize: 9),
                  ],
                  pw.SizedBox(height: 8),
                  pw.Divider(color: colPrim, thickness: 1.5),
                  _rowTotal('TOTAL', fmt(factura.total), colPrim, bold: true, fontSize: 13),
                ]),
              ),
            ]),
            // Forma de pago
            if (factura.metodoPago != null) ...[
              pw.SizedBox(height: 14),
              pw.Text('Forma de pago: ${_lblPago(factura.metodoPago)}',
                  style: pw.TextStyle(fontSize: 9, color: colGris)),
              if (ibanEmpresa?.isNotEmpty == true && factura.metodoPago == MetodoPagoFactura.transferencia)
                pw.Text('IBAN: $ibanEmpresa', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: colTxt)),
            ],
            // Notas
            if (factura.notasCliente?.isNotEmpty == true) ...[
              pw.SizedBox(height: 8),
              pw.Text(factura.notasCliente!, style: pw.TextStyle(fontSize: 8, color: colGris)),
            ],
            // QR
            if (qrBytes != null && qrBytes.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Expanded(child: pw.Text(
                  esVerifactu ? 'Factura verificable en la AEAT (VERI*FACTU)' : 'VERI*FACTU',
                  style: pw.TextStyle(fontSize: 7, color: colGris),
                )),
                pw.SizedBox(width: 57, height: 57, child: pw.Image(pw.MemoryImage(qrBytes))),
              ]),
            ],
          ]),
        ),
      ],
    ));
    return pdf.save();
  }

  /// Muestra el PDF de ejemplo en un popup/dialog.
  static Future<void> previewPlantilla(
    BuildContext context,
    uiTpl.PdfTemplate plantilla,
    String empresaId,
  ) async {
    // Spinner mientras genera
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final bytes = await generarPreviewBytes(plantilla, empresaId);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // cierra spinner

      final acento = _hexToColor(plantilla.colorPrimario);
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header del popup
            Container(
              color: acento,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(children: [
                Expanded(child: Text(
                  '${plantilla.tipo.icon} ${plantilla.nombre}',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                )),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 18),
                  tooltip: 'Compartir PDF',
                  onPressed: () => Printing.sharePdf(
                      bytes: bytes, filename: 'preview_${plantilla.nombre}.pdf'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(ctx).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ]),
            ),
            // PDF viewer dentro del popup
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: PdfPreview(
                build: (_) async => bytes,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                pdfPreviewPageDecoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                ),
              ),
            ),
          ]),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error generando vista previa: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  // ── GENERAR PDF DINÁMICO (con plantillas personalizadas) ─────────────────────

  /// Genera PDF aplicando la plantilla activa de la empresa (colección pdf_templates).
  /// Delegado a generarFacturaPdfConDatos que usa el servicio de plantillas correcto.
  static Future<Uint8List> generarFacturaPdfDinamico(
    Factura factura,
    String empresaId,
  ) async {
    return generarFacturaPdfConDatos(factura, empresaId);
  }

  // ── EXPORTAR CSV ─────────────────────────────────────────────────────────

  static String exportarFacturasCSV(List<Factura> facturas) {
    final buf = StringBuffer();
    buf.writeln(
        'Número,Fecha emisión,Cliente,Email,Subtotal,IVA,Total,Estado,Método pago,Fecha pago');
    for (final f in facturas) {
      buf.writeln([
        _esc(f.numeroFactura),
        _fmtDate(f.fechaEmision),
        _esc(f.clienteNombre),
        _esc(f.clienteCorreo ?? ''),
        f.subtotal.toStringAsFixed(2),
        f.totalIva.toStringAsFixed(2),
        f.total.toStringAsFixed(2),
        _lblEstado(f.estado),
        f.metodoPago != null ? _lblPago(f.metodoPago) : '',
        f.fechaPago != null ? _fmtDate(f.fechaPago!) : '',
      ].join(','));
    }
    return buf.toString();
  }

  static String exportarGastosCSV(List<Gasto> gastos) {
    final buf = StringBuffer();
    buf.writeln(
        'Fecha,Proveedor,Concepto,Base imponible,IVA,Total,Categoría');
    for (final g in gastos) {
      buf.writeln([
        _fmtDate(g.fechaGasto),
        _esc(g.proveedorNombre ?? ''),
        _esc(g.concepto),
        g.baseImponible.toStringAsFixed(2),
        g.importeIva.toStringAsFixed(2),
        g.total.toStringAsFixed(2),
        g.categoria.name,
      ].join(','));
    }
    return buf.toString();
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  static pw.Widget _rowTotal(
    String etiqueta,
    String valor,
    PdfColor color, {
    bool bold = false,
    double fontSize = 10,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            etiqueta,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
          pw.Text(
            valor,
            style: pw.TextStyle(
              fontSize: fontSize + (bold ? 2 : 0),
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _esc(String v) =>
      (v.contains(',') || v.contains('"') || v.contains('\n'))
          ? '"${v.replaceAll('"', '""')}"'
          : v;

  static String _lblEstado(EstadoFactura e) => switch (e) {
        EstadoFactura.pendiente   => 'Pendiente',
        EstadoFactura.pagada      => 'Pagada',
        EstadoFactura.anulada     => 'Anulada',
        EstadoFactura.vencida     => 'Vencida',
        EstadoFactura.rectificada => 'Rectificada',
      };

  static PdfColor _estadoColor(EstadoFactura e) => switch (e) {
        EstadoFactura.pagada      => PdfColor.fromHex('#2E7D32'),
        EstadoFactura.vencida     => PdfColor.fromHex('#D32F2F'),
        EstadoFactura.anulada     => PdfColor.fromHex('#757575'),
        EstadoFactura.rectificada => PdfColor.fromHex('#E65100'),
        EstadoFactura.pendiente   => PdfColor.fromHex('#1565C0'),
      };

  static String _lblPago(MetodoPagoFactura? m) {
    if (m == null) return '';
    return switch (m) {
      MetodoPagoFactura.tarjeta       => 'Tarjeta',
      MetodoPagoFactura.paypal        => 'PayPal',
      MetodoPagoFactura.bizum         => 'Bizum',
      MetodoPagoFactura.efectivo      => 'Efectivo',
      MetodoPagoFactura.transferencia => 'Transferencia bancaria',
    };
  }
}

