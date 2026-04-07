import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/modelos/finiquito.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE CARTA DE CESE
// Templates legales por tipo de causa + generación de PDF con membrete.
// ═══════════════════════════════════════════════════════════════════════════════

class CartaCeseService {
  static final CartaCeseService _i = CartaCeseService._();
  factory CartaCeseService() => _i;
  CartaCeseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const double _mm = PdfPageFormat.mm;

  // ═══════════════════════════════════════════════════════════════════════════
  // TEMPLATES DE TEXTO LEGAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve el template de texto para la carta según el tipo de cese.
  static String templateTexto({
    required CausaBaja causaBaja,
    required String nombreEmpleado,
    required String nombreEmpresa,
    required DateTime fechaCese,
    String? motivoDetallado,
    int? diasPreavisoRestantes,
  }) {
    final fmtFecha = _fmtDate(fechaCese);
    switch (causaBaja) {
      case CausaBaja.despidoProcedente:
        return '''En virtud de lo dispuesto en los artículos 52 y 53 del Estatuto de los Trabajadores, esta empresa le comunica la extinción de su contrato de trabajo por causas objetivas.

CAUSA ESPECÍFICA:
${motivoDetallado ?? '[Especificar la causa objetiva concreta: económica, técnica, organizativa o productiva]'}

En consecuencia, le comunicamos que la extinción de su contrato de trabajo tendrá efectos desde el día $fmtFecha.

De conformidad con lo establecido en el artículo 53.1.b) ET, dispondrá de un preaviso de 15 días desde la notificación de la presente carta, durante los cuales tendrá derecho a una licencia de 6 horas semanales para buscar nuevo empleo.

Asimismo, se pone a su disposición en este acto la indemnización correspondiente de 20 días de salario por año de servicio, con el límite de 12 mensualidades, según establece el artículo 53.1.b) ET.

Contra la presente decisión, podrá interponer demanda ante el Juzgado de lo Social en el plazo de 20 días hábiles desde la notificación (art. 59.3 ET).''';

      case CausaBaja.despidoImprocedente:
        return '''En $nombreEmpresa, con todos los respetos debidos, le comunicamos la extinción de su relación laboral con efectos desde el día $fmtFecha.

${motivoDetallado != null ? 'MOTIVOS:\n$motivoDetallado\n\n' : ''}La empresa reconoce la improcedencia del despido y, en consecuencia, pone a su disposición la indemnización correspondiente de 33 días de salario por año de servicio prestado a partir del 12 de febrero de 2012, y 45 días por año para el período anterior, con el límite de 720 días de salario (art. 56.1 ET).

Lamentamos que no haya sido posible mantener la relación laboral y le deseamos éxito en su futuro profesional.''';

      case CausaBaja.finContrato:
        return '''Le comunicamos que el contrato de trabajo temporal que le une con $nombreEmpresa, formalizado en su día, expirará según lo pactado el día $fmtFecha, conforme a lo establecido en el artículo 49.1.c) del Estatuto de los Trabajadores.

${motivoDetallado != null ? 'OBSERVACIONES:\n$motivoDetallado\n\n' : ''}En cumplimiento de la normativa vigente, se le abonará la indemnización correspondiente de 12 días de salario por año de servicio trabajado, de acuerdo con lo establecido en la legislación aplicable.

Le agradecemos los servicios prestados durante su relación laboral con esta empresa y le deseamos éxito en su futuro profesional.''';

      case CausaBaja.dimision:
        return '''En respuesta a la comunicación de su renuncia voluntaria al puesto de trabajo en $nombreEmpresa, la empresa acepta formalmente su dimisión con efectos desde el día $fmtFecha, de conformidad con lo dispuesto en el artículo 49.1.d) del Estatuto de los Trabajadores.

Le agradecemos sinceramente los años de dedicación y esfuerzo durante su etapa en nuestra empresa. Su contribución ha sido muy valiosa para el equipo y para la organización.

Le deseamos todo el éxito en su nueva etapa profesional y personal.''';

      case CausaBaja.mutuoAcuerdo:
        return '''Con la presente comunicación, $nombreEmpresa y D./Dña. $nombreEmpleado, de mutuo acuerdo, proceden a la extinción del contrato de trabajo que les une, con efectos desde el día $fmtFecha, de conformidad con lo establecido en el artículo 49.1.a) del Estatuto de los Trabajadores.

${motivoDetallado != null ? 'CONDICIONES ACORDADAS:\n$motivoDetallado\n\n' : ''}Ambas partes manifiestan su conformidad con los términos de esta extinción y declaran que quedan saldadas y finiquitadas todas las obligaciones derivadas de la relación laboral.

$nombreEmpresa agradece a D./Dña. $nombreEmpleado su colaboración y dedicación durante el tiempo de prestación de servicios.''';

      case CausaBaja.ere:
        return '''En virtud del Expediente de Regulación de Empleo tramitado al amparo del artículo 51 del Estatuto de los Trabajadores, esta empresa le comunica la extinción de su contrato de trabajo con efectos desde el día $fmtFecha.

${motivoDetallado != null ? 'CAUSA:\n$motivoDetallado\n\n' : ''}De conformidad con lo acordado en el procedimiento de consultas y/o con la Autoridad Laboral, se le abonará la indemnización pactada.''';

      case CausaBaja.jubilacion:
        return '''En respuesta a su solicitud de jubilación, $nombreEmpresa acepta formalmente la extinción de la relación laboral con efectos desde el día $fmtFecha, de conformidad con lo dispuesto en el artículo 49.1.f) del Estatuto de los Trabajadores.

Le expresamos nuestro más sincero agradecimiento por los años de dedicación y profesionalidad demostrados durante su etapa en esta empresa.

Le deseamos una jubilación plena y merecida.''';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERAR PDF
  // ═══════════════════════════════════════════════════════════════════════════

  /// Genera el PDF de la carta de cese con membrete de empresa.
  static Future<Uint8List> generarPDF({
    required Finiquito finiquito,
    required String textoCarta,
    required Map<String, dynamic> datosEmpresa,
  }) async {
    final pdf = pw.Document(
      title: 'Carta de Cese — ${finiquito.empleadoNombre}',
      author: datosEmpresa['nombre'] as String? ?? 'PlaneaG',
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.symmetric(horizontal: 20 * _mm, vertical: 20 * _mm),
      build: (ctx) => _buildContenidoCarta(
        finiquito: finiquito,
        textoCarta: textoCarta,
        datosEmpresa: datosEmpresa,
      ),
    ));

    return pdf.save();
  }

  static pw.Widget _buildContenidoCarta({
    required Finiquito finiquito,
    required String textoCarta,
    required Map<String, dynamic> datosEmpresa,
  }) {
    final nombreEmpresa =
        datosEmpresa['nombre'] as String? ?? finiquito.empresaNombre ?? '—';
    final cifEmpresa =
        datosEmpresa['cif'] as String? ?? finiquito.empresaCif ?? '—';
    final domicilioEmpresa = datosEmpresa['domicilio'] as String? ?? '—';
    final representante = datosEmpresa['representante'] as String? ?? '—';
    final hoy = _fmtDate(DateTime.now());

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Membrete de empresa ──────────────────────────────────────────────
        pw.Container(
          padding: pw.EdgeInsets.all(3 * _mm),
          decoration: pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(nombreEmpresa,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('CIF: $cifEmpresa',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(domicilioEmpresa,
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('CARTA DE CESE',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#334155'))),
                  pw.Text(hoy, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8 * _mm),

        // ── Destinatario ─────────────────────────────────────────────────────
        pw.Text('A la atención de:',
            style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 1 * _mm),
        pw.Text('D./Dña. ${finiquito.empleadoNombre}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text('NIF: ${finiquito.empleadoNif ?? "—"}',
            style: const pw.TextStyle(fontSize: 8)),
        if (finiquito.naf != null)
          pw.Text('NAF: ${finiquito.naf}',
              style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 6 * _mm),

        // ── Asunto ───────────────────────────────────────────────────────────
        pw.Text('Asunto: ${finiquito.causaBaja.etiqueta}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 1 * _mm),
        pw.Text('Ref. contractual: Contrato de trabajo desde '
            '${_fmtDate(finiquito.fechaInicioContrato)}',
            style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 6 * _mm),

        // ── Saludo ───────────────────────────────────────────────────────────
        pw.Text('Estimado/a ${finiquito.empleadoNombre}:',
            style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4 * _mm),

        // ── Cuerpo del texto ─────────────────────────────────────────────────
        pw.Text(textoCarta,
            style: const pw.TextStyle(fontSize: 8.5),
            textAlign: pw.TextAlign.justify),
        pw.SizedBox(height: 10 * _mm),

        // ── Nota legal ───────────────────────────────────────────────────────
        pw.Container(
          padding: pw.EdgeInsets.all(2 * _mm),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8F9FA'),
            border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
          ),
          child: pw.Text(
            finiquito.causaBaja.descripcionLegal,
            style: pw.TextStyle(
                fontSize: 7, fontStyle: pw.FontStyle.italic),
          ),
        ),
        pw.SizedBox(height: 10 * _mm),

        // ── Firma empresa ────────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 15 * _mm),
                pw.Container(
                  width: 60 * _mm,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        top: pw.BorderSide(width: 0.5)),
                  ),
                ),
                pw.Text(representante,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('En representación de $nombreEmpresa',
                    style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          ],
        ),

        // ── Acuse de recibo ──────────────────────────────────────────────────
        pw.SizedBox(height: 8 * _mm),
        pw.Container(
          padding: pw.EdgeInsets.all(2.5 * _mm),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ACUSE DE RECIBO',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2 * _mm),
              pw.Text(
                'D./Dña. ${finiquito.empleadoNombre}, con NIF ${finiquito.empleadoNif ?? "—"}, '
                'declara haber recibido la presente comunicación en fecha: ___________',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 8 * _mm),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Container(
                        width: 55 * _mm,
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                                top: pw.BorderSide(width: 0.5)))),
                    pw.Text('Firma del trabajador',
                        style: const pw.TextStyle(fontSize: 7)),
                  ]),
                  pw.Column(children: [
                    pw.Container(
                        width: 55 * _mm,
                        decoration: const pw.BoxDecoration(
                            border: pw.Border(
                                top: pw.BorderSide(width: 0.5)))),
                    pw.Text('Firma empresa',
                        style: const pw.TextStyle(fontSize: 7)),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GUARDAR EN STORAGE + FIRESTORE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Genera, sube el PDF a Storage y actualiza el finiquito.
  Future<String> generar({
    required Finiquito finiquito,
    required String textoCarta,
    required Map<String, dynamic> datosEmpresa,
  }) async {
    final bytes = await generarPDF(
      finiquito: finiquito,
      textoCarta: textoCarta,
      datosEmpresa: datosEmpresa,
    );

    final path =
        'empresas/${finiquito.empresaId}/finiquitos/cartas_cese/'
        'carta_${finiquito.id}.pdf';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes,
        SettableMetadata(contentType: 'application/pdf'));
    final url = await ref.getDownloadURL();

    // Actualizar finiquito con la URL
    await _db
        .collection('empresas')
        .doc(finiquito.empresaId)
        .collection('finiquitos')
        .doc(finiquito.id)
        .update({'carta_cese_url': url});

    return url;
  }

  /// Genera el PDF y lo comparte directamente.
  Future<void> generarYCompartir({
    required Finiquito finiquito,
    required String textoCarta,
    required Map<String, dynamic> datosEmpresa,
  }) async {
    final bytes = await generarPDF(
      finiquito: finiquito,
      textoCarta: textoCarta,
      datosEmpresa: datosEmpresa,
    );
    final dir = await getTemporaryDirectory();
    final nombre =
        'carta_cese_${finiquito.empleadoNombre.replaceAll(' ', '_')}.pdf';
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(archivo.path)],
        text: 'Carta de cese — ${finiquito.empleadoNombre}');
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

