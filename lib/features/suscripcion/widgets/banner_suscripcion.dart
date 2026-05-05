import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// Banner que aparece en el dashboard cuando la suscripción
/// vence en 7 días o menos. Solo visible para el propietario.
class BannerSuscripcion extends StatelessWidget {
  final String empresaId;
  final bool esPropietario;

  const BannerSuscripcion({
    super.key,
    required this.empresaId,
    required this.esPropietario,
  });

  @override
  Widget build(BuildContext context) {
    if (!esPropietario) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('suscripcion')
          .doc('actual')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final estado = data['estado'] as String? ?? 'ACTIVA';

        // Solo mostrar banner si está activa pero próxima a vencer
        if (estado != 'ACTIVA') return const SizedBox.shrink();

        final fechaFinRaw = data['fecha_fin'];
        if (fechaFinRaw == null) return const SizedBox.shrink();

        DateTime fechaFin;
        if (fechaFinRaw is Timestamp) {
          fechaFin = fechaFinRaw.toDate();
        } else {
          return const SizedBox.shrink();
        }

        final diasRestantes = fechaFin.difference(DateTime.now()).inDays;

        // Solo mostrar si quedan 7 días o menos
        if (diasRestantes > 7) return const SizedBox.shrink();

        return _buildBanner(context, diasRestantes, fechaFin);
      },
    );
  }

  Widget _buildBanner(BuildContext context, int dias, DateTime fechaFin) {
    final esUrgente = dias <= 2;
    final color = esUrgente ? const Color(0xFFD32F2F) : const Color(0xFFF57C00);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            esUrgente ? Icons.warning_amber_rounded : Icons.info_outline,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esUrgente
                      ? '⚠️ Suscripción vence en $dias día${dias == 1 ? '' : 's'}'
                      : '🔔 Suscripción próxima a vencer',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Vence el ${_formatFecha(fechaFin)}. Renueva para no perder el acceso.',
                  style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _mostrarRenovacion(context, color),
            style: TextButton.styleFrom(foregroundColor: color, padding: EdgeInsets.zero),
            child: const Text('Renovar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  void _mostrarRenovacion(BuildContext context, Color color) async {
    final uri = Uri.parse('https://fluixtech.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: mostrar datos de contacto
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.refresh, color: color),
              const SizedBox(width: 8),
              const Text('Renovar Suscripción'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Visita nuestra web o contacta con nosotros:'),
              SizedBox(height: 12),
              Row(children: [Icon(Icons.language, size: 16), SizedBox(width: 8), Text('fluixtech.com')]),
              SizedBox(height: 6),
              Row(children: [Icon(Icons.email, size: 16), SizedBox(width: 8), Text('soporte@fluixtech.com')]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ],
        ),
      );
    }
  }
}

