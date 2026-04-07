import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/modelos/modelo390.dart';
import '../../domain/modelos/empresa_config.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD.390 EXPORTER — PDF multi-página + CSV
// El Mod.390 NO tiene formato posicional para terceros.
// Se presenta online en Sede Electrónica AEAT.
// ═══════════════════════════════════════════════════════════════════════════════

class Mod390Exporter {
  // ═══════════════════════════════════════════════════════════════════════════
  // CSV
  // ═══════════════════════════════════════════════════════════════════════════

  static Uint8List generarCSV(Modelo390 m) {
    final sb = StringBuffer();
    sb.writeln('Casilla,Descripcion,Importe');
    sb.writeln('"01","Base imponible 4%","${m.c01.toStringAsFixed(2)}"');
    sb.writeln('"02","Cuota 4%","${m.c02.toStringAsFixed(2)}"');
    sb.writeln('"03","Base imponible 10%","${m.c03.toStringAsFixed(2)}"');
    sb.writeln('"04","Cuota 10%","${m.c04.toStringAsFixed(2)}"');
    sb.writeln('"05","Base imponible 21%","${m.c05.toStringAsFixed(2)}"');
    sb.writeln('"06","Cuota 21%","${m.c06.toStringAsFixed(2)}"');
    sb.writeln('"21","Base adq. intracom. bienes","${m.c21.toStringAsFixed(2)}"');
    sb.writeln('"22","Cuota adq. intracom. bienes","${m.c22.toStringAsFixed(2)}"');
    sb.writeln('"23","Base adq. intracom. servicios","${m.c23.toStringAsFixed(2)}"');
    sb.writeln('"24","Cuota adq. intracom. servicios","${m.c24.toStringAsFixed(2)}"');
    sb.writeln('"27","Base ISP otros","${m.c27.toStringAsFixed(2)}"');
    sb.writeln('"28","Cuota ISP otros","${m.c28.toStringAsFixed(2)}"');
    sb.writeln('"47","TOTAL IVA DEVENGADO","${m.c47.toStringAsFixed(2)}"');
    sb.writeln('"49","Cuota deducible interiores","${m.c49.toStringAsFixed(2)}"');
    sb.writeln('"51","Cuota deducible inversión","${m.c51.toStringAsFixed(2)}"');
    sb.writeln('"53","Cuota deducible importaciones","${m.c53.toStringAsFixed(2)}"');
    sb.writeln('"55","Cuota deducible import. inversión","${m.c55.toStringAsFixed(2)}"');
    sb.writeln('"57","Cuota adq. intracom. bienes","${m.c57.toStringAsFixed(2)}"');
    sb.writeln('"59","Cuota adq. intracom. inversión","${m.c59.toStringAsFixed(2)}"');
    sb.writeln('"598","Cuota adq. intracom. servicios","${m.c598.toStringAsFixed(2)}"');
    sb.writeln('"63","Regularización bienes inversión","${m.c63.toStringAsFixed(2)}"');
    sb.writeln('"522","Regularización prorrata","${m.c522.toStringAsFixed(2)}"');
    sb.writeln('"64","TOTAL DEDUCCIONES","${m.c64.toStringAsFixed(2)}"');
    sb.writeln('"65","RESULTADO REG. GENERAL","${m.c65.toStringAsFixed(2)}"');
    sb.writeln('"84","Suma resultados","${m.c84.toStringAsFixed(2)}"');
    sb.writeln('"85","Compensación anterior","${m.c85.toStringAsFixed(2)}"');
    sb.writeln('"86","RESULTADO LIQUIDACIÓN","${m.c86.toStringAsFixed(2)}"');
    sb.writeln('"99","Volumen operaciones","${m.c99.toStringAsFixed(2)}"');
    sb.writeln('"103","Entregas intracom. exentas","${m.c103.toStringAsFixed(2)}"');
    sb.writeln('"104","Exportaciones exentas","${m.c104.toStringAsFixed(2)}"');
    sb.writeln('"105","Exentas sin derecho deducción","${m.c105.toStringAsFixed(2)}"');
    sb.writeln('"110","No sujetas localización","${m.c110.toStringAsFixed(2)}"');

    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF MULTI-PÁGINA
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generarPDF({
    required Modelo390 modelo,
    required EmpresaConfig empresa,
  }) async {
    final pdf = pw.Document();

    // Página 1: Datos declarante + IVA devengado
    pdf.addPage(_paginaDevengado(modelo, empresa));

    // Página 2: IVA deducible + Liquidación
    pdf.addPage(_paginaDeducible(modelo, empresa));

    // Página 3: Volumen de operaciones + Alertas
    pdf.addPage(_paginaVolumen(modelo, empresa));

    return pdf.save();
  }

  static pw.Page _paginaDevengado(Modelo390 m, EmpresaConfig e) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _cabecera(m, e, 'IVA DEVENGADO'),
          pw.SizedBox(height: 10),
          _seccionDatos(m, e),
          pw.SizedBox(height: 14),
          _tituloSeccion('SECCIÓN 5 — IVA DEVENGADO'),
          pw.SizedBox(height: 6),
          _tabla([
            ['Casilla', 'Concepto', 'Base', 'Cuota'],
            ['01/02', 'Operaciones 4%', m.c01, m.c02],
            ['03/04', 'Operaciones 10%', m.c03, m.c04],
            ['05/06', 'Operaciones 21%', m.c05, m.c06],
            ['21/22', 'Adq. intracom. bienes', m.c21, m.c22],
            ['23/24', 'Adq. intracom. servicios', m.c23, m.c24],
            ['27/28', 'ISP otros supuestos', m.c27, m.c28],
          ]),
          pw.SizedBox(height: 10),
          _filaTotalPdf('[47]', 'TOTAL CUOTA IVA DEVENGADA', m.c47),
          pw.Spacer(),
          _piePagina(1, 3),
        ],
      ),
    );
  }

  static pw.Page _paginaDeducible(Modelo390 m, EmpresaConfig e) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _cabeceraSimple(m, 'IVA DEDUCIBLE Y LIQUIDACIÓN'),
          pw.SizedBox(height: 14),
          _tituloSeccion('IVA DEDUCIBLE'),
          pw.SizedBox(height: 6),
          _filaCasillaPdf('[49]', 'Cuota deducible interiores corrientes', m.c49),
          _filaCasillaPdf('[51]', 'Cuota deducible interiores inversión', m.c51),
          _filaCasillaPdf('[53]', 'Cuota deducible importaciones corrientes', m.c53),
          _filaCasillaPdf('[55]', 'Cuota deducible importaciones inversión', m.c55),
          _filaCasillaPdf('[57]', 'Cuota adq. intracom. bienes', m.c57),
          _filaCasillaPdf('[59]', 'Cuota adq. intracom. inversión', m.c59),
          _filaCasillaPdf('[598]', 'Cuota adq. intracom. servicios', m.c598),
          _filaCasillaPdf('[63]', 'Regularización bienes inversión', m.c63),
          _filaCasillaPdf('[522]', 'Regularización prorrata definitiva', m.c522),
          pw.Divider(height: 10),
          _filaTotalPdf('[64]', 'TOTAL DEDUCCIONES', m.c64),
          pw.SizedBox(height: 6),
          _filaTotalPdf('[65]', 'RESULTADO RÉGIMEN GENERAL [47]-[64]', m.c65),
          pw.SizedBox(height: 20),
          _tituloSeccion('SECCIÓN 7 — LIQUIDACIÓN ANUAL'),
          pw.SizedBox(height: 6),
          _filaCasillaPdf('[84]', 'Suma de resultados', m.c84),
          _filaCasillaPdf('[85]', 'Compensación cuotas año anterior', m.c85),
          pw.Divider(height: 10),
          _resultadoGrande(m.c86),
          pw.Spacer(),
          _piePagina(2, 3),
        ],
      ),
    );
  }

  static pw.Page _paginaVolumen(Modelo390 m, EmpresaConfig e) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _cabeceraSimple(m, 'VOLUMEN DE OPERACIONES'),
          pw.SizedBox(height: 14),
          _tituloSeccion('SECCIÓN 10 — VOLUMEN DE OPERACIONES'),
          pw.SizedBox(height: 6),
          _filaCasillaPdf('[99]', 'Operaciones régimen general', m.c99),
          _filaCasillaPdf('[103]', 'Entregas intracomunitarias exentas', m.c103),
          _filaCasillaPdf('[104]', 'Exportaciones y exentas con derecho deducción', m.c104),
          _filaCasillaPdf('[105]', 'Exentas sin derecho a deducción', m.c105),
          _filaCasillaPdf('[110]', 'No sujetas por localización', m.c110),
          if (m.alertas.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _tituloSeccion('ALERTAS DE COHERENCIA'),
            pw.SizedBox(height: 6),
            ...m.alertas.map((a) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF3E0'),
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColor.fromHex('#E65100'), width: 0.5),
                ),
                child: pw.Text(a, style: pw.TextStyle(fontSize: 8,
                    color: PdfColor.fromHex('#E65100'))),
              ),
            )),
          ],
          pw.Spacer(),
          pw.Text(
            'Generado el ${_fmtDate(m.fechaGeneracion)} — PDF informativo. '
            'El Mod.390 se presenta online en Sede Electrónica AEAT (plazo: 1–30 enero).',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
          _piePagina(3, 3),
        ],
      ),
    );
  }

  // ── HELPERS ──

  static pw.Widget _cabecera(Modelo390 m, EmpresaConfig e, String subtitulo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#00695C'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MODELO 390', style: pw.TextStyle(color: PdfColors.white,
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Resumen Anual IVA — $subtitulo',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 10)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Ejercicio ${m.ejercicio}', style: pw.TextStyle(color: PdfColors.white,
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Plazo: 1–30 enero ${m.ejercicio + 1}',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _cabeceraSimple(Modelo390 m, String subtitulo) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#00695C'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('MOD.390 — $subtitulo', style: pw.TextStyle(color: PdfColors.white,
              fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('Ejercicio ${m.ejercicio}', style: pw.TextStyle(
              color: PdfColors.grey300, fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _seccionDatos(Modelo390 m, EmpresaConfig e) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('NIF: ${e.nif}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Razón social: ${e.razonSocial}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Domicilio: ${e.domicilioFiscal}', style: const pw.TextStyle(fontSize: 9)),
            ],
          )),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Actividad: ${m.actividadPrincipal}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Epígrafe IAE: ${m.epigrafIAE}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Régimen: General', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _tituloSeccion(String titulo) {
    return pw.Text(titulo, style: pw.TextStyle(fontSize: 10,
        fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#00695C')));
  }

  static pw.Widget _tabla(List<List<dynamic>> filas) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: filas.asMap().entries.map((entry) {
        final idx = entry.key;
        final fila = entry.value;
        final esHeader = idx == 0;
        return pw.TableRow(
          decoration: esHeader ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
          children: fila.map((c) {
            final texto = c is double ? '${c.toStringAsFixed(2)} €' : c.toString();
            return pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(texto, style: pw.TextStyle(fontSize: 8,
                  fontWeight: esHeader ? pw.FontWeight.bold : pw.FontWeight.normal)),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  static pw.Widget _filaCasillaPdf(String casilla, String label, double valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 35, child: pw.Text(casilla,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500))),
          pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 9))),
          pw.Text('${valor.toStringAsFixed(2)} €', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _filaTotalPdf(String casilla, String label, double valor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 35, child: pw.Text(casilla,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
          pw.Text('${valor.toStringAsFixed(2)} €',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _resultadoGrande(double c86) {
    final esNeg = c86 < 0;
    final color = esNeg ? PdfColor.fromHex('#E65100') : PdfColor.fromHex('#1B5E20');
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: esNeg ? PdfColor.fromHex('#FFF3E0') : PdfColor.fromHex('#E8F5E9'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('[86] RESULTADO LIQUIDACIÓN ANUAL',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
              pw.Text(esNeg ? 'A DEVOLVER / COMPENSAR' : 'A INGRESAR',
                  style: pw.TextStyle(fontSize: 9, color: color)),
            ],
          ),
          pw.Text('${c86.toStringAsFixed(2)} €',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _piePagina(int pagina, int total) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Página $pagina / $total',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}




