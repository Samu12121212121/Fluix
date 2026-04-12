import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/modelos/modelo202.dart';
import '../../domain/modelos/empresa_config.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD.202 EXPORTER — PDF borrador (presentación online obligatoria)
// ═══════════════════════════════════════════════════════════════════════════════

class Mod202Exporter {
  static Future<Uint8List> generarPDF({
    required Modelo202 modelo,
    required EmpresaConfig empresa,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _cabecera(modelo, empresa),
              pw.SizedBox(height: 14),
              _seccionDatos(modelo, empresa),
              pw.SizedBox(height: 14),
              _seccionCasillas(modelo),
              pw.SizedBox(height: 14),
              _seccionResultado(modelo),
              pw.SizedBox(height: 20),
              _piePagina(modelo),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cabecera(Modelo202 m, EmpresaConfig e) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#4A148C'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MODELO 202',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Pago fraccionado — Impuesto sobre Sociedades',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 10)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('${m.ejercicio} — ${m.periodo.nombre}',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Modalidad A (art. 40.2 LIS)',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _seccionDatos(Modelo202 m, EmpresaConfig e) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SUJETO PASIVO',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text('NIF: ${e.nif}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Razón social: ${e.razonSocial}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Forma jurídica: ${e.formaJuridica.etiqueta}',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('DEVENGO',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text('Ejercicio: ${m.ejercicio}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Período: ${m.periodo.codigo} (${m.periodo.nombre})',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                  'Plazo: hasta ${_fmtDate(Modelo202.calcularPlazoLimite(m.ejercicio, m.periodo))}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _seccionCasillas(Modelo202 m) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('MODALIDAD A — ART. 40.2 LIS',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#4A148C'))),
          pw.SizedBox(height: 8),
          _filaCasilla('[01]', 'Base del pago fraccionado (cuota IS último ejercicio)', m.c01),
          _filaCasilla('[03]', '18% de [01]', m.c03, bold: true),
          pw.Divider(height: 6, thickness: 0.5),
          _filaCasilla('[04]', 'Deducciones y bonificaciones', m.c04),
          _filaCasilla('[05]', 'Retenciones e ingresos a cuenta', m.c05),
          _filaCasilla('[06]', 'Pagos fraccionados anteriores', m.c06),
          if (m.esComplementaria)
            _filaCasilla('[07]', 'A deducir (complementaria)', m.c07),
        ],
      ),
    );
  }

  static pw.Widget _seccionResultado(Modelo202 m) {
    final esPositivo = m.resultadoIngresar > 0;
    final color = esPositivo
        ? PdfColor.fromHex('#1B5E20')
        : PdfColor.fromHex('#E65100');

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: esPositivo
            ? PdfColor.fromHex('#E8F5E9')
            : PdfColor.fromHex('#FFF3E0'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('[08] RESULTADO',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
              pw.Text(
                esPositivo ? 'A INGRESAR' : 'SIN INGRESO',
                style: pw.TextStyle(fontSize: 9, color: color),
              ),
            ],
          ),
          pw.Text(
            '${m.resultadoIngresar.toStringAsFixed(2)} €',
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  static pw.Widget _piePagina(Modelo202 m) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Documento generado el ${_fmtDate(m.fechaGeneracion)} — BORRADOR INTERNO. '
          'El Mod.202 se presenta online en la Sede Electrónica de la AEAT.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Estado: ${m.estado.etiqueta}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
        ),
      ],
    );
  }

  static pw.Widget _filaCasilla(String casilla, String label, double valor,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 30,
            child: pw.Text(casilla,
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey500)),
          ),
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ),
          pw.Text(
            '${valor.toStringAsFixed(2)} €',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

