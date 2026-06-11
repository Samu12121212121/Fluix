import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import '../../fichaje/pantalla_fichaje/pantalla_fichaje.dart';
import '../../pdf_templates/data/pdf_template_service.dart' as ptSvc;
import '../../pdf_templates/domain/models/pdf_template.dart' as ptModel;

class GestionFichajesScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;

  const GestionFichajesScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
  });

  @override
  State<GestionFichajesScreen> createState() => _GestionFichajesScreenState();
}

class _GestionFichajesScreenState extends State<GestionFichajesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    final length = widget.esAdmin ? 3 : 1;
    _tabCtrl = TabController(length: length, vsync: this)
      ..addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!widget.esAdmin) {
      return const Scaffold(body: PantallaFichaje(embedido: true));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Fichajes'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.fingerprint), text: 'Mi fichaje'),
            Tab(icon: Icon(Icons.people_outline), text: 'Empleados'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Informes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          const PantallaFichaje(embedido: true),
          _TabEmpleados(empresaId: widget.empresaId),
          _TabInformes(empresaId: widget.empresaId),
        ],
      ),
    );
  }
}

// ── Removed Fichajes table tab code (crearDatosDemo etc.) ─────────────────

// ── TAB: EMPLEADOS ────────────────────────────────────────────────────────────

class _TabEmpleados extends StatefulWidget {
  final String empresaId;
  const _TabEmpleados({required this.empresaId});
  @override
  State<_TabEmpleados> createState() => _TabEmpleadosState();
}

class _TabEmpleadosState extends State<_TabEmpleados> {
  final _svc = FichajeService();

  // Empleados del módulo de RRHH (usuarios con empresa_id)
  Stream<QuerySnapshot<Map<String, dynamic>>> get _usuariosStream =>
      FirebaseFirestore.instance
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .snapshots();

  // PINs ya configurados en empleados_fichaje, indexados por UID
  Stream<Map<String, EmpleadoFichaje>> get _fichajeMapStream =>
      FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('empleados_fichaje')
          .snapshots()
          .map((s) => {
                for (final d in s.docs)
                  d.id: EmpleadoFichaje.fromFirestore(d),
              });

  void _configurarPIN(String uid, String nombre, String? pinActual, int jornadaActual) {
    showDialog(
      context: context,
      builder: (ctx) => _DialogConfigurarPIN(
        uid: uid,
        nombre: nombre,
        pinActual: pinActual,
        jornadaActual: jornadaActual,
        empresaId: widget.empresaId,
        svc: _svc,
      ),
    );
  }

  Future<void> _toggleActivo(EmpleadoFichaje emp) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _svc.actualizarEmpleado(
        empresaId: widget.empresaId,
        uid: emp.uid,
        activo: !emp.activo,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, EmpleadoFichaje>>(
      stream: _fichajeMapStream,
      builder: (context, fichajeSnap) {
        final fichajeMap = fichajeSnap.data ?? {};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usuariosStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data?.docs ?? [];
            final activos = docs
                .where((d) => d.data()['estado'] != 'baja')
                .toList()
              ..sort((a, b) => ((a.data()['nombre'] as String?) ?? '')
                  .compareTo((b.data()['nombre'] as String?) ?? ''));

            if (activos.isEmpty) {
              return Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Sin empleados en la empresa',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Añade empleados desde el módulo de RRHH',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ]),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activos.length,
              itemBuilder: (ctx, i) {
                final doc = activos[i];
                final data = doc.data();
                final uid = doc.id;
                final nombre = (data['nombre'] as String?) ?? 'Sin nombre';
                final fichaje = fichajeMap[uid];
                final tienePIN = fichaje != null;
                final pinActivo = tienePIN && fichaje.activo;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: pinActivo ? Colors.blue[50] : Colors.grey[100],
                      child: Icon(Icons.person,
                          color: pinActivo ? Colors.blue : Colors.grey),
                    ),
                    title: Text(nombre),
                    subtitle: tienePIN
                        ? Text('PIN: ${fichaje.pin}',
                            style: const TextStyle(
                                fontFamily: 'monospace', letterSpacing: 2))
                        : TextButton.icon(
                            onPressed: () => _configurarPIN(uid, nombre, null, 480),
                            icon: Icon(Icons.pin_outlined,
                                size: 15, color: Colors.orange[700]),
                            label: Text('Establecer PIN',
                                style: TextStyle(
                                    color: Colors.orange[700], fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                    trailing: tienePIN
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            Chip(
                              label: Text(pinActivo ? 'Activo' : 'Inactivo',
                                  style: const TextStyle(fontSize: 11)),
                              backgroundColor:
                                  pinActivo ? Colors.green[50] : Colors.grey[100],
                              side: BorderSide(
                                  color: pinActivo ? Colors.green : Colors.grey),
                              padding: EdgeInsets.zero,
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () =>
                                  _configurarPIN(uid, nombre, fichaje.pin, fichaje.jornadaDiaria),
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              icon: Icon(
                                  pinActivo
                                      ? Icons.person_off_outlined
                                      : Icons.person_add_outlined,
                                  size: 20),
                              onPressed: () => _toggleActivo(fichaje),
                              tooltip: pinActivo ? 'Desactivar' : 'Activar',
                              color: pinActivo ? Colors.orange : Colors.green,
                            ),
                          ])
                        : null,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── DIALOG: CONFIGURAR PIN ────────────────────────────────────────────────────

class _DialogConfigurarPIN extends StatefulWidget {
  final String uid;
  final String nombre;
  final String? pinActual;
  final int jornadaActual;
  final String empresaId;
  final FichajeService svc;

  const _DialogConfigurarPIN({
    required this.uid,
    required this.nombre,
    required this.pinActual,
    required this.jornadaActual,
    required this.empresaId,
    required this.svc,
  });

  @override
  State<_DialogConfigurarPIN> createState() => _DialogConfigurarPINState();
}

class _DialogConfigurarPINState extends State<_DialogConfigurarPIN> {
  late final TextEditingController _pinCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  late int _jornadaDiaria;

  @override
  void initState() {
    super.initState();
    _pinCtrl = TextEditingController(text: widget.pinActual ?? '');
    _jornadaDiaria = widget.jornadaActual;
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.pinActual == null ? 'Configurar acceso' : 'Editar empleado'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _pinCtrl,
                decoration: const InputDecoration(
                  labelText: 'PIN (4 dígitos)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
                autofocus: true,
                validator: (v) {
                  if (v == null || v.length != 4) return 'Debe tener 4 dígitos';
                  if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Solo números';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _jornadaDiaria,
                decoration: const InputDecoration(
                  labelText: 'Jornada diaria',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: 240, child: Text('4 horas')),
                  DropdownMenuItem(value: 300, child: Text('5 horas')),
                  DropdownMenuItem(value: 360, child: Text('6 horas')),
                  DropdownMenuItem(value: 420, child: Text('7 horas')),
                  DropdownMenuItem(value: 480, child: Text('8 horas')),
                ],
                onChanged: (v) => setState(() => _jornadaDiaria = v!),
              ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final pin = _pinCtrl.text;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.svc.configurarPINEmpleado(
        empresaId: widget.empresaId,
        uid: widget.uid,
        nombre: widget.nombre,
        pin: pin,
        jornadaDiaria: _jornadaDiaria,
      );
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text('Empleado actualizado: ${widget.nombre}'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
      messenger.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

// ── TAB: INFORMES ─────────────────────────────────────────────────────────────

class _ResumenEmpleadoMes {
  final String uid;
  final String nombre;
  final bool activo;
  final int dias;
  final int minutosNetos;
  final int minutosPlani;
  final int minutosExtra;
  final int numPausas;
  final int minutosPausa;
  final int incidencias;

  const _ResumenEmpleadoMes({
    required this.uid, required this.nombre, required this.activo,
    required this.dias, required this.minutosNetos,
    required this.minutosPlani,
    required this.minutosExtra, required this.numPausas,
    required this.minutosPausa, required this.incidencias,
  });

  String get horasStr => _m(minutosNetos);
  String get horasPlanifStr => minutosPlani > 0 ? _m(minutosPlani) : '—';
  String get horasExtraStr {
    if (minutosPlani > 0) {
      final extra = minutosNetos - minutosPlani;
      return extra > 0 ? _m(extra) : '—';
    }
    return minutosExtra > 0 ? _m(minutosExtra) : '—';
  }
  String get pausasStr => numPausas > 0 ? '$numPausas (${_m(minutosPausa)})' : '—';

  static String _m(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class _TabInformes extends StatefulWidget {
  final String empresaId;
  const _TabInformes({required this.empresaId});
  @override
  State<_TabInformes> createState() => _TabInformesState();
}

class _TabInformesState extends State<_TabInformes> {
  final _svc = FichajeService();
  late DateTime _mes;
  bool _cargando = false;
  List<_ResumenEmpleadoMes> _datos = [];

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
      final empSnap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('empleados_fichaje').orderBy('nombre').get();
      final empleados = empSnap.docs.map(EmpleadoFichaje.fromFirestore).toList();
      final Map<String, int> jornadaDiariaMap = {
        for (final e in empleados) e.uid: e.jornadaDiaria,
      };

      final fichajes = await _svc.fichajesMes(empresaId: widget.empresaId, mes: _mes);

      // Fichaje efectivo por empleado+fecha
      final Map<String, Fichaje> efectivos = {};
      for (final f in fichajes) {
        final key = '${f.empleadoId}_${f.fecha}';
        final actual = efectivos[key];
        if (actual == null) {
          efectivos[key] = f;
        } else if (f.esCorreccion && !actual.esCorreccion) {
          efectivos[key] = f;
        } else if (f.esCorreccion && actual.esCorreccion &&
            f.corregidoAt != null && actual.corregidoAt != null &&
            f.corregidoAt!.compareTo(actual.corregidoAt!) > 0) {
          efectivos[key] = f;
        }
      }

      final Map<String, int> mins = {};
      final Map<String, int> dias = {};
      final Map<String, int> minsExtra = {};
      final Map<String, int> numPausas = {};
      final Map<String, int> minsPausa = {};
      final Map<String, int> incidencias = {};
      final hoyKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (final f in efectivos.values) {
        final uid = f.empleadoId;
        mins[uid] = (mins[uid] ?? 0) + (f.tiempoNeto?.inMinutes ?? 0);
        dias[uid] = (dias[uid] ?? 0) + 1;
        if (f.tipoHoras == TipoHoras.extraordinarias) {
          minsExtra[uid] = (minsExtra[uid] ?? 0) + (f.tiempoNeto?.inMinutes ?? 0);
        }
        final cerradas = f.pausas.where((p) => p.fin != null).length;
        numPausas[uid] = (numPausas[uid] ?? 0) + cerradas;
        minsPausa[uid] = (minsPausa[uid] ?? 0) + f.minutosPausa;
        if (f.salida == null && f.fecha != hoyKey) {
          incidencias[uid] = (incidencias[uid] ?? 0) + 1;
        }
      }

      final datos = empleados.map((e) => _ResumenEmpleadoMes(
        uid: e.uid, nombre: e.nombre, activo: e.activo,
        dias: dias[e.uid] ?? 0, minutosNetos: mins[e.uid] ?? 0,
        minutosPlani: (jornadaDiariaMap[e.uid] ?? 480) * (dias[e.uid] ?? 0),
        minutosExtra: minsExtra[e.uid] ?? 0,
        numPausas: numPausas[e.uid] ?? 0,
        minutosPausa: minsPausa[e.uid] ?? 0,
        incidencias: incidencias[e.uid] ?? 0,
      )).toList()..sort((a, b) => a.nombre.compareTo(b.nombre));

      if (mounted) setState(() => _datos = datos);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _verFichajesEmpleado(_ResumenEmpleadoMes emp) {
    showDialog(
      context: context,
      builder: (ctx) => _DialogFichajesEmpleado(
        empresaId: widget.empresaId,
        empleadoId: emp.uid,
        empleadoNombre: emp.nombre,
        mes: _mes,
        svc: _svc,
        onCorregido: _cargar,
      ),
    );
  }

  Future<void> _seleccionarMes() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _mes,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && mounted) {
      setState(() => _mes = DateTime(picked.year, picked.month));
      _cargar();
    }
  }

  void _exportarCSV() {
    if (_datos.isEmpty) return;
    final fmt = DateFormat('MMMM yyyy', 'es_ES');
    final buf = StringBuffer()
      ..writeln('Informe de horas — ${fmt.format(_mes)}')
      ..writeln()
      ..writeln('Empleado,Días trabajados,Horas netas,Estado');
    for (final d in _datos) {
      buf.writeln('${d.nombre},${d.dias},${d.horasStr},${d.activo ? "Activo" : "Inactivo"}');
    }
    final total = _datos.fold(0, (sum, d) => sum + d.minutosNetos);
    buf.writeln('TOTAL,${_datos.fold(0, (s, d) => s + d.dias)},${total ~/ 60}h ${(total % 60).toString().padLeft(2, '0')}m,');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('informe_${DateFormat("yyyy_MM").format(_mes)}.csv'),
        content: SingleChildScrollView(
          child: SelectableText(buf.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMMM yyyy', 'es_ES');
    final totalMins = _datos.fold(0, (sum, d) => sum + d.minutosNetos);
    final totalDias = _datos.fold(0, (sum, d) => sum + d.dias);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.blue[50],
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _seleccionarMes,
                child: Row(children: [
                  const Icon(Icons.calendar_month, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(fmt.format(_mes).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const Icon(Icons.arrow_drop_down, color: Colors.blue),
                ]),
              ),
            ),
            IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.blue), onPressed: _datos.isEmpty ? null : _descargarPdf, tooltip: 'Descargar PDF'),
            IconButton(icon: const Icon(Icons.download, color: Colors.blue), onPressed: _exportarCSV, tooltip: 'Exportar CSV'),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.blue), onPressed: _cargar, tooltip: 'Actualizar'),
          ]),
        ),

        if (_cargando) const LinearProgressIndicator(),

        if (!_cargando && _datos.isEmpty)
          const Expanded(
            child: Center(child: Text('Sin empleados para este mes', style: TextStyle(color: Colors.grey))),
          )
        else if (!_cargando)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Card(
                  color: const Color(0xFF0D47A1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _statCard('Empleados', '${_datos.where((d) => d.dias > 0).length}'),
                      _statCard('Total horas', '${totalMins ~/ 60}h ${(totalMins % 60).toString().padLeft(2, '0')}m'),
                      _statCard('Días totales', '$totalDias'),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Empleado', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('H. Planif.', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('H. Trabajadas', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('H. Extra', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Pausas', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Incidencias', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: _datos.map((d) => DataRow(
                        onSelectChanged: (_) => _verFichajesEmpleado(d),
                        cells: [
                        DataCell(Row(children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: d.activo ? Colors.blue[50] : Colors.grey[100],
                            child: Icon(Icons.person, size: 16, color: d.activo ? Colors.blue : Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Text(d.nombre, style: TextStyle(color: d.activo ? null : Colors.grey[500])),
                        ])),
                        DataCell(Text(d.horasPlanifStr,
                            style: TextStyle(color: d.minutosPlani == 0 ? Colors.grey : null))),
                        DataCell(Text(d.horasStr,
                            style: TextStyle(
                              fontWeight: d.minutosNetos > 0 ? FontWeight.w600 : FontWeight.normal,
                              color: d.minutosNetos == 0 ? Colors.grey : null,
                            ))),
                        DataCell(Text(d.horasExtraStr,
                            style: TextStyle(color: d.minutosExtra > 0 ? Colors.orange[700] : Colors.grey))),
                        DataCell(Text(d.pausasStr, style: const TextStyle(fontSize: 12))),
                        DataCell(d.incidencias > 0
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.warning_amber, size: 14, color: Colors.red[700]),
                                const SizedBox(width: 4),
                                Text('${d.incidencias}', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                              ])
                            : const Text('—', style: TextStyle(color: Colors.grey))),
                      ])).toList(),
                    ),
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  Future<void> _descargarPdf() async {
    final fmt = DateFormat('MMMM yyyy', 'es_ES');
    final mesTxt = fmt.format(_mes);
    final titulo = 'Informe de Horas — ${mesTxt[0].toUpperCase()}${mesTxt.substring(1)}';

    // Buscar colores de la plantilla de fichajes configurada
    String colorHex = '#0D47A1';
    String colorHexRow = '#E3F2FD';
    try {
      final plantilla = await ptSvc.PdfTemplateService()
          .getPlantillaDefault(widget.empresaId, ptModel.TipoDocumentoPdf.horasEmpleado)
          ?? await ptSvc.PdfTemplateService()
              .getPlantillaDefault(widget.empresaId, ptModel.TipoDocumentoPdf.fichajes);
      if (plantilla != null) {
        colorHex = plantilla.colorPrimario;
        // Generar color de fila alternativa desde el color primario con baja opacidad
        colorHexRow = '#F0F4FF';
      }
    } catch (_) {}

    PdfColor pdfColor(String hex) {
      try { return PdfColor.fromHex(hex); } catch (_) { return PdfColor.fromHex('#0D47A1'); }
    }
    final colPrimary = pdfColor(colorHex);
    final colRow     = pdfColor(colorHexRow);

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(titulo,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: colPrimary)),
          pw.SizedBox(height: 4),
          pw.Text('Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Empleado', 'H. Planif.', 'H. Trabajadas', 'H. Extra', 'Pausas', 'Incidencias'],
            data: _datos.map((d) => [
              d.nombre,
              d.horasPlanifStr,
              d.horasStr,
              d.horasExtraStr,
              d.pausasStr,
              d.incidencias > 0 ? '⚠ ${d.incidencias}' : '—',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: colPrimary),
            cellStyle: const pw.TextStyle(fontSize: 9),
            oddRowDecoration: pw.BoxDecoration(color: colRow),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Total horas trabajadas: ${_ResumenEmpleadoMes._m(_datos.fold(0, (s, d) => s + d.minutosNetos))}  |  '
            'Empleados activos: ${_datos.where((d) => d.dias > 0).length}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Widget _statCard(String label, String valor) {
    return Column(children: [
      Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
    ]);
  }
}

// ── DIALOG: FICHAJES DE UN EMPLEADO EN EL MES ─────────────────────────────────

class _DialogFichajesEmpleado extends StatelessWidget {
  final String empresaId;
  final String empleadoId;
  final String empleadoNombre;
  final DateTime mes;
  final FichajeService svc;
  final VoidCallback onCorregido;

  const _DialogFichajesEmpleado({
    required this.empresaId,
    required this.empleadoId,
    required this.empleadoNombre,
    required this.mes,
    required this.svc,
    required this.onCorregido,
  });

  @override
  Widget build(BuildContext context) {
    final mesTxt = DateFormat('MMMM yyyy', 'es_ES').format(mes);
    return AlertDialog(
      title: Text(empleadoNombre),
      titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<Fichaje>>(
          future: svc.fichajesMes(empresaId: empresaId, mes: mes),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final todos = (snap.data ?? []).where((f) => f.empleadoId == empleadoId).toList();
            // Resolver efectivos
            final Map<String, Fichaje> efectivos = {};
            for (final f in todos) {
              final key = f.fecha;
              final actual = efectivos[key];
              if (actual == null) {
                efectivos[key] = f;
              } else if (f.esCorreccion && !actual.esCorreccion) {
                efectivos[key] = f;
              }
            }
            final lista = efectivos.values.toList()..sort((a, b) => a.fecha.compareTo(b.fecha));
            if (lista.isEmpty) {
              return Center(child: Text('Sin fichajes en ${mesTxt.toLowerCase()}',
                  style: const TextStyle(color: Colors.grey)));
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (c, i) {
                final f = lista[i];
                final fmtH = DateFormat('HH:mm');
                final fmtD = DateFormat('EEE d MMM', 'es_ES');
                final fecha = DateTime.parse(f.fecha);
                final entH = f.entrada != null ? fmtH.format(f.entrada!.toDate().toLocal()) : '—';
                final salH = f.salida != null ? fmtH.format(f.salida!.toDate().toLocal()) : '—';
                final neto = f.tiempoNeto;
                final netoTxt = neto != null
                    ? '${neto.inHours}h ${(neto.inMinutes % 60).toString().padLeft(2, '0')}m'
                    : '—';
                return ListTile(
                  dense: true,
                  title: Text(fmtD.format(fecha), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text('$entH → $salH  ·  $netoTxt',
                      style: const TextStyle(fontSize: 12)),
                  leading: f.esCorreccion
                      ? const Icon(Icons.edit_note, color: Colors.orange, size: 18)
                      : const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Editar fichaje',
                    onPressed: () async {
                      await showDialog(
                        context: c,
                        builder: (_) => _DialogEditarFichaje(
                          empresaId: empresaId,
                          fichaje: f,
                          svc: svc,
                        ),
                      );
                      if (c.mounted) Navigator.pop(c);
                      onCorregido();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

// ── DIALOG: EDITAR FICHAJE ────────────────────────────────────────────────────

class _DialogEditarFichaje extends StatefulWidget {
  final String empresaId;
  final Fichaje fichaje;
  final FichajeService svc;

  const _DialogEditarFichaje({
    required this.empresaId,
    required this.fichaje,
    required this.svc,
  });

  @override
  State<_DialogEditarFichaje> createState() => _DialogEditarFichajeState();
}

class _DialogEditarFichajeState extends State<_DialogEditarFichaje> {
  late TimeOfDay _entrada;
  late TimeOfDay _salida;
  final _motivoCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.fichaje.entrada?.toDate().toLocal() ?? DateTime.now();
    final s = widget.fichaje.salida?.toDate().toLocal() ?? DateTime.now();
    _entrada = TimeOfDay(hour: e.hour, minute: e.minute);
    _salida = TimeOfDay(hour: s.hour, minute: s.minute);
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool esEntrada) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: esEntrada ? _entrada : _salida,
    );
    if (picked != null) {
      setState(() => esEntrada ? _entrada = picked : _salida = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmtD = DateFormat("EEEE d 'de' MMMM", 'es_ES');
    final fecha = DateTime.parse(widget.fichaje.fecha);
    return AlertDialog(
      title: Text('Corregir fichaje — ${fmtD.format(fecha)}',
          style: const TextStyle(fontSize: 15)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.fichaje.empleadoNombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _TimeButton(
            label: 'Entrada',
            time: _entrada,
            onTap: () => _pickTime(true),
          )),
          const SizedBox(width: 12),
          Expanded(child: _TimeButton(
            label: 'Salida',
            time: _salida,
            onTap: () => _pickTime(false),
          )),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo de corrección *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.note_alt_outlined),
          ),
          maxLines: 2,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar corrección'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El motivo es obligatorio'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final fechaBase = DateTime.parse(widget.fichaje.fecha);
      final nuevaEntrada = Timestamp.fromDate(DateTime(
        fechaBase.year, fechaBase.month, fechaBase.day,
        _entrada.hour, _entrada.minute,
      ));
      final nuevaSalida = Timestamp.fromDate(DateTime(
        fechaBase.year, fechaBase.month, fechaBase.day,
        _salida.hour, _salida.minute,
      ));
      await widget.svc.corregirFichaje(
        empresaId: widget.empresaId,
        fichajeOriginalId: widget.fichaje.id,
        motivo: motivo,
        corregidoPorUid: 'admin',
        nuevaEntrada: nuevaEntrada,
        nuevaSalida: nuevaSalida,
        nuevasPausas: widget.fichaje.pausas,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Corrección guardada'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeButton({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text('$hh:$mm', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}