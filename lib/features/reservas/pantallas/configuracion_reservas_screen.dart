import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

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

  /// Motivos de cierre por fecha (opcional): "yyyy-MM-dd" → "Vacaciones de verano"
  final Map<String, String> motivosCierre;

  /// Días de la semana recurrentes cerrados (ej: todos los martes = [2])
  /// 1=Lunes, 2=Martes, 3=Miércoles, etc.
  final List<int> diasRecurrentesCerrados;

  /// Intervalos de fechas cerradas: [{inicio: "2026-05-13", fin: "2026-05-15", motivo: "Vacaciones"}]
  final List<Map<String, String>> intervalosCerrados;

  /// Duración de cada slot en minutos (para la web)
  final int duracionSlotMinutos;

  /// Horarios específicos aceptados por día: "1" → ["13:30","14:00","14:30",...]
  /// Si está vacío para un día, se generan automáticamente desde apertura a cierre
  final Map<String, List<String>> horariosReserva;

  const ConfigReservas({
    required this.diasActivos,
    required this.horario,
    required this.diasCerrados,
    this.motivosCierre = const {},
    this.diasRecurrentesCerrados = const [],
    this.intervalosCerrados = const [],
    this.duracionSlotMinutos = 30,
    this.horariosReserva = const {},
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
        motivosCierre: {},
        diasRecurrentesCerrados: [],
        intervalosCerrados: [],
        duracionSlotMinutos: 30,
        horariosReserva: {},
      );

  factory ConfigReservas.fromMap(Map<String, dynamic> data) {
    final rawDias = (data['dias_activos'] as List? ?? []);
    final rawHorario = (data['horario'] as Map<String, dynamic>? ?? {});
    final rawCerrados = (data['dias_cerrados'] as List? ?? []);
    final rawHorariosReserva = (data['horarios_reserva'] as Map<String, dynamic>? ?? {});
    final rawMotivos = (data['motivos_cierre'] as Map<String, dynamic>? ?? {});
    final rawRecurrentes = (data['dias_recurrentes_cerrados'] as List? ?? []);
    final rawIntervalos = (data['intervalos_cerrados'] as List? ?? []);

    return ConfigReservas(
      diasActivos: rawDias.map((e) => (e as num).toInt()).toList(),
      horario: rawHorario.map((k, v) => MapEntry(k, Map<String, String>.from(v as Map))),
      diasCerrados: rawCerrados.map((e) => e.toString()).toList(),
      motivosCierre: rawMotivos.map((k, v) => MapEntry(k.toString(), v.toString())),
      diasRecurrentesCerrados: rawRecurrentes.map((e) => (e as num).toInt()).toList(),
      intervalosCerrados: rawIntervalos.map((e) => Map<String, String>.from(e as Map)).toList(),
      duracionSlotMinutos: (data['duracion_slot_minutos'] as num?)?.toInt() ?? 30,
      horariosReserva: rawHorariosReserva.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'dias_activos': diasActivos,
        'horario': horario,
        'dias_cerrados': diasCerrados,
        'motivos_cierre': motivosCierre,
        'dias_recurrentes_cerrados': diasRecurrentesCerrados,
        'intervalos_cerrados': intervalosCerrados,
        'duracion_slot_minutos': duracionSlotMinutos,
        'horarios_reserva': horariosReserva,
      };

  bool estaCerrado(DateTime fecha) {
    if (!diasActivos.contains(fecha.weekday)) return true;
    
    // Verificar si está en días cerrados específicos
    if (diasCerrados.contains(DateFormat('yyyy-MM-dd').format(fecha))) return true;
    
    // Verificar si está en días recurrentes cerrados (ej: todos los martes)
    if (diasRecurrentesCerrados.contains(fecha.weekday)) return true;
    
    // Verificar si está dentro de algún intervalo cerrado
    for (final intervalo in intervalosCerrados) {
      final inicio = DateTime.parse(intervalo['inicio']!);
      final fin = DateTime.parse(intervalo['fin']!);
      if (fecha.isAfter(inicio.subtract(const Duration(days: 1))) && 
          fecha.isBefore(fin.add(const Duration(days: 1)))) {
        return true;
      }
    }
    
    return false;
  }

  /// Genera slots automáticos desde apertura a cierre con la duración del slot
  List<String> slotsParaDia(int weekday) {
    final clave = weekday.toString();
    if (horariosReserva.containsKey(clave) && horariosReserva[clave]!.isNotEmpty) {
      return horariosReserva[clave]!;
    }
    final h = horario[clave];
    if (h == null) return [];
    final apertura = _parseTimeStr(h['apertura'] ?? '09:00');
    final cierre   = _parseTimeStr(h['cierre'] ?? '20:00');
    final slots    = <String>[];
    var actual = apertura;
    while (_minutosDesde(actual) < _minutosDesde(cierre)) {
      slots.add('${actual.hour.toString().padLeft(2,'0')}:${actual.minute.toString().padLeft(2,'0')}');
      final totalMin = _minutosDesde(actual) + duracionSlotMinutos;
      actual = TimeOfDay(hour: totalMin ~/ 60, minute: totalMin % 60);
    }
    return slots;
  }

  static TimeOfDay _parseTimeStr(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
  }

  static int _minutosDesde(TimeOfDay t) => t.hour * 60 + t.minute;
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
    extends State<ConfiguracionReservasScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  static const _color = Color(0xFF0D47A1);

  bool _cargando = true;
  bool _guardando = false;
  late ConfigReservas _config;
  late TabController _tabCtrl;

  static const _nombresDias = {
    1: 'Lunes', 2: 'Martes', 3: 'Miércoles',
    4: 'Jueves', 5: 'Viernes', 6: 'Sábado', 7: 'Domingo',
  };
  static const _shortDias = {
    1: 'L', 2: 'M', 3: 'X', 4: 'J', 5: 'V', 6: 'S', 7: 'D',
  };

  DocumentReference get _ref => _db
      .collection('empresas')
      .doc(widget.empresaId)
      .collection('configuracion')
      .doc('reservas');

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Carga / Guardado ──────────────────────────────────────────────────────

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
      setState(() { _config = ConfigReservas.porDefecto(); _cargando = false; });
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      // 1. Guardar configuración principal
      await _ref.set(_config.toMap(), SetOptions(merge: true));
      
      // 2. Sincronizar con reservas_web para el formulario HTML
      await _sincronizarConfigWeb();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Configuración guardada y sincronizada con web'),
          backgroundColor: Color(0xFF2E7D32),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Sincroniza la configuración con el documento reservas_web usado por el formulario HTML
  Future<void> _sincronizarConfigWeb() async {
    final webConfig = {
      'fechas_bloqueadas': _config.diasCerrados,
      'motivos_cierre': _config.motivosCierre,
      'dias_recurrentes_cerrados': _config.diasRecurrentesCerrados,
      'intervalos_cerrados': _config.intervalosCerrados,
      'duracion_slot_minutos': _config.duracionSlotMinutos,
      'horario_por_dia': _config.horario,
      'horarios_reserva_por_dia': _config.horariosReserva,
      'actualizado': FieldValue.serverTimestamp(),
    };
    
    await _db
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('configuracion')
        .doc('reservas_web')
        .set(webConfig, SetOptions(merge: true));
  }

  // ── Mutadores de estado ───────────────────────────────────────────────────

  void _toggleDia(int dia) {
    setState(() {
      final nuevos = List<int>.from(_config.diasActivos);
      final nuevoHorario = Map<String, Map<String, String>>.from(_config.horario);
      final nuevosSlots   = Map<String, List<String>>.from(_config.horariosReserva);
      if (nuevos.contains(dia)) {
        nuevos.remove(dia);
        nuevoHorario.remove(dia.toString());
        nuevosSlots.remove(dia.toString());
      } else {
        nuevos.add(dia);
        nuevoHorario[dia.toString()] = {'apertura': '09:00', 'cierre': '20:00'};
      }
      _config = ConfigReservas(
        diasActivos: nuevos..sort(), horario: nuevoHorario,
        diasCerrados: _config.diasCerrados,
        motivosCierre: _config.motivosCierre,
        diasRecurrentesCerrados: _config.diasRecurrentesCerrados,
        intervalosCerrados: _config.intervalosCerrados,
        duracionSlotMinutos: _config.duracionSlotMinutos,
        horariosReserva: nuevosSlots,
      );
    });
  }

  Future<void> _cambiarHora(int dia, bool esApertura) async {
    final clave = dia.toString();
    final actual = _config.horario[clave] ?? {'apertura': '09:00', 'cierre': '20:00'};
    final horaActual = _parseTimeOfDay(esApertura ? actual['apertura']! : actual['cierre']!);

    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,  // ← evita conflicto con el scroll del CupertinoPicker
      backgroundColor: Colors.transparent,
      builder: (_) => _HoraPickerSheet(
        horaInicial: horaActual,
        titulo: esApertura ? 'Hora de apertura' : 'Hora de cierre',
        color: esApertura ? const Color(0xFF388E3C) : const Color(0xFFC62828),
      ),
    );

    if (picked == null || !mounted) return;
    final horaStr = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
    setState(() {
      final nuevoHorario = Map<String, Map<String, String>>.from(_config.horario);
      final diaH = Map<String, String>.from(nuevoHorario[clave] ?? {});
      if (esApertura) diaH['apertura'] = horaStr; else diaH['cierre'] = horaStr;
      nuevoHorario[clave] = diaH;
      _config = ConfigReservas(
        diasActivos: _config.diasActivos, horario: nuevoHorario,
        diasCerrados: _config.diasCerrados,
        motivosCierre: _config.motivosCierre,
        diasRecurrentesCerrados: _config.diasRecurrentesCerrados,
        intervalosCerrados: _config.intervalosCerrados,
        duracionSlotMinutos: _config.duracionSlotMinutos,
        horariosReserva: _config.horariosReserva,
      );
    });
  }

  void _toggleSlotReserva(int dia, String hora) {
    setState(() {
      final clave = dia.toString();
      final nuevosSlots = Map<String, List<String>>.from(_config.horariosReserva);
      // Si no hay slots manuales, inizializar con los auto-generados
      final slotsActuales = nuevosSlots[clave]?.toList()
          ?? _config.slotsParaDia(dia).toList();
      if (slotsActuales.contains(hora)) {
        slotsActuales.remove(hora);
      } else {
        slotsActuales.add(hora);
        slotsActuales.sort();
      }
      nuevosSlots[clave] = slotsActuales;
      _config = ConfigReservas(
        diasActivos: _config.diasActivos, horario: _config.horario,
        diasCerrados: _config.diasCerrados,
        motivosCierre: _config.motivosCierre,
        diasRecurrentesCerrados: _config.diasRecurrentesCerrados,
        intervalosCerrados: _config.intervalosCerrados,
        duracionSlotMinutos: _config.duracionSlotMinutos,
        horariosReserva: nuevosSlots,
      );
    });
  }

  void _resetSlotsParaDia(int dia) {
    setState(() {
      final nuevosSlots = Map<String, List<String>>.from(_config.horariosReserva);
      nuevosSlots.remove(dia.toString());
      _config = ConfigReservas(
        diasActivos: _config.diasActivos, horario: _config.horario,
        diasCerrados: _config.diasCerrados,
        motivosCierre: _config.motivosCierre,
        diasRecurrentesCerrados: _config.diasRecurrentesCerrados,
        intervalosCerrados: _config.intervalosCerrados,
        duracionSlotMinutos: _config.duracionSlotMinutos,
        horariosReserva: nuevosSlots,
      );
    });
  }

  Future<void> _agregarDiaCerrado() async {
    final picked = await showModalBottomSheet<Set<DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalendarioCerradosSheet(
        diasYaCerrados: _config.diasCerrados,
        diasActivosSemana: _config.diasActivos,
      ),
    );
    if (picked == null || picked.isEmpty) return;

    // Pedir motivo del cierre (OBLIGATORIO)
    final motivoCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit_note, color: _color, size: 20),
            const SizedBox(width: 8),
            const Text('Motivo del cierre'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Especifica por qué estará cerrado. Este mensaje se mostrará en el formulario web.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Motivo *',
                hintText: 'Ej: Vacaciones, festivo, mantenimiento...',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.info_outline, color: _color),
                helperText: '* Campo obligatorio',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final texto = motivoCtrl.text.trim();
              if (texto.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ El motivo es obligatorio'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, texto);
            },
            style: FilledButton.styleFrom(backgroundColor: _color),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    motivoCtrl.dispose();
    
    // Si cancela o no pone motivo, no se agregan los días
    if (motivo == null || motivo.isEmpty) return;

    setState(() {
      final nuevos = List<String>.from(_config.diasCerrados);
      final nuevosMotivos = Map<String, String>.from(_config.motivosCierre);
      for (final d in picked) {
        final s = DateFormat('yyyy-MM-dd').format(d);
        if (!nuevos.contains(s)) {
          nuevos.add(s);
          nuevosMotivos[s] = motivo; // Siempre guardar el motivo (ya es obligatorio)
        }
      }
      nuevos.sort();
      _config = ConfigReservas(
        diasActivos: _config.diasActivos, horario: _config.horario,
        diasCerrados: nuevos,
        motivosCierre: nuevosMotivos,
        duracionSlotMinutos: _config.duracionSlotMinutos,
        horariosReserva: _config.horariosReserva,
      );
    });
  }

  void _eliminarDiaCerrado(String fecha) {
    setState(() {
      final nuevos = List<String>.from(_config.diasCerrados)..remove(fecha);
      final nuevosMotivos = Map<String, String>.from(_config.motivosCierre)..remove(fecha);
      _config = ConfigReservas(
        diasActivos: _config.diasActivos, horario: _config.horario,
        diasCerrados: nuevos,
        motivosCierre: nuevosMotivos,
        diasRecurrentesCerrados: _config.diasRecurrentesCerrados,
        intervalosCerrados: _config.intervalosCerrados,
        duracionSlotMinutos: _config.duracionSlotMinutos,
        horariosReserva: _config.horariosReserva,
      );
    });
  }

  // ── Días recurrentes cerrados (todos los martes, etc.) ───────────────────────
  Future<void> _agregarDiaRecurrente() async {
    final seleccionados = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => _DialogoDiasRecurrentes(
        diasYaSeleccionados: _config.diasRecurrentesCerrados,
      ),
    );
    if (seleccionados == null) return;

    setState(() {
      _config = ConfigReservas(
        diasActivos: _config.diasActivos,
        horario: _config.horario,
        diasCerrados: _config.diasCerrados,
        motivosCierre: _config.motivosCierre,
        diasRecurrentesCerrados: seleccionados,
        intervalosCerrados: _config.intervalosCerrados,
        duracionSlotMinutos: _config.duracionSlotMinutos,
        horariosReserva: _config.horariosReserva,
      );
    });
  }

  // ── Intervalos de fechas cerradas (del 13 al 15, etc.) ───────────────────────
  Future<void> _agregarIntervalo() async {
    final intervalo = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _DialogoIntervaloFechas(),
    );
    if (intervalo == null) return;

    setState(() {
      final nuevosIntervalos = List<Map<String, String>>.from(_config.intervalosCerrados)
        ..add(intervalo);
      _config = ConfigReservas(
        diasActivos: _config.diasActivos,
        horario: _config.horario,
        diasCerrados: _config.diasCerrados,
        motivosCierre: _config.motivosCierre,
        diasRecurrentesCerrados: _config.diasRecurrentesCerrados,
        intervalosCerrados: nuevosIntervalos,
        duracionSlotMinutos: _config.duracionSlotMinutos,
        horariosReserva: _config.horariosReserva,
      );
    });
  }

  void _eliminarIntervalo(int index) {
    setState(() {
      final nuevosIntervalos = List<Map<String, String>>.from(_config.intervalosCerrados)
        ..removeAt(index);
      _config = ConfigReservas(
        diasActivos: _config.diasActivos,
        horario: _config.horario,
        diasCerrados: _config.diasCerrados,
        motivosCierre: _config.motivosCierre,
        diasRecurrentesCerrados: _config.diasRecurrentesCerrados,
        intervalosCerrados: nuevosIntervalos,
        duracionSlotMinutos: _config.duracionSlotMinutos,
        horariosReserva: _config.horariosReserva,
      );
    });
  }

  void _cambiarSlot(int minutos) {
    setState(() {
      _config = ConfigReservas(
        diasActivos: _config.diasActivos, horario: _config.horario,
        diasCerrados: _config.diasCerrados,
        motivosCierre: _config.motivosCierre,
        diasRecurrentesCerrados: _config.diasRecurrentesCerrados,
        intervalosCerrados: _config.intervalosCerrados,
        duracionSlotMinutos: minutos,
        horariosReserva: _config.horariosReserva,
      );
    });
  }

  TimeOfDay _parseTimeOfDay(String hora) {
    final p = hora.split(':');
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
              child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
            )
          else
            TextButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save_outlined, color: Colors.white, size: 18),
              label: const Text('Guardar',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today, size: 18), text: 'Horarios'),
            Tab(icon: Icon(Icons.access_time, size: 18), text: 'Slots'),
            Tab(icon: Icon(Icons.event_busy, size: 18), text: 'Vacaciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _tabHorarios(),
          _tabSlots(),
          _tabVacaciones(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: HORARIOS (días activos + apertura/cierre)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _tabHorarios() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _seccionHeader(Icons.wb_sunny_outlined, 'Días y horario de apertura'),
        const SizedBox(height: 4),
        Text(
          'Activa los días en los que estás abierto y ajusta el horario de apertura y cierre tocando las horas.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...List.generate(7, (i) => _cardDia(i + 1)),
        const SizedBox(height: 16),
        _seccionHeader(Icons.schedule, 'Duración de cita (web)'),
        const SizedBox(height: 8),
        _cardSlotDuracion(),
      ],
    );
  }

  Widget _cardDia(int dia) {
    final activo  = _config.diasActivos.contains(dia);
    final horario = _config.horario[dia.toString()];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activo ? _color.withValues(alpha: 0.3) : Colors.grey[200]!,
          width: activo ? 1.5 : 1,
        ),
        boxShadow: activo ? [BoxShadow(
          color: _color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)
        )] : [],
      ),
      child: Column(
        children: [
          // ── Fila principal ───────────────────────────────────────────────
          InkWell(
            onTap: () => _toggleDia(dia),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  // Badge día de semana
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activo ? _color : Colors.grey[200],
                    ),
                    child: Center(
                      child: Text(
                        _shortDias[dia]!,
                        style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16,
                          color: activo ? Colors.white : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Nombre
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nombresDias[dia]!,
                            style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15,
                              color: activo ? Colors.black87 : Colors.grey[400],
                            )),
                        if (activo && horario != null)
                          Text(
                            '${horario['apertura']} – ${horario['cierre']}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1976D2)),
                          )
                        else
                          Text(activo ? 'Sin horario' : 'Cerrado',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  Switch(
                    value: activo,
                    onChanged: (_) => _toggleDia(dia),
                    activeThumbColor: Colors.white,
                    activeTrackColor: _color,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
          // ── Fila de horas (solo si activo) ───────────────────────────────
          if (activo)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.access_time_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('Horario:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 10),
                  _chipHora(
                    label: 'Apertura',
                    valor: horario?['apertura'] ?? '09:00',
                    color: const Color(0xFF388E3C),
                    onTap: () => _cambiarHora(dia, true),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('→', style: TextStyle(color: Colors.grey)),
                  ),
                  _chipHora(
                    label: 'Cierre',
                    valor: horario?['cierre'] ?? '20:00',
                    color: const Color(0xFFC62828),
                    onTap: () => _cambiarHora(dia, false),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Chip de hora visual: icono + hora grande + tap para cambiar
  Widget _chipHora({
    required String label,
    required String valor,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              valor,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 11, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Widget _cardSlotDuracion() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duración de cada cita en el formulario web',
            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Los horarios disponibles se mostrarán con esta frecuencia en el formulario de reservas.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [15, 30, 45, 60, 90, 120].map((min) {
              final sel = _config.duracionSlotMinutos == min;
              return ChoiceChip(
                label: Text(min < 60
                    ? '$min min'
                    : '${min ~/ 60}h${min % 60 > 0 ? " ${min % 60}\'" : ""}'),
                selected: sel,
                onSelected: (_) => _cambiarSlot(min),
                selectedColor: _color,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : Colors.black87,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: SLOTS DE RESERVA (horarios exactos por día)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _tabSlots() {
    if (_config.diasActivos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Activa primero los días de apertura',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _seccionHeader(Icons.access_time_filled, 'Horarios de reservas'),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Define los horarios concretos a los que los clientes pueden reservar. '
                  'Por defecto se generan automáticamente según las horas de apertura/cierre.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0D47A1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._config.diasActivos.map((dia) => _cardSlotsParaDia(dia)),
      ],
    );
  }

  Widget _cardSlotsParaDia(int dia) {
    final clave = dia.toString();
    final tienePersonalizados = _config.horariosReserva.containsKey(clave)
        && _config.horariosReserva[clave]!.isNotEmpty;
    final slotsActuales = tienePersonalizados
        ? _config.horariosReserva[clave]!
        : _config.slotsParaDia(dia);
    // Generar todos los slots posibles para este día (sin restricción manual)
    final todosSlots = _generarTodosSlots(dia);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del día
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
                  child: Center(child: Text(_shortDias[dia]!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nombresDias[dia]!,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(
                        tienePersonalizados
                            ? '${slotsActuales.length} horarios personalizados'
                            : 'Automático (${slotsActuales.length} horarios)',
                        style: TextStyle(
                            fontSize: 11,
                            color: tienePersonalizados ? _color : Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                if (tienePersonalizados)
                  TextButton(
                    onPressed: () => _resetSlotsParaDia(dia),
                    child: const Text('Restaurar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),
          // Grid de chips de hora
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: todosSlots.map((hora) {
                final activo = slotsActuales.contains(hora);
                return GestureDetector(
                  onTap: () => _toggleSlotReserva(dia, hora),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: activo ? _color : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activo ? _color : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      hora,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
                        color: activo ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Genera todos los posibles slots desde apertura hasta cierre usando duracionSlotMinutos
  List<String> _generarTodosSlots(int dia) {
    final h = _config.horario[dia.toString()];
    if (h == null) return [];
    final apertura = ConfigReservas._parseTimeStr(h['apertura'] ?? '09:00');
    final cierre   = ConfigReservas._parseTimeStr(h['cierre'] ?? '20:00');
    final slots    = <String>[];
    // Usar duracionSlotMinutos de la configuración
    final intervalo = _config.duracionSlotMinutos;
    var totalMin  = apertura.hour * 60 + apertura.minute;
    final maxMin  = cierre.hour * 60 + cierre.minute;
    while (totalMin < maxMin) {
      final h2 = totalMin ~/ 60;
      final m2 = totalMin % 60;
      slots.add('${h2.toString().padLeft(2,'0')}:${m2.toString().padLeft(2,'0')}');
      totalMin += intervalo;
    }
    return slots;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: VACACIONES / DÍAS CERRADOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _tabVacaciones() {
    final dias = _config.diasCerrados;
    // Agrupar por mes
    final groupedByMonth = <String, List<String>>{};
    for (final d in dias) {
      final dt = DateTime.tryParse(d);
      if (dt == null) continue;
      final mes = DateFormat('MMMM yyyy', 'es').format(dt).capitalizedFirst;
      groupedByMonth.putIfAbsent(mes, () => []).add(d);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _seccionHeader(Icons.beach_access, 'Días cerrados / Vacaciones'),
        const SizedBox(height: 4),
        Text(
          'Añade días específicos en los que el negocio permanecerá cerrado '
          '(festivos, vacaciones, mantenimiento…). El formulario web no aceptará reservas esos días.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 16),

        // ── Botones añadir ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _agregarDiaCerrado,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Día específico', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _color,
                  side: const BorderSide(color: Color(0xFF0D47A1)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _agregarDiaRecurrente,
                icon: const Icon(Icons.repeat, size: 18),
                label: const Text('Recurrente', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange[800],
                  side: BorderSide(color: Colors.orange[800]!),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _agregarIntervalo,
                icon: const Icon(Icons.date_range, size: 18),
                label: const Text('Intervalo', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple[700],
                  side: BorderSide(color: Colors.purple[700]!),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Días recurrentes ──────────────────────────────────────────────
        if (_config.diasRecurrentesCerrados.isNotEmpty) ...[
          _seccionHeader(Icons.repeat, 'Cerrado todos los...'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _config.diasRecurrentesCerrados.map((dia) {
              return Chip(
                avatar: Icon(Icons.block, size: 16, color: Colors.orange[800]),
                label: Text(_nombresDias[dia] ?? ''),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    final nuevos = List<int>.from(_config.diasRecurrentesCerrados)..remove(dia);
                    _config = ConfigReservas(
                      diasActivos: _config.diasActivos,
                      horario: _config.horario,
                      diasCerrados: _config.diasCerrados,
                      motivosCierre: _config.motivosCierre,
                      diasRecurrentesCerrados: nuevos,
                      intervalosCerrados: _config.intervalosCerrados,
                      duracionSlotMinutos: _config.duracionSlotMinutos,
                      horariosReserva: _config.horariosReserva,
                    );
                  });
                },
                backgroundColor: Colors.orange[50],
                side: BorderSide(color: Colors.orange[200]!),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // ── Intervalos ────────────────────────────────────────────────────
        if (_config.intervalosCerrados.isNotEmpty) ...[
          _seccionHeader(Icons.date_range, 'Intervalos cerrados'),
          const SizedBox(height: 8),
          ..._config.intervalosCerrados.asMap().entries.map((entry) {
            final index = entry.key;
            final intervalo = entry.value;
            final inicio = DateTime.parse(intervalo['inicio']!);
            final fin = DateTime.parse(intervalo['fin']!);
            final motivo = intervalo['motivo'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_busy, color: Colors.purple[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('d MMM', 'es').format(inicio)} - ${DateFormat('d MMM yyyy', 'es').format(fin)}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple[900]),
                        ),
                        if (motivo.isNotEmpty)
                          Text(motivo, style: TextStyle(fontSize: 12, color: Colors.purple[700])),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.grey,
                    onPressed: () => _eliminarIntervalo(index),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],

        // ── Sección de días específicos ───────────────────────────────────
        _seccionHeader(Icons.event_busy, 'Días específicos cerrados'),
        const SizedBox(height: 8),

        // ── Lista de días cerrados ────────────────────────────────────────
        if (dias.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Sin días cerrados añadidos',
                    style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                const SizedBox(height: 6),
                Text('Estás abierto todos los días de tu horario habitual.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center),
              ]),
            ),
          )
        else
          ...groupedByMonth.entries.map((entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13,
                      color: Color(0xFF0D47A1)),
                ),
              ),
              ...entry.value.map((fechaStr) => _tarjetaDiaCerrado(fechaStr)),
              const SizedBox(height: 8),
            ],
          )),
      ],
    );
  }

  Widget _tarjetaDiaCerrado(String fechaStr) {
    final fecha = DateTime.tryParse(fechaStr);
    final esFinde = fecha != null && (fecha.weekday == 6 || fecha.weekday == 7);
    final diasRestantes = fecha != null
        ? fecha.difference(DateTime.now()).inDays
        : null;
    final motivo = _config.motivosCierre[fechaStr];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: fecha != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${fecha.day}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18,
                          color: Color(0xFFC62828)),
                    ),
                    Text(
                      DateFormat('MMM', 'es').format(fecha).toUpperCase(),
                      style: const TextStyle(fontSize: 8, color: Color(0xFFC62828), letterSpacing: 0.5),
                    ),
                  ],
                )
              : const Icon(Icons.event_busy, color: Color(0xFFC62828)),
        ),
        title: Text(
          fecha != null
              ? DateFormat('EEEE, d MMMM', 'es').format(fecha).capitalizedFirst
              : fechaStr,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fecha != null)
              Row(children: [
                if (esFinde) Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text('Fin de semana',
                      style: TextStyle(fontSize: 9, color: Colors.orange[700], fontWeight: FontWeight.w600)),
                ),
                if (diasRestantes != null && diasRestantes >= 0)
                  Text(
                    diasRestantes == 0 ? 'hoy' : 'en $diasRestantes días',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  )
                else if (diasRestantes != null && diasRestantes < 0)
                  Text('hace ${-diasRestantes} días',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ]),
            // Mostrar motivo si existe
            if (motivo != null && motivo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.red[700]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        motivo,
                        style: TextStyle(fontSize: 11, color: Colors.red[900], fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
          onPressed: () => _eliminarDiaCerrado(fechaStr),
          tooltip: 'Eliminar',
        ),
      ),
    );
  }

  // ── Helper común ──────────────────────────────────────────────────────────

  Widget _seccionHeader(IconData icono, String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(children: [
        Icon(icono, size: 17, color: _color),
        const SizedBox(width: 8),
        Text(titulo,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0D47A1))),
      ]),
    );
  }
}

extension _Cap on String {
  String get capitalizedFirst =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// PICKER PERSONALIZADO DE HORA  — drum-roll style bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _HoraPickerSheet extends StatefulWidget {
  final TimeOfDay horaInicial;
  final String titulo;
  final Color color;

  const _HoraPickerSheet({
    required this.horaInicial,
    required this.titulo,
    required this.color,
  });

  @override
  State<_HoraPickerSheet> createState() => _HoraPickerSheetState();
}

class _HoraPickerSheetState extends State<_HoraPickerSheet> {
  late int _hora;
  late int _minuto;

  // Minutos disponibles: cada 5 minutos
  static const _minutos = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  @override
  void initState() {
    super.initState();
    _hora = widget.horaInicial.hour;
    // Redondear el minuto al más cercano de _minutos
    _minuto = _minutos.reduce((a, b) =>
        (a - widget.horaInicial.minute).abs() < (b - widget.horaInicial.minute).abs() ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            // Título con icono de color
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.access_time, color: widget.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(widget.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selectores de hora y minuto con CupertinoPicker
            SizedBox(
              height: 220,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Selector de horas
                  Expanded(
                    child: Column(
                      children: [
                        Text('Hora', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: CupertinoPicker(
                            backgroundColor: Colors.white,
                            itemExtent: 50,
                            scrollController: FixedExtentScrollController(initialItem: _hora),
                            onSelectedItemChanged: (index) => setState(() => _hora = index),
                            children: List.generate(
                              24,
                              (index) => Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: widget.color,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Separador
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                  ),
                  // Selector de minutos
                  Expanded(
                    child: Column(
                      children: [
                        Text('Minutos', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: CupertinoPicker(
                            backgroundColor: Colors.white,
                            itemExtent: 50,
                            scrollController: FixedExtentScrollController(
                              initialItem: _minutos.indexOf(_minuto),
                            ),
                            onSelectedItemChanged: (index) => setState(() => _minuto = _minutos[index]),
                            children: _minutos.map((min) => Center(
                              child: Text(
                                min.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: widget.color,
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Hora seleccionada en grande
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_hora.toString().padLeft(2, '0')}:${_minuto.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: widget.color,
                  ),
                ),
              ),
            ),

            // Botones
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                          context, TimeOfDay(hour: _hora, minute: _minuto)),
                      style: FilledButton.styleFrom(
                          backgroundColor: widget.color,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Confirmar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PICKER PERSONALIZADO DE FECHAS CERRADAS — calendario con TableCalendar
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarioCerradosSheet extends StatefulWidget {
  final List<String> diasYaCerrados;
  final List<int> diasActivosSemana;

  const _CalendarioCerradosSheet({
    required this.diasYaCerrados,
    required this.diasActivosSemana,
  });

  @override
  State<_CalendarioCerradosSheet> createState() =>
      _CalendarioCerradosSheetState();
}

class _CalendarioCerradosSheetState
    extends State<_CalendarioCerradosSheet> {
  static const _color = Color(0xFF0D47A1);
  final Set<DateTime> _seleccionados = {};
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Pre-marcar los ya cerrados
    for (final s in widget.diasYaCerrados) {
      final d = DateTime.tryParse(s);
      if (d != null) _seleccionados.add(_normalize(d));
    }
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _esCerrado(DateTime d) => _seleccionados.contains(_normalize(d));

  @override
  Widget build(BuildContext context) {
    final nuevos = _seleccionados
        .where((d) => !widget.diasYaCerrados.contains(DateFormat('yyyy-MM-dd').format(d)))
        .toSet();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          // Cabecera
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.event_busy, color: Colors.red[700], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Días cerrados',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                      Text('Toca los días para marcarlos/desmarcarlos',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                if (nuevos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.red[700],
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('+${nuevos.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Leyenda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _leyenda(Colors.red[700]!, 'Cerrado'),
                const SizedBox(width: 16),
                _leyenda(Colors.grey[300]!, 'Abierto'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Calendario
          TableCalendar(
            locale: 'es_ES',
            firstDay: DateTime.now().subtract(const Duration(days: 30)),
            lastDay: DateTime.now().add(const Duration(days: 730)),
            focusedDay: _focusedDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              leftChevronIcon:
                  Icon(Icons.chevron_left, color: _color),
              rightChevronIcon:
                  Icon(Icons.chevron_right, color: _color),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: _color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                  color: _color, fontWeight: FontWeight.bold),
              selectedDecoration: BoxDecoration(
                color: Colors.red[700],
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white),
              weekendTextStyle:
                  TextStyle(color: Colors.orange[700]),
              defaultTextStyle: const TextStyle(fontSize: 13),
            ),
            selectedDayPredicate: _esCerrado,
            onDaySelected: (selected, focused) {
              setState(() {
                _focusedDay = focused;
                final norm = _normalize(selected);
                if (_seleccionados.contains(norm)) {
                  _seleccionados.remove(norm);
                } else {
                  _seleccionados.add(norm);
                }
              });
            },
            onPageChanged: (focused) =>
                setState(() => _focusedDay = focused),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, focusedDay) {
                // Días fuera del horario habitual: mostrar en gris claro
                final sinActivo = !widget.diasActivosSemana.contains(day.weekday);
                if (sinActivo) {
                  return Center(
                    child: Text('${day.day}',
                        style: TextStyle(
                            color: Colors.grey[350], fontSize: 13)),
                  );
                }
                return null; // usar el estilo por defecto
              },
            ),
          ),

          // Botones
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: nuevos.isEmpty
                        ? null
                        : () => Navigator.pop(context, nuevos),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(
                      nuevos.isEmpty
                          ? 'Sin cambios'
                          : 'Añadir ${nuevos.length} día${nuevos.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO: Seleccionar días recurrentes cerrados (todos los martes, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class _DialogoDiasRecurrentes extends StatefulWidget {
  final List<int> diasYaSeleccionados;
  const _DialogoDiasRecurrentes({required this.diasYaSeleccionados});

  @override
  State<_DialogoDiasRecurrentes> createState() => _DialogoDiasRecurrentesState();
}

class _DialogoDiasRecurrentesState extends State<_DialogoDiasRecurrentes> {
  late List<int> _seleccionados;

  static const _nombresDias = {
    1: 'Lunes', 2: 'Martes', 3: 'Miércoles',
    4: 'Jueves', 5: 'Viernes', 6: 'Sábado', 7: 'Domingo',
  };

  @override
  void initState() {
    super.initState();
    _seleccionados = List.from(widget.diasYaSeleccionados);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.repeat, color: Colors.orange),
          SizedBox(width: 8),
          Text('Cerrado recurrente'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecciona los días de la semana que estarás siempre cerrado:',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          ..._nombresDias.entries.map((e) {
            final dia = e.key;
            final nombre = e.value;
            final seleccionado = _seleccionados.contains(dia);
            return CheckboxListTile(
              value: seleccionado,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _seleccionados.add(dia);
                  } else {
                    _seleccionados.remove(dia);
                  }
                });
              },
              title: Text(nombre),
              activeColor: Colors.orange[800],
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _seleccionados),
          style: FilledButton.styleFrom(backgroundColor: Colors.orange[800]),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO: Seleccionar intervalo de fechas (del 13 al 15, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class _DialogoIntervaloFechas extends StatefulWidget {
  const _DialogoIntervaloFechas();

  @override
  State<_DialogoIntervaloFechas> createState() => _DialogoIntervaloFechasState();
}

class _DialogoIntervaloFechasState extends State<_DialogoIntervaloFechas> {
  DateTime? _inicio;
  DateTime? _fin;
  final _motivoCtrl = TextEditingController();

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esInicio
          ? (_inicio ?? DateTime.now())
          : (_fin ?? _inicio ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() {
        if (esInicio) {
          _inicio = picked;
          if (_fin != null && _fin!.isBefore(_inicio!)) {
            _fin = null;
          }
        } else {
          _fin = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final puedeGuardar = _inicio != null && _fin != null && _motivoCtrl.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.date_range, color: Colors.purple),
          SizedBox(width: 8),
          Text('Intervalo cerrado'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecciona un rango de fechas en el que estarás cerrado:',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _seleccionarFecha(true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _inicio == null
                        ? 'Desde...'
                        : DateFormat('d MMM yyyy', 'es').format(_inicio!),
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple[700],
                    side: BorderSide(color: Colors.purple[300]!),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _inicio == null ? null : () => _seleccionarFecha(false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _fin == null
                        ? 'Hasta...'
                        : DateFormat('d MMM yyyy', 'es').format(_fin!),
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple[700],
                    side: BorderSide(color: Colors.purple[300]!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _motivoCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            onChanged: (_) => setState(() {}), // Actualizar botón Guardar
            decoration: InputDecoration(
              labelText: 'Motivo *',
              hintText: 'Ej: Vacaciones de verano',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.info_outline, color: Colors.purple[700]),
              helperText: '* Se mostrará en el formulario web',
              helperStyle: TextStyle(color: Colors.purple[700], fontSize: 11),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: puedeGuardar
              ? () {
                  Navigator.pop(context, {
                    'inicio': DateFormat('yyyy-MM-dd').format(_inicio!),
                    'fin': DateFormat('yyyy-MM-dd').format(_fin!),
                    'motivo': _motivoCtrl.text.trim(),
                  });
                }
              : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.purple[700]),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}



















































