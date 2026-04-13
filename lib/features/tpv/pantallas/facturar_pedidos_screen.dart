import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../services/tpv_facturacion_service.dart';

class FacturarPedidosScreen extends StatefulWidget {
  final String empresaId;
  const FacturarPedidosScreen({super.key, required this.empresaId});

  @override
  State<FacturarPedidosScreen> createState() => _FacturarPedidosScreenState();
}

class _FacturarPedidosScreenState extends State<FacturarPedidosScreen> {
  final TpvFacturacionService _svc = TpvFacturacionService();
  final Set<String> _seleccionados = {};
  bool _facturando = false;

  // Rango de fechas seleccionado
  DateTimeRange _rango = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  List<Pedido> _pedidos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final lista = await _svc.obtenerPedientesfacturar(widget.empresaId, _rango);
      setState(() { _pedidos = lista; _cargando = false; });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _rango,
    );
    if (picked != null) {
      setState(() { _rango = picked; _seleccionados.clear(); });
      _cargar();
    }
  }

  Future<void> _facturarSeleccion() async {
    if (_seleccionados.isEmpty) return;
    final pedidos = _pedidos.where((p) => _seleccionados.contains(p.id)).toList();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generar factura'),
        content: Text('¿Generar una factura con los ${pedidos.length} pedidos seleccionados?\n'
            'Total: ${_fmt(pedidos.fold<double>(0, (s, p) => s + p.total))}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _facturando = true);
    try {
      final config = await _svc.obtenerConfig(widget.empresaId);
      final factura = await _svc.facturarSeleccion(
        empresaId: widget.empresaId,
        pedidos: pedidos,
        config: config,
        usuarioNombre: 'TPV Manual',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Factura ${factura.numeroFactura} generada'),
          backgroundColor: Colors.green,
        ));
        _seleccionados.clear();
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _facturando = false);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalSeleccionado = _pedidos
        .where((p) => _seleccionados.contains(p.id))
        .fold<double>(0, (s, p) => s + p.total);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturar Pedidos TPV', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filtro de fechas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _seleccionarRango,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                        '${fmt.format(_rango.start)} – ${fmt.format(_rango.end)}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _pedidos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 64, color: Colors.green[200]),
                            const SizedBox(height: 12),
                            const Text('No hay pedidos pendientes de facturar',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _pedidos.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (_, i) {
                          final p = _pedidos[i];
                          final sel = _seleccionados.contains(p.id);
                          return CheckboxListTile(
                            value: sel,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _seleccionados.add(p.id);
                              } else {
                                _seleccionados.remove(p.id);
                              }
                            }),
                            title: Text(
                              '${fmt.format(p.fechaCreacion)}  ${_fmt(p.total)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${p.lineas.length} línea${p.lineas.length != 1 ? 's' : ''}  ·  ${_icono(p.metodoPago)} ${_nombreMetodo(p.metodoPago)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            secondary: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.origen == OrigenPedido.tpvExterno
                                    ? Colors.orange[100]
                                    : Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                p.origen == OrigenPedido.tpvExterno ? 'Ext.' : 'TPV',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: p.origen == OrigenPedido.tpvExterno
                                      ? Colors.orange[800]
                                      : Colors.blue[800],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Barra de acciones
          const Divider(height: 1),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _pedidos.isEmpty
                          ? null
                          : _seleccionados.length == _pedidos.length
                              ? _seleccionados.clear()
                              : _seleccionados.addAll(_pedidos.map((p) => p.id))),
                      child: Text(_seleccionados.length == _pedidos.length
                          ? 'Deseleccionar todo'
                          : 'Seleccionar todo'),
                    ),
                    const Spacer(),
                    if (_seleccionados.isNotEmpty)
                      Text(
                        '${_seleccionados.length} selec.  |  ${_fmt(totalSeleccionado)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: (_seleccionados.isEmpty || _facturando) ? null : _facturarSeleccion,
                    icon: _facturando
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.receipt_long),
                    label: Text(_facturando
                        ? 'Generando factura…'
                        : '📄 GENERAR FACTURA CON SELECCIÓN'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2).format(v);

  String _icono(MetodoPago m) => switch (m) {
    MetodoPago.efectivo => '💵',
    MetodoPago.tarjeta  => '💳',
    MetodoPago.mixto    => '🔀',
    MetodoPago.bizum    => '📱',
    MetodoPago.paypal   => '🅿️',
  };

  String _nombreMetodo(MetodoPago m) => switch (m) {
    MetodoPago.efectivo => 'Efectivo',
    MetodoPago.tarjeta  => 'Tarjeta',
    MetodoPago.mixto    => 'Mixto',
    MetodoPago.bizum    => 'Bizum',
    MetodoPago.paypal   => 'PayPal',
  };
}


