import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/services/pdf_service.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/detalle_factura_screen.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/formulario_factura_screen.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/resumen_fiscal_screen.dart';
import 'package:planeag_flutter/features/facturacion/pantallas/pantalla_contabilidad.dart';
import 'package:planeag_flutter/features/fiscal/pantallas/review_transaction_screen.dart';
import 'package:planeag_flutter/features/fiscal/pantallas/export_models_screen.dart';
import 'upload_invoice_screen.dart';

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
    _tabController = TabController(length: 7, vsync: this);
    // Detect and mark overdue invoices
    _service.detectarYMarcarVencidas(widget.empresaId);
    // Al pulsar tab 6 (Contabilidad), navegar a pantalla separada
    _tabController.addListener(() {
      if (_tabController.index == 6 && !_tabController.indexIsChanging) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _tabController.animateTo(5);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PantallaContabilidad(empresaId: widget.empresaId),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _migrarNumeros() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renumerar facturas'),
        content: const Text('¿Asignar números correlativos a todas las facturas que no tienen número válido? Esta operación no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final n = await _service.migrarFacturasSinNumero(widget.empresaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $n factura${n != 1 ? 's' : ''} renumerada${n != 1 ? 's' : ''}'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'), backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: kDebugMode ? AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0D47A1),
        title: const Text('Facturas', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.build_outlined, color: Colors.white70, size: 20),
            tooltip: 'Herramientas',
            onSelected: (v) { if (v == 'migrar') _migrarNumeros(); },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'migrar',
                child: ListTile(
                  leading: Icon(Icons.refresh, color: Colors.blue),
                  title: Text('Renumerar facturas sin número'),
                  subtitle: Text('Asigna números a facturas con "FAC-000"'),
                  contentPadding: EdgeInsets.zero, dense: true,
                ),
              ),
            ],
          ),
        ],
      ) : null,
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
                _buildRevisionIA(),
                // Slot dummy – la navegación real ocurre en el listener del TabController
                const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'modelos_aeat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ExportModelsScreen(empresaId: widget.empresaId),
              ),
            ),
            backgroundColor: const Color(0xFF1A237E),
            tooltip: 'Modelos AEAT',
            child: const Icon(Icons.account_balance, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'resumen_fiscal',
            onPressed: _abrirResumenFiscal,
            backgroundColor: const Color(0xFF1565C0),
            tooltip: 'Resumen Fiscal',
            child: const Icon(Icons.summarize, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'subir_documento',
            onPressed: _subirDocumento,
            backgroundColor: const Color(0xFF2E7D32),
            icon: const Icon(Icons.document_scanner, color: Colors.white),
            label: const Text('Subir documento',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
        tabs: [
          const Tab(text: 'Todas'),
          const Tab(text: 'Pendientes'),
          const Tab(text: 'Pagadas'),
          const Tab(text: '⚠️ Vencidas'),
          const Tab(text: 'Estadísticas'),
          Tab(
            child: StreamBuilder<int>(
              stream: watchNeedsReviewCount(widget.empresaId),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: Colors.orange,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('🔍 Revisión IA'),
                  ),
                );
              },
            ),
          ),
          const Tab(icon: Icon(Icons.calculate, size: 16), text: 'Contabilidad'),
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

  void _subirDocumento() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadInvoiceScreen(empresaId: widget.empresaId),
      ),
    );
  }

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

  // ── TAB REVISIÓN IA ────────────────────────────────────────────────────────

  Widget _buildRevisionIA() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('fiscal_transactions')
          .where('status', isEqualTo: 'needs_review')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.green),
                const SizedBox(height: 16),
                const Text('¡Todo revisado!',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('No hay facturas pendientes de revisión IA',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final txId = docs[i].id;
            final proveedor =
                data['supplier_name'] ?? data['counterparty']?['name'] ?? '—';
            final numero = data['invoice_number'] ?? '—';
            final totalCents = (data['total_amount_cents'] as num?)?.toInt() ?? 0;
            final total = (totalCents / 100).toStringAsFixed(2);
            final errors =
                List<String>.from(data['validation_errors'] ?? []);
            final warnings =
                List<String>.from(data['validation_warnings'] ?? []);
            final confidence =
                (data['confidence_score'] as num?)?.toDouble() ?? 0;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: errors.isNotEmpty
                      ? Colors.red.shade100
                      : Colors.orange.shade100,
                  child: Icon(
                    errors.isNotEmpty
                        ? Icons.error_outline
                        : Icons.warning_amber,
                    color:
                        errors.isNotEmpty ? Colors.red : Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(proveedor,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nº $numero · $total €'),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.psychology,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Confianza: ${(confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600]),
                        ),
                        if (errors.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('· ${errors.length} error(es)',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.red)),
                        ] else if (warnings.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('· ${warnings.length} aviso(s)',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.orange)),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewTransactionScreen(
                        empresaId: widget.empresaId,
                        transactionId: txId,
                      ),
                    ),
                  );
                  // El stream se actualiza automáticamente tras confirmar/rechazar
                },
              ),
            );
          },
        );
      },
    );
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


