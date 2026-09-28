import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import 'package:planeag_flutter/core/widgets/fluix_app_bar.dart';

// ═══════════════════════════════════════════════════════════════════════════
// RESUMEN MENSUAL DE FICHAJES — vista admin
//
// Muestra un cuadro por empleado con totales del mes: días trabajados,
// horas netas, horas extra y fichajes pendientes (entrada sin salida).
// Permite navegar entre meses y exportar a CSV.
// ═══════════════════════════════════════════════════════════════════════════

const _kGreen  = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kRed    = Color(0xFFEF4444);
const _kBlue   = Color(0xFF3B82F6);
const _kBg     = Color(0xFFF8F9FA);
const _kBorder = Color(0xFFE5E7EB);
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);

// ── Modelo de resumen por empleado ───────────────────────────────────────────

class _ResumenEmpleado {
  final String empleadoId;
  final String nombre;
  int diasTrabajados = 0;
  int minutosNetos   = 0;
  int minutosExtra   = 0;  // neto > jornadaDiaria (480 min por defecto)
  int pendientes     = 0;  // fichajes con entrada pero sin salida

  _ResumenEmpleado({required this.empleadoId, required this.nombre});

  double get horasNetas  => minutosNetos / 60.0;
  double get horasExtra  => minutosExtra / 60.0;
}

// ── Widget principal ─────────────────────────────────────────────────────────

class ResumenMensualEmpleadosScreen extends StatefulWidget {
  final String empresaId;
  const ResumenMensualEmpleadosScreen({super.key, required this.empresaId});

  @override
  State<ResumenMensualEmpleadosScreen> createState() =>
      _ResumenMensualEmpleadosScreenState();
}

class _ResumenMensualEmpleadosScreenState
    extends State<ResumenMensualEmpleadosScreen> {
  final _svc = FichajeService();

  DateTime _mes     = DateTime(DateTime.now().year, DateTime.now().month);
  bool     _cargando = false;
  String?  _error;

  List<_ResumenEmpleado> _resumenes = [];
  final _fmt = DateFormat('MMMM yyyy', 'es_ES');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ── Carga y cálculo ─────────────────────────────────────────────────────

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final fichajes = await _svc.fichajesMes(
        empresaId: widget.empresaId,
        mes: _mes,
      );

      // Resolver fichaje efectivo por empleado+día (corrección > original)
      final Map<String, Fichaje> efectivos = {};
      for (final f in fichajes) {
        final key = '${f.empleadoId}_${f.fecha}';
        final actual = efectivos[key];
        if (actual == null) {
          efectivos[key] = f;
        } else if (f.esCorreccion && !actual.esCorreccion) {
          efectivos[key] = f;
        } else if (f.esCorreccion &&
            actual.esCorreccion &&
            f.corregidoAt != null &&
            actual.corregidoAt != null &&
            f.corregidoAt!.compareTo(actual.corregidoAt!) > 0) {
          efectivos[key] = f;
        }
      }

      // Agrupar por empleado
      final Map<String, _ResumenEmpleado> map = {};
      for (final f in efectivos.values) {
        final r = map.putIfAbsent(
          f.empleadoId,
          () => _ResumenEmpleado(
              empleadoId: f.empleadoId, nombre: f.empleadoNombre),
        );
        final res = ResumenDiaFichaje.desdeFFichaje(f);
        r.diasTrabajados++;
        r.minutosNetos += res.minutosNetos;
        if (res.tieneHorasExtra) {
          r.minutosExtra += (res.minutosNetos - 480).clamp(0, 9999);
        }
        if (res.fichajePendiente) r.pendientes++;
      }

      final lista = map.values.toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));

      setState(() { _resumenes = lista; _cargando = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  void _mesPrev() {
    setState(() => _mes = DateTime(_mes.year, _mes.month - 1));
    _cargar();
  }

  void _mesSig() {
    final siguiente = DateTime(_mes.year, _mes.month + 1);
    if (siguiente.isAfter(DateTime.now())) return;
    setState(() => _mes = siguiente);
    _cargar();
  }

  Future<void> _exportar() async {
    try {
      final csv = await _svc.exportarCsvInspeccion(
        empresaId: widget.empresaId,
        desde: DateTime(_mes.year, _mes.month, 1),
        hasta: DateTime(_mes.year, _mes.month + 1, 0),
      );
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final nombre =
          'fichajes_${_mes.year}_${_mes.month.toString().padLeft(2, "0")}.csv';
      await Printing.sharePdf(bytes: bytes, filename: nombre);
    } catch (_) {
      if (mounted) FluxToast.error(context, 'Error al exportar');
    }
  }

  // ── Totales globales ─────────────────────────────────────────────────────

  int get _totalMinutos =>
      _resumenes.fold(0, (s, r) => s + r.minutosNetos);
  int get _totalExtra =>
      _resumenes.fold(0, (s, r) => s + r.minutosExtra);
  int get _totalPendientes =>
      _resumenes.fold(0, (s, r) => s + r.pendientes);

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: FluixAppBar(
        titulo: 'Resumen mensual',
        extraActions: [
          if (!_cargando && _resumenes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded, size: 20),
              tooltip: 'Exportar CSV',
              onPressed: _exportar,
            ),
        ],
      ),
      body: Column(
        children: [
          _mesSelector(),
          if (_cargando)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: _errorView())
          else if (_resumenes.isEmpty)
            Expanded(child: _emptyView())
          else ...[
            _summaryStrip(),
            Expanded(child: _lista()),
          ],
        ],
      ),
    );
  }

  // ── Selector de mes ──────────────────────────────────────────────────────

  Widget _mesSelector() => Container(
        color: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _navBtn(Icons.chevron_left_rounded, _mesPrev),
            const SizedBox(width: 16),
            Text(
              _fmt.format(_mes).toUpperCase(),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                  letterSpacing: 0.5),
            ),
            const SizedBox(width: 16),
            _navBtn(
              Icons.chevron_right_rounded,
              DateTime(_mes.year, _mes.month + 1)
                      .isAfter(DateTime.now())
                  ? null
                  : _mesSig,
            ),
          ],
        ),
      );

  Widget _navBtn(IconData ic, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: onTap == null ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(ic,
              size: 18,
              color: onTap == null ? Colors.grey.shade400 : _kText),
        ),
      );

  // ── Franja de totales ────────────────────────────────────────────────────

  Widget _summaryStrip() => Container(
        color: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            _statChip(Icons.people_outline_rounded,
                '${_resumenes.length}', 'empleados', _kBlue),
            const SizedBox(width: 12),
            _statChip(Icons.access_time_rounded,
                '${(_totalMinutos / 60).toStringAsFixed(1)}h',
                'total', _kGreen),
            const SizedBox(width: 12),
            _statChip(Icons.trending_up_rounded,
                '${(_totalExtra / 60).toStringAsFixed(1)}h',
                'extra', _kOrange),
            if (_totalPendientes > 0) ...[
              const SizedBox(width: 12),
              _statChip(Icons.warning_amber_rounded,
                  '$_totalPendientes', 'pendientes', _kRed),
            ],
          ],
        ),
      );

  Widget _statChip(
          IconData ic, String val, String lbl, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ic, size: 16, color: color),
              const SizedBox(height: 3),
              Text(val,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color)),
              Text(lbl,
                  style: const TextStyle(fontSize: 9, color: _kSub)),
            ],
          ),
        ),
      );

  // ── Lista de empleados ───────────────────────────────────────────────────

  Widget _lista() => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _resumenes.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _tarjeta(_resumenes[i]),
      );

  Widget _tarjeta(_ResumenEmpleado r) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: r.pendientes > 0
                  ? _kRed.withValues(alpha: 0.4)
                  : _kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            // Avatar inicial
            CircleAvatar(
              radius: 22,
              backgroundColor: _kBlue.withValues(alpha: 0.1),
              child: Text(
                r.nombre.isNotEmpty
                    ? r.nombre[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kBlue),
              ),
            ),
            const SizedBox(width: 14),
            // Nombre + alerta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.nombre,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kText)),
                  if (r.pendientes > 0)
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 11, color: _kRed),
                      const SizedBox(width: 3),
                      Text(
                          '${r.pendientes} fichaje${r.pendientes > 1 ? "s" : ""} sin salida',
                          style: const TextStyle(
                              fontSize: 10, color: _kRed)),
                    ]),
                ],
              ),
            ),
            // Stats
            _statCol('${r.diasTrabajados}', 'días', _kSub),
            const SizedBox(width: 12),
            _statCol('${r.horasNetas.toStringAsFixed(1)}h', 'netas', _kGreen),
            if (r.minutosExtra > 0) ...[
              const SizedBox(width: 12),
              _statCol('${r.horasExtra.toStringAsFixed(1)}h', 'extra', _kOrange),
            ],
          ],
        ),
      );

  Widget _statCol(String val, String lbl, Color color) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(val,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(lbl,
              style: const TextStyle(fontSize: 9, color: _kSub)),
        ],
      );

  // ── Estados vacío / error ────────────────────────────────────────────────

  Widget _emptyView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Sin fichajes este mes',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kText)),
            const SizedBox(height: 6),
            Text('No hay registros para ${_fmt.format(_mes)}',
                style:
                    const TextStyle(fontSize: 13, color: _kSub)),
          ],
        ),
      );

  Widget _errorView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: _kRed),
            const SizedBox(height: 12),
            const Text('Error al cargar',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kText)),
            const SizedBox(height: 6),
            Text(_error ?? '',
                style: const TextStyle(fontSize: 12, color: _kSub),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
}

