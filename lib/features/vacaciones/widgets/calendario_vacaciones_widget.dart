import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/vacacion_model.dart';
import '../../../services/vacaciones_service.dart';
import '../../../services/festivos_service.dart';
import '../../../core/utils/permisos_service.dart';
import '../pantallas/nueva_solicitud_form.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CALENDARIO VISUAL DE VACACIONES Y AUSENCIAS
// Usa table_calendar con festivos CLM 2026 hardcodeados.
// ═══════════════════════════════════════════════════════════════════════════════

class CalendarioVacacionesWidget extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;

  const CalendarioVacacionesWidget({
    super.key,
    required this.empresaId,
    this.sesion,
  });

  @override
  State<CalendarioVacacionesWidget> createState() =>
      _CalendarioVacacionesWidgetState();
}

class _CalendarioVacacionesWidgetState
    extends State<CalendarioVacacionesWidget> {
  final VacacionesService _svc = VacacionesService();
  final FestivosService _festSvc = FestivosService();

  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();

  /// Mapa día→solicitudes (para el empleado filtrado o todos).
  Map<DateTime, List<SolicitudVacaciones>> _eventosPorDia = {};

  /// Mapa día→nº empleados APROBADOS ausentes ese día (para solapamiento).
  Map<DateTime, int> _solapamientoPorDia = {};

  String? _empleadoFiltroId;
  List<Map<String, dynamic>> _empleados = [];
  int _totalEmpleados = 0;
  bool _cargando = false;

  // ── Festivos dinámicos desde Firestore ──────────────────────────────────
  Set<DateTime> _festivosSet = {};
  Map<DateTime, String> _festivosNombres = {};

  bool _esFestivo(DateTime d) =>
      _festivosSet.contains(DateTime(d.year, d.month, d.day));

  String? _nombreFestivo(DateTime d) =>
      _festivosNombres[DateTime(d.year, d.month, d.day)];

  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
    _cargarFestivos();
    _cargarEventos();
  }

  // ── Carga de festivos dinámicos ─────────────────────────────────────────────

  Future<void> _cargarFestivos() async {
    try {
      final anio = _focusedDay.year;
      // Intentar importar si no existen
      await _festSvc.asegurarFestivosImportados(
        widget.empresaId,
        codigoComunidad: await _festSvc.obtenerComunidadAutonoma(widget.empresaId),
      );

      final festivos = await _festSvc.obtenerFestivos(widget.empresaId, anio);
      if (mounted) {
        setState(() {
          _festivosSet = festivos.map((f) => f.fechaNormalizada).toSet();
          _festivosNombres = {
            for (final f in festivos) f.fechaNormalizada: f.nombre,
          };
        });
      }
    } catch (e) {
      debugPrint('CalendarioVacaciones: error cargando festivos $e');
    }
  }

  // ── Carga de empleados activos ─────────────────────────────────────────────

  Future<void> _cargarEmpleados() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('activo', isEqualTo: true)
          .get();

      final lista = snap.docs
          .map((d) => <String, dynamic>{
                'id': d.id,
                'nombre': d.data()['nombre'] as String? ?? 'Empleado',
              })
          .toList()
        ..sort((a, b) =>
            (a['nombre'] as String).compareTo(b['nombre'] as String));

      if (mounted) {
        setState(() {
          _empleados = lista;
          _totalEmpleados = lista.length;
        });
      }
    } catch (e) {
      debugPrint('CalendarioVacaciones: error cargando empleados $e');
    }
  }

  // ── Carga de eventos del mes visible ──────────────────────────────────────

  Future<void> _cargarEventos() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final anio = _focusedDay.year;
      final mes = _focusedDay.month;

      // Solicitudes para el filtro activo (todos los estados)
      final solicitudesFiltradas = await _svc.obtenerTodasAusenciasMes(
        widget.empresaId,
        anio,
        mes,
        empleadoId: _empleadoFiltroId,
      );

      // Solicitudes aprobadas de todos los empleados para solapamiento
      final todasAprobadas = await _svc.obtenerAusenciasMes(
        widget.empresaId,
        anio,
        mes,
      );

      // Construir mapa de eventos filtrados
      final Map<DateTime, List<SolicitudVacaciones>> eventMap = {};
      for (final s in solicitudesFiltradas) {
        _iterarDias(s.fechaInicio, s.fechaFin, (d) {
          if (d.month == mes && d.year == anio) {
            eventMap[d] = [...(eventMap[d] ?? []), s];
          }
        });
      }

      // Construir mapa de solapamiento (empleados únicos aprobados por día)
      final Map<DateTime, Set<String>> empleadosPorDia = {};
      for (final s in todasAprobadas) {
        _iterarDias(s.fechaInicio, s.fechaFin, (d) {
          if (d.month == mes && d.year == anio) {
            empleadosPorDia[d] = {...(empleadosPorDia[d] ?? {}), s.empleadoId};
          }
        });
      }
      final Map<DateTime, int> solapMap =
          empleadosPorDia.map((k, v) => MapEntry(k, v.length));

      if (mounted) {
        setState(() {
          _eventosPorDia = eventMap;
          _solapamientoPorDia = solapMap;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('CalendarioVacaciones: error cargando eventos $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _iterarDias(
      DateTime inicio, DateTime fin, void Function(DateTime) fn) {
    DateTime d = DateTime(inicio.year, inicio.month, inicio.day);
    final end = DateTime(fin.year, fin.month, fin.day);
    while (!d.isAfter(end)) {
      fn(d);
      d = d.add(const Duration(days: 1));
    }
  }

  List<SolicitudVacaciones> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventosPorDia[key] ?? [];
  }

  /// ¿Ese día supera el 50 % del equipo ausente?
  bool _haySolapamientoAlto(DateTime day) {
    if (_totalEmpleados == 0) return false;
    final key = DateTime(day.year, day.month, day.day);
    final count = _solapamientoPorDia[key] ?? 0;
    return count >= 2 && (count / _totalEmpleados) >= 0.5;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSelectorEmpleado(),
        _buildLeyenda(),
        if (_cargando)
          const LinearProgressIndicator(
              minHeight: 2, color: Color(0xFF00796B)),
        _buildTableCalendar(),
        if (_selectedDay != null)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPanelDia(_selectedDay!),
                  const SizedBox(height: 80), // espacio FAB
                ],
              ),
            ),
          )
        else
          const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSelectorEmpleado() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _empleadoFiltroId,
          isExpanded: true,
          hint: const Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text('Todos los empleados',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.groups, size: 18, color: Color(0xFF00796B)),
                  SizedBox(width: 8),
                  Text('Todos los empleados', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            ..._empleados.map(
              (e) => DropdownMenuItem<String?>(
                value: e['id'] as String,
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e['nombre'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _empleadoFiltroId = v);
            _cargarEventos();
          },
        ),
      ),
    );
  }

  // ── Leyenda de colores ─────────────────────────────────────────────────────

  Widget _buildLeyenda() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        children: [
          _leyendaItem(Colors.grey[400]!, 'Festivo CLM'),
          _leyendaItem(Colors.orange, 'Permiso / Justificada'),
          _leyendaItem(Colors.red, 'Injustificada'),
          _leyendaItem(Colors.blue, 'IT / Baja médica'),
          _leyendaItem(Colors.orange, 'Festivo'),
          _leyendaItem(Colors.amber[400]!, 'Pendiente aprobación'),
          _leyendaItem(Colors.red.shade300, '⚠ Solapamiento >50 %',
              esTexto: true),
        ],
      ),
    );
  }

  Widget _leyendaItem(Color color, String texto, {bool esTexto = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (esTexto)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 10, color: Colors.black87)),
      ],
    );
  }

  // ── TableCalendar ──────────────────────────────────────────────────────────

  Widget _buildTableCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TableCalendar<SolicitudVacaciones>(
          locale: 'es_ES',
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2027, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          eventLoader: _getEventsForDay,
          daysOfWeekHeight: 32,
          rowHeight: 46,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = isSameDay(_selectedDay, selectedDay)
                  ? null // deseleccionar al tocar el mismo día
                  : selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onDayLongPressed: (day, focusedDay) {
            setState(() => _focusedDay = focusedDay);
            _nuevaSolicitudParaDia(day);
          },
          onPageChanged: (focusedDay) {
            final prevYear = _focusedDay.year;
            _focusedDay = focusedDay;
            // Limpiar selección al cambiar de mes
            _selectedDay = null;
            _cargarEventos();
            // Recargar festivos si cambia el año
            if (focusedDay.year != prevYear) _cargarFestivos();
          },
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700),
            leftChevronIcon: const Icon(Icons.chevron_left,
                color: Color(0xFF00796B)),
            rightChevronIcon: const Icon(Icons.chevron_right,
                color: Color(0xFF00796B)),
            headerPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey),
            weekendStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red),
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: true,
            markerDecoration: BoxDecoration(
              color: Colors.transparent,
            ),
            markersMaxCount: 0, // usamos markerBuilder personalizado
          ),
          calendarBuilders: CalendarBuilders<SolicitudVacaciones>(
            defaultBuilder: (ctx, day, _) =>
                _buildDayCellWrapper(day, isSelected: false, isToday: false),
            todayBuilder: (ctx, day, _) =>
                _buildDayCellWrapper(day, isSelected: false, isToday: true),
            selectedBuilder: (ctx, day, _) =>
                _buildDayCellWrapper(day, isSelected: true, isToday: false),
            outsideBuilder: (ctx, day, _) =>
                _buildDayCellWrapper(day,
                    isSelected: false, isToday: false, isOutside: true),
            markerBuilder: (ctx, day, events) =>
                _buildMarkersWidget(day, events),
          ),
        ),
      ),
    );
  }

  // ── Celdas del calendario ──────────────────────────────────────────────────

  Widget _buildDayCellWrapper(
    DateTime day, {
    required bool isSelected,
    required bool isToday,
    bool isOutside = false,
  }) {
    if (isOutside) {
      return Container(
        margin: const EdgeInsets.all(3),
        child: Center(
          child: Text(
            '${day.day}',
            style: const TextStyle(
                color: Color(0xFFCCCCCC), fontSize: 13),
          ),
        ),
      );
    }

    final key = DateTime(day.year, day.month, day.day);
    final esFestivo = _esFestivo(key);
    final esFinde = day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday;
    final haySolap = _haySolapamientoAlto(key);

    Color? bgColor;
    Color textColor;
    BoxBorder? border;
    FontWeight fw = FontWeight.w500;

    if (isSelected) {
      bgColor = const Color(0xFF00796B);
      textColor = Colors.white;
      fw = FontWeight.w700;
    } else if (isToday) {
      bgColor = const Color(0xFF00796B).withValues(alpha: 0.08);
      textColor = const Color(0xFF00796B);
      fw = FontWeight.w700;
    } else if (esFestivo) {
      bgColor = Colors.orange[50];
      textColor = Colors.orange[800]!;
    } else if (esFinde) {
      textColor = Colors.red[300]!;
    } else {
      textColor = Colors.black87;
    }

    // Borde rojo solapamiento (no aplica si ya seleccionado)
    if (haySolap && !isSelected) {
      border = Border.all(color: Colors.red.shade400, width: 2);
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                  color: textColor, fontSize: 13, fontWeight: fw),
            ),
          ),
          // Punto festivo (esquina superior derecha)
          if (esFestivo)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          // Icono solapamiento (esquina superior izquierda)
          if (haySolap && !isSelected)
            Positioned(
              top: 1,
              left: 1,
              child: Icon(Icons.warning_amber_rounded,
                  size: 9, color: Colors.red.shade400),
            ),
        ],
      ),
    );
  }

  Widget? _buildMarkersWidget(
      DateTime day, List<SolicitudVacaciones> events) {
    if (events.isEmpty) return null;

    // Colores únicos por tipo de ausencia presente ese día
    final colores = events
        .map((e) => _colorTipo(e.tipo, e.estado))
        .toSet()
        .toList();

    return Positioned(
      bottom: 3,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: colores.take(4).map((c) {
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          );
        }).toList(),
      ),
    );
  }

  // ── Panel detalle del día seleccionado ────────────────────────────────────

  Widget _buildPanelDia(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    final eventos = _eventosPorDia[key] ?? [];
    final esFestivo = _esFestivo(key);
    final nombreF = _nombreFestivo(key);
    final solapCount = _solapamientoPorDia[key] ?? 0;
    final haySolapAlto = _haySolapamientoAlto(key);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: haySolapAlto
                ? Colors.red.shade200
                : Colors.grey[200]!,
            width: haySolapAlto ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del día
          Row(
            children: [
              const Icon(Icons.today, size: 16, color: Color(0xFF00796B)),
              const SizedBox(width: 6),
              Text(
                '${day.day.toString().padLeft(2, '0')}/'
                '${day.month.toString().padLeft(2, '0')}/'
                '${day.year}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Spacer(),
              // Badge solapamiento
              if (solapCount >= 2)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 13, color: Colors.red.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '$solapCount ausentes',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              // Botón nueva solicitud
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _nuevaSolicitudParaDia(day),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Color(0xFF00796B)),
                      SizedBox(width: 2),
                      Text('Solicitar',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF00796B),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Festivo
          if (esFestivo) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.celebration, size: 14, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text(
                  nombreF ?? 'Festivo',
                  style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          // Eventos del día
          if (eventos.isEmpty && !esFestivo) ...[
            const SizedBox(height: 8),
            Text(
              'No hay solicitudes para este día.\nPresiona largo para crear una nueva.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 8),
            ...eventos.map((e) => _buildEventoTile(e)),
          ],
        ],
      ),
    );
  }

  Widget _buildEventoTile(SolicitudVacaciones e) {
    final color = _colorTipo(e.tipo, e.estado);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.empleadoNombre ?? e.empleadoId,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  '${e.tipo.etiqueta} · ${e.fechaInicio.day}/${e.fechaInicio.month} → '
                  '${e.fechaFin.day}/${e.fechaFin.month}',
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          // Badge estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _colorEstado(e.estado).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              e.estado.etiqueta,
              style: TextStyle(
                  fontSize: 10,
                  color: _colorEstado(e.estado),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Acciones ───────────────────────────────────────────────────────────────

  void _nuevaSolicitudParaDia(DateTime day) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => NuevaSolicitudForm(
        empresaId: widget.empresaId,
        empleadoIdFijo: _empleadoFiltroId,
        fechaInicioFija: day,
      ),
    );
    if (mounted) _cargarEventos();
  }

  // ── Helpers de color ───────────────────────────────────────────────────────

  /// Color del punto/fondo según tipo de ausencia Y estado.
  /// Los pendientes se muestran con tono más suave (amber).
  Color _colorTipo(TipoAusencia tipo, EstadoSolicitud estado) {
    if (estado == EstadoSolicitud.rechazado) return Colors.grey[400]!;
    if (estado == EstadoSolicitud.solicitado) return Colors.amber[600]!;
    // aprobado → color por tipo
    switch (tipo) {
      case TipoAusencia.vacaciones:
        return Colors.green;
      case TipoAusencia.ausenciaJustificada:
        return Colors.orange;
      case TipoAusencia.ausenciaInjustificada:
        return Colors.red;
      case TipoAusencia.permisoRetribuido:
        return Colors.orange.shade600;
      case TipoAusencia.bajaMedica:
        return Colors.blue;
    }
  }

  Color _colorEstado(EstadoSolicitud estado) {
    switch (estado) {
      case EstadoSolicitud.solicitado:
        return Colors.orange;
      case EstadoSolicitud.aprobado:
        return Colors.green;
      case EstadoSolicitud.rechazado:
        return Colors.red;
    }
  }
}

