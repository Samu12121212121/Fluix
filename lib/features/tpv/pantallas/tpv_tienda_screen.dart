// tpv_tienda_screen.dart — versión completa
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../domain/modelos/comanda.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../services/pedidos_service.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../widgets/tpv_type_switcher.dart';
import '../widgets/dialogo_factura_tpv.dart';
import '../widgets/dialogo_devoluciones.dart';
import '../widgets/empleados_banner_widget.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import '../../../services/tpv/impresora_service.dart';
import '../../../services/tpv/cierre_caja_service.dart';
import 'tpv_peluqueria_screen.dart' show PelCierreDeCaja;
import '../../../services/tpv/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/tpv/terminal_fisica_service.dart';
import '../../../services/verifactu/qr_service.dart';
import '../../pedidos/widgets/variante_selector_widget.dart';
import 'configuracion_facturacion_tpv_screen.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../../widgets/tpv/historial_tickets_widget.dart';
import '../../../widgets/tpv/hold_pedidos_widget.dart';
import '../../../widgets/tpv/descuento_linea_widget.dart';
import '../../../widgets/tpv/cupon_input_widget.dart';
import '../../../widgets/tpv/estadisticas_turno_widget.dart';
import '../../../widgets/tpv/arqueo_caja_widget.dart';
import '../../../widgets/tpv/cliente_buscador_tpv.dart';
import '../../../widgets/tpv/teclado_numerico_widget.dart';
import '../../../widgets/tpv/pedidos_web_widget.dart';
import '../../../core/widgets/flux_toast.dart';

/// Acciones del TPV expuestas al header embebido del dashboard.
/// Todos los campos son opcionales: cada tipo de TPV rellena los que aplican.
class TpvEmbedActions {
  final VoidCallback? nuevaVenta;      // solo tienda
  final VoidCallback? abrirCajon;
  final VoidCallback? aperturaCaja;
  final VoidCallback? cierreCaja;
  final VoidCallback? verHistorial;
  final VoidCallback? verHold;
  final ValueNotifier<int>? holdCount;   // badge reactivo
  final VoidCallback? masOpciones;       // abre bottom sheet con opciones extra
  final VoidCallback? toggleTema;        // alterna claro/oscuro en el TPV
  final ValueNotifier<bool>? temaOscuro; // estado reactivo del tema

  const TpvEmbedActions({
    this.nuevaVenta,
    this.abrirCajon,
    this.aperturaCaja,
    this.cierreCaja,
    this.verHistorial,
    this.verHold,
    this.holdCount,
    this.masOpciones,
    this.toggleTema,
    this.temaOscuro,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// ESTADO EXTENDIDO DEL TICKET (descuento + cliente — sin tocar modelos)
// ═══════════════════════════════════════════════════════════════════════════

class _TicketExtra {
  final double descuento;       // importe € descontado
  final double descuentoPct;    // % aplicado
  final String? clienteNombre;
  final String? clienteId;

  const _TicketExtra({
    this.descuento = 0,
    this.descuentoPct = 0,
    this.clienteNombre,
    this.clienteId,
  });

  _TicketExtra copyWith({
    double? descuento,
    double? descuentoPct,
    String? clienteNombre,
    String? clienteId,
    bool limpiarCliente = false,
    bool limpiarDescuento = false,
  }) =>
      _TicketExtra(
        descuento: limpiarDescuento ? 0 : (descuento ?? this.descuento),
        descuentoPct:
        limpiarDescuento ? 0 : (descuentoPct ?? this.descuentoPct),
        clienteNombre:
        limpiarCliente ? null : (clienteNombre ?? this.clienteNombre),
        clienteId: limpiarCliente ? null : (clienteId ?? this.clienteId),
      );
}

// Helper: copia LineaComanda cambiando precioUnitario (copyWith no lo expone)
LineaComanda _lineaConPrecio(LineaComanda l, double nuevoPrecio) =>
    LineaComanda(
      productoId: l.productoId,
      nombre: l.nombre,
      cantidad: l.cantidad,
      precioUnitario: nuevoPrecio,
      ivaPorcentaje: l.ivaPorcentaje,
      notas: l.notas,
      esNuevo: l.esNuevo,
      imagenUrl: l.imagenUrl,
    );

// ═══════════════════════════════════════════════════════════════════════════
// TIPO auxiliar
// ═══════════════════════════════════════════════════════════════════════════

typedef _ProductoEntry = ({
Producto producto,
int? stock,
int stockMinimo,
String? codigoBarras,
});

// ═══════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

class TpvTiendaScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final bool esPropietario;
  /// Cuando [embedded] = true la pantalla se muestra dentro del dashboard
  /// (columna izquierda del menú visible). No bloquea la orientación ni
  /// muestra el botón de volver ni el header propio.
  final bool embedded;

  /// Callback que se invoca con las [TpvEmbedActions] cuando el TPV está listo
  /// en modo embebido, para que el dashboard las muestre en su propio header.
  final void Function(TpvEmbedActions)? onEmbedReady;

  const TpvTiendaScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
    this.esPropietario = false,
    this.embedded = false,
    this.onEmbedReady,
  });

  @override
  State<TpvTiendaScreen> createState() => _TpvTiendaState();
}

class _TpvTiendaState extends State<TpvTiendaScreen> {
  final _db = FirebaseFirestore.instance;

  Comanda? _comandaActiva;
  _TicketExtra _extra = const _TicketExtra();

  // Hold (pedidos en espera)
  final _holdNotifier = HoldPedidosNotifier();
  late final ValueNotifier<int> _holdCountNotifier;

  // Pedidos web (tienda online)
  final _pedidosWebNotifier = PedidosWebNotifier();

  // Cupón
  String? _cuponId;
  double _cuponDescuento = 0;

  // Descuentos por línea: productoId → importe total descontado (€)
  final Map<String, double> _descuentosLinea = {};

  String _categoriaFiltro = 'Todos';
  String _busqueda = '';
  List<String> _categoriasOcultas = [];
  bool _mostrandoCierre = false;
  bool _cajaAbiertaHoy  = false;
  bool _cajaCerradaHoy  = false;
  bool _modoOscuro      = false;
  String? _empleadoSeleccionadoId; // ← empleado activo en el turno

  Timer? _relojTimer;
  String _horaActual = '';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _estaOnline = true;
  bool _btConectado = false;

  bool get _esAdmin => widget.esAdmin || widget.esPropietario;

  @override
  void initState() {
    super.initState();
    _holdCountNotifier = ValueNotifier(0);
    _holdNotifier.addListener(() => _holdCountNotifier.value = _holdNotifier.pedidos.length);
    if (!widget.embedded) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _actualizarHora();
    _relojTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _actualizarHora());
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) {
      if (mounted)
        setState(() => _estaOnline = !r.contains(ConnectivityResult.none));
    });
    Connectivity().checkConnectivity().then((r) {
      if (mounted)
        setState(() => _estaOnline = !r.contains(ConnectivityResult.none));
    });
    ImpressoraBluetooth()
        .estaConectada()
        .then((v) => mounted ? setState(() => _btConectado = v) : null);
    _pedidosWebNotifier.iniciar(widget.empresaId);
    // Cargar categorías ocultas (ej. 'General' en cuentas que lo configuren)
    FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('configuracion').doc('tpv')
        .get()
        .then((doc) {
      if (doc.exists && mounted) {
        final lista = List<String>.from(doc.data()?['categorias_ocultas'] as List? ?? []);
        if (lista.isNotEmpty) setState(() => _categoriasOcultas = lista);
      }
    }).catchError((_) {});
    // Inicializar terminal física si está configurada
    TpvFacturacionService().obtenerConfig(widget.empresaId).then((cfg) {
      if (cfg.terminalFisicaIp.isNotEmpty) {
        TerminalFisicaService().configurar(
          ip: cfg.terminalFisicaIp,
          puerto: cfg.terminalFisicaPuerto,
          protocolo: ProtocoloTerminal.values.firstWhere(
            (p) => p.name == cfg.terminalFisicaProtocolo,
            orElse: () => ProtocoloTerminal.manual,
          ),
        );
      }
    }).catchError((_) {});
    // Verificar si hay apertura de caja para hoy; si no, pedirla al arrancar
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarAperturaCaja());
    // Registrar acciones en el header del dashboard (solo modo embebido)
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onEmbedReady?.call(TpvEmbedActions(
          nuevaVenta: _limpiarTicket,
          abrirCajon: () { _abrirCajonFisico(); },
          aperturaCaja: () { _mostrarAperturaCaja(); },
          cierreCaja: () => setState(() => _mostrandoCierre = true),
          verHistorial: () => HistorialTicketsWidget.mostrar(context, widget.empresaId),
          verHold: () async {
            final recuperado = await HoldPedidosWidget.mostrar(context, _holdNotifier);
            if (recuperado != null && mounted) {
              final lineas = recuperado.lineas.map((m) => LineaComanda(
                productoId: m['productoId'] as String? ?? '',
                nombre: m['nombre'] as String? ?? '',
                cantidad: (m['cantidad'] as num?)?.toInt() ?? 1,
                precioUnitario: (m['precioUnitario'] as num?)?.toDouble() ?? 0,
                ivaPorcentaje: (m['ivaPorcentaje'] as num?)?.toDouble() ?? 21,
                notas: m['notas'] as String?,
              )).toList();
              final base = _comandaActiva ?? Comanda(
                id: _db.collection('empresas').doc(widget.empresaId).collection('comandas').doc().id,
                mesaId: null, camareroUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                lineas: [], estado: 'abierta', apertura: Timestamp.now(), importeTotal: 0,
              );
              setState(() => _comandaActiva = base.copyWith(lineas: [...base.lineas, ...lineas]));
            }
          },
          holdCount: _holdCountNotifier,
          masOpciones: () => _mostrarMasOpcionesTPV(context),
        ));
      });
    }
  }

  Future<void> _mostrarMasOpcionesTPV(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Tickets del turno'),
              onTap: () { Navigator.pop(ctx); HistorialTicketsWidget.mostrar(ctx, widget.empresaId); },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Estadísticas del turno'),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(context: ctx, isScrollControlled: true,
                    backgroundColor: const Color(0xFF0A0F23),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => EstadisticasTurnoWidget(empresaId: widget.empresaId));
              },
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('Arqueo de caja'),
              onTap: () { Navigator.pop(ctx); _mostrarArqueoIntermedio(); },
            ),
            ListTile(
              leading: const Icon(Icons.keyboard_return_outlined),
              title: const Text('Devoluciones'),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(context: ctx,
                    builder: (_) => DialogoDevoluciones(
                        empresaId: widget.empresaId,
                        colorPrimario: const Color(0xFF3B82F6)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Configurar impresora'),
              onTap: () { Navigator.pop(ctx); _mostrarConfigImpresora(); },
            ),
            if (_esAdmin)
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Configuración TPV'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => ConfiguracionFacturacionTpvScreen(
                          empresaId: widget.empresaId,
                          esPropietario: widget.esPropietario)));
                },
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Future<void> _verificarAperturaCaja() async {
    if (!mounted) return;
    final hoy    = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin    = inicio.add(const Duration(days: 1));
    try {
      final snap = await _db
          .collection('empresas').doc(widget.empresaId)
          .collection('aperturas_caja')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin))
          .limit(1)
          .get();
      final yaAbierta = snap.docs.isNotEmpty;
      if (mounted) setState(() => _cajaAbiertaHoy = yaAbierta);
      if (!yaAbierta && mounted) {
        await _mostrarAperturaCaja();
      }
      // Verificar también si ya hay cierre hoy
      await _verificarCierreHoy();
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al verificar caja: $e');
    }
  }

  Future<void> _verificarCierreHoy() async {
    try {
      final hoy     = DateTime.now();
      final fechaStr = '${hoy.year}-${hoy.month.toString().padLeft(2,'0')}-${hoy.day.toString().padLeft(2,'0')}';
      final doc = await _db.collection('empresas').doc(widget.empresaId)
          .collection('cierres_caja').doc(fechaStr).get();
      if (!mounted) return;
      final cerrada = doc.exists &&
          ((doc.data() ?? {}).containsKey('cierre') || (doc.data() ?? {}).containsKey('total'));
      setState(() => _cajaCerradaHoy = cerrada);
    } catch (_) {}
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
    _connectivitySub?.cancel();
    _holdNotifier.dispose();
    _holdCountNotifier.dispose();
    _pedidosWebNotifier.dispose();
    if (!widget.embedded) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  void _actualizarHora() {
    if (mounted)
      setState(
              () => _horaActual = DateFormat('HH:mm').format(DateTime.now()));
  }

  double get _totalDescuentosLinea =>
      _descuentosLinea.values.fold(0.0, (a, b) => a + b);

  double get _totalConDescuento =>
      ((_comandaActiva?.total ?? 0) - _extra.descuento - _totalDescuentosLinea - _cuponDescuento)
          .clamp(0, double.infinity);

  void _limpiarTicket() => setState(() {
    _comandaActiva = null;
    _extra = const _TicketExtra();
    _cuponId = null;
    _cuponDescuento = 0;
    _descuentosLinea.clear();
  });

  Future<void> _abrirCajonFisico() async {
    try {
      final cfg = await TpvFacturacionService().obtenerConfig(widget.empresaId);
      await ImpresoraService().abrirCajonSiProcede(
        config: cfg.copyWith(abrirCajonAlCobrar: true, abrirCajonSoloEfectivo: false),
        metodoPago: 'efectivo',
      );
      if (mounted) FluxToast.exito(context, 'Cajón abierto');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al abrir cajón: $e');
    }
  }

  // Paleta nueva — limpia y moderna (imagen de referencia)
  static const _kW  = Colors.white;
  static const _kBlu= Color(0xFF3B82F6);

  @override
  // Colores adaptativos al modo oscuro
  Color get _bgTPV    => _modoOscuro ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);
  Color get _surfTPV  => _modoOscuro ? const Color(0xFF1E293B) : Colors.white;
  Color get _txtTPV   => _modoOscuro ? const Color(0xFFE2E8F0) : const Color(0xFF111827);
  Color get _bordeTPV => _modoOscuro ? const Color(0xFF334155) : const Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTPV,
      body: _mostrandoCierre
          ? Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _mostrandoCierre = false),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 13),
                    label: const Text('Volver a ventas', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF374151)),
                  ),
                  const SizedBox(width: 12),
                  const Text('Cierre de caja',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                ]),
              ),
              Expanded(child: PelCierreDeCaja(
                empresaId: widget.empresaId,
                fecha: DateTime.now(),
              )),
            ])
          : Column(children: [
              // Header propio solo cuando NO está embebido en el dashboard
              if (!widget.embedded) _buildHeaderBlanco(),
              // ── Layout principal ───────────────────────────────────────────
              Expanded(child: Row(children: [
                // Catálogo 65%
                Expanded(
                  flex: 65,
                  child: _TiendaCatalogoPanel(
                    empresaId: widget.empresaId,
                    esAdmin: _esAdmin,
                    categoriaFiltro: _categoriaFiltro,
                    busqueda: _busqueda,
                    categoriasOcultas: _categoriasOcultas,
                    onCategoriaChanged: (c) => setState(() => _categoriaFiltro = c),
                    onBusquedaChanged: (b) => setState(() => _busqueda = b),
                    onProductoSeleccionado: _agregarProducto,
                    onProductoNoEncontrado: (codigo) => _productoNoEncontrado(codigo),
                  ),
                ),
                // Divider
                Container(width: 1, color: const Color(0xFFE5E7EB)),
                // Carrito 35%
                Expanded(
                  flex: 35,
                  child: _TiendaComandaPanel(
                    empresaId: widget.empresaId,
                    comandaActiva: _comandaActiva,
                    extra: _extra,
                    totalConDescuento: _totalConDescuento,
                    onComandaActualizada: (c) => setState(() => _comandaActiva = c),
                    onExtraChanged: (e) => setState(() => _extra = e),
                    onCobrado: _limpiarTicket,
                    onLimpiar: _limpiarTicket,
                    onProductoLibre: () => _agregarProductoLibre(),
                    holdNotifier: _holdNotifier,
                    onNuevoTicket: _nuevoTicket,
                    onSwitchToHold: _switchToHold,
                    cuponId: _cuponId,
                    cuponDescuento: _cuponDescuento,
                    onCuponAplicado: (id, desc) => setState(() { _cuponId = id; _cuponDescuento = desc; }),
                    onCuponRetirado: () => setState(() { _cuponId = null; _cuponDescuento = 0; }),
                    descuentosLinea: Map.unmodifiable(_descuentosLinea),
                    onDescuentoLineaChanged: (productoId, importe) =>
                        setState(() => _descuentosLinea[productoId] = importe),
                  ),
                ),
              ])),
            ]),
    );
  }

  Widget _buildHeaderBlanco() {
    return Column(children: [
      Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
      decoration: BoxDecoration(
        color: _surfTPV,
        border: Border(bottom: BorderSide(color: _bordeTPV)),
      ),
      child: Row(children: [
        // Volver — solo si no está embebido en el dashboard
        if (!widget.embedded) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 15, color: Color(0xFF6B7280)),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Volver',
          ),
          const SizedBox(width: 4),
        ],
        // Título
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Venta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          Text('Busca productos, añade al carrito y procesa el pago.',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ]),
        const Spacer(),
        // Botones acción
        OutlinedButton.icon(
          onPressed: _cajaAbiertaHoy ? _abrirCajonFisico : _mostrarAperturaCaja,
          icon: Icon(
            _cajaAbiertaHoy ? Icons.point_of_sale_outlined : Icons.lock_open_outlined,
            size: 14,
          ),
          label: Text(
            _cajaAbiertaHoy ? 'Abrir cajón' : 'Abrir caja',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _cajaAbiertaHoy
                ? const Color(0xFF374151)
                : const Color(0xFF16A34A),
            side: BorderSide(
              color: _cajaAbiertaHoy
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFF16A34A),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _limpiarTicket,
          icon: const Icon(Icons.add_rounded, size: 14),
          label: const Text('Nueva venta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: _kBlu,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 4),
        // Botón modo oscuro / claro
        Tooltip(
          message: _modoOscuro ? 'Modo claro' : 'Modo oscuro',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _modoOscuro = !_modoOscuro),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _modoOscuro ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _modoOscuro ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                size: 16,
                color: _modoOscuro ? const Color(0xFFFBBF24) : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Configuración TPV — acceso directo en el header (admin)
        if (_esAdmin)
          Tooltip(
            message: 'Configuración TPV',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ConfiguracionFacturacionTpvScreen(
                      empresaId: widget.empresaId,
                      esPropietario: widget.esPropietario))),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF6B7280)),
              ),
            ),
          ),
        const SizedBox(width: 4),
        // Más opciones
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
          onSelected: (v) {
            if (v == 'historial') HistorialTicketsWidget.mostrar(context, widget.empresaId);
            if (v == 'arqueo') _mostrarArqueoIntermedio();
            if (v == 'cierre') setState(() => _mostrandoCierre = true);
            if (v == 'devoluciones') showDialog(context: context,
                builder: (_) => DialogoDevoluciones(empresaId: widget.empresaId, colorPrimario: _kBlu));
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'historial', child: ListTile(leading: Icon(Icons.receipt_long_outlined), title: Text('Historial de tickets'), contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: 'arqueo', child: ListTile(leading: Icon(Icons.calculate_outlined), title: Text('Arqueo de caja'), contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: 'devoluciones', child: ListTile(leading: Icon(Icons.keyboard_return_outlined), title: Text('Devoluciones'), contentPadding: EdgeInsets.zero)),
            PopupMenuDivider(),
            PopupMenuItem(value: 'cierre', child: ListTile(leading: Icon(Icons.summarize_outlined), title: Text('Cierre de caja'), contentPadding: EdgeInsets.zero)),
          ],
        ),
      ]),
      ),
      // Banner caja cerrada
      if (_cajaCerradaHoy)
        Container(
          color: Colors.orange.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 15),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Caja cerrada hoy. Las ventas que hagas se contarán en el siguiente turno.',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
            )),
          ]),
        ),
    ]);
  }

  // Sage Green — paleta del template de peluquería
  static const _kBg      = Color(0xFF1A3A27);  // AppBar — texto oscuro sage
  static const _kBg2     = Color(0xFF1F3D29);  // AppBar sección secundaria
  static const _kAccent  = Color(0xFF81B29A);  // Sage secundario

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kBg,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 52,
      title: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // ── Volver ─────────────────────────────────────────────────────────
        Material(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white70),
            ),
          ),
        ),
        const SizedBox(width: 14),
        // ── Logo + nombre empresa ───────────────────────────────────────────
        StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('empresas').doc(widget.empresaId).snapshots(),
          builder: (_, snap) {
            final data = snap.hasData && snap.data!.exists
                ? snap.data!.data() as Map<String, dynamic>
                : <String, dynamic>{};
            final nombre = data['nombre'] as String? ?? 'TPV Tienda';
            final logo   = data['logo_url'] as String?;
            return Row(children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: _kAccent.withValues(alpha: 0.2),
                backgroundImage: logo != null ? NetworkImage(logo) : null,
                child: logo == null
                    ? Text(nombre[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _kAccent))
                    : null,
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
                const Text('TPV Tienda',
                    style: TextStyle(fontSize: 9, color: Colors.white38, letterSpacing: 0.5)),
              ]),
            ]);
          },
        ),
        const Spacer(),
        // ── Grupo acciones ─────────────────────────────────────────────────
        _AppBarGroup(children: [
          _AppBarBtn(Icons.keyboard_return_outlined, 'Devoluciones', () => showDialog(
            context: context,
            builder: (_) => DialogoDevoluciones(empresaId: widget.empresaId, colorPrimario: _kAccent),
          )),
          _AppBarBtn(Icons.account_balance_wallet_outlined, 'Apertura caja', _mostrarAperturaCaja),
          _AppBarBtn(Icons.calculate_outlined, 'Arqueo de caja', _mostrarArqueoIntermedio),
          _AppBarBtn(Icons.receipt_long_outlined, 'Historial', () => HistorialTicketsWidget.mostrar(context, widget.empresaId)),
        ]),
        const SizedBox(width: 8),
        // ── Hold badge ─────────────────────────────────────────────────────
        _AppBarGroup(children: [
          Stack(clipBehavior: Clip.none, children: [
            _AppBarBtn(Icons.pause_circle_outline, 'En espera', () async {
              final recuperado = await HoldPedidosWidget.mostrar(context, _holdNotifier);
              if (recuperado != null && mounted) {
                final lineas = recuperado.lineas.map((m) => LineaComanda(
                  productoId: m['productoId'] as String? ?? '',
                  nombre: m['nombre'] as String? ?? '',
                  cantidad: (m['cantidad'] as num?)?.toInt() ?? 1,
                  precioUnitario: (m['precioUnitario'] as num?)?.toDouble() ?? 0,
                  ivaPorcentaje: (m['ivaPorcentaje'] as num?)?.toDouble() ?? 21,
                  notas: m['notas'] as String?,
                  esNuevo: false,
                )).toList();
                final base = _comandaActiva ?? Comanda(
                  id: _db.collection('empresas').doc(widget.empresaId).collection('comandas').doc().id,
                  mesaId: null,
                  camareroUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                  lineas: [], estado: 'abierta', apertura: Timestamp.now(), importeTotal: 0,
                );
                setState(() => _comandaActiva = base.copyWith(lineas: [...base.lineas, ...lineas]));
              }
            }),
            ListenableBuilder(
              listenable: _holdNotifier,
              builder: (_, __) => _holdNotifier.pedidos.isEmpty ? const SizedBox.shrink()
                  : Positioned(top: 2, right: 2,
                      child: CircleAvatar(radius: 6, backgroundColor: Colors.red,
                          child: Text('${_holdNotifier.pedidos.length}',
                              style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)))),
            ),
          ]),
          // Pedidos web badge
          Stack(clipBehavior: Clip.none, children: [
            _AppBarBtn(Icons.shopping_bag_outlined, 'Pedidos online',
                () => PedidosWebWidget.mostrar(context, widget.empresaId)),
            ListenableBuilder(
              listenable: _pedidosWebNotifier,
              builder: (_, __) => _pedidosWebNotifier.pendientes == 0 ? const SizedBox.shrink()
                  : Positioned(top: 2, right: 2,
                      child: CircleAvatar(radius: 6, backgroundColor: Colors.orange,
                          child: Text('${_pedidosWebNotifier.pendientes}',
                              style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)))),
            ),
          ]),
        ]),
        const SizedBox(width: 8),
        // ── Info barra ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kBg2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(children: [
            Text(_horaActual, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
            const SizedBox(width: 8),
            Icon(_estaOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 13, color: _estaOnline ? _kAccent : Colors.orange),
            const SizedBox(width: 6),
            Icon(Icons.print_rounded, size: 13,
                color: _btConectado ? Colors.white54 : Colors.white24),
          ]),
        ),
        const SizedBox(width: 8),
        // ── Cierre de caja ─────────────────────────────────────────────────
        Tooltip(
          message: _mostrandoCierre ? 'Volver a ventas' : 'Cierre de caja',
          child: Material(
            color: _mostrandoCierre ? _kAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _mostrandoCierre = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  Icon(Icons.summarize_outlined, size: 14,
                      color: _mostrandoCierre ? _kAccent : Colors.white54),
                  const SizedBox(width: 5),
                  Text(_mostrandoCierre ? 'Ventas' : 'Cierre',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: _mostrandoCierre ? _kAccent : Colors.white54)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ]),
    );
  }

  // ── Agregar producto del catálogo ────────────────────────────────────────

  Future<void> _agregarProducto(Producto producto, VarianteProducto? variante) async {
    double precioBase = variante?.precioEfectivo(producto.precio) ?? producto.precio;

    // Si el producto tiene precio2 y no es una variante, preguntar cuál usar
    if (producto.precio2 != null && variante == null) {
      final etiqueta1 = 'Precio 1';
      final etiqueta2 = producto.etiquetaPrecio2?.isNotEmpty == true
          ? producto.etiquetaPrecio2!
          : 'Precio 2';
      final elegido = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.price_change_outlined, color: Color(0xFF7B1FA2)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Seleccionar precio', style: TextStyle(fontSize: 15))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(producto.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 16),
            _opcionPrecioBtn(ctx, etiqueta1, precioBase),
            const SizedBox(height: 8),
            _opcionPrecioBtn(ctx, etiqueta2, producto.precio2!),
          ]),
        ),
      );
      if (elegido == null) return; // cancelado
      precioBase = elegido;
    }

    final linea = LineaComanda(
      productoId: producto.id,
      nombre: variante != null
          ? '${producto.nombre} (${variante.nombre})'
          : producto.nombre,
      cantidad: 1,
      precioUnitario: precioBase,
      ivaPorcentaje: producto.ivaPorcentaje,
      esNuevo: true,
      imagenUrl: producto.thumbnailUrl ?? producto.imagenUrl,
    );

    final base = _comandaActiva ??
        Comanda(
          id: _db
              .collection('empresas')
              .doc(widget.empresaId)
              .collection('comandas')
              .doc()
              .id,
          mesaId: null,
          camareroUid: FirebaseAuth.instance.currentUser?.uid ?? '',
          lineas: [],
          estado: 'abierta',
          apertura: Timestamp.now(),
          importeTotal: 0,
        );

    final lineas = List<LineaComanda>.from(base.lineas);
    final idx = lineas.indexWhere((l) =>
    l.productoId == linea.productoId && l.nombre == linea.nombre);
    if (idx >= 0) {
      lineas[idx] = lineas[idx].copyWith(cantidad: lineas[idx].cantidad + 1);
    } else {
      lineas.add(linea);
    }
    setState(() => _comandaActiva = base.copyWith(lineas: lineas));
  }

  Widget _opcionPrecioBtn(BuildContext ctx, String etiqueta, double precio) =>
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.pop(ctx, precio),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF7B1FA2).withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.05),
          ),
          child: Row(children: [
            Expanded(child: Text(etiqueta,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF4A148C)))),
            Text('${precio.toStringAsFixed(2)} €',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: Color(0xFF7B1FA2))),
          ]),
        ),
      );

  // ── Producto libre (precio manual) ────────────────────────────────────────

  Future<void> _agregarProductoLibre() async {
    final nomCtrl = TextEditingController();
    final prcCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.add_circle_outline, color: Color(0xFF1B5E20)),
          SizedBox(width: 8),
          Text('Producto libre'),
        ]),
        content: SizedBox(
          width: 300,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Artículo sin catálogo.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(
              controller: nomCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: prcCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio (€) *',
                prefixIcon: Icon(Icons.euro),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final nombre = nomCtrl.text.trim();
              final precio =
                  double.tryParse(prcCtrl.text.replaceAll(',', '.')) ?? 0;
              if (nombre.isEmpty || precio <= 0) return;
              final linea = LineaComanda(
                productoId:
                'libre_${DateTime.now().millisecondsSinceEpoch}',
                nombre: nombre,
                cantidad: 1,
                precioUnitario: precio,
                ivaPorcentaje: 21,
                esNuevo: true,
              );
              final base = _comandaActiva ??
                  Comanda(
                    id: _db
                        .collection('empresas')
                        .doc(widget.empresaId)
                        .collection('comandas')
                        .doc()
                        .id,
                    mesaId: null,
                    camareroUid:
                    FirebaseAuth.instance.currentUser?.uid ?? '',
                    lineas: [],
                    estado: 'abierta',
                    apertura: Timestamp.now(),
                    importeTotal: 0,
                  );
              setState(() => _comandaActiva =
                  base.copyWith(lineas: [...base.lineas, linea]));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A7C59)),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  // ── Código de barras no encontrado ────────────────────────────────────────

  void _productoNoEncontrado(String codigo) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Código "$codigo" no encontrado en el catálogo'),
      backgroundColor: Colors.orange.shade700,
      action: _esAdmin
          ? SnackBarAction(
        label: 'Crear producto',
        textColor: Colors.white,
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _DialogoNuevoProducto(
            empresaId: widget.empresaId,
            codigoBarrasInicial: codigo,
          ),
        ),
      )
          : null,
    ));
  }

  // ── Nuevo ticket (guarda el actual en hold y abre uno vacío) ─────────────

  void _nuevoTicket() {
    if (_comandaActiva != null && _comandaActiva!.lineas.isNotEmpty) {
      _holdNotifier.guardar(
        etiqueta: 'Ticket',
        lineas: _comandaActiva!.lineas.map((l) => {
          'productoId': l.productoId, 'nombre': l.nombre,
          'cantidad': l.cantidad, 'precioUnitario': l.precioUnitario,
          'ivaPorcentaje': l.ivaPorcentaje, 'notas': l.notas,
        }).toList(),
        total: _totalConDescuento,
      );
    }
    setState(() {
      _comandaActiva = null;
      _extra = const _TicketExtra();
      _cuponId = null;
      _cuponDescuento = 0;
      _descuentosLinea.clear();
    });
  }

  // ── Cambiar al ticket en hold ─────────────────────────────────────────────

  void _switchToHold(String holdId) {
    // Guardar el actual si tiene líneas
    if (_comandaActiva != null && _comandaActiva!.lineas.isNotEmpty) {
      _holdNotifier.guardar(
        etiqueta: 'Ticket',
        lineas: _comandaActiva!.lineas.map((l) => {
          'productoId': l.productoId, 'nombre': l.nombre,
          'cantidad': l.cantidad, 'precioUnitario': l.precioUnitario,
          'ivaPorcentaje': l.ivaPorcentaje, 'notas': l.notas,
        }).toList(),
        total: _totalConDescuento,
      );
    }
    // Recuperar el hold seleccionado
    final recuperado = _holdNotifier.recuperar(holdId);
    if (recuperado == null) return;
    final lineas = recuperado.lineas.map((m) => LineaComanda(
      productoId: m['productoId'] as String? ?? '',
      nombre: m['nombre'] as String? ?? '',
      cantidad: (m['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: (m['precioUnitario'] as num?)?.toDouble() ?? 0,
      ivaPorcentaje: (m['ivaPorcentaje'] as num?)?.toDouble() ?? 21,
      notas: m['notas'] as String?,
      esNuevo: false,
    )).toList();
    final base = Comanda(
      id: _db.collection('empresas').doc(widget.empresaId).collection('comandas').doc().id,
      mesaId: null,
      camareroUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      lineas: lineas,
      estado: 'abierta',
      apertura: Timestamp.now(),
      importeTotal: 0,
    );
    setState(() {
      _comandaActiva = base;
      _extra = const _TicketExtra();
      _cuponId = null;
      _cuponDescuento = 0;
      _descuentosLinea.clear();
    });
  }

  // ── Arqueo intermedio (sin cerrar caja) ────────────────────────────────────

  Future<void> _mostrarArqueoIntermedio() async {
    // Calcular efectivo del turno actual (ventas en efectivo de hoy)
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    double totalEfectivo = 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('pedidos')
          .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .get();
      for (final d in snap.docs) {
        final m = d.data();
        if (m['estado_pago'] != 'pagado') continue;
        final met = m['metodo_pago'] as String? ?? '';
        if (met == 'efectivo') {
          totalEfectivo += (m['total'] as num?)?.toDouble() ?? 0;
        } else if (met == 'mixto') {
          totalEfectivo += (m['importe_efectivo'] as num?)?.toDouble() ?? 0;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    await ArqueoCajaWidget.mostrar(context, totalSistema: totalEfectivo);
  }

  // ── Apertura de caja ──────────────────────────────────────────────────────

  Future<void> _mostrarAperturaCaja() async {
    if (!mounted) return;

    // Guardia anti-duplicado: comprobar antes de mostrar el diálogo
    final hoy    = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin    = inicio.add(const Duration(days: 1));
    try {
      final aperturasHoy = await _db
          .collection('empresas').doc(widget.empresaId)
          .collection('aperturas_caja')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha', isLessThan: Timestamp.fromDate(fin))
          .limit(1)
          .get();
      if (aperturasHoy.docs.isNotEmpty) {
        if (!mounted) return;
        final fondoExistente = (aperturasHoy.docs.first.data()['fondo_inicial'] as num?)
            ?.toStringAsFixed(2) ?? '—';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ La caja ya fue abierta hoy con ${fondoExistente} €'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
        ));
        return;
      }
    } catch (e) {
      if (!mounted) return;
      FluxToast.error(context, 'Error al verificar apertura: $e');
      return;
    }

    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.account_balance_wallet, color: Color(0xFF1B5E20)),
          SizedBox(width: 8),
          Text('Apertura de caja'),
        ]),
        content: SizedBox(
          width: 280,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Introduce el efectivo inicial en caja.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Fondo inicial (€)',
                prefixIcon: Icon(Icons.euro),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final texto = ctrl.text.trim().replaceAll(',', '.');
              final fondo = double.tryParse(texto) ?? 0;
              if (fondo < 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('El fondo inicial no puede ser negativo'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              try {
                await _db
                    .collection('empresas').doc(widget.empresaId)
                    .collection('aperturas_caja')
                    .add({
                  'fondo_inicial': fondo,
                  'fecha': FieldValue.serverTimestamp(),
                  'camarero_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  setState(() => _cajaAbiertaHoy = true);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('✅ Caja abierta con fondo de ${fondo.toStringAsFixed(2)} €'),
                    backgroundColor: Colors.green.shade700,
                  ));
                }
              } catch (e) {
                if (ctx.mounted) {
                  String msg = 'Error al abrir caja: $e';
                  if (e is FirebaseException && e.code == 'permission-denied') {
                    msg = 'Sin permisos para abrir la caja. Contacta con el administrador.';
                  }
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(msg),
                    backgroundColor: Colors.red.shade700,
                  ));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A7C59)),
            child: const Text('Abrir caja'),
          ),
        ],
      ),
    );
  }

  // ── Configuración impresora Bluetooth ─────────────────────────────────────
  void _mostrarConfigImpresora() {
    showDialog(
      context: context,
      builder: (_) => _DialogoConfigImpresora(
        onConectada: () {
          if (mounted) setState(() => _btConectado = true);
        },
      ),
    );
  }
}

// ── AppBar helpers ────────────────────────────────────────────────────────────

class _AppBarGroup extends StatelessWidget {
  final List<Widget> children;
  const _AppBarGroup({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF162A1B),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _AppBarBtn(this.icon, this.tooltip, this.onTap);

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: Colors.white60),
        ),
      ),
    ),
  );
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
    const kCian = Color(0xFF00FFC8);
    const kTarjeta = Color(0xFF1E2139);
    
    return AlertDialog(
      backgroundColor: kTarjeta,
      title: Row(children: [
        const Icon(Icons.print, color: kCian, size: 20),
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
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(children: [
                          Icon(Icons.bluetooth_searching, color: Colors.white38, size: 40),
                          SizedBox(height: 8),
                          Text('No hay impresoras emparejadas.\nEmpareja la impresora en\nAjustes → Bluetooth primero.',
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
                            foregroundColor: const Color(0xFF0A0F23),
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
// CATÁLOGO DE PRODUCTOS — con botón crear + toast código no encontrado
// ═══════════════════════════════════════════════════════════════════════════
// MINI-DASHBOARD DE TURNO — franja compacta sobre el catálogo
// ═══════════════════════════════════════════════════════════════════════════

class _MiniDashboardTurno extends StatelessWidget {
  final String empresaId;
  const _MiniDashboardTurno({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final hoy       = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final ayer      = inicioHoy.subtract(const Duration(days: 1));
    final fmt       = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(empresaId).collection('pedidos')
          .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(ayer))
          .where('fecha_hora', isLessThan: Timestamp.fromDate(inicioHoy.add(const Duration(days: 1))))
          .where('estado_pago', isEqualTo: 'pagado')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 56);

        double totalHoy = 0, totalAyer = 0;
        int ticketsHoy = 0, ticketsAyer = 0;
        int productosHoy = 0, productosAyer = 0;

        for (final d in snap.data!.docs) {
          final m  = d.data() as Map<String, dynamic>;
          final ts = m['fecha_hora'] as Timestamp?;
          if (ts == null) continue;
          final esHoy = ts.toDate().isAfter(inicioHoy);
          final t = (m['total'] as num?)?.toDouble() ?? 0;
          final unidades = (m['lineas'] as List? ?? [])
              .fold<int>(0, (s, l) => s + ((l['cantidad'] as num?)?.toInt() ?? 1));
          if (esHoy) {
            totalHoy += t; ticketsHoy++; productosHoy += unidades;
          } else {
            totalAyer += t; ticketsAyer++; productosAyer += unidades;
          }
        }

        final medioHoy   = ticketsHoy > 0 ? totalHoy / ticketsHoy : 0.0;
        final medioAyer  = ticketsAyer > 0 ? totalAyer / ticketsAyer : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(children: [
            Expanded(child: _StatCard(
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF22C55E),
              label: 'Ventas del día',
              value: fmt.format(totalHoy),
              deltaNum: totalAyer > 0 ? (totalHoy - totalAyer) / totalAyer * 100 : null,
              deltaLabel: totalAyer > 0
                  ? '${((totalHoy - totalAyer) / totalAyer * 100).abs().toStringAsFixed(1)}% vs ayer'
                  : null,
            )),
            Expanded(child: _StatCard(
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFF8B5CF6),
              label: 'Tickets',
              value: '$ticketsHoy',
              deltaNum: (ticketsHoy - ticketsAyer).toDouble(),
              deltaLabel: '${ticketsHoy - ticketsAyer >= 0 ? '+' : ''}${ticketsHoy - ticketsAyer} vs ayer',
            )),
            Expanded(child: _StatCard(
              icon: Icons.equalizer_rounded,
              iconColor: const Color(0xFFF59E0B),
              label: 'Ticket medio',
              value: fmt.format(medioHoy),
              deltaNum: medioAyer > 0 ? (medioHoy - medioAyer) / medioAyer * 100 : null,
              deltaLabel: medioAyer > 0
                  ? '${((medioHoy - medioAyer) / medioAyer * 100).abs().toStringAsFixed(1)}% vs ayer'
                  : null,
            )),
            Expanded(child: _StatCard(
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFF3B82F6),
              label: 'Productos vendidos',
              value: '$productosHoy',
              deltaNum: (productosHoy - productosAyer).toDouble(),
              deltaLabel: '${productosHoy - productosAyer >= 0 ? '+' : ''}${productosHoy - productosAyer} vs ayer',
            )),
          ]),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final double? deltaNum;
  final String? deltaLabel;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.deltaNum,
    this.deltaLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isUp   = deltaNum != null && deltaNum! > 0;
    final isDown = deltaNum != null && deltaNum! < 0;
    final deltaColor = isUp ? const Color(0xFF22C55E) : isDown ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF);

    // No retorna Expanded — el Expanded lo añade el Row en el call site
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 5),
            Flexible(child: Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          if (deltaLabel != null)
            Row(children: [
              Icon(isUp ? Icons.arrow_upward : isDown ? Icons.arrow_downward : Icons.remove,
                  size: 10, color: deltaColor),
              const SizedBox(width: 2),
              Flexible(child: Text(deltaLabel!,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: deltaColor),
                  overflow: TextOverflow.ellipsis)),
            ]),
        ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _TiendaCatalogoPanel extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final String categoriaFiltro;
  final String busqueda;
  final List<String> categoriasOcultas;
  final ValueChanged<String> onCategoriaChanged;
  final ValueChanged<String> onBusquedaChanged;
  final Function(Producto, VarianteProducto?) onProductoSeleccionado;
  final ValueChanged<String> onProductoNoEncontrado;

  const _TiendaCatalogoPanel({
    required this.empresaId,
    required this.esAdmin,
    required this.categoriaFiltro,
    required this.busqueda,
    this.categoriasOcultas = const [],
    required this.onCategoriaChanged,
    required this.onBusquedaChanged,
    required this.onProductoSeleccionado,
    required this.onProductoNoEncontrado,
  });

  @override
  State<_TiendaCatalogoPanel> createState() => _TiendaCatalogoPanelState();
}

class _TiendaCatalogoPanelState extends State<_TiendaCatalogoPanel> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  IconData _iconoCategoria(String cat) {
    final c = cat.toLowerCase();
    if (c == 'todos') return Icons.grid_view_rounded;
    if (c.contains('bebida') || c.contains('drink')) return Icons.local_bar_outlined;
    if (c.contains('comida') || c.contains('food') || c.contains('plato')) return Icons.restaurant_outlined;
    if (c.contains('caf') || c.contains('coffee')) return Icons.coffee_outlined;
    if (c.contains('postre') || c.contains('dulce')) return Icons.cake_outlined;
    if (c.contains('tapa') || c.contains('snack')) return Icons.tapas_outlined;
    if (c.contains('alcohol') || c.contains('vino') || c.contains('cerveza')) return Icons.wine_bar_outlined;
    if (c.contains('fruta') || c.contains('verdura')) return Icons.eco_outlined;
    if (c.contains('carne') || c.contains('pescado')) return Icons.set_meal_outlined;
    return Icons.label_outline;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('catalogo')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final todos = snap.data!.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return (
          producto: Producto(
            id: d.id,
            empresaId: widget.empresaId,
            nombre: data['nombre'] ?? '',
            categoria: data['categoria'] ?? '',
            precio: (data['precio'] as num?)?.toDouble() ?? 0,
            imagenUrl: data['imagen_url'],
            thumbnailUrl: data['thumbnail_url'],
            ivaPorcentaje:
            (data['iva_porcentaje'] as num?)?.toDouble() ?? 21,
            tieneVariantes: data['tiene_variantes'] ?? false,
            variantes: ((data['variantes'] as List?) ?? [])
                .whereType<Map>()
                .map((v) => VarianteProducto.fromMap(
                Map<String, dynamic>.from(v)))
                .toList(),
            etiquetas: [],
            fechaCreacion: DateTime.now(),
          ),
          stock: (data['stock'] as num?)?.toInt(),
          stockMinimo: (data['stock_minimo'] as num?)?.toInt() ?? 0,
          codigoBarras: data['codigo_barras'] as String?,
          ) as _ProductoEntry;
        }).toList();

        // Excluir productos cuya categoría está en la lista de ocultas
        if (widget.categoriasOcultas.isNotEmpty) {
          todos.removeWhere((p) => widget.categoriasOcultas.contains(p.producto.categoria));
        }

        final categorias = {
          'Todos',
          ...todos.map((p) => p.producto.categoria)
        };

        final filtrados = todos.where((p) {
          if (widget.categoriaFiltro != 'Todos' &&
              p.producto.categoria != widget.categoriaFiltro) return false;
          if (widget.busqueda.isNotEmpty) {
            final q = widget.busqueda.toLowerCase();
            return p.producto.nombre.toLowerCase().contains(q) ||
                (p.codigoBarras?.toLowerCase().contains(q) ?? false);
          }
          return true;
        }).toList();

        return Column(children: [
          // Barra de búsqueda / lector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: widget.onBusquedaChanged,
              onSubmitted: (val) {
                final v = val.trim();
                if (v.isEmpty) return;
                // Búsqueda exacta por código de barras
                final match = todos
                    .where((p) => p.codigoBarras == v)
                    .map((p) => p.producto)
                    .firstOrNull;
                if (match != null) {
                  widget.onProductoSeleccionado(match, null);
                  _searchCtrl.clear();
                  widget.onBusquedaChanged('');
                } else {
                  // Buscar también por nombre exacto
                  final matchNombre = todos
                      .where((p) =>
                  p.producto.nombre.toLowerCase() == v.toLowerCase())
                      .map((p) => p.producto)
                      .firstOrNull;
                  if (matchNombre != null) {
                    widget.onProductoSeleccionado(matchNombre, null);
                    _searchCtrl.clear();
                    widget.onBusquedaChanged('');
                  } else {
                    widget.onProductoNoEncontrado(v);
                  }
                }
              },
              decoration: InputDecoration(
                hintText: 'Buscar producto por nombre, SKU o código...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono de escaneo manual (ya existía)
                    const Tooltip(
                      message: 'Compatible con lector USB/BT',
                      child: Icon(Icons.qr_code_scanner,
                          size: 18, color: Colors.grey),
                    ),
                    // NUEVO: botón cámara
                    IconButton(
                      icon: const Icon(Icons.camera_alt_outlined,
                          size: 20, color: Colors.grey),
                      tooltip: 'Escanear con cámara',
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (_) => _EscanerCamaraModal(
                            onCodigoEscaneado: (codigo) {
                              // Buscar en todos los productos
                              final match = todos
                                  .where((p) => p.codigoBarras == codigo)
                                  .map((p) => p.producto)
                                  .firstOrNull;
                              if (match != null) {
                                widget.onProductoSeleccionado(match, null);
                              } else {
                                widget.onProductoNoEncontrado(codigo);
                              }
                            },
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                isDense: true,
              ),
            ),
          ),
          // ── Tabs de categorías — estilo pill ────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              ...categorias.map((c) {
                final sel = widget.categoriaFiltro == c;
                final icon = _iconoCategoria(c);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => widget.onCategoriaChanged(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF3B82F6) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: sel ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 13,
                            color: sel ? Colors.white : const Color(0xFF6B7280)),
                        const SizedBox(width: 5),
                        Text(c, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : const Color(0xFF374151),
                        )),
                      ]),
                    ),
                  ),
                );
              }),
              if (widget.esAdmin)
                GestureDetector(
                  onTap: () => showDialog(context: context,
                      builder: (_) => _DialogoNuevoProducto(empresaId: widget.empresaId)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, size: 13, color: Color(0xFF6B7280)),
                      SizedBox(width: 4),
                      Text('•••', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    ]),
                  ),
                ),
            ]),
          ),
          // Estado vacío
          if (filtrados.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 52, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    widget.busqueda.isNotEmpty
                        ? 'Sin resultados para "${widget.busqueda}"'
                        : 'Sin productos en el catálogo',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (widget.esAdmin && widget.busqueda.isEmpty) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _DialogoNuevoProducto(
                            empresaId: widget.empresaId),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir primer producto'),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4A7C59)),
                    ),
                  ],
                ]),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(builder: (_, c) {
                final cols = (c.maxWidth / 100).floor().clamp(2, 5);
                return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: filtrados.length,
                itemBuilder: (context, idx) {
                  final item = filtrados[idx];
                  return _TiendaProductoCard(
                    producto: item.producto,
                    stock: item.stock,
                    stockMinimo: item.stockMinimo,
                    esAdmin: widget.esAdmin,
                    onTap: () async {
                      if (item.stock == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${item.producto.nombre}: sin stock disponible'),
                          backgroundColor: Colors.orange.shade700,
                          duration: const Duration(seconds: 2),
                        ));
                        return;
                      }
                      if (item.producto.tieneVariantes &&
                          item.producto.variantesDisponibles.isNotEmpty) {
                        final v = await VarianteSelectorWidget.mostrar(
                            context, producto: item.producto);
                        if (v != null) widget.onProductoSeleccionado(item.producto, v);
                      } else {
                        widget.onProductoSeleccionado(item.producto, null);
                      }
                    },
                    onEditar: widget.esAdmin
                        ? () => showDialog(context: context,
                            builder: (_) => _DialogoEditarProducto(
                              empresaId: widget.empresaId,
                              productoId: item.producto.id,
                              datos: {
                                'nombre': item.producto.nombre,
                                'precio': item.producto.precio,
                                'categoria': item.producto.categoria,
                                'stock': item.stock,
                                'stock_minimo': item.stockMinimo,
                                'codigo_barras': item.codigoBarras,
                                'iva_porcentaje': item.producto.ivaPorcentaje,
                              },
                            ))
                        : null,
                  );
                },
              );
            }),
            ),
          // ── Dashboard stats al fondo ─────────────────────────────────────
          _MiniDashboardTurno(empresaId: widget.empresaId),
        ]);
      },
    );
  }
}

// ── Tarjeta de producto ──────────────────────────────────────────────────────

class _TiendaProductoCard extends StatelessWidget {
  final Producto producto;
  final int? stock;
  final int stockMinimo;
  final bool esAdmin;
  final VoidCallback onTap;
  final VoidCallback? onEditar;

  const _TiendaProductoCard({
    required this.producto,
    this.stock,
    this.stockMinimo = 0,
    required this.esAdmin,
    required this.onTap,
    this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final stockNum = stock ?? 0;
    final hasMin   = stockMinimo > 0;
    final umbralRojo    = hasMin ? stockMinimo * 0.2 : 0;
    final umbralNaranja = hasMin ? stockMinimo * 0.5 : 0;

    // Rojo: stock negativo O por debajo del 20% del mínimo
    final esRojo   = stockNum <= 0 || (hasMin && stockNum < umbralRojo);
    // Naranja: entre el 20% y el 50% del mínimo
    final esNaranja = !esRojo && hasMin && stockNum < umbralNaranja;
    final sinStock  = stockNum <= 0;
    final imgUrl = producto.thumbnailUrl ?? producto.imagenUrl;

    return GestureDetector(
      onTap: sinStock ? null : onTap,
      onLongPress: onEditar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: sinStock ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: sinStock ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Imagen cuadrada ────────────────────────────────────────────
          Expanded(
            flex: 13,
            child: Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFF3F4F6),
                  child: imgUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, __) => _placeholder(),
                          errorWidget: (_, __, ___) => _placeholder(),
                          memCacheWidth: 400,
                          memCacheHeight: 400,
                        )
                      : _placeholder(),
                ),
              ),
              if (sinStock)
                Positioned.fill(child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: Container(color: Colors.black.withValues(alpha: 0.45),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Agotado', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    )),
                )),
              if (esAdmin)
                Positioned(top: 6, right: 6,
                  child: GestureDetector(
                    onTap: onEditar,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                      child: const Icon(Icons.edit_outlined, size: 10, color: Color(0xFF6B7280)),
                    ),
                  )),
            ]),
          ),
          // ── Info ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(producto.nombre,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.3,
                      color: sinStock ? const Color(0xFF9CA3AF) : const Color(0xFF111827)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(fmt.format(producto.precio),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: sinStock ? const Color(0xFF9CA3AF) : const Color(0xFF111827))),
              if (stock != null) ...[
                const SizedBox(height: 2),
                Text(stockNum < 0 ? 'Stock: $stockNum ⚠' : 'Stock: $stockNum',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                        color: esRojo    ? const Color(0xFFEF4444)
                            : esNaranja ? const Color(0xFFF59E0B)
                            : const Color(0xFF22C55E))),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Center(
    child: Icon(Icons.image_not_supported_outlined, size: 28, color: Colors.grey.shade300),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PANEL DE TICKET — con descuento, cliente, editar precio y cantidad manual
// ═══════════════════════════════════════════════════════════════════════════
// MONEDERO / FIDELIZACIÓN EN EL TICKET
// Ratio: 1€ gastado = 1 punto · 100 puntos = 1€ de descuento (1% cashback)
// ═══════════════════════════════════════════════════════════════════════════

class _MonederoTienda extends StatelessWidget {
  final String empresaId;
  final String clienteId;
  final double totalTicket;
  final ValueChanged<double> onCanjear;

  static const _ptsPorEuro  = 1;    // puntos que se dan por cada euro gastado
  static const _euroPorPts  = 100;  // puntos necesarios para obtener 1€ de descuento
  static const _primario    = Color(0xFF4A7C59);
  static const _superficie  = Color(0xFFDCF0E6);
  static const _texto       = Color(0xFF1A3A27);

  const _MonederoTienda({
    required this.empresaId,
    required this.clienteId,
    required this.totalTicket,
    required this.onCanjear,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('clientes').doc(clienteId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final puntos = (data['puntos'] as num?)?.toInt() ?? 0;
        if (puntos <= 0) return const SizedBox.shrink();

        final maxCanjeableEuros = (puntos / _euroPorPts).floorToDouble();
        final puntosGanar = (totalTicket * _ptsPorEuro).floor();

        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _superficie,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBDD8C4)),
          ),
          child: Row(children: [
            const Icon(Icons.stars_rounded, size: 16, color: _primario),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$puntos puntos disponibles',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: _texto)),
                Text('Vale ${maxCanjeableEuros.toStringAsFixed(2)} € en descuento  ·  '
                    'Ganará +$puntosGanar pts hoy',
                    style: TextStyle(fontSize: 9, color: _primario.withValues(alpha: 0.7))),
              ]),
            ),
            if (maxCanjeableEuros > 0)
              GestureDetector(
                onTap: () => _mostrarDialogoCanje(context, puntos, maxCanjeableEuros),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _primario,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Canjear',
                      style: TextStyle(fontSize: 11, color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        );
      },
    );
  }

  void _mostrarDialogoCanje(BuildContext ctx, int puntos, double maxEuros) {
    double selectedEuros = maxEuros.clamp(0, totalTicket);
    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.stars_rounded, color: _primario, size: 20),
            SizedBox(width: 8),
            Text('Canjear puntos', style: TextStyle(fontSize: 15)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Tienes $puntos puntos = ${maxEuros.toStringAsFixed(2)} € disponibles',
                style: const TextStyle(fontSize: 12, color: _texto)),
            const SizedBox(height: 16),
            Text('Aplicar descuento de:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: () => setS(() => selectedEuros = (selectedEuros - 1).clamp(0, maxEuros)),
                child: const Icon(Icons.remove_circle_outline, color: _primario),
              ),
              const SizedBox(width: 16),
              Text('${selectedEuros.toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _primario)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => setS(() => selectedEuros = (selectedEuros + 1).clamp(0, maxEuros.clamp(0, totalTicket))),
                child: const Icon(Icons.add_circle_outline, color: _primario),
              ),
            ]),
            const SizedBox(height: 8),
            Text('= ${(selectedEuros * _euroPorPts).toInt()} puntos',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: selectedEuros > 0
                  ? () { Navigator.pop(dCtx); onCanjear(selectedEuros); }
                  : null,
              style: FilledButton.styleFrom(backgroundColor: _primario),
              child: const Text('Aplicar descuento'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TABS DE TICKETS ACTIVOS
// ═══════════════════════════════════════════════════════════════════════════

class _TabsTicket extends StatelessWidget {
  final Comanda? comandaActiva;
  final HoldPedidosNotifier holdNotifier;
  final double totalActual;
  final VoidCallback? onNuevoTicket;
  final ValueChanged<String>? onSwitchToHold;

  const _TabsTicket({
    required this.comandaActiva,
    required this.holdNotifier,
    required this.totalActual,
    this.onNuevoTicket,
    this.onSwitchToHold,
  });

  static const _primario   = Color(0xFF4A7C59);
  static const _superficie = Color(0xFFDCF0E6);
  static const _divisor    = Color(0xFFBDD8C4);
  static const _texto      = Color(0xFF1A3A27);
  static const _muted      = Color(0xFF81B29A);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return ListenableBuilder(
      listenable: holdNotifier,
      builder: (context, _) {
        final pedidosHold = holdNotifier.pedidos;
        final tieneActivo = comandaActiva != null && comandaActiva!.lineas.isNotEmpty;

        // Si no hay hold ni ticket activo, no mostrar la barra de tabs
        if (!tieneActivo && pedidosHold.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: _superficie,
            border: Border(bottom: BorderSide(color: _divisor)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 8, top: 6, bottom: 0, right: 4),
            child: Row(children: [
              // ── Tab activo ────────────────────────────────────────────
              _Tab(
                etiqueta: tieneActivo
                    ? '${fmt.format(totalActual)}'
                    : 'Vacío',
                activo: true,
                color: _primario,
              ),
              // ── Tabs de holds ─────────────────────────────────────────
              ...pedidosHold.map((p) {
                final fmtP = NumberFormat.currency(symbol: '€', decimalDigits: 2);
                return _Tab(
                  etiqueta: p.etiqueta.length > 12
                      ? '${p.etiqueta.substring(0, 10)}…'
                      : p.etiqueta,
                  subLabel: fmtP.format(p.total),
                  activo: false,
                  color: _muted,
                  onTap: () => onSwitchToHold?.call(p.id),
                );
              }),
              // ── Botón + nuevo ticket ────────────────────────────────
              GestureDetector(
                onTap: onNuevoTicket,
                child: Container(
                  margin: const EdgeInsets.only(left: 4, bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _divisor),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 14, color: _muted),
                    const SizedBox(width: 3),
                    Text('Nuevo', style: TextStyle(fontSize: 10, color: _muted,
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  final String etiqueta;
  final String? subLabel;
  final bool activo;
  final Color color;
  final VoidCallback? onTap;

  const _Tab({
    required this.etiqueta,
    this.subLabel,
    required this.activo,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4, bottom: 0),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(
          color: activo ? Colors.white : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: activo
              ? Border(
                  top: BorderSide(color: color, width: 2),
                  left: BorderSide(color: const Color(0xFFBDD8C4)),
                  right: BorderSide(color: const Color(0xFFBDD8C4)),
                )
              : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(etiqueta,
              style: TextStyle(
                fontSize: 11,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? color : const Color(0xFF81B29A),
              )),
          if (subLabel != null)
            Text(subLabel!,
                style: const TextStyle(fontSize: 9, color: Color(0xFF81B29A))),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _TiendaComandaPanel extends StatelessWidget {
  final String empresaId;
  final Comanda? comandaActiva;
  final _TicketExtra extra;
  final double totalConDescuento;
  final ValueChanged<Comanda> onComandaActualizada;
  final ValueChanged<_TicketExtra> onExtraChanged;
  final VoidCallback onCobrado;
  final VoidCallback onLimpiar;
  final VoidCallback onProductoLibre;
  // Hold + tabs
  final HoldPedidosNotifier holdNotifier;
  final VoidCallback? onNuevoTicket;        // abre ticket vacío guardando el actual
  final ValueChanged<String>? onSwitchToHold; // cambia al hold con ese id
  // Cupón
  final String? cuponId;
  final double cuponDescuento;
  final Function(String cuponId, double descuento) onCuponAplicado;
  final VoidCallback onCuponRetirado;
  // Descuentos por línea
  final Map<String, double> descuentosLinea;
  final Function(String productoId, double importe) onDescuentoLineaChanged;

  const _TiendaComandaPanel({
    required this.empresaId,
    this.comandaActiva,
    required this.extra,
    required this.totalConDescuento,
    required this.onComandaActualizada,
    required this.onExtraChanged,
    required this.onCobrado,
    required this.onLimpiar,
    required this.onProductoLibre,
    required this.holdNotifier,
    this.onNuevoTicket,
    this.onSwitchToHold,
    this.cuponId,
    this.cuponDescuento = 0,
    required this.onCuponAplicado,
    required this.onCuponRetirado,
    required this.descuentosLinea,
    required this.onDescuentoLineaChanged,
  });

  static const _kBlue   = Color(0xFF3B82F6);
  static const _kBorder = Color(0xFFE5E7EB);
  static const _kText   = Color(0xFF111827);
  static const _kRed    = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final fmt        = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final lineas     = comandaActiva?.lineas ?? [];
    final tieneLineas = lineas.isNotEmpty;
    final numItems   = lineas.fold(0, (s, l) => s + l.cantidad);

    // Summary calculations
    final subtotalBruto  = lineas.fold(0.0, (s, l) => s + l.total);
    final descuentoTotal = (extra.descuento + cuponDescuento +
        descuentosLinea.values.fold(0.0, (a, b) => a + b))
        .clamp(0.0, subtotalBruto);
    final cuotaIva = subtotalBruto > 0
        ? (comandaActiva?.cuotaIva ?? 0) * (totalConDescuento / subtotalBruto)
        : 0.0;

    return Container(
      color: Colors.white,
      child: Column(children: [
        // ── Header del carrito ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Column(children: [
            Row(children: [
              const Text('Carrito',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kText)),
              if (tieneLineas) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$numItems',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
              const Spacer(),
              if (tieneLineas)
                GestureDetector(
                  onTap: onLimpiar,
                  child: const Row(children: [
                    Icon(Icons.delete_outline, size: 14, color: _kRed),
                    SizedBox(width: 4),
                    Text('Vaciar',
                        style: TextStyle(fontSize: 12, color: _kRed, fontWeight: FontWeight.w500)),
                  ]),
                ),
            ]),
            const SizedBox(height: 10),
            // ── Buscador de cliente ──────────────────────────────────────
            ClienteBuscadorTpv(
              empresaId: empresaId,
              clienteNombre: extra.clienteNombre,
              clienteId: extra.clienteId,
              colorPrimario: _kBlue,
              permitirCrearNuevo: true,
              onSeleccionado: (c) => onExtraChanged(extra.copyWith(
                clienteNombre: c['nombre'] as String?,
                clienteId: c['id'] as String?,
              )),
              onLimpiar: () => onExtraChanged(extra.copyWith(limpiarCliente: true)),
            ),
          ]),
        ),

        // ── Lista de líneas ────────────────────────────────────────────────
        Expanded(
          child: !tieneLineas
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shopping_cart_outlined, size: 44, color: Colors.grey.shade200),
                    const SizedBox(height: 10),
                    Text('Carrito vacío',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                    const SizedBox(height: 4),
                    Text('Añade productos del catálogo',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade300)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: lineas.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
                  itemBuilder: (context, idx) {
                    final linea = lineas[idx];
                    return _TiendaLineaCard(
                      linea: linea,
                      descuentoAplicado: descuentosLinea[linea.productoId] ?? 0,
                      onCantidadChanged: (delta) {
                        final nueva = linea.cantidad + delta;
                        final ls = List<LineaComanda>.from(comandaActiva!.lineas);
                        if (nueva <= 0) { ls.removeAt(idx); } else { ls[idx] = linea.copyWith(cantidad: nueva); }
                        onComandaActualizada(comandaActiva!.copyWith(lineas: ls));
                      },
                      onEditarPrecio: () => _editarPrecio(context, idx, linea),
                      onEditarCantidad: () => _editarCantidad(context, idx, linea),
                      onEliminar: () {
                        final ls = List<LineaComanda>.from(comandaActiva!.lineas)..removeAt(idx);
                        onComandaActualizada(comandaActiva!.copyWith(lineas: ls));
                      },
                      onNotaChanged: (nota) {
                        final ls = List<LineaComanda>.from(comandaActiva!.lineas);
                        ls[idx] = ls[idx].copyWith(notas: nota);
                        onComandaActualizada(comandaActiva!.copyWith(lineas: ls));
                      },
                      onDescuento: () async {
                        final r = await DescuentoLineaWidget.mostrar(
                          context,
                          nombreProducto: linea.nombre,
                          precioOriginal: linea.precioUnitario,
                          cantidad: linea.cantidad,
                        );
                        if (r != null) onDescuentoLineaChanged(linea.productoId, r.importe);
                      },
                    );
                  },
                ),
        ),

        // ── Añadir nota al pedido ──────────────────────────────────────────
        if (tieneLineas)
          InkWell(
            onTap: () => _anadirNota(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: _kBorder),
                  bottom: BorderSide(color: _kBorder),
                ),
              ),
              child: Row(children: [
                const Icon(Icons.edit_note_outlined, size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comandaActiva?.notaGeneral?.isNotEmpty == true
                        ? comandaActiva!.notaGeneral!
                        : 'Añadir nota al pedido',
                    style: TextStyle(
                      fontSize: 12,
                      color: comandaActiva?.notaGeneral?.isNotEmpty == true
                          ? _kText : const Color(0xFF9CA3AF),
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
              ]),
            ),
          ),

        // ── Resumen + Cobrar ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _kBorder)),
          ),
          child: Column(children: [
            if (tieneLineas) ...[
              _SummaryRow('Subtotal', fmt.format(subtotalBruto)),
              const SizedBox(height: 4),
              if (descuentoTotal > 0) ...[
                _SummaryRow('Descuento', '−${fmt.format(descuentoTotal)}', isRed: true),
                const SizedBox(height: 4),
              ],
              _SummaryRow('Impuestos (IVA)', fmt.format(cuotaIva)),
              const SizedBox(height: 10),
              const Divider(height: 1, color: _kBorder),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kText)),
                const Spacer(),
                Text(fmt.format(totalConDescuento),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kBlue)),
              ]),
              const SizedBox(height: 14),
            ],
            // Botón cobrar
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: tieneLineas ? () => _cobrar(context) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _kBlue,
                  disabledBackgroundColor: const Color(0xFFBFDBFE),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 4),
                    const Text('Cobrar',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    Row(children: [
                      Text(fmt.format(totalConDescuento),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                    ]),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }


  // ── Añadir nota global al pedido ─────────────────────────────────────

  Future<void> _anadirNota(BuildContext context) async {
    final ctrl = TextEditingController(text: comandaActiva?.notaGeneral ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.edit_note_outlined, color: Color(0xFF3B82F6), size: 20),
          SizedBox(width: 8),
          Text('Nota del pedido'),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ej: cliente espera en mesa 5, envío urgente…',
            hintStyle: const TextStyle(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
          ),
        ),
        actions: [
          if (comandaActiva?.notaGeneral?.isNotEmpty == true)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Quitar nota', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && comandaActiva != null) {
      onComandaActualizada(
          comandaActiva!.copyWith(notaGeneral: result.isEmpty ? null : result, clearNota: result.isEmpty));
    }
  }

  // ── Descuento ─────────────────────────────────────────────────────────

  Future<void> _aplicarDescuento(BuildContext context) async {
    double pct = extra.descuentoPct;
    final baseTotal = comandaActiva!.total;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Text('Aplicar descuento'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Total sin descuento: ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(baseTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [5, 10, 15, 20, 25, 50].map((p) {
                return ChoiceChip(
                  label: Text('$p%'),
                  selected: pct == p,
                  onSelected: (_) => setS(() => pct = p.toDouble()),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (pct > 0)
              Text(
                'Descuento: - ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(baseTotal * pct / 100)}',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w700),
              ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancelar')),
            if (extra.descuento > 0)
              TextButton(
                onPressed: () {
                  onExtraChanged(
                      extra.copyWith(limpiarDescuento: true));
                  Navigator.pop(ctx2);
                },
                child: const Text('Quitar dto.',
                    style: TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: pct > 0
                  ? () {
                onExtraChanged(extra.copyWith(
                  descuento: baseTotal * pct / 100,
                  descuentoPct: pct,
                ));
                Navigator.pop(ctx2);
              }
                  : null,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A7C59)),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Editar precio de línea ────────────────────────────────────────────

  Future<void> _editarPrecio(
      BuildContext context, int idx, LineaComanda linea) async {
    final ctrl = TextEditingController(
        text: linea.precioUnitario.toStringAsFixed(2));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Precio — ${linea.nombre}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Nuevo precio unitario (€)',
            prefixIcon: Icon(Icons.euro),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final nuevo =
                  double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
              if (nuevo < 0) return;
              final lineas =
              List<LineaComanda>.from(comandaActiva!.lineas);
              lineas[idx] = _lineaConPrecio(linea, nuevo);
              onComandaActualizada(
                  comandaActiva!.copyWith(lineas: lineas));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A7C59)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Editar cantidad directamente ──────────────────────────────────────

  Future<void> _editarCantidad(
      BuildContext context, int idx, LineaComanda linea) async {
    final ctrl = TextEditingController(text: '${linea.cantidad}');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad — ${linea.nombre}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Cantidad',
            prefixIcon: Icon(Icons.numbers),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final nueva = int.tryParse(ctrl.text) ?? 0;
              final lineas =
              List<LineaComanda>.from(comandaActiva!.lineas);
              if (nueva <= 0) {
                lineas.removeAt(idx);
              } else {
                lineas[idx] = linea.copyWith(cantidad: nueva);
              }
              onComandaActualizada(
                  comandaActiva!.copyWith(lineas: lineas));
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A7C59)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Cobrar ────────────────────────────────────────────────────────────

  Future<void> _cobrar(BuildContext context, {String metodoInicial = 'efectivo'}) async {
    if (comandaActiva == null || comandaActiva!.lineas.isEmpty) return;

    // Validar que el descuento no supera el total
    if (totalConDescuento <= 0 && comandaActiva!.total > 0) {
      FluxToast.aviso(context, 'El descuento no puede igualar o superar el total del ticket');
      return;
    }

    // Validar que la caja esté abierta hoy
    try {
      final cajaAbierta = await CierreCajaService().hayCajaAbiertaHoy(empresaId);
      if (!cajaAbierta && context.mounted) {
        FluxToast.aviso(context, 'Abre la caja antes de cobrar', title: 'Caja cerrada');
        return;
      }
    } catch (_) {
      // Sin conexión: permitir cobrar y encolar offline
    }

    final pago = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TiendaDialogoPago(total: totalConDescuento, metodoInicial: metodoInicial),
    );
    if (pago == null) return;

    final ahora = DateTime.now();

    // Número de ticket — Firestore primero, SharedPreferences como fallback offline
    final _prefsKey = 'tpv_ultimo_ticket_$empresaId';
    int numTicket = 1;
    final ref = FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('contadores')
        .doc('tickets');
    try {
      final snap = await ref.get().timeout(const Duration(seconds: 4));
      numTicket = snap.exists
          ? ((snap.data()?['ultimo'] as num?)?.toInt() ?? 0) + 1
          : 1;
      await ref.set({'ultimo': numTicket}, SetOptions(merge: true));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, numTicket);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      numTicket = (prefs.getInt(_prefsKey) ?? 0) + 1;
      await prefs.setInt(_prefsKey, numTicket);
    }

    Map<String, dynamic> empresaData = {};
    try {
      final empresaSnap = await FirebaseFirestore.instance
          .collection('empresas').doc(empresaId).get();
      empresaData = empresaSnap.data() ?? {};
    } catch (_) {}

    final lineasPedido = comandaActiva!.lineas
        .map((l) => LineaPedido(
      productoId: l.productoId,
      productoNombre: l.nombre,
      cantidad: l.cantidad,
      precioUnitario: l.precioUnitario,
      ivaPorcentaje: l.ivaPorcentaje,
      notasLinea: l.notas?.isNotEmpty == true ? l.notas : null,
    ))
        .toList();

    try {
      final pedido = await PedidosService().crearPedido(
        empresaId: empresaId,
        clienteNombre: extra.clienteNombre ?? 'Caja rápida',
        clienteId: extra.clienteId,
        lineas: lineasPedido,
        metodoPago: pago['metodo'] == 'efectivo'
            ? MetodoPago.efectivo
            : pago['metodo'] == 'tarjeta'
            ? MetodoPago.tarjeta
            : MetodoPago.mixto,
        origen: OrigenPedido.presencial,
        numeroTicket: numTicket,
        importeEfectivo: pago['importe_efectivo'],
        importeTarjeta: pago['importe_tarjeta'],
        importeTotal: totalConDescuento,
        importesPorMetodo: (pago['importes'] as Map?)?.cast<String, double>(),
        mesaId: null,
        estado: 'entregado',
        estadoPago: 'pagado',
        fechaHora: Timestamp.fromDate(ahora),
      );

      // QR AEAT (VeriFactu) — solo si el NIF de la empresa está configurado
      try {
        final nif = (empresaData['nif'] as String?)?.trim() ?? '';
        if (nif.isNotEmpty) {
          final qrUrl = QrService().generarUrl(
            nifEmisor: nif,
            serie: 'TPV',
            numero: pedido.id.substring(0, 8).toUpperCase(),
            fecha: ahora,
            importeTotal: totalConDescuento,
          );
          await FirebaseFirestore.instance
              .collection('empresas').doc(empresaId)
              .collection('pedidos').doc(pedido.id)
              .update({'qr_aeat_url': qrUrl});
        }
      } catch (_) {}

      // Preguntar si desea factura
      if (context.mounted) {
        await DialogoFacturaTpv.mostrar(
          context: context,
          empresaId: empresaId,
          pedido: pedido,
        );
      }

      // Descontar stock
      for (final l in lineasPedido) {
        if (l.productoId.startsWith('libre_')) continue;
        try {
          await FirebaseFirestore.instance
              .collection('empresas')
              .doc(empresaId)
              .collection('catalogo')
              .doc(l.productoId)
              .update({'stock': FieldValue.increment(-l.cantidad)});
        } catch (_) {}
      }

      // Imprimir ticket
      try {
        await ImpressoraBluetooth().imprimirTicket(TicketData(
          nombreEmpresa: empresaData['nombre'] as String? ?? '',
          numeroTicket: numTicket,
          fecha: ahora,
          lineas: comandaActiva!.lineas
              .map((l) => LineaTicket(
            nombre: l.nombre,
            cantidad: l.cantidad,
            precioUnitario: l.precioUnitario,
          ))
              .toList(),
          total: totalConDescuento,
          metodoPago: pago['metodo'] as String? ?? 'efectivo',
        ));
      } catch (_) {}

      // Abrir cajón registradora según configuración del tenant
      try {
        final cfg = await TpvFacturacionService().obtenerConfig(empresaId);
        await ImpresoraService().abrirCajonSiProcede(
          config: cfg,
          metodoPago: pago['metodo'] as String? ?? 'efectivo',
        );
      } catch (_) {}

      // Acumular puntos al cliente si está identificado
      if (extra.clienteId != null) {
        try {
          final puntosGanados = totalConDescuento.floor().clamp(1, 9999);
          await FirebaseFirestore.instance
              .collection('empresas').doc(empresaId)
              .collection('clientes').doc(extra.clienteId!)
              .update({
            'puntos': FieldValue.increment(puntosGanados),
            'puntos_totales_ganados': FieldValue.increment(puntosGanados),
            'ultima_compra_tpv': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      if (context.mounted) {
        final puntosMsg = extra.clienteId != null
            ? ' · +${totalConDescuento.floor()} pts'
            : '';
        FluxToast.exito(
          context,
          'Ticket #$numTicket · ${totalConDescuento.toStringAsFixed(2)} €$puntosMsg',
          title: 'Cobro completado',
        );
        onCobrado();
      }
    } catch (e) {
      // Sin conexión: guardar en cola offline para sincronizar después
      try {
        await OfflineQueueService().encolar(empresaId, {
          'cliente_nombre': extra.clienteNombre ?? 'Caja rápida',
          'cliente_id': extra.clienteId,
          'metodo_pago': pago['metodo'] ?? 'efectivo',
          'importe_efectivo': pago['importe_efectivo'],
          'importe_tarjeta': pago['importe_tarjeta'],
          'total': totalConDescuento,
          'numero_ticket': numTicket,
          'fecha_hora': ahora.toIso8601String(),
          'es_offline': true,
          'estado': 'entregado',
          'estado_pago': 'pagado',
          'lineas': lineasPedido.map((l) => {
            'producto_id': l.productoId,
            'producto_nombre': l.productoNombre,
            'cantidad': l.cantidad,
            'precio_unitario': l.precioUnitario,
            'iva_porcentaje': l.ivaPorcentaje,
          }).toList(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sin conexión — ticket #$numTicket guardado. Se sincronizará al recuperar red.'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 5),
          ));
          onCobrado();
        }
      } catch (_) {
        if (context.mounted) {
          FluxToast.error(context, 'Error al cobrar: $e');
        }
      }
    }
  }
}

// ── Tarjeta de línea con editar precio y cantidad ────────────────────────────

class _TiendaLineaCard extends StatelessWidget {
  final LineaComanda linea;
  final double descuentoAplicado;
  final ValueChanged<int> onCantidadChanged;
  final VoidCallback onEditarPrecio;
  final VoidCallback onEditarCantidad;
  final VoidCallback? onDescuento;
  final VoidCallback? onEliminar;
  final ValueChanged<String?>? onNotaChanged;

  const _TiendaLineaCard({
    required this.linea,
    this.descuentoAplicado = 0,
    required this.onCantidadChanged,
    required this.onEditarPrecio,
    required this.onEditarCantidad,
    this.onDescuento,
    this.onEliminar,
    this.onNotaChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt   = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final total = (linea.total - descuentoAplicado).clamp(0.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // ── Imagen + badge cantidad ──────────────────────────────────────
        Stack(clipBehavior: Clip.none, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48, height: 48,
              color: const Color(0xFFF3F4F6),
              child: linea.imagenUrl != null
                  ? CachedNetworkImage(
                      imageUrl: linea.imagenUrl!,
                      fit: BoxFit.cover,
                      width: 48, height: 48,
                      placeholder: (_, __) => _imgPlaceholder(),
                      errorWidget: (_, __, ___) => _imgPlaceholder(),
                      memCacheWidth: 96,
                      memCacheHeight: 96,
                    )
                  : _imgPlaceholder(),
            ),
          ),
          Positioned(
            bottom: -4, left: -4,
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text('${linea.cantidad}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 14),
        // ── Nombre + precio unitario ─────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onLongPress: onNotaChanged != null ? () => _editarNota(context) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(linea.nombre,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF111827)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(fmt.format(linea.precioUnitario),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              if (descuentoAplicado > 0)
                Text('−${fmt.format(descuentoAplicado)}',
                    style: const TextStyle(fontSize: 10, color: Colors.orange)),
              if (linea.notas != null && linea.notas!.isNotEmpty)
                Row(children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 10, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 3),
                  Expanded(child: Text(linea.notas!,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280),
                          fontStyle: FontStyle.italic),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        // ── Total + controles ────────────────────────────────────────────
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          GestureDetector(
            onTap: onEditarPrecio,
            child: Text(fmt.format(total),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF111827))),
          ),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => onCantidadChanged(-1),
              child: const Icon(Icons.remove_circle_outline, size: 17,
                  color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onEditarCantidad,
              child: Text('${linea.cantidad}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Color(0xFF374151))),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: () => onCantidadChanged(1),
              child: const Icon(Icons.add_circle_outline, size: 17,
                  color: Color(0xFF9CA3AF)),
            ),
          ]),
        ]),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onEliminar,
          child: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
        ),
      ]),
    );
  }

  Widget _imgPlaceholder() => const Center(
    child: Icon(Icons.fastfood_outlined, size: 22, color: Color(0xFFD1D5DB)),
  );

  Future<void> _editarNota(BuildContext context) async {
    final ctrl = TextEditingController(text: linea.notas ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.sticky_note_2_outlined, color: Color(0xFF3B82F6), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Nota — ${linea.nombre}',
              style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ej: dedicatoria, envolver para regalo…',
            hintStyle: const TextStyle(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
          ),
        ),
        actions: [
          if (linea.notas != null && linea.notas!.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Quitar nota', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null) {
      onNotaChanged?.call(result.isEmpty ? null : result);
    }
  }
}

// ── Buscador de cliente (tienda) — igual que peluquería ──────────────────────
// Pre-carga clientes, filtrado instantáneo, fallback Firestore, avatar inicial,
// opción de crear cliente nuevo. Usa Sage Green como acento.

class _ClienteBuscadorTienda extends StatefulWidget {
  final String empresaId;
  final String? clienteActual;
  final ValueChanged<Map<String, dynamic>> onSeleccionado;
  final VoidCallback onLimpiar;
  final bool dark;

  const _ClienteBuscadorTienda({
    required this.empresaId,
    this.clienteActual,
    required this.onSeleccionado,
    required this.onLimpiar,
    this.dark = false,
  });

  @override
  State<_ClienteBuscadorTienda> createState() => _ClienteBuscadorTiendaState();
}

class _ClienteBuscadorTiendaState extends State<_ClienteBuscadorTienda> {
  static const _kPrimario = Color(0xFF4A7C59);   // Sage primario
  static const _kSecundario = Color(0xFF81B29A); // Sage secundario

  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  bool _cargadoTodos = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        if (!_cargadoTodos) _cargarTodos();
        if (_ctrl.text.isEmpty) setState(() => _resultados = List.from(_todos));
      } else {
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
          .collection('empresas').doc(widget.empresaId).collection('clientes')
          .orderBy('nombre').limit(50).get();
      if (mounted) {
        final lista = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        setState(() {
          _todos = lista;
          _cargadoTodos = true;
          if (_ctrl.text.isEmpty) _resultados = List.from(lista);
          _buscando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _onChanged(String valor) {
    _debounce?.cancel();
    if (valor.isEmpty) {
      setState(() => _resultados = List.from(_todos));
      return;
    }
    final filtroLocal = _todos.where((c) =>
        ((c['nombre'] ?? '') as String).toLowerCase().contains(valor.toLowerCase())).toList();
    setState(() => _resultados = filtroLocal);

    if (filtroLocal.length < 3 && valor.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 350), () async {
        setState(() => _buscando = true);
        final q = FirebaseFirestore.instance
            .collection('empresas').doc(widget.empresaId).collection('clientes');
        var snap = await q
            .where('nombre_lower', isGreaterThanOrEqualTo: valor.toLowerCase())
            .where('nombre_lower', isLessThan: '${valor.toLowerCase()}z')
            .limit(10).get();
        if (snap.docs.isEmpty) {
          snap = await q
              .where('nombre', isGreaterThanOrEqualTo: valor)
              .where('nombre', isLessThan: '${valor}z')
              .limit(10).get();
        }
        final remotos = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        final ids = filtroLocal.map((c) => c['id']).toSet();
        final merged = [...filtroLocal, ...remotos.where((c) => !ids.contains(c['id']))];
        if (mounted) setState(() { _resultados = merged; _buscando = false; });
      });
    }
  }

  Future<void> _crearNuevoCliente(String nombre) async {
    try {
      final ref = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId).collection('clientes').add({
        'nombre': nombre,
        'nombre_lower': nombre.toLowerCase(),
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
      final nuevo = {'id': ref.id, 'nombre': nombre};
      widget.onSeleccionado(nuevo);
      _ctrl.text = nombre;
      setState(() { _resultados = []; _todos.add(nuevo); });
      _focus.unfocus();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dk = widget.dark;
    final colorTexto = dk ? Colors.white : const Color(0xFF1A3A27);
    final colorMuted = dk ? _kSecundario.withValues(alpha: 0.6) : Colors.grey.shade500;
    final colorFillField = dk ? const Color(0xFF2D4A35).withValues(alpha: 0.4) : Colors.transparent;
    final colorBorde = dk ? const Color(0xFF2D4A35) : Colors.grey.shade300;

    // Si hay cliente seleccionado → mostrar pill (sin campo de búsqueda)
    if (widget.clienteActual != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _kPrimario.withValues(alpha: dk ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kPrimario.withValues(alpha: dk ? 0.4 : 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _kPrimario.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Center(child: Text(
              widget.clienteActual!.isNotEmpty ? widget.clienteActual![0].toUpperCase() : '?',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dk ? _kSecundario : _kPrimario),
            )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.clienteActual!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorTexto)),
          ),
          GestureDetector(
            onTap: () { _ctrl.clear(); widget.onLimpiar(); },
            child: Icon(Icons.close_rounded, size: 14, color: colorMuted),
          ),
        ]),
      );
    }

    // Campo de búsqueda + dropdown
    return Column(children: [
      TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: _onChanged,
        style: TextStyle(fontSize: 12, color: colorTexto),
        decoration: InputDecoration(
          hintText: 'Buscar cliente…',
          hintStyle: TextStyle(fontSize: 11, color: colorMuted),
          prefixIcon: Icon(Icons.search, size: 16, color: colorMuted),
          suffixIcon: _buscando
              ? const Padding(padding: EdgeInsets.all(12),
                  child: SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 14, color: colorMuted),
                      onPressed: () { _ctrl.clear(); setState(() => _resultados = List.from(_todos)); },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28))
                  : null,
          filled: true,
          fillColor: colorFillField,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorBorde)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kPrimario, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
      ),
      if (_resultados.isNotEmpty || (_ctrl.text.length >= 2 && !_buscando))
        Builder(builder: (ctx) {
          const alturaItem = 52.0;
          final visibles = _resultados.take(5).toList();
          final hayMas = _resultados.length > 5;
          final maxH = (visibles.length * alturaItem + (hayMas ? 30 : 0) + 40).clamp(0.0, 5 * alturaItem + 70.0);
          return Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: BoxConstraints(maxHeight: maxH),
            decoration: BoxDecoration(
              color: dk ? const Color(0xFF233A29) : Colors.white,
              border: Border.all(color: colorBorde),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
            ),
            child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
              ...visibles.map((c) {
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
                          color: _kPrimario.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Center(child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: dk ? _kSecundario : _kPrimario),
                        )),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: colorTexto)),
                        if (telefono.isNotEmpty)
                          Text(telefono, style: TextStyle(fontSize: 10, color: colorMuted)),
                      ])),
                    ]),
                  ),
                );
              }),
              if (hayMas)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('+${_resultados.length - 5} resultados más — escribe para filtrar',
                      style: TextStyle(fontSize: 10, color: colorMuted, fontStyle: FontStyle.italic))),
              if (_ctrl.text.length >= 2 &&
                  !_resultados.any((c) => ((c['nombre'] ?? '') as String).toLowerCase() ==
                      _ctrl.text.trim().toLowerCase()) &&
                  !_todos.any((c) => ((c['nombre'] ?? '') as String).toLowerCase() ==
                      _ctrl.text.trim().toLowerCase()))
                InkWell(
                  onTap: () => _crearNuevoCliente(_ctrl.text.trim()),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(children: [
                      Container(width: 28, height: 28,
                        decoration: BoxDecoration(color: _kPrimario.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.person_add_outlined, size: 16, color: _kPrimario)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Crear "${_ctrl.text.trim()}"',
                          style: const TextStyle(fontSize: 12, color: _kPrimario, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),
            ]),
          );
        }),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO: NUEVO PRODUCTO
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoNuevoProducto extends StatefulWidget {
  final String empresaId;
  final String? codigoBarrasInicial;

  const _DialogoNuevoProducto({
    required this.empresaId,
    this.codigoBarrasInicial,
  });

  @override
  State<_DialogoNuevoProducto> createState() =>
      _DialogoNuevoProductoState();
}

class _DialogoNuevoProductoState extends State<_DialogoNuevoProducto> {
  final _nomCtrl = TextEditingController();
  final _prcCtrl = TextEditingController();
  final _prcWebCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _cbCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _stockMinCtrl = TextEditingController(text: '0');
  double _iva = 21;
  bool _guardando = false;

  final _catsRapidas = [
    'Bebidas', 'Alimentación', 'Higiene', 'Limpieza',
    'Electrónica', 'Ropa', 'Calzado', 'Hogar',
    'Papelería', 'Juguetes',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.codigoBarrasInicial != null) {
      _cbCtrl.text = widget.codigoBarrasInicial!;
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prcCtrl.dispose();
    _catCtrl.dispose();
    _cbCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.add_shopping_cart, color: Color(0xFF1B5E20)),
        SizedBox(width: 8),
        Text('Nuevo producto'),
      ]),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _nomCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _prcCtrl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio tienda (€) *',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _prcWebCtrl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio web (€)',
                    hintText: 'Vacío = igual tienda',
                    prefixIcon: Icon(Icons.language_outlined),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _cbCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código de barras',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _catCtrl,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Categoría',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _catsRapidas
                  .map((c) => ActionChip(
                label: Text(c,
                    style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => _catCtrl.text = c),
              ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Stock inicial',
                    prefixIcon: Icon(Icons.inventory),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _stockMinCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Stock mínimo',
                    prefixIcon: Icon(Icons.warning_amber_outlined),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Text('IVA:'),
              const SizedBox(width: 10),
              ...[4, 10, 21].map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$p%'),
                  selected: _iva == p,
                  onSelected: (_) =>
                      setState(() => _iva = p.toDouble()),
                  selectedColor: Colors.green.shade100,
                ),
              )),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C59)),
          child: _guardando
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    final nombre = _nomCtrl.text.trim();
    final precio =
        double.tryParse(_prcCtrl.text.replaceAll(',', '.')) ?? 0;
    if (nombre.isEmpty || precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nombre y precio son obligatorios'),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('catalogo')
          .add({
        'nombre': nombre,
        'precio': precio,
        'categoria': _catCtrl.text.trim().isEmpty
            ? 'General'
            : _catCtrl.text.trim(),
        'codigo_barras': _cbCtrl.text.trim().isEmpty
            ? null
            : _cbCtrl.text.trim(),
        'stock': int.tryParse(_stockCtrl.text) ?? 0,
        'stock_minimo': int.tryParse(_stockMinCtrl.text) ?? 0,
        'iva_porcentaje': _iva,
        'activo': true,
        'tiene_variantes': false,
        'variantes': [],
        if (_prcWebCtrl.text.trim().isNotEmpty)
          'precio_web': double.tryParse(_prcWebCtrl.text.replaceAll(',', '.')),
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        final messengerCatalogo = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messengerCatalogo.showSnackBar(SnackBar(
          content: Text('✅ "$nombre" añadido al catálogo'),
          backgroundColor: Colors.green.shade700,
        ));
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
// DIÁLOGO: EDITAR PRODUCTO EXISTENTE
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoEditarProducto extends StatefulWidget {
  final String empresaId;
  final String productoId;
  final Map<String, dynamic> datos;

  const _DialogoEditarProducto({
    required this.empresaId,
    required this.productoId,
    required this.datos,
  });

  @override
  State<_DialogoEditarProducto> createState() =>
      _DialogoEditarProductoState();
}

class _DialogoEditarProductoState extends State<_DialogoEditarProducto> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _prcCtrl;
  late final TextEditingController _catCtrl;
  late final TextEditingController _cbCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _stockMinCtrl;
  late double _iva;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(
        text: widget.datos['nombre'] as String? ?? '');
    _prcCtrl = TextEditingController(
        text: (widget.datos['precio'] as double?)?.toStringAsFixed(2) ??
            '0');
    _catCtrl = TextEditingController(
        text: widget.datos['categoria'] as String? ?? '');
    _cbCtrl = TextEditingController(
        text: widget.datos['codigo_barras'] as String? ?? '');
    _stockCtrl = TextEditingController(
        text: '${widget.datos['stock'] ?? 0}');
    _stockMinCtrl = TextEditingController(
        text: '${widget.datos['stock_minimo'] ?? 0}');
    _iva = (widget.datos['iva_porcentaje'] as double?) ?? 21;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prcCtrl.dispose();
    _catCtrl.dispose();
    _cbCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.edit, color: Color(0xFF1B5E20)),
        SizedBox(width: 8),
        Text('Editar producto'),
      ]),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _nomCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration:
              const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _prcCtrl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                  const InputDecoration(labelText: 'Precio (€)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _cbCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Código de barras'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _catCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration:
              const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration: const InputDecoration(labelText: 'Stock'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _stockMinCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Stock mínimo'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const Text('IVA:'),
              const SizedBox(width: 10),
              ...[4, 10, 21].map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$p%'),
                  selected: _iva == p,
                  onSelected: (_) =>
                      setState(() => _iva = p.toDouble()),
                  selectedColor: Colors.green.shade100,
                ),
              )),
            ]),
            const SizedBox(height: 10),
            // Botón desactivar producto
            OutlinedButton.icon(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(widget.empresaId)
                    .collection('catalogo')
                    .doc(widget.productoId)
                    .update({'activo': false});
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.visibility_off,
                  size: 16, color: Colors.red),
              label: const Text('Desactivar producto',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
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
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C59)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    final precio =
        double.tryParse(_prcCtrl.text.replaceAll(',', '.')) ?? 0;
    if (_nomCtrl.text.trim().isEmpty || precio <= 0) return;
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('catalogo')
          .doc(widget.productoId)
          .update({
        'nombre': _nomCtrl.text.trim(),
        'precio': precio,
        'categoria': _catCtrl.text.trim(),
        'codigo_barras': _cbCtrl.text.trim().isEmpty
            ? null
            : _cbCtrl.text.trim(),
        'stock': int.tryParse(_stockCtrl.text) ?? 0,
        'stock_minimo': int.tryParse(_stockMinCtrl.text) ?? 0,
        'iva_porcentaje': _iva,
      });
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
// DIÁLOGO DE PAGO
// ═══════════════════════════════════════════════════════════════════════════

class _TiendaDialogoPago extends StatefulWidget {
  final double total;
  final String metodoInicial;
  const _TiendaDialogoPago({required this.total, this.metodoInicial = 'efectivo'});

  @override
  State<_TiendaDialogoPago> createState() => _TiendaDialogoPagoState();
}

class _TiendaDialogoPagoState extends State<_TiendaDialogoPago> {
  late String _metodo;
  bool _terminalProcesando = false;
  String _terminalEstado = '';
  String? _terminalError;

  @override
  void initState() {
    super.initState();
    _metodo = widget.metodoInicial;
  }
  final _entregaCtrl = TextEditingController();
  final _efectivoCtrl = TextEditingController();
  final _tarjetaCtrl = TextEditingController();
  double _cambio = 0;

  @override
  void dispose() {
    _entregaCtrl.dispose();
    _efectivoCtrl.dispose();
    _tarjetaCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarCobroTerminal() async {
    setState(() { _terminalProcesando = true; _terminalEstado = 'procesando'; _terminalError = null; });
    final res = await TerminalFisicaService().cobrar(
      widget.total,
      descripcion: 'Venta TPV ${widget.total.toStringAsFixed(2)}€',
    );
    if (!mounted) return;
    if (res.esManual) {
      setState(() { _terminalProcesando = false; _terminalEstado = 'manual'; });
    } else if (res.exito) {
      setState(() { _terminalProcesando = false; _terminalEstado = 'exito'; });
    } else {
      setState(() { _terminalProcesando = false; _terminalEstado = 'error'; _terminalError = res.error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return AlertDialog(
      title: const Text('Método de pago'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(children: [
              const Text('Total',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF1B5E20))),
              Text(fmt.format(widget.total),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B5E20))),
            ]),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _TChip(
              label: 'Efectivo',
              icon: Icons.payments_outlined,
              selected: _metodo == 'efectivo',
              onTap: () => setState(() => _metodo = 'efectivo'),
              color: const Color(0xFF4CAF50),
            ),
            _TChip(
              label: 'Tarjeta',
              icon: Icons.credit_card,
              selected: _metodo == 'tarjeta',
              onTap: () => setState(() => _metodo = 'tarjeta'),
              color: const Color(0xFF2196F3),
            ),
            _TChip(
              label: 'Bizum',
              icon: Icons.smartphone_outlined,
              selected: _metodo == 'bizum',
              onTap: () => setState(() => _metodo = 'bizum'),
              color: const Color(0xFF7B1FA2),
            ),
            _TChip(
              label: 'Mixto',
              icon: Icons.swap_horiz,
              selected: _metodo == 'mixto',
              onTap: () => setState(() => _metodo = 'mixto'),
              color: const Color(0xFFFF9800),
            ),
            _TChip(
              label: 'Terminal',
              icon: Icons.credit_score,
              selected: _metodo == 'terminal',
              onTap: () => setState(() { _metodo = 'terminal'; _terminalEstado = ''; _terminalError = null; }),
              color: const Color(0xFF546E7A),
            ),
          ]),
          // UI terminal física
          if (_metodo == 'terminal') ...[
            const SizedBox(height: 12),
            _buildTerminalUi(),
          ],
          const SizedBox(height: 16),
          if (_metodo == 'efectivo') ...[
            TextField(
              controller: _entregaCtrl,
              autofocus: true,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Entrega del cliente (€)',
                  prefixIcon: Icon(Icons.payments_outlined)),
              onChanged: (v) {
                final e =
                    double.tryParse(v.replaceAll(',', '.')) ?? 0;
                setState(() => _cambio =
                    (e - widget.total).clamp(0.0, double.infinity));
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cambio',
                        style:
                        TextStyle(color: Colors.green.shade800)),
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
          if (_metodo == 'mixto') ...[
            TextField(
              controller: _efectivoCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Importe en efectivo (€)',
                  prefixIcon: Icon(Icons.payments_outlined)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tarjetaCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Importe en tarjeta (€)',
                  prefixIcon: Icon(Icons.credit_card)),
            ),
          ],
          if (_metodo == 'tarjeta') ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.info_outline, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text('Cobro por datáfono',
                  style: TextStyle(
                      fontSize: 13, color: cs.primary)),
            ]),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: (_metodo == 'terminal' && _terminalEstado != 'exito' && _terminalEstado != 'manual')
              ? null
              : () {
            double ef = 0, tj = 0, bz = 0;
            if (_metodo == 'efectivo') {
              ef = widget.total;
            } else if (_metodo == 'tarjeta' || _metodo == 'terminal') {
              tj = widget.total;
            } else if (_metodo == 'bizum') {
              bz = widget.total;
            } else {
              // mixto
              ef = double.tryParse(_efectivoCtrl.text.replaceAll(',', '.')) ?? 0;
              tj = double.tryParse(_tarjetaCtrl.text.replaceAll(',', '.')) ?? 0;
              if ((ef + tj - widget.total).abs() > 0.01) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Los importes no suman el total')));
                return;
              }
            }
            Navigator.pop(context, {
              'metodo': _metodo == 'terminal' ? 'tarjeta' : _metodo,
              'importe_efectivo': ef,
              'importe_tarjeta': tj,
              'importe_bizum': bz,
              'importes': <String, double>{
                if (ef > 0) 'efectivo': ef,
                if (tj > 0) 'tarjeta': tj,
                if (bz > 0) 'bizum': bz,
              },
            });
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A7C59)),
          child: const Text('Confirmar cobro'),
        ),
      ],
    );
  }

  Widget _buildTerminalUi() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7B1FA2).withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_terminalEstado == '' || _terminalEstado == 'error') ...[
          if (_terminalError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_terminalError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          FilledButton.icon(
            onPressed: _terminalProcesando ? null : _iniciarCobroTerminal,
            icon: _terminalProcesando
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.credit_score, size: 16),
            label: Text(_terminalProcesando ? 'Conectando con terminal…' : 'Iniciar cobro en terminal'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7B1FA2)),
          ),
        ],
        if (_terminalEstado == 'manual') ...[
          const Icon(Icons.phonelink_off, color: Color(0xFF7B1FA2)),
          const SizedBox(height: 6),
          const Text('Sin terminal configurado — confirma el pago manualmente', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        ],
        if (_terminalEstado == 'exito') ...[
          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28),
          const SizedBox(height: 4),
          const Text('Pago confirmado por terminal', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

// ── Widget fila de resumen (subtotal / descuento / IVA) ──────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isRed;
  const _SummaryRow(this.label, this.value, {this.isRed = false});

  @override
  Widget build(BuildContext context) {
    final color = isRed ? const Color(0xFFEF4444) : const Color(0xFF6B7280);
    return Row(children: [
      Text(label, style: TextStyle(fontSize: 13, color: color)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Botón de acceso rápido de pago ────────────────────────────────────────────

class _QuickPayBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickPayBtn({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    // No retorna Expanded: el Expanded lo pone el padre (Row) en el call site
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _TChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _TChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color = const Color(0xFF2196F3),
  });

  @override
  Widget build(BuildContext context) {
    // No retorna Expanded: este widget se usa dentro de Wrap (no es Flex)
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 22,
                color:
                selected ? color : Colors.grey.shade600),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: selected ? color : Colors.grey.shade700,
              ),
            ),
          ]),
        ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CIERRE DE CAJA (sin cambios respecto al original)
// ═══════════════════════════════════════════════════════════════════════════

class _TiendaCierreDeCaja extends StatefulWidget {
  final String empresaId;
  final VoidCallback? onCierreCerrado;
  const _TiendaCierreDeCaja({required this.empresaId, this.onCierreCerrado});

  @override
  State<_TiendaCierreDeCaja> createState() => _TiendaCierreDeCajaState();
}

class _TiendaCierreDeCajaState extends State<_TiendaCierreDeCaja> {
  Map<String, dynamic>? _datos;
  Map<String, dynamic>? _empresa;
  bool _cargando    = true;
  bool _cerrando    = false;
  bool _abriendo    = false;
  bool _cajaCerrada = false;
  DateTime? _horaCierre;
  bool _historialExpandido = false;
  List<Map<String, dynamic>> _ticketsDia      = [];
  List<Map<String, dynamic>> _ventasPostCierre = [];
  double _totalAyer = 0;
  final _efectivoContadoCtrl = TextEditingController();

  static const _kCian = Color(0xFF4A7C59);  // Sage primario (para fondos blancos)

  @override
  void dispose() {
    _efectivoContadoCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final hoy = DateTime.now();
      final inicio = DateTime(hoy.year, hoy.month, hoy.day);
      final fin = inicio.add(const Duration(days: 1));
      final fechaStr = DateFormat('yyyy-MM-dd').format(hoy);

      // ── Si ya existe un cierre registrado hoy, mostrar esos datos
      //    congelados en lugar de recalcular desde pedidos en vivo.
      final cierreDoc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('cierres_caja').doc(fechaStr).get();

      if (cierreDoc.exists) {
        final raw = cierreDoc.data() ?? {};
        final c = raw['cierre'] as Map<String, dynamic>?;
        if (c != null) {
          final pm = (c['por_metodo'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {};

          DateTime? horaCierre;
          final ts = c['fecha_hora'];
          if (ts is Timestamp) horaCierre = ts.toDate();

          // Reconstruir num_z y top a partir de datos secundarios
          int numZ = 1;
          try {
            final todosSnap = await FirebaseFirestore.instance
                .collection('empresas').doc(widget.empresaId)
                .collection('cierres_caja').get();
            numZ = todosSnap.docs.length;
          } catch (_) {}

          // Empresa
          Map<String, dynamic> empresaData = {};
          try {
            final eDoc = await FirebaseFirestore.instance
                .collection('empresas').doc(widget.empresaId).get();
            empresaData = eDoc.data() ?? {};
          } catch (_) {}

          final ef = (c['efectivo'] as num?)?.toDouble() ?? 0.0;
          final fondoInicial = (c['fondo_inicial'] as num?)?.toDouble() ?? 0.0;

          if (mounted) {
            setState(() {
              _cajaCerrada = true;
              _horaCierre  = horaCierre;
              _empresa     = empresaData;
              _datos = {
                'total':          (c['total'] as num?)?.toDouble() ?? 0.0,
                'efectivo':       ef,
                'tarjeta':        (c['tarjeta'] as num?)?.toDouble() ?? 0.0,
                'por_metodo':     pm,
                'metodos_config': [
                  {'id': 'efectivo', 'label': 'Efectivo'},
                  {'id': 'tarjeta',  'label': 'Tarjeta'},
                ],
                'num_tickets':     (c['num_tickets'] as num?)?.toInt() ?? 0,
                'tickets_anulados': 0,
                'ticket_medio':    0.0,
                'base_imponible':  (c['base_imponible'] as num?)?.toDouble() ?? 0.0,
                'cuota_iva':       (c['cuota_iva'] as num?)?.toDouble() ?? 0.0,
                'fondo_inicial':   fondoInicial,
                'efectivo_esperado': fondoInicial + ef,
                'apertura_usuario': c['usuario'] ?? '',
                'num_z':           numZ,
                'top':             <MapEntry<String, int>>[],
              };
              // Pre-rellenar el efectivo contado si se guardó
              final contado = (c['efectivo_contado'] as num?)?.toDouble();
              if (contado != null && _efectivoContadoCtrl.text.isEmpty) {
                _efectivoContadoCtrl.text = contado.toStringAsFixed(2);
              }
              _cargando = false;
            });
          }

          // Cargar historial completo del día (incluyendo pre-cierre)
          try {
            final tickSnap = await FirebaseFirestore.instance
                .collection('empresas').doc(widget.empresaId)
                .collection('pedidos')
                .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
                .where('fecha_hora', isLessThan: Timestamp.fromDate(fin))
                .orderBy('fecha_hora', descending: true).get();
            final tix = tickSnap.docs.map((d) => {
              'id': d.id,
              'num': d.data()['numero_ticket'] ?? '',
              'cliente': (d.data()['cliente_nombre'] as String?)?.isNotEmpty == true
                  ? d.data()['cliente_nombre'] : 'Caja directa',
              'total': (d.data()['total'] as num?)?.toDouble() ?? 0,
              'metodo': d.data()['metodo_pago'] ?? 'efectivo',
              'estado': d.data()['estado_pago'] ?? '',
              'hora': (d.data()['fecha_hora'] as Timestamp?)?.toDate(),
            }).toList();
            if (mounted) setState(() => _ticketsDia = tix);
          } catch (_) {}

          // Cargar ventas hechas DESPUÉS del cierre para mostrarlas aparte.
          // Query simple (sin filtro compuesto, evita necesitar índice Firestore).
          if (horaCierre != null) {
            try {
              final postSnap = await FirebaseFirestore.instance
                  .collection('empresas').doc(widget.empresaId)
                  .collection('pedidos')
                  .where('fecha_hora',
                      isGreaterThan: Timestamp.fromDate(horaCierre))
                  .orderBy('fecha_hora', descending: true)
                  .get();
              // Filtrar en Dart: solo pagados, no anulados
              final post = postSnap.docs
                  .where((d) {
                    final estado = d.data()['estado_pago'] as String? ?? '';
                    return estado == 'pagado';
                  })
                  .map((d) => {'id': d.id, ...d.data()})
                  .toList();
              if (mounted) setState(() => _ventasPostCierre = post);
            } catch (_) {}
          }

          return; // No recalcular desde pedidos
        }
      }

      // ── Métodos de pago configurados ──────────────────────────────────────
      const _baseMetodos = [
        (id: 'efectivo', label: 'Efectivo'), (id: 'tarjeta', label: 'Tarjeta'),
        (id: 'bizum', label: 'Bizum'), (id: 'transferencia', label: 'Transferencia'),
        (id: 'cheque_regalo', label: 'Cheque regalo'),
      ];
      List<({String id, String label})> metodosConfig = [(id: 'efectivo', label: 'Efectivo'), (id: 'tarjeta', label: 'Tarjeta')];
      try {
        final cfgDoc = await FirebaseFirestore.instance.collection('empresas')
            .doc(widget.empresaId).collection('configuracion').doc('tpv_cobro').get();
        if (cfgDoc.exists) {
          final habilitados = (cfgDoc.data()?['metodos_habilitados'] as List?)?.map((e) => e.toString()).toSet() ?? {};
          final custom = (cfgDoc.data()?['metodos_custom'] as List?)?.map((e) => e.toString()).toList() ?? [];
          if (habilitados.isNotEmpty) {
            metodosConfig = [
              ..._baseMetodos.where((m) => habilitados.contains(m.id)),
              ...custom.asMap().entries.where((e) => habilitados.contains('custom_${e.key}'))
                  .map((e) => (id: 'custom_${e.key}', label: e.value)),
            ];
          }
        }
      } catch (_) {}

      final snap = await FirebaseFirestore.instance.collection('empresas')
          .doc(widget.empresaId).collection('pedidos')
          .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha_hora', isLessThan: Timestamp.fromDate(fin)).get();

      final Map<String, double> porMetodo = {};
      double baseImponibleTotal = 0, cuotaIvaTotal = 0;
      final top = <String, int>{};
      int ticketsPagados = 0, ticketsAnulados = 0;

      for (final d in snap.docs) {
        final m = d.data();
        if (m['estado_pago'] == 'anulado') { ticketsAnulados++; continue; }
        if (m['estado_pago'] != 'pagado') continue;
        ticketsPagados++;
        final pedTotal = (m['total'] as num?)?.toDouble() ?? 0.0;
        final met = m['metodo_pago'] as String? ?? 'efectivo';
        if (met == 'mixto') {
          // Intenta primero 'importes' (campo que guarda el TPV Tienda),
          // luego 'importes_por_metodo' como fallback de otros TPVs.
          final rawImportes = m['importes'] ?? m['importes_por_metodo'];
          final importes = (rawImportes as Map?)?.cast<String, dynamic>();
          if (importes != null && importes.isNotEmpty) {
            for (final e in importes.entries) {
              final v = (e.value as num?)?.toDouble() ?? 0;
              if (v > 0) porMetodo[e.key] = (porMetodo[e.key] ?? 0) + v;
            }
          } else {
            final ef = (m['importe_efectivo'] as num?)?.toDouble() ?? 0;
            final tj = (m['importe_tarjeta'] as num?)?.toDouble() ?? 0;
            porMetodo['efectivo'] = (porMetodo['efectivo'] ?? 0) + (ef == 0 && tj == 0 ? pedTotal / 2 : ef);
            porMetodo['tarjeta'] = (porMetodo['tarjeta'] ?? 0) + (ef == 0 && tj == 0 ? pedTotal / 2 : tj);
          }
        } else {
          porMetodo[met] = (porMetodo[met] ?? 0) + pedTotal;
        }
        for (final l in m['lineas'] as List? ?? []) {
          final n = (l['producto_nombre'] as String?) ?? (l['nombre'] as String?) ?? '';
          if (n.isNotEmpty) top[n] = (top[n] ?? 0) + ((l['cantidad'] as num?)?.toInt() ?? 1);
          final base = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
          final cant = (l['cantidad'] as num?)?.toDouble() ?? 1.0;
          final iva = ((l['iva_porcentaje'] ?? l['porcentaje_iva'] ?? 21.0) as num).toDouble();
          baseImponibleTotal += base * cant;
          cuotaIvaTotal += base * cant * iva / 100;
        }
      }

      final total = porMetodo.values.fold(0.0, (a, b) => a + b);
      if (baseImponibleTotal == 0 && total > 0) {
        baseImponibleTotal = total / 1.21;
        cuotaIvaTotal = total - baseImponibleTotal;
      }

      // ── Apertura de caja ──
      double fondoInicial = 0;
      String? aperturaUsuario;
      int numZ = 1;
      try {
        final aperturasSnap = await FirebaseFirestore.instance.collection('empresas')
            .doc(widget.empresaId).collection('aperturas_caja')
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('fecha', isLessThan: Timestamp.fromDate(fin))
            .orderBy('fecha', descending: true).limit(1).get();
        if (aperturasSnap.docs.isNotEmpty) {
          final ap = aperturasSnap.docs.first.data();
          fondoInicial = (ap['fondo_inicial'] as num?)?.toDouble() ?? 0;
          final uid = ap['camarero_uid'] as String? ?? '';
          if (uid.isNotEmpty) {
            try {
              final uDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
              final ud = uDoc.data();
              aperturaUsuario = (ud?['nombre'] as String?) ?? (ud?['email'] as String?) ?? uid;
            } catch (_) { aperturaUsuario = uid; }
          }
        }
        final todosSnap = await FirebaseFirestore.instance.collection('empresas')
            .doc(widget.empresaId).collection('cierres_caja').get();
        numZ = todosSnap.docs.length + 1;
      } catch (_) {}

      // ── Historial tickets ──
      final List<Map<String, dynamic>> ticketsDia = [];
      try {
        final tickSnap = await FirebaseFirestore.instance.collection('empresas')
            .doc(widget.empresaId).collection('pedidos')
            .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('fecha_hora', isLessThan: Timestamp.fromDate(fin))
            .orderBy('fecha_hora', descending: true).get();
        for (final d in tickSnap.docs) {
          final m = d.data();
          ticketsDia.add({
            'id': d.id,
            'num': m['numero_ticket'] ?? '',
            'cliente': m['cliente_nombre'] ?? 'Caja directa',
            'total': (m['total'] as num?)?.toDouble() ?? 0,
            'metodo': m['metodo_pago'] ?? 'efectivo',
            'estado': m['estado_pago'] ?? '',
            'hora': (m['fecha_hora'] as Timestamp?)?.toDate(),
          });
        }
      } catch (_) {}

      // ── Total ayer ──
      double totalAyer = 0;
      try {
        final ayerStr = DateFormat('yyyy-MM-dd').format(hoy.subtract(const Duration(days: 1)));
        final ayerDoc = await FirebaseFirestore.instance.collection('empresas')
            .doc(widget.empresaId).collection('cierres_caja').doc(ayerStr).get();
        if (ayerDoc.exists) totalAyer = (ayerDoc.data()?['cierre']?['total'] as num?)?.toDouble() ?? 0;
      } catch (_) {}

      // ── Empresa ──
      Map<String, dynamic> empresaData = {};
      try {
        final eDoc = await FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).get();
        empresaData = eDoc.data() ?? {};
      } catch (_) {}

      if (mounted) {
        setState(() {
          _empresa = empresaData;
          _ticketsDia = ticketsDia;
          _totalAyer = totalAyer;
          _datos = {
            'total': total,
            'efectivo': porMetodo['efectivo'] ?? 0,
            'tarjeta': porMetodo['tarjeta'] ?? 0,
            'por_metodo': porMetodo,
            'metodos_config': metodosConfig.map((m) => {'id': m.id, 'label': m.label}).toList(),
            'num_tickets': ticketsPagados,
            'tickets_anulados': ticketsAnulados,
            'ticket_medio': ticketsPagados == 0 ? 0.0 : total / ticketsPagados,
            'base_imponible': baseImponibleTotal,
            'cuota_iva': cuotaIvaTotal,
            'fondo_inicial': fondoInicial,
            'efectivo_esperado': fondoInicial + (porMetodo['efectivo'] ?? 0),
            'apertura_usuario': aperturaUsuario ?? 'Sin registrar',
            'num_z': numZ,
            'top': (top.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList(),
          };
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _datos = {'total': 0.0, 'efectivo': 0.0, 'tarjeta': 0.0, 'por_metodo': <String, double>{},
            'num_tickets': 0, 'ticket_medio': 0.0, 'base_imponible': 0.0, 'cuota_iva': 0.0,
            'top': <MapEntry<String, int>>[], 'num_z': 1};
          _cargando = false;
        });
        FluxToast.aviso(context, 'Error al cargar datos: $e');
      }
    }
  }

  Future<void> _cerrar() async {
    final totalSistema = (_datos?['efectivo'] as num?)?.toDouble() ?? 0.0;
    final arqueoResult = await ArqueoCajaWidget.mostrar(context, totalSistema: totalSistema);
    if (!mounted || arqueoResult == null) return;

    // Conectar el total del arqueo al cálculo de descuadre
    _efectivoContadoCtrl.text = arqueoResult.total.toStringAsFixed(2);

    final hayDescuadre = _efectivoContado >= 0 && _descuadre.abs() >= 0.01;
    String? motivoDescuadre;
    if (hayDescuadre) {
      final motivo = await _dialogoDescuadre();
      if (motivo == null) return;
      motivoDescuadre = motivo;
    } else {
      final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('Confirmar cierre de caja'),
        content: const Text('¿Registrar el cierre del día?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar caja')),
        ],
      ));
      if (ok != true) return;
    }

    setState(() => _cerrando = true);
    try {
      final d = _datos!;
      final fechaStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final contado = _efectivoContado >= 0 ? _efectivoContado : null;
      final docRef = FirebaseFirestore.instance.collection('empresas')
          .doc(widget.empresaId).collection('cierres_caja').doc(fechaStr);

      // Guardia anti-doble-cierre: si el documento existe con cualquier dato
      // de cierre, bloqueamos — aunque haya sido escritura parcial.
      final existing = await docRef.get();
      if (existing.exists) {
        final data = existing.data() ?? {};
        final tieneCierre = data.containsKey('cierre') ||
            data.containsKey('fecha_hora') ||
            data.containsKey('total');
        if (tieneCierre) {
          if (mounted) FluxToast.aviso(context, 'La caja ya fue cerrada hoy');
          setState(() => _cerrando = false);
          return;
        }
      }

      await docRef.set({'fecha': fechaStr, 'cierre': {
        'fecha_hora': FieldValue.serverTimestamp(),
        'usuario': uid, 'total': d['total'],
        'efectivo': d['efectivo'], 'tarjeta': d['tarjeta'],
        'por_metodo': d['por_metodo'] ?? {'efectivo': d['efectivo'], 'tarjeta': d['tarjeta']},
        'num_tickets': d['num_tickets'],
        'base_imponible': d['base_imponible'], 'cuota_iva': d['cuota_iva'],
        'fondo_inicial': (d['fondo_inicial'] as num?)?.toDouble() ?? 0,
        if (contado != null) ...{
          'efectivo_contado': contado,
          'efectivo_esperado': (d['efectivo_esperado'] as num?)?.toDouble() ?? 0,
          'descuadre': _descuadre, 'hay_descuadre': hayDescuadre,
          if (motivoDescuadre != null) 'motivo_descuadre': motivoDescuadre,
          'arqueo_denominaciones': arqueoResult.dens,
        },
      }}, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          _cajaCerrada = true;
          _horaCierre  = DateTime.now();
        });
        widget.onCierreCerrado?.call();
        hayDescuadre
          ? FluxToast.aviso(context, 'Cierre registrado con descuadre de ${_descuadre.abs().toStringAsFixed(2)} EUR')
          : FluxToast.exito(context, 'Cierre de caja registrado');
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al cerrar caja: $e');
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  Future<String?> _dialogoDescuadre() async {
    final ctrl = TextEditingController();
    final descuadreAbs = _descuadre.abs();
    final esSobrante = _descuadre > 0;
    return showDialog<String>(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          SizedBox(width: 8), Text('Descuadre detectado'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200)),
            child: Row(children: [
              Text(esSobrante ? 'Sobrante:' : 'Falta:', style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text('${descuadreAbs.toStringAsFixed(2)} EUR',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: esSobrante ? Colors.green.shade700 : Colors.red.shade700)),
            ]),
          ),
          const SizedBox(height: 14),
          const Text('Indica el motivo del descuadre (obligatorio):', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          TextField(controller: ctrl, maxLines: 3, autofocus: true,
              decoration: InputDecoration(hintText: 'Ej: Error al dar cambio…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          StatefulBuilder(builder: (ctx, setSt) => FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) { setSt(() {}); return; }
              Navigator.pop(context, ctrl.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
            child: const Text('Registrar con descuadre'),
          )),
        ],
      ),
    );
  }

  Future<void> _enviarZPdfEmail() async {
    if (_datos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin datos de cierre'), backgroundColor: Colors.orange));
      return;
    }

    // ── 1. Pedir email al usuario ──────────────────────────────────────────
    final emailCtrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool enviando = false;
        return StatefulBuilder(builder: (ctx, setS) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.email_outlined, size: 20),
            SizedBox(width: 8),
            Text('Enviar Z-Report por email', style: TextStyle(fontSize: 15)),
          ]),
          content: SizedBox(
            width: 300,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: emailCtrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (e) {
                  if (e.trim().contains('@')) Navigator.pop(ctx, e.trim());
                },
                decoration: InputDecoration(
                  labelText: 'Destinatario',
                  hintText: 'gerente@empresa.com',
                  prefixIcon: const Icon(Icons.alternate_email, size: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: enviando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: enviando ? null : () {
                final e = emailCtrl.text.trim();
                if (e.contains('@')) Navigator.pop(ctx, e);
              },
              icon: enviando
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : const Icon(Icons.send_rounded, size: 15),
              label: Text(enviando ? 'Enviando…' : 'Enviar'),
              style: FilledButton.styleFrom(
                  backgroundColor: _kCian, foregroundColor: Colors.black87),
            ),
          ],
        ));
      },
    );
    if (email == null || !mounted) return;

    // ── 2. Mostrar progreso ────────────────────────────────────────────────
    final messenger = ScaffoldMessenger.of(context);
    final progressBar = messenger.showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Generando PDF y enviando…'),
      ]),
      duration: Duration(minutes: 2),
      backgroundColor: Color(0xFF1E293B),
    ));

    try {
      // ── 3. Generar PDF ─────────────────────────────────────────────────
      final pdfBytes    = await _buildPdfBytes();
      final pdfBase64   = base64Encode(pdfBytes);
      final numZ        = (_datos!['num_z'] as num?)?.toInt() ?? 1;
      final empresaNombre = (_empresa?['nombre'] as String?) ?? 'TPV';

      // ── 4. Enviar via HTTP (evita canal Pigeon que no funciona en Windows)
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final resp = await http.post(
        Uri.parse(
          'https://europe-west1-planeaapp-4bea4.cloudfunctions.net/enviarEmailConPdf',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'data': {
          'destinatario': email,
          'asunto': 'Z-Report #$numZ — $empresaNombre — $_hoy',
          'cuerpoHtml':
              '<p>Adjunto el Z-Report #$numZ del día $_hoy.</p>'
              '<p>Total ventas: ${(_datos!['total'] as num?)?.toStringAsFixed(2) ?? '0,00'} €</p>'
              '<p>— $empresaNombre</p>',
          'pdfBase64': pdfBase64,
          'nombreArchivo':
              'z_report_${numZ}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
          'empresaId': widget.empresaId,
        }}),
      ).timeout(const Duration(seconds: 30));

      progressBar.close();

      if (resp.statusCode >= 400) {
        throw Exception('Servidor devolvió ${resp.statusCode}:\n${resp.body}');
      }

      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('✅ Z-Report enviado a $email'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      progressBar.close();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.error_outline, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Error al enviar', style: TextStyle(fontSize: 15)),
            ]),
            content: SelectableText('$e',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
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
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _imprimirZPdf() async {
    if (_datos == null) return;
    final bytes = await _buildPdfBytes();
    await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
  }

  Future<List<int>> _buildPdfBytes() async {
    final d = _datos!;
    final e = _empresa ?? {};
    String fmtEur(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} EUR';
    final now = DateTime.now();
    final numZ = d['num_z'] as int? ?? 1;
    final empresaNombre = e['nombre'] as String? ?? 'Sin nombre';
    final empresaNif = e['nif'] as String? ?? e['cif'] as String? ?? 'Sin NIF';
    final empresaDireccion = e['direccion'] as String? ?? '';
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(empresaNombre, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            if (empresaDireccion.isNotEmpty)
              pw.Text(empresaDireccion, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text('NIF: $empresaNif', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Z-REPORT Nº $numZ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Fecha: $_hoy  ${DateFormat('HH:mm').format(now)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ]),
        ]),
        pw.SizedBox(height: 6), pw.Divider(thickness: 1.5), pw.SizedBox(height: 8),
        _pSeccion('RESUMEN DE VENTAS'),
        _pRow('Tickets cobrados', '${d['num_tickets']}'),
        _pRow('Ticket medio', fmtEur((d['ticket_medio'] as num).toDouble())),
        _pRowBold('TOTAL VENTAS', fmtEur((d['total'] as num).toDouble())),
        pw.SizedBox(height: 10),
        _pSeccion('COBROS POR FORMA DE PAGO'),
        ...(() {
          final pm = d['por_metodo'] as Map<String, double>? ?? <String, double>{};
          final cfg = (d['metodos_config'] as List?)?.map((e) => (id: e['id'] as String, label: e['label'] as String)).toList()
              ?? [(id: 'efectivo', label: 'Efectivo'), (id: 'tarjeta', label: 'Tarjeta')];
          return cfg.map((m) => _pRow(m.label, fmtEur(pm[m.id] ?? 0)));
        })(),
        pw.SizedBox(height: 10),
        _pSeccion('DESGLOSE IVA'),
        _pRow('Base imponible', fmtEur((d['base_imponible'] as num).toDouble())),
        _pRow('Cuota IVA (21%)', fmtEur((d['cuota_iva'] as num).toDouble())),
        pw.SizedBox(height: 10),
        _pSeccion('TOP PRODUCTOS'),
        ...(d['top'] as List).asMap().entries.map((e) {
          final entry = e.value as MapEntry<String, int>;
          return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('${e.key + 1}. ${entry.key}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('×${entry.value}', style: const pw.TextStyle(fontSize: 10)),
          ]);
        }),
      ]),
    ));
    return doc.save();
  }

  pw.Widget _pSeccion(String t) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey700)));
  pw.Widget _pRow(String l, String v) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [pw.Text(l, style: const pw.TextStyle(fontSize: 10)),
               pw.Text(v, style: const pw.TextStyle(fontSize: 10))]);
  pw.Widget _pRowBold(String l, String v) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [pw.Text(l, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
               pw.Text(v, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))]);

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
    if (_cargando) return const Center(child: CircularProgressIndicator(color: _kCian));
    final d = _datos!;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    double n(String k) => (d[k] as num?)?.toDouble() ?? 0.0;
    final total = n('total');
    final ef = n('efectivo');
    final numTickets = (d['num_tickets'] as num?)?.toInt() ?? 0;
    final anulados = (d['tickets_anulados'] as num?)?.toInt() ?? 0;
    final fondoInicial = n('fondo_inicial');
    final efectivoEsperado = n('efectivo_esperado');
    final baseImp = n('base_imponible');
    final cuotaIva = n('cuota_iva');
    final numZ = (d['num_z'] as num?)?.toInt() ?? 1;
    final pctVsAyer = _totalAyer > 0 ? ((total - _totalAyer) / _totalAyer * 100) : null;

    return Column(children: [
      // ── Toolbar ────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(children: [
          // Badge Z + fecha
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _cajaCerrada
                  ? Colors.green.shade50
                  : _kCian.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: _cajaCerrada
                  ? Border.all(color: Colors.green.shade300) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_cajaCerrada) ...[
                Icon(Icons.lock, size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
              ],
              Text(
                _cajaCerrada
                    ? 'Z-$numZ · Cerrada${_horaCierre != null ? ' ${DateFormat('HH:mm').format(_horaCierre!)}' : ''}'
                    : 'Z-$numZ · $_hoy',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: _cajaCerrada ? Colors.green.shade700 : const Color(0xFF4A7C59),
                ),
              ),
            ]),
          ),
          const Spacer(),
          _toolBtn(Icons.refresh, 'Actualizar', _cargarDatos),
          const SizedBox(width: 4),
          _toolBtn(Icons.print_outlined, 'Vista previa Z-PDF', _imprimirZPdf, color: _kCian),
          const SizedBox(width: 4),
          _toolBtn(Icons.email_outlined, 'Enviar Z-PDF por email', _enviarZPdfEmail),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _abriendo ? null : _abrirCajon,
            icon: _abriendo
                ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
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
          // Botón "Cerrar caja" / "Caja cerrada"
          _cajaCerrada
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text('Caja cerrada',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.green.shade700)),
                  ]),
                )
              : FilledButton.icon(
                  onPressed: _cerrando ? null : _cerrar,
                  icon: _cerrando
                      ? const SizedBox(width: 13, height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                      : const Icon(Icons.lock_outline, size: 14, color: Colors.black87),
                  label: const Text('Cerrar caja', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kCian,
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

            // ── KPIs ──────────────────────────────────────────────────
            Row(children: [
              Expanded(child: _kpi('Total ventas', fmt.format(total), Icons.euro_rounded,
                  color: _kCian,
                  sub: pctVsAyer != null ? '${pctVsAyer >= 0 ? '+' : ''}${pctVsAyer.toStringAsFixed(1)}% vs ayer' : null,
                  subColor: pctVsAyer == null ? null : (pctVsAyer >= 0 ? Colors.green : Colors.red))),
              const SizedBox(width: 8),
              Expanded(child: _kpi('Tickets', '$numTickets', Icons.receipt_long_rounded,
                  sub: anulados > 0 ? '$anulados anulados' : null, subColor: Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _kpi('Ticket medio', fmt.format(n('ticket_medio')), Icons.show_chart, color: _kCian)),
            ]),
            const SizedBox(height: 10),

            // ── Cobros por forma de pago ───────────────────────────────
            _seccion('Cobros por forma de pago', [
              LayoutBuilder(builder: (ctx, constraints) {
                final pm = (d['por_metodo'] as Map<String, double>?) ?? {'efectivo': ef};
                final todosIds = <String>{
                  ...(d['metodos_config'] as List?)?.map((e) => e['id'] as String)
                      .where((k) => k != 'mixto') ?? const ['efectivo', 'tarjeta'],
                  ...pm.keys.where((k) => k != 'mixto'),
                };
                final metodos = todosIds
                    .where((k) => (pm[k] ?? 0) > 0.001)
                    .map((k) => (id: k, label: _labelMetodo(k), valor: pm[k] ?? 0))
                    .toList()..sort((a, b) => b.valor.compareTo(a.valor));
                if (metodos.isEmpty) {
                  return Text('Sin cobros hoy', style: TextStyle(color: Colors.grey.shade500, fontSize: 12));
                }
                final w = constraints.maxWidth;
                final itemW = metodos.length > 1 ? (w - 8) / 2 : w;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 8, children: metodos.map((m) =>
                    SizedBox(width: itemW, child: _barraMetodo(m.label, m.valor, total, _colorMetodo(m.id), _iconMetodo(m.id)))).toList()),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.euro_rounded, size: 14),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('TOTAL VENTAS DEL DÍA',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
                    Text(fmt.format(total),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF4A7C59))),
                  ]),
                ]);
              }),
            ]),
            const SizedBox(height: 10),

            // ── Cuadre de caja ─────────────────────────────────────────
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
                const Expanded(
                  child: Text('Efectivo real contado:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                // Botón táctil que abre el teclado numérico
                GestureDetector(
                  onTap: () async {
                    final actual = _efectivoContado >= 0 ? _efectivoContado : null;
                    final v = await TecladoNumerico.mostrar(
                      context,
                      label: 'EFECTIVO CONTADO',
                      sufijo: '€',
                      valorInicial: actual,
                      permitirDecimal: true,
                    );
                    if (v != null) {
                      setState(() => _efectivoContadoCtrl.text = v.toStringAsFixed(2));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kCian.withValues(alpha: 0.6)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.dialpad_rounded, size: 15, color: _kCian),
                      const SizedBox(width: 8),
                      Text(
                        _efectivoContado >= 0
                            ? '${_efectivoContado.toStringAsFixed(2)} €'
                            : 'Tocar para contar',
                        style: TextStyle(
                          color: _efectivoContado >= 0 ? Colors.white : Colors.white38,
                          fontSize: _efectivoContado >= 0 ? 16 : 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                // Badge cuadre / descuadre
                if (_efectivoContado >= 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _descuadre.abs() < 0.01
                          ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _descuadre.abs() < 0.01
                          ? Colors.green.shade300 : Colors.red.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _descuadre.abs() < 0.01
                            ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 14,
                        color: _descuadre.abs() < 0.01
                            ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _descuadre.abs() < 0.01
                            ? 'Cuadra ✓'
                            : '${_descuadre > 0 ? '+' : ''}${fmt.format(_descuadre)}',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _descuadre.abs() < 0.01
                              ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ]),
                  ),
              ]),
            ]),
            const SizedBox(height: 10),

            // ── Ventas post-cierre (solo cuando la caja está cerrada) ───
            if (_cajaCerrada && _ventasPostCierre.isNotEmpty) ...[
              const SizedBox(height: 10),
              _seccion('Ventas posteriores al cierre', [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Estas ${_ventasPostCierre.length} ventas se incluirán en el próximo cierre.',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                    )),
                  ]),
                ),
                const SizedBox(height: 8),
                ...() {
                  final fmtH = NumberFormat.currency(symbol: '€', decimalDigits: 2);
                  final totalPost = _ventasPostCierre.fold(0.0, (s, p) => s + ((p['total'] as num?)?.toDouble() ?? 0));
                  return [
                    ..._ventasPostCierre.map((p) {
                      final hora = (p['fecha_hora'] as Timestamp?)?.toDate();
                      final horaStr = hora != null ? DateFormat('HH:mm').format(hora) : '';
                      final t = (p['total'] as num?)?.toDouble() ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Text('#${p['numero_ticket'] ?? '—'}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151))),
                          const SizedBox(width: 8),
                          if (horaStr.isNotEmpty) ...[
                            Text(horaStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                            const SizedBox(width: 8),
                          ],
                          Expanded(child: Text(p['cliente_nombre'] as String? ?? 'Sin cliente',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              overflow: TextOverflow.ellipsis)),
                          Text(fmtH.format(t),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A7C59))),
                        ]),
                      );
                    }),
                    const Divider(height: 16),
                    Row(children: [
                      const Expanded(child: Text('TOTAL POST-CIERRE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
                      Text(fmtH.format(totalPost),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                              color: Color(0xFF4A7C59))),
                    ]),
                  ];
                }(),
              ]),
            ] else if (_cajaCerrada) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text('Sin ventas posteriores al cierre.',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
                ]),
              ),
            ],

            // ── IVA fiscal ─────────────────────────────────────────────
            _seccion('Desglose IVA (art. 164 Ley 37/1992)', [
              Table(
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3),
                    2: FlexColumnWidth(3), 3: FlexColumnWidth(3)},
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: _kCian.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6)),
                    children: ['Tipo', 'Base imp.', 'Cuota IVA', 'Total']
                        .map((h) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            child: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))))
                        .toList(),
                  ),
                  TableRow(children: ['21%', fmt.format(baseImp), fmt.format(cuotaIva), fmt.format(total)]
                      .map((v) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: Text(v, style: const TextStyle(fontSize: 11)))).toList()),
                ],
              ),
            ]),
            const SizedBox(height: 10),

            // ── Top productos ──────────────────────────────────────────
            if ((d['top'] as List).isNotEmpty)
              _seccion('Top productos del día', [
                ...(d['top'] as List).asMap().entries.map((e) {
                  final entry = e.value as MapEntry<String, int>;
                  final maxCnt = ((d['top'] as List).first as MapEntry<String, int>).value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 18, height: 18,
                          decoration: BoxDecoration(color: const Color(0xFF4A7C59), borderRadius: BorderRadius.circular(4)),
                          child: Center(child: Text('${e.key + 1}',
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                        Text('×${entry.value}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4A7C59))),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: entry.value / maxCnt,
                          backgroundColor: _kCian.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF4A7C59)),
                          minHeight: 3,
                        ),
                      ),
                    ]),
                  );
                }),
              ]),
            if ((d['top'] as List).isNotEmpty) const SizedBox(height: 10),

            // ── Historial tickets ──────────────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _historialExpandido = !_historialExpandido),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kCian.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kCian.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.receipt_long, size: 15, color: Color(0xFF4A7C59)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Historial del día — ${_ticketsDia.length} tickets',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A7C59)))),
                  GestureDetector(
                    onTap: () => HistorialTicketsWidget.mostrar(context, widget.empresaId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kCian.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kCian.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Ver completo', style: TextStyle(fontSize: 10, color: Color(0xFF4A7C59), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_historialExpandido ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: const Color(0xFF4A7C59)),
                ]),
              ),
            ),
            if (_historialExpandido && _ticketsDia.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                child: Column(children: _ticketsDia.asMap().entries.map((e) {
                  final t = e.value;
                  final hora = t['hora'] as DateTime?;
                  final horaStr = hora != null ? DateFormat('HH:mm').format(hora) : '';
                  final ticketTotal = t['total'] as double;
                  final pagado = t['estado'] == 'pagado';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: e.key.isEven ? Colors.white : Colors.grey.shade50,
                      borderRadius: e.key == _ticketsDia.length - 1
                          ? const BorderRadius.vertical(bottom: Radius.circular(8)) : null,
                    ),
                    child: Row(children: [
                      Text(horaStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle,
                          color: pagado ? Colors.green : Colors.red)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(t['cliente'] as String,
                          style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                      Text(_metodoPagoEmoji(t['metodo'] as String), style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 6),
                      Text(fmt.format(ticketTotal), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: pagado ? Colors.green.shade700 : Colors.red.shade400)),
                    ]),
                  );
                }).toList()),
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
      IconButton(icon: Icon(icon, size: 17, color: color), tooltip: tooltip, onPressed: onTap,
          padding: const EdgeInsets.all(6), constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          visualDensity: VisualDensity.compact);

  // Retorna Container, no Expanded — el Expanded lo añade el Row en el call site
  Widget _kpi(String label, String valor, IconData icon,
      {Color? color, String? sub, Color? subColor}) =>
      Container(
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
              color: color != null ? const Color(0xFF4A7C59) : Colors.black87)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 10, color: subColor ?? Colors.grey.shade500)),
          ],
        ]),
      );

  static String _labelMetodo(String id) => switch (id) {
    'efectivo' => 'Efectivo', 'tarjeta' => 'Tarjeta', 'bizum' => 'Bizum',
    'transferencia' => 'Transferencia', 'cheque_regalo' => 'Cheque regalo', 'mixto' => 'Mixto',
    _ => id.startsWith('custom_') ? id.replaceFirst('custom_', 'Otro ') : id,
  };

  static Color _colorMetodo(String id) => switch (id) {
    'efectivo' => const Color(0xFF2E7D32), 'tarjeta' => const Color(0xFF1565C0),
    'bizum' => const Color(0xFF7B1FA2), 'transferencia' => const Color(0xFF00838F),
    'cheque_regalo' => const Color(0xFFF57F17), _ => const Color(0xFF546E7A),
  };

  static IconData _iconMetodo(String id) => switch (id) {
    'efectivo' => Icons.payments_outlined, 'tarjeta' => Icons.credit_card,
    'bizum' => Icons.smartphone_outlined, 'transferencia' => Icons.account_balance_outlined,
    'cheque_regalo' => Icons.card_giftcard_outlined, _ => Icons.payment_outlined,
  };

  Widget _barraMetodo(String label, double valor, double total, Color color, IconData icon) {
    final pct = total > 0 ? (valor / total).clamp(0.0, 1.0) : 0.0;
    final fmt2 = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${(pct * 100).toInt()}%', style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        ]),
        const SizedBox(height: 5),
        Text(fmt2.format(valor), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: pct, backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color), minHeight: 4)),
      ]),
    );
  }

  Widget _filaCuadre(String label, double valor) {
    final fmt2 = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(fmt2.format(valor), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _filaCuadreDestacada(String label, double valor) {
    final fmt2 = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kCian.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kCian.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(fmt2.format(valor),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF4A7C59))),
      ]),
    );
  }

  Widget _seccion(String titulo, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: Colors.grey.shade600, letterSpacing: 0.3)),
      const SizedBox(height: 8),
      ...children,
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ESCÁNER DE CÁMARA MODAL
// ═══════════════════════════════════════════════════════════════════════════

class _EscanerCamaraModal extends StatefulWidget {
  final ValueChanged<String> onCodigoEscaneado;

  const _EscanerCamaraModal({required this.onCodigoEscaneado});

  @override
  State<_EscanerCamaraModal> createState() => _EscanerCamaraModalState();
}

class _EscanerCamaraModalState extends State<_EscanerCamaraModal> {
  MobileScannerController controller = MobileScannerController();
  bool _yaEscaneado = false; // Evitar doble disparo

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Cámara a pantalla casi completa
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (_yaEscaneado) return;
                final barcode = capture.barcodes.firstOrNull;
                if (barcode?.rawValue != null) {
                  _yaEscaneado = true;
                  Navigator.pop(context);
                  widget.onCodigoEscaneado(barcode!.rawValue!);
                }
              },
            ),
          ),
          // Botón cerrar
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                shape: const CircleBorder(),
              ),
            ),
          ),
          // Instrucciones
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, size: 32, color: Color(0xFF1B5E20)),
                  SizedBox(height: 8),
                  Text(
                    'Enfoca el código de barras',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Se escaneará automáticamente',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO: ETIQUETA PARA PEDIDO EN ESPERA
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoEtiquetaEspera extends StatefulWidget {
  const _DialogoEtiquetaEspera();

  @override
  State<_DialogoEtiquetaEspera> createState() => _DialogoEtiquetaEsperaState();
}

class _DialogoEtiquetaEsperaState extends State<_DialogoEtiquetaEspera> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.pause_circle_outline, color: Color(0xFF1B5E20)),
        SizedBox(width: 8),
        Text('Guardar en espera'),
      ]),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Etiqueta (ej: Mesa 3, Cliente Juan…)',
          prefixIcon: Icon(Icons.label_outline),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim().isEmpty ? 'En espera' : v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v = _ctrl.text.trim();
            Navigator.pop(context, v.isEmpty ? 'En espera' : v);
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A7C59)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
