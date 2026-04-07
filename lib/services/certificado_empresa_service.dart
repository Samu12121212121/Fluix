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
// SERVICIO CERTIFICADO DE EMPRESA — SEPE
// Modelo oficial para prestación por desempleo.
// ═══════════════════════════════════════════════════════════════════════════════

/// Codigos de causa de cese según SEPE.
const Map<CausaBaja, String> codigosSEPE = {
  CausaBaja.despidoImprocedente: '01 - Despido improcedente o sin causa justificada',
  CausaBaja.despidoProcedente: '02 - Despido procedente por causas objetivas',
  CausaBaja.finContrato: '04 - Fin de contrato temporal',
  CausaBaja.dimision: '10 - Dimisión voluntaria',
  CausaBaja.mutuoAcuerdo: '10 - Mutuo acuerdo',
  CausaBaja.ere: '06 - Despido colectivo - ERE',
  CausaBaja.jubilacion: '10 - Jubilación del trabajador',
};

class CertificadoEmpresaService {
  static final CertificadoEmpresaService _i = CertificadoEmpresaService._();
  factory CertificadoEmpresaService() => _i;
  CertificadoEmpresaService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const double _mm = PdfPageFormat.mm;

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERAR CERTIFICADO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Agrega todos los datos y genera el certificado.
  Future<String> generar(String empresaId, String finiquitoId) async {
    // Obtener finiquito
    final finiqDoc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('finiquitos')
        .doc(finiquitoId)
        .get();
    if (!finiqDoc.exists) throw Exception('Finiquito no encontrado');
    final finiquito = Finiquito.fromMap({...finiqDoc.data()!, 'id': finiqDoc.id});

    // Obtener datos empresa
    final empDoc = await _db.collection('empresas').doc(empresaId).get();
    final datosEmpresa = empDoc.data() ?? {};

    // Obtener datos empleado
    final empladoDoc =
        await _db.collection('usuarios').doc(finiquito.empleadoId).get();
    final datosEmpleado = empladoDoc.data() ?? {};

    // Obtener bases de cotización últimos 180 días (6 meses)
    final basesCotizacion = await _obtenerBasesCotizacion(
      empresaId,
      finiquito.empleadoId,
      finiquito.fechaBaja,
    );

    // Validar campos obligatorios
    _validarCamposObligatorios(datosEmpresa, datosEmpleado);

    // Generar PDF
    final bytes = await generarPDF(
      finiquito: finiquito,
      datosEmpresa: datosEmpresa,
      datosEmpleado: datosEmpleado,
      basesCotizacion: basesCotizacion,
    );

    // Subir a Storage
    final path =
        'empresas/$empresaId/finiquitos/certificados_sepe/'
        'certificado_sepe_$finiquitoId.pdf';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    final url = await ref.getDownloadURL();

    // Actualizar finiquito
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('finiquitos')
        .doc(finiquitoId)
        .update({'certificado_sepe_url': url});

    return url;
  }

  void _validarCamposObligatorios(
    Map<String, dynamic> empresa,
    Map<String, dynamic> empleado,
  ) {
    final errores = <String>[];
    if ((empresa['ccc'] as String?) == null ||
        (empresa['ccc'] as String?)!.isEmpty) {
      errores.add('CCC (Código Cuenta Cotización) de la empresa');
    }
    final naf = empleado['naf'] as String? ??
        (empleado['datos_nomina'] as Map?)?.values
            .firstWhere((_) => false, orElse: () => null)
            ?.toString();
    if (naf == null || naf.isEmpty) {
      errores.add('NAF (Número de Afiliación SS) del empleado');
    }
    if (errores.isNotEmpty) {
      throw Exception(
          '⚠️ Campos obligatorios faltantes:\n- ${errores.join('\n- ')}');
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerBasesCotizacion(
    String empresaId,
    String empleadoId,
    DateTime fechaBaja,
  ) async {
    final desde = DateTime(fechaBaja.year, fechaBaja.month - 5, 1);
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('nominas')
        .where('empleado_id', isEqualTo: empleadoId)
        .where('anio', isGreaterThanOrEqualTo: desde.year)
        .orderBy('anio')
        .orderBy('mes')
        .limit(6)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return {
        'mes': data['mes'],
        'anio': data['anio'],
        'base_cc': (data['base_cotizacion'] as num?)?.toDouble() ?? 0.0,
        'dias': 30,
      };
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERAR PDF
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generarPDF({
    required Finiquito finiquito,
    required Map<String, dynamic> datosEmpresa,
    required Map<String, dynamic> datosEmpleado,
    required List<Map<String, dynamic>> basesCotizacion,
  }) async {
    final pdf = pw.Document(
      title: 'Certificado de Empresa SEPE — ${finiquito.empleadoNombre}',
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.symmetric(horizontal: 18 * _mm, vertical: 18 * _mm),
      build: (ctx) => _buildCertificado(
        finiquito: finiquito,
        datosEmpresa: datosEmpresa,
        datosEmpleado: datosEmpleado,
        basesCotizacion: basesCotizacion,
      ),
    ));

    return pdf.save();
  }

  static pw.Widget _buildCertificado({
    required Finiquito finiquito,
    required Map<String, dynamic> datosEmpresa,
    required Map<String, dynamic> datosEmpleado,
    required List<Map<String, dynamic>> basesCotizacion,
  }) {
    final nombreEmpresa = datosEmpresa['nombre'] as String? ?? finiquito.empresaNombre ?? '—';
    final cif = datosEmpresa['cif'] as String? ?? finiquito.empresaCif ?? '—';
    final ccc = datosEmpresa['ccc'] as String? ?? '—';
    final domicilioEmpresa = datosEmpresa['domicilio'] as String? ?? '—';
    final representante = datosEmpresa['representante'] as String? ?? '—';

    final naf = datosEmpleado['naf'] as String? ??
        (datosEmpleado['datos_nomina'] as Map<String, dynamic>?)?['naf'] as String?;
    final domicilioEmp = [
      datosEmpleado['calle'] as String?,
      datosEmpleado['ciudad'] as String?,
      datosEmpleado['cp'] as String?,
    ].where((e) => e != null).join(', ');

    final datosNomina =
        datosEmpleado['datos_nomina'] as Map<String, dynamic>? ?? {};
    final grupoCotizacion = datosNomina['grupo_cotizacion'] as String? ?? '—';
    final tipoContrato = datosNomina['tipo_contrato'] as String? ?? '—';
    final salarioMensual = finiquito.salarioBrutoAnual / 12;
    final codigoCese = codigosSEPE[finiquito.causaBaja] ?? '—';

    final totalDiasCotizados =
        basesCotizacion.fold<int>(0, (s, b) => s + (b['dias'] as int? ?? 30));
    final totalBasesCotizacion = basesCotizacion.fold<double>(
        0, (s, b) => s + (b['base_cc'] as double? ?? 0));

    pw.Widget seccion(String titulo, List<pw.Widget> hijos) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(
                horizontal: 2 * _mm, vertical: 1 * _mm),
            color: PdfColor.fromHex('#334155'),
            child: pw.Text(titulo,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
          pw.Container(
            padding: pw.EdgeInsets.all(2 * _mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: hijos),
          ),
          pw.SizedBox(height: 2 * _mm),
        ],
      );
    }

    pw.Widget fila(String l, String v) => pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 0.4 * _mm),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 55 * _mm,
                child: pw.Text('$l:',
                    style: pw.TextStyle(
                        fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(
                child: pw.Text(v, style: const pw.TextStyle(fontSize: 7.5))),
          ]),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Título ─────────────────────────────────────────────────────────
        pw.Center(
          child: pw.Column(children: [
            pw.Text('CERTIFICADO DE EMPRESA',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 1 * _mm),
            pw.Text(
                'Para prestación por desempleo, subsidio y renta activa de inserción '
                '(RD 625/1985, de 2 de abril)',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center),
          ]),
        ),
        pw.SizedBox(height: 5 * _mm),

        // ── I. DATOS DE LA EMPRESA ─────────────────────────────────────────
        seccion('I. DATOS DE LA EMPRESA', [
          fila('Razón social', nombreEmpresa),
          fila('CIF', cif),
          fila('CCC (Cód. Cuenta Cotización)', ccc),
          fila('Domicilio', domicilioEmpresa),
          fila('Representante legal', representante),
        ]),

        // ── II. DATOS DEL TRABAJADOR ───────────────────────────────────────
        seccion('II. DATOS DEL TRABAJADOR', [
          fila('Apellidos y nombre', finiquito.empleadoNombre),
          fila('DNI/NIE', finiquito.empleadoNif ?? '—'),
          fila('N.º Afiliación SS (NAF)', naf ?? '—'),
          fila('Domicilio', domicilioEmp.isNotEmpty ? domicilioEmp : '—'),
          fila('Categoría / cargo', finiquito.cargoEmpleado ?? '—'),
          fila('Grupo de cotización', grupoCotizacion),
        ]),

        // ── III. DATOS DEL CONTRATO Y CESE ────────────────────────────────
        seccion('III. DATOS DEL CONTRATO Y CESE', [
          fila('Tipo de contrato', tipoContrato),
          fila('Fecha inicio contrato', _fmtDate(finiquito.fechaInicioContrato)),
          fila('Fecha de cese', _fmtDate(finiquito.fechaBaja)),
          fila('Causa del cese', codigoCese),
          fila('Causa legal', finiquito.causaBaja.descripcionLegal),
          fila('Período de prueba', 'No'),
        ]),

        // ── IV. BASES DE COTIZACIÓN (últimos 180 días) ─────────────────────
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.symmetric(
                  horizontal: 2 * _mm, vertical: 1 * _mm),
              color: PdfColor.fromHex('#334155'),
              child: pw.Text('IV. BASES DE COTIZACIÓN — ÚLTIMOS 180 DÍAS',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey400, width: 0.3),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                  children: [
                    _celdaH('MES'),
                    _celdaH('AÑO'),
                    _celdaH('DÍAS'),
                    _celdaH('BASE CC (€)'),
                  ],
                ),
                if (basesCotizacion.isEmpty)
                  pw.TableRow(children: [
                    _celda('Sin datos'),
                    _celda('—'),
                    _celda('—'),
                    _celda('—'),
                  ])
                else
                  ...basesCotizacion.map((b) => pw.TableRow(children: [
                        _celda(_nombreMes(b['mes'] as int? ?? 0)),
                        _celda('${b['anio']}'),
                        _celda('${b['dias']}',
                            align: pw.TextAlign.center),
                        _celda('${(b['base_cc'] as double).toStringAsFixed(2)} €',
                            align: pw.TextAlign.right),
                      ])),
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                  children: [
                    _celda('TOTAL', bold: true),
                    _celda(''),
                    _celda('$totalDiasCotizados',
                        bold: true, align: pw.TextAlign.center),
                    _celda('${totalBasesCotizacion.toStringAsFixed(2)} €',
                        bold: true, align: pw.TextAlign.right),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 2 * _mm),
          ],
        ),

        // ── V. DATOS ECONÓMICOS ────────────────────────────────────────────
        seccion('V. DATOS ECONÓMICOS', [
          fila('Salario bruto mensual',
              '${salarioMensual.toStringAsFixed(2)} €'),
          fila('Salario en especie', 'No'),
          fila('Reducción de jornada', 'No'),
          fila('Pagas extra',
              finiquito.pagasProrrateadas ? 'Prorrateadas' : '${finiquito.numPagas} pagas/año'),
        ]),

        // ── Firma ──────────────────────────────────────────────────────────
        pw.SizedBox(height: 4 * _mm),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Firma y sello de la empresa:',
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.SizedBox(height: 12 * _mm),
              pw.Container(
                  width: 60 * _mm,
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          top: pw.BorderSide(width: 0.5)))),
              pw.Text(representante,
                  style: const pw.TextStyle(fontSize: 7)),
              pw.Text('Firmado en ${_fmtDate(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 7)),
            ]),
          ],
        ),
      ],
    );
  }

  static pw.Widget _celdaH(String t) => pw.Padding(
        padding: pw.EdgeInsets.all(1.5 * _mm),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _celda(String t,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(1.5 * _mm),
      child: pw.Text(t,
          style: bold
              ? pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)
              : const pw.TextStyle(fontSize: 7.5),
          textAlign: align),
    );
  }

  static String _nombreMes(int m) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return meses.elementAtOrNull(m) ?? '—';
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Compartir el certificado generado.
  Future<void> compartir(Uint8List bytes, String nombreEmpleado) async {
    final dir = await getTemporaryDirectory();
    final nombre = 'certificado_sepe_${nombreEmpleado.replaceAll(' ', '_')}.pdf';
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(archivo.path)],
        text: 'Certificado de empresa SEPE — $nombreEmpleado');
  }
}



