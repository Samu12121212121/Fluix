import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/modelos/modelo115.dart';
import '../../domain/modelos/empresa_config.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MOD.115 EXPORTER — Fichero posicional DR115e15v13 + PDF resumen
// Encoding: ISO-8859-1 con CRLF
// ═══════════════════════════════════════════════════════════════════════════════

class Mod115Exporter {
  static const _crlf = '\r\n';

  // ═══════════════════════════════════════════════════════════════════════════
  // FICHERO TXT POSICIONAL (DR115e15v13)
  // ═══════════════════════════════════════════════════════════════════════════

  static Uint8List generarFicheroTXT({
    required Modelo115 modelo,
    required EmpresaConfig empresa,
  }) {
    final sb = StringBuffer();

    final periodo = modelo.trimestre; // "1T","2T","3T","4T"
    final ejercicio = modelo.ejercicio.toString().padLeft(4, '0');

    // ── LÍNEA 1: Cabecera envolvente ──
    sb.write('<T115 0 $ejercicio $periodo 0000>$_crlf');

    // ── LÍNEA 2: Registro AUX (300 posiciones entre etiquetas) ──
    final aux = StringBuffer();
    aux.write(_pad('', 70));                   // Pos 6-75: blancos
    aux.write(_pad('0100', 4));                // Pos 76-79: versión software
    aux.write(_pad('', 4));                    // Pos 80-83: blancos
    aux.write(_padLeft(empresa.nif, 9));       // Pos 84-92: NIF presentador
    aux.write(_pad('', 213));                  // Pos 93-305: blancos
    sb.write('<AUX>${aux.toString()}</AUX>$_crlf');

    // ── LÍNEA 3: Inicio página 01 ──
    sb.write('<T11501000>$_crlf');

    // ── LÍNEA 4: Registro página 01 ──
    final pag = StringBuffer();
    // Pos 1: Complementaria
    pag.write(modelo.esComplementaria ? 'C' : ' ');
    // Pos 2: Tipo declaración
    pag.write(modelo.tipoDeclaracion.codigo);
    // Pos 3-11: NIF sujeto pasivo (9 An, ajust izq, blancos der, MAYÚSCULAS)
    pag.write(_padLeft(_normalizar(empresa.nif), 9));
    // Pos 12-15: Ejercicio
    pag.write(ejercicio);
    // Pos 16-17: Período
    pag.write(_padLeft(periodo, 2));
    // Pos 18-26: [01] nº perceptores (9 Num, ajust der, ceros izq)
    pag.write(_numPad(modelo.c01, 9));
    // Pos 27-43: [02] Base retenciones (17 N: 15 enteros + 2 decimales)
    pag.write(_formatImporte17(modelo.c02));
    // Pos 44-60: [03] Retenciones practicadas
    pag.write(_formatImporte17(modelo.c03));
    // Pos 61-77: Resultado a ingresar [05]
    pag.write(_formatImporte17(modelo.c05));
    // Pos 78-90: Nº justificante anterior (13 Num)
    pag.write(modelo.esComplementaria && modelo.nJustificanteAnterior != null
        ? _numPadStr(modelo.nJustificanteAnterior!, 13)
        : '0000000000000');
    // Pos 91-124: IBAN domiciliación (34 An, blancos si no aplica)
    pag.write(_padLeft(modelo.ibanDomiciliacion ?? '', 34));

    sb.write('${pag.toString()}$_crlf');

    // ── LÍNEA 5: Cierre ──
    sb.write('</T115${ejercicio}${periodo}0000>$_crlf');

    // Convertir a ISO-8859-1
    return _toIso88591(sb.toString());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF RESUMEN VISUAL
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generarPDF({
    required Modelo115 modelo,
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
              _cabeceraPdf(modelo, empresa),
              pw.SizedBox(height: 14),
              _datosPdf(modelo, empresa),
              pw.SizedBox(height: 14),
              _casillasPdf(modelo),
              pw.SizedBox(height: 14),
              if (modelo.arrendadores.isNotEmpty) _arrendadoresPdf(modelo),
              pw.SizedBox(height: 14),
              _resultadoPdf(modelo),
              pw.SizedBox(height: 20),
              _piePdf(modelo),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS FORMATO POSICIONAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convierte importe a 17 posiciones: 15 enteros + 2 decimales, sin separador.
  /// Negativo: "N" en posición 1, resto del importe en valor absoluto.
  /// Ejemplo: 1500.00 → "00000000000150000"
  ///         -500.00 → "N0000000000050000"
  static String _formatImporte17(double valor) {
    final negativo = valor < 0;
    final abs = valor.abs();
    final centimos = (abs * 100).round();
    final str = centimos.toString().padLeft(17, '0');
    if (negativo) {
      return 'N${str.substring(1)}'; // "N" + 16 dígitos
    }
    return str.length > 17 ? str.substring(str.length - 17) : str;
  }

  /// Rellena con blancos a la derecha
  static String _padLeft(String s, int len) {
    final limpio = s.length > len ? s.substring(0, len) : s;
    return limpio.padRight(len);
  }

  /// Rellena con blancos
  static String _pad(String s, int len) => s.padRight(len).substring(0, len);

  /// Número ajustado a derecha con ceros a la izquierda
  static String _numPad(int valor, int len) =>
      valor.toString().padLeft(len, '0');

  /// String numérico ajustado a derecha con ceros
  static String _numPadStr(String s, int len) {
    final limpio = s.replaceAll(RegExp(r'[^0-9]'), '');
    return limpio.padLeft(len, '0').substring(0, len);
  }

  /// Normalizar texto: quitar acentos, ñ→N, mayúsculas
  static String _normalizar(String s) {
    return s
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll('Ü', 'U')
        .replaceAll('Ç', 'C');
  }

  /// Convierte string a bytes ISO-8859-1
  static Uint8List _toIso88591(String s) {
    try {
      return Uint8List.fromList(latin1.encode(s));
    } catch (_) {
      // Fallback: reemplazar caracteres no representables
      final limpio = _normalizar(s);
      return Uint8List.fromList(latin1.encode(limpio));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS PDF
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _cabeceraPdf(Modelo115 m, EmpresaConfig e) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1565C0'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MODELO 115',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 18,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Retenciones arrendamientos locales de negocio',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 10)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('${m.ejercicio} — ${m.trimestre}',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 14,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Tipo: ${m.tipoDeclaracion.etiqueta}',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _datosPdf(Modelo115 m, EmpresaConfig e) {
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
            ],
          )),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Ejercicio: ${m.ejercicio}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Período: ${m.trimestre}', style: const pw.TextStyle(fontSize: 10)),
              if (m.esComplementaria)
                pw.Text('COMPLEMENTARIA', style: pw.TextStyle(fontSize: 9,
                    fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _casillasPdf(Modelo115 m) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          _filaCasilla('[01]', 'Nº de perceptores (arrendadores)', m.c01.toDouble()),
          _filaCasilla('[02]', 'Base de retenciones', m.c02),
          _filaCasilla('[03]', 'Retenciones practicadas (19%)', m.c03, bold: true),
          if (m.esComplementaria)
            _filaCasilla('[04]', 'A deducir declaración anterior', m.c04),
          _filaCasilla('[05]', 'Resultado a ingresar', m.c05, bold: true),
        ],
      ),
    );
  }

  static pw.Widget _arrendadoresPdf(Modelo115 m) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('DETALLE ARRENDADORES', style: pw.TextStyle(fontSize: 10,
              fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1565C0'))),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: ['NIF', 'Nombre', 'Base', 'Retención'].map((h) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ).toList(),
              ),
              ...m.arrendadores.map((a) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(a.nif, style: const pw.TextStyle(fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(a.nombre, style: const pw.TextStyle(fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${a.baseImponible.toStringAsFixed(2)} €', style: const pw.TextStyle(fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${a.retencion.toStringAsFixed(2)} €', style: const pw.TextStyle(fontSize: 8))),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _resultadoPdf(Modelo115 m) {
    final esNegativa = m.tipoDeclaracion == TipoDeclaracion115.negativa;
    final color = esNegativa ? PdfColor.fromHex('#E65100') : PdfColor.fromHex('#1B5E20');

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: esNegativa ? PdfColor.fromHex('#FFF3E0') : PdfColor.fromHex('#E8F5E9'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('[05] RESULTADO', style: pw.TextStyle(fontSize: 11,
              fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text('${m.c05.toStringAsFixed(2)} €', style: pw.TextStyle(
              fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _piePdf(Modelo115 m) {
    return pw.Text(
      'Generado el ${_fmtDate(m.fechaGeneracion)} — Fichero posicional DR115e15v13 disponible para presentación en Sede AEAT.',
      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
    );
  }

  static pw.Widget _filaCasilla(String casilla, String label, double valor,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 30, child: pw.Text(casilla,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500))),
          pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Text('${valor.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}



