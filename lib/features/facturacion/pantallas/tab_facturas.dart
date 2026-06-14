import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/services/pdf_service.dart';
import 'detalle_factura_screen.dart';
import 'formulario_factura_screen.dart';

const _kPrimario = Color(0xFF0D47A1);

enum _Filtro { todas, pendientes, pagadas, vencidas, tpv }

extension _FiltroLabel on _Filtro {
  String get label {
    switch (this) {
      case _Filtro.todas: return 'Todas';
      case _Filtro.pendientes: return 'Pendientes';
      case _Filtro.pagadas: return 'Pagadas';
      case _Filtro.vencidas: return 'Vencidas';
      case _Filtro.tpv: return 'TPV';
    }
  }
}

class TabFacturas extends StatefulWidget {
  final String empresaId;

  const TabFacturas({super.key, required this.empresaId});

  @override
  State<TabFacturas> createState() => _TabFacturasState();
}

class _TabFacturasState extends State<TabFacturas> {
  final _service = FacturacionService();
  _Filtro _filtro = _Filtro.todas;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _service.detectarYMarcarVencidas(widget.empresaId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildBarra(),
        _buildFiltros(),
        Expanded(
          child: StreamBuilder<List<Factura>>(
            stream: _service.obtenerFacturas(widget.empresaId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var lista = snap.data ?? [];
              lista = _aplicarFiltro(lista);
              if (_busqueda.isNotEmpty) {
                final q = _busqueda.toLowerCase();
                lista = lista.where((f) =>
                    f.clienteNombre.toLowerCase().contains(q) ||
                    f.numeroFactura.toLowerCase().contains(q)).toList();
              }
              if (lista.isEmpty) return _buildVacia();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: lista.length,
                itemBuilder: (_, i) => _buildTarjeta(lista[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Factura> _aplicarFiltro(List<Factura> lista) {
    switch (_filtro) {
      case _Filtro.todas: return lista;
      case _Filtro.pendientes: return lista.where((f) => f.estado == EstadoFactura.pendiente).toList();
      case _Filtro.pagadas: return lista.where((f) => f.estado == EstadoFactura.pagada).toList();
      case _Filtro.vencidas: return lista.where((f) => f.estaVencida || f.estado == EstadoFactura.vencida).toList();
      case _Filtro.tpv: return lista.where((f) => f.pedidoId != null || (f.ticketIds?.isNotEmpty == true)).toList();
    }
  }

  Widget _buildBarra() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: TextField(
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        hintText: 'Buscar por cliente o número…',
        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
        suffixIcon: _busqueda.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _busqueda = ''))
            : null,
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _buildFiltros() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _Filtro.values.map((f) {
          final sel = _filtro == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filtro = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _kPrimario : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _kPrimario : Colors.grey[300]!),
                ),
                child: Text(
                  f.label,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.grey[700],
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );

  Widget _buildTarjeta(Factura f) {
    final color = _colorEstado(f.estado);
    final esTpv = f.pedidoId != null || (f.ticketIds?.isNotEmpty == true);
    final fecha = '${f.fechaEmision.day.toString().padLeft(2, '0')}/${f.fechaEmision.month.toString().padLeft(2, '0')}/${f.fechaEmision.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetalleFacturaScreen(factura: f, empresaId: widget.empresaId),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(_iconoEstado(f.estado), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(f.numeroFactura, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (esTpv) ...[
                    const SizedBox(width: 6),
                    _chip('TPV', Colors.deepOrange),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  f.clienteNombre.isEmpty ? 'Cliente general' : f.clienteNombre,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(fecha, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${f.total.toStringAsFixed(2)}€',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _kPrimario)),
              const SizedBox(height: 4),
              _chip(f.estado.etiqueta, color),
            ]),
            const SizedBox(width: 4),
            // Acción rápida PDF
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.grey),
              onPressed: () => PdfService.verFacturaPdf(context, f, widget.empresaId),
              visualDensity: VisualDensity.compact,
              tooltip: 'Ver PDF',
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildVacia() => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _filtro == _Filtro.todas ? 'Sin facturas todavía' : 'Sin facturas ${_filtro.label.toLowerCase()}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text('Crea tu primera factura con el botón +',
              style: TextStyle(color: Colors.grey[400], fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  Color _colorEstado(EstadoFactura e) {
    switch (e) {
      case EstadoFactura.pendiente: return const Color(0xFFFF9800);
      case EstadoFactura.pagada: return const Color(0xFF4CAF50);
      case EstadoFactura.anulada: return Colors.grey;
      case EstadoFactura.vencida: return Colors.red;
      case EstadoFactura.rectificada: return Colors.orange;
    }
  }

  IconData _iconoEstado(EstadoFactura e) {
    switch (e) {
      case EstadoFactura.pendiente: return Icons.pending_actions;
      case EstadoFactura.pagada: return Icons.check_circle;
      case EstadoFactura.anulada: return Icons.cancel;
      case EstadoFactura.vencida: return Icons.warning;
      case EstadoFactura.rectificada: return Icons.swap_horiz;
    }
  }
}
