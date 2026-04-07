import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/modelos/tarea.dart';
import '../../../domain/modelos/recurrencia_config.dart';

/// Widget para configurar la recurrencia de una tarea.
///
/// Uso:
/// ```dart
/// RecurrenciaConfigWidget(
///   config: _config,
///   onChanged: (nueva) => setState(() => _config = nueva),
/// )
/// ```
class RecurrenciaConfigWidget extends StatefulWidget {
  final ConfiguracionRecurrencia? config;
  final ValueChanged<ConfiguracionRecurrencia?> onChanged;

  const RecurrenciaConfigWidget({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<RecurrenciaConfigWidget> createState() => _RecurrenciaConfigWidgetState();
}

class _RecurrenciaConfigWidgetState extends State<RecurrenciaConfigWidget> {
  bool _activa = false;
  FrecuenciaRecurrencia _frecuencia = FrecuenciaRecurrencia.semanal;
  Set<int> _diasSemana = {DateTime.monday};
  int _diaMes = 1;
  bool _ultimoDiaMes = false;
  DateTime? _fechaFin;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    if (c != null) {
      _activa = true;
      _frecuencia = c.frecuencia;
      _diasSemana = Set.from(c.diasSemana.isNotEmpty ? c.diasSemana : [DateTime.monday]);
      _diaMes = c.diaMes ?? 1;
      _ultimoDiaMes = c.diaMes == 0;
      _fechaFin = c.fechaFin;
    }
  }

  void _emitir() {
    if (!_activa) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(ConfiguracionRecurrencia(
      frecuencia: _frecuencia,
      diasSemana: _frecuencia == FrecuenciaRecurrencia.semanal ||
              _frecuencia == FrecuenciaRecurrencia.quincenal
          ? _diasSemana.toList()
          : [],
      diaMes: _frecuencia == FrecuenciaRecurrencia.mensual
          ? (_ultimoDiaMes ? 0 : _diaMes)
          : null,
      fechaFin: _fechaFin,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tarea recurrente',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: _activa
              ? Text(_descripcionFrecuencia(),
                  style: const TextStyle(color: Color(0xFF1976D2), fontSize: 12))
              : null,
          secondary: Icon(
            Icons.repeat,
            color: _activa ? const Color(0xFF1976D2) : Colors.grey,
          ),
          value: _activa,
          activeColor: const Color(0xFF1976D2),
          onChanged: (v) {
            setState(() => _activa = v);
            _emitir();
          },
        ),
        if (_activa) ...[
          const SizedBox(height: 8),
          // Selector de frecuencia
          DropdownButtonFormField<FrecuenciaRecurrencia>(
            value: _frecuencia,
            decoration: const InputDecoration(
              labelText: 'Frecuencia',
              prefixIcon: Icon(Icons.schedule),
              isDense: true,
            ),
            items: FrecuenciaRecurrencia.values
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(_nombreFrecuencia(f)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _frecuencia = v);
              _emitir();
            },
          ),

          // Días de la semana (para semanal / quincenal)
          if (_frecuencia == FrecuenciaRecurrencia.semanal ||
              _frecuencia == FrecuenciaRecurrencia.quincenal) ...[
            const SizedBox(height: 12),
            const Text('Días de la semana',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            _selectorDiasSemana(),
          ],

          // Día del mes (para mensual)
          if (_frecuencia == FrecuenciaRecurrencia.mensual) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Último día del mes',
                  style: TextStyle(fontSize: 13)),
              value: _ultimoDiaMes,
              activeColor: const Color(0xFF1976D2),
              onChanged: (v) {
                setState(() => _ultimoDiaMes = v);
                _emitir();
              },
            ),
            if (!_ultimoDiaMes) ...[
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                value: _diaMes.clamp(1, 31),
                decoration: const InputDecoration(
                  labelText: 'Día del mes',
                  isDense: true,
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: List.generate(
                  31,
                  (i) => DropdownMenuItem(value: i + 1, child: Text('Día ${i + 1}')),
                ),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _diaMes = v);
                  _emitir();
                },
              ),
            ],
          ],

          // Fecha de fin
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.event_busy,
              color: _fechaFin != null ? const Color(0xFF1976D2) : Colors.grey,
            ),
            title: Text(
              _fechaFin != null
                  ? 'Hasta: ${DateFormat('dd/MM/yyyy').format(_fechaFin!)}'
                  : 'Sin fecha de fin (indefinida)',
              style: const TextStyle(fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _seleccionarFechaFin,
                  child: const Text('Elegir'),
                ),
                if (_fechaFin != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() => _fechaFin = null);
                      _emitir();
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _selectorDiasSemana() {
    const dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Wrap(
      spacing: 6,
      children: List.generate(7, (i) {
        final dia = i + 1; // 1=Lun…7=Dom
        final seleccionado = _diasSemana.contains(dia);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (seleccionado && _diasSemana.length > 1) {
                _diasSemana.remove(dia);
              } else {
                _diasSemana.add(dia);
              }
            });
            _emitir();
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: seleccionado
                  ? const Color(0xFF1976D2)
                  : const Color(0xFF1976D2).withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: seleccionado
                    ? const Color(0xFF1976D2)
                    : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                dias[i],
                style: TextStyle(
                  color: seleccionado ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _seleccionarFechaFin() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (fecha != null) {
      setState(() => _fechaFin = fecha);
      _emitir();
    }
  }

  String _nombreFrecuencia(FrecuenciaRecurrencia f) => switch (f) {
        FrecuenciaRecurrencia.diaria     => 'Diaria',
        FrecuenciaRecurrencia.semanal    => 'Semanal',
        FrecuenciaRecurrencia.quincenal  => 'Quincenal',
        FrecuenciaRecurrencia.mensual    => 'Mensual',
        FrecuenciaRecurrencia.anual      => 'Anual',
      };

  String _descripcionFrecuencia() {
    switch (_frecuencia) {
      case FrecuenciaRecurrencia.diaria:
        return 'Se repite cada día';
      case FrecuenciaRecurrencia.semanal:
        final dias = _diasSemana.map(_nombreDia).join(', ');
        return 'Se repite los: $dias';
      case FrecuenciaRecurrencia.quincenal:
        return 'Quincenal';
      case FrecuenciaRecurrencia.mensual:
        if (_ultimoDiaMes) return 'El último día de cada mes';
        return 'El día $_diaMes de cada mes';
      case FrecuenciaRecurrencia.anual:
        return 'Una vez al año';
    }
  }

  String _nombreDia(int d) => ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][d - 1];
}

