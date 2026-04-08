import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/modelos/nomina.dart';

/// Genera PDFs de nóminas con formato oficial español.
/// Modelo BOE-A-2014-11637 (Orden ESS/2098/2014, 11/11/2014).
/// Cumple RD 2064/1995 — único modelo legal válido en España.
///
/// Estructura: 2 páginas (anverso + reverso).
class NominaPdfService {
  static final _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTES DE ESTILO — BOE-A-2014-11637
  // ═══════════════════════════════════════════════════════════════════════════

  static const double _mm = PdfPageFormat.mm;

  // ── Márgenes ──────────────────────────────────────────────────────────────
  static const double _marginH    = 15.0 * _mm;
  static const double _marginTop  = 20.0 * _mm;
  static const double _marginBot  = 20.0 * _mm;

  // ── Medidas ───────────────────────────────────────────────────────────────
  static const double _paddingCell    = 3.0 * _mm;
  static const double _alturaLinea    = 5.0 * _mm;
  static const double _separacion     = 4.0 * _mm;
  static const double _bordeLinea     = 0.5;

  // ── Tipografía ────────────────────────────────────────────────────────────
  static const double _fontTitulo     = 10.0;
  static const double _fontBase       = 8.0;
  static const double _fontCve        = 6.0;

  // ── Colores ───────────────────────────────────────────────────────────────
  static const PdfColor _negro     = PdfColors.black;
  static final PdfColor _grisClaro = PdfColor.fromHex('#F0F0F0');

  // ── Anchos de columna (devengos/deducciones) ──────────────────────────────
  static const Map<int, pw.FlexColumnWidth> _colsDevengos = {
    0: pw.FlexColumnWidth(4),
    1: pw.FlexColumnWidth(1),
    2: pw.FlexColumnWidth(1),
  };

  // ── Anchos de columna (reverso: bases cotización) ─────────────────────────
  static const Map<int, pw.FlexColumnWidth> _colsBases = {
    0: pw.FlexColumnWidth(3.2),
    1: pw.FlexColumnWidth(1.4),
    2: pw.FlexColumnWidth(1),
    3: pw.FlexColumnWidth(1.6),
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTILOS REUTILIZABLES
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.TextStyle get _stTitulo => pw.TextStyle(
    fontSize: _fontTitulo, fontWeight: pw.FontWeight.bold);

  static pw.TextStyle get _stSeccion => pw.TextStyle(
    fontSize: _fontBase, fontWeight: pw.FontWeight.bold);

  static pw.TextStyle get _stSubtitulo => pw.TextStyle(
    fontSize: _fontBase, fontWeight: pw.FontWeight.bold);

  static pw.TextStyle get _stNormal => const pw.TextStyle(fontSize: _fontBase);

  static pw.TextStyle get _stLabel => pw.TextStyle(
    fontSize: _fontBase, fontWeight: pw.FontWeight.bold);

  static pw.TextStyle get _stCve => const pw.TextStyle(fontSize: _fontCve);

  static pw.TextStyle get _stPie => const pw.TextStyle(fontSize: _fontBase);

  // ═══════════════════════════════════════════════════════════════════════════
  // FORMATEO
  // ═══════════════════════════════════════════════════════════════════════════

  static String _fmt(double v) => v.toStringAsFixed(2);

  static String _fmtPct(double v) => '${v.toStringAsFixed(2)} %';

  static String _nombreMes(int m) => const [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ][m.clamp(1, 12)];

  static int _diasMes(int m, int a) => DateTime(a, m + 1, 0).day;

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN DEL PDF — 2 PÁGINAS (ANVERSO + REVERSO)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generarNominaPdf(
    Nomina nomina, {
    String nombreEmpresa = 'Mi Empresa',
    String? cifEmpresa,
    String? direccionEmpresa,
    String? cccEmpresa,
    String? grupoProfesional,
    String? grupoCotizacion,
    Uint8List? firmaImageBytes,
  }) async {
    final pdf = pw.Document(
      title: 'Nómina ${nomina.empleadoNombre} — ${nomina.periodo}',
      author: nombreEmpresa,
    );

    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: _marginH,
      marginRight: _marginH,
      marginTop: _marginTop,
      marginBottom: _marginBot,
    );

    // ══════════════════════════════════════════════════════════════════════
    // PÁGINA 1 — ANVERSO
    // ══════════════════════════════════════════════════════════════════════
    pdf.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (ctx) => pw.Stack(children: [
        _buildCveLateral(),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildAnverso(ctx, nomina,
              nombreEmpresa: nombreEmpresa,
              cifEmpresa: cifEmpresa,
              direccionEmpresa: direccionEmpresa,
              cccEmpresa: cccEmpresa,
              grupoProfesional: grupoProfesional,
              grupoCotizacion: grupoCotizacion,
              firmaImageBytes: firmaImageBytes,
            ),
          ],
        ),
      ]),
    ));

    // ══════════════════════════════════════════════════════════════════════
    // PÁGINA 2 — REVERSO
    // ══════════════════════════════════════════════════════════════════════
    pdf.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (ctx) => pw.Stack(children: [
        _buildCveLateral(),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildReverso(ctx, nomina, nombreEmpresa: nombreEmpresa),
          ],
        ),
      ]),
    ));

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANVERSO (Página 1)
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildAnverso(
    pw.Context ctx,
    Nomina n, {
    required String nombreEmpresa,
    String? cifEmpresa,
    String? direccionEmpresa,
    String? cccEmpresa,
    String? grupoProfesional,
    String? grupoCotizacion,
    Uint8List? firmaImageBytes,
  }) {
    final dias = _diasMes(n.mes, n.anio);
    final mes = _nombreMes(n.mes);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── TÍTULO ──────────────────────────────────────────────────────
        pw.Center(
          child: pw.Text(
            'RECIBO INDIVIDUAL JUSTIFICATIVO DEL PAGO DE SALARIOS',
            style: _stTitulo,
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: _separacion),

        // ── CABECERA: EMPRESA + TRABAJADOR ──────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _negro, width: _bordeLinea),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Columna izquierda: EMPRESA
              pw.Expanded(
                child: pw.Container(
                  padding: pw.EdgeInsets.all(_paddingCell),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      right: pw.BorderSide(color: _negro, width: _bordeLinea),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _labelValor('Empresa:', nombreEmpresa),
                      pw.SizedBox(height: 1 * _mm),
                      _labelValor('Domicilio:', direccionEmpresa ?? ''),
                      pw.SizedBox(height: 1 * _mm),
                      _labelValor('CIF:', cifEmpresa ?? ''),
                      pw.SizedBox(height: 1 * _mm),
                      _labelValor('CCC:', cccEmpresa ?? ''),
                    ],
                  ),
                ),
              ),
              // Columna derecha: TRABAJADOR
              pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.all(_paddingCell),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _labelValor('Trabajador:', n.empleadoNombre),
                      pw.SizedBox(height: 1 * _mm),
                      _labelValor('NIF:', n.empleadoNif ?? ''),
                      pw.SizedBox(height: 1 * _mm),
                      _labelValor('Núm. Afil. S.S.:', n.empleadoNss ?? ''),
                      pw.SizedBox(height: 1 * _mm),
                      _labelValor('Grupo profesional:', grupoProfesional ?? ''),
                      pw.SizedBox(height: 1 * _mm),
                      _labelValor('Grupo de cotización:', grupoCotizacion ?? ''),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── PERIODO DE LIQUIDACIÓN ──────────────────────────────────────
        pw.Container(
          width: double.infinity,
          height: 8 * _mm,
          padding: pw.EdgeInsets.symmetric(horizontal: _paddingCell),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: _negro, width: _bordeLinea),
              right: pw.BorderSide(color: _negro, width: _bordeLinea),
              bottom: pw.BorderSide(color: _negro, width: _bordeLinea),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: 'Periodo de liquidación: ', style: _stLabel),
                pw.TextSpan(
                  text: 'del 1 de $mes al $dias de $mes de ${n.anio}',
                  style: _stNormal,
                ),
              ])),
              pw.Row(children: [
                pw.Text('Total días: ', style: _stLabel),
                pw.Container(
                  width: 10 * _mm,
                  height: 6 * _mm,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _negro, width: _bordeLinea),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text('$dias', style: _stNormal),
                ),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: _separacion),

        // ── I. DEVENGOS ─────────────────────────────────────────────────
        _buildBloqueDevengos(n),
        pw.SizedBox(height: 3 * _mm),

        // ── II. DEDUCCIONES ─────────────────────────────────────────────
        _buildBloqueDeducciones(n),
        pw.SizedBox(height: 2 * _mm),

        // ── LÍQUIDO TOTAL A PERCIBIR (A – B) ────────────────────────────
        _buildLiquidoTotal(n),
        pw.SizedBox(height: 8 * _mm),

        // ── PIE: FIRMAS ─────────────────────────────────────────────────
        _buildPieFirmas(n, firmaImageBytes: firmaImageBytes),
      ],
    );
  }

  // ── Bloque I — DEVENGOS ───────────────────────────────────────────────────

  static pw.Widget _buildBloqueDevengos(Nomina n) {
    return pw.Column(children: [
      _encabezadoSeccion('I. DEVENGOS'),
      _cabeceraColumnas(['', 'IMPORTE', 'TOTALES']),
      pw.Table(
        columnWidths: _colsDevengos,
        border: pw.TableBorder(
          left: const pw.BorderSide(color: _negro, width: _bordeLinea),
          right: const pw.BorderSide(color: _negro, width: _bordeLinea),
          bottom: const pw.BorderSide(color: _negro, width: _bordeLinea),
          horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#CCCCCC'), width: 0.3),
        ),
        children: [
          _filaSubtitulo('1. Percepciones salariales'),
          _filaConcepto('Salario base', importe: n.salarioBrutoMensual, indent: 2),
          _filaConcepto('Complementos salariales', importe: n.complementos > 0 ? n.complementos : null, indent: 2),
          _filaVacia(),
          _filaVacia(),
          _filaVacia(),
          _filaConcepto('Horas extraordinarias',
            importe: n.importeHorasExtra > 0 ? n.importeHorasExtra : null, indent: 2),
          _filaConcepto('Horas complementarias', indent: 2),
          _filaConcepto('Gratificaciones extraordinarias',
            importe: n.pagaExtra > 0 ? n.pagaExtra : null, indent: 2),
          _filaConcepto('Salario en especie',
            importe: n.retribucionesEspecie > 0 ? n.retribucionesEspecie : null, indent: 2),
          // ── Complementos detallados ────────────────────────────────────
          if (n.complementosDetallados.isNotEmpty)
            _filaSubtitulo('Complementos salariales variables'),
          ...n.complementosDetallados.map((c) =>
            _filaConcepto('  ${c['descripcion'] ?? ''}', importe: (c['importe'] as num?)?.toDouble(), indent: 2)),
          _filaSubtitulo('2. Percepciones no salariales'),
          _filaConcepto('Indemnizaciones o suplidos', indent: 2),
          // ── Incapacidad Temporal (IT) ──────────────────────────────────
          if (n.diasIT > 0) ...[
            _filaConcepto(
              'Prestación IT (${n.diasIT} días) — ${n.tipoContingenciaIT ?? ""}',
              importe: n.importeIT, indent: 2),
            if (n.descuentoSalarioPorIT > 0)
              _filaConcepto('Descuento salario por IT',
                importe: -n.descuentoSalarioPorIT, indent: 2),
          ] else ...[
            _filaVacia(),
          ],
          _filaVacia(),
          _filaConcepto('Prestaciones e indemnizaciones de la Seguridad Social', indent: 2),
          _filaConcepto('Indemnizaciones por traslados, suspensiones o despidos', indent: 2),
          _filaConcepto('Otras percepciones no salariales',
            importe: n.pagaExtraProrrata > 0 ? n.pagaExtraProrrata : null, indent: 2),
        ],
      ),
      _filaTotalSeccion('A. TOTAL DEVENGADO', n.totalDevengos),
    ]);
  }

  // ── Bloque II — DEDUCCIONES ───────────────────────────────────────────────

  static pw.Widget _buildBloqueDeducciones(Nomina n) {
    final tipoDesempleo = (n.baseCotizacion > 0 && n.ssTrabajadorDesempleo > 0)
        ? (n.ssTrabajadorDesempleo / n.baseCotizacion * 100)
        : 1.55;

    return pw.Column(children: [
      _encabezadoSeccion('II. DEDUCCIONES'),
      _cabeceraColumnas(['', 'IMPORTE', 'TOTALES']),
      pw.Table(
        columnWidths: _colsDevengos,
        border: pw.TableBorder(
          left: const pw.BorderSide(color: _negro, width: _bordeLinea),
          right: const pw.BorderSide(color: _negro, width: _bordeLinea),
          bottom: const pw.BorderSide(color: _negro, width: _bordeLinea),
          horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#CCCCCC'), width: 0.3),
        ),
        children: [
          _filaSubtitulo('1. Aportación del trabajador a las cotizaciones de la S.S. y conceptos de recaudación conjunta'),
          _filaConceptoPct('Contingencias comunes', 4.70, n.ssTrabajadorCC),
          _filaConceptoPct('Desempleo', tipoDesempleo, n.ssTrabajadorDesempleo),
          _filaConceptoPct('Formación Profesional', 0.10, n.ssTrabajadorFP),
          _filaConceptoPct('MEI', 0.15, n.ssMeiTrabajador),
          if (n.ssSolidaridadTrabajador > 0)
            _filaConceptoPct('Cotización solidaridad', 0, n.ssSolidaridadTrabajador),
          _filaConcepto('Horas extraordinarias', indent: 2),
          _filaConcepto('TOTAL APORTACIONES',
            total: n.totalSSTrabajador, indent: 2, bold: true),
          _filaSubtitulo('2. Impuesto sobre la Renta de las Personas Físicas'),
          _filaConceptoPct('Retención IRPF', n.porcentajeIrpf, n.retencionIrpf),
          if (n.regularizacionIrpf != 0) ...[
            _filaConcepto(
              'Regularización IRPF ${n.regularizacionIrpf > 0 ? "(a retener)" : "(a devolver)"}',
              importe: n.regularizacionIrpf, indent: 2),
          ],
          _filaSubtitulo('3. Anticipos'),
          _filaVacia(),
          _filaSubtitulo('4. Valor de los productos recibidos en especie'),
          _filaConcepto('', importe: n.retribucionesEspecie > 0 ? n.retribucionesEspecie : null, indent: 2),
          _filaSubtitulo('5. Otras deducciones'),
          if (n.embargoJudicial > 0)
            _filaConcepto(
              'Embargo judicial (art. 607 LEC)',
              importe: n.embargoJudicial,
              indent: 2,
            )
          else
            _filaVacia(),
          // ── 6. Descuentos por ausencias ─────────────────────────────────
          if (n.descuentoAusencias > 0) ...[
            _filaSubtitulo('6. Ausencias y permisos'),
            ...n.lineasAusencias.map((l) {
              final concepto = l['concepto'] as String? ?? '';
              final importe = (l['importe'] as num?)?.toDouble() ?? 0;
              return _filaConcepto(
                concepto,
                importe: importe.abs(),
                indent: 2,
              );
            }),
          ],
        ],
      ),
      _filaTotalSeccion(
        'B. TOTAL A DEDUCIR',
        n.totalDeducciones + n.embargoJudicial + n.descuentoAusencias,
      ),
    ]);
  }

  // ── LÍQUIDO TOTAL A PERCIBIR ──────────────────────────────────────────────

  static pw.Widget _buildLiquidoTotal(Nomina n) {
    return pw.Column(children: [
      pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.symmetric(horizontal: _paddingCell, vertical: 3 * _mm),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _negro, width: 1.0),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('LÍQUIDO TOTAL A PERCIBIR (A – B)', style: _stTitulo),
            pw.Text('${_fmt(n.liquidoFinal)} €',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
      if (n.embargoJudicial > 0) ...[
        pw.SizedBox(height: 1.5 * _mm),
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(horizontal: _paddingCell, vertical: 1.5 * _mm),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF3E0'),
            border: pw.Border.all(color: PdfColor.fromHex('#FF8F00'), width: 0.7),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Incluye embargo judicial (art. 607 LEC):', style: _stLabel),
                  pw.Text('−${_fmt(n.embargoJudicial)} €',
                    style: pw.TextStyle(
                      fontSize: _fontBase,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#E65100'),
                    )),
                ],
              ),
              if (n.embargoDescripcion != null) ...[
                pw.SizedBox(height: 0.5 * _mm),
                pw.Text(n.embargoDescripcion!,
                  style: const pw.TextStyle(fontSize: 6.5)),
              ],
            ],
          ),
        ),
      ],
    ]);
  }

  // ── PIE — FIRMAS ──────────────────────────────────────────────────────────

  static pw.Widget _buildPieFirmas(Nomina n, {Uint8List? firmaImageBytes}) {
    final fecha = n.fechaPago ?? n.fechaCreacion;
    final mes = _nombreMes(fecha.month);

    // Si la regularización IRPF se aplicó, añadir nota explicativa
    final notaRegularizacion = n.regularizacionIrpf != 0
        ? pw.Container(
            width: double.infinity,
            margin: pw.EdgeInsets.only(bottom: 4 * _mm),
            padding: pw.EdgeInsets.all(2 * _mm),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFF8E1'),
              border: pw.Border.all(color: PdfColor.fromHex('#FFC107'), width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'Regularización IRPF: Ajuste por diferencia entre retención estimada y retención real del ejercicio. '
              'Importe: ${_fmt(n.regularizacionIrpf)} €',
              style: const pw.TextStyle(fontSize: 6.5),
            ),
          )
        : pw.SizedBox();

    // Si hay IT, añadir nota informativa
    final notaIT = n.diasIT > 0
        ? pw.Container(
            width: double.infinity,
            margin: pw.EdgeInsets.only(bottom: 4 * _mm),
            padding: pw.EdgeInsets.all(2 * _mm),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFF3E0'),
              border: pw.Border.all(color: PdfColor.fromHex('#FF9800'), width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              'Incapacidad Temporal: ${n.diasIT} días de baja. '
              'Empresa: ${_fmt(n.importeITEmpresa)} € · INSS: ${_fmt(n.importeITINSS)} € · '
              'Mutua: ${_fmt(n.importeITMutua)} €',
              style: const pw.TextStyle(fontSize: 6.5),
            ),
          )
        : pw.SizedBox();

    return pw.Column(children: [
      notaIT,
      notaRegularizacion,
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '_______, a ${fecha.day} de $mes de ${fecha.year}',
          style: _stPie,
        ),
      ),
      pw.SizedBox(height: 15 * _mm),
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 140,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: _negro, width: _bordeLinea)),
                  ),
                ),
                pw.SizedBox(height: 2 * _mm),
                pw.Text('Firma y sello de la empresa', style: _stPie),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // ── Firma digital del empleado (si existe) ──────────────
                if (firmaImageBytes != null)
                  pw.Container(
                    width: 140,
                    height: 50,
                    child: pw.Image(pw.MemoryImage(firmaImageBytes), fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 50),
                pw.Container(
                  width: 140,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: _negro, width: _bordeLinea)),
                  ),
                ),
                pw.SizedBox(height: 2 * _mm),
                pw.Text(
                  n.estadoFirma == 'firmada' ? 'FIRMADO DIGITALMENTE' : 'RECIBÍ',
                  style: _stPie,
                ),
                if (n.firmaFecha != null)
                  pw.Text(
                    '${n.firmaFecha!.day}/${n.firmaFecha!.month}/${n.firmaFecha!.year}',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REVERSO (Página 2)
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildReverso(
    pw.Context ctx,
    Nomina n, {
    required String nombreEmpresa,
  }) {
    final remuneracionMensual = n.salarioBrutoMensual + n.complementos +
        n.importeHorasExtra + n.retribucionesEspecie;
    final prorrataExtras = n.baseCotizacion - remuneracionMensual;
    final prorrataPositiva = prorrataExtras > 0 ? prorrataExtras : 0.0;

    final tipoAT = (n.baseCotizacion > 0 && n.ssEmpresaAT > 0)
        ? (n.ssEmpresaAT / n.baseCotizacion * 100)
        : 1.50;
    final tipoDesempleoEmp = (n.baseCotizacion > 0 && n.ssEmpresaDesempleo > 0)
        ? (n.ssEmpresaDesempleo / n.baseCotizacion * 100)
        : 5.50;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── TÍTULO DEL BLOQUE ────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(2 * _mm),
          decoration: pw.BoxDecoration(color: _grisClaro),
          child: pw.Text(
            'DETERMINACIÓN DE LAS BASES DE COTIZACIÓN A LA SEGURIDAD SOCIAL\n'
            'Y CONCEPTOS DE RECAUDACIÓN CONJUNTA Y DE LA BASE SUJETA A RETENCIÓN DEL IRPF',
            style: _stSeccion,
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: _separacion),

        // ── 1. CONTINGENCIAS COMUNES ─────────────────────────────────────
        pw.Text('1. Contingencias comunes', style: _stSubtitulo),
        pw.SizedBox(height: 1 * _mm),
        pw.Table(
          columnWidths: _colsBases,
          border: pw.TableBorder.all(color: _negro, width: _bordeLinea),
          children: [
            _cabeceraReverso(),
            _filaBase('Importe remuneración mensual', remuneracionMensual),
            _filaBase('Importe prorrata pagas extraordinarias', prorrataPositiva),
            _filaBaseTotal('TOTAL', n.baseCotizacion, 23.60, n.ssEmpresaCC),
          ],
        ),
        pw.SizedBox(height: _separacion),

        // ── 2. CONTINGENCIAS PROFESIONALES ───────────────────────────────
        pw.Text('2. Contingencias profesionales y conceptos de recaudación conjunta',
          style: _stSubtitulo),
        pw.SizedBox(height: 1 * _mm),
        pw.Table(
          columnWidths: _colsBases,
          border: pw.TableBorder.all(color: _negro, width: _bordeLinea),
          children: [
            _cabeceraReverso(),
            _filaBaseCompleta('AT y EP', n.baseCotizacion, tipoAT, n.ssEmpresaAT),
            _filaBaseCompleta('Desempleo', n.baseCotizacion, tipoDesempleoEmp, n.ssEmpresaDesempleo),
            _filaBaseCompleta('Formación Profesional', n.baseCotizacion, 0.60, n.ssEmpresaFP),
            _filaBaseCompleta('Fondo de Garantía Salarial', n.baseCotizacion, 0.20, n.ssEmpresaFogasa),
            _filaBaseCompleta('MEI', n.baseCotizacion, 0.75, n.ssMeiEmpresa),
            if (n.ssSolidaridadEmpresa > 0)
              _filaBaseCompleta('Cotización solidaridad', n.baseCotizacion, 0, n.ssSolidaridadEmpresa),
          ],
        ),
        pw.SizedBox(height: _separacion),

        // ── 3. COTIZACIÓN ADICIONAL HORAS EXTRA ──────────────────────────
        pw.Text('3. Cotización adicional por horas extraordinarias', style: _stSubtitulo),
        pw.SizedBox(height: 1 * _mm),
        pw.Table(
          columnWidths: _colsBases,
          border: pw.TableBorder.all(color: _negro, width: _bordeLinea),
          children: [
            _cabeceraReverso(),
            // Fuerza mayor: solo si el tipo es FM
            _filaBaseCompleta(
              'Horas extra fuerza mayor',
              n.tipoHoraExtra == TipoHoraExtra.fuerzaMayor ? n.importeHorasExtra : 0,
              n.tipoHoraExtra == TipoHoraExtra.fuerzaMayor ? 12.00 : 0,
              n.tipoHoraExtra == TipoHoraExtra.fuerzaMayor ? n.ssHorasExtraEmpresa : 0,
            ),
            // No fuerza mayor: estructurales / no estructurales
            _filaBaseCompleta(
              'Horas extra no fuerza mayor',
              n.tipoHoraExtra != TipoHoraExtra.fuerzaMayor ? n.importeHorasExtra : 0,
              n.tipoHoraExtra != TipoHoraExtra.fuerzaMayor ? 23.60 : 0,
              n.tipoHoraExtra != TipoHoraExtra.fuerzaMayor ? n.ssHorasExtraEmpresa : 0,
            ),
          ],
        ),
        pw.SizedBox(height: _separacion),

        // ── 4. BASE SUJETA A RETENCIÓN DEL IRPF ─────────────────────────
        pw.Text('4. Base sujeta a retención del IRPF', style: _stSubtitulo),
        pw.SizedBox(height: 1 * _mm),
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(horizontal: _paddingCell, vertical: 2 * _mm),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _negro, width: _bordeLinea),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Base sujeta a retención del IRPF', style: _stNormal),
              pw.Text('${_fmt(n.baseIrpf)} €', style: _stLabel),
            ],
          ),
        ),
        pw.SizedBox(height: _separacion * 2),

        // ── RESUMEN COSTE EMPRESA ────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.all(_paddingCell),
          decoration: pw.BoxDecoration(
            color: _grisClaro,
            border: pw.Border.all(color: _negro, width: _bordeLinea),
          ),
          child: pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total aportación empresa a la S.S.', style: _stLabel),
                pw.Text('${_fmt(n.totalSSEmpresa)} €', style: _stLabel),
              ],
            ),
            pw.SizedBox(height: 1 * _mm),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('COSTE TOTAL EMPRESA (devengos + SS empresa)', style: _stLabel),
                pw.Text('${_fmt(n.costeTotalEmpresa)} €',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ]),
        ),

        pw.SizedBox(height: 20 * _mm),

        // ── Pie reverso ──────────────────────────────────────────────────
        pw.Divider(color: _negro, height: 1, thickness: 0.3),
        pw.SizedBox(height: 1 * _mm),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Modelo oficial recibo de salarios — Orden ESS/2098/2014 (BOE-A-2014-11637)',
              style: pw.TextStyle(fontSize: 6, color: PdfColor.fromHex('#999999'))),
            pw.Text('Generado por Fluix · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: pw.TextStyle(fontSize: 6, color: PdfColor.fromHex('#999999'))),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CVE LATERAL (ambas páginas)
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildCveLateral() {
    return pw.Positioned(
      right: -12 * _mm,
      top: 0,
      bottom: 0,
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: -3.14159 / 2,
          child: pw.Text('cve: BOE-A-2014-11637', style: _stCve),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS — CONSTRUCCIÓN DE FILAS Y CELDAS
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _labelValor(String label, String valor) {
    return pw.RichText(text: pw.TextSpan(children: [
      pw.TextSpan(text: label, style: _stLabel),
      pw.TextSpan(text: ' $valor', style: _stNormal),
    ]));
  }

  static pw.Widget _encabezadoSeccion(String titulo) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(horizontal: _paddingCell, vertical: 1.5 * _mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _negro, width: _bordeLinea),
      ),
      child: pw.Text(titulo, style: _stSeccion),
    );
  }

  static pw.Widget _cabeceraColumnas(List<String> cols) {
    return pw.Table(
      columnWidths: _colsDevengos,
      border: const pw.TableBorder(
        left: pw.BorderSide(color: _negro, width: _bordeLinea),
        right: pw.BorderSide(color: _negro, width: _bordeLinea),
        bottom: pw.BorderSide(color: _negro, width: _bordeLinea),
      ),
      children: [
        pw.TableRow(children: [
          _celdaFila(cols[0], bold: true),
          _celdaFila(cols[1], bold: true, align: pw.Alignment.centerRight),
          _celdaFila(cols[2], bold: true, align: pw.Alignment.centerRight),
        ]),
      ],
    );
  }

  static pw.TableRow _filaSubtitulo(String texto) {
    return pw.TableRow(children: [
      _celdaFila(texto, bold: true, indent: 0),
      _celdaFila(''),
      _celdaFila(''),
    ]);
  }

  static pw.TableRow _filaConcepto(String concepto, {
    double? importe,
    double? total,
    int indent = 0,
    bool bold = false,
  }) {
    final indentMm = indent * 2.0;
    return pw.TableRow(children: [
      _celdaFila(concepto, indent: indentMm, bold: bold),
      _celdaFila(importe != null && importe > 0 ? _fmt(importe) : '',
        align: pw.Alignment.centerRight),
      _celdaFila(total != null && total > 0 ? _fmt(total) : '',
        align: pw.Alignment.centerRight, bold: bold),
    ]);
  }

  static pw.TableRow _filaConceptoPct(String concepto, double pct, double importe) {
    return pw.TableRow(children: [
      _celdaFila('     $concepto ........ ${_fmtPct(pct)}'),
      _celdaFila(_fmt(importe), align: pw.Alignment.centerRight),
      _celdaFila(''),
    ]);
  }

  static pw.TableRow _filaVacia() {
    return pw.TableRow(children: [
      _celdaFila(''),
      _celdaFila(''),
      _celdaFila(''),
    ]);
  }

  static pw.Widget _filaTotalSeccion(String label, double importe) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(horizontal: _paddingCell, vertical: 2 * _mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _negro, width: _bordeLinea),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 4, child: pw.Text(label, style: _stLabel)),
          pw.Expanded(flex: 1, child: pw.Text('', textAlign: pw.TextAlign.right)),
          pw.Expanded(
            flex: 1,
            child: pw.Text('${_fmt(importe)} €',
              style: _stLabel, textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  static pw.Widget _celdaFila(String text, {
    bool bold = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    double indent = 0,
  }) {
    return pw.Container(
      height: _alturaLinea,
      padding: pw.EdgeInsets.only(
        left: _paddingCell / 2 + indent * _mm,
        right: _paddingCell / 2,
      ),
      alignment: align,
      child: pw.Text(text, style: bold ? _stSubtitulo : _stNormal),
    );
  }

  // ── Helpers Reverso ───────────────────────────────────────────────────────

  static pw.TableRow _cabeceraReverso() {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: _grisClaro),
      children: [
        _celdaRev('CONCEPTO', bold: true),
        _celdaRev('BASE', bold: true, align: pw.Alignment.centerRight),
        _celdaRev('TIPO %', bold: true, align: pw.Alignment.centerRight),
        _celdaRev('APORTACIÓN EMPRESA', bold: true, align: pw.Alignment.centerRight),
      ],
    );
  }

  static pw.TableRow _filaBase(String concepto, double base) {
    return pw.TableRow(children: [
      _celdaRev(concepto),
      _celdaRev(_fmt(base), align: pw.Alignment.centerRight),
      _celdaRev(''),
      _celdaRev(''),
    ]);
  }

  static pw.TableRow _filaBaseTotal(String concepto, double base, double tipo, double aport) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: _grisClaro),
      children: [
        _celdaRev(concepto, bold: true),
        _celdaRev('${_fmt(base)} €', bold: true, align: pw.Alignment.centerRight),
        _celdaRev(_fmtPct(tipo), bold: true, align: pw.Alignment.centerRight),
        _celdaRev('${_fmt(aport)} €', bold: true, align: pw.Alignment.centerRight),
      ],
    );
  }

  static pw.TableRow _filaBaseCompleta(String concepto, double base, double tipo, double aport) {
    return pw.TableRow(children: [
      _celdaRev(concepto),
      _celdaRev(base > 0 ? _fmt(base) : ''),
      _celdaRev(tipo > 0 ? _fmtPct(tipo) : ''),
      _celdaRev(aport > 0 ? _fmt(aport) : '', align: pw.Alignment.centerRight),
    ]);
  }

  static pw.Widget _celdaRev(String text, {
    bool bold = false,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      height: _alturaLinea,
      padding: pw.EdgeInsets.symmetric(horizontal: _paddingCell / 2),
      alignment: align,
      child: pw.Text(text, style: bold ? _stLabel : _stNormal),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VER / IMPRIMIR / COMPARTIR NÓMINA
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> _cargarDatosEmpresa(String empresaId) async {
    String nombreEmpresa = 'Mi Empresa';
    String? cif, direccion, ccc;
    try {
      final doc = await _db.collection('empresas').doc(empresaId).get();
      final data = doc.data();
      if (data != null) {
        final perfil = data['perfil'] as Map<String, dynamic>? ?? {};
        nombreEmpresa = perfil['nombre'] as String? ?? 'Mi Empresa';
        cif = perfil['cif'] as String?;
        direccion = perfil['direccion'] as String?;
        ccc = perfil['ccc_ss'] as String?;
      }
    } catch (_) {}
    return {'nombre': nombreEmpresa, 'cif': cif, 'direccion': direccion, 'ccc': ccc};
  }

  static Future<Uint8List> _generarBytes(Nomina nomina, String empresaId) async {
    final datos = await _cargarDatosEmpresa(empresaId);
    return generarNominaPdf(
      nomina,
      nombreEmpresa: datos['nombre'],
      cifEmpresa: datos['cif'],
      direccionEmpresa: datos['direccion'],
      cccEmpresa: datos['ccc'],
    );
  }

  /// Abre una pantalla dedicada con vista previa del PDF y botón de retroceso.
  static Future<void> verNominaPdf(
    BuildContext context,
    Nomina nomina,
    String empresaId,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NominaPdfPreviewScreen(
          nomina: nomina,
          empresaId: empresaId,
        ),
      ),
    );
  }

  /// Guarda el PDF temporalmente y devuelve la ruta del archivo.
  /// ⚠️ Solo para plataformas nativas (Android/iOS/Desktop). No usar en Web.
  static Future<File> guardarPdfTemporal(Nomina nomina, String empresaId) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'guardarPdfTemporal no está disponible en Web. '
        'Usa Printing.sharePdf en su lugar.',
      );
    }
    final bytes = await _generarBytes(nomina, empresaId);
    final dir = await getTemporaryDirectory();
    final nombre = 'Nomina_${nomina.empleadoNombre.replaceAll(' ', '_')}_${nomina.periodo.replaceAll(' ', '_')}.pdf';
    final file = File('${dir.path}/$nombre');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Muestra un diálogo para elegir cómo enviar: correo directo o compartir.
  static Future<void> enviarNominaPorCorreo(
    BuildContext context,
    Nomina nomina,
    String empresaId,
  ) async {
    final opcion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enviar nómina'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFFD93025)),
              title: const Text('Abrir app de correo'),
              subtitle: const Text('Gmail, Outlook, etc.'),
              onTap: () => Navigator.pop(ctx, 'email'),
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Color(0xFF0D47A1)),
              title: const Text('Compartir PDF'),
              subtitle: const Text('WhatsApp, Telegram, etc.'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (opcion == null || !context.mounted) return;

    try {
      final bytes = await _generarBytes(nomina, empresaId);

      // En Web no existe dart:io — compartir directamente con Printing
      if (kIsWeb) {
        final nombre = 'Nomina_${nomina.empleadoNombre.replaceAll(' ', '_')}_${nomina.periodo}.pdf';
        await Printing.sharePdf(bytes: bytes, filename: nombre);
        return;
      }

      final file = await guardarPdfTemporal(nomina, empresaId);
      final subject = 'Nómina ${nomina.periodo} — ${nomina.empleadoNombre}';
      final body = 'Adjunto la nómina de ${nomina.empleadoNombre} '
          'correspondiente a ${nomina.periodo}.\n\n'
          'Líquido a percibir: €${_fmt(nomina.salarioNeto)}';

      if (opcion == 'email') {
        final mailUri = Uri(
          scheme: 'mailto',
          query: Uri(queryParameters: {
            'subject': subject,
            'body': body,
          }).query,
        );

        if (await canLaunchUrl(mailUri)) {
          await launchUrl(mailUri);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('📎 Pulsa compartir para adjuntar el PDF'),
                backgroundColor: const Color(0xFF1976D2),
                action: SnackBarAction(
                  label: 'Adjuntar PDF',
                  textColor: Colors.white,
                  onPressed: () {
                    Share.shareXFiles(
                      [XFile(file.path, mimeType: 'application/pdf')],
                      subject: subject,
                      text: body,
                    );
                  },
                ),
              ),
            );
          }
        } else {
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'application/pdf')],
            subject: subject,
            text: body,
          );
        }
      } else {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: subject,
          text: body,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE VISTA PREVIA PDF (con botón de retroceso)
// ═══════════════════════════════════════════════════════════════════════════════

class _NominaPdfPreviewScreen extends StatelessWidget {
  final Nomina nomina;
  final String empresaId;

  const _NominaPdfPreviewScreen({
    required this.nomina,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF — ${nomina.empleadoNombre}'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir',
            onPressed: () => NominaPdfService.enviarNominaPorCorreo(
              context, nomina, empresaId,
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => NominaPdfService._generarBytes(nomina, empresaId),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: 'Nomina_${nomina.empleadoNombre}_${nomina.periodo}.pdf',
      ),
    );
  }
}


