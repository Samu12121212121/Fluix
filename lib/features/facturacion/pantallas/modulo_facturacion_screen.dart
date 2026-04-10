import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/services/pdf_service.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/detalle_factura_screen.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/formulario_factura_screen.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/resumen_fiscal_screen.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/pantalla_contabilidad.dart';

class ModuloFacturacionScreen extends StatefulWidget {
  final String empresaId;

  const ModuloFacturacionScreen({super.key, required this.empresaId});

  @override
  State<ModuloFacturacionScreen> createState() =>
      _ModuloFacturacionScreenState();
}

class _ModuloFacturacionScreenState extends State<ModuloFacturacionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FacturacionService _service = FacturacionService();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    // Detect and mark overdue invoices
    _service.detectarYMarcarVencidas(widget.empresaId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListaFacturas(null),
                _buildListaFacturas(EstadoFactura.pendiente),
                _buildListaFacturas(EstadoFactura.pagada),
                _buildListaFacturas(EstadoFactura.vencida),
                _buildEstadisticas(),
                PantallaContabilidad(empresaId: widget.empresaId),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'resumen_fiscal',
            onPressed: _abrirResumenFiscal,
            backgroundColor: const Color(0xFF1565C0),
            tooltip: 'Resumen Fiscal',
            child: const Icon(Icons.summarize, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'nueva_factura',
            onPressed: _nuevaFactura,
            backgroundColor: const Color(0xFF0D47A1),
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            label: const Text('Nueva Factura',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF0D47A1),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF0D47A1),
        indicatorWeight: 3,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: const [
          Tab(text: 'Todas'),
          Tab(text: 'Pendientes'),
          Tab(text: 'Pagadas'),
          Tab(text: '⚠️ Vencidas'),
          Tab(text: 'Estadísticas'),
          Tab(icon: Icon(Icons.calculate, size: 16), text: 'Contabilidad'),
        ],
      ),
    );
  }

  Widget _buildListaFacturas(EstadoFactura? filtro) {
    final stream = filtro == null
        ? _service.obtenerFacturas(widget.empresaId)
        : filtro == EstadoFactura.vencida
            ? _service.obtenerFacturasVencidas(widget.empresaId)
            : _service.obtenerFacturasPorEstado(widget.empresaId, filtro);

    return Column(
      children: [
        _buildBarraBusqueda(),
        Expanded(
          child: StreamBuilder<List<Factura>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var facturas = snap.data ?? [];

              // Filtrar por búsqueda
              if (_busqueda.isNotEmpty) {
                facturas = facturas
                    .where((f) =>
                        f.clienteNombre
                            .toLowerCase()
                            .contains(_busqueda.toLowerCase()) ||
                        f.numeroFactura
                            .toLowerCase()
                            .contains(_busqueda.toLowerCase()))
                    .toList();
              }

              if (facturas.isEmpty) {
                return _buildListaVacia(filtro);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: facturas.length,
                itemBuilder: (ctx, i) => _buildTarjetaFactura(facturas[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBarraBusqueda() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: InputDecoration(
          hintText: 'Buscar por cliente o número...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaFactura(Factura factura) {
    final color = _colorEstado(factura.estado);
    final icono = _iconoEstado(factura.estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _verDetalle(factura),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icono, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          factura.numeroFactura,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          factura.clienteNombre.isEmpty
                              ? 'Cliente general'
                              : factura.clienteNombre,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${factura.total.toStringAsFixed(2)}€',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          factura.estado.etiqueta,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatFecha(factura.fechaEmision),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  if (factura.lineas.isNotEmpty) ...[
                    Icon(Icons.inventory_2,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${factura.lineas.length} línea${factura.lineas.length != 1 ? 's' : ''}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    'IVA: ${factura.totalIva.toStringAsFixed(2)}€',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              // Acciones rápidas
              if (factura.esPendiente) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _marcarComoPagada(factura),
                        icon:
                            const Icon(Icons.check_circle, size: 16),
                        label: const Text('Marcar Pagada',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _anularFactura(factura),
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Anular',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Botón PDF siempre visible
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => PdfService.verFacturaPdf(context, factura, widget.empresaId),
                  icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF0D47A1)),
                  label: const Text('Ver PDF', style: TextStyle(fontSize: 12, color: Color(0xFF0D47A1))),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaVacia(EstadoFactura? filtro) {
    String mensaje = 'No hay facturas';
    if (filtro == EstadoFactura.pendiente) mensaje = 'No hay facturas pendientes';
    if (filtro == EstadoFactura.pagada) mensaje = 'No hay facturas pagadas';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(mensaje,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Crea una nueva factura pulsando el botón +',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _nuevaFactura,
            icon: const Icon(Icons.add),
            label: const Text('Nueva Factura'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _service.calcularEstadisticas(widget.empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snap.data ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSeccionEstadisticas('📅 Hoy', [
              _buildFilaStat('Facturado hoy',
                  '${(stats['total_hoy'] ?? 0.0).toStringAsFixed(2)}€'),
              _buildFilaStat('Facturas emitidas',
                  '${stats['num_facturas_hoy'] ?? 0}'),
            ]),
            const SizedBox(height: 16),
            _buildSeccionEstadisticas('📆 Este Mes', [
              _buildFilaStat('Total facturado',
                  '${(stats['total_mes'] ?? 0.0).toStringAsFixed(2)}€'),
              _buildFilaStat('Base imponible',
                  '${((stats['total_mes'] ?? 0.0) - (stats['iva_mes'] ?? 0.0)).toStringAsFixed(2)}€'),
              _buildFilaStat('IVA recaudado',
                  '${(stats['iva_mes'] ?? 0.0).toStringAsFixed(2)}€'),
              _buildFilaStat(
                  'Facturas emitidas', '${stats['num_facturas_mes'] ?? 0}'),
              _buildFilaStat(
                  'Facturas pagadas', '${stats['num_pagadas_mes'] ?? 0}'),
              _buildFilaStat(
                  'Facturas pendientes', '${stats['num_pendientes'] ?? 0}'),
            ]),
            const SizedBox(height: 16),
            _buildSeccionEstadisticas('📊 Este Año', [
              _buildFilaStat('Total facturado',
                  '${(stats['total_anio'] ?? 0.0).toStringAsFixed(2)}€'),
              _buildFilaStat('IVA total',
                  '${(stats['iva_anio'] ?? 0.0).toStringAsFixed(2)}€'),
              _buildFilaStat('Facturas emitidas',
                  '${stats['num_facturas_anio'] ?? 0}'),
            ]),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📋 Declaración Trimestral',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(
                      'IVA repercutido este mes: ${(stats['iva_mes'] ?? 0.0).toStringAsFixed(2)}€',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _abrirResumenFiscal,
                        icon: const Icon(Icons.download),
                        label: const Text('Ver Resumen Fiscal Completo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeccionEstadisticas(String titulo, List<Widget> filas) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...filas,
          ],
        ),
      ),
    );
  }

  Widget _buildFilaStat(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text(valor,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // ── ACCIONES ───────────────────────────────────────────────────────────────

  void _nuevaFactura() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FormularioFacturaScreen(empresaId: widget.empresaId),
      ),
    );
  }

  void _verDetalle(Factura factura) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleFacturaScreen(
          factura: factura,
          empresaId: widget.empresaId,
        ),
      ),
    );
  }

  void _marcarComoPagada(Factura factura) async {
    final metodo = await _elegirMetodoPago();
    if (metodo == null) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _service.actualizarEstado(
        empresaId: widget.empresaId,
        facturaId: factura.id,
        nuevoEstado: EstadoFactura.pagada,
        metodoPago: metodo,
        usuarioId: uid,
        usuarioNombre: 'Administrador',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Factura marcada como pagada'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<MetodoPagoFactura?> _elegirMetodoPago() {
    return showDialog<MetodoPagoFactura>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Método de pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MetodoPagoFactura.values
              .map((m) => ListTile(
                    leading: Icon(_iconoMetodoPago(m)),
                    title: Text(m.etiqueta),
                    onTap: () => Navigator.pop(ctx, m),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _anularFactura(Factura factura) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Anular Factura'),
          content: TextField(
            controller: ctrl,
            decoration:
                const InputDecoration(labelText: 'Motivo de anulación'),
            maxLines: 2,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Anular',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (motivo == null || motivo.isEmpty) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _service.anularFactura(
        empresaId: widget.empresaId,
        facturaId: factura.id,
        motivo: motivo,
        usuarioId: uid,
        usuarioNombre: 'Administrador',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🗑️ Factura anulada'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirResumenFiscal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResumenFiscalScreen(empresaId: widget.empresaId),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  Color _colorEstado(EstadoFactura estado) {
    switch (estado) {
      case EstadoFactura.pendiente: return const Color(0xFFFF9800);
      case EstadoFactura.pagada: return const Color(0xFF4CAF50);
      case EstadoFactura.anulada: return Colors.grey;
      case EstadoFactura.vencida: return Colors.red;
      case EstadoFactura.rectificada: return Colors.orange;
    }
  }

  IconData _iconoEstado(EstadoFactura estado) {
    switch (estado) {
      case EstadoFactura.pendiente: return Icons.pending_actions;
      case EstadoFactura.pagada: return Icons.check_circle;
      case EstadoFactura.anulada: return Icons.cancel;
      case EstadoFactura.vencida: return Icons.warning;
      case EstadoFactura.rectificada: return Icons.swap_horiz;
    }
  }

  IconData _iconoMetodoPago(MetodoPagoFactura m) {
    switch (m) {
      case MetodoPagoFactura.tarjeta: return Icons.credit_card;
      case MetodoPagoFactura.paypal: return Icons.paypal;
      case MetodoPagoFactura.bizum: return Icons.phone_android;
      case MetodoPagoFactura.efectivo: return Icons.money;
      case MetodoPagoFactura.transferencia: return Icons.account_balance;
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }
}


