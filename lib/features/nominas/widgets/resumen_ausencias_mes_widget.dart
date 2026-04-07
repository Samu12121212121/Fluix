import 'package:flutter/material.dart';
import '../../../services/ausencias_nomina_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET RESUMEN DE AUSENCIAS DEL MES PARA NÓMINA
// Muestra las ausencias detectadas antes de confirmar la nómina.
// ═══════════════════════════════════════════════════════════════════════════════

class ResumenAusenciasMesWidget extends StatelessWidget {
  final ResumenAusenciasMes resumen;

  const ResumenAusenciasMesWidget({super.key, required this.resumen});

  @override
  Widget build(BuildContext context) {
    final tieneDescuentos = resumen.descuentos.isNotEmpty;
    final tieneInfo = resumen.lineasInformativas.isNotEmpty;

    if (!tieneDescuentos && !tieneInfo) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tieneDescuentos ? Colors.red[200]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            children: [
              Icon(
                tieneDescuentos ? Icons.warning_amber_rounded : Icons.info_outline,
                size: 18,
                color: tieneDescuentos ? Colors.red[700] : Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tieneDescuentos
                      ? 'Ausencias con descuento en nómina'
                      : 'Ausencias del mes',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color:
                        tieneDescuentos ? Colors.red[800] : Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),

          // Alerta de pendientes de justificación
          if (resumen.hayPendientesJustificacion) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_empty,
                      size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hay solicitudes pendientes de justificar. '
                      'Revísalas antes de cerrar la nómina.',
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

          // Descuentos
          if (tieneDescuentos) ...[
            const SizedBox(height: 10),
            ...resumen.descuentos.map(_buildDescuentoTile),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total descuento',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  '-${resumen.totalDescuento.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          ],

          // Líneas informativas
          if (tieneInfo) ...[
            const SizedBox(height: 10),
            ...resumen.lineasInformativas.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l['concepto'] as String? ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      'Sin descuento',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescuentoTile(DescuentoAusencia d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.concepto,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${d.diasAusencia} día${d.diasAusencia > 1 ? 's' : ''} · '
                  '${d.fechaInicio.day}/${d.fechaInicio.month} - '
                  '${d.fechaFin.day}/${d.fechaFin.month}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '-${d.importeDescuento.toStringAsFixed(2)} €',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.red[700]),
          ),
        ],
      ),
    );
  }
}

