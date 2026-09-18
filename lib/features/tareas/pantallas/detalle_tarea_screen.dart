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
import 'package:planeag_flutter/core/widgets/flux_toast.dart';

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
    const accent = Color(0xFF3B82F6);
    const bg     = Color(0xFFF1F5F9);
    const textC  = Color(0xFF1F2937);
    const subC   = Color(0xFF6B7280);
    const borderC = Color(0xFFE5E7EB);

    Color estadoColor(EstadoTarea e) => switch (e) {
      EstadoTarea.pendiente  => const Color(0xFFF59E0B),
      EstadoTarea.enProgreso => const Color(0xFF3B82F6),
      EstadoTarea.enRevision => const Color(0xFF8B5CF6),
      EstadoTarea.completada => const Color(0xFF22C55E),
      EstadoTarea.cancelada  => const Color(0xFF94A3B8),
    };

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(children: [
          // ── Header ───────────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16, right: 16, bottom: 0,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: borderC)),
            ),
            child: Column(children: [
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: borderC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded, size: 17, color: Color(0xFF6B7280)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_tarea.titulo, style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700, color: textC),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: estadoColor(_tarea.estado).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_nombreEstado(_tarea.estado),
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700, color: estadoColor(_tarea.estado))),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _colorPrioridad(_tarea.prioridad).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_labelPrioridad(_tarea.prioridad),
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700, color: _colorPrioridad(_tarea.prioridad))),
                    ),
                  ]),
                ])),
                const SizedBox(width: 8),
                if (_tarea.configuracionRecurrencia != null)
                  const Icon(Icons.repeat_rounded, size: 18, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FormularioTareaScreen(
                        empresaId: widget.empresaId,
                        usuarioId: widget.usuarioId,
                        tareaEditar: _tarea,
                      ))),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF3B82F6)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              // Tabs
              TabBar(
                controller: _tabs,
                labelColor: accent,
                unselectedLabelColor: subC,
                indicatorColor: accent,
                indicatorWeight: 2,
                isScrollable: true,
                padding: EdgeInsets.zero,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline_rounded, size: 16), text: 'Detalle'),
                  Tab(icon: Icon(Icons.attach_file_rounded, size: 16), text: 'Adjuntos'),
                  Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 16), text: 'Chat'),
                  Tab(icon: Icon(Icons.history_rounded, size: 16), text: 'Historial'),
                ],
              ),
            ]),
          ),
          // ── Tabs body ─────────────────────────────────────────────────────────
          Expanded(child: TabBarView(
            controller: _tabs,
            children: [
              _buildTabDetalle(),
              _buildTabAdjuntos(),
              _buildTabChat(),
              _buildTabHistorial(),
            ],
          )),
        ]),
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
          _cardSubtareas(),
          const SizedBox(height: 12),
          if (_tarea.etiquetas.isNotEmpty) ...[
            _cardEtiquetas(),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _cardClienteVinculado() {
    return _dsCard([
      const Row(children: [
        Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF3B82F6)),
        SizedBox(width: 6),
        Text('Cliente vinculado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
      ]),
      const SizedBox(height: 8),
      ClienteVinculadoWidget(empresaId: widget.empresaId, clienteId: _tarea.clienteId!),
    ]);
  }

  Widget _cardRecurrencia() {
    final config = _tarea.configuracionRecurrencia!;
    final pausada = config.pausada;
    final color = pausada ? const Color(0xFF94A3B8) : const Color(0xFF3B82F6);
    return _dsCard([
      Row(children: [
        Icon(Icons.repeat_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Text(pausada ? 'Recurrente (pausada)' : 'Tarea recurrente',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'pausar') { await _recSvc.pausarRecurrencia(widget.empresaId, _tarea.id); }
            else if (v == 'reanudar') { await _recSvc.reanudarRecurrencia(widget.empresaId, _tarea.id); }
            else if (v == 'cancelar') { await _recSvc.cancelarRecurrencia(widget.empresaId, _tarea.id); }
          },
          itemBuilder: (_) => [
            if (!pausada) const PopupMenuItem(value: 'pausar',
                child: ListTile(leading: Icon(Icons.pause), title: Text('Pausar'), contentPadding: EdgeInsets.zero, dense: true)),
            if (pausada) const PopupMenuItem(value: 'reanudar',
                child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Reanudar'), contentPadding: EdgeInsets.zero, dense: true)),
            const PopupMenuItem(value: 'cancelar',
                child: ListTile(leading: Icon(Icons.cancel, color: Colors.red), title: Text('Cancelar', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero, dense: true)),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.more_horiz, size: 14, color: Color(0xFF6B7280)),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Text('Cada ${_nombreFrecuencia(config.frecuencia)}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      if (_tarea.proximaFechaRecurrencia != null)
        Text('Próxima: ${DateFormat('dd/MM/yyyy').format(_tarea.proximaFechaRecurrencia!)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _cardEstadoPrioridad() {
    return _dsCard([
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Estado', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _selectorEstado(),
        ])),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Prioridad', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _tarea.creadoPorId == widget.usuarioId ? _selectorPrioridad() : _badgePrioridad(_tarea.prioridad),
        ])),
      ]),
      if (_tarea.fechaLimite != null) ...[
        const Divider(height: 16, color: Color(0xFFE5E7EB)),
        Row(children: [
          Icon(Icons.schedule_rounded, size: 14,
              color: _tarea.estaAtrasada ? const Color(0xFFEF4444) : const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Text('Vence: ${DateFormat('dd/MM/yyyy HH:mm').format(_tarea.fechaLimite!)}',
              style: TextStyle(fontSize: 12,
                  color: _tarea.estaAtrasada ? const Color(0xFFEF4444) : const Color(0xFF374151),
                  fontWeight: _tarea.estaAtrasada ? FontWeight.w700 : FontWeight.normal)),
          if (_tarea.estaAtrasada) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
              child: const Text('ATRASADA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ],
    ]);
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
            FluxToast.exito(context,
              'Tarea completada. La siguiente se creará el '
              '${DateFormat('dd/MM/yyyy').format(proxima)}',
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
    return _dsCard([
      const Row(children: [
        Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF3B82F6)),
        SizedBox(width: 6),
        Text('Información', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
      ]),
      if (_tarea.descripcion != null && _tarea.descripcion!.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(_tarea.descripcion!, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF374151))),
        ),
      ],
      const SizedBox(height: 10),
      _filaInfoDs(Icons.category_outlined, 'Tipo', _nombreTipo(_tarea.tipo)),
      if (_tarea.ubicacion != null)
        _filaInfoDs(Icons.location_on_outlined, 'Ubicación', _tarea.ubicacion!),
      if (_tarea.tiempoEstimadoMin != null)
        _filaInfoDs(Icons.hourglass_empty_rounded, 'Estimado', '${_tarea.tiempoEstimadoMin} min'),
      _filaInfoDs(Icons.calendar_today_outlined, 'Creada', DateFormat('dd/MM/yyyy').format(_tarea.fechaCreacion)),
      if (_tarea.recordatorio != null && _tarea.recordatorio!.tipo != TipoRecordatorio.ninguno)
        _filaInfoDs(Icons.alarm_outlined, 'Recordatorio', _tarea.recordatorio!.tipo.etiqueta),
    ]);
  }

  Widget _filaInfoDs(IconData icon, String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF6B7280)),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      const Spacer(),
      Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
    ]),
  );

  Widget _cardSubtareas() {
    final completadas = _tarea.subtareas.where((s) => s.completada).length;
    final total = _tarea.subtareas.length;
    return _dsCard([
      Row(children: [
        const Icon(Icons.checklist_rounded, size: 14, color: Color(0xFF3B82F6)),
        const SizedBox(width: 6),
        const Text('Checklist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
        const Spacer(),
        Text('$completadas/$total', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
      ]),
      const SizedBox(height: 8),
      if (total > 0) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total > 0 ? completadas / total : 0,
            minHeight: 4,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
          ),
        ),
        const SizedBox(height: 10),
      ],
      ..._tarea.subtareas.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          GestureDetector(
            onTap: () async {
              final updated = _tarea.subtareas.map((st) =>
                  st.id == s.id ? Subtarea(id: st.id, titulo: st.titulo, completada: !st.completada) : st
              ).toList();
              await _svc.actualizarSubtareas(widget.empresaId, _tarea.id, updated);
            },
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: s.completada ? const Color(0xFF22C55E) : Colors.transparent,
                border: Border.all(color: s.completada ? const Color(0xFF22C55E) : const Color(0xFFE5E7EB), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: s.completada ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(s.titulo, style: TextStyle(
            fontSize: 13, color: const Color(0xFF1F2937),
            decoration: s.completada ? TextDecoration.lineThrough : null,
            decorationColor: const Color(0xFF6B7280),
          ))),
        ]),
      )),
      if (_agregandoSubtarea) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(
            controller: _subtareaCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nuevo paso...',
              hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onSubmitted: (_) => _guardarSubtarea(),
          )),
          const SizedBox(width: 8),
          GestureDetector(onTap: _guardarSubtarea, child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
          )),
          const SizedBox(width: 4),
          GestureDetector(onTap: () => setState(() => _agregandoSubtarea = false), child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF6B7280)),
          )),
        ]),
      ] else ...[
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _agregandoSubtarea = true),
          child: Row(children: [
            Container(width: 18, height: 18,
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                    borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.add_rounded, size: 12, color: Color(0xFF3B82F6))),
            const SizedBox(width: 10),
            const Text('Añadir paso', style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    ]);
  }

  Future<void> _guardarSubtarea() async {
    final texto = _subtareaCtrl.text.trim();
    if (texto.isEmpty) return;
    final nuevas = [..._tarea.subtareas, Subtarea(id: DateTime.now().millisecondsSinceEpoch.toString(), titulo: texto)];
    await _svc.actualizarSubtareas(widget.empresaId, _tarea.id, nuevas);
    _subtareaCtrl.clear();
    if (mounted) setState(() => _agregandoSubtarea = false);
  }

  Widget _cardEtiquetas() {
    return _dsCard([
      const Row(children: [
        Icon(Icons.local_offer_outlined, size: 14, color: Color(0xFF3B82F6)),
        SizedBox(width: 6),
        Text('Etiquetas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: _tarea.etiquetas.map((e) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _colorTag(e).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _colorTag(e).withValues(alpha: 0.25)),
          ),
          child: Text(e, style: TextStyle(fontSize: 11, color: _colorTag(e), fontWeight: FontWeight.w600)),
        )
      ).toList()),
    ]);
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
      separatorBuilder: (context, index) => const SizedBox(height: 4),
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

  Widget _selectorPrioridad() {
    return DropdownButton<PrioridadTarea>(
      value: _tarea.prioridad,
      isDense: true,
      underline: const SizedBox(),
      items: PrioridadTarea.values.map((p) {
        final (color, label) = switch (p) {
          PrioridadTarea.urgente => (Colors.red, '🔴 Urgente'),
          PrioridadTarea.alta    => (Colors.orange, '🟠 Alta'),
          PrioridadTarea.media   => (Colors.blue, '🔵 Media'),
          PrioridadTarea.baja    => (Colors.grey, '⚪ Baja'),
        };
        return DropdownMenuItem(
          value: p,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        );
      }).toList(),
      onChanged: (nuevo) async {
        if (nuevo == null || nuevo == _tarea.prioridad) return;
        await _svc.actualizarTarea(
          widget.empresaId,
          _tarea.id,
          {'prioridad': nuevo.name},
          widget.usuarioId,
          'Prioridad cambiada a ${nuevo.name}',
        );
        if (mounted) {
          FluxToast.exito(context, 'Prioridad cambiada a ${nuevo.name}');
        }
      },
    );
  }

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

  Widget _dsCard(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Color _colorTag(String tag) {
    const palette = [
      Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981),
      Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF06B6D4),
      Color(0xFFF97316), Color(0xFFEC4899),
    ];
    return palette[tag.hashCode.abs() % palette.length];
  }

  Color _colorPrioridad(PrioridadTarea p) => switch (p) {
    PrioridadTarea.urgente => const Color(0xFFDC2626),
    PrioridadTarea.alta    => const Color(0xFFEF4444),
    PrioridadTarea.media   => const Color(0xFFF59E0B),
    PrioridadTarea.baja    => const Color(0xFF94A3B8),
  };

  String _labelPrioridad(PrioridadTarea p) => switch (p) {
    PrioridadTarea.urgente => 'Urgente',
    PrioridadTarea.alta    => 'Alta',
    PrioridadTarea.media   => 'Media',
    PrioridadTarea.baja    => 'Baja',
  };

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
