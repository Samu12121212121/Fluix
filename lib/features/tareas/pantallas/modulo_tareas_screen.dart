import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:planeag_flutter/domain/modelos/tarea.dart';
import 'package:planeag_flutter/services/tareas_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/features/tareas/pantallas/detalle_tarea_screen.dart';
import 'package:planeag_flutter/features/tareas/pantallas/formulario_tarea_screen.dart';
import 'package:planeag_flutter/features/tareas/pantallas/equipos_screen.dart';
import '../../../core/utils/permisos_service.dart';

class ModuloTareasScreen extends StatefulWidget {
  final String empresaId;
  const ModuloTareasScreen({super.key, required this.empresaId});

  @override
  State<ModuloTareasScreen> createState() => _ModuloTareasScreenState();
}

class _ModuloTareasScreenState extends State<ModuloTareasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final TareasService _svc = TareasService();
  int _vistaActual = 0; // 0=kanban, 1=lista, 2=calendario

  // Estado para la vista calendario
  DateTime _focusedDay   = DateTime.now();
  DateTime _diaSeleccionado = DateTime.now();
  // Filtro por estado en vista calendario (null = todas)
  EstadoTarea? _filtroCalendario;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _usuarioId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Gestión de Tareas', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Toggle vista: kanban → lista → calendario → kanban
          IconButton(
            icon: Icon(
              _vistaActual == 0 ? Icons.view_kanban
                : _vistaActual == 1 ? Icons.list
                : Icons.calendar_month,
              size: 22,
            ),
            onPressed: () => setState(() => _vistaActual = (_vistaActual + 1) % 3),
            tooltip: _vistaActual == 0 ? 'Vista lista'
                : _vistaActual == 1 ? 'Vista calendario'
                : 'Vista Kanban',
          ),
          IconButton(
            icon: const Icon(Icons.group, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => EquiposScreen(empresaId: widget.empresaId),
            )),
            tooltip: 'Equipos',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          padding: EdgeInsets.zero,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Pendientes'),
            Tab(text: 'En Progreso'),
            Tab(text: 'Revisión'),
            Tab(text: 'Completadas'),
          ],
        ),
      ),
      body: StreamBuilder<List<Tarea>>(
        stream: _svc.tareasVisiblesStream(
          widget.empresaId,
          esPropietario:
              PermisosService().sesion?.esPropietario ?? false,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final todas = snapshot.data ?? [];
          return Column(
            children: [
              // Resumen rápido
              _buildResumenRapido(todas),
              // Contenido tabs
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _vistaActual == 0
                        ? _buildKanban(todas)
                        : _vistaActual == 1
                            ? _buildLista(todas)
                            : _buildCalendario(todas),
                    _buildLista(todas.where((t) => t.estado == EstadoTarea.pendiente).toList()),
                    _buildLista(todas.where((t) => t.estado == EstadoTarea.enProgreso).toList()),
                    _buildLista(todas.where((t) => t.estado == EstadoTarea.enRevision).toList()),
                    _buildLista(todas.where((t) => t.estado == EstadoTarea.completada).toList()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_tareas',
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => FormularioTareaScreen(
            empresaId: widget.empresaId,
            usuarioId: _usuarioId,
          ),
        )),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildResumenRapido(List<Tarea> tareas) {
    final pendientes = tareas.where((t) => t.estado == EstadoTarea.pendiente).length;
    final enProgreso = tareas.where((t) => t.estado == EstadoTarea.enProgreso).length;
    final atrasadas = tareas.where((t) => t.estaAtrasada).length;
    final completadasHoy = tareas.where((t) {
      final ahora = DateTime.now();
      return t.estado == EstadoTarea.completada &&
          t.fechaActualizacion != null &&
          t.fechaActualizacion!.day == ahora.day &&
          t.fechaActualizacion!.month == ahora.month &&
          t.fechaActualizacion!.year == ahora.year;
    }).length;

    return Container(
      color: const Color(0xFF1976D2),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _chipResumen('$pendientes', 'Pendientes', Colors.orange),
          const SizedBox(width: 8),
          _chipResumen('$enProgreso', 'En progreso', Colors.blue[300]!),
          const SizedBox(width: 8),
          _chipResumen('$atrasadas', 'Atrasadas', Colors.red[300]!),
          const SizedBox(width: 8),
          _chipResumen('$completadasHoy', 'Hoy ✓', Colors.green[300]!),
        ],
      ),
    );
  }

  Widget _chipResumen(String valor, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── VISTA CALENDARIO ─────────────────────────────────────────────

  Map<DateTime, List<Tarea>> _buildEventMap(List<Tarea> tareas) {
    final Map<DateTime, List<Tarea>> map = {};
    for (final t in tareas) {
      if (t.fechaLimite == null) continue;
      final key = DateTime(t.fechaLimite!.year, t.fechaLimite!.month, t.fechaLimite!.day);
      map[key] = [...(map[key] ?? []), t];
    }
    return map;
  }

  Color _colorEvento(Tarea t) => switch (t.estado) {
    EstadoTarea.pendiente  => const Color(0xFFF57C00),
    EstadoTarea.enProgreso => const Color(0xFF1976D2),
    EstadoTarea.enRevision => const Color(0xFF7B1FA2),
    EstadoTarea.completada => const Color(0xFF388E3C),
    EstadoTarea.cancelada  => Colors.grey,
  };

  Widget _chipFiltro(EstadoTarea? estado, String label, Color color) {
    final isSelected = _filtroCalendario == estado;
    return FilterChip(
      selected: isSelected,
      label: Text(label, style: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : color,
        fontWeight: FontWeight.w600,
      )),
      backgroundColor: color.withValues(alpha: 0.08),
      selectedColor: color,
      checkmarkColor: Colors.white,
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      onSelected: (_) => setState(() => _filtroCalendario = estado),
    );
  }

  Widget _buildCalendario(List<Tarea> tareas) {
    final tareasFiltradas = _filtroCalendario == null
        ? tareas
        : tareas.where((t) => t.estado == _filtroCalendario).toList();

    final eventMap = _buildEventMap(tareasFiltradas);

    List<Tarea> _tareasDelDia(DateTime day) {
      final key = DateTime(day.year, day.month, day.day);
      return eventMap[key] ?? [];
    }

    final tareasHoy = _tareasDelDia(_diaSeleccionado);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Chips de filtro por estado ─────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _chipFiltro(null, 'Todas', Colors.blueGrey),
                const SizedBox(width: 6),
                _chipFiltro(EstadoTarea.pendiente, 'Pendiente', Colors.orange),
                const SizedBox(width: 6),
                _chipFiltro(EstadoTarea.enProgreso, 'En progreso', Colors.blue),
                const SizedBox(width: 6),
                _chipFiltro(EstadoTarea.enRevision, 'Revisión', Colors.purple),
                const SizedBox(width: 6),
                _chipFiltro(EstadoTarea.completada, 'Completada', Colors.green),
                const SizedBox(width: 6),
                _chipFiltro(EstadoTarea.cancelada, 'Cancelada', Colors.grey),
              ],
            ),
          ),
          // Calendario con altura fija
          SizedBox(
            height: 360,
            child: TableCalendar<Tarea>(
              locale: 'es_ES',
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_diaSeleccionado, day),
              eventLoader: (day) => _tareasDelDia(day),
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Mes',
                CalendarFormat.week: 'Semana',
              },
              onDaySelected: (selected, focused) {
                setState(() {
                  _diaSeleccionado = selected;
                  _focusedDay      = focused;
                });
              },
              onPageChanged: (focused) => setState(() => _focusedDay = focused),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF1976D2),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF1976D2),
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              calendarBuilders: CalendarBuilders<Tarea>(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: events.take(4).map((t) => Container(
                        width: 5, height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: _colorEvento(t),
                          shape: BoxShape.circle,
                        ),
                      )).toList(),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Cabecera día seleccionado ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  DateFormat('EEEE d MMMM', 'es_ES').format(_diaSeleccionado),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tareasHoy.length} tarea${tareasHoy.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de tareas del día (sin scroll propio) ────────────
          if (tareasHoy.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Sin tareas para este día',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              itemCount: tareasHoy.length,
              itemBuilder: (_, i) => _tarjetaLista(tareasHoy[i]),
            ),
        ],
      ),
    );
  }

  // ── VISTA KANBAN ──────────────────────────────────────────────

  Widget _buildKanban(List<Tarea> tareas) {
    final columnas = [
      (EstadoTarea.pendiente, 'Pendiente', const Color(0xFFFFF8E1), Colors.orange),
      (EstadoTarea.enProgreso, 'En Progreso', const Color(0xFFE3F2FD), Colors.blue),
      (EstadoTarea.enRevision, 'Revisión', const Color(0xFFF3E5F5), Colors.purple),
      (EstadoTarea.completada, 'Completada', const Color(0xFFE8F5E9), Colors.green),
    ];

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      children: columnas.map((col) {
        final (estado, titulo, bgColor, color) = col;
        final tareasCol = tareas.where((t) => t.estado == estado).toList();
        return _columnaKanban(titulo, tareasCol, bgColor, color);
      }).toList(),
    );
  }

  Widget _columnaKanban(String titulo, List<Tarea> tareas, Color bg, Color color) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          // Header columna
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: color, width: 2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text('${tareas.length}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Tarjetas
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bg.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: tareas.isEmpty
                  ? Center(child: Text('Sin tareas', style: TextStyle(color: Colors.grey[400], fontSize: 13)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: tareas.length,
                      itemBuilder: (_, i) => _tarjetaKanban(tareas[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaKanban(Tarea tarea) {
    return GestureDetector(
      onTap: () => _abrirDetalle(tarea),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: tarea.estaAtrasada ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prioridad + tipo
              Row(
                children: [
                  _chipPrioridad(tarea.prioridad),
                  const Spacer(),
                  Icon(_iconoTipo(tarea.tipo), size: 14, color: Colors.grey[500]),
                  if (tarea.estaAtrasada) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(tarea.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (tarea.descripcion != null) ...[
                const SizedBox(height: 4),
                Text(tarea.descripcion!, style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              // Subtareas progress
              if (tarea.subtareas.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.check_box_outlined, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('${tarea.subtareasCompletadas}/${tarea.subtareas.length}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: tarea.subtareas.isEmpty ? 0 :
                              tarea.subtareasCompletadas / tarea.subtareas.length,
                          minHeight: 4,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              // Fecha límite
              if (tarea.fechaLimite != null)
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13,
                        color: tarea.estaAtrasada ? Colors.red : Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM HH:mm').format(tarea.fechaLimite!),
                      style: TextStyle(
                        fontSize: 11,
                        color: tarea.estaAtrasada ? Colors.red : Colors.grey[600],
                        fontWeight: tarea.estaAtrasada ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── VISTA LISTA ──────────────────────────────────────────────

  Widget _buildLista(List<Tarea> tareas) {
    if (tareas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay tareas', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tareas.length,
      itemBuilder: (_, i) => _tarjetaLista(tareas[i]),
    );
  }

  Widget _tarjetaLista(Tarea tarea) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: tarea.estaAtrasada ? const BorderSide(color: Colors.red, width: 1) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _abrirDetalle(tarea),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Estado checkbox
              GestureDetector(
                onTap: () => _cambiarEstadoRapido(tarea),
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _colorEstado(tarea.estado), width: 2),
                    color: tarea.estado == EstadoTarea.completada
                        ? _colorEstado(tarea.estado)
                        : Colors.transparent,
                  ),
                  child: tarea.estado == EstadoTarea.completada
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _chipPrioridad(tarea.prioridad),
                        const SizedBox(width: 6),
                        Icon(_iconoTipo(tarea.tipo), size: 13, color: Colors.grey[500]),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tarea.titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: tarea.estado == EstadoTarea.completada
                            ? TextDecoration.lineThrough
                            : null,
                        color: tarea.estado == EstadoTarea.completada
                            ? Colors.grey
                            : Colors.black87,
                      ),
                    ),
                    if (tarea.fechaLimite != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 12,
                              color: tarea.estaAtrasada ? Colors.red : Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(tarea.fechaLimite!),
                            style: TextStyle(
                              fontSize: 11,
                              color: tarea.estaAtrasada ? Colors.red : Colors.grey[600],
                              fontWeight: tarea.estaAtrasada ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (tarea.estaAtrasada) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('ATRASADA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirDetalle(Tarea tarea) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DetalleTareaScreen(
        tarea: tarea,
        empresaId: widget.empresaId,
        usuarioId: _usuarioId,
      ),
    ));
  }

  void _cambiarEstadoRapido(Tarea tarea) {
    EstadoTarea nuevoEstado;
    switch (tarea.estado) {
      case EstadoTarea.pendiente:
        nuevoEstado = EstadoTarea.enProgreso;
        break;
      case EstadoTarea.enProgreso:
        nuevoEstado = EstadoTarea.completada;
        break;
      default:
        nuevoEstado = EstadoTarea.pendiente;
    }
    _svc.cambiarEstado(widget.empresaId, tarea.id, nuevoEstado, _usuarioId);
  }

  Widget _chipPrioridad(PrioridadTarea p) {
    final (color, label) = switch (p) {
      PrioridadTarea.urgente => (Colors.red, '🔴 Urgente'),
      PrioridadTarea.alta    => (Colors.orange, '🟠 Alta'),
      PrioridadTarea.media   => (Colors.blue, '🔵 Media'),
      PrioridadTarea.baja    => (Colors.grey, '⚪ Baja'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  IconData _iconoTipo(TipoTarea t) => switch (t) {
    TipoTarea.normal     => Icons.task_alt,
    TipoTarea.checklist  => Icons.checklist,
    TipoTarea.incidencia => Icons.bug_report,
    TipoTarea.proyecto   => Icons.folder,
  };

  Color _colorEstado(EstadoTarea e) => switch (e) {
    EstadoTarea.pendiente   => Colors.orange,
    EstadoTarea.enProgreso  => Colors.blue,
    EstadoTarea.enRevision  => Colors.purple,
    EstadoTarea.completada  => Colors.green,
    EstadoTarea.cancelada   => Colors.grey,
  };
}


