import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import '../domain/modelos/modelo111.dart';
import '../domain/modelos/empresa_config.dart';

/// Genera PDF del Modelo 111 con formato visual idéntico al formulario oficial.
/// 3 ejemplares por documento: sujeto pasivo / entidad colaboradora / administración.
class Modelo111PdfService {
  static const double _mm = PdfPageFormat.mm;

  // ── Estilos ──────────────────────────────────────────────────────────────
  static pw.TextStyle get _stTitulo => pw.TextStyle(
      fontSize: 11, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _stSubtitulo => pw.TextStyle(
      fontSize: 8.5, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _stNormal => const pw.TextStyle(fontSize: 7.5);
  static pw.TextStyle get _stBold => pw.TextStyle(
      fontSize: 7.5, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _stPeque => const pw.TextStyle(fontSize: 6.5);
  static pw.TextStyle get _stCasilla => pw.TextStyle(
      fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700);
  static pw.TextStyle get _stImporte => pw.TextStyle(
      fontSize: 8, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _stModeloNum => pw.TextStyle(
      fontSize: 22, fontWeight: pw.FontWeight.bold);

  static final PdfColor _grisCabecera = PdfColor.fromHex('#E8E8E8');
  static final PdfColor _grisClaro = PdfColor.fromHex('#F5F5F5');
  static const PdfColor _negro = PdfColors.black;

  /// Genera el PDF completo (3 ejemplares).
  static Future<Uint8List> generar(Modelo111 m, EmpresaConfig empresa) async {
    final pdf = pw.Document(
      title: 'Modelo 111 — ${m.ejercicio} ${m.trimestre}',
      author: empresa.razonSocial,
    );

    final ejemplares = [
      'Ejemplar para el sujeto pasivo',
      'Ejemplar para la Entidad colaboradora — AEAT',
      'Ejemplar para la Administración',
    ];

    for (final ejemplar in ejemplares) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.symmetric(horizontal: 15 * _mm, vertical: 12 * _mm),
        build: (ctx) => _buildFormulario(m, empresa, ejemplar),
      ));
    }

    return pdf.save();
  }

  /// Genera, guarda y comparte el PDF.
  static Future<void> generarYCompartir(
    BuildContext context,
    Modelo111 m,
    EmpresaConfig empresa,
  ) async {
    final bytes = await generar(m, empresa);
    final dir = await getTemporaryDirectory();
    final nombre = 'Modelo111_${m.ejercicio}_${m.trimestre}.pdf';
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(archivo.path)],
        text: 'Modelo 111 — ${m.ejercicio} ${m.trimestre}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FORMULARIO COMPLETO
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildFormulario(
    Modelo111 m,
    EmpresaConfig empresa,
    String ejemplar,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── CABECERA ─────────────────────────────────────────────────────
        _buildCabecera(m),
        pw.SizedBox(height: 3 * _mm),

        // ── DECLARANTE ───────────────────────────────────────────────────
        _buildDeclarante(m, empresa),
        pw.SizedBox(height: 3 * _mm),

        // ── LIQUIDACIÓN ──────────────────────────────────────────────────
        _buildLiquidacion(m),
        pw.SizedBox(height: 3 * _mm),

        // ── INGRESO / NEGATIVA / COMPLEMENTARIA ──────────────────────────
        _buildIngreso(m),
        pw.SizedBox(height: 2 * _mm),
        _buildNegativaComplementaria(m),
        pw.SizedBox(height: 3 * _mm),

        // ── FIRMA ────────────────────────────────────────────────────────
        _buildFirma(m),
        pw.Spacer(),

        // ── PIE ──────────────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Este documento no será válido sin la certificación mecánica o, '
              'en su defecto, firma autorizada.',
              style: _stPeque,
            ),
            pw.Text(ejemplar, style: pw.TextStyle(
                fontSize: 7, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildCabecera(Modelo111 m) {
    return pw.Container(
      padding: pw.EdgeInsets.all(2 * _mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _negro, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Agencia Tributaria', style: _stTitulo),
                pw.SizedBox(height: 1 * _mm),
                pw.Text('Retenciones e ingresos a cuenta del IRPF.', style: _stSubtitulo),
                pw.Text(
                  'Rendimientos del trabajo y de actividades económicas, '
                  'premios y determinadas ganancias patrimoniales e '
                  'imputaciones de renta.',
                  style: _stPeque,
                ),
                pw.SizedBox(height: 1 * _mm),
                pw.Text('Declaración — Documento de ingreso', style: _stBold),
              ],
            ),
          ),
          pw.Container(
            width: 25 * _mm,
            height: 18 * _mm,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _negro, width: 1),
            ),
            child: pw.Center(
              child: pw.Text('111', style: _stModeloNum),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDeclarante(Modelo111 m, EmpresaConfig empresa) {
    return pw.Container(
      padding: pw.EdgeInsets.all(2 * _mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _negro, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('Identificación (1)', style: _stSubtitulo),
              pw.Spacer(),
              pw.Text('Devengo (2)', style: _stSubtitulo),
            ],
          ),
          pw.Divider(height: 1 * _mm, thickness: 0.3),
          pw.SizedBox(height: 1 * _mm),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Datos declarante
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _campoLabel('NIF', empresa.nifNormalizado),
                    _campoLabel('Apellidos y nombre o razón social',
                        empresa.razonSocial),
                  ],
                ),
              ),
              pw.SizedBox(width: 4 * _mm),
              // Devengo
              pw.Container(
                width: 40 * _mm,
                padding: pw.EdgeInsets.all(1.5 * _mm),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _negro, width: 0.3),
                ),
                child: pw.Column(
                  children: [
                    _campoLabel('Ejercicio', m.ejercicio.toString()),
                    _campoLabel('Período', m.periodoAeat),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLiquidacion(Modelo111 m) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _negro, width: 0.5),
      ),
      child: pw.Column(
        children: [
          // Cabecera sección
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(1.5 * _mm),
            color: _grisCabecera,
            child: pw.Text('Liquidación (3)', style: _stSubtitulo),
          ),
          // Cabecera tabla
          _filaCabeceraSecciones(),
          // I. Rendimientos del trabajo
          _filaSeccion('I. Rendimientos del trabajo'),
          _filaDatos('Dinerarios', '01', m.c01, '02', m.c02, '03', m.c03),
          _filaDatos('En especie', '04', m.c04, '05', m.c05, '06', m.c06),
          // II. Rendimientos actividades económicas
          _filaSeccion('II. Rtos. actividades económicas'),
          _filaDatos('Dinerarios', '07', m.c07, '08', m.c08, '09', m.c09),
          _filaDatos('En especie', '10', m.c10, '11', m.c11, '12', m.c12),
          // III. Premios
          _filaSeccion('III. Premios por juegos, concursos, rifas...'),
          _filaDatos('En metálico', '13', m.c13, '14', m.c14, '15', m.c15),
          _filaDatos('En especie', '16', m.c16, '17', m.c17, '18', m.c18),
          // IV. Ganancias patrimoniales forestales
          _filaSeccion('IV. Ganancias patrimoniales forestales'),
          _filaDatos('Dinerarias', '19', m.c19, '20', m.c20, '21', m.c21),
          _filaDatos('En especie', '22', m.c22, '23', m.c23, '24', m.c24),
          // V. Contraprestaciones cesión derechos imagen
          _filaSeccion('V. Contrapr. cesión derechos imagen'),
          _filaDatos('Dinerarias/especie', '25', m.c25, '26', m.c26, '27', m.c27),

          pw.Divider(height: 0.5 * _mm, thickness: 1),

          // TOTALES
          _filaTotales(m),
        ],
      ),
    );
  }

  static pw.Widget _filaCabeceraSecciones() {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 1.5 * _mm, vertical: 0.8 * _mm),
      color: _grisClaro,
      child: pw.Row(
        children: [
          pw.SizedBox(width: 45 * _mm),
          _colCab('Nº perceptores', flex: 2),
          _colCab('Importe de las\npercepciones', flex: 3),
          _colCab('Importe retenciones /\ningresos a cuenta', flex: 3),
        ],
      ),
    );
  }

  static pw.Widget _colCab(String txt, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(txt, style: _stCasilla, textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _filaSeccion(String titulo) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(horizontal: 1.5 * _mm, vertical: 0.5 * _mm),
      color: _grisClaro,
      child: pw.Text(titulo, style: pw.TextStyle(
          fontSize: 7, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _filaDatos(
    String subtipo,
    String casPerc, int nPerc,
    String casImporte, double importe,
    String casRet, double retencion,
  ) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 1.5 * _mm, vertical: 0.3 * _mm),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 0.2)),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 45 * _mm,
              child: pw.Text(subtipo, style: _stNormal)),
          _celdaCasilla(casPerc, nPerc.toString(), flex: 2),
          _celdaCasilla(casImporte, _fmtEuros(importe), flex: 3),
          _celdaCasilla(casRet, _fmtEuros(retencion), flex: 3),
        ],
      ),
    );
  }

  static pw.Widget _celdaCasilla(String casilla, String valor, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: 0.5 * _mm, vertical: 0.3 * _mm),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
        ),
        child: pw.Row(
          children: [
            pw.Text('[$casilla]', style: _stCasilla),
            pw.Spacer(),
            pw.Text(valor, style: _stNormal),
          ],
        ),
      ),
    );
  }

  static pw.Widget _filaTotales(Modelo111 m) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(1.5 * _mm),
      child: pw.Column(
        children: [
          _filaTotal('Total retenciones e ingresos a cuenta', '28', m.c28),
          _filaTotal('A deducir (exclusivamente en complementaria)', '29', m.c29),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 1 * _mm),
            color: _grisClaro,
            child: _filaTotal('Resultado a ingresar', '30', m.c30, bold: true),
          ),
        ],
      ),
    );
  }

  static pw.Widget _filaTotal(String label, String casilla, double valor,
      {bool bold = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 0.3 * _mm),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style: bold ? _stBold : _stNormal),
          ),
          pw.Text('[$casilla]', style: _stCasilla),
          pw.SizedBox(width: 2 * _mm),
          pw.Container(
            width: 30 * _mm,
            padding: pw.EdgeInsets.all(0.5 * _mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: bold ? 1 : 0.3),
            ),
            child: pw.Text(_fmtEuros(valor),
                style: bold ? _stImporte : _stNormal,
                textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildIngreso(Modelo111 m) {
    return pw.Container(
      padding: pw.EdgeInsets.all(2 * _mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _negro, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Ingreso (4)', style: _stSubtitulo),
          pw.SizedBox(height: 1 * _mm),
          pw.Row(
            children: [
              pw.Text('Importe del ingreso:  I ', style: _stBold),
              pw.Container(
                width: 30 * _mm,
                padding: pw.EdgeInsets.all(0.5 * _mm),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5)),
                child: pw.Text(_fmtEuros(m.c30),
                    style: _stImporte, textAlign: pw.TextAlign.right),
              ),
              pw.Text('  (casilla [30])', style: _stPeque),
            ],
          ),
          pw.SizedBox(height: 1 * _mm),
          pw.Text('Forma de pago: En efectivo ☐  E.C. adeudo en cuenta ☐',
              style: _stPeque),
        ],
      ),
    );
  }

  static pw.Widget _buildNegativaComplementaria(Modelo111 m) {
    return pw.Row(
      children: [
        // Negativa
        pw.Expanded(
          child: pw.Container(
            padding: pw.EdgeInsets.all(1.5 * _mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _negro, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Negativa (5)', style: _stSubtitulo),
                pw.SizedBox(height: 0.5 * _mm),
                pw.Row(children: [
                  pw.Container(width: 3 * _mm, height: 3 * _mm,
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.5)),
                      child: m.tipoAutomatico == TipoDeclaracion111.negativa
                          ? pw.Center(child: pw.Text('X', style: _stBold))
                          : pw.SizedBox()),
                  pw.SizedBox(width: 1 * _mm),
                  pw.Text('Declaración negativa', style: _stNormal),
                ]),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 2 * _mm),
        // Complementaria
        pw.Expanded(
          child: pw.Container(
            padding: pw.EdgeInsets.all(1.5 * _mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _negro, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Complementaria (6)', style: _stSubtitulo),
                pw.SizedBox(height: 0.5 * _mm),
                pw.Row(children: [
                  pw.Container(width: 3 * _mm, height: 3 * _mm,
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.5)),
                      child: m.tipo == TipoDeclaracion111.complementaria
                          ? pw.Center(child: pw.Text('X', style: _stBold))
                          : pw.SizedBox()),
                  pw.SizedBox(width: 1 * _mm),
                  pw.Text('Declaración complementaria', style: _stNormal),
                ]),
                if (m.justificanteComplementaria != null) ...[
                  pw.SizedBox(height: 0.5 * _mm),
                  pw.Text('Nº just.: ${m.justificanteComplementaria}', style: _stPeque),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFirma(Modelo111 m) {
    return pw.Container(
      padding: pw.EdgeInsets.all(2 * _mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _negro, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Firma (7)', style: _stSubtitulo),
          pw.SizedBox(height: 1 * _mm),
          pw.Text(
            '__________________, a ____ de __________________ de ${m.ejercicio}',
            style: _stNormal,
          ),
          pw.SizedBox(height: 8 * _mm),
          pw.Text('Firma:', style: _stNormal),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _campoLabel(String label, String valor) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 0.4 * _mm),
      child: pw.Row(children: [
        pw.Text('$label: ', style: _stCasilla),
        pw.Text(valor, style: _stBold),
      ]),
    );
  }

  static String _fmtEuros(double v) =>
      v == 0 ? '' : '${v.toStringAsFixed(2)} €';
}

