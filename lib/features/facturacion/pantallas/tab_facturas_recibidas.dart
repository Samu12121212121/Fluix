import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:planeag_flutter/domain/modelos/factura_recibida.dart';
import 'package:planeag_flutter/services/contabilidad_service.dart';
import 'package:planeag_flutter/features/fiscal/pantallas/invoice_result_screen.dart';
import 'formulario_factura_recibida_screen.dart';
import 'upload_invoice_screen.dart';

class TabFacturasRecibidas extends StatefulWidget {
  final String empresaId;
  final ContabilidadService svc;

  const TabFacturasRecibidas({
    super.key,
    required this.empresaId,
    required this.svc,
  });

  @override
  State<TabFacturasRecibidas> createState() => _TabFacturasRecibidasState();
}

class _TabFacturasRecibidasState extends State<TabFacturasRecibidas> {
  EstadoFacturaRecibida? _filtroEstado;
  String _busqueda = '';
  bool _exportando = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildBarraFiltros(),
          Expanded(
            child: StreamBuilder<List<FacturaRecibida>>(
              stream: _obtenerStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var facturas = snap.data ?? [];

                if (_busqueda.isNotEmpty) {
                  facturas = facturas
                      .where((f) =>
                          f.nombreProveedor
                              .toLowerCase()
                              .contains(_busqueda.toLowerCase()) ||
                          f.numeroFactura
                              .toLowerCase()
                              .contains(_busqueda.toLowerCase()) ||
                          f.nifProveedor.contains(_busqueda))
                      .toList();
                }

                if (facturas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No hay facturas recibidas',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _abrirFormulario,
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar factura recibida'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: facturas.length,
                  itemBuilder: (ctx, i) =>
                      _buildTarjetaFactura(facturas[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _subirFactura,
        icon: const Icon(Icons.document_scanner),
        label: const Text('Subir factura'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
    );
  }

  void _subirFactura() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadInvoiceScreen(empresaId: widget.empresaId),
      ),
    );
  }

  void _abrirFormulario([FacturaRecibida? existente]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioFacturaRecibidaScreen(
          empresaId: widget.empresaId,
          facturaExistente: existente,
        ),
      ),
    );
  }

  Widget _buildBarraFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Búsqueda
          TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: InputDecoration(
              hintText: 'Buscar por proveedor, factura o NIF...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filtro por estado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Botón "Todos"
                _buildFiltroChip(
                  label: 'Todas',
                  isSelected: _filtroEstado == null,
                  onTap: () => setState(() => _filtroEstado = null),
                ),
                const SizedBox(width: 8),
                // Filtros por estado
                ...EstadoFacturaRecibida.values.map((estado) =>
                    _buildFiltroChip(
                      label: estado.etiqueta,
                      isSelected: _filtroEstado == estado,
                      onTap: () => setState(() => _filtroEstado = estado),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Botón exportar CSV
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportando ? null : _mostrarDialogoExportacion,
              icon: _exportando
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 16),
              label: Text(
                _exportando ? 'Generando...' : 'Exportar CSV',
                style: const TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
                side: const BorderSide(color: Color(0xFF0D47A1)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Exportación CSV ────────────────────────────────────────────────────────

  void _mostrarDialogoExportacion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DialogoFiltrosExport(
        onExportar: (desde, hasta, estado, proveedor) async {
          Navigator.pop(ctx);
          await _ejecutarExportacion(
            desde: desde,
            hasta: hasta,
            estado: estado,
            proveedorFiltro: proveedor,
          );
        },
      ),
    );
  }

  Future<void> _ejecutarExportacion({
    DateTime? desde,
    DateTime? hasta,
    EstadoFacturaRecibida? estado,
    String? proveedorFiltro,
  }) async {
    setState(() => _exportando = true);
    try {
      final csv = await widget.svc.exportarCSVRecibidasFiltrado(
        widget.empresaId,
        desde: desde,
        hasta: hasta,
        estado: estado,
        proveedorFiltro: proveedorFiltro,
      );

      // Construir nombre de archivo descriptivo
      final partes = <String>['facturas_recibidas'];
      if (desde != null) {
        partes.add(
            '${desde.day.toString().padLeft(2, '0')}${desde.month.toString().padLeft(2, '0')}${desde.year}');
      }
      if (hasta != null) {
        partes.add(
            '${hasta.day.toString().padLeft(2, '0')}${hasta.month.toString().padLeft(2, '0')}${hasta.year}');
      }
      if (estado != null) partes.add(estado.name);
      final nombre = '${partes.join('_')}.csv';

      if (mounted) {
        setState(() => _exportando = false);
        _mostrarResultadoCsv(csv, nombre);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exportando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarResultadoCsv(String csv, String nombre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              // Título
              Row(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: csv));
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('✅ CSV copiado al portapapeles')));
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar'),
                ),
              ]),
              const Divider(),
              // Vista previa
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(csv,
                        style: const TextStyle(
                            color: Color(0xFF9CDCFE),
                            fontSize: 10,
                            fontFamily: 'monospace')),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Botón copiar y cerrar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: csv));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '📋 CSV copiado — pégalo en Google Sheets o Excel'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copiar y cerrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Botón compartir
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final dir = await getTemporaryDirectory();
                      final file = File('${dir.path}/$nombre');
                      await file.writeAsString(csv, flush: true);
                      await Share.shareXFiles(
                        [XFile(file.path, mimeType: 'text/csv')],
                        subject: nombre,
                      );
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content: Text('Error al compartir: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir como archivo .csv'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xFF0D47A1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filtros existentes ─────────────────────────────────────────────────────

  Widget _buildFiltroChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF0D47A1),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTarjetaFactura(FacturaRecibida factura) {
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
              // Encabezado: número y estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          factura.numeroFactura,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          factura.nombreProveedor,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icono, color: color, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          factura.estado.etiqueta,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Detalles: NIF, fecha, importe
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NIF: ${factura.nifProveedor}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recibida: ${_fmtDate(factura.fechaRecepcion)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${factura.baseImponible.toStringAsFixed(2)}€',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'IVA: ${factura.importeIva.toStringAsFixed(2)}€',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Etiqueta IVA deducible/no deducible
              if (!factura.ivaDeducible) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '⚠️ IVA No deducible',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              // Badge IA
              if (factura.aiTransactionId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.indigo.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.psychology,
                              size: 11, color: Colors.indigo),
                          SizedBox(width: 4),
                          Text('Procesada por IA',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _verDetalle(FacturaRecibida factura) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(factura.numeroFactura),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilaDetalle('Proveedor', factura.nombreProveedor),
              _buildFilaDetalle('NIF', factura.nifProveedor),
              _buildFilaDetalle(
                'Fecha emisión',
                _fmtDate(factura.fechaEmision),
              ),
              _buildFilaDetalle(
                'Fecha recepción',
                _fmtDate(factura.fechaRecepcion),
              ),
              _buildFilaDetalle(
                'Base imponible',
                '${factura.baseImponible.toStringAsFixed(2)}€',
              ),
              _buildFilaDetalle(
                'IVA (${factura.porcentajeIva.toInt()}%)',
                '${factura.importeIva.toStringAsFixed(2)}€',
              ),
              _buildFilaDetalle(
                'Total',
                '${factura.totalConImpuestos.toStringAsFixed(2)}€',
              ),
              _buildFilaDetalle(
                'Estado',
                factura.estado.etiqueta,
              ),
              if (!factura.ivaDeducible)
                _buildFilaDetalle(
                  'IVA',
                  '❌ No deducible',
                ),
              if (factura.notas != null)
                _buildFilaDetalle('Notas', factura.notas!),
            ],
          ),
        ),
        actions: [
          // Botón "Ver análisis IA" — solo si fue procesada por IA
          if (factura.aiTransactionId != null)
            TextButton.icon(
              icon: const Icon(Icons.psychology, size: 16, color: Colors.indigo),
              label: const Text('Ver IA',
                  style: TextStyle(color: Colors.indigo)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceResultScreen(
                      empresaId: widget.empresaId,
                      transactionId: factura.aiTransactionId!,
                    ),
                  ),
                );
              },
            ),
          TextButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Editar'),
              onPressed: () {
                Navigator.pop(ctx);
                _abrirFormulario(factura);
              },
            ),
            if (factura.estaPendiente)
            TextButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Marcar como recibida'),
              onPressed: () async {
                await widget.svc.actualizarEstadoFacturaRecibida(
                  empresaId: widget.empresaId,
                  facturaRecibidaId: factura.id,
                  nuevoEstado: EstadoFacturaRecibida.recibida,
                );
                Navigator.pop(ctx);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilaDetalle(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<FacturaRecibida>> _obtenerStream() {
    if (_filtroEstado != null) {
      return widget.svc.obtenerFacturasRecibidasPorEstado(
        widget.empresaId,
        _filtroEstado!,
      );
    }
    return widget.svc.obtenerFacturasRecibidas(widget.empresaId);
  }

  Color _colorEstado(EstadoFacturaRecibida estado) {
    switch (estado) {
      case EstadoFacturaRecibida.pendiente:
        return Colors.orange;
      case EstadoFacturaRecibida.recibida:
        return Colors.blue;
      case EstadoFacturaRecibida.pagada:
        return Colors.green;
      case EstadoFacturaRecibida.rechazada:
        return Colors.red;
    }
  }

  IconData _iconoEstado(EstadoFacturaRecibida estado) {
    switch (estado) {
      case EstadoFacturaRecibida.pendiente:
        return Icons.schedule;
      case EstadoFacturaRecibida.recibida:
        return Icons.check_circle_outline;
      case EstadoFacturaRecibida.pagada:
        return Icons.verified;
      case EstadoFacturaRecibida.rechazada:
        return Icons.cancel;
    }
  }

  String _fmtDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DIÁLOGO DE FILTROS PARA EXPORTACIÓN CSV
// ═════════════════════════════════════════════════════════════════════════════

class _DialogoFiltrosExport extends StatefulWidget {
  final Future<void> Function(
    DateTime? desde,
    DateTime? hasta,
    EstadoFacturaRecibida? estado,
    String? proveedor,
  ) onExportar;

  const _DialogoFiltrosExport({required this.onExportar});

  @override
  State<_DialogoFiltrosExport> createState() => _DialogoFiltrosExportState();
}

class _DialogoFiltrosExportState extends State<_DialogoFiltrosExport> {
  DateTime? _desde;
  DateTime? _hasta;
  EstadoFacturaRecibida? _estado; // null = todas
  final _proveedorCtrl = TextEditingController();

  static const _colorPrimario = Color(0xFF0D47A1);

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _seleccionarDesde() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _desde ?? DateTime(DateTime.now().year, 1, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) setState(() => _desde = picked);
  }

  Future<void> _seleccionarHasta() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hasta ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) setState(() => _hasta = picked);
  }

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle + título
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _colorPrimario.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.filter_list,
                    color: _colorPrimario, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Filtros para exportar CSV',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _colorPrimario),
              ),
            ]),
            const SizedBox(height: 20),

            // ── Rango de fechas ──────────────────────────────────────────────
            const Text('Rango de fechas',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _buildSelectorFecha(
                  label: 'Desde',
                  valor: _desde != null ? _fmtDate(_desde!) : 'Cualquier fecha',
                  onTap: _seleccionarDesde,
                  onClear: _desde != null
                      ? () => setState(() => _desde = null)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSelectorFecha(
                  label: 'Hasta',
                  valor: _hasta != null ? _fmtDate(_hasta!) : 'Hoy',
                  onTap: _seleccionarHasta,
                  onClear: _hasta != null
                      ? () => setState(() => _hasta = null)
                      : null,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            // Accesos rápidos de rango
            Wrap(
              spacing: 8,
              children: [
                _quickRange('Este mes', () {
                  final now = DateTime.now();
                  setState(() {
                    _desde = DateTime(now.year, now.month, 1);
                    _hasta = DateTime(now.year, now.month + 1, 0);
                  });
                }),
                _quickRange('Este año', () {
                  final y = DateTime.now().year;
                  setState(() {
                    _desde = DateTime(y, 1, 1);
                    _hasta = DateTime(y, 12, 31);
                  });
                }),
                _quickRange('Último trimestre', () {
                  final now = DateTime.now();
                  final mes = now.month;
                  final trimestre = ((mes - 1) ~/ 3) + 1;
                  setState(() {
                    _desde = DateTime(now.year, (trimestre - 1) * 3 + 1, 1);
                    _hasta = DateTime(now.year, trimestre * 3 + 1, 0);
                  });
                }),
              ],
            ),
            const SizedBox(height: 20),

            // ── Estado de pago ───────────────────────────────────────────────
            const Text('Estado de pago',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _estadoChip('Todas', null),
                ...EstadoFacturaRecibida.values
                    .map((e) => _estadoChip(e.etiqueta, e)),
              ],
            ),
            const SizedBox(height: 20),

            // ── Proveedor ────────────────────────────────────────────────────
            const Text('Proveedor (opcional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _proveedorCtrl,
              decoration: InputDecoration(
                hintText: 'Nombre o NIF del proveedor...',
                prefixIcon: const Icon(Icons.business_outlined, size: 18),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _proveedorCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () =>
                            setState(() => _proveedorCtrl.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // ── Botón exportar ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onExportar(
                  _desde,
                  _hasta,
                  _estado,
                  _proveedorCtrl.text.trim().isEmpty
                      ? null
                      : _proveedorCtrl.text.trim(),
                ),
                icon: const Icon(Icons.download),
                label: const Text('Generar CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorPrimario,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorFecha({
    required String label,
    required String valor,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined,
              size: 14, color: _colorPrimario),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500)),
                Text(valor,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.clear, size: 14, color: Colors.grey),
            ),
        ]),
      ),
    );
  }

  Widget _estadoChip(String label, EstadoFacturaRecibida? estado) {
    final sel = _estado == estado;
    return GestureDetector(
      onTap: () => setState(() => _estado = estado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _colorPrimario : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _quickRange(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: _colorPrimario.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              color: _colorPrimario,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}





