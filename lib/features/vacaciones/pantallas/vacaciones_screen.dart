import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_settings.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../../models/vacacion_model.dart';
import '../../../services/vacaciones_service.dart';
import 'nueva_solicitud_form.dart';

// ═════════════════════════════════════════════════════════════════════════════
// VACACIONES Y AUSENCIAS — rediseño fiel a la imagen
// ═════════════════════════════════════════════════════════════════════════════

const _kGreen  = Color(0xFF16A34A);
const _kAmber  = Color(0xFFF59E0B);
const _kBlue   = Color(0xFF3B82F6);
const _kRed    = Color(0xFFEF4444);
const _kPurple = Color(0xFF8B5CF6);

class VacacionesScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  /// true  = dentro del dashboard (no crea Scaffold propio)
  /// false = ruta standalone (crea Scaffold + FluixAppBar, oculta header verde)
  final bool embedded;
  const VacacionesScreen({super.key, required this.empresaId, this.sesion, this.embedded = true});

  @override
  State<VacacionesScreen> createState() => _VacacionesScreenState();
}

class _VacacionesScreenState extends State<VacacionesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final VacacionesService _svc = VacacionesService();

  // Calendario
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);
  String _vistaCalendario = 'mes'; // mes / semana / lista

  // Filtros
  String? _empleadoIdFiltro;
  String _busqueda = '';
  TipoAusencia? _tipoFiltro;

  bool _isDark = false;

  Color get _bg     => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _surf   => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _text   => _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _sub    => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _border => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  void _onDark() { if (mounted) setState(() => _isDark = AppSettings.darkMode.value); }

  bool get _esAdmin =>
      widget.sesion?.esAdmin ?? (PermisosService().sesion?.esAdmin ?? false);

  @override
  void initState() {
    super.initState();
    _isDark = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDark);
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_onDark);
    _tabs.dispose();
    super.dispose();
  }

  Color _colorTipo(TipoAusencia t) => switch (t) {
    TipoAusencia.vacaciones             => _kGreen,
    TipoAusencia.permisoRetribuido      => _kAmber,
    TipoAusencia.bajaMedica             => _kBlue,
    TipoAusencia.ausenciaJustificada    => _kRed,
    TipoAusencia.ausenciaInjustificada  => _kRed,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: FluixAppBar(
        titulo: 'Vacaciones y ausencias',
        showLeading: true,
        extraActions: _esAdmin
            ? [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Nueva solicitud',
                  onPressed: _nuevaSolicitud,
                )
              ]
            : const [],
      ),
      body: StreamBuilder<List<SolicitudVacaciones>>(
        stream: _svc.obtenerSolicitudes(widget.empresaId),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error al cargar ausencias: ${snap.error}',
                style: const TextStyle(color: Colors.red)));
          }
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final todas     = snap.data ?? [];
          final filtradas = _filtrar(todas);
          final pendientes = todas.where((s) => s.estado == EstadoSolicitud.solicitado).length;

          return ColoredBox(
            color: _bg,
            child: Column(children: [
              _buildTabBar(pendientes),
              Expanded(child: TabBarView(
                controller: _tabs,
                children: [
                  _buildCalendarioTab(filtradas),
                  _buildSolicitudesTab(filtradas, todas),
                  _buildCoberturaTab(todas),
                ],
              )),
            ]),
          );
        },
      ),
    );
  }

  static const _docBand = Color(0xFF16A34A);

  // ── TabBar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar(int pendientes) {
    return Container(
      decoration: BoxDecoration(
        color: _surf,
        border: Border(bottom: BorderSide(color: _border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDark ? 0.1 : 0.04),
            blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: TabBar(
        controller: _tabs,
        labelColor: _docBand,
        unselectedLabelColor: _sub,
        indicatorColor: _docBand,
        indicatorWeight: 3,
        tabs: [
          const Tab(text: 'Calendario', icon: Icon(Icons.calendar_month_outlined, size: 16)),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Solicitudes'),
              if (pendientes > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$pendientes', style: const TextStyle(
                      fontSize: 10.5, color: _kAmber, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
          const Tab(text: 'Cobertura', icon: Icon(Icons.people_outline, size: 16)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PESTAÑA CALENDARIO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCalendarioTab(List<SolicitudVacaciones> filtradas) {
    return Column(children: [
      _buildFiltros(),
      _buildNavCalendario(),
      Expanded(child: _vistaCalendario == 'lista'
          ? _buildListaView(filtradas)
          : _buildMesView(filtradas)),
    ]);
  }

  // ── Filtros ─────────────────────────────────────────────────────────────────

  // Nombre del empleado seleccionado para mostrar en el filtro
  String _empleadoNombreFiltro = 'Todos';

  void _abrirSelectorEmpleado() async {
    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('empresa_id', isEqualTo: widget.empresaId)
        .get();
    if (!mounted) return;
    final empleados = snap.docs.map((d) {
      final data = d.data();
      return (id: d.id, nombre: data['nombre'] as String? ?? data['email'] as String? ?? d.id);
    }).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));

    showModalBottomSheet(
      context: context,
      backgroundColor: _surf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 32, height: 3,
          decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text('Filtrar por empleado',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text)),
        ),
        ListTile(
          leading: Icon(Icons.people_outline, color: _sub, size: 18),
          title: Text('Todos los empleados', style: TextStyle(fontSize: 13, color: _text)),
          selected: _empleadoIdFiltro == null,
          selectedTileColor: _kGreen.withValues(alpha: 0.07),
          onTap: () {
            setState(() { _empleadoIdFiltro = null; _empleadoNombreFiltro = 'Todos'; });
            Navigator.pop(context);
          },
        ),
        ...empleados.map((e) => ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: _kGreen.withValues(alpha: 0.12),
            child: Text(e.nombre.isNotEmpty ? e.nombre[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 11, color: _kGreen, fontWeight: FontWeight.w700)),
          ),
          title: Text(e.nombre, style: TextStyle(fontSize: 13, color: _text)),
          selected: _empleadoIdFiltro == e.id,
          selectedTileColor: _kGreen.withValues(alpha: 0.07),
          onTap: () {
            setState(() { _empleadoIdFiltro = e.id; _empleadoNombreFiltro = e.nombre; });
            Navigator.pop(context);
          },
        )),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildFiltros() {
    const tipos = [
      (null,                             'Todos',      Colors.white),
      (TipoAusencia.vacaciones,          'Vac.',       _kGreen),
      (TipoAusencia.permisoRetribuido,   'Permisos',   _kAmber),
      (TipoAusencia.bajaMedica,          'Baja',       _kBlue),
      (TipoAusencia.ausenciaJustificada, 'Ausencias',  _kRed),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _surf,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Fila 1: selector empleado (admin) + búsqueda
        if (_esAdmin) Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            GestureDetector(
              onTap: _abrirSelectorEmpleado,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _empleadoIdFiltro != null ? _kGreen : _border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 13, color: _empleadoIdFiltro != null ? _kGreen : _sub),
                  const SizedBox(width: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(_empleadoNombreFiltro,
                        style: TextStyle(fontSize: 11.5,
                            color: _empleadoIdFiltro != null ? _kGreen : _text),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 13,
                      color: _empleadoIdFiltro != null ? _kGreen : _sub),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                const SizedBox(width: 8),
                Icon(Icons.search, size: 13, color: _sub),
                const SizedBox(width: 6),
                Expanded(child: TextField(
                  onChanged: (v) => setState(() => _busqueda = v.trim()),
                  style: TextStyle(fontSize: 12, color: _text),
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    hintStyle: TextStyle(fontSize: 12, color: _sub),
                    border: InputBorder.none, isDense: true,
                  ),
                )),
              ]),
            )),
          ]),
        ),
        // Fila 2: chips de tipo
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: tipos.map((t) {
              final sel = _tipoFiltro == t.$1;
              final c   = t.$3 == Colors.white ? _border : t.$3 as Color;
              return Padding(
                padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _tipoFiltro = _tipoFiltro == t.$1 ? null : t.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel ? c.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? c : _border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (t.$1 != null) Container(
                        width: 6, height: 6, margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                      ),
                      Text(t.$2, style: TextStyle(
                          fontSize: 11.5,
                          color: sel ? c : _sub,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── Navegación calendario ───────────────────────────────────────────────────

  Widget _buildNavCalendario() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surf,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        // ◀ mes anterior
        GestureDetector(
          onTap: () => setState(() =>
              _mesActual = DateTime(_mesActual.year, _mesActual.month - 1)),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(Icons.chevron_left, color: _text, size: 18),
          ),
        ),
        const SizedBox(width: 6),
        // Mes actual — flexible para no desbordar
        Flexible(
          child: GestureDetector(
            onTap: () => setState(() => _mesActual =
                DateTime(DateTime.now().year, DateTime.now().month)),
            child: Text(
              _mesActual.month == DateTime.now().month &&
                      _mesActual.year == DateTime.now().year
                  ? 'Hoy · ${DateFormat('MMM yyyy', 'es_ES').format(_mesActual)}'
                  : DateFormat('MMMM yyyy', 'es_ES').format(_mesActual),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: _text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // mes siguiente ▶
        GestureDetector(
          onTap: () => setState(() =>
              _mesActual = DateTime(_mesActual.year, _mesActual.month + 1)),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(Icons.chevron_right, color: _text, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Mes / Lista
        Container(
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final v in [('mes', 'Mes'), ('lista', 'Lista')])
              GestureDetector(
                onTap: () => setState(() => _vistaCalendario = v.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _vistaCalendario == v.$1 ? _surf : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: _vistaCalendario == v.$1
                        ? Border.all(color: _border) : null,
                  ),
                  child: Text(v.$2, style: TextStyle(
                      fontSize: 12, color: _text,
                      fontWeight: _vistaCalendario == v.$1
                          ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  // ── Vista mes ───────────────────────────────────────────────────────────────

  Widget _buildMesView(List<SolicitudVacaciones> solicitudes) {
    final hoy     = DateTime.now();
    final primerD = DateTime(_mesActual.year, _mesActual.month, 1);
    // Offset: Monday=0
    int offsetLunes = primerD.weekday - 1;
    final diasMes = DateUtils.getDaysInMonth(_mesActual.year, _mesActual.month);
    final totalCeldas = offsetLunes + diasMes;
    final filas = (totalCeldas / 7).ceil();

    // Indexar solicitudes por día
    final Map<String, List<SolicitudVacaciones>> porDia = {};
    for (final s in solicitudes) {
      var d = s.fechaInicio;
      while (!d.isAfter(s.fechaFin)) {
        if (d.month == _mesActual.month && d.year == _mesActual.year) {
          final key = '${d.day}';
          (porDia[key] ??= []).add(s);
        }
        d = d.add(const Duration(days: 1));
      }
    }

    return LayoutBuilder(builder: (_, bc) {
      // Distribuir la altura disponible entre las filas sin scroll
      // Cabecera días = 28px; el resto se reparte entre las filas
      const headerH = 28.0;
      final rowH = ((bc.maxHeight - headerH) / filas).clamp(44.0, 80.0);

      return Column(children: [
        // Cabecera días semana
        SizedBox(
          height: headerH,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: ['L','M','X','J','V','S','D'].map((d) =>
              Expanded(child: Center(child: Text(d, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _sub))))).toList(),
            ),
          ),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: _surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(children: [
              for (int fila = 0; fila < filas; fila++)
                Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (int col = 0; col < 7; col++) ...[
                    Builder(builder: (_) {
                      final idx = fila * 7 + col;
                      final dia = idx - offsetLunes + 1;
                      final esEsteMes = dia >= 1 && dia <= diasMes;
                      final esHoy     = esEsteMes && dia == hoy.day &&
                          _mesActual.month == hoy.month && _mesActual.year == hoy.year;
                      final esFin     = col >= 5;
                      final eventos   = esEsteMes ? (porDia['$dia'] ?? []) : <SolicitudVacaciones>[];

                      return Expanded(child: Container(
                        decoration: BoxDecoration(
                          color: esHoy
                              ? _kGreen.withValues(alpha: _isDark ? 0.12 : 0.04)
                              : Colors.transparent,
                          border: Border(
                            right: col < 6 ? BorderSide(color: _border, width: 0.5) : BorderSide.none,
                            bottom: fila < filas - 1 ? BorderSide(color: _border, width: 0.5) : BorderSide.none,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(3, 4, 2, 2),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Center(child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: esHoy ? _kGreen : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text(
                                esEsteMes ? '$dia' : '',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: esHoy ? Colors.white
                                      : esFin ? _kRed
                                      : esEsteMes ? _text : _sub,
                                ),
                              )),
                            )),
                            if (rowH > 46) ...[
                              const SizedBox(height: 2),
                              ...eventos.take(1).map((s) {
                                final c = _colorTipo(s.tipo);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 1),
                                  child: Row(children: [
                                    Container(width: 5, height: 5,
                                        decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                    const SizedBox(width: 2),
                                    Flexible(child: Text(
                                      s.empleadoNombre?.split(' ').first ?? '·',
                                      style: TextStyle(fontSize: 8.5, color: _text),
                                      overflow: TextOverflow.ellipsis, maxLines: 1,
                                    )),
                                  ]),
                                );
                              }),
                              if (eventos.length > 1)
                                Text('+${eventos.length - 1}',
                                    style: TextStyle(fontSize: 8, color: _sub)),
                            ],
                          ]),
                        ),
                      ));
                    }),
                  ],
                ])),
            ]),
          ),
        )),
      ]);
    });
  }

  // ── Vista lista ─────────────────────────────────────────────────────────────

  Widget _buildListaView(List<SolicitudVacaciones> solicitudes) {
    if (solicitudes.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_available_outlined, size: 48, color: _sub.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text('Sin solicitudes', style: TextStyle(fontSize: 16, color: _sub)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: solicitudes.length,
      itemBuilder: (_, i) => _solicitudCard(solicitudes[i]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PESTAÑA SOLICITUDES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSolicitudesTab(List<SolicitudVacaciones> filtradas,
      List<SolicitudVacaciones> todas) {
    final pendientes = filtradas.where((s) => s.estado == EstadoSolicitud.solicitado).toList();
    final resto      = filtradas.where((s) => s.estado != EstadoSolicitud.solicitado).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendientes.isNotEmpty) ...[
          Text('Pendientes de aprobación',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kAmber)),
          const SizedBox(height: 8),
          ...pendientes.map(_solicitudCard),
          const SizedBox(height: 16),
        ],
        if (resto.isNotEmpty) ...[
          Text('Historial', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _sub)),
          const SizedBox(height: 8),
          ...resto.map(_solicitudCard),
        ],
        if (filtradas.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_outlined, size: 48, color: _sub.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('Sin solicitudes', style: TextStyle(fontSize: 16, color: _sub)),
            ]),
          )),
      ],
    );
  }

  Widget _solicitudCard(SolicitudVacaciones s) {
    final c = _colorTipo(s.tipo);
    final estadoColor = switch (s.estado) {
      EstadoSolicitud.solicitado  => _kAmber,
      EstadoSolicitud.aprobado   => _kGreen,
      EstadoSolicitud.rechazado  => _kRed,
      _ => _sub,
    };
    final estadoLabel = switch (s.estado) {
      EstadoSolicitud.solicitado  => 'Pendiente',
      EstadoSolicitud.aprobado   => 'Aprobada',
      EstadoSolicitud.rechazado  => 'Rechazada',
      _ => s.estado.name,
    };
    final fechaStr =
        '${DateFormat('dd MMM', 'es_ES').format(s.fechaInicio)}'
        ' — ${DateFormat('dd MMM yyyy', 'es_ES').format(s.fechaFin)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Barra lateral de color
        Container(
          width: 5,
          decoration: BoxDecoration(
            color: c,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
          ),
        ),
        const SizedBox(width: 14),
        // Icono tipo
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: c.withValues(alpha: _isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_iconTipo(s.tipo), color: c, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        // Contenido
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s.empleadoNombre ?? 'Empleado',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: _text))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(estadoLabel, style: TextStyle(
                    fontSize: 10.5, color: estadoColor,
                    fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 3),
            // tipo
            Row(children: [
              Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              Flexible(child: Text(s.tipo.etiqueta,
                  style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _sub.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${s.diasNaturales}d',
                    style: TextStyle(fontSize: 10, color: _sub)),
              ),
            ]),
            const SizedBox(height: 2),
            // fecha
            Row(children: [
              Icon(Icons.date_range_outlined, size: 11, color: _sub),
              const SizedBox(width: 3),
              Flexible(child: Text(fechaStr,
                  style: TextStyle(fontSize: 11, color: _sub),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ]),
        )),
        if (_esAdmin && s.estado == EstadoSolicitud.solicitado)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _accionBtn(Icons.check_rounded, _kGreen, () => _aprobar(s)),
              const SizedBox(height: 4),
              _accionBtn(Icons.close_rounded, _kRed, () => _rechazar(s)),
            ]),
          )
        else
          const SizedBox(width: 14),
      ])),
    );
  }

  IconData _iconTipo(TipoAusencia t) => switch (t) {
    TipoAusencia.vacaciones             => Icons.beach_access_rounded,
    TipoAusencia.permisoRetribuido      => Icons.event_available_rounded,
    TipoAusencia.bajaMedica             => Icons.local_hospital_outlined,
    TipoAusencia.ausenciaJustificada    => Icons.assignment_late_outlined,
    TipoAusencia.ausenciaInjustificada  => Icons.block_outlined,
  };

  Widget _accionBtn(IconData icon, Color c, VoidCallback fn) => GestureDetector(
    onTap: fn,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: c, size: 14),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // PESTAÑA COBERTURA
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCoberturaTab(List<SolicitudVacaciones> todas) {
    final hoy = DateTime.now();
    // Empleados ausentes por día (próximos 14 días)
    final dias = List.generate(14, (i) => hoy.add(Duration(days: i)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Cobertura del equipo — próximos 14 días',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text)),
        const SizedBox(height: 12),
        ...dias.map((d) {
          final ausentes = todas.where((s) =>
              !d.isBefore(s.fechaInicio) && !d.isAfter(s.fechaFin)).toList();
          final esHoy = d.day == hoy.day && d.month == hoy.month;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: esHoy
                  ? _kGreen.withValues(alpha: _isDark ? 0.1 : 0.04)
                  : _surf,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: esHoy ? _kGreen.withValues(alpha: 0.25) : _border,
              ),
            ),
            child: Row(children: [
              SizedBox(width: 36, child: Text(
                  DateFormat('dd', 'es_ES').format(d),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: esHoy ? _kGreen : _text))),
              Text(DateFormat('EEE', 'es_ES').format(d),
                  style: TextStyle(fontSize: 11, color: _sub)),
              const SizedBox(width: 12),
              if (ausentes.isEmpty)
                Text('Sin ausencias', style: TextStyle(fontSize: 11.5, color: _sub))
              else
                Expanded(child: Wrap(spacing: 6, runSpacing: 4,
                  children: ausentes.map((s) {
                    final c = _colorTipo(s.tipo);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(s.empleadoNombre ?? 'Empleado',
                          style: TextStyle(fontSize: 10.5, color: c,
                              fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                )),
            ]),
          );
        }),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<SolicitudVacaciones> _filtrar(List<SolicitudVacaciones> todas) {
    return todas.where((s) {
      if (_tipoFiltro != null && s.tipo != _tipoFiltro) return false;
      if (_empleadoIdFiltro != null && s.empleadoId != _empleadoIdFiltro) return false;
      if (_busqueda.isNotEmpty) {
        final q = _busqueda.toLowerCase();
        return (s.empleadoNombre ?? '').toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  void _nuevaSolicitud() => Navigator.push(context, MaterialPageRoute(
      builder: (_) => NuevaSolicitudForm(empresaId: widget.empresaId)));

  Future<void> _aprobar(SolicitudVacaciones s) async {
    try {
      await VacacionesService().aprobarSolicitud(widget.empresaId, s.id);
      if (mounted) FluxToast.exito(context, 'Solicitud aprobada', title: 'Aprobada');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  Future<void> _rechazar(SolicitudVacaciones s) async {
    try {
      await VacacionesService().rechazarSolicitud(widget.empresaId, s.id);
      if (mounted) FluxToast.aviso(context, 'Solicitud rechazada', title: 'Rechazada');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }
}
