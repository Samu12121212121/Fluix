// tpv_peluqueria_screen.dart — TPV Peluquería / Estética
// UI: 3 columnas según TPV_SPECS_UI_DETALLADAS.md
//   Izquierda (230px): Profesionales con navegador de fecha
//   Centro (flexible): Tabs Agenda (timeline) / Walk-in / Cabinas
//   Derecha (290px): Cliente + catálogo servicios + ticket
// Color: Morado #6A1B9A

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../services/pedidos_service.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import '../../../services/tpv/cierre_caja_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// CONSTANTES
// ═════════════════════════════════════════════════════════════════════════════

const double kPelColIzquierda = 230.0;
const double kPelColDerecha = 290.0;
const Color kPelColorPrimario = Color(0xFF6A1B9A);
const Color kPelColorFondo = Color(0xFFFAF7FD);
const double kPelSlotHeight = 60.0;
const int kPelSlotDuration = 30;

const List<Color> kProfColors = [
  Color(0xFF7B1FA2), // morado
  Color(0xFF2E7D32), // verde
  Color(0xFFBF360C), // coral
  Color(0xFF1565C0), // azul
  Color(0xFF00695C), // teal
  Color(0xFFE65100), // naranja
  Color(0xFF880E4F), // rosa
  Color(0xFF37474F), // gris
];

Color profColor(int idx) => kProfColors[idx % kProfColors.length];

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

List<String> generarSlots({String desde = '09:00', String hasta = '20:00', int pasoMin = 30}) {
  final slots = <String>[];
  int h = int.parse(desde.split(':')[0]), m = int.parse(desde.split(':')[1]);
  final hF = int.parse(hasta.split(':')[0]), mF = int.parse(hasta.split(':')[1]);
  while (h < hF || (h == hF && m < mF)) {
    slots.add('${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}');
    m += pasoMin;
    if (m >= 60) { h++; m -= 60; }
  }
  return slots;
}

int slotIndex(String hora, List<String> slots) => slots.indexOf(hora);

// ═════════════════════════════════════════════════════════════════════════════
// MODELOS LIGEROS
// ═════════════════════════════════════════════════════════════════════════════

class Profesional {
  final String id, nombre;
  final int colorIdx;
  final bool activo;
  const Profesional({required this.id, required this.nombre, required this.colorIdx, this.activo = true});
  
  Color get color => profColor(colorIdx);
  String get initials {
    final parts = nombre.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return nombre.substring(0, nombre.length.clamp(0, 2)).toUpperCase();
  }
  
  factory Profesional.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Profesional(
      id: d.id,
      nombre: m['nombre'] as String? ?? 'Prof',
      colorIdx: (m['color_index'] as num?)?.toInt() ?? 0,
      activo: m['activo'] as bool? ?? true,
    );
  }
}

class Cita {
  final String id, fecha, horaInicio, clienteNombre, profId, estado;
  final int duracionMinutos;
  final List<Map<String, dynamic>> servicios;
  
  const Cita({
    required this.id, required this.fecha, required this.horaInicio,
    required this.clienteNombre, required this.profId, required this.estado,
    required this.duracionMinutos, required this.servicios,
  });
  
  double get importe => servicios.fold(0.0, (s, e) => s + ((e['precio'] as num?)?.toDouble() ?? 0));
  
  factory Cita.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Cita(
      id: d.id,
      fecha: m['fecha'] as String? ?? '',
      horaInicio: m['hora_inicio'] as String? ?? '',
      clienteNombre: m['cliente_nombre'] as String? ?? 'Cliente',
      profId: m['prof_id'] as String? ?? '',
      estado: m['estado'] as String? ?? 'pendiente',
      duracionMinutos: (m['duracion_minutos'] as num?)?.toInt() ?? 30,
      servicios: (m['servicios'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
    );
  }
}

class TurnoWalkIn {
  final String id, clienteNombre, servicio;
  final int numero;
  final DateTime horaLlegada;
  
  const TurnoWalkIn({
    required this.id, required this.clienteNombre, required this.servicio,
    required this.numero, required this.horaLlegada,
  });
  
  factory TurnoWalkIn.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return TurnoWalkIn(
      id: d.id,
      numero: (m['numero'] as num?)?.toInt() ?? 0,
      clienteNombre: m['cliente_nombre'] as String? ?? 'Cliente sin cita',
      servicio: m['servicio'] as String? ?? '',
      horaLlegada: (m['hora_llegada'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ═════════════════════════════════════════════════════════════════════════════

class TpvPeluqueriaScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  const TpvPeluqueriaScreen({super.key, required this.empresaId, this.esAdmin = false});
  
  @override
  State<TpvPeluqueriaScreen> createState() => _TpvPeluqueriaState();
}

class _TpvPeluqueriaState extends State<TpvPeluqueriaScreen> {
  DateTime _fecha = DateTime.now();
  String? _profIdSeleccionado;
  int _profColorIdx = 0;
  
  final List<Map<String, dynamic>> _lineasTicket = [];
  Map<String, dynamic>? _clienteSeleccionado;
  double _descuentoBono = 0;
  
  Timer? _relojTimer;
  String _hora = '';
  bool _estaOnline = true;
  bool _btConectado = false;
  bool _mostrandoCierre = false;
  StreamSubscription<List<ConnectivityResult>>? _connectSub;
  
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _hora = DateFormat('HH:mm').format(DateTime.now());
    _relojTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() => _hora = DateFormat('HH:mm').format(DateTime.now()));
    });
    _connectSub = Connectivity().onConnectivityChanged.listen((r) {
      if (mounted) setState(() => _estaOnline = !r.contains(ConnectivityResult.none));
    });
    ImpressoraBluetooth().estaConectada().then((v) {
      if (mounted) setState(() => _btConectado = v);
    });
  }
  
  @override
  void dispose() {
    _relojTimer?.cancel();
    _connectSub?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }
  
  String get _fechaStr => DateFormat('yyyy-MM-dd').format(_fecha);
  
  @override
  Widget build(BuildContext context) {
    if (_mostrandoCierre) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: CierreWrapper(
          empresaId: widget.empresaId,
          onVolver: () => setState(() => _mostrandoCierre = false),
        ),
      );
    }
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: _buildAppBar(),
        body: Row(children: [
          ColProfesionales(
            empresaId: widget.empresaId,
            fecha: _fecha,
            fechaStr: _fechaStr,
            profIdSeleccionado: _profIdSeleccionado,
            onFechaChanged: (d) => setState(() => _fecha = d),
            onProfSeleccionado: (id, colorIdx) => setState(() {
              _profIdSeleccionado = id;
              _profColorIdx = colorIdx;
            }),
            onNuevaCita: () => _mostrarDialogoNuevaCita(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(children: [
              Container(
                color: kPelColorPrimario,
                child: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(text: 'Agenda'),
                    Tab(text: 'Walk-in / Cola'),
                    Tab(text: 'Cabinas'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(children: [
                  AgendaTab(
                    empresaId: widget.empresaId,
                    profId: _profIdSeleccionado,
                    fechaStr: _fechaStr,
                    profColor: profColor(_profColorIdx),
                    onNuevaCita: () => _mostrarDialogoNuevaCita(),
                  ),
                  WalkInTab(
                    empresaId: widget.empresaId,
                    fechaStr: _fechaStr,
                    onAsignar: (turno) => _mostrarAsignarTurno(turno),
                  ),
                  CabinasTab(empresaId: widget.empresaId),
                ]),
              ),
            ]),
          ),
          const VerticalDivider(width: 1),
          ColTicket(
            empresaId: widget.empresaId,
            lineas: _lineasTicket,
            cliente: _clienteSeleccionado,
            descuentoBono: _descuentoBono,
            onClienteSeleccionado: (c, d) => setState(() {
              _clienteSeleccionado = c;
              _descuentoBono = d;
            }),
            onServicioAdded: (s) => setState(() => _lineasTicket.add(s)),
            onServicioRemoved: (i) => setState(() => _lineasTicket.removeAt(i)),
            onCobrar: () => _cobrar(),
            onLimpiar: () => setState(() {
              _lineasTicket.clear();
              _clienteSeleccionado = null;
              _descuentoBono = 0;
            }),
          ),
        ]),
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kPelColorPrimario,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 48,
      automaticallyImplyLeading: false,
      title: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => Navigator.pop(context)),
        const Icon(Icons.content_cut, size: 18),
        const SizedBox(width: 6),
        const Text('TPV Peluquería', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const Spacer(),
        Text(_hora, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Icon(_estaOnline ? Icons.wifi : Icons.wifi_off, size: 15, color: _estaOnline ? Colors.white70 : Colors.orangeAccent),
        const SizedBox(width: 6),
        Icon(Icons.print, size: 15, color: _btConectado ? Colors.white70 : Colors.white38),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.summarize_outlined, size: 18, color: _mostrandoCierre ? Colors.amber : Colors.white70),
          onPressed: () => setState(() => _mostrandoCierre = !_mostrandoCierre),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ]),
    );
  }
  
  void _mostrarDialogoNuevaCita() {
    showDialog(context: context, builder: (_) => DialogoNuevaCita(
      empresaId: widget.empresaId, fecha: _fechaStr, profIdInicial: _profIdSeleccionado,
    ));
  }
  
  void _mostrarAsignarTurno(TurnoWalkIn turno) {
    showDialog(context: context, builder: (_) => DialogoAsignarTurno(
      empresaId: widget.empresaId, turno: turno, fecha: _fechaStr,
    ));
  }
  
  Future<void> _cobrar() async {
    if (_lineasTicket.isEmpty) return;
    final total = (_lineasTicket.fold(0.0, (s, l) => s + ((l['precio'] as num?)?.toDouble() ?? 0)
) - _descuentoBono).clamp(0.0, double.infinity);
    if (total <= 0) return;

    final pago = await showDialog<Map<String, dynamic>>(
      context: context, barrierDismissible: false,
      builder: (_) => DialogoPago(total: total),
    );
    if (pago == null) return;

    final ahora = DateTime.now();
    final ref = FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/contadores').doc('tickets');
    int numTicket = 1;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      numTicket = snap.exists ? ((snap.data()?['ultimo'] as num?)?.toInt() ?? 0) + 1 : 1;
      tx.set(ref, {'ultimo': numTicket}, SetOptions(merge: true));
    });

    final empresaSnap = await FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).get();
    final lineasPedido = _lineasTicket.map((l) => LineaPedido(
      productoId: '', productoNombre: l['nombre'] as String? ?? '',
      cantidad: 1, precioUnitario: (l['precio'] as num?)?.toDouble() ?? 0,
      ivaPorcentaje: 21, notasLinea: null,
    )).toList();

    try {
      final pedido = await PedidosService().crearPedido(
        empresaId: widget.empresaId,
        clienteNombre: _clienteSeleccionado?['nombre'] as String? ?? 'Caja directa',
        lineas: lineasPedido,
        metodoPago: pago['metodo'] == 'efectivo' ? MetodoPago.efectivo : MetodoPago.tarjeta,
        origen: OrigenPedido.presencial, numeroTicket: numTicket,
        importeEfectivo: pago['importe_efectivo'], importeTarjeta: pago['importe_tarjeta'],
        importeTotal: total, mesaId: null, estado: 'entregado', estadoPago: 'pagado',
        fechaHora: Timestamp.fromDate(ahora),
      );
      
      try {
        final cfg = await TpvFacturacionService().obtenerConfig(widget.empresaId);
        if (cfg.facturacionAutomatica) {
          await TpvFacturacionService().generarFacturaPorPedido(
            empresaId: widget.empresaId, pedido: pedido, config: cfg,
            usuarioNombre: FirebaseAuth.instance.currentUser?.displayName ?? 'TPV Peluquería',
          );
        }
      } catch (_) {}
      
      try {
        await ImpressoraBluetooth().imprimirTicket(TicketData(
          nombreEmpresa: empresaSnap.data()?['nombre'] as String? ?? '',
          numeroTicket: numTicket, fecha: ahora,
          lineas: _lineasTicket.map((l) => LineaTicket(
            nombre: l['nombre'] as String? ?? '', cantidad: 1,
            precioUnitario: (l['precio'] as num?)?.toDouble() ?? 0,
          )).toList(),
          total: total, metodoPago: pago['metodo'] as String? ?? 'efectivo',
        ));
      } catch (_) {}
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ticket #$numTicket cobrado — ${total.toStringAsFixed(2)} €'),
          backgroundColor: Colors.green.shade700,
        ));
        setState(() { _lineasTicket.clear(); _clienteSeleccionado = null; _descuentoBono = 0; });
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COLUMNA IZQUIERDA — PROFESIONALES
// ═════════════════════════════════════════════════════════════════════════════

class ColProfesionales extends StatelessWidget {
  final String empresaId, fechaStr;
  final DateTime fecha;
  final String? profIdSeleccionado;
  final ValueChanged<DateTime> onFechaChanged;
  final void Function(String id, int colorIdx) onProfSeleccionado;
  final VoidCallback onNuevaCita;
  
  const ColProfesionales({
    super.key, required this.empresaId, required this.fecha, required this.fechaStr,
    required this.profIdSeleccionado, required this.onFechaChanged,
    required this.onProfSeleccionado, required this.onNuevaCita,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: kPelColIzquierda,
      color: kPelColorFondo,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: const BoxDecoration(
            color: kPelColorPrimario,
            border: Border(bottom: BorderSide(color: Color(0xFF4A0E6E))),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
              onPressed: () => onFechaChanged(fecha.subtract(const Duration(days: 1))),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Expanded(child: Text(
              DateFormat('EEE d MMM', 'es').format(fecha),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.center,
            )),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
              onPressed: () => onFechaChanged(fecha.add(const Duration(days: 1))),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('empresas/$empresaId/profesionales')
                .where('activo', isEqualTo: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_add_outlined, size: 40, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('Sin profesionales', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => showDialog(context: context, builder: (_) => DialogoNuevoProf(empresaId: empresaId)),
                    child: const Text('Añadir profesional'),
                  ),
                ]));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final prof = Profesional.fromDoc(docs[i]);
                  return ProfRow(
                    prof: prof,
                    seleccionado: profIdSeleccionado == prof.id,
                    empresaId: empresaId,
                    fechaStr: fechaStr,
                    onTap: () => onProfSeleccionado(prof.id, prof.colorIdx),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNuevaCita,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva cita'),
              style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ),
      ]),
    );
  }
}

class ProfRow extends StatelessWidget {
  final Profesional prof;
  final bool seleccionado;
  final String empresaId, fechaStr;
  final VoidCallback onTap;
  
  const ProfRow({super.key, required this.prof, required this.seleccionado, required this.empresaId, required this.fechaStr, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('empresas/$empresaId/citas')
          .where('prof_id', isEqualTo: prof.id).where('fecha', isEqualTo: fechaStr).snapshots(),
      builder: (context, snap) {
        final citas = snap.data?.docs ?? [];
        final ahora = DateFormat('HH:mm').format(DateTime.now());
        final enCurso = citas.any((d) {
          final m = d.data() as Map<String, dynamic>;
          return m['hora_inicio'] != null && m['hora_inicio'].toString().compareTo(ahora) <= 0 && m['estado'] == 'en_curso';
        });
        final minOcupados = citas.fold<int>(0, (s, d) => s + (((d.data() as Map)['duracion_minutos'] as num?)?.toInt() ?? 0));
        final hLibres = ((8 * 60 - minOcupados) / 60).clamp(0.0, 8.0);
        
        return InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: seleccionado ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: seleccionado ? Border(left: BorderSide(color: prof.color, width: 4)) : null,
              boxShadow: seleccionado ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: prof.color.withValues(alpha: 0.2),
                child: Text(prof.initials, style: TextStyle(color: prof.color, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(prof.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${citas.length} cita${citas.length != 1 ? 's' : ''} · ${hLibres.toStringAsFixed(1)}h libres',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ])),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: enCurso ? const Color(0xFFFFA726) : const Color(0xFF4CAF50)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PESTAÑA AGENDA — TIMELINE
// ═════════════════════════════════════════════════════════════════════════════

class AgendaTab extends StatelessWidget {
  final String empresaId, fechaStr;
  final String? profId;
  final Color profColor;
  final VoidCallback onNuevaCita;
  
  const AgendaTab({super.key, required this.empresaId, required this.fechaStr, this.profId, required this.profColor, required this.onNuevaCita});
  
  @override
  Widget build(BuildContext context) {
    if (profId == null) {
      return const Center(child: Text('Selecciona un profesional', style: TextStyle(color: Colors.grey)));
    }
    final slots = generarSlots(pasoMin: kPelSlotDuration);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('empresas/$empresaId/citas')
          .where('prof_id', isEqualTo: profId).where('fecha', isEqualTo: fechaStr).snapshots(),
      builder: (context, snap) {
        final citas = snap.hasData ? snap.data!.docs.map(Cita.fromDoc).toList() : <Cita>[];
        final Map<int, Cita> citaEnSlot = {};
        final Set<int> slotsOcupados = {};
        for (final cita in citas) {
          final idx = slotIndex(cita.horaInicio, slots);
          if (idx < 0) continue;
          citaEnSlot[idx] = cita;
          final numSlots = (cita.duracionMinutos / kPelSlotDuration).ceil();
          for (int k = 1; k < numSlots; k++) {
            if (idx + k < slots.length) slotsOcupados.add(idx + k);
          }
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: slots.length,
          itemBuilder: (context, i) {
            if (slotsOcupados.contains(i)) return const SizedBox.shrink();
            final cita = citaEnSlot[i];
            final numSlots = cita != null ? (cita.duracionMinutos / kPelSlotDuration).ceil() : 1;
            final height = numSlots * kPelSlotHeight;
            return SizedBox(
              height: height,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 48, child: Padding(
                  padding: const EdgeInsets.only(top: 6, right: 6),
                  child: Text(slots[i], style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.right),
                )),
                Container(width: 1, height: height, color: Colors.grey.shade200),
                const SizedBox(width: 8),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8, bottom: 4),
                  child: cita != null ? CitaCard(cita: cita, profColor: profColor, height: height - 8) : SlotVacio(height: height - 8, onTap: onNuevaCita),
                )),
              ]),
            );
          },
        );
      },
    );
  }
}

class CitaCard extends StatelessWidget {
  final Cita cita;
  final Color profColor;
  final double height;
  const CitaCard({super.key, required this.cita, required this.profColor, required this.height});
  
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: profColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: profColor, width: 4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(cita.clienteNombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (cita.servicios.isNotEmpty) ...[
          const SizedBox(height: 2),
          Wrap(spacing: 4, children: cita.servicios.take(2).map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: profColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
            child: Text(s['nombre'] as String? ?? '', style: TextStyle(fontSize: 10, color: profColor, fontWeight: FontWeight.w600)),
          )).toList()),
        ],
        const SizedBox(height: 2),
        Text('${cita.duracionMinutos} min · ${fmt.format(cita.importe)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}

class SlotVacio extends StatelessWidget {
  final double height;
  final VoidCallback onTap;
  const SlotVacio({super.key, required this.height, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
        child: const Center(child: Text('+ Nueva cita', style: TextStyle(fontSize: 12, color: Colors.grey))),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PESTAÑA WALK-IN
// ═════════════════════════════════════════════════════════════════════════════

class WalkInTab extends StatelessWidget {
  final String empresaId, fechaStr;
  final void Function(TurnoWalkIn) onAsignar;
  const WalkInTab({super.key, required this.empresaId, required this.fechaStr, required this.onAsignar});
  
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          FilledButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => DialogoAddTurno(empresaId: empresaId, fechaStr: fechaStr)),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+ Añadir turno'),
            style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('empresas/$empresaId/turnos_espera')
              .where('fecha', isEqualTo: fechaStr).where('estado', isEqualTo: 'esperando').orderBy('numero').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final turnos = snap.data!.docs.map(TurnoWalkIn.fromDoc).toList();
            if (turnos.isEmpty) return const Center(child: Text('Sin clientes en espera', style: TextStyle(color: Colors.grey)));
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: turnos.length,
              itemBuilder: (context, i) {
                final t = turnos[i];
                final esperaMin = i * 30;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(color: Color(0xFFF3E5F5), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('${t.numero}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kPelColorPrimario)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.clienteNombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(t.servicio.isNotEmpty ? t.servicio : 'Sin servicio especificado',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        Text('Espera estimada: ~$esperaMin min', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ])),
                      FilledButton(
                        onPressed: () => onAsignar(t),
                        style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), textStyle: const TextStyle(fontSize: 12)),
                        child: const Text('Asignar'),
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PESTAÑA CABINAS
// ═════════════════════════════════════════════════════════════════════════════

class CabinasTab extends StatelessWidget {
  final String empresaId;
  const CabinasTab({super.key, required this.empresaId});
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('empresas/$empresaId/sillones').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Sin cabinas configuradas', style: TextStyle(color: Colors.grey)));
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, childAspectRatio: 0.9, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final libre = (d['estado'] as String? ?? 'libre') == 'libre';
            return Container(
              decoration: BoxDecoration(
                color: libre ? Colors.white : const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: libre ? Colors.grey.shade200 : const Color(0xFF9C27B0), width: libre ? 1 : 2),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.chair_alt, size: 32, color: libre ? Colors.grey.shade400 : const Color(0xFF9C27B0)),
                const SizedBox(height: 6),
                Text(d['nombre'] as String? ?? 'Cabina', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: libre ? Colors.green.shade100 : Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(libre ? 'Libre' : 'Ocupada',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: libre ? Colors.green.shade800 : Colors.purple.shade800)),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// COLUMNA DERECHA — TICKET
// ═════════════════════════════════════════════════════════════════════════════

class ColTicket extends StatefulWidget {
  final String empresaId;
  final List<Map<String, dynamic>> lineas;
  final Map<String, dynamic>? cliente;
  final double descuentoBono;
  final void Function(Map<String, dynamic> cliente, double descuento) onClienteSeleccionado;
  final void Function(Map<String, dynamic> servicio) onServicioAdded;
  final void Function(int index) onServicioRemoved;
  final VoidCallback onCobrar;
  final VoidCallback onLimpiar;
  
  const ColTicket({
    super.key, required this.empresaId, required this.lineas, this.cliente,
    required this.descuentoBono, required this.onClienteSeleccionado,
    required this.onServicioAdded, required this.onServicioRemoved,
    required this.onCobrar, required this.onLimpiar,
  });
  
  @override
  State<ColTicket> createState() => _ColTicketState();
}

class _ColTicketState extends State<ColTicket> {
  final _busquedaCtrl = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  String _categoria = 'Todos';
  List<String> _categorias = ['Todos'];
  
  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }
  
  @override
  void dispose() { _busquedaCtrl.dispose(); super.dispose(); }
  
  Future<void> _cargarCategorias() async {
    final snap = await FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/catalogo').where('activo', isEqualTo: true).get();
    final cats = snap.docs.map((d) => (d.data())['categoria'] as String? ?? '').toSet().toList();
    cats.sort();
    if (mounted) setState(() => _categorias = ['Todos', ...cats]);
  }
  
  Future<void> _buscarClientes(String q) async {
    if (q.length < 2) { setState(() => _resultados = []); return; }
    final snap = await FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/clientes')
        .where('nombre_lower', isGreaterThanOrEqualTo: q.toLowerCase())
        .where('nombre_lower', isLessThanOrEqualTo: '${q.toLowerCase()}\uf8ff')
        .limit(8).get();
    if (mounted) setState(() => _resultados = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
  
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final subtotal = widget.lineas.fold(0.0, (s, l) => s + ((l['precio'] as num?)?.toDouble() ?? 0));
    final total = (subtotal - widget.descuentoBono).clamp(0.0, double.infinity);
    
    return Container(
      width: kPelColDerecha,
      color: kPelColorFondo,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _busquedaCtrl,
              onChanged: _buscarClientes,
              decoration: InputDecoration(
                hintText: 'Buscar cliente…',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: widget.cliente != null
                    ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () {
                        _busquedaCtrl.clear();
                        setState(() => _resultados = []);
                        widget.onClienteSeleccionado({}, 0);
                      })
                    : null,
              ),
            ),
            if (_resultados.isNotEmpty && widget.cliente == null) ...[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(shrinkWrap: true, children: _resultados.map((r) => ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 14, backgroundColor: const Color(0xFFF3E5F5),
                      child: Text((r['nombre'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: kPelColorPrimario, fontWeight: FontWeight.bold, fontSize: 12))),
                  title: Text(r['nombre'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                  onTap: () async {
                    setState(() => _resultados = []);
                    _busquedaCtrl.text = r['nombre'] as String? ?? '';
                    double descuento = 0;
                    final ficha = r['ficha_cliente'] as Map? ?? {};
                    final bonoSesiones = (ficha['bono_sesiones_restantes'] as num?)?.toInt() ?? 0;
                    if (bonoSesiones > 0) descuento = (ficha['bono_precio_sesion'] as num?)?.toDouble() ?? 0;
                    widget.onClienteSeleccionado(Map<String, dynamic>.from(r), descuento);
                  },
                )).toList()),
              ),
            ],
            if (widget.cliente != null && widget.cliente!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClienteCard(cliente: widget.cliente!),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _categorias.map((c) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(c, style: const TextStyle(fontSize: 11)),
                selected: _categoria == c,
                onSelected: (_) => setState(() => _categoria = c),
                selectedColor: kPelColorPrimario,
                labelStyle: TextStyle(color: _categoria == c ? Colors.white : null),
              ),
            )).toList()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/catalogo').where('activo', isEqualTo: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final servicios = snap.data!.docs
                  .where((d) => _categoria == 'Todos' || (d.data() as Map)['categoria'] == _categoria)
                  .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
                  .toList();
              
              return Column(children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    itemCount: servicios.length,
                    itemBuilder: (context, i) {
                      final s = servicios[i];
                      final fmt2 = NumberFormat.currency(symbol: '€', decimalDigits: 2);
                      final enTicket = widget.lineas.any((l) => l['id'] == s['id']);
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        title: Text(s['nombre'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                        subtitle: Text(fmt2.format((s['precio'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: IconButton(
                          icon: Icon(enTicket ? Icons.remove_circle_outline : Icons.add_circle_outline,
                              color: enTicket ? Colors.red.shade400 : kPelColorPrimario, size: 22),
                          onPressed: () {
                            if (enTicket) {
                              final idx = widget.lineas.indexWhere((l) => l['id'] == s['id']);
                              if (idx >= 0) widget.onServicioRemoved(idx);
                            } else {
                              widget.onServicioAdded({'id': s['id'], 'nombre': s['nombre'], 'precio': s['precio']});
                            }
                          },
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      );
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
        if (widget.lineas.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ticket', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              ...widget.lineas.asMap().entries.map((e) {
                final l = e.value;
                final fmt2 = NumberFormat.currency(symbol: '€', decimalDigits: 2);
                return Row(children: [
                  Expanded(child: Text(l['nombre'] as String? ?? '', style: const TextStyle(fontSize: 12))),
                  Text(fmt2.format((l['precio'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  GestureDetector(onTap: () => widget.onServicioRemoved(e.key), child: const Icon(Icons.close, size: 14, color: Colors.red)),
                ]);
              }),
            ]),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Subtotal', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(fmt.format(subtotal), style: const TextStyle(fontSize: 12)),
            ]),
            if (widget.descuentoBono > 0) ...[
              const SizedBox(height: 2),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Descuento bono', style: TextStyle(fontSize: 12, color: Colors.green)),
                Text('−${fmt.format(widget.descuentoBono)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
              ]),
            ],
            const Divider(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(fmt.format(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kPelColorPrimario)),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.lineas.isEmpty ? null : widget.onCobrar,
                style: FilledButton.styleFrom(
                  backgroundColor: kPelColorPrimario,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Cobrar ${fmt.format(total)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class ClienteCard extends StatelessWidget {
  final Map<String, dynamic> cliente;
  const ClienteCard({super.key, required this.cliente});
  
  @override
  Widget build(BuildContext context) {
    final ficha = cliente['ficha_cliente'] as Map? ?? {};
    final visitas = (cliente['num_visitas'] as num?)?.toInt() ?? 0;
    final bonoRestantes = (ficha['bono_sesiones_restantes'] as num?)?.toInt() ?? 0;
    final colorHab = ficha['color_habitual'] as String?;
    final producto = ficha['producto'] as String?;
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCE93D8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 16, backgroundColor: kPelColorPrimario,
            child: Text((cliente['nombre'] as String? ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cliente['nombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('$visitas visita${visitas != 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ])),
        ]),
        if (colorHab != null || bonoRestantes > 0 || producto != null) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (colorHab != null) EtiquetaFicha(label: '🎨 $colorHab'),
            if (bonoRestantes > 0) EtiquetaFicha(label: '🎟 $bonoRestantes sesiones', color: Colors.green.shade100),
            if (producto != null) EtiquetaFicha(label: '💧 $producto'),
          ]),
        ],
      ]),
    );
  }
}

class EtiquetaFicha extends StatelessWidget {
  final String label;
  final Color? color;
  const EtiquetaFicha({super.key, required this.label, this.color});
  
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color ?? const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGOS
// ═════════════════════════════════════════════════════════════════════════════

class DialogoPago extends StatefulWidget {
  final double total;
  const DialogoPago({super.key, required this.total});
  @override State<DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<DialogoPago> {
  String _metodo = 'efectivo';
  final _ctrl = TextEditingController();
  double _cambio = 0;
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Método de pago'),
      content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            const Text('Total', style: TextStyle(fontSize: 12, color: kPelColorPrimario)),
            Text('${widget.total.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kPelColorPrimario)),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: GestureDetector(onTap: () => setState(() => _metodo = 'efectivo'), child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _metodo == 'efectivo' ? const Color(0xFFF3E5F5) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _metodo == 'efectivo' ? kPelColorPrimario : Colors.transparent, width: 1.5),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.payments_outlined, size: 20, color: _metodo == 'efectivo' ? kPelColorPrimario : Colors.grey),
              const SizedBox(height: 4),
              Text('Efectivo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _metodo == 'efectivo' ? kPelColorPrimario : Colors.grey)),
            ]),
          ))),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(onTap: () => setState(() => _metodo = 'tarjeta'), child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _metodo == 'tarjeta' ? const Color(0xFFF3E5F5) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _metodo == 'tarjeta' ? kPelColorPrimario : Colors.transparent, width: 1.5),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.credit_card, size: 20, color: _metodo == 'tarjeta' ? kPelColorPrimario : Colors.grey),
              const SizedBox(height: 4),
              Text('Tarjeta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _metodo == 'tarjeta' ? kPelColorPrimario : Colors.grey)),
            ]),
          ))),
        ]),
        if (_metodo == 'efectivo') ...[
          const SizedBox(height: 12),
          TextField(controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Entrega del cliente (€)'),
              onChanged: (v) {
                final e = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() => _cambio = (e - widget.total).clamp(0, double.infinity));
              }),
          if (_cambio > 0) ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Cambio', style: TextStyle(color: Colors.green.shade800)),
                  Text('${_cambio.toStringAsFixed(2)} €', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade800, fontSize: 16)),
                ])),
          ],
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario),
          onPressed: () => Navigator.pop(context, {
            'metodo': _metodo,
            'importe_efectivo': _metodo == 'efectivo' ? widget.total : 0.0,
            'importe_tarjeta': _metodo == 'tarjeta' ? widget.total : 0.0,
          }),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class DialogoNuevaCita extends StatefulWidget {
  final String empresaId, fecha;
  final String? profIdInicial;
  const DialogoNuevaCita({super.key, required this.empresaId, required this.fecha, this.profIdInicial});
  @override State<DialogoNuevaCita> createState() => _DialogoNuevaCitaState();
}

class _DialogoNuevaCitaState extends State<DialogoNuevaCita> {
  final _clienteCtrl = TextEditingController();
  String? _profId;
  String _horaInicio = '09:00';
  int _duracionMinutos = 30;
  @override void initState() { super.initState(); _profId = widget.profIdInicial; }
  @override void dispose() { _clienteCtrl.dispose(); super.dispose(); }
  
  @override
  Widget build(BuildContext context) {
    final slots = generarSlots();
    return AlertDialog(
      title: const Text('Nueva cita'),
      content: SizedBox(width: 340, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _clienteCtrl, decoration: const InputDecoration(labelText: 'Nombre del cliente', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/profesionales').where('activo', isEqualTo: true).snapshots(),
          builder: (context, snap) {
            final profs = snap.data?.docs ?? [];
            return DropdownButtonFormField<String>(
              initialValue: _profId,
              decoration: const InputDecoration(labelText: 'Profesional', isDense: true, border: OutlineInputBorder()),
              items: profs.map((d) => DropdownMenuItem(value: d.id, child: Text((d.data() as Map)['nombre'] as String? ?? ''))).toList(),
              onChanged: (v) => setState(() => _profId = v),
            );
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _horaInicio,
          decoration: const InputDecoration(labelText: 'Hora inicio', isDense: true, border: OutlineInputBorder()),
          items: slots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _horaInicio = v ?? '09:00'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _duracionMinutos,
          items: [30, 45, 60, 90, 120].map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
          onChanged: (v) => setState(() => _duracionMinutos = v ?? 30),
          decoration: const InputDecoration(labelText: 'Duración', prefixIcon: Icon(Icons.timelapse)),
        ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario),
          onPressed: () async {
            if (_clienteCtrl.text.trim().isEmpty) return;
            await FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/citas').add({
              'fecha': widget.fecha, 'hora_inicio': _horaInicio, 'duracion_minutos': _duracionMinutos,
              'prof_id': _profId ?? '', 'cliente_nombre': _clienteCtrl.text.trim(),
              'servicios': [], 'estado': 'pendiente', 'creado_en': FieldValue.serverTimestamp(),
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Guardar cita'),
        ),
      ],
    );
  }
}

class DialogoAddTurno extends StatefulWidget {
  final String empresaId, fechaStr;
  const DialogoAddTurno({super.key, required this.empresaId, required this.fechaStr});
  @override State<DialogoAddTurno> createState() => _DialogoAddTurnoState();
}

class _DialogoAddTurnoState extends State<DialogoAddTurno> {
  final _nombreCtrl = TextEditingController();
  final _servicioCtrl = TextEditingController();
  @override void dispose() { _nombreCtrl.dispose(); _servicioCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Añadir turno'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre del cliente (opcional)')),
      const SizedBox(height: 10),
      TextField(controller: _servicioCtrl, decoration: const InputDecoration(labelText: 'Servicio solicitado')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario),
        onPressed: () async {
          final nombre = _nombreCtrl.text.trim().isEmpty ? 'Cliente sin cita' : _nombreCtrl.text.trim();
          final snap = await FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/turnos_espera').where('fecha', isEqualTo: widget.fechaStr).get();
          final siguiente = (snap.docs.fold(0, (s, d) => ((d.data()['numero'] as num?)?.toInt() ?? 0) > s ? (d.data()['numero'] as num).toInt() : s)) + 1;
          await FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/turnos_espera').add({
            'fecha': widget.fechaStr, 'numero': siguiente, 'cliente_nombre': nombre,
            'servicio': _servicioCtrl.text.trim(), 'hora_llegada': Timestamp.now(), 'estado': 'esperando',
          });
          if (context.mounted) Navigator.pop(context);
        },
        child: const Text('Añadir'),
      ),
    ],
  );
}

class DialogoAsignarTurno extends StatefulWidget {
  final String empresaId, fecha;
  final TurnoWalkIn turno;
  const DialogoAsignarTurno({super.key, required this.empresaId, required this.turno, required this.fecha});
  @override State<DialogoAsignarTurno> createState() => _DialogoAsignarTurnoState();
}

class _DialogoAsignarTurnoState extends State<DialogoAsignarTurno> {
  String? _profId;
  String _horaInicio = '09:00';
  
  @override
  Widget build(BuildContext context) {
    final slots = generarSlots();
    return AlertDialog(
      title: Text('Asignar turno #${widget.turno.numero}'),
      content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.turno.clienteNombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (widget.turno.servicio.isNotEmpty) Text(widget.turno.servicio, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/profesionales').where('activo', isEqualTo: true).snapshots(),
          builder: (context, snap) => DropdownButtonFormField<String>(
            initialValue: _profId,
            hint: const Text('Profesional'),
            items: (snap.data?.docs ?? []).map((d) => DropdownMenuItem(value: d.id, child: Text((d.data() as Map)['nombre'] as String? ?? ''))).toList(),
            onChanged: (v) => setState(() => _profId = v),
            decoration: const InputDecoration(labelText: 'Asignar a'),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _horaInicio,
          items: slots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _horaInicio = v ?? '09:00'),
          decoration: const InputDecoration(labelText: 'Hora'),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario),
          onPressed: () async {
            if (_profId == null) return;
            final batch = FirebaseFirestore.instance.batch();
            final nuevaCitaRef = FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/citas').doc();
            batch.set(nuevaCitaRef, {
              'fecha': widget.fecha, 'hora_inicio': _horaInicio, 'duracion_minutos': 30,
              'prof_id': _profId, 'cliente_nombre': widget.turno.clienteNombre,
              'servicios': widget.turno.servicio.isNotEmpty ? [{'nombre': widget.turno.servicio, 'precio': 0}] : [],
              'estado': 'pendiente', 'creado_en': FieldValue.serverTimestamp(),
            });
            batch.update(FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/turnos_espera').doc(widget.turno.id), {'estado': 'asignado'});
            await batch.commit();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Asignar'),
        ),
      ],
    );
  }
}

class DialogoNuevoProf extends StatefulWidget {
  final String empresaId;
  const DialogoNuevoProf({super.key, required this.empresaId});
  @override State<DialogoNuevoProf> createState() => _DialogoNuevoProfState();
}

class _DialogoNuevoProfState extends State<DialogoNuevoProf> {
  final _ctrl = TextEditingController();
  int _colorIdx = 0;
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuevo profesional'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _ctrl, decoration: const InputDecoration(labelText: 'Nombre')),
      const SizedBox(height: 12),
      const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: List.generate(kProfColors.length, (i) => GestureDetector(
        onTap: () => setState(() => _colorIdx = i),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: kProfColors[i], shape: BoxShape.circle,
            border: _colorIdx == i ? Border.all(color: Colors.black, width: 2) : null,
          ),
        ),
      ))),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario),
        onPressed: () async {
          if (_ctrl.text.trim().isEmpty) return;
          await FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/profesionales')
              .add({'nombre': _ctrl.text.trim(), 'color_index': _colorIdx, 'activo': true});
          if (context.mounted) Navigator.pop(context);
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// CIERRE DE CAJA
// ═════════════════════════════════════════════════════════════════════════════

class CierreWrapper extends StatefulWidget {
  final String empresaId;
  final VoidCallback onVolver;
  const CierreWrapper({super.key, required this.empresaId, required this.onVolver});
  @override State<CierreWrapper> createState() => _CierreWrapperState();
}

class _CierreWrapperState extends State<CierreWrapper> {
  Map<String, dynamic>? _datos;
  bool _cargando = true;
  bool _cerrando = false;
  
  @override
  void initState() { super.initState(); _cargarDatos(); }
  
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));
    final snap = await FirebaseFirestore.instance.collection('empresas/${widget.empresaId}/pedidos')
        .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_hora', isLessThan: Timestamp.fromDate(fin))
        .where('estado_pago', isEqualTo: 'pagado').get();
    double ef = 0, tj = 0;
    final top = <String, int>{};
    for (final d in snap.docs) {
      final m = d.data();
      final met = m['metodo_pago'] as String? ?? 'efectivo';
      if (met == 'efectivo') ef += (m['importe_efectivo'] as num?)?.toDouble() ?? (m['importe_total'] as num?)?.toDouble() ?? 0;
      else tj += (m['importe_tarjeta'] as num?)?.toDouble() ?? (m['importe_total'] as num?)?.toDouble() ?? 0;
      for (final l in m['lineas'] as List? ?? []) {
        final nombre = l['producto_nombre'] as String? ?? ''; top[nombre] = (top[nombre] ?? 0) + ((l['cantidad'] as num?)?.toInt() ?? 1);
      }
    }
    final total = ef + tj;
    if (mounted) setState(() {
      _datos = {'total': total, 'efectivo': ef, 'tarjeta': tj, 'num_tickets': snap.docs.length,
        'base': total / 1.21, 'iva': total - total / 1.21,
        'top': (top.entries.toList()..sort((a,b)=>b.value.compareTo(a.value))).take(3).toList()};
      _cargando = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final d = _datos!;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final hoy = DateTime.now();
    final fecha = '${hoy.day.toString().padLeft(2,'0')}/${hoy.month.toString().padLeft(2,'0')}/${hoy.year}';
    
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        TextButton.icon(onPressed: widget.onVolver, icon: const Icon(Icons.arrow_back), label: const Text('Volver')),
        const Spacer(),
        Text('Cierre — $fecha', style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: _generarPdf, icon: const Icon(Icons.download, size: 14), label: const Text('Z-PDF', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), visualDensity: VisualDensity.compact)),
        const SizedBox(width: 6),
        FilledButton(onPressed: _cerrando ? null : _confirmarCierre,
          style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), visualDensity: VisualDensity.compact),
          child: _cerrando ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Cerrar caja', style: TextStyle(fontSize: 12)),
        ),
      ])),
      const Divider(height: 1),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Wrap(spacing: 12, runSpacing: 12, children: [
        _cifra('Total', fmt.format(d['total']), color: kPelColorPrimario),
        _cifra('Tickets', '${d['num_tickets']}'),
        _tarjeta('Pago', [_fila('Efectivo', fmt.format(d['efectivo'])), const SizedBox(height: 4), _fila('Tarjeta', fmt.format(d['tarjeta']))]),
        _tarjeta('IVA 21%', [_fila('Base', fmt.format(d['base'])), const SizedBox(height: 4), _fila('Cuota', fmt.format(d['iva']))]),
        _tarjeta('Top servicios', (d['top'] as List).asMap().entries.map((e) {
          final entry = e.value as MapEntry<String, int>;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
            Text('${e.key+1}.', style: const TextStyle(color: kPelColorPrimario, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
            Text('×${entry.value}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]));
        }).toList()),
      ]))),
    ]);
  }
  
  Future<void> _confirmarCierre() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Confirmar cierre'), content: const Text('¿Registrar el cierre del día?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar'))],
    ));
    if (ok != true) return;
    setState(() => _cerrando = true);
    try {
      final svc = CierreCajaService();
      await svc.guardarCierreCaja(widget.empresaId, await svc.calcularCierreCaja(widget.empresaId, DateTime.now()));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cierre registrado'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _cerrando = false); }
  }
  
  Future<void> _generarPdf() async {
    final d = _datos!; final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32), build: (c) => pw.Column(children: [
      pw.Text('Z-REPORT — PELUQUERÍA', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16), pw.Divider(),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total'), pw.Text(fmt.format(d['total']))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tickets'), pw.Text('${d['num_tickets']}')]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Efectivo'), pw.Text(fmt.format(d['efectivo']))]),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tarjeta'), pw.Text(fmt.format(d['tarjeta']))]),
    ])));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }
  
  Widget _cifra(String l, String v, {Color? color}) => SizedBox(width: 160, child: Container(
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [Text(l, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 4),
      Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color))]),
  ));
  
  Widget _tarjeta(String titulo, List<Widget> children) => SizedBox(width: 200, child: Container(
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)), const SizedBox(height: 10), ...children]),
  ));
  
  Widget _fila(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
  ]);
}












