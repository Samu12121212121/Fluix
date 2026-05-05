import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Configuración de reservas
// Almacenado en: empresas/{empresaId}/configuracion/reservas
// ─────────────────────────────────────────────────────────────────────────────

class ConfigReservas {
  /// Días de la semana activos (1=Lunes … 7=Domingo, ISO weekday)
  final List<int> diasActivos;

  /// Horario de apertura/cierre por día activo
  /// Clave: String del weekday (ej. "1"), valor: {"apertura": "09:00", "cierre": "20:00"}
  final Map<String, Map<String, String>> horario;

  /// Fechas cerradas específicas en formato "yyyy-MM-dd"
  final List<String> diasCerrados;

  /// Duración de cada slot en minutos (para la web)
  final int duracionSlotMinutos;

  const ConfigReservas({
    required this.diasActivos,
    required this.horario,
    required this.diasCerrados,
    this.duracionSlotMinutos = 30,
  });

  factory ConfigReservas.porDefecto() => const ConfigReservas(
        diasActivos: [1, 2, 3, 4, 5],
        horario: {
          '1': {'apertura': '09:00', 'cierre': '20:00'},
          '2': {'apertura': '09:00', 'cierre': '20:00'},
          '3': {'apertura': '09:00', 'cierre': '20:00'},
          '4': {'apertura': '09:00', 'cierre': '20:00'},
          '5': {'apertura': '09:00', 'cierre': '20:00'},
        },
        diasCerrados: [],
        duracionSlotMinutos: 30,
      );

  factory ConfigReservas.fromMap(Map<String, dynamic> data) {
    final rawDias = (data['dias_activos'] as List? ?? []);
    final rawHorario = (data['horario'] as Map<String, dynamic>? ?? {});
    final rawCerrados = (data['dias_cerrados'] as List? ?? []);

    return ConfigReservas(
      diasActivos: rawDias.map((e) => (e as num).toInt()).toList(),
      horario: rawHorario.map(
        (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
      ),
      diasCerrados: rawCerrados.map((e) => e.toString()).toList(),
      duracionSlotMinutos: (data['duracion_slot_minutos'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toMap() => {
        'dias_activos': diasActivos,
        'horario': horario,
        'dias_cerrados': diasCerrados,
        'duracion_slot_minutos': duracionSlotMinutos,
      };

  /// Devuelve true si la fecha dada está marcada como cerrada o es un día no activo
  bool estaCerrado(DateTime fecha) {
    final diaSemana = fecha.weekday; // 1=lunes, 7=domingo
    if (!diasActivos.contains(diaSemana)) return true;
    final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);
    return diasCerrados.contains(fechaStr);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA: Configuración de reservas
// ─────────────────────────────────────────────────────────────────────────────

class ConfiguracionReservasScreen extends StatefulWidget {
  final String empresaId;
  const ConfiguracionReservasScreen({super.key, required this.empresaId});

  @override
  State<ConfiguracionReservasScreen> createState() =>
      _ConfiguracionReservasScreenState();
}

class _ConfiguracionReservasScreenState
    extends State<ConfiguracionReservasScreen> {
  final _db = FirebaseFirestore.instance;
  static const _color = Color(0xFF0D47A1);

  bool _cargando = true;
  bool _guardando = false;
  late ConfigReservas _config;

  static const _nombresDias = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };

  DocumentReference get _ref => _db
      .collection('empresas')
      .doc(widget.empresaId)
      .collection('configuracion')
      .doc('reservas');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final snap = await _ref.get();
      setState(() {
        _config = snap.exists
            ? ConfigReservas.fromMap(snap.data() as Map<String, dynamic>)
            : ConfigReservas.porDefecto();
        _cargando = false;
      });
    } catch (_) {
      setState(() {
        _config = ConfigReservas.porDefecto();
        _cargando = false;
      });
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _ref.set(_config.toMap(), SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Configuración guardada'),
          backgroundColor: Color(0xFF2E7D32),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error guardando: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _toggleDia(int dia) {
    setState(() {
      final nuevos = List<int>.from(_config.diasActivos);
      if (nuevos.contains(dia)) {
        nuevos.remove(dia);
        // Borrar horario del día desactivado
        final nuevoHorario = Map<String, Map<String, String>>.from(_config.horario);
        nuevoHorario.remove(dia.toString());
        _config = ConfigReservas(
          diasActivos: nuevos..sort(),
          horario: nuevoHorario,
          diasCerrados: _config.diasCerrados,
          duracionSlotMinutos: _config.duracionSlotMinutos,
        );
      } else {
        nuevos.add(dia);
        final nuevoHorario = Map<String, Map<String, String>>.from(_config.horario);
        nuevoHorario[dia.toString()] = {'apertura': '09:00', 'cierre': '20:00'};
        _config = ConfigReservas(
          diasActivos: nuevos..sort(),
          horario: nuevoHorario,
          diasCerrados: _config.diasCerrados,
          duracionSlotMinutos: _config.duracionSlotMinutos,
        );
      }
    });
  }

  Future<void> _cambiarHora(int dia, bool esApertura) async {
    final clave = dia.toString();
    final actual = _config.horario[clave] ?? {'apertura': '09:00', 'cierre': '20:00'};
    final horaActual = _parseTimeOfDay(
        esApertura ? actual['apertura']! : actual['cierre']!);
    final picked = await showTimePicker(
      context: context,
      initialTime: horaActual,
      helpText: esApertura ? 'Hora de apertura' : 'Hora de cierre',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final horaStr =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      final nuevoHorario = Map<String, Map<String, String>>.from(_config.horario);
      final diaHorario = Map<String, String>.from(nuevoHorario[clave] ?? {});
      if (esApertura) {
        diaHorario['apertura'] = horaStr;
      } else {
        diaHorario['cierre'] = horaStr;
      }
      nuevoHorario[clave] = diaHorario;
      _config = ConfigReservas(
        diasActivos: _config.diasActivos,
        horario: nuevoHorario,
        diasCerrados: _config.diasCerrados,
        duracionSlotMinutos: _config.duracionSlotMinutos,
      );
    });
  }

  Future<void> _agregarDiaCerrado() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Selecciona un día cerrado',
    );
    if (picked == null) return;
    final fechaStr = DateFormat('yyyy-MM-dd').format(picked);
    if (_config.diasCerrados.contains(fechaStr)) return;
    setState(() {
      final nuevos = List<String>.from(_config.diasCerrados)..add(fechaStr);
      nuevos.sort();
      _config = ConfigReservas(
        diasActivos: _config.diasActivos,
        horario: _config.horario,
        diasCerrados: nuevos,
        duracionSlotMinutos: _config.duracionSlotMinutos,
      );
    });
  }

  void _eliminarDiaCerrado(String fecha) {
    setState(() {
      final nuevos = List<String>.from(_config.diasCerrados)..remove(fecha);
      _config = ConfigReservas(
        diasActivos: _config.diasActivos,
        horario: _config.horario,
        diasCerrados: nuevos,
        duracionSlotMinutos: _config.duracionSlotMinutos,
      );
    });
  }

  void _cambiarSlot(int minutos) {
    setState(() {
      _config = ConfigReservas(
        diasActivos: _config.diasActivos,
        horario: _config.horario,
        diasCerrados: _config.diasCerrados,
        duracionSlotMinutos: minutos,
      );
    });
  }

  TimeOfDay _parseTimeOfDay(String hora) {
    final parts = hora.split(':');
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Configuración de Reservas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))),
            )
          else
            TextButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save_outlined, color: Colors.white, size: 18),
              label: const Text('Guardar',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sección: Días de apertura ─────────────────────────────────
          _seccionHeader(Icons.calendar_today, 'Días de apertura'),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: List.generate(7, (i) {
                  final dia = i + 1;
                  final activo = _config.diasActivos.contains(dia);
                  final horario = _config.horario[dia.toString()];
                  return Column(
                    children: [
                      SwitchListTile(
                        value: activo,
                        onChanged: (_) => _toggleDia(dia),
                        title: Text(
                          _nombresDias[dia]!,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: activo ? Colors.black87 : Colors.grey[500]),
                        ),
                        subtitle: activo && horario != null
                            ? Text(
                                '${horario['apertura']} – ${horario['cierre']}',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF1976D2)),
                              )
                            : Text(
                                activo ? 'Sin horario' : 'Cerrado',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[400]),
                              ),
                        activeColor: _color,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      // Botones de horario si el día está activo
                      if (activo) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              const SizedBox(width: 40),
                              Expanded(
                                child: _botonHora(
                                  label: 'Apertura',
                                  hora: horario?['apertura'] ?? '09:00',
                                  onTap: () => _cambiarHora(dia, true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.arrow_forward,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _botonHora(
                                  label: 'Cierre',
                                  hora: horario?['cierre'] ?? '20:00',
                                  onTap: () => _cambiarHora(dia, false),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (i < 6) const Divider(height: 1, indent: 16),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Sección: Días cerrados especiales ─────────────────────────
          _seccionHeader(Icons.event_busy, 'Días cerrados especiales'),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                if (_config.diasCerrados.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('Sin días cerrados añadidos',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 14)),
                      ],
                    ),
                  )
                else
                  ..._config.diasCerrados.map((fechaStr) {
                    final fecha = DateTime.tryParse(fechaStr);
                    final label = fecha != null
                        ? DateFormat('EEEE, d MMMM yyyy', 'es')
                            .format(fecha)
                            .capitalized
                        : fechaStr;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close, color: Colors.red, size: 16),
                      ),
                      title: Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(fechaStr,
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _eliminarDiaCerrado(fechaStr),
                        tooltip: 'Eliminar',
                      ),
                    );
                  }),
                const Divider(height: 1),
                ListTile(
                  onTap: _agregarDiaCerrado,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: _color, size: 16),
                  ),
                  title: Text('Añadir día cerrado',
                      style: TextStyle(
                          color: _color, fontWeight: FontWeight.w600)),
                  subtitle: Text('Vacaciones, festivos, mantenimiento…',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Sección: Duración de slots ────────────────────────────────
          _seccionHeader(Icons.schedule, 'Duración de cita (web)'),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tiempo mínimo entre reservas en el formulario web',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [15, 30, 45, 60, 90, 120].map((minutos) {
                      final sel = _config.duracionSlotMinutos == minutos;
                      return ChoiceChip(
                        label: Text(
                          minutos < 60
                              ? '$minutos min'
                              : '${minutos ~/ 60}h${minutos % 60 > 0 ? " ${minutos % 60}'" : ""}',
                        ),
                        selected: sel,
                        onSelected: (_) => _cambiarSlot(minutos),
                        selectedColor: _color,
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : Colors.black87,
                          fontWeight:
                              sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Sección: Info para el formulario web ─────────────────────
          Card(
            color: const Color(0xFFE3F2FD),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF0D47A1), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Cómo funciona?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'El formulario HTML de reservas de tu web lee automáticamente esta configuración desde Firestore. '
                          'Los días cerrados y los días fuera del horario de apertura quedarán bloqueados en el selector de fechas de la web, '
                          'impidiendo que los clientes reserven esas fechas.',
                          style: TextStyle(
                              color: Colors.blue[800], fontSize: 12, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          'Ruta Firestore:\nempresas/${widget.empresaId}/\nconfiguracion/reservas',
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF0D47A1)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _seccionHeader(IconData icono, String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Icon(icono, size: 17, color: _color),
          const SizedBox(width: 8),
          Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF0D47A1))),
        ],
      ),
    );
  }

  Widget _botonHora(
      {required String label,
      required String hora,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 13, color: Colors.blue[700]),
            const SizedBox(width: 5),
            Text(
              '$label $hora',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700]),
            ),
          ],
        ),
      ),
    );
  }
}

extension _Cap on String {
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

