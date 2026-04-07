import 'package:flutter/material.dart';
import '../../../models/saldo_vacaciones_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET DE SALDO DE VACACIONES
// Muestra días ordinarios y traspasados con barra segmentada.
// ═══════════════════════════════════════════════════════════════════════════════

class SaldoVacacionesWidget extends StatelessWidget {
  final SaldoVacaciones saldo;

  const SaldoVacacionesWidget({super.key, required this.saldo});

  @override
  Widget build(BuildContext context) {
    final ordinarios = saldo.diasOrdinariosPendientes;
    final arrastre = saldo.arrastreExpirado ? 0.0 : saldo.diasArrastreRestantes;
    final total = saldo.totalDisponible;
    final devengados = saldo.diasDevengados;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              const Icon(Icons.beach_access, size: 18, color: Color(0xFF00796B)),
              const SizedBox(width: 8),
              const Text(
                'Saldo de vacaciones',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${saldo.anio}',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Número grande
          Center(
            child: Column(
              children: [
                Text(
                  total.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00796B),
                  ),
                ),
                Text(
                  'días disponibles',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Barra segmentada
          _buildBarraSegmentada(ordinarios, arrastre, devengados),
          const SizedBox(height: 12),

          // Desglose
          _buildLineaDetalle(
            'Días ordinarios',
            ordinarios.toStringAsFixed(1),
            Colors.green,
          ),
          if (saldo.diasArrastre > 0)
            _buildLineaDetalle(
              'Días traspasados ${saldo.anio - 1}',
              arrastre.toStringAsFixed(1),
              Colors.blue,
              subtexto: saldo.arrastreExpirado
                  ? 'Expirados'
                  : saldo.fechaExpiracionArrastre != null
                      ? 'Límite: ${_formatFecha(saldo.fechaExpiracionArrastre!)}'
                      : null,
              subtextoColor:
                  saldo.arrastreExpirado ? Colors.red : Colors.blue[300],
            ),
          _buildLineaDetalle(
            'Disfrutados',
            '-${saldo.diasDisfrutados.toStringAsFixed(1)}',
            Colors.grey,
          ),
          _buildLineaDetalle(
            'Devengados total',
            devengados.toStringAsFixed(1),
            Colors.teal,
          ),

          // Alerta de expiración próxima
          if (!saldo.arrastreExpirado &&
              saldo.diasArrastreRestantes > 0 &&
              saldo.fechaExpiracionArrastre != null &&
              saldo.fechaExpiracionArrastre!
                  .difference(DateTime.now())
                  .inDays <=
                  7)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '⏰ Tus días traspasados expiran en '
                      '${saldo.fechaExpiracionArrastre!.difference(DateTime.now()).inDays} día(s)',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBarraSegmentada(
      double ordinarios, double arrastre, double devengados) {
    final total = ordinarios + arrastre;
    final maxWidth = devengados > 0 ? devengados : total;
    final fracOrdinarios = maxWidth > 0 ? (ordinarios / maxWidth) : 0.0;
    final fracArrastre = maxWidth > 0 ? (arrastre / maxWidth) : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            Expanded(
              flex: (fracOrdinarios * 100).round().clamp(0, 100),
              child: Container(color: Colors.green),
            ),
            if (arrastre > 0)
              Expanded(
                flex: (fracArrastre * 100).round().clamp(0, 100),
                child: Container(color: Colors.blue),
              ),
            Expanded(
              flex: ((1 - fracOrdinarios - fracArrastre) * 100)
                  .round()
                  .clamp(0, 100),
              child: Container(color: Colors.grey[200]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineaDetalle(
    String titulo,
    String valor,
    Color color, {
    String? subtexto,
    Color? subtextoColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(fontSize: 12, color: Colors.black87)),
                if (subtexto != null)
                  Text(subtexto,
                      style: TextStyle(
                          fontSize: 10,
                          color: subtextoColor ?? Colors.grey[400])),
              ],
            ),
          ),
          Text(valor,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

