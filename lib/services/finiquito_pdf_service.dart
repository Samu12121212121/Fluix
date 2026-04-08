      final nombre = 'finiquito_${f.empleadoNombre.replaceAll(' ', '_')}_'
          '${f.fechaBaja.day}${f.fechaBaja.month}${f.fechaBaja.year}.pdf';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import '../domain/modelos/finiquito.dart';

/// Genera PDF de finiquito con formato laboral español.
class FiniquitoPdfService {
  static const double _mm = PdfPageFormat.mm;

  // ── Estilos ──────────────────────────────────────────────────────────────
  static pw.TextStyle get _stTitulo => pw.TextStyle(
      fontSize: 12, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _stSubtitulo => pw.TextStyle(
      fontSize: 9, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _stNormal => const pw.TextStyle(fontSize: 8);
  static pw.TextStyle get _stNormalBold => pw.TextStyle(
      fontSize: 8, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _stPeque => const pw.TextStyle(fontSize: 7);
  static pw.TextStyle get _stLegal => pw.TextStyle(
      fontSize: 6.5, fontStyle: pw.FontStyle.italic);

  static final PdfColor _grisClaro = PdfColor.fromHex('#F2F2F2');
  static const PdfColor _negro = PdfColors.black;

  /// Genera el PDF con la firma incrustada y texto legal de conformidad.
  static Future<Uint8List> generarConFirma(
    Finiquito f, {
    required Uint8List firmaBytes,
    String ciudad = 'Guadalajara',
  }) async {
    final pdf = pw.Document(
      title: 'Finiquito Firmado — ${f.empleadoNombre}',
      author: f.empresaNombre ?? 'PlaneaG',
    );

    final firmaImage = pw.MemoryImage(firmaBytes);
    final fechaFirmaTexto = _fmtDate(DateTime.now());

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.symmetric(
        horizontal: 18 * _mm,
        vertical: 15 * _mm,
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildContenido(f),
          pw.SizedBox(height: 8 * _mm),
          // ── Bloque de conformidad ────────────────────────────────────────
          pw.Container(
            padding: pw.EdgeInsets.all(3 * _mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DECLARACIÓN DE CONFORMIDAD',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2 * _mm),
                pw.Text(
                  'Declaro haber recibido la cantidad de '
                  '${f.liquidoPercibir.toStringAsFixed(2)} euros '
                  'en concepto de liquidación final, quedando saldadas '
                  'todas las deudas entre las partes.\n\n'
                  'Conforme y en prueba de conformidad con la liquidación '
                  'anterior, firmo el presente finiquito en $ciudad, '
                  'a $fechaFirmaTexto.',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 4 * _mm),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Firma del trabajador:',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2 * _mm),
                        pw.Image(firmaImage, width: 60 * _mm, height: 25 * _mm),
                        pw.Divider(height: 1 * _mm, thickness: 0.5),
                        pw.Text('${f.empleadoNombre}  |  NIF: ${f.empleadoNif ?? "—"}',
                            style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Firma empresa / representante:',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2 * _mm),
                        pw.Container(
                          width: 60 * _mm, height: 25 * _mm,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                                color: PdfColors.grey400, width: 0.3),
                          ),
                        ),
                        pw.Divider(height: 1 * _mm, thickness: 0.5),
                        pw.Text('${f.empresaNombre ?? "—"}',
                            style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));

    return pdf.save();
  }

  /// Genera el PDF y lo devuelve como bytes.
  static Future<Uint8List> generar(Finiquito f) async {
    final pdf = pw.Document(
      title: 'Finiquito — ${f.empleadoNombre}',
      author: f.empresaNombre ?? 'PlaneaG',
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.symmetric(
        horizontal: 18 * _mm,
        vertical: 15 * _mm,
      ),
      build: (ctx) => _buildContenido(f),
    ));

    return pdf.save();
  }

  /// Genera, guarda en temporal y comparte el PDF.
  static Future<void> generarYCompartir(
    BuildContext context,
    Finiquito f,
    final bytes = await generar(f);
    final dir = await getTemporaryDirectory();
        '${f.fechaBaja.day}${f.fechaBaja.month}${f.fechaBaja.year}.pdf';
    final dir = await getTemporaryDirectory();

    // En Web no existe dart:io — usar Printing.sharePdf directamente
        '${f.fechaBaja.day}${f.fechaBaja.month}${f.fechaBaja.year}.pdf';
      return;
    }

    final dir = await getTemporaryDirectory();
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(archivo.path)],
      text: 'Finiquito — ${f.empleadoNombre}',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTRUCCIÓN DEL CONTENIDO
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildContenido(Finiquito f) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Título ─────────────────────────────────────────────────────────
        pw.Center(child: pw.Text('DOCUMENTO DE LIQUIDACIÓN Y FINIQUITO', style: _stTitulo)),
        pw.SizedBox(height: 3 * _mm),
        pw.Center(child: pw.Text(f.causaBaja.descripcionLegal, style: _stPeque)),
        pw.SizedBox(height: 5 * _mm),

        // ── Datos empresa ──────────────────────────────────────────────────
        _buildSeccion('DATOS DE LA EMPRESA', [
          _fila('Empresa:', f.empresaNombre ?? '—'),
          _fila('CIF:', f.empresaCif ?? '—'),
        ]),
        pw.SizedBox(height: 3 * _mm),

        // ── Datos empleado ─────────────────────────────────────────────────
        _buildSeccion('DATOS DEL TRABAJADOR', [
          _fila('Nombre:', f.empleadoNombre),
          _fila('NIF:', f.empleadoNif ?? '—'),
          _fila('Nº Seg. Social:', f.empleadoNss ?? '—'),
          _fila('Fecha alta:', _fmtDate(f.fechaInicioContrato)),
          _fila('Fecha baja:', _fmtDate(f.fechaBaja)),
          _fila('Antigüedad:', f.antiguedadTexto),
          _fila('Causa baja:', f.causaBaja.etiqueta),
          _fila('Salario bruto anual:', '${f.salarioBrutoAnual.toStringAsFixed(2)} €'),
        ]),
        pw.SizedBox(height: 4 * _mm),

        // ── Tabla de conceptos ─────────────────────────────────────────────
        pw.Text('CONCEPTOS', style: _stSubtitulo),
        pw.SizedBox(height: 2 * _mm),
        _buildTablaConceptos(f),
        pw.SizedBox(height: 4 * _mm),

        // ── Resumen totales ────────────────────────────────────────────────
        _buildResumenTotales(f),
        pw.SizedBox(height: 8 * _mm),

        // ── Firma ──────────────────────────────────────────────────────────
        _buildBloqueeFirma(f),

        // ── Nota legal ─────────────────────────────────────────────────────
        pw.SizedBox(height: 6 * _mm),
        pw.Container(
          padding: pw.EdgeInsets.all(2 * _mm),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
          ),
          child: pw.Text(
            'La percepción de las cantidades reflejadas en este documento de '
            'liquidación y finiquito no implica conformidad con el despido ni '
            'renuncia por parte del trabajador al ejercicio de las acciones '
            'legales que pudieran corresponderle (art. 49.2 ET).',
            style: _stLegal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSeccion(String titulo, List<pw.Widget> hijos) {
    return pw.Container(
      padding: pw.EdgeInsets.all(2.5 * _mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _negro, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(titulo, style: _stSubtitulo),
          pw.Divider(height: 1 * _mm, thickness: 0.3),
          pw.SizedBox(height: 1 * _mm),
          ...hijos,
        ],
      ),
    );
  }

  static pw.Widget _fila(String label, String valor) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 0.5 * _mm),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 45 * _mm,
          child: pw.Text(label, style: _stNormalBold),
        ),
        pw.Expanded(child: pw.Text(valor, style: _stNormal)),
      ]),
    );
  }

  static pw.Widget _buildTablaConceptos(Finiquito f) {
    final filas = <List<String>>[];

    // Salario pendiente
    filas.add([
      'Salario pendiente (${f.diasTrabajadosMes} de ${f.diasMesBaja} días)',
      '${f.diasTrabajadosMes}',
      '${f.salarioPendiente.toStringAsFixed(2)} €',
    ]);

    // Vacaciones no disfrutadas
    filas.add([
      'Vacaciones no disfrutadas',
      '${f.diasVacacionesPendientes}',
      '${f.importeVacaciones.toStringAsFixed(2)} €',
    ]);

    // Pagas extra prorrateadas
    for (final paga in f.prorrataPagasExtra) {
      filas.add([
        '${paga.nombre} (prorrata)',
        '${paga.diasDevengados}',
        '${paga.importe.toStringAsFixed(2)} €',
      ]);
    }

    // Indemnización
    if (f.indemnizacion > 0) {
      String detalle = 'Indemnización — ${f.causaBaja.etiqueta}';
      if (f.indemnizacionTramoAnterior != null) {
        detalle += '\n  Tramo pre-12/02/2012: ${f.indemnizacionTramoAnterior!.toStringAsFixed(2)} €'
                   '\n  Tramo post-12/02/2012: ${f.indemnizacionTramoPosterior!.toStringAsFixed(2)} €';
      }
      filas.add([
        detalle,
        '${f.diasIndemnizacion.toStringAsFixed(1)}',
        '${f.indemnizacion.toStringAsFixed(2)} €',
      ]);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _negro, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.5),
      },
      children: [
        // Cabecera
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _grisClaro),
          children: [
            _celda('Concepto', bold: true),
            _celda('Días', bold: true, align: pw.TextAlign.center),
            _celda('Importe', bold: true, align: pw.TextAlign.right),
          ],
        ),
        // Filas de conceptos
        ...filas.map((fila) => pw.TableRow(children: [
          _celda(fila[0]),
          _celda(fila[1], align: pw.TextAlign.center),
          _celda(fila[2], align: pw.TextAlign.right),
        ])),
      ],
    );
  }

  static pw.Widget _buildResumenTotales(Finiquito f) {
    final lineas = <List<String>>[
      ['TOTAL BRUTO', '${f.totalBruto.toStringAsFixed(2)} €'],
      ['(-) Retención IRPF (${f.porcentajeIrpf.toStringAsFixed(2)}%)', '-${f.importeIrpf.toStringAsFixed(2)} €'],
      ['(-) Cuota obrera SS', '-${f.cuotaObreraSSFiniquito.toStringAsFixed(2)} €'],
    ];

    // Si hay exención IRPF, mostrar detalle
    if (f.indemnizacionExenta > 0) {
      lineas.insert(1, [
        '  Indemnización exenta IRPF (art. 7.e LIRPF)',
        '${f.indemnizacionExenta.toStringAsFixed(2)} €',
      ]);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _negro, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        ...lineas.map((l) => pw.TableRow(children: [
          _celda(l[0], bold: l[0].startsWith('TOTAL') || l[0].startsWith('LÍQUIDO')),
          _celda(l[1], align: pw.TextAlign.right,
              bold: l[0].startsWith('TOTAL') || l[0].startsWith('LÍQUIDO')),
        ])),
        // Línea final: LÍQUIDO A PERCIBIR
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _grisClaro),
          children: [
            _celda('LÍQUIDO A PERCIBIR', bold: true),
            _celda('${f.liquidoPercibir.toStringAsFixed(2)} €',
                align: pw.TextAlign.right, bold: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildBloqueeFirma(Finiquito f) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('RECIBÍ CONFORME', style: _stSubtitulo),
            pw.SizedBox(height: 15 * _mm),
            pw.Container(
              width: 60 * _mm,
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(width: 0.5)),
              ),
              child: pw.Text('Firma del trabajador', style: _stPeque),
            ),
            pw.SizedBox(height: 2 * _mm),
            pw.Text('Nombre: ${f.empleadoNombre}', style: _stPeque),
            pw.Text('NIF: ${f.empleadoNif ?? "—"}', style: _stPeque),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('LA EMPRESA', style: _stSubtitulo),
            pw.SizedBox(height: 15 * _mm),
            pw.Container(
              width: 60 * _mm,
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(width: 0.5)),
              ),
              child: pw.Text('Firma y sello de la empresa', style: _stPeque),
            ),
            pw.SizedBox(height: 2 * _mm),
            pw.Text('Empresa: ${f.empresaNombre ?? "—"}', style: _stPeque),
            pw.Text('CIF: ${f.empresaCif ?? "—"}', style: _stPeque),
          ],
        ),
      ],
    );
  }

  static pw.Widget _celda(String texto, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(1.5 * _mm),
      child: pw.Text(texto, style: bold ? _stNormalBold : _stNormal,
          textAlign: align),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

