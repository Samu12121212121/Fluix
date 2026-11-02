import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import '../../pdf_templates/data/pdf_template_service.dart' as ptSvc;
import '../../pdf_templates/domain/models/pdf_template.dart' as ptModel;
import 'fichajes_colors.dart';

class TabInformesFichaje extends StatefulWidget {
  final String empresaId;

  const TabInformesFichaje({super.key, required this.empresaId});

  @override
  State<TabInformesFichaje> createState() => _TabInformesFichajeState();
}

class _TabInformesFichajeState extends State<TabInformesFichaje> {
  final _svc = FichajeService();
  late DateTime _mes;
  bool _cargando = false;
  List<_ResumenEmpleadoMes> _datos = [];
  String _empresaNombre = '';

  static const _bandColor = Color(0xFF2E5A50);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mes = DateTime(now.year, now.month);
    _cargar();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      final empDoc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .get();
      _empresaNombre = (empDoc.data()?['nombre'] as String? ?? '').isNotEmpty
          ? (empDoc.data()!['nombre'] as String)
          : 'Mi empresa';

      final empSnap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('empleados_fichaje')
          .orderBy('nombre')
          .get();
      final empleados =
          empSnap.docs.map(EmpleadoFichaje.fromFirestore).toList();
      final jornadaMap = {for (final e in empleados) e.uid: e.jornadaDiaria};
      final fichajes =
          await _svc.fichajesMes(empresaId: widget.empresaId, mes: _mes);
      final Map<String, Fichaje> efectivos = {};
      for (final f in fichajes) {
        final key = '${f.empleadoId}_${f.fecha}';
        final actual = efectivos[key];
        if (actual == null) {
          efectivos[key] = f;
        } else if (f.esCorreccion && !actual.esCorreccion) {
          efectivos[key] = f;
        }
      }
      final Map<String, int> mins = {},
          dias = {},
          minsExtra = {},
          numPausas = {},
          minsPausa = {},
          incidencias = {};
      final hoyKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      for (final f in efectivos.values) {
        final uid = f.empleadoId;
        mins[uid] = (mins[uid] ?? 0) + (f.tiempoNeto?.inMinutes ?? 0);
        dias[uid] = (dias[uid] ?? 0) + 1;
        if (f.tipoHoras == TipoHoras.extraordinarias) {
          minsExtra[uid] =
              (minsExtra[uid] ?? 0) + (f.tiempoNeto?.inMinutes ?? 0);
        }
        numPausas[uid] = (numPausas[uid] ?? 0) +
            f.pausas.where((p) => p.fin != null).length;
        minsPausa[uid] = (minsPausa[uid] ?? 0) + f.minutosPausa;
        if (f.salida == null && f.fecha != hoyKey) {
          incidencias[uid] = (incidencias[uid] ?? 0) + 1;
        }
      }
      final datos = empleados
          .map((e) => _ResumenEmpleadoMes(
                uid: e.uid,
                nombre: e.nombre,
                activo: e.activo,
                dias: dias[e.uid] ?? 0,
                minutosNetos: mins[e.uid] ?? 0,
                minutosPlani:
                    (jornadaMap[e.uid] ?? 480) * (dias[e.uid] ?? 0),
                minutosExtra: minsExtra[e.uid] ?? 0,
                numPausas: numPausas[e.uid] ?? 0,
                minutosPausa: minsPausa[e.uid] ?? 0,
                incidencias: incidencias[e.uid] ?? 0,
              ))
          .toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));
      if (mounted) setState(() => _datos = datos);
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMMM yyyy', 'es_ES');
    final mesTxt = fmt.format(_mes);
    final mesLabel = '${mesTxt[0].toUpperCase()}${mesTxt.substring(1)}';
    final totalMins = _datos.fold(0, (s, d) => s + d.minutosNetos);
    final totalDias = _datos.fold(0, (s, d) => s + d.dias);
    final conDias = _datos.where((d) => d.dias > 0).length;
    final incTotal = _datos.fold(0, (s, d) => s + d.incidencias);
    final avgMin = conDias > 0 ? totalMins ~/ conDias : 0;
    final hoyStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: kFBorder)),
        ),
        child: Row(children: [
          const Text('Informes de horas',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kFText)),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _mes,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                locale: const Locale('es', 'ES'),
              );
              if (picked != null && mounted) {
                setState(
                    () => _mes = DateTime(picked.year, picked.month));
                _cargar();
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  border: Border.all(color: kFBorder),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 14, color: kFGreen),
                const SizedBox(width: 6),
                Text(mesLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kFText)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 16, color: kFSub),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _datos.isEmpty ? null : _descargarPdf,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: kFGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.picture_as_pdf_outlined, size: 14, color: kFGreen),
                SizedBox(width: 5),
                Text('PDF',
                    style: TextStyle(
                        fontSize: 12,
                        color: kFGreen,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _datos.isEmpty ? null : _enviarPorEmail,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.email_outlined, size: 14, color: Color(0xFF6366F1)),
                SizedBox(width: 5),
                Text('Email',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _cargar,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  border: Border.all(color: kFBorder),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.refresh_rounded, size: 16, color: kFSub),
            ),
          ),
        ]),
      ),
      if (_cargando)
        const LinearProgressIndicator(color: kFGreen, minHeight: 2),
      if (!_cargando && _datos.isEmpty)
        const Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart_outlined,
                    size: 56, color: Color(0xFFE5E7EB)),
                SizedBox(height: 12),
                Text('Sin datos para este mes',
                    style: TextStyle(color: kFSub, fontSize: 14)),
              ],
            ),
          ),
        )
      else
        Expanded(
          child: Container(
            color: const Color(0xFFF0F2F5),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 40,
                            offset: const Offset(0, 12))
                      ],
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.fromLTRB(40, 30, 40, 30),
                            color: _bandColor,
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              _empresaNombre.toUpperCase(),
                                              style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5)),
                                          const SizedBox(height: 4),
                                          const Text(
                                              'Departamento de Recursos Humanos',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFFD0E5DE))),
                                        ]),
                                  ),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text('INFORME DE HORAS',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 1)),
                                        const SizedBox(height: 4),
                                        Text(
                                            '$mesLabel  ·  Generado $hoyStr',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.white70)),
                                      ]),
                                ]),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(40, 30, 40, 40),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    _docKpi('Empleados activos', '$conDias'),
                                    const SizedBox(width: 12),
                                    _docKpi('Total horas', _fmtMin(totalMins)),
                                    const SizedBox(width: 12),
                                    _docKpi('Media por empleado',
                                        _fmtMin(avgMin)),
                                    const SizedBox(width: 12),
                                    _docKpi('Incidencias', '$incTotal',
                                        accent: incTotal > 0
                                            ? Colors.red
                                            : null),
                                  ]),
                                  const SizedBox(height: 28),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(3.2),
                                        1: FlexColumnWidth(1.8),
                                        2: FlexColumnWidth(2.2),
                                        3: FlexColumnWidth(1.8),
                                        4: FlexColumnWidth(1.4),
                                        5: FlexColumnWidth(2),
                                      },
                                      border: TableBorder.symmetric(
                                          inside: const BorderSide(
                                              color: Color(0xFFEEEEEE))),
                                      children: [
                                        TableRow(
                                          decoration: const BoxDecoration(
                                              color: _bandColor),
                                          children: [
                                            'EMPLEADO',
                                            'H. PLANIF.',
                                            'H. TRABAJADAS',
                                            'H. EXTRA',
                                            'DÍAS',
                                            'INCIDENCIAS'
                                          ]
                                              .map((h) => Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                                    child: Text(h,
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Colors.white,
                                                            letterSpacing:
                                                                0.4)),
                                                  ))
                                              .toList(),
                                        ),
                                        ..._datos.asMap().entries.map((entry) {
                                          final i = entry.key;
                                          final d = entry.value;
                                          final bg = i.isEven
                                              ? const Color(0xFFF8F9FB)
                                              : Colors.white;
                                          return TableRow(
                                            decoration:
                                                BoxDecoration(color: bg),
                                            children: [
                                              _tcell(d.nombre, bold: true),
                                              _tcell(d.horasPlanifStr),
                                              _tcell(d.horasStr,
                                                  color: d.minutosNetos > 0
                                                      ? _bandColor
                                                      : null,
                                                  bold: d.minutosNetos > 0),
                                              _tcell(d.horasExtraStr,
                                                  color: d.minutosExtra > 0
                                                      ? const Color(0xFFF59E0B)
                                                      : null),
                                              _tcell('${d.dias}d'),
                                              _tcell(
                                                  d.incidencias > 0
                                                      ? '⚠ ${d.incidencias}'
                                                      : '—',
                                                  color: d.incidencias > 0
                                                      ? Colors.red
                                                      : null),
                                            ],
                                          );
                                        }),
                                        TableRow(
                                          decoration: const BoxDecoration(
                                              color: Color(0xFFF5F5F5)),
                                          children: [
                                            _tcell('TOTAL',
                                                bold: true, isLabel: true),
                                            _tcell('—'),
                                            _tcell(_fmtMin(totalMins),
                                                bold: true, color: _bandColor),
                                            _tcell('—'),
                                            _tcell('${totalDias}d',
                                                bold: true),
                                            _tcell('$incTotal',
                                                bold: incTotal > 0,
                                                color: incTotal > 0
                                                    ? Colors.red
                                                    : null),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 44),
                                  Row(children: [
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            SizedBox(height: 40),
                                            Divider(
                                                color: Color(0xFF999999)),
                                            SizedBox(height: 6),
                                            Text(
                                                'Firma del responsable de RRHH',
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    color:
                                                        Color(0xFF666666))),
                                          ]),
                                    ),
                                    const SizedBox(width: 48),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            SizedBox(height: 40),
                                            Divider(
                                                color: Color(0xFF999999)),
                                            SizedBox(height: 6),
                                            Text('Visto bueno — Dirección',
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    color:
                                                        Color(0xFF666666))),
                                          ]),
                                    ),
                                  ]),
                                ]),
                          ),
                        ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _docKpi(String label, String valor, {Color? accent}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF999999),
                    letterSpacing: 0.4)),
            const SizedBox(height: 5),
            Text(valor,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accent ?? _bandColor)),
          ]),
        ),
      );

  static Widget _tcell(String text,
          {bool bold = false, Color? color, bool isLabel = false}) =>
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Text(text,
            style: TextStyle(
              fontSize: isLabel ? 10 : 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ??
                  (isLabel
                      ? const Color(0xFF8A8A8A)
                      : const Color(0xFF1A1A1A)),
            )),
      );

  static String _fmtMin(int min) =>
      '${min ~/ 60}h ${(min % 60).toString().padLeft(2, '0')}m';

  Future<void> _enviarPorEmail() async {
    // Pedir email al usuario
    final ctrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar informe por email'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Dirección de email',
            hintText: 'ejemplo@empresa.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;

    FluxToast.info(context, 'Generando PDF…');
    try {
      // Generar PDF en memoria
      final pdfBytes = await _generarPdfBytes();
      if (!mounted) return;
      FluxToast.info(context, 'Enviando a $email…');

      final fmt = DateFormat('MMMM yyyy', 'es_ES');
      final mesTxt = fmt.format(_mes);
      final titulo = 'Informe de Horas — ${mesTxt[0].toUpperCase()}${mesTxt.substring(1)}';

      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
      await fn.httpsCallable('enviarInformeFichajes',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
        .call({
          'empresaId': widget.empresaId,
          'email':     email,
          'asunto':    titulo,
          'mes':       _mes.month,
          'año':       _mes.year,
          'pdfBase64': base64Encode(pdfBytes),
          'nombreArchivo': 'informe_horas_${_mes.year}_${_mes.month.toString().padLeft(2,'0')}.pdf',
        });
      if (mounted) FluxToast.exito(context, 'Informe enviado a $email', title: 'Enviado ✓');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) FluxToast.error(context, 'Error ${e.code}: ${e.message}');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  Future<void> _descargarPdf() async {
    final bytes = await _generarPdfBytes();
    await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
  }

  Future<List<int>> _generarPdfBytes() async {
    final fmt = DateFormat('MMMM yyyy', 'es_ES');
    final mesTxt = fmt.format(_mes);
    final titulo =
        'Informe de Horas — ${mesTxt[0].toUpperCase()}${mesTxt.substring(1)}';
    String colorHex = '#22C55E';
    try {
      final p = await ptSvc.PdfTemplateService().getPlantillaDefault(
              widget.empresaId, ptModel.TipoDocumentoPdf.horasEmpleado) ??
          await ptSvc.PdfTemplateService().getPlantillaDefault(
              widget.empresaId, ptModel.TipoDocumentoPdf.fichajes);
      if (p != null && p.colorPrimario.isNotEmpty) colorHex = p.colorPrimario;
    } catch (_) {}
    PdfColor pdfColor(String hex) {
      try { return PdfColor.fromHex(hex); } catch (_) { return PdfColor.fromHex('#22C55E'); }
    }

    final colPrimary = pdfColor(colorHex);
    final pdf = pw.Document();
    final totalMins = _datos.fold(0, (s, d) => s + d.minutosNetos);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Text(titulo,
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold, color: colPrimary)),
        pw.SizedBox(height: 4),
        pw.Text('Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(
            'Total horas: ${_fmtMin(totalMins)}  ·  Empleados: ${_datos.where((d) => d.dias > 0).length}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Empleado','H. Planif.','H. Trab.','H. Extra','Pausas','Días','Incidencias'],
          data: _datos.map((d) => [
                d.nombre, d.horasPlanifStr, d.horasStr, d.horasExtraStr,
                d.pausasStr, '${d.dias}d',
                d.incidencias > 0 ? '⚠ ${d.incidencias}' : '—'
              ]).toList(),
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: colPrimary),
          cellStyle: const pw.TextStyle(fontSize: 9),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3.0),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.2),
            4: pw.FlexColumnWidth(1.2),
            5: pw.FlexColumnWidth(0.8),
            6: pw.FlexColumnWidth(1.4),
          },
        ),
      ],
    ));
    return pdf.save();
  }
}

class _ResumenEmpleadoMes {
  final String uid, nombre;
  final bool activo;
  final int dias,
      minutosNetos,
      minutosPlani,
      minutosExtra,
      numPausas,
      minutosPausa,
      incidencias;

  const _ResumenEmpleadoMes({
    required this.uid,
    required this.nombre,
    required this.activo,
    required this.dias,
    required this.minutosNetos,
    required this.minutosPlani,
    required this.minutosExtra,
    required this.numPausas,
    required this.minutosPausa,
    required this.incidencias,
  });

  String get horasStr => _m(minutosNetos);
  String get horasPlanifStr =>
      minutosPlani > 0 ? _m(minutosPlani) : '—';
  String get horasExtraStr {
    if (minutosPlani > 0) {
      final e = minutosNetos - minutosPlani;
      return e > 0 ? _m(e) : '—';
    }
    return minutosExtra > 0 ? _m(minutosExtra) : '—';
  }

  String get pausasStr =>
      numPausas > 0 ? '$numPausas (${_m(minutosPausa)})' : '—';

  static String _m(int min) =>
      '${min ~/ 60}h ${(min % 60).toString().padLeft(2, '0')}m';
}
