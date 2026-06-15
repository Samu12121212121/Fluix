import 'dart:async';
import 'dart:math' show Random;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
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
import 'pantalla_cocina_screen.dart'; // ← NUEVO: Pantalla de cocina (KDS)
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

  const TpvRootScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
    this.esPropietario = false,
    this.mesaInicialId,
    this.tpvPersonalizadoId,
    this.tpvPersonalizadoNombre,
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
  bool _btConectado = false;

  static const _tpvAppBarColor = Color(0xFF1565C0);

  final _holdNotifier = HoldPedidosNotifier();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _iniciarReloj();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _estaOnline = !results.contains(ConnectivityResult.none));
    });
    Connectivity().checkConnectivity().then((results) {
      if (mounted) setState(() => _estaOnline = !results.contains(ConnectivityResult.none));
    });
    ImpressoraBluetooth().estaConectada().then((conectada) {
      if (mounted) setState(() => _btConectado = conectada);
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
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
    _connectivitySub?.cancel();
    _holdNotifier.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
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
    const bgColor = Color(0xFF111111);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: _tpvAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 48,
        title: Row(
          children: [
            // ── Izquierda: nav + modo ──────────────────────────────────
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_modoActual, style: const TextStyle(fontSize: 10)),
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
                  color: _tpvAppBarColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.account_balance_wallet, size: 13, color: Colors.white70),
                  SizedBox(width: 3),
                  Text('Caja', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
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
                  color: _tpvAppBarColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.summarize_outlined, size: 13, color: Colors.white70),
                  SizedBox(width: 3),
                  Text('Cierre', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            // Reloj + wifi
            const SizedBox(width: 6),
            Text(_horaActual, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Icon(
              _estaOnline ? Icons.wifi : Icons.wifi_off,
              size: 14,
              color: _estaOnline ? Colors.white54 : Colors.orangeAccent,
            ),
            // ── Menú desbordamiento para acciones secundarias ─────────
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: Colors.white70),
              color: const Color(0xFF1E2139),
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
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'historial', child: Row(children: [
                  Icon(Icons.history, size: 16, color: Colors.white70), SizedBox(width: 10),
                  Text('Historial de ventas', style: TextStyle(color: Colors.white)),
                ])),
                const PopupMenuItem(value: 'tickets', child: Row(children: [
                  Icon(Icons.receipt_long, size: 16, color: Colors.white70), SizedBox(width: 10),
                  Text('Tickets del turno', style: TextStyle(color: Colors.white)),
                ])),
                const PopupMenuItem(value: 'stats', child: Row(children: [
                  Icon(Icons.bar_chart, size: 16, color: Colors.white70), SizedBox(width: 10),
                  Text('Estadísticas', style: TextStyle(color: Colors.white)),
                ])),
                const PopupMenuItem(value: 'cocina', child: Row(children: [
                  Icon(Icons.restaurant_menu, size: 16, color: Colors.white70), SizedBox(width: 10),
                  Text('Pantalla de cocina', style: TextStyle(color: Colors.white)),
                ])),
                const PopupMenuItem(value: 'devoluciones', child: Row(children: [
                  Icon(Icons.keyboard_return, size: 16, color: Colors.white70), SizedBox(width: 10),
                  Text('Devoluciones', style: TextStyle(color: Colors.white)),
                ])),
                const PopupMenuItem(value: 'tema', child: Row(children: [
                  Icon(Icons.palette_outlined, size: 16, color: Colors.white70), SizedBox(width: 10),
                  Text('Tema del plano', style: TextStyle(color: Colors.white)),
                ])),
                const PopupMenuItem(value: 'impresora', child: Row(children: [
                  Icon(Icons.print, size: 16, color: Colors.white70), SizedBox(width: 10),
                  Text('Impresora', style: TextStyle(color: Colors.white)),
                ])),
                if (widget.esAdmin)
                  const PopupMenuItem(value: 'config', child: Row(children: [
                    Icon(Icons.settings, size: 16, color: Colors.white70), SizedBox(width: 10),
                    Text('Configuración TPV', style: TextStyle(color: Colors.white)),
                  ])),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Franja de empleados activos ──────────────────────────────────
          EmpleadosBannerWidget(
            empresaId: widget.empresaId,
            empleadoSeleccionadoId: _empleadoSeleccionadoId,
            onEmpleadoChanged: (id) => setState(() => _empleadoSeleccionadoId = id),
            colorPrimario: const Color(0xFF00BCD4),
            colorFondo: const Color(0xFF0D1B2A),
          ),
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
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF333333)),
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
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF333333)),
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
      ),         // cierre Column (body)
    );
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
    return Stack(
      children: [
        Container(
          color: const Color(0xFF1A1A1A),
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
                      final uid = (m.asignadoAUid ?? '').trim();
                      return uid.isEmpty || uid == widget.empleadoFiltroUid!.trim();
                    }).toList();

              final mesasFiltradas = widget.zonaFiltro.isEmpty
                  ? mesasPorEmpleado
                  : mesasPorEmpleado.where((m) => m.zona == widget.zonaFiltro).toList();
              final libres = mesasPorEmpleado.where((m) => m.esLibre).length;
              final ocupadas = mesasPorEmpleado.where((m) => m.esOcupada).length;

              return ClipRect(
                child: Column(
                children: [
                  // ── Cabecera ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A2E),
                      border: Border(bottom: BorderSide(color: Color(0xFF333333))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fila superior: título + edit
                        Row(
                          children: [
                            const Icon(Icons.table_restaurant, size: 14, color: Color(0xFF00FFC8)),
                            const SizedBox(width: 6),
                            const Text('PLANO DE MESAS',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4)),
                            const Spacer(),
                            if (widget.esAdmin) ...[
                              _EditPlanoBtn(
                                activo: _modoEdicionPlano,
                                onToggle: () => setState(
                                    () => _modoEdicionPlano = !_modoEdicionPlano),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Fila de contadores + botones añadir mesa
                        Row(
                          children: [
                            _ResumenCounter(count: libres, label: 'LIBRES', color: Colors.green),
                            const SizedBox(width: 12),
                            _ResumenCounter(count: ocupadas, label: 'OCUPADAS', color: Colors.red),
                            const Spacer(),
                            if (widget.esAdmin) ...[
                              _BtnAddMesa(
                                tooltip: 'Mesa rectangular',
                                icono: Icons.crop_square,
                                color: const Color(0xFF00FFC8),
                                onTap: () => _crearMesaConForma('rect'),
                              ),
                              const SizedBox(width: 4),
                              _BtnAddMesa(
                                tooltip: 'Mesa redonda',
                                icono: Icons.circle_outlined,
                                color: const Color(0xFF00FFC8),
                                onTap: () => _crearMesaConForma('circle'),
                              ),
                              const SizedBox(width: 4),
                              _BtnAddMesa(
                                tooltip: 'Barra (mesa larga)',
                                icono: Icons.horizontal_rule,
                                color: const Color(0xFFEF9F27),
                                onTap: () => _crearMesaConForma('bar'),
                              ),
                            ],
                          ],
                        ),
                        // ── Filtro de zonas + botón crear zona ────────────
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 26,
                          child: Row(
                            children: [
                              Expanded(
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    // Chips de zonas reales
                                    ...zonas.map((zona) => _ZonaChip(
                                      zona: zona,
                                      seleccionada: widget.zonaFiltro == zona,
                                      onTap: () => widget.onZonaChanged(zona),
                                    )),
                                  ],
                                ),
                              ),
                              // ── Botón "+" crear zona ──────────────────────
                              Tooltip(
                                message: 'Nueva zona',
                                child: InkWell(
                                  onTap: () => _crearZona(context),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2A2A2A),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF00FFC8).withValues(alpha: 0.5)),
                                    ),
                                    child: const Icon(Icons.add, size: 14, color: Color(0xFF00FFC8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: seleccionada ? const Color(0xFFFFA000) : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: seleccionada ? const Color(0xFFFFA000) : const Color(0xFF444444),
            ),
          ),
          child: Text(
            zona,
            style: TextStyle(
              color: seleccionada ? Colors.black : Colors.white70,
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
                : const Color(0xFF333333),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: activo
                  ? Colors.orange.withValues(alpha: 0.5)
                  : const Color(0xFF444444),
            ),
          ),
          child: Icon(
            activo ? Icons.lock_open : Icons.edit_location_alt,
            size: 14,
            color: activo ? Colors.orange : Colors.white54,
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

// ── NUEVO: pantalla cierre de caja desde AppBar ──────────────────────────
Future<void> mostrarPantallaCierreCaja(
    BuildContext context, String empresaId) async {
  await showDialog(
    context: context,
    builder: (ctx) {
      final screenH = MediaQuery.of(ctx).size.height;
      final screenW = MediaQuery.of(ctx).size.width;
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenW.clamp(300, 780),
            maxHeight: (screenH * 0.88).clamp(400, 680),
          ),
          child: _CierreDeCaja(empresaId: empresaId),
        ),
      );
    },
  );
}

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
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return Container(
      color: const Color(0xFF111111),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(bottom: BorderSide(color: Color(0xFF333333))),
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
                if (snap.hasData && snap.data!.exists) {
                  final d = snap.data!.data() as Map<String, dynamic>;
                  nombre = d['nombre'] as String? ?? 'Mesa ${d['numero']}';
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.0),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // ── Camarero asignado ──────────────────────────
                        if (comandaActiva?.camareroUid.isNotEmpty == true)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('empresas')
                                .doc(empresaId)
                                .collection('empleados')
                                .doc(comandaActiva!.camareroUid)
                                .snapshots(),
                            builder: (_, empSnap) {
                              String empNombre = '';
                              if (empSnap.hasData && empSnap.data!.exists) {
                                final d = empSnap.data!.data() as Map<String, dynamic>;
                                empNombre = (d['nombre'] as String?) ?? '';
                              }
                              if (empNombre.isEmpty) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF1565C0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person, size: 11, color: Color(0xFF90CAF9)),
                                    const SizedBox(width: 4),
                                    Text(empNombre,
                                        style: const TextStyle(
                                            color: Color(0xFF90CAF9),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Botones de acción: FittedBox garantiza una sola línea
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      child: Row(
                      children: [
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
                      ],
                    ),   // close Row
                  ),     // close FittedBox
                  ],
                );
              },
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: icono + título
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 6),
                    Text('VENTA DIRECTA',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6)),
                  ],
                ),
                const SizedBox(height: 6),
                // Fila 2: botones de acción
                Row(
                  children: [
                    _BotonAccion(
                      icon: Icons.add_circle_outline,
                      label: 'Libre',
                      onTap: () => _agregarProductoLibre(context),
                    ),
                    const SizedBox(width: 6),
                    _BotonAccion(
                      icon: Icons.discount_outlined,
                      label: 'Dto.',
                      onTap: comandaActiva != null &&
                          comandaActiva!.lineas.isNotEmpty
                          ? () => _aplicarDescuento(context)
                          : () {},
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white54, size: 18),
                      tooltip: 'Limpiar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => onComandaActualizada(Comanda(
                        id: '',
                        camareroUid: '',
                        lineas: [],
                        estado: 'abierta',
                        apertura: Timestamp.now(),
                        importeTotal: 0,
                      )),
                    ),
                  ],
                ),
              ],
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
                            color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        const Text('Comanda vacía',
                            style: TextStyle(color: Colors.white38, fontSize: 16)),
                        const SizedBox(height: 8),
                        const Text('Selecciona productos del catálogo',
                            style: TextStyle(color: Colors.white24, fontSize: 12)),
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
                      );
                    },
                  ),
          ),
          // Total y botón cobro
          if (comandaActiva != null && comandaActiva!.lineas.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(
                    top: BorderSide(color: Color(0xFF333333), width: 2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:',
                          style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(fmt.format(comandaActiva!.baseImponible),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('IVA:',
                          style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(fmt.format(comandaActiva!.cuotaIva),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  // Descuento si existe
                  if ((comandaActiva!.descuento ?? 0) > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Text('Descuento:',
                              style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
                          if (comandaActiva!.descuentoPct != null)
                            Text('  (${comandaActiva!.descuentoPct!.toStringAsFixed(0)}%)',
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                        ]),
                        Text('- ${fmt.format(comandaActiva!.descuento!)}',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    TextButton(
                      onPressed: () => onComandaActualizada(
                          comandaActiva!.copyWith(clearDescuento: true)),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Quitar descuento',
                          style: TextStyle(color: Colors.red, fontSize: 10)),
                    ),
                  ],
                  // Nota general si existe
                  if ((comandaActiva!.notaGeneral ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        const Icon(Icons.note, size: 13, color: Colors.amber),
                        const SizedBox(width: 4),
                        Expanded(child: Text(
                          comandaActiva!.notaGeneral!,
                          style: const TextStyle(color: Colors.amber, fontSize: 11, fontStyle: FontStyle.italic),
                        )),
                      ]),
                    ),
                  const Divider(color: Color(0xFF444444), height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text('TOTAL:',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            fmt.format(comandaActiva!.total),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFA000),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () => _cobrar(context, empresaId,
                          comandaActiva!, mesaId, onCobrado),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'COBRAR ${fmt.format(comandaActiva!.total)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1),
                        ),
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
            'es_nuevo': false, // ya enviado
            'subtotal': l.total,
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
        builder: (_) => _DialogoMetodoPago(total: comanda.total),
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
    final pedidoCreado = await PedidosService().crearPedido(
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
      importeTotal: comanda.total,
      mesaId: mesaId,
      estado: 'entregado',
      estadoPago: 'pagado',
      fechaHora: fechaHoraTs,
    );
    debugPrint('💰 [COBRO] ✅ Pedido creado: ${pedidoCreado.id}');

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
      debugPrint('🪟 Plataforma Windows detectada - intentando impresión Bluetooth...');

      try {
        // Mostrar dialog de loading
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => WillPopScope(
              onWillPop: () async => false,
              child: const AlertDialog(
                backgroundColor: Color(0xFF1E2139),
                content: Row(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00FFC8)),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Imprimiendo ticket...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        try {
          // Intentar impresión REAL en Windows (async, no bloqueante)
          await ImpresoraWindowsService().imprimirTicket(ticketData);

          // Cerrar loading
          if (context.mounted) Navigator.pop(context);

          // Mostrar éxito
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('🖨️ Ticket impreso correctamente'),
                ]),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }

        } catch (e, stackTrace) {
          debugPrint('❌ Error al imprimir en Windows: $e\n$stackTrace');

          // Cerrar loading
          if (context.mounted) Navigator.pop(context);

          // Fallback: Mostrar ticket en pantalla
          if (context.mounted) {
            await _mostrarVistaTicket(context, ticketData,
                aviso: '⚠️ Error de impresión: ${e.toString()}\n\nMostrando ticket en pantalla como alternativa.');
          }
        }
      } catch (dialogError) {
        debugPrint('❌ Error al mostrar diálogo de impresión: $dialogError');
        // Si falla todo, al menos mostrar ticket en pantalla
        if (context.mounted) {
          await _mostrarVistaTicket(context, ticketData,
              aviso: '⚠️ Error en sistema de impresión. Mostrando ticket en pantalla.');
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
      // Enviar a Crashlytics (siempre, en producción y debug)
      FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'Error crítico en proceso de cobro TPV');

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

  const _LineaComandaCard({
    required this.linea,
    required this.onCantidadChanged,
    required this.onEditarPrecio,
    required this.onEditarNota,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    if (compact) return _buildCompact(fmt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
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
                        color: linea.esNuevo ? Colors.white : Colors.white70)),
              ),
              // ── IMPLEMENTADO: Botón editar precio ──
              GestureDetector(
                onTap: onEditarPrecio,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF555555)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit, size: 11, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(fmt.format(linea.precioUnitario),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white54)),
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
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      color: Colors.white70,
                      onPressed: () => onCantidadChanged(-1),
                      padding: const EdgeInsets.all(8),
                      constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('${linea.cantidad}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      color: Colors.white70,
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
                      : Colors.white38,
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
  Widget _buildCompact(NumberFormat fmt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Row(
        children: [
          // Botones cantidad compactos
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => onCantidadChanged(-1),
                  child: const SizedBox(
                    width: 26, height: 26,
                    child: Icon(Icons.remove, size: 13, color: Colors.white70),
                  ),
                ),
                SizedBox(
                  width: 22,
                  child: Text(
                    '${linea.cantidad}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                InkWell(
                  onTap: () => onCantidadChanged(1),
                  child: const SizedBox(
                    width: 26, height: 26,
                    child: Icon(Icons.add, size: 13, color: Colors.white70),
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
                  color: linea.esNuevo ? Colors.white : Colors.white60),
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
                  : Colors.white24,
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
    return Container(
      color: const Color(0xFF111111),
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

              return Column(
                children: [
                  // ── Cabecera ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      border: Border(bottom: BorderSide(color: Color(0xFF333333))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront, size: 14, color: Color(0xFFFFA000)),
                            const SizedBox(width: 6),
                            const Text('CATÁLOGO',
                                style: TextStyle(
                                    color: Colors.white70,
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
                                icon: const Icon(Icons.add_circle_outline,
                                    color: Color(0xFF00FFC8), size: 18),
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
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: 'Buscar producto…',
                                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                    prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
                                    suffixIcon: widget.busqueda.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 14, color: Colors.white38),
                                            onPressed: () => widget.onBusquedaChanged(''),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: const Color(0xFF252525),
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
                                      color: const Color(0xFF252525),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.qr_code_scanner,
                                        size: 18, color: Color(0xFF00FFC8)),
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
                                    size: 48, color: Colors.white.withValues(alpha: 0.1)),
                                const SizedBox(height: 8),
                                Text(
                                  widget.busqueda.isNotEmpty ? 'Sin resultados' : 'Sin productos',
                                  style: const TextStyle(color: Colors.white24, fontSize: 13),
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
                      ? const Color(0xFFFFA000).withValues(alpha: 0.25)
                      : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: sel
                        ? const Color(0xFFFFA000)
                        : const Color(0xFF444444),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: sel ? const Color(0xFFFFA000) : Colors.white54,
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
    return Container(
      height: 78,
      color: const Color(0xFF1A1A1A),
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
                childAspectRatio: 0.36, // height/width → chips ~92px ancho
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
                        color: sel ? Colors.white : Colors.white70,
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
                    color: const Color(0xFF2A2A2A),
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

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: usandoImagenAuto
                ? const Color(0xFFFFA000).withValues(alpha: 0.4)
                : const Color(0xFF2E2E2E),
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
                        ? Image.network(
                            urlImagen,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                _inicialBox(colorCategoria, inicial),
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
                    Text(
                      producto.nombre,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      fmt.format(producto.precio),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1565C0),
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
  const _DialogoMetodoPago({required this.total});

  @override
  State<_DialogoMetodoPago> createState() => _DialogoMetodoPagoState();
}

class _DialogoMetodoPagoState extends State<_DialogoMetodoPago> {
  String _metodo = 'efectivo';
  final _entregaCtrl = TextEditingController();
  final _efectivoMixtoCtrl = TextEditingController();
  final _tarjetaMixtoCtrl = TextEditingController();
  double _cambio = 0;

  double get _efectivoMixto =>
      double.tryParse(_efectivoMixtoCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _tarjetaMixto =>
      double.tryParse(_tarjetaMixtoCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _restoMixto =>
      (widget.total - _efectivoMixto - _tarjetaMixto);

  @override
  void dispose() {
    _entregaCtrl.dispose();
    _efectivoMixtoCtrl.dispose();
    _tarjetaMixtoCtrl.dispose();
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
                    '${widget.total.toStringAsFixed(2)} €',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _PagoChip(
                    label: 'Efectivo',
                    icon: Icons.payments_outlined,
                    selected: _metodo == 'efectivo',
                    onTap: () => setState(() => _metodo = 'efectivo')),
                const SizedBox(width: 8),
                _PagoChip(
                    label: 'Tarjeta',
                    icon: Icons.credit_card,
                    selected: _metodo == 'tarjeta',
                    onTap: () => setState(() => _metodo = 'tarjeta')),
                const SizedBox(width: 8),
                _PagoChip(
                    label: 'Mixto',
                    icon: Icons.swap_horiz,
                    selected: _metodo == 'mixto',
                    onTap: () => setState(() => _metodo = 'mixto')),
              ],
            ),
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
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            double efectivo = 0, tarjeta = 0;
            if (_metodo == 'efectivo') {
              efectivo = widget.total;
            } else if (_metodo == 'tarjeta') {
              tarjeta = widget.total;
            } else {
              efectivo = double.tryParse(
                  _efectivoMixtoCtrl.text.replaceAll(',', '.')) ??
                  0;
              tarjeta = double.tryParse(
                  _tarjetaMixtoCtrl.text.replaceAll(',', '.')) ??
                  0;
              if ((efectivo + tarjeta - widget.total).abs() > 0.01) {
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
            });
          },
          child: const Text('Confirmar cobro'),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
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
      ),
    );
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
// NÚMERO DE TICKET (contador atómico)
// ═══════════════════════════════════════════════════════════════════════════

Future<int> _obtenerSiguienteNumeroTicket(String empresaId) async {
  debugPrint('🎫 [TICKET] Obteniendo siguiente número de ticket...');
  debugPrint('🎫 [TICKET] ℹ️ Modo Windows Desktop: SIN transacciones (evita threading issues)');
  
  final ref = FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('contadores')
      .doc('tickets');

  int siguiente = 1;
  
  try {
    // WINDOWS DESKTOP FIX: No usar transacciones debido a problemas de threading
    // Ver: https://docs.flutter.dev/platform-integration/platform-channels#channels-and-platform-threading
    debugPrint('🎫 [TICKET] Método simple (sin transacción) para Windows Desktop...');
    
    // 1. Leer el contador actual
    debugPrint('🎫 [TICKET] Paso 1: Leyendo contador actual...');
    final snap = await ref.get();
    
    if (snap.exists) {
      siguiente = ((snap.data()?['ultimo'] as num?)?.toInt() ?? 0) + 1;
      debugPrint('🎫 [TICKET] Contador existe, siguiente: $siguiente');
    } else {
      siguiente = 1;
      debugPrint('🎫 [TICKET] Contador no existe, inicializando en: $siguiente');
    }
    
    // 2. Actualizar el contador
    debugPrint('🎫 [TICKET] Paso 2: Actualizando contador a: $siguiente');
    await ref.set({'ultimo': siguiente}, SetOptions(merge: true));
    debugPrint('🎫 [TICKET] ✅ Contador actualizado correctamente');
    
  } catch (e, stackTrace) {
    debugPrint('❌ [TICKET] Error obteniendo/actualizando contador');
    debugPrint('❌ [TICKET] Error: $e');
    debugPrint('❌ [TICKET] StackTrace: $stackTrace');
    
    // FALLBACK: Usar timestamp como número de ticket si falla
    siguiente = DateTime.now().millisecondsSinceEpoch % 100000;
    debugPrint('⚠️ [TICKET] Usando fallback temporal: $siguiente');
    
    // Intentar actualizar el contador de forma simple
    try {
      debugPrint('🎫 [TICKET] Intentando actualización simple del fallback...');
      await ref.set({'ultimo': siguiente}, SetOptions(merge: true));
      debugPrint('🎫 [TICKET] ✅ Actualización simple exitosa');
    } catch (e2) {
      debugPrint('❌ [TICKET] También falló actualización simple: $e2');
      // No importa, usamos el número temporal
    }
  }
  
  return siguiente;
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
    final color = enabled ? Colors.white70 : Colors.white24;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 28,
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF2A2A2A)
                : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF444444)),
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
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF444444)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70,
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

