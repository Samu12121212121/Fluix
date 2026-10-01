import 'dart:async';
import 'dart:math' show Random;
import 'dart:io' show Platform;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../domain/modelos/mesa.dart';
import '../../../domain/modelos/comanda.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../domain/modelos/factura.dart';
import '../../../services/pedidos_service.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../../../services/facturacion_service.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import '../../../services/tpv/impresora_service.dart';
import '../../../services/tpv/impresora_windows_service.dart' show ImpresoraWindowsService;
import '../../../services/tpv/cierre_caja_service.dart';
import '../../pedidos/widgets/variante_selector_widget.dart';
import '../widgets/dialogo_factura_tpv.dart';
import 'package:intl/intl.dart';
import 'tpv_peluqueria_screen.dart' hide Producto, ImpressoraBluetooth, LineaTicket, TicketData, CierreCajaService;
import 'tpv_tienda_screen.dart';
import 'configuracion_facturacion_tpv_screen.dart';
import 'pantalla_cocina_screen.dart';
import 'pantalla_fiados_screen.dart';
import '../widgets/tpv_type_switcher.dart';
import '../widgets/dialogo_devoluciones.dart';
import '../widgets/empleados_banner_widget.dart';
import '../widgets/floor_plan_widget.dart';
import '../widgets/mesa_theme_selector_bottom_sheet.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../../widgets/tpv/historial_tickets_widget.dart';
import '../../../widgets/tpv/estadisticas_turno_widget.dart';
import '../../../widgets/tpv/hold_pedidos_widget.dart';
import '../../../widgets/tpv/arqueo_caja_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/tpv/offline_queue_service.dart';
import '../../../widgets/tpv/cupon_input_widget.dart';
import '../../../widgets/tpv/descuento_linea_widget.dart';
import '../../../services/tpv/terminal_fisica_service.dart';
import '../../../services/verifactu/qr_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TEMA DEL TPV ROOT — paleta claro / oscuro (login palette)
// ═══════════════════════════════════════════════════════════════════════════

class _TpvRootTema {
  final Color fondo;
  final Color superficie;
  final Color borde;
  final Color texto;
  final Color textoMuted;
  final Color primario;
  final bool isDark;

  const _TpvRootTema._({
    required this.fondo,
    required this.superficie,
    required this.borde,
    required this.texto,
    required this.textoMuted,
    required this.primario,
    required this.isDark,
  });

  static const claro = _TpvRootTema._(
    fondo:       Colors.white,
    superficie:  Color(0xFFF5F7FA),
    borde:       Color(0xFFE0E3EC),
    texto:       Color(0xFF0A0F23),
    textoMuted:  Color(0xFF6B7280),
    primario:    Color(0xFF00FFC8),
    isDark:      false,
  );

  // Paleta del login — navy + cian
  static const oscuro = _TpvRootTema._(
    fondo:       Color(0xFF0A0F23),
    superficie:  Color(0xFF1E2139),
    borde:       Color(0xFF2A2E45),
    texto:       Colors.white,
    textoMuted:  Color(0xFFB0B3C1),
    primario:    Color(0xFF00FFC8),
    isDark:      true,
  );
}

class _TpvRootTemaScope extends InheritedWidget {
  final _TpvRootTema tema;
  const _TpvRootTemaScope({required this.tema, required super.child});

  static _TpvRootTema of(BuildContext ctx) =>
      ctx.dependOnInheritedWidgetOfExactType<_TpvRootTemaScope>()?.tema ??
      _TpvRootTema.claro;

  @override
  bool updateShouldNotify(_TpvRootTemaScope old) => tema.fondo != old.tema.fondo;
}

// ═══════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class TpvRootScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final bool esPropietario;

  /// Si se proporciona, la pantalla pre-selecciona esta mesa al abrirse.
  final String? mesaInicialId;

  /// Si se proporciona, aplica los overrides del TPV personalizado al catálogo.
  final String? tpvPersonalizadoId;

  /// Nombre del TPV personalizado (para mostrarlo en el AppBar).
  final String? tpvPersonalizadoNombre;

  final bool embedded;
  final void Function(TpvEmbedActions)? onEmbedReady;

  const TpvRootScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
    this.esPropietario = false,
    this.mesaInicialId,
    this.tpvPersonalizadoId,
    this.tpvPersonalizadoNombre,
    this.embedded = false,
    this.onEmbedReady,
  });

  @override
  State<TpvRootScreen> createState() => _TpvRootScreenState();
}

class _TpvRootScreenState extends State<TpvRootScreen> {
  final _db = FirebaseFirestore.instance;
  final _pedidosService = PedidosService();

  int _railIndex = 0;
  String? _mesaSeleccionadaId;
  Comanda? _comandaActiva;
  String _zonaFiltro = ''; // '' = todas las zonas
  String _categoriaFiltro = 'Todos';
  String _busqueda = '';
  String? _empleadoSeleccionadoId; // ← empleado activo en el turno

  Timer? _relojTimer;
  String _horaActual = '';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _estaOnline = true;
  bool _prevEstaOnline = true;
  int _pendientesOffline = 0;
  bool _btConectado = false;
  bool _oscuro = false; // tema manual: false = claro (blanco por defecto)
  late final ValueNotifier<bool> _oscuroNotifier;

  static const _tpvAppBarColor = Color(0xFF1565C0);

  final _holdNotifier = HoldPedidosNotifier();
  late final ValueNotifier<int> _holdCountNotifier;

  void _toggleTema() {
    setState(() => _oscuro = !_oscuro);
    _oscuroNotifier.value = _oscuro;
  }

  @override
  void initState() {
    super.initState();
    _oscuroNotifier = ValueNotifier(_oscuro);
    _holdCountNotifier = ValueNotifier(0);
    _holdNotifier.addListener(() => _holdCountNotifier.value = _holdNotifier.pedidos.length);
    if (!widget.embedded) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _iniciarReloj();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online && !_prevEstaOnline) _sincronizarOffline();
      _prevEstaOnline = online;
      if (mounted) setState(() => _estaOnline = online);
    });
    Connectivity().checkConnectivity().then((results) {
      if (mounted) setState(() => _estaOnline = !results.contains(ConnectivityResult.none));
    });
    ImpressoraBluetooth().estaConectada().then((conectada) {
      if (mounted) setState(() => _btConectado = conectada);
    });
    // Cargar config del terminal física
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
    });
    
    // Inicializar servicio de impresión Windows
    if (!kIsWeb && Platform.isWindows) {
      ImpresoraWindowsService().inicializar().catchError((e) {
        debugPrint('⚠️ Error al inicializar servicio de impresión Windows: $e');
      });
    }

    // Pre-seleccionar mesa si se viene desde el plano
    if (widget.mesaInicialId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _mesaSeleccionadaId = widget.mesaInicialId);
          _cargarComandaDeMesa(widget.mesaInicialId!);
        }
      });
    }
    // Registrar acciones en el header del dashboard (solo modo embebido)
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onEmbedReady?.call(TpvEmbedActions(
          abrirCajon: _abrirCajon,
          aperturaCaja: () => mostrarDialogoAperturaCaja(context, widget.empresaId),
          cierreCaja: () => mostrarPantallaCierreCaja(context, widget.empresaId),
          verHistorial: () => HistorialTicketsWidget.mostrar(context, widget.empresaId),
          verHold: () async {
            final pedido = await HoldPedidosWidget.mostrar(context, _holdNotifier);
            if (pedido != null && mounted) {
              final lineas = pedido.lineas.map((m) => LineaComanda(
                productoId: m['productoId'] as String? ?? '',
                nombre: m['nombre'] as String? ?? '',
                precioUnitario: (m['precioUnitario'] as num?)?.toDouble() ?? 0,
                cantidad: (m['cantidad'] as num?)?.toInt() ?? 1,
                ivaPorcentaje: (m['ivaPorcentaje'] as num?)?.toDouble() ?? 21,
                notas: m['notas'] as String?,
              )).toList();
              final base = _comandaActiva ?? Comanda(
                id: _db.collection('empresas').doc(widget.empresaId).collection('comandas').doc().id,
                camareroUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                lineas: [], estado: 'abierta', apertura: Timestamp.now(), importeTotal: 0,
              );
              setState(() => _comandaActiva = base.copyWith(lineas: [...base.lineas, ...lineas]));
              _sincronizarComanda();
            }
          },
          holdCount: _holdCountNotifier,
          masOpciones: () => _mostrarMasOpcionesTPV(context),
          toggleTema: _toggleTema,
          temaOscuro: _oscuroNotifier,
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
              leading: const Icon(Icons.history),
              title: const Text('Historial de ventas'),
              onTap: () { Navigator.pop(ctx); _mostrarHistorialVentas(ctx); },
            ),
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
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Personalizar tema'),
              onTap: () { Navigator.pop(ctx); mostrarMesaThemeSelector(ctx); },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Pantalla de cocina'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => PantallaCocinaScreen(empresaId: widget.empresaId)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Fiados pendientes'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => PantallaFiadosScreen(empresaId: widget.empresaId)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.keyboard_return_outlined),
              title: const Text('Devoluciones'),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(context: ctx,
                    builder: (_) => DialogoDevoluciones(
                        empresaId: widget.empresaId,
                        colorPrimario: _tpvAppBarColor));
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Configurar impresora'),
              onTap: () { Navigator.pop(ctx); _mostrarConfigImpresora(); },
            ),
            if (widget.esAdmin)
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

  @override
  void dispose() {
    _relojTimer?.cancel();
    _connectivitySub?.cancel();
    _holdNotifier.dispose();
    _holdCountNotifier.dispose();
    _oscuroNotifier.dispose();
    if (!widget.embedded) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  Future<void> _actualizarContadorOffline() async {
    try {
      final n = await OfflineQueueService().contarPendientes(widget.empresaId);
      if (mounted) setState(() => _pendientesOffline = n);
    } catch (_) {}
  }

  Future<void> _sincronizarOffline() async {
    final n = await OfflineQueueService().contarPendientes(widget.empresaId);
    if (n == 0) return;
    try {
      await OfflineQueueService().sincronizarTodos(widget.empresaId);
      await _actualizarContadorOffline();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$n pedido${n > 1 ? 's' : ''} sincronizado${n > 1 ? 's' : ''} al recuperar conexión'),
            backgroundColor: const Color(0xFF00FFC8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  void _iniciarReloj() {
    _actualizarHora();
    _relojTimer = Timer.periodic(const Duration(seconds: 60), (_) => _actualizarHora());
  }

  void _actualizarHora() {
    setState(() => _horaActual = DateFormat('HH:mm').format(DateTime.now()));
  }

  String get _modoActual {
    if (_railIndex == 0 && _mesaSeleccionadaId != null) return 'Comanda de mesa';
    switch (_railIndex) {
      case 0: return 'Plano de mesas';
      case 1: return 'Caja rápida';
      case 2: return 'Cierre de caja';
      default: return 'TPV';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = _oscuro ? _TpvRootTema.oscuro : _TpvRootTema.claro;
    final bgColor = tema.fondo;

    return _TpvRootTemaScope(
      tema: tema,
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: widget.embedded ? null : AppBar(
        backgroundColor: tema.isDark ? const Color(0xFF0A0F23) : Colors.white,
        foregroundColor: tema.texto,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: tema.borde),
        ),
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 48,
        title: Row(
          children: [
            // ── Izquierda: nav + modo ──────────────────────────────────
            if (!widget.embedded)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Salir del TPV',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            const Icon(Icons.point_of_sale, size: 16),
            const SizedBox(width: 4),
            const Text('TPV', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tema.primario.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tema.primario.withValues(alpha: 0.4)),
              ),
              child: Text(_modoActual, style: TextStyle(fontSize: 10, color: tema.isDark ? Colors.white : tema.texto)),
            ),
            const Spacer(),
            // ── Derecha: acciones críticas siempre visibles ───────────
            // Hold — con badge
            ListenableBuilder(
              listenable: _holdNotifier,
              builder: (_, __) => Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline, size: 18),
                    onPressed: () async {
                      final pedido = await HoldPedidosWidget.mostrar(context, _holdNotifier);
                      if (pedido != null && mounted) {
                        final lineas = pedido.lineas.map((l) => LineaComanda(
                          productoId: l['productoId'] as String? ?? '',
                          nombre: l['nombre'] as String? ?? '',
                          precioUnitario: (l['precioUnitario'] as num?)?.toDouble() ?? 0,
                          cantidad: (l['cantidad'] as num?)?.toInt() ?? 1,
                          ivaPorcentaje: (l['ivaPorcentaje'] as num?)?.toDouble() ?? 21,
                          notas: l['notas'] as String?,
                        )).toList();
                        final comandaBase = _comandaActiva ?? Comanda(
                          id: _db.collection('empresas').doc(widget.empresaId).collection('comandas').doc().id,
                          camareroUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                          lineas: [],
                          estado: 'abierta',
                          apertura: Timestamp.now(),
                          importeTotal: 0,
                        );
                        setState(() {
                          _comandaActiva = comandaBase.copyWith(
                            lineas: [...comandaBase.lineas, ...lineas],
                          );
                        });
                        _sincronizarComanda();
                      }
                    },
                    tooltip: 'Pedidos en espera',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  if (_holdNotifier.pedidos.isNotEmpty)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: const BoxDecoration(
                          color: Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${_holdNotifier.pedidos.length}',
                            style: const TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Cajón registradora
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              onPressed: _abrirCajon,
              tooltip: 'Abrir cajón',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            // Caja
            GestureDetector(
              onTap: () => mostrarDialogoAperturaCaja(context, widget.empresaId),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tema.primario.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tema.primario.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.account_balance_wallet, size: 13, color: tema.primario),
                  const SizedBox(width: 3),
                  Text('Caja', style: TextStyle(fontSize: 11, color: tema.primario, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            // Cierre
            GestureDetector(
              onTap: () => mostrarPantallaCierreCaja(context, widget.empresaId),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tema.superficie,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tema.borde),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.summarize_outlined, size: 13, color: tema.textoMuted),
                  const SizedBox(width: 3),
                  Text('Cierre', style: TextStyle(fontSize: 11, color: tema.textoMuted, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            // Reloj + wifi
            const SizedBox(width: 6),
            Text(_horaActual, style: TextStyle(fontSize: 11, color: tema.textoMuted)),
            const SizedBox(width: 4),
            Icon(
              _estaOnline ? Icons.wifi : Icons.wifi_off,
              size: 14,
              color: _estaOnline ? tema.textoMuted : Colors.orangeAccent,
            ),
            if (_pendientesOffline > 0) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _sincronizarOffline,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_pendientesOffline offline',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                ),
              ),
            ],
            // ── Toggle claro/oscuro ────────────────────────────────────
            _TemaToggleBtn(
              oscuro: _oscuro,
              onToggle: _toggleTema,
              tema: tema,
            ),
            // ── Configuración TPV — acceso directo (admin) ────────────
            if (widget.esAdmin) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'Configuración TPV',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ConfiguracionFacturacionTpvScreen(
                            empresaId: widget.empresaId,
                            esPropietario: widget.esPropietario))),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(Icons.settings_outlined, size: 16, color: tema.textoMuted),
                    ),
                  ),
                ),
              ),
            ],
            // ── Menú desbordamiento para acciones secundarias ─────────
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: tema.textoMuted),
              color: tema.superficie,
              onSelected: (v) {
                switch (v) {
                  case 'historial':
                    _mostrarHistorialVentas(context);
                  case 'tickets':
                    HistorialTicketsWidget.mostrar(context, widget.empresaId);
                  case 'stats':
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF0A0F23),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => EstadisticasTurnoWidget(empresaId: widget.empresaId),
                    );
                  case 'tema':
                    mostrarMesaThemeSelector(context);
                  case 'cocina':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PantallaCocinaScreen(empresaId: widget.empresaId),
                    ));
                  case 'fiados':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PantallaFiadosScreen(empresaId: widget.empresaId),
                    ));
                  case 'devoluciones':
                    showDialog(
                      context: context,
                      builder: (_) => DialogoDevoluciones(
                        empresaId: widget.empresaId,
                        colorPrimario: _tpvAppBarColor,
                      ),
                    );
                  case 'impresora':
                    _mostrarConfigImpresora();
                  case 'config':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ConfiguracionFacturacionTpvScreen(
                        empresaId: widget.empresaId,
                        esPropietario: widget.esPropietario,
                      ),
                    ));
                }
              },
              itemBuilder: (ctx) {
                final t = _TpvRootTemaScope.of(ctx);
                PopupMenuEntry<String> item(String val, IconData ic, String lbl, {Color? iconColor}) =>
                  PopupMenuItem<String>(value: val, child: Row(children: [
                    Icon(ic, size: 16, color: iconColor ?? t.textoMuted), const SizedBox(width: 10),
                    Text(lbl, style: TextStyle(color: t.texto)),
                  ]));
                return [
                  item('historial', Icons.history, 'Historial de ventas'),
                  item('tickets', Icons.receipt_long, 'Tickets del turno'),
                  item('stats', Icons.bar_chart, 'Estadísticas'),
                  item('cocina', Icons.restaurant_menu, 'Pantalla de cocina'),
                  item('fiados', Icons.schedule_rounded, 'Fiados pendientes', iconColor: const Color(0xFFFFCC00)),
                  item('devoluciones', Icons.keyboard_return, 'Devoluciones'),
                  item('tema', Icons.palette_outlined, 'Tema del plano'),
                  item('impresora', Icons.print, 'Impresora'),
                  if (widget.esAdmin)
                    item('config', Icons.settings, 'Configuración TPV'),
                ];
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
        children: [
          // ── Layout principal del TPV ─────────────────────────────────────
          Expanded(
            child: Row(
        children: [
          // COLUMNA IZQUIERDA (25%): TICKET / COMANDA ACTIVA
          Expanded(
            flex: 25,
            child: _ColumnaComandaActiva(
              empresaId: widget.empresaId,
              comandaActiva: _comandaActiva,
              mesaId: _mesaSeleccionadaId,
              estaOnline: _estaOnline,
              onActualizarOffline: _actualizarContadorOffline,
              onAbrirConfig: widget.esAdmin ? () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ConfiguracionFacturacionTpvScreen(
                      empresaId: widget.empresaId,
                      esPropietario: widget.esPropietario))) : null,
              onComandaActualizada: (comanda) {
                setState(() => _comandaActiva = comanda);
                _sincronizarComanda();
              },
              onCobrado: () {
                setState(() {
                  _mesaSeleccionadaId = null;
                  _comandaActiva = null;
                });
              },
              onVolverAMesas: () => setState(() {
                _mesaSeleccionadaId = null;
                _comandaActiva = null;
              }),
              onTransferirComanda: (nuevaMesaId) {
                setState(() => _mesaSeleccionadaId = nuevaMesaId);
                _cargarComandaDeMesa(nuevaMesaId);
              },
              holdNotifier: _holdNotifier,
              onEnEspera: () {
                if (_comandaActiva == null || _comandaActiva!.lineas.isEmpty) return;
                final lineasMap = _comandaActiva!.lineas.map((l) => {
                  'productoId': l.productoId,
                  'nombre': l.nombre,
                  'precioUnitario': l.precioUnitario,
                  'cantidad': l.cantidad,
                  'ivaPorcentaje': l.ivaPorcentaje,
                  if (l.notas != null) 'notas': l.notas,
                }).toList();
                _holdNotifier.guardar(
                  etiqueta: _mesaSeleccionadaId != null
                      ? 'Mesa ${_mesaSeleccionadaId!}'
                      : 'Venta directa',
                  lineas: lineasMap,
                  total: _comandaActiva!.total,
                );
                setState(() {
                  _comandaActiva = null;
                  _mesaSeleccionadaId = null;
                });
              },
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: _TpvRootTemaScope.of(context).borde),
          // COLUMNA CENTRAL (45%): PLANO DE MESAS
          Expanded(
            flex: 45,
            child: _ColumnaListaMesas(
              empresaId: widget.empresaId,
              esAdmin: widget.esAdmin,
              zonaFiltro: _zonaFiltro,
              empleadoFiltroUid: _empleadoSeleccionadoId,
              onZonaChanged: (z) => setState(() => _zonaFiltro = z),
              onMesaSeleccionada: (mesaId) async {
                setState(() => _mesaSeleccionadaId = mesaId);
                await _cargarComandaDeMesa(mesaId);
              },
              mesaSeleccionadaId: _mesaSeleccionadaId,
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: _TpvRootTemaScope.of(context).borde),
          // COLUMNA DERECHA (30%): CATÁLOGO DE PRODUCTOS
          Expanded(
            flex: 30,
            child: _ColumnaCatalogoProductos(
              empresaId: widget.empresaId,
              esAdmin: widget.esAdmin,
              categoriaFiltro: _categoriaFiltro,
              busqueda: _busqueda,
              tpvPersonalizadoId: widget.tpvPersonalizadoId,
              onCategoriaChanged: (c) => setState(() => _categoriaFiltro = c),
              onBusquedaChanged: (b) => setState(() => _busqueda = b),
              onProductoSeleccionado: (producto, variante) {
                _agregarProductoAComanda(context, producto, variante);
              },
            ),
          ),
        ],
      ),          // cierre Row
          ),     // cierre Expanded
        ],
      ),         // cierre Column interna del Stack
        ],
      ),         // cierre Stack (body)
    ),           // cierre Scaffold
    );           // cierre _TpvRootTemaScope
  }

  void _agregarProductoAComanda(BuildContext context, Producto producto, VarianteProducto? variante) {
    if (_comandaActiva == null) {
      final nuevaComanda = Comanda(
        id: FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId).collection('comandas').doc().id,
        mesaId: _mesaSeleccionadaId,
        camareroUid: _empleadoSeleccionadoId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
        lineas: [],
        estado: 'abierta',
        apertura: Timestamp.now(),
        importeTotal: 0,
      );
      setState(() => _comandaActiva = nuevaComanda);
    }

    final precioUnitario = variante?.precioEfectivo(producto.precio) ?? producto.precio;
    final nuevaLinea = LineaComanda(
      productoId: producto.id,
      nombre: variante != null ? '${producto.nombre} (${variante.nombre})' : producto.nombre,
      cantidad: 1,
      precioUnitario: precioUnitario,
      ivaPorcentaje: producto.ivaPorcentaje,
      esNuevo: true,
      destino: producto.destino,
    );

    final lineasActualizadas = List<LineaComanda>.from(_comandaActiva?.lineas ?? []);
    final indiceExistente = lineasActualizadas.indexWhere(
            (l) => l.productoId == nuevaLinea.productoId && l.nombre == nuevaLinea.nombre);

    if (indiceExistente >= 0) {
      lineasActualizadas[indiceExistente] = lineasActualizadas[indiceExistente]
          .copyWith(cantidad: lineasActualizadas[indiceExistente].cantidad + 1);
    } else {
      lineasActualizadas.add(nuevaLinea);
    }

    final comandaActualizada = _comandaActiva!.copyWith(lineas: lineasActualizadas);
    setState(() => _comandaActiva = comandaActualizada);
    _sincronizarComanda();
  }

  Future<void> _cargarComandaDeMesa(String mesaId) async {
    final mesaDoc = await _db
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas')
        .doc(mesaId)
        .get();

    if (!mesaDoc.exists) return;
    final mesa = Mesa.fromFirestore(mesaDoc, empresaId: widget.empresaId);

    if (mesa.comandaId != null) {
      final comandaDoc = await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('comandas')
          .doc(mesa.comandaId)
          .get();
      if (comandaDoc.exists) {
        setState(() => _comandaActiva = Comanda.fromFirestore(comandaDoc));
        return;
      }
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final nuevaComanda = Comanda(
      id: _db.collection('empresas').doc(widget.empresaId).collection('comandas').doc().id,
      mesaId: mesaId,
      camareroUid: uid,
      lineas: [],
      estado: 'abierta',
      apertura: Timestamp.now(),
      importeTotal: 0,
    );

    await _db
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('comandas')
        .doc(nuevaComanda.id)
        .set(nuevaComanda.toFirestore());

    await _db
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas')
        .doc(mesaId)
        .update({
      'estado': 'ocupada',
      'comanda_id': nuevaComanda.id,
      'camarero_uid': uid,
      'fecha_apertura': Timestamp.now(),
    });

    setState(() => _comandaActiva = nuevaComanda);
  }

  Future<void> _sincronizarComanda() async {
    if (_comandaActiva == null || _comandaActiva!.id.isEmpty) return;

    final ref = _db
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('comandas')
        .doc(_comandaActiva!.id);

    await ref.set({
      'mesa_id': _mesaSeleccionadaId,
      'camarero_uid': _empleadoSeleccionadoId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
      'lineas': _comandaActiva!.lineas.map((l) => {
        'producto_id': l.productoId,
        'nombre': l.nombre,
        'cantidad': l.cantidad,
        'precio_unitario': l.precioUnitario,
        'iva_porcentaje': l.ivaPorcentaje,
        'notas': l.notas,
        'es_nuevo': l.esNuevo,
        'subtotal': l.total,
      }).toList(),
      'estado': 'abierta',
      'apertura': _comandaActiva!.apertura ?? FieldValue.serverTimestamp(),
      'importe_total': _comandaActiva!.total,
      'descuento': _comandaActiva!.descuento,
      'descuento_pct': _comandaActiva!.descuentoPct,
      'nota_general': _comandaActiva!.notaGeneral,
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (_mesaSeleccionadaId != null) {
      await _db
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('mesas')
          .doc(_mesaSeleccionadaId)
          .update({
        'estado': 'ocupada',
        'comanda_id': _comandaActiva!.id,
        'camarero_uid': _empleadoSeleccionadoId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
        'fecha_apertura': FieldValue.serverTimestamp(),
        if (_empleadoSeleccionadoId != null)
          'asignado_a_uid': _empleadoSeleccionadoId,
      });
    }
  }

  // ── Abrir cajón registradora ──────────────────────────────────────────────
  Future<void> _abrirCajon() async {
    try {
      final cfg = await TpvFacturacionService().obtenerConfig(widget.empresaId);
      await ImpresoraService().abrirCajonSiProcede(
        config: cfg.copyWith(abrirCajonAlCobrar: true, abrirCajonSoloEfectivo: false),
        metodoPago: 'efectivo',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cajón abierto'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir cajón: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Configuración impresora Bluetooth ─────────────────────────────────────
  void _mostrarHistorialVentas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2139),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.history, color: Color(0xFF00FFC8), size: 18),
                  SizedBox(width: 8),
                  Text('Historial de ventas',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A2E45), height: 1),
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
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFC8)));
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No hay ventas registradas',
                          style: TextStyle(color: Colors.white38)),
                    );
                  }
                  final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
                  final dateFmt = DateFormat('dd/MM HH:mm');
                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xFF2A2E45), height: 1),
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final total = (d['total'] as num?)?.toDouble() ?? 0.0;
                      final metodo = d['metodo_pago'] as String? ?? '—';
                      final mesa = d['mesa_id'] as String? ?? 'Caja rápida';
                      final fecha = (d['fecha_creacion'] as Timestamp?)?.toDate();
                      final nLineas = (d['lineas'] as List?)?.length ?? 0;
                      final lineas = (d['lineas'] as List<dynamic>?) ?? [];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        onTap: () => _mostrarDetalleVenta(ctx, d, docs[i].id, fmt),
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FFC8).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, color: Color(0xFF00FFC8), size: 18),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                fmt.format(total),
                                style: const TextStyle(
                                    color: Color(0xFFFFA000), fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2E45),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(metodo,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${fecha != null ? dateFmt.format(fecha) : '—'}  ·  Mesa: $mesa  ·  $nLineas artículos',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalleVenta(
      BuildContext context,
      Map<String, dynamic> d,
      String pedidoId,
      NumberFormat fmt) {
    final lineas     = (d['lineas'] as List<dynamic>?) ?? [];
    final total      = (d['total'] as num?)?.toDouble() ?? 0.0;
    final metodo     = d['metodo_pago'] as String? ?? '—';
    final mesa       = d['mesa_id']    as String? ?? 'Caja rápida';
    final fecha      = (d['fecha_creacion'] as Timestamp?)?.toDate();
    final yaFacturado = d['factura_id'] != null;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2139),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.35,
        builder: (_, sc) => Column(
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            // Cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmt.format(total),
                            style: const TextStyle(
                                color: Color(0xFFFFA000), fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          '${fecha != null ? dateFmt.format(fecha) : '—'}  ·  $metodo  ·  Mesa: $mesa',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A2E45), height: 1),
            // Lista de líneas
            Expanded(
              child: lineas.isEmpty
                  ? const Center(
                      child: Text('Sin detalle de artículos',
                          style: TextStyle(color: Colors.white38)))
                  : ListView.separated(
                      controller: sc,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: lineas.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Color(0xFF2A2E45), height: 1),
                      itemBuilder: (_, i) {
                        final l = Map<String, dynamic>.from(
                            lineas[i] is Map ? lineas[i] as Map : {});
                        // El campo se guarda como 'producto_nombre' en pedidos TPV
                        final nombre   = (l['producto_nombre'] ?? l['nombre'] ?? '—') as String;
                        final cantidad = (l['cantidad'] as num?)?.toInt() ?? 1;
                        final precio   = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
                        final subtotal = (l['subtotal'] as num?)?.toDouble() ?? precio * cantidad;
                        final nota     = (l['notas_linea'] ?? l['notas'] ?? '') as String;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2E45),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text('×$cantidad',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nombre,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                    if (nota.isNotEmpty)
                                      Text(nota,
                                          style: const TextStyle(
                                              color: Colors.amber, fontSize: 10, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(fmt.format(subtotal),
                                      style: const TextStyle(
                                          color: Color(0xFFFFA000),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800)),
                                  if (cantidad > 1)
                                    Text('${fmt.format(precio)} u.',
                                        style: const TextStyle(
                                            color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Total + botón factura
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF2A2E45))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(fmt.format(total),
                          style: const TextStyle(
                              color: Color(0xFFFFA000), fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: Icon(yaFacturado ? Icons.receipt_long : Icons.receipt_long_outlined, size: 16),
                      label: Text(yaFacturado ? 'Ver factura existente' : 'Generar factura'),
                      style: FilledButton.styleFrom(
                        backgroundColor: yaFacturado
                            ? const Color(0xFF2A2E45)
                            : const Color(0xFF1565C0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () async {
                        Navigator.pop(context); // cierra el detalle
                        // Reconstruir un Pedido mínimo desde los datos del historial
                        final lineasPedido = lineas.map((raw) {
                          final l = Map<String, dynamic>.from(raw is Map ? raw : {});
                          return LineaPedido(
                            productoId: l['producto_id'] as String? ?? '',
                            productoNombre: (l['producto_nombre'] ?? l['nombre'] ?? '').toString(),
                            cantidad: (l['cantidad'] as num?)?.toInt() ?? 1,
                            precioUnitario: (l['precio_unitario'] as num?)?.toDouble() ?? 0.0,
                            ivaPorcentaje: (l['iva_porcentaje'] as num?)?.toDouble() ?? 10.0,
                          );
                        }).toList();
                        final pedido = Pedido(
                          id: pedidoId,
                          empresaId: widget.empresaId,
                          clienteNombre: mesa,
                          lineas: lineasPedido,
                          metodoPago: metodo == 'tarjeta' ? MetodoPago.tarjeta
                              : metodo == 'mixto' ? MetodoPago.mixto
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
// COLUMNA IZQUIERDA: LISTA DE MESAS (25%)
// ═══════════════════════════════════════════════════════════════════════════

class _ColumnaListaMesas extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final String zonaFiltro;
  final String? empleadoFiltroUid;
  final ValueChanged<String> onZonaChanged;
  final ValueChanged<String> onMesaSeleccionada;
  final String? mesaSeleccionadaId;

  const _ColumnaListaMesas({
    required this.empresaId,
    required this.esAdmin,
    required this.zonaFiltro,
    this.empleadoFiltroUid,
    required this.onZonaChanged,
    required this.onMesaSeleccionada,
    this.mesaSeleccionadaId,
  });

  @override
  State<_ColumnaListaMesas> createState() => _ColumnaListaMesasState();
}

class _ColumnaListaMesasState extends State<_ColumnaListaMesas> {
  bool _modoEdicionPlano = false;

  Future<void> _crearZona(BuildContext ctx) async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Nueva zona'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Ej: Terraza, Salón, VIP…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    // Guardar en configuracion/tpv_zonas (tiene permisos de admin)
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('configuracion')
        .doc('tpv_zonas')
        .set({'zonas': FieldValue.arrayUnion([nombre])}, SetOptions(merge: true));
    if (mounted) widget.onZonaChanged(nombre);
  }

  /// Cache de mesas del último StreamBuilder para usarla al crear nuevas
  List<Mesa> _latestMesas = [];

  // ── Crear mesa nueva con forma específica ─────────────────────────────────
  Future<void> _crearMesaConForma(String forma) async {
    final rng = Random();
    final posX = 0.05 + rng.nextDouble() * 0.55;
    final posY = 0.05 + rng.nextDouble() * 0.45;
    final numero = _latestMesas.length + 1;
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas')
        .add({
      'nombre': forma == 'bar' ? 'Barra' : 'Mesa $numero',
      'zona': widget.zonaFiltro.isEmpty ? 'Salón' : widget.zonaFiltro,
      'capacidad': forma == 'bar' ? 8 : (forma == 'circle' ? 2 : 4),
      'estado': 'libre',
      'numero': numero,
      'pos_x': posX,
      'pos_y': posY,
      'mesa_ancho': forma == 'bar' ? 0.32 : (forma == 'circle' ? 0.15 : 0.18),
      'mesa_alto': forma == 'bar' ? 0.08 : 0.14,
      'forma': forma,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = _TpvRootTemaScope.of(context);
    return Stack(
      children: [
        Container(
          color: tema.fondo,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas')
                .doc(widget.empresaId)
                .collection('configuracion')
                .doc('tpv_zonas')
                .snapshots(),
            builder: (context, snapZonas) {
              // Zonas guardadas en configuracion/tpv_zonas
              final data = snapZonas.data?.data() as Map<String, dynamic>?;
              final zonasGuardadas = (data?['zonas'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .where((n) => n.isNotEmpty)
                  .toList();

              return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas')
                .doc(widget.empresaId)
                .collection('mesas')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final mesas = snap.data!.docs
                  .map((d) => Mesa.fromFirestore(d, empresaId: widget.empresaId))
                  .toList();

              // Actualizar cache para uso en _crearMesaConForma
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _latestMesas = mesas;
              });

              // Merge: zonas guardadas + zonas derivadas de mesas (sin "Todas")
              final Set<String> _zonasRaw = {...zonasGuardadas};
              _zonasRaw.addAll(mesas.map((m) => m.zona).where((z) => z.isNotEmpty));

              // Ordenar: "Salón" y variantes siempre primero, resto alfabético
              final zonas = _zonasRaw.toList()
                ..sort((a, b) {
                  final aSalon = a.toLowerCase().replaceAll('ó', 'o').contains('salon');
                  final bSalon = b.toLowerCase().replaceAll('ó', 'o').contains('salon');
                  if (aSalon && !bSalon) return -1;
                  if (!aSalon && bSalon) return 1;
                  return a.toLowerCase().compareTo(b.toLowerCase());
                });

              // Auto-seleccionar la primera zona (Salón) si no hay ninguna activa
              if (widget.zonaFiltro.isEmpty && zonas.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) widget.onZonaChanged(zonas.first);
                });
              }

              final mesasPorEmpleado = widget.empleadoFiltroUid == null
                  ? mesas
                  : mesas.where((m) {
                      final asig = (m.asignadoAUid ?? '').trim();
                      final cam  = (m.camareroUid   ?? '').trim();
                      final uid  = widget.empleadoFiltroUid!.trim();
                      // Muestra la mesa si está permanentemente asignada a este camarero,
                      // si él la está atendiendo ahora, o si no tiene asignación permanente.
                      return asig.isEmpty || asig == uid || cam == uid;
                    }).toList();

              final mesasFiltradas = widget.zonaFiltro.isEmpty
                  ? mesasPorEmpleado
                  : mesasPorEmpleado.where((m) => m.zona == widget.zonaFiltro).toList();
              final libres     = mesasPorEmpleado.where((m) => m.esLibre).length;
              final ocupadas   = mesasPorEmpleado.where((m) => m.esOcupada).length;
              final reservadas = mesasPorEmpleado.where((m) => m.esReservada).length;
              final bloqueadas = mesasPorEmpleado.where((m) => !m.esLibre && !m.esOcupada && !m.esReservada).length;
              final zonaLabel  = widget.zonaFiltro.isEmpty ? 'TODAS LAS SALAS' : widget.zonaFiltro.toUpperCase();
              final hasMesa    = widget.mesaSeleccionadaId != null;

              final tema = _TpvRootTemaScope.of(context);
              return ClipRect(
                child: Column(
                children: [
                  // ── Cabecera — Resumen + Acciones rápidas ─────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: tema.superficie,
                      border: Border(bottom: BorderSide(color: tema.borde)),
                    ),
                    child: Column(children: [
                      // Fila 1: stats | acciones rápidas
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // ── Stats ───────────────────────────────────────────
                          Expanded(
                            flex: 6,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('RESUMEN $zonaLabel',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                      color: tema.textoMuted, letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Row(children: [
                                _StatTile(count: libres,     label: 'Libres',     color: const Color(0xFF22C55E)),
                                const SizedBox(width: 8),
                                _StatTile(count: ocupadas,   label: 'Ocupadas',   color: const Color(0xFFEF4444)),
                                const SizedBox(width: 8),
                                _StatTile(count: reservadas, label: 'Reservadas', color: const Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                _StatTile(count: bloqueadas, label: 'Bloqueadas', color: const Color(0xFF94A3B8)),
                              ]),
                            ]),
                          ),
                          Container(width: 1, height: 44, color: tema.borde, margin: const EdgeInsets.symmetric(horizontal: 12)),
                          // ── Acciones rápidas ────────────────────────────────
                          Expanded(
                            flex: 5,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('ACCIONES RÁPIDAS',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                      color: tema.textoMuted, letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Row(children: [
                                _AccionRapida(
                                  icon: Icons.merge_type,
                                  label: 'Unir mesas',
                                  enabled: hasMesa,
                                  onTap: hasMesa ? () => _mostrarMenuContextualMesa(context, mesasFiltradas.firstWhere((m) => m.id == widget.mesaSeleccionadaId, orElse: () => mesasFiltradas.first), widget.empresaId) : null,
                                ),
                                const SizedBox(width: 10),
                                _AccionRapida(
                                  icon: Icons.call_split,
                                  label: 'Dividir',
                                  enabled: hasMesa,
                                  onTap: hasMesa ? () {} : null,
                                ),
                                const SizedBox(width: 10),
                                _AccionRapida(
                                  icon: Icons.discount_outlined,
                                  label: 'Descuento',
                                  enabled: hasMesa,
                                  onTap: hasMesa ? () {} : null,
                                ),
                                const SizedBox(width: 10),
                                _AccionRapida(
                                  icon: Icons.swap_horiz,
                                  label: 'Trasladar',
                                  enabled: hasMesa,
                                  onTap: hasMesa ? () {} : null,
                                ),
                              ]),
                            ]),
                          ),
                        ]),
                      ),
                      // Fila 2: zonas + controles
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: tema.borde))),
                        child: Row(children: [
                          // Chips de zonas
                          Expanded(
                            child: SizedBox(
                              height: 26,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: zonas.map((zona) => _ZonaChip(
                                  zona: zona,
                                  seleccionada: widget.zonaFiltro == zona,
                                  onTap: () => widget.onZonaChanged(zona),
                                )).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botón + crear zona
                          Tooltip(
                            message: 'Nueva zona',
                            child: InkWell(
                              onTap: () => _crearZona(context),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: tema.superficie,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: tema.primario.withValues(alpha: 0.5)),
                                ),
                                child: Icon(Icons.add, size: 13, color: tema.primario),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Editar plano
                          if (widget.esAdmin)
                            _EditPlanoBtn(
                              activo: _modoEdicionPlano,
                              onToggle: () => setState(() => _modoEdicionPlano = !_modoEdicionPlano),
                            ),
                          const SizedBox(width: 4),
                          // Botones añadir mesa (solo en modo edición)
                          if (widget.esAdmin && _modoEdicionPlano) ...[
                            _BtnAddMesa(tooltip: 'Rect', icono: Icons.crop_square, color: const Color(0xFF00FFC8), onTap: () => _crearMesaConForma('rect')),
                            const SizedBox(width: 3),
                            _BtnAddMesa(tooltip: 'Redonda', icono: Icons.circle_outlined, color: const Color(0xFF00FFC8), onTap: () => _crearMesaConForma('circle')),
                            const SizedBox(width: 3),
                            _BtnAddMesa(tooltip: 'Barra', icono: Icons.horizontal_rule, color: const Color(0xFFEF9F27), onTap: () => _crearMesaConForma('bar')),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                  // ── Plano de mesas ────────────────────────────────────
                  Expanded(
                    child: FloorPlanWidget(
                      mesas: mesasFiltradas,
                      empresaId: widget.empresaId,
                      mesaSeleccionadaId: widget.mesaSeleccionadaId,
                      modoEdicion: _modoEdicionPlano,
                      onMesaTap: widget.onMesaSeleccionada,
                      onMesaMoved: _modoEdicionPlano
                          ? (mesaId, newX, newY) async {
                              await FirebaseFirestore.instance
                                  .collection('empresas')
                                  .doc(widget.empresaId)
                                  .collection('mesas')
                                  .doc(mesaId)
                                  .update({'pos_x': newX, 'pos_y': newY});
                            }
                          : null,
                    ),
                  ),
                  // ── Leyenda de estados ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: tema.superficie,
                      border: Border(top: BorderSide(color: tema.borde)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _LeyendaItem(color: const Color(0xFF4CAF50), label: 'Libre', muted: tema.textoMuted),
                        _LeyendaItem(color: Colors.redAccent, label: 'Ocupada', muted: tema.textoMuted),
                        _LeyendaItem(color: Colors.orange, label: 'Reservada', muted: tema.textoMuted),
                        _LeyendaItem(color: Colors.grey, label: 'Bloqueada', muted: tema.textoMuted),
                      ],
                    ),
                  ),
                ],
              ), // Column
              ); // ClipRect
            },
          ); // cierre StreamBuilder mesas
            }, // cierre builder zonas
          ), // cierre StreamBuilder zonas
        ),
        // Botón flotante crear mesa
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFF00FFC8),
            foregroundColor: const Color(0xFF0A0F23),
            onPressed: () => mostrarDialogoCrearMesa(context, widget.empresaId,
                empleadoFiltroUid: widget.empleadoFiltroUid,
                zonaInicial: widget.zonaFiltro.isEmpty ? null : widget.zonaFiltro),
            tooltip: 'Nueva mesa',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// ── Chip de zona ──────────────────────────────────────────────────────────────
class _ZonaChip extends StatelessWidget {
  final String zona;
  final bool seleccionada;
  final VoidCallback onTap;

  const _ZonaChip({required this.zona, required this.seleccionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = _TpvRootTemaScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: seleccionada ? const Color(0xFFFFA000) : tema.superficie,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: seleccionada ? const Color(0xFFFFA000) : tema.borde,
            ),
          ),
          child: Text(
            zona,
            style: TextStyle(
              color: seleccionada ? Colors.black : tema.textoMuted,
              fontSize: 11,
              fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botón activar/desactivar edición del plano ───────────────────────────────
class _EditPlanoBtn extends StatelessWidget {
  final bool activo;
  final VoidCallback onToggle;

  const _EditPlanoBtn({required this.activo, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final tema = _TpvRootTemaScope.of(context);
    return Tooltip(
      message: activo ? 'Bloquear posiciones' : 'Mover mesas',
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: activo
                ? Colors.orange.withValues(alpha: 0.2)
                : tema.superficie,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: activo
                  ? Colors.orange.withValues(alpha: 0.5)
                  : tema.borde,
            ),
          ),
          child: Icon(
            activo ? Icons.lock_open : Icons.edit_location_alt,
            size: 14,
            color: activo ? Colors.orange : tema.textoMuted,
          ),
        ),
      ),
    );
  }
}

// ── Botón de añadir mesa (rect / circle / bar) ───────────────────────────────
class _BtnAddMesa extends StatelessWidget {
  final String tooltip;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  const _BtnAddMesa({
    required this.tooltip,
    required this.icono,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(icono, size: 14, color: color),
        ),
      ),
    );
  }
}

void _mostrarMenuContextualMesa(BuildContext context, Mesa mesa, String empresaId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E2139),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            mesa.nombre.isNotEmpty ? mesa.nombre : 'Mesa ${mesa.numero}',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(color: Color(0xFF2A2E45), height: 1),
        ListTile(
          leading: const Icon(Icons.people, color: Color(0xFFFF3296)),
          title: const Text('Establecer comensales',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(ctx);
            mostrarDialogoComensales(context, empresaId, mesa.id, 0);
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit, color: Color(0xFF00FFC8)),
          title: const Text('Editar mesa', style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(ctx);
            mostrarDialogoEditarMesa(
              context,
              empresaId,
              {
                'nombre': 'Mesa ${mesa.numero}',
                'zona': mesa.zona,
                'capacidad': 4,
                'estado': mesa.estado,
              },
              mesa.id,
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: const Text('Eliminar mesa', style: TextStyle(color: Colors.redAccent)),
          onTap: () {
            Navigator.pop(ctx);
            _confirmarEliminarMesa(context, empresaId, mesa);
          },
        ),
        const Divider(color: Color(0xFF2A2E45)),
        ListTile(
          leading: const Icon(Icons.close, color: Color(0xFFB0B3C1)),
          title: const Text('Cancelar', style: TextStyle(color: Color(0xFFB0B3C1))),
          onTap: () => Navigator.pop(ctx),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

// ── NUEVO: eliminar mesa con confirmación ────────────────────────────────
Future<void> _confirmarEliminarMesa(
    BuildContext context, String empresaId, Mesa mesa) async {
  if (mesa.esOcupada) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('No se puede eliminar una mesa ocupada'),
          backgroundColor: Colors.orange),
    );
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Eliminar mesa'),
      content: Text('¿Seguro que quieres eliminar ${mesa.nombre.isNotEmpty ? mesa.nombre : "Mesa ${mesa.numero}"}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('mesas')
      .doc(mesa.id)
      .delete();
  if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${mesa.nombre.isNotEmpty ? mesa.nombre : "Mesa ${mesa.numero}"} eliminada')),
      );
  }
}

// ── NUEVO: diálogo de comensales ─────────────────────────────────────────
Future<void> mostrarDialogoComensales(
    BuildContext context, String empresaId, String mesaId, int actual) async {
  int comensales = actual;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setS) => AlertDialog(
        title: const Text('Número de comensales'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 32),
              onPressed: comensales > 1 ? () => setS(() => comensales--) : null,
            ),
            const SizedBox(width: 16),
            Text('$comensales',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 32),
              onPressed: comensales < 20 ? () => setS(() => comensales++) : null,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .collection('mesas')
                  .doc(mesaId)
                  .update({'comensales': comensales});
              if (ctx2.mounted) Navigator.pop(ctx2);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

// ── NUEVO: diálogo editar mesa ───────────────────────────────────────────
Future<void> mostrarDialogoEditarMesa(BuildContext context, String empresaId,
    Map<String, dynamic> datos, String mesaId) async {
  final nombreCtrl = TextEditingController(text: datos['nombre'] as String? ?? '');
  final zonaCtrl = TextEditingController(text: datos['zona'] as String? ?? '');
  int capacidad = (datos['capacidad'] as int?) ?? 4;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setS) => AlertDialog(
        title: const Text('Editar mesa'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: zonaCtrl,
                decoration: const InputDecoration(labelText: 'Zona'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Capacidad:'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: capacidad > 1 ? () => setS(() => capacidad--) : null,
                  ),
                  Text('$capacidad',
                      style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: capacidad < 20 ? () => setS(() => capacidad++) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .collection('mesas')
                  .doc(mesaId)
                  .update({
                'nombre': nombreCtrl.text.trim(),
                'zona': zonaCtrl.text.trim(),
                'capacidad': capacidad,
              });
              if (ctx2.mounted) Navigator.pop(ctx2);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

// ── NUEVO: diálogo crear mesa ─────────────────────────────────────────────
Future<void> mostrarDialogoCrearMesa(
    BuildContext context, String empresaId,
    {String? empleadoFiltroUid, String? zonaInicial}) async {
  // Cargar zonas desde mesas Y desde zonas_tpv
  final results = await Future.wait([
    FirebaseFirestore.instance
        .collection('empresas').doc(empresaId)
        .collection('mesas').get(),
    FirebaseFirestore.instance
        .collection('empresas').doc(empresaId)
        .collection('configuracion').doc('tpv_zonas').get(),
  ]);
  final Set<String> setZonas = {};
  for (final doc in (results[0] as QuerySnapshot).docs) {
    final z = ((doc.data() as Map<String, dynamic>?)??{})['zona'] as String? ?? '';
    if (z.isNotEmpty) setZonas.add(z);
  }
  final cfgDoc = results[1] as DocumentSnapshot;
  final cfgData = cfgDoc.data() as Map<String, dynamic>?;
  for (final z in (cfgData?['zonas'] as List<dynamic>? ?? [])) {
    final s = z.toString();
    if (s.isNotEmpty) setZonas.add(s);
  }
  final zonasExistentes = setZonas.toList();

  // Obtener nombre del empleado si hay filtro
  String? empleadoNombre;
  if (empleadoFiltroUid != null) {
    try {
      final empDoc = await FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('empleados').doc(empleadoFiltroUid).get();
      if (empDoc.exists) {
        empleadoNombre = empDoc.data()?['nombre'] as String?;
      }
    } catch (_) {}
    if (empleadoNombre == null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('usuarios').doc(empleadoFiltroUid).get();
        if (userDoc.exists) {
          empleadoNombre = userDoc.data()?['nombre'] as String?;
        }
      } catch (_) {}
    }
  }

  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (_) => _DialogoNuevaMesa(
      empresaId: empresaId,
      zonasExistentes: zonasExistentes,
      empleadoUid: empleadoFiltroUid,
      empleadoNombre: empleadoNombre,
      zonaInicial: zonaInicial,
    ),
  );
}

// ── NUEVO: apertura de caja ──────────────────────────────────────────────
Future<void> mostrarDialogoAperturaCaja(
    BuildContext context, String empresaId) async {
  // P3: Bloquear doble apertura en el mismo día
  final hoy = DateTime.now();
  final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
  final finHoy = inicioHoy.add(const Duration(days: 1));
  final aperturasHoy = await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('aperturas_caja')
      .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
      .where('fecha', isLessThan: Timestamp.fromDate(finHoy))
      .limit(1)
      .get();

  if (aperturasHoy.docs.isNotEmpty && context.mounted) {
    final fondoExistente = (aperturasHoy.docs.first.data()['fondo_inicial'] as num?)
        ?.toStringAsFixed(2) ?? '—';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ Caja ya abierta hoy con fondo de $fondoExistente €'),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
    return;
  }

  final ctrl = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Text('Apertura de caja'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Introduce el efectivo inicial en caja para este turno.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
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
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            final fondo =
                double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
            await FirebaseFirestore.instance
                .collection('empresas')
                .doc(empresaId)
                .collection('aperturas_caja')
                .add({
              'fondo_inicial': fondo,
              'fecha': FieldValue.serverTimestamp(),
              'camarero_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
            });
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                      'Caja abierta con fondo de ${fondo.toStringAsFixed(2)} €'),
                  backgroundColor: Colors.green.shade700,
                ),
              );
            }
          },
          child: const Text('Abrir caja'),
        ),
      ],
    ),
  );
}

// ── Cierre de caja — usa el diseño unificado del TPV peluquería ───────────
Future<void> mostrarPantallaCierreCaja(
    BuildContext context, String empresaId) =>
    mostrarCierreTPV(context, empresaId);

class _ResumenCounter extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _ResumenCounter(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count',
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COLUMNA CENTRAL: COMANDA ACTIVA (45%)
// ═══════════════════════════════════════════════════════════════════════════

class _ColumnaComandaActiva extends StatelessWidget {
  final String empresaId;
  final Comanda? comandaActiva;
  final String? mesaId;
  final ValueChanged<Comanda> onComandaActualizada;
  final VoidCallback onCobrado;
  final VoidCallback onVolverAMesas;
  final ValueChanged<String>? onTransferirComanda;
  final HoldPedidosNotifier? holdNotifier;
  final VoidCallback? onEnEspera;
  final bool estaOnline;
  final VoidCallback? onActualizarOffline;
  final VoidCallback? onAbrirConfig;

  const _ColumnaComandaActiva({
    required this.empresaId,
    this.comandaActiva,
    this.mesaId,
    required this.onComandaActualizada,
    required this.onCobrado,
    required this.onVolverAMesas,
    this.onTransferirComanda,
    this.holdNotifier,
    this.onEnEspera,
    this.estaOnline = true,
    this.onActualizarOffline,
    this.onAbrirConfig,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final tema = _TpvRootTemaScope.of(context);

    return Container(
      color: tema.superficie,
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: tema.fondo,
              border: Border(bottom: BorderSide(color: tema.borde)),
            ),
            child: mesaId != null
                ? StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .collection('mesas')
                  .doc(mesaId)
                  .snapshots(),
              builder: (ctx, snap) {
                String nombre = 'Mesa';
                int? numero;
                if (snap.hasData && snap.data!.exists) {
                  final d = snap.data!.data() as Map<String, dynamic>;
                  nombre = d['nombre'] as String? ?? 'Mesa ${d['numero']}';
                  numero = d['numero'] as int?;
                }
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  // ── Fila 1: Comanda # + menú ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: tema.primario.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.receipt_long, size: 14, color: tema.primario),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          numero != null ? 'Comanda #$numero' : nombre,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tema.texto),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 18, color: tema.textoMuted),
                        color: tema.superficie,
                        itemBuilder: (ctx2) {
                          final t = _TpvRootTemaScope.of(ctx2);
                          return [
                            PopupMenuItem(value: 'cocina', child: Row(children: [
                              Icon(Icons.send, size: 14, color: t.textoMuted), const SizedBox(width: 8),
                              Text('Enviar a cocina', style: TextStyle(color: t.texto, fontSize: 13)),
                            ])),
                            PopupMenuItem(value: 'nota', child: Row(children: [
                              Icon(Icons.note_add, size: 14, color: t.textoMuted), const SizedBox(width: 8),
                              Text('Añadir nota', style: TextStyle(color: t.texto, fontSize: 13)),
                            ])),
                            PopupMenuItem(value: 'libre', child: Row(children: [
                              Icon(Icons.add_circle_outline, size: 14, color: t.textoMuted), const SizedBox(width: 8),
                              Text('Producto libre', style: TextStyle(color: t.texto, fontSize: 13)),
                            ])),
                            PopupMenuItem(value: 'descuento', child: Row(children: [
                              Icon(Icons.discount_outlined, size: 14, color: t.textoMuted), const SizedBox(width: 8),
                              Text('Aplicar descuento', style: TextStyle(color: t.texto, fontSize: 13)),
                            ])),
                            PopupMenuItem(value: 'espera', child: Row(children: [
                              Icon(Icons.pause_circle_outline, size: 14, color: t.textoMuted), const SizedBox(width: 8),
                              Text('Poner en espera', style: TextStyle(color: t.texto, fontSize: 13)),
                            ])),
                            PopupMenuItem(value: 'dividir', child: Row(children: [
                              Icon(Icons.call_split, size: 14, color: t.textoMuted), const SizedBox(width: 8),
                              Text('Dividir comanda', style: TextStyle(color: t.texto, fontSize: 13)),
                            ])),
                            PopupMenuItem(value: 'transferir', child: Row(children: [
                              Icon(Icons.swap_horiz, size: 14, color: t.textoMuted), const SizedBox(width: 8),
                              Text('Trasladar mesa', style: TextStyle(color: t.texto, fontSize: 13)),
                            ])),
                          ];
                        },
                        onSelected: (v) {
                          switch (v) {
                            case 'cocina':    _enviarACocina(context);
                            case 'nota':      _agregarNotaGeneral(context);
                            case 'libre':     _agregarProductoLibre(context);
                            case 'descuento': if (comandaActiva != null && comandaActiva!.lineas.isNotEmpty) _aplicarDescuento(context);
                            case 'espera':    if (comandaActiva != null && comandaActiva!.lineas.isNotEmpty) onEnEspera?.call();
                            case 'dividir':   if (comandaActiva != null && comandaActiva!.lineas.length > 1) _mostrarDividirComanda(context, empresaId, mesaId!, comandaActiva!, onComandaActualizada);
                            case 'transferir': _transferirComanda(context);
                          }
                        },
                      ),
                    ]),
                  ),
                  // ── Fila 2: cliente + personas ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    child: Row(children: [
                      Icon(Icons.person_outline, size: 14, color: tema.textoMuted),
                      const SizedBox(width: 6),
                      Text('Cliente', style: TextStyle(fontSize: 11, color: tema.textoMuted)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Walk-in',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tema.texto),
                          overflow: TextOverflow.ellipsis)),
                      Icon(Icons.people_outline, size: 13, color: tema.textoMuted),
                      const SizedBox(width: 4),
                      Text('Personas', style: TextStyle(fontSize: 10, color: tema.textoMuted)),
                    ]),
                  ),
                  // ── Fila 3: camarero ──────────────────────────────────
                  if (comandaActiva?.camareroUid.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('empresas').doc(empresaId)
                            .collection('empleados').doc(comandaActiva!.camareroUid).snapshots(),
                        builder: (_, empSnap) {
                          String empNombre = '';
                          if (empSnap.hasData && empSnap.data!.exists) {
                            empNombre = (empSnap.data!.data() as Map<String, dynamic>)['nombre'] as String? ?? '';
                          }
                          if (empNombre.isEmpty) return const SizedBox.shrink();
                          final inicial = empNombre.isNotEmpty ? empNombre[0].toUpperCase() : '?';
                          return Row(children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text(inicial,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                            ),
                            const SizedBox(width: 6),
                            Text('Camarero', style: TextStyle(fontSize: 11, color: tema.textoMuted)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(empNombre,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tema.texto),
                                overflow: TextOverflow.ellipsis)),
                          ]);
                        },
                      ),
                    )
                  else
                    const SizedBox(height: 6),
                  // ── Fila 4: botones de acción compactos ───────────────
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: tema.borde))),
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      child: Row(children: [
                        _AccionIconBtn(
                          icon: Icons.send,
                          tooltip: 'Cocina',
                          onTap: () => _enviarACocina(context),
                        ),
                        const SizedBox(width: 4),
                        _AccionIconBtn(
                          icon: Icons.swap_horiz,
                          tooltip: 'Transferir',
                          enabled: comandaActiva != null &&
                              comandaActiva!.lineas.isNotEmpty &&
                              mesaId != null,
                          onTap: () => _transferirComanda(context),
                        ),
                        const SizedBox(width: 4),
                        _AccionIconBtn(
                          icon: Icons.merge_type,
                          tooltip: 'Fusionar mesa',
                          enabled: mesaId != null,
                          onTap: () => _fusionarConMesa(context),
                        ),
                        const SizedBox(width: 4),
                        _AccionIconBtn(
                          icon: Icons.call_split,
                          tooltip: 'Dividir',
                          enabled: comandaActiva != null &&
                              comandaActiva!.lineas.length > 1,
                          onTap: comandaActiva != null &&
                              comandaActiva!.lineas.length > 1
                              ? () => _mostrarDividirComanda(
                              context, empresaId, mesaId!,
                              comandaActiva!, onComandaActualizada)
                              : () {},
                        ),
                        const SizedBox(width: 4),
                        _AccionIconBtn(
                          icon: Icons.receipt_outlined,
                          tooltip: 'Pago parcial',
                          enabled: comandaActiva != null &&
                              comandaActiva!.lineas.length > 1,
                          onTap: comandaActiva != null &&
                              comandaActiva!.lineas.length > 1
                              ? () => _cobroParcialLineas(context)
                              : () {},
                        ),
                        const SizedBox(width: 4),
                        _AccionIconBtn(
                          icon: Icons.note_add,
                          tooltip: 'Nota',
                          onTap: () => _agregarNotaGeneral(context),
                        ),
                        const SizedBox(width: 4),
                        _AccionIconBtn(
                          icon: Icons.add_circle_outline,
                          tooltip: 'Prod. libre',
                          onTap: () => _agregarProductoLibre(context),
                        ),
                        const SizedBox(width: 4),
                        _AccionIconBtn(
                          icon: Icons.discount_outlined,
                          tooltip: 'Descuento',
                          enabled: comandaActiva != null &&
                              comandaActiva!.lineas.isNotEmpty,
                          onTap: comandaActiva != null &&
                              comandaActiva!.lineas.isNotEmpty
                              ? () => _aplicarDescuento(context)
                              : () {},
                        ),
                        const SizedBox(width: 4),
                        _AccionIconBtn(
                          icon: Icons.pause_circle_outline,
                          tooltip: 'En espera',
                          enabled: comandaActiva != null &&
                              comandaActiva!.lineas.isNotEmpty,
                          onTap: comandaActiva != null &&
                              comandaActiva!.lineas.isNotEmpty
                              ? () => onEnEspera?.call()
                              : () {},
                        ),
                        const SizedBox(width: 4),
                        _AccionIconBtn(
                          icon: Icons.print_outlined,
                          tooltip: 'Reimprimir ticket',
                          enabled: mesaId != null,
                          onTap: () => _reimprimirUltimoTicket(context),
                        ),
                      ],
                    ),   // close Row
                  ),     // close FittedBox
                  ),     // close actions Container
                ]);      // close mesa Column
              },
            )
                : Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila 1: ⚡ VENTA DIRECTA
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.orange, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text('VENTA DIRECTA',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                            color: tema.texto, letterSpacing: 0.4)),
                  ]),
                  const SizedBox(height: 10),
                  // Fila 2: botones de acción
                  Row(children: [
                    _BotonAccion(
                      icon: Icons.add_circle_outline,
                      label: 'Libre',
                      onTap: () => _agregarProductoLibre(context),
                    ),
                    const SizedBox(width: 6),
                    _BotonAccion(
                      icon: Icons.discount_outlined,
                      label: 'Dto.',
                      onTap: comandaActiva != null && comandaActiva!.lineas.isNotEmpty
                          ? () => _aplicarDescuento(context)
                          : () {},
                    ),
                    const Spacer(),
                    if (onAbrirConfig != null)
                      Tooltip(
                        message: 'Configuración TPV',
                        child: GestureDetector(
                          onTap: onAbrirConfig,
                          child: Icon(Icons.settings_outlined, size: 17, color: tema.textoMuted.withValues(alpha: 0.7)),
                        ),
                      ),
                    if (onAbrirConfig != null) const SizedBox(width: 8),
                    if (comandaActiva != null && comandaActiva!.lineas.isNotEmpty)
                      GestureDetector(
                        onTap: () => onComandaActualizada(Comanda(
                          id: '', camareroUid: '', lineas: [],
                          estado: 'abierta', apertura: Timestamp.now(), importeTotal: 0,
                        )),
                        child: Icon(Icons.delete_outline, size: 18, color: tema.textoMuted.withValues(alpha: 0.6)),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          // Lista de productos — compacto cuando hay >5
          Expanded(
            child: comandaActiva == null || comandaActiva!.lineas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64,
                            color: tema.textoMuted.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text('Comanda vacía',
                            style: TextStyle(color: tema.textoMuted, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Selecciona productos del catálogo',
                            style: TextStyle(color: tema.textoMuted.withValues(alpha: 0.6), fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: comandaActiva!.lineas.length,
                    itemBuilder: (context, idx) {
                      final count = comandaActiva!.lineas.length;
                      // Compacto si hay más de 5 líneas
                      final bool compact = count > 5;
                      final linea = comandaActiva!.lineas[idx];
                      return _LineaComandaCard(
                        linea: linea,
                        compact: compact,
                        onCantidadChanged: (delta) {
                          final nuevaCantidad = linea.cantidad + delta;
                          final lineasActualizadas =
                              List<LineaComanda>.from(comandaActiva!.lineas);
                          if (nuevaCantidad <= 0) {
                            lineasActualizadas.removeAt(idx);
                          } else {
                            lineasActualizadas[idx] =
                                linea.copyWith(cantidad: nuevaCantidad);
                          }
                          onComandaActualizada(
                              comandaActiva!.copyWith(lineas: lineasActualizadas));
                        },
                        onEditarPrecio: () =>
                            _editarPrecioLinea(context, idx, linea),
                        onEditarNota: () =>
                            _editarNotaLinea(context, idx, linea),
                        onDescuento: () async {
                          final res = await DescuentoLineaWidget.mostrar(
                            context,
                            nombreProducto: linea.nombre,
                            precioOriginal: linea.precioUnitario,
                            cantidad: linea.cantidad,
                          );
                          if (res != null && res.importe > 0) {
                            onComandaActualizada(comandaActiva!.copyWith(
                              descuento: (comandaActiva!.descuento ?? 0) + res.importe,
                            ));
                          }
                        },
                      );
                    },
                  ),
          ),
          // ── Panel total + cobrar ─────────────────────────────────────────
          if (comandaActiva != null && comandaActiva!.lineas.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: tema.superficie,
                border: Border(top: BorderSide(color: tema.borde)),
              ),
              child: Column(children: [
                // Subtotal
                _totalRow('Subtotal', fmt.format(comandaActiva!.baseImponible), tema),
                const SizedBox(height: 3),
                // Descuento
                if ((comandaActiva!.descuento ?? 0) > 0) ...[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Text(
                        'Descuento${comandaActiva!.descuentoPct != null ? " (${comandaActiva!.descuentoPct!.toStringAsFixed(0)}%)" : ""}',
                        style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => onComandaActualizada(comandaActiva!.copyWith(clearDescuento: true)),
                        child: const Icon(Icons.close, size: 12, color: Colors.redAccent),
                      ),
                    ]),
                    Text('- ${fmt.format(comandaActiva!.descuento!)}',
                        style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 3),
                ],
                // IVA
                _totalRow('Impuestos', fmt.format(comandaActiva!.cuotaIva), tema),
                // Nota
                if ((comandaActiva!.notaGeneral ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      const Icon(Icons.note, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Expanded(child: Text(comandaActiva!.notaGeneral!,
                          style: const TextStyle(color: Colors.amber, fontSize: 10, fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                Divider(color: tema.borde, height: 14),
                // TOTAL
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tema.textoMuted)),
                  FittedBox(fit: BoxFit.scaleDown,
                    child: Text(fmt.format(comandaActiva!.total),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)))),
                ]),
                const SizedBox(height: 6),
                // Cupón de descuento
                CuponInputWidget(
                  empresaId: empresaId,
                  totalBase: comandaActiva!.total,
                  onAplicado: (cuponId, descuento) {
                    onComandaActualizada(comandaActiva!.copyWith(
                      descuento: (comandaActiva!.descuento ?? 0) + descuento,
                    ));
                  },
                  onRetirar: () {
                    onComandaActualizada(comandaActiva!.copyWith(clearDescuento: true));
                  },
                ),
                const SizedBox(height: 10),
                // Botón Cobrar
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => _cobrar(context, empresaId, comandaActiva!, mesaId, onCobrado),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: FittedBox(fit: BoxFit.scaleDown,
                      child: Text('Cobrar ${fmt.format(comandaActiva!.total)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Botón Enviar a cocina
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => _enviarACocina(context),
                    icon: Icon(Icons.restaurant_outlined, size: 16, color: tema.textoMuted),
                    label: Text('Enviar a cocina',
                        style: TextStyle(fontSize: 13, color: tema.texto, fontWeight: FontWeight.w500)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: tema.borde),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Barra de acciones rápidas
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _miniAccion(Icons.discount_outlined, 'Descuento', tema,
                      onTap: () => _aplicarDescuento(context)),
                  _miniAccion(Icons.note_add_outlined, 'Nota', tema,
                      onTap: () => _agregarNotaGeneral(context)),
                  _miniAccion(Icons.call_split, 'Dividir', tema,
                      enabled: (comandaActiva?.lineas.length ?? 0) > 1,
                      onTap: comandaActiva != null && comandaActiva!.lineas.length > 1
                          ? () => _mostrarDividirComanda(context, empresaId, mesaId ?? '', comandaActiva!, onComandaActualizada)
                          : () {}),
                  _miniAccion(Icons.more_horiz, 'Más', tema,
                      onTap: () {}),
                ]),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String valor, _TpvRootTema t) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: t.textoMuted)),
        Text(valor,  style: TextStyle(fontSize: 12, color: t.textoMuted)),
      ]);

  Widget _miniAccion(IconData icon, String label, _TpvRootTema t,
      {VoidCallback? onTap, bool enabled = true}) =>
    GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: enabled ? t.texto : t.textoMuted.withValues(alpha: 0.4)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: enabled ? t.textoMuted : t.textoMuted.withValues(alpha: 0.4))),
      ]),
    );

  // ── IMPLEMENTADO: Enviar comanda a impresora de cocina ─────────────────
  Future<void> _transferirComanda(BuildContext context) async {
    if (comandaActiva == null || mesaId == null) return;

    // Cargar mesas libres
    final snap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('mesas')
        .where('estado', isEqualTo: 'libre')
        .get();

    final mesasLibres = snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((m) => m['id'] != mesaId)
        .toList();

    if (!context.mounted) return;

    if (mesasLibres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay mesas libres disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final mesaDestinoId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E2139),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Icon(Icons.swap_horiz, color: Color(0xFF00FFC8), size: 18),
                SizedBox(width: 8),
                Text('Transferir a mesa libre',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2E45), height: 1),
          ...mesasLibres.map((m) {
            final nombre = (m['nombre'] as String?) ??
                'Mesa ${m['numero'] ?? ''}';
            final zona = m['zona'] as String? ?? '';
            return ListTile(
              leading: const Icon(Icons.table_restaurant_outlined,
                  color: Colors.green, size: 20),
              title: Text(nombre,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: zona.isNotEmpty
                  ? Text(zona,
                      style: const TextStyle(color: Colors.white38, fontSize: 11))
                  : null,
              onTap: () => Navigator.pop(context, m['id'] as String),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (mesaDestinoId == null || !context.mounted) return;

    // Ejecutar transferencia en batch
    final db = FirebaseFirestore.instance.collection('empresas').doc(empresaId);
    final batch = FirebaseFirestore.instance.batch();

    // Actualizar comanda → nueva mesa
    batch.update(
      db.collection('comandas').doc(comandaActiva!.id),
      {'mesa_id': mesaDestinoId},
    );

    // Liberar mesa origen
    batch.update(
      db.collection('mesas').doc(mesaId),
      {'estado': 'libre', 'comanda_id': null, 'camarero_uid': null, 'fecha_apertura': null},
    );

    // Ocupar mesa destino
    batch.update(
      db.collection('mesas').doc(mesaDestinoId),
      {
        'estado': 'ocupada',
        'comanda_id': comandaActiva!.id,
        'camarero_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'fecha_apertura': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    // Notificar al padre para que actualice la mesa seleccionada
    onTransferirComanda?.call(mesaDestinoId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Comanda transferida'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── FUSIONAR MESAS: une la comanda de otra mesa ocupada a la actual ────────
  Future<void> _fusionarConMesa(BuildContext context) async {
    if (mesaId == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('mesas')
        .where('estado', isEqualTo: 'ocupada')
        .get();

    final mesasOcupadas = snap.docs
        .where((d) => d.id != mesaId)
        .map((d) => {'id': d.id, ...d.data()})
        .toList();

    if (!context.mounted) return;

    if (mesasOcupadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay otras mesas ocupadas para fusionar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final mesaOrigenId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E2139),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Icon(Icons.merge_type, color: Color(0xFFFF3296), size: 18),
                SizedBox(width: 8),
                Text('Fusionar con mesa',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2E45), height: 1),
          ...mesasOcupadas.map((m) {
            final nombre = (m['nombre'] as String?) ?? 'Mesa';
            final zona = m['zona'] as String? ?? '';
            return ListTile(
              leading: const Icon(Icons.table_restaurant, color: Color(0xFFFF3296), size: 20),
              title: Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: zona.isNotEmpty
                  ? Text(zona, style: const TextStyle(color: Colors.white38, fontSize: 11))
                  : null,
              onTap: () => Navigator.pop(context, m['id'] as String),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (mesaOrigenId == null || !context.mounted) return;

    // Cargar la comanda de la mesa origen
    final comandasOrigen = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('comandas')
        .where('mesa_id', isEqualTo: mesaOrigenId)
        .where('estado', isEqualTo: 'abierta')
        .limit(1)
        .get();

    if (comandasOrigen.docs.isEmpty || !context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La mesa seleccionada no tiene comanda activa'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final comandaOrigenDoc = comandasOrigen.docs.first;
    final lineasOrigen = (comandaOrigenDoc.data()['lineas'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    // Fusionar: unir las líneas de la comanda origen a la comanda actual
    final lineasActuales = (comandaActiva?.lineas ?? []).map((l) => {
      'producto_id': l.productoId,
      'nombre': l.nombre,
      'cantidad': l.cantidad,
      'precio_unitario': l.precioUnitario,
      'iva_porcentaje': l.ivaPorcentaje,
      'notas': l.notas,
      'es_nuevo': l.esNuevo,
      'subtotal': l.total,
    }).toList();

    final lineasFusionadas = [...lineasActuales, ...lineasOrigen];
    final nuevoTotal = lineasFusionadas.fold<double>(
        0.0, (s, l) => s + ((l['subtotal'] as num?)?.toDouble() ?? 0));

    final db = FirebaseFirestore.instance.collection('empresas').doc(empresaId);
    final batch = FirebaseFirestore.instance.batch();

    // Actualizar comanda actual con líneas fusionadas
    if (comandaActiva != null) {
      batch.update(db.collection('comandas').doc(comandaActiva!.id), {
        'lineas': lineasFusionadas,
        'importe_total': nuevoTotal,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      });
    }

    // Cerrar comanda origen
    batch.update(db.collection('comandas').doc(comandaOrigenDoc.id), {
      'estado': 'fusionada',
      'fusionada_en': comandaActiva?.id ?? '',
      'fecha_fusion': FieldValue.serverTimestamp(),
    });

    // Liberar mesa origen
    batch.update(db.collection('mesas').doc(mesaOrigenId), {
      'estado': 'libre',
      'comanda_id': null,
      'camarero_uid': null,
      'fecha_apertura': null,
    });

    await batch.commit();

    // Recargar la comanda actual
    if (comandaActiva != null) {
      final doc = await db.collection('comandas').doc(comandaActiva!.id).get();
      if (doc.exists) {
        final lineasNuevas = (doc.data()!['lineas'] as List<dynamic>? ?? [])
            .map((l) => LineaComanda(
              productoId: l['producto_id'] as String? ?? '',
              nombre: l['nombre'] as String? ?? '',
              precioUnitario: (l['precio_unitario'] as num?)?.toDouble() ?? 0,
              cantidad: (l['cantidad'] as num?)?.toInt() ?? 1,
              ivaPorcentaje: (l['iva_porcentaje'] as num?)?.toDouble() ?? 21,
              notas: l['notas'] as String?,
            )).toList();
        onComandaActualizada(comandaActiva!.copyWith(
            lineas: lineasNuevas, importeTotal: nuevoTotal));
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Mesas fusionadas'),
          backgroundColor: Color(0xFFFF3296),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── COBRO PARCIAL: pagar líneas seleccionadas sin cerrar la mesa ──────────
  Future<void> _cobroParcialLineas(BuildContext context) async {
    if (comandaActiva == null || mesaId == null) return;

    final selectedIndices = <int>{};
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          final totalSeleccionado = selectedIndices.fold<double>(
              0, (s, i) => s + comandaActiva!.lineas[i].total);
          return AlertDialog(
            backgroundColor: const Color(0xFF1E2139),
            title: const Row(children: [
              Icon(Icons.receipt_outlined, color: Color(0xFF00FFC8), size: 18),
              SizedBox(width: 8),
              Text('Pago parcial', style: TextStyle(color: Colors.white, fontSize: 16)),
            ]),
            content: SizedBox(
              width: 340,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona los artículos que se van a cobrar ahora.\nLos restantes quedan en la mesa.',
                      style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ...comandaActiva!.lineas.asMap().entries.map((e) =>
                        CheckboxListTile(
                          dense: true,
                          checkColor: const Color(0xFF0A0F23),
                          activeColor: const Color(0xFF00FFC8),
                          tileColor: Colors.transparent,
                          title: Text(
                              '${e.value.nombre} ×${e.value.cantidad}',
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text(
                              fmt.format(e.value.total),
                              style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 11)),
                          value: selectedIndices.contains(e.key),
                          onChanged: (v) => setS(() {
                            if (v == true) selectedIndices.add(e.key);
                            else selectedIndices.remove(e.key);
                          }),
                        )),
                    if (selectedIndices.isNotEmpty) ...[
                      const Divider(color: Color(0xFF2A2E45)),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('A cobrar:', style: TextStyle(color: Color(0xFFB0B3C1))),
                        Text(fmt.format(totalSeleccionado),
                            style: const TextStyle(
                                color: Color(0xFF00FFC8),
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx2, false),
                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFFB0B3C1)))),
              FilledButton(
                onPressed: selectedIndices.isEmpty ? null : () => Navigator.pop(ctx2, true),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00FFC8)),
                child: const Text('Cobrar selección',
                    style: TextStyle(color: Color(0xFF0A0F23), fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmar != true || selectedIndices.isEmpty || !context.mounted) return;

    final lineasACobrar = selectedIndices.map((i) => comandaActiva!.lineas[i]).toList();
    final subtotalParcial = lineasACobrar.fold<double>(0, (s, l) => s + l.total);

    // Mostrar diálogo de método de pago
    final pago = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoMetodoPago(total: subtotalParcial, empresaId: empresaId),
    );

    if (pago == null || !context.mounted) return;

    try {
      final numeroTicket = await _obtenerSiguienteNumeroTicket(empresaId);
      if (!context.mounted) return;

      final lineasPedido = lineasACobrar.map((l) => LineaPedido(
        productoId: l.productoId,
        productoNombre: l.nombre,
        cantidad: l.cantidad,
        precioUnitario: l.precioUnitario,
        ivaPorcentaje: l.ivaPorcentaje,
        notasLinea: l.notas?.isNotEmpty == true ? l.notas : null,
      )).toList();

      await PedidosService().crearPedido(
        empresaId: empresaId,
        clienteNombre: 'Pago parcial',
        lineas: lineasPedido,
        metodoPago: pago['metodo'] == 'efectivo'
            ? MetodoPago.efectivo
            : pago['metodo'] == 'tarjeta'
            ? MetodoPago.tarjeta
            : MetodoPago.mixto,
        origen: OrigenPedido.presencial,
        numeroTicket: numeroTicket,
        importeEfectivo: pago['importe_efectivo'],
        importeTarjeta: pago['importe_tarjeta'],
        importeTotal: subtotalParcial,
        mesaId: mesaId,
        estado: 'entregado',
        estadoPago: 'pagado',
        fechaHora: Timestamp.now(),
      );

      // Eliminar las líneas cobradas de la comanda
      final lineasRestantes = comandaActiva!.lineas
          .asMap()
          .entries
          .where((e) => !selectedIndices.contains(e.key))
          .map((e) => e.value)
          .toList();

      final totalRestante = lineasRestantes.fold<double>(0, (s, l) => s + l.total);

      final db = FirebaseFirestore.instance.collection('empresas').doc(empresaId);

      if (lineasRestantes.isEmpty) {
        // Si no quedan líneas, cerrar la mesa normal
        await db.collection('comandas').doc(comandaActiva!.id).update({
          'estado': 'cerrada',
          'fecha_cierre': FieldValue.serverTimestamp(),
        });
        await db.collection('mesas').doc(mesaId).update({
          'estado': 'libre',
          'comanda_id': null,
          'camarero_uid': null,
        });
        onCobrado();
      } else {
        // Actualizar comanda con líneas restantes
        await db.collection('comandas').doc(comandaActiva!.id).update({
          'lineas': lineasRestantes.map((l) => {
            'producto_id': l.productoId,
            'nombre': l.nombre,
            'cantidad': l.cantidad,
            'precio_unitario': l.precioUnitario,
            'iva_porcentaje': l.ivaPorcentaje,
            'notas': l.notas,
            'es_nuevo': l.esNuevo,
            'subtotal': l.total,
          }).toList(),
          'importe_total': totalRestante,
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        });
        onComandaActualizada(comandaActiva!.copyWith(
            lineas: lineasRestantes, importeTotal: totalRestante));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Cobro parcial realizado · Quedan ${fmt.format(totalRestante)} en mesa'),
              backgroundColor: const Color(0xFF00FFC8),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en pago parcial: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── REIMPRIMIR ÚLTIMO TICKET DE ESTA MESA ────────────────────────────────
  Future<void> _reimprimirUltimoTicket(BuildContext context) async {
    if (mesaId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos')
          .where('mesa_id', isEqualTo: mesaId)
          .where('estado_pago', isEqualTo: 'pagado')
          .orderBy('fecha_creacion', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay tickets anteriores para esta mesa'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final data = snap.docs.first.data();
      final nombre = (data['cliente_nombre'] as String?) ?? 'Mesa';
      final total = (data['total'] as num?)?.toDouble() ?? 0;
      final metodo = (data['metodo_pago'] as String?) ?? 'efectivo';
      final lineasRaw = data['lineas'] as List<dynamic>? ?? [];
      final lineasTicket = lineasRaw.map((l) {
        final m = l as Map<String, dynamic>;
        return LineaTicket(
          nombre: m['producto_nombre'] as String? ?? m['nombre'] as String? ?? '',
          cantidad: (m['cantidad'] as num?)?.toInt() ?? 1,
          precioUnitario: (m['precio_unitario'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      final ticketData = TicketData(
        nombreEmpresa: nombre,
        numeroTicket: (data['numero_ticket'] as num?)?.toInt() ?? 0,
        fecha: DateTime.now(),
        lineas: lineasTicket,
        total: total,
        metodoPago: metodo,
      );

      await ImpressoraBluetooth().imprimirTicket(ticketData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖨️ Ticket reimpreso'),
            backgroundColor: Color(0xFF1565C0),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reimprimir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _enviarACocina(BuildContext context) async {
    if (comandaActiva == null || comandaActiva!.lineas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La comanda está vacía')),
      );
      return;
    }
    try {
      // Marcar líneas como enviadas en Firestore
      if (comandaActiva!.id.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaId)
            .collection('comandas')
            .doc(comandaActiva!.id)
            .update({
          'enviada_cocina': true,
          'fecha_envio_cocina': FieldValue.serverTimestamp(),
          'estado_cocina': 'pendiente', // ← NUEVO: Estado inicial
          'lineas': comandaActiva!.lineas.map((l) => {
            'producto_id': l.productoId,
            'nombre': l.nombre,
            'cantidad': l.cantidad,
            'precio_unitario': l.precioUnitario,
            'iva_porcentaje': l.ivaPorcentaje,
            'notas': l.notas,
            'es_nuevo': false,
            'subtotal': l.total,
            if (l.destino != null) 'destino': l.destino,
          }).toList(),
          'nota_general': comandaActiva!.notaGeneral, // ← NUEVO: Incluir nota
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Comanda enviada a cocina'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        // ═══════════════════════════════════════════════════════════════════
        // NAVEGACIÓN A PANTALLA DE COCINA
        // ═══════════════════════════════════════════════════════════════════
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => PantallaCocinaScreen(empresaId: empresaId),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar a cocina: $e'),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: () => _enviarACocina(context),
            ),
          ),
        );
      }
    }
  }

  // ── IMPLEMENTADO: Nota general a la comanda ────────────────────────────
  Future<void> _agregarNotaGeneral(BuildContext context) async {
    if (comandaActiva == null) return;
    final ctrl = TextEditingController(text: comandaActiva!.notaGeneral ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.note_add, color: Color(0xFFFFA000)),
          SizedBox(width: 8),
          Text('Nota de la comanda'),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej: Alergia al gluten, celebración de cumpleaños…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final nota = ctrl.text.trim();
              onComandaActualizada(comandaActiva!.copyWith(
                notaGeneral: nota.isEmpty ? null : nota,
                clearNota: nota.isEmpty,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Producto libre (sin catálogo) — con selector de IVA ─────────────────
  Future<void> _agregarProductoLibre(BuildContext context) async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    double ivaSeleccionado = 10;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFFFFA000)),
            SizedBox(width: 8),
            Text('Producto libre'),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Añade un artículo que no está en el catálogo.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nombreCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción *',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio con IVA (€) *',
                  prefixIcon: Icon(Icons.euro),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                value: ivaSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Tipo de IVA',
                  prefixIcon: Icon(Icons.percent),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 0,  child: Text('0% — Exento')),
                  DropdownMenuItem(value: 4,  child: Text('4% — Superreducido')),
                  DropdownMenuItem(value: 10, child: Text('10% — Reducido')),
                  DropdownMenuItem(value: 21, child: Text('21% — General')),
                ],
                onChanged: (v) => setS(() => ivaSeleccionado = v ?? 10),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final nombre = nombreCtrl.text.trim();
              final precio = double.tryParse(
                  precioCtrl.text.replaceAll(',', '.')) ??
                  0;
              if (nombre.isEmpty || precio <= 0) return;

              final linea = LineaComanda(
                productoId: 'libre_${DateTime.now().millisecondsSinceEpoch}',
                nombre: nombre,
                cantidad: 1,
                precioUnitario: precio,
                ivaPorcentaje: ivaSeleccionado,
                esNuevo: true,
              );

              final lineas = List<LineaComanda>.from(
                  comandaActiva?.lineas ?? [])
                ..add(linea);

              final base = comandaActiva ??
                  Comanda(
                    id: FirebaseFirestore.instance
                        .collection('dummy')
                        .doc()
                        .id,
                    camareroUid:
                    FirebaseAuth.instance.currentUser?.uid ?? '',
                    lineas: [],
                    estado: 'abierta',
                    apertura: Timestamp.now(),
                    importeTotal: 0,
                  );
              onComandaActualizada(base.copyWith(lineas: lineas));
              Navigator.pop(ctx2);
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
      ),
    );
    nombreCtrl.dispose();
    precioCtrl.dispose();
  }

  // ── Descuento sobre el total (% o importe fijo) ─────────────────────────
  Future<void> _aplicarDescuento(BuildContext context) async {
    double pct = 0;
    bool modoPct = true;
    final importeCtrl = TextEditingController();
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          final totalBase = comandaActiva!.total;
          double descuentoPreview = 0;
          if (modoPct && pct > 0) {
            descuentoPreview = totalBase * pct / 100;
          } else if (!modoPct) {
            descuentoPreview = double.tryParse(
                importeCtrl.text.replaceAll(',', '.')) ?? 0;
            descuentoPreview = descuentoPreview.clamp(0, totalBase);
          }

          return AlertDialog(
            title: const Text('Aplicar descuento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total: ${fmt.format(totalBase)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                // Toggle % vs €
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Porcentaje %')),
                    ButtonSegment(value: false, label: Text('Importe €')),
                  ],
                  selected: {modoPct},
                  onSelectionChanged: (s) => setS(() {
                    modoPct = s.first;
                    pct = 0;
                    importeCtrl.clear();
                  }),
                ),
                const SizedBox(height: 12),
                if (modoPct) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [5, 10, 15, 20, 25, 50].map((p) {
                      return ChoiceChip(
                        label: Text('$p%'),
                        selected: pct == p,
                        onSelected: (_) => setS(() => pct = p.toDouble()),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  TextField(
                    controller: importeCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Importe a descontar (€)',
                      prefixIcon: Icon(Icons.euro),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                ],
                const SizedBox(height: 10),
                if (descuentoPreview > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Descuento:', style: TextStyle(color: Colors.green)),
                        Text('- ${fmt.format(descuentoPreview)}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: descuentoPreview > 0
                    ? () {
                        onComandaActualizada(comandaActiva!.copyWith(
                          descuento: descuentoPreview,
                          descuentoPct: modoPct ? pct : null,
                        ));
                        Navigator.pop(ctx2);
                      }
                    : null,
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
    importeCtrl.dispose();
  }

  // ── IMPLEMENTADO: Editar precio de línea ──────────────────────────────
  Future<void> _editarPrecioLinea(
      BuildContext context, int idx, LineaComanda linea) async {
    final ctrl = TextEditingController(
        text: linea.precioUnitario.toStringAsFixed(2));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Precio de "${linea.nombre}"'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Nuevo precio unitario (€)',
            prefixIcon: Icon(Icons.euro),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final nuevoPrecio = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (nuevoPrecio == null || nuevoPrecio < 0) return;
              final lineas = List<LineaComanda>.from(comandaActiva!.lineas);
              lineas[idx] = linea.copyWith(precioUnitario: nuevoPrecio);
              onComandaActualizada(comandaActiva!.copyWith(lineas: lineas));
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── IMPLEMENTADO: Editar nota por línea ───────────────────────────────
  Future<void> _editarNotaLinea(
      BuildContext context, int idx, LineaComanda linea) async {
    final ctrl = TextEditingController(text: linea.notas ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nota: "${linea.nombre}"'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej: sin gluten, poco hecho, sin cebolla…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final nota = ctrl.text.trim();
              final lineas =
              List<LineaComanda>.from(comandaActiva!.lineas);
              lineas[idx] =
                  linea.copyWith(notas: nota.isEmpty ? null : nota);
              onComandaActualizada(comandaActiva!.copyWith(lineas: lineas));
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cobrar(BuildContext context, String empresaId, Comanda comanda,
      String? mesaId, VoidCallback onCobrado) async {
    debugPrint('💰 [COBRO] ═══════════════════════════════════════');
    debugPrint('💰 [COBRO] Iniciando proceso de cobro');
    debugPrint('💰 [COBRO] Empresa: $empresaId');
    debugPrint('💰 [COBRO] Mesa: ${mesaId ?? "Caja rápida"}');
    debugPrint('💰 [COBRO] Total: ${comanda.total.toStringAsFixed(2)} €');
    debugPrint('💰 [COBRO] Líneas: ${comanda.lineas.length}');
    
    try {
      debugPrint('💰 [COBRO] Paso 1: Mostrando diálogo de pago...');
      final pago = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogoMetodoPago(total: comanda.total, empresaId: empresaId),
      );
      if (pago == null) {
        debugPrint('💰 [COBRO] Usuario canceló el pago');
        return;
      }
      if (!context.mounted) {
        debugPrint('💰 [COBRO] Context desmontado después de diálogo');
        return;
      }
      debugPrint('💰 [COBRO] ✅ Método de pago seleccionado: ${pago['metodo']}');

    debugPrint('💰 [COBRO] Paso 2: Obteniendo número de ticket...');
    final numeroTicket = await _obtenerSiguienteNumeroTicket(empresaId);
    debugPrint('💰 [COBRO] ✅ Número ticket: $numeroTicket');
    
    if (!context.mounted) return;
    
    debugPrint('💰 [COBRO] Paso 3: Obteniendo datos empresa...');
    final empresaSnap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .get();
    final empresaData = empresaSnap.data() ?? {};
    debugPrint('💰 [COBRO] ✅ Datos empresa obtenidos');
    
    final ahora = DateTime.now();
    final fechaHoraTs = Timestamp.fromDate(ahora);

    debugPrint('💰 [COBRO] Paso 4: Preparando líneas del pedido...');
    final lineasPedido = comanda.lineas
        .map((l) => LineaPedido(
      productoId: l.productoId,
      productoNombre: l.nombre,
      cantidad: l.cantidad,
      precioUnitario: l.precioUnitario,
      ivaPorcentaje: l.ivaPorcentaje,
      notasLinea: l.notas?.isNotEmpty == true ? l.notas : null,
    ))
        .toList();
    debugPrint('💰 [COBRO] ✅ ${lineasPedido.length} líneas preparadas');

    debugPrint('💰 [COBRO] Paso 5: Creando pedido en Firestore...');
    late final Pedido pedidoCreado;
    try {
      pedidoCreado = await PedidosService().crearPedido(
        empresaId: empresaId,
        clienteNombre: mesaId != null ? 'Mesa $mesaId' : 'Caja rápida',
        lineas: lineasPedido,
        metodoPago: pago['metodo'] == 'efectivo'
            ? MetodoPago.efectivo
            : pago['metodo'] == 'tarjeta'
            ? MetodoPago.tarjeta
            : MetodoPago.mixto,
        origen: OrigenPedido.presencial,
        numeroTicket: numeroTicket,
        importeEfectivo: pago['importe_efectivo'],
        importeTarjeta: pago['importe_tarjeta'],
        importeTotal: (pago['total_final'] as double?) ?? comanda.total,
        mesaId: mesaId,
        estado: 'entregado',
        estadoPago: 'pagado',
        fechaHora: fechaHoraTs,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || !estaOnline) {
        // Sin conexión — guardar localmente
        await OfflineQueueService().encolar(empresaId, {
          'mesa_id': mesaId ?? '',
          'mesa_nombre': mesaId != null ? 'Mesa $mesaId' : 'Caja rápida',
          'lineas': comanda.lineas.map((l) => {
            'nombre': l.nombre, 'cantidad': l.cantidad,
            'precio_unitario': l.precioUnitario,
          }).toList(),
          'total': comanda.total,
          'metodo_pago': pago['metodo'],
          'estado_pago': 'pagado',
          'fecha_hora': ahora.toIso8601String(),
          'numero_ticket': numeroTicket,
          'es_offline': true,
        });
        onActualizarOffline?.call();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sin conexión — cobro guardado localmente. Se subirá al recuperar WiFi.'),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 5),
          ));
          onCobrado();
        }
        return;
      }
      rethrow;
    }
    debugPrint('💰 [COBRO] ✅ Pedido creado: ${pedidoCreado.id}');

    // QR AEAT (VeriFactu) — solo si el NIF de la empresa está configurado
    try {
      final nif = (empresaData['nif'] as String?)?.trim() ?? '';
      if (nif.isNotEmpty) {
        final qrUrl = QrService().generarUrl(
          nifEmisor: nif,
          serie: 'TPV',
          numero: pedidoCreado.id.substring(0, 8).toUpperCase(),
          fecha: ahora,
          importeTotal: (pago['total_final'] as double?) ?? comanda.total,
        );
        await FirebaseFirestore.instance
            .collection('empresas').doc(empresaId)
            .collection('pedidos').doc(pedidoCreado.id)
            .update({'qr_aeat_url': qrUrl});
      }
    } catch (_) {}

    if (!context.mounted) {
      debugPrint('💰 [COBRO] Context desmontado después de crear pedido');
      onCobrado();
      return;
    }

    debugPrint('💰 [COBRO] Paso 6: Omitido (factura opcional, se pregunta al final)');

    debugPrint('💰 [COBRO] Paso 7: Actualizando comanda...');
    if (comanda.id.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('comandas')
          .doc(comanda.id)
          .update({
        'estado': 'cobrada',
        'fecha_cobro': FieldValue.serverTimestamp(),
      });
      debugPrint('💰 [COBRO] ✅ Comanda actualizada');
    }

    debugPrint('💰 [COBRO] Paso 8: Liberando mesa...');
    if (mesaId != null) {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('mesas')
          .doc(mesaId)
          .update({
        'estado': 'libre',
        'comanda_id': null,
        'camarero_uid': null,
        'fecha_apertura': null,
      });
      debugPrint('💰 [COBRO] ✅ Mesa $mesaId liberada');
    }

    if (!context.mounted) {
      debugPrint('💰 [COBRO] Context desmontado antes de imprimir');
      onCobrado(); 
      return; 
    }

    debugPrint('💰 [COBRO] Paso 9: Preparando ticket...');
    final ticketData = TicketData(
      nombreEmpresa: empresaData['nombre'] as String? ?? '',
      numeroTicket: numeroTicket,
      fecha: ahora,
      lineas: comanda.lineas
          .map((l) => LineaTicket(
        nombre: l.nombre,
        cantidad: l.cantidad,
        precioUnitario: l.precioUnitario,
      ))
          .toList(),
      total: comanda.total,
      metodoPago: pago['metodo'] as String? ?? 'efectivo',
    );
    debugPrint('💰 [COBRO] ✅ Ticket preparado');

    // ── Imprimir ticket: lógica específica por plataforma ──────────────────
    debugPrint('💰 [COBRO] Paso 10: Detectando plataforma e impresora...');
    bool btConectado = false;
    final bool esWindows = !kIsWeb && Platform.isWindows;
    debugPrint('💰 [COBRO] Plataforma: ${esWindows ? "Windows" : "Móvil"}');

    // En plataformas móviles, verificar Bluetooth
    if (!esWindows) {
      try {
        btConectado = await ImpressoraBluetooth().estaConectada();
        debugPrint('💰 [COBRO] Bluetooth conectado: $btConectado');
      } catch (e) {
        debugPrint('⚠️ [COBRO] Error al verificar Bluetooth: $e');
        btConectado = false; // Asegurar que es false en caso de error
      }
    }

    if (!context.mounted) { 
      debugPrint('💰 [COBRO] Context desmontado antes de imprimir');
      onCobrado(); 
      return; 
    }

    // ═══════════════════════════════════════════════════════════════════════
    // WINDOWS: Intentar impresión REAL Bluetooth por Serial Port
    // ═══════════════════════════════════════════════════════════════════════
    if (esWindows) {
      final winSvc = ImpresoraWindowsService();
      if (!winSvc.estaConectada) {
        // Sin impresora configurada — mostrar ticket en pantalla sin aviso de error
        debugPrint('ℹ️ [COBRO] Windows sin impresora configurada — mostrando ticket en pantalla');
        if (context.mounted) {
          await _mostrarVistaTicket(context, ticketData,
              aviso: 'Sin impresora configurada. El ticket se muestra aquí para que el cliente lo fotografíe.\n'
                     'Configura la impresora desde Ajustes TPV → Impresora.');
        }
      } else {
        debugPrint('🪟 [COBRO] Windows con impresora — intentando impresión...');
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => WillPopScope(
              onWillPop: () async => false,
              child: const AlertDialog(
                backgroundColor: Color(0xFF1E2139),
                content: Row(children: [
                  CircularProgressIndicator(color: Color(0xFF00FFC8)),
                  SizedBox(width: 16),
                  Expanded(child: Text('Imprimiendo ticket...',
                      style: TextStyle(color: Colors.white))),
                ]),
              ),
            ),
          );

          await winSvc.imprimirTicket(ticketData);
          if (context.mounted) Navigator.pop(context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Row(children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('🖨️ Ticket impreso correctamente'),
              ]),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ));
          }
        } catch (e) {
          debugPrint('❌ [COBRO] Error impresión Windows: $e');
          if (context.mounted) Navigator.pop(context);
          if (context.mounted) {
            await _mostrarVistaTicket(context, ticketData,
                aviso: '⚠️ Error de impresión: $e\n\nMostrando ticket en pantalla.');
          }
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MÓVIL: Impresión Bluetooth estándar
    // ═══════════════════════════════════════════════════════════════════════
    else if (btConectado) {
      try {
        await ImpressoraBluetooth().imprimirTicket(ticketData);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🖨️ Ticket impreso correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Error al imprimir en móvil: $e\n$stackTrace');
        // Error real de impresora → mostrar ticket en pantalla como fallback
        if (context.mounted) {
          await _mostrarVistaTicket(context, ticketData,
              aviso: 'Error al imprimir (${e.toString()}). Mostrando ticket en pantalla.');
        }
      }
    } else {
      // Sin impresora BT conectada → mostrar ticket en pantalla
      if (context.mounted) {
        await _mostrarVistaTicket(context, ticketData,
            aviso: '⚠️ Sin impresora Bluetooth conectada. Conecta una impresora desde el botón 🖨️ del menú superior.');
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Ticket #$numeroTicket cobrado — ${pago['metodo']} · ${comanda.total.toStringAsFixed(2)} €'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
    
    // Preguntar si desea generar factura
    if (context.mounted) {
      await DialogoFacturaTpv.mostrar(
        context: context,
        empresaId: empresaId,
        pedido: pedidoCreado,
        terminalId: mesaId ?? 'caja_rapida',
      );
    }

    // Liberar UI inmediatamente
    onCobrado();

    // Gestionar mesa en segundo plano (sin bloquear)
    if (mesaId != null) {
      FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('mesas')
          .doc(mesaId)
          .get()
          .then((snap) {
        if (!snap.exists) return;
        final esTicketDividido = snap.data()?['es_ticket_dividido'] == true;
        if (esTicketDividido) {
          // Ticket dividido → borrar la mesa sub-ticket
          snap.reference.delete().catchError((e) {
            debugPrint('⚠️ [COBRO] No se pudo borrar sub-ticket: $e');
          });
        } else {
          // Mesa original → marcar libre (no borrar)
          snap.reference.update({
            'estado': 'libre',
            'comanda_id': null,
            'camarero_uid': null,
            'fecha_apertura': null,
          }).catchError((e) {
            debugPrint('⚠️ [COBRO] No se pudo liberar mesa: $e');
          });
        }
      }).catchError((e) {
        debugPrint('⚠️ [COBRO] No se pudo leer la mesa: $e');
      });
    }
    debugPrint('💰 [COBRO] ═══════════════════════════════════════');
    debugPrint('💰 [COBRO] ✅ COBRO COMPLETADO EXITOSAMENTE');
    debugPrint('💰 [COBRO] ═══════════════════════════════════════');

    } catch (e, stackTrace) {
      // Enviar a Crashlytics solo en móvil (desktop no tiene el plugin)
      if (!kIsWeb &&
          defaultTargetPlatform != TargetPlatform.windows &&
          defaultTargetPlatform != TargetPlatform.linux &&
          defaultTargetPlatform != TargetPlatform.macOS) {
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason: 'Error crítico en proceso de cobro TPV');
      }

      // Logs técnicos solo en debug
      if (kDebugMode) {
        debugPrint('🔴 [COBRO] ERROR CRÍTICO: $e');
        debugPrint(stackTrace.toString());
      }

      if (context.mounted) {
        final incId = 'INC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _DialogoErrorCobro(incId: incId),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO DE ERROR DE COBRO — sin datos técnicos para el usuario
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoErrorCobro extends StatelessWidget {
  final String incId;
  const _DialogoErrorCobro({required this.incId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Text('Error en el cobro', style: TextStyle(fontSize: 17)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ha ocurrido un error inesperado al procesar el cobro. '
            'Por favor, inténtalo de nuevo.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.tag, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    incId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Proporciona este ID al soporte si el problema persiste.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copiar ID'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: incId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ID copiado al portapapeles'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LINEA COMANDA CARD — con editar precio y nota
// ═══════════════════════════════════════════════════════════════════════════

class _LineaComandaCard extends StatelessWidget {
  final LineaComanda linea;
  final ValueChanged<int> onCantidadChanged;
  final VoidCallback onEditarPrecio;
  final VoidCallback onEditarNota;
  final bool compact;
  final VoidCallback? onDescuento;

  const _LineaComandaCard({
    required this.linea,
    required this.onCantidadChanged,
    required this.onEditarPrecio,
    required this.onEditarNota,
    this.compact = false,
    this.onDescuento,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final tema = _TpvRootTemaScope.of(context);

    if (compact) return _buildCompact(fmt, tema);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.superficie,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tema.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ── Indicador "enviado a cocina" ──
              if (!linea.esNuevo)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: 'Ya enviado a cocina',
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              Expanded(
                child: Text(linea.nombre,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: linea.esNuevo ? tema.texto : tema.textoMuted)),
              ),
              // Botón descuento por línea
              if (onDescuento != null)
                Tooltip(
                  message: 'Descuento en esta línea',
                  child: GestureDetector(
                    onTap: onDescuento,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: Icon(Icons.local_offer_outlined, size: 14,
                          color: tema.primario.withValues(alpha: 0.8)),
                    ),
                  ),
                ),
              // Botón editar precio
              GestureDetector(
                onTap: onEditarPrecio,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tema.fondo,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tema.borde),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 11, color: tema.textoMuted.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(fmt.format(linea.precioUnitario),
                          style: TextStyle(fontSize: 11, color: tema.textoMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Nota si existe
          if (linea.notas != null && linea.notas!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.notes, size: 12, color: Colors.amber),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(linea.notas!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.amber, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Botones cantidad
              Container(
                decoration: BoxDecoration(
                  color: tema.fondo,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tema.borde),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, size: 18, color: tema.textoMuted),
                      onPressed: () => onCantidadChanged(-1),
                      padding: const EdgeInsets.all(8),
                      constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('${linea.cantidad}',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: tema.texto)),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, size: 18, color: tema.primario),
                      onPressed: () => onCantidadChanged(1),
                      padding: const EdgeInsets.all(8),
                      constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
              // ── IMPLEMENTADO: Botón nota por línea ──
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.notes,
                  size: 18,
                  color: (linea.notas?.isNotEmpty == true)
                      ? Colors.amber
                      : tema.textoMuted.withValues(alpha: 0.4),
                ),
                tooltip: 'Añadir nota',
                onPressed: onEditarNota,
                padding: EdgeInsets.zero,
                constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const Spacer(),
              // Total línea
              Text(
                fmt.format(linea.total),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFA000)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Layout compacto (cuando hay muchos ítems y hay que encoger) ────────────
  Widget _buildCompact(NumberFormat fmt, _TpvRootTema tema) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tema.superficie,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tema.borde),
      ),
      child: Row(
        children: [
          // Botones cantidad compactos
          Container(
            decoration: BoxDecoration(
              color: tema.fondo,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => onCantidadChanged(-1),
                  child: SizedBox(
                    width: 26, height: 26,
                    child: Icon(Icons.remove, size: 13, color: tema.textoMuted),
                  ),
                ),
                SizedBox(
                  width: 22,
                  child: Text(
                    '${linea.cantidad}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: tema.texto),
                  ),
                ),
                InkWell(
                  onTap: () => onCantidadChanged(1),
                  child: SizedBox(
                    width: 26, height: 26,
                    child: Icon(Icons.add, size: 13, color: tema.primario),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Indicador enviado a cocina (compacto)
          if (!linea.esNuevo)
            const Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(Icons.check_circle, size: 12, color: Color(0xFF4CAF50)),
            ),
          // Nombre
          Expanded(
            child: Text(
              linea.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: linea.esNuevo ? tema.texto : tema.textoMuted),
            ),
          ),
          const SizedBox(width: 4),
          // Precio editable
          GestureDetector(
            onTap: onEditarPrecio,
            child: Text(
              fmt.format(linea.total),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFFA000)),
            ),
          ),
          const SizedBox(width: 4),
          // Nota
          InkWell(
            onTap: onEditarNota,
            child: Icon(
              Icons.notes,
              size: 14,
              color: (linea.notas?.isNotEmpty == true)
                  ? Colors.amber
                  : tema.textoMuted.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COLUMNA DERECHA: CATÁLOGO (30%) — con buscador
// ═══════════════════════════════════════════════════════════════════════════

class _ColumnaCatalogoProductos extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final String categoriaFiltro;
  final String busqueda;
  final String? tpvPersonalizadoId;
  final ValueChanged<String> onCategoriaChanged;
  final ValueChanged<String> onBusquedaChanged;
  final Function(Producto, VarianteProducto?) onProductoSeleccionado;

  const _ColumnaCatalogoProductos({
    required this.empresaId,
    required this.esAdmin,
    required this.categoriaFiltro,
    required this.busqueda,
    this.tpvPersonalizadoId,
    required this.onCategoriaChanged,
    required this.onBusquedaChanged,
    required this.onProductoSeleccionado,
  });

  @override
  State<_ColumnaCatalogoProductos> createState() => _ColumnaCatalogoProductosState();
}

class _ColumnaCatalogoProductosState extends State<_ColumnaCatalogoProductos> {
  // ── Número de columnas del grid (3 o 4) ──────────────────────────────────
  int _columnas = 3;

  // ── Colores por categoría (ciclo de paleta) ───────────────────────────────
  static const _paleta = [
    Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFC62828),
    Color(0xFF6A1B9A), Color(0xFF00838F), Color(0xFFE65100),
    Color(0xFF4E342E), Color(0xFF37474F), Color(0xFF880E4F),
  ];

  // ── Biblioteca de imágenes por nombre clave (TPV genérico) ───────────────
  // Mapa: clave normalizada → URL pública de imagen
  // Logos de marca: Wikipedia Commons (estables, licencia libre)
  // Iconos genéricos: Flaticon CDN (pack/id)
  static const _urlCafe    = 'https://cdn-icons-png.flaticon.com/512/924/924514.png';
  static const _urlTe      = 'https://cdn-icons-png.flaticon.com/512/924/924517.png';
  static const _urlCerveza = 'https://cdn-icons-png.flaticon.com/512/920/920528.png';
  static const _urlVino    = 'https://cdn-icons-png.flaticon.com/512/763/763236.png';
  static const _urlAgua    = 'https://cdn-icons-png.flaticon.com/512/824/824239.png';
  static const _urlZumo    = 'https://cdn-icons-png.flaticon.com/512/3649/3649652.png';
  static const _urlRefresco= 'https://cdn-icons-png.flaticon.com/512/2738/2738730.png';
  static const _urlBatido  = 'https://cdn-icons-png.flaticon.com/512/3481/3481107.png';
  static const _urlPan     = 'https://cdn-icons-png.flaticon.com/512/3141/3141060.png';
  static const _urlBocadillo='https://cdn-icons-png.flaticon.com/512/3141/3141169.png';
  static const _urlCroissant='https://cdn-icons-png.flaticon.com/512/3480/3480207.png';
  static const _urlChurros = 'https://cdn-icons-png.flaticon.com/512/3480/3480208.png';
  static const _urlPatatas = 'https://cdn-icons-png.flaticon.com/512/1046/1046769.png';
  static const _urlCroquetas='https://cdn-icons-png.flaticon.com/512/3480/3480226.png';
  static const _urlTortilla='https://cdn-icons-png.flaticon.com/512/3595/3595462.png';
  static const _urlJamon   = 'https://cdn-icons-png.flaticon.com/512/3480/3480227.png';
  static const _urlHelado  = 'https://cdn-icons-png.flaticon.com/512/938/938063.png';
  static const _urlPizza   = 'https://cdn-icons-png.flaticon.com/512/3595/3595455.png';
  static const _urlBurger  = 'https://cdn-icons-png.flaticon.com/512/1046/1046784.png';
  static const _urlEnsalada= 'https://cdn-icons-png.flaticon.com/512/2515/2515183.png';
  static const _urlMarisco = 'https://cdn-icons-png.flaticon.com/512/2515/2515217.png';
  static const _urlPollo   = 'https://cdn-icons-png.flaticon.com/512/1046/1046751.png';
  static const _urlQueso   = 'https://cdn-icons-png.flaticon.com/512/3480/3480234.png';
  static const _urlPincho  = 'https://cdn-icons-png.flaticon.com/512/3480/3480208.png';
  static const _urlCava    = 'https://cdn-icons-png.flaticon.com/512/763/763239.png';
  static const _urlSangria = 'https://cdn-icons-png.flaticon.com/512/3649/3649652.png';

  static const Map<String, String> _imagenesTpv = {
    // ── BEBIDAS: marcas ─────────────────────────────────────────────────────
    'coca cola':       'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Coca-Cola_logo.svg/200px-Coca-Cola_logo.svg.png',
    'coca-cola':       'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Coca-Cola_logo.svg/200px-Coca-Cola_logo.svg.png',
    'cocacola':        'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Coca-Cola_logo.svg/200px-Coca-Cola_logo.svg.png',
    'coca cola zero':  'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Coca-Cola_logo.svg/200px-Coca-Cola_logo.svg.png',
    'coca cola light': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Coca-Cola_logo.svg/200px-Coca-Cola_logo.svg.png',
    'pepsi':           'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Pepsi_logo_2014.svg/200px-Pepsi_logo_2014.svg.png',
    'fanta':           'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/Fanta_logo.svg/200px-Fanta_logo.svg.png',
    'fanta naranja':   'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/Fanta_logo.svg/200px-Fanta_logo.svg.png',
    'fanta limon':     'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/Fanta_logo.svg/200px-Fanta_logo.svg.png',
    'fanta limón':     'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/Fanta_logo.svg/200px-Fanta_logo.svg.png',
    'sprite':          'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Sprite_logo.svg/200px-Sprite_logo.svg.png',
    'red bull':        'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Red_bull_logo.svg/200px-Red_bull_logo.svg.png',
    'monster':         'https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Monster_Energy_logo.svg/200px-Monster_Energy_logo.svg.png',
    'nestea':          _urlTe,
    'aquarius':        _urlRefresco,
    'kas':             _urlRefresco,
    'kas naranja':     _urlRefresco,
    'kas limon':       _urlRefresco,
    'kas limón':       _urlRefresco,
    'tonica':          _urlRefresco,
    'tónica':          _urlRefresco,
    'refresco':        _urlRefresco,
    // ── BEBIDAS: agua ───────────────────────────────────────────────────────
    'agua':            _urlAgua,
    'agua pequena':    _urlAgua,
    'agua pequeña':    _urlAgua,
    'agua grande':     _urlAgua,
    'agua con gas':    _urlAgua,
    // ── BEBIDAS: zumos y batidos ────────────────────────────────────────────
    'zumo':            _urlZumo,
    'zumo naranja':    _urlZumo,
    'zumo pina':       _urlZumo,
    'zumo piña':       _urlZumo,
    'zumo melocoton':  _urlZumo,
    'zumo melocotón':  _urlZumo,
    'batido':          _urlBatido,
    'batido chocolate':_urlBatido,
    'batido vainilla': _urlBatido,
    'batido fresa':    _urlBatido,
    // ── CAFÉS ───────────────────────────────────────────────────────────────
    'cafe':            _urlCafe,
    'café':            _urlCafe,
    'cafe solo':       _urlCafe,
    'café solo':       _urlCafe,
    'cafe cortado':    _urlCafe,
    'café cortado':    _urlCafe,
    'cortado':         _urlCafe,
    'cafe con leche':  _urlCafe,
    'café con leche':  _urlCafe,
    'cafe americano':  _urlCafe,
    'café americano':  _urlCafe,
    'cafe bombon':     _urlCafe,
    'café bombón':     _urlCafe,
    'cafe manchado':   _urlCafe,
    'café manchado':   _urlCafe,
    'cappuccino':      _urlCafe,
    'capuccino':       _urlCafe,
    'cafe descafeinado':_urlCafe,
    'café descafeinado':_urlCafe,
    'descafeinado':    _urlCafe,
    'colacao':         _urlBatido,
    'chocolate caliente':_urlBatido,
    'chocolate':       _urlBatido,
    'te':              _urlTe,
    'té':              _urlTe,
    'te negro':        _urlTe,
    'té negro':        _urlTe,
    'te verde':        _urlTe,
    'té verde':        _urlTe,
    'manzanilla':      _urlTe,
    'poleo':           _urlTe,
    'poleo menta':     _urlTe,
    'infusion':        _urlTe,
    'infusión':        _urlTe,
    // ── CERVEZAS ────────────────────────────────────────────────────────────
    'cerveza':         _urlCerveza,
    'cana':            _urlCerveza,
    'caña':            _urlCerveza,
    'doble':           _urlCerveza,
    'jarra':           _urlCerveza,
    'tercio':          _urlCerveza,
    'mahou':           _urlCerveza,
    'estrella galicia':_urlCerveza,
    'heineken':        _urlCerveza,
    'amstel':          _urlCerveza,
    'coronita':        _urlCerveza,
    'corona':          _urlCerveza,
    'budweiser':       _urlCerveza,
    'bud':             _urlCerveza,
    'alhambra':        _urlCerveza,
    '1906':            _urlCerveza,
    'voll damm':       _urlCerveza,
    // ── VINOS ───────────────────────────────────────────────────────────────
    'vino':            _urlVino,
    'vino tinto':      _urlVino,
    'vino blanco':     _urlVino,
    'vino rosado':     _urlVino,
    'copa vino':       _urlVino,
    'ribera':          _urlVino,
    'rioja':           _urlVino,
    'verdejo':         _urlVino,
    'albarino':        _urlVino,
    'albariño':        _urlVino,
    'lambrusco':       _urlVino,
    'cava':            _urlCava,
    'sangria':         _urlSangria,
    'sangría':         _urlSangria,
    'copa':            _urlVino,
    'chupito':         _urlVino,
    // ── DESAYUNOS ───────────────────────────────────────────────────────────
    'tostada':         _urlPan,
    'pan':             _urlPan,
    'croissant':       _urlCroissant,
    'napolitana':      _urlCroissant,
    'churros':         _urlChurros,
    'porras':          _urlChurros,
    'bocadillo':       _urlBocadillo,
    'sandwich':        _urlBocadillo,
    'sándwich':        _urlBocadillo,
    'bocata':          _urlBocadillo,
    'montadito':       _urlBocadillo,
    'pincho':          _urlPincho,
    // ── TAPAS ───────────────────────────────────────────────────────────────
    'patatas':         _urlPatatas,
    'fritas':          _urlPatatas,
    'patatas fritas':  _urlPatatas,
    'patatas bravas':  _urlPatatas,
    'patatas alioli':  _urlPatatas,
    'nachos':          _urlPatatas,
    'tortilla':        _urlTortilla,
    'croquetas':       _urlCroquetas,
    'jamon':           _urlJamon,
    'jamón':           _urlJamon,
    'jamon iberico':   _urlJamon,
    'jamón ibérico':   _urlJamon,
    'queso':           _urlQueso,
    'ensalada':        _urlEnsalada,
    'ensaladilla':     _urlEnsalada,
    'pizza':           _urlPizza,
    'hamburguesa':     _urlBurger,
    'postre':          _urlHelado,
    'tarta':           _urlHelado,
    'helado':          _urlHelado,
    'calamares':       _urlMarisco,
    'boquerones':      _urlMarisco,
    'gambas':          _urlMarisco,
    'gambas al ajillo':_urlMarisco,
    'sepia':           _urlMarisco,
    'pulpo':           _urlMarisco,
    'pulpo gallega':   _urlMarisco,
    'oreja':           _urlPollo,
    'alitas':          _urlPollo,
    'alitas pollo':    _urlPollo,
    'pollo':           _urlPollo,
    'menu':            _urlChurros,
    'menú':            _urlChurros,
  };

  /// Devuelve la URL de imagen si el nombre del producto coincide con alguna clave.
  String? _imagenAutomatica(String nombreProducto) {
    final normalizado = nombreProducto.toLowerCase().trim();
    // Buscar coincidencia exacta primero
    if (_imagenesTpv.containsKey(normalizado)) return _imagenesTpv[normalizado];
    // Buscar si alguna clave está contenida en el nombre
    for (final entry in _imagenesTpv.entries) {
      if (normalizado.contains(entry.key)) return entry.value;
    }
    return null;
  }

  Color _colorCategoria(String categoria) {
    if (categoria.isEmpty || categoria == 'Todos') return const Color(0xFF444444);
    final idx = categoria.codeUnits.fold(0, (a, b) => a + b) % _paleta.length;
    return _paleta[idx];
  }

  // ── Crear nueva categoría ─────────────────────────────────────────────────
  Future<void> _crearCategoria(BuildContext context) async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.category_outlined, color: Color(0xFFFFA000)),
            SizedBox(width: 8),
            Text('Nueva categoría'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ej: Platos, Bebidas, Postres…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('categorias_tpv')
        .add({'nombre': nombre, 'orden': 0, 'creado': FieldValue.serverTimestamp()});
    if (mounted) widget.onCategoriaChanged(nombre);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tpvPersonalizadoId != null) {
      // ── Con overrides de TPV personalizado ───────────────────────────────
      final ovrRef = FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('tpvs_personalizados').doc(widget.tpvPersonalizadoId!);
      return StreamBuilder<DocumentSnapshot>(
        stream: ovrRef.snapshots(),
        builder: (ctx, snapOvr) {
          final ovr = snapOvr.data?.data() as Map<String, dynamic>? ?? {};
          final ocultos = List<String>.from(ovr['productos_ocultos'] ?? []);
          final imagenes = Map<String, dynamic>.from(ovr['imagenes'] ?? {});
          return StreamBuilder<QuerySnapshot>(
            stream: ovrRef.collection('productos_extra')
                .where('activo', isEqualTo: true).snapshots(),
            builder: (ctx, snapExtras) {
              final extras = (snapExtras.data?.docs ?? []).map((d) {
                final ed = d.data() as Map<String, dynamic>;
                return Producto(
                  id: 'extra_${d.id}',
                  empresaId: widget.empresaId,
                  nombre: ed['nombre'] ?? '',
                  categoria: ed['categoria'] ?? '',
                  precio: (ed['precio'] as num?)?.toDouble() ?? 0,
                  imagenUrl: ed['imagen_url'],
                  thumbnailUrl: null,
                  ivaPorcentaje: (ed['iva_porcentaje'] as num?)?.toDouble() ?? 10,
                  tieneVariantes: false,
                  variantes: [],
                  etiquetas: [],
                  fechaCreacion: DateTime.now(),
                );
              }).toList();
              return _buildCatalogo(ocultos: ocultos, imagenes: imagenes, extras: extras);
            },
          );
        },
      );
    }
    return _buildCatalogo(ocultos: const [], imagenes: const {}, extras: const []);
  }

  Widget _buildCatalogo({
    required List<String> ocultos,
    required Map<String, dynamic> imagenes,
    required List<Producto> extras,
  }) {
    final temaOuter = _TpvRootTemaScope.of(context);
    return Container(
      color: temaOuter.fondo,
      // ── Stream externo: productos activos ────────────────────────────────
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('catalogo')
            .where('activo', isEqualTo: true)
            .snapshots(),
        builder: (context, snapProd) {
          if (!snapProd.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Productos base, aplicando ocultos e imágenes personalizadas
          final productosBase = snapProd.data!.docs
              .where((d) => !ocultos.contains(d.id))
              .map((d) {
            final data = d.data() as Map<String, dynamic>;
            final imgOverride = imagenes[d.id] as String?;
            return Producto(
              id: d.id,
              empresaId: widget.empresaId,
              nombre: data['nombre'] ?? '',
              categoria: data['categoria'] ?? '',
              precio: (data['precio'] as num?)?.toDouble() ?? 0,
              imagenUrl: imgOverride ?? data['imagen_url'],
              thumbnailUrl: imgOverride != null ? null : data['thumbnail_url'],
              ivaPorcentaje: (data['iva_porcentaje'] as num?)?.toDouble() ?? 10,
              tieneVariantes: data['tiene_variantes'] ?? false,
              variantes: ((data['variantes'] as List?) ?? [])
                  .whereType<Map>()
                  .map((v) => VarianteProducto.fromMap(Map<String, dynamic>.from(v)))
                  .toList(),
              etiquetas: [],
              fechaCreacion: DateTime.now(),
            );
          }).toList();

          // Base + extras del TPV personalizado
          final productos = [...productosBase, ...extras];

          // ── Stream interno: categorías explícitas ───────────────────────
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas')
                .doc(widget.empresaId)
                .collection('categorias_tpv')
                .orderBy('orden')
                .snapshots(),
            builder: (context, snapCat) {
              // Categorías explícitas desde Firestore
              final catExplicitas = (snapCat.data?.docs ?? [])
                  .map((d) => (d.data() as Map<String, dynamic>)['nombre'] as String? ?? '')
                  .where((n) => n.isNotEmpty)
                  .toList();

              // Categorías de productos (mantener las que no están ya)
              final catProductos = productos.map((p) => p.categoria).where((c) => c.isNotEmpty).toSet();

              // Merge: explícitas primero, luego las derivadas de productos
              final Set<String> catMerge = {'Todos', ...catExplicitas};
              for (final c in catProductos) {
                catMerge.add(c);
              }
              final categorias = catMerge.toList();

              // Filtro
              final productosFiltrados = productos.where((p) {
                if (widget.categoriaFiltro != 'Todos' && p.categoria != widget.categoriaFiltro) return false;
                if (widget.busqueda.isNotEmpty &&
                    !p.nombre.toLowerCase().contains(widget.busqueda.toLowerCase())) return false;
                return true;
              }).toList();

              final tema = _TpvRootTemaScope.of(context);
              return Column(
                children: [
                  // ── Cabecera ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    decoration: BoxDecoration(
                      color: tema.superficie,
                      border: Border(bottom: BorderSide(color: tema.borde)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storefront, size: 14, color: tema.primario),
                            const SizedBox(width: 6),
                            Text('CATÁLOGO',
                                style: TextStyle(
                                    color: tema.textoMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4)),
                            const Spacer(),
                            _SelectorColumnas(
                              columnas: _columnas,
                              onChanged: (n) => setState(() => _columnas = n),
                            ),
                            const SizedBox(width: 4),
                            if (widget.esAdmin)
                              IconButton(
                                icon: Icon(Icons.add_circle_outline,
                                    color: tema.primario, size: 18),
                                tooltip: 'Nuevo producto',
                                onPressed: () =>
                                    _mostrarDialogoNuevoProducto(context, widget.empresaId),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // ── Buscador + scanner ────────────────────────────
                        SizedBox(
                          height: 32,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: widget.onBusquedaChanged,
                                  style: TextStyle(color: tema.texto, fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: 'Buscar producto…',
                                    hintStyle: TextStyle(color: tema.textoMuted, fontSize: 12),
                                    prefixIcon: Icon(Icons.search, size: 16, color: tema.textoMuted),
                                    suffixIcon: widget.busqueda.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.clear, size: 14, color: tema.textoMuted),
                                            onPressed: () => widget.onBusquedaChanged(''),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: tema.fondo,
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // ── Botón scanner de código de barras ────────
                              Tooltip(
                                message: 'Escanear código de barras',
                                child: InkWell(
                                  onTap: () => _abrirScanner(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: tema.superficie,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: tema.primario.withValues(alpha: 0.4)),
                                    ),
                                    child: Icon(Icons.qr_code_scanner,
                                        size: 18, color: tema.primario),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Barra de categorías ───────────────────────────────
                  _BarraCategorias(
                    categorias: categorias,
                    seleccionada: widget.categoriaFiltro,
                    esAdmin: widget.esAdmin,
                    colorCategoria: _colorCategoria,
                    onSeleccionada: widget.onCategoriaChanged,
                    onCrearCategoria: () => _crearCategoria(context),
                  ),
                  // ── Grid 4 columnas ───────────────────────────────────
                  Expanded(
                    child: productosFiltrados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    size: 48, color: tema.textoMuted.withValues(alpha: 0.2)),
                                const SizedBox(height: 8),
                                Text(
                                  widget.busqueda.isNotEmpty ? 'Sin resultados' : 'Sin productos',
                                  style: TextStyle(color: tema.textoMuted, fontSize: 13),
                                ),
                                if (widget.esAdmin && widget.busqueda.isEmpty) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _mostrarDialogoNuevoProducto(context, widget.empresaId),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Añadir primero'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (ctx, constraints) {
                              final colW = (constraints.maxWidth - 16 - (_columnas - 1) * 6) / _columnas;
                              // Área de texto: nombre (10px) + precio (13px) + padding vertical 4px
                              // + line-height buffer = 36px mínimo real
                              // El área de texto ocupa flex 2 de 11 total (≈18.18%)
                              const minTextH = 36.0;
                              const textFraction = 2.0 / 11.0;
                              // Ratio máximo permitido para que el texto nunca desborde
                              final maxAllowedRatio = colW / (minTextH / textFraction);
                              final idealRatio = colW / (colW / 0.58 + 1);
                              // Usar el ratio más pequeño (tarjetas más altas) si hace falta
                              final ratio = (idealRatio < maxAllowedRatio ? idealRatio : maxAllowedRatio)
                                  .clamp(0.20, 0.70);
                              return GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columnas,
                              childAspectRatio: ratio,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                            itemCount: productosFiltrados.length,
                            itemBuilder: (context, idx) {
                              final producto = productosFiltrados[idx];
                              return _ProductoCardBar(
                                producto: producto,
                                colorCategoria: _colorCategoria(producto.categoria),
                                imagenAutoUrl: _imagenAutomatica(producto.nombre),
                                onTap: () async {
                                  if (producto.tieneVariantes &&
                                      producto.variantesDisponibles.isNotEmpty) {
                                    final variante = await VarianteSelectorWidget.mostrar(
                                      context,
                                      producto: producto,
                                    );
                                    if (variante != null) {
                                      widget.onProductoSeleccionado(producto, variante);
                                    }
                                  } else {
                                    widget.onProductoSeleccionado(producto, null);
                                  }
                                },
                                onLongPress: widget.esAdmin
                                    ? () => _mostrarMenuContextualProducto(
                                        context, widget.empresaId, producto)
                                    : null,
                                onGuardarImagenDefecto: widget.esAdmin
                                    ? (url) => _guardarImagenDefecto(
                                        widget.empresaId, producto.id, url)
                                    : null,
                              );
                            },
                          );  // GridView
                            }, // LayoutBuilder builder
                          ), // LayoutBuilder
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _abrirScanner(BuildContext context) async {
    final ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2139),
        contentPadding: EdgeInsets.zero,
        title: const Row(children: [
          Icon(Icons.qr_code_scanner, color: Color(0xFF00FFC8), size: 20),
          SizedBox(width: 8),
          Text('Escanear código', style: TextStyle(color: Colors.white, fontSize: 15)),
        ]),
        content: SizedBox(
          width: 300,
          height: 260,
          child: MobileScanner(
            controller: ctrl,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                ctrl.dispose();
                Navigator.pop(ctx, barcode!.rawValue);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { ctrl.dispose(); Navigator.pop(ctx); },
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
    if (resultado != null && resultado.isNotEmpty && mounted) {
      widget.onBusquedaChanged(resultado);
    }
  }

  Future<void> _guardarImagenDefecto(
      String empresaId, String productoId, String url) async {
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('catalogo')
        .doc(productoId)
        .update({'imagen_url': url, 'thumbnail_url': url});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Imagen guardada como predeterminada'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ── Widget selector de columnas ───────────────────────────────────────────────
class _SelectorColumnas extends StatelessWidget {
  final int columnas;
  final ValueChanged<int> onChanged;

  const _SelectorColumnas({required this.columnas, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tema = _TpvRootTemaScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [3, 4].map((n) {
        final sel = columnas == n;
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Tooltip(
            message: '$n columnas',
            child: InkWell(
              onTap: () => onChanged(n),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                width: 26,
                height: 22,
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFFFFA000).withValues(alpha: 0.2)
                      : tema.superficie,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: sel ? const Color(0xFFFFA000) : tema.borde,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: sel ? const Color(0xFFFFA000) : tema.textoMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Barra de categorías con botón + ──────────────────────────────────────────

class _BarraCategorias extends StatelessWidget {
  final List<String> categorias;
  final String seleccionada;
  final bool esAdmin;
  final Color Function(String) colorCategoria;
  final ValueChanged<String> onSeleccionada;
  final VoidCallback onCrearCategoria;

  const _BarraCategorias({
    required this.categorias,
    required this.seleccionada,
    required this.esAdmin,
    required this.colorCategoria,
    required this.onSeleccionada,
    required this.onCrearCategoria,
  });

  @override
  Widget build(BuildContext context) {
    final tema = _TpvRootTemaScope.of(context);
    return Container(
      height: 78,
      color: tema.superficie,
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      child: Row(
        children: [
          // ── Grid 2 filas × scroll horizontal ─────────────────────────
          Expanded(
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 5,
                mainAxisSpacing: 6,
                childAspectRatio: 0.36,
              ),
              itemCount: categorias.length,
              itemBuilder: (_, i) {
                final cat = categorias[i];
                final sel = seleccionada == cat;
                final color = colorCategoria(cat);
                return GestureDetector(
                  onTap: () => onSeleccionada(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: sel ? color : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: sel ? color : color.withValues(alpha: 0.3),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sel ? Colors.white : tema.textoMuted,
                        fontSize: 11,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // ── Botón crear categoría (admin) ─────────────────────────────
          if (esAdmin)
            Tooltip(
              message: 'Nueva categoría',
              child: InkWell(
                onTap: onCrearCategoria,
                child: Container(
                  width: 32,
                  height: double.infinity,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: tema.fondo,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFFFFA000).withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.add, size: 16, color: Color(0xFFFFA000)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── NUEVO: menú contextual producto (editar / desactivar) ─────────────────
void _mostrarMenuContextualProducto(
    BuildContext context, String empresaId, Producto producto) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E2139),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(producto.nombre,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        const Divider(color: Color(0xFF2A2E45), height: 1),
        ListTile(
          leading: const Icon(Icons.edit, color: Color(0xFF00FFC8)),
          title: const Text('Editar producto',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(ctx);
            _mostrarDialogoEditarProducto(context, empresaId, producto);
          },
        ),
        ListTile(
          leading: const Icon(Icons.visibility_off, color: Colors.orange),
          title: const Text('Desactivar (ocultar)',
              style: TextStyle(color: Colors.white)),
          onTap: () async {
            await FirebaseFirestore.instance
                .collection('empresas')
                .doc(empresaId)
                .collection('catalogo')
                .doc(producto.id)
                .update({'activo': false});
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

// ── NUEVO: editar producto existente ─────────────────────────────────────
Future<void> _mostrarDialogoEditarProducto(
    BuildContext context, String empresaId, Producto producto) async {
  final nombreCtrl = TextEditingController(text: producto.nombre);
  final precioCtrl =
  TextEditingController(text: producto.precio.toStringAsFixed(2));
  final categoriaCtrl = TextEditingController(text: producto.categoria);
  double iva = producto.ivaPorcentaje;
  final ivaCtrl = TextEditingController(
      text: iva == iva.truncateToDouble() ? iva.toInt().toString() : iva.toString());

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setS) => AlertDialog(
        title: const Text('Editar producto'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio (€)',
                  prefixIcon: Icon(Icons.euro),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoriaCtrl,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setS(() {}),
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Ej: Bebidas, Tapas…',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('IVA:'),
                  const SizedBox(width: 12),
                  ...[4, 10, 21].map((p) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$p%'),
                      selected: iva == p,
                      onSelected: (_) => setS(() {
                        iva = p.toDouble();
                        ivaCtrl.text = p.toString();
                      }),
                      selectedColor: const Color(0xFFFFA000),
                      labelStyle: TextStyle(
                        color: iva == p ? Colors.black : null,
                        fontWeight: iva == p ? FontWeight.w700 : null,
                      ),
                    ),
                  )),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: ivaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        suffixText: '%',
                        isDense: true,
                        hintText: 'otro',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        if (val != null && val >= 0 && val <= 100) {
                          setS(() => iva = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final precio = double.tryParse(
                  precioCtrl.text.replaceAll(',', '.')) ??
                  0;
              if (nombreCtrl.text.trim().isEmpty || precio <= 0) return;
              await FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .collection('catalogo')
                  .doc(producto.id)
                  .update({
                'nombre': nombreCtrl.text.trim(),
                'precio': precio,
                'categoria': categoriaCtrl.text.trim().isEmpty
                    ? 'General'
                    : categoriaCtrl.text.trim(),
                'iva_porcentaje': iva,
              });
              if (ctx2.mounted) Navigator.pop(ctx2);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

class _ProductoCardBar extends StatelessWidget {
  final Producto producto;
  final Color colorCategoria;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  /// URL de imagen automática (de la biblioteca interna, si coincide el nombre)
  final String? imagenAutoUrl;
  /// Callback para guardar la imagen auto como predeterminada en Firestore
  final void Function(String url)? onGuardarImagenDefecto;

  const _ProductoCardBar({
    required this.producto,
    required this.colorCategoria,
    required this.onTap,
    this.onLongPress,
    this.imagenAutoUrl,
    this.onGuardarImagenDefecto,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final inicial = producto.nombre.isNotEmpty
        ? producto.nombre[0].toUpperCase()
        : '?';
    final tieneImagenPropia =
        producto.thumbnailUrl != null || producto.imagenUrl != null;
    // Usar imagen propia si existe; si no, usar la automática de la biblioteca
    final urlImagen = tieneImagenPropia
        ? (producto.thumbnailUrl ?? producto.imagenUrl!)
        : imagenAutoUrl;
    final usandoImagenAuto = !tieneImagenPropia && imagenAutoUrl != null;

    final tema = _TpvRootTemaScope.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: tema.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: usandoImagenAuto
                ? const Color(0xFFFFA000).withValues(alpha: 0.4)
                : tema.borde,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Área imagen / color ───────────────────────────────────
            Expanded(
              flex: 9,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(7)),
                    child: urlImagen != null
                        ? CachedNetworkImage(
                            imageUrl: urlImagen,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (_, __) => _inicialBox(colorCategoria, inicial),
                            errorWidget: (_, __, ___) => _inicialBox(colorCategoria, inicial),
                            memCacheWidth: 400,
                            memCacheHeight: 400,
                          )
                        : _inicialBox(colorCategoria, inicial),
                  ),
                  // Indicador + botón guardar cuando se usa imagen automática
                  if (usandoImagenAuto && onGuardarImagenDefecto != null)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Tooltip(
                        message: 'Guardar como imagen por defecto',
                        child: GestureDetector(
                          onTap: () => onGuardarImagenDefecto!(imagenAutoUrl!),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.save_alt,
                                size: 12, color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Datos ─────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          producto.nombre,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: tema.texto,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Badge barra
                      if (producto.destino == 'barra')
                        const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Tooltip(
                            message: 'Va a barra',
                            child: Icon(Icons.local_bar_rounded,
                                size: 10, color: Color(0xFFFF3296)),
                          ),
                        ),
                      // Badge alergenos
                      if (producto.alergenos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Tooltip(
                            message: 'Contiene alergenos',
                            child: Container(
                              width: 12, height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('!',
                                    style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black)),
                              ),
                            ),
                          ),
                        ),
                    ]),
                    Text(
                      fmt.format(producto.precio),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: tema.primario == const Color(0xFF00FFC8)
                            ? const Color(0xFF059669)  // verde oscuro en modo claro (legible)
                            : const Color(0xFF00FFC8), // cian en modo oscuro
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inicialBox(Color color, String inicial) {
    return Container(
      color: color.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          inicial,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO: NUEVA MESA
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoNuevaMesa extends StatefulWidget {
  final String empresaId;
  final List<String> zonasExistentes;
  final String? empleadoUid;
  final String? empleadoNombre;
  final String? zonaInicial;

  const _DialogoNuevaMesa({
    required this.empresaId,
    required this.zonasExistentes,
    this.empleadoUid,
    this.empleadoNombre,
    this.zonaInicial,
  });

  @override
  State<_DialogoNuevaMesa> createState() => _DialogoNuevaMesaState();
}

class _DialogoNuevaMesaState extends State<_DialogoNuevaMesa> {
  final _numeroCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  String _zona = '';
  int _capacidad = 4;

  @override
  void initState() {
    super.initState();
    if (widget.zonaInicial != null && widget.zonaInicial!.isNotEmpty) {
      _zona = widget.zonaInicial!;
    } else {
      final zonasFiltradas =
          widget.zonasExistentes.where((z) => z != 'Todas').toList();
      _zona = zonasFiltradas.isNotEmpty ? zonasFiltradas.first : 'Salón';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Mesa'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de asignación
            if (widget.empleadoUid != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFC8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00FFC8).withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.person_pin, size: 16, color: Color(0xFF00FFC8)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Asignada a: ${widget.empleadoNombre ?? widget.empleadoUid}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF00FFC8), fontWeight: FontWeight.w600),
                  )),
                ]),
              ),
            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nombre de la mesa *',
                  hintText: 'Ej: Mesa 1, Terraza, Barra, VIP…'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numeroCtrl,
              decoration: const InputDecoration(
                  labelText: 'Número (opcional)', hintText: '1'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _zona,
              decoration: const InputDecoration(labelText: 'Zona'),
              items: [
                ...{_zona, ...widget.zonasExistentes.where((z) => z != 'Todas')}
                    .map((z) => DropdownMenuItem(value: z, child: Text(z))),
                const DropdownMenuItem(
                    value: '__nueva__', child: Text('+ Nueva zona…')),
              ],
              onChanged: (v) {
                if (v == '__nueva__') {
                  _pedirNuevaZona(context);
                } else if (v != null) {
                  setState(() => _zona = v);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Capacidad:'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed:
                  _capacidad > 1 ? () => setState(() => _capacidad--) : null,
                ),
                Text('$_capacidad',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _capacidad < 20
                      ? () => setState(() => _capacidad++)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      // Mostrar error si falta el nombre
      return;
    }
    final numero = int.tryParse(_numeroCtrl.text.trim()) ?? 0;

    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas')
        .add({
      'numero': numero,
      'nombre': nombre,
      'zona': _zona,
      'capacidad': _capacidad,
      'estado': 'libre',
      'comanda_id': null,
      'camarero_uid': null,
      'fecha_apertura': null,
      // Asignación permanente al empleado seleccionado (null = visible para todos)
      'asignado_a_uid': widget.empleadoUid,
      'asignado_a_nombre': widget.empleadoNombre,
    });

    if (mounted) Navigator.pop(context);
  }

  void _pedirNuevaZona(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Nueva zona'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre de la zona',
            hintText: 'Ej: Terraza, Bar, Privado…',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final zona = ctrl.text.trim();
              if (zona.isNotEmpty) setState(() => _zona = zona);
              Navigator.pop(ctx);
            },
            child: const Text('Crear zona'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO: NUEVO PRODUCTO
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _mostrarDialogoNuevoProducto(
    BuildContext context, String empresaId) async {
  await showDialog(
    context: context,
    builder: (_) => _DialogoNuevoProducto(empresaId: empresaId),
  );
}

class _DialogoNuevoProducto extends StatefulWidget {
  final String empresaId;
  const _DialogoNuevoProducto({required this.empresaId});

  @override
  State<_DialogoNuevoProducto> createState() => _DialogoNuevoProductoState();
}

class _DialogoNuevoProductoState extends State<_DialogoNuevoProducto> {
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();
  final _ivaCtrl = TextEditingController(text: '10');
  double _iva = 10;
  bool _guardando = false;
  List<String> _categorias = [];

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    final db = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId);

    final results = await Future.wait([
      // Categorías explícitas (categorias_tpv)
      db.collection('categorias_tpv').orderBy('orden').get(),
      // Categorías derivadas de productos en catálogo
      db.collection('catalogo').where('activo', isEqualTo: true).get(),
    ]);

    final Set<String> cats = {};

    for (final doc in results[0].docs) {
      final n = (doc.data()['nombre'] as String?) ?? '';
      if (n.isNotEmpty) cats.add(n);
    }
    for (final doc in results[1].docs) {
      final c = (doc.data()['categoria'] as String?) ?? '';
      if (c.isNotEmpty) cats.add(c);
    }

    if (mounted) setState(() => _categorias = cats.toList());
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _categoriaCtrl.dispose();
    _ivaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_shopping_cart, color: Color(0xFFFFA000)),
          SizedBox(width: 8),
          Text('Nuevo producto'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _precioCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio (€) *',
                  prefixIcon: Icon(Icons.euro_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoriaCtrl,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Ej: Bebidas, Tapas…',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              if (_categorias.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _categorias.map((cat) {
                    final sel = _categoriaCtrl.text == cat;
                    return ActionChip(
                      label: Text(cat, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: sel
                          ? const Color(0xFFFFA000).withValues(alpha: 0.2)
                          : null,
                      side: sel
                          ? const BorderSide(color: Color(0xFFFFA000))
                          : null,
                      onPressed: () =>
                          setState(() => _categoriaCtrl.text = cat),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('IVA:'),
                  const SizedBox(width: 12),
                  ...[4, 10, 21].map((p) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$p%'),
                      selected: _iva == p,
                      onSelected: (_) => setState(() {
                        _iva = p.toDouble();
                        _ivaCtrl.text = p.toString();
                      }),
                      selectedColor: const Color(0xFFFFA000),
                      labelStyle: TextStyle(
                        color: _iva == p ? Colors.black : null,
                        fontWeight: _iva == p ? FontWeight.w700 : null,
                      ),
                    ),
                  )),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _ivaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        suffixText: '%',
                        isDense: true,
                        hintText: 'otro',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        if (val != null && val >= 0 && val <= 100) {
                          setState(() => _iva = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _guardando ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFA000)),
          child: _guardando
              ? const SizedBox(
              width: 16,
              height: 16,
              child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Guardar',
              style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final precio =
        double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0;
    if (nombre.isEmpty || precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nombre y precio son obligatorios'),
            backgroundColor: Colors.orange),
      );
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
        'categoria': _categoriaCtrl.text.trim().isEmpty
            ? 'General'
            : _categoriaCtrl.text.trim(),
        'iva_porcentaje': _iva,
        'activo': true,
        'tiene_variantes': false,
        'variantes': [],
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('✅ "$nombre" añadido al catálogo'),
              backgroundColor: Colors.green.shade700),
        );
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
// DIÁLOGO: MÉTODO DE PAGO
// ═══════════════════════════════════════════════════════════════════════════

class _DialogoMetodoPago extends StatefulWidget {
  final double total;
  final String empresaId;
  final bool mostrarPropina;
  const _DialogoMetodoPago({
    required this.total,
    required this.empresaId,
    this.mostrarPropina = true,
  });

  @override
  State<_DialogoMetodoPago> createState() => _DialogoMetodoPagoState();
}

class _DialogoMetodoPagoState extends State<_DialogoMetodoPago> {
  String _metodo = 'efectivo';
  final _entregaCtrl = TextEditingController();
  final _efectivoMixtoCtrl = TextEditingController();
  final _tarjetaMixtoCtrl = TextEditingController();
  double _cambio = 0;

  // Propina
  double _propina = 0.0;
  final _propinaCtrl = TextEditingController();

  // Métodos extra (Bizum, Transferencia, etc. desde config)
  List<({String id, String emoji, String label})> _metodosExtra = const [];

  // Split bill
  int _splitPersonas = 2;
  late List<TextEditingController> _splitCtrls;

  // Terminal física
  bool _terminalProcesando = false;
  String _terminalEstado = '';
  String? _terminalError;

  double get _totalFinal => widget.total + _propina;
  double get _efectivoMixto =>
      double.tryParse(_efectivoMixtoCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _tarjetaMixto =>
      double.tryParse(_tarjetaMixtoCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _restoMixto =>
      (_totalFinal - _efectivoMixto - _tarjetaMixto);

  @override
  void initState() {
    super.initState();
    final importe = (widget.total / _splitPersonas).toStringAsFixed(2);
    _splitCtrls = List.generate(_splitPersonas, (_) => TextEditingController(text: importe));
    _cargarMetodosExtra();
    // Recalcular split cuando cambia la propina
  }

  Future<void> _cargarMetodosExtra() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('tpv_cobro').get();
      if (!doc.exists || !mounted) return;
      final habilitados = (doc.data()?['metodos_habilitados'] as List?)
          ?.map((e) => e.toString()).toSet() ?? {};
      const candidatos = [
        (id: 'bizum',         emoji: '📱', label: 'Bizum'),
        (id: 'transferencia', emoji: '🏦', label: 'Transferencia'),
        (id: 'cheque_regalo', emoji: '🎁', label: 'Cheque regalo'),
      ];
      setState(() => _metodosExtra = candidatos.where((m) => habilitados.contains(m.id)).toList());
    } catch (_) {}
  }

  Future<void> _iniciarCobroTerminal() async {
    setState(() { _terminalProcesando = true; _terminalEstado = 'procesando'; _terminalError = null; });
    final resultado = await TerminalFisicaService().cobrar(
      widget.total,
      descripcion: 'Venta TPV ${widget.total.toStringAsFixed(2)}€',
    );
    if (!mounted) return;
    if (resultado.esManual) {
      setState(() { _terminalProcesando = false; _terminalEstado = 'manual'; });
    } else if (resultado.exito) {
      setState(() { _terminalProcesando = false; _terminalEstado = 'exito'; });
    } else {
      setState(() { _terminalProcesando = false; _terminalEstado = 'error'; _terminalError = resultado.error; });
    }
  }

  void _setSplitPersonas(int n) {
    for (final c in _splitCtrls) c.dispose();
    final importe = (_totalFinal / n).toStringAsFixed(2);
    setState(() {
      _splitPersonas = n;
      _splitCtrls = List.generate(n, (_) => TextEditingController(text: importe));
    });
  }

  double get _totalSplit => _splitCtrls.fold(0.0, (s, c) => s + (double.tryParse(c.text.replaceAll(',', '.')) ?? 0));

  @override
  void dispose() {
    _entregaCtrl.dispose();
    _propinaCtrl.dispose();
    _efectivoMixtoCtrl.dispose();
    _tarjetaMixtoCtrl.dispose();
    for (final c in _splitCtrls) c.dispose();
    super.dispose();
  }

  void _calcularCambio(String val) {
    final entrega = double.tryParse(val.replaceAll(',', '.')) ?? 0;
    setState(() =>
    _cambio = (entrega - widget.total).clamp(0, double.infinity));
  }

  void _autoRellenarTarjeta() {
    final ef = _efectivoMixto;
    if (ef >= 0 && ef <= widget.total) {
      final resto = widget.total - ef;
      _tarjetaMixtoCtrl.text = resto.toStringAsFixed(2);
      setState(() {});
    }
  }

  void _autoRellenarEfectivo() {
    final ta = _tarjetaMixto;
    if (ta >= 0 && ta <= widget.total) {
      final resto = widget.total - ta;
      _efectivoMixtoCtrl.text = resto.toStringAsFixed(2);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Método de pago'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('Total',
                      style: TextStyle(
                          fontSize: 12, color: cs.onPrimaryContainer)),
                  Text(
                    '${(widget.total + _propina).toStringAsFixed(2)} €',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer),
                  ),
                  if (_propina > 0)
                    Text('incl. propina ${_propina.toStringAsFixed(2)} €',
                        style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
                ],
              ),
            ),
            // ── Propina ──────────────────────────────────────────────────────
            if (widget.mostrarPropina) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _propinaCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onChanged: (v) => setState(() => _propina = double.tryParse(v.replaceAll(',', '.')) ?? 0),
                decoration: const InputDecoration(
                  labelText: 'Propina (opcional)',
                  prefixIcon: Icon(Icons.volunteer_activism),
                  suffixText: '€',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [1.0, 2.0, 5.0].map((v) =>
                ActionChip(
                  label: Text('$v €', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() { _propina = v; _propinaCtrl.text = v.toString(); }),
                )).toList()),
            ],
            const SizedBox(height: 12),
            // ── Métodos principales ───────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _PagoChip(
                    label: 'Efectivo',
                    icon: Icons.payments_outlined,
                    selected: _metodo == 'efectivo',
                    onTap: () => setState(() => _metodo = 'efectivo'))),
                const SizedBox(width: 8),
                Expanded(child: _PagoChip(
                    label: 'Tarjeta',
                    icon: Icons.credit_card,
                    selected: _metodo == 'tarjeta',
                    onTap: () => setState(() => _metodo = 'tarjeta'))),
                const SizedBox(width: 8),
                Expanded(child: _PagoChip(
                    label: 'Mixto',
                    icon: Icons.swap_horiz,
                    selected: _metodo == 'mixto',
                    onTap: () => setState(() => _metodo = 'mixto'))),
                const SizedBox(width: 8),
                Expanded(child: _PagoChip(
                    label: 'Split',
                    icon: Icons.group,
                    selected: _metodo == 'split',
                    onTap: () => setState(() => _metodo = 'split'))),
                const SizedBox(width: 8),
                Expanded(child: _PagoChip(
                    label: 'Terminal',
                    icon: Icons.credit_score,
                    selected: _metodo == 'terminal',
                    onTap: () => setState(() {
                      _metodo = 'terminal';
                      _terminalEstado = '';
                      _terminalError = null;
                    }))),
              ],
            ),
            // ── Métodos extra (Bizum, Transferencia…) ────────────────────────
            if (_metodosExtra.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: _metodosExtra.map((m) {
                final icons = {
                  'bizum': Icons.qr_code,
                  'transferencia': Icons.account_balance,
                  'cheque_regalo': Icons.card_giftcard,
                };
                return _PagoChip(
                  label: '${m.emoji} ${m.label}',
                  icon: icons[m.id] ?? Icons.payment,
                  selected: _metodo == m.id,
                  onTap: () => setState(() => _metodo = m.id),
                );
              }).toList()),
            ],
            const SizedBox(height: 16),
            if (_metodo == 'efectivo') ...[
              TextField(
                controller: _entregaCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Entrega del cliente (€)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                onChanged: _calcularCambio,
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
                      Text(
                        '${_cambio.toStringAsFixed(2)} €',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                            fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (_metodo == 'mixto') ...[
              // Campo efectivo
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _efectivoMixtoCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Efectivo (€)',
                        prefixIcon: Icon(Icons.payments_outlined),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Rellenar con el resto',
                    child: IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: _autoRellenarEfectivo,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Campo tarjeta
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tarjetaMixtoCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Tarjeta (€)',
                        prefixIcon: Icon(Icons.credit_card),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Rellenar con el resto',
                    child: IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: _autoRellenarTarjeta,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Indicador en tiempo real
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _restoMixto.abs() < 0.01
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _restoMixto.abs() < 0.01
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _restoMixto.abs() < 0.01
                          ? Icons.check_circle
                          : Icons.info_outline,
                      size: 16,
                      color: _restoMixto.abs() < 0.01
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _restoMixto.abs() < 0.01
                          ? Text(
                              'Pago completo ✓  '
                              '${_efectivoMixto.toStringAsFixed(2)} € efectivo + '
                              '${_tarjetaMixto.toStringAsFixed(2)} € tarjeta',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.green.shade700),
                            )
                          : Text(
                              _restoMixto > 0
                                  ? 'Falta ${_restoMixto.toStringAsFixed(2)} € por asignar'
                                  : 'Exceso de ${(-_restoMixto).toStringAsFixed(2)} €',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange.shade700),
                            ),
                    ),
                  ],
                ),
              ),
            ],
            if (_metodo == 'tarjeta') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text('Cobro por datáfono',
                      style: TextStyle(fontSize: 13, color: cs.primary)),
                ],
              ),
            ],
            if (_metodo == 'split') ...[
              const SizedBox(height: 12),
              Row(children: [
                const Text('Personas:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                ...[2, 3, 4, 5, 6].map((n) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('$n'),
                    selected: _splitPersonas == n,
                    onSelected: (_) => _setSplitPersonas(n),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(
                      color: _splitPersonas == n ? cs.onPrimaryContainer : null,
                      fontWeight: _splitPersonas == n ? FontWeight.bold : null,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )),
              ]),
              const SizedBox(height: 10),
              ...List.generate(_splitPersonas, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _splitCtrls[i],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Persona ${i + 1} (€)',
                        isDense: true,
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                      ),
                    ),
                  ),
                ]),
              )),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (_totalSplit - _totalFinal).abs() < 0.01
                      ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_totalSplit - _totalFinal).abs() < 0.01
                        ? Colors.green.shade300 : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (_totalSplit - _totalFinal).abs() < 0.01
                          ? '✓ Suma correcta'
                          : 'Falta ${(_totalFinal - _totalSplit).toStringAsFixed(2)} € por repartir',
                      style: TextStyle(
                        fontSize: 12,
                        color: (_totalSplit - _totalFinal).abs() < 0.01
                            ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    Text('${_totalSplit.toStringAsFixed(2)} / ${_totalFinal.toStringAsFixed(2)} €',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
            if (_metodo == 'terminal') ...[
              const SizedBox(height: 16),
              _UiTerminalFisica(
                total: _totalFinal,
                estado: _terminalEstado,
                error: _terminalError,
                procesando: _terminalProcesando,
                onIniciarCobro: _iniciarCobroTerminal,
                onConfirmarManual: () => setState(() => _terminalEstado = 'exito'),
                onRechazar: () => setState(() { _terminalEstado = 'error'; _terminalError = 'Pago rechazado'; }),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _metodo == 'terminal' && _terminalEstado != 'exito' ? null : () {
            double efectivo = 0, tarjeta = 0;
            if (_metodo == 'efectivo') {
              efectivo = _totalFinal;
            } else if (_metodo == 'tarjeta') {
              tarjeta = _totalFinal;
            } else if (_metodo == 'terminal') {
              tarjeta = _totalFinal;
            } else if (_metodo == 'split') {
              if ((_totalSplit - _totalFinal).abs() > 0.01) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Los importes del split no suman el total')),
                );
                return;
              }
              efectivo = _totalFinal;
            } else {
              efectivo = double.tryParse(
                  _efectivoMixtoCtrl.text.replaceAll(',', '.')) ??
                  0;
              tarjeta = double.tryParse(
                  _tarjetaMixtoCtrl.text.replaceAll(',', '.')) ??
                  0;
              if ((efectivo + tarjeta - _totalFinal).abs() > 0.01) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Los importes no suman el total')),
                );
                return;
              }
            }
            Navigator.pop(context, {
              'metodo': _metodo,
              'importe_efectivo': efectivo,
              'importe_tarjeta': tarjeta,
              'propina': _propina,
              'total_final': _totalFinal,
              if (_metodo == 'split') ...{
                'split_personas': _splitPersonas,
                'split_importes': _splitCtrls.map((c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0).toList(),
              },
              // Métodos extra (Bizum, Transferencia, etc.)
              if (_metodosExtra.any((m) => m.id == _metodo))
                'importes': <String, double>{_metodo: _totalFinal},
            });
          },
          child: Text('Confirmar cobro ${_totalFinal.toStringAsFixed(2)} €'),
        ),
      ],
    );
  }
}

class _PagoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PagoChip(
      {required this.label,
        required this.icon,
        required this.selected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // No retorna Expanded: el widget se usa tanto en Row como en Wrap.
    // El Expanded lo añade el padre cuando sea necesario (call site en Row).
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UI TERMINAL FÍSICA
// ═══════════════════════════════════════════════════════════════════════════

class _UiTerminalFisica extends StatelessWidget {
  final double total;
  final String estado; // '', 'procesando', 'manual', 'exito', 'error'
  final bool procesando;
  final String? error;
  final VoidCallback onIniciarCobro;
  final VoidCallback onConfirmarManual;
  final VoidCallback onRechazar;

  const _UiTerminalFisica({
    required this.total,
    required this.estado,
    required this.procesando,
    required this.onIniciarCobro,
    required this.onConfirmarManual,
    required this.onRechazar,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2, locale: 'es_ES');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorFondo(cs),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorBorde(cs)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Importe grande
          Text(
            fmt.format(total),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: _colorImporte(cs),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          // Estado
          if (estado.isEmpty) ...[
            Text('Pulsa "Cobrar en terminal" para enviar el importe al datáfono',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onIniciarCobro,
                icon: const Icon(Icons.credit_score, size: 18),
                label: const Text('Cobrar en terminal'),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else if (estado == 'procesando') ...[
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Procesando pago en el terminal…',
                style: TextStyle(fontSize: 13)),
            const Text('El cliente debe introducir la tarjeta en el datáfono',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ] else if (estado == 'manual') ...[
            const SizedBox(height: 4),
            Text('Cobra este importe en tu datáfono y confirma aquí',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRechazar,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Rechazado'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConfirmarManual,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Cobrado ✓'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ]),
          ] else if (estado == 'exito') ...[
            const SizedBox(height: 4),
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 36),
            const SizedBox(height: 4),
            const Text('¡Pago completado!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            Text('Pulsa "Confirmar cobro" para cerrar la mesa',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ] else if (estado == 'error') ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(height: 4),
            Text(error ?? 'Error en el terminal',
                style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onIniciarCobro,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }

  Color _colorFondo(ColorScheme cs) {
    if (estado == 'exito') return Colors.green.shade50;
    if (estado == 'error') return Colors.red.shade50;
    return cs.surfaceVariant.withValues(alpha: 0.4);
  }

  Color _colorBorde(ColorScheme cs) {
    if (estado == 'exito') return Colors.green.shade300;
    if (estado == 'error') return Colors.red.shade300;
    if (estado == 'manual') return cs.primary.withValues(alpha: 0.4);
    return cs.outline.withValues(alpha: 0.3);
  }

  Color _colorImporte(ColorScheme cs) {
    if (estado == 'exito') return Colors.green.shade700;
    if (estado == 'error') return Colors.red.shade700;
    return cs.onSurface;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CIERRE DE CAJA
// ═══════════════════════════════════════════════════════════════════════════

class _CierreDeCaja extends StatefulWidget {
  final String empresaId;
  const _CierreDeCaja({required this.empresaId});

  @override
  State<_CierreDeCaja> createState() => _CierreDeCajaState();
}

class _CierreDeCajaState extends State<_CierreDeCaja> {
  Map<String, dynamic>? _datos;
  bool _cargando = true;
  bool _cerrando = false;
  final _efectivoRealCtrl = TextEditingController();
  double _fondoInicial = 0;

  @override
  void dispose() {
    _efectivoRealCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));

    // Buscar apertura del día para mostrar fondo inicial
    final aperturasSnap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('aperturas_caja')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .orderBy('fecha', descending: true)
        .limit(1)
        .get();

    _fondoInicial = aperturasSnap.docs.isNotEmpty
        ? (aperturasSnap.docs.first.data()['fondo_inicial'] as num?)
                ?.toDouble() ??
            0.0
        : 0.0;

    final snapHoy = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('pedidos')
        .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_hora', isLessThan: Timestamp.fromDate(fin))
        .where('estado_pago', isEqualTo: 'pagado')
        .get();

    final inicioAyer = inicio.subtract(const Duration(days: 1));
    final snapAyer = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('pedidos')
        .where('fecha_hora',
        isGreaterThanOrEqualTo: Timestamp.fromDate(inicioAyer))
        .where('fecha_hora', isLessThan: Timestamp.fromDate(inicio))
        .where('estado_pago', isEqualTo: 'pagado')
        .get();

    double totalEfectivo = 0, totalTarjeta = 0;
    final Map<String, int> topProductos = {};

    for (final doc in snapHoy.docs) {
      final d = doc.data();
      final metodo = d['metodo_pago'] as String? ?? 'efectivo';
      if (metodo == 'efectivo') {
        totalEfectivo +=
            (d['importe_efectivo'] as num?)?.toDouble() ??
                (d['importe_total'] as num?)?.toDouble() ??
                0;
      } else if (metodo == 'tarjeta') {
        totalTarjeta +=
            (d['importe_tarjeta'] as num?)?.toDouble() ??
                (d['importe_total'] as num?)?.toDouble() ??
                0;
      } else if (metodo == 'mixto') {
        totalEfectivo +=
            (d['importe_efectivo'] as num?)?.toDouble() ?? 0;
        totalTarjeta +=
            (d['importe_tarjeta'] as num?)?.toDouble() ?? 0;
      }
      final lineas = d['lineas'] as List? ?? [];
      for (final l in lineas) {
        final nombre = l['producto_nombre'] as String? ?? '';
        final qty = (l['cantidad'] as num?)?.toInt() ?? 1;
        topProductos[nombre] = (topProductos[nombre] ?? 0) + qty;
      }
    }

    double totalAyer = 0;
    for (final doc in snapAyer.docs) {
      totalAyer +=
      ((doc.data()['importe_total'] as num?)?.toDouble() ?? 0);
    }

    final totalHoy = totalEfectivo + totalTarjeta;
    final baseImponible = totalHoy / 1.10;
    final cuotaIva = totalHoy - baseImponible;

    final topList = topProductos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (mounted) {
      setState(() {
        _datos = {
          'total': totalHoy,
          'efectivo': totalEfectivo,
          'tarjeta': totalTarjeta,
          'num_tickets': snapHoy.docs.length,
          'ticket_medio': snapHoy.docs.isEmpty
              ? 0.0
              : totalHoy / snapHoy.docs.length,
          'base_imponible': baseImponible,
          'cuota_iva': cuotaIva,
          'total_ayer': totalAyer,
          'top_productos': topList.take(3).toList(),
          'fondo_inicial': _fondoInicial,
          'efectivo_teorico': _fondoInicial + totalEfectivo,
        };
        _cargando = false;
      });
    }
  }

  Future<void> _confirmarCierre() async {
    // Arqueo de caja: el cajero cuenta el dinero antes de confirmar
    final efectivoTeorico = (_datos?['efectivo_teorico'] as double?) ?? 0.0;
    if (!context.mounted) return;
    await ArqueoCajaWidget.mostrar(context, totalSistema: efectivoTeorico);
    if (!context.mounted) return;

    final efectivoRealStr = _efectivoRealCtrl.text.trim().replaceAll(',', '.');
    final efectivoReal = double.tryParse(efectivoRealStr);
    final diferencia = (efectivoReal ?? efectivoTeorico) - efectivoTeorico;
    final fmtAmt = NumberFormat('#,##0.00', 'es_ES');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar cierre de caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResumenFilaCierre('Fondo inicial', fmtAmt.format(_fondoInicial)),
            _ResumenFilaCierre('Ventas efectivo', fmtAmt.format((_datos?['efectivo'] as double?) ?? 0)),
            _ResumenFilaCierre('Efectivo teórico', fmtAmt.format(efectivoTeorico), bold: true),
            if (efectivoReal != null)
              _ResumenFilaCierre('Efectivo contado', fmtAmt.format(efectivoReal)),
            if (efectivoReal != null)
              _ResumenFilaCierre(
                'Diferencia',
                '${diferencia >= 0 ? '+' : ''}${fmtAmt.format(diferencia)} €',
                color: diferencia.abs() < 0.01
                    ? Colors.green
                    : diferencia < 0
                        ? Colors.red
                        : Colors.orange,
              ),
            const SizedBox(height: 8),
            const Text('Esta acción es definitiva e irreversible.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar cierre')),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _cerrando = true);
    try {
      final svc = CierreCajaService();
      final cierre = await svc.calcularCierreCaja(
        widget.empresaId,
        DateTime.now(),
        efectivoReal: efectivoReal,
      );
      await svc.guardarCierreCaja(widget.empresaId, cierre);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cierre de caja registrado correctamente'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al cerrar caja: $e')));
      }
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final d = _datos!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Cierre — ${_fechaHoy()}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _datos == null ? null : _generarZReport,
                icon: const Icon(Icons.download_outlined, size: 14),
                label:
                const Text('Z-PDF', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _cerrando ? null : _confirmarCierre,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: _cerrando
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cerrar caja',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _MetricCard2(
                              label: 'Total ventas',
                              value:
                              '${(d['total'] as double).toStringAsFixed(2)} €',
                              color: cs.primary),
                          const SizedBox(width: 8),
                          _MetricCard2(
                              label: 'Tickets',
                              value: '${d['num_tickets']}'),
                          const SizedBox(width: 8),
                          _MetricCard2(
                              label: 'Ticket medio',
                              value:
                              '${(d['ticket_medio'] as double).toStringAsFixed(2)} €'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CardCierre(
                        title: 'Desglose por método de pago',
                        child: Column(
                          children: [
                            _FilaDesglose(
                              label: 'Efectivo',
                              icono: Icons.payments_outlined,
                              valor:
                              '${(d['efectivo'] as double).toStringAsFixed(2)} €',
                              porcentaje: d['total'] > 0
                                  ? (d['efectivo'] / d['total'] * 100)
                                  : 0,
                            ),
                            const SizedBox(height: 6),
                            _FilaDesglose(
                              label: 'Tarjeta',
                              icono: Icons.credit_card,
                              valor:
                              '${(d['tarjeta'] as double).toStringAsFixed(2)} €',
                              porcentaje: d['total'] > 0
                                  ? (d['tarjeta'] / d['total'] * 100)
                                  : 0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CardCierre(
                        title: 'Top productos del día',
                        child: (d['top_productos'] as List).isEmpty
                            ? const Text('Sin datos',
                            style: TextStyle(color: Colors.grey))
                            : Column(
                          children: (d['top_productos'] as List)
                              .asMap()
                              .entries
                              .map((e) {
                            final entry =
                            e.value as MapEntry<String, int>;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 3),
                              child: Row(
                                children: [
                                  Text('${e.key + 1}.',
                                      style: TextStyle(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(entry.key,
                                          style: const TextStyle(
                                              fontSize: 12))),
                                  Text('×${entry.value}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color:
                                          cs.onSurfaceVariant)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _CardCierre(
                        title: 'Desglose IVA (10%)',
                        child: Column(
                          children: [
                            _FilaSimple(
                                label: 'Base imponible',
                                valor:
                                '${(d['base_imponible'] as double).toStringAsFixed(2)} €'),
                            const SizedBox(height: 4),
                            _FilaSimple(
                                label: 'Cuota IVA',
                                valor:
                                '${(d['cuota_iva'] as double).toStringAsFixed(2)} €'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CardCierre(
                        title: 'Comparativa',
                        child: Column(
                          children: [
                            _FilaSimple(
                                label: 'Hoy',
                                valor:
                                '${(d['total'] as double).toStringAsFixed(2)} €'),
                            const SizedBox(height: 4),
                            _FilaSimple(
                                label: 'Ayer',
                                valor:
                                '${(d['total_ayer'] as double).toStringAsFixed(2)} €'),
                            if ((d['total_ayer'] as double) > 0) ...[
                              const SizedBox(height: 6),
                              Builder(builder: (ctx) {
                                final diff =
                                    ((d['total'] as double) -
                                        (d['total_ayer'] as double)) /
                                        (d['total_ayer'] as double) *
                                        100;
                                return Text(
                                  '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}% vs ayer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: diff >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ── P2: Recuento físico de efectivo ───────────────
                      _CardCierre(
                        title: 'Recuento de efectivo',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FilaSimple(
                              label: 'Fondo inicial',
                              valor: '${_fondoInicial.toStringAsFixed(2)} €',
                            ),
                            const SizedBox(height: 4),
                            _FilaSimple(
                              label: 'Ventas efectivo',
                              valor: '${((d['efectivo'] as double?) ?? 0).toStringAsFixed(2)} €',
                            ),
                            const Divider(height: 12),
                            _FilaSimple(
                              label: 'Efectivo teórico',
                              valor: '${((d['efectivo_teorico'] as double?) ?? 0).toStringAsFixed(2)} €',
                              bold: true,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _efectivoRealCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Efectivo contado (€)',
                                hintText: '0.00',
                                prefixIcon: Icon(Icons.payments_outlined, size: 18),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            if (_efectivoRealCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Builder(builder: (ctx) {
                                final real = double.tryParse(
                                    _efectivoRealCtrl.text.replaceAll(',', '.')) ?? 0;
                                final teorico = (d['efectivo_teorico'] as double?) ?? 0;
                                final diff = real - teorico;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: diff.abs() < 0.01
                                        ? Colors.green.shade50
                                        : diff < 0
                                            ? Colors.red.shade50
                                            : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Diferencia',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      Text(
                                        '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)} €',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: diff.abs() < 0.01
                                              ? Colors.green.shade700
                                              : diff < 0
                                                  ? Colors.red.shade700
                                                  : Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _cargarDatos,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Actualizar',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fechaHoy() {
    final h = DateTime.now();
    return '${h.day.toString().padLeft(2, '0')}/${h.month.toString().padLeft(2, '0')}/${h.year}';
  }

  String _fmtEurPdf(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} EUR';

  Future<void> _generarZReport() async {
    final d = _datos!;
    String fmt(double v) => _fmtEurPdf(v);
    final fecha = _fechaHoy();

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context pctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
                child: pw.Text('Z-REPORT — CIERRE DE CAJA',
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold))),
            pw.Center(
                child: pw.Text('Fecha: $fecha',
                    style: pw.TextStyle(
                        fontSize: 13, color: PdfColors.grey600))),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('RESUMEN',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total ventas'),
                  pw.Text(fmt((d['total'] as num).toDouble())),
                ]),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Número de tickets'),
                  pw.Text('${d['num_tickets']}'),
                ]),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ticket medio'),
                  pw.Text(fmt((d['ticket_medio'] as num).toDouble())),
                ]),
            pw.SizedBox(height: 16),
            pw.Text('METODO DE PAGO',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Efectivo'),
                  pw.Text(fmt((d['efectivo'] as num).toDouble())),
                ]),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tarjeta'),
                  pw.Text(fmt((d['tarjeta'] as num).toDouble())),
                ]),
            pw.SizedBox(height: 16),
            pw.Text('DESGLOSE IVA (10%)',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Base imponible'),
                  pw.Text(fmt((d['base_imponible'] as num).toDouble())),
                ]),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cuota IVA'),
                  pw.Text(fmt((d['cuota_iva'] as num).toDouble())),
                ]),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text('TOP PRODUCTOS',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            ...(d['top_productos'] as List).asMap().entries.map((e) {
              final entry = e.value as MapEntry<String, int>;
              return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${e.key + 1}. ${entry.key}'),
                    pw.Text('x${entry.value}'),
                  ]);
            }),
            pw.SizedBox(height: 24),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ayer',
                      style: pw.TextStyle(color: PdfColors.grey600)),
                  pw.Text(fmt((d['total_ayer'] as num).toDouble()),
                      style: pw.TextStyle(color: PdfColors.grey600)),
                ]),
          ],
        );
      },
    ));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RESUMEN TURNO STREAM
// ═══════════════════════════════════════════════════════════════════════════

class _ResumenTurnoStream extends StatelessWidget {
  final String empresaId;
  const _ResumenTurnoStream({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos')
          .where('fecha_hora', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('fecha_hora', isLessThan: Timestamp.fromDate(fin))
          .where('estado_pago', isEqualTo: 'pagado')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        double totalVentas = 0;
        int numComandas = 0;
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          totalVentas +=
              (data['importe_total'] as num?)?.toDouble() ?? 0;
          if (data['mesa_id'] != null) numComandas++;
        }
        final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
        return Column(
          children: [
            _MetricChip(label: 'Ventas', valor: fmt.format(totalVentas)),
            const SizedBox(height: 6),
            _MetricChip(label: 'Tickets', valor: '${docs.length}'),
            const SizedBox(height: 6),
            _MetricChip(label: 'Mesas hoy', valor: '$numComandas'),
          ],
        );
      },
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String valor;

  const _MetricChip({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Text(valor,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSFERIR COMANDA
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _mostrarTransferirComanda(
    BuildContext context,
    String empresaId,
    String mesaOrigenId,
    Comanda comanda,
    ValueChanged<Comanda> onComandaActualizada,
    VoidCallback onVolverAMesas,
    ) async {
  final snap = await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('mesas')
      .where('estado', isEqualTo: 'libre')
      .get();

  final mesasLibres = snap.docs
      .where((d) => d.id != mesaOrigenId)
      .map((d) {
    final data = d.data();
    return <String, String>{
      'id': d.id,
      'nombre': (data['nombre'] as String?) ??
          'Mesa ${data['numero']}',
    };
  })
      .toList();

  if (!context.mounted) return;

  if (mesasLibres.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('No hay mesas libres disponibles')),
    );
    return;
  }

  final mesaDestino = await showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Transferir comanda a…'),
      content: SizedBox(
        width: 280,
        child: ListView(
          shrinkWrap: true,
          children: mesasLibres
              .map((m) => ListTile(
            leading: const Icon(Icons.table_restaurant),
            title: Text(m['nombre']!),
            onTap: () => Navigator.pop(ctx, m),
          ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
      ],
    ),
  );

  if (mesaDestino == null) return;

  final batch = FirebaseFirestore.instance.batch();
  final ref = FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId);

  batch.update(ref.collection('mesas').doc(mesaOrigenId), {
    'estado': 'libre',
    'comanda_id': null,
    'camarero_uid': null,
    'fecha_apertura': null,
  });
  batch.update(ref.collection('mesas').doc(mesaDestino['id']), {
    'estado': 'ocupada',
    'comanda_id': comanda.id,
    'camarero_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
    'fecha_apertura': FieldValue.serverTimestamp(),
  });
  if (comanda.id.isNotEmpty) {
    batch.update(ref.collection('comandas').doc(comanda.id),
        {'mesa_id': mesaDestino['id']});
  }
  await batch.commit();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Comanda transferida a ${mesaDestino['nombre']}')),
    );
    onVolverAMesas();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIVIDIR COMANDA
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _mostrarDividirComanda(
    BuildContext context,
    String empresaId,
    String mesaOrigenId,
    Comanda comanda,
    ValueChanged<Comanda> onComandaActualizada,
    ) async {
  final selectedIndices = <int>{};

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setS) => AlertDialog(
        title: const Text('Dividir comanda'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Selecciona los artículos que van a una nueva comanda:',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                ...comanda.lineas.asMap().entries.map((e) =>
                    CheckboxListTile(
                      dense: true,
                      title: Text(
                          '${e.value.nombre} ×${e.value.cantidad}',
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                          NumberFormat.currency(
                              symbol: '€', decimalDigits: 2)
                              .format(e.value.total),
                          style: const TextStyle(fontSize: 11)),
                      value: selectedIndices.contains(e.key),
                      onChanged: (v) => setS(() {
                        if (v == true)
                          selectedIndices.add(e.key);
                        else
                          selectedIndices.remove(e.key);
                      }),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: selectedIndices.isEmpty ||
                selectedIndices.length == comanda.lineas.length
                ? null
                : () => Navigator.pop(ctx2, true),
            child: const Text('Dividir'),
          ),
        ],
      ),
    ),
  );

  if (confirmar != true || selectedIndices.isEmpty) return;

  final lineasOrigen = comanda.lineas
      .asMap()
      .entries
      .where((e) => !selectedIndices.contains(e.key))
      .map((e) => e.value)
      .toList();
  final lineasNueva = comanda.lineas
      .asMap()
      .entries
      .where((e) => selectedIndices.contains(e.key))
      .map((e) => e.value)
      .toList();

  List<Map<String, dynamic>> lineasToMap(List<LineaComanda> lineas) =>
      lineas.map((l) => {
        'producto_id': l.productoId,
        'nombre': l.nombre,
        'cantidad': l.cantidad,
        'precio_unitario': l.precioUnitario,
        'iva_porcentaje': l.ivaPorcentaje,
        'notas': l.notas,
        'es_nuevo': l.esNuevo,
        'subtotal': l.total,
      }).toList();

  final db = FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId);
  final totalOrigen =
  lineasOrigen.fold(0.0, (s, l) => s + l.total);
  final totalNueva =
  lineasNueva.fold(0.0, (s, l) => s + l.total);

  await db.collection('comandas').doc(comanda.id).update({
    'lineas': lineasToMap(lineasOrigen),
    'importe_total': totalOrigen,
    'ultima_actualizacion': FieldValue.serverTimestamp(),
  });

  // Crear nueva mesa con nombre derivado de la original
  final mesaOriginalSnap = await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('mesas')
      .doc(mesaOrigenId)
      .get();
  final mesaData = mesaOriginalSnap.data() ?? {};
  final nombreMesaOriginal = mesaData['nombre'] as String? ?? 'Mesa';
  final zonaMesa  = mesaData['zona']        as String? ?? 'Salón';
  final formaOrig = mesaData['forma']       as String? ?? 'rect';
  final anchoOrig = (mesaData['mesa_ancho'] as num?)?.toDouble() ?? 0.18;
  final altoOrig  = (mesaData['mesa_alto']  as num?)?.toDouble() ?? 0.14;
  final posXOrig  = (mesaData['pos_x']      as num?)?.toDouble() ?? 0.1;
  final posYOrig  = (mesaData['pos_y']      as num?)?.toDouble() ?? 0.1;
  // Colocar la nueva mesa justo debajo de la original
  final posXNueva = posXOrig;
  final posYNueva = (posYOrig + altoOrig + 0.04).clamp(0.0, 0.85);

  // Nombre base (la original mantiene su nombre, sin renombrar)
  final nombreBase = nombreMesaOriginal;

  // Contar tickets divididos ya existentes para esta mesa base
  final ticketsExistentes = await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('mesas')
      .where('es_ticket_dividido', isEqualTo: true)
      .get();
  final ticketCount = ticketsExistentes.docs
      .where((d) {
        final n = (d.data()['nombre'] as String? ?? '');
        return n.startsWith('$nombreBase - Ticket');
      })
      .length;
  // Próximo número = tickets divididos existentes + 2
  final numTicketNuevo = ticketCount + 2;

  // Crear nueva mesa con misma forma/tamaño que la original
  final nuevaMesaRef = await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('mesas')
      .add({
    'nombre': '$nombreBase - Ticket $numTicketNuevo',
    'zona': zonaMesa,
    'forma': formaOrig,
    'mesa_ancho': anchoOrig,
    'mesa_alto': altoOrig,
    'pos_x': posXNueva,
    'pos_y': posYNueva,
    'numero': 0,
    'capacidad': 2,
    'estado': 'ocupada',
    'comanda_id': null,
    'camarero_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
    'fecha_apertura': FieldValue.serverTimestamp(),
    'asignado_a_uid': null,
    'asignado_a_nombre': null,
    'es_ticket_dividido': true,
  });

  // Crear comanda para la nueva mesa
  final nuevaComandaRef = await db.collection('comandas').add({
    'mesa_id': nuevaMesaRef.id,
    'camarero_uid': FirebaseAuth.instance.currentUser?.uid ?? '',
    'lineas': lineasToMap(lineasNueva),
    'estado': 'abierta',
    'apertura': FieldValue.serverTimestamp(),
    'importe_total': totalNueva,
    'ultima_actualizacion': FieldValue.serverTimestamp(),
  });

  // Vincular comanda a la nueva mesa
  await nuevaMesaRef.update({'comanda_id': nuevaComandaRef.id});

  onComandaActualizada(comanda.copyWith(lineas: lineasOrigen));

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ Dividida: "$nombreBase" y "$nombreBase - Ticket $numTicketNuevo" visibles en el plano.',
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NÚMERO DE TICKET — Firestore primero, SharedPreferences como fallback offline
// ═══════════════════════════════════════════════════════════════════════════

Future<int> _obtenerSiguienteNumeroTicket(String empresaId) async {
  final prefsKey = 'tpv_ultimo_ticket_$empresaId';
  final ref = FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('contadores')
      .doc('tickets');

  try {
    final snap = await ref.get().timeout(const Duration(seconds: 4));
    final siguiente = snap.exists
        ? ((snap.data()?['ultimo'] as num?)?.toInt() ?? 0) + 1
        : 1;
    await ref.set({'ultimo': siguiente}, SetOptions(merge: true));
    // Persiste localmente para que el fallback offline sea secuencial
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKey, siguiente);
    debugPrint('🎫 [TICKET] Firestore → #$siguiente');
    return siguiente;
  } catch (_) {
    // Offline o timeout → contador local persistente
    final prefs = await SharedPreferences.getInstance();
    final local = (prefs.getInt(prefsKey) ?? 0) + 1;
    await prefs.setInt(prefsKey, local);
    debugPrint('📴 [TICKET] Offline → local #$local');
    return local;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES — CIERRE DE CAJA
// ═══════════════════════════════════════════════════════════════════════════

class _MetricCard2 extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _MetricCard2(
      {required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    ),
  );
}

class _CardCierre extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardCierre({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _FilaDesglose extends StatelessWidget {
  final String label, valor;
  final IconData icono;
  final double porcentaje;

  const _FilaDesglose(
      {required this.label,
        required this.valor,
        required this.icono,
        required this.porcentaje});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icono, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 12))),
          Text('${porcentaje.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          Text(valor,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _FilaSimple extends StatelessWidget {
  final String label, valor;
  final bool bold;
  const _FilaSimple({required this.label, required this.valor, this.bold = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Text(valor,
          style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
    ],
  );
}

// Fila de resumen para el diálogo de confirmación de cierre
class _ResumenFilaCierre extends StatelessWidget {
  final String label, valor;
  final bool bold;
  final Color? color;
  const _ResumenFilaCierre(this.label, this.valor, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        Text('$valor €',
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color)),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TICKET EN PANTALLA (fallback sin impresora BT)
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _mostrarVistaTicket(
  BuildContext context,
  TicketData ticket, {
  String? aviso,
}) async {
  final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
  final fmtFecha = DateFormat('dd/MM/yyyy HH:mm');

  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F23),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00FFC8), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FFC8).withValues(alpha: 0.2),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (aviso != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: const Border(bottom: BorderSide(color: Color(0xFF333333))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.print_disabled, color: Color(0xFFFF9800), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(aviso, style: const TextStyle(color: Color(0xFFFF9800), fontSize: 11))),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long, color: Color(0xFF00FFC8), size: 32),
                    const SizedBox(height: 8),
                    if (ticket.nombreEmpresa.isNotEmpty) ...[
                      Text(ticket.nombreEmpresa.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                    ],
                    Text('TICKET Nº ${ticket.numeroTicket}',
                        style: const TextStyle(color: Color(0xFF00FFC8), fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    Text(fmtFecha.format(ticket.fecha),
                        style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 12)),
                    const SizedBox(height: 16),
                    _DividerTicket(),
                    const SizedBox(height: 12),
                    ...ticket.lineas.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(width: 28,
                            child: Text('${l.cantidad}x',
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: Color(0xFFFFA000), fontSize: 13, fontWeight: FontWeight.w700))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l.nombre, style: const TextStyle(color: Colors.white, fontSize: 13))),
                          Text(fmt.format(l.subtotal), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                    const SizedBox(height: 12),
                    _DividerTicket(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        Text(fmt.format(ticket.total),
                            style: const TextStyle(color: Color(0xFF00FFC8), fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF1E2139), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ticket.metodoPago == 'efectivo' ? Icons.payments
                                : ticket.metodoPago == 'tarjeta' ? Icons.credit_card : Icons.swap_horiz,
                            color: const Color(0xFFB0B3C1), size: 16),
                          const SizedBox(width: 6),
                          Text(ticket.metodoPago.toUpperCase(),
                              style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DividerTicket(),
                    const SizedBox(height: 8),
                    const Text('¡Gracias por su visita!',
                        style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 13, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFC8),
                    foregroundColor: const Color(0xFF0A0F23),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DividerTicket extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Color(0xFF2A2E45), Color(0xFF2A2E45), Colors.transparent],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────

// ── Stat tile del resumen sala ────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatTile({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final tema = _TpvRootTemaScope.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, height: 1.1)),
      Text(label, style: TextStyle(fontSize: 9, color: tema.textoMuted, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Botón acción rápida del plano ─────────────────────────────────────────────
class _AccionRapida extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  const _AccionRapida({required this.icon, required this.label, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = _TpvRootTemaScope.of(context);
    final color = enabled ? tema.texto : tema.textoMuted.withValues(alpha: 0.4);
    return Tooltip(
      message: enabled ? label : '$label (selecciona una mesa)',
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: enabled ? tema.primario.withValues(alpha: 0.1) : tema.borde.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: enabled ? tema.primario.withValues(alpha: 0.3) : tema.borde),
            ),
            child: Icon(icon, size: 16, color: enabled ? tema.primario : tema.textoMuted.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── Leyenda item (punto de color + etiqueta) ──────────────────────────────────
class _LeyendaItem extends StatelessWidget {
  final Color color;
  final String label;
  final Color muted;
  const _LeyendaItem({required this.color, required this.label, required this.muted});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w500)),
    ],
  );
}

// ── Botón toggle claro / oscuro ───────────────────────────────────────────────
class _TemaToggleBtn extends StatelessWidget {
  final bool oscuro;
  final VoidCallback onToggle;
  final _TpvRootTema tema;

  const _TemaToggleBtn({
    required this.oscuro,
    required this.onToggle,
    required this.tema,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: oscuro ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 32,
          decoration: BoxDecoration(
            color: tema.superficie,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tema.borde),
          ),
          child: Icon(
            oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 16,
            color: oscuro ? const Color(0xFF00FFC8) : tema.textoMuted,
          ),
        ),
      ),
    );
  }
}

// ── Botón de icono compacto para acciones de comanda ─────────────────────────
class _AccionIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const _AccionIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tema = _TpvRootTemaScope.of(context);
    final color = enabled ? tema.textoMuted : tema.textoMuted.withValues(alpha: 0.3);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 28,
          decoration: BoxDecoration(
            color: tema.superficie,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tema.borde),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BotonAccion({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tema = _TpvRootTemaScope.of(context);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: tema.superficie,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tema.borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: tema.textoMuted),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: tema.textoMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
class _MesaActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _MesaActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

