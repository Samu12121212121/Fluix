import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/tiempo_tarea_service.dart';

/// Cronómetro de tarea con persistencia y entrada manual de tiempo.
class CronometroTareaWidget extends StatefulWidget {
  final String empresaId;
  final String tareaId;
  final String usuarioId;
  final int totalSegundosPrevios;

  const CronometroTareaWidget({
    super.key,
    required this.empresaId,
    required this.tareaId,
    required this.usuarioId,
    this.totalSegundosPrevios = 0,
  });

  @override
  State<CronometroTareaWidget> createState() => _CronometroTareaWidgetState();
}

class _CronometroTareaWidgetState extends State<CronometroTareaWidget> {
  final TiempoTareaService _svc = TiempoTareaService();
  Timer? _timer;
  bool _activo = false;
  int _segundos = 0;

  @override
  void initState() {
    super.initState();
    // Recuperar cronómetro activo de esta tarea
    final svc = TiempoTareaService();
    if (svc.hayCronometroActivo && svc.tareaIdActiva == widget.tareaId) {
      _segundos = DateTime.now().difference(svc.inicioActivo!).inSeconds;
      _activo = true;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _segundos++);
    });
  }

  Future<void> _toggle() async {
    if (_activo) {
      _timer?.cancel();
      setState(() => _activo = false);
      await _svc.pausar(
        empresaId: widget.empresaId,
        tareaId: widget.tareaId,
        usuarioId: widget.usuarioId,
      );
      setState(() => _segundos = 0);
    } else {
      await _svc.iniciar(
        empresaId: widget.empresaId,
        tareaId: widget.tareaId,
        usuarioId: widget.usuarioId,
      );
      setState(() {
        _activo = true;
        _segundos = 0;
      });
      _startTimer();
    }
  }

  Future<void> _agregarManual() async {
    final resultado = await showDialog<_TiempoManualResult>(
      context: context,
      builder: (_) => const _DialogTiempoManual(),
    );
    if (resultado == null || !mounted) return;

    await _svc.annadirManual(
      empresaId: widget.empresaId,
      tareaId: widget.tareaId,
      usuarioId: widget.usuarioId,
      segundos: resultado.segundos,
      fecha: resultado.fecha,
      nota: resultado.nota,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Añadido: ${_formatDuracion(resultado.segundos)} de forma manual'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  String _formatDuracion(int seg) {
    final h = seg ~/ 3600;
    final m = (seg % 3600) ~/ 60;
    final s = seg % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer,
                    color: _activo ? const Color(0xFF1976D2) : Colors.grey),
                const SizedBox(width: 8),
                const Text('Control de tiempo',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Cronómetro actual
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_activo)
                        Text(
                          _formatDuracion(_segundos),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: Color(0xFF1976D2),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      StreamBuilder<List<RegistroTiempo>>(
                        stream: _svc.registrosStream(
                            widget.empresaId, widget.tareaId),
                        builder: (context, snap) {
                          final regs = snap.data ?? [];
                          final totalSeg = regs.fold<int>(
                              0, (s, r) => s + r.segundos);
                          return Text(
                            'Total: ${_formatDuracion(totalSeg)}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Botones
                Column(
                  children: [
                    FilledButton.icon(
                      onPressed: _toggle,
                      icon: Icon(
                          _activo ? Icons.stop : Icons.play_arrow,
                          size: 18),
                      label: Text(_activo ? 'Pausar' : 'Iniciar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _activo
                            ? Colors.red
                            : const Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _agregarManual,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('+ Manual', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Últimos registros
            StreamBuilder<List<RegistroTiempo>>(
              stream:
                  _svc.registrosStream(widget.empresaId, widget.tareaId),
              builder: (context, snap) {
                final regs = (snap.data ?? [])
                    .where((r) => r.id != '_en_progreso')
                    .take(5)
                    .toList();
                if (regs.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    const Divider(height: 20),
                    ...regs.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(
                                  r.esManual
                                      ? Icons.edit_calendar
                                      : Icons.play_circle_outline,
                                  size: 14,
                                  color: Colors.grey[500]),
                              const SizedBox(width: 6),
                              Text(
                                _formatFecha(r.inicio),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              if (r.esManual) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('manual',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange)),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                r.duracionFormateada,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime dt) {
    final ahora = DateTime.now();
    if (dt.day == ahora.day &&
        dt.month == ahora.month &&
        dt.year == ahora.year) {
      return 'Hoy ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── DIÁLOGO TIEMPO MANUAL ────────────────────────────────────────────────────

class _TiempoManualResult {
  final int segundos;
  final DateTime fecha;
  final String? nota;
  _TiempoManualResult({
    required this.segundos,
    required this.fecha,
    this.nota,
  });
}

class _DialogTiempoManual extends StatefulWidget {
  const _DialogTiempoManual();

  @override
  State<_DialogTiempoManual> createState() => _DialogTiempoManualState();
}

class _DialogTiempoManualState extends State<_DialogTiempoManual> {
  int _horas = 0;
  int _minutos = 0;
  DateTime _fecha = DateTime.now();
  final _notaCtrl = TextEditingController();

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir tiempo manual'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '0',
                  decoration: const InputDecoration(
                      labelText: 'Horas', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _horas = int.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: '0',
                  decoration: const InputDecoration(
                      labelText: 'Minutos', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _minutos = int.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, size: 18),
            title: Text(
                '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                style: const TextStyle(fontSize: 13)),
            trailing: TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _fecha,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _fecha = d);
              },
              child: const Text('Cambiar'),
            ),
          ),
          TextField(
            controller: _notaCtrl,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final seg = _horas * 3600 + _minutos * 60;
            if (seg == 0) return;
            Navigator.pop(
              context,
              _TiempoManualResult(
                segundos: seg,
                fecha: _fecha,
                nota: _notaCtrl.text.trim().isEmpty
                    ? null
                    : _notaCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}

