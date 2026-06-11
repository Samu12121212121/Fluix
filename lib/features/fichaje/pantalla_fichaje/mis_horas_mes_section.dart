import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../fichajes/modelos/fichaje.dart';
import '../../fichajes/servicios/fichaje_service.dart';

// ── Dato de un día trabajado ──────────────────────────────────────────────────

class _DatoDia {
  final DateTime fecha;
  final DateTime? entrada;
  final DateTime? salida;
  final double horasNetas;
  final bool jornadaAbierta;

  const _DatoDia({
    required this.fecha,
    this.entrada,
    this.salida,
    required this.horasNetas,
    required this.jornadaAbierta,
  });
}

// ── Widget principal ──────────────────────────────────────────────────────────

class MisHorasMesSection extends StatefulWidget {
  final String empresaId;
  final String empleadoId;

  const MisHorasMesSection({
    super.key,
    required this.empresaId,
    required this.empleadoId,
  });

  @override
  State<MisHorasMesSection> createState() => _MisHorasMesSectionState();
}

class _MisHorasMesSectionState extends State<MisHorasMesSection> {
  final _svc = FichajeService();
  late DateTime _mes;

  @override
  void initState() {
    super.initState();
    _mes = DateTime(DateTime.now().year, DateTime.now().month);
  }

  DateTime get _inicioMes => DateTime(_mes.year, _mes.month, 1);

  // Last day of the month — inclusive upper bound for isLessThanOrEqualTo
  DateTime get _finMes => DateTime(_mes.year, _mes.month + 1, 0);

  bool get _esMesActual {
    final ahora = DateTime.now();
    return _mes.year == ahora.year && _mes.month == ahora.month;
  }

  Future<List<_DatoDia>> _cargarMes() async {
    final raw = await _svc.obtenerFichajesEmpleado(
      empresaId: widget.empresaId,
      empleadoId: widget.empleadoId,
      desde: _inicioMes,
      hasta: _finMes,
    );

    // Prefer correction over original when deduplicating by date
    final Map<String, Fichaje> efectivos = {};
    for (final f in raw) {
      final key = f.fecha;
      final actual = efectivos[key];
      if (actual == null) {
        efectivos[key] = f;
      } else if (f.esCorreccion && !actual.esCorreccion) {
        efectivos[key] = f;
      }
    }

    final result = efectivos.values.map((f) {
      final jornadaAbierta = f.estado == EstadoFichaje.trabajando ||
          f.estado == EstadoFichaje.enPausa;
      return _DatoDia(
        fecha: DateTime.parse(f.fecha),
        entrada: f.entrada?.toDate().toLocal(),
        salida: f.salida?.toDate().toLocal(),
        horasNetas: (f.tiempoNeto?.inMinutes ?? 0) / 60.0,
        jornadaAbierta: jornadaAbierta,
      );
    }).toList();

    result.sort((a, b) => a.fecha.compareTo(b.fecha));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final mesTxt = DateFormat('MMMM yyyy', 'es_ES').format(_mes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: const Row(
            children: [
              Icon(Icons.calendar_month_outlined,
                  size: 18, color: Color(0xFF1565C0)),
              SizedBox(width: 6),
              Text(
                'Mis horas del mes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1a1a2e),
                ),
              ),
            ],
          ),
        ),

        // Selector de mes
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() =>
                      _mes = DateTime(_mes.year, _mes.month - 1)),
                ),
                Text(
                  mesTxt[0].toUpperCase() + mesTxt.substring(1),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _esMesActual
                      ? null
                      : () => setState(() =>
                          _mes = DateTime(_mes.year, _mes.month + 1)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Contenido del mes
        FutureBuilder<List<_DatoDia>>(
          key: ValueKey('${_mes.year}-${_mes.month}'),
          future: _cargarMes(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snap.hasError) {
              return _TarjetaError(mensaje: snap.error.toString());
            }
            final dias = snap.data ?? [];
            if (dias.isEmpty) {
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Sin fichajes este mes',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              );
            }

            final totalHoras =
                dias.fold<double>(0, (s, d) => s + d.horasNetas);
            final diasTrabajados = dias.length;

            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Column(
                children: [
                  // Resumen
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.08),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ResumenChip(
                            label: 'Días trabajados',
                            valor: '$diasTrabajados',
                            icono: Icons.calendar_today_outlined),
                        _ResumenChip(
                            label: 'Total horas',
                            valor: '${totalHoras.toStringAsFixed(1)}h',
                            icono: Icons.access_time_outlined),
                        _ResumenChip(
                            label: 'Media diaria',
                            valor: diasTrabajados > 0
                                ? '${(totalHoras / diasTrabajados).toStringAsFixed(1)}h'
                                : '—',
                            icono: Icons.show_chart),
                      ],
                    ),
                  ),
                  // Lista de días
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dias.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, i) => _FilaDia(dato: dias[i]),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Chip de resumen ───────────────────────────────────────────────────────────

class _ResumenChip extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icono;

  const _ResumenChip(
      {required this.label, required this.valor, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, size: 20, color: const Color(0xFF1565C0)),
        const SizedBox(height: 4),
        Text(valor,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0))),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── Fila de un día ────────────────────────────────────────────────────────────

class _FilaDia extends StatelessWidget {
  final _DatoDia dato;

  const _FilaDia({required this.dato});

  @override
  Widget build(BuildContext context) {
    final fmtFecha = DateFormat('EEE d MMM', 'es_ES');
    final fmtHora = DateFormat('HH:mm');

    final entradaTxt =
        dato.entrada != null ? fmtHora.format(dato.entrada!) : '—';
    final salidaTxt = dato.salida != null
        ? fmtHora.format(dato.salida!)
        : dato.jornadaAbierta
            ? 'En curso'
            : '—';

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: dato.jornadaAbierta
            ? Colors.green[50]
            : const Color(0xFFE3F0FF),
        child: Icon(
          dato.jornadaAbierta
              ? Icons.access_time
              : Icons.check_circle_outline,
          size: 18,
          color: dato.jornadaAbierta
              ? Colors.green[700]
              : const Color(0xFF1565C0),
        ),
      ),
      title: Text(
        fmtFecha.format(dato.fecha),
        style:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text('$entradaTxt → $salidaTxt',
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Text(
        '${dato.horasNetas.toStringAsFixed(1)}h',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: dato.jornadaAbierta
              ? Colors.green[700]
              : const Color(0xFF1565C0),
        ),
      ),
    );
  }
}

// ── Widget de error ───────────────────────────────────────────────────────────

class _TarjetaError extends StatelessWidget {
  final String mensaje;

  const _TarjetaError({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final esIndice = mensaje.contains('index') ||
        mensaje.contains('Index') ||
        mensaje.contains('FAILED_PRECONDITION');
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(esIndice ? Icons.storage : Icons.error_outline,
                color: esIndice ? Colors.orange : Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(
              esIndice
                  ? 'Crea un índice compuesto en Firestore:\n'
                      'fichajes → empleado_id + fecha + creado_at'
                  : mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
