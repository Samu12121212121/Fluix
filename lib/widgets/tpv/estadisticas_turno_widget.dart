import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kBg = Color(0xFF0A0F23);
const _kCard = Color(0xFF1E2139);
const _kVerde = Color(0xFF00FFC8);
const _kRosa = Color(0xFFFF3296);
const _kSecondary = Color(0xFFB0B3C1);

class EstadisticasTurnoWidget extends StatelessWidget {
  final String empresaId;

  const EstadisticasTurnoWidget({super.key, required this.empresaId});

  Stream<QuerySnapshot> _streamPedidosHoy() {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = inicio.add(const Duration(days: 1));
    // Rango en un solo campo — no requiere índice compuesto.
    // estado_pago se filtra client-side en el builder.
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos')
        .where('fecha_creacion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_creacion', isLessThan: Timestamp.fromDate(fin))
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final fmtEuro = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return StreamBuilder<QuerySnapshot>(
      stream: _streamPedidosHoy(),
      builder: (ctx, snap) {
        final docs = (snap.data?.docs ?? [])
            .where((d) =>
                (d.data() as Map<String, dynamic>)['estado_pago'] == 'pagado')
            .toList();

        double totalVendido = 0;
        int numTickets = docs.length;
        final Map<String, double> porMetodo = {
          'efectivo': 0,
          'tarjeta': 0,
          'bizum': 0,
          'mixto': 0,
        };

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final t = (d['total'] as num?)?.toDouble() ?? 0;
          totalVendido += t;
          final metodo = (d['metodo_pago'] as String?) ?? 'efectivo';
          porMetodo[metodo] = (porMetodo[metodo] ?? 0) + t;
        }

        final ticketMedio =
            numTickets > 0 ? totalVendido / numTickets : 0.0;

        final isLoading = snap.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kVerde),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TURNO HOY',
                      style: TextStyle(
                        color: _kSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Total',
                            valor: fmtEuro.format(totalVendido),
                            color: _kVerde,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricCard(
                            label: 'Tickets',
                            valor: '$numTickets',
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricCard(
                            label: 'Ticket medio',
                            valor: fmtEuro.format(ticketMedio),
                            color: _kRosa,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Por método de pago',
                      style: TextStyle(
                        color: _kSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _FilaMetodo(
                      icono: Icons.money_rounded,
                      label: 'Efectivo',
                      valor: fmtEuro.format(porMetodo['efectivo'] ?? 0),
                      color: _kVerde,
                    ),
                    _FilaMetodo(
                      icono: Icons.credit_card_rounded,
                      label: 'Tarjeta',
                      valor: fmtEuro.format(porMetodo['tarjeta'] ?? 0),
                      color: const Color(0xFF4FC3F7),
                    ),
                    _FilaMetodo(
                      icono: Icons.smartphone_rounded,
                      label: 'Bizum',
                      valor: fmtEuro.format(porMetodo['bizum'] ?? 0),
                      color: const Color(0xFFFFB74D),
                    ),
                    _FilaMetodo(
                      icono: Icons.merge_type_rounded,
                      label: 'Mixto',
                      valor: fmtEuro.format(porMetodo['mixto'] ?? 0),
                      color: _kRosa,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: _kSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FilaMetodo extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;
  final Color color;

  const _FilaMetodo({
    required this.icono,
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          Text(valor,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
