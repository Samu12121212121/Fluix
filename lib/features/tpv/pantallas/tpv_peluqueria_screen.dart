// TPV Peluquería - Vista Agenda Profesional con Timeline
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/tpv_type_switcher.dart';
import 'tpv_tienda_screen.dart';
import 'configuracion_facturacion_tpv_screen.dart';
import '../../../services/pedidos_service.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../../../services/cierre_caja_service.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

// ═══════════════════════════════════════════════════════════════════════════
// COLORES
// ═══════════════════════════════════════════════════════════════════════════

const Color kCian = Color(0xFF00FFC8);
const Color kMagenta = Color(0xFFFF3296);
const Color kRosa = Color(0xFFFF4678);
const Color kFondoOscuro = Color(0xFF0A0F23);
const Color kSuperficie = Color(0xFF151932);
const Color kTarjeta = Color(0xFF1E2139);
const Color kDivisor = Color(0xFF2A2E45);

const Color kPelPrimario = Color(0xFF9C27B0);
const Color kPelPrimarioLight = Color(0xFFE1BEE7);

const List<Color> kProfColors = [
  Color(0xFF00FFC8),
  Color(0xFFFF3296),
  Color(0xFFFF4678),
  Color(0xFF00D9FF),
  Color(0xFFFFB84D),
  Color(0xFF4CAF50),
  Color(0xFF9C27B0),
  Color(0xFF2196F3),
];

Color profColor(int idx) => kProfColors[idx % kProfColors.length];

// ═══════════════════════════════════════════════════════════════════════════
// FUNCIÓN AUXILIAR: GENERAR SLOTS
// ═══════════════════════════════════════════════════════════════════════════

List<String> generarSlots(
    {int horaInicio = 8, int horaFin = 21, int pasoMin = 30}) {
  final slots = <String>[];
  for (var h = horaInicio; h < horaFin; h++) {
    for (var m = 0; m < 60; m += pasoMin) {
      slots.add(
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
    }
  }
  return slots;
}

// ═══════════════════════════════════════════════════════════════════════════
// MODELO: PROFESIONAL
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
  final List<String> serviciosIds;

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
    this.serviciosIds = const [],
  });

  Color get color => profColor(colorIdx);

  String get initials {
    final parts = nombre.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nombre.substring(0, nombre.length.clamp(0, 2)).toUpperCase();
  }

  factory Profesional.fromEmpleado(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawServicios = data['servicios_ids'];
    final List<String> servicios = rawServicios is List
        ? rawServicios.map((e) => e.toString()).toList()
        : [];
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
      serviciosIds: servicios,
    );
  }

  factory Profesional.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawServicios = data['servicios_ids'];
    final List<String> servicios = rawServicios is List
        ? rawServicios.map((e) => e.toString()).toList()
        : [];
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
      serviciosIds: servicios,
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
  final String horaInicio; // "HH:mm" — siempre String
  final int duracionMinutos;
  final String? nota;
  final String estado;
  final List<Map<String, dynamic>> servicios;
  final double importe;
  final String? reservaId;

  const Cita({
    required this.id,
    required this.profesionalId,
    required this.clienteNombre,
    this.clienteTelefono,
    required this.servicioNombre,
    required this.horaInicio,
    required this.duracionMinutos,
    this.nota,
    this.estado = 'pendiente',
    this.servicios = const [],
    this.importe = 0.0,
    this.reservaId,
  });

  // ── GETTERS de conveniencia (CORREGIDO: derivados de String, no al revés) ──
  DateTime get horaInicioDateTime {
    final parts = horaInicio.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year, now.month, now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  DateTime get horaFinDateTime =>
      horaInicioDateTime.add(Duration(minutes: duracionMinutos));

  String get horaFinStr {
    final fin = horaFinDateTime;
    return '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}';
  }

  factory Cita.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final List<Map<String, dynamic>> serviciosList = [];
    if (data['servicios'] != null) {
      for (var s in data['servicios'] as List) {
        serviciosList.add(Map<String, dynamic>.from(s as Map));
      }
    }

    double importeTotal = serviciosList.fold(
      0.0,
          (sum, s) => sum + ((s['precio'] as num?)?.toDouble() ?? 0),
    );

    // hora_inicio: puede ser Timestamp, String "HH:mm", o derivado de fecha_hora
    String horaStr = '09:00';
    if (data['hora_inicio'] is Timestamp) {
      final dt = (data['hora_inicio'] as Timestamp).toDate();
      horaStr =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (data['hora_inicio'] is String &&
        (data['hora_inicio'] as String).isNotEmpty) {
      horaStr = data['hora_inicio'] as String;
    } else if (data['fecha_hora'] != null) {
      // Documento unificado — derivar hora de fecha_hora
      DateTime? dt;
      if (data['fecha_hora'] is Timestamp) {
        dt = (data['fecha_hora'] as Timestamp).toDate();
      } else if (data['fecha_hora'] is String) {
        dt = DateTime.tryParse(data['fecha_hora'] as String);
      }
      if (dt != null) {
        horaStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    // servicio_nombre: nuevo campo unificado o fallback de la lista
    final String servicioNombre = data['servicio_nombre'] as String? ??
        (serviciosList.isNotEmpty
            ? (serviciosList.first['nombre'] as String? ?? 'Servicio')
            : (data['servicio'] as String? ?? 'Servicio'));

    return Cita(
      id: doc.id,
      profesionalId:
      data['prof_id'] ?? data['profesional_id'] ?? '',
      clienteNombre: data['cliente_nombre'] ?? data['nombre_cliente'] ?? 'Cliente',
      clienteTelefono: data['cliente_telefono'] ?? data['telefono_cliente'],
      servicioNombre: servicioNombre,
      horaInicio: horaStr,
      duracionMinutos: (data['duracion_minutos'] as int?) ??
          (data['duracion'] as int?) ??
          30,
      nota: (data['notas'] as String?)?.isNotEmpty == true
          ? data['notas'] as String
          : data['nota'] as String?, // CORREGIDO: acepta ambas claves
      estado: data['estado'] ?? 'pendiente',
      servicios: serviciosList,
      importe: importeTotal,
      reservaId: data['reserva_id'], // puede ser null en doc unificado
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WALK-IN
// ═══════════════════════════════════════════════════════════════════════════

class TurnoWalkIn {
  final String id, clienteNombre, servicio;
  final int numero;
  final DateTime horaLlegada;
  final List<Map<String, dynamic>> serviciosSeleccionados;

  const TurnoWalkIn({
    required this.id,
    required this.clienteNombre,
    required this.servicio,
    required this.numero,
    required this.horaLlegada,
    this.serviciosSeleccionados = const [],
  });

  factory TurnoWalkIn.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return TurnoWalkIn(
      id: d.id,
      numero: (m['numero'] as num?)?.toInt() ?? 0,
      clienteNombre: m['cliente_nombre'] as String? ?? 'Cliente sin cita',
      servicio: m['servicio'] as String? ?? '',
      horaLlegada:
      (m['hora_llegada'] as Timestamp?)?.toDate() ?? DateTime.now(),
      serviciosSeleccionados: (m['servicios_seleccionados'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
          [],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TICKET EXTRA
// ═══════════════════════════════════════════════════════════════════════════

class _TicketExtra {
  final double propina;
  final double descuentoBono;
  final String? nombreCliente;
  final String? clienteId;

  const _TicketExtra({
    this.propina = 0,
    this.descuentoBono = 0,
    this.nombreCliente,
    this.clienteId,
  });

  _TicketExtra copyWith({
    double? propina,
    double? descuentoBono,
    String? nombreCliente,
    String? clienteId,
    bool limpiarCliente = false,
  }) =>
      _TicketExtra(
        propina: propina ?? this.propina,
        descuentoBono: descuentoBono ?? this.descuentoBono,
        nombreCliente:
        limpiarCliente ? null : (nombreCliente ?? this.nombreCliente),
        clienteId: limpiarCliente ? null : (clienteId ?? this.clienteId),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
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
  State<TpvPeluqueriaScreen> createState() => _TpvPeluqueriaState();
}

class _TpvPeluqueriaState extends State<TpvPeluqueriaScreen> {
  DateTime _fecha = DateTime.now();
  String? _profIdSeleccionado;
  int _profColorIdx = 0;
  String? _uid; // uid del usuario Firebase actual

  final List<Map<String, dynamic>> _lineasTicket = [];
  _TicketExtra _extra = const _TicketExtra();

  Timer? _relojTimer;
  String _hora = '';
  bool _estaOnline = true;
  bool _btConectado = false;
  bool _mostrandoCierre = false;
  StreamSubscription<List<ConnectivityResult>>? _connectSub;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _hora = DateFormat('HH:mm').format(DateTime.now());
    _relojTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        setState(
                () => _hora = DateFormat('HH:mm').format(DateTime.now()));
      }
    });
    _connectSub = Connectivity().onConnectivityChanged.listen((r) {
      if (mounted) {
        setState(
                () => _estaOnline = !r.contains(ConnectivityResult.none));
      }
    });
    ImpressoraBluetooth()
        .estaConectada()
        .then((v) {
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

  double get _subtotal =>
      _lineasTicket.fold(
          0.0, (s, l) => s + ((l['precio'] as num?)?.toDouble() ?? 0));

  double get _total =>
      (_subtotal - _extra.descuentoBono + _extra.propina)
          .clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    if (_mostrandoCierre) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: _CierreWrapper(
          empresaId: widget.empresaId,
          onVolver: () => setState(() => _mostrandoCierre = false),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: Column(children: [
        _FilaProfesionales(
          empresaId: widget.empresaId,
          esAdmin: widget.esAdmin || widget.esPropietario,
          fecha: _fecha,
          fechaStr: _fechaStr,
          profIdSeleccionado: _profIdSeleccionado,
          currentUserUid: _uid,
          onFechaChanged: (d) => setState(() => _fecha = d),
          onProfSeleccionado: (id, idx) =>
              setState(() {
                _profIdSeleccionado = id;
                _profColorIdx = idx;
              }),
          onNuevaCita: _mostrarDialogoNuevaCita,
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(children: [
            Expanded(
              flex: 60,
              child: _profIdSeleccionado == null ||
                  _profIdSeleccionado == '__todos__'
                  ? _TodosTab(
                empresaId: widget.empresaId,
                fechaStr: _fechaStr,
                onCitaCompletada: _cargarCitaEnTicket,
              )
                  : _AgendaTab(
                empresaId: widget.empresaId,
                profId: _profIdSeleccionado,
                fechaStr: _fechaStr,
                profColor: profColor(_profColorIdx),
                onNuevaCita: _mostrarDialogoNuevaCita,
                onCitaCompletada: _cargarCitaEnTicket,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 40,
              child: _ColTicket(
                empresaId: widget.empresaId,
                lineas: _lineasTicket,
                extra: _extra,
                onServicioAdded: (s) =>
                    setState(() => _lineasTicket.add(s)),
                onServicioRemoved: (i) =>
                    setState(() => _lineasTicket.removeAt(i)),
                onExtraChanged: (e) => setState(() => _extra = e),
                onCobrar: _cobrar,
                onLimpiar: _limpiarTicket,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kPelPrimario,
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
        const Text('TPV Peluquería',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const Spacer(),
        Text(_hora, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Icon(
          _estaOnline ? Icons.wifi : Icons.wifi_off,
          size: 15,
          color: _estaOnline ? Colors.white70 : Colors.orangeAccent,
        ),
        const SizedBox(width: 8),
        // ── Apertura de caja ──
        IconButton(
          icon: const Icon(Icons.account_balance_wallet, size: 16),
          onPressed: () => _mostrarAperturaCaja(),
          tooltip: 'Apertura de caja',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
        // ── Cierre de caja ──
        IconButton(
          icon: const Icon(Icons.lock_clock, size: 16),
          onPressed: () => setState(() => _mostrandoCierre = !_mostrandoCierre),
          tooltip: 'Cierre de caja',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 8),
        Text(_hora, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Icon(
          _estaOnline ? Icons.wifi : Icons.wifi_off,
          size: 15,
          color: _estaOnline ? Colors.white70 : Colors.orangeAccent,
        ),
        const SizedBox(width: 6),
        // ── Botón impresora: abre diálogo de configuración BT ──
        IconButton(
          icon: Icon(
            Icons.print,
            size: 16,
            color: _btConectado ? Colors.white70 : Colors.white38,
          ),
          onPressed: () => _mostrarConfigImpresora(),
          tooltip: 'Impresora Bluetooth',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 8),
        TpvTypeSwitcher(
          tipoActual: 'peluqueria',
          onTipoChanged: (tipo) {
            if (tipo == 'tienda') {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    TpvTiendaScreen(
                      empresaId: widget.empresaId,
                      esAdmin: widget.esAdmin,
                      esPropietario: true,
                    ),
              ));
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            Icons.summarize_outlined,
            size: 18,
            color: _mostrandoCierre ? Colors.amber : Colors.white70,
          ),
          onPressed: () =>
              setState(() => _mostrandoCierre = !_mostrandoCierre),
          tooltip: _mostrandoCierre ? 'Volver al TPV' : 'Cierre de caja',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        if (widget.esAdmin || widget.esPropietario) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.palette_outlined, size: 16),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _DialogoReglasColor(empresaId: widget.empresaId),
            ),
            tooltip: 'Reglas de color',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings, size: 16),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ConfiguracionFacturacionTpvScreen(
                        empresaId: widget.empresaId,
                        esPropietario: widget.esPropietario,
                      ),
                ),
              );
            },
            tooltip: 'Configuración TPV',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
        const SizedBox(width: 4),
      ]),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _limpiarTicket() =>
      setState(() {
        _lineasTicket.clear();
        _extra = const _TicketExtra();
      });

  void _cargarCitaEnTicket(Cita cita) {
    if (cita.servicios.isEmpty) return;
    setState(() {
      _lineasTicket.clear();
      for (final s in cita.servicios) {
        _lineasTicket.add({
          'nombre': s['nombre'] ?? '',
          'precio': (s['precio'] as num?)?.toDouble() ?? 0,
        });
      }
      _extra = _extra.copyWith(nombreCliente: cita.clienteNombre);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Servicios de ${cita.clienteNombre} cargados en el ticket'),
      backgroundColor: Colors.green.shade700,
    ));
  }

  void _cargarTurnoEnTicket(TurnoWalkIn turno) {
    setState(() {
      _lineasTicket.clear();
      if (turno.serviciosSeleccionados.isNotEmpty) {
        for (final s in turno.serviciosSeleccionados) {
          _lineasTicket.add({
            'nombre': s['nombre'] ?? '',
            'precio': (s['precio'] as num?)?.toDouble() ?? 0,
          });
        }
      } else if (turno.servicio.isNotEmpty) {
        _lineasTicket.add({'nombre': turno.servicio, 'precio': 0.0});
      }
      _extra = _extra.copyWith(nombreCliente: turno.clienteNombre);
    });
  }

  void _mostrarDialogoNuevaCita() async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _DialogoNuevaCita(
            empresaId: widget.empresaId,
            fecha: _fechaStr,
            profIdInicial: _profIdSeleccionado,
          ),
    );

    // Si se creó una cita, cambiar al profesional seleccionado
    if (resultado != null && resultado['profId'] != null) {
      final profId = resultado['profId'] as String;
      final profIdx = resultado['profIdx'] as int? ?? 0;

      if (mounted) {
        setState(() {
          _profIdSeleccionado = profId;
          _profColorIdx = profIdx;
        });
      }
    }
  }

  // ── Configuración impresora Bluetooth ─────────────────────────────────────
  void _mostrarConfigImpresora() {
    showDialog(
      context: context,
      builder: (_) =>
          _DialogoConfigImpresora(
            onConectada: () {
              if (mounted) setState(() => _btConectado = true);
            },
          ),
    );
  }

  // ── Apertura de caja ──────────────────────────────────────────────────────
  void _mostrarAperturaCaja() {
    showDialog(
      context: context,
      builder: (_) => _DialogoAperturaCaja(empresaId: widget.empresaId),
    );
  }

  Future<void> _cobrar() async {
    if (_lineasTicket.isEmpty) return;
    if (_total <= 0 && _extra.propina == 0) return;

    final pago = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoPago(total: _total, propina: _extra.propina),
    );
    if (pago == null) return;

    try {
      final ahora = DateTime.now();

      // Contador de tickets atómico
      final ref = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('contadores')
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
          .collection('empresas')
          .doc(widget.empresaId)
          .get();
      final nombreEmpresa = empresaSnap.data()?['nombre'] as String? ?? '';

      final lineasPedido = _lineasTicket
          .map((l) => LineaPedido(
        productoId: '',
        productoNombre: l['nombre'] as String? ?? '',
        cantidad: 1,
        precioUnitario: (l['precio'] as num?)?.toDouble() ?? 0,
        ivaPorcentaje: 21,
        notasLinea: null,
      ))
          .toList();

      final pedido = await PedidosService().crearPedido(
        empresaId: widget.empresaId,
        clienteNombre: _extra.nombreCliente ?? 'Caja directa',
        lineas: lineasPedido,
        metodoPago: pago['metodo'] == 'efectivo'
            ? MetodoPago.efectivo
            : MetodoPago.tarjeta,
        origen: OrigenPedido.presencial,
        numeroTicket: numTicket,
        importeEfectivo: pago['importe_efectivo'],
        importeTarjeta: pago['importe_tarjeta'],
        importeTotal: _total,
        mesaId: null,
        estado: 'entregado',
        estadoPago: 'pagado',
        fechaHora: Timestamp.fromDate(ahora),
      );

      // Facturación automática — silenciosa si falla
      try {
        final cfg = await TpvFacturacionService().obtenerConfig(widget.empresaId);
        if (cfg.facturacionAutomatica) {
          await TpvFacturacionService().generarFacturaPorPedido(
            empresaId: widget.empresaId,
            pedido: pedido,
            config: cfg,
            usuarioNombre:
            FirebaseAuth.instance.currentUser?.displayName ?? 'TPV Peluquería',
          );
        }
      } catch (_) {}

      // Impresión Bluetooth — solo Android/iOS, silenciosa si falla
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          await ImpressoraBluetooth().imprimirTicket(TicketData(
            nombreEmpresa: nombreEmpresa,
            numeroTicket: numTicket,
            fecha: ahora,
            lineas: _lineasTicket
                .map((l) => LineaTicket(
              nombre: l['nombre'] as String? ?? '',
              cantidad: 1,
              precioUnitario: (l['precio'] as num?)?.toDouble() ?? 0,
            ))
                .toList(),
            total: _total,
            metodoPago: pago['metodo'] as String? ?? 'efectivo',
          ));
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ticket #$numTicket cobrado — ${_total.toStringAsFixed(2)} €'),
        backgroundColor: Colors.green.shade700,
      ));
      _limpiarTicket();

    } catch (e, stackTrace) {
      debugPrint('❌ Error en _cobrar: $e\n$stackTrace');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error al cobrar'),
          content: SingleChildScrollView(
            child: SelectableText(
              '${e.runtimeType}\n\n$e\n\n$stackTrace',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }
}
// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO CONFIGURACIÓN IMPRESORA BLUETOOTH
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoConfigImpresora extends StatefulWidget {
  final VoidCallback onConectada;
  const _DialogoConfigImpresora({required this.onConectada});

  @override
  State<_DialogoConfigImpresora> createState() => _DialogoConfigImporesoraState();
}

class _DialogoConfigImporesoraState extends State<_DialogoConfigImpresora> {
  final _servicio = ImpressoraBluetooth();
  List<BluetoothDevice> _dispositivos = [];
  bool _cargando = true;
  String? _error;
  String? _dispositivoConectadoNombre;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final conectado = await _servicio.estaConectada();
      final ultima = await _servicio.obtenerUltimaGuardada();
      final lista = await _servicio.escanearImpresoras();
      if (mounted) {
        setState(() {
          _dispositivos = lista;
          _cargando = false;
          _dispositivoConectadoNombre = conectado ? (ultima?['name']) : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  Future<void> _conectar(BluetoothDevice device) async {
    setState(() => _cargando = true);
    try {
      await _servicio.conectar(device);
      if (mounted) {
        setState(() {
          _dispositivoConectadoNombre = device.name;
          _cargando = false;
        });
        widget.onConectada();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Conectado a ${device.name}'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  Future<void> _imprimirPrueba() async {
    try {
      await _servicio.imprimirTicket(TicketData(
        nombreEmpresa: 'PRUEBA IMPRESORA',
        numeroTicket: 0,
        fecha: DateTime.now(),
        lineas: [
          LineaTicket(nombre: 'Línea de prueba', cantidad: 1, precioUnitario: 9.99),
        ],
        total: 9.99,
        metodoPago: 'efectivo',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error imprimiendo: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kTarjeta,
      title: Row(children: [
        Icon(Icons.print, color: kCian, size: 20),
        const SizedBox(width: 8),
        const Text('Impresora Bluetooth',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
          onPressed: _cargar,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
      content: SizedBox(
        width: 340,
        child: _cargando
            ? const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: kCian),
              ))
            : _error != null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bluetooth_disabled, color: Colors.red.shade300, size: 40),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _cargar, child: const Text('Reintentar', style: TextStyle(color: kCian))),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_dispositivoConectadoNombre != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: kCian.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kCian.withValues(alpha: 0.4)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle, color: kCian, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Conectado: $_dispositivoConectadoNombre',
                              style: const TextStyle(color: kCian, fontSize: 12))),
                          TextButton(
                            onPressed: _imprimirPrueba,
                            style: TextButton.styleFrom(padding: EdgeInsets.zero,
                                minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Test', style: TextStyle(color: kCian, fontSize: 11)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_dispositivos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Icon(Icons.bluetooth_searching, color: Colors.white38, size: 40),
                          const SizedBox(height: 8),
                          const Text('No hay impresoras emparejadas.\nEmpareja la impresora en\nAjustes → Bluetooth primero.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ]),
                      )
                    else
                      ...(_dispositivos.map((d) => ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: const Icon(Icons.print_outlined, color: Colors.white54, size: 20),
                        title: Text(d.name ?? 'Dispositivo',
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text(d.address ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        trailing: ElevatedButton(
                          onPressed: () => _conectar(d),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kCian,
                            foregroundColor: kFondoOscuro,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Conectar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ))),
                  ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CIERRE WRAPPER
// ═══════════════════════════════════════════════════════════════════════════

class _CierreWrapper extends StatelessWidget {
  final String empresaId;
  final VoidCallback onVolver;

  const _CierreWrapper(
      {required this.empresaId, required this.onVolver});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: kPelPrimarioLight,
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          TextButton.icon(
            onPressed: onVolver,
            icon: const Icon(Icons.arrow_back_ios_new, size: 14),
            label: const Text('Volver al TPV',
                style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
      Expanded(child: _PelCierreDeCaja(empresaId: empresaId)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FILA DE PROFESIONALES — con fallback a empleados si profesionales vacío
// ═══════════════════════════════════════════════════════════════════════════

// ══ _FilaProfesionales ════════════════════════════════════════════════════════
// StatefulWidget para gestionar suscripciones conjuntas empleados+profesionales.
// Para admin/propietario: fusiona empleados (fuente principal) con profesionales
// (datos TPV específicos que sobreescriben por mismo doc-id).
// Para staff: solo lee profesionales (Firestore rules no permiten leer empleados).

class _FilaProfesionales extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final DateTime fecha;
  final String fechaStr;
  final String? profIdSeleccionado;
  final String? currentUserUid;
  final ValueChanged<DateTime> onFechaChanged;
  final Function(String id, int colorIdx) onProfSeleccionado;
  final VoidCallback onNuevaCita;

  const _FilaProfesionales({
    required this.empresaId,
    required this.esAdmin,
    required this.fecha,
    required this.fechaStr,
    required this.profIdSeleccionado,
    this.currentUserUid,
    required this.onFechaChanged,
    required this.onProfSeleccionado,
    required this.onNuevaCita,
  });

  @override
  State<_FilaProfesionales> createState() => _FilaProfesionalesState();
}

class _FilaProfesionalesState extends State<_FilaProfesionales> {
  List<Profesional> _profesionales = [];
  bool _cargando = true;

  List<Profesional> _listaProfs = [];
  List<Profesional> _listaEmpleados = [];

  StreamSubscription<QuerySnapshot>? _subProfs;
  StreamSubscription<QuerySnapshot>? _subEmpleados;

  @override
  void initState() {
    super.initState();
    _suscribir();
  }

  @override
  void didUpdateWidget(_FilaProfesionales old) {
    super.didUpdateWidget(old);
    if (old.empresaId != widget.empresaId || old.esAdmin != widget.esAdmin) {
      _cancelar();
      _suscribir();
    }
  }

  void _suscribir() {
    // Siempre escuchar la colección profesionales (staff y admin pueden leerla)
    _subProfs = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('profesionales')
        .snapshots()
        .listen((snap) {
      _listaProfs = snap.docs
          .where((d) => (d.data() as Map<String, dynamic>)['activo'] != false)
          .map(Profesional.fromDoc)
          .toList();
      _fusionar();
    }, onError: (_) {
      _listaProfs = [];
      _fusionar();
    });

    // Suscribirse a usuarios con empresa_id (fuente real de empleados).
    // Los usuarios en Firestore se guardan en la colección 'usuarios' con campo
    // 'empresa_id'. Esto incluye a staff, admin y propietario.
    _subEmpleados = FirebaseFirestore.instance
        .collection('usuarios')
        .where('empresa_id', isEqualTo: widget.empresaId)
        .snapshots()
        .listen((snap) {
      _listaEmpleados = snap.docs
          .where((d) =>
              (d.data() as Map<String, dynamic>)['activo'] != false)
          .map(Profesional.fromEmpleado)
          .toList();
      _fusionar();
    }, onError: (_) {
      // Sin permisos o error: intentar también subcollección empleados (fallback)
      _subEmpleados?.cancel();
      _subEmpleados = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('empleados')
          .snapshots()
          .listen((snap) {
        _listaEmpleados = snap.docs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['activo'] != false)
            .map(Profesional.fromEmpleado)
            .toList();
        _fusionar();
      }, onError: (_) {
        _listaEmpleados = [];
        _fusionar();
      });
    });
  }

  void _fusionar() {
    // Los profesionales con entrada en `profesionales` tienen prioridad.
    // Los empleados que NO tienen entrada en `profesionales` se añaden al final.
    final idsProfs = _listaProfs.map((p) => p.id).toSet();
    final merged = [
      ..._listaProfs,
      ..._listaEmpleados.where((e) => !idsProfs.contains(e.id)),
    ];
    // Future.delayed(Duration.zero) garantiza que setState se ejecuta
    // en el event loop de Flutter (hilo principal), evitando el warning
    // "non-platform thread" del plugin cloud_firestore en Windows.
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      setState(() {
        _profesionales = merged;
        _cargando = false;
      });
      // Auto-seleccionar profesional:
      // – Si es empleado (no admin) y su uid está en la lista → su propia agenda
      // – En caso contrario → el primero de la lista
      if (merged.isNotEmpty && widget.profIdSeleccionado == null) {
        if (!widget.esAdmin && widget.currentUserUid != null) {
          final myIdx = merged.indexWhere((p) => p.id == widget.currentUserUid);
          if (myIdx >= 0) {
            widget.onProfSeleccionado(merged[myIdx].id, myIdx);
            return;
          }
        }
        widget.onProfSeleccionado(merged.first.id, 0);
      }
    });
  }

  void _cancelar() {
    _subProfs?.cancel();
    _subEmpleados?.cancel();
    _subProfs = null;
    _subEmpleados = null;
  }

  @override
  void dispose() {
    _cancelar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.white,
      child: Row(children: [
        // Navegador de fecha
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: kPelPrimarioLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => widget.onFechaChanged(
                  widget.fecha.subtract(const Duration(days: 1))),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('EEE d MMM yyyy', 'es').format(widget.fecha),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => widget.onFechaChanged(
                  widget.fecha.add(const Duration(days: 1))),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        // Lista de profesionales
        Expanded(
          child: _cargando
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : _buildListaProfesionales(_profesionales),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: widget.onNuevaCita,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva cita', style: TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(
            backgroundColor: kPelPrimario,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ]),
    );
  }

  Widget _buildListaProfesionales(List<Profesional> profs) {
    if (profs.isEmpty) {
      return Row(children: [
        const Text('Sin profesionales',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        if (widget.esAdmin) ...[
          const SizedBox(width: 12),
          _BtnCrearProfesional(empresaId: widget.empresaId, colorIdx: 0),
        ],
      ]);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        // ── CHIP "Todos" ──────────────────────────────────────────
        GestureDetector(
          onTap: () => widget.onProfSeleccionado('__todos__', -1),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.profIdSeleccionado == '__todos__' || widget.profIdSeleccionado == null
                        ? kPelPrimario
                        : Colors.grey.shade300,
                    width: widget.profIdSeleccionado == '__todos__' || widget.profIdSeleccionado == null ? 3 : 1.5,
                  ),
                  color: kPelPrimario.withValues(alpha: 0.1),
                ),
                child: const Center(
                  child: Icon(Icons.people, color: kPelPrimario, size: 22),
                ),
              ),
              const SizedBox(height: 4),
              Text('Todos',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: (widget.profIdSeleccionado == '__todos__' || widget.profIdSeleccionado == null)
                      ? FontWeight.w700 : FontWeight.w500,
                  color: (widget.profIdSeleccionado == '__todos__' || widget.profIdSeleccionado == null)
                      ? kPelPrimario : Colors.grey.shade700,
                ),
              ),
            ]),
          ),
        ),
        // ── Lista de profesionales ────────────────────────────────
        ...profs.asMap().entries.map((e) {
          final idx = e.key;
          final prof = e.value;
          return _AvatarProfesional(
            prof: prof,
            colorIdx: idx,
            seleccionado: prof.id == widget.profIdSeleccionado,
            empresaId: widget.empresaId,
            fechaStr: widget.fechaStr,
            esAdmin: widget.esAdmin,
            onTap: () => widget.onProfSeleccionado(prof.id, idx),
          );
        }),
        if (widget.esAdmin)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _BtnCrearProfesional(
              empresaId: widget.empresaId,
              colorIdx: profs.length,
            ),
          ),
      ]),
    );
  }
}

// ── Avatar profesional ───────────────────────────────────────────────────────

class _AvatarProfesional extends StatelessWidget {
  final Profesional prof;
  final int colorIdx;
  final bool seleccionado;
  final String empresaId, fechaStr;
  final bool esAdmin;
  final VoidCallback onTap;

  const _AvatarProfesional({
    required this.prof,
    required this.colorIdx,
    required this.seleccionado,
    required this.empresaId,
    required this.fechaStr,
    required this.esAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = profColor(colorIdx);
    return GestureDetector(
      onTap: onTap,
      onLongPress: esAdmin ? () => _menuProfesional(context) : null,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                  seleccionado ? color : Colors.grey.shade300,
                  width: seleccionado ? 3 : 1.5,
                ),
                color: color.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text(
                  prof.initials,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(empresaId)
                    .collection('reservas')
                    .where('prof_id', isEqualTo: prof.id)
                    .where('fecha', isEqualTo: fechaStr)
                    .where('estado', isEqualTo: 'enCurso')
                    .snapshots(),
                builder: (_, snap) {
                  final ocupado =
                      snap.hasData && snap.data!.docs.isNotEmpty;
                  return Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ocupado ? Colors.red : Colors.green,
                      border:
                      Border.all(color: Colors.white, width: 2),
                    ),
                  );
                },
              ),
            ),
          ]),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              prof.nombre.split(' ').first,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: seleccionado
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: seleccionado ? color : Colors.grey.shade700,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _menuProfesional(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) =>
          Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(prof.nombre,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar profesional'),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => _DialogoProfesional(
                      empresaId: empresaId,
                      profesional: prof,
                      colorIdx: colorIdx),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_off, color: Colors.orange),
              title: const Text('Desactivar'),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(empresaId)
                    .collection('profesionales')
                    .doc(prof.id)
                    .update({'activo': false});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ]),
    );
  }
}

// ── Botón crear profesional ──────────────────────────────────────────────────

class _BtnCrearProfesional extends StatelessWidget {
  final String empresaId;
  final int colorIdx;

  const _BtnCrearProfesional(
      {required this.empresaId, required this.colorIdx});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _DialogoProfesional(
            empresaId: empresaId,
            profesional: null,
            colorIdx: colorIdx),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: kPelPrimario.withValues(alpha: 0.4),
              width: 1.5,
            ),
            color: kPelPrimarioLight,
          ),
          child: const Icon(Icons.add, color: kPelPrimario, size: 22),
        ),
        const SizedBox(height: 4),
        const Text('Añadir',
            style: TextStyle(fontSize: 10, color: kPelPrimario)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO CREAR / EDITAR PROFESIONAL
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoProfesional extends StatefulWidget {
  final String empresaId;
  final Profesional? profesional;
  final int colorIdx;

  const _DialogoProfesional({
    required this.empresaId,
    required this.profesional,
    required this.colorIdx,
  });

  @override
  State<_DialogoProfesional> createState() => _DialogoProfesionalState();
}

class _DialogoProfesionalState extends State<_DialogoProfesional> {
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _especialidadCtrl = TextEditingController();
  String _horaEntrada = '09:00';
  String _horaSalida = '20:00';
  int _colorIdx = 0;
  bool _guardando = false;
  double _comisionPct = 0.0;

  final List<String> _especialidades = [
    'Corte', 'Color / Tinte', 'Mechas', 'Peinado',
    'Manicura', 'Pedicura', 'Depilación', 'Estética facial',
    'Masajes', 'Pestañas', 'Cejas',
  ];

  @override
  void initState() {
    super.initState();
    _colorIdx = widget.colorIdx % kProfColors.length;
    if (widget.profesional != null) {
      final p = widget.profesional!;
      _nombreCtrl.text = p.nombre;
      _telefonoCtrl.text = p.telefono ?? '';
      _especialidadCtrl.text = p.especialidad ?? '';
      _horaEntrada = p.horaEntrada;
      _horaSalida = p.horaSalida;
      _colorIdx = p.colorIdx;
      FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('profesionales')
          .doc(p.id)
          .get()
          .then((snap) {
        if (snap.exists && mounted) {
          final data = snap.data() as Map<String, dynamic>;
          setState(() {
            _comisionPct =
                (data['comision_pct'] as num?)?.toDouble() ?? 0;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _especialidadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slots = generarSlots(pasoMin: 60);
    final esEdicion = widget.profesional != null;

    return AlertDialog(
      title: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: profColor(_colorIdx).withValues(alpha: 0.15),
          ),
          child: Center(
            child: Text(
              _nombreCtrl.text.isNotEmpty
                  ? _nombreCtrl.text[0].toUpperCase()
                  : '+',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: profColor(_colorIdx)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(esEdicion ? 'Editar profesional' : 'Nuevo profesional'),
      ]),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Nombre completo *',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _especialidadCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Especialidad principal',
                prefixIcon: Icon(Icons.content_cut),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _especialidades
                  .map((e) => ActionChip(
                label: Text(e,
                    style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(
                        () => _especialidadCtrl.text = e),
              ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _horaEntrada,
                  decoration: const InputDecoration(
                      labelText: 'Entrada', isDense: true),
                  items: slots
                      .map((s) => DropdownMenuItem(
                      value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _horaEntrada = v ?? '09:00'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _horaSalida,
                  decoration: const InputDecoration(
                      labelText: 'Salida', isDense: true),
                  items: slots
                      .map((s) => DropdownMenuItem(
                      value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _horaSalida = v ?? '20:00'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comisión sobre ventas',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_comisionPct.toInt()}%',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kPelPrimario),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _comisionPct,
                  min: 0,
                  max: 60,
                  divisions: 12,
                  activeColor: kPelPrimario,
                  label: '${_comisionPct.toInt()}%',
                  onChanged: (v) => setState(() => _comisionPct = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0%',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600)),
                    Text('60%',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Color de agenda',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(kProfColors.length, (i) {
                final c = kProfColors[i];
                return GestureDetector(
                  onTap: () => setState(() => _colorIdx = i),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: _colorIdx == i
                            ? Colors.black87
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: _colorIdx == i
                        ? const Icon(Icons.check,
                        size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_guardando || _nombreCtrl.text.trim().isEmpty)
              ? null
              : _guardar,
          style: FilledButton.styleFrom(backgroundColor: kPelPrimario),
          child: _guardando
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Text(esEdicion ? 'Guardar cambios' : 'Crear profesional'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _guardando = true);

    final data = {
      'nombre': nombre,
      'telefono': _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim(),
      'especialidad': _especialidadCtrl.text.trim().isEmpty
          ? null
          : _especialidadCtrl.text.trim(),
      'hora_entrada': _horaEntrada,
      'hora_salida': _horaSalida,
      'color_index': _colorIdx,
      'comision_pct': _comisionPct,
      'activo': true,
    };

    try {
      if (widget.profesional != null) {
        await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('profesionales')
            .doc(widget.profesional!.id)
            .update(data);
      } else {
        await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('profesionales')
            .add(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AGENDA TAB
// ═══════════════════════════════════════════════════════════════════════════

// ── AgendaTab: siempre muestra el timeline, con citas posicionadas por hora ──

class _AgendaTab extends StatefulWidget {
  final String empresaId;
  final String? profId;
  final String fechaStr;
  final Color profColor;
  final VoidCallback onNuevaCita;
  final ValueChanged<Cita> onCitaCompletada;

  const _AgendaTab({
    required this.empresaId,
    required this.profId,
    required this.fechaStr,
    required this.profColor,
    required this.onNuevaCita,
    required this.onCitaCompletada,
  });

  @override
  State<_AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<_AgendaTab> {
  List<Cita> _citas = [];
  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _suscribir();
  }

  @override
  void didUpdateWidget(_AgendaTab old) {
    super.didUpdateWidget(old);
    if (old.profId != widget.profId || old.fechaStr != widget.fechaStr) {
      _suscribir();
    }
  }

  void _suscribir() {
    _sub?.cancel();
    _sub = null;
    if (widget.profId == null) {
      Future.delayed(Duration.zero, () {
        if (mounted) setState(() => _citas = []);
      });
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('reservas')
        .where('fecha', isEqualTo: widget.fechaStr)
        .snapshots()
        .listen((snap) {
      final citas = <Cita>[];
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final pId = (data['prof_id'] as String?) ??
            (data['profesional_id'] as String?) ??
            (data['empleado_id'] as String?) ??
            '';
        if (pId == widget.profId) citas.add(Cita.fromDoc(d));
      }
      citas.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
      Future.delayed(Duration.zero, () {
        if (mounted) setState(() => _citas = citas);
      });
    }, onError: (_) {
      Future.delayed(Duration.zero, () {
        if (mounted) setState(() => _citas = []);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profId == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_search, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Selecciona un profesional',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('o pulsa "Nueva cita" para crear una directamente',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );
    }

    return _AgendaTimeline(
      citas: _citas,
      profColor: widget.profColor,
      onNuevaCita: widget.onNuevaCita,
      onTapCita: (c) => showDialog(
        context: context,
        builder: (_) => _DialogoDetalleCita(
          cita: c,
          empresaId: widget.empresaId,
          onCompletada: widget.onCitaCompletada,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB "TODOS" — Vista global de todas las citas del día por todos los profesionales
// ═══════════════════════════════════════════════════════════════════════════

class _TodosTab extends StatefulWidget {
  final String empresaId;
  final String fechaStr;
  final ValueChanged<Cita> onCitaCompletada;

  const _TodosTab({
    required this.empresaId,
    required this.fechaStr,
    required this.onCitaCompletada,
  });

  @override
  State<_TodosTab> createState() => _TodosTabState();
}

class _TodosTabState extends State<_TodosTab> {
  List<Cita> _citas = [];
  List<Profesional> _profesionales = [];
  List<Profesional> _listaProfs = [];
  List<Profesional> _listaUsuarios = [];
  List<Map<String, dynamic>> _reglasColor = [];
  StreamSubscription<QuerySnapshot>? _subCitas;
  StreamSubscription<QuerySnapshot>? _subProfs;
  StreamSubscription<QuerySnapshot>? _subUsuarios;

  @override
  void initState() {
    super.initState();
    _suscribir();
  }

  @override
  void didUpdateWidget(_TodosTab old) {
    super.didUpdateWidget(old);
    if (old.fechaStr != widget.fechaStr) _suscribirCitas();
  }

  void _fusionarProfs() {
    final idsProfs = _listaProfs.map((p) => p.id).toSet();
    final merged = [
      ..._listaProfs,
      ..._listaUsuarios.where((e) => !idsProfs.contains(e.id)),
    ];
    Future.delayed(Duration.zero, () {
      if (mounted) setState(() => _profesionales = merged);
    });
  }

  void _suscribir() {
    _subProfs = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('profesionales')
        .snapshots()
        .listen((snap) {
      _listaProfs = snap.docs
          .where((d) => (d.data() as Map<String, dynamic>)['activo'] != false)
          .map(Profesional.fromDoc)
          .toList();
      _fusionarProfs();
    }, onError: (_) {});

    _subUsuarios = FirebaseFirestore.instance
        .collection('usuarios')
        .where('empresa_id', isEqualTo: widget.empresaId)
        .snapshots()
        .listen((snap) {
      _listaUsuarios = snap.docs
          .where((d) => (d.data() as Map<String, dynamic>)['activo'] != false)
          .map(Profesional.fromEmpleado)
          .toList();
      _fusionarProfs();
    }, onError: (_) {});

    // Reglas de color: carga puntual (no suscripción) para reducir canales en Windows
    FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('config')
        .doc('color_rules_tpv')
        .get()
        .then((snap) {
      final reglas = (snap.data()?['reglas'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      Future.delayed(Duration.zero, () {
        if (mounted) setState(() => _reglasColor = reglas);
      });
    }).catchError((_) {});

    _suscribirCitas();
  }

  void _suscribirCitas() {
    _subCitas?.cancel();
    _subCitas = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('reservas')
        .where('fecha', isEqualTo: widget.fechaStr)
        .snapshots()
        .listen((snap) {
      final citas = snap.docs.map(Cita.fromDoc).toList();
      Future.delayed(Duration.zero, () {
        if (mounted) setState(() => _citas = citas);
      });
    }, onError: (_) {
      Future.delayed(Duration.zero, () {
        if (mounted) setState(() => _citas = []);
      });
    });
  }

  @override
  void dispose() {
    _subCitas?.cancel();
    _subProfs?.cancel();
    _subUsuarios?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TodosTimeline(
      citas: _citas,
      profesionales: _profesionales,
      reglasColor: _reglasColor,
      onTapCita: (c) => showDialog(
        context: context,
        builder: (_) => _DialogoDetalleCita(
          cita: c,
          empresaId: widget.empresaId,
          onCompletada: widget.onCitaCompletada,
        ),
      ),
    );
  }
}

// ── Timeline multi-profesional ───────────────────────────────────────────────

class _TodosTimeline extends StatefulWidget {
  final List<Cita> citas;
  final List<Profesional> profesionales;
  final List<Map<String, dynamic>> reglasColor;
  final ValueChanged<Cita> onTapCita;

  static const int inicioHora = 8;
  static const int finHora = 21;
  static const double alturaHora = 100.0;

  const _TodosTimeline({
    required this.citas,
    required this.profesionales,
    required this.reglasColor,
    required this.onTapCita,
  });

  @override
  State<_TodosTimeline> createState() => _TodosTimelineState();
}

class _TodosTimelineState extends State<_TodosTimeline> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _irAHoraActual());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _irAHoraActual() {
    final ahora = DateTime.now();
    if (ahora.hour < _TodosTimeline.inicioHora || ahora.hour > _TodosTimeline.finHora) return;
    final minDesdeInicio = (ahora.hour - _TodosTimeline.inicioHora) * 60 + ahora.minute;
    final offset = (minDesdeInicio * (_TodosTimeline.alturaHora / 60)) - 80.0;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  Color _colorParaCita(Cita cita) {
    final servNombre = cita.servicios.isNotEmpty
        ? (cita.servicios.first['nombre'] as String? ?? '')
        : cita.servicioNombre;
    for (final regla in widget.reglasColor) {
      final tipo = regla['tipo'] as String? ?? '';
      final valor = (regla['valor'] as String? ?? '').toLowerCase();
      final colorVal = regla['color'] as int?;
      if (colorVal == null) continue;
      final c = Color(colorVal);
      if (tipo == 'servicio' && servNombre.toLowerCase().contains(valor)) return c;
      if (tipo == 'estado' && cita.estado.toLowerCase() == valor) return c;
      if (tipo == 'profesional') {
        final profNombre = widget.profesionales
            .where((p) => p.id == cita.profesionalId)
            .map((p) => p.nombre.toLowerCase())
            .firstOrNull ?? '';
        if (profNombre.contains(valor)) return c;
      }
    }
    final idx = widget.profesionales.indexWhere((p) => p.id == cita.profesionalId);
    return idx >= 0 ? profColor(idx) : Colors.grey.shade400;
  }

  String _nombreProf(String profId) {
    try {
      return widget.profesionales
          .firstWhere((p) => p.id == profId)
          .nombre
          .split(' ')
          .first;
    } catch (_) {
      return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalHoras = _TodosTimeline.finHora - _TodosTimeline.inicioHora;
    final totalAltura = totalHoras * _TodosTimeline.alturaHora;
    final horaActual = DateTime.now().hour;
    final citasConColumna = _calcularColumnas(widget.citas);

    return Column(children: [
      // ── Cabecera con leyenda de profesionales ──
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                widget.citas.isEmpty
                    ? 'Sin citas hoy'
                    : '${widget.citas.length} cita${widget.citas.length == 1 ? '' : 's'} en total',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _irAHoraActual,
                icon: Icon(Icons.access_time, size: 13, color: Colors.grey.shade600),
                label: Text('Ahora', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
            if (widget.profesionales.isNotEmpty) ...[
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ...widget.profesionales.asMap().entries.map((e) {
                    final color = profColor(e.key);
                    final cnt = widget.citas.where((c) => c.profesionalId == e.value.id).length;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          e.value.nombre.split(' ').first,
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                        ),
                        if (cnt > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                            child: Text('$cnt',
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                    );
                  }),
                ]),
              ),
            ],
          ],
        ),
      ),
      const Divider(height: 1),
      // ── Timeline scrollable ──
      Expanded(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.only(bottom: 24, top: 4),
          child: SizedBox(
            height: totalAltura + 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna de horas
                SizedBox(
                  width: 58,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (int h = _TodosTimeline.inicioHora; h < _TodosTimeline.finHora; h++)
                        if (h.isEven)
                          Positioned(
                            top: (h - _TodosTimeline.inicioHora) * _TodosTimeline.alturaHora,
                            left: 0, right: 0,
                            height: _TodosTimeline.alturaHora,
                            child: Container(color: Colors.grey.shade50),
                          ),
                      for (int h = _TodosTimeline.inicioHora; h <= _TodosTimeline.finHora; h++)
                        Positioned(
                          top: (h - _TodosTimeline.inicioHora) * _TodosTimeline.alturaHora - 8,
                          right: 8,
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 11,
                              color: h == horaActual ? Colors.red.shade500 : Colors.grey.shade600,
                              fontWeight: h == horaActual ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(width: 1, color: Colors.grey.shade200),
                // Área del timeline
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final anchoDisponible = constraints.maxWidth;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (int h = _TodosTimeline.inicioHora; h < _TodosTimeline.finHora; h++)
                            if (h.isEven)
                              Positioned(
                                top: (h - _TodosTimeline.inicioHora) * _TodosTimeline.alturaHora,
                                left: 0, right: 0, height: _TodosTimeline.alturaHora,
                                child: Container(color: Colors.grey.shade50),
                              ),
                          for (int h = _TodosTimeline.inicioHora; h <= _TodosTimeline.finHora; h++) ...[
                            Positioned(
                              top: (h - _TodosTimeline.inicioHora) * _TodosTimeline.alturaHora,
                              left: 0, right: 8, height: 1,
                              child: Container(
                                color: h == horaActual ? Colors.red.shade200 : Colors.grey.shade300,
                              ),
                            ),
                            if (h < _TodosTimeline.finHora)
                              Positioned(
                                top: (h - _TodosTimeline.inicioHora) * _TodosTimeline.alturaHora +
                                    _TodosTimeline.alturaHora / 2,
                                left: 12, right: 8, height: 1,
                                child: Container(color: Colors.grey.shade200),
                              ),
                          ],
                          _buildHoraActualIndicador(),
                          for (final info in citasConColumna)
                            _buildCitaBlock(
                              info['cita'] as Cita,
                              info['columna'] as int,
                              info['totalColumnas'] as int,
                              anchoDisponible,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildHoraActualIndicador() {
    final ahora = DateTime.now();
    if (ahora.hour < _TodosTimeline.inicioHora || ahora.hour > _TodosTimeline.finHora) {
      return const SizedBox.shrink();
    }
    final minDesdeInicio = (ahora.hour - _TodosTimeline.inicioHora) * 60 + ahora.minute;
    final top = minDesdeInicio * (_TodosTimeline.alturaHora / 60);
    return Positioned(
      top: top, left: 0, right: 8,
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
        ),
        Expanded(child: Container(height: 1.5, color: Colors.red.withValues(alpha: 0.6))),
      ]),
    );
  }

  Widget _buildCitaBlock(Cita cita, int columna, int totalColumnas, double anchoDisponible) {
    final parts = cita.horaInicio.split(':');
    final h = int.tryParse(parts[0]) ?? _TodosTimeline.inicioHora;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final minDesdeInicio = (h - _TodosTimeline.inicioHora) * 60 + m;
    final top = minDesdeInicio * (_TodosTimeline.alturaHora / 60);
    final height = (cita.duracionMinutos * (_TodosTimeline.alturaHora / 60)).clamp(20.0, double.infinity);
    final color = _colorParaCita(cita);
    final profNombre = _nombreProf(cita.profesionalId);
    final servicioNombre = cita.servicios.isNotEmpty
        ? cita.servicios.map((s) => s['nombre'] as String? ?? '').join(', ')
        : cita.servicioNombre.isNotEmpty
            ? cita.servicioNombre
            : '';
    final anchoPorColumna = (anchoDisponible - 12) / totalColumnas;
    final left = 2 + (columna * anchoPorColumna);
    final width = anchoPorColumna - 4;

    return Positioned(
      top: top, left: left, width: width, height: height,
      child: GestureDetector(
        onTap: () => widget.onTapCita(cita),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 3, offset: const Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    cita.clienteNombre,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                _EstadoBadge(estado: cita.estado),
              ]),
              const SizedBox(height: 1),
              Text(
                servicioNombre.isNotEmpty
                    ? '${cita.horaInicio}  ·  $servicioNombre'
                    : cita.horaInicio,
                style: const TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (profNombre.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  profNombre,
                  style: const TextStyle(fontSize: 8, color: Colors.white60),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _calcularColumnas(List<Cita> citas) {
    if (citas.isEmpty) return [];
    final citasOrd = List<Cita>.from(citas)..sort((a, b) {
      int toMin(Cita c) {
        final p = c.horaInicio.split(':');
        return (int.tryParse(p[0]) ?? 0) * 60 + (p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0);
      }
      return toMin(a).compareTo(toMin(b));
    });
    final resultado = <Map<String, dynamic>>[];
    final grupos = <List<Cita>>[];
    for (final cita in citasOrd) {
      bool agregado = false;
      for (final grupo in grupos) {
        if (grupo.any((g) => _seSolapan(cita, g))) {
          grupo.add(cita);
          agregado = true;
          break;
        }
      }
      if (!agregado) grupos.add([cita]);
    }
    for (final grupo in grupos) {
      for (int i = 0; i < grupo.length; i++) {
        resultado.add({'cita': grupo[i], 'columna': i, 'totalColumnas': grupo.length});
      }
    }
    return resultado;
  }

  bool _seSolapan(Cita a, Cita b) {
    int toMin(Cita c) {
      final p = c.horaInicio.split(':');
      return (int.tryParse(p[0]) ?? _TodosTimeline.inicioHora) * 60 +
          (p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0);
    }
    final aI = toMin(a), aF = aI + a.duracionMinutos;
    final bI = toMin(b), bF = bI + b.duracionMinutos;
    return (aI < bF) && (bI < aF);
  }
}


class _AgendaTimeline extends StatefulWidget {
  final List<Cita> citas;
  final Color profColor;
  final VoidCallback onNuevaCita;
  final ValueChanged<Cita> onTapCita;

  static const int inicioHora = 8;
  static const int finHora = 21;

  /// Píxeles por hora — ajusta la densidad visual del calendario
  static const double alturaHora = 100.0;

  const _AgendaTimeline({
    required this.citas,
    required this.profColor,
    required this.onNuevaCita,
    required this.onTapCita,
  });

  @override
  State<_AgendaTimeline> createState() => _AgendaTimelineState();
}

class _AgendaTimelineState extends State<_AgendaTimeline> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _irAHoraActual());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _irAHoraActual() {
    final ahora = DateTime.now();
    if (ahora.hour < _AgendaTimeline.inicioHora ||
        ahora.hour > _AgendaTimeline.finHora) return;
    final minDesdeInicio =
        (ahora.hour - _AgendaTimeline.inicioHora) * 60 + ahora.minute;
    final offset =
        (minDesdeInicio * (_AgendaTimeline.alturaHora / 60)) - 80.0;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalHoras = _AgendaTimeline.finHora - _AgendaTimeline.inicioHora;
    final totalAltura = totalHoras * _AgendaTimeline.alturaHora;
    final horaActual = DateTime.now().hour;

    // Calcular columnas para evitar solapamiento
    final citasConColumna = _calcularColumnasParaCitas(widget.citas);

    return Column(children: [
      // Cabecera mini con estado del día
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.citas.isEmpty ? Colors.grey.shade300 : widget.profColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.citas.isEmpty
                ? 'Día libre — sin citas'
                : '${widget.citas.length} cita${widget.citas.length == 1 ? '' : 's'} hoy',
            style: TextStyle(
              fontSize: 12,
              color: widget.citas.isEmpty ? Colors.grey : widget.profColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _irAHoraActual,
            icon: Icon(Icons.access_time, size: 13, color: Colors.grey.shade600),
            label: Text('Ahora', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: widget.onNuevaCita,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Nueva cita', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: kPelPrimario),
          ),
        ]),
      ),
      const Divider(height: 1),
      // ── Timeline scrollable ──
      Expanded(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.only(bottom: 24, top: 4),
          child: SizedBox(
            height: totalAltura + 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna de horas (izquierda)
                SizedBox(
                  width: 58,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Bandas de fondo alternadas (sobre la columna de horas también)
                      for (int h = _AgendaTimeline.inicioHora; h < _AgendaTimeline.finHora; h++)
                        if (h.isEven)
                          Positioned(
                            top: (h - _AgendaTimeline.inicioHora) * _AgendaTimeline.alturaHora,
                            left: 0, right: 0,
                            height: _AgendaTimeline.alturaHora,
                            child: Container(color: Colors.grey.shade50),
                          ),
                      for (int h = _AgendaTimeline.inicioHora; h <= _AgendaTimeline.finHora; h++)
                        Positioned(
                          top: (h - _AgendaTimeline.inicioHora) * _AgendaTimeline.alturaHora - 8,
                          right: 8,
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 11,
                              color: h == horaActual
                                  ? Colors.red.shade500
                                  : Colors.grey.shade600,
                              fontWeight: h == horaActual
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Separador vertical entre horas y citas
                Container(width: 1, color: Colors.grey.shade200),
                // Área del timeline con líneas y citas
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final anchoDisponible = constraints.maxWidth;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Bandas de fondo alternadas para identificar las horas
                          for (int h = _AgendaTimeline.inicioHora; h < _AgendaTimeline.finHora; h++)
                            if (h.isEven)
                              Positioned(
                                top: (h - _AgendaTimeline.inicioHora) * _AgendaTimeline.alturaHora,
                                left: 0, right: 0,
                                height: _AgendaTimeline.alturaHora,
                                child: Container(color: Colors.grey.shade50),
                              ),
                          // Líneas de hora (más visibles) y media hora (sutiles)
                          for (int h = _AgendaTimeline.inicioHora; h <= _AgendaTimeline.finHora; h++) ...[
                            Positioned(
                              top: (h - _AgendaTimeline.inicioHora) * _AgendaTimeline.alturaHora,
                              left: 0, right: 8, height: 1,
                              child: Container(
                                color: h == horaActual
                                    ? Colors.red.shade200
                                    : Colors.grey.shade300,
                              ),
                            ),
                            if (h < _AgendaTimeline.finHora)
                              Positioned(
                                top: (h - _AgendaTimeline.inicioHora) * _AgendaTimeline.alturaHora +
                                    _AgendaTimeline.alturaHora / 2,
                                left: 12, right: 8, height: 1,
                                child: Container(color: Colors.grey.shade200),
                              ),
                          ],
                          // Indicador hora actual
                          _buildHoraActual(),
                          // Bloques de citas con columnas
                          for (final citaInfo in citasConColumna) 
                            _buildCitaBlock(citaInfo['cita'] as Cita, citaInfo['columna'] as int, citaInfo['totalColumnas'] as int, anchoDisponible),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  // Calcular columnas para citas que se solapan
  List<Map<String, dynamic>> _calcularColumnasParaCitas(List<Cita> citas) {
    if (citas.isEmpty) return [];
    
    // Ordenar citas por hora de inicio
    final citasOrdenadas = List<Cita>.from(citas)..sort((a, b) {
      final aInicio = _getMinutosDesdeInicio(a);
      final bInicio = _getMinutosDesdeInicio(b);
      return aInicio.compareTo(bInicio);
    });
    
    final resultado = <Map<String, dynamic>>[];
    final grupos = <List<Cita>>[];
    
    // Agrupar citas que se solapan
    for (final cita in citasOrdenadas) {
      bool agregado = false;
      
      for (final grupo in grupos) {
        // Verificar si solapa con alguna cita del grupo
        bool solapa = false;
        for (final citaGrupo in grupo) {
          if (_seSolapan(cita, citaGrupo)) {
            solapa = true;
            break;
          }
        }
        
        if (solapa) {
          grupo.add(cita);
          agregado = true;
          break;
        }
      }
      
      if (!agregado) {
        grupos.add([cita]);
      }
    }
    
    // Asignar columnas a cada cita
    for (final grupo in grupos) {
      for (int i = 0; i < grupo.length; i++) {
        resultado.add({
          'cita': grupo[i],
          'columna': i,
          'totalColumnas': grupo.length,
        });
      }
    }
    
    return resultado;
  }
  
  int _getMinutosDesdeInicio(Cita cita) {
    final parts = cita.horaInicio.split(':');
    final h = int.tryParse(parts[0]) ?? _AgendaTimeline.inicioHora;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return (h - _AgendaTimeline.inicioHora) * 60 + m;
  }
  
  bool _seSolapan(Cita a, Cita b) {
    final aInicio = _getMinutosDesdeInicio(a);
    final aFin = aInicio + a.duracionMinutos;
    final bInicio = _getMinutosDesdeInicio(b);
    final bFin = bInicio + b.duracionMinutos;
    
    return (aInicio < bFin) && (bInicio < aFin);
  }

  Widget _buildHoraActual() {
    final ahora = DateTime.now();
    final minDesdeInicio = (ahora.hour - _AgendaTimeline.inicioHora) * 60 + ahora.minute;
    if (ahora.hour < _AgendaTimeline.inicioHora || ahora.hour > _AgendaTimeline.finHora) {
      return const SizedBox.shrink();
    }
    final top = minDesdeInicio * (_AgendaTimeline.alturaHora / 60);
    return Positioned(
      top: top, left: 0, right: 8,
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
        ),
        Expanded(child: Container(height: 1.5, color: Colors.red.withValues(alpha: 0.6))),
      ]),
    );
  }

  Widget _buildCitaBlock(Cita cita, int columna, int totalColumnas, double anchoDisponible) {
    final parts = cita.horaInicio.split(':');
    final h = int.tryParse(parts[0]) ?? _AgendaTimeline.inicioHora;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final minDesdeInicio = (h - _AgendaTimeline.inicioHora) * 60 + m;
    final top = minDesdeInicio * (_AgendaTimeline.alturaHora / 60);
    final height = (cita.duracionMinutos * (_AgendaTimeline.alturaHora / 60))
        .clamp(20.0, double.infinity);

    final servicioNombre = cita.servicios.isNotEmpty
        ? cita.servicios.map((s) => s['nombre'] as String? ?? '').join(', ')
        : cita.servicioNombre.isNotEmpty
            ? cita.servicioNombre
            : 'Servicio';

    // Calcular posición y ancho basado en columnas
    final anchoPorColumna = (anchoDisponible - 12) / totalColumnas; // -12 para margen derecho
    final left = 2 + (columna * anchoPorColumna);
    final width = anchoPorColumna - 4; // -4 para espacio entre columnas

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => widget.onTapCita(cita),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: widget.profColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: widget.profColor.withValues(alpha: 0.35),
                blurRadius: 3, offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    cita.clienteNombre,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                _EstadoBadge(estado: cita.estado),
              ]),
              const SizedBox(height: 1),
              Text(
                '${cita.horaInicio} – ${cita.horaFinStr}  ·  $servicioNombre',
                style: const TextStyle(fontSize: 8, color: Colors.white70),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (height > 40 && totalColumnas < 2 && cita.nota != null && cita.nota!.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  cita.nota!,
                  style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white60,
                      fontStyle: FontStyle.italic),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    switch (estado) {
      case 'completada':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        label = 'OK';
        break;
      case 'enCurso':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        label = 'En curso';
        break;
      case 'cancelada':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'X';
        break;
      case 'noPresento':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = 'No';
        break;
      default:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        label = '·';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reducido padding
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)), // Reducido radio
      child: Text(label,
          style: TextStyle(
              fontSize: 7.5, // Reducido fuente
              color: fg,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO NUEVA CITA
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoNuevaCita extends StatefulWidget {
  final String empresaId;
  final String fecha;
  final String? profIdInicial;
  final bool esAdmin;

  const _DialogoNuevaCita({
    required this.empresaId,
    required this.fecha,
    this.profIdInicial,
    this.esAdmin = true,
  });

  @override
  State<_DialogoNuevaCita> createState() => _DialogoNuevaCitaState();
}

class _DialogoNuevaCitaState extends State<_DialogoNuevaCita> {
  final _clienteCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  String? _profId;
  String _horaInicio = '09:00';
  int _duracion = 30;
  final List<Map<String, dynamic>> _servicios = [];
  bool _guardando = false;

  // Profesionales fusionados
  List<Profesional> _profesionales = [];
  StreamSubscription<QuerySnapshot>? _subProfs;
  StreamSubscription<QuerySnapshot>? _subEmpleados;
  List<Profesional> _listaProfs = [];
  List<Profesional> _listaEmpleados = [];

  @override
  void initState() {
    super.initState();
    // Si venimos de la vista "Todos", no pre-seleccionar ningún profesional
    _profId = (widget.profIdInicial == null || widget.profIdInicial == '__todos__')
        ? null
        : widget.profIdInicial;
    _suscribirProfesionales();
  }

  void _suscribirProfesionales() {
    _subProfs = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('profesionales')
        .snapshots()
        .listen((snap) {
      _listaProfs = snap.docs
          .where((d) => (d.data() as Map<String, dynamic>)['activo'] != false)
          .map(Profesional.fromDoc)
          .toList();
      _fusionar();
    }, onError: (_) => _fusionar());

    // Misma fuente que _FilaProfesionales para que los IDs coincidan
    _subEmpleados = FirebaseFirestore.instance
        .collection('usuarios')
        .where('empresa_id', isEqualTo: widget.empresaId)
        .snapshots()
        .listen((snap) {
      _listaEmpleados = snap.docs
          .where((d) => (d.data() as Map<String, dynamic>)['activo'] != false)
          .map(Profesional.fromEmpleado)
          .toList();
      _fusionar();
    }, onError: (_) {
      // fallback a subcollección empleados
      _subEmpleados?.cancel();
      _subEmpleados = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('empleados')
          .snapshots()
          .listen((snap) {
        _listaEmpleados = snap.docs
            .where((d) => (d.data() as Map<String, dynamic>)['activo'] != false)
            .map(Profesional.fromEmpleado)
            .toList();
        _fusionar();
      }, onError: (_) => _fusionar());
    });
  }

  void _fusionar() {
    final idsProfs = _listaProfs.map((p) => p.id).toSet();
    final merged = [
      ..._listaProfs,
      ..._listaEmpleados.where((e) => !idsProfs.contains(e.id)),
    ];
    Future.delayed(Duration.zero, () {
      if (mounted) setState(() => _profesionales = merged);
    });
  }

  @override
  void dispose() {
    _subProfs?.cancel();
    _subEmpleados?.cancel();
    _clienteCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  double get _importeTotal => _servicios.fold(
      0.0,
          (s, e) => s + ((e['precio'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    final slots = generarSlots();

    return AlertDialog(
      title: const Text('Nueva cita'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child:
          Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _clienteCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del cliente *',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            // Dropdown profesionales — usa lista fusionada empleados+profesionales
            if (_profesionales.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No hay profesionales activos. Añade profesionales desde la configuración.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _profesionales.any((p) => p.id == _profId) ? _profId : null,
                decoration: const InputDecoration(labelText: 'Profesional *'),
                items: _profesionales
                    .map((p) => DropdownMenuItem(
                        value: p.id, child: Text(p.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _profId = v),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _horaInicio,
                  decoration: const InputDecoration(
                      labelText: 'Hora inicio'),
                  items: slots
                      .map((s) => DropdownMenuItem(
                      value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(
                          () => _horaInicio = v ?? '09:00'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _duracion,
                  decoration: const InputDecoration(
                      labelText: 'Duración'),
                  items: [15, 30, 45, 60, 90, 120]
                      .map((d) => DropdownMenuItem(
                      value: d, child: Text('$d min')))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _duracion = v ?? 30),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Servicios',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
            ),
            const SizedBox(height: 6),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(widget.empresaId)
                  .collection('servicios')
                  .where('activo', isEqualTo: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                      height: 32,
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2)));
                }
                final servicios = snap.data!.docs.map((d) {
                  final m = d.data() as Map<String, dynamic>;
                  return {
                    'id': d.id,
                    'nombre': m['nombre'] as String? ?? '',
                    'precio':
                    (m['precio'] as num?)?.toDouble() ?? 0.0,
                  };
                }).toList();

                if (servicios.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border:
                      Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Sin servicios configurados. Añade servicios desde el catálogo del panel derecho.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  );
                }

                return Container(
                  constraints:
                  const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    border:
                    Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding:
                    const EdgeInsets.symmetric(vertical: 4),
                    children: servicios.map((s) {
                      final seleccionado = _servicios
                          .any((e) => e['id'] == s['id']);
                      return CheckboxListTile(
                        dense: true,
                        value: seleccionado,
                        activeColor: kPelPrimario,
                        title: Text(s['nombre'] as String,
                            style:
                            const TextStyle(fontSize: 12)),
                        secondary: Text(
                          NumberFormat.currency(
                              symbol: '€', decimalDigits: 2)
                              .format(s['precio']),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600),
                        ),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _servicios.add(
                                  Map<String, dynamic>.from(s));
                            } else {
                              _servicios.removeWhere(
                                  (e) => e['id'] == s['id']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            if (_servicios.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Total: ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    Text(
                      NumberFormat.currency(
                          symbol: '€', decimalDigits: 2)
                          .format(_importeTotal),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kPelPrimario),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _notaCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Alergias, preferencias…',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_guardando ||
              _clienteCtrl.text.trim().isEmpty ||
              _profId == null ||
              _profId == '__todos__')
              ? null
              : _guardar,
          style: FilledButton.styleFrom(backgroundColor: kPelPrimario),
          child: _guardando
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Text('Guardar cita'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      // Nombre del servicio para mostrar
      final servicioNombre = _servicios.isNotEmpty
          ? _servicios.map((s) => s['nombre']).join(', ')
          : 'Servicio';

      // Calcular precio total
      final precioTotal = _servicios.fold<double>(
          0.0, (sum, s) => sum + ((s['precio'] as num?)?.toDouble() ?? 0.0));

      // ✅ SOLO escribir en reservas/ (colección unificada)
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('reservas')
          .add({
        // ── Campos comunes ──────────────────────────────────────────────
        'cliente_nombre': _clienteCtrl.text.trim(),
        'cliente_telefono': null,
        'fecha': widget.fecha, // yyyy-MM-dd
        'hora_inicio': _horaInicio, // HH:mm String
        'duracion_minutos': _duracion,
        'estado': 'pendiente',
        'origen': 'tpv_peluqueria',
        'precio': precioTotal,
        'notas': _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
        'fecha_creacion': FieldValue.serverTimestamp(),

        // ── Campos unificados (prof_id y profesional_id para compatibilidad) ──
        'prof_id': _profId,
        'profesional_id': _profId,

        // ── Servicios y nombre_servicio ────────────────────────────────────
        'servicios': _servicios,
        'servicio_nombre': servicioNombre,

        // ── Campos del TPV peluquería ────────────────────────────────────────
        'recordatorio_enviado': false,
        'recordatorio_cliente_enviado': false,
        'es_walkin': false,
      });

      if (mounted) {
        // Encontrar el índice del profesional en la lista para el color
        final profIdx = _profesionales.indexWhere((p) => p.id == _profId);
        
        // Devolver el profId y su índice para cambiar la vista
        Navigator.pop(context, {
          'profId': _profId,
          'profIdx': profIdx >= 0 ? profIdx : 0,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO DETALLE CITA — CORREGIDO (horaFin y nota)
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoDetalleCita extends StatelessWidget {
  final Cita cita;
  final String empresaId;
  final ValueChanged<Cita> onCompletada;

  const _DialogoDetalleCita({
    required this.cita,
    required this.empresaId,
    required this.onCompletada,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return AlertDialog(
      title: Text(cita.clienteNombre),
      content: SizedBox(
        width: 340,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CORREGIDO: usa horaInicio (String) y horaFinStr (getter derivado)
              _fila('Hora',
                  '${cita.horaInicio} → ${cita.horaFinStr}'),
              _fila('Duración', '${cita.duracionMinutos} min'),
              if (cita.servicios.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Servicios:',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                ...cita.servicios.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 2),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s['nombre'] as String? ?? '',
                          style:
                          const TextStyle(fontSize: 12)),
                      Text(
                        fmt.format(
                            (s['precio'] as num?)?.toDouble() ??
                                0),
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )),
                const Divider(),
                _fila('Total', fmt.format(cita.importe)),
              ],
              // CORREGIDO: cita.nota (no cita.notas)
              if (cita.nota != null && cita.nota!.isNotEmpty)
                _fila('Nota', cita.nota!),
              const SizedBox(height: 8),
              _EstadoBadge(estado: cita.estado),
            ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        if (cita.estado == 'pendiente') ...[
          OutlinedButton(
            onPressed: () async {
              await _cambiarEstado(context, 'noPresento');
            },
            child: const Text('No vino'),
          ),
          FilledButton(
            onPressed: () async {
              await _cambiarEstado(context, 'enCurso');
            },
            style: FilledButton.styleFrom(
                backgroundColor: kPelPrimario),
            child: const Text('Iniciar'),
          ),
        ],
        if (cita.estado == 'enCurso')
          FilledButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .collection('reservas')
                  .doc(cita.id)
                  .update({'estado': 'completada'});
              if (context.mounted) {
                Navigator.pop(context);
                onCompletada(cita);
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.green),
            child: const Text('Completar → Cobrar'),
          ),
      ],
    );
  }

  Future<void> _cambiarEstado(
      BuildContext context, String estado) async {
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('reservas')
        .doc(cita.id)
        .update({'estado': estado});

    // ✅ Ya no necesitamos sincronizar con reserva vinculada,
    // porque ahora TODO está en reservas/

    if (context.mounted) Navigator.pop(context);
  }

  Widget _fila(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text('$label: ',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500)),
      Expanded(
          child: Text(valor,
              style: const TextStyle(fontSize: 12))),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// WALK-IN TAB — CORREGIDO (sin .orderBy, ordena en memoria)
// ═══════════════════════════════════════════════════════════════════════════

class _WalkInTab extends StatelessWidget {
  final String empresaId;
  final String fechaStr;
  final ValueChanged<TurnoWalkIn> onTurnoLlamado;

  const _WalkInTab({
    required this.empresaId,
    required this.fechaStr,
    required this.onTurnoLlamado,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Text('Cola de espera',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _mostrarNuevoTurno(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Añadir turno',
                style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: kPelPrimario,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas')
              .doc(empresaId)
              .collection('turnos_walkin')
              .where('fecha', isEqualTo: fechaStr)
              .where('asignado', isEqualTo: false)
          // CORREGIDO: sin .orderBy para evitar índice compuesto
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2));
            }
            // CORREGIDO: ordenar en memoria
            final turnos = snap.data!.docs
                .map(TurnoWalkIn.fromDoc)
                .toList()
              ..sort((a, b) => a.numero.compareTo(b.numero));

            if (turnos.isEmpty) {
              return Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      const Text('Sin clientes en espera',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ]),
              );
            }
            return ListView.builder(
              padding:
              const EdgeInsets.symmetric(horizontal: 12),
              itemCount: turnos.length,
              itemBuilder: (context, idx) {
                final t = turnos[idx];
                final espera = DateTime.now()
                    .difference(t.horaLlegada)
                    .inMinutes;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: kPelPrimarioLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('${t.numero}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: kPelPrimario)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(t.clienteNombre,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            Text(
                              '${t.servicio.isEmpty ? 'Sin especificar' : t.servicio}'
                                  ' · espera $espera min',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () =>
                            _llamarTurno(context, t),
                        style: FilledButton.styleFrom(
                          backgroundColor: kPelPrimario,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        child: const Text('Llamar',
                            style: TextStyle(fontSize: 11)),
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

  Future<void> _llamarTurno(
      BuildContext context, TurnoWalkIn turno) async {
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('turnos_walkin')
        .doc(turno.id)
        .update({'asignado': true});

    onTurnoLlamado(turno);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${turno.clienteNombre} llamado — servicios cargados en el ticket'),
        backgroundColor: Colors.green.shade700,
      ));
    }
  }

  void _mostrarNuevoTurno(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _DialogoNuevoTurno(
          empresaId: empresaId, fechaStr: fechaStr),
    );
  }
}

class _DialogoNuevoTurno extends StatefulWidget {
  final String empresaId;
  final String fechaStr;
  const _DialogoNuevoTurno(
      {required this.empresaId, required this.fechaStr});

  @override
  State<_DialogoNuevoTurno> createState() =>
      _DialogoNuevoTurnoState();
}

class _DialogoNuevoTurnoState extends State<_DialogoNuevoTurno> {
  final _nombreCtrl = TextEditingController();
  final List<Map<String, dynamic>> _serviciosSeleccionados = [];
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo turno walk-in'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre del cliente',
              hintText: 'Cliente sin cita',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Servicios solicitados',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const SizedBox(height: 6),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas')
                .doc(widget.empresaId)
                .collection('servicios')
                .where('activo', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              final servicios = snap.data?.docs.map((d) {
                final m = d.data() as Map<String, dynamic>;
                return {
                  'id': d.id,
                  'nombre': m['nombre'] as String? ?? '',
                  'precio':
                  (m['precio'] as num?)?.toDouble() ??
                      0.0,
                };
              }).toList() ??
                  [];

              if (servicios.isEmpty) {
                return const Text('Sin servicios configurados',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey));
              }

              return Container(
                constraints:
                const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  border:
                  Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: servicios.map((s) {
                    final sel = _serviciosSeleccionados
                        .any((e) => e['id'] == s['id']);
                    return CheckboxListTile(
                      dense: true,
                      value: sel,
                      activeColor: kPelPrimario,
                      title: Text(s['nombre'] as String,
                          style:
                          const TextStyle(fontSize: 12)),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _serviciosSeleccionados.add(
                                Map<String, dynamic>.from(s));
                          } else {
                            _serviciosSeleccionados
                                .removeWhere(
                                    (e) => e['id'] == s['id']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(backgroundColor: kPelPrimario),
          child: const Text('Añadir a la cola'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final col = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('turnos_walkin');
    final snap =
    await col.where('fecha', isEqualTo: widget.fechaStr).get();
    final siguiente = snap.docs.length + 1;
    final servicioStr = _serviciosSeleccionados
        .map((s) => s['nombre'] as String)
        .join(', ');

    await col.add({
      'numero': siguiente,
      'cliente_nombre': _nombreCtrl.text.trim().isEmpty
          ? 'Cliente sin cita'
          : _nombreCtrl.text.trim(),
      'servicio': servicioStr,
      'servicios_seleccionados': _serviciosSeleccionados,
      'fecha': widget.fechaStr,
      'hora_llegada': Timestamp.now(),
      'asignado': false,
    });
    if (mounted) Navigator.pop(context);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CABINAS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _CabinasTab extends StatelessWidget {
  final String empresaId;
  final bool esAdmin;

  const _CabinasTab(
      {required this.empresaId, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('cabinas')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline,
                  color: Colors.orange, size: 40),
              const SizedBox(height: 8),
              Text('Error al cargar cabinas: ${snap.error}',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              if (esAdmin)
                FilledButton.icon(
                  onPressed: () => _nuevaCabina(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear primera cabina'),
                  style: FilledButton.styleFrom(
                      backgroundColor: kPelPrimario),
                ),
            ]),
          );
        }

        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.door_back_door_outlined,
                  size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              const Text('Sin cabinas configuradas',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Pulsa el botón para añadir la primera',
                  style:
                  TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              if (esAdmin)
                FilledButton.icon(
                  onPressed: () => _nuevaCabina(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Añadir cabina'),
                  style: FilledButton.styleFrom(
                      backgroundColor: kPelPrimario),
                ),
            ]),
          );
        }

        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Text('${docs.length} cabinas',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              if (esAdmin)
                TextButton.icon(
                  onPressed: () => _nuevaCabina(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nueva',
                      style: TextStyle(fontSize: 12)),
                ),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding:
              const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate:
              const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                childAspectRatio: 1.1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: docs.length,
              itemBuilder: (context, idx) {
                final doc = docs[idx];
                final data = doc.data() as Map<String, dynamic>;
                final estado =
                    data['estado'] as String? ?? 'libre';
                final libre = estado == 'libre';
                final enLimpieza = estado == 'limpieza';

                Color borderColor = Colors.grey.shade200;
                Color bgColor = Colors.white;
                Color iconColor = Colors.grey.shade400;
                Color tagBg = Colors.green.shade100;
                Color tagFg = Colors.green.shade800;
                String tagLabel = 'Libre';

                if (!libre) {
                  if (enLimpieza) {
                    borderColor =
                        Colors.orange.withValues(alpha: 0.5);
                    bgColor = Colors.orange.shade50;
                    iconColor = Colors.orange;
                    tagBg = Colors.orange.shade100;
                    tagFg = Colors.orange.shade800;
                    tagLabel = 'Limpieza';
                  } else {
                    borderColor =
                        kPelPrimario.withValues(alpha: 0.5);
                    bgColor = kPelPrimarioLight;
                    iconColor = kPelPrimario;
                    tagBg = Colors.purple.shade100;
                    tagFg = Colors.purple.shade800;
                    tagLabel = 'Ocupada';
                  }
                }

                return GestureDetector(
                  onTap: esAdmin
                      ? () => _menuCabina(
                      context, doc.id, data)
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: borderColor,
                          width: libre ? 1 : 1.5),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(Icons.spa_outlined,
                            size: 28, color: iconColor),
                        const SizedBox(height: 6),
                        Text(
                          data['nombre'] as String? ?? 'Cabina',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagBg,
                            borderRadius:
                            BorderRadius.circular(4),
                          ),
                          child: Text(tagLabel,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: tagFg)),
                        ),
                        if (data['profesional_nombre'] != null &&
                            !libre) ...[
                          const SizedBox(height: 4),
                          Text(
                            data['profesional_nombre'] as String,
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }

  void _menuCabina(BuildContext context, String docId,
      Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) =>
          Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(data['nombre'] as String? ?? 'Cabina',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: Colors.green),
              title: const Text('Marcar como libre'),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(empresaId)
                    .collection('cabinas')
                    .doc(docId)
                    .update(
                    {'estado': 'libre', 'profesional_nombre': null});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.circle, color: Colors.purple),
              title: const Text('Marcar como ocupada'),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(empresaId)
                    .collection('cabinas')
                    .doc(docId)
                    .update({'estado': 'ocupada'});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services,
                  color: Colors.orange),
              title: const Text('Pendiente de limpieza'),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(empresaId)
                    .collection('cabinas')
                    .doc(docId)
                    .update({'estado': 'limpieza'});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Eliminar cabina',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(empresaId)
                    .collection('cabinas')
                    .doc(docId)
                    .delete();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ]),
    );
  }

  void _nuevaCabina(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva cabina'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Cabina 1, Cabina VIP…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .collection('cabinas')
                  .add({
                'nombre': ctrl.text.trim(),
                'estado': 'libre',
                'profesional_nombre': null,
              });
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: kPelPrimario),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COLUMNA DERECHA — TICKET + CATÁLOGO
// ═══════════════════════════════════════════════════════════════════════════

class _ColTicket extends StatefulWidget {
  final String empresaId;
  final List<Map<String, dynamic>> lineas;
  final _TicketExtra extra;
  final ValueChanged<Map<String, dynamic>> onServicioAdded;
  final ValueChanged<int> onServicioRemoved;
  final ValueChanged<_TicketExtra> onExtraChanged;
  final VoidCallback onCobrar;
  final VoidCallback onLimpiar;

  const _ColTicket({
    required this.empresaId,
    required this.lineas,
    required this.extra,
    required this.onServicioAdded,
    required this.onServicioRemoved,
    required this.onExtraChanged,
    required this.onCobrar,
    required this.onLimpiar,
  });

  @override
  State<_ColTicket> createState() => _ColTicketState();
}

class _ColTicketState extends State<_ColTicket> {
  String _catFiltro = 'Todos';
  final _clienteCtrl = TextEditingController();

  @override
  void dispose() {
    _clienteCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => widget.lineas
      .fold(0.0, (s, l) => s + ((l['precio'] as num?)?.toDouble() ?? 0));
  double get _total =>
      (_subtotal - widget.extra.descuentoBono + widget.extra.propina)
          .clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return Column(children: [
      // ── Cliente ──────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Colors.grey.shade200))),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.person_outline,
                size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              widget.extra.nombreCliente ?? 'Sin cliente',
              style: TextStyle(
                fontSize: 12,
                color: widget.extra.nombreCliente != null
                    ? Colors.black87
                    : Colors.grey,
                fontWeight: widget.extra.nombreCliente != null
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (widget.extra.nombreCliente != null)
              GestureDetector(
                onTap: () {
                  _clienteCtrl.clear();
                  widget.onExtraChanged(
                      widget.extra.copyWith(limpiarCliente: true));
                },
                child: const Icon(Icons.close,
                    size: 14, color: Colors.grey),
              ),
          ]),
          const SizedBox(height: 6),
          _ClienteBuscador(
            empresaId: widget.empresaId,
            controller: _clienteCtrl,
            onSeleccionado: (c) {
              _clienteCtrl.text = c['nombre'] as String? ?? '';
              final bono =
              c['bono_activo'] as Map<String, dynamic>?;
              final dto =
                  (bono?['descuento_por_sesion'] as num?)
                      ?.toDouble() ??
                      0;
              widget.onExtraChanged(widget.extra.copyWith(
                nombreCliente: c['nombre'] as String?,
                clienteId: c['id'] as String?,
                descuentoBono: dto,
              ));
            },
          ),
        ]),
      ),

      // ── Catálogo ─────────────────────────────────────────────────────
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas')
              .doc(widget.empresaId)
              .collection('servicios')
              .where('activo', isEqualTo: true)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2));
            }

            var servicios = snap.data!.docs.map((d) {
              final m = d.data() as Map<String, dynamic>;
              return {
                'id': d.id,
                'nombre': m['nombre'] as String? ?? '',
                'precio':
                (m['precio'] as num?)?.toDouble() ?? 0.0,
                'categoria':
                m['categoria'] as String? ?? 'General',
              };
            }).toList();

            final cats = {
              'Todos',
              ...servicios
                  .map((s) => s['categoria'] as String)
            };

            if (_catFiltro != 'Todos') {
              servicios = servicios
                  .where((s) => s['categoria'] == _catFiltro)
                  .toList();
            }

            if (servicios.isEmpty && snap.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_cut,
                          size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      const Text('Sin servicios configurados',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      const Text(
                        'Añade servicios en Firebase:\ncolección "servicios" con\n{ nombre, precio, categoria, activo }',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ]),
              );
            }

            return Column(children: [
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: cats
                      .map((c) => Padding(
                    padding:
                    const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(c,
                          style: const TextStyle(
                              fontSize: 10)),
                      selected: _catFiltro == c,
                      onSelected: (_) => setState(
                              () => _catFiltro = c),
                      selectedColor: kPelPrimarioLight,
                      labelStyle: TextStyle(
                          color: _catFiltro == c
                              ? kPelPrimario
                              : null),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      visualDensity:
                      VisualDensity.compact,
                    ),
                  ))
                      .toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: servicios.length,
                  itemBuilder: (context, idx) {
                    final s = servicios[idx];
                    return InkWell(
                      onTap: () => widget.onServicioAdded(
                          Map<String, dynamic>.from(s)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        child: Row(children: [
                          Expanded(
                            child: Text(s['nombre'] as String,
                                style: const TextStyle(
                                    fontSize: 12)),
                          ),
                          Text(
                            fmt.format(s['precio']),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.add_circle_outline,
                              size: 18,
                              color: kPelPrimario
                                  .withValues(alpha: 0.6)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      ),

      // ── Ticket activo ─────────────────────────────────────────────
      if (widget.lineas.isNotEmpty)
        Container(
          color: Colors.grey.shade50,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              child: Row(children: [
                const Text('Ticket',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onLimpiar,
                  child: const Text('Limpiar',
                      style: TextStyle(
                          fontSize: 10, color: Colors.red)),
                ),
              ]),
            ),
            ...widget.lineas.asMap().entries.map((e) {
              final idx = e.key;
              final l = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Text(l['nombre'] as String? ?? '',
                        style: const TextStyle(fontSize: 11)),
                  ),
                  Text(
                    fmt.format(
                        (l['precio'] as num?)?.toDouble() ?? 0),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => widget.onServicioRemoved(idx),
                    child: Icon(Icons.close,
                        size: 14, color: Colors.red.shade300),
                  ),
                ]),
              );
            }),
            if (widget.extra.descuentoBono > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 2),
                child: Row(children: [
                  const Text('Bono aplicado',
                      style: TextStyle(
                          fontSize: 11, color: Colors.green)),
                  const Spacer(),
                  Text(
                      '−${fmt.format(widget.extra.descuentoBono)}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.green)),
                ]),
              ),
            if (widget.extra.propina > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 2),
                child: Row(children: [
                  const Text('Propina',
                      style: TextStyle(
                          fontSize: 11, color: Colors.blue)),
                  const Spacer(),
                  Text('+${fmt.format(widget.extra.propina)}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.blue)),
                ]),
              ),
          ]),
        ),

      // ── Footer cobro ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border:
          Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(children: [
          if (widget.lineas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Text('Propina:',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 8),
                ...[0, 1, 2, 5].map((p) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => widget.onExtraChanged(
                        widget.extra.copyWith(
                            propina: p.toDouble())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.extra.propina == p
                            ? kPelPrimarioLight
                            : Colors.grey.shade100,
                        borderRadius:
                        BorderRadius.circular(4),
                        border: Border.all(
                          color: widget.extra.propina == p
                              ? kPelPrimario
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        p == 0 ? 'Sin' : '+$p€',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.extra.propina == p
                              ? kPelPrimario
                              : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                )),
              ]),
            ),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  fmt.format(_total),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kPelPrimario),
                ),
              ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
              widget.lineas.isEmpty ? null : widget.onCobrar,
              style: FilledButton.styleFrom(
                backgroundColor: kPelPrimario,
                padding:
                const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Cobrar ${fmt.format(_total)}',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ── Buscador cliente ─────────────────────────────────────────────────────────

class _ClienteBuscador extends StatefulWidget {
  final String empresaId;
  final TextEditingController controller;
  final ValueChanged<Map<String, dynamic>> onSeleccionado;

  const _ClienteBuscador({
    required this.empresaId,
    required this.controller,
    required this.onSeleccionado,
  });

  @override
  State<_ClienteBuscador> createState() => _ClienteBuscadorState();
}

class _ClienteBuscadorState extends State<_ClienteBuscador> {
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  Timer? _debounce;

  void _onChanged(String valor) {
    _debounce?.cancel();
    if (valor.length < 2) {
      setState(() => _resultados = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _buscando = true);
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes')
          .where('nombre_lower',
          isGreaterThanOrEqualTo: valor.toLowerCase())
          .where('nombre_lower',
          isLessThan: '${valor.toLowerCase()}z')
          .limit(5)
          .get();
      if (mounted) {
        setState(() {
          _resultados = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _buscando = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: widget.controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar cliente…',
          hintStyle: const TextStyle(fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 16),
          suffixIcon: _buscando
              ? const SizedBox(
              width: 16,
              height: 16,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 12),
      ),
      if (_resultados.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: _resultados
                .map((c) => InkWell(
              onTap: () {
                widget.onSeleccionado(c);
                widget.controller.text =
                    c['nombre'] as String? ?? '';
                setState(() => _resultados = []);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        c['nombre'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 12)),
                  ),
                  if (c['bono_activo'] != null)
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius:
                        BorderRadius.circular(4),
                      ),
                      child: Text('Bono',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors
                                  .green.shade800)),
                    ),
                ]),
              ),
            ))
                .toList(),
          ),
        ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO DE PAGO
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoPago extends StatefulWidget {
  final double total;
  final double propina;
  const _DialogoPago({required this.total, required this.propina});

  @override
  State<_DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<_DialogoPago> {
  String _metodo = 'efectivo';
  final _ctrl = TextEditingController();
  double _cambio = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return AlertDialog(
      title: const Text('Método de pago'),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPelPrimarioLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              const Text('Total a cobrar',
                  style: TextStyle(
                      fontSize: 12, color: kPelPrimario)),
              Text(fmt.format(widget.total),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: kPelPrimario)),
              if (widget.propina > 0)
                Text(
                    'incl. propina ${fmt.format(widget.propina)}',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _PelChip(
              label: 'Efectivo',
              icon: Icons.payments_outlined,
              selected: _metodo == 'efectivo',
              onTap: () => setState(() => _metodo = 'efectivo'),
            ),
            const SizedBox(width: 8),
            _PelChip(
              label: 'Tarjeta',
              icon: Icons.credit_card,
              selected: _metodo == 'tarjeta',
              onTap: () => setState(() => _metodo = 'tarjeta'),
            ),
          ]),
          const SizedBox(height: 16),
          if (_metodo == 'efectivo') ...[
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: const InputDecoration(
                labelText: 'Entrega del cliente (€)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              onChanged: (v) {
                final e =
                    double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() => _cambio = (e - widget.total)
                    .clamp(0, double.infinity));
              },
            ),
            if (_cambio > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cambio',
                        style: TextStyle(
                            color: Colors.green.shade800)),
                    Text(fmt.format(_cambio),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                            fontSize: 18)),
                  ],
                ),
              ),
            ],
          ],
          if (_metodo == 'tarjeta') ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.info_outline,
                  size: 16,
                  color:
                  Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text('Cobro por datáfono',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .primary)),
            ]),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style:
          FilledButton.styleFrom(backgroundColor: kPelPrimario),
          onPressed: () => Navigator.pop(context, {
            'metodo': _metodo,
            'importe_efectivo':
            _metodo == 'efectivo' ? widget.total : 0.0,
            'importe_tarjeta':
            _metodo == 'tarjeta' ? widget.total : 0.0,
          }),
          child: const Text('Confirmar cobro'),
        ),
      ],
    );
  }
}

class _PelChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PelChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? kPelPrimarioLight
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kPelPrimario : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 20,
              color: selected ? kPelPrimario : Colors.grey),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color:
                  selected ? kPelPrimario : Colors.grey)),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// CIERRE DE CAJA
// ═══════════════════════════════════════════════════════════════════════════

class _PelCierreDeCaja extends StatefulWidget {
  final String empresaId;
  const _PelCierreDeCaja({required this.empresaId});

  @override
  State<_PelCierreDeCaja> createState() => _PelCierreDeCajaState();
}

class _PelCierreDeCajaState extends State<_PelCierreDeCaja> {
  Map<String, dynamic>? _datos;
  bool _cargando = true, _cerrando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final hoy = DateTime.now();
      final inicio = DateTime(hoy.year, hoy.month, hoy.day);
      final fin = inicio.add(const Duration(days: 1));

      // ── Pedidos del día ──
      // Filtramos estado_pago client-side para evitar índice compuesto
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('pedidos')
          .where('fecha_hora',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha_hora', isLessThan: Timestamp.fromDate(fin))
          .get();

      double ef = 0, tj = 0;
      final top = <String, int>{};
      int ticketsPagados = 0;

      for (final d in snap.docs) {
        final m = d.data();
        // Filtro client-side: solo pedidos pagados
        if (m['estado_pago'] != 'pagado') continue;
        ticketsPagados++;
        final met = m['metodo_pago'] as String? ?? 'efectivo';
        if (met == 'tarjeta') {
          tj += (m['importe_tarjeta'] as num?)?.toDouble() ??
              (m['importe_total'] as num?)?.toDouble() ?? 0;
        } else {
          ef += (m['importe_efectivo'] as num?)?.toDouble() ??
              (m['importe_total'] as num?)?.toDouble() ?? 0;
        }
        for (final l in m['lineas'] as List? ?? []) {
          final n = l['producto_nombre'] as String? ??
              l['nombre'] as String? ?? '';
          if (n.isNotEmpty) {
            top[n] = (top[n] ?? 0) + ((l['cantidad'] as num?)?.toInt() ?? 1);
          }
        }
      }

      final total = ef + tj;

      // ── Comisiones: citas completadas del día ──
      final fechaStr = DateFormat('yyyy-MM-dd').format(hoy);
      final citasSnap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('reservas')
          .where('fecha', isEqualTo: fechaStr)
          .where('estado', isEqualTo: 'completada')
          .get();

      final Map<String, double> ventasPorProf = {};
      for (final doc in citasSnap.docs) {
        final data = doc.data();
        final profId = data['prof_id'] as String? ??
            data['profesional_id'] as String? ?? '';
        if (profId.isEmpty) continue;
        final servicios = data['servicios'] as List? ?? [];
        final importe = servicios.fold(
            0.0, (sum, s) => sum + ((s['precio'] as num?)?.toDouble() ?? 0));
        ventasPorProf[profId] = (ventasPorProf[profId] ?? 0) + importe;
      }

      // ── Obtener nombres: primero profesionales, luego empleados ──
      final Map<String, Map<String, dynamic>> datosProf = {};

      // Leer colección profesionales
      try {
        final profsSnap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('profesionales')
            .get();
        for (final d in profsSnap.docs) {
          datosProf[d.id] = d.data();
        }
      } catch (_) {}

      // Leer colección empleados (fallback y complemento)
      try {
        final empSnap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('empleados')
            .get();
        for (final d in empSnap.docs) {
          if (!datosProf.containsKey(d.id)) {
            datosProf[d.id] = d.data();
          }
        }
      } catch (_) {}

      final comisiones = ventasPorProf.entries.map((e) {
        final data = datosProf[e.key] ?? {};
        final ventas = e.value;
        final pct = (data['comision_pct'] as num?)?.toDouble() ?? 0;
        final nombre = data['nombre'] as String? ??
            data['displayName'] as String? ?? e.key;
        return {
          'nombre': nombre,
          'ventas': ventas,
          'comision_pct': pct,
          'comision_importe': ventas * pct / 100,
        };
      }).where((m) => (m['ventas'] as double) > 0).toList();

      final totalComisiones = comisiones.fold(
          0.0, (sum, m) => sum + (m['comision_importe'] as double));

      if (mounted) {
        setState(() {
          _datos = {
            'total': total,
            'efectivo': ef,
            'tarjeta': tj,
            'num_tickets': ticketsPagados,
            'ticket_medio': ticketsPagados == 0 ? 0.0 : total / ticketsPagados,
            'base_imponible': total / 1.21,
            'cuota_iva': total - total / 1.21,
            'top': (top.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(3)
                .toList(),
            'comisiones': comisiones,
            'total_comisiones': totalComisiones,
          };
          _cargando = false;
        });
      }
    } catch (e) {
      // Si falla la carga, mostrar datos a cero para no bloquear la UI
      if (mounted) {
        setState(() {
          _datos = {
            'total': 0.0,
            'efectivo': 0.0,
            'tarjeta': 0.0,
            'num_tickets': 0,
            'ticket_medio': 0.0,
            'base_imponible': 0.0,
            'cuota_iva': 0.0,
            'top': <MapEntry<String, int>>[],
            'comisiones': <Map<String, dynamic>>[],
            'total_comisiones': 0.0,
          };
          _cargando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _cerrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar cierre'),
        content: const Text('¿Registrar el cierre del día?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cerrando = true);
    try {
      final svc = CierreCajaService();
      final cierre = await svc.calcularCierreCaja(
          widget.empresaId, DateTime.now());
      await svc.guardarCierreCaja(widget.empresaId, cierre);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cierre registrado'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  String get _hoy {
    final h = DateTime.now();
    return '${h.day.toString().padLeft(2, '0')}/${h.month.toString().padLeft(2, '0')}/${h.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final d = _datos!;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final cs = Theme.of(context).colorScheme;

    return Column(children: [
      Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Flexible(
            child: Text('Cierre — $_hoy',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _zPdf,
            icon: const Icon(Icons.download_outlined, size: 14),
            label: const Text('Z-PDF',
                style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: _cerrando ? null : _cerrar,
            style: FilledButton.styleFrom(
              backgroundColor: kPelPrimario,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            child: _cerrando
                ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Text('Cerrar caja',
                style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Actualizar',
                style: TextStyle(fontSize: 11)),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            _cifra('Total ventas', fmt.format(d['total']),
                color: kPelPrimario),
            _cifra('Tickets', '${d['num_tickets']}'),
            _cifra('Ticket medio',
                fmt.format(d['ticket_medio'])),
            _tarjeta('Método de pago', [
              _fila('Efectivo', fmt.format(d['efectivo'])),
              const SizedBox(height: 4),
              _fila('Tarjeta', fmt.format(d['tarjeta'])),
            ]),
            _tarjeta('IVA (21%)', [
              _fila('Base imponible',
                  fmt.format(d['base_imponible'])),
              const SizedBox(height: 4),
              _fila('Cuota IVA', fmt.format(d['cuota_iva'])),
            ]),
            _tarjeta('Top servicios', [
              ...(d['top'] as List).asMap().entries.map((e) {
                final entry = e.value as MapEntry<String, int>;
                return Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Text('${e.key + 1}.',
                        style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(entry.key,
                            style: const TextStyle(
                                fontSize: 12))),
                    Text('×${entry.value}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12)),
                  ]),
                );
              }),
            ]),
            if ((d['comisiones'] as List? ?? []).isNotEmpty)
              _tarjeta('Comisiones del día', [
                ...(d['comisiones'] as List).map((m) => Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4),
                  child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                  m['nombre'] as String,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                      FontWeight.w600))),
                          Text(
                              '${(m['comision_pct'] as double).toInt()}%',
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                  Colors.grey.shade600)),
                        ]),
                        const SizedBox(height: 2),
                        Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  'Ventas: ${fmt.format(m['ventas'])}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                      Colors.grey.shade600)),
                              Text(
                                  fmt.format(
                                      m['comision_importe']),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kPelPrimario)),
                            ]),
                        const Divider(height: 12),
                      ]),
                )),
                Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total comisiones:',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text(
                          fmt.format(d['total_comisiones']),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kPelPrimario)),
                    ]),
              ]),
          ]),
        ),
      ),
    ]);
  }

  Widget _cifra(String label, String valor, {Color? color}) =>
      SizedBox(
        width: 150,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ]),
        ),
      );

  Widget _tarjeta(String titulo, List<Widget> children) =>
      SizedBox(
        width: 200,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant,
                width: 0.5),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                ...children,
              ]),
        ),
      );

  Widget _fila(String label, String valor) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant)),
      Text(valor,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500)),
    ],
  );

  Future<void> _zPdf() async {
    if (_datos == null) return;
    final d = _datos!;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
              child: pw.Text('Z-REPORT — CIERRE PELUQUERÍA',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold))),
          pw.Center(
              child: pw.Text('Fecha: $_hoy',
                  style: pw.TextStyle(
                      fontSize: 13,
                      color: PdfColors.grey600))),
          pw.SizedBox(height: 20),
          pw.Divider(),
          _pRow('Total ventas', fmt.format(d['total'])),
          _pRow('Tickets', '${d['num_tickets']}'),
          _pRow('Ticket medio', fmt.format(d['ticket_medio'])),
          pw.SizedBox(height: 10),
          _pRow('Efectivo', fmt.format(d['efectivo'])),
          _pRow('Tarjeta', fmt.format(d['tarjeta'])),
          pw.SizedBox(height: 10),
          _pRow('Base imponible',
              fmt.format(d['base_imponible'])),
          _pRow(
              'Cuota IVA (21%)', fmt.format(d['cuota_iva'])),
          pw.SizedBox(height: 10),
          pw.Text('Top servicios',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold)),
          ...(d['top'] as List).asMap().entries.map((e) {
            final entry = e.value as MapEntry<String, int>;
            return _pRow(
                '${e.key + 1}. ${entry.key}', '×${entry.value}');
          }),
          if ((d['comisiones'] as List? ?? []).isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('COMISIONES DEL DÍA',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13)),
            pw.SizedBox(height: 6),
            ...(d['comisiones'] as List).map((m) => pw.Row(
              mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    '${m['nombre']} (${(m['comision_pct'] as double).toInt()}%)'),
                pw.Text(
                    fmt.format(m['comision_importe'])),
              ],
            )),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total comisiones',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    fmt.format(d['total_comisiones']),
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  pw.Widget _pRow(String l, String v) =>
      pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text(l), pw.Text(v)]);
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO: APERTURA DE CAJA
// ═════════════════════════════════════════════════════════════════════════════

class _DialogoAperturaCaja extends StatefulWidget {
  final String empresaId;
  const _DialogoAperturaCaja({required this.empresaId});

  @override
  State<_DialogoAperturaCaja> createState() => _DialogoAperturaCajaState();
}

class _DialogoAperturaCajaState extends State<_DialogoAperturaCaja> {
  final _montoCtrl = TextEditingController(text: '0.00');
  bool _guardando = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarApertura() async {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    setState(() => _guardando = true);

    try {
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('cierres_caja')
          .doc(hoy)
          .set({
        'fecha': hoy,
        'apertura': {
          'fecha_hora': FieldValue.serverTimestamp(),
          'monto_inicial': monto,
          'usuario': FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario',
        },
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Apertura de caja registrada'),
          backgroundColor: Color(0xFF4CAF50),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPelPrimario.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance_wallet, color: kPelPrimario, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Apertura de caja', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Registra el monto inicial en caja para el día de hoy',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto inicial (€)',
              prefixIcon: Icon(Icons.euro),
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _guardarApertura(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardarApertura,
          style: FilledButton.styleFrom(backgroundColor: kPelPrimario),
          child: _guardando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO REGLAS DE COLOR
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoReglasColor extends StatefulWidget {
  final String empresaId;
  const _DialogoReglasColor({required this.empresaId});

  @override
  State<_DialogoReglasColor> createState() => _DialogoReglasColorState();
}

class _DialogoReglasColorState extends State<_DialogoReglasColor> {
  static const _paleta = [
    Color(0xFF9C27B0), Color(0xFF2196F3), Color(0xFF4CAF50),
    Color(0xFFF44336), Color(0xFFFF9800), Color(0xFF00BCD4),
    Color(0xFFE91E63), Color(0xFF795548), Color(0xFF607D8B),
    Color(0xFF8BC34A), Color(0xFFFFEB3B), Color(0xFF673AB7),
  ];

  static const _estados = ['pendiente', 'confirmada', 'enCurso', 'completada', 'cancelada'];

  List<Map<String, dynamic>> _reglas = [];
  List<Map<String, dynamic>> _servicios = [];
  List<Profesional> _profesionales = [];
  bool _cargando = true;
  String _tipo = 'servicio';
  String? _valorSel;
  Color _colorSel = _paleta[0];

  late final DocumentReference _docRef;

  @override
  void initState() {
    super.initState();
    _docRef = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('config')
        .doc('color_rules_tpv');
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final results = await Future.wait([
        _docRef.get(),
        FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('servicios')
            .where('activo', isEqualTo: true)
            .get(),
        FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('profesionales')
            .get(),
        FirebaseFirestore.instance
            .collection('usuarios')
            .where('empresa_id', isEqualTo: widget.empresaId)
            .get(),
      ]);

      final rulesSnap = results[0] as DocumentSnapshot;
      final serviciosSnap = results[1] as QuerySnapshot;
      final profsSnap = results[2] as QuerySnapshot;
      final usuariosSnap = results[3] as QuerySnapshot;

      final reglas = (rulesSnap.data() as Map<String, dynamic>?)?['reglas'] as List? ?? [];
      final servicios = serviciosSnap.docs
          .map((d) => {'id': d.id, 'nombre': (d.data() as Map)['nombre'] as String? ?? d.id})
          .toList();

      final listaProfs = profsSnap.docs.map(Profesional.fromDoc).toList();
      final idsProfs = listaProfs.map((p) => p.id).toSet();
      final listaUsuarios = usuariosSnap.docs
          .where((d) => (d.data() as Map<String, dynamic>)['activo'] != false)
          .map(Profesional.fromEmpleado)
          .toList();
      final profesionales = [
        ...listaProfs,
        ...listaUsuarios.where((e) => !idsProfs.contains(e.id)),
      ];

      if (mounted) {
        setState(() {
          _reglas = reglas.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _servicios = servicios.cast<Map<String, dynamic>>();
          _profesionales = profesionales;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    try {
      await _docRef.set({'reglas': _reglas}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _agregarRegla() async {
    final valor = _valorSel;
    if (valor == null || valor.isEmpty) return;
    setState(() {
      _reglas.add({'tipo': _tipo, 'valor': valor, 'color': _colorSel.toARGB32()});
      _valorSel = null;
    });
    await _guardar();
  }

  Future<void> _eliminarRegla(int idx) async {
    setState(() => _reglas.removeAt(idx));
    await _guardar();
  }

  List<DropdownMenuItem<String>> _opciones() {
    switch (_tipo) {
      case 'servicio':
        return _servicios
            .map((s) => DropdownMenuItem(value: s['nombre'] as String, child: Text(s['nombre'] as String)))
            .toList();
      case 'profesional':
        return _profesionales
            .map((p) => DropdownMenuItem(value: p.nombre, child: Text(p.nombre)))
            .toList();
      case 'estado':
        return _estados
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList();
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.palette_outlined, color: kPelPrimario),
        SizedBox(width: 8),
        Text('Reglas de color', style: TextStyle(fontSize: 16)),
      ]),
      content: SizedBox(
        width: 440,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_reglas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Sin reglas. Las citas usarán el color del profesional.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _reglas.length,
                        itemBuilder: (_, i) {
                          final r = _reglas[i];
                          final c = Color((r['color'] as int?) ?? 0xFF9C27B0);
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                            ),
                            title: Text('${r['tipo']}: ${r['valor']}',
                                style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              onPressed: () => _eliminarRegla(i),
                              color: Colors.red.shade300,
                            ),
                          );
                        },
                      ),
                    ),
                  const Divider(),
                  const Text('Nueva regla',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    DropdownButton<String>(
                      value: _tipo,
                      items: const [
                        DropdownMenuItem(value: 'servicio',    child: Text('Servicio')),
                        DropdownMenuItem(value: 'profesional', child: Text('Profesional')),
                        DropdownMenuItem(value: 'estado',      child: Text('Estado')),
                      ],
                      onChanged: (v) => setState(() { _tipo = v!; _valorSel = null; }),
                      isDense: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _valorSel,
                        decoration: InputDecoration(
                          hintText: _tipo == 'servicio'
                              ? 'Selecciona servicio'
                              : _tipo == 'profesional'
                                  ? 'Selecciona profesional'
                                  : 'Selecciona estado',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        items: _opciones(),
                        onChanged: (v) => setState(() => _valorSel = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _paleta.map((c) => GestureDetector(
                      onTap: () => setState(() => _colorSel = c),
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: _colorSel == c
                              ? Border.all(color: Colors.white, width: 2.5)
                              : Border.all(color: Colors.grey.shade300),
                          boxShadow: _colorSel == c
                              ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)]
                              : null,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Agregar'),
          onPressed: _valorSel != null ? _agregarRegla : null,
        ),
      ],
    );
  }
}











