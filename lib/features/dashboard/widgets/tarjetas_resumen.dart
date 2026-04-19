        // Segunda fila de tarjetas
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
        Row(
/// Widget de resumen general con KPIs conectados a datos reales
          children: const [
  final String empresaId;

  const TarjetasResumen({
    super.key,
    required this.empresaId,
  });
              child: _TarjetaResumen(
                titulo: 'Ingresos Mes',
                valor: '\$2,450',
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('estadisticas')
          .doc('resumen')
          .snapshots(),
      builder: (context, snapshot) {
        // Valores por defecto mientras carga
        int totalClientes = 0;
        int reservasMes = 0;
        double ingresosMes = 0.0;
        double valoracionPromedio = 0.0;
        double crecimientoClientes = 0.0;
        double crecimientoReservas = 0.0;
        double crecimientoIngresos = 0.0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            totalClientes = (data['total_clientes'] as num?)?.toInt() ?? 0;
            reservasMes = (data['reservas_mes'] as num?)?.toInt() ?? 0;
            ingresosMes = (data['ingresos_mes'] as num?)?.toDouble() ?? 0.0;
            valoracionPromedio = (data['valoracion_promedio'] as num?)?.toDouble() ?? 
                                 (data['rating_google'] as num?)?.toDouble() ?? 0.0;
            
            // Cálculo de crecimientos basados en mes anterior
            final reservasMesAnterior = (data['reservas_mes_anterior'] as num?)?.toInt() ?? 0;
            final ingresosMesAnterior = (data['ingresos_mes_anterior'] as num?)?.toDouble() ?? 0.0;
            final clientesMesAnterior = (data['nuevos_clientes_mes_anterior'] as num?)?.toInt() ?? 0;
            final clientesNuevosMes = (data['nuevos_clientes_mes'] as num?)?.toInt() ?? 0;

            if (reservasMesAnterior > 0) {
              crecimientoReservas = ((reservasMes - reservasMesAnterior) / reservasMesAnterior) * 100;
            }
            if (ingresosMesAnterior > 0) {
              crecimientoIngresos = ((ingresosMes - ingresosMesAnterior) / ingresosMesAnterior) * 100;
            }
            if (clientesMesAnterior > 0) {
              crecimientoClientes = ((clientesNuevosMes - clientesMesAnterior) / clientesMesAnterior) * 100;
            }
          }
        }

        final formatoMoneda = NumberFormat.currency(symbol: '€', decimalDigits: 0);

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
                icono: Icons.star,
            // Primera fila de tarjetas
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
                color: Color(0xFF1976D2),
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
      },
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
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
