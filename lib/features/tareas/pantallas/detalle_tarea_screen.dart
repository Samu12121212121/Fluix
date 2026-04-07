import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/domain/modelos/tarea.dart';
import 'package:planeag_flutter/domain/modelos/recurrencia_config.dart';
import 'package:planeag_flutter/services/tareas_service.dart';
import 'package:planeag_flutter/features/tareas/pantallas/formulario_tarea_screen.dart';
import 'package:planeag_flutter/services/recurrencia_service.dart';
import '../widgets/cronometro_tarea_widget.dart';
import '../widgets/adjuntos_grid_widget.dart';
import '../widgets/cliente_vinculado_widget.dart';

class DetalleTareaScreen extends StatefulWidget {
  final Tarea tarea;
  final String empresaId;
  final String usuarioId;
  const DetalleTareaScreen({
    super.key,
    required this.tarea,
    required this.empresaId,
    required this.usuarioId,
  });

  @override
  State<DetalleTareaScreen> createState() => _DetalleTareaScreenState();
}

class _DetalleTareaScreenState extends State<DetalleTareaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final TareasService _svc = TareasService();
  final RecurrenciaService _recSvc = RecurrenciaService();
  final TextEditingController _mensajeCtrl = TextEditingController();
  late Tarea _tarea;
  final TextEditingController _subtareaCtrl = TextEditingController();
  bool _agregandoSubtarea = false;

  @override
  void initState() {
    super.initState();
    _tarea = widget.tarea;
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _mensajeCtrl.dispose();
    _subtareaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tarea>>(
      stream: _svc.tareasStream(widget.empresaId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final actualizada =
              snapshot.data!.where((t) => t.id == _tarea.id).firstOrNull;
          if (actualizada != null) _tarea = actualizada;
        }
        return _buildScaffold();
      },
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_tarea.titulo,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          // Iconos de recurrencia / cliente
          if (_tarea.configuracionRecurrencia != null)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.repeat, color: Colors.white70, size: 20),
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => FormularioTareaScreen(
                          empresaId: widget.empresaId,
                          usuarioId: widget.usuarioId,
                          tareaEditar: _tarea,
                        ))),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Detalle'),
            Tab(icon: Icon(Icons.attach_file, size: 18), text: 'Adjuntos'),
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Chat'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildTabDetalle(),
          _buildTabAdjuntos(),
          _buildTabChat(),
          _buildTabHistorial(),
        ],
      ),
    );
  }

  // ── TAB DETALLE ──────────────────────────────────────────────────────────

  Widget _buildTabDetalle() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardEstadoPrioridad(),
          const SizedBox(height: 12),
          // Cliente vinculado
          if (_tarea.clienteId != null) ...[
            _cardClienteVinculado(),
            const SizedBox(height: 12),
          ],
          // Badge recurrencia
          if (_tarea.configuracionRecurrencia != null) ...[
            _cardRecurrencia(),
            const SizedBox(height: 12),
          ],
          // Cronómetro mejorado
          CronometroTareaWidget(
            empresaId: widget.empresaId,
            tareaId: _tarea.id,
            usuarioId: widget.usuarioId,
          ),
          const SizedBox(height: 12),
          _cardInfoGeneral(),
          const SizedBox(height: 12),
          if (_tarea.subtareas.isNotEmpty) ...[
            _cardSubtareas(),
            const SizedBox(height: 12),
          ],
          if (_tarea.etiquetas.isNotEmpty) ...[
            _cardEtiquetas(),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _cardClienteVinculado() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.person, color: Color(0xFF00796B)),
            const SizedBox(width: 8),
            const Text('Cliente:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            ClienteVinculadoWidget(
              empresaId: widget.empresaId,
              clienteId: _tarea.clienteId!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardRecurrencia() {
    final config = _tarea.configuracionRecurrencia!;
    final pausada = config.pausada;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.repeat,
                color: pausada ? Colors.grey : const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pausada ? 'Recurrente (pausada)' : 'Tarea recurrente',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: pausada ? Colors.grey : const Color(0xFF1976D2),
                    ),
                  ),
                  Text(
                    'Cada ${_nombreFrecuencia(config.frecuencia)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (_tarea.proximaFechaRecurrencia != null)
                    Text(
                      'Próxima: ${DateFormat('dd/MM/yyyy').format(_tarea.proximaFechaRecurrencia!)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF1976D2)),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'pausar') {
                  await _recSvc.pausarRecurrencia(
                      widget.empresaId, _tarea.id);
                } else if (v == 'reanudar') {
                  await _recSvc.reanudarRecurrencia(
                      widget.empresaId, _tarea.id);
                } else if (v == 'cancelar') {
                  await _recSvc.cancelarRecurrencia(
                      widget.empresaId, _tarea.id);
                }
              },
              itemBuilder: (_) => [
                if (!pausada)
                  const PopupMenuItem(
                      value: 'pausar',
                      child: ListTile(
                          leading: Icon(Icons.pause),
                          title: Text('Pausar recurrencia'))),
                if (pausada)
                  const PopupMenuItem(
                      value: 'reanudar',
                      child: ListTile(
                          leading: Icon(Icons.play_arrow),
                          title: Text('Reanudar recurrencia'))),
                const PopupMenuItem(
                    value: 'cancelar',
                    child: ListTile(
                        leading: Icon(Icons.cancel, color: Colors.red),
                        title: Text('Cancelar recurrencia'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardEstadoPrioridad() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Estado',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey)),
                const Spacer(),
                _selectorEstado(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Prioridad',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey)),
                const Spacer(),
                _badgePrioridad(_tarea.prioridad),
              ],
            ),
            if (_tarea.fechaLimite != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.schedule,
                      size: 16,
                      color: _tarea.estaAtrasada
                          ? Colors.red
                          : Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Vence: ${DateFormat('dd/MM/yyyy HH:mm').format(_tarea.fechaLimite!)}',
                    style: TextStyle(
                      color: _tarea.estaAtrasada
                          ? Colors.red
                          : Colors.grey[700],
                      fontWeight: _tarea.estaAtrasada
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (_tarea.estaAtrasada) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('ATRASADA',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectorEstado() {
    return DropdownButton<EstadoTarea>(
      value: _tarea.estado,
      isDense: true,
      underline: const SizedBox(),
      items: EstadoTarea.values.map((e) => DropdownMenuItem(
            value: e,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _colorEstado(e).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_nombreEstado(e),
                  style: TextStyle(
                      color: _colorEstado(e),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          )).toList(),
      onChanged: (nuevo) async {
        if (nuevo == null) return;
        await _svc.cambiarEstado(
            widget.empresaId, _tarea.id, nuevo, widget.usuarioId);

        // Si se completó y es recurrente, mostrar snackbar con próxima fecha
        if (nuevo == EstadoTarea.completada &&
            _tarea.configuracionRecurrencia != null &&
            !_tarea.configuracionRecurrencia!.pausada) {
          final recSvc = RecurrenciaService();
          final proxima = recSvc.calcularProximaFecha(
              _tarea.configuracionRecurrencia!, DateTime.now());
          if (proxima != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ Tarea completada. La siguiente se creará el '
                  '${DateFormat('dd/MM/yyyy').format(proxima)}',
                ),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 5),
              ),
            );
            // Generar la instancia
            await recSvc.crearInstanciaDesde(
              plantilla: _tarea.esPlantillaRecurrencia
                  ? _tarea
                  : _tarea, // usar la tarea actual como referencia
              fechaLimite: proxima,
              generadoPorId: widget.usuarioId,
            );
          }
        }
      },
    );
  }

  Widget _cardInfoGeneral() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Información',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Divider(height: 20),
            if (_tarea.descripcion != null) ...[
              Text(_tarea.descripcion!,
                  style: const TextStyle(height: 1.5)),
              const SizedBox(height: 12),
            ],
            _filaInfo(Icons.category, 'Tipo', _nombreTipo(_tarea.tipo)),
            if (_tarea.ubicacion != null)
              _filaInfo(
                  Icons.location_on, 'Ubicación', _tarea.ubicacion!),
            if (_tarea.tiempoEstimadoMin != null)
              _filaInfo(Icons.hourglass_empty, 'Estimado',
                  '${_tarea.tiempoEstimadoMin} min'),
            _filaInfo(
                Icons.calendar_today,
                'Creada',
                DateFormat('dd/MM/yyyy').format(_tarea.fechaCreacion)),
            // Recordatorio
            if (_tarea.recordatorio != null &&
                _tarea.recordatorio!.tipo != TipoRecordatorio.ninguno)
              _filaInfo(
                  Icons.alarm,
                  'Recordatorio',
                  _tarea.recordatorio!.tipo.etiqueta),
          ],
        ),
      ),
    );
  }

  Widget _filaInfo(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icono, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const Spacer(),
          Text(valor,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _cardSubtareas() {
    final subtareas = List<Subtarea>.from(_tarea.subtareas);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Text(
                    'Checklist (${_tarea.subtareasCompletadas}/${subtareas.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: subtareas.isEmpty
                  ? 0
                  : _tarea.subtareasCompletadas / subtareas.length,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
              minHeight: 6,
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subtareas.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = subtareas.removeAt(oldIndex);
                subtareas.insert(newIndex, item);
                _svc.actualizarSubtareas(
                    widget.empresaId, _tarea.id, subtareas);
              },
              itemBuilder: (context, index) {
                final sub = subtareas[index];
                return Padding(
                  key: ValueKey(sub.id),
                  padding: EdgeInsets.zero,
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator,
                          color: Colors.grey, size: 20),
                      Checkbox(
                        value: sub.completada,
                        activeColor: const Color(0xFF4CAF50),
                        onChanged: (val) {
                          subtareas[index] = Subtarea(
                            id: sub.id,
                            titulo: sub.titulo,
                            completada: val ?? false,
                          );
                          _svc.actualizarSubtareas(
                              widget.empresaId, _tarea.id, subtareas);
                        },
                      ),
                      Expanded(
                        child: Text(
                          sub.titulo,
                          style: TextStyle(
                            decoration: sub.completada
                                ? TextDecoration.lineThrough
                                : null,
                            color: sub.completada
                                ? Colors.grey
                                : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.grey),
                        onPressed: () {
                          subtareas.removeAt(index);
                          _svc.actualizarSubtareas(
                              widget.empresaId, _tarea.id, subtareas);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_agregandoSubtarea)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subtareaCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Nueva subtarea...',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 0, vertical: 8),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _agregarSubtarea(),
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.check, color: Color(0xFF4CAF50)),
                      onPressed: _agregarSubtarea,
                    ),
                  ],
                ),
              )
            else
              TextButton.icon(
                onPressed: () =>
                    setState(() => _agregandoSubtarea = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir elemento'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 0, vertical: 8),
                  alignment: Alignment.centerLeft,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _agregarSubtarea() {
    final titulo = _subtareaCtrl.text.trim();
    if (titulo.isEmpty) {
      setState(() => _agregandoSubtarea = false);
      return;
    }
    final nueva = Subtarea(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      titulo: titulo,
      completada: false,
    );
    final nuevas = [..._tarea.subtareas, nueva];
    _svc.actualizarSubtareas(widget.empresaId, _tarea.id, nuevas);
    _subtareaCtrl.clear();
  }

  Widget _cardEtiquetas() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Etiquetas',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tarea.etiquetas
                  .map((e) => Chip(
                        label: Text(e,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: const Color(0xFF1976D2)
                            .withValues(alpha: 0.1),
                        side: const BorderSide(color: Color(0xFF1976D2)),
                        labelStyle: const TextStyle(
                            color: Color(0xFF1976D2)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB ADJUNTOS ─────────────────────────────────────────────────────────

  Widget _buildTabAdjuntos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AdjuntosGridWidget(
            empresaId: widget.empresaId,
            tareaId: _tarea.id,
            usuarioId: widget.usuarioId,
          ),
        ),
      ),
    );
  }

  // ── TAB CHAT ─────────────────────────────────────────────────────────────

  Widget _buildTabChat() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: _svc.mensajesTareaStream(widget.empresaId, _tarea.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Sin mensajes',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d =
                      docs[i].data() as Map<String, dynamic>;
                  final esMio = d['usuario_id'] == widget.usuarioId;
                  return _burbujaMensaje(d, esMio);
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mensajeCtrl,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    isDense: true,
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF1976D2),
                child: IconButton(
                  icon: const Icon(Icons.send,
                      color: Colors.white, size: 18),
                  onPressed: _enviarMensaje,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _burbujaMensaje(Map<String, dynamic> data, bool esMio) {
    return Align(
      alignment:
          esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: esMio ? const Color(0xFF1976D2) : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!esMio)
              Text(data['nombre_usuario'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF1976D2))),
            Text(data['texto'] ?? '',
                style: TextStyle(
                    color:
                        esMio ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  void _enviarMensaje() {
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty) return;
    _svc.enviarMensaje(
      empresaId: widget.empresaId,
      tareaId: _tarea.id,
      usuarioId: widget.usuarioId,
      nombreUsuario: 'Yo',
      texto: texto,
    );
    _mensajeCtrl.clear();
  }

  // ── TAB HISTORIAL ────────────────────────────────────────────────────────

  Widget _buildTabHistorial() {
    final historial = _tarea.historial.reversed.toList();
    if (historial.isEmpty) {
      return Center(
          child: Text('Sin historial',
              style: TextStyle(color: Colors.grey[500])));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: historial.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final h = historial[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: Color(0xFF1976D2),
                      shape: BoxShape.circle),
                ),
                if (i < historial.length - 1)
                  Container(
                      width: 2,
                      height: 36,
                      color: Colors.grey[300]),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.descripcion,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    Text(
                        DateFormat('dd/MM/yyyy HH:mm')
                            .format(h.fecha),
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  Widget _badgePrioridad(PrioridadTarea p) {
    final (color, label) = switch (p) {
      PrioridadTarea.urgente => (Colors.red, '🔴 Urgente'),
      PrioridadTarea.alta    => (Colors.orange, '🟠 Alta'),
      PrioridadTarea.media   => (Colors.blue, '🔵 Media'),
      PrioridadTarea.baja    => (Colors.grey, '⚪ Baja'),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600)),
    );
  }

  Color _colorEstado(EstadoTarea e) => switch (e) {
        EstadoTarea.pendiente   => Colors.orange,
        EstadoTarea.enProgreso  => Colors.blue,
        EstadoTarea.enRevision  => Colors.purple,
        EstadoTarea.completada  => Colors.green,
        EstadoTarea.cancelada   => Colors.grey,
      };

  String _nombreEstado(EstadoTarea e) => switch (e) {
        EstadoTarea.pendiente   => 'Pendiente',
        EstadoTarea.enProgreso  => 'En Progreso',
        EstadoTarea.enRevision  => 'En Revisión',
        EstadoTarea.completada  => 'Completada',
        EstadoTarea.cancelada   => 'Cancelada',
      };

  String _nombreTipo(TipoTarea t) => switch (t) {
        TipoTarea.normal     => 'Normal',
        TipoTarea.checklist  => 'Checklist',
        TipoTarea.incidencia => 'Incidencia',
        TipoTarea.proyecto   => 'Proyecto',
      };

  String _nombreFrecuencia(FrecuenciaRecurrencia f) => switch (f) {
        FrecuenciaRecurrencia.diaria    => 'día',
        FrecuenciaRecurrencia.semanal   => 'semana',
        FrecuenciaRecurrencia.quincenal => '2 semanas',
        FrecuenciaRecurrencia.mensual   => 'mes',
        FrecuenciaRecurrencia.anual     => 'año',
      };
}
