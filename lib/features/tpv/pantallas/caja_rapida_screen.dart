import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../domain/modelos/configuracion_facturacion_tpv.dart';
import '../../../services/pedidos_service.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../widgets/dialogo_factura_tpv.dart';
import '../../../services/tpv/impresora_service.dart';
import '../../../services/tpv/facturacion_automatica_service.dart';
import '../../../widgets/tpv/historial_tickets_widget.dart';
import '../../../widgets/tpv/hold_pedidos_widget.dart';
import '../../../widgets/tpv/estadisticas_turno_widget.dart';
import 'caja_rapida_helpers.dart';
import 'caja_rapida_widgets.dart';

class CajaRapidaScreen extends StatefulWidget {
  final String empresaId;
  const CajaRapidaScreen({super.key, required this.empresaId});
  @override
  State<CajaRapidaScreen> createState() => _CajaRapidaScreenState();
}

class _CajaRapidaScreenState extends State<CajaRapidaScreen>
    with SingleTickerProviderStateMixin {
  final _svc = PedidosService();
  final _facturacionSvc = TpvFacturacionService();
  final _facturacionAuto = FacturacionAutomaticaService();
  final _impresora = ImpresoraService();
  final _holdNotifier = HoldPedidosNotifier();

  final List<LineaTicket> _lineas = [];
  MetodoPago _metodoPago = MetodoPago.efectivo;
  final _entregaCtrl = TextEditingController();
  final _efectivoMixtoCtrl = TextEditingController();
  final _tarjetaMixtoCtrl = TextEditingController();
  bool _cobrando = false;
  double _descuentoCupon = 0;

  ConfiguracionFacturacionTpv? _configTpv;
  Uint8List? _ultimoPdf;
  String? _ultimoPedidoId;

  String _busqueda = '';
  String? _categoriaFiltro;
  final _busCtrl = TextEditingController();
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _facturacionSvc.obtenerConfig(widget.empresaId).then((c) {
      if (mounted) setState(() => _configTpv = c);
    }).catchError((_) {
      if (mounted) setState(() => _configTpv = const ConfiguracionFacturacionTpv());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _busCtrl.dispose();
    _entregaCtrl.dispose();
    _efectivoMixtoCtrl.dispose();
    _tarjetaMixtoCtrl.dispose();
    _holdNotifier.dispose();
    super.dispose();
  }

  double get _totalBruto => _lineas.fold(0.0, (s, l) => s + l.subtotal);
  double get _total => (_totalBruto - _descuentoCupon).clamp(0, double.infinity);
  double get _cambio {
    final e = double.tryParse(_entregaCtrl.text.replaceAll(',', '.')) ?? 0;
    return (e - _total).clamp(0, double.infinity);
  }
  String _fmt(double v) =>
      NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2).format(v);
  String _nombrePago(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.tarjeta  => 'Tarjeta',
        MetodoPago.mixto    => 'Mixto',
        MetodoPago.bizum    => 'Bizum',
        MetodoPago.paypal   => 'PayPal',
      };

  // ── ACCIONES ───────────────────────────────────────────────────────────────

  void _agregarProducto(Producto p) {
    setState(() {
      final idx = _lineas.indexWhere((l) => l.productoId == p.id);
      if (idx >= 0) {
        _lineas[idx].cantidad++;
      } else {
        _lineas.add(LineaTicket(
            productoId: p.id, nombre: p.nombre, precioUnitario: p.precio));
      }
    });
  }

  Future<void> _guardarEnEspera() async {
    if (_lineas.isEmpty) return;
    final label = await pedirEtiquetaEspera(context);
    if (label == null) return;
    _holdNotifier.guardar(
      etiqueta: label,
      lineas: _lineas.map((l) => {
        'productoId': l.productoId, 'nombre': l.nombre,
        'precio': l.precioUnitario, 'cantidad': l.cantidad,
      }).toList(),
      total: _total,
    );
    setState(() { _lineas.clear(); _descuentoCupon = 0; });
  }

  Future<void> _recuperarPedido() async {
    final rec = await HoldPedidosWidget.mostrar(context, _holdNotifier);
    if (rec != null) {
      setState(() {
        _lineas.clear(); _descuentoCupon = 0;
        for (final l in rec.lineas) {
          _lineas.add(LineaTicket(
            productoId: l['productoId'] as String? ?? '',
            nombre: l['nombre'] as String? ?? '',
            precioUnitario: (l['precio'] as num?)?.toDouble() ?? 0,
          )..cantidad = (l['cantidad'] as num?)?.toInt() ?? 1);
        }
      });
    }
  }

  void _limpiarTicket() => setState(() {
    _lineas.clear(); _metodoPago = MetodoPago.efectivo;
    _entregaCtrl.clear(); _efectivoMixtoCtrl.clear(); _tarjetaMixtoCtrl.clear();
    _ultimoPdf = null; _ultimoPedidoId = null; _descuentoCupon = 0;
  });

  // ── COBRAR ─────────────────────────────────────────────────────────────────

  Future<void> _cobrar() async {
    String paso = 'Validación inicial';
    try {
      if (_lineas.isEmpty) return;
      if (_metodoPago == MetodoPago.mixto) {
        paso = 'Validación pago mixto';
        final ef = double.tryParse(_efectivoMixtoCtrl.text.replaceAll(',', '.')) ?? 0;
        final ta = double.tryParse(_tarjetaMixtoCtrl.text.replaceAll(',', '.')) ?? 0;
        if ((ef + ta - _total).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Importe mixto (${_fmt(ef + ta)}) ≠ total (${_fmt(_total)})'),
            backgroundColor: Colors.red,
          ));
          return;
        }
      }
      paso = 'Confirmación';
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirmar cobro'),
          content: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total: ${_fmt(_total)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Método: ${_nombrePago(_metodoPago)}'),
            if (_metodoPago == MetodoPago.efectivo && _entregaCtrl.text.isNotEmpty)
              Text('Cambio: ${_fmt(_cambio)}'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('COBRAR')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => _cobrando = true);

      paso = 'Creando pedido';
      final pedido = await _svc.crearPedido(
        empresaId: widget.empresaId,
        clienteNombre: 'Cliente TPV',
        lineas: _lineas.map((l) => LineaPedido(
          productoId: l.productoId, productoNombre: l.nombre,
          precioUnitario: l.precioUnitario, cantidad: l.cantidad,
        )).toList(),
        origen: OrigenPedido.presencial,
        metodoPago: _metodoPago,
        notasInternas: 'Venta TPV caja rápida',
        usuarioNombre: 'TPV',
      );
      paso = 'Marcando entregado';
      await _svc.cambiarEstado(widget.empresaId, pedido.id, EstadoPedido.entregado, '', 'TPV');
      paso = 'Marcando pagado';
      await _svc.cambiarEstadoPago(widget.empresaId, pedido.id, EstadoPago.pagado, '', 'TPV');
      if (!mounted) return;
      await DialogoFacturaTpv.mostrar(
        context: context, empresaId: widget.empresaId,
        pedido: pedido, terminalId: 'caja_rapida',
      );
      if (!mounted) return;
      final ticket = generarTicketTexto(
        lineas: _lineas, total: _total, metodoPago: _metodoPago,
        cambio: _cambio, pedidoId: pedido.id, fmt: _fmt, nombrePago: _nombrePago,
      );
      _mostrarDialogoExito(ticket, null);
    } catch (e, stack) {
      await mostrarErrorCritico(context, paso, e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al cobrar en: $paso'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _cobrando = false);
    }
  }

  void _mostrarDialogoExito(String ticket, Uint8List? pdfBytes) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8), Text('¡Cobro realizado!'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Total cobrado: ${_fmt(_total)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_metodoPago == MetodoPago.efectivo && _cambio > 0)
            Padding(padding: const EdgeInsets.only(top: 8),
              child: Text('Cambio: ${_fmt(_cambio)}',
                  style: const TextStyle(fontSize: 16, color: Colors.green))),
        ]),
        actions: [
          if (pdfBytes != null) ...[
            TextButton.icon(icon: const Icon(Icons.visibility, size: 18), label: const Text('Ver PDF'),
                onPressed: () async => Printing.layoutPdf(onLayout: (_) => pdfBytes)),
            TextButton.icon(icon: const Icon(Icons.print, size: 18), label: const Text('Imprimir'),
                onPressed: () async => _impresora.imprimirPdf(pdfBytes,
                    nombreArchivo: 'documento_${_ultimoPedidoId ?? "venta"}.pdf')),
          ],
          TextButton.icon(
            icon: const Icon(Icons.share, size: 18), label: const Text('Compartir'),
            onPressed: () {
              if (pdfBytes != null) {
                Printing.sharePdf(bytes: pdfBytes,
                    filename: 'ticket_${_ultimoPedidoId ?? "venta"}.pdf');
              } else {
                Share.share(ticket, subject: 'Ticket de compra');
              }
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Nueva venta'),
            onPressed: () { Navigator.pop(context); _limpiarTicket(); },
          ),
        ],
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: _buildAppBar(),
        body: LayoutBuilder(builder: (context, c) {
          final catalogoWidget = CatalogoCajaWidget(
            svc: _svc, empresaId: widget.empresaId,
            busqueda: _busqueda, categoriaFiltro: _categoriaFiltro,
            busCtrl: _busCtrl, lineas: _lineas,
            onBusqueda: (v) => setState(() => _busqueda = v),
            onCategoria: (v) => setState(() => _categoriaFiltro = v),
            onAgregarProducto: _agregarProducto,
          );
          final ticketWidget = _buildTicketPanel();
          if (c.maxWidth >= 600) {
            return Row(children: [
              Expanded(flex: 3,
                child: c.maxWidth > 900
                    ? Column(children: [
                        Expanded(child: catalogoWidget),
                        Padding(padding: const EdgeInsets.all(8),
                          child: EstadisticasTurnoWidget(empresaId: widget.empresaId)),
                      ])
                    : catalogoWidget,
              ),
              const VerticalDivider(width: 1),
              SizedBox(width: 340, child: ticketWidget),
            ]);
          }
          return TabBarView(controller: _tabCtrl,
              children: [catalogoWidget, ticketWidget]);
        }),
      ),
    );
  }

  Widget _buildTicketPanel() => TicketPanelWidget(
    lineas: _lineas,
    metodoPago: _metodoPago,
    total: _total,
    totalBruto: _totalBruto,
    cambio: _cambio,
    descuentoCupon: _descuentoCupon,
    cobrando: _cobrando,
    empresaId: widget.empresaId,
    entregaCtrl: _entregaCtrl,
    efectivoMixtoCtrl: _efectivoMixtoCtrl,
    tarjetaMixtoCtrl: _tarjetaMixtoCtrl,
    onCobrar: _cobrar,
    onMetodoPago: (m) => setState(() {
      _metodoPago = m;
      _entregaCtrl.clear(); _efectivoMixtoCtrl.clear(); _tarjetaMixtoCtrl.clear();
    }),
    onCantidad: (i, bajar) => setState(() {
      final l = _lineas[i];
      if (bajar) { if (l.cantidad > 1) l.cantidad--; else _lineas.removeAt(i); }
      else { l.cantidad++; }
    }),
    onEliminar: (i) => setState(() => _lineas.removeAt(i)),
    onDescuentoLinea: (i, importe) => setState(() => _lineas[i].descuentoImporte = importe),
    onCuponAplicado: (desc) => setState(() => _descuentoCupon = desc),
    onCuponRetirado: () => setState(() => _descuentoCupon = 0),
    fmt: _fmt,
  );

  PreferredSizeWidget _buildAppBar() => AppBar(
    title: const Row(children: [
      Icon(Icons.point_of_sale, size: 22), SizedBox(width: 8),
      Text('Caja Rápida', style: TextStyle(fontWeight: FontWeight.w700)),
    ]),
    backgroundColor: const Color(0xFF1565C0),
    foregroundColor: Colors.white,
    elevation: 0,
    actions: [
      IconButton(
        icon: const Icon(Icons.receipt_long),
        tooltip: 'Historial del día',
        onPressed: () => HistorialTicketsWidget.mostrar(context, widget.empresaId),
      ),
      ListenableBuilder(
        listenable: _holdNotifier,
        builder: (_, __) {
          final count = _holdNotifier.pedidos.length;
          return Stack(clipBehavior: Clip.none, children: [
            IconButton(
              icon: const Icon(Icons.history_toggle_off),
              tooltip: 'Pedidos en espera',
              onPressed: _recuperarPedido,
            ),
            if (count > 0) Positioned(top: 6, right: 6,
              child: IgnorePointer(child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                child: Text('$count', style: const TextStyle(
                    color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
              ))),
          ]);
        },
      ),
      if (_lineas.isNotEmpty) ...[
        IconButton(
          icon: const Icon(Icons.pause_circle_outline),
          tooltip: 'Guardar en espera',
          onPressed: _guardarEnEspera,
        ),
        TextButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Limpiar ticket'),
              content: const Text('¿Descartar todas las líneas del ticket?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                TextButton(onPressed: () { Navigator.pop(context); _limpiarTicket(); },
                    child: const Text('Limpiar')),
              ],
            ),
          ),
          icon: const Icon(Icons.delete_sweep, color: Colors.white70),
          label: const Text('Limpiar', style: TextStyle(color: Colors.white70)),
        ),
      ],
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(40),
      child: LayoutBuilder(builder: (_, c) {
        if (c.maxWidth >= 600) return const SizedBox.shrink();
        return TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'Catálogo'),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Ticket'),
              if (_lineas.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_lineas.length}',
                      style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ])),
          ],
        );
      }),
    ),
  );
}
