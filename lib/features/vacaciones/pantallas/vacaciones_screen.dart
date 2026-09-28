import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_settings.dart';
import '../../../core/utils/permisos_service.dart';
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
  const VacacionesScreen({super.key, required this.empresaId, this.sesion});

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
    return StreamBuilder<List<SolicitudVacaciones>>(
      stream: _svc.obtenerSolicitudes(widget.empresaId),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error al cargar ausencias: ${snap.error}',
              style: const TextStyle(color: Colors.red)));
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final todas    = snap.data ?? [];
        final filtradas = _filtrar(todas);
        final hoy      = DateTime.now();

        // KPIs
        final mes      = hoy.month; final anio = hoy.year;
        final vacMes   = todas.where((s) => s.tipo == TipoAusencia.vacaciones &&
            (s.fechaInicio.month == mes || s.fechaFin.month == mes) &&
            s.fechaInicio.year == anio).length;
        final permMes  = todas.where((s) => s.tipo == TipoAusencia.permisoRetribuido &&
            (s.fechaInicio.month == mes || s.fechaFin.month == mes) &&
            s.fechaInicio.year == anio).length;
        final ausentesHoy = todas.where((s) =>
            !hoy.isBefore(s.fechaInicio) && !hoy.isAfter(s.fechaFin)).length;
        final pendientes  = todas.where((s) => s.estado == EstadoSolicitud.solicitado).length;

        return ColoredBox(
          color: _bg,
          child: Column(children: [
            // ── Header ──────────────────────────────────────────────────────
            _buildHeader(),
            // ── TabBar ──────────────────────────────────────────────────────
            _buildTabBar(pendientes),
            // ── Contenido ───────────────────────────────────────────────────
            Expanded(child: TabBarView(
              controller: _tabs,
              children: [
                // Tab 0: Calendario
                _buildCalendarioTab(filtradas, vacMes, permMes, ausentesHoy, pendientes),
                // Tab 1: Solicitudes
                _buildSolicitudesTab(filtradas, todas),
                // Tab 2: Cobertura
                _buildCoberturaTab(todas),
              ],
            )),
          ]),
        );
      },
    );
  }

  // ── Header (estilo D1 informe.html) ────────────────────────────────────────

  static const _docBand = Color(0xFF16A34A);

  Widget _buildHeader() {
    final hoy = DateFormat("MMMM yyyy", 'es_ES').format(DateTime.now());
    final hoyLabel = '${hoy[0].toUpperCase()}${hoy.substring(1)}';
    return Container(
      color: _docBand,
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('VACACIONES Y AUSENCIAS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text('Gestión de vacaciones, permisos y ausencias · $hoyLabel',
              style: const TextStyle(fontSize: 11, color: Color(0xFFBBF7D0))),
        ])),
        IconButton(
          icon: const Icon(Icons.download_outlined, color: Colors.white70, size: 20),
          tooltip: 'Exportar',
          onPressed: () => FluxToast.info(context, 'Exportar — próximamente'),
        ),
        if (_esAdmin)
          FilledButton.icon(
            onPressed: _nuevaSolicitud,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nueva solicitud',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _docBand,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ]),
    );
  }

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

  Widget _buildCalendarioTab(List<SolicitudVacaciones> filtradas,
      int vacMes, int permMes, int ausentesHoy, int pendientes) {
    return Column(children: [
      // Filtros
      _buildFiltros(),
      // KPIs
      _buildKpis(vacMes, permMes, ausentesHoy, pendientes),
      // Nav
      _buildNavCalendario(),
      // Calendario
      Expanded(child: _vistaCalendario == 'lista'
          ? _buildListaView(filtradas)
          : _buildMesView(filtradas)),
      // FAB area
      const SizedBox(height: 8),
    ]);
  }

  // ── Filtros ─────────────────────────────────────────────────────────────────

  Widget _buildFiltros() {
    const tipos = [
      (null,                             'Todos',      Colors.white),
      (TipoAusencia.vacaciones,          'Vacaciones', _kGreen),
      (TipoAusencia.permisoRetribuido,   'Permisos',   _kAmber),
      (TipoAusencia.bajaMedica,          'Baja médica',_kBlue),
      (TipoAusencia.ausenciaJustificada, 'Ausencias',  _kRed),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: _surf,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        // Employee filter (admin only)
        if (_esAdmin) ...[
          GestureDetector(
            onTap: () => FluxToast.info(context, 'Filtrar por empleado'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline, size: 14, color: _sub),
                const SizedBox(width: 5),
                Text('Todos los empleados',
                    style: TextStyle(fontSize: 11.5, color: _text)),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _sub),
              ]),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Search
        if (_esAdmin) Expanded(child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            const SizedBox(width: 8),
            Icon(Icons.search, size: 14, color: _sub),
            const SizedBox(width: 6),
            Expanded(child: TextField(
              onChanged: (v) => setState(() => _busqueda = v.trim()),
              style: TextStyle(fontSize: 12, color: _text),
              decoration: InputDecoration(
                hintText: 'Buscar empleado...',
                hintStyle: TextStyle(fontSize: 12, color: _sub),
                border: InputBorder.none, isDense: true,
              ),
            )),
          ]),
        )) else const Spacer(),
        const SizedBox(width: 12),
        // Type chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: tipos.map((t) {
            final sel = _tipoFiltro == t.$1;
            final c   = t.$3 == Colors.white ? _border : t.$3 as Color;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _tipoFiltro = _tipoFiltro == t.$1 ? null : t.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? c.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? c : _border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (t.$1 != null) Container(
                      width: 7, height: 7, margin: const EdgeInsets.only(right: 5),
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
          }).toList()),
        ),
      ]),
    );
  }

  // ── KPIs (estilo D1 informe.html) ───────────────────────────────────────────

  Widget _buildKpis(int vacMes, int permMes, int ausentesHoy, int pendientes) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA),
      child: Row(children: [
        _kpiDoc('$vacMes', 'Vacaciones\neste mes', _kGreen),
        const SizedBox(width: 10),
        _kpiDoc('$permMes', 'Permisos\neste mes', _kAmber),
        const SizedBox(width: 10),
        _kpiDoc('$ausentesHoy', 'Ausentes\nhoy', _kRed),
        const SizedBox(width: 10),
        _kpiDoc('$pendientes', 'Solicitudes\npendientes', _kPurple),
      ]),
    );
  }

  Widget _kpiDoc(String val, String lbl, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDark ? 0.15 : 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c,
            height: 1.1)),
        const SizedBox(height: 3),
        Text(lbl, style: TextStyle(fontSize: 10, color: _sub, height: 1.3)),
      ]),
    ),
  );

  // ── Navegación calendario ───────────────────────────────────────────────────

  Widget _buildNavCalendario() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _surf,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        // < Hoy >
        IconButton(
          icon: Icon(Icons.chevron_left, color: _text, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => setState(() => _mesActual =
              DateTime(_mesActual.year, _mesActual.month - 1)),
        ),
        OutlinedButton(
          onPressed: () => setState(() => _mesActual =
              DateTime(DateTime.now().year, DateTime.now().month)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _text,
            side: BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Hoy', style: TextStyle(fontSize: 12.5)),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: _text, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => setState(() => _mesActual =
              DateTime(_mesActual.year, _mesActual.month + 1)),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {},
          child: Row(children: [
            Text(DateFormat('MMMM yyyy', 'es_ES').format(_mesActual),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
            Icon(Icons.keyboard_arrow_down_rounded, color: _sub, size: 18),
          ]),
        ),
        const Spacer(),
        // Mes / Semana / Lista
        Container(
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final v in [('mes','Mes'), ('semana','Semana'), ('lista','Lista')])
              GestureDetector(
                onTap: () => setState(() => _vistaCalendario = v.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

    return Column(children: [
      // Cabecera días semana
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: ['LUN','MAR','MIÉ','JUE','VIE','SÁB','DOM'].map((d) =>
          Expanded(child: Center(child: Text(d, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: _sub,
              letterSpacing: 0.3))))).toList(),
        ),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: _surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            for (int fila = 0; fila < filas; fila++)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                      constraints: const BoxConstraints(minHeight: 80),
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
                        padding: const EdgeInsets.fromLTRB(6, 6, 4, 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Número del día
                          Center(child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: esHoy ? _kGreen : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(
                              esEsteMes ? '$dia' : '',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: esHoy ? Colors.white
                                    : esFin ? _kRed
                                    : esEsteMes ? _text : _sub,
                              ),
                            )),
                          )),
                          const SizedBox(height: 3),
                          // Eventos (máx 2 + "+N más")
                          ...eventos.take(2).map((s) {
                            final c = _colorTipo(s.tipo);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              child: Row(children: [
                                Container(width: 6, height: 6,
                                    decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                const SizedBox(width: 3),
                                Flexible(child: Text(
                                  s.empleadoNombre ?? 'Empleado',
                                  style: TextStyle(fontSize: 9.5, color: _text,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis, maxLines: 1,
                                )),
                              ]),
                            );
                          }),
                          if (eventos.length > 2)
                            Text('+${eventos.length - 2} más',
                                style: TextStyle(fontSize: 9, color: _sub)),
                        ]),
                      ),
                    ));
                  }),
                ],
              ]),
          ]),
        ),
      )),
    ]);
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Barra lateral de color (estilo d-line-icon del HTML)
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
            const SizedBox(height: 4),
            Row(children: [
              Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              Text(s.tipo.etiqueta,
                  style: TextStyle(fontSize: 11.5, color: c,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Icon(Icons.date_range_outlined, size: 12, color: _sub),
              const SizedBox(width: 3),
              Text(fechaStr, style: TextStyle(fontSize: 11.5, color: _sub)),
              const SizedBox(width: 8),
              Text('${s.diasNaturales}d',
                  style: TextStyle(fontSize: 11, color: _sub,
                      fontStyle: FontStyle.italic)),
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
      ]),
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
