// TPV Peluquería - Vista Agenda Profesional con Timeline
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../../core/widgets/flux_toast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/actividad_cliente_service.dart';
import '../../../domain/modelos/actividad_cliente.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/firebase/firestore_stream_helper.dart';
import '../../../core/platform/platform_data_source.dart';
import '../widgets/tpv_type_switcher.dart';
import '../widgets/dialogo_factura_tpv.dart';
import '../../facturacion/pantallas/detalle_factura_screen.dart';
import '../../../domain/modelos/factura.dart';
import 'tpv_tienda_screen.dart';
import 'configuracion_facturacion_tpv_screen.dart';
import '../../../services/pedidos_service.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../../../services/tpv/impresora_service.dart';
import '../../../services/cierre_caja_service.dart';
import '../../../services/verifactu/qr_service.dart';
import '../../../services/tpv/tpv_document_renderer.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../../widgets/tpv/historial_tickets_widget.dart';
import '../../../widgets/tpv/hold_pedidos_widget.dart';
import '../../../widgets/tpv/estadisticas_turno_widget.dart';
import '../../../widgets/tpv/arqueo_caja_widget.dart';
import '../../../widgets/tpv/descuento_linea_widget.dart';
import '../../../widgets/tpv/cupon_input_widget.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TEMA DINÁMICO — InheritedWidget para propagar colores a todos los hijos
// ═══════════════════════════════════════════════════════════════════════════

class _TpvTema {
  final Color primario;
  final Color secundario;
  final Color fondo;
  final Color superficie;
  final Color texto;

  const _TpvTema({
    required this.primario,
    required this.secundario,
    required this.fondo,
    required this.superficie,
    required this.texto,
  });

  bool get esOscuro => fondo.computeLuminance() < 0.3;
  Color get textoPrimario => esOscuro ? Colors.white : texto;
  Color get textoSecundario => textoPrimario.withValues(alpha: 0.6);
  Color get divisor => textoPrimario.withValues(alpha: 0.1);
}

class _TpvTemaScope extends InheritedWidget {
  final _TpvTema tema;

  const _TpvTemaScope({required this.tema, required super.child});

  static _TpvTema of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TpvTemaScope>()!.tema;

  /// Versión segura: si no hay scope (ej: diálogos), devuelve kPelPrimario como fallback.
  static Color primarioOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TpvTemaScope>()?.tema.primario
      ?? kPelPrimario;

  @override
  bool updateShouldNotify(_TpvTemaScope old) =>
      tema.primario != old.tema.primario ||
      tema.fondo != old.tema.fondo;
}

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

const Color kPelPrimario = Color(0xFF374151); // Slate Neutro
const Color kPelPrimarioLight = Color(0xFFF3F4F6);

// Paleta legacy (ya no se usa para avatares)
const List<Color> kProfColors = [
  Color(0xFF00FFC8), Color(0xFFFF3296), Color(0xFFFF4678),
  Color(0xFF00D9FF), Color(0xFFFFB84D), Color(0xFF4CAF50),
  Color(0xFF9C27B0), Color(0xFF2196F3),
];

Color profColor(int idx) => kProfColors[idx % kProfColors.length];

/// 15 colores planos y reconocibles para avatares de profesionales.
const List<Color> _kProfPaleta = [
  Color(0xFFE53935), // Rojo
  Color(0xFFF4511E), // Naranja
  Color(0xFFEFA00F), // Ámbar
  Color(0xFF33A852), // Verde
  Color(0xFF009688), // Teal
  Color(0xFF1A73E8), // Azul
  Color(0xFF8835AB), // Morado
  Color(0xFFE91E63), // Rosa
  Color(0xFF00ACC1), // Cian
  Color(0xFF7CB342), // Verde lima
  Color(0xFF6D4C41), // Marrón
  Color(0xFF546E7A), // Gris azulado
  Color(0xFFD81B60), // Fucsia
  Color(0xFF3949AB), // Índigo
  Color(0xFF00897B), // Verde agua
];

Color profColorTema(int idx, Color primario) =>
    _kProfPaleta[idx % _kProfPaleta.length];

/// Color fijo por ID de profesional — no cambia aunque se reordene la lista.
Color profColorPorId(String profId) {
  final hash = profId.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7FFFFFFF);
  return _kProfPaleta[hash % _kProfPaleta.length];
}

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
  final double descuento;
  final String? nombreCliente;
  final String? clienteId;

  const _TicketExtra({
    this.propina = 0,
    this.descuentoBono = 0,
    this.descuento = 0,
    this.nombreCliente,
    this.clienteId,
  });

  _TicketExtra copyWith({
    double? propina,
    double? descuentoBono,
    double? descuento,
    String? nombreCliente,
    String? clienteId,
    bool limpiarCliente = false,
  }) =>
      _TicketExtra(
        propina: propina ?? this.propina,
        descuentoBono: descuentoBono ?? this.descuentoBono,
        descuento: descuento ?? this.descuento,
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

  // ── Pedidos en espera ─────────────────────────────────────────────────────
  final _holdNotifier = HoldPedidosNotifier();

  Timer? _relojTimer;
  String _hora = '';
  bool _estaOnline = true;
  bool _btConectado = false;
  bool _mostrandoCierre = false;
  StreamSubscription<List<ConnectivityResult>>? _connectSub;

  // ── Configuración fiscal ──────────────────────────────────────────────────
  bool _preciosConIva = false;
  int  _descuentoMaxPct = 100;
  bool _mostrarPropina = true;

  // ── Tema predeterminado = Slate Neutro (si el usuario no ha elegido otro) ──
  Color _colorPrimario    = const Color(0xFF374151);
  Color _colorSecundario  = const Color(0xFF6B7280);
  Color _colorFondo       = const Color(0xFFF9FAFB);
  Color _colorSuperficie  = const Color(0xFFF3F4F6);
  Color _colorTexto       = const Color(0xFF111827);

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
      final online = !r.contains(ConnectivityResult.none);
      if (mounted) setState(() => _estaOnline = online);
      // Al reconectar, precargar para refrescar caché
      if (online) _prefetchParaOffline();
    });
    // Precargar al abrir si hay conexión
    _prefetchParaOffline();
    // Cargar configuración fiscal
    TpvFacturacionService().obtenerConfig(widget.empresaId).then((c) {
      if (mounted) setState(() {
        _preciosConIva    = c.preciosIncluyenIva;
        _descuentoMaxPct  = c.descuentoMaximoPct;
        _mostrarPropina   = c.mostrarPropina;
      });
    }).catchError((_) {});
    ImpressoraBluetooth()
        .estaConectada()
        .then((v) {
      if (mounted) setState(() => _btConectado = v);
    });
    _cargarTema();
  }

  Future<void> _cargarTema() async {
    // 1. Cargar desde SharedPreferences (instantáneo, sin flicker)
    try {
      final prefs = await SharedPreferences.getInstance();
      final pKey = 'tpv_tema_${widget.empresaId}';
      final cached = prefs.getString(pKey);
      if (cached != null && mounted) {
        final parts = cached.split(',');
        if (parts.length == 5) {
          setState(() {
            _colorPrimario   = Color(int.parse(parts[0]));
            _colorSecundario = Color(int.parse(parts[1]));
            _colorFondo      = Color(int.parse(parts[2]));
            _colorSuperficie = Color(int.parse(parts[3]));
            _colorTexto      = Color(int.parse(parts[4]));
          });
        }
      }
    } catch (_) {}

    // 2. Sincronizar con Firestore en background
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('configuracion')
          .doc('peluqueria_tema')
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      Color? c(String key) => data[key] is int ? Color(data[key] as int) : null;
      setState(() {
        _colorPrimario   = c('primario')   ?? _colorPrimario;
        _colorSecundario = c('secundario') ?? _colorSecundario;
        _colorFondo      = c('fondo')      ?? _colorFondo;
        _colorSuperficie = c('superficie') ?? _colorSuperficie;
        _colorTexto      = c('texto')      ?? _colorTexto;
      });
    } catch (_) {}
  }

  Future<void> _guardarTema() async {
    // Caché local instantánea
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tpv_tema_${widget.empresaId}',
          '${_colorPrimario.value},${_colorSecundario.value},${_colorFondo.value},${_colorSuperficie.value},${_colorTexto.value}');
    } catch (_) {}
    // Persistencia en Firestore
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('configuracion')
          .doc('peluqueria_tema')
          .set({
        'primario':   _colorPrimario.value,
        'secundario': _colorSecundario.value,
        'fondo':      _colorFondo.value,
        'superficie': _colorSuperficie.value,
        'texto':      _colorTexto.value,
        'actualizado': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    // fin _guardarTema
  }

  // ── Precarga de datos para funcionar offline ──────────────────────────────

  /// Lee las colecciones clave para asegurar que Firestore las guarda en caché.
  /// Se llama al abrir y al reconectar. Si falla (sin conexión), no importa.
  Future<void> _prefetchParaOffline() async {
    if (!_estaOnline) return;
    try {
      final db  = FirebaseFirestore.instance;
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // Prefetch en paralelo: catálogo, citas de hoy, empleados
      await Future.wait([
        db.collection('empresas').doc(widget.empresaId)
            .collection('servicios').where('activo', isEqualTo: true).get(),
        db.collection('empresas').doc(widget.empresaId)
            .collection('citas').where('fecha', isEqualTo: hoy).get(),
        db.collection('empresas').doc(widget.empresaId)
            .collection('empleados').where('activo', isEqualTo: true).get(),
        db.collection('empresas').doc(widget.empresaId)
            .collection('catalogo').where('activo', isEqualTo: true).get(),
      ], eagerError: false);
      debugPrint('✅ TPV: datos precargados para offline (${DateTime.now().hour}h)');
    } catch (_) {
      // Silencioso — si falla ya hay caché previa
    }
  }

  /// Obtiene el próximo número de ticket.
  /// Intenta Firestore primero; si falla (offline), usa SharedPreferences.
  Future<int> _obtenerNumTicket() async {
    final prefsKey = 'tpv_ultimo_ticket_${widget.empresaId}';
    final ref = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('contadores')
        .doc('tickets');

    try {
      final snap = await ref.get().timeout(const Duration(seconds: 3));
      final siguiente = snap.exists
          ? ((snap.data()?['ultimo'] as num?)?.toInt() ?? 0) + 1
          : 1;
      await ref.set({'ultimo': siguiente}, SetOptions(merge: true));
      // Guardar en SharedPreferences por si se va offline después
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefsKey, siguiente);
      return siguiente;
    } catch (_) {
      // Offline o timeout → usar contador local
      final prefs = await SharedPreferences.getInstance();
      final local  = (prefs.getInt(prefsKey) ?? 0) + 1;
      await prefs.setInt(prefsKey, local);
      debugPrint('📴 TPV offline: usando ticket local #$local');
      return local;
    }
  }

  void _abrirPersonalizacion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PanelPersonalizacion(
        primario:   _colorPrimario,
        secundario: _colorSecundario,
        fondo:      _colorFondo,
        superficie: _colorSuperficie,
        texto:      _colorTexto,
        onGuardar: (p, s, f, sup, t) {
          setState(() {
            _colorPrimario   = p;
            _colorSecundario = s;
            _colorFondo      = f;
            _colorSuperficie = sup;
            _colorTexto      = t;
          });
          _guardarTema();
        },
      ),
    );
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
    _connectSub?.cancel();
    _holdNotifier.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  String get _fechaStr => DateFormat('yyyy-MM-dd').format(_fecha);

  double get _subtotal =>
      _lineasTicket.fold(
          0.0, (s, l) => s + ((l['precio'] as num?)?.toDouble() ?? 0));

  double get _total =>
      (_subtotal - _extra.descuentoBono - _extra.descuento + _extra.propina)
          .clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    if (_mostrandoCierre) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: _CierreWrapper(
          empresaId: widget.empresaId,
          fecha: DateTime.now(),
          onVolver: () => setState(() => _mostrandoCierre = false),
        ),
      );
    }

    final tema = _TpvTema(
      primario:   _colorPrimario,
      secundario: _colorSecundario,
      fondo:      _colorFondo,
      superficie: _colorSuperficie,
      texto:      _colorTexto,
    );

    return _TpvTemaScope(
      tema: tema,
      child: Scaffold(
      backgroundColor: _colorFondo,
      appBar: _buildAppBar(),
      body: Column(children: [
        // ── Banner offline ─────────────────────────────────────────────────
        if (!_estaOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            color: const Color(0xFFFF8F00),
            child: const Row(children: [
              Icon(Icons.wifi_off, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Expanded(child: Text(
                'Sin conexión — trabajando con datos locales. Los cobros se sincronizarán al reconectar.',
                style: TextStyle(fontSize: 11, color: Colors.white,
                    fontWeight: FontWeight.w600),
              )),
            ]),
          ),
        // ── Mini-dashboard ─────────────────────────────────────────────────
        _MiniDashboard(empresaId: widget.empresaId),
        // ── Estadísticas de turno (solo admin/propietario) ──────────────────
        if (widget.esAdmin || widget.esPropietario)
          _EstadisticasTurnoColapsable(empresaId: widget.empresaId),
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
              child: ColoredBox(
                color: _colorFondo,
                child: _profIdSeleccionado == null ||
                    _profIdSeleccionado == '__todos__'
                    ? _TodosTab(
                  empresaId: widget.empresaId,
                  fechaStr: _fechaStr,
                  onCitaCompletada: _cargarCitaEnTicket,
                  onNuevaCita: _mostrarDialogoNuevaCita,
                )
                    : _AgendaTab(
                  empresaId: widget.empresaId,
                  profId: _profIdSeleccionado,
                  fechaStr: _fechaStr,
                  profColor: _profIdSeleccionado != null
                      ? profColorPorId(_profIdSeleccionado!)
                      : profColorTema(_profColorIdx, _colorPrimario),
                  onNuevaCita: _mostrarDialogoNuevaCita,
                  onCitaCompletada: _cargarCitaEnTicket,
                ),
              ),
            ),
            VerticalDivider(width: 1, color: tema.divisor),
            Expanded(
              flex: 40,
              child: ColoredBox(
                color: _colorSuperficie,
                child: _ColTicket(
                empresaId: widget.empresaId,
                lineas: _lineasTicket,
                extra: _extra,
                descuentoMaxPct: _descuentoMaxPct,
                onServicioAdded: (s) =>
                    setState(() => _lineasTicket.add(s)),
                onServicioRemoved: (i) =>
                    setState(() => _lineasTicket.removeAt(i)),
                onExtraChanged: (e) => setState(() => _extra = e),
                onCobrar: _cobrar,
                onLimpiar: _limpiarTicket,
                onEnEspera: _guardarEnEspera,
              ),
              ), // ColoredBox ticket
            ),
          ]),
        ),
      ]),
      ), // Scaffold
    ); // _TpvTemaScope
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _colorPrimario,
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
        // Orden: hora · wifi · apertura · cierre · impresora · personalizar · config
        Text(_hora, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(width: 6),
        Icon(
          _estaOnline ? Icons.wifi : Icons.wifi_off,
          size: 15,
          color: _estaOnline ? Colors.white70 : Colors.orangeAccent,
        ),
        const SizedBox(width: 4),
        // Apertura de caja — color del tema
        GestureDetector(
          onTap: () => _mostrarAperturaCaja(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _colorPrimario.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _colorPrimario.withValues(alpha: 0.6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_balance_wallet, size: 13, color: _colorSecundario),
              const SizedBox(width: 4),
              Text('Caja', style: TextStyle(fontSize: 11, color: _colorSecundario, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        // Cierre de caja — color del tema
        GestureDetector(
          onTap: () => setState(() => _mostrandoCierre = !_mostrandoCierre),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _mostrandoCierre
                  ? _colorSecundario.withValues(alpha: 0.3)
                  : _colorPrimario.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _mostrandoCierre
                    ? _colorSecundario.withValues(alpha: 0.8)
                    : _colorPrimario.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.summarize_outlined, size: 13,
                  color: _mostrandoCierre ? _colorSecundario : Colors.white70),
              const SizedBox(width: 4),
              Text('Cierre', style: TextStyle(
                  fontSize: 11,
                  color: _mostrandoCierre ? _colorSecundario : Colors.white70,
                  fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        IconButton(
          icon: Icon(Icons.print, size: 16,
              color: _btConectado ? Colors.white70 : Colors.white38),
          onPressed: () => _mostrarConfigImpresora(),
          tooltip: 'Impresora Bluetooth',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        if (widget.esAdmin || widget.esPropietario) ...[
          IconButton(
            icon: const Icon(Icons.tune, size: 16),
            onPressed: _abrirPersonalizacion,
            tooltip: 'Personalizar pantalla',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.history, size: 16),
            onPressed: () => _mostrarHistorialVentas(),
            tooltip: 'Historial de ventas',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Historial completo (HistorialTicketsWidget)
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, size: 16),
            onPressed: () => HistorialTicketsWidget.mostrar(context, widget.empresaId),
            tooltip: 'Historial completo del día',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Pedidos en espera (HoldPedidosWidget)
          ListenableBuilder(
            listenable: _holdNotifier,
            builder: (_, __) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline, size: 16),
                  onPressed: _mostrarPedidosEnEspera,
                  tooltip: 'Pedidos en espera',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                if (_holdNotifier.pedidos.isNotEmpty)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3296),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, size: 16),
            onPressed: _mostrarEstadisticasEmpleados,
            tooltip: 'Estadísticas de empleados',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Ticket de ejemplo: solo propietario
          if (widget.esPropietario)
            IconButton(
              icon: const Icon(Icons.receipt_long, size: 16),
              onPressed: _mostrarTicketEjemplo,
              tooltip: 'Ver ticket de ejemplo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          IconButton(
            icon: const Icon(Icons.settings, size: 16),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ConfiguracionFacturacionTpvScreen(
                empresaId: widget.empresaId,
                esPropietario: widget.esPropietario,
              ),
            )),
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

  /// Upsert cliente en Firestore a partir de los datos de una cita.
  /// Si ya existe (por nombre+teléfono), devuelve su ID. Si no, lo crea.
  Future<String?> _upsertCliente({
    required String nombre,
    String? telefono,
    String? email,
  }) async {
    if (nombre.trim().isEmpty) return null;
    try {
      final col = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes');

      // Buscar por teléfono primero (si lo hay)
      if (telefono != null && telefono.isNotEmpty) {
        final snap = await col.where('telefono', isEqualTo: telefono).limit(1).get();
        if (snap.docs.isNotEmpty) return snap.docs.first.id;
      }

      // Buscar por nombre
      final snapNombre = await col
          .where('nombre_lower', isEqualTo: nombre.toLowerCase().trim())
          .limit(1)
          .get();
      if (snapNombre.docs.isNotEmpty) return snapNombre.docs.first.id;

      // No existe → crear
      final doc = await col.add({
        'nombre': nombre.trim(),
        'nombre_lower': nombre.toLowerCase().trim(),
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
        if (email != null && email.isNotEmpty) 'email': email,
        'creado': FieldValue.serverTimestamp(),
        'activo': true,
        'num_visitas': 0,
        'total_gastado': 0.0,
        'origen': 'tpv_cita',
      });
      return doc.id;
    } catch (_) {
      return null;
    }
  }

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

    // Upsert cliente en background
    if (cita.clienteNombre.isNotEmpty) {
      _upsertCliente(
        nombre: cita.clienteNombre,
        telefono: cita.clienteTelefono,
      ).then((id) {
        if (id != null && mounted) {
          setState(() => _extra = _extra.copyWith(clienteId: id));
        }
      });
    }
    FluxToast.exito(context, 'Servicios de ${cita.clienteNombre} cargados en el ticket');
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
    final resultado = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black26,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, _) => _DialogoNuevaCita(
        empresaId: widget.empresaId,
        fecha: _fechaStr,
        profIdInicial: _profIdSeleccionado,
        colorPrimario: _colorPrimario,
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeInOut)),
        child: child,
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
      builder: (_) => _DialogoAperturaCaja(
        empresaId: widget.empresaId,
        fecha: _fecha,
      ),
    );
  }

  // ── Estadísticas de empleados ──────────────────────────────────────────────

  void _mostrarEstadisticasEmpleados() {
    final tema = _TpvTema(
      primario: _colorPrimario, secundario: _colorSecundario,
      fondo: _colorFondo, superficie: _colorSuperficie, texto: _colorTexto,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tema.superficie,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, sc) => _PanelEstadisticasEmpleados(
          empresaId: widget.empresaId,
          tema: tema,
          scrollCtrl: sc,
        ),
      ),
    );
  }

  // ── Historial de ventas ───────────────────────────────────────────────────

  void _mostrarHistorialVentas() {
    final tema = _TpvTema(
      primario: _colorPrimario, secundario: _colorSecundario,
      fondo: _colorFondo, superficie: _colorSuperficie, texto: _colorTexto,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tema.superficie,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: tema.textoPrimario.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Icon(Icons.history, color: tema.primario, size: 18),
              const SizedBox(width: 8),
              Text('Historial de ventas',
                  style: TextStyle(color: tema.textoPrimario, fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          Divider(color: tema.divisor, height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(widget.empresaId)
                  .collection('pedidos')
                  .orderBy('fecha_creacion', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return Center(
                      child: CircularProgressIndicator(color: tema.primario));
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(child: Text('Sin ventas registradas',
                      style: TextStyle(color: tema.textoSecundario)));
                }
                final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
                final dateFmt = DateFormat('dd/MM HH:mm');
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: tema.divisor, height: 1),
                  itemBuilder: (_, i) {
                    final doc  = docs[i];
                    final d    = doc.data() as Map<String, dynamic>;
                    final total       = (d['total'] as num?)?.toDouble() ?? 0.0;
                    final metodo      = d['metodo_pago'] as String? ?? '—';
                    final cliente     = d['cliente_nombre'] as String? ?? '—';
                    final fecha       = (d['fecha_creacion'] as Timestamp?)?.toDate();
                    final nLineas     = (d['lineas'] as List?)?.length ?? 0;
                    final yaFacturado = d['factura_id'] != null;
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      onTap: () => _mostrarDetalleVenta(ctx, d, doc.id, fmt, tema),
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                            color: tema.primario.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.receipt_long, color: tema.primario, size: 18),
                      ),
                      title: Row(children: [
                        Expanded(child: Text(fmt.format(total),
                            style: TextStyle(color: tema.primario, fontSize: 14,
                                fontWeight: FontWeight.w800))),
                        if (yaFacturado) ...[
                          const Icon(Icons.check_circle, color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: tema.textoPrimario.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(metodo,
                              style: TextStyle(
                                  color: tema.textoSecundario, fontSize: 10)),
                        ),
                      ]),
                      subtitle: Text(
                        '${fecha != null ? dateFmt.format(fecha) : '—'}  ·  $cliente  ·  $nLineas servicios',
                        style: TextStyle(color: tema.textoSecundario, fontSize: 11),
                      ),
                      trailing: Icon(Icons.chevron_right,
                          color: tema.textoSecundario, size: 16),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Detalle de venta ──────────────────────────────────────────────────────

  void _mostrarDetalleVenta(BuildContext context, Map<String, dynamic> d,
      String pedidoId, NumberFormat fmt, _TpvTema tema) {
    final lineas       = (d['lineas'] as List<dynamic>?) ?? [];
    final total        = (d['total'] as num?)?.toDouble() ?? 0.0;
    final metodo       = d['metodo_pago'] as String? ?? '—';
    final cliente      = d['cliente_nombre'] as String? ?? 'Cliente';
    final fecha        = (d['fecha_creacion'] as Timestamp?)?.toDate();
    final yaFacturado  = d['factura_id'] != null;
    final dateFmt      = DateFormat('dd/MM/yyyy HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tema.superficie,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        builder: (_, sc) => Column(children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: tema.textoPrimario.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2)),
          ),
          // ── Cabecera ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmt.format(total),
                      style: TextStyle(color: tema.primario, fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    '${fecha != null ? dateFmt.format(fecha) : '—'}  ·  $metodo',
                    style: TextStyle(color: tema.textoSecundario, fontSize: 11),
                  ),
                  if (cliente.isNotEmpty && cliente != 'Cliente')
                    Row(children: [
                      Icon(Icons.person_outline, size: 12, color: tema.textoSecundario),
                      const SizedBox(width: 4),
                      Text(cliente,
                          style: TextStyle(fontSize: 11, color: tema.textoSecundario)),
                    ]),
                ],
              )),
              if (yaFacturado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 14),
                    SizedBox(width: 4),
                    Text('Facturado', style: TextStyle(color: Colors.green,
                        fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
          Divider(color: tema.divisor, height: 1),

          // ── Líneas ───────────────────────────────────────────
          Expanded(
            child: lineas.isEmpty
                ? Center(child: Text('Sin detalle de servicios',
                    style: TextStyle(color: tema.textoSecundario)))
                : ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: lineas.length,
                    separatorBuilder: (_, __) => Divider(color: tema.divisor, height: 1),
                    itemBuilder: (_, i) {
                      final l = Map<String, dynamic>.from(
                          lineas[i] is Map ? lineas[i] as Map : {});
                      final nombre   = (l['producto_nombre'] ?? l['nombre'] ?? '—').toString();
                      final cantidad = (l['cantidad'] as num?)?.toInt() ?? 1;
                      final precio   = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
                      final subtotal = (l['subtotal'] as num?)?.toDouble() ?? precio * cantidad;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                                color: tema.primario.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6)),
                            child: Center(child: Text('×$cantidad',
                                style: TextStyle(color: tema.primario,
                                    fontSize: 11, fontWeight: FontWeight.w700))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(nombre,
                              style: TextStyle(color: tema.textoPrimario,
                                  fontSize: 13, fontWeight: FontWeight.w600))),
                          const SizedBox(width: 8),
                          Text(fmt.format(subtotal),
                              style: TextStyle(color: tema.primario,
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                        ]),
                      );
                    },
                  ),
          ),

          // ── Footer: total + factura ───────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tema.divisor))),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL', style: TextStyle(color: tema.textoSecundario,
                      fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(fmt.format(total), style: TextStyle(color: tema.primario,
                      fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(yaFacturado
                      ? Icons.open_in_new_rounded
                      : Icons.receipt_long_outlined,
                      size: 16),
                  label: Text(yaFacturado
                      ? 'Abrir factura'
                      : 'Crear factura'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tema.primario,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    if (yaFacturado) {
                      // ── Abrir la factura existente en DetalleFacturaScreen ──
                      final facturaId = d['factura_id'] as String;
                      try {
                        final snap = await FirebaseFirestore.instance
                            .collection('empresas')
                            .doc(widget.empresaId)
                            .collection('facturas')
                            .doc(facturaId)
                            .get();
                        if (!snap.exists || !context.mounted) return;
                        final factura = Factura.fromFirestore(snap);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetalleFacturaScreen(
                              factura: factura,
                              empresaId: widget.empresaId,
                            ),
                          ),
                        );
                      } catch (_) {
                        if (context.mounted) {
                          FluxToast.error(context, 'No se pudo cargar la factura');
                        }
                      }
                      return;
                    }
                    // ── Crear nueva factura ──
                    final lineasPedido = lineas.map((raw) {
                      final l = Map<String, dynamic>.from(
                          raw is Map ? raw : {});
                      return LineaPedido(
                        productoId: l['producto_id'] as String? ?? '',
                        productoNombre: (l['producto_nombre'] ?? l['nombre'] ?? '').toString(),
                        cantidad: (l['cantidad'] as num?)?.toInt() ?? 1,
                        precioUnitario: (l['precio_unitario'] as num?)?.toDouble() ?? 0.0,
                        ivaPorcentaje: (l['iva_porcentaje'] as num?)?.toDouble() ?? 10.0,
                        notasLinea: null,
                      );
                    }).toList();
                    final pedido = Pedido(
                      id: pedidoId,
                      empresaId: widget.empresaId,
                      clienteNombre: cliente,
                      lineas: lineasPedido,
                      metodoPago: metodo == 'tarjeta' ? MetodoPago.tarjeta
                          : MetodoPago.efectivo,
                      origen: OrigenPedido.presencial,
                      total: total,
                      estado: EstadoPedido.entregado,
                      estadoPago: EstadoPago.pagado,
                      numeroTicket: (d['numero_ticket'] as num?)?.toInt() ?? 0,
                      historial: const [],
                      fechaCreacion: fecha ?? DateTime.now(),
                      facturaId: d['factura_id'] as String?,
                    );
                    if (context.mounted) {
                      await DialogoFacturaTpv.mostrar(
                        context: context,
                        empresaId: widget.empresaId,
                        pedido: pedido,
                      );
                    }
                  },
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Mostrar ticket de ejemplo ─────────────────────────────────────────────
  Future<void> _mostrarTicketEjemplo() async {
    try {
      final ahora = DateTime.now();

      // Usar el ticket actual si tiene servicios; si no, usar datos de ejemplo
      final List<LineaPedido> lineasEjemplo;
      final String clienteEjemplo;

      if (_lineasTicket.isNotEmpty) {
        lineasEjemplo = _lineasTicket.map((l) => LineaPedido(
              productoId: '',
              productoNombre: l['nombre'] as String? ?? '',
              cantidad: 1,
              precioUnitario: (l['precio'] as num?)?.toDouble() ?? 0,
              ivaPorcentaje: 21,
              notasLinea: null,
            )).toList();
        clienteEjemplo = _extra.nombreCliente ?? 'Cliente';
      } else {
        lineasEjemplo = const [
          LineaPedido(productoId: 'e1', productoNombre: 'Corte de Pelo Mujer',
              cantidad: 1, precioUnitario: 25.0, ivaPorcentaje: 21, notasLinea: null),
          LineaPedido(productoId: 'e2', productoNombre: 'Tinte Completo',
              cantidad: 1, precioUnitario: 45.0, ivaPorcentaje: 21, notasLinea: null),
          LineaPedido(productoId: 'e3', productoNombre: 'Tratamiento Keratina',
              cantidad: 1, precioUnitario: 35.0, ivaPorcentaje: 21, notasLinea: null),
        ];
        clienteEjemplo = 'Cliente Ejemplo';
      }
      final totalEjemplo = lineasEjemplo.fold<double>(
          0, (s, l) => s + l.precioUnitario * l.cantidad);

      final pedidoEjemplo = Pedido(
        total: totalEjemplo,
        id: 'EJEMPLO-${ahora.millisecondsSinceEpoch}',
        empresaId: widget.empresaId,
        historial: [],
        clienteNombre: clienteEjemplo,
        clienteTelefono: '+34 600 000 000',
        lineas: lineasEjemplo,
        metodoPago: MetodoPago.efectivo,
        origen: OrigenPedido.presencial,
        estado: EstadoPedido.pendiente,
        estadoPago: EstadoPago.pendiente,
        fechaCreacion: ahora,
        numeroTicket: 999,
      );

      // Cargar configuración del TPV
      final config = await TpvFacturacionService().obtenerConfig(widget.empresaId);
      
      // Generar PDF del ticket
      final pdfBytes = await TpvDocumentRenderer().renderizarDocumento(
        empresaId: widget.empresaId,
        pedido: pedidoEjemplo,
        config: config,
        clienteNif: null,
        clienteEmail: null,
        clienteDireccion: null,
      );

      if (!mounted) return;

      // Mostrar el PDF en un diálogo
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 600,
            height: 800,
            child: Column(
              children: [
                AppBar(
                  title: const Text('Ejemplo de Ticket', style: TextStyle(fontSize: 14)),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.print),
                      onPressed: () async {
                        await Printing.layoutPdf(
                          onLayout: (_) async => pdfBytes,
                        );
                      },
                      tooltip: 'Imprimir',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) async => pdfBytes,
                    allowPrinting: true,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error al generar ticket de ejemplo: $e');
      if (!mounted) return;
      FluxToast.error(context, 'Error al generar ticket de ejemplo: $e');
    }
  }

  // ── Guardar ticket actual en espera ──────────────────────────────────────
  void _guardarEnEspera() {
    if (_lineasTicket.isEmpty) return;
    final etiqueta = _extra.nombreCliente?.isNotEmpty == true
        ? _extra.nombreCliente!
        : 'Pedido ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    _holdNotifier.guardar(
      etiqueta: etiqueta,
      lineas: List<Map<String, dynamic>>.from(_lineasTicket),
      total: _total,
    );
    _limpiarTicket();
    FluxToast.exito(context, 'Guardado en espera: $etiqueta');
  }

  // ── Recuperar pedido en espera ────────────────────────────────────────────
  Future<void> _mostrarPedidosEnEspera() async {
    final recuperado = await HoldPedidosWidget.mostrar(context, _holdNotifier);
    if (recuperado != null && mounted) {
      setState(() {
        _lineasTicket.clear();
        _lineasTicket.addAll(recuperado.lineas);
        _extra = const _TicketExtra();
      });
    }
  }

  Future<void> _cobrar() async {
    if (_lineasTicket.isEmpty) return;
    if (_total <= 0 && _extra.propina == 0) return;

    // La caja siempre es de hoy — ignorar la fecha de la agenda
    final cajaAbierta = await CierreCajaService()
        .hayCajaAbiertaHoy(widget.empresaId);
    if (!mounted) return;
    if (!cajaAbierta) {
      FluxToast.error(
          context, 'No hay caja abierta. Pulsa "Caja" en el menú para abrirla.');
      return;
    }

    final pago = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoPago(
          total: _total, propina: _extra.propina,
          empresaId: widget.empresaId,
          mostrarPropina: _mostrarPropina,
          tema: _TpvTema(primario: _colorPrimario, secundario: _colorSecundario,
              fondo: _colorFondo, superficie: _colorSuperficie, texto: _colorTexto)),
    );
    if (pago == null) return;

    try {
      final ahora = DateTime.now();

      // Contador de tickets — con fallback offline via SharedPreferences
      final numTicket = await _obtenerNumTicket();

      final empresaSnap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .get();
      final nombreEmpresa = empresaSnap.data()?['nombre'] as String? ?? '';

      final lineasPedido = _lineasTicket.map((l) {
        final pvp = (l['precio'] as num?)?.toDouble() ?? 0;
        // Usar IVA del servicio o fallback al global (21%)
        final iva = (l['iva_porcentaje'] as num?)?.toDouble() ?? 21.0;
        // Usar precio_con_iva del servicio; si no tiene, usar la config global
        final conIva = l['precio_con_iva'] as bool? ?? _preciosConIva;
        // Extraer base imponible si el precio ya incluye IVA
        final base = conIva ? pvp / (1 + iva / 100) : pvp;
        return LineaPedido(
          productoId: '',
          productoNombre: l['nombre'] as String? ?? '',
          cantidad: 1,
          precioUnitario: base,
          ivaPorcentaje: iva,
          notasLinea: null,
        );
      }).toList();

      final pedido = await PedidosService().crearPedido(
        empresaId: widget.empresaId,
        clienteNombre: _extra.nombreCliente ?? 'Caja directa',
        lineas: lineasPedido,
        metodoPago: switch (pago['metodo'] as String? ?? 'efectivo') {
          'efectivo'      => MetodoPago.efectivo,
          'bizum'         => MetodoPago.bizum,
          'paypal'        => MetodoPago.paypal,
          'mixto'         => MetodoPago.mixto,
          _               => MetodoPago.tarjeta,
        },
        origen: OrigenPedido.presencial,
        numeroTicket: numTicket,
        importeEfectivo: pago['importe_efectivo'],
        importeTarjeta: pago['importe_tarjeta'],
        importeTotal: _total,
        importesPorMetodo: (pago['importes'] as Map?)
            ?.cast<String, double>(),
        mesaId: null,
        estado: 'entregado',
        estadoPago: 'pagado',
        fechaHora: Timestamp.fromDate(ahora),
      );

      // QR AEAT (VeriFactu) — almacenar URL en el pedido
      try {
        final nif = (empresaSnap.data()?['nif'] as String?)?.trim() ?? '';
        if (nif.isNotEmpty) {
          final qrUrl = QrService().generarUrl(
            nifEmisor: nif,
            serie: 'TPV',
            numero: pedido.id.substring(0, 8).toUpperCase(),
            fecha: ahora,
            importeTotal: _total,
          );
          await FirebaseFirestore.instance
              .collection('empresas')
              .doc(widget.empresaId)
              .collection('pedidos')
              .doc(pedido.id)
              .update({'qr_aeat_url': qrUrl});
        }
      } catch (_) {}

      // Preguntar si desea factura
      if (mounted) {
        await DialogoFacturaTpv.mostrar(
          context: context,
          empresaId: widget.empresaId,
          pedido: pedido,
        );
      }

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

      // Abrir cajón registradora según configuración del tenant
      try {
        final cfg = await TpvFacturacionService().obtenerConfig(widget.empresaId);
        await ImpresoraService().abrirCajonSiProcede(
          config: cfg,
          metodoPago: pago['metodo'] as String? ?? 'efectivo',
        );
      } catch (_) {}

      // ── Actualizar ficha del cliente + historial de actividad ────────────
      final clienteId = _extra.clienteId;
      if (clienteId != null && clienteId.isNotEmpty) {
        final serviciosStr = _lineasTicket
            .map((l) => l['nombre'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ');

        // Contadores del cliente
        FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('clientes')
            .doc(clienteId)
            .update({
          'num_visitas': FieldValue.increment(1),
          'total_gastado': FieldValue.increment(_total),
          'ultima_visita': FieldValue.serverTimestamp(),
          'ultimo_servicio': _lineasTicket
              .map((l) => l['nombre'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .toList(),
        }).catchError((_) {});

        // Registrar en el historial de actividad visible en el módulo Clientes
        ActividadClienteService().registrarEvento(
          empresaId: widget.empresaId,
          clienteId: clienteId,
          tipo: TipoEventoActividad.pedidoEntregado,
          descripcion: 'Ticket #$numTicket — $serviciosStr',
          documentoId: pedido.id,
          importe: _total,
          estado: 'pagado',
          servicio: serviciosStr.isNotEmpty ? serviciosStr : null,
          creadoPorId: _uid,
        ).catchError((_) {});
      }

      if (!mounted) return;
      FluxToast.exito(context, 'Ticket #$numTicket cobrado — ${_total.toStringAsFixed(2)} EUR');
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
  State<_DialogoConfigImpresora> createState() => _DialogoConfigImpresoraState();
}

class _DialogoConfigImpresoraState extends State<_DialogoConfigImpresora> {
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
        FluxToast.exito(context, 'Conectado a ${device.name}');
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
        FluxToast.error(context, 'Error imprimiendo: $e');
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
  final DateTime fecha;
  final VoidCallback onVolver;

  const _CierreWrapper(
      {required this.empresaId,
      required this.fecha,
      required this.onVolver});

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
      Expanded(child: _PelCierreDeCaja(empresaId: empresaId, fecha: fecha)),
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
    // Solo empleados activos del módulo empleados (usuarios con empresa_id).
    final merged = List<Profesional>.from(_listaEmpleados);
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
    final tema = _TpvTemaScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: tema.superficie,
      child: Row(children: [
        // Navegador de fecha
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: tema.primario.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: Icon(Icons.chevron_left, size: 20, color: tema.textoPrimario),
              onPressed: () => widget.onFechaChanged(
                  widget.fecha.subtract(const Duration(days: 1))),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('EEE d MMM yyyy', 'es').format(widget.fecha),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: tema.textoPrimario),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.chevron_right, size: 20, color: tema.textoPrimario),
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
            backgroundColor: tema.primario,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ]),
    );
  }

  Widget _buildListaProfesionales(List<Profesional> profs) {
    final tema = _TpvTemaScope.of(context);
    if (profs.isEmpty) {
      return Text('Sin empleados activos',
          style: TextStyle(fontSize: 12, color: tema.textoSecundario));
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
                        ? tema.primario
                        : tema.divisor,
                    width: widget.profIdSeleccionado == '__todos__' || widget.profIdSeleccionado == null ? 3 : 1.5,
                  ),
                  color: tema.primario.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Icon(Icons.people, color: tema.primario, size: 22),
                ),
              ),
              const SizedBox(height: 4),
              Text('Todos',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: (widget.profIdSeleccionado == '__todos__' || widget.profIdSeleccionado == null)
                      ? FontWeight.w700 : FontWeight.w500,
                  color: (widget.profIdSeleccionado == '__todos__' || widget.profIdSeleccionado == null)
                      ? tema.primario : tema.textoSecundario,
                ),
              ),
            ]),
          ),
        ),
        // ── Lista de empleados ────────────────────────────────────
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
    // Color fijo por ID del profesional, no por posición en lista
    final color = profColorPorId(prof.id);
    final tema = _TpvTemaScope.of(context);
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
                  color: seleccionado ? color : tema.divisor,
                  width: seleccionado ? 3 : 1.5,
                ),
                color: color.withValues(alpha: seleccionado ? 0.18 : 0.12),
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
                color: seleccionado ? color : tema.textoSecundario,
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
                  style: TextStyle(
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
              color: _TpvTemaScope.primarioOf(context).withValues(alpha: 0.4),
              width: 1.5,
            ),
            color: kPelPrimarioLight,
          ),
          child: Icon(Icons.add, color: _TpvTemaScope.primarioOf(context), size: 22),
        ),
        const SizedBox(height: 4),
        Text('Añadir',
            style: TextStyle(fontSize: 10, color: _TpvTemaScope.primarioOf(context))),
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
        Text(esEdicion ? 'Editar profesional' : 'Nuevo profesional',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _TpvTemaScope.primarioOf(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _comisionPct,
                  min: 0,
                  max: 60,
                  divisions: 12,
                  activeColor: _TpvTemaScope.primarioOf(context),
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
          style: FilledButton.styleFrom(backgroundColor: _TpvTemaScope.primarioOf(context)),
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
        FluxToast.error(context, 'Error: $e');
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
      empresaId: widget.empresaId,
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
  final VoidCallback? onNuevaCita;

  const _TodosTab({
    required this.empresaId,
    required this.fechaStr,
    required this.onCitaCompletada,
    this.onNuevaCita,
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
      empresaId: widget.empresaId,
      citas: _citas,
      profesionales: _profesionales,
      reglasColor: _reglasColor,
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

// ── Timeline multi-profesional ───────────────────────────────────────────────

class _TodosTimeline extends StatefulWidget {
  final String empresaId;
  final List<Cita> citas;
  final List<Profesional> profesionales;
  final List<Map<String, dynamic>> reglasColor;
  final ValueChanged<Cita> onTapCita;
  final VoidCallback? onNuevaCita;

  static const int inicioHora = 8;
  static const int finHora = 21;
  static const double alturaHora = 100.0;

  const _TodosTimeline({
    required this.empresaId,
    required this.citas,
    required this.profesionales,
    required this.reglasColor,
    required this.onTapCita,
    this.onNuevaCita,
  });

  @override
  State<_TodosTimeline> createState() => _TodosTimelineState();
}

class _TodosTimelineState extends State<_TodosTimeline> {
  final ScrollController _scrollCtrl = ScrollController();

  // ── Drag & drop entre profesionales / horas ────────────────────────────────
  final _timelineKey = GlobalKey();
  Cita? _citaArrastrada;
  double _dragTop = 0;
  double _dragHeight = 0;
  double _dragOffsetY = 0;
  int _profOrigenIdx = 0;
  int _profDestinoIdx = 0;

  String _horaDesdeTop(double top) {
    final min = (top / _TodosTimeline.alturaHora * 60).round();
    final minR = (min / 15).round() * 15;
    final h = (minR ~/ 60) + _TodosTimeline.inicioHora;
    final m = minR % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int _profIdxFromGlobal(Offset global, int numProfs) {
    final box =
        _timelineKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || numProfs == 0) return _profOrigenIdx;
    final local = box.globalToLocal(global);
    final x = local.dx - 58; // 58px = columna de horas
    if (x < 0) return 0;
    final colW = (box.size.width - 58) / numProfs;
    return (x / colW).floor().clamp(0, numProfs - 1);
  }

  Future<void> _commitDragMultiProf(
      Cita cita, List<Profesional> profs) async {
    final nuevaHora = _horaDesdeTop(_dragTop);
    final nuevoProfId = _profDestinoIdx < profs.length
        ? profs[_profDestinoIdx].id
        : cita.profesionalId;
    setState(() => _citaArrastrada = null);

    final cambioHora = nuevaHora != cita.horaInicio;
    final cambioProf = nuevoProfId != cita.profesionalId;
    if (!cambioHora && !cambioProf) return;

    try {
      final Map<String, dynamic> updates = {};
      if (cambioHora) updates['hora_inicio'] = nuevaHora;
      if (cambioProf) {
        updates['prof_id'] = nuevoProfId;
        updates['profesional_id'] = nuevoProfId;
      }
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('reservas')
          .doc(cita.id)
          .update(updates);
    } catch (_) {}
  }

  Future<void> _moverCitaAProfesional(Cita cita, String nuevoProfId) async {
    if (cita.profesionalId == nuevoProfId) return;
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('reservas')
          .doc(cita.id)
          .update({
        'prof_id': nuevoProfId,
        'profesional_id': nuevoProfId,
      });
    } catch (_) {}
  }

  void _mostrarSelectorProfesional(Cita cita) {
    if (widget.profesionales.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mover cita a…', style: TextStyle(fontSize: 15)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.profesionales.map((prof) {
              final esActual = prof.id == cita.profesionalId;
              final color = profColorPorId(prof.id);
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: color,
                  child: Text(
                    prof.nombre.isNotEmpty ? prof.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(prof.nombre,
                    style: TextStyle(
                        fontWeight: esActual ? FontWeight.w700 : FontWeight.w500,
                        color: esActual ? color : null)),
                trailing: esActual
                    ? Icon(Icons.check_circle, color: color, size: 18)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _moverCitaAProfesional(cita, prof.id);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

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
        : cita.servicioNombre.isNotEmpty
            ? cita.servicioNombre
            : '';
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
    // Color fijo por ID (no cambia con la posición)
    return profColorPorId(cita.profesionalId);
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

  /// Columnas por profesional dentro de su swim lane
  List<Map<String, dynamic>> _columnasPorProf(List<Cita> citas) {
    if (citas.isEmpty) return [];
    final sorted = List<Cita>.from(citas)..sort((a, b) {
      int toMin(Cita c) {
        final p = c.horaInicio.split(':');
        return (int.tryParse(p[0]) ?? 0) * 60 + (p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0);
      }
      return toMin(a).compareTo(toMin(b));
    });
    final result = <Map<String, dynamic>>[];
    final grupos = <List<Cita>>[];
    for (final cita in sorted) {
      bool added = false;
      for (final g in grupos) {
        if (g.any((x) => _seSolapan(cita, x))) { g.add(cita); added = true; break; }
      }
      if (!added) grupos.add([cita]);
    }
    for (final g in grupos) {
      for (int i = 0; i < g.length; i++) {
        result.add({'cita': g[i], 'col': i, 'total': g.length});
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final totalHoras = _TodosTimeline.finHora - _TodosTimeline.inicioHora;
    final totalAltura = totalHoras * _TodosTimeline.alturaHora;
    final horaActual = DateTime.now().hour;
    final tema = _TpvTemaScope.of(context);

    // Agrupar citas por profesional
    final Map<String, List<Cita>> citasPorProf = {};
    for (final c in widget.citas) {
      citasPorProf.putIfAbsent(c.profesionalId, () => []).add(c);
    }

    // Si no hay profesionales definidos, usar los que aparecen en las citas
    final profsAMostrar = widget.profesionales.isNotEmpty
        ? widget.profesionales
        : widget.citas.map((c) => c.profesionalId).toSet()
            .map((id) => Profesional(id: id, nombre: _nombreProf(id), email: null, telefono: null, especialidad: null, colorIdx: 0, activo: true, horaEntrada: '08:00', horaSalida: '20:00'))
            .toList();

    return Column(children: [
      // ── Cabecera resumen ─────────────────────────────────────────────
      Container(
        color: tema.superficie,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(children: [
          Text(
            widget.citas.isEmpty
                ? 'Sin citas hoy'
                : '${widget.citas.length} cita${widget.citas.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tema.textoPrimario),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _irAHoraActual,
            icon: Icon(Icons.access_time, size: 13, color: tema.textoSecundario),
            label: Text('Ahora', style: TextStyle(fontSize: 11, color: tema.textoSecundario)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ]),
      ),

      // ── Cabeceras sticky de profesionales ──────────────────────────
      Container(
        height: 44,
        decoration: BoxDecoration(
          color: tema.superficie,
          border: Border(bottom: BorderSide(color: tema.divisor, width: 1.5)),
        ),
        child: Row(children: [
          SizedBox(width: 58), // hueco para col de horas
          Container(width: 1, color: tema.divisor),
          ...profsAMostrar.map((prof) {
            final avatarColor = profColorPorId(prof.id);
            final cnt = (citasPorProf[prof.id] ?? []).length;
            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.06),
                  border: Border(right: BorderSide(color: tema.divisor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: avatarColor),
                      child: Center(child: Text(
                        prof.nombre.isNotEmpty ? prof.nombre[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                      )),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        prof.nombre.split(' ').first,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tema.secundario),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (cnt > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: avatarColor, borderRadius: BorderRadius.circular(8)),
                        child: Text('$cnt', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ]),
      ),

      // ── Timeline por columnas ──────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.only(bottom: 24),
          child: SizedBox(
            height: totalAltura + 24,
            child: Row(
              key: _timelineKey,
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
                            left: 0, right: 0, height: _TodosTimeline.alturaHora,
                            child: Container(color: tema.textoPrimario.withValues(alpha: 0.04)),
                          ),
                      for (int h = _TodosTimeline.inicioHora; h <= _TodosTimeline.finHora; h++)
                        Positioned(
                          top: (h - _TodosTimeline.inicioHora) * _TodosTimeline.alturaHora - 8,
                          right: 8,
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 11,
                              color: h == horaActual ? Colors.red.shade400 : tema.textoSecundario,
                              fontWeight: h == horaActual ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(width: 1, color: tema.divisor),
                // Una columna por profesional
                ...profsAMostrar.asMap().entries.map((entry) {
                  final profIdx = entry.key;
                  final prof   = entry.value;
                  final color = profColorPorId(prof.id);
                  final profCitas = citasPorProf[prof.id] ?? [];
                  final bloques = _columnasPorProf(profCitas);
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: tema.divisor)),
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final ancho = constraints.maxWidth;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (_) => widget.onNuevaCita?.call(),
                            child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Fondo suave del profesional
                              Positioned.fill(child: Container(
                                color: color.withValues(alpha: 0.03),
                              )),
                              // Líneas de hora
                              for (int h = _TodosTimeline.inicioHora; h < _TodosTimeline.finHora; h++)
                                if (h.isEven)
                                  Positioned(
                                    top: (h - _TodosTimeline.inicioHora) * _TodosTimeline.alturaHora,
                                    left: 0, right: 0, height: _TodosTimeline.alturaHora,
                                    child: Container(color: tema.textoPrimario.withValues(alpha: 0.025)),
                                  ),
                              for (int h = _TodosTimeline.inicioHora; h <= _TodosTimeline.finHora; h++) ...[
                                Positioned(
                                  top: (h - _TodosTimeline.inicioHora) * _TodosTimeline.alturaHora,
                                  left: 0, right: 4, height: 1,
                                  child: Container(
                                    color: h == horaActual
                                        ? Colors.red.shade400.withValues(alpha: 0.5)
                                        : tema.divisor,
                                  ),
                                ),
                                if (h < _TodosTimeline.finHora)
                                  Positioned(
                                    top: (h - _TodosTimeline.inicioHora) * _TodosTimeline.alturaHora +
                                        _TodosTimeline.alturaHora / 2,
                                    left: 8, right: 4, height: 1,
                                    child: Container(color: tema.textoPrimario.withValues(alpha: 0.04)),
                                  ),
                              ],
                              // Indicador hora actual
                              _buildHoraActualIndicador(),
                              // Citas de este profesional
                              ...bloques.map((info) => _buildCitaBlock(
                                info['cita'] as Cita,
                                info['col'] as int,
                                info['total'] as int,
                                ancho,
                                profsAMostrar,
                                profIdx,
                              )),
                              // Ghost durante arrastre — muestra destino en esta columna
                              if (_citaArrastrada != null &&
                                  _profDestinoIdx == profIdx)
                                Positioned(
                                  top: _dragTop,
                                  left: 2,
                                  right: 8,
                                  height: _dragHeight.clamp(20.0, double.infinity),
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _colorParaCita(_citaArrastrada!)
                                            .withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _colorParaCita(_citaArrastrada!),
                                          width: 2,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _horaDesdeTop(_dragTop),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ));
                        },
                      ),
                    ),
                  );
                }),
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

  Widget _buildCitaBlock(
    Cita cita,
    int columna,
    int totalColumnas,
    double anchoDisponible,
    List<Profesional> profs,
    int profIdx,
  ) {
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

    final estaArrastrando = _citaArrastrada?.id == cita.id;
    final maxTop =
        ((_TodosTimeline.finHora - _TodosTimeline.inicioHora) *
                _TodosTimeline.alturaHora -
            height)
            .clamp(0.0, double.infinity);

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: _citaArrastrada == null ? () => widget.onTapCita(cita) : null,
        onLongPressStart: (d) => setState(() {
          _citaArrastrada = cita;
          _dragTop = top;
          _dragHeight = height;
          _dragOffsetY = d.localPosition.dy;
          _profOrigenIdx = profIdx;
          _profDestinoIdx = profIdx;
        }),
        onLongPressMoveUpdate: (d) {
          final nuevoTop =
              (top + d.offsetFromOrigin.dy - _dragOffsetY)
                  .clamp(0.0, maxTop);
          final targetIdx =
              _profIdxFromGlobal(d.globalPosition, profs.length);
          setState(() {
            _dragTop = nuevoTop;
            _profDestinoIdx = targetIdx;
          });
        },
        onLongPressEnd: (_) => _commitDragMultiProf(cita, profs),
        onLongPressCancel: () => setState(() => _citaArrastrada = null),
        child: Opacity(
          opacity: estaArrastrando ? 0.35 : 1.0,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 3, offset: const Offset(0, 1))],
          ),
          child: _contenidoTodosBloque(height: height, nombre: cita.clienteNombre,
              hora: cita.horaInicio, servicio: servicioNombre, prof: profNombre,
              nota: cita.nota, estado: cita.estado),
        ),      // Container
        ),      // Opacity
      ),        // GestureDetector
    );          // Positioned
  }

  Widget _contenidoTodosBloque({
    required double height, required String nombre,
    required String hora, required String servicio, required String prof,
    String? nota, required String estado,
  }) {
    if (height < 18) return const SizedBox.shrink();
    if (height < 26) return Text(nombre,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
        maxLines: 1, overflow: TextOverflow.ellipsis);
    if (height < 42) return Row(children: [
      Expanded(child: Text(nombre,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
      _EstadoBadge(estado: estado),
    ]);
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(nombre,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          _EstadoBadge(estado: estado),
        ]),
        const SizedBox(height: 1),
        Text('$hora  ·  $servicio',
            style: const TextStyle(fontSize: 8, color: Colors.white70),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        if (height > 54 && prof.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(prof, style: const TextStyle(fontSize: 8, color: Colors.white60),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        if (height > 68 && nota != null && nota.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(nota, style: const TextStyle(fontSize: 8, color: Colors.white60, fontStyle: FontStyle.italic),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
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
  final String empresaId;
  final List<Cita> citas;
  final Color profColor;
  final VoidCallback onNuevaCita;
  final ValueChanged<Cita> onTapCita;

  static const int inicioHora = 8;
  static const int finHora = 21;

  /// Píxeles por hora — ajusta la densidad visual del calendario
  static const double alturaHora = 100.0;

  const _AgendaTimeline({
    required this.empresaId,
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

  // Estado para arrastre de citas
  Cita? _citaArrastrada;
  double _dragTop = 0;
  double _dragOffsetY = 0;

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

    final tema = _TpvTemaScope.of(context);
    return Column(children: [
      // Cabecera mini con estado del día
      Container(
        color: tema.superficie,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.citas.isEmpty ? tema.textoSecundario : widget.profColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.citas.isEmpty
                ? 'Día libre — sin citas'
                : '${widget.citas.length} cita${widget.citas.length == 1 ? '' : 's'} hoy',
            style: TextStyle(
              fontSize: 12,
              color: widget.citas.isEmpty ? tema.textoSecundario : widget.profColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _irAHoraActual,
            icon: Icon(Icons.access_time, size: 13, color: tema.textoSecundario),
            label: Text('Ahora', style: TextStyle(fontSize: 11, color: tema.textoSecundario)),
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
            style: TextButton.styleFrom(foregroundColor: _TpvTemaScope.primarioOf(context)),
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
                            child: Container(color: tema.textoPrimario.withValues(alpha: 0.04)),
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
                                  ? Colors.red.shade400
                                  : tema.textoSecundario,
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
                Container(width: 1, color: tema.divisor),
                // Área del timeline con líneas y citas
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final anchoDisponible = constraints.maxWidth;
                      return GestureDetector(
                        onTapUp: (details) {
                          // Tap en zona libre del timeline → nueva cita
                          widget.onNuevaCita();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Bandas de fondo alternadas para identificar las horas
                            for (int h = _AgendaTimeline.inicioHora; h < _AgendaTimeline.finHora; h++)
                              if (h.isEven)
                                Positioned(
                                  top: (h - _AgendaTimeline.inicioHora) * _AgendaTimeline.alturaHora,
                                  left: 0, right: 0,
                                  height: _AgendaTimeline.alturaHora,
                                  child: Container(color: tema.textoPrimario.withValues(alpha: 0.03)),
                                ),
                            // Líneas de hora (más visibles) y media hora (sutiles)
                            for (int h = _AgendaTimeline.inicioHora; h <= _AgendaTimeline.finHora; h++) ...[
                              Positioned(
                                top: (h - _AgendaTimeline.inicioHora) * _AgendaTimeline.alturaHora,
                                left: 0, right: 8, height: 1,
                                child: Container(
                                  color: h == horaActual
                                      ? Colors.red.shade400.withValues(alpha: 0.5)
                                      : tema.divisor,
                                ),
                              ),
                              if (h < _AgendaTimeline.finHora)
                                Positioned(
                                  top: (h - _AgendaTimeline.inicioHora) * _AgendaTimeline.alturaHora +
                                      _AgendaTimeline.alturaHora / 2,
                                  left: 12, right: 8, height: 1,
                                  child: Container(color: tema.textoPrimario.withValues(alpha: 0.05)),
                                ),
                            ],
                            // Indicador hora actual
                            _buildHoraActual(),
                            // Bloques de citas con columnas
                            for (final citaInfo in citasConColumna)
                              _buildCitaBlock(citaInfo['cita'] as Cita, citaInfo['columna'] as int, citaInfo['totalColumnas'] as int, anchoDisponible),
                          ],
                        ),
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

  Future<void> _commitDrag(Cita cita) async {
    final totalHoras = _AgendaTimeline.finHora - _AgendaTimeline.inicioHora;
    final maxTop = totalHoras * _AgendaTimeline.alturaHora -
        cita.duracionMinutos * (_AgendaTimeline.alturaHora / 60);
    final clampedTop = _dragTop.clamp(0.0, maxTop);
    final minDesdeInicio = (clampedTop / _AgendaTimeline.alturaHora * 60).round();
    final minRedondeado = (minDesdeInicio / 15).round() * 15;
    final h = (minRedondeado ~/ 60) + _AgendaTimeline.inicioHora;
    final m = minRedondeado % 60;
    final nuevaHora = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    setState(() => _citaArrastrada = null);
    if (nuevaHora == cita.horaInicio) return;
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('reservas')
          .doc(cita.id)
          .update({'hora_inicio': nuevaHora});
    } catch (_) {}
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

    // Calcular posición y ancho — máx 50% cuando la cita está sola
    final colsEfectivas = totalColumnas == 1 ? 2 : totalColumnas;
    final anchoPorColumna = (anchoDisponible - 12) / colsEfectivas;
    final left = 2 + (columna * anchoPorColumna);
    final width = (anchoPorColumna - 4).clamp(20.0, double.infinity);
    // Si el bloque es muy estrecho, ocultar el badge para evitar overflow horizontal
    final mostrarBadge = width > 50;

    final estaArrastrando = _citaArrastrada?.id == cita.id;
    final displayTop = estaArrastrando ? _dragTop : top;

    Widget contenido = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: widget.profColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: widget.profColor.withValues(alpha: estaArrastrando ? 0.6 : 0.35),
            blurRadius: estaArrastrando ? 8 : 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      // Contenido escalado a la altura disponible — sin Column que pueda desbordar
      child: _buildCitaContenido(
        height: height,
        nombre: cita.clienteNombre,
        subtitulo: estaArrastrando
            ? _horaDesdeTop(_dragTop)
            : '${cita.horaInicio} – ${cita.horaFinStr}  ·  $servicioNombre',
        nota: (!estaArrastrando && cita.nota != null && cita.nota!.isNotEmpty)
            ? cita.nota
            : null,
        estado: cita.estado,
        arrastrandoIcon: estaArrastrando,
        mostrarBadge: mostrarBadge,
      ),
    );

    return Positioned(
      top: displayTop,
      left: left,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: estaArrastrando ? null : () => widget.onTapCita(cita),
        onLongPressStart: (d) => setState(() {
          _citaArrastrada = cita;
          _dragTop = top;
          _dragOffsetY = d.localPosition.dy;
        }),
        onLongPressMoveUpdate: (d) {
          final totalHoras = _AgendaTimeline.finHora - _AgendaTimeline.inicioHora;
          final maxTop = totalHoras * _AgendaTimeline.alturaHora - height;
          setState(() {
            _dragTop = (top + d.offsetFromOrigin.dy - _dragOffsetY + d.localOffsetFromOrigin.dy)
                .clamp(0.0, maxTop);
          });
        },
        onLongPressEnd: (_) => _commitDrag(cita),
        onLongPressCancel: () => setState(() => _citaArrastrada = null),
        child: Opacity(opacity: estaArrastrando ? 0.92 : 1.0, child: contenido),
      ),
    );
  }

  /// Construye el contenido interno de un bloque de cita
  /// sin usar Column(mainAxisSize.min) — evita cualquier overflow vertical.
  Widget _buildCitaContenido({
    required double height,
    required String nombre,
    required String subtitulo,
    String? nota,
    required String estado,
    required bool arrastrandoIcon,
    required bool mostrarBadge,
  }) {
    // < 18px: solo color (sin texto)
    if (height < 18) return const SizedBox.shrink();

    // 18-26px: solo nombre en una línea
    if (height < 26) {
      return Text(nombre,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
          maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    // 26-42px: nombre + badge, sin segunda línea
    if (height < 42) {
      return Row(children: [
        Expanded(child: Text(nombre,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (arrastrandoIcon)
          const Icon(Icons.drag_indicator, size: 10, color: Colors.white70)
        else if (mostrarBadge)
          _EstadoBadge(estado: estado),
      ]);
    }

    // >= 42px: nombre + badge + subtítulo (+ nota si hay espacio)
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(nombre,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (arrastrandoIcon)
            const Icon(Icons.drag_indicator, size: 10, color: Colors.white70)
          else if (mostrarBadge)
            _EstadoBadge(estado: estado),
        ]),
        const SizedBox(height: 1),
        Text(subtitulo,
            style: const TextStyle(fontSize: 8, color: Colors.white70),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        if (nota != null && height > 58) ...[
          const SizedBox(height: 1),
          Text(nota,
              style: const TextStyle(fontSize: 8, color: Colors.white60, fontStyle: FontStyle.italic),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }

  String _horaDesdeTop(double top) {
    final min = (top / _AgendaTimeline.alturaHora * 60).round();
    final minRound = (min / 15).round() * 15;
    final h = (minRound ~/ 60) + _AgendaTimeline.inicioHora;
    final m = minRound % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
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
        label = '▶';
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
  final Color colorPrimario;

  const _DialogoNuevaCita({
    required this.empresaId,
    required this.fecha,
    this.profIdInicial,
    this.esAdmin = true,
    this.colorPrimario = kPelPrimario,
  });

  @override
  State<_DialogoNuevaCita> createState() => _DialogoNuevaCitaState();
}

/// Devuelve el slot de 30 min más cercano a la hora actual,
/// siempre dentro del rango de la agenda (08:00–20:30).
String _horaInicioSugerida() {
  final ahora = DateTime.now();
  // Redondear al bloque de 30 min más próximo hacia abajo
  final minutos = (ahora.hour * 60 + ahora.minute);
  final slot = (minutos ~/ 30) * 30;
  final h = (slot ~/ 60).clamp(8, 20);
  final m = slot % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

class _DialogoNuevaCitaState extends State<_DialogoNuevaCita> {
  final _clienteCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  bool _clienteNuevo = true;
  String? _clienteExistenteId;
  String? _clienteExistenteNombre;
  List<Map<String, dynamic>> _clientesBuscados = [];
  bool _buscandoClientes = false;
  Timer? _debounceClientes;
  String? _profId;
  String _horaInicio = _horaInicioSugerida();
  int _duracion = 30;
  final List<Map<String, dynamic>> _servicios = [];
  bool _guardando = false;
  String _catFiltro = 'Todos';

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

  void _buscarClientes(String query) {
    _debounceClientes?.cancel();
    if (query.isEmpty) {
      setState(() { _clientesBuscados = []; _buscandoClientes = false; });
      return;
    }
    setState(() => _buscandoClientes = true);
    _debounceClientes = Timer(const Duration(milliseconds: 300), () async {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('clientes')
            .orderBy('nombre')
            .limit(30)
            .get();
        final q = query.toLowerCase();
        final resultados = snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .where((c) => ((c['nombre'] as String?) ?? '').toLowerCase().contains(q) ||
                ((c['telefono'] as String?) ?? '').contains(q))
            .take(8)
            .toList();
        if (mounted) setState(() { _clientesBuscados = resultados; _buscandoClientes = false; });
      } catch (_) {
        if (mounted) setState(() => _buscandoClientes = false);
      }
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
    _debounceClientes?.cancel();
    _clienteCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  double get _importeTotal => _servicios.fold(
      0.0,
          (s, e) => s + ((e['precio'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    final slots = generarSlots();

    final primario = widget.colorPrimario;
    // Panel flotante desde la derecha — no toca ningún borde
    final topPad = MediaQuery.of(context).viewPadding.top;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, topPad + 12, 16, 20),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: Container(
          width: 460,
          height: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(-6, 4),
              ),
            ],
          ),
          child: Column(children: [
            // ── Header estilo tarjeta ───────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
              decoration: BoxDecoration(
                color: primario.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: primario.withValues(alpha: 0.15))),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primario.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_today_rounded, color: primario, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nueva cita',
                        style: TextStyle(color: primario, fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(widget.fecha,
                        style: TextStyle(fontSize: 12, color: primario.withValues(alpha: 0.7))),
                  ],
                )),
                IconButton(
                  icon: Icon(Icons.close, color: primario, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ]),
            ),
            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Toggle Nuevo / Existente ──────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _clienteNuevo = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _clienteNuevo ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _clienteNuevo
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                          : null,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.person_add_outlined, size: 14,
                          color: _clienteNuevo ? primario : Colors.grey),
                      const SizedBox(width: 5),
                      Text('Cliente nuevo',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: _clienteNuevo ? primario : Colors.grey)),
                    ]),
                  ),
                )),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _clienteNuevo = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_clienteNuevo ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: !_clienteNuevo
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                          : null,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search, size: 14,
                          color: !_clienteNuevo ? primario : Colors.grey),
                      const SizedBox(width: 5),
                      Text('Existente',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: !_clienteNuevo ? primario : Colors.grey)),
                    ]),
                  ),
                )),
              ]),
            ),
            const SizedBox(height: 12),
            // ── Campos cliente ────────────────────────────────────
            if (_clienteNuevo) ...[
              TextField(
                controller: _clienteCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                )),
              ]),
            ] else ...[
              // Buscador igual al del ticket (sin crear cliente)
              _ClienteBuscadorCita(
                empresaId: widget.empresaId,
                primario: primario,
                onSeleccionado: (c) => setState(() {
                  _clienteExistenteId = c['id'] as String?;
                  _clienteExistenteNombre = c['nombre'] as String?;
                  _telefonoCtrl.text = (c['telefono'] as String?) ?? '';
                  _emailCtrl.text = (c['correo'] as String?) ?? (c['email'] as String?) ?? '';
                }),
              ),
              if (_clienteExistenteNombre != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primario.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primario.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Icon(Icons.person, color: primario, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_clienteExistenteNombre!,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primario))),
                    GestureDetector(
                      onTap: () => setState(() {
                        _clienteExistenteId = null;
                        _clienteExistenteNombre = null;
                      }),
                      child: Icon(Icons.close, size: 14, color: primario),
                    ),
                  ]),
                ),
            ],
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
                          child: CircularProgressIndicator(strokeWidth: 2)));
                }
                final todosServicios = snap.data!.docs.map((d) {
                  final m = d.data() as Map<String, dynamic>;
                  return {
                    'id': d.id,
                    'nombre': m['nombre'] as String? ?? '',
                    'precio': (m['precio'] as num?)?.toDouble() ?? 0.0,
                    'categoria': m['categoria'] as String? ?? 'General',
                  };
                }).toList();

                if (todosServicios.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Sin servicios configurados. Añade servicios desde el catálogo del panel derecho.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                }

                final cats = {'Todos', ...todosServicios.map((s) => s['categoria'] as String)};
                final serviciosFiltrados = _catFiltro == 'Todos'
                    ? todosServicios
                    : todosServicios.where((s) => s['categoria'] == _catFiltro).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chips de categoría
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: cats.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c, style: const TextStyle(fontSize: 11)),
                            selected: _catFiltro == c,
                            onSelected: (_) => setState(() => _catFiltro = c),
                            selectedColor: primario.withValues(alpha: 0.15),
                            labelStyle: TextStyle(color: _catFiltro == c ? primario : Colors.grey.shade600),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            visualDensity: VisualDensity.compact,
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Lista de servicios con divisores
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          itemCount: serviciosFiltrados.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Colors.grey.shade200,
                            indent: 12,
                            endIndent: 12,
                          ),
                          itemBuilder: (_, i) {
                            final s = serviciosFiltrados[i];
                            final seleccionado = _servicios.any((e) => e['id'] == s['id']);
                            return CheckboxListTile(
                              dense: true,
                              value: seleccionado,
                              activeColor: primario,
                              title: Text(s['nombre'] as String,
                                  style: const TextStyle(fontSize: 12)),
                              secondary: Text(
                                NumberFormat.currency(symbol: '€', decimalDigits: 2)
                                    .format(s['precio']),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _servicios.add(Map<String, dynamic>.from(s));
                                  } else {
                                    _servicios.removeWhere((e) => e['id'] == s['id']);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
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
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _TpvTemaScope.primarioOf(context)),
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
            // ── Footer ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: (_guardando ||
                      (_clienteNuevo
                          ? _clienteCtrl.text.trim().isEmpty
                          : _clienteExistenteNombre == null) ||
                      _profId == null ||
                      _profId == '__todos__')
                      ? null
                      : _guardar,
                  style: FilledButton.styleFrom(
                    backgroundColor: primario,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _guardando
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Guardar cita', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      ),
    ));
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
        'cliente_nombre': _clienteNuevo
            ? _clienteCtrl.text.trim()
            : _clienteExistenteNombre,
        'cliente_id': _clienteNuevo ? null : _clienteExistenteId,
        'cliente_telefono': _telefonoCtrl.text.trim().isEmpty
            ? null : _telefonoCtrl.text.trim(),
        'cliente_email': _emailCtrl.text.trim().isEmpty
            ? null : _emailCtrl.text.trim(),
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
        FluxToast.error(context, 'Error: $e');
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
                backgroundColor: _TpvTemaScope.primarioOf(context)),
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
          style: TextStyle(
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
              backgroundColor: _TpvTemaScope.primarioOf(context),
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
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _TpvTemaScope.primarioOf(context))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(t.clienteNombre,
                                style: TextStyle(
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
                          backgroundColor: _TpvTemaScope.primarioOf(context),
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
      FluxToast.exito(context, '${turno.clienteNombre} — servicios en el ticket');
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
                  'categoria':
                  m['categoria'] as String? ?? 'General',
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
                      activeColor: _TpvTemaScope.primarioOf(context),
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
          style: FilledButton.styleFrom(backgroundColor: _TpvTemaScope.primarioOf(context)),
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
                      backgroundColor: _TpvTemaScope.primarioOf(context)),
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
                      backgroundColor: _TpvTemaScope.primarioOf(context)),
                ),
            ]),
          );
        }

        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Text('${docs.length} cabinas',
                  style: TextStyle(
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
                        _TpvTemaScope.primarioOf(context).withValues(alpha: 0.5);
                    bgColor = kPelPrimarioLight;
                    iconColor = _TpvTemaScope.primarioOf(context);
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
                          style: TextStyle(
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
                  style: TextStyle(
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
                backgroundColor: _TpvTemaScope.primarioOf(context)),
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
  final VoidCallback? onEnEspera;
  final int descuentoMaxPct;

  const _ColTicket({
    required this.empresaId,
    required this.lineas,
    required this.extra,
    required this.onServicioAdded,
    required this.onServicioRemoved,
    required this.onExtraChanged,
    required this.onCobrar,
    required this.onLimpiar,
    this.onEnEspera,
    this.descuentoMaxPct = 100,
  });

  @override
  State<_ColTicket> createState() => _ColTicketState();
}

class _ColTicketState extends State<_ColTicket> {
  String _catFiltro = 'Todos';
  final _clienteCtrl = TextEditingController();
  List<String> _sugerenciasServicios = [];

  @override
  void dispose() {
    _clienteCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => widget.lineas
      .fold(0.0, (s, l) => s + ((l['precio'] as num?)?.toDouble() ?? 0));
  double get _total =>
      (_subtotal - widget.extra.descuentoBono - widget.extra.descuento + widget.extra.propina)
          .clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final tema = _TpvTemaScope.of(context);

    return Column(children: [
      // ── Cliente ──────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tema.divisor))),
        child: Column(children: [
          Row(children: [
            Icon(Icons.person_outline, size: 14, color: tema.textoSecundario),
            const SizedBox(width: 6),
            Text(
              widget.extra.nombreCliente ?? 'Sin cliente',
              style: TextStyle(
                fontSize: 12,
                color: widget.extra.nombreCliente != null
                    ? tema.textoPrimario
                    : tema.textoSecundario,
                fontWeight: widget.extra.nombreCliente != null
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            const Spacer(),
            // Botón ficha cliente
            if (widget.extra.clienteId != null) ...[
              GestureDetector(
                onTap: () => _abrirFichaCliente(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.open_in_new, size: 13, color: tema.primario),
                ),
              ),
            ],
            if (widget.extra.nombreCliente != null)
              GestureDetector(
                onTap: () {
                  _clienteCtrl.clear();
                  widget.onExtraChanged(
                      widget.extra.copyWith(limpiarCliente: true));
                },
                child: Icon(Icons.close, size: 14, color: tema.textoSecundario),
              ),
          ]),
          const SizedBox(height: 6),
          _ClienteBuscador(
            empresaId: widget.empresaId,
            controller: _clienteCtrl,
            onSeleccionado: (c) {
              _clienteCtrl.text = c['nombre'] as String? ?? '';
              final bono = c['bono_activo'] as Map<String, dynamic>?;
              final dto  = (bono?['descuento_por_sesion'] as num?)?.toDouble() ?? 0;
              widget.onExtraChanged(widget.extra.copyWith(
                nombreCliente: c['nombre'] as String?,
                clienteId: c['id'] as String?,
                descuentoBono: dto,
              ));
              // Mostrar sugerencias de servicios anteriores
              final prevServ = (c['ultimo_servicio'] as List?)?.cast<String>() ?? [];
              if (prevServ.isNotEmpty && mounted) {
                setState(() => _sugerenciasServicios = prevServ);
              }
            },
          ),
        ]),
      ),

      // ── Sugerencias de servicios anteriores ─────────────────────────
      if (_sugerenciasServicios.isNotEmpty)
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tema.divisor))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.history, size: 12, color: tema.textoSecundario),
                const SizedBox(width: 4),
                Text('Volver a pedir', style: TextStyle(fontSize: 11,
                    color: tema.textoSecundario, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _sugerenciasServicios = []),
                  child: Icon(Icons.close, size: 12, color: tema.textoSecundario),
                ),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4,
                children: _sugerenciasServicios.map((nombre) =>
                  GestureDetector(
                    onTap: () => widget.onServicioAdded({
                      'nombre': nombre,
                      'precio': 0.0, // precio actualizado al cobrar
                      'iva_porcentaje': 21.0,
                      'precio_con_iva': false,
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: tema.primario.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tema.primario.withValues(alpha: 0.3))),
                      child: Text(nombre, style: TextStyle(fontSize: 11,
                          color: tema.primario, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ).toList(),
              ),
            ],
          ),
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
                'precio': (m['precio'] as num?)?.toDouble() ?? 0.0,
                'categoria': m['categoria'] as String? ?? 'General',
                'iva_porcentaje': (m['iva_porcentaje'] as num?)?.toDouble() ?? 21.0,
                'precio_con_iva': m['precio_con_iva'] as bool? ?? false,
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
                          style: TextStyle(
                              fontSize: 10)),
                      selected: _catFiltro == c,
                      onSelected: (_) => setState(
                              () => _catFiltro = c),
                      selectedColor: tema.primario.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                          color: _catFiltro == c
                              ? tema.primario
                              : tema.textoSecundario),
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
                child: ListView.separated(
                  itemCount: servicios.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: tema.divisor,
                    indent: 12,
                    endIndent: 12,
                  ),
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
                                style: TextStyle(
                                    fontSize: 12, color: tema.textoPrimario)),
                          ),
                          Text(
                            fmt.format(s['precio']),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: tema.textoPrimario),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.add_circle_outline,
                              size: 18,
                              color: tema.primario.withValues(alpha: 0.7)),
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
          color: tema.textoPrimario.withValues(alpha: 0.05),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              child: Row(children: [
                Text('Ticket',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tema.textoSecundario)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onLimpiar,
                  child: const Text('Limpiar',
                      style: TextStyle(
                          fontSize: 10, color: Colors.red)),
                ),
              ]),
            ),
            // Agrupar líneas con el mismo nombre
            ...() {
              final grupos = _agruparLineas(widget.lineas);
              return grupos.asMap().entries.expand((e) {
                final idx = e.key;
                final grupo = e.value;
                final count = grupo['count'] as int;
                final nombre = grupo['nombre'] as String? ?? '';
                final precio = (grupo['precio'] as num?)?.toDouble() ?? 0;
                final lastIndex = grupo['lastIndex'] as int;
                final total = count > 1 ? precio * count : precio;
                return [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          count > 1 ? '$nombre  ×$count' : nombre,
                          style: TextStyle(fontSize: 11, color: tema.textoPrimario),
                        ),
                      ),
                      Text(
                        fmt.format(total),
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: tema.textoPrimario),
                      ),
                      const SizedBox(width: 4),
                      // Descuento por línea
                      GestureDetector(
                        onTap: () async {
                          final res = await DescuentoLineaWidget.mostrar(
                            context,
                            nombreProducto: nombre,
                            precioOriginal: precio,
                            cantidad: count,
                            maxPct: widget.descuentoMaxPct,
                          );
                          if (res != null && res.importe > 0) {
                            widget.onExtraChanged(
                              widget.extra.copyWith(
                                descuento: widget.extra.descuento + res.importe,
                              ),
                            );
                          }
                        },
                        child: Icon(Icons.local_offer_outlined, size: 14,
                            color: tema.primario.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () => widget.onServicioRemoved(lastIndex),
                        child: Icon(Icons.close, size: 14, color: Colors.red.shade300),
                      ),
                    ]),
                  ),
                  if (idx < grupos.length - 1)
                    Divider(height: 1, thickness: 0.5, color: tema.divisor, indent: 12, endIndent: 12),
                ];
              });
            }(),
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
                      style: TextStyle(
                          fontSize: 11, color: Colors.green)),
                ]),
              ),
            if (widget.extra.descuento > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 2),
                child: Row(children: [
                  const Text('Descuento',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange)),
                  const Spacer(),
                  Text(
                      '−${fmt.format(widget.extra.descuento)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => widget.onExtraChanged(
                        widget.extra.copyWith(descuento: 0)),
                    child: const Icon(Icons.close, size: 12, color: Colors.orange),
                  ),
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
                      style: TextStyle(
                          fontSize: 11, color: Colors.blue)),
                ]),
              ),
          ]),
        ),

      // ── Footer cobro ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tema.superficie,
          border: Border(top: BorderSide(color: tema.divisor)),
        ),
        child: Column(children: [
          if (widget.lineas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                // ── Propina ──
                Expanded(
                  child: GestureDetector(
                    onTap: () => _mostrarDialogoPropina(context, tema),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.extra.propina > 0
                            ? tema.primario.withValues(alpha: 0.1)
                            : tema.textoPrimario.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.extra.propina > 0 ? tema.primario : tema.divisor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          widget.extra.propina > 0
                              ? Icons.tips_and_updates : Icons.add_circle_outline,
                          size: 13,
                          color: widget.extra.propina > 0 ? tema.primario : tema.textoSecundario),
                        const SizedBox(width: 5),
                        Flexible(child: Text(
                          widget.extra.propina > 0
                              ? '+${widget.extra.propina.toStringAsFixed(2)}€'
                              : 'Propina',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: widget.extra.propina > 0 ? tema.primario : tema.textoSecundario,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )),
                        if (widget.extra.propina > 0) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => widget.onExtraChanged(widget.extra.copyWith(propina: 0)),
                            child: Icon(Icons.close, size: 12, color: tema.textoSecundario),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ── Descuento ──
                Expanded(
                  child: GestureDetector(
                    onTap: () => _mostrarDialogoDescuento(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.extra.descuento > 0
                            ? Colors.orange.withValues(alpha: 0.1)
                            : tema.textoPrimario.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.extra.descuento > 0 ? Colors.orange : tema.divisor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          widget.extra.descuento > 0
                              ? Icons.local_offer : Icons.add_circle_outline,
                          size: 13,
                          color: widget.extra.descuento > 0 ? Colors.orange : tema.textoSecundario),
                        const SizedBox(width: 5),
                        Flexible(child: Text(
                          widget.extra.descuento > 0
                              ? '−${fmt.format(widget.extra.descuento)}'
                              : 'Descuento',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: widget.extra.descuento > 0 ? Colors.orange : tema.textoSecundario,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )),
                        if (widget.extra.descuento > 0) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => widget.onExtraChanged(widget.extra.copyWith(descuento: 0)),
                            child: Icon(Icons.close, size: 12, color: tema.textoSecundario),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: tema.textoPrimario)),
                Text(
                  fmt.format(_total),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: tema.primario),
                ),
              ]),
          const SizedBox(height: 10),
          // ── Cupón de descuento ─────────────────────────────────────────
          if (widget.lineas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CuponInputWidget(
                empresaId: widget.empresaId,
                totalBase: _total,
                onAplicado: (cuponId, descuento) {
                  widget.onExtraChanged(
                    widget.extra.copyWith(descuento: descuento),
                  );
                },
                onRetirar: () {
                  widget.onExtraChanged(
                    widget.extra.copyWith(descuento: 0),
                  );
                },
              ),
            ),
          // ── Fila botones: En espera + Cobrar ───────────────────────────
          Row(
            children: [
              if (widget.onEnEspera != null) ...[
                OutlinedButton.icon(
                  onPressed: widget.lineas.isEmpty ? null : widget.onEnEspera,
                  icon: const Icon(Icons.pause_circle_outline, size: 15),
                  label: const Text('En espera', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tema.primario,
                    side: BorderSide(color: tema.primario.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: widget.lineas.isEmpty ? null : widget.onCobrar,
                  style: FilledButton.styleFrom(
                    backgroundColor: tema.primario,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Cobrar ${fmt.format(_total)}',
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ]),
      ),
    ]);
  }

  /// Abre un bottom sheet con el historial de actividad del cliente.
  void _abrirFichaCliente(BuildContext context) {
    final clienteId = widget.extra.clienteId;
    if (clienteId == null) return;
    final tema = _TpvTemaScope.of(context);
    final fmt  = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final dateFmt = DateFormat('dd/MM/yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tema.superficie,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        builder: (_, sc) => FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('empresas').doc(widget.empresaId)
              .collection('clientes').doc(clienteId).get(),
          builder: (_, snap) {
            final d = snap.data?.data() as Map<String, dynamic>? ?? {};
            final nombre        = d['nombre'] as String? ?? widget.extra.nombreCliente ?? '—';
            final telefono      = d['telefono'] as String? ?? '';
            final numVisitas    = (d['num_visitas'] as num?)?.toInt() ?? 0;
            final totalGastado  = (d['total_gastado'] as num?)?.toDouble() ?? 0.0;
            final ultimaVisita  = (d['ultima_visita'] as Timestamp?)?.toDate();
            final ultimoServ    = (d['ultimo_servicio'] as List?)?.cast<String>() ?? [];
            final notas         = d['notas'] as String? ?? '';

            return Column(children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: tema.textoPrimario.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Cabecera
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: tema.primario.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: Center(child: Text(
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                            color: tema.primario))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700, color: tema.textoPrimario)),
                      if (telefono.isNotEmpty)
                        Text(telefono, style: TextStyle(fontSize: 12,
                            color: tema.textoSecundario)),
                    ],
                  )),
                ]),
              ),
              Divider(color: tema.divisor, height: 1),
              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                child: Row(children: [
                  _FichaChip(label: 'Visitas', valor: '$numVisitas', color: tema.primario),
                  const SizedBox(width: 10),
                  _FichaChip(label: 'Total gastado', valor: fmt.format(totalGastado), color: Colors.green),
                  const SizedBox(width: 10),
                  if (ultimaVisita != null)
                    _FichaChip(label: 'Última visita', valor: dateFmt.format(ultimaVisita), color: tema.textoSecundario),
                ]),
              ),
              if (ultimoServ.isNotEmpty) ...[
                Divider(color: tema.divisor, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Text('Último servicio', style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600, color: tema.textoSecundario)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(ultimoServ.join(', '),
                      style: TextStyle(fontSize: 13, color: tema.textoPrimario)),
                ),
              ],
              if (notas.isNotEmpty) ...[
                Divider(color: tema.divisor, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Text('Notas', style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600, color: tema.textoSecundario)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(notas, style: TextStyle(fontSize: 13,
                      color: tema.textoPrimario, fontStyle: FontStyle.italic)),
                ),
              ],
              // Actividad reciente
              Divider(color: tema.divisor, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: Text('Actividad reciente', style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600, color: tema.textoSecundario)),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('empresas').doc(widget.empresaId)
                      .collection('clientes').doc(clienteId)
                      .collection('actividad')
                      .orderBy('fecha', descending: true).limit(10)
                      .snapshots(),
                  builder: (_, snapAct) {
                    final items = snapAct.data?.docs ?? [];
                    if (items.isEmpty) {
                      return Center(child: Text('Sin actividad',
                          style: TextStyle(color: tema.textoSecundario)));
                    }
                    return ListView.separated(
                      controller: sc,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(color: tema.divisor, height: 1),
                      itemBuilder: (_, i) {
                        final a = items[i].data() as Map<String, dynamic>;
                        final desc   = a['descripcion'] as String? ?? '';
                        final importe = (a['importe'] as num?)?.toDouble();
                        final fecha  = (a['fecha'] as Timestamp?)?.toDate();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.receipt_outlined, size: 16, color: tema.primario),
                          title: Text(desc, style: TextStyle(fontSize: 12,
                              color: tema.textoPrimario)),
                          subtitle: fecha != null
                              ? Text(dateFmt.format(fecha),
                                  style: TextStyle(fontSize: 11, color: tema.textoSecundario))
                              : null,
                          trailing: importe != null
                              ? Text(fmt.format(importe), style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: tema.primario))
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _agruparLineas(List<Map<String, dynamic>> lineas) {
    final Map<String, Map<String, dynamic>> grupos = {};
    final Map<String, int> ultimoIndice = {};
    for (int i = 0; i < lineas.length; i++) {
      final l = lineas[i];
      final key = (l['id'] as String?)?.isNotEmpty == true
          ? l['id'] as String
          : (l['nombre'] as String? ?? '');
      if (grupos.containsKey(key)) {
        grupos[key]!['count'] = (grupos[key]!['count'] as int) + 1;
        ultimoIndice[key] = i;
      } else {
        grupos[key] = Map<String, dynamic>.from(l)..['count'] = 1;
        ultimoIndice[key] = i;
      }
    }
    return grupos.entries.map((e) {
      return {...e.value, 'lastIndex': ultimoIndice[e.key]!};
    }).toList();
  }

  void _mostrarDialogoPropina(BuildContext context, _TpvTema tema) {
    final ctrl = TextEditingController(
      text: widget.extra.propina > 0
          ? widget.extra.propina.toStringAsFixed(2) : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tema.superficie,
        title: Text('Propina',
            style: TextStyle(color: tema.textoPrimario, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: tema.textoPrimario),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0,00',
            hintStyle: TextStyle(color: tema.textoSecundario),
            prefix: Text('€ ', style: TextStyle(fontSize: 20, color: tema.textoSecundario)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: tema.primario, width: 2)),
            filled: true,
            fillColor: tema.textoPrimario.withValues(alpha: 0.04),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: tema.textoSecundario),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (val != null && val >= 0) {
                widget.onExtraChanged(widget.extra.copyWith(propina: val));
              }
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: tema.primario),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoDescuento(BuildContext context) {
    final ctrl = TextEditingController(
      text: widget.extra.descuento > 0
          ? widget.extra.descuento.toStringAsFixed(2)
          : '',
    );
    bool esPorcentaje = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Aplicar descuento'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: esPorcentaje ? 'Porcentaje (%)' : 'Importe (€)',
                    prefixIcon: Icon(
                      esPorcentaje ? Icons.percent : Icons.euro,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Switch(
                value: esPorcentaje,
                onChanged: (v) => setS(() => esPorcentaje = v),
              ),
              Text(esPorcentaje ? 'Porcentaje' : 'Importe fijo',
                  style: const TextStyle(fontSize: 12)),
            ]),
          ]),
          actions: [
            TextButton(
              onPressed: () {
                widget.onExtraChanged(widget.extra.copyWith(descuento: 0));
                Navigator.pop(ctx);
              },
              child: const Text('Quitar', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final val = double.tryParse(
                    ctrl.text.replaceAll(',', '.')) ?? 0;
                final importe = esPorcentaje
                    ? (_subtotal * val / 100)
                    : val;
                widget.onExtraChanged(
                    widget.extra.copyWith(descuento: importe.clamp(0, _subtotal)));
                Navigator.pop(ctx);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Buscador cliente ─────────────────────────────────────────────────────────

// ── Buscador para el diálogo de nueva cita (sin opción de crear) ─────────────

class _ClienteBuscadorCita extends StatefulWidget {
  final String empresaId;
  final Color primario;
  final ValueChanged<Map<String, dynamic>> onSeleccionado;

  const _ClienteBuscadorCita({
    required this.empresaId,
    required this.primario,
    required this.onSeleccionado,
  });

  @override
  State<_ClienteBuscadorCita> createState() => _ClienteBuscadorCitaState();
}

class _ClienteBuscadorCitaState extends State<_ClienteBuscadorCita> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  bool _cargado = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        if (!_cargado) _cargarTodos();
        if (_ctrl.text.isEmpty) setState(() => _resultados = List.from(_todos));
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _resultados = []);
        });
      }
    });
    _cargarTodos();
  }

  Future<void> _cargarTodos() async {
    setState(() => _buscando = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes')
          .orderBy('nombre')
          .limit(50)
          .get();
      if (mounted) {
        final lista = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        setState(() {
          _todos = lista;
          _cargado = true;
          if (_ctrl.text.isEmpty) _resultados = List.from(lista);
          _buscando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.isEmpty) { setState(() => _resultados = List.from(_todos)); return; }
    final q = v.toLowerCase();
    setState(() => _resultados = _todos.where((c) =>
        ((c['nombre'] ?? '') as String).toLowerCase().contains(q) ||
        ((c['telefono'] ?? '') as String).contains(q)).toList());
    if (_resultados.length < 3 && v.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        if (!mounted) return;
        setState(() => _buscando = true);
        try {
          final snap = await FirebaseFirestore.instance
              .collection('empresas').doc(widget.empresaId).collection('clientes')
              .where('nombre', isGreaterThanOrEqualTo: v)
              .where('nombre', isLessThan: '${v}z').limit(10).get();
          final remotos = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          final ids = _resultados.map((c) => c['id']).toSet();
          if (mounted) setState(() {
            _resultados = [..._resultados, ...remotos.where((c) => !ids.contains(c['id']))];
            _buscando = false;
          });
        } catch (_) { if (mounted) setState(() => _buscando = false); }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.primario;
    return Column(children: [
      TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar cliente…',
          prefixIcon: Icon(Icons.search, size: 16, color: p.withValues(alpha: 0.7)),
          suffixIcon: _buscando
              ? const SizedBox(width: 16, height: 16,
                  child: Padding(padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14),
                      onPressed: () { _ctrl.clear(); setState(() => _resultados = List.from(_todos)); },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28))
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: p, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true, filled: true, fillColor: Colors.grey.shade50,
        ),
        style: const TextStyle(fontSize: 12),
      ),
      if (_resultados.isNotEmpty) ...[
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6)],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _resultados.take(6).length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (_, i) {
              final c = _resultados[i];
              final nombre = c['nombre'] as String? ?? '';
              final telefono = c['telefono'] as String? ?? '';
              return InkWell(
                onTap: () {
                  widget.onSeleccionado(c);
                  _ctrl.text = nombre;
                  setState(() => _resultados = []);
                  _focus.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: p.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Center(child: Text(
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p),
                      )),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        if (telefono.isNotEmpty)
                          Text(telefono, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    )),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
  List<Map<String, dynamic>> _todos = [];   // todos los clientes cargados
  List<Map<String, dynamic>> _resultados = []; // lista filtrada visible
  bool _buscando = false;
  bool _cargadoTodos = false;
  Timer? _debounce;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        if (!_cargadoTodos) _cargarTodos();
        if (widget.controller.text.isEmpty) {
          setState(() => _resultados = List.from(_todos));
        }
      } else {
        // Cerrar lista al perder el foco
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _resultados = []);
        });
      }
    });
  }

  Future<void> _cargarTodos() async {
    setState(() => _buscando = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes')
          .orderBy('nombre')
          .limit(50)
          .get();
      if (mounted) {
        final lista = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        setState(() {
          _todos = lista;
          _cargadoTodos = true;
          if (widget.controller.text.isEmpty) _resultados = List.from(lista);
          _buscando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _onChanged(String valor) {
    _debounce?.cancel();

    // Filtro inmediato client-side sobre la lista cargada
    if (valor.isEmpty) {
      setState(() => _resultados = List.from(_todos));
      return;
    }

    final filtroLocal = _todos.where((c) {
      final nombre = ((c['nombre'] ?? '') as String).toLowerCase();
      return nombre.contains(valor.toLowerCase());
    }).toList();

    setState(() => _resultados = filtroLocal);

    // Si hay pocas coincidencias locales, buscar también en Firestore
    if (filtroLocal.length < 3 && valor.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        setState(() => _buscando = true);
        final q = FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('clientes');

        var snap = await q
            .where('nombre_lower',
                isGreaterThanOrEqualTo: valor.toLowerCase())
            .where('nombre_lower',
                isLessThan: '${valor.toLowerCase()}z')
            .limit(10)
            .get();

        if (snap.docs.isEmpty) {
          snap = await q
              .where('nombre', isGreaterThanOrEqualTo: valor)
              .where('nombre', isLessThan: '${valor}z')
              .limit(10)
              .get();
        }

        final remotos = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();

        // Merge: locales + remotos sin duplicados
        final ids = filtroLocal.map((c) => c['id']).toSet();
        final merged = [
          ...filtroLocal,
          ...remotos.where((c) => !ids.contains(c['id'])),
        ];

        if (mounted) setState(() { _resultados = merged; _buscando = false; });
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = _TpvTemaScope.of(context);
    return Column(children: [
      TextField(
        controller: widget.controller,
        focusNode: _focus,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: 'Buscar cliente…',
          hintStyle: TextStyle(fontSize: 12, color: tema.textoSecundario),
          prefixIcon: Icon(Icons.search, size: 16, color: tema.textoSecundario),
          suffixIcon: _buscando
              ? const SizedBox(width: 16, height: 16,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2)))
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 14, color: tema.textoSecundario),
                      onPressed: () {
                        widget.controller.clear();
                        setState(() => _resultados = List.from(_todos));
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    )
                  : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: tema.divisor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: tema.divisor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: tema.primario, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
          filled: true,
          fillColor: tema.textoPrimario.withValues(alpha: 0.04),
        ),
        style: TextStyle(fontSize: 12, color: tema.textoPrimario),
      ),
      if (_resultados.isNotEmpty || (widget.controller.text.length >= 2 && !_buscando))
        Builder(builder: (ctx) {
          // Máximo 5 resultados visibles; altura de cada ítem ≈ 52px
          const alturaItem = 52.0;
          final visibles = _resultados.take(5).toList();
          final hayMas = _resultados.length > 5;
          final maxH = (visibles.length * alturaItem + (hayMas ? 30 : 0) + 40).clamp(0.0, 5 * alturaItem + 70.0);
          return Container(
          margin: const EdgeInsets.only(top: 4),
          constraints: BoxConstraints(maxHeight: maxH),
          decoration: BoxDecoration(
            color: tema.superficie,
            border: Border.all(color: tema.divisor),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
            ...visibles.map((c) {
              final nombre = c['nombre'] as String? ?? '';
              final telefono = c['telefono'] as String? ?? '';
              final bono = c['bono_activo'];
              return InkWell(
                onTap: () {
                  widget.onSeleccionado(c);
                  widget.controller.text = nombre;
                  setState(() => _resultados = []);
                  _focus.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(children: [
                    // Avatar inicial
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: tema.primario.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: tema.primario),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre,
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tema.textoPrimario)),
                          if (telefono.isNotEmpty)
                            Text(telefono,
                                style: TextStyle(fontSize: 10,
                                    color: tema.textoSecundario)),
                        ],
                      ),
                    ),
                    if (bono != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Bono',
                            style: TextStyle(fontSize: 9, color: Colors.green,
                                fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),
              );
            }).toList(),
            // ── Indicador "más resultados" ────────────────────────────
            if (hayMas)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  '+${_resultados.length - 5} resultados más — escribe para filtrar',
                  style: TextStyle(fontSize: 10, color: tema.textoSecundario,
                      fontStyle: FontStyle.italic),
                ),
              ),
            // ── Crear cliente nuevo: solo si no existe en resultados NI en la lista cargada ──
            if (widget.controller.text.length >= 2 &&
                !_resultados.any((c) =>
                    ((c['nombre'] ?? '') as String).toLowerCase() ==
                    widget.controller.text.trim().toLowerCase()) &&
                !_todos.any((c) =>
                    ((c['nombre'] ?? '') as String).toLowerCase() ==
                    widget.controller.text.trim().toLowerCase()))
              InkWell(
                onTap: () => _crearNuevoCliente(widget.controller.text.trim()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_outlined, size: 16, color: Colors.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Crear "${widget.controller.text.trim()}"',
                        style: const TextStyle(fontSize: 12, color: Colors.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
          ); // Container
        }), // Builder
    ]);
  }

  Future<void> _crearNuevoCliente(String nombre) async {
    final tema = _TpvTemaScope.of(context); // capturar antes de showDialog
    final telefonoCtrl  = TextEditingController();
    final emailCtrl     = TextEditingController();
    final notasCtrl     = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: tema.superficie,
        title: Text('Nuevo cliente',
            style: TextStyle(color: tema.textoPrimario)),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: tema.primario.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.person, color: tema.primario, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(nombre,
                      style: TextStyle(fontWeight: FontWeight.w700,
                          color: tema.textoPrimario))),
                ]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: 'Opcional',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Opcional',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notasCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Notas internas',
                    hintText: 'Alergias, preferencias… (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(), isDense: true),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: tema.textoSecundario),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: tema.primario),
              child: const Text('Crear cliente')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final docRef = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('clientes')
          .add({
        'nombre': nombre,
        'nombre_lower': nombre.toLowerCase(),
        if (telefonoCtrl.text.trim().isNotEmpty) 'telefono': telefonoCtrl.text.trim(),
        if (emailCtrl.text.trim().isNotEmpty)    'email': emailCtrl.text.trim(),
        if (notasCtrl.text.trim().isNotEmpty)    'notas': notasCtrl.text.trim(),
        'creado': FieldValue.serverTimestamp(),
        'activo': true,
        'num_visitas': 0,
        'total_gastado': 0.0,
        'origen': 'tpv_manual',
      });
      widget.onSeleccionado({
        'id': docRef.id,
        'nombre': nombre,
        'telefono': telefonoCtrl.text.trim(),
      });
      widget.controller.text = nombre;
      if (mounted) setState(() => _resultados = []);
      _focus.unfocus();
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error: $e');
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO DE PAGO
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoPago extends StatefulWidget {
  final double total;
  final double propina;
  final String empresaId;
  final _TpvTema tema;
  final bool mostrarPropina;
  const _DialogoPago({
    required this.total,
    required this.propina,
    required this.empresaId,
    required this.tema,
    this.mostrarPropina = true,
  });

  @override
  State<_DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<_DialogoPago> {
  String _metodo = 'efectivo';
  String? _metodoSecundario;
  final _ctrl = TextEditingController();
  final _ctrlMixto1 = TextEditingController();
  final _ctrlMixto2 = TextEditingController();
  double _cambio = 0;
  List<({String id, String emoji, String label})> _metodos = [
    (id: 'efectivo', emoji: '💵', label: 'Efectivo'),
    (id: 'tarjeta', emoji: '💳', label: 'Tarjeta'),
  ];

  @override
  void initState() {
    super.initState();
    _cargarMetodos();
  }

  Future<void> _cargarMetodos() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('tpv_cobro').get();
      if (!doc.exists) return;
      final habilitados = (doc.data()?['metodos_habilitados'] as List?)
          ?.map((e) => e.toString()).toSet() ?? {};
      final custom = (doc.data()?['metodos_custom'] as List?)
          ?.map((e) => e.toString()).toList() ?? [];
      if (habilitados.isEmpty) return;

      const base = [
        (id: 'efectivo',      emoji: '💵', label: 'Efectivo'),
        (id: 'tarjeta',       emoji: '💳', label: 'Tarjeta'),
        (id: 'bizum',         emoji: '📱', label: 'Bizum'),
        (id: 'transferencia', emoji: '🏦', label: 'Transferencia'),
        (id: 'cheque_regalo', emoji: '🎁', label: 'Cheque regalo'),
      ];
      final lista = <({String id, String emoji, String label})>[
        ...base.where((m) => habilitados.contains(m.id)),
        ...custom.asMap().entries
            .where((e) => habilitados.contains('custom_${e.key}'))
            .map((e) => (id: 'custom_${e.key}', emoji: '⚡', label: e.value)),
      ];
      if (lista.isNotEmpty && mounted) {
        setState(() {
          _metodos = lista;
          _metodo = lista.first.id;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _ctrlMixto1.dispose();
    _ctrlMixto2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    final tema = widget.tema;
    return AlertDialog(
      backgroundColor: tema.superficie,
      title: Text('Método de pago', style: TextStyle(color: tema.textoPrimario)),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tema.primario.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text('Total a cobrar',
                  style: TextStyle(fontSize: 12, color: tema.primario)),
              Text(fmt.format(widget.total),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
                      color: tema.primario)),
              if (widget.propina > 0)
                Text('incl. propina ${fmt.format(widget.propina)}',
                    style: TextStyle(fontSize: 10, color: tema.textoSecundario)),
            ]),
          ),
          const SizedBox(height: 12),
          // Método primario
          Text('Método de pago:',
              style: TextStyle(fontSize: 11, color: tema.textoSecundario)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6,
            children: _metodos.map((m) => _PelChip(
              label: '${m.emoji}  ${m.label}',
              icon: m.id == 'efectivo' ? Icons.payments_outlined : Icons.credit_card,
              selected: _metodo == m.id,
              onTap: () => setState(() {
                _metodo = m.id;
                if (_metodoSecundario == m.id) _metodoSecundario = null;
              }),
            )).toList(),
          ),
          const SizedBox(height: 12),
          // Segundo método opcional
          Text('También pago con (opcional):',
              style: TextStyle(fontSize: 11, color: tema.textoSecundario)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6,
            children: [
              ..._metodos.where((m) => m.id != _metodo).map((m) => _PelChip(
                label: '${m.emoji}  ${m.label}',
                icon: m.id == 'efectivo' ? Icons.payments_outlined : Icons.credit_card,
                selected: _metodoSecundario == m.id,
                onTap: () => setState(() {
                  _metodoSecundario = _metodoSecundario == m.id ? null : m.id;
                  if (_metodoSecundario != null) {
                    _ctrlMixto1.text = (widget.total / 2).toStringAsFixed(2);
                    _ctrlMixto2.text = (widget.total / 2).toStringAsFixed(2);
                  }
                }),
              )),
            ],
          ),
          const SizedBox(height: 16),
          // Sin segundo método: comportamiento original
          if (_metodoSecundario == null) ...[
            if (_metodo == 'efectivo') ...[
              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Entrega del cliente (€)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                onChanged: (v) {
                  final e = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                  setState(() => _cambio = (e - widget.total).clamp(0, double.infinity));
                },
              ),
              if (_cambio > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cambio', style: TextStyle(color: Colors.green.shade800)),
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
                Icon(Icons.info_outline, size: 16,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text('Cobro por datáfono',
                    style: TextStyle(fontSize: 13,
                        color: Theme.of(context).colorScheme.primary)),
              ]),
            ],
          ],
          // Con segundo método: campos de importe dividido
          if (_metodoSecundario != null) ...[
            Text('Reparte el total ${fmt.format(widget.total)}:',
                style: TextStyle(fontSize: 11, color: tema.textoSecundario)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrlMixto1,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _metodos.firstWhere(
                            (m) => m.id == _metodo,
                        orElse: () => (id: _metodo, emoji: '', label: _metodo))
                        .label,
                    prefixText: '€ ',
                  ),
                  onChanged: (v) {
                    final v1 = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                    final v2 = (widget.total - v1).clamp(0, widget.total);
                    _ctrlMixto2.text = v2.toStringAsFixed(2);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrlMixto2,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _metodos.firstWhere(
                            (m) => m.id == _metodoSecundario,
                        orElse: () => (id: _metodoSecundario!, emoji: '', label: _metodoSecundario!))
                        .label,
                    prefixText: '€ ',
                  ),
                  onChanged: (v) {
                    final v2 = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                    final v1 = (widget.total - v2).clamp(0, widget.total);
                    _ctrlMixto1.text = v1.toStringAsFixed(2);
                  },
                ),
              ),
            ]),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: tema.textoSecundario),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: tema.primario),
          onPressed: () {
            if (_metodoSecundario != null) {
              final imp1 = double.tryParse(
                  _ctrlMixto1.text.replaceAll(',', '.')) ?? 0;
              final imp2 = double.tryParse(
                  _ctrlMixto2.text.replaceAll(',', '.')) ?? 0;
              Navigator.pop(context, {
                'metodo': 'mixto',
                'metodo_primario': _metodo,
                'metodo_secundario': _metodoSecundario,
                // Legacy — mantener para compatibilidad con código antiguo
                'importe_efectivo': (_metodo == 'efectivo' ? imp1 : 0.0) +
                    (_metodoSecundario == 'efectivo' ? imp2 : 0.0),
                'importe_tarjeta': (_metodo == 'tarjeta' ? imp1 : 0.0) +
                    (_metodoSecundario == 'tarjeta' ? imp2 : 0.0),
                'importe_total': widget.total,
                // Nuevo: desglose real de cada método (incluye bizum, transferencia, etc.)
                'importes': <String, double>{
                  _metodo: imp1,
                  _metodoSecundario!: imp2,
                },
              });
            } else {
              Navigator.pop(context, {
                'metodo': _metodo,
                'importe_efectivo': _metodo == 'efectivo' ? widget.total : 0.0,
                'importe_tarjeta':  _metodo == 'tarjeta'  ? widget.total : 0.0,
                // Nuevo: desglose real
                'importes': <String, double>{_metodo: widget.total},
              });
            }
          },
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
            color: selected ? _TpvTemaScope.primarioOf(context) : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 20,
              color: selected ? _TpvTemaScope.primarioOf(context) : Colors.grey),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color:
                  selected ? _TpvTemaScope.primarioOf(context) : Colors.grey)),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MINI-DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════

// ── Chip de la ficha de cliente ───────────────────────────────────────────────
class _FichaChip extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  const _FichaChip({required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
      ]),
    );
  }
}

// ── Estadísticas de turno colapsable ─────────────────────────────────────────

class _EstadisticasTurnoColapsable extends StatefulWidget {
  final String empresaId;
  const _EstadisticasTurnoColapsable({required this.empresaId});

  @override
  State<_EstadisticasTurnoColapsable> createState() =>
      _EstadisticasTurnoColapsableState();
}

class _EstadisticasTurnoColapsableState
    extends State<_EstadisticasTurnoColapsable> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final tema = _TpvTemaScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            color: tema.primario.withValues(alpha: 0.04),
            child: Row(children: [
              Icon(Icons.show_chart, size: 14, color: tema.primario),
              const SizedBox(width: 6),
              Text(
                'Estadísticas del turno',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tema.textoSecundario),
              ),
              const Spacer(),
              Icon(
                _expandido
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 14,
                color: tema.textoSecundario,
              ),
            ]),
          ),
        ),
        if (_expandido)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child:
                EstadisticasTurnoWidget(empresaId: widget.empresaId),
          ),
      ],
    );
  }
}

class _MiniDashboard extends StatelessWidget {
  final String empresaId;
  const _MiniDashboard({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final hoy = DateFormat('yyyy-MM-dd').format(ahora);
    final inicio = Timestamp.fromDate(DateTime(ahora.year, ahora.month, ahora.day));
    final fin = Timestamp.fromDate(DateTime(ahora.year, ahora.month, ahora.day + 1));
    final tema = _TpvTemaScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: tema.primario.withValues(alpha: 0.07),
      child: Row(children: [
        Expanded(child: _DashChip(empresaId: empresaId, hoy: hoy, inicioTs: inicio, finTs: fin, tema: tema, tipo: _DashTipo.citasHoy)),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: _DashChip(empresaId: empresaId, hoy: hoy, inicioTs: inicio, finTs: fin, tema: tema, tipo: _DashTipo.cobradoHoy)),
        const SizedBox(width: 6),
        Expanded(child: _DashChip(empresaId: empresaId, hoy: hoy, inicioTs: inicio, finTs: fin, tema: tema, tipo: _DashTipo.pendientes)),
      ]),
    );
  }
}

enum _DashTipo { citasHoy, cobradoHoy, pendientes }

class _DashChip extends StatelessWidget {
  final String empresaId;
  final String hoy;
  final Timestamp inicioTs;
  final Timestamp finTs;
  final _TpvTema tema;
  final _DashTipo tipo;

  const _DashChip({
    required this.empresaId,
    required this.hoy,
    required this.inicioTs,
    required this.finTs,
    required this.tema,
    required this.tipo,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId);

    return StreamBuilder<QuerySnapshot>(
      stream: _buildStream(db),
      builder: (ctx, snap) {
        final label = _label(snap);
        final icon = _icon();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: tema.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tema.divisor),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: tema.primario),
            const SizedBox(width: 4),
            Flexible(child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: tema.textoPrimario,
                    fontWeight: FontWeight.w500))),
          ]),
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildStream(
      DocumentReference<Map<String, dynamic>> db) {
    switch (tipo) {
      case _DashTipo.citasHoy:
        return db.collection('reservas')
            .where('fecha', isEqualTo: hoy)
            .snapshots();
      case _DashTipo.cobradoHoy:
        // Sin filtro estado_pago en Firestore (evita índice compuesto)
        // → se filtra client-side en _label()
        return db.collection('pedidos')
            .where('fecha_creacion', isGreaterThanOrEqualTo: inicioTs)
            .where('fecha_creacion', isLessThan: finTs)
            .snapshots();
      case _DashTipo.pendientes:
        return db.collection('reservas')
            .where('fecha', isEqualTo: hoy)
            .where('estado', isEqualTo: 'pendiente')
            .snapshots();
    }
  }

  String _label(AsyncSnapshot<QuerySnapshot> snap) {
    if (!snap.hasData) {
      switch (tipo) {
        case _DashTipo.citasHoy:    return 'Citas: …';
        case _DashTipo.cobradoHoy:  return 'Cobrado: …';
        case _DashTipo.pendientes:  return 'Pendientes: …';
      }
    }
    final docs = snap.data!.docs;
    switch (tipo) {
      case _DashTipo.citasHoy:
        return 'Citas: ${docs.length}';
      case _DashTipo.cobradoHoy:
        final total = docs.fold<double>(0, (s, d) {
          final data = d.data() as Map<String, dynamic>;
          // Filtro client-side: solo pagados
          if (data['estado_pago'] != 'pagado') return s;
          return s + ((data['importe_total'] as num?)?.toDouble() ??
              (data['total'] as num?)?.toDouble() ?? 0);
        });
        return 'Cobrado: ${total.toStringAsFixed(0)} EUR';
      case _DashTipo.pendientes:
        return 'Pendientes: ${docs.length}';
    }
  }

  IconData _icon() {
    switch (tipo) {
      case _DashTipo.citasHoy:   return Icons.calendar_today;
      case _DashTipo.cobradoHoy: return Icons.euro;
      case _DashTipo.pendientes: return Icons.pending_actions;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CIERRE DE CAJA
// ═══════════════════════════════════════════════════════════════════════════

class _PelCierreDeCaja extends StatefulWidget {
  final String empresaId;
  final DateTime fecha;
  const _PelCierreDeCaja({required this.empresaId, required this.fecha});

  @override
  State<_PelCierreDeCaja> createState() => _PelCierreDeCajaState();
}

class _PelCierreDeCajaState extends State<_PelCierreDeCaja> {
  Map<String, dynamic>? _datos;
  Map<String, dynamic>? _empresa;
  bool _cargando = true, _cerrando = false;
  bool _abriendo = false;
  bool _historialExpandido = false;
  List<Map<String, dynamic>> _ticketsDia = [];
  double _totalAyer = 0;
  final _efectivoContadoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _efectivoContadoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final hoy = widget.fecha;
      final inicio = DateTime(hoy.year, hoy.month, hoy.day);
      final fin = inicio.add(const Duration(days: 1));

      // ── Métodos de pago configurados ──────────────────────────────────────
      const _baseMetodos = [
        (id: 'efectivo',      label: 'Efectivo'),
        (id: 'tarjeta',       label: 'Tarjeta'),
        (id: 'bizum',         label: 'Bizum'),
        (id: 'transferencia', label: 'Transferencia'),
        (id: 'cheque_regalo', label: 'Cheque regalo'),
      ];
      List<({String id, String label})> metodosConfig = [
        (id: 'efectivo', label: 'Efectivo'),
        (id: 'tarjeta',  label: 'Tarjeta'),
      ];
      try {
        final cfgDoc = await FirebaseFirestore.instance
            .collection('empresas').doc(widget.empresaId)
            .collection('configuracion').doc('tpv_cobro').get();
        if (cfgDoc.exists) {
          final habilitados = (cfgDoc.data()?['metodos_habilitados'] as List?)
              ?.map((e) => e.toString()).toSet() ?? {};
          final custom = (cfgDoc.data()?['metodos_custom'] as List?)
              ?.map((e) => e.toString()).toList() ?? [];
          if (habilitados.isNotEmpty) {
            metodosConfig = [
              ..._baseMetodos.where((m) => habilitados.contains(m.id)),
              ...custom.asMap().entries
                  .where((e) => habilitados.contains('custom_${e.key}'))
                  .map((e) => (id: 'custom_${e.key}', label: e.value)),
            ];
          }
        }
      } catch (_) {}

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

      final Map<String, double> porMetodo = {};
      double baseImponibleTotal = 0;
      double cuotaIvaTotal = 0;
      final top = <String, int>{};
      int ticketsPagados = 0;

      for (final d in snap.docs) {
        final m = d.data();
        // Filtro client-side: solo pedidos pagados
        if (m['estado_pago'] != 'pagado') continue;
        ticketsPagados++;
        final pedTotal = (m['total'] as num?)?.toDouble() ?? 0.0;
        final met = m['metodo_pago'] as String? ?? 'efectivo';
        if (met == 'mixto') {
          // Usar el desglose detallado si existe (captura bizum, transferencia, etc.)
          final importes = (m['importes_por_metodo'] as Map?)
              ?.cast<String, dynamic>();
          if (importes != null && importes.isNotEmpty) {
            for (final e in importes.entries) {
              final v = (e.value as num?)?.toDouble() ?? 0;
              if (v > 0) porMetodo[e.key] = (porMetodo[e.key] ?? 0) + v;
            }
          } else {
            // Fallback para documentos antiguos: solo efectivo + tarjeta
            final efMixto = (m['importe_efectivo'] as num?)?.toDouble() ?? 0;
            final tjMixto = (m['importe_tarjeta'] as num?)?.toDouble() ?? 0;
            porMetodo['efectivo'] = (porMetodo['efectivo'] ?? 0) +
                (efMixto == 0 && tjMixto == 0 ? pedTotal / 2 : efMixto);
            porMetodo['tarjeta'] = (porMetodo['tarjeta'] ?? 0) +
                (efMixto == 0 && tjMixto == 0 ? pedTotal / 2 : tjMixto);
          }
        } else {
          porMetodo[met] = (porMetodo[met] ?? 0) + pedTotal;
        }
        for (final l in m['lineas'] as List? ?? []) {
          final n = (l['producto_nombre'] as String?) ??
              (l['nombre'] as String?) ?? '';
          if (n.isNotEmpty) {
            top[n] = (top[n] ?? 0) + ((l['cantidad'] as num?)?.toInt() ?? 1);
          }
          // Desglose IVA — precio_unitario es siempre BASE (sin IVA)
          final base = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
          final cant = (l['cantidad'] as num?)?.toDouble() ?? 1.0;
          final iva = ((l['iva_porcentaje'] ?? l['porcentaje_iva'] ?? 21.0) as num).toDouble();
          baseImponibleTotal += base * cant;
          cuotaIvaTotal += base * cant * iva / 100;
        }
      }

      final ef = porMetodo['efectivo'] ?? 0;
      final tj = porMetodo['tarjeta'] ?? 0;
      final total = porMetodo.values.fold(0.0, (a, b) => a + b);

      // Si no hay líneas con datos (pedidos sin desglose), fallback al total con IVA 21%
      if (baseImponibleTotal == 0 && total > 0) {
        baseImponibleTotal = total / 1.21;
        cuotaIvaTotal = total - baseImponibleTotal;
      }

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

      // ── Obtener nombres: fuente principal = usuarios con empresa_id ──
      final Map<String, Map<String, dynamic>> datosProf = {};

      // Fuente principal: colección usuarios (misma que usa la agenda)
      try {
        final usuariosSnap = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('empresa_id', isEqualTo: widget.empresaId)
            .get();
        for (final d in usuariosSnap.docs) {
          datosProf[d.id] = d.data();
        }
      } catch (_) {}

      // Fallback: subcollección profesionales (datos TPV específicos)
      try {
        final profsSnap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('profesionales')
            .get();
        for (final d in profsSnap.docs) {
          // Solo añadir si no existe ya en usuarios; preservar comision_pct
          if (!datosProf.containsKey(d.id)) {
            datosProf[d.id] = d.data();
          } else {
            // Combinar: mantener nombre de usuarios pero añadir comision_pct
            final pct = d.data()['comision_pct'];
            if (pct != null) datosProf[d.id]!['comision_pct'] = pct;
          }
        }
      } catch (_) {}

      final comisiones = ventasPorProf.entries.map((e) {
        final data = datosProf[e.key] ?? {};
        final ventas = e.value;
        final pct = (data['comision_pct'] as num?)?.toDouble() ?? 0;
        // Si no encontramos el nombre, mostrar texto amigable en lugar del ID
        final nombreRaw = data['nombre'] as String? ?? data['displayName'] as String?;
        final nombre = (nombreRaw != null && nombreRaw.isNotEmpty)
            ? nombreRaw
            : 'Profesional eliminado';
        return {
          'nombre': nombre,
          'ventas': ventas,
          'comision_pct': pct,
          'comision_importe': ventas * pct / 100,
        };
      }).where((m) => (m['ventas'] as double) > 0).toList();

      final totalComisiones = comisiones.fold(
          0.0, (sum, m) => sum + (m['comision_importe'] as double));

      // ── Datos empresa ──
      Map<String, dynamic> empresaData = {};
      try {
        final eDoc = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .get();
        empresaData = eDoc.data() ?? {};
      } catch (_) {}

      // ── Apertura de caja — fuente canónica: aperturas_caja ──
      double fondoInicial = 0;
      String? aperturaUsuario;
      int numZ = 1;
      try {
        // Leer fondo_inicial de la apertura de hoy
        final aperturasSnap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('aperturas_caja')
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('fecha', isLessThan: Timestamp.fromDate(fin))
            .orderBy('fecha', descending: true)
            .limit(1)
            .get();
        if (aperturasSnap.docs.isNotEmpty) {
          final ap = aperturasSnap.docs.first.data();
          fondoInicial = (ap['fondo_inicial'] as num?)?.toDouble() ?? 0;
          final uid = ap['camarero_uid'] as String? ?? '';
          // Resolver nombre real del usuario a partir del UID
          if (uid.isNotEmpty) {
            try {
              final uDoc = await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(uid)
                  .get();
              final d = uDoc.data();
              aperturaUsuario =
                  (d?['nombre'] as String?) ??
                  (d?['nombre_completo'] as String?) ??
                  (d?['display_name'] as String?) ??
                  (d?['email'] as String?) ??
                  uid;
            } catch (_) {
              aperturaUsuario = uid;
            }
          }
        }
        // Número Z = total de cierres anteriores + 1
        final todosSnap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('cierres_caja')
            .get();
        numZ = todosSnap.docs.length + 1;
      } catch (_) {}

      // ── Tickets anulados ──
      int ticketsAnulados = 0;
      try {
        final anulados = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('pedidos')
            .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('fecha_hora', isLessThan: Timestamp.fromDate(fin))
            .where('estado_pago', isEqualTo: 'anulado')
            .get();
        ticketsAnulados = anulados.docs.length;
      } catch (_) {}

      // ── Historial tickets del día ──
      final List<Map<String, dynamic>> ticketsDia = [];
      try {
        final tickSnap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('pedidos')
            .where('fecha_creacion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('fecha_creacion', isLessThan: Timestamp.fromDate(fin))
            .orderBy('fecha_creacion', descending: true)
            .get();
        for (final d in tickSnap.docs) {
          final m = d.data();
          ticketsDia.add({
            'id': d.id,
            'num': m['numero_ticket'] ?? '',
            'cliente': m['cliente_nombre'] ?? 'Caja directa',
            'total': (m['total'] as num?)?.toDouble() ?? 0,
            'metodo': m['metodo_pago'] ?? 'efectivo',
            'estado': m['estado_pago'] ?? '',
            'hora': (m['fecha_creacion'] as Timestamp?)?.toDate(),
          });
        }
      } catch (_) {}

      // ── Total de ayer (comparativa) ──
      double totalAyer = 0;
      try {
        final ayerStr = DateFormat('yyyy-MM-dd').format(hoy.subtract(const Duration(days: 1)));
        final ayerDoc = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('cierres_caja')
            .doc(ayerStr)
            .get();
        if (ayerDoc.exists) {
          totalAyer = (ayerDoc.data()?['cierre']?['total'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _empresa = empresaData;
          _ticketsDia = ticketsDia;
          _totalAyer = totalAyer;
          _datos = {
            'total': total,
            'efectivo': ef,
            'tarjeta': tj,
            'por_metodo': porMetodo,
            'metodos_config': metodosConfig.map((m) => {'id': m.id, 'label': m.label}).toList(),
            'num_tickets': ticketsPagados,
            'tickets_anulados': ticketsAnulados,
            'ticket_medio': ticketsPagados == 0 ? 0.0 : total / ticketsPagados,
            'base_imponible': baseImponibleTotal,
            'cuota_iva': cuotaIvaTotal,
            'fondo_inicial': fondoInicial,
            'efectivo_esperado': fondoInicial + ef,
            'apertura_usuario': aperturaUsuario ?? 'Sin registrar',
            'num_z': numZ,
            'top': (top.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(5)
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
            'por_metodo': <String, double>{},
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
        FluxToast.aviso(context, 'Error al cargar datos: $e');
      }
    }
  }

  Future<void> _cerrar() async {
    // ── Arqueo de caja antes de cerrar ────────────────────────────────────
    final totalSistema =
        (_datos?['efectivo'] as num?)?.toDouble() ?? 0.0;
    final arqueoResult = await ArqueoCajaWidget.mostrar(
      context,
      totalSistema: totalSistema,
    );
    if (!mounted) return;
    // Si el usuario cancela el arqueo (cierra sin confirmar), abortamos
    if (arqueoResult == null) return;

    final hayDescuadre = _efectivoContado >= 0 && _descuadre.abs() >= 0.01;
    String? motivoDescuadre;

    // Si hay descuadre, pedir justificación obligatoria
    if (hayDescuadre) {
      final motivo = await _dialogoDescuadre();
      if (motivo == null) return; // canceló
      motivoDescuadre = motivo;
    } else {
      // Confirmación normal
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirmar cierre de caja'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_efectivoContado >= 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text('La caja cuadra ✓',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                ]),
              )
            else
              const Text('¿Registrar el cierre del día?'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar caja')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _cerrando = true);
    try {
      final d = _datos!;
      final fechaStr = DateFormat('yyyy-MM-dd').format(widget.fecha);
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) FluxToast.error(context, 'No hay sesión activa. Vuelve a iniciar sesión.');
        return;
      }
      final uid = currentUser.uid;
      final contado = _efectivoContado >= 0 ? _efectivoContado : null;

      final docRef = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('cierres_caja')
          .doc(fechaStr);

      // Pre-check: si ya existe con campo 'cierre', evitar la escritura
      final existing = await docRef.get();
      if (existing.exists && existing.data()?.containsKey('cierre') == true) {
        if (mounted) FluxToast.aviso(context, 'La caja ya fue cerrada hoy ($fechaStr)');
        return;
      }

      await docRef.set({
        'fecha': fechaStr,
        'cierre': {
          'fecha_hora': FieldValue.serverTimestamp(),
          'usuario': uid,
          'total': d['total'],
          'efectivo': d['efectivo'],
          'tarjeta': d['tarjeta'],
          'por_metodo': d['por_metodo'] ?? {'efectivo': d['efectivo'], 'tarjeta': d['tarjeta']},
          'num_tickets': d['num_tickets'],
          'base_imponible': d['base_imponible'],
          'cuota_iva': d['cuota_iva'],
          'fondo_inicial': (d['fondo_inicial'] as num?)?.toDouble() ?? 0,
          // ── Cuadre ──
          if (contado != null) ...{
            'efectivo_contado': contado,
            'efectivo_esperado': (d['efectivo_esperado'] as num?)?.toDouble() ?? 0,
            'descuadre': _descuadre,
            'hay_descuadre': hayDescuadre,
            if (motivoDescuadre != null) 'motivo_descuadre': motivoDescuadre,
          },
        },
      }, SetOptions(merge: true));

      if (mounted) {
        if (hayDescuadre) {
          FluxToast.aviso(context,
              'Cierre registrado con descuadre de ${_descuadre.abs().toStringAsFixed(2)} EUR',
              title: 'Descuadre registrado');
        } else {
          FluxToast.exito(context, 'Cierre de caja registrado');
        }
      }
    } catch (e) {
      String msg = 'Error al cerrar caja: $e';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          msg = 'Sin permisos. Comprueba que tu usuario tiene rol staff, admin o propietario en esta empresa (código: ${e.code})';
        } else {
          msg = 'Error Firebase [${e.code}]: ${e.message}';
        }
      }
      if (mounted) FluxToast.error(context, msg);
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  /// Diálogo que aparece cuando hay descuadre — pide justificación obligatoria.
  Future<String?> _dialogoDescuadre() async {
    final ctrl = TextEditingController();
    final primario = _TpvTemaScope.primarioOf(context);
    final descuadreAbs = _descuadre.abs();
    final esSobrante = _descuadre > 0;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          const SizedBox(width: 8),
          const Text('Descuadre detectado', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(esSobrante ? 'Sobrante en caja:' : 'Falta en caja:',
                    style: const TextStyle(fontSize: 13)),
                const Spacer(),
                Text('${descuadreAbs.toStringAsFixed(2)} EUR',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: esSobrante ? Colors.green.shade700 : Colors.red.shade700,
                    )),
              ]),
              const SizedBox(height: 4),
              Text(
                esSobrante
                    ? 'Hay más efectivo del esperado.'
                    : 'Hay menos efectivo del esperado.',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          const Text('Indica el motivo del descuadre (obligatorio):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ej: Error al dar cambio, propina no registrada...',
              hintStyle: const TextStyle(fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primario)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          StatefulBuilder(builder: (ctx, setSt) => FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) {
                setSt(() {}); // trigger rebuild to show hint
                return;
              }
              Navigator.pop(context, ctrl.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
            child: const Text('Registrar con descuadre'),
          )),
        ],
      ),
    );
  }

  Future<void> _abrirCajon() async {
    if (_abriendo) return;
    setState(() => _abriendo = true);
    try {
      final cfg = await TpvFacturacionService().obtenerConfig(widget.empresaId);
      await ImpresoraService().abrirCajonSiProcede(
        config: cfg.copyWith(abrirCajonAlCobrar: true, abrirCajonSoloEfectivo: false),
        metodoPago: 'efectivo',
      );
      if (mounted) FluxToast.exito(context, 'Comando enviado al cajón');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al abrir cajón: $e');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  String get _hoy {
    final h = DateTime.now();
    return '${h.day.toString().padLeft(2, '0')}/${h.month.toString().padLeft(2, '0')}/${h.year}';
  }

  double get _efectivoContado =>
      double.tryParse(_efectivoContadoCtrl.text.replaceAll(',', '.')) ?? -1;
  double get _descuadre =>
      _efectivoContado < 0 ? 0 : _efectivoContado - (_datos?['efectivo_esperado'] as double? ?? 0);

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final d = _datos!;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final primario = _TpvTemaScope.primarioOf(context);
    double _n(String k) => (d[k] as num?)?.toDouble() ?? 0.0;
    final total = _n('total');
    final ef = _n('efectivo');
    final tj = _n('tarjeta');
    final numTickets = (d['num_tickets'] as num?)?.toInt() ?? 0;
    final ticketMedio = _n('ticket_medio');
    final anulados = (d['tickets_anulados'] as num?)?.toInt() ?? 0;
    final fondoInicial = _n('fondo_inicial');
    final efectivoEsperado = _n('efectivo_esperado');
    final baseImp = _n('base_imponible');
    final cuotaIva = _n('cuota_iva');
    final numZ = (d['num_z'] as num?)?.toInt() ?? 1;

    // Comparativa ayer
    final pctVsAyer = _totalAyer > 0
        ? ((total - _totalAyer) / _totalAyer * 100)
        : null;

    return Column(children: [
      // ── Toolbar ────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: primario.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text('Z-$numZ · $_hoy',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primario)),
          ),
          const Spacer(),
          _toolBtn(Icons.refresh, 'Actualizar', _cargar),
          const SizedBox(width: 4),
          _toolBtn(Icons.print_outlined, 'Imprimir', _zPdf),
          const SizedBox(width: 4),
          _toolBtn(Icons.download_rounded, 'PDF', _descargarPdf, color: primario),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _abriendo ? null : _abrirCajon,
            icon: _abriendo
                ? const SizedBox(width: 13, height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.inventory_2_outlined, size: 14),
            label: const Text('Abrir cajón', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              side: BorderSide(color: Colors.orange.shade400),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: _cerrando ? null : _cerrar,
            icon: _cerrando
                ? const SizedBox(width: 13, height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.lock_outline, size: 14),
            label: const Text('Cerrar caja', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: primario,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ]),
      ),

      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── KPIs principales ─────────────────────────────────────
            Row(children: [
              _kpi('Total ventas', fmt.format(total), Icons.euro_rounded,
                  color: primario, sub: pctVsAyer != null
                      ? '${pctVsAyer >= 0 ? '+' : ''}${pctVsAyer.toStringAsFixed(1)}% vs ayer'
                      : null,
                  subColor: pctVsAyer == null ? null : (pctVsAyer >= 0 ? Colors.green : Colors.red)),
              const SizedBox(width: 8),
              _kpi('Tickets', '$numTickets', Icons.receipt_long_rounded,
                  sub: anulados > 0 ? '$anulados anulados' : null, subColor: Colors.orange),
              const SizedBox(width: 8),
              _kpi('Ticket medio', fmt.format(ticketMedio), Icons.show_chart),
            ]),
            const SizedBox(height: 10),

            // ── Cobros por forma de pago ──────────────────────────────
            _seccion('Cobros por forma de pago', [
              LayoutBuilder(builder: (ctx, constraints) {
                final pm = (d['por_metodo'] as Map<String, double>?) ??
                    {'efectivo': ef, 'tarjeta': tj};
                // Construir la lista de métodos con saldo > 0.
                // 'mixto' se excluye siempre: ya fue descompuesto en efectivo+tarjeta en _cargar().
                final todosIds = <String>{
                  ...(d['metodos_config'] as List?)
                          ?.map((e) => e['id'] as String)
                          .where((k) => k != 'mixto') ??
                      const ['efectivo', 'tarjeta'],
                  ...pm.keys.where((k) => k != 'mixto'),
                };
                final metodos = todosIds
                    .where((k) => (pm[k] ?? 0) > 0.001)
                    .map((k) => (id: k, label: _labelMetodo(k),
                                 valor: pm[k] ?? 0))
                    .toList()
                  ..sort((a, b) => b.valor.compareTo(a.valor));

                if (metodos.isEmpty) {
                  return Text('Sin cobros hoy',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12));
                }

                final w = constraints.maxWidth;
                final itemW = metodos.length > 1 ? (w - 8) / 2 : w;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: metodos.map((m) =>
                      SizedBox(width: itemW, child: _barraMetodo(
                        m.label, m.valor, total,
                        _colorMetodo(m.id), _iconMetodo(m.id),
                      )),
                    ).toList()),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.euro_rounded, size: 14),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('TOTAL VENTAS DEL DÍA',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              letterSpacing: 0.3))),
                      Text(fmt.format(total),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                              color: primario)),
                    ]),
                  ],
                );
              }),
            ]),
            const SizedBox(height: 10),

            // ── Cuadre de caja ────────────────────────────────────────
            _seccion('Cuadre de caja', [
              Row(children: [
                Expanded(child: _filaCuadre('Fondo apertura', fondoInicial)),
                const SizedBox(width: 12),
                Expanded(child: _filaCuadre('+ Efectivo cobrado', ef)),
              ]),
              const SizedBox(height: 6),
              _filaCuadreDestacada('Efectivo esperado en caja', efectivoEsperado),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const Text('Efectivo real contado:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _efectivoContadoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      prefixText: '€ ',
                      hintText: '0,00',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primario)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                if (_efectivoContado >= 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _descuadre.abs() < 0.01
                          ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _descuadre.abs() < 0.01
                          ? Colors.green.shade300 : Colors.red.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_descuadre.abs() < 0.01 ? Icons.check_circle : Icons.warning_amber_rounded,
                          size: 14,
                          color: _descuadre.abs() < 0.01 ? Colors.green.shade700 : Colors.red.shade700),
                      const SizedBox(width: 5),
                      Text(
                        _descuadre.abs() < 0.01
                            ? 'Cuadra ✓'
                            : 'Descuadre: ${fmt.format(_descuadre.abs())}',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _descuadre.abs() < 0.01 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ]),
                  ),
                ],
              ]),
            ]),
            const SizedBox(height: 10),

            // ── IVA fiscal ────────────────────────────────────────────
            _seccion('Desglose IVA (art. 164 Ley 37/1992)', [
              Table(
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3),
                    2: FlexColumnWidth(3), 3: FlexColumnWidth(3)},
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: primario.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6)),
                    children: ['Tipo', 'Base imp.', 'Cuota IVA', 'Total']
                        .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))))
                        .toList(),
                  ),
                  TableRow(children: [
                    '21%', fmt.format(baseImp), fmt.format(cuotaIva), fmt.format(total)
                  ].map((v) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: Text(v, style: const TextStyle(fontSize: 11)))).toList()),
                ],
              ),
            ]),
            const SizedBox(height: 10),

            // ── Top servicios ─────────────────────────────────────────
            if ((d['top'] as List).isNotEmpty)
              _seccion('Top servicios del día', [
                ...(d['top'] as List).asMap().entries.map((e) {
                  final entry = e.value as MapEntry<String, int>;
                  final maxCnt = ((d['top'] as List).first as MapEntry<String, int>).value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 18, height: 18,
                          decoration: BoxDecoration(color: primario, borderRadius: BorderRadius.circular(4)),
                          child: Center(child: Text('${e.key + 1}',
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                        Text('×${entry.value}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primario)),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: entry.value / maxCnt,
                          backgroundColor: primario.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(primario.withValues(alpha: 0.6)),
                          minHeight: 3,
                        ),
                      ),
                    ]),
                  );
                }),
              ]),
            if ((d['top'] as List).isNotEmpty) const SizedBox(height: 10),

            // ── Comisiones ────────────────────────────────────────────
            if ((d['comisiones'] as List? ?? []).isNotEmpty)
              _seccion('Comisiones profesionales', [
                Table(
                  columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2), 3: FlexColumnWidth(2)},
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: primario.withValues(alpha: 0.08)),
                      children: ['Profesional', 'Ventas', '%', 'Comisión']
                          .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                              child: Text(h, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))))
                          .toList(),
                    ),
                    ...(d['comisiones'] as List).map((m) => TableRow(
                      children: [
                        m['nombre'] as String,
                        fmt.format((m['ventas'] as num?)?.toDouble() ?? 0),
                        '${((m['comision_pct'] as num?)?.toInt() ?? 0)}%',
                        fmt.format((m['comision_importe'] as num?)?.toDouble() ?? 0),
                      ].map((v) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(v, style: const TextStyle(fontSize: 10)))).toList(),
                    )),
                    TableRow(
                      decoration: BoxDecoration(color: primario.withValues(alpha: 0.05)),
                      children: [
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(fmt.format((d['comisiones'] as List).fold<double>(0, (s, m) => s + ((m['ventas'] as num?)?.toDouble() ?? 0))),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                        const SizedBox(),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(fmt.format(d['total_comisiones']),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: primario))),
                      ],
                    ),
                  ],
                ),
              ]),
            if ((d['comisiones'] as List? ?? []).isNotEmpty) const SizedBox(height: 10),

            // ── Historial tickets ─────────────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _historialExpandido = !_historialExpandido),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primario.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primario.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.receipt_long, size: 15, color: primario),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Historial del día — ${_ticketsDia.length} tickets',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primario))),
                  // Botón "Ver completo" → HistorialTicketsWidget
                  GestureDetector(
                    onTap: () => HistorialTicketsWidget.mostrar(context, widget.empresaId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primario.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: primario.withValues(alpha: 0.3)),
                      ),
                      child: Text('Ver completo',
                          style: TextStyle(fontSize: 10, color: primario, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_historialExpandido ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: primario),
                ]),
              ),
            ),
            if (_historialExpandido && _ticketsDia.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: _ticketsDia.asMap().entries.map((e) {
                    final t = e.value;
                    final hora = t['hora'] as DateTime?;
                    final horaStr = hora != null
                        ? DateFormat('HH:mm').format(hora) : '';
                    final total = (t['total'] as double);
                    final pagado = t['estado'] == 'pagado';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: e.key.isEven ? Colors.white : Colors.grey.shade50,
                        borderRadius: e.key == _ticketsDia.length - 1
                            ? const BorderRadius.vertical(bottom: Radius.circular(8))
                            : null,
                      ),
                      child: Row(children: [
                        Text(horaStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(width: 8),
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pagado ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(t['cliente'] as String,
                            style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                        Text(_metodoPagoEmoji(t['metodo'] as String),
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 6),
                        Text(fmt.format(total),
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: pagado ? Colors.green.shade700 : Colors.red.shade400,
                            )),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ]),
        ),
      ),
    ]);
  }

  String _metodoPagoEmoji(String m) => switch (m) {
    'efectivo' => '💵', 'tarjeta' => '💳', 'bizum' => '📱',
    'transferencia' => '🏦', _ => '💰',
  };

  Widget _toolBtn(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) =>
      IconButton(
        icon: Icon(icon, size: 17, color: color),
        tooltip: tooltip,
        onPressed: onTap,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        visualDensity: VisualDensity.compact,
      );

  Widget _kpi(String label, String valor, IconData icon,
      {Color? color, String? sub, Color? subColor}) =>
      Expanded(child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (color ?? Colors.grey).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: (color ?? Colors.grey).withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
              color: color ?? Colors.black87)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 10, color: subColor ?? Colors.grey.shade500)),
          ],
        ]),
      ));

  static String _labelMetodo(String id) => switch (id) {
    'efectivo'      => 'Efectivo',
    'tarjeta'       => 'Tarjeta',
    'bizum'         => 'Bizum',
    'transferencia' => 'Transferencia',
    'cheque_regalo' => 'Cheque regalo',
    'mixto'         => 'Mixto',
    _               => id.startsWith('custom_') ? id.replaceFirst('custom_', 'Otro ') : id,
  };

  static Color _colorMetodo(String id) => switch (id) {
    'efectivo'      => const Color(0xFF2E7D32),
    'tarjeta'       => const Color(0xFF1565C0),
    'bizum'         => const Color(0xFF7B1FA2),
    'transferencia' => const Color(0xFF00838F),
    'cheque_regalo' => const Color(0xFFF57F17),
    _               => const Color(0xFF546E7A),
  };

  static IconData _iconMetodo(String id) => switch (id) {
    'efectivo'      => Icons.payments_outlined,
    'tarjeta'       => Icons.credit_card,
    'bizum'         => Icons.smartphone_outlined,
    'transferencia' => Icons.account_balance_outlined,
    'cheque_regalo' => Icons.card_giftcard_outlined,
    _               => Icons.payment_outlined,
  };

  Widget _barraMetodo(String label, double valor, double total, Color color, IconData icon) {
    final pct = total > 0 ? (valor / total).clamp(0.0, 1.0) : 0.0;
    final fmt2 = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${(pct * 100).toInt()}%',
              style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        ]),
        const SizedBox(height: 5),
        Text(fmt2.format(valor),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: pct,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color), minHeight: 4)),
      ]),
    );
  }

  Widget _filaCuadre(String label, double valor) {
    final fmt2 = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(fmt2.format(valor),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _filaCuadreDestacada(String label, double valor) {
    final fmt2 = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(fmt2.format(valor),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: Color(0xFF1565C0))),
      ]),
    );
  }

  Widget _seccion(String titulo, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: Colors.grey.shade600, letterSpacing: 0.3)),
      const SizedBox(height: 8),
      ...children,
    ]),
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
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500)),
    ],
  );

  // Formateador PDF sin símbolo € (no soportado por fuente base Helvetica)
  static String _fmtEur(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} EUR';

  Future<void> _zPdf() async {
    if (_datos == null) return;
    final bytes = await _buildPdfBytes();
    await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
  }

  Future<void> _descargarPdf() async {
    if (_datos == null) return;
    final bytes = Uint8List.fromList(await _buildPdfBytes());
    final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final nombre = 'cierre_caja_$fecha.pdf';
    try {
      Directory? dir;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        dir = await getDownloadsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$nombre');
      await file.writeAsBytes(bytes);
      if (mounted) {
        FluxToast.exito(context, 'PDF guardado en Descargas',
            title: nombre, duration: const Duration(seconds: 5));
      }
    } catch (e) {
      // Fallback: abrir diálogo de guardado del sistema
      await Printing.sharePdf(bytes: bytes, filename: nombre);
    }
  }

  Future<List<int>> _buildPdfBytes() async {
    final d = _datos!;
    final e = _empresa ?? {};
    // Usar 'EUR' como símbolo — la fuente base de pdf/dart (Helvetica) no incluye €
    String fmt(double v) => _fmtEur(v);
    final now = DateTime.now();
    final horaStr = DateFormat('HH:mm:ss').format(now);
    final numZ = d['num_z'] as int? ?? 1;

    final empresaNombre = e['nombre'] as String? ?? 'Sin nombre';
    final empresaNif = e['nif'] as String? ?? e['cif'] as String? ?? 'Sin NIF';
    final empresaDireccion = e['direccion'] as String? ??
        e['perfil']?['direccion'] as String? ?? '';
    final empresaTelefono = e['telefono'] as String? ??
        e['perfil']?['telefono'] as String? ?? '';

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── CABECERA EMPRESA ──────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(empresaNombre,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  if (empresaDireccion.isNotEmpty)
                    pw.Text(empresaDireccion,
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  if (empresaTelefono.isNotEmpty)
                    pw.Text('Tel: $empresaTelefono',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('NIF: $empresaNif',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              )),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Z-REPORT Nº $numZ',
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800)),
                  pw.Text('Fecha: $_hoy  Hora: $horaStr',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('Apertura: ${d['apertura_usuario']}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 8),

          // ── RESUMEN VENTAS ────────────────────────────────────────
          _pSeccion('RESUMEN DE VENTAS DEL DÍA'),
          _pRow('Tickets cobrados', '${d['num_tickets']}'),
          _pRow('Tickets anulados', '${d['tickets_anulados'] ?? 0}'),
          _pRow('Ticket medio', fmt(d['ticket_medio'] as double)),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          _pRowBold('TOTAL VENTAS', fmt(d['total'] as double)),
          pw.SizedBox(height: 10),

          // ── DESGLOSE COBRO ────────────────────────────────────────
          _pSeccion('DESGLOSE POR FORMA DE PAGO'),
          ...() {
            final pm = d['por_metodo'] as Map<String, double>? ??
                {'efectivo': d['efectivo'] as double, 'tarjeta': d['tarjeta'] as double};
            final cfg = (d['metodos_config'] as List?)
                ?.map((e) => (id: e['id'] as String, label: e['label'] as String))
                .toList()
                ?? [(id: 'efectivo', label: 'Efectivo'), (id: 'tarjeta', label: 'Tarjeta')];
            return cfg.map((m) => _pRow(m.label, fmt(pm[m.id] ?? 0)));
          }(),
          pw.SizedBox(height: 10),

          // ── CUADRE CAJA ───────────────────────────────────────────
          _pSeccion('CUADRE DE CAJA'),
          _pRow('Fondo inicial (apertura)', fmt((d['fondo_inicial'] as num?)?.toDouble() ?? 0)),
          _pRow('+ Cobros en efectivo', fmt((d['efectivo'] as num).toDouble())),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          _pRowBold('Efectivo esperado en caja', fmt((d['efectivo_esperado'] as num?)?.toDouble() ?? 0)),
          if (_efectivoContado >= 0) ...[
            _pRow('Efectivo real contado', fmt(_efectivoContado)),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Descuadre', style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: _descuadre.abs() < 0.01 ? PdfColors.green700 : PdfColors.red700)),
              pw.Text(_descuadre.abs() < 0.01
                  ? 'CUADRA OK'
                  : '${_descuadre > 0 ? '+' : ''}${fmt(_descuadre)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: _descuadre.abs() < 0.01 ? PdfColors.green700 : PdfColors.red700)),
            ]),
          ],
          pw.SizedBox(height: 10),

          // ── IVA (tabla fiscal) ────────────────────────────────────
          _pSeccion('DESGLOSE IVA (art. 164 Ley 37/1992)'),
          _pTablaIva(d),
          pw.SizedBox(height: 10),

          // ── TOP SERVICIOS ─────────────────────────────────────────
          if ((d['top'] as List).isNotEmpty) ...[
            _pSeccion('TOP SERVICIOS'),
            ...(d['top'] as List).asMap().entries.map((e) {
              final entry = e.value as MapEntry<String, int>;
              return _pRow('${e.key + 1}. ${entry.key}', '×${entry.value}');
            }),
            pw.SizedBox(height: 10),
          ],

          // ── COMISIONES ────────────────────────────────────────────
          if ((d['comisiones'] as List? ?? []).isNotEmpty) ...[
            _pSeccion('COMISIONES PROFESIONALES'),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['Profesional', '%', 'Ventas', 'Comisión']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ))
                      .toList(),
                ),
                ...(d['comisiones'] as List).map((m) => pw.TableRow(
                  children: [
                    m['nombre'] as String,
                    '${(m['comision_pct'] as double).toInt()}%',
                    fmt((m['ventas'] as num).toDouble()),
                    fmt((m['comision_importe'] as num).toDouble()),
                  ].map((v) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        child: pw.Text(v, style: const pw.TextStyle(fontSize: 9)),
                      )).toList(),
                )),
              ],
            ),
            pw.SizedBox(height: 4),
            _pRowBold('Total comisiones', fmt((d['total_comisiones'] as double))),
            pw.SizedBox(height: 10),
          ],

          // ── PIE FISCAL ────────────────────────────────────────────
          pw.Spacer(),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 4),
          pw.Text(
            'Documento generado por Fluix CRM | '
            'Software sujeto a RD 1007/2023 (Verifactu) | '
            'Conservar 6 años (art. 30 CCom)',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    ));
    return doc.save();
  }

  pw.Widget _pSeccion(String titulo) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(titulo,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700)),
      );

  pw.Widget _pTablaIva(Map<String, dynamic> d) {
    final base = (d['base_imponible'] as double);
    final cuota = (d['cuota_iva'] as double);
    final total = base + cuota;
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: ['Tipo IVA', 'Base imponible', 'Cuota IVA', 'Total']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Text(h,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ))
              .toList(),
        ),
        pw.TableRow(children: [
          '21%', _fmtEur(base), _fmtEur(cuota), _fmtEur(total)
        ].map((v) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: pw.Text(v, style: const pw.TextStyle(fontSize: 9)),
            )).toList()),
      ],
    );
  }

  pw.Widget _pRowBold(String l, String v) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(l, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ],
      );

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
  final DateTime fecha;
  const _DialogoAperturaCaja(
      {required this.empresaId, required this.fecha});

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
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final nombre = FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';
      final db = FirebaseFirestore.instance;

      // ── 1. Verificar doble apertura para la fecha del TPV ─────────────
      final inicioDelDia = DateTime(
          widget.fecha.year, widget.fecha.month, widget.fecha.day);
      final finDelDia = inicioDelDia.add(const Duration(days: 1));
      final existente = await db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('aperturas_caja')
          .where('fecha',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(inicioDelDia))
          .where('fecha', isLessThan: Timestamp.fromDate(finDelDia))
          .limit(1)
          .get();
      if (existente.docs.isNotEmpty && mounted) {
        FluxToast.error(context, 'Ya hay una caja abierta hoy');
        return;
      }

      // ── 2. Escribir en aperturas_caja (estándar — para hayCajaAbiertaHoy)
      await db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('aperturas_caja')
          .add({
        'fondo_inicial': monto,
        'fecha': FieldValue.serverTimestamp(),
        'camarero_uid': uid,
      });

      if (mounted) {
        Navigator.pop(context);
        FluxToast.exito(context,
            'Caja abierta con fondo de ${monto.toStringAsFixed(2)} €');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Error al abrir caja: $e';
        if (e is FirebaseException && e.code == 'permission-denied') {
          msg = 'Sin permisos para abrir caja. Comprueba que tu usuario tiene rol staff, admin o propietario.';
        }
        FluxToast.error(context, msg);
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
              color: _TpvTemaScope.primarioOf(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.account_balance_wallet, color: _TpvTemaScope.primarioOf(context), size: 20),
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
          style: FilledButton.styleFrom(backgroundColor: _TpvTemaScope.primarioOf(context)),
          child: _guardando
              ? const SizedBox(
              width: 16,
              height: 16,
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
        FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('empleados')
            .where('activo', isEqualTo: true)
            .get(),
      ]);

      final rulesSnap = results[0] as DocumentSnapshot;
      final serviciosSnap = results[1] as QuerySnapshot;
      final profsSnap = results[2] as QuerySnapshot;
      final usuariosSnap = results[3] as QuerySnapshot;
      final empleadosSnap = results[4] as QuerySnapshot;

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
      final listaEmpleados = empleadosSnap.docs
          .map(Profesional.fromEmpleado)
          .toList();
      
      // Combinar todas las fuentes, evitando duplicados
      final idsExistentes = <String>{};
      final profesionales = <Profesional>[];
      
      for (final prof in [...listaProfs, ...listaUsuarios, ...listaEmpleados]) {
        if (!idsExistentes.contains(prof.id)) {
          idsExistentes.add(prof.id);
          profesionales.add(prof);
        }
      }

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
      title: Row(children: [
        Icon(Icons.palette_outlined, color: _TpvTemaScope.primarioOf(context)),
        const SizedBox(width: 8),
        const Text('Reglas de color', style: TextStyle(fontSize: 16)),
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

// ═══════════════════════════════════════════════════════════════════════════
// PANEL PERSONALIZACIÓN TPV PELUQUERÍA — 12 paletas predefinidas
// ═══════════════════════════════════════════════════════════════════════════

class _Paleta {
  final String nombre;
  final String emoji;
  final Color primario;
  final Color secundario;
  final Color fondo;
  final Color superficie;
  final Color texto;

  const _Paleta(this.nombre, this.emoji,
      this.primario, this.secundario, this.fondo, this.superficie, this.texto);
}

// Orden de campos: nombre, emoji, primario, secundario, fondo, superficie, textoOscuro
// primario   = AppBar, botones principales, acentos
// secundario = iconos activos, hover
// fondo      = background general
// superficie = tarjetas, paneles
// textoOscuro= títulos y texto principal sobre ese fondo
const _paletas = [
  _Paleta('Lavanda',          '🟣', Color(0xFF7C3AED), Color(0xFF8B5CF6), Color(0xFFF5F3FF), Color(0xFFEDE9FE), Color(0xFF1E1B4B)),
  _Paleta('Rosa Coral',       '🩷', Color(0xFFE11D74), Color(0xFFF472B6), Color(0xFFFFF0F7), Color(0xFFFEE2F0), Color(0xFF3D0020)),
  _Paleta('Sage Green',       '🟢', Color(0xFF4A7C59), Color(0xFF81B29A), Color(0xFFF0F7F4), Color(0xFFDCF0E6), Color(0xFF1A3A27)),
  _Paleta('Midnight Dark',    '🔵', Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF182033), Color(0xFF243047), Color(0xFFCBD5E1)),
  _Paleta('Terracota',        '🟠', Color(0xFFC2522A), Color(0xFFE07A5F), Color(0xFFFDF0EB), Color(0xFFF9D5C8), Color(0xFF4A1500)),
  _Paleta('Azul Índigo',      '🔷', Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFFEFF6FF), Color(0xFFDBEAFE), Color(0xFF0F2460)),
  _Paleta('Dorado Champagne', '🟡', Color(0xFF92702A), Color(0xFFC9A84C), Color(0xFFFFFDF5), Color(0xFFFFF3CC), Color(0xFF3A2800)),
  _Paleta('Slate Neutro',     '⬜', Color(0xFF374151), Color(0xFF6B7280), Color(0xFFF9FAFB), Color(0xFFF3F4F6), Color(0xFF111827)),
  _Paleta('Morado Night',     '🌑', Color(0xFFC4B5FD), Color(0xFFA78BFA), Color(0xFF251445), Color(0xFF32206A), Color(0xFFEDE9FE)),
  _Paleta('Blush Nude',       '🌸', Color(0xFFC48B8B), Color(0xFFD4A5A5), Color(0xFFFDF8F5), Color(0xFFF5EBE6), Color(0xFF5C3030)),
  _Paleta('Teal Agua',        '🩵', Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFFF0FDFB), Color(0xFFCCFBF1), Color(0xFF042F2E)),
  _Paleta('Negro + Rojo',     '🔴', Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFF181818), Color(0xFF272727), Color(0xFFFECACA)),
];

class _PanelPersonalizacion extends StatefulWidget {
  final Color primario;
  final Color secundario;
  final Color fondo;
  final Color superficie;
  final Color texto;
  final void Function(Color p, Color s, Color f, Color sup, Color t) onGuardar;

  const _PanelPersonalizacion({
    required this.primario,
    required this.secundario,
    required this.fondo,
    required this.superficie,
    required this.texto,
    required this.onGuardar,
  });

  @override
  State<_PanelPersonalizacion> createState() => _PanelPersonalizacionState();
}

class _PanelPersonalizacionState extends State<_PanelPersonalizacion> {
  late _Paleta _seleccionada;

  @override
  void initState() {
    super.initState();
    // Detectar si el tema actual coincide con alguna paleta
    _seleccionada = _paletas.firstWhere(
      (p) => p.primario == widget.primario,
      orElse: () => _paletas.first,
    );
  }

  bool _esOscura(_Paleta p) {
    // Fondo oscuro si su luminancia es baja
    final lum = p.fondo.computeLuminance();
    return lum < 0.3;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _seleccionada.primario.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.palette, color: _seleccionada.primario, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Estilo de pantalla',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 6),
          Text('${_seleccionada.emoji} ${_seleccionada.nombre} seleccionado',
              style: TextStyle(
                  fontSize: 13, color: _seleccionada.primario,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),

          // Grid de paletas
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _paletas.length,
              itemBuilder: (_, i) {
                final p = _paletas[i];
                final sel = _seleccionada == p;
                final oscura = _esOscura(p);
                return GestureDetector(
                  onTap: () => setState(() => _seleccionada = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: p.fondo,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? p.primario : Colors.grey[300]!,
                          width: sel ? 3 : 1),
                      boxShadow: sel
                          ? [BoxShadow(color: p.primario.withValues(alpha: 0.4),
                              blurRadius: 8)]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mini AppBar simulada
                        Container(
                          height: 12,
                          margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          decoration: BoxDecoration(
                            color: p.primario,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Mini superficie
                        Container(
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: p.superficie,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: p.secundario.withValues(alpha: 0.3)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${p.emoji} ${p.nombre}',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: oscura ? Colors.white70 : p.texto)),
                        if (sel)
                          Icon(Icons.check_circle, color: p.primario, size: 14),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Preview barra
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _seleccionada.fondo,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(children: [
              Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: _seleccionada.primario,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.content_cut, color: Colors.white, size: 16)),
              const SizedBox(width: 10),
              Text('TPV Peluquería',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _esOscura(_seleccionada)
                          ? Colors.white : _seleccionada.texto)),
              const Spacer(),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _seleccionada.superficie,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _seleccionada.secundario.withValues(alpha: 0.4))),
                  child: Text('09:30',
                      style: TextStyle(
                          color: _seleccionada.secundario,
                          fontSize: 11, fontWeight: FontWeight.w700))),
            ]),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                widget.onGuardar(
                  _seleccionada.primario,
                  _seleccionada.secundario,
                  _seleccionada.fondo,
                  _seleccionada.superficie,
                  _seleccionada.texto,
                );
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                  backgroundColor: _seleccionada.primario,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Aplicar estilo',

                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PANEL ESTADÍSTICAS DE EMPLEADOS
// ═══════════════════════════════════════════════════════════════════════════

class _PanelEstadisticasEmpleados extends StatefulWidget {
  final String empresaId;
  final _TpvTema tema;
  final ScrollController scrollCtrl;

  const _PanelEstadisticasEmpleados({
    required this.empresaId,
    required this.tema,
    required this.scrollCtrl,
  });

  @override
  State<_PanelEstadisticasEmpleados> createState() =>
      _PanelEstadisticasEmpleadosState();
}

class _PanelEstadisticasEmpleadosState
    extends State<_PanelEstadisticasEmpleados> {
  // Rango activo
  DateTime _desde = DateTime.now().subtract(const Duration(days: 29));
  DateTime _hasta = DateTime.now();
  int _filtroRapido = 3; // 0=Hoy 1=Ayer 2=7d 3=30d 4=Custom

  bool _cargando = true;
  List<_StatEmpleado> _empleados = [];
  List<_StatServicio> _servicios = [];
  Map<String, String> _nombresPorId = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final inicio = DateTime(_desde.year, _desde.month, _desde.day);
      final fin = DateTime(_hasta.year, _hasta.month, _hasta.day)
          .add(const Duration(days: 1));

      // Obtener nombres de profesionales
      final Map<String, String> nombres = {};
      try {
        final usersSnap = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('empresa_id', isEqualTo: widget.empresaId)
            .get();
        for (final d in usersSnap.docs) {
          final data = d.data();
          nombres[d.id] =
              (data['nombre'] as String?) ?? (data['email'] as String?) ?? d.id;
        }
        final profsSnap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('profesionales')
            .get();
        for (final d in profsSnap.docs) {
          nombres[d.id] ??= (d.data()['nombre'] as String?) ?? d.id;
        }
      } catch (_) {}
      _nombresPorId = nombres;

      // Cargar reservas del período (filtro de estado en cliente para evitar índice compuesto)
      final reservasSnap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('reservas')
          .where('fecha', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(inicio))
          .where('fecha', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(_hasta))
          .get();
      // Filtro cliente: solo citas completadas
      final docs = reservasSnap.docs
          .where((d) => (d.data()['estado'] as String?) == 'completada')
          .toList();

      // Agregar por empleado
      final Map<String, _StatEmpleadoBuilder> porEmpleado = {};
      final Map<String, _StatServicioBuilder> porServicio = {};

      for (final doc in docs) {
        final d = doc.data();
        final profId = (d['prof_id'] ?? d['profesional_id'] ?? '') as String;
        final duracion = (d['duracion_minutos'] as num?)?.toInt() ?? 0;
        final servicios = d['servicios'] as List? ?? [];
        final importe = servicios.fold<double>(
            0, (s, x) => s + ((x['precio'] as num?)?.toDouble() ?? 0));
        final horaInicio = d['hora_inicio'] as String? ?? '';
        final hora = int.tryParse(horaInicio.split(':').firstOrNull ?? '') ?? -1;

        if (profId.isNotEmpty) {
          porEmpleado.putIfAbsent(profId, () => _StatEmpleadoBuilder(profId));
          porEmpleado[profId]!.agregar(duracion, importe, hora, doc.data());
        }

        for (final srv in servicios) {
          final nombre = (srv['nombre'] as String?) ?? 'Servicio';
          final precio = (srv['precio'] as num?)?.toDouble() ?? 0;
          porServicio.putIfAbsent(nombre, () => _StatServicioBuilder(nombre));
          porServicio[nombre]!.agregar(duracion, precio);
        }
      }

      setState(() {
        _empleados = porEmpleado.values
            .map((b) => b.build(_nombresPorId))
            .toList()
          ..sort((a, b) => b.citasCompletadas.compareTo(a.citasCompletadas));
        _servicios = porServicio.values
            .map((b) => b.build())
            .toList()
          ..sort((a, b) => b.veces.compareTo(a.veces));
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final fmtFecha = DateFormat('dd/MM/yy');
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return Column(children: [
      // Handle
      Container(
        width: 36, height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: t.textoPrimario.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2)),
      ),
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(children: [
          Icon(Icons.bar_chart_rounded, color: t.primario, size: 20),
          const SizedBox(width: 8),
          Text('Estadísticas de empleados',
              style: TextStyle(color: t.textoPrimario, fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
      // Filtros rápidos de período
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final entry in [
              (0, 'Hoy'), (1, 'Ayer'), (2, '7 días'), (3, '30 días'),
            ]) ...[
              _ChipFiltro(
                label: entry.$2,
                seleccionado: _filtroRapido == entry.$1,
                tema: t,
                onTap: () => _aplicarFiltroRapido(entry.$1),
              ),
              const SizedBox(width: 6),
            ],
            _ChipFiltro(
              label: _filtroRapido == 4
                  ? '${fmtFecha.format(_desde)}–${fmtFecha.format(_hasta)}'
                  : 'Personalizado',
              seleccionado: _filtroRapido == 4,
              tema: t,
              icono: Icons.date_range,
              onTap: _seleccionarRango,
            ),
          ]),
        ),
      ),
      Divider(color: t.divisor, height: 1),
      Expanded(
        child: _cargando
            ? Center(child: CircularProgressIndicator(color: t.primario))
            : ListView(
                controller: widget.scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  if (_empleados.isEmpty && _servicios.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Sin citas completadas en el período',
                            style: TextStyle(color: t.textoSecundario)),
                      ),
                    )
                  else ...[
                    // ── Por empleado ──
                    _SectionHeader(label: 'Por empleado', tema: t),
                    const SizedBox(height: 8),
                    ..._empleados.map((e) => _TarjetaEmpleado(
                  e: e, tema: t, fmt: fmt,
                  onTap: () => _mostrarDetalleEmpleado(e),
                )),
                    const SizedBox(height: 20),
                    // ── Por servicio ──
                    _SectionHeader(label: 'Top servicios', tema: t),
                    const SizedBox(height: 8),
                    ..._servicios.take(10).map((s) =>
                        _FilaServicio(s: s, tema: t, fmt: fmt)),
                  ],
                ],
              ),
      ),
    ]);
  }

  void _mostrarDetalleEmpleado(_StatEmpleado e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.tema.superficie,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, sc) => _DetalleEmpleadoSheet(
            e: e, tema: widget.tema, scrollCtrl: sc),
      ),
    );
  }

  void _aplicarFiltroRapido(int idx) {
    final hoy = DateTime.now();
    DateTime desde, hasta;
    switch (idx) {
      case 0: desde = hasta = hoy; break;
      case 1: desde = hasta = hoy.subtract(const Duration(days: 1)); break;
      case 2: desde = hoy.subtract(const Duration(days: 6)); hasta = hoy; break;
      case 3: default: desde = hoy.subtract(const Duration(days: 29)); hasta = hoy; break;
    }
    setState(() { _filtroRapido = idx; _desde = desde; _hasta = hasta; });
    _cargar();
  }

  Future<void> _seleccionarRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
      locale: const Locale('es', 'ES'),
    );
    if (rango != null) {
      setState(() {
        _filtroRapido = 4;
        _desde = rango.start;
        _hasta = rango.end;
      });
      _cargar();
    }
  }
}

// ── Modelos de datos para stats ────────────────────────────────────────────

class _CitaDetalle {
  final String fecha;
  final String horaInicio;
  final int duracionMin;
  final String clienteNombre;
  final List<Map<String, dynamic>> servicios;
  final double importe;

  const _CitaDetalle({
    required this.fecha, required this.horaInicio,
    required this.duracionMin, required this.clienteNombre,
    required this.servicios, required this.importe,
  });
}

class _StatEmpleado {
  final String profId;
  final String nombre;
  final int citasCompletadas;
  final int minutosTotales;
  final double ingresosTotales;
  final Map<int, int> citasPorHora;
  final List<_CitaDetalle> citas;

  double get minutosMedio =>
      citasCompletadas == 0 ? 0 : minutosTotales / citasCompletadas;
  double get ingresoMedio =>
      citasCompletadas == 0 ? 0 : ingresosTotales / citasCompletadas;

  const _StatEmpleado({
    required this.profId, required this.nombre,
    required this.citasCompletadas, required this.minutosTotales,
    required this.ingresosTotales, required this.citasPorHora,
    required this.citas,
  });
}

class _StatEmpleadoBuilder {
  final String profId;
  int citas = 0, minutos = 0;
  double ingresos = 0;
  final Map<int, int> porHora = {};
  final List<_CitaDetalle> detalles = [];

  _StatEmpleadoBuilder(this.profId);

  void agregar(int dur, double ing, int hora, Map<String, dynamic> data) {
    citas++;
    minutos += dur;
    ingresos += ing;
    if (hora >= 0) porHora[hora] = (porHora[hora] ?? 0) + 1;
    final servicios = (data['servicios'] as List?)
            ?.map((s) => Map<String, dynamic>.from(s as Map))
            .toList() ??
        [];
    detalles.add(_CitaDetalle(
      fecha: data['fecha'] as String? ?? '',
      horaInicio: data['hora_inicio'] as String? ?? '',
      duracionMin: dur,
      clienteNombre: data['cliente_nombre'] as String? ?? 'Cliente',
      servicios: servicios,
      importe: ing,
    ));
  }

  _StatEmpleado build(Map<String, String> nombres) => _StatEmpleado(
    profId: profId,
    nombre: nombres[profId] ?? profId,
    citasCompletadas: citas,
    minutosTotales: minutos,
    ingresosTotales: ingresos,
    citasPorHora: porHora,
    citas: detalles..sort((a, b) {
      final c = b.fecha.compareTo(a.fecha);
      return c != 0 ? c : b.horaInicio.compareTo(a.horaInicio);
    }),
  );
}

class _StatServicio {
  final String nombre;
  final int veces;
  final int duracionMediaMin;
  final double precioMedio;

  const _StatServicio({required this.nombre, required this.veces,
      required this.duracionMediaMin, required this.precioMedio});
}

class _StatServicioBuilder {
  final String nombre;
  int veces = 0, minTotales = 0;
  double precioTotal = 0;

  _StatServicioBuilder(this.nombre);

  void agregar(int dur, double precio) {
    veces++;
    minTotales += dur;
    precioTotal += precio;
  }

  _StatServicio build() => _StatServicio(
    nombre: nombre, veces: veces,
    duracionMediaMin: veces == 0 ? 0 : minTotales ~/ veces,
    precioMedio: veces == 0 ? 0 : precioTotal / veces,
  );
}

// ── Widgets de display ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final _TpvTema tema;
  const _SectionHeader({required this.label, required this.tema});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
            color: tema.primario, fontSize: 13, fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      );
}

class _ChipFiltro extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final _TpvTema tema;
  final VoidCallback onTap;
  final IconData? icono;
  const _ChipFiltro({required this.label, required this.seleccionado,
      required this.tema, required this.onTap, this.icono});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: seleccionado ? tema.primario : tema.primario.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icono != null) ...[
              Icon(icono, size: 12,
                  color: seleccionado ? Colors.white : tema.primario),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: seleccionado ? Colors.white : tema.primario)),
          ]),
        ),
      );
}

class _TarjetaEmpleado extends StatelessWidget {
  final _StatEmpleado e;
  final _TpvTema tema;
  final NumberFormat fmt;
  final VoidCallback? onTap;
  const _TarjetaEmpleado({required this.e, required this.tema,
      required this.fmt, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = profColorPorId(e.profId);
    // Hora pico
    final horaPico = e.citasPorHora.isEmpty ? -1
        : e.citasPorHora.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tema.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 16, backgroundColor: color,
            child: Text(e.nombre.isNotEmpty ? e.nombre[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(e.nombre,
              style: TextStyle(color: tema.textoPrimario, fontWeight: FontWeight.w700, fontSize: 14))),
          Text(fmt.format(e.ingresosTotales),
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _KpiChip(icon: Icons.event_available_rounded,
              label: '${e.citasCompletadas} citas', tema: tema),
          const SizedBox(width: 8),
          _KpiChip(icon: Icons.timer_outlined,
              label: '${e.minutosMedio.toStringAsFixed(0)} min/cita', tema: tema),
          const SizedBox(width: 8),
          _KpiChip(icon: Icons.euro_rounded,
              label: '${fmt.format(e.ingresoMedio)}/cita', tema: tema),
          if (horaPico >= 0) ...[
            const SizedBox(width: 8),
            _KpiChip(icon: Icons.access_time_rounded,
                label: 'Pico ${horaPico.toString().padLeft(2, "0")}h', tema: tema),
          ],
        ]),
        if (onTap != null) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('Ver detalle ',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            Icon(Icons.chevron_right, size: 14, color: color),
          ]),
        ),
      ]),
    ));  // GestureDetector + Container
  }
}

class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final _TpvTema tema;
  const _KpiChip({required this.icon, required this.label, required this.tema});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tema.textoPrimario.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: tema.textoSecundario),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: tema.textoPrimario,
              fontWeight: FontWeight.w600)),
        ]),
      );
}

class _FilaServicio extends StatelessWidget {
  final _StatServicio s;
  final _TpvTema tema;
  final NumberFormat fmt;
  const _FilaServicio({required this.s, required this.tema, required this.fmt});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(s.nombre,
              style: TextStyle(color: tema.textoPrimario, fontSize: 13,
                  fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: tema.primario.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text('×${s.veces}',
                style: TextStyle(color: tema.primario, fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Text('${s.duracionMediaMin} min',
              style: TextStyle(color: tema.textoSecundario, fontSize: 12)),
          const SizedBox(width: 8),
          Text(fmt.format(s.precioMedio),
              style: TextStyle(color: tema.textoPrimario, fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Vista detalle de un empleado ───────────────────────────────────────────

class _DetalleEmpleadoSheet extends StatelessWidget {
  final _StatEmpleado e;
  final _TpvTema tema;
  final ScrollController scrollCtrl;

  const _DetalleEmpleadoSheet({
    required this.e, required this.tema, required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = profColorPorId(e.profId);
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final fmtFecha = DateFormat('dd/MM/yyyy', 'es_ES');

    return Column(children: [
      Container(
        width: 36, height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: tema.textoPrimario.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2)),
      ),
      // Header empleado
      Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: color,
              child: Text(e.nombre.isNotEmpty ? e.nombre[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(e.nombre,
                style: TextStyle(color: tema.textoPrimario, fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text('${e.citasCompletadas} citas  ·  '
                '${e.minutosMedio.toStringAsFixed(0)} min/cita  ·  '
                '${fmt.format(e.ingresosTotales)}',
                style: TextStyle(color: tema.textoSecundario, fontSize: 12)),
          ])),
        ]),
      ),
      Divider(color: tema.divisor, height: 1),
      Expanded(
        child: e.citas.isEmpty
            ? Center(child: Text('Sin citas registradas',
                style: TextStyle(color: tema.textoSecundario)))
            : ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: e.citas.length,
                separatorBuilder: (_, __) =>
                    Divider(color: tema.divisor, height: 1),
                itemBuilder: (_, i) {
                  final c = e.citas[i];
                  final fecha = DateTime.tryParse(c.fecha);
                  final serviciosTxt = c.servicios.isNotEmpty
                      ? c.servicios
                          .map((s) => s['nombre'] as String? ?? '')
                          .where((s) => s.isNotEmpty)
                          .join(', ')
                      : 'Sin servicio';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      // Hora
                      SizedBox(
                        width: 48,
                        child: Text(c.horaInicio,
                            style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(c.clienteNombre,
                            style: TextStyle(
                                color: tema.textoPrimario,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(serviciosTxt,
                            style: TextStyle(
                                color: tema.textoSecundario, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (fecha != null)
                          Text(fmtFecha.format(fecha),
                              style: TextStyle(
                                  color: tema.textoSecundario, fontSize: 11)),
                      ])),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                        Text(fmt.format(c.importe),
                            style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Text('${c.duracionMin} min',
                            style: TextStyle(
                                color: tema.textoSecundario, fontSize: 11)),
                      ]),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}
