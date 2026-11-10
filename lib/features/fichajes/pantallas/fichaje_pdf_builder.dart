import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 7 layouts de PDF para informes de fichajes.
// Cada layout es visualmente distinto (no solo color diferente).
//
//  d1_corp    — Landscape, header azul + KPI row + tabla ancha
//  d2_minimal — Portrait,  sin colores, solo tipografía y líneas
//  d3_hero    — Landscape, 3 números gigantes arriba + tabla compacta
//  d4_sidebar — Landscape, sidebar oscuro izq. + tabla derecha
//  d5_cards   — Portrait,  tarjetas en grid 3 columnas
//  d6_dark    — Landscape, fondo oscuro + filas intercaladas claras
//  d7_exec    — Portrait,  formal, tabla compacta + zona de firma
// ═══════════════════════════════════════════════════════════════════════════════

class FichajeResumen {
  final String nombre;
  final int dias;
  final int minutosNetos;
  final int minutosPlani;
  final int minutosExtra;
  final int numPausas;
  final int incidencias;

  const FichajeResumen({
    required this.nombre,
    required this.dias,
    required this.minutosNetos,
    required this.minutosPlani,
    required this.minutosExtra,
    required this.numPausas,
    required this.incidencias,
  });

  String get horasStr => _fmtMin(minutosNetos);
  String get horasPlStr => minutosPlani > 0 ? _fmtMin(minutosPlani) : '—';
  String get extraStr {
    if (minutosPlani > 0) {
      final e = minutosNetos - minutosPlani;
      return e > 0 ? '+${_fmtMin(e)}' : '—';
    }
    return minutosExtra > 0 ? '+${_fmtMin(minutosExtra)}' : '—';
  }

  static String _fmtMin(int m) =>
      '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
}

class FichajePdfBuilder {
  static Future<Uint8List> generar({
    required String estiloLayout,
    required String titulo,
    required String empresaNombre,
    required String mes,
    required List<FichajeResumen> datos,
    required String colorHex,
  }) async {
    final col    = _hex(colorHex);
    final activos = datos.where((d) => d.dias > 0).toList();
    final totalMins = datos.fold(0, (s, d) => s + d.minutosNetos);
    final totalDias = datos.fold(0, (s, d) => s + d.dias);

    final fonts = await (
      PdfGoogleFonts.interRegular(),
      PdfGoogleFonts.interBold(),
    ).wait;
    final regular = fonts.$1;
    final bold    = fonts.$2;

    return switch (estiloLayout) {
      'd2_minimal'  => _minimal(titulo, empresaNombre, mes, activos, totalMins, totalDias, regular, bold),
      'd3_hero'     => _hero(titulo, empresaNombre, mes, activos, totalMins, totalDias, col, regular, bold),
      'd4_sidebar'  => _sidebar(titulo, empresaNombre, mes, activos, totalMins, totalDias, col, regular, bold),
      'd5_cards'    => _cards(titulo, empresaNombre, mes, activos, totalMins, col, regular, bold),
      'd6_dark'     => _dark(titulo, empresaNombre, mes, activos, totalMins, totalDias, col, regular, bold),
      'd7_exec'     => _exec(titulo, empresaNombre, mes, activos, totalMins, totalDias, regular, bold),
      _             => _corp(titulo, empresaNombre, mes, activos, totalMins, totalDias, col, regular, bold),
    };
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  static PdfColor _hex(String h) {
    try { return PdfColor.fromHex(h); } catch (_) { return PdfColors.blue800; }
  }

  static PdfColor _lighten(PdfColor c, double f) => PdfColor(
    (c.red + (1 - c.red) * f).clamp(0, 1),
    (c.green + (1 - c.green) * f).clamp(0, 1),
    (c.blue + (1 - c.blue) * f).clamp(0, 1),
  );

  static String _fmtMin(int m) =>
      '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';

  // ── D1 CORP — Header azul + KPI row + tabla landscape ────────────────────

  static Future<Uint8List> _corp(String titulo, String empresa, String mes,
      List<FichajeResumen> datos, int totalMins, int totalDias,
      PdfColor col, pw.Font r, pw.Font b) async {
    final pale = _lighten(col, 0.9);
    final doc  = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        // Header band
        pw.Container(
          color: col,
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(empresa, style: pw.TextStyle(font: b, fontSize: 15, color: PdfColors.white)),
            pw.Text(titulo, style: pw.TextStyle(font: r, fontSize: 11, color: const PdfColor(1, 1, 1, 0.7))),
          ]),
        ),
        pw.SizedBox(height: 10),
        // KPI row
        pw.Row(children: [
          _kpiBox('Total horas', _fmtMin(totalMins), col, pale, b, r),
          pw.SizedBox(width: 8),
          _kpiBox('Empleados', '${datos.length}', col, pale, b, r),
          pw.SizedBox(width: 8),
          _kpiBox('Días registrados', '$totalDias', col, pale, b, r),
          pw.SizedBox(width: 8),
          _kpiBox('Con incidencias', '${datos.where((d) => d.incidencias > 0).length}', PdfColors.red700, _lighten(PdfColors.red700, 0.9), b, r),
        ]),
        pw.SizedBox(height: 12),
        // Tabla
        pw.TableHelper.fromTextArray(
          headers: ['Empleado', 'Días', 'H. Planif.', 'H. Trab.', 'Extra', 'Pausas', 'Incid.'],
          data: datos.map((d) => [d.nombre, '${d.dias}d', d.horasPlStr, d.horasStr, d.extraStr, '${d.numPausas}', d.incidencias > 0 ? '⚠ ${d.incidencias}' : '—']).toList(),
          headerStyle: pw.TextStyle(font: b, fontSize: 8.5, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: col),
          cellStyle: pw.TextStyle(font: r, fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          oddRowDecoration: pw.BoxDecoration(color: pale),
          columnWidths: const { 0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.3), 3: pw.FlexColumnWidth(1.3), 4: pw.FlexColumnWidth(1.1), 5: pw.FlexColumnWidth(1), 6: pw.FlexColumnWidth(1) },
        ),
        pw.SizedBox(height: 8),
        pw.Text('Generado por Fluix · Reglamento (UE) 2016/679 — uso interno', style: pw.TextStyle(font: r, fontSize: 7, color: PdfColors.grey500)),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _kpiBox(String label, String value, PdfColor col, PdfColor bg, pw.Font b, pw.Font r) =>
    pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: bg, border: pw.Border.all(color: col, width: 1), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(value, style: pw.TextStyle(font: b, fontSize: 16, color: col)),
        pw.SizedBox(height: 2),
        pw.Text(label, style: pw.TextStyle(font: r, fontSize: 7.5, color: PdfColors.grey600)),
      ]),
    ));

  // ── D2 MINIMAL — Portrait, sin colores, solo tipografía ──────────────────

  static Future<Uint8List> _minimal(String titulo, String empresa, String mes,
      List<FichajeResumen> datos, int totalMins, int totalDias,
      pw.Font r, pw.Font b) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(60, 52, 60, 48),
      build: (ctx) => [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(titulo, style: pw.TextStyle(font: b, fontSize: 18, color: PdfColors.black)),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(empresa, style: pw.TextStyle(font: b, fontSize: 9)),
            pw.Text(mes, style: pw.TextStyle(font: r, fontSize: 9, color: PdfColors.grey600)),
          ]),
        ]),
        pw.Container(height: 1.5, color: PdfColors.black, margin: const pw.EdgeInsets.symmetric(vertical: 8)),
        pw.Text('${datos.length} empleados · ${_fmtMin(totalMins)} total · $totalDias días',
            style: pw.TextStyle(font: r, fontSize: 8.5, color: PdfColors.grey600)),
        pw.SizedBox(height: 20),
        // Tabla sin relleno, solo líneas inferiores
        pw.Table(
          border: const pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          columnWidths: const {0: pw.FlexColumnWidth(3.5), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.3), 3: pw.FlexColumnWidth(1.3), 4: pw.FlexColumnWidth(1)},
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1))),
              children: ['EMPLEADO', 'DÍAS', 'PLANIF.', 'TRABAJADO', 'EXTRA'].map((h) =>
                pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Text(h, style: pw.TextStyle(font: b, fontSize: 8, color: PdfColors.grey700)),
                )).toList(),
            ),
            ...datos.map((d) => pw.TableRow(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
              children: [d.nombre, '${d.dias}d', d.horasPlStr, d.horasStr, d.extraStr].map((v) =>
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Text(v, style: pw.TextStyle(font: r, fontSize: 9)),
                )).toList(),
            )),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Container(height: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 6),
        pw.Text('Fluix · Informe de control horario conforme al RD-ley 8/2019',
            style: pw.TextStyle(font: r, fontSize: 7, color: PdfColors.grey500)),
      ],
    ));
    return doc.save();
  }

  // ── D3 HERO — 3 números gigantes arriba + tabla landscape ────────────────

  static Future<Uint8List> _hero(String titulo, String empresa, String mes,
      List<FichajeResumen> datos, int totalMins, int totalDias,
      PdfColor col, pw.Font r, pw.Font b) async {
    final pale = _lighten(col, 0.92);
    final doc  = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        // Hero band
        pw.Container(
          color: col,
          padding: const pw.EdgeInsets.fromLTRB(32, 24, 32, 20),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(empresa, style: pw.TextStyle(font: r, fontSize: 9, color: const PdfColor(1, 1, 1, 0.7))),
            pw.SizedBox(height: 4),
            pw.Text(titulo, style: pw.TextStyle(font: b, fontSize: 17, color: PdfColors.white)),
            pw.SizedBox(height: 20),
            pw.Row(children: [
              _heroStat(_fmtMin(totalMins), 'Horas totales', b, r),
              _heroDivider(),
              _heroStat('${datos.length}', 'Empleados', b, r),
              _heroDivider(),
              _heroStat('$totalDias', 'Días registrados', b, r),
              _heroDivider(),
              _heroStat('${datos.where((d) => d.incidencias > 0).length}', 'Con incidencias', b, r),
            ]),
          ]),
        ),
        // Tabla sobre fondo muy claro
        pw.Container(
          color: pale,
          padding: const pw.EdgeInsets.fromLTRB(32, 16, 32, 24),
          child: pw.TableHelper.fromTextArray(
            headers: ['Empleado', 'Días', 'H. Planif.', 'H. Trab.', 'Extra', 'Pausas', 'Incid.'],
            data: datos.map((d) => [d.nombre, '${d.dias}d', d.horasPlStr, d.horasStr, d.extraStr, '${d.numPausas}', d.incidencias > 0 ? '⚠ ${d.incidencias}' : '—']).toList(),
            headerStyle: pw.TextStyle(font: b, fontSize: 8.5, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: col),
            cellStyle: pw.TextStyle(font: r, fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            border: pw.TableBorder.all(color: PdfColors.white, width: 1),
            oddRowDecoration: pw.BoxDecoration(color: PdfColors.white),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.3), 3: pw.FlexColumnWidth(1.3), 4: pw.FlexColumnWidth(1.1), 5: pw.FlexColumnWidth(1), 6: pw.FlexColumnWidth(1)},
          ),
        ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _heroStat(String val, String lbl, pw.Font b, pw.Font r) =>
    pw.Expanded(child: pw.Column(children: [
      pw.Text(val, style: pw.TextStyle(font: b, fontSize: 28, color: PdfColors.white)),
      pw.SizedBox(height: 2),
      pw.Text(lbl, style: pw.TextStyle(font: r, fontSize: 8.5, color: const PdfColor(1, 1, 1, 0.7))),
    ]));

  static pw.Widget _heroDivider() => pw.Container(
    width: 1, height: 50, margin: const pw.EdgeInsets.symmetric(horizontal: 8),
    color: const PdfColor(1, 1, 1, 0.3));

  // ── D4 SIDEBAR — sidebar oscuro izq. + tabla derecha ─────────────────────

  static Future<Uint8List> _sidebar(String titulo, String empresa, String mes,
      List<FichajeResumen> datos, int totalMins, int totalDias,
      PdfColor col, pw.Font r, pw.Font b) async {
    final dark = PdfColor(col.red * 0.6, col.green * 0.6, col.blue * 0.6);
    final doc  = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Row(children: [
        // Sidebar
        pw.Container(
          width: 165,
          color: dark,
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(empresa, style: pw.TextStyle(font: b, fontSize: 11, color: PdfColors.white)),
            pw.SizedBox(height: 4),
            pw.Text(mes, style: pw.TextStyle(font: r, fontSize: 9, color: const PdfColor(1, 1, 1, 0.7))),
            pw.Container(height: 1, color: const PdfColor(1, 1, 1, 0.3), margin: const pw.EdgeInsets.symmetric(vertical: 14)),
            _sidebarKpi('Horas totales', _fmtMin(totalMins), col, b, r),
            pw.SizedBox(height: 10),
            _sidebarKpi('Empleados', '${datos.length}', col, b, r),
            pw.SizedBox(height: 10),
            _sidebarKpi('Días totales', '$totalDias', col, b, r),
            pw.SizedBox(height: 10),
            _sidebarKpi('Incidencias', '${datos.where((d) => d.incidencias > 0).length}', PdfColors.red400, b, r),
            pw.Spacer(),
            pw.Text('Fluix · Control\nhorario RD 8/2019', style: pw.TextStyle(font: r, fontSize: 7, color: const PdfColor(1, 1, 1, 0.38))),
          ]),
        ),
        // Contenido
        pw.Expanded(child: pw.Container(
          color: PdfColors.white,
          padding: const pw.EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(titulo, style: pw.TextStyle(font: b, fontSize: 14, color: dark)),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: ['Empleado', 'Días', 'H. Planif.', 'H. Trab.', 'Extra', 'Incid.'],
              data: datos.map((d) => [d.nombre, '${d.dias}d', d.horasPlStr, d.horasStr, d.extraStr, d.incidencias > 0 ? '⚠ ${d.incidencias}' : '—']).toList(),
              headerStyle: pw.TextStyle(font: b, fontSize: 8.5, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: dark),
              cellStyle: pw.TextStyle(font: r, fontSize: 8.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              oddRowDecoration: pw.BoxDecoration(color: PdfColors.grey50),
              columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.3), 3: pw.FlexColumnWidth(1.3), 4: pw.FlexColumnWidth(1.1), 5: pw.FlexColumnWidth(1)},
            ),
          ]),
        )),
      ]),
    ));
    return doc.save();
  }

  static pw.Widget _sidebarKpi(String lbl, String val, PdfColor accent, pw.Font b, pw.Font r) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: const PdfColor(1, 1, 1, 0.1), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(lbl, style: pw.TextStyle(font: r, fontSize: 7.5, color: const PdfColor(1, 1, 1, 0.6))),
        pw.SizedBox(height: 2),
        pw.Text(val, style: pw.TextStyle(font: b, fontSize: 14, color: accent)),
      ]),
    );

  // ── D5 CARDS — tarjetas en grid 3 columnas ───────────────────────────────

  static Future<Uint8List> _cards(String titulo, String empresa, String mes,
      List<FichajeResumen> datos, int totalMins,
      PdfColor col, pw.Font r, pw.Font b) async {
    final pale = _lighten(col, 0.92);
    final doc  = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Container(
          color: col,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(titulo, style: pw.TextStyle(font: b, fontSize: 14, color: PdfColors.white)),
            pw.Text('$empresa · $mes · ${_fmtMin(totalMins)}', style: pw.TextStyle(font: r, fontSize: 9, color: const PdfColor(1, 1, 1, 0.7))),
          ]),
        ),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: datos.map((d) => pw.SizedBox(
            width: 170,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: d.incidencias > 0 ? _lighten(PdfColors.red700, 0.9) : pale,
                border: pw.Border.all(color: d.incidencias > 0 ? PdfColors.red300 : col, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(d.nombre, style: pw.TextStyle(font: b, fontSize: 8.5, color: PdfColors.black), maxLines: 1),
                pw.SizedBox(height: 6),
                pw.Row(children: [
                  _cardStat(d.horasStr, 'Horas', col, b, r),
                  pw.SizedBox(width: 6),
                  _cardStat('${d.dias}d', 'Días', col, b, r),
                  pw.SizedBox(width: 6),
                  _cardStat(d.extraStr == '—' ? '—' : d.extraStr, 'Extra', d.incidencias > 0 ? PdfColors.red600 : col, b, r),
                ]),
                if (d.incidencias > 0) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('⚠ ${d.incidencias} incidencia${d.incidencias > 1 ? 's' : ''}',
                      style: pw.TextStyle(font: b, fontSize: 7.5, color: PdfColors.red700)),
                ],
              ]),
            ),
          )).toList(),
        ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _cardStat(String val, String lbl, PdfColor col, pw.Font b, pw.Font r) =>
    pw.Expanded(child: pw.Column(children: [
      pw.Text(val, style: pw.TextStyle(font: b, fontSize: 10, color: col)),
      pw.Text(lbl, style: pw.TextStyle(font: r, fontSize: 7, color: PdfColors.grey600)),
    ]));

  // ── D6 DARK — fondo oscuro landscape ────────────────────────────────────

  static Future<Uint8List> _dark(String titulo, String empresa, String mes,
      List<FichajeResumen> datos, int totalMins, int totalDias,
      PdfColor accent, pw.Font r, pw.Font b) async {
    const bg   = PdfColor(0.098, 0.102, 0.165);  // #191A2A
    const bg2  = PdfColor(0.122, 0.137, 0.212);  // #1F2336
    const bgr  = PdfColor(0.141, 0.153, 0.235);  // #24273C
    final doc  = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      theme: pw.ThemeData.withFont(base: r, bold: b),
      build: (ctx) => [
        pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.fromLTRB(32, 20, 32, 16),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(titulo, style: pw.TextStyle(font: b, fontSize: 16, color: PdfColors.white)),
              pw.Text(empresa, style: pw.TextStyle(font: r, fontSize: 9, color: PdfColors.grey400)),
            ]),
            pw.SizedBox(height: 14),
            pw.Row(children: [
              _darkKpi(_fmtMin(totalMins), 'Horas totales', accent, bg2, b, r),
              pw.SizedBox(width: 10),
              _darkKpi('${datos.length}', 'Empleados', accent, bg2, b, r),
              pw.SizedBox(width: 10),
              _darkKpi('$totalDias', 'Días', accent, bg2, b, r),
              pw.SizedBox(width: 10),
              _darkKpi('${datos.where((d) => d.incidencias > 0).length}', 'Incidencias', PdfColors.red400, bg2, b, r),
            ]),
            pw.SizedBox(height: 16),
            // Tabla
            pw.Table(
              columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.3), 3: pw.FlexColumnWidth(1.3), 4: pw.FlexColumnWidth(1.1), 5: pw.FlexColumnWidth(1), 6: pw.FlexColumnWidth(1)},
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: accent, border: pw.Border.all(color: accent, width: 0)),
                  children: ['Empleado', 'Días', 'Planif.', 'Trabajado', 'Extra', 'Pausas', 'Incid.'].map((h) =>
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: pw.Text(h, style: pw.TextStyle(font: b, fontSize: 8.5, color: PdfColors.white)),
                    )).toList(),
                ),
                ...datos.asMap().entries.map((entry) {
                  final i = entry.key; final d = entry.value;
                  final rowBg = i.isOdd ? bg2 : bgr;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBg),
                    children: [d.nombre, '${d.dias}d', d.horasPlStr, d.horasStr, d.extraStr, '${d.numPausas}', d.incidencias > 0 ? '⚠ ${d.incidencias}' : '—'].map((v) =>
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: pw.Text(v, style: pw.TextStyle(font: r, fontSize: 8.5, color: PdfColors.grey200)),
                      )).toList(),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text('Fluix · Informe control horario · ${mes}', style: pw.TextStyle(font: r, fontSize: 7, color: PdfColors.grey600)),
          ]),
        ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _darkKpi(String val, String lbl, PdfColor accent, PdfColor bg, pw.Font b, pw.Font r) =>
    pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(val, style: pw.TextStyle(font: b, fontSize: 18, color: accent)),
        pw.SizedBox(height: 2),
        pw.Text(lbl, style: pw.TextStyle(font: r, fontSize: 7.5, color: PdfColors.grey500)),
      ]),
    ));

  // ── D7 EXEC — Portrait formal + zona de firma ────────────────────────────

  static Future<Uint8List> _exec(String titulo, String empresa, String mes,
      List<FichajeResumen> datos, int totalMins, int totalDias,
      pw.Font r, pw.Font b) async {
    const navy = PdfColor(0.098, 0.141, 0.247); // #192340
    final doc  = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 40),
      build: (ctx) => [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('INFORME DE ASISTENCIA', style: pw.TextStyle(font: b, fontSize: 10, color: PdfColors.grey600, letterSpacing: 1.5)),
              pw.SizedBox(height: 4),
              pw.Text(mes.toUpperCase(), style: pw.TextStyle(font: b, fontSize: 22, color: navy)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(empresa, style: pw.TextStyle(font: b, fontSize: 10, color: navy)),
              pw.SizedBox(height: 2),
              pw.Text('${datos.length} empleados · ${_fmtMin(totalMins)}', style: pw.TextStyle(font: r, fontSize: 8.5, color: PdfColors.grey500)),
            ]),
          ],
        ),
        pw.Container(height: 2, color: navy, margin: const pw.EdgeInsets.symmetric(vertical: 10)),
        pw.TableHelper.fromTextArray(
          headers: ['Empleado', 'Días', 'H. Plan.', 'H. Real', 'Extra', 'Incid.'],
          data: datos.map((d) => [d.nombre, '${d.dias}d', d.horasPlStr, d.horasStr, d.extraStr, d.incidencias > 0 ? '⚠${d.incidencias}' : '—']).toList(),
          headerStyle: pw.TextStyle(font: b, fontSize: 8.5, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: navy),
          cellStyle: pw.TextStyle(font: r, fontSize: 8.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          border: pw.TableBorder(horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5), bottom: const pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor(0.973, 0.976, 0.984)),
          columnWidths: const {0: pw.FlexColumnWidth(3.5), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.3), 3: pw.FlexColumnWidth(1.3), 4: pw.FlexColumnWidth(1.1), 5: pw.FlexColumnWidth(1)},
        ),
        pw.SizedBox(height: 40),
        // Zona de firma
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(height: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('Responsable RRHH', style: pw.TextStyle(font: r, fontSize: 8, color: PdfColors.grey500)),
          ])),
          pw.SizedBox(width: 32),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(height: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('Dirección', style: pw.TextStyle(font: r, fontSize: 8, color: PdfColors.grey500)),
          ])),
          pw.SizedBox(width: 32),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(height: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('Fecha y sello', style: pw.TextStyle(font: r, fontSize: 8, color: PdfColors.grey500)),
          ])),
        ]),
        pw.SizedBox(height: 20),
        pw.Text('Informe generado por Fluix conforme al Real Decreto-ley 8/2019 de control horario obligatorio.',
            style: pw.TextStyle(font: r, fontSize: 7, color: PdfColors.grey400)),
      ],
    ));
    return doc.save();
  }
}
