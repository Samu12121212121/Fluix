import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../services/estadisticas_trigger_service.dart';

class ModuloReservas extends StatelessWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  final String collectionId;
  final String moduloSingular;
  final String moduloPlural;
  /// Si true, el formulario muestra un selector de profesional (empleado asignado)
  final bool mostrarProfesional;

  const ModuloReservas({
    super.key,
    required this.empresaId,
    this.sesion,
    this.collectionId = 'reservas',
    this.moduloSingular = 'Reserva',
    this.moduloPlural = 'Reservas',
    this.mostrarProfesional = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection(collectionId)
          .orderBy('fecha', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final pendientes  = docs.where((d) => (d['estado'] as String? ?? '').toUpperCase() == 'PENDIENTE').toList();
        final confirmadas = docs.where((d) => (d['estado'] as String? ?? '').toUpperCase() == 'CONFIRMADA').toList();
        final canceladas  = docs.where((d) => (d['estado'] as String? ?? '').toUpperCase() == 'CANCELADA').toList();

        return Stack(
          children: [
            DefaultTabController(
              length: 5,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // ── KPIs (scrollable) ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _miniKpi('Pendientes',  '${pendientes.length}',  const Color(0xFFF57C00)),
                          _divider(),
                          _miniKpi('Confirmadas', '${confirmadas.length}', const Color(0xFF4CAF50)),
                          _divider(),
                          _miniKpi('Canceladas',  '${canceladas.length}',  const Color(0xFFD32F2F)),
                          _divider(),
                          _miniKpi('Total',       '${docs.length}',        const Color(0xFF1976D2)),
                        ],
                      ),
                    ),
                  ),

                  // ── TABS (sticky) ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: TabBar(
                      labelColor: const Color(0xFF1976D2),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF1976D2),
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        const Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month, size: 20),
                              SizedBox(width: 8),
                              Text('Calendario'),
                            ],
                          ),
                        ),
                        _tab('Pendientes',  pendientes.length,  const Color(0xFFF57C00)),
                        _tab('Confirmadas', confirmadas.length, const Color(0xFF4CAF50)),
                        _tab('Canceladas',  canceladas.length,  const Color(0xFFD32F2F)),
                        _tab('Todas',       docs.length,        const Color(0xFF1976D2)),
                      ],
                    ),
                  ),
                ],

                // ── CONTENIDO ─────────────────────────────────────────
                body: TabBarView(
                      children: [
                        // 1. Calendario Semanal (NUEVO)
                        _VistaCalendarioSemanal(
                          reservas: docs,
                          empresaId: empresaId,
                          mostrarAcciones: sesion?.puedeGestionarReservas ?? true,
                          collectionId: collectionId,
                          moduloSingular: moduloSingular,
                          moduloPlural: moduloPlural,
                          onAddReserva: (date) => _mostrarFormulario(context, date),
                        ),
                        // 2. Pendientes
                        _ListaReservas(
                          reservas: pendientes,
                          empresaId: empresaId,
                          mostrarAcciones: sesion?.puedeGestionarReservas ?? true,
                          mensajeVacio: 'No hay ${moduloPlural.toLowerCase()} pendientes 🎉',
                          collectionId: collectionId,
                          moduloSingular: moduloSingular,
                        ),
                        // 3. Confirmadas
                        _ListaReservas(
                          reservas: confirmadas,
                          empresaId: empresaId,
                          mostrarAcciones: sesion?.puedeGestionarReservas ?? true,
                          mensajeVacio: 'No hay ${moduloPlural.toLowerCase()} confirmadas',
                          collectionId: collectionId,
                          moduloSingular: moduloSingular,
                        ),
                        // 4. Canceladas
                        _ListaReservas(
                          reservas: canceladas,
                          empresaId: empresaId,
                          mostrarAcciones: false,
                          mensajeVacio: 'No hay ${moduloPlural.toLowerCase()} canceladas',
                          collectionId: collectionId,
                          moduloSingular: moduloSingular,
                        ),
                        // 5. Todas
                        _ListaReservas(
                          reservas: docs,
                          empresaId: empresaId,
                          mostrarAcciones: sesion?.puedeGestionarReservas ?? true,
                          mensajeVacio: 'Aún no hay ${moduloPlural.toLowerCase()}. ¡Crea la primera!',
                          collectionId: collectionId,
                          moduloSingular: moduloSingular,
                        ),
                      ],
                    ),
              ),
            ),

            // FAB nueva reserva (solo admin/propietario)
            if (sesion?.puedeGestionarReservas ?? true)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'fab_reserva',
                  onPressed: () => _mostrarFormulario(context),
                  icon: const Icon(Icons.add),
                  label: Text('Nueva $moduloSingular'),
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _miniKpi(String label, String valor, Color color) => Column(
    children: [
      Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
    ],
  );

  Widget _divider() => Container(width: 1, height: 30, color: Colors.grey[300]);

  Tab _tab(String label, int count, Color color) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    ),
  );

  void _mostrarFormulario(BuildContext context, [DateTime? fechaPreselec]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioReserva(
        empresaId: empresaId,
        collectionId: collectionId,
        moduloSingular: moduloSingular,
        fechaInicial: fechaPreselec,
        mostrarProfesional: mostrarProfesional,
      ),
    );
  }
}

// ── VISTA CALENDARIO SEMANAL ──────────────────────────────────────────────────

class _VistaCalendarioSemanal extends StatefulWidget {
  final List<QueryDocumentSnapshot> reservas;
  final String empresaId;
  final bool mostrarAcciones;
  final String collectionId;
  final String moduloSingular;
  final String moduloPlural;
  final void Function(DateTime)? onAddReserva;

  const _VistaCalendarioSemanal({
    required this.reservas,
    required this.empresaId,
    required this.mostrarAcciones,
    required this.collectionId,
    required this.moduloSingular,
    required this.moduloPlural,
    this.onAddReserva,
  });

  @override
  State<_VistaCalendarioSemanal> createState() => _VistaCalendarioSemanalState();
}

class _VistaCalendarioSemanalState extends State<_VistaCalendarioSemanal> {
  DateTime _selectedDate = DateTime.now();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Scroll inicial para centrar hoy (aproximado)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0); // Empezar en hoy
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<QueryDocumentSnapshot> _getReservasDelDia(DateTime date) {
    return widget.reservas.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final raw = data['fecha']; // Timestamp o String
      DateTime? dt;
      if (raw is Timestamp) dt = raw.toDate();
      else if (raw is String) dt = DateTime.tryParse(raw);
      
      if (dt == null) return false;
      return _isSameDay(dt, date);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Generar lista de días: Hoy + próximos 30 días
    final days = List.generate(31, (index) => now.add(Duration(days: index)));

    final reservasHoy = _getReservasDelDia(_selectedDate);

    return Column(
      children: [
        // ── Selector de Fecha Horizontal ───────────────────────────────────
        Container(
          height: 90,
          color: Colors.white,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final isSelected = _isSameDay(day, _selectedDate);
              final isToday = _isSameDay(day, now);
              
              // Verificar si hay reservas este día para mostrar puntito
              final reservasDia = _getReservasDelDia(day);
              final hasPending = reservasDia.any((d) => (d['estado'] as String? ?? '').toUpperCase() == 'PENDIENTE');
              final hasConfirmed = reservasDia.any((d) => (d['estado'] as String? ?? '').toUpperCase() == 'CONFIRMADA');

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = day),
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1976D2) : (isToday ? const Color(0xFFE3F2FD) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1976D2) : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(color: const Color(0xFF1976D2).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE', 'es').format(day).toUpperCase().replaceAll('.', ''),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        day.day.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Indicadores de reservas (puntos)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasPending)
                            Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: const BoxDecoration(color: Color(0xFFF57C00), shape: BoxShape.circle)),
                          if (hasConfirmed)
                            Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // ── Cabecera del Día Seleccionado ──────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: const Color(0xFFF5F7FA),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE d MMMM', 'es').format(_selectedDate).toUpperCase(),
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${reservasHoy.length} ${reservasHoy.length == 1 ? widget.moduloSingular.toLowerCase() : widget.moduloPlural.toLowerCase()}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),

        // ── Lista de Reservas Filtrada ─────────────────────────────────────
        Expanded(
          child: _ListaReservas(
            reservas: reservasHoy,
            empresaId: widget.empresaId,
            mostrarAcciones: widget.mostrarAcciones,
            mensajeVacio: 'Sin ${widget.moduloPlural.toLowerCase()} para este día 📅',
            collectionId: widget.collectionId,
            moduloSingular: widget.moduloSingular,
          ),
        ),
      ],
    );
  }
}

// ── LISTA DE RESERVAS ─────────────────────────────────────────────────────────

class _ListaReservas extends StatelessWidget {
  final List<QueryDocumentSnapshot> reservas;
  final String empresaId;
  final bool mostrarAcciones;
  final String mensajeVacio;
  final String collectionId;
  final String moduloSingular;

  const _ListaReservas({
    required this.reservas,
    required this.empresaId,
    required this.mostrarAcciones,
    required this.mensajeVacio,
    required this.collectionId,
    required this.moduloSingular,
  });

  @override
  Widget build(BuildContext context) {
    if (reservas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(mensajeVacio, style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: reservas.length,
      itemBuilder: (context, i) {
        final doc = reservas[i];
        final data = doc.data() as Map<String, dynamic>;
        return _TarjetaReserva(
          docId: doc.id,
          empresaId: empresaId,
          data: data,
          mostrarAcciones: mostrarAcciones,
          collectionId: collectionId,
          moduloSingular: moduloSingular,
        );
      },
    );
  }
}

// ── FORMULARIO RESERVA CON CLIENTES Y SERVICIOS REALES ───────────────────────

// ── TARJETA RESERVA CON ACCIONES ─────────────────────────────────────────────

class _TarjetaReserva extends StatelessWidget {
  final String docId;
  final String empresaId;
  final Map<String, dynamic> data;
  final bool mostrarAcciones;
  final String collectionId;
  final String moduloSingular;

  const _TarjetaReserva({
    required this.docId,
    required this.empresaId,
    required this.data,
    required this.mostrarAcciones,
    required this.collectionId,
    required this.moduloSingular,
  });

  String get _estado => (data['estado'] as String? ?? 'PENDIENTE').toUpperCase();

  Color get _colorEstado {
    switch (_estado) {
      case 'CONFIRMADA': return const Color(0xFF4CAF50);
      case 'CANCELADA':  return const Color(0xFFD32F2F);
      case 'COMPLETADA': return const Color(0xFF1976D2);
      default:           return const Color(0xFFF57C00);
    }
  }

  String get _fechaFormateada {
    try {
      final raw = data['fecha'];
      DateTime dt;
      if (raw is Timestamp) {
        dt = raw.toDate();
      } else if (raw is String) {
        dt = DateTime.parse(raw);
      } else {
        return 'Sin fecha';
      }
      return DateFormat('EEE dd/MM · HH:mm', 'es').format(dt);
    } catch (_) {
      return data['fecha_hora']?.toString() ?? 'Sin fecha';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente   = data['nombre_cliente'] ?? 'Sin nombre';
    final telefono  = data['telefono_cliente'] ?? '';
    final servicio  = data['servicio'] ?? 'Sin servicio';
    final telefono  = data['telefono_cliente'] ?? '';
    final servicio  = data['servicio'] ?? 'Sin servicio';
    final precio    = data['precio'];
    final notas     = data['notas'] ?? '';
    final profesional = data['nombre_profesional'] as String?;
    final cancelada  = _estado == 'CANCELADA';
    final completada = _estado == 'COMPLETADA';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _colorEstado.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _colorEstado.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person, color: _colorEstado),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cliente,
                      Text(cliente,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (telefono.isNotEmpty)
                        Text(telefono,
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                // Badge estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _colorEstado.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _estado,
                    style: TextStyle(
                        color: _colorEstado, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Detalles ──────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.spa, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(servicio, style: const TextStyle(fontSize: 13))),
                if (precio != null)
                  Text('€${(precio as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF1976D2))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_fechaFormateada,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            if (notas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.notes, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(notas,
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
            // Profesional asignado (solo citas)
            if (profesional != null && profesional.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_pin, size: 14, color: Color(0xFF5C6BC0)),
                  const SizedBox(width: 4),
                  Text(
                    profesional,
                    style: const TextStyle(
                      color: Color(0xFF5C6BC0),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            // ── Acciones ──────────────────────────────────────────────
            if (mostrarAcciones && !cancelada && !completada) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _confirmarAccion(context, 'CANCELADA'),
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text('Cancelar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                      side: const BorderSide(color: Color(0xFFD32F2F)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_estado == 'PENDIENTE')
                    ElevatedButton.icon(
                      onPressed: () => _cambiarEstado(context, 'CONFIRMADA'),
                      icon: const Icon(Icons.check, size: 15),
                      label: const Text('Confirmar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  if (_estado == 'CONFIRMADA')
                    ElevatedButton.icon(
                      onPressed: () => _cambiarEstado(context, 'COMPLETADA'),
                      icon: const Icon(Icons.done_all, size: 15),
                      label: const Text('Completada'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarAccion(BuildContext context, String nuevoEstado) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Cancelar ${moduloSingular.toLowerCase()}'),
        content: Text(
            '¿Seguro que quieres cancelar la ${moduloSingular.toLowerCase()} de ${data['nombre_cliente'] ?? 'este cliente'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white),
            child: Text('Sí, cancelar ${moduloSingular.toLowerCase()}'),
          ),
        ],
      ),
    );
    if (confirmar == true && context.mounted) {
      await _cambiarEstado(context, nuevoEstado);
    }
  }

  Future<void> _cambiarEstado(BuildContext context, String nuevoEstado) async {
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection(collectionId)
          .doc(docId)
          .update({'estado': nuevoEstado});

      // Trigger estadísticas en tiempo real
      final trigger = EstadisticasTriggerService();
      if (nuevoEstado == 'CONFIRMADA') trigger.reservaConfirmada(empresaId);
      if (nuevoEstado == 'CANCELADA')  trigger.reservaCancelada(empresaId);
      if (nuevoEstado == 'COMPLETADA') trigger.reservaCompletada(empresaId);

      if (context.mounted) {
        final modulo = moduloSingular.toLowerCase();
        final mensajes = {
          'CONFIRMADA': '✅ $modulo confirmada',
          'CANCELADA':  '❌ $modulo cancelada',
          'COMPLETADA': '🎉 $modulo completada',
        };
        final colores = {
          'CONFIRMADA': const Color(0xFF4CAF50),
          'CANCELADA':  const Color(0xFFD32F2F),
          'COMPLETADA': const Color(0xFF1976D2),
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajes[nuevoEstado] ?? 'Estado actualizado'),
            backgroundColor: colores[nuevoEstado] ?? Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── FORMULARIO RESERVA CON CLIENTES Y SERVICIOS REALES ───────────────────────

class _FormularioReserva extends StatefulWidget {
  final String empresaId;
  final String collectionId;
  final String moduloSingular;
  final DateTime? fechaInicial;
  final bool mostrarProfesional;

  const _FormularioReserva({
    required this.empresaId,
    required this.collectionId,
    required this.moduloSingular,
    this.fechaInicial,
    this.mostrarProfesional = false,
  });

  @override
  State<_FormularioReserva> createState() => _FormularioReservaState();
}

class _FormularioReservaState extends State<_FormularioReserva> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  // Clientes, servicios y empleados cargados de Firestore
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _servicios = [];
  List<Map<String, dynamic>> _empleados = [];
  bool _cargando = true;

  // Selección
  Map<String, dynamic>? _clienteSeleccionado;
  Map<String, dynamic>? _servicioSeleccionado;
  Map<String, dynamic>? _profesionalSeleccionado;

  // Nuevo cliente (si no existe)
  bool _clienteNuevo = false;
  final _nombreNuevoCtrl = TextEditingController();
  final _telefonoNuevoCtrl = TextEditingController();
  final _correoNuevoCtrl = TextEditingController();

  // Fecha, hora y notas
  late DateTime _fecha;
  TimeOfDay _hora = const TimeOfDay(hour: 10, minute: 0);
  final _notasCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _fecha = widget.fechaInicial ?? DateTime.now().add(const Duration(days: 1));
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreNuevoCtrl.dispose();
    _telefonoNuevoCtrl.dispose();
    _correoNuevoCtrl.dispose();
    _notasCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final resClientes = await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes')
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .get();

      final resServicios = await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('servicios')
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .get();

      List<Map<String, dynamic>> empleados = [];
      if (widget.mostrarProfesional) {
        final resEmpleados = await _db
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('empleados')
            .where('activo', isEqualTo: true)
            .orderBy('nombre')
            .get();
        empleados = resEmpleados.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
      }

      if (mounted) {
        setState(() {
          _clientes = resClientes.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _servicios = resServicios.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _empleados = empleados;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación mínima: si es cliente nuevo debe tener nombre
    if (_clienteNuevo && _nombreNuevoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre del cliente'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      String clienteId = '';
      String nombreCliente = '';
      String telefonoCliente = '';
      String correoCliente = '';

      if (_clienteNuevo) {
        // Crear cliente nuevo en Firestore
        nombreCliente   = _nombreNuevoCtrl.text.trim();
        telefonoCliente = _telefonoNuevoCtrl.text.trim();
        correoCliente   = _correoNuevoCtrl.text.trim();
        final docRef = await _db
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('clientes')
            .add({
          'nombre': nombreCliente,
          'telefono': telefonoCliente,
          'correo': correoCliente,
          'activo': true,
          'total_gastado': 0.0,
          'numero_reservas': 1,
          'etiquetas': [],
          'fecha_registro': DateTime.now().toIso8601String(),
        });
        clienteId = docRef.id;
      } else if (_clienteSeleccionado != null) {
        // Cliente existente seleccionado
        clienteId       = _clienteSeleccionado!['id'];
        nombreCliente   = _clienteSeleccionado!['nombre'] ?? '';
        telefonoCliente = _clienteSeleccionado!['telefono'] ?? '';
        correoCliente   = _clienteSeleccionado!['correo'] ?? '';
      } else {
        // Sin cliente (p.ej. walk-in o restaurante sin reserva vinculada)
        nombreCliente = _nombreNuevoCtrl.text.trim().isNotEmpty
            ? _nombreNuevoCtrl.text.trim()
            : 'Sin nombre';
      }

      final fechaHora = DateTime(
        _fecha.year, _fecha.month, _fecha.day,
        _hora.hour, _hora.minute,
      );


      final servicio = _servicioSeleccionado;
      final precioManual = double.tryParse(_precioCtrl.text.replaceAll(',', '.'));
      final precioServicio = servicio != null
          ? (servicio['precio'] ?? 0.0 as num).toDouble()
          : null;
      final precio = precioManual ?? precioServicio;

      // Crear la reserva
      await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection(widget.collectionId)
          .add({
        'cliente_id': clienteId,
        'nombre_cliente': nombreCliente,
        'telefono_cliente': telefonoCliente,
        'correo_cliente': correoCliente,
        if (servicio != null) 'servicio_id': servicio['id'],
        'servicio': servicio?['nombre'] ?? '',
        if (precio != null) 'precio': precio,
        if (servicio != null) 'duracion_minutos': servicio['duracion_minutos'] ?? 60,
        'fecha': Timestamp.fromDate(fechaHora),
        'fecha_hora': fechaHora.toIso8601String(),
        'estado': 'PENDIENTE',
        'notas': _notasCtrl.text.trim(),
        'origen': 'manual',
        // Profesional asignado (solo para citas)
        if (_profesionalSeleccionado != null) 'profesional_id': _profesionalSeleccionado!['id'],
        if (_profesionalSeleccionado != null) 'nombre_profesional': _profesionalSeleccionado!['nombre'] ?? '',
        'fecha_creacion': FieldValue.serverTimestamp(),
      });

      // Triggers estadísticas en tiempo real
      EstadisticasTriggerService().reservaCreada(widget.empresaId);
      if (_clienteNuevo && _nombreNuevoCtrl.text.trim().isNotEmpty) {
        EstadisticasTriggerService().clienteCreado(widget.empresaId);
      }

      // Actualizar estadísticas del cliente existente
      if (clienteId.isNotEmpty && !_clienteNuevo && _clienteSeleccionado != null) {
        await _db
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('clientes')
            .doc(clienteId)
            .update({
          'numero_reservas': FieldValue.increment(1),
          'ultima_visita': fechaHora.toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${widget.moduloSingular} creada correctamente'),
            backgroundColor: Color(0xFF4CAF50),
          ),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _cargando
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Nueva ${widget.moduloSingular}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),

                    // ── CLIENTE (opcional) ────────────────────────────
                    _label('Cliente (opcional)'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Existente'),
                            selected: !_clienteNuevo,
                            onSelected: (_) => setState(() { _clienteNuevo = false; _clienteSeleccionado = null; }),
                            selectedColor: const Color(0xFF0D47A1),
                            labelStyle: TextStyle(color: !_clienteNuevo ? Colors.white : Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Nuevo / Sin cliente'),
                            selected: _clienteNuevo,
                            onSelected: (_) => setState(() { _clienteNuevo = true; _clienteSeleccionado = null; }),
                            selectedColor: const Color(0xFF0D47A1),
                            labelStyle: TextStyle(color: _clienteNuevo ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (!_clienteNuevo) ...[
                      if (_clientes.isEmpty)
                        _aviso('Aún no hay clientes guardados. Puedes escribir el nombre directamente seleccionando "Nuevo / Sin cliente".')
                      else
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _clienteSeleccionado,
                          decoration: _deco('Seleccionar cliente (opcional)', Icons.person),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('— Sin cliente —')),
                            ..._clientes.map((c) => DropdownMenuItem(
                              value: c,
                              child: Text('${c['nombre']} ${(c['telefono'] ?? '') != '' ? '· ${c['telefono']}' : ''}', overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) => setState(() => _clienteSeleccionado = v),
                        ),
                    ] else ...[
                      TextFormField(
                        controller: _nombreNuevoCtrl,
                        decoration: _deco('Nombre (opcional)', Icons.person),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _telefonoNuevoCtrl,
                        decoration: _deco('Teléfono', Icons.phone),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _correoNuevoCtrl,
                        decoration: _deco('Correo electrónico', Icons.email),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── SERVICIO (opcional) ───────────────────────────
                    _label('Servicio (opcional)'),
                    const SizedBox(height: 8),
                    if (_servicios.isEmpty)
                      _aviso('No hay servicios configurados aún. La ${widget.moduloSingular.toLowerCase()} se creará sin servicio asignado.')
                    else
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _servicioSeleccionado,
                        decoration: _deco('Seleccionar servicio (opcional)', Icons.spa),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Sin servicio —')),
                          ..._servicios.map((s) {
                            final precio = (s['precio'] ?? 0.0 as num).toDouble();
                            final dur = s['duracion_minutos'] ?? 60;
                            return DropdownMenuItem(
                              value: s,
                              child: Text('${s['nombre']} · €${precio.toStringAsFixed(0)} · ${dur}min', overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() {
                          _servicioSeleccionado = v;
                          if (v != null) {
                            final p = (v['precio'] ?? 0.0 as num).toDouble();
                            _precioCtrl.text = p > 0 ? p.toStringAsFixed(2) : '';
                          } else {
                            _precioCtrl.clear();
                          }
                        }),
                      ),

                    // Info del servicio seleccionado
                    if (_servicioSeleccionado != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D47A1).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Color(0xFF0D47A1)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${_servicioSeleccionado!['nombre']} · €${(_servicioSeleccionado!['precio'] ?? 0.0 as num).toStringAsFixed(2)} · ${_servicioSeleccionado!['duracion_minutos'] ?? 60} min',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF0D47A1)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── PRECIO MANUAL ─────────────────────────────────
                    const SizedBox(height: 16),
                    _label('Precio (€)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _precioCtrl,
                      decoration: _deco(
                        _servicioSeleccionado != null
                            ? 'Precio (se autorellenó del servicio)'
                            : 'Precio de la reserva (opcional)',
                        Icons.euro,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    // ── PROFESIONAL (solo citas) ───────────────────────────
                    if (widget.mostrarProfesional) ...[
                      const SizedBox(height: 16),
                      _label('Profesional asignado (opcional)'),
                      const SizedBox(height: 8),
                      if (_empleados.isEmpty)
                        _aviso('No hay empleados activos. Añade empleados en el módulo de Empleados.')
                      else
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _profesionalSeleccionado,
                          decoration: _deco('Seleccionar profesional (opcional)', Icons.person_pin),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('— Sin asignar —')),
                            ..._empleados.map((e) => DropdownMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.15),
                                    child: Text(
                                      (e['nombre'] as String? ?? '?').substring(0, 1).toUpperCase(),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF1976D2), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(e['nombre'] ?? '', overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            )),
                          ],
                          onChanged: (v) => setState(() => _profesionalSeleccionado = v),
                        ),
                    ],

                    const SizedBox(height: 16),

                    // ── FECHA Y HORA ──────────────────────────────────────
                    _label('Fecha y hora'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _fecha,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _fecha = picked);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(_hora.format(context)),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _hora);
                              if (picked != null) setState(() => _hora = picked);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── NOTAS ─────────────────────────────────────────────
                    TextFormField(
                      controller: _notasCtrl,
                      decoration: _deco('Notas internas (opcional)', Icons.notes),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // ── BOTÓN GUARDAR ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _guardando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(
                          _guardando ? 'Guardando...' : 'Crear ${widget.moduloSingular}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _label(String texto) => Text(
    texto,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1)),
  );

  Widget _aviso(String texto) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blue[200]!),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
      ],
    ),
  );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}







