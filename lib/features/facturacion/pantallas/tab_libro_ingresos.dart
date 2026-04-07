import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contabilidad_service.dart';
import '../../../domain/modelos/factura.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB LIBRO DE INGRESOS
// ═════════════════════════════════════════════════════════════════════════════

class TabLibroIngresos extends StatefulWidget {
  final String empresaId;
  final int anio;
  final ContabilidadService svc;

  const TabLibroIngresos({
    super.key,
    required this.empresaId,
    required this.anio,
    required this.svc,
  });

  @override
  State<TabLibroIngresos> createState() => _TabLibroIngresosState();
}

class _TabLibroIngresosState extends State<TabLibroIngresos> {
  // Filtro de estado
  EstadoFactura? _filtroEstado; // null = todos

  static const List<String> _nombresMes = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    return StreamBuilder<List<Factura>>(
      stream: widget.svc.obtenerFacturasStream(widget.empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final todas = (snap.data ?? [])
            .where((f) => f.fechaEmision.year == widget.anio)
            .where((f) => f.tipo != TipoFactura.proforma) // excluir proformas
            .toList();

        final filtradas = _filtroEstado == null
            ? todas
            : todas.where((f) => f.estado == _filtroEstado).toList();

        return Column(
          children: [
            // KPIs + filtros
            _buildHeader(todas, color),
            // Lista
            Expanded(
              child: filtradas.isEmpty
                  ? _buildVacio(color)
                  : _buildLista(filtradas, color),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(List<Factura> facturas, Color color) {
    final pagadas = facturas.where((f) => f.esPagada).toList();
    final pendientes = facturas.where((f) => f.esPendiente).toList();
    final totalCobrado = pagadas.fold(0.0, (s, f) => s + f.total);
    final totalPendiente = pendientes.fold(0.0, (s, f) => s + f.total);
    final ivaRepercutido = pagadas.fold(0.0, (s, f) => s + f.totalIva);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // KPIs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              _miniKpi('Cobrado', '${totalCobrado.toStringAsFixed(0)}€',
                  Colors.green, Icons.check_circle_outline),
              _divV(),
              _miniKpi('Pendiente', '${totalPendiente.toStringAsFixed(0)}€',
                  Colors.orange, Icons.pending_outlined),
              _divV(),
              _miniKpi('IVA rep.', '${ivaRepercutido.toStringAsFixed(0)}€',
                  color, Icons.percent),
              _divV(),
              _miniKpi('Facturas', '${facturas.length}',
                  Colors.grey[600]!, Icons.receipt_long_outlined),
            ]),
          ),
          // Filtros
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              scrollDirection: Axis.horizontal,
              children: [
                _chip('Todas', null, color),
                _chip('Pagadas', EstadoFactura.pagada, color),
                _chip('Pendientes', EstadoFactura.pendiente, color),
                _chip('Vencidas', EstadoFactura.vencida, color),
                _chip('Anuladas', EstadoFactura.anulada, color),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _chip(String label, EstadoFactura? estado, Color color) {
    final sel = _filtroEstado == estado;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = estado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : Colors.grey.withValues(alpha: 0.1),
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

  Widget _buildLista(List<Factura> facturas, Color color) {
    // Agrupar por mes desc
    final grupos = <String, List<Factura>>{};
    for (final f in facturas) {
      final key =
          '${f.fechaEmision.year}-${f.fechaEmision.month.toString().padLeft(2, '0')}';
      grupos.putIfAbsent(key, () => []).add(f);
    }
    final claves = grupos.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: claves.map((k) {
        final parts = k.split('-');
        final mes = int.parse(parts[1]);
        final grupo = grupos[k]!;
        final totalMes = grupo.fold(0.0, (s, f) => s + f.total);
        final cobradoMes =
            grupo.where((f) => f.esPagada).fold(0.0, (s, f) => s + f.total);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Text(
                  '${_nombresMes[mes]} ${parts[0]}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${totalMes.toStringAsFixed(2)}€ total',
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${cobradoMes.toStringAsFixed(2)}€ cobrado',
                    style: const TextStyle(
                        fontSize: 10, color: Colors.green),
                  ),
                ]),
              ]),
            ),
            ...grupo.map((f) => _TarjetaFacturaIngreso(
                  factura: f,
                  color: color,
                )),
            const SizedBox(height: 4),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildVacio(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _filtroEstado == null
                ? 'Sin facturas en ${widget.anio}'
                : 'Sin facturas con ese filtro',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Las facturas emitidas aparecerán aquí',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _miniKpi(String label, String valor, Color color, IconData icono) =>
      Expanded(
        child: Column(children: [
          Icon(icono, color: color, size: 16),
          const SizedBox(height: 2),
          Text(valor,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      );

  Widget _divV() =>
      Container(width: 1, height: 36, color: Colors.grey[200]);
}

// ── Tarjeta de factura en el libro de ingresos ────────────────────────────────

class _TarjetaFacturaIngreso extends StatelessWidget {
  final Factura factura;
  final Color color;

  const _TarjetaFacturaIngreso({required this.factura, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorEstado = _colorEstado(factura.estado);
    final d = factura.fechaEmision;
    final fechaStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          // Icono estado
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconoEstado(factura.estado),
                color: colorEstado, size: 18),
          ),
          const SizedBox(width: 10),
          // Info principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    factura.numeroFactura,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      factura.clienteNombre,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Text(fechaStr,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 10)),
                  const SizedBox(width: 8),
                  if (factura.datosFiscales?.nif != null)
                    Text(
                      factura.datosFiscales!.nif!,
                      style: TextStyle(color: Colors.grey[400], fontSize: 10),
                    ),
                ]),
                // Desglose
                const SizedBox(height: 4),
                Row(children: [
                  _chip2('Base: ${factura.subtotal.toStringAsFixed(2)}€',
                      Colors.grey[600]!),
                  const SizedBox(width: 6),
                  _chip2('IVA: ${factura.totalIva.toStringAsFixed(2)}€',
                      Colors.orange[700]!),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Total y estado
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${factura.total.toStringAsFixed(2)}€',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _etiquetaEstado(factura.estado),
                  style: TextStyle(
                      fontSize: 10,
                      color: colorEstado,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _chip2(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 9, color: color)),
      );

  Color _colorEstado(EstadoFactura e) {
    switch (e) {
      case EstadoFactura.pagada:
        return Colors.green;
      case EstadoFactura.pendiente:
        return Colors.orange;
      case EstadoFactura.vencida:
        return Colors.red;
      case EstadoFactura.anulada:
        return Colors.grey;
      case EstadoFactura.rectificada:
        return Colors.orange;
    }
  }

  IconData _iconoEstado(EstadoFactura e) {
    switch (e) {
      case EstadoFactura.pagada:
        return Icons.check_circle;
      case EstadoFactura.pendiente:
        return Icons.access_time;
      case EstadoFactura.vencida:
        return Icons.warning;
      case EstadoFactura.anulada:
        return Icons.cancel;
      case EstadoFactura.rectificada:
        return Icons.swap_horiz;
    }
  }

  String _etiquetaEstado(EstadoFactura e) {
    switch (e) {
      case EstadoFactura.pagada:
        return 'Cobrada';
      case EstadoFactura.pendiente:
        return 'Pendiente';
      case EstadoFactura.vencida:
        return 'Vencida';
      case EstadoFactura.anulada:
        return 'Anulada';
      case EstadoFactura.rectificada:
        return 'Rectificada';
    }
  }
}

