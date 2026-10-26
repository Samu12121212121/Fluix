import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';

class HistorialEmpleadoSheet extends StatefulWidget {
  final String empresaId;
  final String empleadoId;
  final String empleadoNombre;

  const HistorialEmpleadoSheet({
    super.key,
    required this.empresaId,
    required this.empleadoId,
    required this.empleadoNombre,
  });

  @override
  State<HistorialEmpleadoSheet> createState() => _HistorialEmpleadoSheetState();
}

class _HistorialEmpleadoSheetState extends State<HistorialEmpleadoSheet> {
  final _svc = FichajeService();

  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  List<ResumenDiaFichaje> _dias = [];
  bool _cargando = false;

  static const _kBlue   = Color(0xFF1565C0);
  static const _kGreen  = Color(0xFF22C55E);
  static const _kOrange = Color(0xFFF59E0B);
  static const _kGray   = Color(0xFF9CA3AF);
  static const _kBorder = Color(0xFFE5E7EB);
  static const _kText   = Color(0xFF111827);
  static const _kSub    = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final desde = DateTime(_mes.year, _mes.month, 1);
      final hasta = DateTime(_mes.year, _mes.month + 1, 0);
      final fichajes = await _svc.obtenerFichajesEmpleado(
        empresaId: widget.empresaId,
        empleadoId: widget.empleadoId,
        desde: desde,
        hasta: hasta,
      );

      final Map<String, Fichaje> efectivos = {};
      for (final f in fichajes) {
        final key = f.fecha;
        final actual = efectivos[key];
        if (actual == null) {
          efectivos[key] = f;
        } else if (f.esCorreccion && !actual.esCorreccion) {
          efectivos[key] = f;
        } else if (f.esCorreccion && actual.esCorreccion) {
          final fAt = f.corregidoAt;
          final aAt = actual.corregidoAt;
          if (fAt != null && aAt != null && fAt.compareTo(aAt) > 0) {
            efectivos[key] = f;
          }
        }
      }

      final diasMes = <ResumenDiaFichaje>[];
      final fmt = DateFormat('yyyy-MM-dd');
      for (int d = 1; d <= hasta.day; d++) {
        final dia = DateTime(_mes.year, _mes.month, d);
        final key = fmt.format(dia);
        final f = efectivos[key];
        if (f != null) {
          diasMes.add(ResumenDiaFichaje.desdeFFichaje(f));
        } else {
          diasMes.add(ResumenDiaFichaje(
            fecha: dia,
            empleadoId: widget.empleadoId,
            empleadoNombre: widget.empleadoNombre,
          ));
        }
      }
      if (mounted) setState(() => _dias = diasMes);
    } catch (e) {
      debugPrint('[HistorialEmpleado] error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarMes(int delta) {
    setState(() {
      _mes = DateTime(_mes.year, _mes.month + delta);
      _dias = [];
    });
    _cargar();
  }

  String _fmtHora(DateTime? dt) =>
      dt != null ? DateFormat('HH:mm').format(dt) : '--:--';

  String _fmtMin(int min) {
    if (min == 0) return '—';
    final h = min ~/ 60;
    final m = min % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2,'0')}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final diasTrabajados = _dias.where((d) => d.minutosNetos > 0).length;
    final totalMin = _dias.fold(0, (s, d) => s + d.minutosNetos);
    final extraMin = _dias.fold(0, (s, d) => s + (d.tieneHorasExtra ? d.minutosNetos - 480 : 0));
    final esMesActual = _mes.year == DateTime.now().year && _mes.month == DateTime.now().month;
    final diasMostrados = _dias.where((d) => !d.fecha.isAfter(DateTime.now())).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          // ── Cabecera ──────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Icon(Icons.history_rounded, size: 20, color: _kBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.empleadoNombre,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: _kGray),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              // Selector de mes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: () => _cambiarMes(-1),
                        color: _kBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        constraints: const BoxConstraints(minHeight: 40),
                      ),
                      Text(
                        () {
                          final s = DateFormat('MMMM yyyy', 'es_ES').format(_mes);
                          return s[0].toUpperCase() + s.substring(1);
                        }(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: esMesActual ? null : () => _cambiarMes(1),
                        color: esMesActual ? _kGray : _kBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        constraints: const BoxConstraints(minHeight: 40),
                      ),
                    ],
                  ),
                ),
              ),
              // Resumen del mes
              if (!_cargando && diasTrabajados > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    _summaryChip(Icons.calendar_today_outlined, '$diasTrabajados días', _kBlue),
                    const SizedBox(width: 8),
                    _summaryChip(Icons.timer_outlined, _fmtMin(totalMin), _kBlue),
                    const SizedBox(width: 8),
                    _summaryChip(
                      Icons.trending_up_rounded,
                      extraMin > 0 ? '+${_fmtMin(extraMin)}' : '0 extra',
                      extraMin > 0 ? _kOrange : _kGray,
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: _kBorder),
            ]),
          ),

          // ── Lista de días ─────────────────────────────────────────────────
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: _kBlue))
                : diasMostrados.isEmpty
                    ? const Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.calendar_today_outlined, size: 48, color: _kGray),
                          SizedBox(height: 12),
                          Text('Sin fichajes este mes', style: TextStyle(color: _kSub, fontSize: 14)),
                        ]),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: diasMostrados.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 68, endIndent: 16, color: _kBorder),
                        itemBuilder: (_, i) => _buildDayRow(diasMostrados[i]),
                      ),
          ),

          // ── Pie legal ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Text(
              'Registros conservados 4 años · RDL 8/2019',
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(ResumenDiaFichaje d) {
    final sinDatos = d.minutosNetos == 0 && d.entrada == null;
    final esFinde = d.fecha.weekday == DateTime.saturday || d.fecha.weekday == DateTime.sunday;
    final esHoy   = DateFormat('yyyy-MM-dd').format(d.fecha) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    final dayLabel = DateFormat('EEE', 'es_ES').format(d.fecha).toUpperCase();
    final dayNum   = '${d.fecha.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Columna fecha
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: esHoy ? _kBlue : esFinde ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              dayLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: esHoy ? Colors.white70 : esFinde ? _kGray : _kSub,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dayNum,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: esHoy ? Colors.white : esFinde ? _kGray : _kText,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        // Info principal
        Expanded(
          child: sinDatos
              ? Row(children: [
                  const Icon(Icons.remove_circle_outline, size: 14, color: _kGray),
                  const SizedBox(width: 6),
                  Text(
                    esFinde ? 'Día libre' : 'Sin fichar',
                    style: const TextStyle(fontSize: 13, color: _kGray),
                  ),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  // Entrada → Salida
                  Row(children: [
                    const Icon(Icons.login_rounded, size: 13, color: _kGreen),
                    const SizedBox(width: 4),
                    Text(_fmtHora(d.entrada), style: const TextStyle(fontSize: 13, color: _kText)),
                    const SizedBox(width: 8),
                    const Icon(Icons.logout_rounded, size: 13, color: Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Text(
                      d.salida != null ? _fmtHora(d.salida) : 'activo',
                      style: TextStyle(
                        fontSize: 13,
                        color: d.salida == null ? _kOrange : _kText,
                      ),
                    ),
                  ]),
                  if (d.pausas.isNotEmpty || d.fichajePendiente) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (d.pausas.isNotEmpty) '${d.pausas.length} pausa${d.pausas.length > 1 ? 's' : ''}',
                        if (d.fichajePendiente) 'pendiente',
                      ].join('  ·  '),
                      style: const TextStyle(fontSize: 11, color: _kSub),
                    ),
                  ],
                ]),
        ),
        const SizedBox(width: 8),
        // Tiempo neto
        if (!sinDatos)
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(
              _fmtMin(d.minutosNetos),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: d.tieneHorasExtra ? _kOrange : _kBlue,
              ),
            ),
            if (d.tieneHorasExtra)
              Text(
                '+${_fmtMin(d.minutosNetos - 480)}',
                style: const TextStyle(fontSize: 10, color: _kOrange),
              ),
          ]),
      ]),
    );
  }

  Widget _summaryChip(IconData icon, String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}
