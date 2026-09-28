import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/albaran_recibido.dart';
import 'package:planeag_flutter/services/contabilidad_service.dart';
import 'formulario_albaran_recibido_screen.dart';
import 'formulario_factura_recibida_screen.dart';

class TabAlbaranesRecibidos extends StatefulWidget {
  final String empresaId;
  final ContabilidadService svc;

  const TabAlbaranesRecibidos({
    super.key,
    required this.empresaId,
    required this.svc,
  });

  @override
  State<TabAlbaranesRecibidos> createState() => _TabAlbaranesRecibidosState();
}

class _TabAlbaranesRecibidosState extends State<TabAlbaranesRecibidos> {
  EstadoAlbaranRecibido? _filtroEstado;
  String _busqueda = '';

  static const _primary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        _buildFiltros(),
        Expanded(
          child: StreamBuilder<List<AlbaranRecibido>>(
            stream: _stream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var lista = snap.data ?? [];

              if (_busqueda.isNotEmpty) {
                final q = _busqueda.toLowerCase();
                lista = lista
                    .where((a) =>
                        a.nombreProveedor.toLowerCase().contains(q) ||
                        a.numeroAlbaran.toLowerCase().contains(q) ||
                        a.nifProveedor.toLowerCase().contains(q))
                    .toList();
              }

              if (lista.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No hay albaranes recibidos',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _nuevo,
                        icon: const Icon(Icons.add),
                        label: const Text('Registrar albarán'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                itemBuilder: (_, i) => _tarjeta(lista[i]),
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo albarán'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  Widget _buildFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
          onChanged: (v) => setState(() => _busqueda = v),
          decoration: InputDecoration(
            hintText: 'Buscar por proveedor, nº albarán...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('Todos', _filtroEstado == null,
                () => setState(() => _filtroEstado = null)),
            const SizedBox(width: 8),
            ...EstadoAlbaranRecibido.values.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _chip(e.etiqueta, _filtroEstado == e,
                      () => setState(() => _filtroEstado = e)),
                )),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => onTap(),
      selectedColor: _primary,
      labelStyle: TextStyle(
        color: sel ? Colors.white : Colors.grey[700],
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ── Tarjeta ───────────────────────────────────────────────────────────────

  Widget _tarjeta(AlbaranRecibido a) {
    final color = _colorEstado(a.estado);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _verDetalle(a),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.numeroAlbaran,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(a.nombreProveedor,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              )),
              _badgeEstado(a.estado, color),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(_fmtDate(a.fechaRecepcion),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 16),
              Icon(Icons.list_alt, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('${a.totalLineas} ${a.totalLineas == 1 ? 'artículo' : 'artículos'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (a.nifProveedor.isNotEmpty) ...[
                const SizedBox(width: 16),
                Text('NIF: ${a.nifProveedor}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _badgeEstado(EstadoAlbaranRecibido e, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_iconoEstado(e), color: color, size: 14),
        const SizedBox(width: 5),
        Text(e.etiqueta,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Detalle / acciones ────────────────────────────────────────────────────

  void _verDetalle(AlbaranRecibido a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DetalleAlbaranSheet(
        albaran:   a,
        empresaId: widget.empresaId,
        svc:       widget.svc,
        onEditar:  () => _abrir(a),
        onEliminar: () => _eliminar(a),
      ),
    );
  }

  void _nuevo()        => _abrir(null);
  void _abrir([AlbaranRecibido? existente]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioAlbaranRecibidoScreen(
          empresaId: widget.empresaId,
          existente: existente,
        ),
      ),
    );
  }

  Future<void> _eliminar(AlbaranRecibido a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar albarán'),
        content: Text('¿Eliminar el albarán ${a.numeroAlbaran}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.svc.eliminarAlbaranRecibido(widget.empresaId, a.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Albarán eliminado'),
              backgroundColor: Colors.red));
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Stream<List<AlbaranRecibido>> _stream() {
    if (_filtroEstado != null) {
      return widget.svc.obtenerAlbaranesRecibidosPorEstado(
          widget.empresaId, _filtroEstado!);
    }
    return widget.svc.obtenerAlbaranesRecibidos(widget.empresaId);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _colorEstado(EstadoAlbaranRecibido e) {
    switch (e) {
      case EstadoAlbaranRecibido.pendiente:   return Colors.orange;
      case EstadoAlbaranRecibido.conforme:    return Colors.green;
      case EstadoAlbaranRecibido.disconforme: return Colors.red;
      case EstadoAlbaranRecibido.parcial:     return Colors.blue;
    }
  }

  IconData _iconoEstado(EstadoAlbaranRecibido e) {
    switch (e) {
      case EstadoAlbaranRecibido.pendiente:   return Icons.schedule;
      case EstadoAlbaranRecibido.conforme:    return Icons.check_circle_outline;
      case EstadoAlbaranRecibido.disconforme: return Icons.cancel_outlined;
      case EstadoAlbaranRecibido.parcial:     return Icons.remove_circle_outline;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHEET DE DETALLE
// ═════════════════════════════════════════════════════════════════════════════

class _DetalleAlbaranSheet extends StatelessWidget {
  final AlbaranRecibido albaran;
  final String empresaId;
  final ContabilidadService svc;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _DetalleAlbaranSheet({
    required this.albaran,
    required this.empresaId,
    required this.svc,
    required this.onEditar,
    required this.onEliminar,
  });

  static const _primary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(controller: ctrl, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          // Encabezado
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(albaran.numeroAlbaran,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              Text(albaran.nombreProveedor,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ])),
            _badgeEstado(albaran.estado),
          ]),
          const SizedBox(height: 16),

          // Cambio de estado rápido
          _cambioEstadoRapido(context),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Info básica
          _fila('Fecha albarán', _fmtDate(albaran.fechaAlbaran)),
          _fila('Fecha recepción', _fmtDate(albaran.fechaRecepcion)),
          if (albaran.nifProveedor.isNotEmpty)
            _fila('NIF proveedor', albaran.nifProveedor),
          if (albaran.telefonoProveedor.isNotEmpty)
            _fila('Teléfono', albaran.telefonoProveedor),

          // Líneas
          if (albaran.lineas.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Artículos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...albaran.lineas.asMap().entries.map((e) =>
                _filaLinea(e.key + 1, e.value)),
          ],

          // Notas
          if (albaran.notas.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Notas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(albaran.notas,
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ],

          const SizedBox(height: 24),

          // Botón principal: crear factura a partir de este albarán
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormularioFacturaRecibidaScreen(
                      empresaId: empresaId,
                      nombreProveedorInicial: albaran.nombreProveedor,
                      nifProveedorInicial: albaran.nifProveedor.isNotEmpty
                          ? albaran.nifProveedor
                          : null,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Crear factura de este albarán'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Acciones secundarias
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () { Navigator.pop(context); onEditar(); },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Editar'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary)),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () { Navigator.pop(context); onEliminar(); },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Eliminar'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red)),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _cambioEstadoRapido(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Cambiar estado',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: Colors.grey)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: EstadoAlbaranRecibido.values.map((e) {
          final sel = albaran.estado == e;
          final color = _colorEstadoStatic(e);
          return GestureDetector(
            onTap: sel ? null : () async {
              await svc.actualizarEstadoAlbaranRecibido(
                empresaId: empresaId,
                albaranId: albaran.id,
                nuevoEstado: e,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? color : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: sel ? 1 : 0.3)),
              ),
              child: Text(e.etiqueta,
                  style: TextStyle(
                      color: sel ? Colors.white : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _filaLinea(int num, LineaAlbaran l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
            child: Center(child: Text('$num',
                style: const TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(l.descripcion,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
        if (l.referencia.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('Ref: ${l.referencia}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
        const SizedBox(height: 4),
        Row(children: [
          if (l.cantidadPedida > 0) ...[
            Text('Pedida: ${_fmtQty(l.cantidadPedida)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(width: 12),
          ],
          Text('Recibida: ${_fmtQty(l.cantidadRecibida)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          if (l.cantidadPedida > 0 &&
              l.cantidadRecibida < l.cantidadPedida) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Parcial',
                  style: const TextStyle(color: Colors.orange, fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        if (l.notas.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(l.notas,
              style: const TextStyle(fontSize: 11, color: Colors.orange)),
        ],
      ]),
    );
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 120,
            child: Text(label, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12))),
        Expanded(child: Text(valor, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  Widget _badgeEstado(EstadoAlbaranRecibido e) {
    final color = _colorEstadoStatic(e);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(e.etiqueta,
          style: TextStyle(color: color, fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtQty(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static Color _colorEstadoStatic(EstadoAlbaranRecibido e) {
    switch (e) {
      case EstadoAlbaranRecibido.pendiente:   return Colors.orange;
      case EstadoAlbaranRecibido.conforme:    return Colors.green;
      case EstadoAlbaranRecibido.disconforme: return Colors.red;
      case EstadoAlbaranRecibido.parcial:     return Colors.blue;
    }
  }
}
