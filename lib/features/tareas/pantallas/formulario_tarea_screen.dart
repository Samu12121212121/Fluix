import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:planeag_flutter/domain/modelos/tarea.dart';
import 'package:planeag_flutter/domain/modelos/recurrencia_config.dart';
import 'package:planeag_flutter/services/tareas_service.dart';
import '../widgets/recurrencia_config_widget.dart';
import '../widgets/cliente_vinculado_widget.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar tarea' : 'Nueva tarea'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Guardar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _seccionCard('Información básica', [
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(
                    labelText: 'Título *',
                    prefixIcon: Icon(Icons.title)),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El título es obligatorio'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true),
                maxLines: 3,
              ),
            ]),
            const SizedBox(height: 12),
            _seccionCard('Clasificación', [
              _selectorEnum<TipoTarea>(
                  'Tipo', Icons.category, _tipo, TipoTarea.values,
                  _nombreTipo, (v) => setState(() => _tipo = v)),
              const SizedBox(height: 12),
              _selectorEnum<PrioridadTarea>(
                  'Prioridad', Icons.flag, _prioridad, PrioridadTarea.values,
                  _nombrePrioridad, (v) => setState(() => _prioridad = v)),
            ]),
            const SizedBox(height: 12),
            _seccionCard('Tiempo y ubicación', [
              ListTile(
                leading: Icon(Icons.schedule,
                    color: _fechaLimite != null
                        ? const Color(0xFF1976D2)
                        : Colors.grey),
                title: Text(_fechaLimite != null
                    ? 'Vence: ${DateFormat('dd/MM/yyyy HH:mm').format(_fechaLimite!)}'
                    : 'Sin fecha límite'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                        onPressed: _seleccionarFecha,
                        child: const Text('Elegir')),
                    if (_fechaLimite != null)
                      IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(() => _fechaLimite = null)),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
              ),
              TextFormField(
                controller: _ubicCtrl,
                decoration: const InputDecoration(
                    labelText: 'Ubicación (opcional)',
                    prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _tiempoEstimado?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Tiempo estimado (minutos)',
                  prefixIcon: Icon(Icons.hourglass_empty),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onEditingComplete: () => FocusScope.of(context).unfocus(),
                onChanged: (v) => _tiempoEstimado = int.tryParse(v),
              ),
            ]),
            const SizedBox(height: 12),
            // ── RECORDATORIO ──────────────────────────────────────────────
            if (_fechaLimite != null)
              _seccionCard('Recordatorio', [
                DropdownButtonFormField<TipoRecordatorio>(
                  value: _tipoRecordatorio,
                  decoration: const InputDecoration(
                    labelText: 'Recordarme',
                    prefixIcon: Icon(Icons.alarm),
                    isDense: true,
                  ),
                  items: TipoRecordatorio.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.etiqueta),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _tipoRecordatorio = v ?? TipoRecordatorio.ninguno),
                ),
                if (_tipoRecordatorio == TipoRecordatorio.personalizado) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, size: 18),
                    title: Text(
                      _fechaRecordatorioPersonalizada != null
                          ? DateFormat('dd/MM/yyyy HH:mm')
                              .format(_fechaRecordatorioPersonalizada!)
                          : 'Seleccionar fecha',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: TextButton(
                      onPressed: _seleccionarFechaRecordatorio,
                      child: const Text('Elegir'),
                    ),
                  ),
                ],
              ]),
            const SizedBox(height: 12),
            // ── RECURRENCIA ───────────────────────────────────────────────
            _seccionCard('Recurrencia', [
              RecurrenciaConfigWidget(
                config: _configuracionRecurrencia,
                onChanged: (c) =>
                    setState(() => _configuracionRecurrencia = c),
              ),
            ]),
            const SizedBox(height: 12),
            // ── CLIENTE VINCULADO ─────────────────────────────────────────
            _seccionCard('Cliente vinculado', [
              SelectorClienteWidget(
                empresaId: widget.empresaId,
                clienteIdSeleccionado: _clienteId,
                onChanged: (id) => setState(() => _clienteId = id),
              ),
            ]),
            const SizedBox(height: 12),
            // ── SUBTAREAS ─────────────────────────────────────────────────
            _seccionCard('Checklist / Subtareas', [
              ..._subtareas.asMap().entries.map((e) => ListTile(
                    leading: Checkbox(
                      value: e.value.completada,
                      onChanged: (v) => setState(() {
                        _subtareas[e.key] = Subtarea(
                          id: e.value.id,
                          titulo: e.value.titulo,
                          completada: v ?? false,
                        );
                      }),
                      activeColor: const Color(0xFF4CAF50),
                    ),
                    title: Text(e.value.titulo),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: () =>
                          setState(() => _subtareas.removeAt(e.key)),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtareaCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Añadir subtarea...', isDense: true),
                      onSubmitted: (_) => _agregarSubtarea(),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.add,
                          color: Color(0xFF1976D2)),
                      onPressed: _agregarSubtarea),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            _seccionCard('Etiquetas', [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._etiquetas.map((e) => Chip(
                        label: Text(e),
                        onDeleted: () =>
                            setState(() => _etiquetas.remove(e)),
                        backgroundColor:
                            const Color(0xFF1976D2).withValues(alpha: 0.1),
                        deleteIconColor: const Color(0xFF1976D2),
                        labelStyle:
                            const TextStyle(color: Color(0xFF1976D2)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      )),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _etiquetaCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Nueva etiqueta...', isDense: true),
                      onSubmitted: (_) => _agregarEtiqueta(),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.add,
                          color: Color(0xFF1976D2)),
                      onPressed: _agregarEtiqueta),
                ],
              ),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── HELPERS DE CONSTRUCCIÓN ──────────────────────────────────────────────

  Widget _seccionCard(String titulo, List<Widget> children) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1976D2))),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _selectorEnum<T>(
    String label,
    IconData icono,
    T valor,
    List<T> opciones,
    String Function(T) nombre,
    void Function(T) onChange,
  ) {
    return DropdownButtonFormField<T>(
      value: valor,
      decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icono)),
      items: opciones
          .map((o) =>
              DropdownMenuItem(value: o, child: Text(nombre(o))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChange(v);
      },
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

  Future<void> _seleccionarFechaRecordatorio() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate:
          _fechaRecordatorioPersonalizada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: _fechaLimite ??
          DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha == null || !mounted) return;
    final hora =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (hora == null || !mounted) return;
    setState(() {
      _fechaRecordatorioPersonalizada = DateTime(
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  String _nombreTipo(TipoTarea t) => switch (t) {
        TipoTarea.normal     => 'Normal',
        TipoTarea.checklist  => 'Checklist',
        TipoTarea.incidencia => 'Incidencia',
        TipoTarea.proyecto   => 'Proyecto',
      };

  String _nombrePrioridad(PrioridadTarea p) => switch (p) {
        PrioridadTarea.urgente => '🔴 Urgente',
        PrioridadTarea.alta    => '🟠 Alta',
        PrioridadTarea.media   => '🔵 Media',
        PrioridadTarea.baja    => '⚪ Baja',
      };
}

