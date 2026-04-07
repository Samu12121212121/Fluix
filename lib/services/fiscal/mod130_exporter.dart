import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/modelos/modelo130.dart';
import '../../domain/modelos/empresa_config.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD.130 EXPORTER — Genera PDF resumen visual
// El Mod.130 NO tiene formato posicional AEAT público para terceros,
// se presenta online en Sede Electrónica AEAT
// ═══════════════════════════════════════════════════════════════════════════════

class Mod130Exporter {
  static Future<Uint8List> generarPDF({
    required Modelo130 modelo,
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
              _seccionI(modelo),
              pw.SizedBox(height: 10),
              _seccionLiquidacion(modelo),
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

  static pw.Widget _cabecera(Modelo130 m, EmpresaConfig e) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#283593'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MODELO 130',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Pago fraccionado IRPF — Estimación directa',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 10)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Ejercicio ${m.ejercicio} — ${m.trimestre}',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Plazo: hasta ${_fmtDate(Modelo130.calcularPlazoLimite(m.ejercicio, m.trimestre))}',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _seccionDatos(Modelo130 m, EmpresaConfig e) {
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
                pw.Text('DECLARANTE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text('NIF: ${e.nif}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Razón social: ${e.razonSocial}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('DEVENGO', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text('Ejercicio: ${m.ejercicio}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Período: ${m.trimestre}', style: const pw.TextStyle(fontSize: 10)),
              if (m.esComplementaria)
                pw.Text('COMPLEMENTARIA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _seccionI(Modelo130 m) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('I. ACTIVIDADES ECONÓMICAS EN ESTIMACIÓN DIRECTA',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#283593'))),
          pw.Text('(Cálculo acumulativo desde 1 enero)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          pw.SizedBox(height: 8),
          _filaCasilla('[01]', 'Ingresos computables (acumulado YTD)', m.c01),
          _filaCasilla('[02]', 'Gastos deducibles (acumulado YTD)', m.c02),
          _filaCasilla('[03]', 'Rendimiento neto [01]-[02]', m.c03, bold: true),
          pw.Divider(height: 6, thickness: 0.5),
          _filaCasilla('[04]', '20% de [03] (si positivo)', m.c04),
          _filaCasilla('[05]', 'Pagos fraccionados anteriores', m.c05),
          _filaCasilla('[06]', 'Retenciones soportadas (acumulado)', m.c06),
          _filaCasilla('[07]', 'Resultado [04]-[05]-[06]', m.c07, bold: true),
        ],
      ),
    );
  }

  static pw.Widget _seccionLiquidacion(Modelo130 m) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('LIQUIDACIÓN',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#283593'))),
          pw.SizedBox(height: 8),
          _filaCasilla('[12]', 'Suma de pagos fraccionados', m.c12),
          _filaCasilla('[13]', 'Minoración rendimientos bajos', m.c13),
          _filaCasilla('[14]', '[12]-[13]', m.c14),
          pw.Divider(height: 6, thickness: 0.5),
          _filaCasilla('[15]', 'Resultados negativos anteriores', m.c15),
          _filaCasilla('[16]', 'Deducción vivienda habitual (máx. 660,14€)', m.c16),
          _filaCasilla('[17]', '[14]-[15]-[16]', m.c17),
          if (m.esComplementaria) ...[
            pw.Divider(height: 6, thickness: 0.5),
            _filaCasilla('[18]', 'Autoliquidaciones anteriores (complementaria)', m.c18),
          ],
        ],
      ),
    );
  }

  static pw.Widget _seccionResultado(Modelo130 m) {
    final esNegativo = m.c19 < 0;
    final color = esNegativo ? PdfColor.fromHex('#E65100') : PdfColor.fromHex('#1B5E20');

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: esNegativo
            ? PdfColor.fromHex('#FFF3E0')
            : PdfColor.fromHex('#E8F5E9'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('[19] RESULTADO DE LA DECLARACIÓN',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
              pw.Text(
                esNegativo ? 'A DEDUCIR en siguientes trimestres' : 'A INGRESAR',
                style: pw.TextStyle(fontSize: 9, color: color),
              ),
            ],
          ),
          pw.Text(
            '${m.c19.toStringAsFixed(2)} €',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  static pw.Widget _piePagina(Modelo130 m) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Documento generado el ${_fmtDate(m.fechaGeneracion)} — Este PDF es un resumen interno. '
          'El Mod.130 se presenta online en la Sede Electrónica de la AEAT.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Estado: ${m.estado.etiqueta} | Facturas emitidas: ${m.facturasEmitidasIds.length} | '
          'Facturas recibidas: ${m.facturasRecibidasIds.length}',
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
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ),
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ),
          pw.Text(
            '${valor.toStringAsFixed(2)} €',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

