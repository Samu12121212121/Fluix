import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/modelos/factura.dart';
import '../domain/modelos/contabilidad.dart';
import '../domain/modelos/pdf_template.dart';
import 'verifactu_service.dart';
import 'verifactu/qr_service.dart';
import 'pdf/pdf_renderer.dart';
import 'pdf/pdf_template_service.dart';
// Servicio de la feature de plantillas (usa la misma colección que la UI)
import '../features/pdf_templates/data/pdf_template_service.dart' as uiTplSvc;
import '../features/pdf_templates/domain/models/pdf_template.dart' as uiTpl;

class PdfService {
  static final _db = FirebaseFirestore.instance;
  static final _templateService = PdfTemplateService();
  
  static PdfRenderer get _renderer => PdfRenderer();

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

      // Buscar nombre en orden estricto de prioridad:
      // 1. Config de facturación (el usuario lo configura explícitamente)
      // 2. Campos legales/fiscales del documento
      // 3. Campos de nombre del documento o perfil
      final nombreEmpresa = (
        cfg['nombre_empresa'] ??           // configurado en ajustes de facturación
        cfg['razon_social'] ??             // razón social en config
        data['razon_social'] ??            // razón social en raíz
        data['nombre_fiscal'] ??           // nombre fiscal
        data['nombre_empresa'] ??          // nombre empresa explícito
        data['nombre_negocio'] ??          // nombre negocio
        perfil['nombre_empresa'] ??        // nombre empresa en perfil
        _resolverNombreEmpresa(data)       // resolución inteligente
      )?.toString() ?? '';

      debugPrint('📄 [PDF] Empresa: $empresaId → nombre="$nombreEmpresa"');

      return {
        'nombre': nombreEmpresa.isEmpty ? 'Mi Empresa' : nombreEmpresa,
        'cif': (cfg['nif'] ?? cfg['cif'] ?? data['nif'] ?? data['cif'] ?? '').toString(),
        'direccion': (cfg['domicilio_fiscal'] ?? data['domicilio_fiscal'] ?? perfil['direccion'] ?? data['direccion'] ?? '').toString(),
        'telefono': (cfg['telefono'] ?? perfil['telefono'] ?? data['telefono'] ?? '').toString(),
        'correo': (cfg['correo'] ?? data['email_contacto'] ?? perfil['correo'] ?? data['correo'] ?? '').toString(),
        'iban': (cfg['iban'] ?? data['iban_empresa'] ?? '').toString(),
        'logo_url': (perfil['logo_url'] ?? data['logo_url'] ?? '').toString(),
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
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold    = await PdfGoogleFonts.nunitoBold();
    final fontItalic  = await PdfGoogleFonts.nunitoItalic();

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
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
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
                    'PROFORMA',
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

  static Future<Uint8List> generarFacturaPdfConDatos(
      Factura factura, String empresaId) async {
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

    // ── Buscar colores del template asignado (usa la colección de la UI) ──
    String? colorPrimario;
    String? colorSecundario;
    try {
      final svc = uiTplSvc.PdfTemplateService();
      final tipoUi = factura.esRectificativa
          ? uiTpl.TipoDocumentoPdf.facturaRectificativa
          : uiTpl.TipoDocumentoPdf.factura;
      final tpl = await svc.getPlantillaDefault(empresaId, tipoUi);
      if (tpl != null) {
        colorPrimario   = tpl.colorPrimario;
        colorSecundario = tpl.colorSecundario;
        debugPrint('🎨 [PDF] Plantilla "${tpl.nombre}" → primario=$colorPrimario secundario=$colorSecundario');
      } else {
        debugPrint('⚠️ [PDF] Sin plantilla default para tipo=${tipoUi.id} empresa=$empresaId');
      }
    } catch (e) {
      debugPrint('⚠️ [PDF] Error buscando plantilla UI: $e');
    }

    // Generar QR Verifactu si la factura tiene datos Verifactu
    Uint8List? qrBytes;
    bool esVerifactu = false;

    if (factura.verifactu != null) {
      try {
        final datos = DatosVerifactu.fromMap(factura.verifactu!);
        esVerifactu = datos.estado != EstadoVerifactu.error;
        // Usar QrService con los campos correctos:
        // - numeroFactura: el número de factura real (FAC-2026-0001), no el UUID
        // - QrService formatea la fecha a dd-MM-yyyy según HAC/1177/2024
        final qrSvc = QrService();
        final qrUrl = datos.urlVerificacion ??
            qrSvc.generarUrl(
              nifEmisor: datos.nifEmisor,
              serie: '',                         // la serie ya va incluida en el numeroFactura
              numero: datos.numeroFactura.isNotEmpty
                  ? datos.numeroFactura
                  : factura.numeroFactura,
              fecha: factura.fechaEmision,       // fecha real de la factura
              importeTotal: factura.total,
            );
        if (!kIsWeb && qrUrl.isNotEmpty) {
          qrBytes = await qrSvc.generarImagenQr(qrUrl);
        }
      } catch (_) {}
    }

    return _generarPdfBytes(
      factura: factura,
      nombreEmpresa: nombreEmpresa.isEmpty ? 'Mi Empresa' : nombreEmpresa,
      cifEmpresa: cifEmpresa?.isNotEmpty == true ? cifEmpresa : null,
      direccionEmpresa:
          direccionEmpresa?.isNotEmpty == true ? direccionEmpresa : null,
      telefonoEmpresa:
          telefonoEmpresa?.isNotEmpty == true ? telefonoEmpresa : null,
      correoEmpresa: correoEmpresa?.isNotEmpty == true ? correoEmpresa : null,
      ibanEmpresa: ibanEmpresa?.isNotEmpty == true ? ibanEmpresa : null,
      logoBytes: logoBytes,
      qrVerifactuBytes: qrBytes,
      esVerifactu: esVerifactu,
      colorPrimarioTemplate: colorPrimario,
      colorSecundarioTemplate: colorSecundario,
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

    switch (plantilla.estiloLayout) {
      case 'linea':
        return _generarPdfLinea(
          primario: plantilla.colorPrimario, secundario: plantilla.colorSecundario,
          nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
          logoBytes: logoBytes, anio: ahora.year,
        );
      case 'bold':
        return _generarPdfBold(
          primario: plantilla.colorPrimario, secundario: plantilla.colorSecundario,
          nombreEmpresa: nombreEmpresa, cifEmpresa: cifEmpresa,
          logoBytes: logoBytes, anio: ahora.year,
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

  // ── Layout 'linea' — minimalista con acento de línea ─────────────────────
  static Future<Uint8List> _generarPdfLinea({
    required String primario, required String secundario,
    required String nombreEmpresa, String? cifEmpresa,
    Uint8List? logoBytes, required int anio,
  }) async {
    final colPrim = PdfColor.fromHex(primario);
    final fontR = await PdfGoogleFonts.nunitoRegular();
    final fontB = await PdfGoogleFonts.nunitoBold();
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
              pw.Text('FACTURA', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: colPrim, letterSpacing: 3)),
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
    Uint8List? logoBytes, required int anio,
  }) async {
    final colPrim  = PdfColor.fromHex(primario);
    final colSecun = PdfColor.fromHex(secundario);
    final fontR = await PdfGoogleFonts.nunitoRegular();
    final fontB = await PdfGoogleFonts.nunitoBold();
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
                  decoration: pw.BoxDecoration(color: PdfColors.white.withOpacity(0.2), borderRadius: pw.BorderRadius.circular(8)),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    nombreEmpresa.substring(0, 1).toUpperCase(),
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('FAC-$anio-0001', style: pw.TextStyle(color: PdfColors.white.withOpacity(0.9), fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Fecha: ${DateTime.now().day}/${DateTime.now().month}/$anio',
                    style: pw.TextStyle(color: PdfColors.white.withOpacity(0.7), fontSize: 9)),
              ]),
            ]),
            pw.SizedBox(height: 20),
            pw.Text('FACTURA', style: pw.TextStyle(color: PdfColors.white.withOpacity(0.55), fontSize: 10, letterSpacing: 4, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(nombreEmpresa, style: pw.TextStyle(color: PdfColors.white, fontSize: 26, fontWeight: pw.FontWeight.bold)),
            if (cifEmpresa?.isNotEmpty == true)
              pw.Text(cifEmpresa!, style: pw.TextStyle(color: PdfColors.white.withOpacity(0.65), fontSize: 10)),
            pw.SizedBox(height: 16),
            // Total destacado en la cabecera
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: pw.BoxDecoration(color: PdfColors.white.withOpacity(0.15), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                pw.Text('TOTAL A PAGAR: ', style: pw.TextStyle(color: PdfColors.white.withOpacity(0.8), fontSize: 11, fontWeight: pw.FontWeight.bold)),
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

  /// Intenta generar PDF usando plantilla dinámica, fallback a legacy si no existe
  static Future<Uint8List> generarFacturaPdfDinamico(
    Factura factura,
    String empresaId,
  ) async {
    try {
      // 1. Intentar obtener plantilla personalizada
      final template = await _templateService.getTemplateForDocument(
        empresaId: empresaId,
        type: PdfDocumentType.factura,
      );
      
      // Si no hay plantilla, usar método legacy
      if (template == null) {
        debugPrint('📄 Sin plantilla personalizada, usando diseño por defecto');
        return await generarFacturaPdfConDatos(factura, empresaId);
      }
      
      debugPrint('🎨 Usando plantilla personalizada: ${template.name}');
      
      // 2. Cargar datos empresa y assets
      final empresa = await _cargarDatosEmpresa(empresaId);
      final logoBytes = !kIsWeb ? await _descargarLogo(empresa['logo_url']) : null;
      
      // 3. Generar QR Verifactu si aplica
      Uint8List? qrBytes;
      if (factura.verifactu != null) {
        try {
          final datos = DatosVerifactu.fromMap(factura.verifactu!);
          final qrUrl = datos.urlVerificacion ??
              VerifactuService.generarUrlQr(
                nifEmisor: datos.nifEmisor,
                numeroFactura: datos.idFactura,
                fechaExpedicion: datos.fechaExpedicion,
                importeTotal: factura.total,
              );
          if (!kIsWeb && qrUrl.isNotEmpty) {
            qrBytes = await QrService().generarImagenQr(qrUrl);
          }
        } catch (e) {
          debugPrint('⚠️ Error generando QR Verifactu: $e');
        }
      }
      
      // 4. Preparar branding
      final branding = PdfBranding(
        logoUrl: empresa['logo_url'],
        companyName: empresa['nombre'] ?? 'Mi Empresa',
        nif: empresa['cif'],
        domicilioFiscal: empresa['direccion'],
        telefono: empresa['telefono'],
        correo: empresa['correo'],
        iban: empresa['iban'],
      );
      
      // 5. Renderizar con motor dinámico
      return await _renderer.render(
        template: template,
        branding: branding,
        documentData: factura,
        logoBytes: logoBytes,
        qrBytes: qrBytes,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error en PDF dinámico, fallback a legacy: $e');
      debugPrint('   Stack: $stackTrace');
      // Fallback a legacy si falla algo
      return await generarFacturaPdfConDatos(factura, empresaId);
    }
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

