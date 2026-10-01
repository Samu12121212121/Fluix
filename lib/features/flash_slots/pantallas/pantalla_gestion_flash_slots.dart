import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/flash_slot_model.dart';
import '../../../services/flash_slot_service.dart';
import 'pantalla_crear_flash_slot.dart';
import '../../../core/widgets/fluix_app_bar.dart';

class _P {
  static const fondo      = Color(0xFF0A0F23);
  static const superficie = Color(0xFF151932);
  static const tarjeta    = Color(0xFF1E2139);
  static const borde      = Color(0xFF2A2E45);
  static const flash      = Color(0xFFFFBB00);
  static const flashBg    = Color(0xFF3D2E00);
  static const accent     = Color(0xFF00FFC8);
  static const rosa       = Color(0xFFFF3296);
  static const rojo       = Color(0xFFFF2850);
  static const texto      = Color(0xFFFFFFFF);
  static const textoMuted = Color(0xFFB0B3C1);
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA GESTIÓN FLASH SLOTS (vista NEGOCIO)
// ─────────────────────────────────────────────────────────────────────────────
class PantallaGestionFlashSlots extends StatelessWidget {
  final String negocioId;
  final String negocioNombre;
  final String empresaId;
  final String? negocioFotoUrl;

  const PantallaGestionFlashSlots({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    required this.empresaId,
    this.negocioFotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _P.fondo,
        appBar: const FluixAppBar(titulo: 'Flash Slots'),
        body: const SizedBox.shrink(),
      ),
    );
  }
}

class _MetricaBox extends StatelessWidget {
  final String label, valor;
  final bool highlight;
  const _MetricaBox({required this.label, required this.valor,
    this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? _P.flash.withValues(alpha: 0.12)
            : _P.tarjeta,
        borderRadius: BorderRadius.circular(10),
        border: highlight ? Border.all(color: _P.flash.withValues(alpha: 0.3)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 10, color: highlight ? _P.flash : _P.textoMuted)),
        const SizedBox(height: 4),
        Text(valor, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800,
            color: highlight ? _P.flash : _P.texto)),
      ]),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD HISTORIAL
// ─────────────────────────────────────────────────────────────────────────────
class _CardHistorial extends StatelessWidget {
  final FlashSlotModel slot;
  const _CardHistorial({required this.slot});

  @override
  Widget build(BuildContext context) {
    final pct = (slot.porcentajeOcupacion * 100).toInt();
    final ingresos = slot.huecosReservados * slot.precioFinal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.tarjeta, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(slot.servicioNombre, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _P.texto)),
          ),
          _EstadoBadge(estado: slot.estado),
        ]),
        const SizedBox(height: 8),

        // Precios
        Row(children: [
          Text('€${slot.precioFinal.toStringAsFixed(2)} flash',
              style: const TextStyle(fontSize: 12, color: _P.flash,
                  fontWeight: FontWeight.w600)),
          const Text(' · ', style: TextStyle(color: _P.borde)),
          Text('€${slot.precioOriginal.toStringAsFixed(2)} original',
              style: const TextStyle(fontSize: 11, color: _P.textoMuted,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _P.textoMuted)),
        ]),
        const SizedBox(height: 10),

        // Métricas
        Row(children: [
          _MiniMetrica(label: 'Huecos', val: '${slot.huecosReservados}/${slot.huecosTotal}'),
          const SizedBox(width: 12),
          _MiniMetrica(label: 'Ocupación', val: '$pct%',
              color: pct >= 80 ? _P.accent : pct >= 50 ? _P.flash : _P.rojo),
          const SizedBox(width: 12),
          _MiniMetrica(label: 'Ingresos', val: '€${ingresos.toStringAsFixed(2)}',
              color: _P.flash),
        ]),
        const SizedBox(height: 8),

        // Barra de ocupación
        _BarraOcupacion(slot: slot, compact: true),
        const SizedBox(height: 8),

        Text(_formatFecha(slot.creadoAt),
            style: const TextStyle(fontSize: 10, color: _P.textoMuted)),
      ]),
    );
  }

  String _formatFecha(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _MiniMetrica extends StatelessWidget {
  final String label, val;
  final Color? color;
  const _MiniMetrica({required this.label, required this.val, this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: _P.textoMuted)),
      Text(val, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: color ?? _P.texto)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS REUTILIZABLES
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownBadge extends StatelessWidget {
  final Duration restante;
  const _CountdownBadge({required this.restante});

  @override
  Widget build(BuildContext context) {
    if (restante.isNegative) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: _P.rojo.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6)),
        child: const Text('Expirado',
            style: TextStyle(fontSize: 10, color: _P.rojo, fontWeight: FontWeight.w700)),
      );
    }
    final h = restante.inHours;
    final m = restante.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = restante.inSeconds.remainder(60).toString().padLeft(2, '0');
    final urgente = restante.inMinutes < 30;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgente ? _P.rojo.withValues(alpha: 0.15)
            : _P.flash.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 11,
            color: urgente ? _P.rojo : _P.flash),
        const SizedBox(width: 3),
        Text(h > 0 ? '${h}h ${m}m' : '${m}m ${s}s',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: urgente ? _P.rojo : _P.flash)),
      ]),
    );
  }
}

class _BarraOcupacion extends StatelessWidget {
  final FlashSlotModel slot;
  final bool compact;
  const _BarraOcupacion({required this.slot, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final pct = slot.porcentajeOcupacion;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!compact) ...[
        Row(children: [
          Icon(Icons.people_outline_rounded, size: 12, color: _P.textoMuted),
          const SizedBox(width: 4),
          Text('${slot.huecosReservados} de ${slot.huecosTotal} huecos ocupados',
              style: const TextStyle(fontSize: 11, color: _P.textoMuted)),
        ]),
        const SizedBox(height: 5),
      ],
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: compact ? 4 : 6,
          backgroundColor: _P.borde,
          valueColor: AlwaysStoppedAnimation<Color>(
            pct >= 0.8 ? _P.rojo : pct >= 0.5 ? _P.flash : _P.accent,
          ),
        ),
      ),
    ]);
  }
}

class _EstadoBadge extends StatelessWidget {
  final EstadoFlashSlot estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color;
    String texto;
    switch (estado) {
      case EstadoFlashSlot.activo:
        color = _P.accent; texto = '● Activo'; break;
      case EstadoFlashSlot.completo:
        color = _P.flash; texto = '✓ Completo'; break;
      case EstadoFlashSlot.expirado:
        color = _P.textoMuted; texto = '⏱ Expirado'; break;
      case EstadoFlashSlot.cancelado:
        color = _P.rojo; texto = '✕ Cancelado'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(texto, style: TextStyle(
          fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

