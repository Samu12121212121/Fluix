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

      // Resolver fichaje efectivo por día (corrección > original, más reciente gana)
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

      // Generar lista de días del mes
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
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final diasTrabajados = _dias.where((d) => d.minutosNetos > 0).length;
    final totalMin = _dias.fold(0, (s, d) => s + d.minutosNetos);
    final extraMin = _dias.fold(0, (s, d) => s + (d.tieneHorasExtra ? d.minutosNetos - 480 : 0));
    final esMesActual = _mes.year == DateTime.now().year && _mes.month == DateTime.now().month;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          // Handle + cabecera
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mi historial — ${widget.empleadoNombre}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Selector de mes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _cambiarMes(-1),
                    ),
                    Text(
                      DateFormat("MMMM yyyy", 'es_ES').format(_mes),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: esMesActual ? null : () => _cambiarMes(1),
                    ),
                  ],
                ),
                // Totales del mes
                if (!_cargando && diasTrabajados > 0)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _totalItem('Días', '$diasTrabajados', Icons.calendar_today),
                        _totalItem('Total neto', _fmtMin(totalMin), Icons.timer),
                        _totalItem('H. extra', _fmtMin(extraMin), Icons.trending_up,
                            color: extraMin > 0 ? Colors.orange : Colors.grey),
                      ],
                    ),
                  ),
                const Divider(height: 1),
              ],
            ),
          ),

          // Lista de días
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    controller: controller,
                    itemCount: _dias.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) {
                      final d = _dias[i];
                      final esFuturo = d.fecha.isAfter(DateTime.now());
                      final sinDatos = d.minutosNetos == 0 && d.entrada == null;

                      if (esFuturo) return const SizedBox.shrink();

                      return ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 36,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE', 'es_ES').format(d.fecha).toUpperCase(),
                                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                              ),
                              Text(
                                '${d.fecha.day}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        title: sinDatos
                            ? Text('Sin fichar',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13))
                            : Row(
                                children: [
                                  const Icon(Icons.login, size: 14, color: Colors.green),
                                  const SizedBox(width: 3),
                                  Text(_fmtHora(d.entrada),
                                      style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.logout, size: 14, color: Colors.red),
                                  const SizedBox(width: 3),
                                  Text(
                                    d.salida != null ? _fmtHora(d.salida) : 'activo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: d.salida == null ? Colors.orange : null,
                                    ),
                                  ),
                                ],
                              ),
                        subtitle: sinDatos
                            ? null
                            : Text(
                                'Neto: ${_fmtMin(d.minutosNetos)}'
                                '${d.pausas.isNotEmpty ? '  ·  ${d.pausas.length} pausa${d.pausas.length > 1 ? 's' : ''}' : ''}'
                                '${d.fichajePendiente ? '  ·  pendiente' : ''}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                        trailing: d.tieneHorasExtra
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: Text(
                                  '+${_fmtMin(d.minutosNetos - 480)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ),

          // Nota legal al pie
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Text(
              'Registros conservados 4 años según RDL 8/2019 · Consulta tus datos en cualquier momento',
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalItem(String label, String valor, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.blue[700]),
        const SizedBox(height: 2),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
