import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

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
      };
    } catch (e) {
      debugPrint('❌ Error cargando datos empresa: $e');
      return {};
    }
  }

  // ── GENERAR PDF BYTES ─────────────────────────────────────────────────────

  static Future<Uint8List> _generarPdfBytes({
    required Factura factura,
    required String nombreEmpresa,
    String? cifEmpresa,
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

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        build: (ctx) => [
          // CABECERA
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: colorCabecera,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 18, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  if (cifEmpresa != null) pw.Text('CIF: $cifEmpresa', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#E0E0E0'))),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(factura.numeroFactura, style: pw.TextStyle(fontSize: 14, color: colorAccent, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Emisión: ${_fmtDate(factura.fechaEmision)}', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#E0E0E0'))),
                  if (factura.fechaVencimiento != null)
                    pw.Text('Vencimiento: ${_fmtDate(factura.fechaVencimiento!)}', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#E0E0E0'))),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: _estadoColor(factura.estado),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(_lblEstado(factura.estado),
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

            // BLOQUE RECTIFICATIVA — referencia a factura original
            if (factura.esRectificativa && factura.facturaOriginalNumero != null) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF3E0'),
                  border: pw.Border.all(color: colorRojo, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('RECTIFICA A LA FACTURA',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colorRojo, letterSpacing: 1)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Nº ${factura.facturaOriginalNumero}'
                    '${factura.facturaOriginalFecha != null ? "  de fecha  ${_fmtDate(factura.facturaOriginalFecha!)}" : ""}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                  pw.SizedBox(height: 6),
                  if (factura.motivoRectificacion != null) ...[
                    pw.Text('Motivo: ${factura.motivoRectificacion!.etiqueta}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                  ],
                  if (factura.motivoRectificacionTexto != null && factura.motivoRectificacionTexto!.isNotEmpty)
                    pw.Text(factura.motivoRectificacionTexto!,
                        style: pw.TextStyle(fontSize: 9, color: colorGris)),
                  if (factura.metodoRectificacion != null)
                    pw.Text('Método: ${factura.metodoRectificacion!.etiqueta}',
                        style: pw.TextStyle(fontSize: 9, color: colorGris)),
                ]),
              ),
              pw.SizedBox(height: 16),
            ],

            // CLIENTE
            pw.Text('FACTURAR A:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colorAzul, letterSpacing: 1.2)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: colorFondoBg,
                border: pw.Border.all(color: colorLinea),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(factura.clienteNombre, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (factura.clienteCorreo != null)
                  pw.Text(factura.clienteCorreo!, style: pw.TextStyle(fontSize: 10, color: colorGris, letterSpacing: 0.3)),
                if (factura.datosFiscales?.nif != null)
                  pw.Text('NIF/CIF: ${factura.datosFiscales!.nif}', style: pw.TextStyle(fontSize: 10, color: colorGris, fontWeight: pw.FontWeight.bold)),
                if (factura.datosFiscales?.direccion != null)
                  pw.Text(factura.datosFiscales!.direccion!, style: pw.TextStyle(fontSize: 10, color: colorGris)),
              ]),
            ),
            pw.SizedBox(height: 20),

            // CABECERA TABLA
            pw.Container(
              decoration: pw.BoxDecoration(
                color: colorAzulOsc,
                  borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(8), topRight: pw.Radius.circular(8))),
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: pw.Row(children: [
                pw.Expanded(flex: 5, child: pw.Text('DESCRIPCIÓN',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5))),
                pw.SizedBox(width: 40, child: pw.Text('CANT',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                    textAlign: pw.TextAlign.center)),
                pw.SizedBox(width: 65, child: pw.Text('PRECIO',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                    textAlign: pw.TextAlign.right)),
                pw.SizedBox(width: 35, child: pw.Text('IVA',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                    textAlign: pw.TextAlign.center)),
                pw.SizedBox(width: 65, child: pw.Text('TOTAL',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                    textAlign: pw.TextAlign.right)),
              ]),
            ),

            // FILAS LÍNEAS
            ...factura.lineas.asMap().entries.map((e) {
              final l = e.value;
              final bg = e.key.isEven ? PdfColors.white : PdfColor.fromHex('#FAFBFC');
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: pw.BoxDecoration(
                  color: bg,
                  border: pw.Border(bottom: pw.BorderSide(color: colorLinea, width: 0.5)),
                ),
                child: pw.Row(children: [
                  pw.Expanded(flex: 5, child: pw.Text(l.descripcion, style: pw.TextStyle(fontSize: 10, color: PdfColors.black))),
                  pw.SizedBox(width: 40, child: pw.Text('${l.cantidad}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.black), textAlign: pw.TextAlign.center)),
                  pw.SizedBox(width: 65, child: pw.Text('${l.precioUnitario.toStringAsFixed(2)} €',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.black), textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 35, child: pw.Text('${l.porcentajeIva.toStringAsFixed(0)}%',
                      style: pw.TextStyle(fontSize: 10, color: colorGris), textAlign: pw.TextAlign.center)),
                  pw.SizedBox(width: 65, child: pw.Text('${l.subtotalConIva.toStringAsFixed(2)} €',
                      textAlign: pw.TextAlign.right)),
                ]),
              );
            }),

            pw.Divider(color: colorLinea),
            pw.SizedBox(height: 10),

            // TOTALES
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 220,
                child: pw.Column(children: [
                  _rowTotal('IVA', '${factura.totalIva.toStringAsFixed(2)} €', colorGris, fontSize: 11),
                  if (factura.totalRecargoEquivalencia > 0)
                    _rowTotal('Recargo equiv.', '${factura.totalRecargoEquivalencia.toStringAsFixed(2)} €', colorGris, fontSize: 11),
                  if (factura.porcentajeIrpf > 0)
                    _rowTotal('IRPF (-${factura.porcentajeIrpf.toStringAsFixed(0)}%)', '-${factura.retencionIrpf.toStringAsFixed(2)} €', colorGris, fontSize: 11),
                  pw.Divider(color: colorLinea),
                  _rowTotal('TOTAL', '${factura.total.toStringAsFixed(2)} €', colorAzul, bold: true, fontSize: 14),
                ]),
              ),
            ),

            // Sello PROFORMA si aplica
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 12),
                child: pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromHex('#009688'), width: 2),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text('PROFORMA',
                        style: pw.TextStyle(color: PdfColor.fromHex('#009688'), fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ),
                ),
              ),

            // QR VERIFACTU — obligatorio cuando Verifactu está activo
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
                  // Imagen QR: ~57px ≈ 30mm a 96DPI (mínimo reglamentario)
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
      cifEmpresa: cifEmpresa,
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
      Navigator.of(context).pop(); // Cerrar loading

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
        Navigator.of(context).pop(); // Cerrar loading si hay error
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
    buf.writeln('Número,Fecha emisión,Cliente,Email,Subtotal,IVA,Total,Estado,Método pago,Fecha pago');
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
    buf.writeln('Fecha,Proveedor,Concepto,Base imponible,IVA,Total,Categoría');
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

  static pw.Widget _rowTotal(String etiqueta, String valor, PdfColor color, {bool bold = false, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(etiqueta,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: fontSize + (bold ? 2 : 0),
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
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
    EstadoFactura.pendiente    => 'Pendiente',
    EstadoFactura.pagada       => 'Pagada',
    EstadoFactura.anulada      => 'Anulada',
    EstadoFactura.vencida      => 'Vencida',
    EstadoFactura.rectificada  => 'Rectificada',
  };

  static PdfColor _estadoColor(EstadoFactura e) => switch (e) {
    EstadoFactura.pagada       => PdfColor.fromHex('#2E7D32'),
    EstadoFactura.vencida      => PdfColor.fromHex('#D32F2F'),
    EstadoFactura.anulada      => PdfColor.fromHex('#757575'),
    EstadoFactura.rectificada  => PdfColor.fromHex('#E65100'),
    EstadoFactura.pendiente    => PdfColor.fromHex('#1565C0'),
  };

   static String _lblPago(MetodoPagoFactura? m) {
     if (m == null) return '';
     return switch (m) {
       MetodoPagoFactura.tarjeta        => 'Tarjeta',
       MetodoPagoFactura.paypal         => 'PayPal',
       MetodoPagoFactura.bizum          => 'Bizum',
       MetodoPagoFactura.efectivo       => 'Efectivo',
       MetodoPagoFactura.transferencia  => 'Transferencia',
     };
   }
 }
