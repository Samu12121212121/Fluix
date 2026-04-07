import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── RESUMEN FACTURACIÓN ───────────────────────────────────────────────────────

class WidgetResumenFacturacion extends StatelessWidget {
  final String empresaId;
  const WidgetResumenFacturacion({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioMes  = DateTime(hoy.year, hoy.month, 1);
    final inicioHoy  = DateTime(hoy.year, hoy.month, hoy.day);
    final inicioAnio = DateTime(hoy.year, 1, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('facturas')
          .where('fecha_emision',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioAnio))
          .snapshots(),
      builder: (context, snap) {
        double totalHoy  = 0;
        double totalMes  = 0;
        double totalAnio = 0;
        double ivaMes    = 0;
        int pendientes   = 0;
        int vencidas     = 0;
        int totalFacturasMes = 0;

        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final estado = d['estado'] as String? ?? '';
            final total  = (d['total']     as num?)?.toDouble() ?? 0;
            final iva    = (d['total_iva'] as num?)?.toDouble() ?? 0;
            final fecha  = (d['fecha_emision'] as Timestamp?)?.toDate();

            if (fecha == null) continue;

            // Acumulados anuales (pagadas)
            if (estado == 'pagada') {
              totalAnio += total;
              if (!fecha.isBefore(inicioMes)) {
                totalMes += total;
                ivaMes   += iva;
                totalFacturasMes++;
              }
              if (!fecha.isBefore(inicioHoy)) totalHoy += total;
            }
            if (estado == 'pendiente') pendientes++;
            if (estado == 'vencida')   vencidas++;
          }
        }

        final mesNombre = _nombreMes(hoy.month);

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Cabecera ──────────────────────────────────────────────
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Facturación',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  // Badges de alertas
                  if (vencidas > 0) ...[
                    _badge('$vencidas vencida${vencidas != 1 ? 's' : ''}',
                        Colors.red),
                    const SizedBox(width: 6),
                  ],
                  if (pendientes > 0)
                    _badge('$pendientes pendiente${pendientes != 1 ? 's' : ''}',
                        Colors.orange),
                ]),
                const SizedBox(height: 14),

                // ── KPIs fila 1 ───────────────────────────────────────────
                Row(children: [
                  Expanded(child: _kpi('Hoy',
                      '${totalHoy.toStringAsFixed(2)}€',
                      Icons.today, const Color(0xFF1976D2))),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi('$mesNombre',
                      '${totalMes.toStringAsFixed(2)}€',
                      Icons.calendar_month, const Color(0xFF4CAF50))),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi('IVA mes',
                      '${ivaMes.toStringAsFixed(2)}€',
                      Icons.percent, const Color(0xFFE65100))),
                ]),
                const SizedBox(height: 10),

                // ── KPIs fila 2 ───────────────────────────────────────────
                Row(children: [
                  Expanded(child: _kpi('Anual ${hoy.year}',
                      '${totalAnio.toStringAsFixed(2)}€',
                      Icons.bar_chart, const Color(0xFF7B1FA2))),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi('Facturas mes',
                      '$totalFacturasMes',
                      Icons.description_outlined, const Color(0xFF0097A7))),
                  const SizedBox(width: 10),
                  // Ratio cobro
                  Expanded(child: _kpi('Pendiente',
                      '$pendientes fact.',
                      Icons.pending_actions,
                      pendientes > 0 ? Colors.orange : Colors.green)),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _badge(String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(texto,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  Widget _kpi(String label, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icono, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 4),
          Text(valor,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  String _nombreMes(int mes) {
    const nombres = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo',
      'Junio', 'Julio', 'Agosto', 'Sep.', 'Octubre', 'Nov.', 'Dic.'];
    return nombres[mes];
  }
}

// ── RESUMEN PEDIDOS ───────────────────────────────────────────────────────────

class WidgetResumenPedidos extends StatelessWidget {
  final String empresaId;
  const WidgetResumenPedidos({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final inicioMes = DateTime(hoy.year, hoy.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos')
          .where('fecha_creacion',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .snapshots(),
      builder: (context, snap) {
        int pedidosHoy    = 0;
        int pedidosMes    = 0;
        int pendientes    = 0;
        double ventasHoy  = 0;
        double ventasMes  = 0;

        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final estado = d['estado'] as String? ?? '';
            final precio = (d['precio_total'] as num?)?.toDouble() ?? 0;
            final fecha  = (d['fecha_creacion'] as Timestamp?)?.toDate();

            pedidosMes++;
            ventasMes += precio;

            if (fecha != null && !fecha.isBefore(inicioHoy)) {
              pedidosHoy++;
              ventasHoy += precio;
            }
            if (estado == 'pendiente' || estado == 'confirmado') pendientes++;
          }
        }

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Cabecera ──────────────────────────────────────────────
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE65100), Color(0xFFFF9800)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Pedidos',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  if (pendientes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendientes por gestionar',
                        style: const TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),

                // ── KPIs ─────────────────────────────────────────────────
                Row(children: [
                  Expanded(child: _kpi('Pedidos hoy',
                      '$pedidosHoy',
                      Icons.today, const Color(0xFFE65100))),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi('Ventas hoy',
                      '${ventasHoy.toStringAsFixed(2)}€',
                      Icons.euro, const Color(0xFF4CAF50))),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi('Mes',
                      '$pedidosMes ped.',
                      Icons.calendar_month, const Color(0xFF1976D2))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _kpi('Ventas mes',
                      '${ventasMes.toStringAsFixed(2)}€',
                      Icons.bar_chart, const Color(0xFF7B1FA2))),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi('Pendientes',
                      '$pendientes',
                      Icons.pending_actions,
                      pendientes > 0 ? Colors.orange : Colors.green)),
                  const SizedBox(width: 10),
                  // Ticket medio
                  Expanded(child: _kpi('Ticket medio',
                      pedidosMes > 0
                          ? '${(ventasMes / pedidosMes).toStringAsFixed(2)}€'
                          : '-',
                      Icons.receipt, const Color(0xFF0097A7))),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kpi(String label, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icono, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 4),
          Text(valor,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

