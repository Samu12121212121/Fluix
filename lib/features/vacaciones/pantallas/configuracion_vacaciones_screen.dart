import 'package:flutter/material.dart';
import '../../../models/saldo_vacaciones_model.dart';
import '../../../models/festivo_model.dart';
import '../../../services/vacaciones_service.dart';
import '../../../services/festivos_service.dart';
import '../../../services/cobertura_equipo_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE CONFIGURACIÓN DE VACACIONES
// Comunidad autónoma, carryover, mínimo de cobertura.
// ═══════════════════════════════════════════════════════════════════════════════

class ConfiguracionVacacionesScreen extends StatefulWidget {
  final String empresaId;
  const ConfiguracionVacacionesScreen({super.key, required this.empresaId});

  @override
  State<ConfiguracionVacacionesScreen> createState() =>
      _ConfiguracionVacacionesScreenState();
}

class _ConfiguracionVacacionesScreenState
    extends State<ConfiguracionVacacionesScreen> {
  final VacacionesService _vacSvc = VacacionesService();
  final FestivosService _festSvc = FestivosService();
  final CoberturaEquipoService _cobSvc = CoberturaEquipoService();

  // Carryover
  int _diasMaximos = 5;
  int _mesExpiracion = 3;
  int _diaExpiracion = 31;
  bool _notificarAntes = true;
  bool _permitirManual = true;

  // Comunidad autónoma
  String? _comunidadSeleccionada;

  // Cobertura mínima
  int _minimoCoberturaPorc = 50;

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final config = await _vacSvc.obtenerConfigCarryover(widget.empresaId);
      final comunidad =
      await _festSvc.obtenerComunidadAutonoma(widget.empresaId);

      // Leer mínimo cobertura
      final minCob = await _cobSvc.obtenerMinimoPorcentaje(widget.empresaId);

      if (mounted) {
        setState(() {
          _diasMaximos = config.diasMaximosTraspasar;
          _mesExpiracion = config.mesExpiracion;
          _diaExpiracion = config.diaExpiracion;
          _notificarAntes = config.notificarAnteDeExpirar;
          _permitirManual = config.permitirTraspasManual;
          _comunidadSeleccionada = comunidad;
          _minimoCoberturaPorc = minCob;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      // Guardar carryover
      await _vacSvc.guardarConfigCarryover(
        widget.empresaId,
        ConfiguracionCarryover(
          diasMaximosTraspasar: _diasMaximos,
          mesExpiracion: _mesExpiracion,
          diaExpiracion: _diaExpiracion,
          notificarAnteDeExpirar: _notificarAntes,
          permitirTraspasManual: _permitirManual,
        ),
      );

      // Guardar comunidad autónoma
      if (_comunidadSeleccionada != null) {
        await _festSvc.guardarComunidadAutonoma(
            widget.empresaId, _comunidadSeleccionada!);
      }

      // Guardar mínimo cobertura
      await _cobSvc.guardarMinimoPorcentaje(
          widget.empresaId, _minimoCoberturaPorc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Configuración guardada'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Configuración Vacaciones'),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        actions: [
          if (_guardando)
            const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                ))
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _guardar,
              tooltip: 'Guardar configuración',
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Comunidad autónoma ──
          _buildSeccion(
            'Comunidad autónoma',
            'Festivos autonómicos que se importarán automáticamente',
            Icons.map,
            [
              DropdownButtonFormField<String>(
                value: _comunidadSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Comunidad autónoma',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                items: ComunidadesAutonomas.lista
                    .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value,
                      style: const TextStyle(fontSize: 13)),
                ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _comunidadSeleccionada = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Carryover (arrastre) ──
          _buildSeccion(
            'Arrastre de días',
            'Configuración del traspaso de días no disfrutados',
            Icons.swap_horiz,
            [
              _buildSlider(
                'Máximo días a traspasar',
                _diasMaximos,
                0,
                30,
                    (v) => setState(() => _diasMaximos = v.round()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _mesExpiracion,
                      decoration: const InputDecoration(
                        labelText: 'Mes límite',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: List.generate(
                          12,
                              (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(_nombreMes(i + 1)),
                          )),
                      onChanged: (v) =>
                          setState(() => _mesExpiracion = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: '$_diaExpiracion',
                      decoration: const InputDecoration(
                        labelText: 'Día',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed >= 1 && parsed <= 31) {
                          _diaExpiracion = parsed;
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notificar 7 días antes de expirar',
                    style: TextStyle(fontSize: 13)),
                value: _notificarAntes,
                onChanged: (v) =>
                    setState(() => _notificarAntes = v),
                activeColor: const Color(0xFF00796B),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permitir traspaso manual',
                    style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                    'El propietario puede traspasar días manualmente',
                    style: TextStyle(fontSize: 11)),
                value: _permitirManual,
                onChanged: (v) =>
                    setState(() => _permitirManual = v),
                activeColor: const Color(0xFF00796B),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Cobertura mínima ──
          _buildSeccion(
            'Cobertura mínima del equipo',
            'Porcentaje mínimo de empleados presentes para alertas',
            Icons.groups,
            [
              _buildSlider(
                'Mínimo presentes',
                _minimoCoberturaPorc,
                10,
                100,
                    (v) =>
                    setState(() => _minimoCoberturaPorc = v.round()),
                suffix: '%',
              ),
              Text(
                'Se mostrará alerta al aprobar vacaciones si la cobertura '
                    'queda por debajo del $_minimoCoberturaPorc%',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion(
      String titulo, String subtitulo, IconData icono, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: const Color(0xFF00796B)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(subtitulo,
                        style:
                        TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSlider(
      String label,
      int value,
      int min,
      int max,
      ValueChanged<double> onChanged, {
        String suffix = '',
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text('$value$suffix',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF00796B))),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: const Color(0xFF00796B),
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _nombreMes(int mes) {
    const meses = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return meses[mes];
  }
}