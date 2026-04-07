import 'package:flutter/material.dart';
import '../models/saldo_vacaciones_model.dart';
import '../services/vacaciones_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET DE SALDO DE VACACIONES
// ═══════════════════════════════════════════════════════════════════════════════

/// Widget reutilizable que muestra la barra de progreso de vacaciones.
/// Ej: "Vacaciones 2026: 12/30 días disfrutados | 18 pendientes"
class SaldoVacacionesWidget extends StatelessWidget {
  final String empresaId;
  final String empleadoId;
  final int anio;
  final VoidCallback? onNuevaSolicitud;

  const SaldoVacacionesWidget({
    super.key,
    required this.empresaId,
    required this.empleadoId,
    required this.anio,
    this.onNuevaSolicitud,
  });

  @override
  Widget build(BuildContext context) {
    final svc = VacacionesService();

    return FutureBuilder<SaldoVacaciones>(
      future: svc.calcularSaldo(empresaId, empleadoId, anio),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error calculando saldo: ${snap.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          );
        }

        final saldo = snap.data;
        if (saldo == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sin datos de vacaciones',
                style: TextStyle(color: Colors.grey)),
          );
        }

        return _buildCard(context, saldo);
      },
    );
  }

  Widget _buildCard(BuildContext context, SaldoVacaciones saldo) {
    final total = saldo.diasDevengados + saldo.diasPendientesAnoAnterior;
    final pct = total > 0
        ? (saldo.diasDisfrutados / total).clamp(0.0, 1.0)
        : 0.0;
    final pendientes = saldo.totalDisponible;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00796B).withValues(alpha: 0.08),
            const Color(0xFF26A69A).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF00796B).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.beach_access,
                  color: Color(0xFF00796B), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vacaciones $anio',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF00796B)),
                ),
              ),
              if (onNuevaSolicitud != null)
                TextButton.icon(
                  onPressed: onNuevaSolicitud,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Solicitar',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00796B),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: pct > 0.9
                  ? Colors.red
                  : (pct > 0.7 ? Colors.orange : const Color(0xFF00796B)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${saldo.diasDisfrutados.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} días disfrutados',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pendientes > 5
                      ? const Color(0xFF00796B).withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${pendientes.toStringAsFixed(1)} pendientes',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pendientes > 5
                        ? const Color(0xFF00796B)
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          if (saldo.diasPendientesAnoAnterior > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Incluye ${saldo.diasPendientesAnoAnterior.toStringAsFixed(1)} días del año anterior (hasta 31/01)',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}

