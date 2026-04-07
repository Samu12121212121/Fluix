import 'package:flutter/material.dart';
import '../../../services/briefing_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — Alertas fiscales próximas (semáforo verde/naranja/rojo)
// ─────────────────────────────────────────────────────────────────────────────

class AlertasFiscalesWidget extends StatelessWidget {
  const AlertasFiscalesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final vencimientos =
        CalendarioFiscalService.proximosVencimientos(DateTime.now());

    if (vencimientos.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Obligaciones fiscales',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('Sin vencimientos próximos',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
          ]),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.event_note, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Text('📋 Obligaciones fiscales',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const Divider(height: 20),
            ...vencimientos.take(5).map((v) => _ItemVencimiento(v: v)),
          ],
        ),
      ),
    );
  }
}

class _ItemVencimiento extends StatelessWidget {
  final VencimientoFiscal v;
  const _ItemVencimiento({required this.v});

  Color get _color {
    if (v.diasRestantes < 7) return Colors.red;
    if (v.diasRestantes <= 15) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        // Semáforo
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: _color, shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(v.descripcion,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _color.withValues(alpha: 0.3)),
          ),
          child: Text(
            v.diasRestantes == 0 ? 'HOY' : '${v.diasRestantes}d',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: _color),
          ),
        ),
      ]),
    );
  }
}

