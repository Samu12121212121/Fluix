import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/domain/modelos/tarea.dart';
import 'package:planeag_flutter/services/tareas_service.dart';
import 'package:planeag_flutter/features/tareas/pantallas/detalle_tarea_screen.dart';
import 'package:planeag_flutter/features/tareas/pantallas/formulario_tarea_screen.dart';
import '../../../core/utils/permisos_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MÓDULO TAREAS — diseño Kanban estilo Notion/Linear
// ═════════════════════════════════════════════════════════════════════════════

class ModuloTareasScreen extends StatefulWidget {
  final String empresaId;
  const ModuloTareasScreen({super.key, required this.empresaId});

  @override
  State<ModuloTareasScreen> createState() => _ModuloTareasScreenState();
}

class _ModuloTareasScreenState extends State<ModuloTareasScreen> {
  final TareasService _svc = TareasService();

  int _vista = 0; // 0=kanban, 1=lista, 2=calendario
  PrioridadTarea? _filtroPrioridad;
  DateTime _focusedDay      = DateTime.now();
  DateTime _diaSeleccionado = DateTime.now();
  EstadoTarea? _filtroCalendario;

  // Cache de nombres de usuario
  final Map<String, String> _nombres = {};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Columnas Kanban ───────────────────────────────────────────────────────

  static const _columnas = [
    (EstadoTarea.pendiente,  'Por hacer',   Color(0xFFFFFBEB), Color(0xFFF59E0B)),
    (EstadoTarea.enProgreso, 'En progreso', Color(0xFFEFF6FF), Color(0xFF3B82F6)),
    (EstadoTarea.enRevision, 'En revisión', Color(0xFFF5F3FF), Color(0xFF8B5CF6)),
    (EstadoTarea.completada, 'Completadas', Color(0xFFF0FDF4), Color(0xFF22C55E)),
  ];

  // ── Colores helpers ───────────────────────────────────────────────────────

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

  String _formatFecha(DateTime dt) {
    final d = dt.day;
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '$d ${meses[dt.month - 1]}';
  }

  // ── Cache nombres ─────────────────────────────────────────────────────────

  Future<void> _cargarNombres(List<Tarea> tareas) async {
    final ids = tareas
        .map((t) => t.usuarioAsignadoId)
        .whereType<String>()
        .where((id) => !_nombres.containsKey(id))
        .toSet();
    for (final id in ids) {
      try {
        final doc = await FirebaseFirestore.instance.collection('usuarios').doc(id).get();
        if (doc.exists && mounted) {
          setState(() => _nombres[id] = doc.data()?['nombre'] as String? ?? 'Usuario');
        }
      } catch (_) {}
    }
  }

  String _nombre(String? uid) {
    if (uid == null) return '';
    return _nombres[uid] ?? uid.substring(0, uid.length.clamp(0, 6));
  }

  String _iniciales(String? uid) {
    if (uid == null) return '?';
    final n = _nombres[uid] ?? '';
    if (n.isEmpty) return uid[0].toUpperCase();
    final parts = n.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n[0].toUpperCase();
  }

  Color _avatarColor(String? uid) {
    if (uid == null) return Colors.grey;
    const palette = [
      Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981),
      Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF06B6D4),
    ];
    return palette[uid.hashCode.abs() % palette.length];
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  List<Tarea> _filtrar(List<Tarea> todas) {
    var r = todas.where((t) => t.estado != EstadoTarea.cancelada).toList();
    if (_filtroPrioridad != null) r = r.where((t) => t.prioridad == _filtroPrioridad).toList();
    return r;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Tarea>>(
      stream: _svc.tareasVisiblesStream(widget.empresaId,
          esPropietario: PermisosService().sesion?.esPropietario ?? false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && (snap.data?.isEmpty ?? true)) {
          return const Center(child: CircularProgressIndicator());
        }
        final todas    = snap.data ?? [];
        final filtradas = _filtrar(todas);

        // Cargar nombres en background
        if (todas.isNotEmpty) _cargarNombres(todas);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(children: [
            _buildHeader(),
            _buildFilterBar(),
            _buildViewBar(todas),
            Expanded(child: _vista == 0
                ? _buildKanbanConResumen(filtradas, todas)
                : _vista == 1
                    ? _buildListaConResumen(filtradas, todas)
                    : _buildCalendario(todas)),
          ]),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tareas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        Text('Organiza y gestiona todas las tareas de tu equipo.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
      const Spacer(),
      ElevatedButton.icon(
        onPressed: _nuevaTarea,
        icon: const Icon(Icons.add, size: 16, color: Colors.white),
        label: const Text('Nueva tarea', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), elevation: 0,
        ),
      ),
    ]),
  );

  // ── Barra de filtros ──────────────────────────────────────────────────────

  Widget _buildFilterBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Row(children: [
      _filtroChip('Responsable', 'Todos', null),
      const SizedBox(width: 8),
      _filtroChip('Proyecto', 'Todos', null),
      const SizedBox(width: 8),
      // Prioridad — funcional
      PopupMenuButton<PrioridadTarea?>(
        onSelected: (p) => setState(() => _filtroPrioridad = p),
        itemBuilder: (_) => [
          const PopupMenuItem(value: null, child: Text('Todas')),
          const PopupMenuItem(value: PrioridadTarea.urgente, child: Text('🔴 Urgente')),
          const PopupMenuItem(value: PrioridadTarea.alta,    child: Text('🟠 Alta')),
          const PopupMenuItem(value: PrioridadTarea.media,   child: Text('🟡 Media')),
          const PopupMenuItem(value: PrioridadTarea.baja,    child: Text('⚪ Baja')),
        ],
        child: _filtroChip('Prioridad', _filtroPrioridad == null ? 'Todas' : _labelPrioridad(_filtroPrioridad!), null, active: _filtroPrioridad != null),
      ),
      const SizedBox(width: 8),
      _filtroChip('Fecha límite', 'Cualquiera', null),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          const Icon(Icons.tune, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 5),
          const Text('Más filtros', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          if (_filtroPrioridad != null) ...[
            const SizedBox(width: 5),
            Container(width: 16, height: 16,
                decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                child: const Center(child: Text('1', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)))),
          ],
        ]),
      ),
    ]),
  );

  Widget _filtroChip(String label, String valor, VoidCallback? onTap, {bool active = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: active ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(6),
            color: active ? const Color(0xFFEFF6FF) : Colors.transparent,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text(valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? const Color(0xFF3B82F6) : const Color(0xFF334155))),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: active ? const Color(0xFF3B82F6) : Colors.grey.shade400),
          ]),
        ),
      );

  // ── Barra de vista ────────────────────────────────────────────────────────

  Widget _buildViewBar(List<Tarea> todas) {
    final nPend    = todas.where((t) => t.estado == EstadoTarea.pendiente).length;
    final nProg    = todas.where((t) => t.estado == EstadoTarea.enProgreso).length;
    final nRev     = todas.where((t) => t.estado == EstadoTarea.enRevision).length;
    final nComp    = todas.where((t) => t.estado == EstadoTarea.completada).length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(children: [
        // Vista switcher
        _vistaSwitcher(),
        const SizedBox(width: 20),
        // Stat chips
        _statChip(nPend.toString(), 'Por hacer', const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        _statChip(nProg.toString(), 'En progreso', const Color(0xFF3B82F6)),
        const SizedBox(width: 8),
        _statChip(nRev.toString(), 'En revisión', const Color(0xFF8B5CF6)),
        const SizedBox(width: 8),
        _statChip(nComp.toString(), 'Completadas', const Color(0xFF22C55E)),
      ]),
    );
  }

  Widget _vistaSwitcher() => Row(children: [
    _vBtn(0, Icons.view_kanban_outlined, 'Kanban'),
    _vBtn(1, Icons.list_rounded,          'Lista'),
    _vBtn(2, Icons.calendar_month_outlined,'Calendario'),
  ]);

  Widget _vBtn(int idx, IconData icon, String label) {
    final sel = _vista == idx;
    return GestureDetector(
      onTap: () => setState(() => _vista = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: sel ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)) : null,
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: sel ? const Color(0xFF3B82F6) : Colors.grey.shade500),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
              color: sel ? const Color(0xFF3B82F6) : Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _statChip(String valor, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('$valor $label', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // KANBAN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildKanbanConResumen(List<Tarea> filtradas, List<Tarea> todas) =>
      SingleChildScrollView(child: Column(children: [
        SizedBox(
          height: 560,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: _columnas.map((col) {
              final (estado, titulo, bg, accent) = col;
              final tareas = filtradas.where((t) => t.estado == estado).toList();
              return _columna(estado, titulo, bg, accent, tareas);
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: _buildResumen(todas),
        ),
      ]));

  Widget _columna(EstadoTarea estado, String titulo, Color bg, Color accent, List<Tarea> tareas) =>
      Container(
        width: 280,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              if (estado == EstadoTarea.completada)
                Icon(Icons.check_circle, color: accent, size: 15)
              else
                Container(width: 9, height: 9, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text('${tareas.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
              ),
            ]),
          ),
          // Cards
          Expanded(child: tareas.isEmpty
              ? Center(child: Text('Sin tareas', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  itemCount: tareas.length,
                  itemBuilder: (_, i) => _tarjeta(tareas[i], accent),
                )),
          // Añadir
          InkWell(
            onTap: () => _nuevaTareaEstado(estado),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
              child: Row(children: [
                Icon(Icons.add, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text('Añadir tarea', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ]),
            ),
          ),
        ]),
      );

  Widget _tarjeta(Tarea tarea, Color accent) {
    final completada = tarea.estado == EstadoTarea.completada;
    final hayProgreso = tarea.subtareas.isNotEmpty;
    final pct = hayProgreso ? tarea.subtareasCompletadas / tarea.subtareas.length : 0.0;
    return GestureDetector(
      onTap: () => _abrirDetalle(tarea),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          color: completada ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: completada ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title + menu
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(tarea.titulo,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: completada ? Colors.grey.shade400 : const Color(0xFF1E293B),
                    decoration: completada ? TextDecoration.lineThrough : null),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: () {},
              child: Icon(Icons.more_horiz, size: 16, color: Colors.grey.shade400),
            ),
          ]),
          // Tag
          if (tarea.etiquetas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _colorTag(tarea.etiquetas.first).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(tarea.etiquetas.first,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _colorTag(tarea.etiquetas.first))),
            ),
          ],
          // Fecha
          if (tarea.fechaLimite != null) ...[
            const SizedBox(height: 7),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 11,
                  color: tarea.estaAtrasada ? Colors.red : Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(_formatFecha(tarea.fechaLimite!),
                  style: TextStyle(fontSize: 11, color: tarea.estaAtrasada ? Colors.red : const Color(0xFF64748B))),
            ]),
          ],
          // Progress bar
          if (hayProgreso) ...[
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
              value: pct, minHeight: 4,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(accent),
            )),
          ],
          // Assignee + priority
          const SizedBox(height: 8),
          Row(children: [
            if (tarea.usuarioAsignadoId != null) ...[
              CircleAvatar(radius: 9,
                  backgroundColor: _avatarColor(tarea.usuarioAsignadoId),
                  child: Text(_iniciales(tarea.usuarioAsignadoId),
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
              const SizedBox(width: 5),
              Text(_nombre(tarea.usuarioAsignadoId),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis),
            ],
            const Spacer(),
            Container(width: 7, height: 7, decoration: BoxDecoration(
                color: _colorPrioridad(tarea.prioridad), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(_labelPrioridad(tarea.prioridad),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _colorPrioridad(tarea.prioridad))),
          ]),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LISTA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildListaConResumen(List<Tarea> filtradas, List<Tarea> todas) =>
      SingleChildScrollView(child: Column(children: [
        filtradas.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No hay tareas', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14))),
              )
            : ListView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                itemCount: filtradas.length,
                itemBuilder: (_, i) => _filaLista(filtradas[i]),
              ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: _buildResumen(todas),
        ),
      ]));

  Widget _filaLista(Tarea tarea) {
    final accent = _columnas
        .firstWhere((c) => c.$1 == tarea.estado,
            orElse: () => _columnas.first)
        .$4;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _abrirDetalle(tarea),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tarea.titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  decoration: tarea.estado == EstadoTarea.completada ? TextDecoration.lineThrough : null,
                  color: tarea.estado == EstadoTarea.completada ? Colors.grey.shade400 : const Color(0xFF1E293B))),
              if (tarea.etiquetas.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _colorTag(tarea.etiquetas.first).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(tarea.etiquetas.first, style: TextStyle(fontSize: 10, color: _colorTag(tarea.etiquetas.first), fontWeight: FontWeight.w600)),
                ),
              ],
            ])),
            if (tarea.fechaLimite != null) ...[
              const SizedBox(width: 12),
              Text(_formatFecha(tarea.fechaLimite!),
                  style: TextStyle(fontSize: 11, color: tarea.estaAtrasada ? Colors.red : const Color(0xFF94A3B8))),
            ],
            const SizedBox(width: 12),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: _colorPrioridad(tarea.prioridad), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(_labelPrioridad(tarea.prioridad), style: TextStyle(fontSize: 11, color: _colorPrioridad(tarea.prioridad))),
            const SizedBox(width: 12),
            if (tarea.usuarioAsignadoId != null)
              CircleAvatar(radius: 10,
                  backgroundColor: _avatarColor(tarea.usuarioAsignadoId),
                  child: Text(_iniciales(tarea.usuarioAsignadoId),
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CALENDARIO (reutiliza diseño existente)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCalendario(List<Tarea> todas) {
    final filtradas = _filtroCalendario == null ? todas : todas.where((t) => t.estado == _filtroCalendario).toList();
    final eventMap  = <DateTime, List<Tarea>>{};
    for (final t in filtradas) {
      if (t.fechaLimite == null) continue;
      final key = DateTime(t.fechaLimite!.year, t.fechaLimite!.month, t.fechaLimite!.day);
      eventMap[key] = [...(eventMap[key] ?? []), t];
    }
    final tareasHoy = eventMap[DateTime(_diaSeleccionado.year, _diaSeleccionado.month, _diaSeleccionado.day)] ?? [];

    return SingleChildScrollView(child: Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          _chipCal(null, 'Todas', Colors.blueGrey),
          const SizedBox(width: 6),
          _chipCal(EstadoTarea.pendiente, 'Pendiente', const Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          _chipCal(EstadoTarea.enProgreso, 'En progreso', const Color(0xFF3B82F6)),
          const SizedBox(width: 6),
          _chipCal(EstadoTarea.enRevision, 'Revisión', const Color(0xFF8B5CF6)),
          const SizedBox(width: 6),
          _chipCal(EstadoTarea.completada, 'Completada', const Color(0xFF22C55E)),
        ]),
      ),
      SizedBox(height: 360, child: TableCalendar<Tarea>(
        locale: 'es_ES',
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (d) => isSameDay(_diaSeleccionado, d),
        eventLoader: (d) => eventMap[DateTime(d.year, d.month, d.day)] ?? [],
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
        onDaySelected: (sel, foc) => setState(() { _diaSeleccionado = sel; _focusedDay = foc; }),
        onPageChanged: (foc) => setState(() => _focusedDay = foc),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.25), shape: BoxShape.circle),
          selectedDecoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
          markerDecoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
          outsideDaysVisible: false,
        ),
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        calendarBuilders: CalendarBuilders<Tarea>(
          markerBuilder: (ctx, day, events) {
            if (events.isEmpty) return const SizedBox.shrink();
            return Positioned(bottom: 4, child: Row(mainAxisSize: MainAxisSize.min,
                children: events.take(4).map((t) => Container(
                  width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: _columnas.firstWhere((c) => c.$1 == t.estado, orElse: () => _columnas.first).$4, shape: BoxShape.circle),
                )).toList()));
          },
        ),
      )),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text(DateFormat('EEEE d MMMM', 'es_ES').format(_diaSeleccionado),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('${tareasHoy.length} tarea${tareasHoy.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ]),
      ),
      if (tareasHoy.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Icon(Icons.event_available, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('Sin tareas para este día', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            ]))
      else
        ListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
          itemCount: tareasHoy.length,
          itemBuilder: (_, i) => _filaLista(tareasHoy[i]),
        ),
    ]));
  }

  Widget _chipCal(EstadoTarea? estado, String label, Color color) {
    final sel = _filtroCalendario == estado;
    return FilterChip(
      selected: sel, label: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : color, fontWeight: FontWeight.w600)),
      backgroundColor: color.withValues(alpha: 0.08), selectedColor: color,
      checkmarkColor: Colors.white, side: BorderSide(color: color.withValues(alpha: 0.4)),
      onSelected: (_) => setState(() => _filtroCalendario = estado),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN INFERIOR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResumen(List<Tarea> todas) {
    final nTotal = todas.where((t) => t.estado != EstadoTarea.cancelada).length;
    final nPend  = todas.where((t) => t.estado == EstadoTarea.pendiente).length;
    final nProg  = todas.where((t) => t.estado == EstadoTarea.enProgreso).length;
    final nRev   = todas.where((t) => t.estado == EstadoTarea.enRevision).length;
    final nComp  = todas.where((t) => t.estado == EstadoTarea.completada).length;

    // Carga de trabajo por usuario
    final carga = <String, int>{};
    for (final t in todas) {
      if (t.usuarioAsignadoId != null && t.estado != EstadoTarea.cancelada) {
        carga[t.usuarioAsignadoId!] = (carga[t.usuarioAsignadoId!] ?? 0) + 1;
      }
    }
    final cargaOrdenada = carga.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCarga = cargaOrdenada.isEmpty ? 1 : cargaOrdenada.first.value;

    // Próximos vencimientos
    final proximos = todas
        .where((t) => t.fechaLimite != null && t.estado != EstadoTarea.completada && t.estado != EstadoTarea.cancelada)
        .toList()
      ..sort((a, b) => a.fechaLimite!.compareTo(b.fechaLimite!));

    return LayoutBuilder(builder: (_, c) {
      final wide = c.maxWidth > 700;
      final left = _buildResumenEquipo(nTotal, nPend, nProg, nRev, nComp, cargaOrdenada, maxCarga);
      final right = _buildProximos(proximos.take(5).toList());
      if (wide) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left), const SizedBox(width: 16), Expanded(child: right),
      ]);
      return Column(children: [left, const SizedBox(height: 16), right]);
    });
  }

  Widget _buildResumenEquipo(int total, int pend, int prog, int rev, int comp,
      List<MapEntry<String, int>> carga, int max) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Resumen del equipo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      const SizedBox(height: 14),
      Row(children: [
        _resumenChip('$total',  'Total tareas',   const Color(0xFF3B82F6)),
        _resumenChip('$pend',   'Por hacer',      const Color(0xFFF59E0B)),
        _resumenChip('$prog',   'En progreso',    const Color(0xFF3B82F6)),
        _resumenChip('$rev',    'En revisión',    const Color(0xFF8B5CF6)),
        _resumenChip('$comp',   'Completadas',    const Color(0xFF22C55E)),
      ]),
      if (carga.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Text('Carga de trabajo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        ...carga.take(6).map((e) {
          final pct = e.value / max;
          final barColor = pct >= 0.7 ? const Color(0xFF22C55E) : pct >= 0.4 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              CircleAvatar(radius: 13, backgroundColor: _avatarColor(e.key),
                  child: Text(_iniciales(e.key), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nombre(e.key), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                  value: pct, minHeight: 5,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation(barColor),
                )),
              ])),
              const SizedBox(width: 10),
              Text('${e.value} tareas', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(width: 6),
              Text('${(pct * 100).round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: barColor)),
            ]),
          );
        }),
      ],
    ]),
  );

  Widget _resumenChip(String valor, String label, Color color) => Expanded(
    child: Column(children: [
      Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), textAlign: TextAlign.center, maxLines: 2),
    ]),
  );

  Widget _buildProximos(List<Tarea> tareas) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Próximos vencimientos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _vista = 2),
          child: const Text('Ver calendario →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
        ),
      ]),
      const SizedBox(height: 14),
      if (tareas.isEmpty)
        Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('Sin vencimientos próximos',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13))))
      else
        ...tareas.asMap().entries.map((e) {
          final t = e.value;
          final idx = e.key + 1;
          final badgeColor = _colorPrioridad(t.prioridad);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(width: 24, height: 24,
                  decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Center(child: Text('$idx', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor)))),
              const SizedBox(width: 10),
              Expanded(child: Text(t.titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis)),
              if (t.fechaLimite != null) ...[
                const SizedBox(width: 8),
                Text(_formatFecha(t.fechaLimite!),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: t.estaAtrasada ? Colors.red : const Color(0xFF64748B))),
              ],
              const SizedBox(width: 8),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(_labelPrioridad(t.prioridad), style: TextStyle(fontSize: 11, color: badgeColor)),
              const SizedBox(width: 8),
              if (t.usuarioAsignadoId != null)
                CircleAvatar(radius: 10, backgroundColor: _avatarColor(t.usuarioAsignadoId),
                    child: Text(_iniciales(t.usuarioAsignadoId),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
            ]),
          );
        }),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  void _abrirDetalle(Tarea tarea) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _modalShell(
        height: 0.95,
        child: DetalleTareaScreen(
          tarea: tarea, empresaId: widget.empresaId, usuarioId: _uid),
      ),
    );
  }

  void _nuevaTarea() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _modalShell(
        height: 0.95,
        child: FormularioTareaScreen(empresaId: widget.empresaId, usuarioId: _uid),
      ),
    );
  }

  void _nuevaTareaEstado(EstadoTarea estado) => _nuevaTarea();

  Widget _modalShell({required double height, required Widget child}) {
    return Container(
      height: MediaQuery.of(context).size.height * height,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

