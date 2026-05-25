// tpv_tienda_screen.dart — versión completa
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
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../domain/modelos/comanda.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../services/pedidos_service.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../widgets/tpv_type_switcher.dart';
import '../widgets/dialogo_devoluciones.dart';
import '../widgets/empleados_banner_widget.dart';
import '../../../services/tpv/impresora_bluetooth_service.dart';
import '../../../services/tpv/cierre_caja_service.dart';
import '../../pedidos/widgets/variante_selector_widget.dart';
import 'configuracion_facturacion_tpv_screen.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

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

  const TpvTiendaScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
    this.esPropietario = false,
  });

  @override
  State<TpvTiendaScreen> createState() => _TpvTiendaState();
}

class _TpvTiendaState extends State<TpvTiendaScreen> {
  final _db = FirebaseFirestore.instance;

  Comanda? _comandaActiva;
  _TicketExtra _extra = const _TicketExtra();

  String _categoriaFiltro = 'Todos';
  String _busqueda = '';
  bool _mostrandoCierre = false;
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
    _connectivitySub?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _actualizarHora() {
    if (mounted)
      setState(
              () => _horaActual = DateFormat('HH:mm').format(DateTime.now()));
  }

  double get _totalConDescuento =>
      ((_comandaActiva?.total ?? 0) - _extra.descuento)
          .clamp(0, double.infinity);

  void _limpiarTicket() => setState(() {
    _comandaActiva = null;
    _extra = const _TicketExtra();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(),
      body: _mostrandoCierre
          ? _TiendaCierreDeCaja(empresaId: widget.empresaId)
          : Column(children: [
              // ── Franja de empleados activos ────────────────────────────────
              EmpleadosBannerWidget(
                empresaId: widget.empresaId,
                empleadoSeleccionadoId: _empleadoSeleccionadoId,
                onEmpleadoChanged: (id) => setState(() => _empleadoSeleccionadoId = id),
                colorPrimario: const Color(0xFF43A047),
                colorFondo: const Color(0xFF1B5E20),
              ),
              // ── Layout principal ───────────────────────────────────────────
              Expanded(
                child: Row(children: [
              // Catálogo 60%
              Expanded(
                flex: 6,
                child: _TiendaCatalogoPanel(
                  empresaId: widget.empresaId,
                  esAdmin: _esAdmin,
                  categoriaFiltro: _categoriaFiltro,
                  busqueda: _busqueda,
                  onCategoriaChanged: (c) =>
                      setState(() => _categoriaFiltro = c),
                  onBusquedaChanged: (b) => setState(() => _busqueda = b),
                  onProductoSeleccionado: _agregarProducto,
                  onProductoNoEncontrado: (codigo) =>
                      _productoNoEncontrado(codigo),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              // Ticket 40%
              Expanded(
                flex: 4,
                child: _TiendaComandaPanel(
                  empresaId: widget.empresaId,
                  comandaActiva: _comandaActiva,
                  extra: _extra,
                  totalConDescuento: _totalConDescuento,
                  onComandaActualizada: (c) =>
                      setState(() => _comandaActiva = c),
                  onExtraChanged: (e) => setState(() => _extra = e),
                  onCobrado: _limpiarTicket,
                  onLimpiar: _limpiarTicket,
                  onProductoLibre: () => _agregarProductoLibre(),
                ),
              ),
            ]),
              ),
          ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1B5E20),
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 48,
      title: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const Icon(Icons.store, size: 20),
        const SizedBox(width: 8),
        const Text('TPV Tienda',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(width: 12),
        // Nombre empresa
        StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('empresas').doc(widget.empresaId).snapshots(),
          builder: (_, snap) {
            if (!snap.hasData || !snap.data!.exists)
              return const SizedBox.shrink();
            final data = snap.data!.data() as Map<String, dynamic>;
            final nombre = data['nombre'] as String? ?? 'Mi Tienda';
            final logo = data['logo_url'] as String?;
            return Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: Colors.white24,
                backgroundImage: logo != null ? NetworkImage(logo) : null,
                child: logo == null
                    ? Text(nombre[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 6),
              Text(nombre,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ]);
          },
        ),
        const Spacer(),
        // Devoluciones
        IconButton(
          icon: const Icon(Icons.keyboard_return, size: 16),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => DialogoDevoluciones(
              empresaId: widget.empresaId,
              colorPrimario: const Color(0xFF1B5E20),
            ),
          ),
          tooltip: 'Devoluciones',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
        // Apertura de caja
        IconButton(
          icon: const Icon(Icons.account_balance_wallet, size: 16),
          onPressed: () => _mostrarAperturaCaja(),
          tooltip: 'Apertura de caja',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
        Text(_horaActual, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 8),
        Icon(_estaOnline ? Icons.wifi : Icons.wifi_off,
            size: 14,
            color: _estaOnline ? Colors.white70 : Colors.orangeAccent),
        const SizedBox(width: 6),
        Icon(Icons.print,
            size: 14,
            color: _btConectado ? Colors.white70 : Colors.white38),
        const SizedBox(width: 8),
        TpvTypeSwitcher(
          tipoActual: 'tienda',
          onTipoChanged: (_) => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.summarize_outlined,
              size: 18,
              color: _mostrandoCierre ? Colors.amber : Colors.white70),
          onPressed: () =>
              setState(() => _mostrandoCierre = !_mostrandoCierre),
          tooltip: _mostrandoCierre ? 'Volver a ventas' : 'Cierre de caja',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  // ── Agregar producto del catálogo ────────────────────────────────────────

  void _agregarProducto(Producto producto, VarianteProducto? variante) {
    final precio =
        variante?.precioEfectivo(producto.precio) ?? producto.precio;
    final linea = LineaComanda(
      productoId: producto.id,
      nombre: variante != null
          ? '${producto.nombre} (${variante.nombre})'
          : producto.nombre,
      cantidad: 1,
      precioUnitario: precio,
      ivaPorcentaje: producto.ivaPorcentaje,
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
                backgroundColor: const Color(0xFF1B5E20)),
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

  // ── Apertura de caja ──────────────────────────────────────────────────────

  Future<void> _mostrarAperturaCaja() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
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
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
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
              final fondo =
                  double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
              await _db
                  .collection('empresas')
                  .doc(widget.empresaId)
                  .collection('aperturas_caja')
                  .add({
                'fondo_inicial': fondo,
                'fecha': FieldValue.serverTimestamp(),
                'camarero_uid':
                FirebaseAuth.instance.currentUser?.uid ?? '',
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text(
                      'Caja abierta con fondo de ${fondo.toStringAsFixed(2)} €'),
                  backgroundColor: Colors.green.shade700,
                ));
              }
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20)),
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

class _TiendaCatalogoPanel extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final String categoriaFiltro;
  final String busqueda;
  final ValueChanged<String> onCategoriaChanged;
  final ValueChanged<String> onBusquedaChanged;
  final Function(Producto, VarianteProducto?) onProductoSeleccionado;
  final ValueChanged<String> onProductoNoEncontrado;

  const _TiendaCatalogoPanel({
    required this.empresaId,
    required this.esAdmin,
    required this.categoriaFiltro,
    required this.busqueda,
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
            padding: const EdgeInsets.all(12),
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
                hintText: 'Buscar o escanear código de barras…',
                prefixIcon: const Icon(Icons.search, size: 20),
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
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
            ),
          ),
          // Chips de categoría + botón nueva categoría (admin)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              ...categorias.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c),
                  selected: widget.categoriaFiltro == c,
                  onSelected: (_) => widget.onCategoriaChanged(c),
                ),
              )),
              if (widget.esAdmin)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: const Text('Nuevo producto',
                        style: TextStyle(fontSize: 11)),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => _DialogoNuevoProducto(
                          empresaId: widget.empresaId),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
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
                          backgroundColor: const Color(0xFF1B5E20)),
                    ),
                  ],
                ]),
              ),
            )
          else
          // Grid de productos
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 155,
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
                      if (item.stock == 0) return;
                      if (item.producto.tieneVariantes &&
                          item.producto.variantesDisponibles.isNotEmpty) {
                        final v = await VarianteSelectorWidget.mostrar(
                          context,
                          producto: item.producto,
                        );
                        if (v != null) {
                          widget.onProductoSeleccionado(item.producto, v);
                        }
                      } else {
                        widget.onProductoSeleccionado(item.producto, null);
                      }
                    },
                    onEditar: widget.esAdmin
                        ? () => showDialog(
                      context: context,
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
                          'iva_porcentaje':
                          item.producto.ivaPorcentaje,
                        },
                      ),
                    )
                        : null,
                  );
                },
              ),
            ),
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
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final sinStock = stock == 0;
    final stockBajo =
        stock != null && stock! > 0 && stock! <= stockMinimo && stockMinimo > 0;

    return Opacity(
      opacity: sinStock ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: sinStock ? null : onTap,
        onLongPress: onEditar,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Imagen / placeholder
            Expanded(
              child: Stack(children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10)),
                  ),
                  child: producto.thumbnailUrl != null
                      ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10)),
                      child: Image.network(producto.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholder()))
                      : _placeholder(),
                ),
                // Overlay sin stock
                if (sinStock)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('SIN STOCK',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                // Badge editar (admin, long press)
                if (esAdmin)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.edit,
                          size: 10, color: Colors.white70),
                    ),
                  ),
              ]),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fmt.format(producto.precio),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B5E20))),
                      if (stock != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: stockBajo
                                ? Colors.amber.shade100
                                : sinStock
                                ? Colors.red.shade100
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (stockBajo)
                              Icon(Icons.warning_amber,
                                  size: 9,
                                  color: Colors.amber.shade700),
                            Text(
                              '$stock',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: stockBajo
                                    ? Colors.amber.shade800
                                    : sinStock
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder() => Center(
    child: Text(
      producto.nombre.isNotEmpty
          ? producto.nombre[0].toUpperCase()
          : '?',
      style: const TextStyle(
          fontSize: 30, fontWeight: FontWeight.w700, color: Colors.grey),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PANEL DE TICKET — con descuento, cliente, editar precio y cantidad manual
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
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final cs = Theme.of(context).colorScheme;

    return Column(children: [
      // ── Header ────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Row(children: [
          const Icon(Icons.shopping_cart_outlined, size: 16),
          const SizedBox(width: 6),
          const Text('Venta directa',
              style:
              TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          // Producto libre
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            tooltip: 'Producto libre',
            onPressed: onProductoLibre,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Descuento
          IconButton(
            icon: Icon(
              Icons.discount_outlined,
              size: 18,
              color: extra.descuento > 0 ? Colors.green : null,
            ),
            tooltip: 'Descuento',
            onPressed: (comandaActiva?.lineas.isNotEmpty ?? false)
                ? () => _aplicarDescuento(context)
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // Limpiar
          if (comandaActiva != null && comandaActiva!.lineas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Limpiar ticket',
              onPressed: onLimpiar,
              padding: EdgeInsets.zero,
              constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ]),
      ),

      // ── Buscador de cliente ───────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: _ClienteBuscadorTienda(
          empresaId: empresaId,
          clienteActual: extra.clienteNombre,
          onSeleccionado: (c) => onExtraChanged(extra.copyWith(
            clienteNombre: c['nombre'] as String?,
            clienteId: c['id'] as String?,
          )),
          onLimpiar: () => onExtraChanged(extra.copyWith(limpiarCliente: true)),
        ),
      ),

      // ── Líneas ────────────────────────────────────────────────────────
      Expanded(
        child: (comandaActiva == null || comandaActiva!.lineas.isEmpty)
            ? Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shopping_cart_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            const Text('Ticket vacío',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onProductoLibre,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir producto libre',
                  style: TextStyle(fontSize: 12)),
            ),
          ]),
        )
            : ListView.builder(
          itemCount: comandaActiva!.lineas.length,
          itemBuilder: (context, idx) {
            final linea = comandaActiva!.lineas[idx];
            return _TiendaLineaCard(
              linea: linea,
              onCantidadChanged: (delta) {
                final nueva = linea.cantidad + delta;
                final lineas = List<LineaComanda>.from(
                    comandaActiva!.lineas);
                if (nueva <= 0) {
                  lineas.removeAt(idx);
                } else {
                  lineas[idx] = linea.copyWith(cantidad: nueva);
                }
                onComandaActualizada(
                    comandaActiva!.copyWith(lineas: lineas));
              },
              onEditarPrecio: () =>
                  _editarPrecio(context, idx, linea),
              onEditarCantidad: () =>
                  _editarCantidad(context, idx, linea),
            );
          },
        ),
      ),

      // ── Footer ───────────────────────────────────────────────────────
      if (comandaActiva != null && comandaActiva!.lineas.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Subtotal:',
                  style: TextStyle(fontSize: 12)),
              Text(fmt.format(comandaActiva!.baseImponible),
                  style: const TextStyle(fontSize: 12)),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('IVA:', style: TextStyle(fontSize: 12)),
              Text(fmt.format(comandaActiva!.cuotaIva),
                  style: const TextStyle(fontSize: 12)),
            ]),
            if (extra.descuento > 0)
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Descuento (${extra.descuentoPct.toStringAsFixed(0)}%):',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.green),
                    ),
                    Text(
                      '- ${fmt.format(extra.descuento)}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.green),
                    ),
                  ]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('TOTAL:',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Text(fmt.format(totalConDescuento),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => _cobrar(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFF1B5E20),
              ),
              child: Text('Cobrar ${fmt.format(totalConDescuento)}'),
            ),
          ]),
        ),
    ]);
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
                  backgroundColor: const Color(0xFF1B5E20)),
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
                backgroundColor: const Color(0xFF1B5E20)),
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
                backgroundColor: const Color(0xFF1B5E20)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Cobrar ────────────────────────────────────────────────────────────

  Future<void> _cobrar(BuildContext context) async {
    if (comandaActiva == null || comandaActiva!.lineas.isEmpty) return;

    final pago = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TiendaDialogoPago(total: totalConDescuento),
    );
    if (pago == null) return;

    final ahora = DateTime.now();

    final ref = FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
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
        .doc(empresaId)
        .get();
    final empresaData = empresaSnap.data() ?? {};

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
        mesaId: null,
        estado: 'entregado',
        estadoPago: 'pagado',
        fechaHora: Timestamp.fromDate(ahora),
      );

      // Facturación automática
      try {
        final cfg =
        await TpvFacturacionService().obtenerConfig(empresaId);
        if (cfg.facturacionAutomatica) {
          await TpvFacturacionService().generarFacturaPorPedido(
            empresaId: empresaId,
            pedido: pedido,
            config: cfg,
            usuarioNombre:
            FirebaseAuth.instance.currentUser?.displayName ??
                'TPV Tienda',
          );
        }
      } catch (_) {}

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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Ticket #$numTicket cobrado — ${totalConDescuento.toStringAsFixed(2)} €'),
          backgroundColor: Colors.green.shade700,
        ));
        onCobrado();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al cobrar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}

// ── Tarjeta de línea con editar precio y cantidad ────────────────────────────

class _TiendaLineaCard extends StatelessWidget {
  final LineaComanda linea;
  final ValueChanged<int> onCantidadChanged;
  final VoidCallback onEditarPrecio;
  final VoidCallback onEditarCantidad;

  const _TiendaLineaCard({
    required this.linea,
    required this.onCantidadChanged,
    required this.onEditarPrecio,
    required this.onEditarCantidad,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          border: Border(
              bottom:
              BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(children: [
        // Nombre + precio editable
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(linea.nombre,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: onEditarPrecio,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.edit, size: 10, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text(fmt.format(linea.precioUnitario),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ]),
              ),
            ),
          ]),
        ),
        // Controles de cantidad
        GestureDetector(
          onTap: onEditarCantidad, // tap en número → editar manualmente
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              onPressed: () => onCantidadChanged(-1),
              padding: EdgeInsets.zero,
              constraints:
              const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${linea.cantidad}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              onPressed: () => onCantidadChanged(1),
              padding: EdgeInsets.zero,
              constraints:
              const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ]),
        ),
        // Total línea
        SizedBox(
          width: 64,
          child: Text(fmt.format(linea.total),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Buscador de cliente (tienda) ─────────────────────────────────────────────

class _ClienteBuscadorTienda extends StatefulWidget {
  final String empresaId;
  final String? clienteActual;
  final ValueChanged<Map<String, dynamic>> onSeleccionado;
  final VoidCallback onLimpiar;

  const _ClienteBuscadorTienda({
    required this.empresaId,
    this.clienteActual,
    required this.onSeleccionado,
    required this.onLimpiar,
  });

  @override
  State<_ClienteBuscadorTienda> createState() =>
      _ClienteBuscadorTiendaState();
}

class _ClienteBuscadorTiendaState extends State<_ClienteBuscadorTienda> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _buscar(String valor) {
    _debounce?.cancel();
    if (valor.length < 2) {
      setState(() => _resultados = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
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
              .map((d) =>
          {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clienteActual != null) {
      return Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(children: [
          const Icon(Icons.person, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(widget.clienteActual!,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () {
              _ctrl.clear();
              widget.onLimpiar();
            },
            child: const Icon(Icons.close, size: 14, color: Colors.grey),
          ),
        ]),
      );
    }

    return Column(children: [
      TextField(
        controller: _ctrl,
        onChanged: _buscar,
        decoration: InputDecoration(
          hintText: 'Buscar cliente…',
          hintStyle: const TextStyle(fontSize: 11),
          prefixIcon: const Icon(Icons.person_search, size: 16),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 12),
      ),
      if (_resultados.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: _resultados
                .map((c) => InkWell(
              onTap: () {
                widget.onSeleccionado(c);
                _ctrl.clear();
                setState(() => _resultados = []);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(c['nombre'] as String? ?? '',
                        style:
                        const TextStyle(fontSize: 12)),
                  ),
                  Text(c['telefono'] as String? ?? '',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500)),
                ]),
              ),
            ))
                .toList(),
          ),
        ),
      const SizedBox(height: 6),
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
                    labelText: 'Precio (€) *',
                    prefixIcon: Icon(Icons.euro),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
              backgroundColor: const Color(0xFF1B5E20)),
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
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
              backgroundColor: const Color(0xFF1B5E20)),
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
  const _TiendaDialogoPago({required this.total});

  @override
  State<_TiendaDialogoPago> createState() => _TiendaDialogoPagoState();
}

class _TiendaDialogoPagoState extends State<_TiendaDialogoPago> {
  String _metodo = 'efectivo';
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
          Row(children: [
            _TChip(
              label: 'Efectivo',
              icon: Icons.payments_outlined,
              selected: _metodo == 'efectivo',
              onTap: () => setState(() => _metodo = 'efectivo'),
              color: const Color(0xFF4CAF50),
            ),
            const SizedBox(width: 8),
            _TChip(
              label: 'Tarjeta',
              icon: Icons.credit_card,
              selected: _metodo == 'tarjeta',
              onTap: () => setState(() => _metodo = 'tarjeta'),
              color: const Color(0xFF2196F3),
            ),
            const SizedBox(width: 8),
            _TChip(
              label: 'Mixto',
              icon: Icons.swap_horiz,
              selected: _metodo == 'mixto',
              onTap: () => setState(() => _metodo = 'mixto'),
              color: const Color(0xFFFF9800),
            ),
          ]),
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
          onPressed: () {
            double ef = 0, tj = 0;
            if (_metodo == 'efectivo') {
              ef = widget.total;
            } else if (_metodo == 'tarjeta') {
              tj = widget.total;
            } else {
              ef = double.tryParse(
                  _efectivoCtrl.text.replaceAll(',', '.')) ??
                  0;
              tj = double.tryParse(
                  _tarjetaCtrl.text.replaceAll(',', '.')) ??
                  0;
              if ((ef + tj - widget.total).abs() > 0.01) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Los importes no suman el total')),
                );
                return;
              }
            }
            Navigator.pop(context, {
              'metodo': _metodo,
              'importe_efectivo': ef,
              'importe_tarjeta': tj,
            });
          },
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20)),
          child: const Text('Confirmar cobro'),
        ),
      ],
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CIERRE DE CAJA (sin cambios respecto al original)
// ═══════════════════════════════════════════════════════════════════════════

class _TiendaCierreDeCaja extends StatefulWidget {
  final String empresaId;
  const _TiendaCierreDeCaja({required this.empresaId});

  @override
  State<_TiendaCierreDeCaja> createState() =>
      _TiendaCierreDeCajaState();
}

class _TiendaCierreDeCajaState extends State<_TiendaCierreDeCaja> {
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
        .where('fecha_hora',
        isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_hora', isLessThan: Timestamp.fromDate(fin))
        .where('estado_pago', isEqualTo: 'pagado')
        .get();

    final snapAyer = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('pedidos')
        .where('fecha_hora',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
            inicio.subtract(const Duration(days: 1))))
        .where('fecha_hora', isLessThan: Timestamp.fromDate(inicio))
        .where('estado_pago', isEqualTo: 'pagado')
        .get();

    double ef = 0, tj = 0;
    final top = <String, int>{};

    for (final doc in snapHoy.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final met = d['metodo_pago'] as String? ?? 'efectivo';
      if (met == 'efectivo') {
        ef += (d['importe_efectivo'] as num?)?.toDouble() ??
            (d['importe_total'] as num?)?.toDouble() ??
            0;
      } else if (met == 'tarjeta') {
        tj += (d['importe_tarjeta'] as num?)?.toDouble() ??
            (d['importe_total'] as num?)?.toDouble() ??
            0;
      } else {
        ef += (d['importe_efectivo'] as num?)?.toDouble() ?? 0;
        tj += (d['importe_tarjeta'] as num?)?.toDouble() ?? 0;
      }
      for (final l in d['lineas'] as List? ?? []) {
        final nombre = l['producto_nombre'] as String? ?? '';
        top[nombre] =
            (top[nombre] ?? 0) + ((l['cantidad'] as num?)?.toInt() ?? 1);
      }
    }

    double totalAyer = 0;
    for (final doc in snapAyer.docs) {
      totalAyer +=
          ((doc.data() as Map<String, dynamic>)['importe_total'] as num?)
              ?.toDouble() ??
              0;
    }

    final total = ef + tj;
    if (mounted) {
      setState(() {
        _datos = {
          'total': total,
          'efectivo': ef,
          'tarjeta': tj,
          'num_tickets': snapHoy.docs.length,
          'ticket_medio':
          snapHoy.docs.isEmpty ? 0.0 : total / snapHoy.docs.length,
          'base_imponible': total / 1.21,
          'cuota_iva': total - total / 1.21,
          'total_ayer': totalAyer,
          'top': (top.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
              .take(3)
              .toList(),
        };
        _cargando = false;
      });
    }
  }

  Future<void> _confirmarCierre() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar cierre de caja'),
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
      final cierre =
      await svc.calcularCierreCaja(widget.empresaId, DateTime.now());
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

  Future<void> _generarZReport() async {
    if (_datos == null) return;
    final d = _datos!;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final hoy = DateTime.now();
    final fecha =
        '${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}';
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
              child: pw.Text('Z-REPORT — TIENDA',
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
          _pRow('Total ventas', fmt.format(d['total'])),
          _pRow('Tickets', '${d['num_tickets']}'),
          _pRow('Ticket medio', fmt.format(d['ticket_medio'])),
          pw.SizedBox(height: 10),
          _pRow('Efectivo', fmt.format(d['efectivo'])),
          _pRow('Tarjeta', fmt.format(d['tarjeta'])),
          pw.SizedBox(height: 10),
          _pRow('Base imponible', fmt.format(d['base_imponible'])),
          _pRow('Cuota IVA (21%)', fmt.format(d['cuota_iva'])),
          pw.SizedBox(height: 10),
          _pRow('Total ayer', fmt.format(d['total_ayer'])),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('TOP PRODUCTOS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...(d['top'] as List).asMap().entries.map((e) {
            final entry = e.value as MapEntry<String, int>;
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${e.key + 1}. ${entry.key}'),
                pw.Text('×${entry.value}'),
              ],
            );
          }),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  pw.Widget _pRow(String l, String v) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [pw.Text(l), pw.Text(v)],
  );

  @override
  Widget build(BuildContext context) {
    if (_cargando)
      return const Center(child: CircularProgressIndicator());
    final d = _datos!;
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final hoy = DateTime.now();
    final fecha =
        '${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}';
    final cs = Theme.of(context).colorScheme;

    return Column(children: [
      Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Flexible(
            child: Text('Cierre — $fecha',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _generarZReport,
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
              backgroundColor: const Color(0xFF1B5E20),
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
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Refrescar',
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
                color: const Color(0xFF1B5E20)),
            _cifra('Tickets', '${d['num_tickets']}'),
            _cifra('Ticket medio', fmt.format(d['ticket_medio'])),
            _tarjeta('Método de pago', [
              _fila('Efectivo', fmt.format(d['efectivo'])),
              const SizedBox(height: 4),
              _fila('Tarjeta', fmt.format(d['tarjeta'])),
            ]),
            _tarjeta('Desglose IVA (21%)', [
              _fila('Base imponible', fmt.format(d['base_imponible'])),
              const SizedBox(height: 4),
              _fila('Cuota IVA', fmt.format(d['cuota_iva'])),
            ]),
            _tarjeta('Comparativa', [
              _fila('Hoy', fmt.format(d['total'])),
              const SizedBox(height: 4),
              _fila('Ayer', fmt.format(d['total_ayer'])),
            ]),
            _tarjeta('Top productos', [
              ...(d['top'] as List).asMap().entries.map((e) {
                final entry = e.value as MapEntry<String, int>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Text('${e.key + 1}.',
                        style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(entry.key,
                            style: const TextStyle(fontSize: 12))),
                    Text('×${entry.value}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12)),
                  ]),
                );
              }),
            ]),
          ]),
        ),
      ),
    ]);
  }

  Widget _cifra(String label, String valor, {Color? color}) => SizedBox(
    width: 160,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
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
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    ),
  );

  Widget _tarjeta(String titulo, List<Widget> children) => SizedBox(
    width: 200,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color:
            Theme.of(context).colorScheme.outlineVariant,
            width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
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


