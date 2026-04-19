        // Segunda fila de tarjetas
        Row(
/// Widget de resumen general con KPIs conectados a datos reales
  final String empresaId;

  const TarjetasResumen({
    super.key,
    required this.empresaId,
  });
            Expanded(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen')
          .snapshots(),
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
                color: Color(0xFF1976D2),
                crecimiento: 8.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
import 'package:flutter/material.dart';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Resumen General',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
  const TarjetasResumen({super.key});
        Row(
          children: const [
            Expanded(
              child: _TarjetaResumen(
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen General',
            // Segunda fila de tarjetas
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
            
            // Indicador de carga o actualización
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(),
                  ),
                ),
              ),
          ],
        );
                color: Color(0xFFF57C00),
                mostrarCrecimiento: false,
              ),
            ),
          ],
        ),
      ],
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
