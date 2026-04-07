import 'dart:async';
            content: Text('❌ Error generando PDF: $e'),
        ),
                color: bg,
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import '../domain/modelos/factura.dart';
import 'verifactu_service.dart';
import 'verifactu/qr_service.dart';

class PdfService {
  static final _db = FirebaseFirestore.instance;

  // ── CARGAR DATOS EMPRESA ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> cargarDatosEmpresa(String empresaId) async {
      if (!raiz.exists) return {};
      final data = raiz.data() ?? {};

      // Los datos pueden estar en campos raíz (EmpresaConfig merge: nif, razon_social…)
      // o dentro de 'perfil' (Empresa.toFirestore: nombre, correo, telefono…)
      final perfil = data['perfil'] as Map<String, dynamic>? ?? {};

      return {
        'nombre': (data['razon_social'] ?? perfil['nombre'] ?? data['nombre'] ?? '').toString(),
        'cif': (data['nif'] ?? data['cif'] ?? '').toString(),
        'direccion': (data['domicilio_fiscal'] ?? perfil['direccion'] ?? data['direccion'] ?? '').toString(),
        'telefono': (perfil['telefono'] ?? data['telefono'] ?? '').toString(),
        'correo': (perfil['correo'] ?? data['correo'] ?? '').toString(),
      };
      final raiz = await _db.collection('empresas').doc(empresaId).get();
      if (raiz.exists) return raiz.data() ?? {};
      if (raiz.exists) return raiz.data() ?? {};
    final colorLinea   = PdfColor.fromHex('#E0E0E0');
    final colorFondoBg = PdfColor.fromHex('#F5F9FF');
    final colorAccent  = PdfColor.fromHex('#00ACC1');
    final colorRojo    = PdfColor.fromHex('#D32F2F');

    // Determinar título y color de cabecera según tipo
    final esRect = factura.esRectificativa;
    final tituloFactura = esRect ? 'FACTURA RECTIFICATIVA' : 'FACTURA';
    final colorCabecera = esRect ? colorRojo : colorAzul;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // CABECERA
            pw.Container(
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
      pw.MultiPage(
                    pw.SizedBox(height: 6),
                    if (cifEmpresa != null) pw.Text('CIF: $cifEmpresa', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#E0E0E0'))),
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        build: (ctx) => [
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
                    pw.Text(factura.numeroFactura, style: pw.TextStyle(fontSize: 14, color: colorAccent, fontWeight: pw.FontWeight.bold)),
                     pw.SizedBox(height: 4),
                    pw.Text('Emisión: ${_fmtDate(factura.fechaEmision)}', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#E0E0E0'))),
                     if (factura.fechaVencimiento != null)
                      pw.Text('Vencimiento: ${_fmtDate(factura.fechaVencimiento!)}', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#E0E0E0'))),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(color: colorAccent, borderRadius: pw.BorderRadius.circular(6)),
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
                color: bg,
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: pw.BoxDecoration(
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
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colorAzul),
                      textAlign: pw.TextAlign.right)),
              );
            }),
                  color: bg,

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
            if (factura.tipo == TipoFactura.proforma)
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
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generarFacturaPdfConDatos(
      Factura factura, String empresaId) async {
    final empresa = await cargarDatosEmpresa(empresaId);

    // Generar QR Verifactu si la factura tiene datos Verifactu
    Uint8List? qrBytes;
    String? qrUrl;
    bool esVerifactu = false;

    if (factura.verifactu != null) {
      try {
        qrUrl = datos.urlVerificacion ??
            VerifactuService.generarUrlQr(
              nifEmisor: datos.nifEmisor,
              numeroFactura: datos.idFactura,
              fechaExpedicion: datos.fechaExpedicion,
              importeTotal: factura.total,
            );
        esVerifactu = datos.estado != EstadoVerifactu.error;
        if (!kIsWeb && qrUrl.isNotEmpty) {
    // ⚠️ Advertencia si la empresa no tiene datos configurados
    final nombreEmpresa = empresa['nombre'] as String? ?? '';
    final cifEmpresa = empresa['cif'] as String?;
    if (nombreEmpresa.isEmpty || cifEmpresa == null || cifEmpresa.isEmpty) {
      // Se continúa generando el PDF pero con datos incompletos.
      // La UI mostrará una advertencia al usuario (ver verFacturaPdf).
    }

          qrBytes = await QrService().generarImagenQr(qrUrl);
        }
      } catch (_) {
        // QR no crítico: si falla, el PDF se genera sin él
      }
    }

    return generarFacturaPdf(
      factura,
      nombreEmpresa: empresa['nombre'] as String? ?? 'Mi Empresa',
      cifEmpresa: empresa['cif'] as String?,
      direccionEmpresa: empresa['direccion'] as String?,
      telefonoEmpresa: empresa['telefono'] as String?,
      correoEmpresa: empresa['correo'] as String?,
      qrVerifactuBytes: qrBytes,
      qrVerifactuUrl: qrUrl,
      esVerifactu: esVerifactu,
    );
  }

  static Future<void> verFacturaPdf(BuildContext context, Factura factura, String empresaId) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      nombreEmpresa: nombreEmpresa.isEmpty ? 'Mi Empresa' : nombreEmpresa,
      cifEmpresa: cifEmpresa,
    try {
      final bytes = await generarFacturaPdfConDatos(factura, empresaId);
      if (!context.mounted) return;
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
      final bytes = await generarFacturaPdfConDatos(factura, empresaId)
          .timeout(const Duration(seconds: 20));
            ),
            body: PdfPreview(
              build: (_) async => bytes,
      // Advertir si la empresa no tiene datos fiscales completos
      try {
        final empresa = await cargarDatosEmpresa(empresaId);
        final nombre = empresa['nombre'] as String? ?? '';
        final cif = empresa['cif'] as String? ?? '';
        if ((nombre.isEmpty || cif.isEmpty) && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Empresa sin nombre/CIF configurado — configura los datos fiscales',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (_) {}
      
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: '${factura.numeroFactura}.pdf',
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar loading si hay error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generando PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

      nombreEmpresa: empresa['nombre'] as String? ?? 'Mi Empresa',
      cifEmpresa: empresa['cif'] as String?,
    final buf = StringBuffer();
    buf.writeln('Número,Fecha emisión,Cliente,Email,Subtotal,IVA,Total,Estado,Método pago,Fecha pago');
    for (final f in facturas) {
      buf.writeln([
        _esc(f.numeroFactura), _fmtDate(f.fechaEmision), _esc(f.clienteNombre),
        _esc(f.clienteCorreo ?? ''), f.subtotal.toStringAsFixed(2),
        f.totalIva.toStringAsFixed(2), f.total.toStringAsFixed(2),
        _lblEstado(f.estado), _lblPago(f.metodoPago),
        f.fechaPago != null ? _fmtDate(f.fechaPago!) : '',
      ].join(','));
    }
    return buf.toString();
  }

      final bytes = await generarFacturaPdfConDatos(factura, empresaId);
    buf.writeln('Fecha,Proveedor,Concepto,Base imponible,IVA soportado,Total,Categoría');
    for (final g in gastos) {
        final msg = e is TimeoutException
            ? '⏱ Tiempo agotado generando el PDF. Inténtalo de nuevo.'
            : '❌ Error generando PDF: $e';
      buf.writeln([
          children: [
            content: Text(msg),
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
