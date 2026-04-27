import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/domain/modelos/widget_config.dart';
import 'package:planeag_flutter/features/dashboard/widgets/widget_proximos_dias.dart';
import 'package:planeag_flutter/features/dashboard/widgets/widgets_adicionales.dart';
import 'package:planeag_flutter/features/dashboard/widgets/widgets_resumen_modulos.dart';
import 'package:planeag_flutter/features/dashboard/widgets/briefing_card.dart';
import 'package:planeag_flutter/features/dashboard/widgets/alertas_fiscales_widget.dart';

class WidgetFactory {
  static Widget buildWidget(WidgetConfig config, String empresaId) {
    switch (config.id) {
    // ── IMPLEMENTADOS ──────────────────────────────────────────────────────
      case 'briefing_matutino':
        return BriefingCard(
          empresaId: empresaId,
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        );
      case 'alertas_fiscales':
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 0),
          child: AlertasFiscalesWidget(),
        );
      case 'proximos_dias':
        return WidgetProximosDias(empresaId: empresaId);
      case 'kpis_rapidos':
        return WidgetKpisRapidos(empresaId: empresaId);
      case 'reservas_hoy':
        return WidgetReservasHoy(empresaId: empresaId);
      case 'valoraciones_recientes':
        return WidgetValoracionesRecientes(empresaId: empresaId);
      case 'resumen_facturacion':
        return WidgetResumenFacturacion(empresaId: empresaId);
      case 'resumen_pedidos':
        return WidgetResumenPedidos(empresaId: empresaId);
    // ── PRÓXIMAMENTE ───────────────────────────────────────────────────────
      case 'ingresos_mes':
        return WidgetIngresosMes(empresaId: empresaId);
      case 'clientes_nuevos':
        return WidgetClientesNuevos(empresaId: empresaId);
      case 'alertas_negocio':
        return WidgetAlertasNegocio(empresaId: empresaId);

      default:
        debugPrint('WidgetFactory: id no reconocido -> ${config.id}');
        return WidgetNoImplementado(config: config);
    }
  }
}

// Widget placeholder para widgets no implementados
class WidgetNoImplementado extends StatelessWidget {
  final WidgetConfig config;

  const WidgetNoImplementado({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(config.icono, size: 32, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            Text(
              config.nombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Widget en desarrollo',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Próximamente',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}