import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/fluix_app_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DE FIADOS — Deudas pendientes de cobro
// ─────────────────────────────────────────────────────────────────────────────

class PantallaFiadosScreen extends StatefulWidget {
  final String empresaId;
  const PantallaFiadosScreen({super.key, required this.empresaId});

  @override
  State<PantallaFiadosScreen> createState() => _PantallaFiadosScreenState();
}

class _PantallaFiadosScreenState extends State<PantallaFiadosScreen> {
  static const _bg     = Color(0xFF0A0F23);
  static const _card   = Color(0xFF1E2139);
  static const _oro    = Color(0xFFFFCC00);
  static const _verde  = Color(0xFF00FFC8);
  static const _rojo   = Color(0xFFFF2850);
  static const _texto  = Colors.white;
  static const _muted  = Color(0xFFB0B3C1);

  String _filtro = 'pendiente'; // 'pendiente' | 'cobrado' | 'todos'

  Stream<QuerySnapshot> get _stream {
    var q = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('pedidos')
        .where('es_fiado', isEqualTo: true)
        .orderBy('fecha_creacion', descending: true);

    if (_filtro != 'todos') {
      q = q.where('estado_pago',
          isEqualTo: _filtro == 'pendiente' ? 'pendiente' : 'pagado');
    }
    return q.snapshots();
  }

  Future<void> _marcarCobrado(String pedidoId, double total) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Row(children: [
          Icon(Icons.check_circle_outline, color: _verde, size: 20),
          SizedBox(width: 8),
          Text('Cobrar fiado', style: TextStyle(color: _texto, fontSize: 16)),
        ]),
        content: Text(
          '¿Marcar este fiado de ${NumberFormat.currency(symbol: '€', decimalDigits: 2).format(total)} como cobrado?',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: _muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _verde),
            child: const Text('Cobrar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('pedidos')
        .doc(pedidoId)
        .update({
      'estado_pago': 'pagado',
      'metodo_pago': 'efectivo',
      'fecha_cobro_fiado': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Fiado cobrado'),
          backgroundColor: _verde,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final fmtDate = DateFormat('dd/MM/yy HH:mm');

    return Scaffold(
      backgroundColor: _bg,
      appBar: FluixAppBar(
        titulo: 'Fiados pendientes',
        showLeading: true,
        extraActions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _filtro = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pendiente', child: Text('Solo pendientes')),
              PopupMenuItem(value: 'cobrado', child: Text('Solo cobrados')),
              PopupMenuItem(value: 'todos', child: Text('Todos')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _oro));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: _rojo)),
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _Vacio(filtro: _filtro);

          // Calcular totales
          double totalPendiente = 0;
          double totalCobrado = 0;
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final total = (data['total'] as num?)?.toDouble() ?? 0;
            if (data['estado_pago'] == 'pendiente') {
              totalPendiente += total;
            } else {
              totalCobrado += total;
            }
          }

          return Column(
            children: [
              // Resumen
              _TarjetaResumen(
                totalPendiente: totalPendiente,
                totalCobrado: totalCobrado,
                numPendientes: docs.where((d) =>
                    (d.data() as Map)['estado_pago'] == 'pendiente').length,
                fmt: fmt,
              ),

              // Lista
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final doc  = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final total      = (data['total'] as num?)?.toDouble() ?? 0;
                    final cliente    = data['cliente_fiado'] as String?
                        ?? data['cliente_nombre'] as String?
                        ?? 'Desconocido';
                    final mesa       = data['mesa_nombre'] as String?
                        ?? data['mesa_id'] as String?
                        ?? '';
                    final esPendiente = data['estado_pago'] == 'pendiente';
                    final fecha      = (data['fecha_creacion'] as Timestamp?)?.toDate();
                    final lineas = (data['lineas'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>();

                    return _TarjetaFiado(
                      cliente: cliente,
                      mesa: mesa,
                      total: total,
                      esPendiente: esPendiente,
                      fecha: fecha,
                      lineas: lineas,
                      fmt: fmt,
                      fmtDate: fmtDate,
                      onCobrar: esPendiente
                          ? () => _marcarCobrado(doc.id, total)
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

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA RESUMEN SUPERIOR
// ─────────────────────────────────────────────────────────────────────────────
class _TarjetaResumen extends StatelessWidget {
  final double totalPendiente;
  final double totalCobrado;
  final int numPendientes;
  final NumberFormat fmt;

  const _TarjetaResumen({
    required this.totalPendiente,
    required this.totalCobrado,
    required this.numPendientes,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        // Pendiente
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PENDIENTE', style: TextStyle(
                color: Color(0xFFB0B3C1), fontSize: 10, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(fmt.format(totalPendiente),
                style: const TextStyle(
                    color: Color(0xFFFFCC00),
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            Text('$numPendientes fiado${numPendientes != 1 ? 's' : ''}',
                style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 12)),
          ]),
        ),
        Container(width: 1, height: 48, color: const Color(0xFF2A2E45)),
        const SizedBox(width: 16),
        // Cobrado
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('COBRADO', style: TextStyle(
                color: Color(0xFFB0B3C1), fontSize: 10, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(fmt.format(totalCobrado),
                style: const TextStyle(
                    color: Color(0xFF00FFC8),
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA FIADO
// ─────────────────────────────────────────────────────────────────────────────
class _TarjetaFiado extends StatefulWidget {
  final String cliente;
  final String mesa;
  final double total;
  final bool esPendiente;
  final DateTime? fecha;
  final List<Map<String, dynamic>> lineas;
  final NumberFormat fmt;
  final DateFormat fmtDate;
  final VoidCallback? onCobrar;

  const _TarjetaFiado({
    required this.cliente,
    required this.mesa,
    required this.total,
    required this.esPendiente,
    required this.fecha,
    required this.lineas,
    required this.fmt,
    required this.fmtDate,
    required this.onCobrar,
  });

  @override
  State<_TarjetaFiado> createState() => _TarjetaFiadoState();
}

class _TarjetaFiadoState extends State<_TarjetaFiado> {
  bool _expanded = false;

  static const _oro   = Color(0xFFFFCC00);
  static const _verde = Color(0xFF00FFC8);
  static const _card  = Color(0xFF1E2139);
  static const _texto = Colors.white;
  static const _muted = Color(0xFFB0B3C1);

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.esPendiente ? _oro : _verde;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withValues(alpha: _expanded ? 0.6 : 0.3),
            width: _expanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                // Estado badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      widget.esPendiente ? Icons.schedule_rounded : Icons.check_circle_rounded,
                      size: 10, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      widget.esPendiente ? 'PENDIENTE' : 'COBRADO',
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                // Cliente
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.cliente,
                        style: const TextStyle(
                            color: _texto,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    if (widget.mesa.isNotEmpty)
                      Text(widget.mesa,
                          style: const TextStyle(color: _muted, fontSize: 11)),
                  ]),
                ),
                // Total
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(widget.fmt.format(widget.total),
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  if (widget.fecha != null)
                    Text(widget.fmtDate.format(widget.fecha!),
                        style: const TextStyle(color: _muted, fontSize: 10)),
                ]),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: _muted, size: 18),
              ]),
            ),

            // Expandido: líneas + botón cobrar
            if (_expanded) ...[
              const Divider(height: 1, color: Color(0xFF2A2E45)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ARTÍCULOS', style: TextStyle(
                        color: _muted, fontSize: 9,
                        letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ...widget.lineas.map((l) {
                      final cant  = (l['cantidad'] as num?)?.toInt() ?? 1;
                      final nombre = l['producto_nombre'] as String?
                          ?? l['nombre'] as String? ?? '';
                      final pvp   = (l['precio_pvp'] as num?)?.toDouble()
                          ?? (l['precio_unitario'] as num?)?.toDouble() ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: Text('$cant',
                                style: TextStyle(
                                    color: accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(nombre,
                                style: const TextStyle(color: _texto, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(widget.fmt.format(pvp * cant),
                              style: const TextStyle(color: _muted, fontSize: 12)),
                        ]),
                      );
                    }),
                    if (widget.onCobrar != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton.icon(
                          onPressed: widget.onCobrar,
                          icon: const Icon(Icons.payments_rounded, size: 16),
                          label: Text('Cobrar ${widget.fmt.format(widget.total)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: _verde,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO VACÍO
// ─────────────────────────────────────────────────────────────────────────────
class _Vacio extends StatelessWidget {
  final String filtro;
  const _Vacio({required this.filtro});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_outline_rounded,
            size: 64, color: Color(0xFF00FFC8)),
        const SizedBox(height: 16),
        Text(
          filtro == 'pendiente'
              ? 'Sin fiados pendientes'
              : filtro == 'cobrado'
                  ? 'Sin fiados cobrados'
                  : 'No hay fiados registrados',
          style: const TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Los cobros "fiado" aparecerán aquí',
          style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 12),
        ),
      ]),
    );
  }
}
