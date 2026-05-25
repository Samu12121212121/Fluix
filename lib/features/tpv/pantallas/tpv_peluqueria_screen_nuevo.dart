// TPV Peluquería - Vista Agenda Profesional con Timeline
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/tpv_type_switcher.dart';
import 'tpv_root_screen.dart';
import 'tpv_tienda_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// COLORES TEMA CIAN/MAGENTA
// ═══════════════════════════════════════════════════════════════════════════

const Color kCian = Color(0xFF00FFC8);
const Color kMagenta = Color(0xFFFF3296);
const Color kRosa = Color(0xFFFF4678);
const Color kFondoOscuro = Color(0xFF0A0F23);
const Color kSuperficie = Color(0xFF151932);
const Color kTarjeta = Color(0xFF1E2139);
const Color kDivisor = Color(0xFF2A2E45);

// Colores para profesionales (8 opciones vibrantes)
const List<Color> kProfColors = [
  Color(0xFF00FFC8), // Cian
  Color(0xFFFF3296), // Magenta
  Color(0xFFFF4678), // Rosa
  Color(0xFF00D9FF), // Azul claro
  Color(0xFFFFB84D), // Naranja
  Color(0xFF4CAF50), // Verde
  Color(0xFF9C27B0), // Púrpura
  Color(0xFF2196F3), // Azul
];

Color profColor(int idx) => kProfColors[idx % kProfColors.length];

// ═══════════════════════════════════════════════════════════════════════════
// MODELO: PROFESIONAL (vinculado con empleados de la empresa)
// ═══════════════════════════════════════════════════════════════════════════

class Profesional {
  final String id;
  final String nombre;
  final String? email;
  final String? telefono;
  final String? especialidad;
  final String? avatar;
  final int colorIdx;
  final bool activo;
  final String horaEntrada;
  final String horaSalida;

  const Profesional({
    required this.id,
    required this.nombre,
    this.email,
    this.telefono,
    this.especialidad,
    this.avatar,
    required this.colorIdx,
    this.activo = true,
    this.horaEntrada = '09:00',
    this.horaSalida = '20:00',
  });

  Color get color => profColor(colorIdx);

  String get initials {
    final parts = nombre.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nombre.substring(0, nombre.length.clamp(0, 2)).toUpperCase();
  }

  // Crear desde documento de Firestore (empleados)
  factory Profesional.fromEmpleado(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Profesional(
      id: doc.id,
      nombre: data['nombre'] ?? 'Sin nombre',
      email: data['email'],
      telefono: data['telefono'],
      especialidad: data['puesto'] ?? data['especialidad'],
      avatar: data['foto_url'],
      colorIdx: (data['color_index'] as int?) ?? 0,
      activo: data['activo'] ?? true,
      horaEntrada: data['hora_entrada'] ?? '09:00',
      horaSalida: data['hora_salida'] ?? '20:00',
    );
  }

  // Crear desde profesional de TPV
  factory Profesional.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Profesional(
      id: doc.id,
      nombre: data['nombre'] ?? 'Profesional',
      email: data['email'],
      telefono: data['telefono'],
      especialidad: data['especialidad'],
      avatar: data['avatar'],
      colorIdx: (data['color_index'] as int?) ?? 0,
      activo: data['activo'] ?? true,
      horaEntrada: data['hora_entrada'] ?? '09:00',
      horaSalida: data['hora_salida'] ?? '20:00',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODELO: CITA
// ═══════════════════════════════════════════════════════════════════════════

class Cita {
  final String id;
  final String profesionalId;
  final String clienteNombre;
  final String? clienteTelefono;
  final String servicioNombre;
  final DateTime horaInicio;
  final int duracionMinutos;
  final String? notas;
  final String estado; // pendiente, confirmada, completada, cancelada

  const Cita({
    required this.id,
    required this.profesionalId,
    required this.clienteNombre,
    this.clienteTelefono,
    required this.servicioNombre,
    required this.horaInicio,
    required this.duracionMinutos,
    this.notas,
    this.estado = 'pendiente',
  });

  DateTime get horaFin => horaInicio.add(Duration(minutes: duracionMinutos));

  factory Cita.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Cita(
      id: doc.id,
      profesionalId: data['profesional_id'] ?? '',
      clienteNombre: data['cliente_nombre'] ?? 'Cliente',
      clienteTelefono: data['cliente_telefono'],
      servicioNombre: data['servicio_nombre'] ?? 'Servicio',
      horaInicio: (data['hora_inicio'] as Timestamp).toDate(),
      duracionMinutos: (data['duracion_minutos'] as int?) ?? 30,
      notas: data['notas'],
      estado: data['estado'] ?? 'pendiente',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL: TPV PELUQUERÍA CON VISTA AGENDA
// ═══════════════════════════════════════════════════════════════════════════

class TpvPeluqueriaScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final bool esPropietario;

  const TpvPeluqueriaScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
    this.esPropietario = false,
  });

  @override
  State<TpvPeluqueriaScreen> createState() => _TpvPeluqueriaScreenState();
}

class _TpvPeluqueriaScreenState extends State<TpvPeluqueriaScreen> {
  final _scrollController = ScrollController();
  DateTime _fechaSeleccionada = DateTime.now();
  String? _profesionalSeleccionado;

  // Horas de operación
  final int _horaInicio = 8; // 08:00
  final int _horaFin = 21; // 21:00
  final int _intervaloMinutos = 30;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kFondoOscuro,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // Panel izquierdo: Lista de profesionales
          Container(
            width: 280,
            color: kSuperficie,
            child: _buildPanelProfesionales(),
          ),
          const VerticalDivider(width: 1, color: kDivisor),
          // Panel central: Agenda Timeline
          Expanded(
            child: _buildAgendaTimeline(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botón agregar profesional
          FloatingActionButton.extended(
            onPressed: () => _mostrarDialogoNuevoProfesional(),
            backgroundColor: kCian,
            foregroundColor: kFondoOscuro,
            icon: const Icon(Icons.person_add),
            label: const Text('Nuevo Profesional'),
          ),
          const SizedBox(height: 12),
          // Botón agregar cita
          FloatingActionButton(
            onPressed: () => _mostrarDialogoNuevaCita(),
            backgroundColor: kMagenta,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kSuperficie,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Icon(Icons.cut, size: 20, color: kMagenta),
          const SizedBox(width: 8),
          const Text(
            'TPV Peluquería',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          // Selector de fecha
          InkWell(
            onTap: () => _seleccionarFecha(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kTarjeta,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kCian),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: kCian),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, dd MMM yyyy', 'es_ES')
                        .format(_fechaSeleccionada),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Botón de hoy
        TextButton.icon(
          onPressed: () => setState(() => _fechaSeleccionada = DateTime.now()),
          icon: const Icon(Icons.today, size: 16),
          label: const Text('Hoy'),
          style: TextButton.styleFrom(foregroundColor: kCian),
        ),
        const SizedBox(width: 8),
        // Switcher de TPV
        TpvTypeSwitcher(
          tipoActual: 'peluqueria',
          onTipoChanged: (tipo) {
            Widget pantalla;
            switch (tipo) {
              case 'bar':
                pantalla = TpvRootScreen(
                  empresaId: widget.empresaId,
                  esAdmin: widget.esAdmin,
                  esPropietario: true,
                );
                break;
              case 'tienda':
                pantalla = TpvTiendaScreen(
                  empresaId: widget.empresaId,
                  esAdmin: widget.esAdmin,
                  esPropietario: true,
                );
                break;
              default:
                return;
            }
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => pantalla),
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PANEL DE PROFESIONALES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPanelProfesionales() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kDivisor)),
          ),
          child: const Text(
            'PROFESIONALES',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        // Lista de profesionales
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Intentar cargar desde empleados primero, luego profesionales
            stream: FirebaseFirestore.instance
                .collection('empresas')
                .doc(widget.empresaId)
                .collection('empleados')
                .where('activo', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: kCian),
                );
              }

              final empleados = snapshot.data!.docs;

              if (empleados.isEmpty) {
                return _buildEmptyProfesionales();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: empleados.length,
                itemBuilder: (context, index) {
                  final prof = Profesional.fromEmpleado(empleados[index]);
                  final seleccionado = _profesionalSeleccionado == prof.id;

                  return _buildProfesionalCard(prof, seleccionado);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProfesionales() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline,
                size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            const Text(
              'Sin profesionales',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega empleados o profesionales\npara empezar',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _mostrarDialogoNuevoProfesional(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar Profesional'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kCian,
                foregroundColor: kFondoOscuro,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfesionalCard(Profesional prof, bool seleccionado) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _profesionalSeleccionado =
                seleccionado ? null : prof.id;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: seleccionado ? prof.color.withValues(alpha: 0.2) : kTarjeta,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado ? prof.color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: prof.color.withValues(alpha: 0.3),
                foregroundColor: prof.color,
                backgroundImage:
                    prof.avatar != null ? NetworkImage(prof.avatar!) : null,
                child: prof.avatar == null
                    ? Text(
                        prof.initials,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prof.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (prof.especialidad != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        prof.especialidad!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: prof.color),
                        const SizedBox(width: 4),
                        Text(
                          '${prof.horaEntrada} - ${prof.horaSalida}',
                          style: TextStyle(
                            color: prof.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Indicador de selección
              if (seleccionado)
                Icon(Icons.check_circle, color: prof.color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AGENDA TIMELINE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAgendaTimeline() {
    return Container(
      color: kFondoOscuro,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('empleados')
            .where('activo', isEqualTo: true)
            .snapshots(),
        builder: (context, profSnapshot) {
          if (!profSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: kCian),
            );
          }

          final profesionales = profSnapshot.data!.docs
              .map((d) => Profesional.fromEmpleado(d))
              .where((p) =>
                  _profesionalSeleccionado == null ||
                  p.id == _profesionalSeleccionado)
              .toList();

          if (profesionales.isEmpty) {
            return const Center(
              child: Text(
                'Selecciona un profesional',
                style: TextStyle(color: Colors.white38),
              ),
            );
          }

          return _buildTimelineGrid(profesionales);
        },
      ),
    );
  }

  Widget _buildTimelineGrid(List<Profesional> profesionales) {
    // Calcular altura de cada slot (30 minutos)
    const alturaPorSlot = 60.0;
    final totalSlots = ((_horaFin - _horaInicio) * 60) ~/ _intervaloMinutos;

    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: totalSlots * alturaPorSlot,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Columna de horas (lado izquierdo)
            SizedBox(
              width: 80,
              child: _buildColumnaTiempo(totalSlots, alturaPorSlot),
            ),
            // Columnas de profesionales
            Expanded(
              child: Row(
                children: profesionales.map((prof) {
                  return Expanded(
                    child: _buildColumnaProfesional(
                      prof,
                      totalSlots,
                      alturaPorSlot,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Columna de tiempo (horas)
  Widget _buildColumnaTiempo(int totalSlots, double alturaPorSlot) {
    return Container(
      decoration: const BoxDecoration(
        color: kSuperficie,
        border: Border(right: BorderSide(color: kDivisor, width: 2)),
      ),
      child: Column(
        children: List.generate(totalSlots, (index) {
          final minutosTotales = _horaInicio * 60 + index * _intervaloMinutos;
          final hora = minutosTotales ~/ 60;
          final minutos = minutosTotales % 60;
          final esHoraCompleta = minutos == 0;

          return Container(
            height: alturaPorSlot,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: esHoraCompleta ? kDivisor : kDivisor.withValues(alpha: 0.3),
                  width: esHoraCompleta ? 1.5 : 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.only(right: 12, top: 4),
            alignment: Alignment.centerRight,
            child: Text(
              '${hora.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: esHoraCompleta ? Colors.white : Colors.white38,
                fontSize: esHoraCompleta ? 13 : 11,
                fontWeight: esHoraCompleta ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
      ),
    );
  }

  // Columna de profesional con citas
  Widget _buildColumnaProfesional(
    Profesional prof,
    int totalSlots,
    double alturaPorSlot,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('citas')
          .where('profesional_id', isEqualTo: prof.id)
          .where('fecha',
              isEqualTo: DateFormat('yyyy-MM-dd').format(_fechaSeleccionada))
          .snapshots(),
      builder: (context, citasSnapshot) {
        final citas = citasSnapshot.hasData
            ? citasSnapshot.data!.docs.map((d) => Cita.fromDoc(d)).toList()
            : <Cita>[];

        return Stack(
          children: [
            // Grid de fondo con líneas
            Column(
              children: List.generate(totalSlots, (index) {
                final minutosTotales =
                    _horaInicio * 60 + index * _intervaloMinutos;
                final minutos = minutosTotales % 60;
                final esHoraCompleta = minutos == 0;

                return Container(
                  height: alturaPorSlot,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: esHoraCompleta
                            ? kDivisor
                            : kDivisor.withValues(alpha: 0.3),
                        width: esHoraCompleta ? 1.5 : 0.5,
                      ),
                      right: const BorderSide(color: kDivisor, width: 0.5),
                    ),
                  ),
                );
              }),
            ),
            // Citas superpuestas
            ...citas.map((cita) => _buildCitaBloque(cita, prof, alturaPorSlot)),
          ],
        );
      },
    );
  }

  // Bloque de cita visual
  Widget _buildCitaBloque(Cita cita, Profesional prof, double alturaPorSlot) {
    // Calcular posición y altura
    final minutosDesdeInicio =
        cita.horaInicio.hour * 60 + cita.horaInicio.minute - _horaInicio * 60;
    final top = (minutosDesdeInicio / _intervaloMinutos) * alturaPorSlot;
    final altura = (cita.duracionMinutos / _intervaloMinutos) * alturaPorSlot;

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: altura - 4,
      child: InkWell(
        onTap: () => _mostrarDetalleCita(cita),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [prof.color, prof.color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: prof.color.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hora
              Row(
                children: [
                  const Icon(Icons.access_time, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('HH:mm').format(cita.horaInicio),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${cita.duracionMinutos}min',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Cliente
              Text(
                cita.clienteNombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Servicio
              Text(
                cita.servicioNombre,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIÁLOGOS Y ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es'),
    );
    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
    }
  }

  void _mostrarDialogoNuevoProfesional() {
    showDialog(
      context: context,
      builder: (ctx) => const AlertDialog(
        title: Text('Nuevo Profesional'),
        content: Text(
          'Función en desarrollo.\n\n'
          'Por ahora, agrega empleados desde el módulo de RRHH '
          'y aparecerán automáticamente aquí.',
        ),
      ),
    );
  }

  void _mostrarDialogoNuevaCita() {
    showDialog(
      context: context,
      builder: (ctx) => const AlertDialog(
        title: Text('Nueva Cita'),
        content: Text('Función de nueva cita en desarrollo'),
      ),
    );
  }

  void _mostrarDetalleCita(Cita cita) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTarjeta,
        title: const Row(
          children: [
            Icon(Icons.calendar_month, color: kCian),
            SizedBox(width: 8),
            Text('Detalle de Cita', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Cliente', cita.clienteNombre),
            _buildInfoRow('Servicio', cita.servicioNombre),
            _buildInfoRow('Hora',
                '${DateFormat('HH:mm').format(cita.horaInicio)} - ${DateFormat('HH:mm').format(cita.horaFin)}'),
            _buildInfoRow('Duración', '${cita.duracionMinutos} minutos'),
            if (cita.clienteTelefono != null)
              _buildInfoRow('Teléfono', cita.clienteTelefono!),
            if (cita.notas != null) ...[
              const SizedBox(height: 12),
              const Text('Notas:',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(cita.notas!,
                  style: const TextStyle(color: Colors.white)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: kCian)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

