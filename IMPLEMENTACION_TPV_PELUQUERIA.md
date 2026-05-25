# 🚧 Guía de Implementación — TPV Peluquería UI Detallada

> Instrucciones paso a paso para reemplazar `tpv_peluqueria_screen.dart` con la UI especificada en `TPV_SPECS_UI_DETALLADAS.md`

---

## 📋 Resumen de cambios

**Estado actual:** NavigationRail con Sillones/Caja/Cierre (vertical)  
**Estado objetivo:** 3 columnas fijas horizontales (230px | flex | 290px)

---

## 1️⃣ Estructura general del archivo

```dart
// Imports (mantener los actuales + añadir si falta)
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
import '../../../domain/modelos/comanda.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../services/pedidos_service.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import '../../../services/tpv/cierre_caja_service.dart';

// ── CONSTANTES ───────────────────────────────────────────────────────────────
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

// ── HELPERS ──────────────────────────────────────────────────────────────────
List<String

> generarSlots({String desde = '09:00', String hasta = '20:00', int pasoMin = 30}) {
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

int slotIndex(String hora, List<String> slots) {
  final idx = slots.indexOf(hora);
  return idx >= 0 ? idx : -1;
}

// ── MODELOS LIGEROS (sin fichero propio) ────────────────────────────────────
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
```

---

## 2️⃣ Widget principal

```dart
class TpvPeluqueriaScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  const TpvPeluqueriaScreen({super.key, required this.empresaId, this.esAdmin = false});
  
  @override
  State<TpvPeluqueriaScreen> createState() => _TpvPeluqueriaState();
}

class _TpvPeluqueriaState extends State<TpvPeluqueriaScreen> {
  // Estado
  DateTime _fecha = DateTime.now();
  String? _profIdSeleccionado;
  int _profColorIdx = 0;
  
  // Ticket
  final List<Map<String, dynamic>> _lineasTicket = []; // {id, nombre, precio}
  Map<String, dynamic>? _clienteSeleccionado;
  double _descuentoBono = 0;
  
  // UI/UX
  Timer? _relojTimer;
  String _hora = '';
  bool _estaOnline = true;
  bool _btConectado = false;
  bool _mostrandoCierre = false;
  StreamSubscription<List<ConnectivityResult>>? _connectSub;
  
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
          // Columna izquierda: Profesionales (230px fija)
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
          
          // Columna central: Tabs (flexible)
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
          
          // Columna derecha: Ticket (290px fija)
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
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
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
    showDialog(
      context: context,
      builder: (_) => DialogoNuevaCita(
        empresaId: widget.empresaId,
        fecha: _fechaStr,
        profIdInicial: _profIdSeleccionado,
      ),
    );
  }
  
  void _mostrarAsignarTurno(TurnoWalkIn turno) {
    showDialog(
      context: context,
      builder: (_) => DialogoAsignarTurno(
        empresaId: widget.empresaId,
        turno: turno,
        fecha: _fechaStr,
      ),
    );
  }
  
  Future<void> _cobrar() async {
    // Implementación del cobro (mantener la actual adaptando a nuevos campos)
    // Ver sección 6️⃣ más abajo
  }
}
```

---

## 3️⃣ Columna Izquierda — Profesionales

```dart
class ColProfesionales extends StatelessWidget {
  final String empresaId, fechaStr;
  final DateTime fecha;
  final String? profIdSeleccionado;
  final ValueChanged<DateTime> onFechaChanged;
  final void Function(String id, int colorIdx) onProfSeleccionado;
  final VoidCallback onNuevaCita;
  
  const ColProfesionales({
    super.key,
    required this.empresaId,
    required this.fecha,
    required this.fechaStr,
    required this.profIdSeleccionado,
    required this.onFechaChanged,
    required this.onProfSeleccionado,
    required this.onNuevaCita,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: kPelColIzquierda,
      color: kPelColorFondo,
      child: Column(children: [
        // Navegador de fecha
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
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Expanded(
              child: Text(
                DateFormat('EEE d MMM', 'es').format(fecha),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
              onPressed: () => onFechaChanged(fecha.add(const Duration(days: 1))),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ]),
        ),
        
        // Lista de profesionales
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas/$empresaId/profesionales')
                .where('activo', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_add_outlined, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('Sin profesionales', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _mostrarDialogoNuevoProf(context),
                      child: const Text('Añadir profesional'),
                    ),
                  ]),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final prof = Profesional.fromDoc(docs[i]);
                  final seleccionado = profIdSeleccionado == prof.id;
                  
                  return ProfRow(
                    prof: prof,
                    seleccionado: seleccionado,
                    empresaId: empresaId,
                    fechaStr: fechaStr,
                    onTap: () => onProfSeleccionado(prof.id, prof.colorIdx),
                  );
                },
              );
            },
          ),
        ),
        
        // Botón Nueva cita
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNuevaCita,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva cita'),
              style: FilledButton.styleFrom(
                backgroundColor: kPelColorPrimario,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ]),
    );
  }
  
  void _mostrarDialogoNuevoProf(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => DialogoNuevoProf(empresaId: empresaId),
    );
  }
}

// ── Fila de profesional ──────────────────────────────────────────────────────
class ProfRow extends StatelessWidget {
  final Profesional prof;
  final bool seleccionado;
  final String empresaId, fechaStr;
  final VoidCallback onTap;
  
  const ProfRow({
    super.key,
    required this.prof,
    required this.seleccionado,
    required this.empresaId,
    required this.fechaStr,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas/$empresaId/citas')
          .where('prof_id', isEqualTo: prof.id)
          .where('fecha', isEqualTo: fechaStr)
          .snapshots(),
      builder: (context, snap) {
        final citas = snap.data?.docs ?? [];
        final ahora = DateFormat('HH:mm').format(DateTime.now());
        
        // Determinar si está ocupado justo ahora
        final enCurso = citas.any((d) {
          final m = d.data() as Map<String, dynamic>;
          final inicio = m['hora_inicio'] as String? ?? '';
          return inicio.isNotEmpty && inicio.compareTo(ahora) <= 0 && m['estado'] == 'en_curso';
        });
        
        // Calcular horas libres (8h - suma duración citas)
        final minOcupados = citas.fold(0, (s, d) =>
            s + ((d.data() as Map)['duracion_minutos'] as num?)?.toInt() ?? 0);
        final hLibres = ((8 * 60 - minOcupados) / 60).clamp(0.0, 8.0);
        
        return InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: seleccionado ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: seleccionado
                  ? Border(left: BorderSide(color: prof.color, width: 4))
                  : null,
              boxShadow: seleccionado
                  ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                  : null,
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: prof.color.withValues(alpha: 0.2),
                child: Text(
                  prof.initials,
                  style: TextStyle(
                    color: prof.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prof.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${citas.length} cita${citas.length != 1 ? 's' : ''} · ${hLibres.toStringAsFixed(1)}h libres',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enCurso ? const Color(0xFFFFA726) : const Color(0xFF4CAF50),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
```

---

## 4️⃣ Columna Central — Tabs

### Pestaña Agenda (Timeline)

```dart
class AgendaTab extends StatelessWidget {
  final String empresaId, fechaStr;
  final String? profId;
  final Color profColor;
  final VoidCallback onNuevaCita;
  
  const AgendaTab({
    super.key,
    required this.empresaId,
    required this.fechaStr,
    this.profId,
    required this.profColor,
    required this.onNuevaCita,
  });
  
  static const double _slotH = kPelSlotHeight;
  
  @override
  Widget build(BuildContext context) {
    if (profId == null) {
      return const Center(
        child: Text('Selecciona un profesional', style: TextStyle(color: Colors.grey)),
      );
    }
    
    final slots = generarSlots(pasoMin: kPelSlotDuration);
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas/$empresaId/citas')
          .where('prof_id', isEqualTo: profId)
          .where('fecha', isEqualTo: fechaStr)
          .snapshots(),
      builder: (context, snap) {
        final citas = snap.hasData ? snap.data!.docs.map(Cita.fromDoc).toList() : <Cita>[];
        
        // Mapear slots
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
            final height = numSlots * _slotH;
            
            return SizedBox(
              height: height,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Hora
                SizedBox(
                  width: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: Text(
                      slots[i],
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                // Línea vertical
                Container(width: 1, height: height, color: Colors.grey.shade200),
                const SizedBox(width: 8),
                // Contenido
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8, bottom: 4),
                    child: cita != null
                        ? CitaCard(cita: cita, profColor: profColor, height: height - 8)
                        : SlotVacio(height: height - 8, onTap: onNuevaCita),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Tarjeta de cita ocupada ──────────────────────────────────────────────────
class CitaCard extends StatelessWidget {
  final Cita cita;
  final Color profColor;
  final double height;
  
  const CitaCard({
    super.key,
    required this.cita,
    required this.profColor,
    required this.height,
  });
  
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cita.clienteNombre,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (cita.servicios.isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              children: cita.servicios.take(2).map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: profColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s['nombre'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: profColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            '${cita.duracionMinutos} min · ${fmt.format(cita.importe)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── Slot vacío (borde punteado) ──────────────────────────────────────────────
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: const Center(
          child: Text('+ Nueva cita', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ),
    );
  }
}
```

### Pestaña Walk-in

```dart
class WalkInTab extends StatelessWidget {
  final String empresaId, fechaStr;
  final void Function(TurnoWalkIn) onAsignar;
  
  const WalkInTab({
    super.key,
    required this.empresaId,
    required this.fechaStr,
    required this.onAsignar,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          FilledButton.icon(
            onPressed: () => _mostrarAddTurno(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+ Añadir turno'),
            style: FilledButton.styleFrom(backgroundColor: kPelColorPrimario),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas/$empresaId/turnos_espera')
              .where('fecha', isEqualTo: fechaStr)
              .where('estado', isEqualTo: 'esperando')
              .orderBy('numero')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            
            final turnos = snap.data!.docs.map(TurnoWalkIn.fromDoc).toList();
            
            if (turnos.isEmpty) {
              return const Center(
                child: Text('Sin clientes en espera', style: TextStyle(color: Colors.grey)),
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: turnos.length,
              itemBuilder: (context, i) {
                final t = turnos[i];
                final esperaMin = i * 30; // Estimación simple
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      // Número
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3E5F5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${t.numero}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: kPelColorPrimario,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.clienteNombre,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              t.servicio.isNotEmpty ? t.servicio : 'Sin servicio especificado',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Text(
                              'Espera estimada: ~$esperaMin min',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      // Botón Asignar
                      FilledButton(
                        onPressed: () => onAsignar(t),
                        style: FilledButton.styleFrom(
                          backgroundColor: kPelColorPrimario,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
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
  
  void _mostrarAddTurno(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => DialogoAddTurno(empresaId: empresaId, fechaStr: fechaStr),
    );
  }
}
```

### Pestaña Cabinas

```dart
class CabinasTab extends StatelessWidget {
  final String empresaId;
  
  const CabinasTab({super.key, required this.empresaId});
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas/$empresaId/sillones')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('Sin cabinas configuradas', style: TextStyle(color: Colors.grey)),
          );
        }
        
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            childAspectRatio: 0.9,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final libre = (d['estado'] as String? ?? 'libre') == 'libre';
            
            return Container(
              decoration: BoxDecoration(
                color: libre ? Colors.white : const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: libre ? Colors.grey.shade200 : const Color(0xFF9C27B0),
                  width: libre ? 1 : 2,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chair_alt,
                    size: 32,
                    color: libre ? Colors.grey.shade400 : const Color(0xFF9C27B0),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d['nombre'] as String? ?? 'Cabina',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: libre ? Colors.green.shade100 : Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      libre ? 'Libre' : 'Ocupada',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: libre ? Colors.green.shade800 : Colors.purple.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
```

---

## 5️⃣ Columna Derecha — Cliente + Ticket

```dart
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
    super.key,
    required this.empresaId,
    required this.lineas,
    this.cliente,
    required this.descuentoBono,
    required this.onClienteSeleccionado,
    required this.onServicioAdded,
    required this.onServicioRemoved,
    required this.onCobrar,
    required this.onLimpiar,
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
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }
  
  Future<void> _cargarCategorias() async {
    final snap = await FirebaseFirestore.instance
        .collection('empresas/${widget.empresaId}/catalogo')
        .where('activo', isEqualTo: true)
        .get();
    
    final cats = snap.docs
        .map((d) => (d.data())['categoria'] as String? ?? '')
        .toSet()
        .toList();
    cats.sort();
    
    if (mounted) {
      setState(() => _categorias = ['Todos', ...cats]);
    }
  }
  
  Future<void> _buscarClientes(String q) async {
    if (q.length < 2) {
      setState(() => _resultados = []);
      return;
    }
    
    final snap = await FirebaseFirestore.instance
        .collection('empresas/${widget.empresaId}/clientes')
        .where('nombre_lower', isGreaterThanOrEqualTo: q.toLowerCase())
        .where('nombre_lower', isLessThanOrEqualTo: '${q.toLowerCase()}\uf8ff')
        .limit(8)
        .get();
    
    if (mounted) {
      setState(() {
        _resultados = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    }
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
        // ── Buscador de cliente ──
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _busquedaCtrl.clear();
                            setState(() => _resultados = []);
                            widget.onClienteSeleccionado({}, 0);
                          },
                        )
                      : null,
                ),
              ),
              
              // Resultados de búsqueda
              if (_resultados.isNotEmpty && widget.cliente == null) ...[
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView(
                    shrinkWrap: true,
                    children: _resultados.map((r) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFF3E5F5),
                        child: Text(
                          (r['nombre'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                            color: kPelColorPrimario,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        r['nombre'] as String? ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () async {
                        setState(() => _resultados = []);
                        _busquedaCtrl.text = r['nombre'] as String? ?? '';
                        
                        double descuento = 0;
                        final ficha = r['ficha_cliente'] as Map? ?? {};
                        final bonoSesiones = (ficha['bono_sesiones_restantes'] as num?)?.toInt() ?? 0;
                        if (bonoSesiones > 0) {
                          descuento = (ficha['bono_precio_sesion'] as num?)?.toDouble() ?? 0;
                        }
                        
                        widget.onClienteSeleccionado(Map<String, dynamic>.from(r), descuento);
                      },
                    )).toList(),
                  ),
                ),
              ],
              
              // Card cliente seleccionado
              if (widget.cliente != null && widget.cliente!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClienteCard(cliente: widget.cliente!),
              ],
            ],
          ),
        ),
        
        // ── Chips de categoría ──
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categorias.map((c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 11)),
                  selected: _categoria == c,
                  onSelected: (_) => setState(() => _categoria = c),
                  selectedColor: kPelColorPrimario,
                  labelStyle: TextStyle(
                    color: _categoria == c ? Colors.white : null,
                  ),
                ),
              )).toList(),
            ),
          ),
        ),
        
        // ── Lista de servicios + ticket ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas/${widget.empresaId}/catalogo')
                .where('activo', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              
              final servicios = snap.data!.docs
                  .where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return _categoria == 'Todos' || data['categoria'] == _categoria;
                  })
                  .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
                  .toList();
              
              return Column(children: [
                // Servicios disponibles
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
                        title: Text(
                          s['nombre'] as String? ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          fmt2.format((s['precio'] as num?)?.toDouble() ?? 0),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            enTicket ? Icons.remove_circle_outline : Icons.add_circle_outline,
                            color: enTicket ? Colors.red.shade400 : kPelColorPrimario,
                            size: 22,
                          ),
                          onPressed: () {
                            if (enTicket) {
                              final idx = widget.lineas.indexWhere((l) => l['id'] == s['id']);
                              if (idx >= 0) widget.onServicioRemoved(idx);
                            } else {
                              widget.onServicioAdded({
                                'id': s['id'],
                                'nombre': s['nombre'],
                                'precio': s['precio'],
                              });
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      );
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
        
        // ── Ticket añadido ──
        if (widget.lineas.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ticket',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                ...widget.lineas.asMap().entries.map((e) {
                  final l = e.value;
                  final fmt2 = NumberFormat.currency(symbol: '€', decimalDigits: 2);
                  return Row(children: [
                    Expanded(
                      child: Text(
                        l['nombre'] as String? ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      fmt2.format((l['precio'] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => widget.onServicioRemoved(e.key),
                      child: const Icon(Icons.close, size: 14, color: Colors.red),
                    ),
                  ]);
                }),
              ],
            ),
          ),
        
        // ── Footer totales + cobrar ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(fmt.format(subtotal), style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (widget.descuentoBono > 0) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Descuento bono',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                  Text(
                    '−${fmt.format(widget.descuentoBono)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ],
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  fmt.format(total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kPelColorPrimario,
                  ),
                ),
              ],
            ),
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
                child: Text(
                  'Cobrar ${fmt.format(total)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Card de cliente seleccionado ─────────────────────────────────────────────
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
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCE93D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: kPelColorPrimario,
              child: Text(
                (cliente['nombre'] as String? ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente['nombre'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    '$visitas visita${visitas != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ]),
          if (colorHab != null || bonoRestantes > 0 || producto != null) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (colorHab != null) EtiquetaFicha(label: '🎨 $colorHab'),
              if (bonoRestantes > 0)
                EtiquetaFicha(
                  label: '🎟 $bonoRestantes sesiones',
                  color: Colors.green.shade100,
                ),
              if (producto != null) EtiquetaFicha(label: '💧 $producto'),
            ]),
          ],
        ],
      ),
    );
  }
}

class EtiquetaFicha extends StatelessWidget {
  final String label;
  final Color? color;
  
  const EtiquetaFicha({super.key, required this.label, this.color});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
```

---

## 6️⃣ Método de cobro

```dart
Future<void> _cobrar() async {
  if (_lineasTicket.isEmpty) return;
  
  final total = _lineasTicket.fold(
    0.0,
    (s, l) => s + ((l['precio'] as num?)?.toDouble() ?? 0),
  ) - _descuentoBono;
  
  if (total <= 0) return;
  
  // Mostrar diálogo de pago (mantener el actual, ya funciona)
  final pago = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DialogoPago(total: total.clamp(0, double.infinity)),
  );
  
  if (pago == null) return;
  
  // Generar número de ticket atómico
  final ahora = DateTime.now();
  final ref = FirebaseFirestore.instance
      .collection('empresas/${widget.empresaId}/contadores')
      .doc('tickets');
  
  int numTicket = 1;
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(ref);
    numTicket = snap.exists
        ? ((snap.data()?['ultimo'] as num?)?.toInt() ?? 0) + 1
        : 1;
    tx.set(ref, {'ultimo': numTicket}, SetOptions(merge: true));
  });
  
  final empresaSnap = await FirebaseFirestore.instance
      .collection('empresas/${widget.empresaId}')
      .get();
  
  final lineasPedido = _lineasTicket.map((l) => LineaPedido(
    productoId: '',
    productoNombre: l['nombre'] as String? ?? '',
    cantidad: 1,
    precioUnitario: (l['precio'] as num?)?.toDouble() ?? 0,
    ivaPorcentaje: 21,
    notasLinea: null,
  )).toList();
  
  try {
    final pedido = await PedidosService().crearPedido(
      empresaId: widget.empresaId,
      clienteNombre: _clienteSeleccionado?['nombre'] as String? ?? 'Caja directa',
      lineas: lineasPedido,
      metodoPago: pago['metodo'] == 'efectivo'
          ? MetodoPago.efectivo
          : MetodoPago.tarjeta,
      origen: OrigenPedido.presencial,
      numeroTicket: numTicket,
      importeEfectivo: pago['importe_efectivo'],
      importeTarjeta: pago['importe_tarjeta'],
      importeTotal: total.clamp(0, double.infinity),
      mesaId: null,
      estado: 'entregado',
      estadoPago: 'pagado',
      fechaHora: Timestamp.fromDate(ahora),
    );
    
    // Facturación automática
    try {
      final cfg = await TpvFacturacionService().obtenerConfig(widget.empresaId);
      if (cfg.facturacionAutomatica) {
        await TpvFacturacionService().generarFacturaPorPedido(
          empresaId: widget.empresaId,
          pedido: pedido,
          config: cfg,
          usuarioNombre: FirebaseAuth.instance.currentUser?.displayName ?? 'TPV Peluquería',
        );
      }
    } catch (_) {}
    
    // Imprimir ticket
    try {
      await ImpressoraBluetooth().imprimirTicket(TicketData(
        nombreEmpresa: empresaSnap.data()?['nombre'] as String? ?? '',
        numeroTicket: numTicket,
        fecha: ahora,
        lineas: _lineasTicket.map((l) => LineaTicket(
          nombre: l['nombre'] as String? ?? '',
          cantidad: 1,
          precioUnitario: (l['precio'] as num?)?.toDouble() ?? 0,
        )).toList(),
        total: total.clamp(0, double.infinity),
        metodoPago: pago['metodo'] as String? ?? 'efectivo',
      ));
    } catch (_) {}
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Ticket #$numTicket cobrado — ${total.toStringAsFixed(2)} €',
        ),
        backgroundColor: Colors.green.shade700,
      ));
      
      setState(() {
        _lineasTicket.clear();
        _clienteSeleccionado = null;
        _descuentoBono = 0;
      });
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cobrar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

---

## 7️⃣ Diálogos auxiliares

Los diálogos `DialogoNuevaCita`, `DialogoAddTurno`, `DialogoAsignarTurno`, `DialogoNuevoProf` y `DialogoPago` se mantienen igual que en la versión actual del archivo, solo adaptando los colores a `kPelColorPrimario`.

---

## 8️⃣ Widget de Cierre de Caja

El widget `CierreWrapper` se mantiene igual, solo adaptando colores.

---

## ✅ Checklist de implementación

- [ ] Reemplazar constantes al inicio del archivo
- [ ] Reemplazar `TpvPeluqueriaScreen` y `_TpvPeluqueriaState`
- [ ] Implementar `ColProfesionales` con navegador de fecha
- [ ] Implementar `ProfRow` con avatar coloreado y stats
- [ ] Implementar `AgendaTab` con timeline vertical
- [ ] Implementar `CitaCard` y `SlotVacio`
- [ ] Implementar `WalkInTab` con círculos numerados
- [ ] Implementar `CabinasTab` con grid
- [ ] Implementar `ColTicket` con 3 bloques (búsqueda/catálogo/footer)
- [ ] Implementar `ClienteCard` con etiquetas de ficha
- [ ] Adaptar método `_cobrar()` a nuevos campos
- [ ] Adaptar diálogos auxiliares con colores morados
- [ ] Adaptar `CierreWrapper` con colores morados

---

**Tiempo estimado:** 2-3 horas de implementación cuidadosa  
**Archivos afectados:** Solo `tpv_peluqueria_screen.dart`  
**Colecciones Firestore requeridas:**
- `empresas/{id}/profesionales` con campo `color_index`
- `empresas/{id}/citas` con campos de fecha/hora/profesional
- `empresas/{id}/turnos_espera` para walk-in
- `empresas/{id}/sillones` para tab de cabinas (ya existe)
- `empresas/{id}/clientes` con campo `ficha_cliente` para bonos/etiquetas

---

*Guía de implementación v1.0 · PlaneaG · Mayo 2026*

