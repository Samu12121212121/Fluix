import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../../services/tpv/impresora_windows_service.dart' show ImpresoraWindowsService;
import '../../../services/tpv/cierre_caja_service.dart';
import '../../pedidos/widgets/variante_selector_widget.dart';
import 'package:intl/intl.dart';
import 'tpv_peluqueria_screen.dart' hide Producto, ImpressoraBluetooth, LineaTicket, TicketData, CierreCajaService;
import 'tpv_tienda_screen.dart';
import 'configuracion_facturacion_tpv_screen.dart';
import 'pantalla_cocina_screen.dart'; // ← NUEVO: Pantalla de cocina (KDS)
import '../widgets/tpv_type_switcher.dart';
import '../widgets/dialogo_devoluciones.dart';
import '../widgets/empleados_banner_widget.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class TpvRootScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final bool esPropietario;

  const TpvRootScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
    this.esPropietario = false,
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
  String _zonaFiltro = 'Todas';
  String _categoriaFiltro = 'Todos';
  String _busqueda = '';
  String? _empleadoSeleccionadoId; // ← empleado activo en el turno

  Timer? _relojTimer;
  String _horaActual = '';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _estaOnline = true;
  bool _btConectado = false;

  static const _tpvAppBarColor = Color(0xFF1565C0);

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
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
    _connectivitySub?.cancel();
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
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Salir del TPV',
            ),
            const Icon(Icons.point_of_sale, size: 18),
            const SizedBox(width: 6),
            const Text('TPV', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_modoActual, style: const TextStyle(fontSize: 11)),
            ),
            const Spacer(),
            // Botones de acción alineados a la derecha
            IconButton(
              icon: const Icon(Icons.restaurant_menu, size: 16),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PantallaCocinaScreen(empresaId: widget.empresaId),
                  ),
                );
              },
              tooltip: 'Pantalla de Cocina',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.keyboard_return, size: 16),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => DialogoDevoluciones(
                  empresaId: widget.empresaId,
                  colorPrimario: _tpvAppBarColor,
                ),
              ),
              tooltip: 'Devoluciones',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.account_balance_wallet, size: 16),
              onPressed: () => mostrarDialogoAperturaCaja(context, widget.empresaId),
              tooltip: 'Apertura de caja',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.lock_clock, size: 16),
              onPressed: () => mostrarPantallaCierreCaja(context, widget.empresaId),
              tooltip: 'Cierre de caja',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 8),
            Text(_horaActual, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Icon(
              _estaOnline ? Icons.wifi : Icons.wifi_off,
              size: 15,
              color: _estaOnline ? Colors.white70 : Colors.orangeAccent,
            ),
            const SizedBox(width: 6),
            // ── Botón impresora: abre diálogo de configuración BT ──
            IconButton(
              icon: Icon(Icons.print, 
                  size: 16, 
                  color: _btConectado ? Colors.white70 : Colors.white38),
              onPressed: () => _mostrarConfigImpresora(),
              tooltip: 'Impresora Bluetooth',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 8),
            TpvTypeSwitcher(
              tipoActual: 'bar',
              onTipoChanged: (tipo) {
                Widget pantalla;
                switch (tipo) {
                  case 'peluqueria':
                    pantalla = TpvPeluqueriaScreen(
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
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
              },
            ),
            if (widget.esAdmin) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.settings, size: 16),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConfiguracionFacturacionTpvScreen(
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
          // COLUMNA IZQUIERDA (25%): LISTA DE MESAS
          Expanded(
            flex: 25,
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
          // COLUMNA CENTRAL (45%): COMANDA ACTIVA
          Expanded(
            flex: 45,
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

class _ColumnaListaMesas extends StatelessWidget {
  final String empresaId;
  final bool esAdmin;
  final String zonaFiltro;
  final String? empleadoFiltroUid; // ← filtrar por camarero si no es null
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
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: const Color(0xFF1A1A1A),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas')
                .doc(empresaId)
                .collection('mesas')
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final mesas = snap.data!.docs
                  .map((d) => Mesa.fromFirestore(d, empresaId: empresaId))
                  .toList();
              final zonas = {'Todas', ...mesas.map((m) => m.zona)};

              // ── Filtro por empleado (asignación permanente) ──────────────────────
              final mesasPorEmpleado = empleadoFiltroUid == null
                  ? mesas
                  : mesas.where((m) {
                      final uid = (m.asignadoAUid ?? '').trim();
                      // Mostrar solo las mesas asignadas a este empleado
                      // o las que no tienen asignación (uid vacío)
                      return uid.isEmpty || uid == empleadoFiltroUid!.trim();
                    }).toList();

              final mesasFiltradas = zonaFiltro == 'Todas'
                  ? mesasPorEmpleado
                  : mesasPorEmpleado.where((m) => m.zona == zonaFiltro).toList();
              final libres = mesasPorEmpleado.where((m) => m.esLibre).length;
              final ocupadas = mesasPorEmpleado.where((m) => m.esOcupada).length;

              return Column(
                children: [
                  // Resumen rápido
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF222222),
                      border: Border(bottom: BorderSide(color: Color(0xFF333333))),
                    ),
                    child: Column(
                      children: [
                        const Text('MESAS',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ResumenCounter(count: libres, label: 'LIBRES', color: Colors.green),
                            _ResumenCounter(count: ocupadas, label: 'OCUPADAS', color: Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Filtro de zonas
                  if (zonas.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: zonas
                            .map((z) => ChoiceChip(
                          label: Text(z, style: const TextStyle(fontSize: 10)),
                          selected: zonaFiltro == z,
                          onSelected: (_) => onZonaChanged(z),
                          visualDensity: VisualDensity.compact,
                          selectedColor: const Color(0xFFFFA000),
                          backgroundColor: const Color(0xFF2A2A2A),
                          labelStyle: TextStyle(
                            color: zonaFiltro == z ? Colors.black : Colors.white70,
                            fontWeight: zonaFiltro == z ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ))
                            .toList(),
                      ),
                    ),
                  // Lista de mesas
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: mesasFiltradas.length,
                      itemBuilder: (context, idx) {
                        final mesa = mesasFiltradas[idx];
                        final seleccionada = mesa.id == mesaSeleccionadaId;

                        Color colorEstado;
                        Color colorBorde;
                        if (mesa.esLibre) {
                          colorEstado = Colors.green;
                          colorBorde = Colors.green.shade700;
                        } else if (mesa.esOcupada) {
                          colorEstado = Colors.red;
                          colorBorde = Colors.red.shade700;
                        } else {
                          colorEstado = Colors.amber;
                          colorBorde = Colors.amber.shade700;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => onMesaSeleccionada(mesa.id),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: seleccionada
                                    ? const Color(0xFF333333)
                                    : const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: seleccionada
                                      ? const Color(0xFFFFA000)
                                      : colorBorde,
                                  width: seleccionada ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6, height: 36,
                                    decoration: BoxDecoration(
                                      color: colorEstado,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mesa.nombre.isNotEmpty
                                              ? mesa.nombre
                                              : 'Mesa ${mesa.numero}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700),
                                        ),
                                        Row(children: [
                                          if (mesa.numero > 0) ...[
                                            Text('Nº ${mesa.numero}',
                                                style: const TextStyle(
                                                    color: Colors.white38, fontSize: 10)),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(mesa.zona,
                                              style: const TextStyle(
                                                  color: Colors.white54, fontSize: 10)),
                                        ]),
                                        if (mesa.esOcupada && mesa.comandaId != null)
                                          StreamBuilder<DocumentSnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('empresas')
                                                .doc(mesa.empresaId)
                                                .collection('comandas')
                                                .doc(mesa.comandaId)
                                                .snapshots(),
                                            builder: (context, snap) {
                                              if (!snap.hasData || !snap.data!.exists) {
                                                return const SizedBox.shrink();
                                              }
                                              final data =
                                              snap.data!.data() as Map<String, dynamic>;
                                              final total =
                                                  (data['importe_total'] as num?)
                                                      ?.toDouble() ??
                                                      0.0;
                                              if (total <= 0) return const SizedBox.shrink();
                                              return Text(
                                                NumberFormat.currency(
                                                    symbol: '€', decimalDigits: 2)
                                                    .format(total),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.orange.shade300,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              );
                                            },
                                          ),
                                        if (empleadoFiltroUid == null &&
                                            mesa.asignadoANombre != null)
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00FFC8)
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                  color: const Color(0xFF00FFC8)
                                                      .withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.person,
                                                      size: 8,
                                                      color: Color(0xFF00FFC8)),
                                                  const SizedBox(width: 2),
                                                  Text(mesa.asignadoANombre!,
                                                      style: const TextStyle(
                                                          fontSize: 8,
                                                          color: Color(0xFF00FFC8),
                                                          fontWeight: FontWeight.w600)),
                                                ]),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // ── Botones acción ──────────────────
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _MesaActionBtn(
                                        icon: Icons.delete_outline,
                                        color: Colors.red.shade400,
                                        tooltip: 'Eliminar',
                                        onTap: () => _confirmarEliminarMesa(
                                            context, empresaId, mesa),
                                      ),
                                      const SizedBox(height: 4),
                                      _MesaActionBtn(
                                        icon: Icons.check_circle_outline,
                                        color: Colors.green.shade400,
                                        tooltip: 'Marcar libre',
                                        onTap: () async {
                                          await FirebaseFirestore.instance
                                              .collection('empresas')
                                              .doc(empresaId)
                                              .collection('mesas')
                                              .doc(mesa.id)
                                              .update({
                                            'estado': 'libre',
                                            'comanda_id': null,
                                            'camarero_uid': null,
                                            'fecha_apertura': null,
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                      _MesaActionBtn(
                                        icon: Icons.circle,
                                        color: Colors.red.shade400,
                                        tooltip: 'Marcar ocupada',
                                        onTap: () async {
                                          await FirebaseFirestore.instance
                                              .collection('empresas')
                                              .doc(empresaId)
                                              .collection('mesas')
                                              .doc(mesa.id)
                                              .update({'estado': 'ocupada'});
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // Botón flotante crear mesa
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFF00FFC8),
            foregroundColor: const Color(0xFF0A0F23),
            onPressed: () => mostrarDialogoCrearMesa(context, empresaId,
                empleadoFiltroUid: empleadoFiltroUid),
            tooltip: 'Nueva mesa',
            child: const Icon(Icons.add),
          ),
        ),
      ],
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
    BuildContext context, String empresaId, {String? empleadoFiltroUid}) async {
  // Cargar zonas existentes
  final snap = await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('mesas')
      .get();
  final zonasExistentes = snap.docs
      .map((d) => (d.data()['zona'] as String?) ?? 'Salón')
      .toSet()
      .toList();

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
    ),
  );
}

// ── NUEVO: apertura de caja ──────────────────────────────────────────────
Future<void> mostrarDialogoAperturaCaja(
    BuildContext context, String empresaId) async {
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
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 700,
        height: 520,
        child: _CierreDeCaja(empresaId: empresaId),
      ),
    ),
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
      children: [
        Text('$count',
            style: TextStyle(
                color: color, fontSize: 32, fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 9,
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

  const _ColumnaComandaActiva({
    required this.empresaId,
    this.comandaActiva,
    this.mesaId,
    required this.onComandaActualizada,
    required this.onCobrado,
    required this.onVolverAMesas,
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
                    // Botones de acción: scrollable horizontal para evitar overflow
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // ── IMPLEMENTADO: Enviar a cocina ──
                          _BotonAccion(
                            icon: Icons.send,
                            label: 'Cocina',
                            onTap: () => _enviarACocina(context),
                          ),
                          const SizedBox(width: 6),
                          // ── IMPLEMENTADO: Dividir ──
                          _BotonAccion(
                            icon: Icons.call_split,
                            label: 'Dividir',
                            onTap: comandaActiva != null &&
                                comandaActiva!.lineas.length > 1
                                ? () => _mostrarDividirComanda(
                                context,
                                empresaId,
                                mesaId!,
                                comandaActiva!,
                                onComandaActualizada)
                                : () {},
                          ),
                          const SizedBox(width: 6),
                          // ── IMPLEMENTADO: Nota general ──
                          _BotonAccion(
                            icon: Icons.note_add,
                            label: 'Nota',
                            onTap: () => _agregarNotaGeneral(context),
                          ),
                          const SizedBox(width: 6),
                          // ── NUEVO: Producto libre ──
                          _BotonAccion(
                            icon: Icons.add_circle_outline,
                            label: 'Libre',
                            onTap: () => _agregarProductoLibre(context),
                          ),
                          const SizedBox(width: 6),
                          // ── NUEVO: Descuento ──
                          _BotonAccion(
                            icon: Icons.discount_outlined,
                            label: 'Dto.',
                            onTap: comandaActiva != null &&
                                comandaActiva!.lineas.isNotEmpty
                                ? () => _aplicarDescuento(context)
                                : () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            )
                : Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text('VENTA DIRECTA',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const Spacer(),
                // Producto libre en venta directa
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
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white54),
                  tooltip: 'Limpiar',
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
          ),
          // Lista de productos
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
              padding: const EdgeInsets.all(8),
              itemCount: comandaActiva!.lineas.length,
              itemBuilder: (context, idx) {
                final linea = comandaActiva!.lineas[idx];
                return _LineaComandaCard(
                  linea: linea,
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
                  // ── IMPLEMENTADO: editar precio ──
                  onEditarPrecio: () =>
                      _editarPrecioLinea(context, idx, linea),
                  // ── IMPLEMENTADO: nota por línea ──
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
                      const Text('TOTAL:',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text(
                        fmt.format(comandaActiva!.total),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFA000),
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
                      child: Text(
                        'COBRAR ${fmt.format(comandaActiva!.total)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1),
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

  // ── IMPLEMENTADO: Producto libre (sin catálogo) ────────────────────────
  Future<void> _agregarProductoLibre(BuildContext context) async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                  labelText: 'Precio (€) *',
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
                ivaPorcentaje: 10,
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
              Navigator.pop(ctx);
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  // ── IMPLEMENTADO: Descuento sobre el total ─────────────────────────────
  Future<void> _aplicarDescuento(BuildContext context) async {
    double pct = 0;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Text('Aplicar descuento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total sin descuento: ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(comandaActiva!.total)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              // Botones rápidos de porcentaje
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
              Text(
                pct > 0
                    ? 'Descuento: - ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(comandaActiva!.total * pct / 100)}'
                : '',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx2),
            child: const Text('Cancelar')),
        // TODO: Añadir campos descuento y descuentoPct al modelo Comanda
        FilledButton(
          onPressed: pct > 0
              ? () {
            final dto = comandaActiva!.total * pct / 100;
            onComandaActualizada(comandaActiva!.copyWith(
              descuento: dto,
              descuentoPct: pct,
            ));
            Navigator.pop(ctx2);
          }
              : null,
          child: const Text('Aplicar'),
        ),
      ],
        ),
      ),
    );
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
    try {
      final pago = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogoMetodoPago(total: comanda.total),
      );
      if (pago == null) return;
      if (!context.mounted) return;

    final numeroTicket = await _obtenerSiguienteNumeroTicket(empresaId);
    if (!context.mounted) return;
    final empresaSnap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .get();
    final empresaData = empresaSnap.data() ?? {};
    final ahora = DateTime.now();
    final fechaHoraTs = Timestamp.fromDate(ahora);

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

    if (!context.mounted) { onCobrado(); return; }

    try {
      final configFact = await TpvFacturacionService().obtenerConfig(empresaId);
      if (configFact.facturacionAutomatica) {
        await TpvFacturacionService().generarFacturaPorPedido(
          empresaId: empresaId,
          pedido: pedidoCreado,
          config: configFact,
          usuarioNombre:
          FirebaseAuth.instance.currentUser?.displayName ?? 'TPV automático',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error en facturación automática: $e');
    }

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
    }

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
    }

    if (!context.mounted) { onCobrado(); return; }

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

    // ── Imprimir ticket: lógica específica por plataforma ──────────────────
    bool btConectado = false;
    final bool esWindows = !kIsWeb && Platform.isWindows;

    // En plataformas móviles, verificar Bluetooth
    if (!esWindows) {
      try {
        btConectado = await ImpressoraBluetooth().estaConectada();
      } catch (e) {
        debugPrint('⚠️ Error al verificar Bluetooth: $e');
      }
    }

    if (!context.mounted) { onCobrado(); return; }

    // ═══════════════════════════════════════════════════════════════════════
    // WINDOWS: Intentar impresión REAL Bluetooth por Serial Port
    // ═══════════════════════════════════════════════════════════════════════
    if (esWindows) {
      debugPrint('🪟 Plataforma Windows detectada - intentando impresión Bluetooth...');

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
      } catch (e) {
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
    
    // Llamar onCobrado SIEMPRE para refrescar la UI (setState interno)
    onCobrado();

    } catch (e, stackTrace) {
      debugPrint('❌ Error al procesar cobro: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar el cobro: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF2850),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Ver detalles',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Error de Cobro'),
                    content: SingleChildScrollView(child: Text('$e\n\n$stackTrace')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
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

  const _LineaComandaCard({
    required this.linea,
    required this.onCantidadChanged,
    required this.onEditarPrecio,
    required this.onEditarNota,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

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
              Expanded(
                child: Text(linea.nombre,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
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
}

// ═══════════════════════════════════════════════════════════════════════════
// COLUMNA DERECHA: CATÁLOGO (30%) — con buscador
// ═══════════════════════════════════════════════════════════════════════════

class _ColumnaCatalogoProductos extends StatelessWidget {
  final String empresaId;
  final bool esAdmin;
  final String categoriaFiltro;
  final String busqueda;
  final ValueChanged<String> onCategoriaChanged;
  final ValueChanged<String> onBusquedaChanged;
  final Function(Producto, VarianteProducto?) onProductoSeleccionado;

  const _ColumnaCatalogoProductos({
    required this.empresaId,
    required this.esAdmin,
    required this.categoriaFiltro,
    required this.busqueda,
    required this.onCategoriaChanged,
    required this.onBusquedaChanged,
    required this.onProductoSeleccionado,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaId)
            .collection('catalogo')
            .where('activo', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final productos = snap.data!.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return Producto(
              id: d.id,
              empresaId: empresaId,
              nombre: data['nombre'] ?? '',
              categoria: data['categoria'] ?? '',
              precio: (data['precio'] as num?)?.toDouble() ?? 0,
              imagenUrl: data['imagen_url'],
              thumbnailUrl: data['thumbnail_url'],
              ivaPorcentaje:
              (data['iva_porcentaje'] as num?)?.toDouble() ?? 10,
              tieneVariantes: data['tiene_variantes'] ?? false,
              variantes: ((data['variantes'] as List?) ?? [])
                  .whereType<Map>()
                  .map((v) => VarianteProducto.fromMap(
                  Map<String, dynamic>.from(v)))
                  .toList(),
              etiquetas: [],
              fechaCreacion: DateTime.now(),
            );
          }).toList();

          final categorias = {'Todos', ...productos.map((p) => p.categoria)};
          final productosFiltrados = productos.where((p) {
            if (categoriaFiltro != 'Todos' && p.categoria != categoriaFiltro)
              return false;
            if (busqueda.isNotEmpty &&
                !p.nombre.toLowerCase().contains(busqueda.toLowerCase()))
              return false;
            return true;
          }).toList();

          return Column(
            children: [
              // Header + buscador
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF222222),
                  border: Border(
                      bottom: BorderSide(color: Color(0xFF333333))),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('CATÁLOGO',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5)),
                        const Spacer(),
                        // ── Botón añadir producto (admin) ──
                        if (esAdmin)
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Color(0xFF00FFC8), size: 20),
                            tooltip: 'Nuevo producto',
                            onPressed: () =>
                                _mostrarDialogoNuevoProducto(context, empresaId),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ── IMPLEMENTADO: Buscador en columna derecha ──
                    TextField(
                      onChanged: onBusquedaChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar…',
                        hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white38, size: 18),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tabs de categorías
              Container(
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  border: Border(
                      bottom: BorderSide(color: Color(0xFF333333))),
                ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  children: categorias.map((c) {
                    final sel = categoriaFiltro == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => onCategoriaChanged(c),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFFFFA000)
                                : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              color: sel ? Colors.black : Colors.white70,
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Grid
              Expanded(
                child: productosFiltrados.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 8),
                      Text(
                        busqueda.isNotEmpty
                            ? 'Sin resultados'
                            : 'Sin productos',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 13),
                      ),
                      if (esAdmin && busqueda.isEmpty) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _mostrarDialogoNuevoProducto(
                              context, empresaId),
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir primero'),
                        ),
                      ],
                    ],
                  ),
                )
                    : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: productosFiltrados.length,
                  itemBuilder: (context, idx) {
                    final producto = productosFiltrados[idx];
                    return _ProductoCardBar(
                      producto: producto,
                      onTap: () async {
                        if (producto.tieneVariantes &&
                            producto.variantesDisponibles.isNotEmpty) {
                          final variante =
                          await VarianteSelectorWidget.mostrar(
                            context,
                            producto: producto,
                          );
                          if (variante != null) {
                            onProductoSeleccionado(producto, variante);
                          }
                        } else {
                          onProductoSeleccionado(producto, null);
                        }
                      },
                      onLongPress: esAdmin
                          ? () => _mostrarMenuContextualProducto(
                          context, empresaId, producto)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
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
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ProductoCardBar(
      {required this.producto, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(9)),
                child: (producto.thumbnailUrl != null || producto.imagenUrl != null)
                    ? Image.network(
                  producto.thumbnailUrl ?? producto.imagenUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
                    : _placeholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(producto.precio),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFA000)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Text(
          producto.nombre.isNotEmpty
              ? producto.nombre[0].toUpperCase()
              : '?',
          style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Color(0xFF444444)),
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

  const _DialogoNuevaMesa({
    required this.empresaId,
    required this.zonasExistentes,
    this.empleadoUid,
    this.empleadoNombre,
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
    final zonasFiltradas =
    widget.zonasExistentes.where((z) => z != 'Todas').toList();
    _zona = zonasFiltradas.isNotEmpty ? zonasFiltradas.first : 'Salón';
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

  final List<String> _categoriasRapidas = [
    'Bebidas', 'Cervezas', 'Vinos', 'Tapas', 'Raciones',
    'Bocadillos', 'Postres', 'Cafés', 'Menús', 'Platos',
  ];

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
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _categoriasRapidas
                    .map((cat) => ActionChip(
                  label: Text(cat,
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _categoriaCtrl.text = cat),
                ))
                    .toList(),
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
              TextField(
                controller: _efectivoMixtoCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importe en efectivo (€)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tarjetaMixtoCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importe en tarjeta (€)',
                  prefixIcon: Icon(Icons.credit_card),
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
        };
        _cargando = false;
      });
    }
  }

  Future<void> _confirmarCierre() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar cierre de caja'),
        content: const Text(
            'Esta acción registrará el cierre del día. ¿Continuar?'),
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
    if (confirmar != true) return;
    setState(() => _cerrando = true);
    try {
      final svc = CierreCajaService();
      final cierre =
      await svc.calcularCierreCaja(widget.empresaId, DateTime.now());
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

  Future<void> _generarZReport() async {
    final d = _datos!;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
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
                  pw.Text(fmt.format(d['total'])),
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
                  pw.Text(fmt.format(d['ticket_medio'])),
                ]),
            pw.SizedBox(height: 16),
            pw.Text('MÉTODO DE PAGO',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Efectivo'),
                  pw.Text(fmt.format(d['efectivo'])),
                ]),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tarjeta'),
                  pw.Text(fmt.format(d['tarjeta'])),
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
                  pw.Text(fmt.format(d['base_imponible'])),
                ]),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cuota IVA'),
                  pw.Text(fmt.format(d['cuota_iva'])),
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
                    pw.Text('×${entry.value}'),
                  ]);
            }),
            pw.SizedBox(height: 24),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Ayer',
                      style: pw.TextStyle(color: PdfColors.grey600)),
                  pw.Text(fmt.format(d['total_ayer']),
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
  final nombreMesaOriginal = mesaOriginalSnap.exists
      ? (mesaOriginalSnap.data()?['nombre'] as String? ?? 'Mesa')
      : 'Mesa';
  final zonaMesa = mesaOriginalSnap.exists
      ? (mesaOriginalSnap.data()?['zona'] as String? ?? 'Salón')
      : 'Salón';

  // Extraer nombre base (quitar " — Ticket X" si ya fue dividida antes)
  final _ticketRegExp = RegExp(r'\s+—\s+Ticket\s+\d+$');
  final nombreBase = nombreMesaOriginal.replaceAll(_ticketRegExp, '');

  // Contar cuántos tickets ya existen para esta mesa base
  final ticketsExistentes = await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('mesas')
      .get();
  final ticketCount = ticketsExistentes.docs
      .where((d) {
        final n = (d.data()['nombre'] as String? ?? '');
        return n == nombreBase || n.startsWith('$nombreBase — Ticket');
      })
      .length;
  // ticketCount incluye la mesa original → próximo número = ticketCount + 1
  final numTicketNuevo = ticketCount + 1;

  // Renombrar mesa original a "NombreBase — Ticket 1" si aún no lo está
  if (!nombreMesaOriginal.contains('— Ticket')) {
    await db.collection('mesas').doc(mesaOrigenId).update({
      'nombre': '$nombreBase — Ticket 1',
    });
  }

  // Crear nueva mesa para la parte dividida
  final nuevaMesaRef = await FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('mesas')
      .add({
    'nombre': '$nombreBase — Ticket $numTicketNuevo',
    'zona': zonaMesa,
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
          '✅ Dividida: "$nombreBase — Ticket 1" y "$nombreBase — Ticket $numTicketNuevo" visibles en el panel de mesas.',
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
  final ref = FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('contadores')
      .doc('tickets');

  int siguiente = 1;
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (snap.exists) {
      siguiente =
          ((snap.data()?['ultimo'] as num?)?.toInt() ?? 0) + 1;
    } else {
      siguiente = 1;
    }
    tx.set(ref, {'ultimo': siguiente}, SetOptions(merge: true));
  });
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
  const _FilaSimple({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) => Row(
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

