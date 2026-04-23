import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Widget de resumen general con KPIs conectados a datos reales de Firestore.
class TarjetasResumen extends StatelessWidget {
  final String empresaId;

  const TarjetasResumen({
    super.key,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0);
    final ahora = DateTime.now();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen')
          .snapshots(),
      builder: (context, snapshot) {
        final data = (snapshot.data?.data() as Map<String, dynamic>?) ?? {};

        final totalClientes = (data['total_clientes'] as num?)?.toInt() ?? 0;
        final reservasMes = (data['reservas_mes'] as num?)?.toInt() ?? 0;
        final ingresosMes = (data['ingresos_mes'] as num?)?.toDouble() ?? 0.0;
        final valoracionPromedio = (data['valoracion_promedio'] as num?)?.toDouble() ?? 0.0;
        final crecimientoClientes = (data['crecimiento_clientes'] as num?)?.toDouble() ?? 0.0;
        final crecimientoReservas = (data['crecimiento_reservas'] as num?)?.toDouble() ?? 0.0;
        final crecimientoIngresos = (data['crecimiento_ingresos'] as num?)?.toDouble() ?? 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen · ${_nombreMes(ahora.month)} ${ahora.year}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TarjetaResumen(
                    titulo: 'Clientes',
                    valor: '$totalClientes',
                    icono: Icons.people,
                    color: const Color(0xFF388E3C),
                    crecimiento: crecimientoClientes != 0 ? crecimientoClientes : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TarjetaResumen(
                    titulo: 'Reservas Mes',
                    valor: '$reservasMes',
                    icono: Icons.calendar_today,
                    color: const Color(0xFF1976D2),
                    crecimiento: crecimientoReservas != 0 ? crecimientoReservas : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TarjetaResumen(
                    titulo: 'Ingresos Mes',
                    valor: formatoMoneda.format(ingresosMes),
                    icono: Icons.account_balance_wallet,
                    color: const Color(0xFF689F38),
                    crecimiento: crecimientoIngresos != 0 ? crecimientoIngresos : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TarjetaResumen(
                    titulo: 'Valoración',
                    valor: valoracionPromedio > 0
                        ? '${valoracionPromedio.toStringAsFixed(1)} ★'
                        : '- ★',
                    icono: Icons.star,
                    color: const Color(0xFFF57C00),
                    mostrarCrecimiento: false,
                  ),
                ),
              ],
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        );
      },
    );
  }

  String _nombreMes(int mes) {
    const nombres = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return nombres[mes];
  }
}

class _TarjetaResumen extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  final double? crecimiento;
  final bool mostrarCrecimiento;

  const _TarjetaResumen({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
    this.crecimiento,
    this.mostrarCrecimiento = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(titulo,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(valor,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          if (mostrarCrecimiento && crecimiento != null) _buildCrecimiento(),
        ],
      ),
    );
  }

  Widget _buildCrecimiento() {
    final esPositivo = crecimiento! > 0;
    final colorCrecimiento = esPositivo ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: colorCrecimiento.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(esPositivo ? Icons.trending_up : Icons.trending_down, size: 12, color: colorCrecimiento),
            const SizedBox(width: 2),
            Text('${crecimiento!.abs().toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorCrecimiento)),
          ],
        ),
      ),
    );
  }
}
