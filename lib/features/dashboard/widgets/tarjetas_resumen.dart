import 'package:flutter/material.dart';

class TarjetasResumen extends StatelessWidget {
  const TarjetasResumen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen General',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Primera fila de tarjetas
        Row(
          children: const [
            Expanded(
              child: _TarjetaResumen(
                titulo: 'Clientes',
                valor: '25',
                icono: Icons.people,
                color: Color(0xFF388E3C),
                crecimiento: 12.5,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _TarjetaResumen(
                titulo: 'Reservas',
                valor: '48',
                icono: Icons.calendar_today,
                color: Color(0xFF1976D2),
                crecimiento: 8.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Segunda fila de tarjetas
        Row(
          children: const [
            Expanded(
              child: _TarjetaResumen(
                titulo: 'Ingresos Mes',
                valor: '\$2,450',
                icono: Icons.account_balance_wallet,
                color: Color(0xFF689F38),
                crecimiento: 15.7,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _TarjetaResumen(
                titulo: 'Valoración',
                valor: '4.8 ★',
                icono: Icons.star,
                color: Color(0xFFF57C00),
                mostrarCrecimiento: false,
              ),
            ),
          ],
        ),
      ],
    );
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con icono y título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    icono,
                    color: color,
                    size: 20,
                  ),
                ),
                if (mostrarCrecimiento && crecimiento != null)
                  _buildIndicadorCrecimiento(),
              ],
            ),
            const SizedBox(height: 16),

            // Valor principal
            Text(
              valor,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),

            // Título
            Text(
              titulo,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicadorCrecimiento() {
    if (crecimiento == null) return const SizedBox.shrink();

    final esPositivo = crecimiento! > 0;
    final colorCrecimiento = esPositivo ? const Color(0xFF4CAF50) : const Color(0xFFF44336);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colorCrecimiento.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esPositivo ? Icons.trending_up : Icons.trending_down,
            size: 12,
            color: colorCrecimiento,
          ),
          const SizedBox(width: 2),
          Text(
            '${crecimiento!.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorCrecimiento,
            ),
          ),
        ],
      ),
    );
  }
}
