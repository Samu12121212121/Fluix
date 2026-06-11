import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/modelos/pedido.dart';
import '../../domain/modelos/configuracion_facturacion_tpv.dart';
import '../../domain/modelos/pdf_template.dart';
import '../../features/pdf_templates/data/pdf_template_service.dart';
import '../../features/pdf_templates/domain/models/pdf_template.dart' as pdf_models;

/// Servicio para renderizar documentos TPV (tickets, facturas simplificadas, facturas completas)
/// Lee configuración + datos del pedido → genera PDF optimizado para impresión térmica o A4
class TpvDocumentRenderer {
  final PdfTemplateService _templateSvc = PdfTemplateService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Genera el documento PDF para un pedido según la configuración TPV
  Future<Uint8List> renderizarDocumento({
    required String empresaId,
    required Pedido pedido,
    required ConfiguracionFacturacionTpv config,
    String? clienteNif,
    String? clienteEmail,
    String? clienteDireccion,
  }) async {
    // 1. Cargar datos de la empresa (branding)
    final branding = await _cargarBrandingEmpresa(empresaId);

    // 2. Determinar qué tipo de documento generar
    final tipoDoc = config.tipoDocumento;

    // 3. Cargar logo de la empresa (si existe)
    Uint8List? logoBytes;
    if (branding.logoUrl != null && branding.logoUrl!.isNotEmpty) {
      try {
        logoBytes = await _descargarLogo(branding.logoUrl!);
      } catch (_) {
        // Logo no disponible
      }
    }

    // 4. Generar según formato
    return config.formatoImpresion == FormatoImpresionTpv.a4
        ? _generarPdfA4(
            pedido: pedido,
            branding: branding,
            tipoDoc: tipoDoc,
            logoBytes: logoBytes,
            config: config,
            clienteNif: clienteNif,
            clienteEmail: clienteEmail,
            clienteDireccion: clienteDireccion,
          )
        : _generarTicketTermico(
            pedido: pedido,
            branding: branding,
            tipoDoc: tipoDoc,
            anchoMm: config.formatoImpresion == FormatoImpresionTpv.ticket80mm ? 80 : 58,
            config: config,
            clienteNif: clienteNif,
            clienteEmail: clienteEmail,
          );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN PDF A4 (Factura formal)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Uint8List> _generarPdfA4({
    required Pedido pedido,
    required PdfBranding branding,
    required TipoDocumentoTpv tipoDoc,
    Uint8List? logoBytes,
    required ConfiguracionFacturacionTpv config,
    String? clienteNif,
    String? clienteEmail,
    String? clienteDireccion,
  }) async {
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold    = await PdfGoogleFonts.nunitoBold();

    final pdf = pw.Document(
      title: _tituloDocumento(tipoDoc),
      author: branding.companyName ?? 'Mi Empresa',
      creator: 'FluixCRM TPV',
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header con logo y datos empresa
            _buildHeaderA4(branding, logoBytes, tipoDoc),
            pw.SizedBox(height: 20),

            // Datos del cliente (si es factura completa o simplificada)
            if (tipoDoc != TipoDocumentoTpv.ticket)
              _buildDatosCliente(
                pedido,
                clienteNif: clienteNif,
                clienteEmail: clienteEmail,
                clienteDireccion: clienteDireccion,
                esFacturaCompleta: tipoDoc == TipoDocumentoTpv.facturaCompleta,
              ),

            if (tipoDoc != TipoDocumentoTpv.ticket) pw.SizedBox(height: 20),

            // Información del documento
            _buildInfoDocumento(pedido, tipoDoc),
            pw.SizedBox(height: 20),

            // Tabla de líneas
            _buildTablaLineasA4(pedido.lineas),
            pw.SizedBox(height: 16),

            // Totales
            _buildTotalesA4(pedido, tipoDoc),

            pw.Spacer(),

            // Footer con método de pago
            if (pedido.metodoPago != MetodoPago.efectivo)
              _buildMetodoPago(pedido.metodoPago),

            // Nota legal (según tipo de documento)
            _buildNotaLegal(tipoDoc),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeaderA4(PdfBranding branding, Uint8List? logoBytes, TipoDocumentoTpv tipoDoc) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _colorPrimario(tipoDoc),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo + Datos empresa
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
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 12),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        branding.companyName ?? 'Mi Empresa',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (branding.nif != null) ...[
                        pw.SizedBox(height: 3),
                        pw.Text('NIF: ${branding.nif}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                      ],
                      if (branding.domicilioFiscal != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(branding.domicilioFiscal!,
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
                      ],
                      if (branding.telefono != null)
                        pw.Text('Tel: ${branding.telefono}',
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
                      if (branding.correo != null)
                        pw.Text(branding.correo!,
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          // Título del documento
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              _tituloDocumento(tipoDoc).toUpperCase(),
              style: pw.TextStyle(
                fontSize: 14,
                color: _colorPrimario(tipoDoc),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDatosCliente(
    Pedido pedido, {
    String? clienteNif,
    String? clienteEmail,
    String? clienteDireccion,
    required bool esFacturaCompleta,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CLIENTE',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 6),
          pw.Text(pedido.clienteNombre.isNotEmpty ? pedido.clienteNombre : 'Cliente general',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          if (esFacturaCompleta && clienteNif != null) ...[
            pw.SizedBox(height: 3),
            pw.Text('NIF/CIF: $clienteNif', style: const pw.TextStyle(fontSize: 9)),
          ],
          if (clienteDireccion != null && clienteDireccion.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(clienteDireccion, style: const pw.TextStyle(fontSize: 9)),
          ],
          if (clienteEmail != null && clienteEmail.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text('Email: $clienteEmail', style: const pw.TextStyle(fontSize: 9)),
          ],
          if (pedido.clienteTelefono != null) ...[
            pw.SizedBox(height: 2),
            pw.Text('Tel: ${pedido.clienteTelefono}', style: const pw.TextStyle(fontSize: 9)),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildInfoDocumento(Pedido pedido, TipoDocumentoTpv tipoDoc) {
    final fecha = _formatoFecha(pedido.fechaCreacion);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Número: ${pedido.id.substring(0, 8).toUpperCase()}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Fecha: $fecha', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Origen: ${_etiquetaOrigen(pedido.origen)}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            if (pedido.fechaEntrega != null) ...[
              pw.SizedBox(height: 2),
              pw.Text('Entrega: ${_formatoFecha(pedido.fechaEntrega!)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTablaLineasA4(List<LineaPedido> lineas) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(0.8),
        4: const pw.FlexColumnWidth(1.2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _celdaHeader('Descripción'),
            _celdaHeader('Cant.'),
            _celdaHeader('P. Unit.'),
            _celdaHeader('IVA'),
            _celdaHeader('Subtotal', align: pw.TextAlign.right),
          ],
        ),
        // Filas
        ...lineas.map((linea) => pw.TableRow(
              children: [
                _celdaFila(_nombreCompleto(linea), bold: true),
                _celdaFila('${linea.cantidad}'),
                _celdaFila('${linea.precioUnitario.toStringAsFixed(2)} €'),
                _celdaFila('${linea.ivaPorcentaje.toInt()}%'),
                _celdaFila('${linea.subtotal.toStringAsFixed(2)} €', align: pw.TextAlign.right),
              ],
            )),
      ],
    );
  }

  pw.Widget _buildTotalesA4(Pedido pedido, TipoDocumentoTpv tipoDoc) {
    // Calcular base imponible por tipo de IVA
    final Map<double, double> basesPorIva = {};
    final Map<double, double> cuotasIva = {};

    for (final linea in pedido.lineas) {
      final base = linea.subtotal;
      final tasa = linea.ivaPorcentaje;
      basesPorIva[tasa] = (basesPorIva[tasa] ?? 0) + base;
      cuotasIva[tasa] = (cuotasIva[tasa] ?? 0) + (base * tasa / 100);
    }

    final baseTotal = pedido.lineas.fold<double>(0, (sum, l) => sum + l.subtotal);
    final ivaTotal = cuotasIva.values.fold<double>(0, (sum, v) => sum + v);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Si es factura completa, mostrar desglose de IVA
        if (tipoDoc == TipoDocumentoTpv.facturaCompleta) ...[
          pw.Container(
            width: 250,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text('DESGLOSE IVA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                ...basesPorIva.entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Base ${e.key.toInt()}%', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('${e.value.toStringAsFixed(2)} €', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    )),
                pw.Divider(height: 6, color: PdfColors.grey400),
                ...cuotasIva.entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('IVA ${e.key.toInt()}%', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('${e.value.toStringAsFixed(2)} €', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
        ],

        // Total general
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              if (tipoDoc == TipoDocumentoTpv.facturaCompleta) ...[
                _filaTotal('Base imponible', baseTotal),
                _filaTotal('IVA', ivaTotal),
                pw.Divider(height: 8, color: PdfColors.blue300),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${pedido.total.toStringAsFixed(2)} €',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                ],
              ),
              if (tipoDoc == TipoDocumentoTpv.facturaSimplificada) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'IVA incluido',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _filaTotal(String label, double valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text('${valor.toStringAsFixed(2)} €', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.Widget _buildMetodoPago(MetodoPago metodo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 15, bottom: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          pw.Text('✓', style: pw.TextStyle(fontSize: 12, color: PdfColors.green800)),
          pw.SizedBox(width: 6),
          pw.Text(
            'Pagado con ${_etiquetaMetodoPago(metodo)}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.green900, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNotaLegal(TipoDocumentoTpv tipoDoc) {
    String texto = '';
    switch (tipoDoc) {
      case TipoDocumentoTpv.ticket:
        texto = 'Documento sin validez fiscal. Comprobante de venta.';
        break;
      case TipoDocumentoTpv.facturaSimplificada:
        texto = 'Factura simplificada (Art. 4 RD 1619/2012). IVA incluido. Válida hasta 3.000 €.';
        break;
      case TipoDocumentoTpv.facturaCompleta:
        texto = 'Factura completa. Documento con validez fiscal. El cliente puede deducirse el IVA.';
        break;
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Text(
        texto,
        style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN TICKET TÉRMICO (80mm / 58mm)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Uint8List> _generarTicketTermico({
    required Pedido pedido,
    required PdfBranding branding,
    required TipoDocumentoTpv tipoDoc,
    required int anchoMm,
    required ConfiguracionFacturacionTpv config,
    String? clienteNif,
    String? clienteEmail,
  }) async {
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold    = await PdfGoogleFonts.nunitoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );
    final anchoPt = anchoMm * 2.83; // mm a puntos

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(anchoPt, double.infinity),
        margin: const pw.EdgeInsets.all(8),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Nombre empresa
            pw.Text(
              branding.companyName ?? 'MI EMPRESA',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            if (branding.nif != null) ...[
              pw.SizedBox(height: 2),
              pw.Text('NIF: ${branding.nif}', style: const pw.TextStyle(fontSize: 8)),
            ],
            if (branding.domicilioFiscal != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(branding.domicilioFiscal!, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
            ],
            if (branding.telefono != null)
              pw.Text('Tel: ${branding.telefono}', style: const pw.TextStyle(fontSize: 7)),

            pw.SizedBox(height: 8),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            // Tipo de documento
            pw.Text(
              _tituloDocumento(tipoDoc).toUpperCase(),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Nº ${pedido.id.substring(0, 8).toUpperCase()}', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(_formatoFecha(pedido.fechaCreacion), style: const pw.TextStyle(fontSize: 8)),

            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            // Cliente (si es factura)
            if (tipoDoc != TipoDocumentoTpv.ticket) ...[
              pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(pedido.clienteNombre.isNotEmpty ? pedido.clienteNombre : 'Cliente general',
                  style: const pw.TextStyle(fontSize: 8)),
              if (clienteNif != null) pw.Text('NIF: $clienteNif', style: const pw.TextStyle(fontSize: 7)),
              if (clienteEmail != null) pw.Text(clienteEmail, style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 6),
              pw.Container(height: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
            ],

            // Líneas de productos
            ...pedido.lineas.map((linea) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(_nombreCompleto(linea), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('${linea.cantidad} x ${linea.precioUnitario.toStringAsFixed(2)} €',
                              style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('${linea.subtotal.toStringAsFixed(2)} €',
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                )),

            pw.SizedBox(height: 6),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 8),

            // Total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '${pedido.total.toStringAsFixed(2)} €',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),

            if (tipoDoc == TipoDocumentoTpv.facturaSimplificada) ...[
              pw.SizedBox(height: 2),
              pw.Text('(IVA incluido)', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ],

            pw.SizedBox(height: 8),
            pw.Container(height: 1, color: PdfColors.black),
            pw.SizedBox(height: 8),

            // Método de pago
            pw.Text(
              'Pago: ${_etiquetaMetodoPago(pedido.metodoPago)}',
              style: const pw.TextStyle(fontSize: 8),
            ),

            pw.SizedBox(height: 12),

            // Mensaje de agradecimiento
            pw.Text('¡Gracias por su visita!', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
            if (branding.correo != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(branding.correo!, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
            ],
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<PdfBranding> _cargarBrandingEmpresa(String empresaId) async {
    final doc = await _db.collection('empresas').doc(empresaId).get();
    final data = doc.data();
    if (data == null) return const PdfBranding();

    return PdfBranding(
      companyName: data['nombre'] as String?,
      nif: data['nif'] as String?,
      domicilioFiscal: data['direccion'] as String?,
      telefono: data['telefono'] as String?,
      correo: data['correo'] as String?,
      logoUrl: data['logo_url'] as String?,
      iban: data['iban'] as String?,
    );
  }

  Future<pdf_models.PdfTemplate?> _obtenerPlantilla(
    String empresaId,
    TipoDocumentoTpv tipoDoc,
    ConfiguracionFacturacionTpv config,
  ) async {
    String? plantillaId;
    switch (tipoDoc) {
      case TipoDocumentoTpv.facturaCompleta:
        plantillaId = config.plantillaIdFactura;
        break;
      case TipoDocumentoTpv.facturaSimplificada:
        plantillaId = config.plantillaIdSimplificada;
        break;
      case TipoDocumentoTpv.ticket:
        plantillaId = config.plantillaIdTicket;
        break;
    }

    if (plantillaId != null) {
      return _templateSvc.getPlantillaById(plantillaId);
    }

    // Si no hay plantilla configurada, buscar la por defecto
    return null;
  }

  Future<Uint8List?> _descargarLogo(String url) async {
    final ref = FirebaseStorage.instance.refFromURL(url);
    return await ref.getData(1024 * 1024); // Max 1MB
  }

  String _tituloDocumento(TipoDocumentoTpv tipo) {
    switch (tipo) {
      case TipoDocumentoTpv.ticket:
        return 'Ticket de Venta';
      case TipoDocumentoTpv.facturaSimplificada:
        return 'Factura Simplificada';
      case TipoDocumentoTpv.facturaCompleta:
        return 'Factura';
    }
  }

  PdfColor _colorPrimario(TipoDocumentoTpv tipo) {
    switch (tipo) {
      case TipoDocumentoTpv.ticket:
        return PdfColor.fromHex('#757575');
      case TipoDocumentoTpv.facturaSimplificada:
        return PdfColor.fromHex('#1565C0');
      case TipoDocumentoTpv.facturaCompleta:
        return PdfColor.fromHex('#0D47A1');
    }
  }

  String _formatoFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _etiquetaOrigen(OrigenPedido origen) {
    switch (origen) {
      case OrigenPedido.web:
        return 'Web';
      case OrigenPedido.app:
        return 'App';
      case OrigenPedido.whatsapp:
        return 'WhatsApp';
      case OrigenPedido.presencial:
        return 'Presencial';
      case OrigenPedido.tpvExterno:
        return 'TPV Externo';
    }
  }

  String _etiquetaMetodoPago(MetodoPago metodo) {
    switch (metodo) {
      case MetodoPago.efectivo:
        return 'Efectivo';
      case MetodoPago.tarjeta:
        return 'Tarjeta';
      case MetodoPago.bizum:
        return 'Bizum';
      case MetodoPago.paypal:
        return 'PayPal';
      case MetodoPago.mixto:
        return 'Mixto';
    }
  }

  String _nombreCompleto(LineaPedido linea) {
    if (linea.variante == null) return linea.productoNombre;
    return '${linea.productoNombre} (${linea.variante!.nombre})';
  }

  pw.Widget _celdaHeader(String texto, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        texto,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: align,
      ),
    );
  }

  pw.Widget _celdaFila(String texto, {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        textAlign: align,
      ),
    );
  }
}








