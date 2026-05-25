import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import 'pantalla_fichaje_empleado.dart';

class GestionFichajesScreen extends StatefulWidget {
  final String empresaId;
  final String usuarioActualUid;

  const GestionFichajesScreen({
    super.key,
    required this.empresaId,
    required this.usuarioActualUid,
  });

  @override
  State<GestionFichajesScreen> createState() => _GestionFichajesScreenState();
}

class _GestionFichajesScreenState extends State<GestionFichajesScreen> {
  final FichajeService _service = FichajeService();
  DateTime _fecha = DateTime.now();
  bool _creandoDemo = false;

  String get _fechaKey => DateFormat('yyyy-MM-dd').format(_fecha);
  bool get _esHoy {
    final h = DateTime.now();
    return _fecha.year == h.year && _fecha.month == h.month && _fecha.day == h.day;
  }

  String _formatHora(Timestamp? ts, {bool conSegundos = false}) {
    if (ts == null) return '—';
    return DateFormat(conSegundos ? 'HH:mm:ss' : 'HH:mm').format(ts.toDate());
  }

  String _formatDuracion(Duration? d) {
    if (d == null) return '—';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }

  String _nombreTipo(TipoHoras t) {
    switch (t) {
      case TipoHoras.ordinarias: return 'Ordinarias';
      case TipoHoras.extraordinarias: return 'Extraordinarias';
      case TipoHoras.complementarias: return 'Complementarias';
    }
  }

  Stream<List<Fichaje>> _streamFecha() {
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('fichajes')
        .where('fecha', isEqualTo: _fechaKey)
        .where('es_correccion', isEqualTo: false)
        .orderBy('creado_at', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => Fichaje.fromFirestore(d)).toList());
  }

  // ── Abrir fichaje propio ──────────────────────────────────────────────────

  Future<void> _abrirFichajePropio() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaFichajeEmpleado(
          empresaId: widget.empresaId,
          dispositivoId: 'tablet_gestion',
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // ── Crear datos demo ──────────────────────────────────────────────────────

  Future<void> _crearDatosDemo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.auto_fix_high, color: Color(0xFF7C4DFF)),
          SizedBox(width: 8),
          Text('Crear datos de demo'),
        ]),
        content: const Text(
          'Se crearán 5 empleados de demo con fichajes de ejemplo para hoy y ayer.\n\n'
              'PINs:\n'
              '• María García → 1234\n'
              '• Juan López → 5678\n'
              '• Ana Torres → 9012\n'
              '• Carlos Sánchez → 3456\n'
              '• Laura Fernández → 7890\n\n'
              '¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), foregroundColor: Colors.white),
            child: const Text('Crear demo'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    setState(() => _creandoDemo = true);
    try {
      await _ejecutarCreacionDemo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Datos demo creados'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creandoDemo = false);
    }
  }

  Future<void> _ejecutarCreacionDemo() async {
    final db = FirebaseFirestore.instance;
    final emp = db.collection('empresas').doc(widget.empresaId);

    final empleados = [
      {'uid': 'demo_maria_garcia',    'nombre': 'María García López',    'pin': '1234'},
      {'uid': 'demo_juan_lopez',      'nombre': 'Juan López Martínez',   'pin': '5678'},
      {'uid': 'demo_ana_torres',      'nombre': 'Ana Torres Ruiz',       'pin': '9012'},
      {'uid': 'demo_carlos_sanchez',  'nombre': 'Carlos Sánchez Díaz',   'pin': '3456'},
      {'uid': 'demo_laura_fernandez', 'nombre': 'Laura Fernández Gil',   'pin': '7890'},
    ];
    for (final e in empleados) {
      await emp.collection('empleados_fichaje').doc(e['uid']).set({
        'nombre': e['nombre'], 'pin': e['pin'],
        'empresa_id': widget.empresaId, 'activo': true,
        'creado_at': FieldValue.serverTimestamp(),
      });
    }

    final hoy = DateTime.now();
    final fechaHoy = DateFormat('yyyy-MM-dd').format(hoy);
    final ayer = hoy.subtract(const Duration(days: 1));
    final fechaAyer = DateFormat('yyyy-MM-dd').format(ayer);
    ts(DateTime d, int h, int m) => Timestamp.fromDate(DateTime(d.year, d.month, d.day, h, m));

    // María — cerrada
    await emp.collection('fichajes').add({
      'empleado_id': 'demo_maria_garcia', 'empleado_nombre': 'María García López',
      'fecha': fechaHoy, 'entrada': ts(hoy,9,0), 'salida': ts(hoy,17,30),
      'pausas': [{'inicio': ts(hoy,11,0),'fin': ts(hoy,11,15)}, {'inicio': ts(hoy,14,0),'fin': ts(hoy,14,30)}],
      'tipo_horas': 'ordinarias', 'dispositivo_id': 'tablet_demo',
      'creado_at': ts(hoy,9,0), 'es_correccion': false,
      'correccion_de': null, 'motivo_correccion': null, 'corregido_por_uid': null, 'corregido_at': null,
    });

    // Juan — activo sin salida
    await emp.collection('fichajes').add({
      'empleado_id': 'demo_juan_lopez', 'empleado_nombre': 'Juan López Martínez',
      'fecha': fechaHoy, 'entrada': ts(hoy,10,15), 'salida': null,
      'pausas': [{'inicio': ts(hoy,14,0),'fin': ts(hoy,14,30)}],
      'tipo_horas': 'ordinarias', 'dispositivo_id': 'tablet_demo',
      'creado_at': ts(hoy,10,15), 'es_correccion': false,
      'correccion_de': null, 'motivo_correccion': null, 'corregido_por_uid': null, 'corregido_at': null,
    });

    // Ana — en pausa activa
    final ahora = DateTime.now();
    await emp.collection('fichajes').add({
      'empleado_id': 'demo_ana_torres', 'empleado_nombre': 'Ana Torres Ruiz',
      'fecha': fechaHoy, 'entrada': ts(hoy,8,45), 'salida': null,
      'pausas': [{'inicio': Timestamp.fromDate(ahora.subtract(const Duration(minutes: 8))), 'fin': null}],
      'tipo_horas': 'ordinarias', 'dispositivo_id': 'tablet_demo',
      'creado_at': ts(hoy,8,45), 'es_correccion': false,
      'correccion_de': null, 'motivo_correccion': null, 'corregido_por_uid': null, 'corregido_at': null,
    });

    // Laura — extraordinarias
    await emp.collection('fichajes').add({
      'empleado_id': 'demo_laura_fernandez', 'empleado_nombre': 'Laura Fernández Gil',
      'fecha': fechaHoy, 'entrada': ts(hoy,7,30), 'salida': ts(hoy,19,0),
      'pausas': [{'inicio': ts(hoy,14,0),'fin': ts(hoy,15,0)}],
      'tipo_horas': 'extraordinarias', 'dispositivo_id': 'tablet_demo',
      'creado_at': ts(hoy,7,30), 'es_correccion': false,
      'correccion_de': null, 'motivo_correccion': null, 'corregido_por_uid': null, 'corregido_at': null,
    });

    // Carlos ayer — sin salida + corrección (audit trail)
    final original = await emp.collection('fichajes').add({
      'empleado_id': 'demo_carlos_sanchez', 'empleado_nombre': 'Carlos Sánchez Díaz',
      'fecha': fechaAyer, 'entrada': ts(ayer,9,0), 'salida': null, 'pausas': [],
      'tipo_horas': 'ordinarias', 'dispositivo_id': 'tablet_demo',
      'creado_at': ts(ayer,9,0), 'es_correccion': false,
      'correccion_de': null, 'motivo_correccion': null, 'corregido_por_uid': null, 'corregido_at': null,
    });
    await emp.collection('fichajes').add({
      'empleado_id': 'demo_carlos_sanchez', 'empleado_nombre': 'Carlos Sánchez Díaz',
      'fecha': fechaAyer, 'entrada': ts(ayer,9,0), 'salida': ts(ayer,17,0), 'pausas': [],
      'tipo_horas': 'ordinarias', 'dispositivo_id': 'tablet_demo',
      'creado_at': FieldValue.serverTimestamp(), 'es_correccion': true,
      'correccion_de': original.id, 'motivo_correccion': 'Empleado olvidó fichar la salida',
      'corregido_por_uid': widget.usuarioActualUid, 'corregido_at': FieldValue.serverTimestamp(),
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Fichajes'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _seleccionarFecha, tooltip: 'Cambiar fecha'),
          IconButton(icon: const Icon(Icons.download), onPressed: _mostrarOpcionesExportacion, tooltip: 'Exportar'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFichajePropio,
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.fingerprint, color: Colors.white),
        label: const Text('Fichar ahora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildSelectorFecha(),
          Expanded(
            child: StreamBuilder<List<Fichaje>>(
              stream: _streamFecha(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) return _buildError(snap.error.toString());
                final fichajes = snap.data ?? [];
                if (fichajes.isEmpty) return _buildVacio();
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(child: _buildTabla(fichajes)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    final esIndice = error.contains('index') || error.contains('Index') || error.contains('FAILED_PRECONDITION');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(esIndice ? Icons.storage : Icons.error_outline, size: 56,
              color: esIndice ? Colors.orange : Colors.red),
          const SizedBox(height: 16),
          Text(esIndice ? 'Falta crear el índice en Firestore' : 'Error al cargar fichajes',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          if (esIndice)
            const Text(
              'Firebase Console → Firestore → Indexes\n'
                  'Crea índice compuesto en colección "fichajes":\n\n'
                  '• fecha (Ascending)\n'
                  '• es_correccion (Ascending)\n'
                  '• creado_at (Ascending)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            )
          else
            Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.red)),
        ]),
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _esHoy ? 'No hay fichajes hoy' : 'Sin fichajes el ${DateFormat('dd/MM/yyyy').format(_fecha)}',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          if (_esHoy) ...[
            Text(
              'Pulsa "Fichar ahora" para registrar tu jornada,\n'
                  'o crea datos demo para ver cómo funciona el sistema.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            _creandoDemo
                ? const CircularProgressIndicator()
                : OutlinedButton.icon(
              onPressed: _crearDatosDemo,
              icon: const Icon(Icons.auto_fix_high, color: Color(0xFF7C4DFF)),
              label: const Text('Crear datos de demo', style: TextStyle(color: Color(0xFF7C4DFF))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7C4DFF)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildSelectorFecha() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Colors.blue[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _fecha = _fecha.subtract(const Duration(days: 1)))),
          Text(DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'es_ES').format(_fecha),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.chevron_right),
              onPressed: _esHoy ? null : () => setState(() => _fecha = _fecha.add(const Duration(days: 1)))),
        ],
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context, initialDate: _fecha,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Widget _buildTabla(List<Fichaje> fichajes) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.blue[100]),
      columns: const [
        DataColumn(label: Text('Empleado',   style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Entrada',    style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Pausas',     style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Salida',     style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Total neto', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Estado',     style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Acciones',   style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: fichajes.map((f) {
        final pausasStr = f.pausas.isEmpty
            ? '—'
            : f.pausas.map((p) => '${_formatHora(p.inicio)}-${p.fin != null ? _formatHora(p.fin) : "..."}').join(', ');
        return DataRow(cells: [
          DataCell(Row(children: [
            const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
            const SizedBox(width: 8), Text(f.empleadoNombre),
          ])),
          DataCell(Text(_formatHora(f.entrada))),
          DataCell(SizedBox(width: 160, child: Text(pausasStr, overflow: TextOverflow.ellipsis))),
          DataCell(Text(_formatHora(f.salida))),
          DataCell(Text(_formatDuracion(f.tiempoNeto), style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(_chipEstado(f.estado)),
          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.visibility, size: 20), onPressed: () => _verDetalles(f), tooltip: 'Ver'),
            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _corregirFichaje(f), tooltip: 'Corregir'),
          ])),
        ]);
      }).toList(),
    );
  }

  Widget _chipEstado(EstadoFichaje estado) {
    late Color color; late String texto; late IconData icono;
    switch (estado) {
      case EstadoFichaje.sinFichar:  color = Colors.grey;   texto = 'Sin fichar'; icono = Icons.error_outline; break;
      case EstadoFichaje.trabajando: color = Colors.green;  texto = 'Activo';     icono = Icons.check_circle; break;
      case EstadoFichaje.enPausa:    color = Colors.orange; texto = 'En pausa';   icono = Icons.pause_circle; break;
      case EstadoFichaje.cerrado:    color = Colors.blue;   texto = 'Cerrada';    icono = Icons.done_all; break;
    }
    return Chip(
      avatar: Icon(icono, size: 14, color: color),
      label: Text(texto, style: TextStyle(color: color, fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color, width: 1),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  void _verDetalles(Fichaje f) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(f.empleadoNombre),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _fila('Fecha', f.fecha),
            _fila('Entrada', _formatHora(f.entrada, conSegundos: true)),
            if (f.pausas.isNotEmpty) ...[
              const Divider(),
              const Text('Pausas:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...f.pausas.map((p) {
                final dur = p.duracion != null ? ' (${p.duracion!.inMinutes} min)' : ' (activa)';
                return Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text('• ${_formatHora(p.inicio, conSegundos: true)} — '
                      '${p.fin != null ? _formatHora(p.fin, conSegundos: true) : "en curso"}$dur'),
                );
              }),
            ],
            const Divider(),
            _fila('Salida', _formatHora(f.salida, conSegundos: true)),
            _fila('Total neto', _formatDuracion(f.tiempoNeto)),
            _fila('Tipo', _nombreTipo(f.tipoHoras)),
            _fila('Dispositivo', f.dispositivoId),
            if (f.esCorreccion) ...[
              const Divider(),
              const Text('CORRECCIÓN', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              _fila('Motivo', f.motivoCorreccion ?? '—'),
              _fila('Corregido en', f.corregidoAt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(f.corregidoAt!.toDate()) : '—'),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          if (!f.esCorreccion)
            ElevatedButton.icon(
              onPressed: () { Navigator.pop(ctx); _verHistorialCorrecciones(f); },
              icon: const Icon(Icons.history), label: const Text('Historial'),
            ),
        ],
      ),
    );
  }

  Widget _fila(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 100, child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(valor)),
      ]),
    );
  }

  Future<void> _verHistorialCorrecciones(Fichaje f) async {
    final correcciones = await _service.obtenerHistorialCorrecciones(widget.empresaId, f.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Historial de Correcciones'),
        content: correcciones.isEmpty
            ? const Text('No hay correcciones registradas.')
            : SizedBox(
          width: 420,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: correcciones.length,
            itemBuilder: (_, i) {
              final c = correcciones[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.edit)),
                  title: Text(c.motivoCorreccion ?? 'Sin motivo'),
                  subtitle: Text(c.corregidoAt != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(c.corregidoAt!.toDate()) : '—'),
                  onTap: () => _verDetalles(c),
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  void _corregirFichaje(Fichaje f) {
    final formKey = GlobalKey<FormState>();
    final motivoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) {
          TimeOfDay? nuevaEntrada;
          TimeOfDay? nuevaSalida;
          return AlertDialog(
            title: const Text('Corregir Fichaje'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Empleado: ${f.empleadoNombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                    child: const Text('El fichaje original no se modificará. Se creará un nuevo documento con audit trail.', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: motivoCtrl,
                    decoration: const InputDecoration(labelText: 'Motivo *', border: OutlineInputBorder(), hintText: 'Ej: Olvidó fichar salida'),
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nueva hora de entrada'),
                    trailing: Text(nuevaEntrada != null ? nuevaEntrada!.format(ctx) : _formatHora(f.entrada),
                        style: TextStyle(color: nuevaEntrada != null ? Colors.blue : Colors.grey[600], fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final h = await showTimePicker(context: ctx,
                          initialTime: f.entrada != null ? TimeOfDay.fromDateTime(f.entrada!.toDate()) : TimeOfDay.now());
                      if (h != null) setDS(() => nuevaEntrada = h);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nueva hora de salida'),
                    trailing: Text(nuevaSalida != null ? nuevaSalida!.format(ctx) : _formatHora(f.salida),
                        style: TextStyle(color: nuevaSalida != null ? Colors.blue : Colors.grey[600], fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final h = await showTimePicker(context: ctx,
                          initialTime: f.salida != null ? TimeOfDay.fromDateTime(f.salida!.toDate()) : TimeOfDay.now());
                      if (h != null) setDS(() => nuevaSalida = h);
                    },
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final base = DateTime.parse(f.fecha);
                  final entradaFinal = nuevaEntrada != null
                      ? Timestamp.fromDate(DateTime(base.year, base.month, base.day, nuevaEntrada!.hour, nuevaEntrada!.minute))
                      : f.entrada;
                  final salidaFinal = nuevaSalida != null
                      ? Timestamp.fromDate(DateTime(base.year, base.month, base.day, nuevaSalida!.hour, nuevaSalida!.minute))
                      : f.salida;
                  try {
                    await _service.corregirFichaje(
                      empresaId: widget.empresaId, fichajeOriginalId: f.id,
                      motivo: motivoCtrl.text.trim(), corregidoPorUid: widget.usuarioActualUid,
                      nuevaEntrada: entradaFinal, nuevaSalida: salidaFinal, nuevasPausas: f.pausas,
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Corrección guardada'), backgroundColor: Colors.green));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarOpcionesExportacion() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.table_chart), title: const Text('Exportar día a CSV'),
              onTap: () { Navigator.pop(ctx); _exportarCSV(); }),
          ListTile(leading: const Icon(Icons.date_range), title: const Text('Exportar rango a CSV'),
              onTap: () { Navigator.pop(ctx); _exportarCSVRango(); }),
        ]),
      ),
    );
  }

  Future<void> _exportarCSV() async {
    try {
      final csv = await _service.exportarCsvInspeccion(empresaId: widget.empresaId, desde: _fecha, hasta: _fecha);
      if (!mounted) return;
      _mostrarCSV(csv, _fechaKey);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportarCSVRango() async {
    final rango = await showDateRangePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fecha.subtract(const Duration(days: 7)), end: _fecha),
      locale: const Locale('es', 'ES'),
    );
    if (rango == null || !mounted) return;
    try {
      final csv = await _service.exportarCsvInspeccion(empresaId: widget.empresaId, desde: rango.start, hasta: rango.end);
      if (!mounted) return;
      _mostrarCSV(csv, '${DateFormat('yyyy-MM-dd').format(rango.start)}_${DateFormat('yyyy-MM-dd').format(rango.end)}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _mostrarCSV(String csv, String nombre) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('fichajes_$nombre.csv'),
        content: SingleChildScrollView(child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }
}