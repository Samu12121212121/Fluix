import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:planeag_flutter/domain/modelos/tarea.dart';
import 'package:planeag_flutter/domain/modelos/recurrencia_config.dart';
import 'package:planeag_flutter/services/tareas_service.dart';
import '../widgets/recurrencia_config_widget.dart';
import '../widgets/cliente_vinculado_widget.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';

class FormularioTareaScreen extends StatefulWidget {
  final String empresaId;
  final String usuarioId;
  final Tarea? tareaEditar;
  /// Si se pasa, el cliente queda vinculado automáticamente.
  final String? clienteIdPreseleccionado;

  const FormularioTareaScreen({
    super.key,
    required this.empresaId,
    required this.usuarioId,
    this.tareaEditar,
    this.clienteIdPreseleccionado,
  });

  @override
  State<FormularioTareaScreen> createState() => _FormularioTareaScreenState();
}

class _FormularioTareaScreenState extends State<FormularioTareaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _ubicCtrl = TextEditingController();
  final _subtareaCtrl = TextEditingController();
  final _etiquetaCtrl = TextEditingController();
  final TareasService _svc = TareasService();
  final _uuid = const Uuid();

  TipoTarea _tipo = TipoTarea.normal;
  PrioridadTarea _prioridad = PrioridadTarea.media;
  DateTime? _fechaLimite;
  int? _tiempoEstimado;
  List<Subtarea> _subtareas = [];
  List<String> _etiquetas = [];
  bool _guardando = false;

  // Nuevos campos
  String? _clienteId;
  ConfiguracionRecurrencia? _configuracionRecurrencia;
  TipoRecordatorio _tipoRecordatorio = TipoRecordatorio.ninguno;
  DateTime? _fechaRecordatorioPersonalizada;

  bool get _esEdicion => widget.tareaEditar != null;

  @override
  void initState() {
    super.initState();
    _clienteId = widget.clienteIdPreseleccionado;
    if (_esEdicion) {
      final t = widget.tareaEditar!;
      _tituloCtrl.text = t.titulo;
      _descCtrl.text = t.descripcion ?? '';
      _ubicCtrl.text = t.ubicacion ?? '';
      _tipo = t.tipo;
      _prioridad = t.prioridad;
      _fechaLimite = t.fechaLimite;
      _tiempoEstimado = t.tiempoEstimadoMin;
      _subtareas = List.from(t.subtareas);
      _etiquetas = List.from(t.etiquetas);
      _clienteId = t.clienteId;
      _configuracionRecurrencia = t.configuracionRecurrencia;
      if (t.recordatorio != null) {
        _tipoRecordatorio = t.recordatorio!.tipo;
        _fechaRecordatorioPersonalizada =
            t.recordatorio!.fechaPersonalizada;
      }
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _ubicCtrl.dispose();
    _subtareaCtrl.dispose();
    _etiquetaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3B82F6);
    const bg     = Color(0xFFF1F5F9);
    const cardBg = Colors.white;
    const border = Color(0xFFE5E7EB);
    const textC  = Color(0xFF1F2937);
    const subC   = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        // ── Header estilo dashboard ─────────────────────────────────────────
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16, right: 16, bottom: 14,
          ),
          decoration: const BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded, size: 17, color: subC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_esEdicion ? 'Editar tarea' : 'Nueva tarea',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textC)),
              Text(_esEdicion ? 'Modifica los datos de la tarea' : 'Crea una nueva tarea para tu equipo',
                  style: const TextStyle(fontSize: 11, color: subC)),
            ])),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _guardando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        // ── Contenido ───────────────────────────────────────────────────────
        Expanded(child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Título y descripción (sin card, inline)
              _dsCard(children: [
                _dsLabel('Título de la tarea *', Icons.task_alt_rounded, accent),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tituloCtrl,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textC),
                  decoration: InputDecoration(
                    hintText: 'Ej: Preparar informe mensual...',
                    hintStyle: const TextStyle(color: subC, fontWeight: FontWeight.normal),
                    filled: true, fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: accent, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'El título es obligatorio' : null,
                ),
                const SizedBox(height: 12),
                _dsLabel('Descripción', Icons.notes_rounded, subC),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, color: textC),
                  decoration: InputDecoration(
                    hintText: 'Describe qué hay que hacer...',
                    hintStyle: const TextStyle(color: subC),
                    filled: true, fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: accent, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Clasificación: Tipo + Prioridad en fila
              _dsCard(children: [
                _dsLabel('Clasificación', Icons.label_outline_rounded, accent),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tipo', style: TextStyle(fontSize: 11, color: subC)),
                    const SizedBox(height: 4),
                    _dsDropdown<TipoTarea>(_tipo, TipoTarea.values, _nombreTipo,
                        (v) => setState(() => _tipo = v), border, textC),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Prioridad', style: TextStyle(fontSize: 11, color: subC)),
                    const SizedBox(height: 4),
                    _dsPrioridadSelector(),
                  ])),
                ]),
              ]),
              const SizedBox(height: 12),

              // Fecha límite
              _dsCard(children: [
                _dsLabel('Fecha límite', Icons.schedule_rounded, accent),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _seleccionarFecha,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: _fechaLimite != null
                          ? accent.withValues(alpha: 0.06)
                          : const Color(0xFFF9FAFB),
                      border: Border.all(color: _fechaLimite != null ? accent.withValues(alpha: 0.3) : border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_outlined, size: 16,
                          color: _fechaLimite != null ? accent : subC),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        _fechaLimite != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(_fechaLimite!)
                            : 'Sin fecha límite — toca para establecer',
                        style: TextStyle(fontSize: 13,
                            color: _fechaLimite != null ? textC : subC),
                      )),
                      if (_fechaLimite != null)
                        GestureDetector(
                          onTap: () => setState(() => _fechaLimite = null),
                          child: const Icon(Icons.close_rounded, size: 16, color: subC),
                        ),
                    ]),
                  ),
                ),
                if (_fechaLimite != null) ...[
                  const SizedBox(height: 12),
                  const Text('Recordatorio', style: TextStyle(fontSize: 11, color: subC)),
                  const SizedBox(height: 4),
                  _dsDropdown<TipoRecordatorio>(_tipoRecordatorio, TipoRecordatorio.values,
                      (t) => t.etiqueta, (v) => setState(() => _tipoRecordatorio = v), border, textC),
                ],
              ]),
              const SizedBox(height: 12),

              // Tiempo estimado + ubicación
              _dsCard(children: [
                _dsLabel('Detalles adicionales', Icons.tune_rounded, accent),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tiempo estimado (min)', style: TextStyle(fontSize: 11, color: subC)),
                    const SizedBox(height: 4),
                    TextFormField(
                      initialValue: _tiempoEstimado?.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _tiempoEstimado = int.tryParse(v),
                      decoration: InputDecoration(
                        hintText: 'ej. 60',
                        filled: true, fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: accent, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ubicación (opcional)', style: TextStyle(fontSize: 11, color: subC)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _ubicCtrl,
                      decoration: InputDecoration(
                        hintText: 'Oficina, remoto...',
                        filled: true, fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: accent, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ])),
                ]),
              ]),
              const SizedBox(height: 12),

              // Checklist / Subtareas
              _dsCard(children: [
                _dsLabel('Checklist', Icons.checklist_rounded, accent),
                const SizedBox(height: 8),
                ..._subtareas.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Checkbox(
                      value: e.value.completada,
                      onChanged: (v) => setState(() {
                        _subtareas[e.key] = Subtarea(
                            id: e.value.id, titulo: e.value.titulo, completada: v ?? false);
                      }),
                      activeColor: const Color(0xFF22C55E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Expanded(child: Text(e.value.titulo,
                        style: TextStyle(fontSize: 13, color: textC,
                            decoration: e.value.completada ? TextDecoration.lineThrough : null))),
                    GestureDetector(
                      onTap: () => setState(() => _subtareas.removeAt(e.key)),
                      child: const Icon(Icons.close_rounded, size: 15, color: subC),
                    ),
                  ]),
                )),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _subtareaCtrl,
                    decoration: InputDecoration(
                      hintText: 'Añadir paso...',
                      hintStyle: const TextStyle(color: subC, fontSize: 12),
                      filled: true, fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _agregarSubtarea(),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _agregarSubtarea,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF3B82F6)),
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),

              // Etiquetas
              _dsCard(children: [
                _dsLabel('Etiquetas', Icons.local_offer_outlined, accent),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ..._etiquetas.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(e, style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600)),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () => setState(() => _etiquetas.remove(e)),
                        child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFF3B82F6)),
                      ),
                    ]),
                  )),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _etiquetaCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nueva etiqueta...',
                      hintStyle: const TextStyle(color: subC, fontSize: 12),
                      filled: true, fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _agregarEtiqueta(),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _agregarEtiqueta,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF3B82F6)),
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),

              // Cliente vinculado
              _dsCard(children: [
                _dsLabel('Cliente vinculado', Icons.person_outline_rounded, accent),
                const SizedBox(height: 10),
                SelectorClienteWidget(
                  empresaId: widget.empresaId,
                  clienteIdSeleccionado: _clienteId,
                  onChanged: (id) => setState(() => _clienteId = id),
                ),
              ]),
              const SizedBox(height: 12),

              // Recurrencia
              _dsCard(children: [
                _dsLabel('Recurrencia', Icons.repeat_rounded, accent),
                const SizedBox(height: 10),
                RecurrenciaConfigWidget(
                  config: _configuracionRecurrencia,
                  onChanged: (c) => setState(() => _configuracionRecurrencia = c),
                ),
              ]),
              const SizedBox(height: 80),
            ],
          ),
        )),
      ]),
    );
  }

  // ── Dashboard-style helpers ─────────────────────────────────────────────────

  Widget _dsCard({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 4, offset: const Offset(0, 1))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _dsLabel(String label, IconData icon, Color color) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: color)),
  ]);

  Widget _dsDropdown<T>(T value, List<T> options, String Function(T) label,
      void Function(T) onChange, Color border, Color textC) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: TextStyle(fontSize: 13, color: textC),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(label(o)))).toList(),
      onChanged: (v) { if (v != null) onChange(v); },
    );
  }

  Widget _dsPrioridadSelector() {
    const options = [
      (PrioridadTarea.urgente, 'Urgente', Color(0xFFDC2626)),
      (PrioridadTarea.alta,    'Alta',    Color(0xFFEF4444)),
      (PrioridadTarea.media,   'Media',   Color(0xFFF59E0B)),
      (PrioridadTarea.baja,    'Baja',    Color(0xFF94A3B8)),
    ];
    return DropdownButtonFormField<PrioridadTarea>(
      value: _prioridad,
      decoration: const InputDecoration(
        filled: true, fillColor: Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      items: options.map((o) => DropdownMenuItem(
        value: o.$1,
        child: Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: o.$3, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(o.$2, style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937))),
        ]),
      )).toList(),
      onChanged: (v) { if (v != null) setState(() => _prioridad = v); },
    );
  }

  void _agregarSubtarea() {
    final texto = _subtareaCtrl.text.trim();
    if (texto.isEmpty) return;
    setState(() {
      _subtareas.add(Subtarea(id: _uuid.v4(), titulo: texto));
      _subtareaCtrl.clear();
    });
  }

  void _agregarEtiqueta() {
    final texto = _etiquetaCtrl.text.trim();
    if (texto.isEmpty || _etiquetas.contains(texto)) return;
    setState(() {
      _etiquetas.add(texto);
      _etiquetaCtrl.clear();
    });
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate:
          _fechaLimite ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha == null || !mounted) return;
    final hora =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (hora == null || !mounted) return;
    setState(() {
      _fechaLimite = DateTime(
          fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    });
  }

  // ── GUARDAR ──────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    // Construir recordatorio
    RecordatorioTarea? recordatorio;
    if (_tipoRecordatorio != TipoRecordatorio.ninguno &&
        _fechaLimite != null) {
      recordatorio = RecordatorioTarea(
        tipo: _tipoRecordatorio,
        fechaPersonalizada: _tipoRecordatorio == TipoRecordatorio.personalizado
            ? _fechaRecordatorioPersonalizada
            : null,
      );
    }

    try {
      if (_esEdicion) {
        await _svc.actualizarTarea(
          widget.empresaId,
          widget.tareaEditar!.id,
          {
            'titulo': _tituloCtrl.text.trim(),
            'descripcion': _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            'tipo': _tipo.name,
            'prioridad': _prioridad.name,
            'fecha_limite': _fechaLimite?.toIso8601String(),
            'ubicacion': _ubicCtrl.text.trim().isEmpty
                ? null
                : _ubicCtrl.text.trim(),
            'tiempo_estimado_min': _tiempoEstimado,
            'subtareas': _subtareas.map((s) => s.toMap()).toList(),
            'etiquetas': _etiquetas,
            'cliente_id': _clienteId,
            'configuracion_recurrencia':
                _configuracionRecurrencia?.toMap(),
            'es_recurrente': _configuracionRecurrencia != null,
            'es_plantilla_recurrencia':
                _configuracionRecurrencia != null,
            'recordatorio': recordatorio?.toMap(),
          },
          widget.usuarioId,
          'Tarea actualizada',
        );
      } else {
        await _svc.crearTarea(
          empresaId: widget.empresaId,
          titulo: _tituloCtrl.text.trim(),
          creadoPorId: widget.usuarioId,
          tipo: _tipo,
          prioridad: _prioridad,
          descripcion: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          fechaLimite: _fechaLimite,
          ubicacion: _ubicCtrl.text.trim().isEmpty
              ? null
              : _ubicCtrl.text.trim(),
          tiempoEstimadoMin: _tiempoEstimado,
          subtareas: _subtareas,
          etiquetas: _etiquetas,
          clienteId: _clienteId,
          configuracionRecurrencia: _configuracionRecurrencia,
          esPlantillaRecurrencia: _configuracionRecurrencia != null,
          recordatorio: recordatorio,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _guardando = false);
      FluxToast.error(context, 'Error: $e');
    }
  }

  String _nombreTipo(TipoTarea t) => switch (t) {
        TipoTarea.normal     => 'Normal',
        TipoTarea.checklist  => 'Checklist',
        TipoTarea.incidencia => 'Incidencia',
        TipoTarea.proyecto   => 'Proyecto',
      };

}

