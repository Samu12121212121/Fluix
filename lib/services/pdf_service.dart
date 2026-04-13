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
import 'verifactu_service.dart';
import 'verifactu/qr_service.dart';

class PdfService {
  static final _db = FirebaseFirestore.instance;

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

  static Future<Map<String, String>> _cargarDatosEmpresa(String empresaId) async {
    try {
      final raiz = await _db.collection('empresas').doc(empresaId).get();
      if (!raiz.exists) return {};

      final data = raiz.data() ?? {};
      final perfil = data['perfil'] as Map<String, dynamic>? ?? {};

      return {
        'nombre': (data['razon_social'] ?? perfil['nombre'] ?? data['nombre'] ?? '').toString(),
        'cif': (data['nif'] ?? data['cif'] ?? '').toString(),
        'direccion': (data['domicilio_fiscal'] ?? perfil['direccion'] ?? data['direccion'] ?? '').toString(),
        'telefono': (perfil['telefono'] ?? data['telefono'] ?? '').toString(),
        'correo': (perfil['correo'] ?? data['correo'] ?? '').toString(),
        'iban': (data['iban_empresa'] ?? '').toString(),
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
  }) async {
    final colorCabecera = factura.esRectificativa ? PdfColor.fromHex('#D32F2F') : PdfColor.fromHex('#1565C0');
    final colorAzul    = PdfColor.fromHex('#1565C0');
    final colorAzulOsc = PdfColor.fromHex('#0D47A1');
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

    final pdf = pw.Document();

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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
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
                      'IVA',
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
                      'IRPF (-${factura.porcentajeIrpf.toStringAsFixed(0)}%)',
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

          // ── SELLO "PAGADA" ────────────────────────────────────────────
          if (_mostrarSelloPagada) ...[
            pw.SizedBox(height: 8),
            pw.Center(child: _buildSelloPagada()),
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

    // Generar QR Verifactu si la factura tiene datos Verifactu
    Uint8List? qrBytes;
    bool esVerifactu = false;

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
        esVerifactu = datos.estado != EstadoVerifactu.error;
        if (!kIsWeb && qrUrl.isNotEmpty) {
          qrBytes = await QrService().generarImagenQr(qrUrl);
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

